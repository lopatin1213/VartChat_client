import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_profile_screen.dart';
import 'privacy_settings_screen.dart';
import 'sessions_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatelessWidget {
  final WebSocketService wsService;
  final String username;

  const SettingsScreen({
    super.key,
    required this.wsService,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Аккаунт'),
            subtitle: Text(username),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    wsService: wsService,
                    username: username,
                    myUsername: username,
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
                  builder: (_) => PrivacySettingsScreen(wsService: wsService),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Безопасность'),
            subtitle: const Text('Активные сессии'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionsScreen(wsService: wsService),
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
                  builder: (_) => ChangePasswordScreen(wsService: wsService),
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
            subtitle: const Text('Версия 2.1.2+24'),
          ),
        ],
      ),
    );
  }
}