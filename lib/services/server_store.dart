import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

const _kSubUrlKey = 'subscription_url';
const _kServersKey = 'servers_list';
const _kSelectedKey = 'selected_server';

/// Хранит ссылку на подписку (которую выдаёт бот) и список серверов,
/// полученных из неё. Переживает перезапуск приложения.
class ServerStore extends ChangeNotifier {
  String? subscriptionUrl;
  List<String> servers = [];
  String? selectedServer;
  bool loading = false;
  String? lastError;

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    subscriptionUrl = prefs.getString(_kSubUrlKey);
    servers = prefs.getStringList(_kServersKey) ?? [];
    selectedServer = prefs.getString(_kSelectedKey);
    notifyListeners();
  }

  Future<void> setSubscriptionUrl(String url) async {
    subscriptionUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSubUrlKey, url);
    notifyListeners();
  }

  Future<void> refreshServers() async {
    if (subscriptionUrl == null || subscriptionUrl!.isEmpty) {
      lastError = 'Сначала добавь ссылку на подписку от бота';
      notifyListeners();
      return;
    }
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      final fetched = await SubscriptionService.fetchServers(subscriptionUrl!);
      servers = fetched;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kServersKey, servers);
      // Если выбранного сервера больше нет в списке — сбрасываем выбор.
      if (selectedServer != null && !servers.contains(selectedServer)) {
        selectedServer = null;
        await prefs.remove(_kSelectedKey);
      }
    } catch (e) {
      lastError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectServer(String link) async {
    selectedServer = link;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedKey, link);
    notifyListeners();
  }
}
