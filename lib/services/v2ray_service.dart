import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'settings_store.dart';

/// Простой семафор — ограничивает, сколько проверок пинга может идти
/// одновременно. Полностью параллельно (все сразу) нативный движок
/// V2Ray не тянет — тестовые прокси-порты начинают конфликтовать, и
/// почти все проверки, кроме одной, ложно показывают "недоступен".
/// Но и строго по одной — медленно. 3 одновременно — рабочий компромисс.
class _Semaphore {
  final int maxConcurrent;
  int _current = 0;
  final _waiting = <Completer<void>>[];
  _Semaphore(this.maxConcurrent);

  Future<void> acquire() async {
    if (_current < maxConcurrent) {
      _current++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future;
    _current++;
  }

  void release() {
    _current--;
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    }
  }
}

/// Обёртка над flutter_v2ray, которая держит состояние подключения
/// и уведомляет UI через ChangeNotifier.
class V2RayService extends ChangeNotifier {
  late final FlutterV2ray _v2ray;
  bool _initialized = false;
  final _Semaphore _pingSemaphore = _Semaphore(3);

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
  /// Возвращает -1, если сервер реально недоступен. Не более 3 таких
  /// проверок выполняются одновременно (см. _Semaphore выше), плюс
  /// одна повторная попытка, если первая не удалась.
  Future<int> pingServer(String shareLink) async {
    await _pingSemaphore.acquire();
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final parsed = FlutterV2ray.parseFromURL(shareLink);
          final delay = await _v2ray
              .getServerDelay(config: parsed.getFullConfiguration())
              .timeout(const Duration(seconds: 15));
          if (delay > 0) return delay;
        } catch (_) {
          // пробуем ещё раз ниже
        }
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      return -1;
    } finally {
      _pingSemaphore.release();
    }
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
