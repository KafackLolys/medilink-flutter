import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_environment.dart';
import 'core/services/push_notification_service.dart';
import 'features/auth/application/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      final apiKey = AppEnvironment.firebaseWebApiKey;
      final appId = AppEnvironment.firebaseWebAppId;
      final senderId = AppEnvironment.firebaseWebMessagingSenderId;
      final projectId = AppEnvironment.firebaseWebProjectId;
      final authDomain = AppEnvironment.firebaseWebAuthDomain;

      if (apiKey.isNotEmpty &&
          appId.isNotEmpty &&
          senderId.isNotEmpty &&
          projectId.isNotEmpty &&
          authDomain.isNotEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: apiKey,
            appId: appId,
            messagingSenderId: senderId,
            projectId: projectId,
            authDomain: authDomain,
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
        firebaseMessagingBackgroundHandler,
      );
      await PushNotificationService.instance.initialize();
    }
  } catch (error) {
    PushNotificationService.instance.configurationError(
      'Firebase non configuré : $error',
    );
    debugPrint('Firebase init error : $error');
  }

  final auth = AuthController();
  await auth.initialize();
  runApp(MedLinkApp(auth: auth));
}
