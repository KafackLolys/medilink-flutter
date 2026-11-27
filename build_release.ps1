$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

# ── Charger les credentials de signature depuis .env s'il existe ─────────────
# (.env est ignoré par Git, voir .gitignore. Les valeurs proviennent de .env.data / release-key.jks)
$envFilePath = Join-Path $PSScriptRoot '.env'
if (Test-Path $envFilePath) {
  Get-Content $envFilePath | ForEach-Object {
    $line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { return }
    if ($line -match '^([^=]+)=(.*)$') {
      $name  = $matches[1].Trim()
      $value = $matches[2].Trim()
      # Ne pas écraser une variable d'environnement déjà définie explicitement
      $current = [Environment]::GetEnvironmentVariable($name)
      if (-not [string]::IsNullOrWhiteSpace($current)) { continue }
      [Environment]::SetEnvironmentVariable($name, $value)
    }
  }
}

Write-Host "[DEBUG] build_release.ps1 démarré depuis $PSScriptRoot" -ForegroundColor Cyan
$flutter = Get-Command flutter -ErrorAction Stop
Write-Host "[DEBUG] flutter trouvé : $($flutter.Source)" -ForegroundColor Cyan
$envFile = Join-Path $PSScriptRoot '.env.json'
if (-not (Test-Path $envFile)) {
  throw "Fichier .env.json absent. Créez-le depuis .env.example.json et renseignez API_BASE_URL."
}

$config = Get-Content -Raw $envFile | ConvertFrom-Json
Write-Host "[DEBUG] .env.json lu, API_BASE_URL = $($config.API_BASE_URL)" -ForegroundColor Cyan
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
Write-Host "[DEBUG] flutter pub get terminé" -ForegroundColor Cyan

Write-Host "[DEBUG] lancement de flutter build apk --release ..." -ForegroundColor Cyan
& $flutter.Source build apk --release --dart-define-from-file=.env.json
if ($LASTEXITCODE -ne 0) { throw 'La compilation de l’APK Release a échoué.' }
Write-Host "[DEBUG] flutter build apk terminé" -ForegroundColor Cyan

$apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
  throw "Compilation terminée, mais APK introuvable : $apk"
}
Write-Host "APK Release générée : $apk" -ForegroundColor Green
