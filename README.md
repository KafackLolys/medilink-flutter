# MedLink Flutter

Application Flutter MedLink pour patients et médecins. Elle fonctionne par défaut en **mode démonstration** (données locales, aucune requête API) et peut être connectée au backend Medilink dont les routes sont préfixées **`/v2`** (par exemple `auth/v2/login`, `doctors/v2`, `needs/v2`).

L'intégration API s'inspire de `medilink-mobile` (React Native) : même découpage par ressource, mais tous les appels utilisent le préfixe `v2` et sont regroupés dans `lib/core/api/medilink_api.dart` (client `MedilinkApi` singleton avec gestion de session, refresh automatique du token à la réception d'un 401 et envoi multipart).

## Prérequis

- Flutter stable / Dart 3.4+

## Lancement (démonstration)

```sh
flutter pub get
flutter run
```

## Connexion à l'API v2

Le client lit l'URL de base depuis la constante d'environnement `API_BASE_URL`. Passez-la au lancement :

```sh
flutter run --dart-define=API_BASE_URL=https://api.medilink.app
```

Quand `API_BASE_URL` est configurée, les écrans appellent les endpoints réels (rendez-vous, médecins, besoins, messagerie, notifications, disponibilités, admin, intégrations). Dans le cas contraire, ils basculent sur les données de démonstration de `lib/core/data/demo_data.dart`.

## Organisation du code

- `lib/main.dart` lance l'application.
- `lib/app.dart` configure l'application et le thème.
- `lib/core/api/medilink_api.dart` client HTTP `MedilinkApi` : routes préfixées `/v2`, session, refresh token, gestion d'erreurs et envoi multipart.
- `lib/core/data/demo_data.dart` données de démonstration (formes de réponse backend).
- `lib/core/theme/` et `lib/core/widgets/` thème et composants partagés.
- `lib/features/` écrans par domaine : authentification, accueil, annuaire des médecins, besoins et propositions, messagerie, notifications et rendez-vous.

Les données fictives demeurent simulées en mémoire en mode démo : aucune modification n'est persistée après fermeture de l'application.
