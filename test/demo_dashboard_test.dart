import 'package:cleanbot_app/core/storage/preferences_service.dart';
import 'package:cleanbot_app/features/auth/domain/auth_repository.dart';
import 'package:cleanbot_app/features/auth/domain/user_model.dart';
import 'package:cleanbot_app/features/auth/presentation/auth_controller.dart';
import 'package:cleanbot_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the mock auth repository so the widget test does not need the
/// flutter_secure_storage platform channel.
class _DemoAuthRepository implements AuthRepository {
  User? _user;

  @override
  Future<User> login({
    required String username,
    required String password,
  }) async {
    _user = User(
      id: 'user-operator',
      email: username,
      fullName: 'Sara Operator',
      role: UserRole.operator,
    );
    return _user!;
  }

  @override
  Future<void> logout() async => _user = null;

  @override
  Future<User?> getCurrentUser() async => _user;

  @override
  Future<bool> isAuthenticated() async => _user != null;
}

Future<void> _pumpFreshDemoApp(WidgetTester tester) async {
  // Empty preferences simulate a first launch: no onboarding, no session.
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(_DemoAuthRepository()),
      ],
      child: const CleanBotApp(),
    ),
  );

  // Mock telemetry and stale-check timers are periodic, so pumpAndSettle would
  // never settle. Advance time explicitly to cover login + mock data loads.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('mock mode opens the dashboard on a fresh install',
      (tester) async {
    await _pumpFreshDemoApp(tester);

    expect(find.textContaining('Lobby & Main Hall'), findsWidgets);
    expect(find.text('Waste Fill'), findsOneWidget);
    expect(find.text('Cleanliness'), findsOneWidget);
    expect(find.text('Sign In to Console'), findsNothing);
    expect(find.text('Enter Console'), findsNothing);
  });

  testWidgets('dashboard quick links open mock-data screens', (tester) async {
    await _pumpFreshDemoApp(tester);

    final zonesLink = find.widgetWithText(InkWell, 'Zones & Planning');
    await tester.scrollUntilVisible(
      zonesLink,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(zonesLink);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Select Cleaning Zones'), findsOneWidget);
    expect(find.text('Lobby & Main Hall'), findsWidgets);
  });
}
