import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_shell.dart';

class MedLinkApp extends StatelessWidget {
  const MedLinkApp({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) => MaterialApp(
        title: 'MedLink',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: auth.signedIn ? HomeShell(auth: auth) : LoginScreen(auth: auth),
      ),
    );
  }
}
