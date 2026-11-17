import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Decouples the Dio auth interceptor from the auth controller: the network
/// layer signals expiry and the app root turns it into a logout + navigation.
final StreamController<void> _sessionExpired =
    StreamController<void>.broadcast();

void notifySessionExpired() {
  if (!_sessionExpired.isClosed) _sessionExpired.add(null);
}

final sessionExpiredProvider = StreamProvider<void>((ref) {
  // The controller is app-lifetime; do not close it when a listener is removed.
  ref.onDispose(() {});
  return _sessionExpired.stream;
});
