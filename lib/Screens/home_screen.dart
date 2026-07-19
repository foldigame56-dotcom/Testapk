import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:provider/provider.dart';
import '../services/server_store.dart';
import '../services/v2ray_service.dart';
import '../theme/app_theme.dart';
import 'servers_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;

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
      await v2ray.connect(store.selectedServer!);
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
      appBar: AppBar(title: const Text('GradelVPN')),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: _busy ? null : _toggle,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected
                      ? AppTheme.connectedGreen.withOpacity(0.15)
                      : AppTheme.surface,
                  border: Border.all(
                    color: connected ? AppTheme.connectedGreen : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: _busy
                      ? const CircularProgressIndicator()
                      : Icon(
                          Icons.power_settings_new,
                          size: 64,
                          color: connected
                              ? AppTheme.connectedGreen
                              : Colors.grey,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              connected ? 'ПОДКЛЮЧЕНО' : 'ОТКЛЮЧЕНО',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: connected ? AppTheme.connectedGreen : Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 32),
            const Spacer(),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.dns, color: AppTheme.accent),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
