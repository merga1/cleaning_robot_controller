/// Shared local-time formatting for values supplied as UTC by the backend or
/// by the mock catalog. Keeping this in one place avoids per-screen formats.
String _twoDigits(int n) => n.toString().padLeft(2, '0');

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String formatTime(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String formatRelative(DateTime value, {DateTime? now}) {
  final difference = (now ?? DateTime.now().toUtc()).difference(value.toUtc());
  final seconds = difference.inSeconds;
  if (seconds < 60) return 'just now';
  final minutes = difference.inMinutes;
  if (minutes < 60) return '${minutes}m ago';
  final hours = difference.inHours;
  if (hours < 24) return '${hours}h ${minutes % 60}m ago';
  final days = difference.inDays;
  if (days < 30) return '${days}d ago';
  final months = days ~/ 30;
  return '${months}mo ago';
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}
