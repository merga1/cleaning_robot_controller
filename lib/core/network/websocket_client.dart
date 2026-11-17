import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../security/secure_storage_service.dart';
import 'api_client.dart';

enum WebSocketConnectionState {
  connecting,
  connected,
  disconnected,
}

class WebSocketMessage {
  final String robotId;
  final String type;
  /// Always compared in UTC (MOB-RT-006).
  final DateTime timestamp;
  final bool isSimulated;
  /// Monotonic sequence id when supplied by the backend.
  final int sequence;
  final Map<String, dynamic> payload;

  WebSocketMessage({
    required this.robotId,
    required this.type,
    required this.timestamp,
    required this.isSimulated,
    required this.payload,
    this.sequence = 0,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    final parsed = json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String)
        : null;
    return WebSocketMessage(
      robotId: json['robot_id'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      // A missing timestamp is marked epoch so it can never poison the
      // freshness guard for later, correctly timestamped messages.
      timestamp: (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc(),
      isSimulated: json['is_simulated'] as bool? ?? false,
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }
}

final webSocketClientProvider = Provider<CleanBotWebSocketClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final client = CleanBotWebSocketClient(
    config: config,
    storageService: secureStorage,
  );
  ref.onDispose(() => client.dispose());
  return client;
});

class CleanBotWebSocketClient {
  final AppConfig _config;
  final SecureStorageService _storageService;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  int _reconnectAttempts = 0;
  final Random _random = Random();
  DateTime _lastMessageTime =
      DateTime.fromMillisecondsSinceEpoch(0).toUtc();
  int _lastSequence = 0;

  final _stateController = StreamController<WebSocketConnectionState>.broadcast();
  final _messageController = StreamController<WebSocketMessage>.broadcast();

  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;
  Stream<WebSocketMessage> get messageStream => _messageController.stream;

  WebSocketConnectionState _currentState = WebSocketConnectionState.disconnected;
  WebSocketConnectionState get currentState => _currentState;

  CleanBotWebSocketClient({
    required AppConfig config,
    required SecureStorageService storageService,
  })  : _config = config,
        _storageService = storageService;

  Future<void> connect() async {
    if (_currentState == WebSocketConnectionState.connected ||
        _currentState == WebSocketConnectionState.connecting) {
      return;
    }

    // Frontend-only demo mode never opens a real socket. The dashboard uses
    // MockTelemetryService instead.
    if (_config.enableMockMode) {
      _updateState(WebSocketConnectionState.connected);
      return;
    }

    _updateState(WebSocketConnectionState.connecting);

    final token = await _storageService.getAccessToken();
    if (token == null || token.isEmpty) {
      _updateState(WebSocketConnectionState.disconnected);
      _scheduleReconnect();
      return;
    }

    // The token belongs to the signed-in user (never an embedded secret) and
    // is URL-encoded so special characters cannot corrupt the request.
    final wsUri = Uri.parse(
      '${_config.wsBaseUrl}?token=${Uri.encodeQueryComponent(token)}',
    );

    try {
      _reconnectTimer?.cancel();
      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;

      _updateState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
      _lastMessageTime = DateTime.fromMillisecondsSinceEpoch(0).toUtc();
      _lastSequence = 0;

      _subscription = _channel!.stream.listen(
        (data) => _onMessageReceived(data),
        onError: (error) => _handleDisconnect(),
        onDone: () => _handleDisconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _onMessageReceived(dynamic rawData) {
    try {
      final jsonMap = jsonDecode(rawData as String) as Map<String, dynamic>;
      final message = WebSocketMessage.fromJson(jsonMap);

      // MOB-RT-006: Ignore out-of-order or duplicate live messages. Sequence
      // ids take precedence; otherwise compare timestamps in UTC and accept
      // equal timestamps from different events.
      if (message.sequence > 0) {
        if (message.sequence <= _lastSequence) return;
        _lastSequence = message.sequence;
      } else if (message.timestamp.isBefore(_lastMessageTime)) {
        return;
      }
      if (message.timestamp.isAfter(_lastMessageTime)) {
        _lastMessageTime = message.timestamp;
      }

      _messageController.add(message);
    } catch (_) {
      // Discard malformed packets
    }
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _updateState(WebSocketConnectionState.disconnected);

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // MOB-RT-003: Exponential backoff with jitter
    _reconnectAttempts++;
    final baseDelayMs = min(1000 * pow(2, _reconnectAttempts), 30000).toInt();
    final jitterMs = _random.nextInt(1000);
    final delay = Duration(milliseconds: baseDelayMs + jitterMs);

    _reconnectTimer = Timer(delay, () => connect());
  }

  void _updateState(WebSocketConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _updateState(WebSocketConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _messageController.close();
  }
}

