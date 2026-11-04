import 'package:flutter/material.dart';
import '../network/websocket_client.dart';
import '../theme/app_colors.dart';

class ConnectionBanner extends StatelessWidget {
  final WebSocketConnectionState connectionState;
  final VoidCallback? onRetry;

  const ConnectionBanner({
    super.key,
    required this.connectionState,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (connectionState == WebSocketConnectionState.connected) {
      return const SizedBox.shrink();
    }

    final isConnecting = connectionState == WebSocketConnectionState.connecting;
    final bgColor = isConnecting
        ? AppColors.severityWarning.withOpacity(0.9)
        : AppColors.severityCritical.withOpacity(0.9);

    final message = isConnecting
        ? 'Reconnecting to real-time service…'
        : 'Real-time connection lost. Showing cached data.';

    return Material(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                isConnecting ? Icons.sync : Icons.cloud_off_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!isConnecting && onRetry != null)
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

