$ErrorActionPreference = "Stop"
$ConfirmPreference = "None"

flutter config --enable-windows-desktop
flutter build windows --release

# Find makeappx.exe dynamically
$makeappx = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Recurse -Filter "makeappx.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $makeappx) {
    $makeappx = Get-ChildItem "C:\Program Files\Windows Kits\10\bin" -Recurse -Filter "makeappx.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $makeappx) {
    Write-Host "makeappx.exe not found, trying WiX Toolset..."
    $makeappx = Get-ChildItem "C:\Program Files (x86)\WiX Toolset*" -Recurse -Filter "makeappx.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $makeappx) {
    throw "makeappx.exe not found. Install Windows SDK or WiX Toolset."
}
Write-Host "Using makeappx: $($makeappx.FullName)"

$msixOutput = "build/windows/msix"
if (Test-Path $msixOutput) { Remove-Item $msixOutput -Recurse -Force }
New-Item -ItemType Directory -Path $msixOutput | Out-Null

$buildDir = "build/windows/runner/Release"
$msixFile = Join-Path $msixOutput "Q-Audio.msix"

& $makeappx.FullName pack /d $buildDir /p $msixFile /l
if ($LASTEXITCODE -ne 0) { throw "makeappx failed with exit code $LASTEXITCODE" }

Write-Host "MSIX created: $msixFile"
Get-ChildItem $msixOutput