enum AppEnvironment { dev, staging, prod }

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

  String get environmentLabel {
    switch (environment) {
      case AppEnvironment.dev:
        return 'Development (Mock/Local)';
      case AppEnvironment.staging:
        return 'Staging';
      case AppEnvironment.prod:
        return 'Production';
    }
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

