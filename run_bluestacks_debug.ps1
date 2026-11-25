$ErrorActionPreference = 'Stop'

$flutterCommand = Get-Command flutter -ErrorAction Stop
$androidSdk = $env:ANDROID_HOME
if (-not $androidSdk -or -not (Test-Path (Join-Path $androidSdk 'platform-tools\adb.exe'))) {
  $androidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
}

$adb = Join-Path $androidSdk 'platform-tools\adb.exe'
if (-not (Test-Path $adb)) {
  throw "Android SDK introuvable : $androidSdk"
}

$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
Set-Location $PSScriptRoot

& $adb connect 127.0.0.1:5555
& $flutterCommand.Source run -d emulator-5554 --dart-define-from-file=.env.json
