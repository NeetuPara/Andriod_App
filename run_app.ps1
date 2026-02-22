Set-Location $PSScriptRoot
$env:PATH += ";$PSScriptRoot"

Write-Host "Stopping any running instances..."
Stop-Process -Name "llama-server" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "flutter_app" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Write-Host "Building Windows app..."
flutter build windows --debug

Write-Host "Copying Local AI Engine files..."
$source = "$PSScriptRoot\llama_extracted\*"
$dest = "$PSScriptRoot\build\windows\x64\runner\Debug\"
Copy-Item $source $dest -Recurse -Force

Write-Host "Launching app..."
flutter run -d windows
