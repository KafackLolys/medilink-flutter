import 'package:flutter/material.dart';

import 'app.dart';
import 'features/auth/application/demo_session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MedLinkApp(auth: DemoSessionController()));
}
