import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../api/medilink_api.dart';
import '../config/app_environment.dart';

const _notificationChannel = AndroidNotificationChannel(
  'medilink_notifications',
  'Notifications MediLink',
  description: 'Messages et notifications de votre compte MediLink',
  importance: Importance.high,
);

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

const _sessionStorageKey = 'medilink_auth_session';
const _deviceStorageKey = 'medilink_notification_device_id';

/// Affiche les messages data-only reçus lorsque Android exécute l'application
/// dans un isolate de fond.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (defaultTargetPlatform != TargetPlatform.android) return;

  final local = FlutterLocalNotificationsPlugin();
  await _initializeLocalNotifications(
    local,
    onResponse: notificationTapForeground,
    onBackgroundResponse: notificationActionBackgroundHandler,
  );
  await _showRemoteNotification(message, local);
}

Future<void> _initializeLocalNotifications(
  FlutterLocalNotificationsPlugin plugin, {
  required void Function(NotificationResponse) onResponse,
  required void Function(NotificationResponse) onBackgroundResponse,
}) async {
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_medilink'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: onResponse,
    onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
  );

  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(_notificationChannel);
}

int _stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

String _notificationIconForType(dynamic rawType) {
  final type = (rawType?.toString() ?? '').toLowerCase().replaceAll('-', '_');
  if (type.contains('message') || type.contains('chat')) {
    return 'ic_stat_message';
  }
  if (type.contains('proposal') || type.contains('offer')) {
    return 'ic_stat_proposal';
  }
  if (type.contains('appointment') ||
      type.contains('rendez_vous') ||
      type.contains('rendezvous')) {
    if (type.contains('cancel') || type.contains('reject')) {
      return 'ic_stat_appointment_cancelled';
    }
    return 'ic_stat_appointment';
  }
  if (type.contains('need') || type.contains('besoin')) {
    return 'ic_stat_need';
  }
  if (type.contains('reminder') || type.contains('rappel')) {
    return 'ic_stat_reminder';
  }
  return 'ic_stat_medilink';
}

Future<void> _showRemoteNotification(
  RemoteMessage message,
  FlutterLocalNotificationsPlugin plugin,
) async {
  final data = Map<String, dynamic>.from(message.data);
  final title = message.notification?.title ??
      data['title']?.toString() ??
      'Notification MediLink';
  final body = message.notification?.body ?? data['body']?.toString() ?? '';
  final conversationId = data['conversationId']?.toString();
  final notificationIcon = _notificationIconForType(data['type']);
  final isChat = data['type']?.toString() == 'new_message' &&
      conversationId != null &&
      conversationId.isNotEmpty;

  final payload = <String, dynamic>{
    ...data,
    'title': title,
    'body': body,
  };
  final notificationId = isChat
      ? _stableNotificationId('conversation:$conversationId')
      : (message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000);

  final actions = isChat
      ? <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'reply',
            'Répondre',
            inputs: <AndroidNotificationActionInput>[
              AndroidNotificationActionInput(label: 'Votre réponse'),
            ],
            showsUserInterface: false,
            cancelNotification: false,
            semanticAction: SemanticAction.reply,
          ),
          const AndroidNotificationAction(
            'mark_read',
            'Marquer comme lu',
            showsUserInterface: false,
            cancelNotification: false,
            semanticAction: SemanticAction.markAsRead,
          ),
          const AndroidNotificationAction(
            'open',
            'Ouvrir',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ]
      : const <AndroidNotificationAction>[];

  await plugin.show(
    id: notificationId,
    title: title,
    body: body,
    payload: jsonEncode(payload),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannel.id,
        _notificationChannel.name,
        channelDescription: _notificationChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: notificationIcon,
        category: isChat ? AndroidNotificationCategory.message : null,
        visibility: NotificationVisibility.private,
        onlyAlertOnce: true,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: isChat ? 'Message MediLink' : 'MediLink',
        ),
        actions: actions,
      ),
    ),
  );
}

Map<String, dynamic> _decodeNotificationPayload(String? raw) {
  if (raw == null || raw.isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  } on FormatException {
    return <String, dynamic>{};
  }
}

/// Traite les actions sans ouvrir l'interface, même si l'application est
/// arrêtée. Le jeton Firebase est relu depuis le stockage sécurisé.
@pragma('vm:entry-point')
void notificationActionBackgroundHandler(NotificationResponse response) {
  unawaited(_handleNotificationActionInBackground(response));
}

Future<http.Response> _authenticatedActionRequest({
  required String method,
  required String path,
  Object? body,
}) async {
  final base =
      AppEnvironment.apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  if (base.isEmpty) throw StateError('API_BASE_URL non configurée.');

  final saved = await _secureStorage.read(key: _sessionStorageKey);
  if (saved == null || saved.isEmpty) {
    throw StateError('Aucune session MediLink disponible.');
  }

  final decoded = jsonDecode(saved);
  if (decoded is! Map) throw StateError('Session MediLink invalide.');
  final session = Map<String, dynamic>.from(decoded);
  var idToken = session['idToken']?.toString() ?? '';
  final refreshToken = session['refreshToken']?.toString() ?? '';
  if (idToken.isEmpty) throw StateError('Jeton de session indisponible.');

  Future<http.Response> send(String token) {
    final uri = Uri.parse('$base/$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    return switch (method) {
      'POST' => http
          .post(uri, headers: headers, body: encodedBody)
          .timeout(const Duration(seconds: 12)),
      'PATCH' => http
          .patch(uri, headers: headers, body: encodedBody)
          .timeout(const Duration(seconds: 12)),
      _ => throw ArgumentError.value(method, 'method'),
    };
  }

  var response = await send(idToken);
  if (response.statusCode != 401 || refreshToken.isEmpty) return response;

  final refreshResponse = await http
      .post(
        Uri.parse('$base/auth/v2/refresh'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      )
      .timeout(const Duration(seconds: 12));

  if (refreshResponse.statusCode < 200 || refreshResponse.statusCode >= 300) {
    return response;
  }

  final refreshBody = jsonDecode(refreshResponse.body);
  if (refreshBody is! Map) return response;
  session.addAll(Map<String, dynamic>.from(refreshBody));
  idToken = session['idToken']?.toString() ?? '';
  if (idToken.isEmpty) return response;

  await _secureStorage.write(
    key: _sessionStorageKey,
    value: jsonEncode(session),
  );
  response = await send(idToken);
  return response;
}

Future<void> _handleNotificationActionInBackground(
  NotificationResponse response,
) async {
  final payload = _decodeNotificationPayload(response.payload);
  final conversationId = payload['conversationId']?.toString();
  final notificationId = payload['notificationId']?.toString();
  final actionId = response.actionId;

  if (conversationId == null || conversationId.isEmpty) return;

  try {
    if (actionId == 'reply') {
      final reply = response.input?.trim() ?? '';
      if (reply.isEmpty || reply.length > 4000) return;

      final sent = await _authenticatedActionRequest(
        method: 'POST',
        path:
            'messages/v2/conversations/${Uri.encodeComponent(conversationId)}',
        body: {'body': reply},
      );
      if (sent.statusCode < 200 || sent.statusCode >= 300) return;

      await _authenticatedActionRequest(
        method: 'PATCH',
        path:
            'messages/v2/conversations/${Uri.encodeComponent(conversationId)}/read',
        body: const {},
      );
    } else if (actionId == 'mark_read') {
      final marked = await _authenticatedActionRequest(
        method: 'PATCH',
        path:
            'messages/v2/conversations/${Uri.encodeComponent(conversationId)}/read',
        body: const {},
      );
      if (marked.statusCode < 200 || marked.statusCode >= 300) return;
    } else {
      return;
    }

    if (notificationId != null && notificationId.isNotEmpty) {
      await _authenticatedActionRequest(
        method: 'PATCH',
        path: 'notifications/v2/${Uri.encodeComponent(notificationId)}/read',
        body: const {},
      );
    }

    final local = FlutterLocalNotificationsPlugin();
    final localNotificationId =
        response.id ?? _stableNotificationId('conversation:$conversationId');
    await local.cancel(id: localNotificationId);
    PushNotificationService.instance.notificationActionCompleted();
  } catch (_) {
    // Keep the notification visible when the server action could not be
    // completed. The user can retry or open the conversation in MediLink.
  }
}

class PushNotificationService extends ChangeNotifier {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final List<RemoteMessage> messages = [];

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;

  String? token;
  String? error;
  RemoteMessage? latestForegroundMessage;
  String? _pendingConversationId;
  Map<String, dynamic>? _pendingNotificationData;
  bool initialized = false;
  bool registeredWithBackend = false;

  String get webVapidKey => AppEnvironment.firebaseWebVapidKey;

  void configurationError(String message) {
    error = message;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (initialized) return;

    try {
      if (!kIsWeb) {
        await _initializeLocalNotifications(
          _local,
          onResponse: notificationTapForeground,
          onBackgroundResponse: notificationActionBackgroundHandler,
        );

        final android = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final localPermission = await android?.requestNotificationsPermission();
        debugPrint(
          '[FCM] Android local notification permission: $localPermission',
        );

        final permission = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint(
          '[FCM] Firebase notification authorization: ${permission.authorizationStatus}',
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
      debugPrint(
          '[FCM] Registration token available: ${token?.isNotEmpty == true}');
      if (token != null && token!.isNotEmpty) {
        debugPrint('[FCM] Token value: ${token!.substring(0, 20)}...');
      }

      _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
        token = newToken;
        registeredWithBackend = false;
        notifyListeners();
        if (MedilinkApi.instance.isAuthenticated) {
          await _registerToken();
        }
      });

      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen((message) async {
        debugPrint(
          '[FCM] Foreground message received: id=${message.messageId}, '
          'type=${message.data['type']}, '
          'hasNotification=${message.notification != null}',
        );
        _addMessage(message);
        latestForegroundMessage = message;
        if (defaultTargetPlatform == TargetPlatform.android) {
          try {
            await _showRemoteNotification(message, _local);
            debugPrint('[FCM] Foreground local notification displayed.');
          } catch (exception, stackTrace) {
            debugPrint('[FCM] Foreground display failed: $exception');
            debugPrintStack(stackTrace: stackTrace);
          }
        }
        notifyListeners();
      });

      _openedSubscription = FirebaseMessaging.onMessageOpenedApp
          .listen(_handleRemoteMessageOpened);
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _handleRemoteMessageOpened(initialMessage);

      if (!kIsWeb) {
        final launchDetails = await _local.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true) {
          final payload = _decodeNotificationPayload(
            launchDetails?.notificationResponse?.payload,
          );
          _setPendingNotification(payload);
        }
      }

      initialized = true;
      error = null;
      notifyListeners();

      // Enregistrer le token FCM dès l'initialisation, même si l'utilisateur
      // n'est pas encore authentifié. Si aucune session n'est active, le
      // backend rejettera proprement et registerAuthenticatedDevice()
      // retentera après connexion.
      await _registerToken();
    } catch (exception) {
      error = 'Initialisation FCM impossible : $exception';
      notifyListeners();
    }
  }

  void _handleForegroundNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'reply' || response.actionId == 'mark_read') {
      unawaited(_handleNotificationActionInBackground(response));
      return;
    }
    final payload = _decodeNotificationPayload(response.payload);
    _setPendingNotification(payload);
  }

  void _handleRemoteMessageOpened(RemoteMessage message) {
    _addMessage(message);
    _setPendingNotification(Map<String, dynamic>.from(message.data));
  }

  void _setPendingNotification(Map<String, dynamic> data) {
    final conversationId = data['conversationId']?.toString();
    final targetUrl = (data['targetUrl'] ?? data['url'])?.toString();
    if ((conversationId == null || conversationId.isEmpty) &&
        (targetUrl == null || targetUrl.isEmpty)) {
      return;
    }
    _pendingNotificationData = <String, dynamic>{
      ...data,
      if (targetUrl != null) 'targetUrl': targetUrl,
    };
    _pendingConversationId = conversationId;
    notifyListeners();
  }

  Map<String, dynamic>? takePendingNotificationData() {
    final value = _pendingNotificationData;
    _pendingNotificationData = null;
    _pendingConversationId = null;
    return value;
  }

  String? takePendingConversationId() {
    final value = _pendingConversationId;
    _pendingConversationId = null;
    return value;
  }

  void _addMessage(RemoteMessage message) {
    if (messages.any((item) =>
        item.messageId != null && item.messageId == message.messageId)) {
      return;
    }
    messages.insert(0, message);
    notifyListeners();
  }

  /// Appelé après restauration ou ouverture d'une session MediLink.
  Future<void> registerAuthenticatedDevice() async {
    if (!MedilinkApi.instance.isAuthenticated) return;
    await _registerToken();
  }

  Future<String> _getDeviceId() async {
    final existing = await _secureStorage.read(key: _deviceStorageKey);
    if (existing != null &&
        RegExp(r'^[A-Za-z0-9_-]{16,100}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final id = List<int>.generate(24, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await _secureStorage.write(key: _deviceStorageKey, value: id);
    return id;
  }

  Future<void> _registerToken() async {
    if (!MedilinkApi.instance.isConfigured) {
      registeredWithBackend = false;
      return;
    }
    if (token == null || token!.isEmpty) {
      error = 'Token FCM indisponible sur cet appareil.';
      notifyListeners();
      return;
    }

    try {
      final deviceId = await _getDeviceId();
      debugPrint(
          '[FCM] Registering device: deviceId=$deviceId, token=${token!.substring(0, 20)}...');
      await MedilinkApi.instance.notificationRegisterDevice(
        deviceId: deviceId,
        token: token!,
        platform: kIsWeb ? 'web' : 'mobile',
      );
      registeredWithBackend = true;
      error = null;
      debugPrint(
          '[FCM] Device token successfully registered with MediLink API.');
    } catch (exception) {
      registeredWithBackend = false;
      error =
          'Enregistrement du token FCM auprès de Novu impossible : $exception';
      debugPrint('[FCM] Device registration failed: $exception');
    }
    notifyListeners();
  }

  Future<void> unregisterAuthenticatedDevice() async {
    if (!MedilinkApi.instance.isAuthenticated) {
      registeredWithBackend = false;
      return;
    }
    try {
      final deviceId = await _secureStorage.read(key: _deviceStorageKey);
      if (deviceId != null && deviceId.isNotEmpty) {
        await MedilinkApi.instance.notificationUnregisterDevice(deviceId);
      }
    } catch (_) {
      // The local session is still cleared by AuthController on logout.
    } finally {
      registeredWithBackend = false;
      notifyListeners();
    }
  }

  Future<void> retryRegistration() => registerAuthenticatedDevice();

  void clearRegistrationState() {
    registeredWithBackend = false;
    notifyListeners();
  }

  void notificationActionCompleted() {
    notifyListeners();
  }

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }
}

/// Réponse utilisateur quand l'application est déjà ouverte ou lorsqu'une
/// notification locale a été utilisée pour ouvrir l'application.
void notificationTapForeground(NotificationResponse response) {
  PushNotificationService.instance._handleForegroundNotificationResponse(
    response,
  );
}
