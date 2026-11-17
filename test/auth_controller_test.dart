import 'package:cleanbot_app/core/errors/failures.dart';
import 'package:cleanbot_app/features/auth/domain/auth_repository.dart';
import 'package:cleanbot_app/features/auth/domain/user_model.dart';
import 'package:cleanbot_app/features/auth/presentation/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  User? _currentUser;
  Object? error;

  @override
  Future<User> login({
    required String username,
    required String password,
  }) async {
    if (error != null) throw error!;
    _currentUser = User(
      id: 'user-test',
      email: username,
      fullName: 'Test User',
      role: username.contains('readonly')
          ? UserRole.readOnly
          : UserRole.operator,
    );
    return _currentUser!;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  @override
  Future<User?> getCurrentUser() async => _currentUser;

  @override
  Future<bool> isAuthenticated() async => _currentUser != null;
}

void main() {
  test('demo login sets the authenticated user and role', () async {
    final repository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(authControllerProvider.notifier)
        .login('readonly@cleanbot.io', 'ReadOnly#2026');

    expect(success, isTrue);
    final state = container.read(authControllerProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.user?.role, UserRole.readOnly);
    expect(state.user?.role.canControlRobots, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('invalid credentials are reported without authenticating', () async {
    final repository = FakeAuthRepository()
      ..error = const AuthFailure(message: 'Invalid email or password.');
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(authControllerProvider.notifier)
        .login('operator@cleanbot.io', 'wrong');

    expect(success, isFalse);
    final state = container.read(authControllerProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.errorMessage, contains('Invalid email or password'));
  });

  test('field errors from validation are exposed to the login form', () async {
    final repository = FakeAuthRepository()
      ..error = const ValidationFailure(
        message: 'Please correct the highlighted fields.',
        fieldErrors: {'password': 'Password is required'},
      );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .login('operator@cleanbot.io', '');

    expect(
      container.read(authControllerProvider).fieldErrors['password'],
      'Password is required',
    );
  });

  test('force logout clears the session and keeps the reason visible', () async {
    final repository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .login('operator@cleanbot.io', 'CleanBot#2026');
    await container
        .read(authControllerProvider.notifier)
        .forceLogout('Session expired. Please sign in again.');

    final state = container.read(authControllerProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.user, isNull);
    expect(state.errorMessage, contains('Session expired'));
  });
}
