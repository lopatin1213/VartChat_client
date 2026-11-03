import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../services/protocol.dart';

class UserProfileScreen extends StatefulWidget {
  final WebSocketService wsService;
  final String username;
  final String myUsername;

  const UserProfileScreen({
    super.key,
    required this.wsService,
    required this.username,
    required this.myUsername,
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
  String? _fetchedUsername;

  bool _isLoading = true;
  bool _hasLoaded = false;
  StreamSubscription? _sub;

  final _fnameCtrl = TextEditingController();
  final _lnameCtrl = TextEditingController();
  final _dnameCtrl = TextEditingController();
  final _unameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool get _isMe => widget.username == widget.myUsername;

  @override
  void initState() {
    super.initState();
    _sub = widget.wsService.onMessage.listen(_handleMessage);
    widget.wsService.sendCommand('/profile ${widget.username}');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fnameCtrl.dispose();
    _lnameCtrl.dispose();
    _dnameCtrl.dispose();
    _unameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _handleMessage(Uint8List data) {
    try {
      final parsed = Protocol.parsePacket(data);
      if (parsed.type == Protocol.MSG_TYPE_SYSTEM) {
        final text = Protocol.readString(parsed.payload, 0);
        if (text.startsWith('[Система] Профиль|')) {
          final parts = text.substring('[Система] Профиль|'.length).split('|');
          if (parts.length >= 8) {
            setState(() {
              _fetchedUsername = parts[0];
              _phone = parts[1];
              _firstName = parts[2];
              _lastName = parts[3];
              _displayName = parts[4];
              _bio = parts[5];
              _status = parts[6];
              final lastSeen = int.tryParse(parts[7]) ?? 0;

              // ЛОГИКА СТАТУСА
              if (_status == 'скрыт' || (_status == 'офлайн' && lastSeen == 0)) {
                _status = 'был(а) недавно';
              } else if (_status == 'офлайн' && lastSeen > 0) {
                final dt = DateTime.fromMillisecondsSinceEpoch(lastSeen);
                final now = DateTime.now();
                final diff = now.difference(dt);

                if (diff.inMinutes < 60) {
                  _status = 'был(а) ${diff.inMinutes} мин назад';
                } else if (diff.inHours < 24 && now.day == dt.day) {
                  _status = 'был(а) в ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                } else {
                  _status = 'был(а) ${dt.day}.${dt.month.toString().padLeft(2, '0')}';
                }
              } else if (_status == 'онлайн') {
                _status = 'в сети';
              }

              _isLoading = false;

              if (_isMe && !_hasLoaded) {
                _fnameCtrl.text = _firstName ?? '';
                _lnameCtrl.text = _lastName ?? '';
                _dnameCtrl.text = _displayName ?? '';
                _unameCtrl.text = _fetchedUsername ?? '';
                _bioCtrl.text = _bio ?? '';
                _hasLoaded = true;
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  void _saveProfile() {
    final fname = _fnameCtrl.text.trim();
    final lname = _lnameCtrl.text.trim();
    final dname = _dnameCtrl.text.trim();
    final uname = _unameCtrl.text.trim();
    final bio = _bioCtrl.text.trim();

    if (uname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username не может быть пустым')),
      );
      return;
    }

    final cmd = '/update_profile $fname|$lname|$dname|$uname|$bio';
    widget.wsService.sendCommand(cmd);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Профиль обновлен!'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      _firstName = fname;
      _lastName = lname;
      _displayName = dname;
      _fetchedUsername = uname;
      _bio = bio;
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final initials = (_displayName?.isNotEmpty == true) ? _displayName![0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMe ? 'Мой профиль' : (_displayName ?? widget.username)),
      ),
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
              _displayName ?? _fetchedUsername ?? widget.username,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '@${_fetchedUsername ?? widget.username}',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _status ?? 'был(а) недавно',
              style: TextStyle(
                color: _status == 'в сети' ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            if (_isMe) ...[
              TextField(
                controller: _fnameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lnameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Фамилия',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dnameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Отображаемое имя',
                  border: OutlineInputBorder(),
                  helperText: 'Как вас видят другие',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _unameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                  border: OutlineInputBorder(),
                  helperText: 'Уникальный ник',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioCtrl,
                decoration: const InputDecoration(
                  labelText: 'О себе',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.save),
                  label: const Text('Сохранить изменения'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ] else ...[
              Card(
                child: Column(
                  children: [
                    if (_firstName != null && _firstName!.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.badge),
                        title: const Text('Имя'),
                        subtitle: Text('$_firstName ${_lastName ?? ''}'.trim()),
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
          ],
        ),
      ),
    );
  }
}