import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/websocket_service.dart';
import 'user_profile_screen.dart';
import 'privacy_settings_screen.dart';
import 'security_screen.dart'; // <--- ИЗМЕНЕН ИМПОРТ
import 'change_password_screen.dart';

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
  String _appVersion = 'загрузка...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${info.version} (${info.buildNumber})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'неизвестно';
        });
      }
    }
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
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    wsService: widget.wsService,
                    username: widget.username,
                    myUsername: widget.username,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Приватность'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrivacySettingsScreen(wsService: widget.wsService),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Безопасность'),
            subtitle: const Text('Сессии и удаление аккаунта'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SecurityScreen(wsService: widget.wsService), // <--- ИЗМЕНЕН ПЕРЕХОД
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Сменить пароль'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangePasswordScreen(wsService: widget.wsService),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Политика конфиденциальности'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => launchUrl(
              Uri.parse('https://vartrusdata.alwaysdata.net/pkvartchat.html?v=2'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('О приложении'),
            subtitle: Text('Версия $_appVersion'),
          ),
        ],
      ),
    );
  }
}