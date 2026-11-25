import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

/// Handler exécuté en arrière-plan sous Android dans un Isolate séparé.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Si le message est "data-only", afficher manuellement la notification locale.
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title']?.toString() ?? 'Notification MedLink';
    final body = message.data['body']?.toString() ?? '';
    final local = FlutterLocalNotificationsPlugin();
    await local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await local.show(
      message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medilink_notifications',
          'Notifications MedLink',
          channelDescription:
              'Notifications envoyées depuis Novu et Firebase FCM',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

class PushNotificationService extends ChangeNotifier {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  static const channel = AndroidNotificationChannel(
    'medilink_notifications',
    'Notifications MedLink',
    description: 'Notifications envoyées depuis Novu et Firebase FCM',
    importance: Importance.high,
  );

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final List<RemoteMessage> messages = [];
  RemoteMessage? latestForegroundMessage;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;

  String? token;
  String? error;
  bool initialized = false;
  bool registeredWithBackend = false;
  bool triggeringTest = false;

  // Clés configurées via .env ou --dart-define
  static String get registerEndpoint =>
      dotenv.env['PUSH_REGISTER_URL']?.trim() ??
      const String.fromEnvironment(
        'PUSH_REGISTER_URL',
        defaultValue: 'https://all-test-backend.vercel.app/push/register',
      );

  static String get subscriberId =>
      dotenv.env['NOVU_SUBSCRIBER_ID']?.trim() ??
      const String.fromEnvironment(
        'NOVU_SUBSCRIBER_ID',
        defaultValue: 'flutter-test-001',
      );

  static String get workflowId =>
      dotenv.env['NOVU_WORKFLOW_ID']?.trim() ??
      const String.fromEnvironment(
        'NOVU_WORKFLOW_ID',
        defaultValue: 'medilink-workflow',
      );

  static String get novuApiBaseUrl =>
      dotenv.env['NOVU_API_BASE_URL']?.trim() ??
      const String.fromEnvironment(
        'NOVU_API_BASE_URL',
        defaultValue: 'https://notify.zenithis.tech/api',
      );

  static String get novuSecretKey =>
      dotenv.env['NOVU_SECRET_KEY']?.trim() ??
      const String.fromEnvironment(
        'NOVU_SECRET_KEY',
        defaultValue: '937fe808b2a874b5d43fbec994e35f1e',
      );

  static String get novuIntegrationIdentifier =>
      dotenv.env['NOVU_FCM_INTEGRATION_IDENTIFIER']?.trim() ??
      const String.fromEnvironment(
        'NOVU_FCM_INTEGRATION_IDENTIFIER',
        defaultValue: 'firebase-cloud-messaging-medilink',
      );

  static String get webVapidKey =>
      dotenv.env['FIREBASE_WEB_VAPID_KEY']?.trim() ??
      const String.fromEnvironment(
        'FIREBASE_WEB_VAPID_KEY',
        defaultValue:
            'BMmSSkAMG94WpXsMbfbWM_ST2L46xx-AgPxnoc-9jGUJa-bwlyNtYVQehmDr5y4GbK4QwYaRcNCDOTJdADmwNo0',
      );

  void configurationError(String message) {
    error = message;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (initialized) return;

    if (kIsWeb && webVapidKey.isEmpty) {
      configurationError('Clé VAPID manquante : FIREBASE_WEB_VAPID_KEY.');
      return;
    }

    try {
      if (!kIsWeb) {
        await _local.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );

        final androidImplementation = _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        // Créer le canal de notification avec haute importance
        await androidImplementation?.createNotificationChannel(channel);

        // Demande explicite de permission d'affichage sur Android 13+ (POST_NOTIFICATIONS)
        await androidImplementation?.requestNotificationsPermission();

        // Demande de permission FCM
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      token = await _messaging.getToken(
        vapidKey: kIsWeb && webVapidKey.isNotEmpty ? webVapidKey : null,
      );

      _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
        token = newToken;
        registeredWithBackend = false;
        notifyListeners();
        await _registerToken();
      });

      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen((message) async {
        _addMessage(message);
        latestForegroundMessage = message;
        notifyListeners();

        final title =
            message.notification?.title ?? message.data['title']?.toString();
        final body =
            message.notification?.body ?? message.data['body']?.toString();

        if (defaultTargetPlatform == TargetPlatform.android &&
            (title != null || body != null)) {
          await _local.show(
            message.messageId?.hashCode ??
                DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title ?? 'MedLink',
            body ?? '',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'medilink_notifications',
                'Notifications MedLink',
                channelDescription:
                    'Notifications envoyées depuis Novu et Firebase FCM',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      });

      _openedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_addMessage);
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _addMessage(initialMessage);

      initialized = true;
      error = null;
      notifyListeners();

      await _registerToken();
    } catch (exception) {
      error = 'Initialisation FCM impossible : $exception';
      notifyListeners();
    }
  }

  void _addMessage(RemoteMessage message) {
    if (messages.any(
        (item) => item.messageId != null && item.messageId == message.messageId)) {
      return;
    }
    messages.insert(0, message);
    notifyListeners();
  }

  /// Enregistre le token auprès de Novu via le serveur bridge ou directement via l'API Novu.
  Future<void> _registerToken() async {
    registeredWithBackend = false;
    if (token == null || token!.isEmpty) {
      error = 'Token FCM indisponible. Initialisez FCM avant de vous enregistrer.';
      notifyListeners();
      return;
    }

    final currentSubId = subscriberId;
    if (currentSubId.isEmpty) {
      error = 'Identifiant subscriber Novu non renseigné (NOVU_SUBSCRIBER_ID).';
      notifyListeners();
      return;
    }

    // 1. Essai d'enregistrement via le endpoint backend configuré
    bool endpointSuccess = false;
    if (registerEndpoint.isNotEmpty) {
      try {
        final uri = Uri.parse(registerEndpoint);
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'subscriberId': currentSubId,
                'providerId': 'fcm',
                'token': token,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          endpointSuccess = true;
        }
      } catch (_) {
        // En cas d'échec du bridge distant, on bascule vers l'enregistrement direct Novu
      }
    }

    // 2. Si le endpoint bridge n'a pas répondu ou si la clé Novu est présente, enregistrer directement chez Novu
    if (!endpointSuccess && novuSecretKey.isNotEmpty && novuApiBaseUrl.isNotEmpty) {
      try {
        final base = novuApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'ApiKey $novuSecretKey',
        };

        // Créer ou s'assurer que le subscriber existe
        try {
          await http
              .post(
                Uri.parse('$base/v1/subscribers'),
                headers: headers,
                body: jsonEncode({'subscriberId': currentSubId}),
              )
              .timeout(const Duration(seconds: 10));
        } catch (_) {}

        // Enregistrer le device token FCM pour ce subscriber
        final credUri = Uri.parse(
          '$base/v1/subscribers/${Uri.encodeComponent(currentSubId)}/credentials',
        );
        final credBody = <String, dynamic>{
          'providerId': 'fcm',
          'credentials': {
            'deviceTokens': [token],
          },
        };
        if (novuIntegrationIdentifier.isNotEmpty) {
          credBody['integrationIdentifier'] = novuIntegrationIdentifier;
        }

        final credRes = await http
            .put(
              credUri,
              headers: headers,
              body: jsonEncode(credBody),
            )
            .timeout(const Duration(seconds: 12));

        if (credRes.statusCode >= 200 && credRes.statusCode < 300) {
          endpointSuccess = true;
        } else {
          error = 'Novu HTTP ${credRes.statusCode} : ${credRes.body}';
        }
      } catch (e) {
        error = 'Enregistrement Novu direct impossible : $e';
      }
    }

    if (endpointSuccess) {
      registeredWithBackend = true;
      error = null;
    } else if (error == null) {
      error = 'Impossible d\'enregistrer le token auprès de Novu.';
    }
    notifyListeners();
  }

  /// Déclenche le workflow Novu spécifié (ex: `medilink-workflow`) pour tester la réception push.
  Future<bool> triggerTestPush({
    String? title,
    String? body,
    Map<String, dynamic>? customPayload,
  }) async {
    if (novuSecretKey.isEmpty || novuApiBaseUrl.isEmpty) {
      error = 'Clé secrète Novu manquante pour le déclenchement du test.';
      notifyListeners();
      return false;
    }

    triggeringTest = true;
    notifyListeners();

    try {
      final base = novuApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
      final eventUri = Uri.parse('$base/v1/events/trigger');
      final eventPayload = {
        'name': workflowId,
        'to': [subscriberId],
        'payload': {
          'title': title ?? 'MedLink · Notification Novu',
          'body': body ??
              'Test push réussi avec le workflow $workflowId !',
          ...?customPayload,
        },
      };

      final response = await http
          .post(
            eventUri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'ApiKey $novuSecretKey',
            },
            body: jsonEncode(eventPayload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        error = null;
        return true;
      } else {
        error = 'Échec déclenchement Novu (${response.statusCode}) : ${response.body}';
        return false;
      }
    } catch (e) {
      error = 'Erreur déclenchement Novu : $e';
      return false;
    } finally {
      triggeringTest = false;
      notifyListeners();
    }
  }

  Future<void> retryRegistration() => _registerToken();

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }
}
