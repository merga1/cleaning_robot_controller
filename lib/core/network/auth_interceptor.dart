import 'package:dio/dio.dart';
import '../security/secure_storage_service.dart';

class AuthInterceptor extends QueuedInterceptor {
  final SecureStorageService _storageService;
  final Dio _refreshDio;
  final String _refreshEndpoint;
  final void Function()? onSessionExpired;

  AuthInterceptor({
    required SecureStorageService storageService,
    required Dio refreshDio,
    required String refreshEndpoint,
    this.onSessionExpired,
  })  : _storageService = storageService,
        _refreshDio = refreshDio,
        _refreshEndpoint = refreshEndpoint;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storageService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          // Attempt automatic token refresh (MOB-AUTH-004)
          final response = await _refreshDio.post(
            _refreshEndpoint,
            data: {'refresh_token': refreshToken},
          );

          if (response.statusCode == 200 && response.data != null) {
            final newAccessToken = response.data['access_token'] as String;
            final newRefreshToken =
                (response.data['refresh_token'] as String?) ?? refreshToken;

            await _storageService.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
            );

            // Retry original request once with new token
            final originalOptions = err.requestOptions;
            originalOptions.headers['Authorization'] = 'Bearer $newAccessToken';

            final retryResponse = await _refreshDio.fetch(originalOptions);
            return handler.resolve(retryResponse);
          }
        } catch (_) {
          // Refresh failed, clear credentials and notify (MOB-AUTH-005)
          await _storageService.clearTokens();
          onSessionExpired?.call();
        }
      } else {
        await _storageService.clearTokens();
        onSessionExpired?.call();
      }
    }
    handler.next(err);
  }
}

