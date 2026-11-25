# MedLink Flutter

Application Flutter MedLink pour patients et médecins. L’authentification et les données métier passent par le backend MedLink et ses routes **`/v2`** (par exemple `auth/v2/login`, `doctors/v2`, `needs/v2`). Aucun compte ni enregistrement de démonstration n’est créé localement.

L'intégration API s'inspire de `medilink-mobile` (React Native) : même découpage par ressource, mais tous les appels utilisent le préfixe `v2` et sont regroupés dans `lib/core/api/medilink_api.dart` (client `MedilinkApi` singleton avec gestion de session, refresh automatique du token à la réception d'un 401 et envoi multipart).

## Prérequis

- Flutter stable 3.44+ (the local-notifications plugin requires this baseline)
- Android 17 Preview SDK (API 37) and the latest Android SDK Build-Tools 37.x, installed from the SDK Manager preview channel

## Lancement

```sh
flutter pub get
.\run_bluestacks_debug.ps1
```

## Connexion à l'API v2

Le client reçoit `API_BASE_URL` et `GOOGLE_CLIENT_ID` comme constantes de compilation avec `--dart-define-from-file=.env.json`. Le fichier local `.env.json` n'est pas versionné : créez-le à partir du modèle suivi `.env.example.json` :

```powershell
Copy-Item .env.example.json .env.json
```

Le modèle contient l'identifiant OAuth Web associé au projet Android Firebase `medilink-2027`, ainsi que les valeurs Firebase Web communes récupérées depuis la configuration Android. Pour activer Firebase Web/FCM, renseignez aussi `FIREBASE_WEB_APP_ID` et `FIREBASE_WEB_VAPID_KEY` depuis Firebase Console > Paramètres du projet > application Web / Cloud Messaging. Les cinq valeurs du service worker `web/firebase-messaging-sw.js` doivent provenir du même projet Firebase.

Pour `API_BASE_URL` : utilisez `http://10.0.2.2:3000` depuis l'émulateur Android standard (accès au PC hôte), `http://localhost:3000` depuis Chrome sur le PC, ou l'adresse IPv4 locale du PC si BlueStacks ne route pas via `10.0.2.2`. N'utilisez pas `localhost` depuis Android pour joindre le backend du PC.

La configuration debug BlueStacks et celle de VS Code passent toutes deux le fichier local `.env.json` à Flutter. Une session ne peut être ouverte que si le serveur renvoie un jeton valide et un compte utilisateur :

Sans API configurée ou joignable, la connexion, l’inscription et les actions serveur affichent une erreur. Les listes démarrent vides et sont alimentées par les réponses API. Consultez [BLUESTACKS.md](BLUESTACKS.md) pour le routage de l’API locale depuis BlueStacks.

## Organisation du code

- `lib/main.dart` lance l'application.
- `lib/app.dart` configure l'application et le thème.
- `lib/core/api/medilink_api.dart` client HTTP `MedilinkApi` : routes préfixées `/v2`, session, refresh token, gestion d'erreurs et envoi multipart.
- `lib/core/data/live_state.dart` caches de session alimentés par les réponses API.
- `lib/core/theme/` et `lib/core/widgets/` thème et composants partagés.
- `lib/features/` écrans par domaine : authentification, accueil, annuaire des médecins, besoins et propositions, messagerie, notifications et rendez-vous.

## Notifications Android et messagerie

Les notifications de nouveaux messages utilisent un payload FCM data-only sur Android afin que MediLink puisse afficher une notification locale avec les actions natives :

- **Répondre** : envoie le texte saisi depuis la notification vers `POST /messages/v2/conversations/:id`.
- **Marquer comme lu** : met à jour les messages reçus via `PATCH /messages/v2/conversations/:id/read` et la notification associée.
- **Ouvrir** : ouvre directement la conversation dans l'application.
- Le style Android étendu affiche le contenu du message ; l'aperçu est masqué sur l'écran verrouillé lorsque le système respecte la visibilité privée.

Le token FCM de l'appareil est enregistré sur `POST /notifications/v2/devices` après authentification et supprimé à la déconnexion. Aucune clé secrète Novu ne doit être embarquée dans l'application mobile : les déclenchements Novu doivent rester côté serveur.

Pour tester sur un appareil Android réel :
1. Connectez-vous avec un compte patient ou médecin et autorisez les notifications.
2. Envoyez un message depuis l'autre compte.
3. Testez la notification en premier plan, en arrière-plan puis après fermeture de l'application.
4. Vérifiez les actions Répondre et Marquer comme lu, puis ouvrez la conversation.
5. Contrôlez que la réponse apparaît dans la messagerie et que le compteur de messages non lus diminue.

Les actions rapides nécessitent une nouvelle compilation Android (elles reposent sur le manifeste et les composants natifs).
