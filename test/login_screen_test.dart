import 'package:cleanbot_app/core/errors/failures.dart';
import 'package:cleanbot_app/core/storage/preferences_service.dart';
import 'package:cleanbot_app/features/auth/domain/auth_repository.dart';
import 'package:cleanbot_app/features/auth/domain/user_model.dart';
import 'package:cleanbot_app/features/auth/presentation/auth_controller.dart';
import 'package:cleanbot_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  Object? error;

  @override
  Future<User> login({
    required String username,
    required String password,
  }) async {
    if (error != null) throw error!;
    return User(
      id: 'user-test',
      email: username,
      fullName: 'Test User',
      role: UserRole.operator,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<bool> isAuthenticated() async => false;
}

Future<void> _pumpLogin(WidgetTester tester, AuthRepository repository) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('demo role chips fill credentials from the mock catalogue',
      (tester) async {
    await _pumpLogin(tester, _FakeAuthRepository());

    final chip = find.widgetWithText(ActionChip, 'Operator');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pump();

    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text,
        'operator@cleanbot.io');
    expect(tester.widget<TextFormField>(fields.at(1)).controller!.text,
        'CleanBot#2026');
  });

  testWidgets('invalid credentials are shown in the login form', (tester) async {
    final repository = _FakeAuthRepository()
      ..error = const AuthFailure(message: 'Invalid email or password.');
    await _pumpLogin(tester, repository);

    await tester.enterText(find.byType(TextFormField).at(0),
        'operator@cleanbot.io');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In to Console'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Invalid email or password'), findsOneWidget);
  });
}
