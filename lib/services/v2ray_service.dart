import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

/// Обёртка над flutter_v2ray, которая держит состояние подключения
/// и уведомляет UI через ChangeNotifier.
class V2RayService extends ChangeNotifier {
  late final FlutterV2ray _v2ray;
  bool _initialized = false;

  V2RayStatus status = V2RayStatus();
  String? connectedRemark;

  V2RayService() {
    _v2ray = FlutterV2ray(
      onStatusChanged: (s) {
        status = s;
        notifyListeners();
      },
    );
  }

  Future<void> init() async {
    if (_initialized) return;
    await _v2ray.initializeV2Ray();
    _initialized = true;
  }

  /// Показывает системный диалог "Разрешить приложению создавать VPN-соединения".
  /// Нужно вызвать один раз перед первым подключением.
  Future<bool> requestPermission() => _v2ray.requestPermission();

  /// Проверка задержки конкретного сервера (по share-ссылке), в мс.
  /// Возвращает -1, если сервер недоступен.
  Future<int> pingServer(String shareLink) async {
    try {
      final parsed = FlutterV2ray.parseFromURL(shareLink);
      return await _v2ray.getServerDelay(config: parsed.getFullConfiguration());
    } catch (_) {
      return -1;
    }
  }

  Future<void> connect(String shareLink) async {
    final parsed = FlutterV2ray.parseFromURL(shareLink);
    connectedRemark = parsed.remark.isNotEmpty ? parsed.remark : 'VPN';
    await _v2ray.startV2Ray(
      remark: connectedRemark!,
      config: parsed.getFullConfiguration(),
      notificationDisconnectButtonName: 'ОТКЛЮЧИТЬ',
    );
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _v2ray.stopV2Ray();
    connectedRemark = null;
    notifyListeners();
  }

  bool get isConnected => status.state == 'CONNECTED';
}
