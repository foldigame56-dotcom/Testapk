import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:provider/provider.dart';
import '../services/server_store.dart';
import '../services/v2ray_service.dart';
import '../services/settings_store.dart';
import '../services/ping_store.dart';
import '../theme/app_theme.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String _statusText = '';
  bool _autoConnectTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoConnect());
  }

  Future<void> _maybeAutoConnect() async {
    if (_autoConnectTried) return;
    _autoConnectTried = true;
    final settings = context.read<SettingsStore>();
    final store = context.read<ServerStore>();
    final v2ray = context.read<V2RayService>();
    final hasTarget = store.autoSelectEnabled || store.selectedServer != null;
    if (settings.autoConnect && hasTarget && !v2ray.isConnected) {
      await _toggle();
    }
  }

  String _remarkFor(String link) {
    try {
      final parsed = FlutterV2ray.parseFromURL(link);
      return parsed.remark.isNotEmpty ? parsed.remark : 'Сервер';
    } catch (_) {
      return 'Сервер';
    }
  }

  Future<void> _toggle() async {
    final v2ray = context.read<V2RayService>();
    final store = context.read<ServerStore>();
    final settings = context.read<SettingsStore>();
    final pingStore = context.read<PingStore>();

    if (v2ray.isConnected) {
      setState(() => _busy = true);
      await v2ray.disconnect();
      setState(() {
        _busy = false;
        _statusText = '';
      });
      return;
    }

    String? target = store.selectedServer;

    if (store.autoSelectEnabled) {
      if (store.servers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Список серверов пуст')),
        );
        return;
      }
      setState(() {
        _busy = true;
        _statusText = 'Проверяю все сервера...';
      });
      target = await pingStore.findBest(store.servers);
      if (target == null) {
        setState(() {
          _busy = false;
          _statusText = '';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ни один сервер не ответил, попробуй позже')),
          );
        }
        return;
      }
      store.setAutoSelectedLink(target);
    } else if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выбери сервер')),
      );
      return;
    }

    setState(() {
      _busy = true;
      _statusText = 'Подключаюсь...';
    });
    final granted = await v2ray.requestPermission();
    if (!granted) {
      setState(() {
        _busy = false;
        _statusText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужно разрешение на VPN-соединение')),
        );
      }
      return;
    }
    try {
      await v2ray.connect(target, settings: settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подключения: $e')),
        );
      }
    }
    setState(() {
      _busy = false;
      _statusText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final v2ray = context.watch<V2RayService>();
    final store = context.watch<ServerStore>();
    final connected = v2ray.isConnected;

    final String currentServerLabel;
    if (store.autoSelectEnabled) {
      currentServerLabel = store.autoSelectedLink != null
          ? '⚡ ${_remarkFor(store.autoSelectedLink!)} (авто)'
          : '⚡ Автовыбор';
    } else if (store.selectedServer != null) {
      currentServerLabel = _remarkFor(store.selectedServer!);
    } else {
      currentServerLabel = 'Сервер не выбран';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'GradelVPN',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: _busy ? null : _toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: connected
                      ? AppTheme.connectedGradient
                      : AppTheme.accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: (connected
                              ? AppTheme.connectedGreen
                              : AppTheme.electricBlue)
                          .withOpacity(0.45),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: _busy
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Icon(
                          Icons.power_settings_new,
                          size: 68,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _busy
                  ? _statusText.isNotEmpty
                      ? _statusText.toUpperCase()
                      : 'ПОДКЛЮЧЕНИЕ...'
                  : connected
                      ? 'ПОДКЛЮЧЕНО'
                      : 'ОТКЛЮЧЕНО',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: connected ? AppTheme.connectedGreen : Colors.grey,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (connected) ...[
              const SizedBox(height: 6),
              Text(
                currentServerLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.surface,
                          AppTheme.surfaceLight.withOpacity(0.6),
                        ],
                      ),
                      border: Border.all(
                        color: store.autoSelectEnabled
                            ? AppTheme.gold
                            : AppTheme.surfaceLight,
                      ),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: Icon(
                        store.autoSelectEnabled
                            ? Icons.bolt_rounded
                            : Icons.dns_rounded,
                        color:
                            store.autoSelectEnabled ? AppTheme.gold : AppTheme.cyan,
                      ),
                      title: Text(currentServerLabel),
                      subtitle: Text('${store.servers.length} серверов доступно'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ServersScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.upload_rounded,
                          label: 'Отдано',
                          value: _formatSpeed(v2ray.status.uploadSpeed),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.download_rounded,
                          label: 'Получено',
                          value: _formatSpeed(v2ray.status.downloadSpeed),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.timer_outlined,
                          label: 'Время',
                          value: v2ray.status.duration.isNotEmpty
                              ? v2ray.status.duration
                              : '—',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatSpeed(int? bytesPerSecond) {
    final v = bytesPerSecond ?? 0;
    if (v <= 0) return '0 Кб/с';
    if (v >= 1024 * 1024) {
      return '${(v / (1024 * 1024)).toStringAsFixed(1)} Мб/с';
    }
    return '${(v / 1024).toStringAsFixed(0)} Кб/с';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.cyan),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
