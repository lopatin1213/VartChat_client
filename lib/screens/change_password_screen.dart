import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final WebSocketService wsService;

  const ChangePasswordScreen({super.key, required this.wsService});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_oldCtrl.text.isEmpty || _newCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните оба поля')),
      );
      return;
    }

    setState(() => _isLoading = true);
    widget.wsService.sendCommand('/change_password ${_oldCtrl.text}|${_newCtrl.text}');

    // Мы не ждем ответа от сервера, так как это отдельный экран.
    // Сервер пришлет системное сообщение, но для простоты просто закроем экран.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Запрос на смену пароля отправлен'), backgroundColor: Colors.green),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Смена пароля')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Старый пароль',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Новый пароль',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Сменить пароль'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}