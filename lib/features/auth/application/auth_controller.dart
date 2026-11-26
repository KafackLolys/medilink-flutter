import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/data/live_state.dart';
import '../../../core/services/push_notification_service.dart';

class AuthController extends ChangeNotifier {
  AuthController() {
    MedilinkApi.instance.onSessionExpired = _clearExpiredSession;
  }

  Map<String, dynamic>? _session;
  bool busy = false;
  bool initializing = true;
  bool checkingBackend = false;
  String? error;
  String? startupError;
  Map<String, dynamic>? get user => _session?['user'] as Map<String, dynamic>?;
  bool get signedIn => user != null;
  bool get usesApi => MedilinkApi.instance.isConfigured;
  String get role => user?['role']?.toString() ?? 'patient';
  String get name =>
      '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();

  Future<void> initialize() async {
    try {
      final restored = await MedilinkApi.instance.restoreSession();
      if (restored == null) return;
      _session = restored;
      await retryBackendConnection(notify: false);
      await PushNotificationService.instance.registerAuthenticatedDevice();
    } catch (_) {
      _session = null;
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> retryBackendConnection({bool notify = true}) async {
    if (_session == null) return;
    checkingBackend = true;
    startupError = null;
    if (notify) notifyListeners();
    try {
      final response = await MedilinkApi.instance.profile();
      final profileUser = response['user'];
      if (profileUser is Map && _session != null) {
        _session = {
          ..._session!,
          'user': Map<String, dynamic>.from(profileUser),
        };
        await MedilinkApi.instance.setSession(_session!);
      }
    } catch (exception) {
      if (_session != null) startupError = _formatStartupError(exception);
      if (exception is MedilinkApiException && exception.statusCode == 401) {
        error = 'Votre session a expiré. Connectez-vous à nouveau.';
      }
    } finally {
      checkingBackend = false;
      if (notify) notifyListeners();
    }
  }

  String _formatStartupError(Object exception) {
    if (!MedilinkApi.instance.isConfigured) {
      return 'Le serveur MediLink n’est pas configuré. Vérifiez API_BASE_URL dans .env.json.';
    }
    if (exception is MedilinkApiException) {
      final status = exception.statusCode;
      if (status != null && status >= 500) {
        return 'Le serveur MediLink est momentanément indisponible. Réessayez dans quelques instants.';
      }
      if (status == 403) {
        return 'Le serveur a refusé l’accès à ce compte. Vérifiez son statut et ses autorisations.';
      }
      if (status == 401) {
        return 'Votre session a expiré. Connectez-vous à nouveau.';
      }
      if (status == null) {
        return 'Impossible de joindre le serveur MediLink. Vérifiez le démarrage du backend et la connexion réseau.';
      }
    }
    return 'La connexion au serveur MediLink a échoué. Réessayez dans quelques instants.';
  }

  Future<void> updateUserProfile(Map<String, dynamic> updatedUser) async {
    if (_session == null) return;
    _session = {
      ..._session!,
      'user': {...?user, ...updatedUser}
    };
    await MedilinkApi.instance.setSession(_session!);
    notifyListeners();
  }

  /// Opens a session only when the V2 API accepts the credentials.
  Future<void> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();

    try {
      final emailValue = email.trim();
      if (emailValue.isEmpty) {
        throw const FormatException('Saisissez votre e-mail.');
      }
      if (password.isEmpty) {
        throw const FormatException('Saisissez votre mot de passe.');
      }

      if (!MedilinkApi.instance.isConfigured) {
        throw const MedilinkApiException(
          'Le service MediLink n’est pas configuré. Définissez API_BASE_URL.',
        );
      }
      final session = await MedilinkApi.instance.login(emailValue, password);
      final sessionUser = session['user'];
      if (sessionUser is! Map ||
          sessionUser['id'] == null ||
          session['idToken']?.toString().isNotEmpty != true) {
        throw const MedilinkApiException(
          'La réponse du serveur ne contient pas de session valide.',
        );
      }
      _session = session;
      await MedilinkApi.instance.setSession(_session!);
      await PushNotificationService.instance.registerAuthenticatedDevice();
      startupError = null;
    } catch (exception) {
      _session = null;
      await MedilinkApi.instance.logout();
      if (exception is MedilinkApiException && exception.statusCode == 401) {
        error = 'Email ou mot de passe incorrect.';
      } else {
        error = exception.toString();
      }
    } finally {
      busy = false;
    }
    notifyListeners();
  }

  /// Creates an account through the V2 API.
  Future<void> register(Map<String, dynamic> data) async {
    busy = true;
    error = null;
    notifyListeners();

    try {
      final emailValue = (data['email'] ?? '').toString().trim();
      if (emailValue.isEmpty) {
        throw const FormatException('Saisissez votre e-mail.');
      }
      if ((data['password'] ?? '').toString().isEmpty) {
        throw const FormatException('Saisissez votre mot de passe.');
      }

      if (!MedilinkApi.instance.isConfigured) {
        throw const MedilinkApiException(
          'Le service MediLink n’est pas configuré. Définissez API_BASE_URL.',
        );
      }
      await MedilinkApi.instance.register(data);
    } catch (exception) {
      error = exception.toString();
    } finally {
      busy = false;
    }
    notifyListeners();
  }

  /// Vérifie si un compte Google est déjà enregistré.
  Future<Map<String, dynamic>?> googleStatus(String idToken) async {
    if (!MedilinkApi.instance.isConfigured) {
      throw const MedilinkApiException(
        'Le service MediLink n’est pas configuré. Définissez API_BASE_URL.',
      );
    }
    return MedilinkApi.instance.googleStatus(idToken);
  }

  Future<void> signInWithGoogle(String role) async {
    busy = true;
    error = null;
    notifyListeners();

    try {
      final googleClientId = AppEnvironment.googleClientId;
      if (googleClientId.isEmpty) {
        throw const FormatException(
          'Configurez GOOGLE_CLIENT_ID pour activer la connexion Google.',
        );
      }

      final googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? googleClientId : null,
        serverClientId: googleClientId,
        scopes: <String>['email', 'profile'],
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        // L'utilisateur a annulé la connexion Google.
        return;
      }

      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null) {
        throw const FormatException('Jetons d\'identité Google introuvable.');
      }

      if (!MedilinkApi.instance.isConfigured) {
        throw const FormatException(
          'L’API n’est pas configurée. Définissez API_BASE_URL avant de vous connecter avec Google.',
        );
      }

      // Complète la connexion ou l’inscription Google via l’API v2.
      final session = await MedilinkApi.instance.googleComplete(idToken, role);
      _session = session;
      await MedilinkApi.instance.setSession(session);
      await PushNotificationService.instance.registerAuthenticatedDevice();
    } catch (exception) {
      error = exception is PlatformException &&
              exception.code == 'sign_in_failed' &&
              exception.toString().contains('ApiException: 10')
          ? 'Google refuse cette application (code 10). Dans Firebase/Google Cloud, enregistrez le package Android com.lolys.medilink avec le SHA-1 du certificat de signature de cette build, puis remplacez android/app/google-services.json par le fichier téléchargé.'
          : exception.toString();
    } finally {
      busy = false;
    }
    notifyListeners();
  }

  /// Demande une réinitialisation de mot de passe par e-mail.
  Future<void> resetPassword(String email) async {
    busy = true;
    error = null;
    notifyListeners();

    try {
      if (!MedilinkApi.instance.isConfigured) {
        throw const MedilinkApiException(
          'Le service MediLink n’est pas configuré. Définissez API_BASE_URL.',
        );
      }
      await MedilinkApi.instance.resetPassword(email.trim());
    } catch (exception) {
      error = exception.toString();
    } finally {
      busy = false;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await PushNotificationService.instance.unregisterAuthenticatedDevice();
      await MedilinkApi.instance.logout();
    } catch (_) {
      // Clear the local session even if revocation cannot reach the API.
    }
    _session = null;
    startupError = null;
    error = null;
    LiveState.clearSession();
    notifyListeners();
  }

  void _clearExpiredSession() {
    PushNotificationService.instance.clearRegistrationState();
    _session = null;
    LiveState.clearSession();
    notifyListeners();
  }
}
