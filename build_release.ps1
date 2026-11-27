$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

$flutter = Get-Command flutter -ErrorAction Stop
$envFile = Join-Path $PSScriptRoot '.env.json'
if (-not (Test-Path $envFile)) {
  throw "Fichier .env.json absent. Créez-le depuis .env.example.json et renseignez API_BASE_URL."
}

$config = Get-Content -Raw $envFile | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$config.API_BASE_URL)) {
  throw "API_BASE_URL est vide dans .env.json : l'APK ne pourra pas enregistrer son token FCM auprès de MediLink/Novu."
}
if ([string]::IsNullOrWhiteSpace([string]$config.GOOGLE_CLIENT_ID)) {
  throw "GOOGLE_CLIENT_ID est vide dans .env.json."
}

$firebaseConfigPath = Join-Path $PSScriptRoot 'android\app\google-services.json'
if (-not (Test-Path $firebaseConfigPath)) {
  throw "android/app/google-services.json est absent."
}
$firebaseConfig = Get-Content -Raw $firebaseConfigPath | ConvertFrom-Json
$androidClient = $firebaseConfig.client | Where-Object {
  $_.client_info.android_client_info.package_name -eq 'com.lolys.medilink'
} | Select-Object -First 1
if (-not $androidClient) {
  throw "google-services.json ne contient pas le package Android com.lolys.medilink."
}

if ([string]::IsNullOrWhiteSpace($env:RELEASE_STORE_PASSWORD) -or
    [string]::IsNullOrWhiteSpace($env:RELEASE_KEY_PASSWORD)) {
  throw "Définissez RELEASE_STORE_PASSWORD et RELEASE_KEY_PASSWORD dans votre session PowerShell."
}
if ([string]::IsNullOrWhiteSpace($env:RELEASE_KEY_ALIAS)) {
  $env:RELEASE_KEY_ALIAS = 'medilink-release'
}
if ([string]::IsNullOrWhiteSpace($env:RELEASE_KEYSTORE_PATH)) {
  $env:RELEASE_KEYSTORE_PATH = Join-Path $PSScriptRoot 'android\app\release-key.jks'
}
if (-not (Test-Path $env:RELEASE_KEYSTORE_PATH)) {
  throw "Keystore introuvable : $env:RELEASE_KEYSTORE_PATH. Définissez RELEASE_KEYSTORE_PATH vers votre fichier .jks."
}

$apiUri = [Uri]$config.API_BASE_URL
if ($apiUri.Scheme -ne 'https') {
  Write-Warning "API_BASE_URL n'utilise pas HTTPS. Réservez cette configuration aux tests sur réseau local."
}
if ($apiUri.Host -in @('localhost', '127.0.0.1', '10.0.2.2')) {
  Write-Warning "Cette adresse API n'est pas accessible depuis un téléphone hors de votre environnement local. Les tokens FCM risquent de ne pas être enregistrés."
}

& $flutter.Source pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get a échoué.' }

& $flutter.Source build apk --release --dart-define-from-file=.env.json
if ($LASTEXITCODE -ne 0) { throw 'La compilation de l’APK Release a échoué.' }

$apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
  throw "Compilation terminée, mais APK introuvable : $apk"
}
Write-Host "APK Release générée : $apk" -ForegroundColor Green
