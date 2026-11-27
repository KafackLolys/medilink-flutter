import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medilink_flutter/features/auth/presentation/connection_unavailable_screen.dart';

void main() {
  testWidgets('shows an offline illustration and retry action',
      (WidgetTester tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectionUnavailableScreen(
          loading: false,
          onRetry: () async {
            retried = true;
          },
        ),
      ),
    );

    expect(find.text('Connexion indisponible'), findsOneWidget);
    expect(find.textContaining('Vérifiez votre connexion Internet'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    expect(retried, isTrue);
  });
}
