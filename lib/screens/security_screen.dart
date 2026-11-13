import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../services/protocol.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import 'sessions_screen.dart';
import 'login_screen.dart';

class SecurityScreen extends StatefulWidget {
  final WebSocketService wsService;

  const SecurityScreen({super.key, required this.wsService});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.wsService.onMessage.listen(_handleMessage);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleMessage(Uint8List data) {
    try {
      final parsed = Protocol.parsePacket(data);

      if (parsed.type == Protocol.MSG_TYPE_LOGOUT) {
        final reason = Protocol.parseLogoutFromServer(parsed.payload);
        StorageService.clearAll();
        DatabaseService.clearData();
        widget.wsService.disconnect();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(reason), backgroundColor: Colors.red),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        }
        return;
      }

      if (parsed.type == Protocol.MSG_TYPE_SYSTEM) {
        final text = Protocol.readString(parsed.payload, 0);
        if (text.contains('Неверный пароль')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Неверный пароль — аккаунт не удалён',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _showDeleteAccountDialog() async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Аккаунт и все ваши сообщения будут удалены безвозвратно через 7 дней.\n\nВы точно хотите удалить аккаунт?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => const _PasswordPromptDialog(),
    );
    if (password == null || password.isEmpty || !mounted) return;

    try {
      final token = await StorageService.getToken();
      if (token != null) {
        await widget.wsService.sendDeleteAccount(token, password);
        await Future.delayed(const Duration(milliseconds: 600));
      }
    } catch (e) {
      print('[UI] Ошибка отправки delete_account: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Безопасность')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Активные сессии'),
            subtitle: const Text('Устройства, на которых выполнен вход'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionsScreen(wsService: widget.wsService),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Удалить аккаунт',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Безвозвратное удаление через 7 дней'),
            onTap: _showDeleteAccountDialog,
          ),
        ],
      ),
    );
  }
}

class _PasswordPromptDialog extends StatefulWidget {
  const _PasswordPromptDialog();

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Подтверждение'),
      content: TextField(
        controller: _ctrl,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Пароль'),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Подтвердить'),
        ),
      ],
    );
  }
}