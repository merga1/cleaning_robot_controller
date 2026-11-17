import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';
import '../domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  final config = ref.watch(appConfigProvider);

  return AuthRepositoryImpl(
    dio: dio,
    storage: storage,
    config: config,
  );
});

class AuthState {
  final bool isLoading;
  final User? user;
  final String? errorMessage;
  final bool isAuthenticated;
  /// Field-level validation errors from the backend (MOB-AUTH-007).
  final Map<String, String> fieldErrors;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
    this.isAuthenticated = false,
    this.fieldErrors = const {},
  });

  AuthState copyWith({
    bool? isLoading,
    User? user,
    String? errorMessage,
    bool? isAuthenticated,
    Map<String, String>? fieldErrors,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Called once by the router's splash screen (MOB-ONB-001).
    return const AuthState();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Restores the session. The splash screen awaits this before routing.
  Future<void> restoreSession() async {
    if (state.isLoading || state.isAuthenticated) return;
    state = state.copyWith(isLoading: true);
    final isAuth = await _repository.isAuthenticated();
    if (isAuth) {
      final user = await _repository.getCurrentUser();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: user != null,
        user: user,
      );
    } else {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null, fieldErrors: const {});
    try {
      final user = await _repository.login(
        username: username.trim(),
        password: password,
      );
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      return true;
    } catch (e) {
      final Map<String, String> fieldErrors = {};
      String message = e.toString();
      if (e is ValidationFailure) {
        fieldErrors.addAll(e.fieldErrors);
        message = e.message;
      } else if (e is Failure) {
        message = e.message;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
        fieldErrors: fieldErrors,
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repository.logout();
    state = const AuthState(isAuthenticated: false);
  }

  /// MOB-AUTH-005: token refresh failed - clear credentials, show a message
  /// and let the router redirect to /login.
  Future<void> forceLogout(String message) async {
    await _repository.logout();
    state = AuthState(
      isAuthenticated: false,
      errorMessage: message,
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
