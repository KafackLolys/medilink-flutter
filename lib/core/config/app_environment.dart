/// Build-time configuration supplied through --dart-define-from-file=.env.json.
class AppEnvironment {
  AppEnvironment._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  static const String firebaseWebApiKey =
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
}
