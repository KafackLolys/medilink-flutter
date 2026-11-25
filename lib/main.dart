import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/services/push_notification_service.dart';
import 'features/auth/application/demo_session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Erreur chargement .env : $e');
  }

  // Initialisation de Firebase et du service Push Novu / FCM
  try {
    if (kIsWeb) {
      final webApiKey = dotenv.env['FIREBASE_WEB_API_KEY']?.trim() ??
          const String.fromEnvironment('FIREBASE_WEB_API_KEY');
      final webAppId = dotenv.env['FIREBASE_WEB_APP_ID']?.trim() ??
          const String.fromEnvironment('FIREBASE_WEB_APP_ID');
      final webSenderId =
          dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID']?.trim() ??
              const String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
      final webProjectId = dotenv.env['FIREBASE_WEB_PROJECT_ID']?.trim() ??
          const String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
      final webAuthDomain = dotenv.env['FIREBASE_WEB_AUTH_DOMAIN']?.trim() ??
          const String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');

      if (webApiKey.isNotEmpty &&
          webAppId.isNotEmpty &&
          webSenderId.isNotEmpty &&
          webProjectId.isNotEmpty &&
          webAuthDomain.isNotEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: webApiKey,
            appId: webAppId,
            messagingSenderId: webSenderId,
            projectId: webProjectId,
            authDomain: webAuthDomain,
          ),
        );
        await PushNotificationService.instance.initialize();
      } else {
        PushNotificationService.instance.configurationError(
          'Firebase Web non configuré (clés FIREBASE_WEB_* manquantes).',
        );
      }
    } else {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);
      await PushNotificationService.instance.initialize();
    }
  } catch (error) {
    PushNotificationService.instance.configurationError(
      'Firebase non configuré : $error',
    );
    debugPrint('Firebase init error : $error');
  }

  runApp(MedLinkApp(auth: DemoSessionController()));
}
