import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../security/secure_storage_service.dart';
import 'auth_interceptor.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  // Default to dev config with mock capability as per NFR-MNT-2
  return AppConfig.dev(mock: true);
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectionTimeout,
      receiveTimeout: config.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  final refreshDio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectionTimeout,
      receiveTimeout: config.receiveTimeout,
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      storageService: secureStorage,
      refreshDio: refreshDio,
      refreshEndpoint: '/auth/refresh',
      onSessionExpired: () {
        // Handled via state listener or router redirect
      },
    ),
  );

  return dio;
});

