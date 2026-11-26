import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_environment.dart';

/// HTTP client for the API's copied V2 routes (for example `/auth/v2/login`).
/// Base URL is read at startup from the bundled `.env.json` file.
class MedilinkApi {
  MedilinkApi._();

  static final MedilinkApi instance = MedilinkApi._();
  static String get _apiBaseUrl => AppEnvironment.apiBaseUrl.trim();
  static const String _sessionStorageKey = 'medilink_auth_session';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final http.Client _http = http.Client();
  String? _idToken;
  String? _refreshToken;
  String? _userId;
  void Function()? onSessionExpired;

  bool get isConfigured => _apiBaseUrl.trim().isNotEmpty;
  bool get isAuthenticated => _idToken?.isNotEmpty == true;
  String? get userId => _userId;
  String? get idToken => _idToken;

  Future<void> setSession(Map<String, dynamic> session) async {
    _applySession(session);
    await _persistSession(session);
  }

  void _applySession(Map<String, dynamic> session) {
    _idToken = session['idToken']?.toString();
    _refreshToken = session['refreshToken']?.toString();
    final user = session['user'];
    _userId = user is Map ? user['id']?.toString() : null;
  }

  Future<Map<String, dynamic>?> restoreSession() async {
    final saved = await _secureStorage.read(key: _sessionStorageKey);
    if (saved == null || saved.isEmpty) return null;

    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map) return null;
      final session = Map<String, dynamic>.from(decoded);
      final user = session['user'];
      if (session['idToken']?.toString().isNotEmpty != true ||
          user is! Map ||
          user['id'] == null) {
        await clearSession();
        return null;
      }
      _applySession(session);
      return session;
    } on FormatException {
      await clearSession();
      return null;
    }
  }

  Future<void> _persistSession(Map<String, dynamic> session) async {
    try {
      await _secureStorage.write(
        key: _sessionStorageKey,
        value: jsonEncode(session),
      );
    } catch (_) {
      throw const MedilinkApiException(
        'Impossible de conserver la session de façon sécurisée sur cet appareil.',
      );
    }
  }

  Future<void> clearSession() async {
    _idToken = null;
    _refreshToken = null;
    _userId = null;
    try {
      await _secureStorage.delete(key: _sessionStorageKey);
    } catch (_) {
      // Always clear the in-memory session, even when secure storage fails.
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async =>
      _asMap(await post(
          'auth/v2/login',
          {
            'email': email,
            'password': password,
          },
          authenticated: false));

  Future<Map<String, dynamic>> register(Map<String, dynamic> values) async =>
      _asMap(await post('auth/v2/register', values, authenticated: false));

  Future<Map<String, dynamic>> profile() async =>
      _asMap(await get('auth/v2/profile'));

  Future<void> logout() async {
    try {
      if (isAuthenticated) await post('auth/v2/logout', const {});
    } finally {
      await clearSession();
    }
  }

  /// Renouvelle le token d'accès à partir du refresh token.
  /// Retourne la nouvelle session (idToken, refreshToken, user).
  Future<Map<String, dynamic>> refresh(String refreshToken) async =>
      _asMap(await post(
          'auth/v2/refresh',
          {
            'refreshToken': refreshToken,
          },
          authenticated: false));

  /// Demande une réinitialisation de mot de passe.
  Future<Map<String, dynamic>> resetPassword(String email) async =>
      _asMap(await post(
          'auth/v2/reset-password',
          {
            'email': email,
          },
          authenticated: false));

  Future<Map<String, dynamic>> googleStatus(String idToken) async =>
      _asMap(await post('auth/v2/google/status', {'idToken': idToken},
          authenticated: false));

  Future<Map<String, dynamic>> googleComplete(
          String idToken, String role) async =>
      _asMap(await post(
          'auth/v2/google/complete', {'idToken': idToken, 'role': role},
          authenticated: false));

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<dynamic> put(String path, Object? body) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll({
      'Accept': 'application/json',
      if (_idToken?.isNotEmpty == true) 'Authorization': 'Bearer $_idToken',
    });
    request.fields.addAll(fields);
    request.files.addAll(files);
    try {
      final streamed =
          await _http.send(request).timeout(const Duration(seconds: 15));
      return _decode(
          streamed.statusCode, await streamed.stream.bytesToString());
    } on http.ClientException {
      throw const MedilinkApiException(
        'Connexion API impossible. Vérifiez l’adresse API et le réseau.',
      );
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    if (!isConfigured) {
      throw const MedilinkApiException(
        'API_BASE_URL n’est pas configurée.',
      );
    }
    final uri = _uri(path, query);
    final headers = _headers(authenticated: authenticated);
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (method != 'GET' && body != null) request.body = jsonEncode(body);
      final streamed =
          await _http.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401 &&
          authenticated &&
          retryOnUnauthorized &&
          _refreshToken?.isNotEmpty == true &&
          path != 'auth/v2/refresh') {
        try {
          final refreshed = _asMap(await _send(
            'POST',
            'auth/v2/refresh',
            body: {'refreshToken': _refreshToken},
            authenticated: false,
            retryOnUnauthorized: false,
          ));
          await setSession(refreshed);
          return await _send(
            method,
            path,
            query: query,
            body: body,
            authenticated: authenticated,
            retryOnUnauthorized: false,
          );
        } on MedilinkApiException catch (exception) {
          if (![400, 401, 403].contains(exception.statusCode)) rethrow;
          await clearSession();
          onSessionExpired?.call();
          throw const MedilinkApiException(
            'Session expirée. Veuillez vous reconnecter.',
            statusCode: 401,
          );
        }
      }
      if (response.statusCode == 401 && authenticated) {
        await clearSession();
        onSessionExpired?.call();
        throw const MedilinkApiException(
          'Session expirée. Veuillez vous reconnecter.',
          statusCode: 401,
        );
      }
      return _decode(response.statusCode, response.body);
    } on TimeoutException {
      throw const MedilinkApiException(
        'Le serveur MedLink ne répond pas. Vérifiez sa disponibilité et réessayez.',
      );
    } on http.ClientException {
      throw const MedilinkApiException(
        'Connexion API impossible. Vérifiez l’adresse API et le réseau.',
      );
    }
  }

  Map<String, String> _headers({bool authenticated = true}) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (authenticated && _idToken?.isNotEmpty == true)
          'Authorization': 'Bearer $_idToken',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = _apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/$path').replace(queryParameters: query);
  }

  dynamic _decode(int statusCode, String body) {
    dynamic value;
    if (body.trim().isNotEmpty) {
      try {
        value = jsonDecode(body);
      } on FormatException {
        value = body;
      }
    }
    if (statusCode < 200 || statusCode >= 300) {
      final rawMessage = value is Map ? value['message'] : null;
      final message =
          rawMessage is List ? rawMessage.join('\n') : rawMessage?.toString();
      throw MedilinkApiException(
        message?.isNotEmpty == true
            ? message!
            : 'La requête API a échoué (HTTP $statusCode).',
        statusCode: statusCode,
      );
    }
    return value;
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List)
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    if (value is Map)
      return <Map<String, dynamic>>[Map<String, dynamic>.from(value)];
    throw const MedilinkApiException('Réponse API inattendue.');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const MedilinkApiException('Réponse API inattendue.');
  }

  // ── Rendez-vous (endpoints /appointments/v2/…) ──
  Future<List<Map<String, dynamic>>> appointmentsList() async =>
      _asList(await get('appointments/v2'));

  Future<List<Map<String, dynamic>>> appointmentsForDoctor() async =>
      _asList(await get('appointments/v2/doctor'));

  Future<Map<String, dynamic>> appointmentDetail(String id) async =>
      _asMap(await get('appointments/v2/${Uri.encodeComponent(id)}'));

  Future<Map<String, dynamic>> appointmentCreate(
          Map<String, dynamic> data) async =>
      _asMap(await post('appointments/v2', data));

  Future<Map<String, dynamic>> appointmentUpdateStatus(
          String id, String status) async =>
      _asMap(await patch(
        'appointments/v2/${Uri.encodeComponent(id)}/status',
        {'status': status},
      ));

  Future<dynamic> appointmentReview(String id) async =>
      get('appointments/v2/${Uri.encodeComponent(id)}/review');

  Future<dynamic> appointmentSubmitReview(
    String id, {
    required num rating,
    String? comment,
  }) async =>
      post(
        'appointments/v2/${Uri.encodeComponent(id)}/review',
        {'rating': rating, 'comment': comment},
      );

  // ── Médecins (endpoints /doctors/v2/…) ──
  Future<Map<String, dynamic>> doctorsList({
    String? q,
    String? specialty,
    String? city,
  }) async {
    final query = <String, String>{};
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (specialty != null && specialty.isNotEmpty)
      query['specialty'] = specialty;
    if (city != null && city.isNotEmpty) query['city'] = city;
    return _asMap(await get('doctors/v2', query: query));
  }

  Future<Map<String, dynamic>> doctorDetail(String id) async =>
      _asMap(await get('doctors/v2/${Uri.encodeComponent(id)}'));

  Future<Map<String, dynamic>> doctorMe() async =>
      _asMap(await get('doctors/v2/me'));

  Future<List<Map<String, dynamic>>> doctorReviews() async =>
      _asList(await get('doctors/v2/me/reviews'));

  Future<Map<String, dynamic>> doctorUpdate({
    String? bio,
    num? yearsOfExperience,
    num? consultationFee,
    String? professionalAddress,
  }) async {
    final data = <String, dynamic>{};
    if (bio != null) data['bio'] = bio;
    if (yearsOfExperience != null)
      data['yearsOfExperience'] = yearsOfExperience;
    if (consultationFee != null) data['consultationFee'] = consultationFee;
    if (professionalAddress != null)
      data['professionalAddress'] = professionalAddress;
    return _asMap(await patch('doctors/v2/me', data));
  }

  Future<Map<String, dynamic>> doctorUploadDocument({
    required http.MultipartFile file,
    required String type,
  }) async =>
      _asMap(await postMultipart(
        'doctors/v2/me/documents',
        fields: {'type': type},
        files: [file],
      ));

  Future<void> doctorDeleteDocument(String id) async =>
      await delete('doctors/v2/me/documents/${Uri.encodeComponent(id)}');

  // ── Patients (endpoints /patients/v2/me/…) ──
  Future<List<Map<String, dynamic>>> patientConditions() async =>
      _asList(await get('patients/v2/me/conditions'));

  Future<List<Map<String, dynamic>>> patientDocuments() async =>
      _asList(await get('patients/v2/me/documents'));

  Future<Map<String, dynamic>> patientUploadDocument({
    required http.MultipartFile file,
    required String type,
    String? title,
  }) async {
    final fields = <String, String>{'type': type};
    if (title != null && title.isNotEmpty) fields['title'] = title;
    return _asMap(await postMultipart(
      'patients/v2/me/documents',
      fields: fields,
      files: [file],
    ));
  }

  Future<void> patientDeleteDocument(String id) async =>
      await delete('patients/v2/me/documents/${Uri.encodeComponent(id)}');

  Future<Map<String, dynamic>> patientSaveProfile({
    required String name,
    required String phone,
    required String bloodType,
    required String city,
    required String district,
  }) async =>
      _asMap(await patch('integration/v2/patient/profile', {
        'name': name,
        'phone': phone,
        'bloodType': bloodType,
        'city': city,
        'district': district,
      }));

  // ── Disponibilités médecin (endpoints /availabilities/v2/me/…) ──
  final String _availabilitiesBase = 'availabilities/v2/me';

  Future<List<Map<String, dynamic>>> availabilityModes() async =>
      _availabilityModeRows(await get('$_availabilitiesBase/modes'));

  Future<List<Map<String, dynamic>>> availabilitySetModes(
          List<String> modes) async =>
      _availabilityModeRows(
          await put('$_availabilitiesBase/modes', {'modes': modes}));

  List<Map<String, dynamic>> _availabilityModeRows(dynamic value) {
    if (value is! List) {
      throw const MedilinkApiException(
          'Réponse API inattendue pour les modes de consultation.');
    }
    return value.map((item) {
      if (item is String) return <String, dynamic>{'mode': item};
      if (item is Map) return Map<String, dynamic>.from(item);
      throw const MedilinkApiException(
          'Un mode de consultation renvoyé par l’API est invalide.');
    }).toList();
  }

  Future<Map<String, dynamic>> availabilityDuration() async =>
      _asMap(await get('$_availabilitiesBase/duration'));

  Future<Map<String, dynamic>> availabilitySetDuration(
          int durationMinutes) async =>
      _asMap(await patch(
        '$_availabilitiesBase/duration',
        {'durationMinutes': durationMinutes},
      ));

  Future<List<Map<String, dynamic>>> availabilityWeekly() async =>
      _asList(await get('$_availabilitiesBase/weekly'));

  Future<List<Map<String, dynamic>>> availabilitySetWeekly(
    List<Map<String, dynamic>> weekly,
  ) async =>
      _asList(await put('$_availabilitiesBase/weekly', weekly));

  Future<List<Map<String, dynamic>>> availabilityBlocked() async =>
      _asList(await get('$_availabilitiesBase/blocked'));

  Future<Map<String, dynamic>> availabilityCreateBlocked({
    required String date,
    String? reason,
  }) async {
    final data = <String, dynamic>{'date': date};
    if (reason != null) data['reason'] = reason;
    return _asMap(await post('$_availabilitiesBase/blocked', data));
  }

  Future<void> availabilityDeleteBlocked(String id) async =>
      await delete('$_availabilitiesBase/blocked/${Uri.encodeComponent(id)}');

  Future<List<Map<String, dynamic>>> availabilityAppointments() async =>
      _asList(await get('$_availabilitiesBase/appointments'));

  // ── Besoins médicaux (endpoints /needs/v2/…) ──
  Future<List<Map<String, dynamic>>> needsList() async =>
      _asList(await get('needs/v2'));

  Future<Map<String, dynamic>> needDetail(String id) async =>
      _asMap(await get('needs/v2/${Uri.encodeComponent(id)}'));

  Future<Map<String, dynamic>> needCreate(Map<String, dynamic> data) async =>
      _asMap(await post('needs/v2', data));

  Future<Map<String, dynamic>> needUpdate({
    required String id,
    required String title,
    required String specialty,
    required String description,
    required String mode,
  }) async =>
      _asMap(await patch(
        'needs/v2/${Uri.encodeComponent(id)}',
        {
          'title': title,
          'specialty': specialty,
          'description': description,
          'mode': mode,
        },
      ));

  Future<Map<String, dynamic>> needClose(String id) async => _asMap(
      await patch('needs/v2/${Uri.encodeComponent(id)}/close', const {}));

  Future<Map<String, dynamic>> needDelete(String id) async =>
      _asMap(await delete('needs/v2/${Uri.encodeComponent(id)}'));

  Future<Map<String, dynamic>> needsForDoctor({
    String? q,
    String? specialty,
    String? priority,
    String? mode,
    int? page,
    int? pageSize,
  }) async {
    final query = <String, String>{};
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (specialty != null && specialty.isNotEmpty)
      query['specialty'] = specialty;
    if (priority != null && priority.isNotEmpty) query['priority'] = priority;
    if (mode != null && mode.isNotEmpty) query['mode'] = mode;
    if (page != null) query['page'] = page.toString();
    if (pageSize != null) query['pageSize'] = pageSize.toString();
    return _asMap(await get('needs/v2/doctor', query: query));
  }

  Future<Map<String, dynamic>> needDoctorDetail(String id) async =>
      _asMap(await get('needs/v2/doctor/${Uri.encodeComponent(id)}'));

  Future<Map<String, dynamic>> needsProposals({
    String? status,
    int? page,
    int? pageSize,
  }) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (page != null) query['page'] = page.toString();
    if (pageSize != null) query['pageSize'] = pageSize.toString();
    return _asMap(await get('needs/v2/doctor/proposals', query: query));
  }

  Future<Map<String, dynamic>> needPropose({
    required String id,
    required String message,
    required String proposedAppointmentAt,
    required String consultationMode,
    required num fee,
    String? details,
  }) async {
    final data = <String, dynamic>{
      'message': message,
      'proposedAppointmentAt': proposedAppointmentAt,
      'consultationMode': consultationMode,
      'fee': fee,
    };
    if (details != null) data['details'] = details;
    return _asMap(await post(
      'needs/v2/doctor/${Uri.encodeComponent(id)}/proposals',
      data,
    ));
  }

  Future<dynamic> needCancelProposal(String id) async => patch(
        'needs/v2/doctor/proposals/${Uri.encodeComponent(id)}/cancel',
        const {},
      );

  Future<Map<String, dynamic>> needAcceptProposal(
          String needId, String proposalId) async =>
      _asMap(await patch(
          'needs/v2/${Uri.encodeComponent(needId)}/proposals/${Uri.encodeComponent(proposalId)}/accept',
          const {}));

  // ── Messagerie (endpoints /messages/v2/conversations/…) ──
  Future<Map<String, dynamic>> messagesList() async =>
      _asMap(await get('messages/v2/conversations'));

  Future<Map<String, dynamic>> conversationMessages(String id) async =>
      _asMap(await get('messages/v2/conversations/${Uri.encodeComponent(id)}'));

  Future<Map<String, dynamic>> messageSend(String id, String body) async =>
      _asMap(await post(
        'messages/v2/conversations/${Uri.encodeComponent(id)}',
        {'body': body},
      ));

  Future<Map<String, dynamic>> conversationMarkRead(String id) async =>
      _asMap(await patch(
        'messages/v2/conversations/${Uri.encodeComponent(id)}/read',
        const {},
      ));

  // ── Notifications (endpoints /notifications/v2/…) ──
  Future<Map<String, dynamic>> notificationsList({
    required int page,
    required int pageSize,
  }) async =>
      _asMap(await get(
        'notifications/v2',
        query: {'page': page.toString(), 'pageSize': pageSize.toString()},
      ));

  Future<Map<String, dynamic>> notificationRead(String id) async =>
      _asMap(await patch(
        'notifications/v2/${Uri.encodeComponent(id)}/read',
        const {},
      ));

  Future<Map<String, dynamic>> notificationsReadAll() async =>
      _asMap(await patch('notifications/v2/read-all', const {}));

  Future<Map<String, dynamic>> notificationRegisterDevice({
    required String deviceId,
    required String token,
    required String platform,
    String? userAgent,
  }) async {
    final data = <String, dynamic>{
      'deviceId': deviceId,
      'token': token,
      'platform': platform,
      // Android must receive data-only FCM messages so Flutter can create
      // the local notification with its category-specific small icon.
      // Novu remains available for web subscribers.
      'pushProvider': 'firebase',
    };
    if (userAgent != null) data['userAgent'] = userAgent;
    return _asMap(await post('notifications/v2/devices', data));
  }

  Future<Map<String, dynamic>> notificationUnregisterDevice(String id) async =>
      _asMap(await post(
        'notifications/v2/devices/${Uri.encodeComponent(id)}/unregister',
        const {},
      ));

  // ── Administration (endpoints /admin/v2/…) ──
  Future<Map<String, dynamic>> adminAccounts({
    required String role,
    required int page,
    required int pageSize,
    String q = '',
  }) async {
    final query = <String, String>{
      'role': role,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      'q': q,
    };
    return _asMap(await get('admin/v2/accounts', query: query));
  }

  Future<Map<String, dynamic>> adminUpdateAccountStatus(
          String id, String status) async =>
      _asMap(await patch(
        'admin/v2/accounts/${Uri.encodeComponent(id)}/status',
        {'status': status},
      ));

  Future<Map<String, dynamic>> adminVerification({
    required String id,
    bool? emailVerified,
    String? verificationStatus,
  }) async {
    final data = <String, dynamic>{};
    if (emailVerified != null) data['emailVerified'] = emailVerified;
    if (verificationStatus != null)
      data['verificationStatus'] = verificationStatus;
    return _asMap(await patch(
      'admin/v2/accounts/${Uri.encodeComponent(id)}/verification',
      data,
    ));
  }

  Future<Map<String, dynamic>> adminCreateAdmin(
          Map<String, dynamic> data) async =>
      _asMap(await post('admin/v2/admins', data));

  Future<Map<String, dynamic>> adminUpdateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async =>
      _asMap(await patch('auth/v2/admin/profile', {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
      }));

  // ── Intégrations (endpoints /integration/v2/…) ──
  Future<Map<String, dynamic>> integrationDoctorZone() async =>
      _asMap(await get('integration/v2/doctor/zone'));

  Future<Map<String, dynamic>> integrationSaveDoctorZone(
          Map<String, dynamic> data) async =>
      _asMap(await put('integration/v2/doctor/zone', data));

  Future<Map<String, dynamic>> integrationSavePatientProfile({
    required String name,
    required String phone,
    required String bloodType,
    required String city,
    required String district,
  }) async =>
      _asMap(await patch(
        'integration/v2/patient/profile',
        {
          'name': name,
          'phone': phone,
          'bloodType': bloodType,
          'city': city,
          'district': district,
        },
      ));

  Future<Map<String, dynamic>> integrationContact(
          Map<String, dynamic> data) async =>
      _asMap(await post('integration/v2/contact', data, authenticated: false));
}

class MedilinkApiException implements Exception {
  const MedilinkApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
