/// Build-time configuration supplied from the single `.env.json` source file.
class AppEnvironment {
  AppEnvironment._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID');

  static const String firebaseWebApiApiKey =
      String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const String firebaseWebAppId =
      String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const String firebaseWebMessagingSenderId =
      String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
  static const String firebaseWebProjectId =
      String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
  static const String firebaseWebAuthDomain =
      String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
  static const String firebaseWebVapidKey =
      String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  static const String pushRegisterUrl = String.fromEnvironment(
    'PUSH_REGISTER_URL',
    defaultValue: 'https://all-test-backend.vercel.app/push/register',
  );
  static const String novuSubscriberId = String.fromEnvironment(
    'NOVU_SUBSCRIBER_ID',
    defaultValue: 'flutter-test-001',
  );
  static const String novuWorkflowId = String.fromEnvironment(
    'NOVU_WORKFLOW_ID',
    defaultValue: 'medilink-workflow',
  );
  static const String novuApiBaseUrl = String.fromEnvironment(
    'NOVU_API_BASE_URL',
    defaultValue: 'https://notify.zenithis.tech/api',
  );
  static const String novuSecretKey = String.fromEnvironment(
    'NOVU_SECRET_KEY',
    defaultValue: '937fe808b2a874b5d43fbec994e35f1e',
  );
  static const String novuFcmIntegrationIdentifier = String.fromEnvironment(
    'NOVU_FCM_INTEGRATION_IDENTIFIER',
    defaultValue: 'firebase-cloud-messaging-medilink',
  );
}
