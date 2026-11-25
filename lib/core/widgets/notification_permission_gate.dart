import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// À chaque lancement de l'application, vérifie l'autorisation système des
/// notifications. Si elle manque, propose d'ouvrir les paramètres de MediLink.
class NotificationPermissionGate extends StatefulWidget {
  const NotificationPermissionGate({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationPermissionGate> createState() =>
      _NotificationPermissionGateState();
}

class _NotificationPermissionGateState
    extends State<NotificationPermissionGate> with WidgetsBindingObserver {
  bool _dialogVisible = false;
  bool _settingsOpenedThisLaunch = false;

  bool get _supportsPush =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkPermissionAndPrompt());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_settingsOpenedThisLaunch) {
      unawaited(_checkPermissionAndPrompt());
    }
  }

  Future<void> _checkPermissionAndPrompt() async {
    if (!_supportsPush || !mounted || _dialogVisible) return;

    final status = await Permission.notification.status;
    if (!mounted || status.isGranted || _settingsOpenedThisLaunch) return;

    _dialogVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.notifications_active_outlined,
          size: 34,
        ),
        title: const Text('Activez les notifications'),
        content: const Text(
          'Pour recevoir les messages, demandes de rendez-vous et '
          'informations importantes de MediLink, autorisez les notifications '
          'dans les paramètres de votre téléphone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Plus tard'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              _settingsOpenedThisLaunch = true;
              await openAppSettings();
            },
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Ouvrir les paramètres'),
          ),
        ],
      ),
    );
    _dialogVisible = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
