import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/server_store.dart';
import '../services/v2ray_service.dart';
import '../widgets/server_tile.dart';
import 'subscription_screen.dart';

class ServersScreen extends StatefulWidget {
  const ServersScreen({super.key});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  final Map<String, int> _pings = {};
  final Set<String> _pinging = {};

  Future<void> _pingOne(String link) async {
    final v2ray = context.read<V2RayService>();
    setState(() => _pinging.add(link));
    final ms = await v2ray.pingServer(link);
    if (!mounted) return;
    setState(() {
      _pings[link] = ms;
      _pinging.remove(link);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServerStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Серверы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: store.refreshServers,
        child: store.servers.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade600),
                  const SizedBox(height: 12),
                  const Center(child: Text('Список серверов пуст')),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      ),
                      child: const Text('Добавить подписку'),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: store.servers.length,
                itemBuilder: (context, i) {
                  final link = store.servers[i];
                  return ServerTile(
                    link: link,
                    selected: store.selectedServer == link,
                    pingMs: _pings[link],
                    pinging: _pinging.contains(link),
                    onTap: () => store.selectServer(link),
                    onPing: () => _pingOne(link),
                  );
                },
              ),
      ),
    );
  }
}
