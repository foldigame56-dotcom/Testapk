import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'settings_store.dart';

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
  /// Возвращает -1, если сервер реально недоступен.
  ///
  /// Важно: нативный движок V2Ray поднимает локальный тестовый прокси для
  /// каждой проверки и не всегда успевает освободить порт мгновенно после
  /// предыдущей — из-за этого при частых подряд идущих проверках все, кроме
  /// первой, ошибочно выглядели как "недоступен". Плюс лочим проверки
  /// одну за другой (даже если экран дёрнет несколько параллельно) и
  /// делаем повторную попытку, если первая не удалась.
  Future<int>? _pingQueue;

  Future<int> pingServer(String shareLink) async {
    final previous = _pingQueue ?? Future.value(0);
    final completer = Completer<int>();
    _pingQueue = completer.future;

    // Ждём завершения предыдущей проверки, прежде чем начинать эту.
    await previous.catchError((_) => -1);

    int result = -1;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final parsed = FlutterV2ray.parseFromURL(shareLink);
        final delay = await _v2ray
            .getServerDelay(config: parsed.getFullConfiguration())
            .timeout(const Duration(seconds: 15));
        if (delay > 0) {
          result = delay;
          break;
        }
      } catch (_) {
        // пробуем ещё раз ниже
      }
      if (attempt == 0) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    completer.complete(result);
    return result;
  }

  Future<void> connect(String shareLink, {SettingsStore? settings}) async {
    final parsed = FlutterV2ray.parseFromURL(shareLink);
    connectedRemark = parsed.remark.isNotEmpty ? parsed.remark : 'VPN';
    await _v2ray.startV2Ray(
      remark: connectedRemark!,
      config: parsed.getFullConfiguration(),
      bypassSubnets: (settings?.bypassLan ?? false) ? lanBypassSubnets : null,
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
