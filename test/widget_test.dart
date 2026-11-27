import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medilink_flutter/app.dart';
import 'package:medilink_flutter/features/auth/application/auth_controller.dart';

void main() {
  testWidgets('shows the session loading screen while auth initializes',
      (WidgetTester tester) async {
    final auth = AuthController();
    await tester.pumpWidget(MediLinkApp(auth: auth));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('MediLink'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
}
