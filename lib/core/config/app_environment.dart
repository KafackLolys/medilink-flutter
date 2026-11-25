import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads the single application configuration source bundled as `.env.json`.
class AppEnvironment {
  AppEnvironment._();

  static String apiBaseUrl = '';
  static String googleClientId = '';
  static String? loadError;

  static Future<void> load() async {
    try {
      final source = await rootBundle.loadString('.env.json');
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Le contenu doit être un objet JSON.');
      }
      apiBaseUrl = decoded['API_BASE_URL']?.toString().trim() ?? '';
      googleClientId = decoded['GOOGLE_CLIENT_ID']?.toString().trim() ?? '';
      loadError = null;
    } catch (error) {
      apiBaseUrl = '';
      googleClientId = '';
      loadError = error.toString();
    }
  }
}
