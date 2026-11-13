import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/preferences_service.dart';

class BackendSettings extends Equatable {
  final String host;
  final int port;
  final bool useTls;
  final bool useMock;

  const BackendSettings({
    this.host = 'cleanbot.local',
    this.port = 8000,
    this.useTls = false,
    this.useMock = false,
  });

  String get scheme => useTls ? 'https' : 'http';
  String get wsScheme => useTls ? 'wss' : 'ws';

  String get apiBaseUrl => '$scheme://$host:$port/api/v1';

  String get wsBaseUrl => '$wsScheme://$host:$port/api/v1/ws';

  String get displayAddress => '$host:$port';

  BackendSettings copyWith({
    String? host,
    int? port,
    bool? useTls,
    bool? useMock,
  }) {
    return BackendSettings(
      host: host ?? this.host,
      port: port ?? this.port,
      useTls: useTls ?? this.useTls,
      useMock: useMock ?? this.useMock,
    );
  }

  @override
  List<Object?> get props => [host, port, useTls, useMock];
}

class BackendSettingsNotifier extends Notifier<BackendSettings> {
  @override
  BackendSettings build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return BackendSettings(
      host: prefs.getBackendHost(),
      port: prefs.getBackendPort(),
      useTls: prefs.getBackendUseTls(),
      useMock: prefs.getBackendUseMock(),
    );
  }

  Future<void> save(BackendSettings settings) async {
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setBackendHost(settings.host.trim());
    await prefs.setBackendPort(settings.port);
    await prefs.setBackendUseTls(settings.useTls);
    await prefs.setBackendUseMock(settings.useMock);
    state = settings.copyWith(host: settings.host.trim());
  }
}

final backendSettingsProvider =
    NotifierProvider<BackendSettingsNotifier, BackendSettings>(
  BackendSettingsNotifier.new,
);
