import 'package:flutter/material.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/demo_data.dart';

class DemoSessionController extends ChangeNotifier {
  Map<String, dynamic>? _session;
  bool busy = false;
  String? error;
  Map<String, dynamic>? lastRegistrationSession;
  Map<String, dynamic>? get user => _session?['user'] as Map<String, dynamic>?;
  bool get signedIn => user != null;
  bool get usesApi => MedilinkApi.instance.isConfigured;
  String get role => user?['role']?.toString() ?? 'patient';
  String get name =>
      '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();

  Future<void> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();

    try {
      if (MedilinkApi.instance.isConfigured) {
        _session = await MedilinkApi.instance.login(email.trim(), password);
        MedilinkApi.instance.setSession(_session!);
      } else {
        _session = lastRegistrationSession ??
            DemoData.authSession(
              firstName: 'Amina',
              lastName: 'Nguema',
              email: email.trim().isEmpty
                  ? 'amina.demo@medilink.app'
                  : email.trim(),
              phone: '+237 600 00 00 01',
              role: 'patient',
            );
      }
    } catch (exception) {
      error = exception.toString();
    } finally {
      busy = false;
    }
    notifyListeners();
  }

  Future<void> register(Map<String, dynamic> data) async {
    busy = true;
    error = null;
    notifyListeners();

    try {
      if (MedilinkApi.instance.isConfigured) {
        lastRegistrationSession = await MedilinkApi.instance.register(data);
      } else {
        lastRegistrationSession = DemoData.authSession(
          firstName: data['firstName']?.toString() ?? 'Nouveau',
          lastName: data['lastName']?.toString() ?? 'Compte',
          email: data['email']?.toString() ?? '',
          phone: data['phone']?.toString() ?? '',
          role: data['role']?.toString() ?? 'patient',
          specialty: data['specialty']?.toString(),
          registrationNumber: data['registrationNumber']?.toString(),
        );
      }
    } catch (exception) {
      error = exception.toString();
    } finally {
      busy = false;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await MedilinkApi.instance.logout();
    } catch (_) {
      // Clear the local session even if revocation cannot reach the API.
    }
    _session = null;
    notifyListeners();
  }
}
