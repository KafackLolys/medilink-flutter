# Novu FCM Android: notifications avec icônes MediLink par catégorie

Flutter contient les ressources Android suivantes :

- `ic_stat_message` : nouveau message
- `ic_stat_proposal` : proposition reçue ou acceptée
- `ic_stat_appointment` : rendez-vous mis à jour
- `ic_stat_appointment_cancelled` : rendez-vous annulé ou refusé
- `ic_stat_need` : besoin médical pertinent
- `ic_stat_reminder` : rappel
- `ic_stat_medilink` : icône de repli

Le code Flutter affiche ces petites icônes via `flutter_local_notifications`.
Pour que cela fonctionne lorsque l'application est en arrière-plan ou arrêtée,
le message FCM Android doit être **data-only**.

## Configuration obligatoire du workflow Novu

Dans le workflow `medilink-workflow`, ouvrir l'étape Firebase Cloud Messaging
(`firebase-cloud-messaging-medilink`) et configurer l'envoi Android ainsi :

1. Ne pas renseigner le bloc FCM **Notification** (titre/corps). Sa présence
   fait afficher directement par Android une notification avec l'icône par
   défaut, sans laisser Flutter choisir l'icône métier.
2. Renseigner uniquement les données FCM personnalisées (toutes les valeurs
   doivent être des chaînes) :

   - `notificationId` = `{{payload.notificationId}}`
   - `type` = `{{payload.type}}`
   - `title` = `{{payload.title}}`
   - `body` = `{{payload.body}}`
   - `targetUrl` = `{{payload.targetUrl}}`
   - `conversationId` = `{{payload.conversationId}}` (si présent)

3. Conserver une priorité Android élevée (`high`).
4. Enregistrer et publier le workflow.

Le client Flutter a été renforcé pour lire le type à la racine ou dans un objet
`data` imbriqué. Il choisit ensuite l'icône locale correspondante. Si le
workflow continue d'envoyer un bloc FCM Notification, Android contournera
toujours ce mécanisme lorsque l'application est en arrière-plan.

## Vérification

Tester séparément :
- application ouverte : une seule notification locale avec l'icône métier ;
- application en arrière-plan : une seule notification avec l'icône métier ;
- application arrêtée : une seule notification avec l'icône métier.

Après modification du workflow, reconstruire et réinstaller l'APK Release.
