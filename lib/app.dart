import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_shell.dart';
import 'core/widgets/medilink_logo_mark.dart';
import 'core/widgets/notification_permission_gate.dart';

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
        home: NotificationPermissionGate(
          child: auth.initializing
              ? const _SessionLoadingScreen()
              : auth.signedIn
                  ? HomeShell(auth: auth)
                  : LoginScreen(auth: auth),
        ),
      ),
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MedilinkLogoMark(size: 40),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
}
