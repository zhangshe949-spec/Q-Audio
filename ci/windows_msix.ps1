$ErrorActionPreference = "Stop"
$ConfirmPreference = "None"

flutter config --enable-windows-desktop
flutter build windows --release

# Find makeappx.exe: prefer x64 binary, newest Windows SDK first.
$makeappx = $null
$searchRoots = @(
    "C:\Program Files (x86)\Windows Kits\10\bin",
    "C:\Program Files\Windows Kits\10\bin"
)
foreach ($root in $searchRoots) {
    if (-not (Test-Path $root)) { continue }
    $candidates = Get-ChildItem $root -Recurse -Filter "makeappx.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "\\x64\\" } |
        Sort-Object FullName -Descending
    if ($candidates) { $makeappx = $candidates[0]; break }
}
if (-not $makeappx) {
    throw "x64 makeappx.exe not found under Windows Kits. Install Windows SDK."
}
Write-Host "Using makeappx: $($makeappx.FullName)"

$msixOutput = "build/windows/msix"
if (Test-Path $msixOutput) { Remove-Item $msixOutput -Recurse -Force }
New-Item -ItemType Directory -Path $msixOutput | Out-Null

# Flutter may use an architecture-specific output directory
# (build/windows/x64/runner/Release on recent SDKs).
$buildCandidates = @(
    "build/windows/x64/runner/Release",
    "build/windows/runner/Release"
)
$buildDir = $buildCandidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
if (-not $buildDir) {
    throw "Flutter Windows release output not found (tried: $($buildCandidates -join ', '))."
}
Write-Host "Packaging Windows build from: $buildDir"
$msixFile = Join-Path $msixOutput "Q-Audio.msix"

& $makeappx.FullName pack /d $buildDir /p $msixFile /l
if ($LASTEXITCODE -ne 0) { throw "makeappx failed with exit code $LASTEXITCODE" }

Write-Host "MSIX created: $msixFile"
Get-ChildItem $msixOutput