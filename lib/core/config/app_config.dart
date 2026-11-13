import 'backend_settings.dart';

enum AppEnvironment { dev, pi, staging, prod }

class AppConfig {
  final AppEnvironment environment;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final bool enableMockMode;
  final Duration connectionTimeout;
  final Duration receiveTimeout;
  final Duration commandAckTimeout;
  final Duration staleDataThreshold;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    this.enableMockMode = false,
    this.connectionTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.commandAckTimeout = const Duration(seconds: 10),
    this.staleDataThreshold = const Duration(seconds: 20),
  });

  bool get isProduction => environment == AppEnvironment.prod;

  bool get isLiveRobot => environment == AppEnvironment.pi;

  String get environmentLabel {
    switch (environment) {
      case AppEnvironment.dev:
        return enableMockMode ? 'Development (Demo data)' : 'Development';
      case AppEnvironment.pi:
        return 'Raspberry Pi (Live Robot)';
      case AppEnvironment.staging:
        return 'Staging';
      case AppEnvironment.prod:
        return 'Production';
    }
  }

  /// Builds a config from the user-selected Raspberry Pi backend.
  factory AppConfig.fromBackendSettings(BackendSettings settings) {
    return AppConfig(
      environment:
          settings.useMock ? AppEnvironment.dev : AppEnvironment.pi,
      apiBaseUrl: settings.apiBaseUrl,
      wsBaseUrl: settings.wsBaseUrl,
      enableMockMode: settings.useMock,
    );
  }

  static AppConfig dev({bool mock = true}) => AppConfig(
        environment: AppEnvironment.dev,
        apiBaseUrl: 'http://10.0.2.2:8000/api/v1',
        wsBaseUrl: 'ws://10.0.2.2:8000/api/v1/ws',
        enableMockMode: mock,
      );

  static AppConfig staging() => const AppConfig(
        environment: AppEnvironment.staging,
        apiBaseUrl: 'https://staging.cleanbot.example.com/api/v1',
        wsBaseUrl: 'wss://staging.cleanbot.example.com/api/v1/ws',
        enableMockMode: false,
      );

  static AppConfig prod() => const AppConfig(
        environment: AppEnvironment.prod,
        apiBaseUrl: 'https://api.cleanbot.example.com/api/v1',
        wsBaseUrl: 'wss://api.cleanbot.example.com/api/v1/ws',
        enableMockMode: false,
      );
}
