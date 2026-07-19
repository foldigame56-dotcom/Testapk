import 'dart:convert';
import 'package:http/http.dart' as http;

/// Загружает подписку (ссылку, которую выдаёт твой Telegram-бот) и
/// превращает её в список share-ссылок (vless://, vmess://, trojan://...).
///
/// Подписки обычно отдают base64 от списка ссылок, разделённых переводом
/// строки — именно такой формат генерируют большинство панелей (3x-ui,
/// Marzban и т.п.), которыми управляют боты.
class SubscriptionService {
  static Future<List<String>> fetchServers(String subscriptionUrl) async {
    final uri = Uri.tryParse(subscriptionUrl.trim());
    if (uri == null) {
      throw const FormatException('Некорректная ссылка на подписку');
    }

    final response = await http
        .get(uri, headers: {'User-Agent': 'vless-client/1.0'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Сервер вернул ошибку ${response.statusCode}');
    }

    final body = response.body.trim();
    String decoded;
    try {
      decoded = utf8.decode(base64.decode(base64.normalize(body)));
    } catch (_) {
      // Если это не base64 — считаем, что бот уже отдал список ссылок текстом.
      decoded = body;
    }

    final links = decoded
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.contains('://'))
        .toList();

    if (links.isEmpty) {
      throw Exception('В подписке не найдено ни одного сервера');
    }
    return links;
  }
}
