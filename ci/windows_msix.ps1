$ErrorActionPreference = "Stop"
$ConfirmPreference = "None"

flutter config --enable-windows-desktop
flutter build windows --release

$msixOutput = "build/windows/msix"
if (Test-Path $msixOutput) { Remove-Item $msixOutput -Recurse -Force }
New-Item -ItemType Directory -Path $msixOutput | Out-Null

$buildDir = "build/windows/runner/Release"
$msixFile = Join-Path $msixOutput "Q-Audio.msix"

& "C:\Program Files (x86)\Windows Kits\10\bin\x64\makeappx.exe" pack `
    /d $buildDir `
    /p $msixFile `
    /l