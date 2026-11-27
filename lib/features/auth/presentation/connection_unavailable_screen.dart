import 'package:flutter/material.dart';

/// Écran bloquant affiché au démarrage lorsque l'API MediLink est inaccessible.
class ConnectionUnavailableScreen extends StatelessWidget {
  const ConnectionUnavailableScreen({
    super.key,
    required this.loading,
    required this.onRetry,
  });

  final bool loading;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _ConnectionIllustration(),
                  const SizedBox(height: 34),
                  Text(
                    'Connexion indisponible',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF172B4D),
                        ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nous n’arrivons pas à joindre les services MediLink pour le moment. '
                    'Vérifiez votre connexion Internet ou réessayez dans quelques instants.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: loading ? null : () => onRetry(),
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(loading ? 'Vérification…' : 'Réessayer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'MediLink — votre santé, mieux connectée',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF98A2B3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionIllustration extends StatelessWidget {
  const _ConnectionIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            right: 16,
            child: _dot(10, const Color(0xFFB9D7FF)),
          ),
          Positioned(
            left: 12,
            top: 50,
            child: _dot(7, const Color(0xFF9EDCCB)),
          ),
          Positioned(
            bottom: 12,
            right: 34,
            child: _dot(8, const Color(0xFFFFD28A)),
          ),
          Container(
            width: 174,
            height: 174,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD6E6FF), width: 1.5),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14243F70),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 58,
              color: Color(0xFF3478D4),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 26,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 23,
                color: Color(0xFFE58A45),
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 34,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE4F6EF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                size: 21,
                color: Color(0xFF269B75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
