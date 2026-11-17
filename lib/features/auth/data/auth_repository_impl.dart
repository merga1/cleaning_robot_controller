import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/failures.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../mock/mock_catalog.dart';
import '../domain/auth_repository.dart';
import '../domain/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final SecureStorageService _storage;
  final AppConfig _config;

  User? _cachedUser;

  AuthRepositoryImpl({
    required Dio dio,
    required SecureStorageService storage,
    required AppConfig config,
  })  : _dio = dio,
        _storage = storage,
        _config = config;

  @override
  Future<User> login({required String username, required String password}) async {
    if (_config.enableMockMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      final account = MockCatalog.accountFor(username);
      if (account == null || account.password != password) {
        throw const AuthFailure(
          message: 'Invalid email or password. Use one of the demo accounts.',
        );
      }
      _cachedUser = account.user;
      await _storage.saveTokens(
        accessToken: 'mock-access-token-${account.user.id}',
        refreshToken: 'mock-refresh-token-${account.user.id}',
      );
      await _storage.saveDemoUserEmail(account.user.email);
      return _cachedUser!;
    }

    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;

      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      _cachedUser = user;
      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthFailure(message: 'Invalid username or password.');
      }
      if (e.response?.statusCode == 400) {
        final data = e.response?.data;
        final rawErrors = data is Map
            ? (data['field_errors'] ?? data['errors'])
            : null;
        if (rawErrors is Map) {
          throw ValidationFailure(
            message: data?['message']?.toString() ??
                'Please correct the highlighted fields.',
            fieldErrors: rawErrors.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
          );
        }
      }
      throw ServerFailure(
        message: e.response?.data?['message'] ?? 'Login failed. Please try again.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      if (!_config.enableMockMode) {
        await _dio.post('/auth/logout');
      }
    } catch (_) {
      // MOB-AUTH-006: clear local credentials even if network call fails
    } finally {
      await _storage.clearTokens();
      _cachedUser = null;
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;

    final hasToken = await _storage.hasValidSession();
    if (!hasToken) return null;

    if (_config.enableMockMode) {
      final email = await _storage.getDemoUserEmail();
      _cachedUser = (email == null ? null : MockCatalog.accountFor(email))?.user;
      return _cachedUser;
    }

    try {
      final response = await _dio.get('/auth/me');
      _cachedUser = User.fromJson(response.data as Map<String, dynamic>);
      return _cachedUser;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    return await _storage.hasValidSession();
  }
}
