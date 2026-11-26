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

$envFile = Join-Path $PSScriptRoot '.env.json'
if (-not (Test-Path $envFile)) {
  Copy-Item (Join-Path $PSScriptRoot '.env.example.json') $envFile
  Write-Host 'Fichier .env.json créé depuis .env.example.json. Vérifiez API_BASE_URL avant le lancement.' -ForegroundColor Yellow
}


& $adb connect 127.0.0.1:5555
$deviceId = (& $adb devices | Select-String -Pattern '^(emulator-\d+|127\.0\.0\.1:\d+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -First 1)
if (-not $deviceId) {
  throw 'Aucun appareil BlueStacks détecté par ADB. Vérifiez que BlueStacks est lancé et que ADB est activé dans ses paramètres.'
}
& $flutterCommand.Source run -d $deviceId --dart-define-from-file=.env.json
