import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/websocket_service.dart';
import '../services/protocol.dart';

class UserProfileScreen extends StatefulWidget {
  final WebSocketService wsService;
  final String username;

  const UserProfileScreen({
    super.key,
    required this.wsService,
    required this.username,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String? _phone;
  String? _firstName;
  String? _lastName;
  String? _displayName;
  String? _bio;
  String? _status;
  bool _isLoading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.wsService.onMessage.listen(_handleMessage);
    widget.wsService.sendCommand('/profile ${widget.username}');
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
          if (parts.length >= 7) {
            setState(() {
              // parts[0] - username
              _phone = parts[1];
              _firstName = parts[2];
              _lastName = parts[3];
              _displayName = parts[4];
              _bio = parts[5];
              _status = parts[6];
              _isLoading = false;
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final initials = (_displayName?.isNotEmpty == true) ? _displayName![0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: Text(_displayName ?? widget.username)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              child: Text(initials, style: const TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: 16),
            Text(
              _displayName ?? widget.username,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '@${widget.username}',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _status ?? 'был(а) недавно',
              style: TextStyle(
                color: _status == 'онлайн' ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  if (_firstName != null && _firstName!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.badge),
                      title: const Text('Имя'),
                      subtitle: Text('$_firstName $_lastName'),
                    ),
                  if (_phone != null && _phone!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('Телефон'),
                      subtitle: Text(_phone!),
                    ),
                  if (_bio != null && _bio!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('О себе'),
                      subtitle: Text(_bio!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}