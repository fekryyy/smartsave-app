import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:smartsave/app/app.dart';
import 'package:smartsave/presentation/providers/auth_provider.dart';
import 'package:smartsave/presentation/providers/theme_provider.dart';
import 'package:smartsave/services/google_auth_service.dart';
import 'package:smartsave/presentation/widgets/auth/session_guard.dart';

/// A simple mock GoogleAuthService for smoke test.
class _SmokeMockGoogleAuthService extends GoogleAuthService {
  @override
  bool isAvailable = false;

  @override
  Future<void> init() async {}

  @override
  Future<UserCredential?> signIn() async => null;
}

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              googleAuthService: _SmokeMockGoogleAuthService(),
            ),
          ),
        ],
        child: const SessionGuard(child: SmartSaveApp()),
      ),
    );
    // Advance past all splash screen timers:
    //   - animate_do animations (0ms, 200ms delays)
    //   - AnimationController (1.5s duration)
    //   - Future.delayed(2s) in _navigate()
    await tester.pump(const Duration(seconds: 3));
    // Let navigation (to login) and resulting animations settle
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
