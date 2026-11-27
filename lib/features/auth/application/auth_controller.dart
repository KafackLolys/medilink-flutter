import 'package:firebase_auth/firebase_auth.dart';
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

      final googleAuthentication = await account.authentication;
      if (googleAuthentication.idToken == null) {
        throw const FormatException(
          'Google n’a pas fourni de jeton d’identité. Vérifiez le client OAuth Web.',
        );
      }

      // Le backend vérifie un Firebase ID token (provider google.com), pas
      // le jeton OAuth Google brut. Échange donc le credential Google contre
      // une session Firebase avant d'appeler les routes MediLink.
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuthentication.idToken,
        accessToken: googleAuthentication.accessToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw const FormatException(
          'Firebase n’a pas retourné de compte utilisateur.',
        );
      }
      final firebaseIdToken = await firebaseUser.getIdToken(true);
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw const FormatException(
          'Impossible de récupérer le jeton Firebase.',
        );
      }

      if (!MedilinkApi.instance.isConfigured) {
        throw const FormatException(
          'L’API n’est pas configurée. Définissez API_BASE_URL avant de vous connecter avec Google.',
        );
      }

      // Le backend attend un Firebase ID token et sépare les comptes
      // existants des nouvelles inscriptions Google.
      final status = await MedilinkApi.instance.googleStatus(firebaseIdToken);
      Map<String, dynamic> sessionUser;
      if (status['registered'] == true && status['user'] is Map) {
        sessionUser = Map<String, dynamic>.from(status['user'] as Map);
      } else {
        final completed = await MedilinkApi.instance.googleComplete(
          firebaseIdToken,
          role,
        );
        final user = completed['user'];
        if (user is! Map) {
          throw const MedilinkApiException(
            'La réponse du serveur ne contient pas de profil MediLink valide.',
          );
        }
        sessionUser = Map<String, dynamic>.from(user);
      }

      if (sessionUser['id'] == null) {
        throw const MedilinkApiException(
          'Le profil MediLink ne contient aucun identifiant utilisateur.',
        );
      }
      final session = <String, dynamic>{
        'user': sessionUser,
        'idToken': firebaseIdToken,
        'tokenType': 'Bearer',
      };
      _session = session;
      await MedilinkApi.instance.setSession(session);
      await PushNotificationService.instance.registerAuthenticatedDevice();
      startupError = null;
    } catch (exception) {
      // Évite de laisser une session Firebase active si l'API MediLink
      // n'a pas pu terminer l'authentification.
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {
        // L'erreur d'authentification initiale reste prioritaire.
      }
      error = exception is PlatformException &&
              exception.code == 'sign_in_failed' &&
              exception.toString().contains('ApiException: 10')
          ? 'Google refuse cette application (code 10). Vérifiez le package com.lolys.medilink et le SHA-1 du certificat de cette APK dans Firebase/Google Cloud, puis téléchargez le google-services.json actualisé.'
          : exception is FirebaseAuthException
              ? 'Authentification Firebase impossible : ${exception.message ?? exception.code}'
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
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } catch (_) {
      // La session locale MediLink est déjà supprimée.
    }
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
