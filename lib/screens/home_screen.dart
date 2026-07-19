import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:provider/provider.dart';
import '../services/server_store.dart';
import '../services/v2ray_service.dart';
import '../services/settings_store.dart';
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
    if (settings.autoConnect &&
        store.selectedServer != null &&
        !v2ray.isConnected) {
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

    if (v2ray.isConnected) {
      setState(() => _busy = true);
      await v2ray.disconnect();
      setState(() => _busy = false);
      return;
    }

    if (store.selectedServer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выбери сервер')),
      );
      return;
    }

    setState(() => _busy = true);
    final granted = await v2ray.requestPermission();
    if (!granted) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужно разрешение на VPN-соединение')),
        );
      }
      return;
    }
    try {
      await v2ray.connect(store.selectedServer!, settings: settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подключения: $e')),
        );
      }
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final v2ray = context.watch<V2RayService>();
    final store = context.watch<ServerStore>();
    final connected = v2ray.isConnected;

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
              connected ? 'ПОДКЛЮЧЕНО' : 'ОТКЛЮЧЕНО',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: connected ? AppTheme.connectedGreen : Colors.grey,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.surface,
                      AppTheme.surfaceLight.withOpacity(0.6),
                    ],
                  ),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: const Icon(Icons.dns_rounded, color: AppTheme.cyan),
                  title: Text(
                    store.selectedServer != null
                        ? _remarkFor(store.selectedServer!)
                        : 'Сервер не выбран',
                  ),
                  subtitle: Text('${store.servers.length} серверов доступно'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ServersScreen()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
