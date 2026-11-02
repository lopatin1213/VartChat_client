import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  final WebSocketService wsService;
  final String username;

  const SettingsScreen({
    super.key,
    required this.wsService,
    required this.username,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hidePhone = false;
  int _lastSeenPrivacy = 0;

  @override
  void initState() {
    super.initState();
    // В реальном приложении мы бы запрашивали текущие настройки,
    // но для простоты поставим дефолтные или запросим через /profile
    widget.wsService.sendCommand('/profile');
  }

  void _showEditProfileDialog() {
    final fnameCtrl = TextEditingController();
    final lnameCtrl = TextEditingController();
    final dnameCtrl = TextEditingController(text: widget.username);
    final unameCtrl = TextEditingController(text: widget.username);
    final bioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать профиль'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: fnameCtrl, decoration: const InputDecoration(labelText: 'Имя')),
              TextField(controller: lnameCtrl, decoration: const InputDecoration(labelText: 'Фамилия')),
              TextField(controller: dnameCtrl, decoration: const InputDecoration(labelText: 'Отображаемое имя')),
              TextField(controller: unameCtrl, decoration: const InputDecoration(labelText: 'Username')),
              TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: 'О себе'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final cmd = '/update_profile ${fnameCtrl.text}|${lnameCtrl.text}|${dnameCtrl.text}|${unameCtrl.text}|${bioCtrl.text}';
              widget.wsService.sendCommand(cmd);
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Смена пароля'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldCtrl, decoration: const InputDecoration(labelText: 'Старый пароль'), obscureText: true),
            TextField(controller: newCtrl, decoration: const InputDecoration(labelText: 'Новый пароль'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              widget.wsService.sendCommand('/change_password ${oldCtrl.text}|${newCtrl.text}');
              Navigator.pop(ctx);
            },
            child: const Text('Сменить'),
          ),
        ],
      ),
    );
  }

  void _showSessionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        // Отправляем запрос на сервер при открытии
        widget.wsService.sendCommand('/sessions');
        return AlertDialog(
          title: const Text('Активные сессии'),
          content: const Text('Загрузка данных...\n\n(Сессии отобразятся в чате "VartChat System")'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ОК'))],
        );
      },
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Приватность'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Скрыть номер телефона'),
                  value: _hidePhone,
                  onChanged: (v) => setDialogState(() => _hidePhone = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _lastSeenPrivacy,
                  decoration: const InputDecoration(labelText: 'Кто видит "был(а) в сети"'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Все')),
                    DropdownMenuItem(value: 1, child: Text('Только контакты')),
                    DropdownMenuItem(value: 2, child: Text('Никто')),
                  ],
                  onChanged: (v) => setDialogState(() => _lastSeenPrivacy = v ?? 0),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () {
                  widget.wsService.sendCommand('/update_settings ${_hidePhone ? 1 : 0}|$_lastSeenPrivacy');
                  Navigator.pop(ctx);
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Аккаунт'),
            subtitle: Text(widget.username),
            onTap: _showEditProfileDialog,
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Приватность'),
            onTap: _showPrivacyDialog,
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Безопасность'),
            subtitle: const Text('Активные сессии и пароль'),
            onTap: _showSessionsDialog,
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Сменить пароль'),
            onTap: _showChangePasswordDialog,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Политика конфиденциальности'),
            onTap: () => launchUrl(Uri.parse('https://vartrusdata.alwaysdata.net/pkvartchat.html?v=2'), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('О приложении'),
            subtitle: const Text('Версия 2.1.2+24'),
          ),
        ],
      ),
    );
  }
}