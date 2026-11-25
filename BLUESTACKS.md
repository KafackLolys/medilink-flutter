# Tester MedLink sur BlueStacks

## Préparer Android

La plateforme Android est maintenant présente dans le projet. Si elle doit être régénérée :

```powershell
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
flutter create --platforms=android --org com.medilink .
```

Cette commande crée le dossier `android/` en conservant le code Flutter existant. Elle ne copie pas la configuration Firebase de `learn_flutter`, car MedLink n'utilise pas Firebase pour son API.

## Lancer en debug avec le serveur réel

MedLink n’accepte plus de compte local et n’affiche plus d’enregistrements de démonstration. Démarrez d’abord l’API depuis `E:\Projet\Lolys\Test-IA\medilink-api` avec `npm run start:dev`. Le port configuré est `3000`. Activez ensuite ADB dans BlueStacks, sur le port `5555` détecté ici :

```powershell
.\run_bluestacks_debug.ps1
```

`10.0.2.2` désigne le PC hôte depuis l’émulateur Android. Si ce routage n’est pas disponible dans votre installation BlueStacks, remplacez cette adresse par l’adresse IPv4 du PC sur le réseau local. Le backend doit écouter sur une interface accessible et le pare-feu Windows doit autoriser son port.

Vous pouvez aussi lancer la configuration **MedLink · BlueStacks debug** depuis VS Code. L’application charge ses paramètres depuis l’asset `.env.json` au démarrage.

## Pointer vers une API locale

Pour une autre adresse de serveur, modifiez `API_BASE_URL` dans `.env.json`. Dans l’application, `localhost` et `127.0.0.1` désignent BlueStacks lui-même : ne les utilisez pas pour joindre le serveur du PC.

```powershell
flutter run -d <identifiant-appareil>
```
exemple: ```flutter run -d emulator-5554 --dart-define-from-file=.env.json```

Le trafic HTTP non chiffré est autorisé uniquement dans la configuration Android de débogage pour les essais locaux. Les versions release restent en HTTPS.

## Google Sign-In sur Android

Le code `ApiException: 10` signifie que l’identifiant OAuth Android ne correspond pas à l’application installée. Le package utilisé est `com.lolys.medilink`. Pour BlueStacks en mode debug, le certificat actuel a le SHA-1 `FB:32:90:3E:E4:6E:82:22:2F:82:F9:A8:D3:D7:C5:3F:53:F2:F3:D9`.

Dans les paramètres du projet Firebase, ajoutez ce SHA-1 à l’application Android `com.lolys.medilink`, vérifiez que le fournisseur **Google** est activé sous Authentication > Sign-in method, puis téléchargez à nouveau le fichier `google-services.json` et remplacez `android/app/google-services.json`. Pour une version release, ajoutez également le SHA-1 de son certificat de signature. L’identifiant client Web déjà fourni dans `.env.json` correspond au client Web du fichier Firebase actuel. Le fichier Firebase présent ne contient pas de client OAuth Android ; le nouveau doit inclure le package et l’empreinte ci-dessus.
