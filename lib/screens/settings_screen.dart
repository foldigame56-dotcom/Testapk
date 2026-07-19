import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_store.dart';
import '../services/server_store.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final store = context.watch<ServerStore>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionTitle('VPN'),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('Обходить локальную сеть'),
                subtitle: const Text(
                  'Wi-Fi роутер, принтеры и другие устройства дома останутся доступны напрямую',
                ),
                value: settings.bypassLan,
                activeColor: AppTheme.cyan,
                onChanged: (v) => settings.setBypassLan(v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Автоподключение при запуске'),
                subtitle: const Text(
                  'Подключаться к выбранному серверу сразу при открытии приложения',
                ),
                value: settings.autoConnect,
                activeColor: AppTheme.cyan,
                onChanged: (v) => settings.setAutoConnect(v),
              ),
            ],
          ),
          _SectionTitle('Подписка'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.subscriptions_outlined,
                    color: AppTheme.cyan),
                title: Text(store.subscriptionTitle ?? 'Подписка не названа'),
                subtitle: Text('${store.servers.length} серверов в списке'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.refresh, color: AppTheme.cyan),
                title: const Text('Обновить список серверов'),
                onTap: store.loading ? null : () => store.refreshServers(),
                trailing: store.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ],
          ),
          _SectionTitle('Поддержка'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.send_outlined, color: AppTheme.cyan),
                title: const Text('Бот подписки'),
                subtitle: const Text('@gradelvpnbot'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openUrl('https://t.me/gradelvpnbot'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.campaign_outlined,
                    color: AppTheme.cyan),
                title: const Text('Канал GradelVPN'),
                subtitle: const Text('@gradelvpn'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openUrl('https://t.me/gradelvpn'),
              ),
            ],
          ),
          _SectionTitle('О приложении'),
          _SettingsCard(
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline, color: AppTheme.cyan),
                title: Text('GradelVPN'),
                subtitle: Text('Версия 1.0.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: AppTheme.cyan.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}
