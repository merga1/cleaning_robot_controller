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
    final bgColor = isConnecting ? AppColors.techOrange : AppColors.deepNavy;

    final message = isConnecting
        ? 'Reconnecting to CleanBot real-time telemetry…'
        : 'Real-time telemetry paused. Showing cached state.';

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
                color: AppColors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isConnecting && onRetry != null)
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.techOrange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
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
