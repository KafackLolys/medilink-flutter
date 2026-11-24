# MedLink Flutter

Application Flutter autonome pour les patients et les médecins de MedLink. Ce dépôt est indépendant du frontend web et communique avec l'API NestJS MedLink.

## Prérequis
- Flutter stable / Dart 3.4+
- API MedLink configurée avec Firebase

## Lancement
```sh
flutter create --platforms=android,ios .
flutter pub get
flutter run --dart-define=API_BASE_URL=https://votre-api.example.com
```
Émulateur Android local : `http://10.0.2.2:3000`. Simulateur iOS : `http://127.0.0.1:3000`.

## Parcours de cette première version
- Inscription et connexion patient/médecin
- Session dans le stockage sécurisé; appels Bearer à l'API
- Annuaire des médecins recommandés
- Besoins médicaux patient et propositions médecin
- Rendez-vous patient/médecin et acceptation des propositions
- Déconnexion avec révocation côté API

Les comptes administrateur ne sont pas créés depuis l'app. Les jetons sont stockés avec `flutter_secure_storage`. Les règles d'accès aux données restent appliquées par l'API.
