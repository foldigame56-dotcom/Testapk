import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/server_store.dart';
import '../services/v2ray_service.dart';
import '../theme/app_theme.dart';
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
  bool _pingingAll = false;
  bool _autoSelecting = false;

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

  /// Проверяет все сервера — параллельно (безопасный лимит уже встроен
  /// в V2RayService, так что тут можно просто запустить всё разом).
  Future<void> _pingAll() async {
    final store = context.read<ServerStore>();
    setState(() => _pingingAll = true);
    await Future.wait(store.servers.map(_pingOne));
    if (mounted) setState(() => _pingingAll = false);
  }

  /// Пингует все сервера, выбирает тот, где меньше всего задержка,
  /// и делает его текущим выбранным сервером.
  Future<void> _autoSelectBest() async {
    final store = context.read<ServerStore>();
    if (store.servers.isEmpty) return;

    setState(() => _autoSelecting = true);
    await Future.wait(store.servers.map(_pingOne));

    String? best;
    int bestPing = 1 << 30;
    for (final link in store.servers) {
      final ping = _pings[link];
      if (ping != null && ping > 0 && ping < bestPing) {
        bestPing = ping;
        best = link;
      }
    }

    if (!mounted) return;
    setState(() => _autoSelecting = false);

    if (best == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ни один сервер не ответил, попробуй позже')),
      );
      return;
    }

    await store.selectServer(best);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Выбран лучший сервер — $bestPing мс')),
      );
    }
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} МБ';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServerStore>();
    final hasSubInfo = store.subscriptionTitle != null ||
        store.trafficTotalBytes != null ||
        store.expiresAt != null;
    final busy = _pingingAll || _autoSelecting;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Серверы'),
        actions: [
          IconButton(
            tooltip: 'Проверить все серверы',
            icon: _pingingAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            onPressed: (busy || store.servers.isEmpty) ? null : _pingAll,
          ),
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
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (hasSubInfo)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: AppTheme.accentGradient,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (store.subscriptionTitle != null)
                        Text(
                          store.subscriptionTitle!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (store.trafficTotalBytes != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Трафик: ${_formatBytes(store.trafficUsedBytes)} из ${_formatBytes(store.trafficTotalBytes)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (store.trafficUsedBytes ?? 0) /
                                (store.trafficTotalBytes ?? 1),
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                            minHeight: 6,
                          ),
                        ),
                      ],
                      if (store.expiresAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Действует до: ${store.expiresAt!.day.toString().padLeft(2, '0')}.${store.expiresAt!.month.toString().padLeft(2, '0')}.${store.expiresAt!.year}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (store.servers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: busy ? null : _autoSelectBest,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.gold, width: 1.2),
                        color: AppTheme.gold.withOpacity(0.08),
                      ),
                      child: Row(
                        children: [
                          _autoSelecting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.gold,
                                  ),
                                )
                              : const Icon(Icons.bolt_rounded,
                                  color: AppTheme.gold),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Автовыбор лучшего сервера',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.gold,
                                  ),
                                ),
                                Text(
                                  _autoSelecting
                                      ? 'Проверяю все сервера...'
                                      : 'Найдёт сервер с минимальным пингом',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (store.servers.isEmpty)
              Column(
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
            else
              ...store.servers.map((link) => ServerTile(
                    link: link,
                    selected: store.selectedServer == link,
                    pingMs: _pings[link],
                    pinging: _pinging.contains(link),
                    onTap: () => store.selectServer(link),
                    onPing: () => _pingOne(link),
                  )),
          ],
        ),
      ),
    );
  }
}
