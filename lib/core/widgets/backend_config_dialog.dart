import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/backend_settings.dart';
import '../theme/app_colors.dart';

Future<void> showBackendConfigDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const BackendConfigDialog(),
  );
}

class BackendConfigDialog extends ConsumerStatefulWidget {
  const BackendConfigDialog({super.key});

  @override
  ConsumerState<BackendConfigDialog> createState() =>
      _BackendConfigDialogState();
}

class _BackendConfigDialogState extends ConsumerState<BackendConfigDialog> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late bool _useTls;
  late bool _useMock;

  bool _isTesting = false;
  String? _testMessage;
  bool _testSucceeded = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(backendSettingsProvider);
    _hostController = TextEditingController(text: settings.host);
    _portController = TextEditingController(text: settings.port.toString());
    _useTls = settings.useTls;
    _useMock = settings.useMock;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      setState(() {
        _testSucceeded = false;
        _testMessage = 'Enter a valid host and port.';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    final scheme = _useTls ? 'https' : 'http';
    final dio = Dio(
      BaseOptions(
        baseUrl: '$scheme://$host:$port',
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
      ),
    );

    try {
      final response = await dio.get<Map<String, dynamic>>('/api/v1/health');
      final data = response.data ?? const {};
      final rosConnected = data['ros_connected'] == true;
      setState(() {
        _testSucceeded = response.statusCode == 200;
        _testMessage = rosConnected
            ? 'Connected — ROS 2 bridge is online.'
            : 'Backend reachable. ROS 2 bridge is not connected yet.';
      });
    } catch (e) {
      setState(() {
        _testSucceeded = false;
        _testMessage = 'Cannot reach $host:$port. Check Wi-Fi and the Pi IP.';
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      setState(() {
        _testSucceeded = false;
        _testMessage = 'Enter a valid host and port.';
      });
      return;
    }

    await ref.read(backendSettingsProvider.notifier).save(
          BackendSettings(
            host: host,
            port: port,
            useTls: _useTls,
            useMock: _useMock,
          ),
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Raspberry Pi Backend'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the address of the FastAPI + ROS 2 service running on the robot.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryFor(Theme.of(context).brightness),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hostController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Host / IP address',
                hintText: 'cleanbot.local or 192.168.1.50',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '8000',
                prefixIcon: Icon(Icons.lan_outlined),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _useTls,
              onChanged: (value) => setState(() => _useTls = value),
              title: const Text('Use HTTPS / WSS'),
              subtitle: const Text('Enable when the Pi is behind TLS'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _useMock,
              onChanged: (value) => setState(() => _useMock = value),
              title: const Text('Use demo data'),
              subtitle: const Text(
                'Turn off to control the real Raspberry Pi robot',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering, size: 18),
              label: Text(_isTesting ? 'Testing…' : 'Test connection'),
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _testSucceeded
                      ? AppColors.softBlue
                      : (isDark
                          ? AppColors.darkElevated
                          : AppColors.paleBlue),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderFor(
                    Theme.of(context).brightness,
                  )),
                ),
                child: Text(
                  _testMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimaryFor(
                      Theme.of(context).brightness,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
