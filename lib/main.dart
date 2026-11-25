import 'package:flutter/material.dart';
import 'app.dart';
import 'features/auth/application/auth_controller.dart';
import 'core/config/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnvironment.load();
  runApp(MedLinkApp(auth: AuthController()));
}
