import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/websocket_service.dart';
import '../services/protocol.dart';

class SessionsScreen extends StatefulWidget {
  final WebSocketService wsService;

  const SessionsScreen({super.key, required this.wsService});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _isLoading = true;
  List<({String token, String device, int lastSeen, bool isCurrent})> _sessions = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.wsService.onMessage.listen(_handleMessage);
    widget.wsService.sendCommand('/sessions');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleMessage(Uint8List data) {
    try {
      final parsed = Protocol.parsePacket(data);
      if (parsed.type == Protocol.MSG_TYPE_SYSTEM) {
        final text = Protocol.readString(parsed.payload, 0);

        if (text.startsWith('[Система] Сессии: ')) {
          final raw = text.substring('[Система] Сессии: '.length).trim();
          final List<({String token, String device, int lastSeen, bool isCurrent})> parsedSessions = [];

          if (raw.isNotEmpty) {
            final items = raw.split(', ');
            for (final item in items) {
              final parts = item.split('|');
              if (parts.length >= 4) {
                parsedSessions.add((
                token: parts[0],
                device: parts[1],
                lastSeen: int.tryParse(parts[2]) ?? 0,
                isCurrent: parts[3] == '1',
                ));
              }
            }
          }

          setState(() {
            _sessions = parsedSessions;
            _isLoading = false;
          });
        }
        else if (text == '[Система] Устройство успешно отключено') {
          widget.wsService.sendCommand('/sessions');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Устройство отключено'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (_) {}
  }

  void _killSession(String token) {
    widget.wsService.sendLogout(token, type: 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Активные сессии')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? const Center(child: Text('Нет активных сессий.'))
          : ListView.builder(
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final s = _sessions[index];
          final dt = DateTime.fromMillisecondsSinceEpoch(s.lastSeen);
          final timeStr = DateFormat('dd.MM.yyyy HH:mm').format(dt);

          return ListTile(
            leading: Icon(s.isCurrent ? Icons.phone_android : Icons.devices),
            title: Text(
              s.device,
              style: TextStyle(fontWeight: s.isCurrent ? FontWeight.bold : FontWeight.normal),
            ),
            subtitle: Text('Последняя активность: $timeStr'),
            trailing: s.isCurrent
                ? const Text('Текущее', style: TextStyle(color: Colors.green, fontSize: 12))
                : IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'Отключить',
              onPressed: () => _killSession(s.token),
            ),
          );
        },
      ),
    );
  }
}