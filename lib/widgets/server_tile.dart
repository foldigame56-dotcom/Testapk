import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import '../theme/app_theme.dart';

class ServerTile extends StatelessWidget {
  final String link;
  final bool selected;
  final int? pingMs; // null = ещё не проверяли, -1 = недоступен
  final bool pinging;
  final VoidCallback onTap;
  final VoidCallback onPing;

  const ServerTile({
    super.key,
    required this.link,
    required this.selected,
    required this.pingMs,
    required this.pinging,
    required this.onTap,
    required this.onPing,
  });

  String get _remark {
    try {
      final parsed = FlutterV2ray.parseFromURL(link);
      return parsed.remark.isNotEmpty ? parsed.remark : link;
    } catch (_) {
      return link;
    }
  }

  Color _pingColor() {
    if (pingMs == null) return Colors.grey;
    if (pingMs == -1) return Colors.redAccent;
    if (pingMs! < 150) return AppTheme.connectedGreen;
    if (pingMs! < 400) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _pingText() {
    if (pinging) return '...';
    if (pingMs == null) return '';
    if (pingMs == -1) return 'нет связи';
    return '$pingMs мс';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? const BorderSide(color: AppTheme.accent, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? AppTheme.accent : Colors.grey,
        ),
        title: Text(_remark, overflow: TextOverflow.ellipsis),
        trailing: pinging
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onPing,
                child: Text(
                  _pingText().isEmpty ? 'ping' : _pingText(),
                  style: TextStyle(color: _pingColor()),
                ),
              ),
      ),
    );
  }
}
