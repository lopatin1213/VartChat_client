import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../services/protocol.dart';

class PrivacySettingsScreen extends StatefulWidget {
  final WebSocketService wsService;

  const PrivacySettingsScreen({super.key, required this.wsService});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isLoading = true;
  bool _hidePhone = false;
  int _lastSeenPrivacy = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.wsService.onMessage.listen(_handleMessage);
    widget.wsService.sendCommand('/profile');
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
        if (text.startsWith('[Система] Профиль|')) {
          final parts = text.substring('[Система] Профиль|'.length).split('|');
          if (parts.length >= 10) {
            setState(() {
              _hidePhone = parts[8] == 'true';
              _lastSeenPrivacy = int.tryParse(parts[9]) ?? 0;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('>>> [PRIVACY] Ошибка парсинга: $e');
    }
  }

  void _sendSettings() {
    widget.wsService.sendCommand('/update_settings ${_hidePhone ? 1 : 0}|$_lastSeenPrivacy');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Приватность'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Скрыть номер телефона'),
            subtitle: const Text('Другие пользователи не увидят ваш номер'),
            value: _hidePhone,
            onChanged: (v) {
              setState(() => _hidePhone = v);
              _sendSettings();
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Text(
              'Кто видит "был(а) в сети"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          // Оборачиваем в RadioGroup для нового API Flutter
          RadioGroup<int>(
            groupValue: _lastSeenPrivacy,
            onChanged: (int? value) {
              if (value != null) {
                setState(() => _lastSeenPrivacy = value);
                _sendSettings();
              }
            },
            child: const Column(
              children: [
                RadioListTile<int>(
                  title: Text('Все'),
                  value: 0,
                ),
                RadioListTile<int>(
                  title: Text('Только контакты'),
                  value: 1,
                ),
                RadioListTile<int>(
                  title: Text('Никто'),
                  value: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}