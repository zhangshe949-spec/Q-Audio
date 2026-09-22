$ErrorActionPreference = "Stop"
$ConfirmPreference = "None"

flutter config --enable-windows-desktop
flutter build windows --release

# The raw Flutter output directory has no AppxManifest.xml, so makeappx
# cannot pack it directly. Use the `msix` package (dev dependency) which
# generates the manifest from pubspec msix_config and packs the MSIX.
# msix_config in pubspec.yaml: output_path=build/msix, output_name=Q-Audio,
# build_windows=false (we just built above), sign_msix=false.
dart run msix:create

# msix writes to build/msix/Q-Audio.msix (per pubspec msix_config).
# Copy to the path the workflow artifact step expects.
$msixSource = "build/msix/Q-Audio.msix"
if (-not (Test-Path $msixSource)) {
    # Fallback: locate whatever .msix msix:create produced.
    $found = Get-ChildItem -Path "build" -Recurse -Filter "*.msix" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $found) { throw "msix:create produced no .msix under build/" }
    $msixSource = $found.FullName
}
Write-Host "MSIX produced: $msixSource"

$msixOutput = "build/windows/msix"
New-Item -ItemType Directory -Path $msixOutput -Force | Out-Null
Copy-Item $msixSource -Destination (Join-Path $msixOutput "Q-Audio.msix") -Force

Write-Host "MSIX ready: $msixOutput\Q-Audio.msix"
Get-ChildItem $msixOutput