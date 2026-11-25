# MedLink Flutter

Application Flutter MedLink pour patients et médecins. L’authentification et les données métier passent par le backend MedLink et ses routes **`/v2`** (par exemple `auth/v2/login`, `doctors/v2`, `needs/v2`). Aucun compte ni enregistrement de démonstration n’est créé localement.

L'intégration API s'inspire de `medilink-mobile` (React Native) : même découpage par ressource, mais tous les appels utilisent le préfixe `v2` et sont regroupés dans `lib/core/api/medilink_api.dart` (client `MedilinkApi` singleton avec gestion de session, refresh automatique du token à la réception d'un 401 et envoi multipart).

## Prérequis

- Flutter stable / Dart 3.4+

## Lancement

```sh
flutter pub get
.\run_bluestacks_debug.ps1
```

## Connexion à l'API v2

Le client reçoit `API_BASE_URL` et `GOOGLE_CLIENT_ID` comme constantes de compilation avec `--dart-define-from-file=.env.json`. Ce fichier est l’unique source de configuration : modifiez-le pour changer les valeurs et conservez cette option à chaque lancement. Une session ne peut être ouverte que si le serveur renvoie un jeton valide et un compte utilisateur :

La configuration debug BlueStacks et celle de VS Code passent toutes deux ce même fichier à Flutter.

Sans API configurée ou joignable, la connexion, l’inscription et les actions serveur affichent une erreur. Les listes démarrent vides et sont alimentées par les réponses API. Consultez [BLUESTACKS.md](BLUESTACKS.md) pour le routage de l’API locale depuis BlueStacks.

## Organisation du code

- `lib/main.dart` lance l'application.
- `lib/app.dart` configure l'application et le thème.
- `lib/core/api/medilink_api.dart` client HTTP `MedilinkApi` : routes préfixées `/v2`, session, refresh token, gestion d'erreurs et envoi multipart.
- `lib/core/data/live_state.dart` caches de session alimentés par les réponses API.
- `lib/core/theme/` et `lib/core/widgets/` thème et composants partagés.
- `lib/features/` écrans par domaine : authentification, accueil, annuaire des médecins, besoins et propositions, messagerie, notifications et rendez-vous.
