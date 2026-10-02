import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/websocket_service.dart';
import '../services/protocol.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../models/message.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

enum ViewMode { chats, contacts, groups, channels }

class ChatListScreen extends StatefulWidget {
  final WebSocketService wsService;
  final String username;

  const ChatListScreen({
    super.key,
    required this.wsService,
    required this.username,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  List<({String phone, String username, String displayName})> _contacts = [];
  List<String> _groups = [];
  List<String> _channels = [];

  final Set<String> _onlineUsers = {};
  final Map<String, int> _lastSeen = {};
  Map<String, ({String creator, bool isSubscribed})> _channelInfo = {};

  String? _selectedChat;
  /// Последний отрендеренный чат — держим в дереве, пока идёт анимация закрытия.
  String? _lastRenderedChat;
  /// true — чат в позиции 0 (открыт), false — за правым краем.
  bool _chatOpen = false;

  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _periodicTimer;
  int _reconnectAttempts = 0;
  bool _isConnecting = true;
  String _serverAddress = 'не задан';
  ViewMode _currentView = ViewMode.chats;

  bool _wasInBackground = false;
  bool _reconnectInProgress = false;

  final Map<String, TextEditingController> _draftControllers = {};
  final FocusNode _chatFocusNode = FocusNode();

  /// ScrollController на каждый чат. Живёт до dispose ChatListScreen.
  /// ChatScreen при пересоздании (например, при смене чата на ПК) снова
  /// получит этот же контроллер — позиция сбрасывается вниз при открытии.
  final Map<String, ScrollController> _scrollControllers = {};

  final Map<String, List<({int id, String sender, String text, bool isMe, int timestamp})>>
  _messages = {};

  static const List<int> _reconnectDelays = [1, 5, 10, 30, 60];

  int _getDelayForAttempt(int attempt) {
    if (attempt < _reconnectDelays.length) {
      return _reconnectDelays[attempt];
    }
    return 60;
  }

  TextEditingController _getController(String chatKey) {
    return _draftControllers.putIfAbsent(chatKey, () => TextEditingController());
  }

  ScrollController _getScrollController(String chatKey) {
    return _scrollControllers.putIfAbsent(chatKey, () => ScrollController());
  }

  String _resolveDisplayName(String username) {
    for (final c in _contacts) {
      if (c.username == username) return c.displayName;
    }
    return username;
  }

  int _kindForChat(String chatKey) {
    if (chatKey.startsWith('#')) return Protocol.MSG_KIND_GROUP;
    if (chatKey.startsWith('&')) return Protocol.MSG_KIND_CHANNEL;
    return Protocol.MSG_KIND_PERSONAL;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadServerAddress();
    _loadMessagesFromHive();
    _subscribeToMessages();
    _refreshChats();

    _periodicTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!widget.wsService.isConnected) {
        _scheduleReconnect();
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isConnecting) {
        setState(() => _isConnecting = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    for (final c in _draftControllers.values) {
      c.dispose();
    }
    _draftControllers.clear();
    for (final sc in _scrollControllers.values) {
      sc.dispose();
    }
    _scrollControllers.clear();
    _chatFocusNode.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasInBackground = true;
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    final wasBg = _wasInBackground;
    _wasInBackground = false;

    if (!wasBg) return;
    if (_reconnectInProgress) return;

    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnecting = false;

    if (!widget.wsService.isConnected) {
      _scheduleReconnect();
    }
  }

  Future<void> _loadServerAddress() async {
    final addr = await StorageService.getServer();
    if (addr != null) {
      setState(() => _serverAddress = addr);
    }
  }

  void _loadMessagesFromHive() {
    final allMessages = DatabaseService.getAllMessages();
    allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (var msg in allMessages) {
      String chatKey;
      if (msg.recipient.startsWith('#') || msg.recipient.startsWith('&')) {
        chatKey = msg.recipient;
      } else {
        chatKey = (msg.sender == widget.username) ? msg.recipient : msg.sender;
      }
      _messages.putIfAbsent(chatKey, () => []);
      _messages[chatKey]!.add((
      id: msg.id,
      sender: msg.sender,
      text: msg.text,
      isMe: msg.isMe,
      timestamp: msg.timestamp.millisecondsSinceEpoch,
      ));
    }
  }

  void _addMessageToChat(
      int id,
      String sender,
      String recipient,
      String text,
      bool isMe,
      int timestamp,
      ) {
    String chatKey;
    if (recipient.startsWith('#') || recipient.startsWith('&')) {
      chatKey = recipient;
    } else {
      chatKey = (sender == widget.username) ? recipient : sender;
    }
    _messages.putIfAbsent(chatKey, () => []);
    _messages[chatKey]!.add((
    id: id,
    sender: sender,
    text: text,
    isMe: isMe,
    timestamp: timestamp,
    ));
    _messages[chatKey]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final message = ChatMessage(
      id: id,
      sender: sender,
      recipient: recipient,
      text: text,
      isMe: isMe,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
    DatabaseService.saveMessage(message);
  }

  void _subscribeToMessages() {
    _subscription?.cancel();
    _subscription = widget.wsService.onMessage.listen(
      _handleIncomingMessage,
      onDone: () {
        _scheduleReconnect();
      },
      onError: (error) {
        _scheduleReconnect();
      },
    );
  }

  void _refreshChats() {
    print('[ChatList] _refreshChats: отправка команд');
    try {
      widget.wsService.sendCommand('/listusers');
      widget.wsService.sendCommand('/listgroups');
      widget.wsService.sendCommand('/channels');
      widget.wsService.sendCommand('/onlineusers');
    } catch (e) {
      print('[ChatList] Ошибка при отправке команд: $e');
    }
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    if (_reconnectTimer != null) return;
    if (_isConnecting) return;

    final delaySeconds = _getDelayForAttempt(_reconnectAttempts);
    setState(() => _isConnecting = true);

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      _performReconnect();
    });
  }

  Future<void> _performReconnect() async {
    if (!mounted) return;
    if (_reconnectInProgress) return;

    _reconnectInProgress = true;
    try {
      await widget.wsService.reconnect();
      _reconnectAttempts = 0;
      await DatabaseService.clearData();
      setState(() {
        _messages.clear();
        _onlineUsers.clear();
        _lastSeen.clear();
        _channelInfo.clear();
        _contacts.clear();
      });
      _subscribeToMessages();
      _refreshChats();
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    } catch (e) {
      _reconnectAttempts++;
      if (mounted) {
        setState(() => _isConnecting = false);
      }
      _scheduleReconnect();
    } finally {
      _reconnectInProgress = false;
    }
  }

  void _handleIncomingMessage(Uint8List data) {
    try {
      final parsed = Protocol.parsePacket(data);
      final type = parsed.type;
      final payload = parsed.payload;

      if (type == Protocol.MSG_TYPE_SYSTEM) {
        final text = Protocol.readString(payload, 0);
        debugPrint('[ChatList] SYSTEM: $text');

        if (text.contains('Недействительный токен') ||
            text.contains('Ошибка восстановления') ||
            text.contains('Неверный телефон') ||
            text.contains('Сессия не найдена')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $text, требуется повторный вход')),
          );
          _logout();
          return;
        }

        if (text.startsWith('[Система] Пользователь ') &&
            text.endsWith(' подключился')) {
          const prefix = '[Система] Пользователь ';
          const suffix = ' подключился';
          final name = text.substring(prefix.length, text.length - suffix.length).trim();
          if (name.isNotEmpty) {
            setState(() {
              _onlineUsers.add(name);
              _lastSeen.remove(name);
            });
          }
          return;
        }

        if (text.startsWith('[Система] Пользователь ') &&
            text.endsWith(' отключился')) {
          const prefix = '[Система] Пользователь ';
          const suffix = ' отключился';
          final name = text.substring(prefix.length, text.length - suffix.length).trim();
          if (name.isNotEmpty) {
            setState(() {
              _onlineUsers.remove(name);
              _lastSeen[name] = DateTime.now().millisecondsSinceEpoch;
            });
          }
          return;
        }

        if (text.startsWith('[Система] Пользователей онлайн')) {
          if (!mounted) return;
          if (text.contains('Нет пользователей онлайн')) {
            setState(() => _onlineUsers.clear());
          } else {
            final colonIdx = text.indexOf(':');
            if (colonIdx != -1) {
              final listPart = text.substring(colonIdx + 1).trim();
              final names = listPart
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              setState(() {
                _onlineUsers
                  ..clear()
                  ..addAll(names);
              });
            }
          }
          return;
        }

        if (text.startsWith('[Система] Пользователи:')) {
          final usersPart = text.replaceFirst('[Система] Пользователи:', '').trim();
          if (!mounted) return;
          if (usersPart == 'Нет зарегистрированных пользователей') {
            setState(() {
              _contacts = [];
              _lastSeen.clear();
            });
          } else {
            final items = usersPart.split(',').map((s) => s.trim()).toList();
            final parsed = <({String phone, String username, String displayName})>[];
            final newLastSeen = <String, int>{};
            for (final item in items) {
              if (item.isEmpty) continue;
              final parts = item.split('|');
              final phone = parts.isNotEmpty ? parts[0].trim() : '';
              final username = parts.length > 1 ? parts[1].trim() : '';
              final displayName = parts.length > 2 && parts[2].trim().isNotEmpty
                  ? parts[2].trim()
                  : username;
              final lastSeen = parts.length > 3 ? int.tryParse(parts[3].trim()) : null;
              if (username.isEmpty) continue;
              parsed.add((
              phone: phone,
              username: username,
              displayName: displayName,
              ));
              if (lastSeen != null && lastSeen > 0) {
                newLastSeen[username] = lastSeen;
              }
            }
            setState(() {
              _contacts = parsed;
              _lastSeen
                ..clear()
                ..addAll(newLastSeen);
            });
          }
          if (_isConnecting && mounted) {
            setState(() => _isConnecting = false);
          }
          return;
        }

        if (text.startsWith('[Система] Все группы') ||
            text.startsWith('[Система] Ваши группы:')) {
          if (!mounted) return;
          String groupsPart;
          if (text.startsWith('[Система] Все группы')) {
            final colonIdx = text.indexOf(':');
            groupsPart = colonIdx != -1 ? text.substring(colonIdx + 1).trim() : '';
          } else {
            groupsPart = text.replaceFirst('[Система] Ваши группы:', '').trim();
          }
          if (groupsPart.isEmpty ||
              groupsPart == 'Вы не состоите ни в одной группе' ||
              groupsPart == 'Нет ни одной группы') {
            setState(() => _groups = []);
          } else {
            final items = groupsPart.split(',').map((s) => s.trim()).toList();
            final names = items
                .map((item) => item.split('|').first.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            setState(() => _groups = names);
          }
          if (_isConnecting && mounted) {
            setState(() => _isConnecting = false);
          }
          return;
        }

        if (text.startsWith('[Система] Все каналы') ||
            text.startsWith('[Система] Ваши каналы:')) {
          if (!mounted) return;
          String channelsPart;
          final isNewFormat = text.startsWith('[Система] Все каналы');
          if (isNewFormat) {
            final colonIdx = text.indexOf(':');
            channelsPart = colonIdx != -1 ? text.substring(colonIdx + 1).trim() : '';
          } else {
            channelsPart = text.replaceFirst('[Система] Ваши каналы:', '').trim();
          }
          if (channelsPart.isEmpty ||
              channelsPart == 'Вы не подписаны ни на один канал' ||
              channelsPart == 'Нет ни одного канала') {
            setState(() {
              _channels = [];
              _channelInfo = {};
            });
          } else {
            final items = channelsPart.split(',').map((s) => s.trim()).toList();
            final names = <String>[];
            final infoMap = <String, ({String creator, bool isSubscribed})>{};
            for (final item in items) {
              if (item.isEmpty) continue;
              final parts = item.split('|');
              final name = parts.isNotEmpty ? parts[0].trim() : '';
              if (name.isEmpty) continue;
              final creator = parts.length > 1 ? parts[1].trim() : '';
              final isSub = isNewFormat
                  ? (parts.length > 2 && parts[2].trim() == '1')
                  : true;
              names.add(name);
              infoMap[name] = (creator: creator, isSubscribed: isSub);
            }
            setState(() {
              _channels = names;
              _channelInfo = infoMap;
            });
          }
          if (_isConnecting && mounted) {
            setState(() => _isConnecting = false);
          }
          return;
        }
      } else if (type == Protocol.MSG_TYPE_USER) {
        final parsedUser = Protocol.parseUserPacket(payload);
        final sender = parsedUser.sender;
        final recipient = parsedUser.recipient;
        final encrypted = parsedUser.encrypted;
        final nonce = parsedUser.nonce;
        final timestamp = parsedUser.timestamp;
        final msgId = parsedUser.msgId;

        final key = widget.wsService.sessionKey;
        if (key == null) return;

        CryptoService.decryptAesGcm(encrypted, key, nonce).then((plaintext) {
          final text = utf8.decode(plaintext, allowMalformed: true);
          final isMe = sender == widget.username;
          if (mounted) {
            setState(() {
              _addMessageToChat(msgId, sender, recipient, text, isMe, timestamp);
            });
          }
        }).catchError((e) {
          print('Ошибка расшифровки: $e');
        });
      } else if (type == Protocol.MSG_TYPE_DELETE) {
        if (payload.length < 9) return;
        final msgId = ByteData.sublistView(payload, 0, 8).getInt64(0, Endian.big);
        setState(() {
          for (final entry in _messages.entries) {
            entry.value.removeWhere((m) => m.id == msgId);
          }
        });
        DatabaseService.deleteMessage(msgId);
      }
    } catch (e) {
      print('Ошибка обработки пакета: $e');
    }
  }

  void _deleteMessage(String chatKey, int msgId) {
    final kind = _kindForChat(chatKey);
    try {
      widget.wsService.sendDeleteMessage(msgId, kind, type: 0);
    } catch (e) {
      print('[ChatList] Ошибка отправки delete: $e');
    }
  }

  void _hideMessageForMe(String chatKey, int msgId) {
    final kind = _kindForChat(chatKey);
    setState(() {
      for (final entry in _messages.entries) {
        entry.value.removeWhere((m) => m.id == msgId);
      }
    });
    DatabaseService.deleteMessage(msgId);
    try {
      widget.wsService.sendDeleteMessage(msgId, kind, type: 1);
    } catch (e) {
      print('[ChatList] Ошибка отправки hide: $e');
    }
  }

  void _sendMessage(String chatKey, String text) {
    widget.wsService.sendEncryptedMessage(chatKey, text);
    _getController(chatKey).clear();
  }

  String _displayNameFor(String username) {
    for (final c in _contacts) {
      if (c.username == username) return c.displayName;
    }
    return username;
  }

  ChannelRole _getChannelRole(String chatKey) {
    if (!chatKey.startsWith('&')) return ChannelRole.subscriber;
    final name = chatKey.substring(1);
    final info = _channelInfo[name];
    if (info == null) {
      return ChannelRole.subscriber;
    }
    if (info.creator == widget.username) return ChannelRole.creator;
    if (info.isSubscribed) return ChannelRole.subscriber;
    return ChannelRole.guest;
  }

  void _subscribeToChannel(String channelName) {
    widget.wsService.sendCommand('/subscribe $channelName');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Подписка на канал "$channelName"...')),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _refreshChats();
    });
  }

  Future<void> _logout() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    try {
      final token = await StorageService.getToken();
      if (token != null) {
        await widget.wsService.sendLogout(token);
      }
    } catch (e) {
      print('Ошибка при отправке logout: $e');
    }

    await widget.wsService.resetSession();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _showCreateGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать группу'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Название группы'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.wsService.sendCommand('/creategroup $name');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Группа "$name" создаётся...')),
                );
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) _refreshChats();
                });
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showCreateChannelDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать канал'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Название канала'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.wsService.sendCommand('/createchannel $name');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Канал "$name" создаётся...')),
                );
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) _refreshChats();
                });
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithStatus(String username, IconData icon) {
    final isOnline = username != widget.username && _onlineUsers.contains(username);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 20,
          child: Icon(icon, size: 20),
        ),
        if (isOnline)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentList() {
    switch (_currentView) {
      case ViewMode.contacts:
        if (_contacts.isEmpty) {
          return const Center(child: Text('Нет зарегистрированных пользователей'));
        }
        return ListView.builder(
          itemCount: _contacts.length,
          itemBuilder: (context, index) {
            final contact = _contacts[index];
            return ListTile(
              leading: _buildAvatarWithStatus(contact.username, Icons.person),
              title: Text(contact.displayName),
              subtitle: Text(contact.phone),
              onTap: () {
                final chatKey = contact.username;
                if (!_messages.containsKey(chatKey)) {
                  _messages[chatKey] = [];
                }
                setState(() {
                  _currentView = ViewMode.chats;
                });
                _openChat(chatKey);
              },
            );
          },
        );

      case ViewMode.groups:
        if (_groups.isEmpty) {
          return const Center(child: Text('Нет ни одной группы'));
        }
        return ListView.builder(
          itemCount: _groups.length,
          itemBuilder: (context, index) {
            final groupName = _groups[index];
            return ListTile(
              leading: const Icon(Icons.group),
              title: Text(groupName),
              subtitle: const Text('Нажмите для входа'),
              onTap: () {
                final chatKey = '#$groupName';
                if (!_messages.containsKey(chatKey)) {
                  _messages[chatKey] = [];
                }
                setState(() {
                  _currentView = ViewMode.chats;
                });
                _openChat(chatKey);
              },
              trailing: IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () {
                  widget.wsService.sendCommand('/leavegroup $groupName');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Выход из группы "$groupName"...')),
                  );
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) _refreshChats();
                  });
                },
              ),
            );
          },
        );

      case ViewMode.channels:
        if (_channels.isEmpty) {
          return const Center(child: Text('Нет ни одного канала'));
        }
        return ListView.builder(
          itemCount: _channels.length,
          itemBuilder: (context, index) {
            final channelName = _channels[index];
            final info = _channelInfo[channelName];
            final isOwner = info?.creator == widget.username;
            final isSubscribed = info?.isSubscribed ?? false;

            final String subtitle;
            if (isOwner) {
              subtitle = 'Ваш канал';
            } else if (isSubscribed) {
              subtitle = 'Вы подписаны';
            } else {
              subtitle = 'Не подписан';
            }

            return ListTile(
              leading: const Icon(Icons.campaign),
              title: Text(channelName),
              subtitle: Text(subtitle),
              onTap: () {
                final chatKey = '&$channelName';
                if (!_messages.containsKey(chatKey)) {
                  _messages[chatKey] = [];
                }
                setState(() {
                  _currentView = ViewMode.chats;
                });
                _openChat(chatKey);
              },
              trailing: isSubscribed
                  ? IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'Отписаться',
                onPressed: () {
                  widget.wsService.sendCommand('/unsubscribe $channelName');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Отписка от канала "$channelName"...')),
                  );
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) _refreshChats();
                  });
                },
              )
                  : IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Подписаться',
                onPressed: () => _subscribeToChannel(channelName),
              ),
            );
          },
        );

      case ViewMode.chats:
      default:
        final chatEntries = _messages.entries
            .where((entry) => entry.value.isNotEmpty)
            .toList()
          ..sort((a, b) => b.value.last.timestamp.compareTo(a.value.last.timestamp));
        if (chatEntries.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Нет чатов. Начните общение!'),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: chatEntries.length,
          itemBuilder: (context, index) {
            final entry = chatEntries[index];
            final chatKey = entry.key;
            final lastMessage = entry.value.last;
            final bool isGroup = chatKey.startsWith('#');
            final bool isChannel = chatKey.startsWith('&');
            final bool isPersonal = !isGroup && !isChannel;
            final String displayName = isPersonal
                ? _displayNameFor(chatKey)
                : chatKey.replaceFirst(RegExp(r'^[#&]'), '');
            final IconData icon;
            if (isGroup) {
              icon = Icons.group;
            } else if (isChannel) {
              icon = Icons.campaign;
            } else {
              icon = Icons.person;
            }

            final leading = isPersonal
                ? _buildAvatarWithStatus(chatKey, icon)
                : Icon(icon);

            return ListTile(
              leading: leading,
              title: Text(displayName),
              subtitle: Text(
                lastMessage.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                DateFormat('HH:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(lastMessage.timestamp),
                ),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () => _openChat(chatKey),
            );
          },
        );
    }
  }

  /// Открыть чат. Работает одинаково на ПК и мобиле: просто setState —
  /// ChatScreen показывается в дереве, ничего не пушится через Navigator.
  void _openChat(String chatKey) {
    if (_selectedChat == chatKey) return;
    print('[NAV] _openChat chatKey=$chatKey (было _selectedChat=$_selectedChat)');
    setState(() {
      _selectedChat = chatKey;
      _lastRenderedChat = chatKey;
      _chatOpen = false;
    });
    print('[NAV] после setState: _selectedChat=$_selectedChat _lastRenderedChat=$_lastRenderedChat _chatOpen=$_chatOpen');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        print('[NAV] _openChat postFrame mounted=false');
        return;
      }
      print('[NAV] _openChat postFrame: ставлю _chatOpen=true');
      setState(() => _chatOpen = true);
      final sc = _scrollControllers[chatKey];
      if (sc != null && sc.hasClients) {
        sc.jumpTo(0);
      }
    });
  }

  /// Закрыть чат (кнопка «назад» или системный back).
  void _closeChat() {
    if (_selectedChat == null) return;
    print('[NAV] _closeChat _selectedChat=$_selectedChat');
    setState(() {
      _chatOpen = false;
      _selectedChat = null;
    });
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      if (_selectedChat == null) {
        print('[NAV] _closeChat анимация кончилась, _lastRenderedChat=null');
        setState(() => _lastRenderedChat = null);
      }
    });
  }

  /// Единый билдер ChatScreen для мобилы и ПК.
  Widget _buildChatScreen(String chatKey, {required bool isWide}) {
    final isChannel = chatKey.startsWith('&');
    final isGroup = chatKey.startsWith('#');
    final role = isChannel ? _getChannelRole(chatKey) : null;
    final channelName = isChannel ? chatKey.substring(1) : null;

    return ChatScreen(
      key: ValueKey('chat_$chatKey'),
      wsService: widget.wsService,
      chatName: chatKey,
      username: widget.username,
      messages: _messages[chatKey] ?? [],
      controller: _getController(chatKey),
      focusNode: _chatFocusNode,
      scrollController: _getScrollController(chatKey),
      onSendMessage: (text) => _sendMessage(chatKey, text),
      onDeleteMessage: (msgId) => _deleteMessage(chatKey, msgId),
      onHideForMe: (msgId) => _hideMessageForMe(chatKey, msgId),
      resolveDisplayName: _resolveDisplayName,
      isWide: isWide,
      onBack: _closeChat,
      titleOverride: (!isGroup && !isChannel)
          ? _displayNameFor(chatKey)
          : null,
      isOnline: _onlineUsers.contains(chatKey),
      lastSeen: _lastSeen[chatKey],
      channelRole: role,
      onSubscribe: channelName != null
          ? () => _subscribeToChannel(channelName)
          : null,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'VartChat',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.username,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.chat,
              color: _currentView == ViewMode.chats ? Theme.of(context).primaryColor : null,
            ),
            title: const Text('Чаты'),
            selected: _currentView == ViewMode.chats,
            onTap: () {
              if (_currentView != ViewMode.chats) {
                setState(() => _currentView = ViewMode.chats);
              }
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.contacts,
              color: _currentView == ViewMode.contacts ? Theme.of(context).primaryColor : null,
            ),
            title: const Text('Контакты'),
            selected: _currentView == ViewMode.contacts,
            onTap: () {
              if (_currentView != ViewMode.contacts) {
                setState(() => _currentView = ViewMode.contacts);
              }
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.group,
              color: _currentView == ViewMode.groups ? Theme.of(context).primaryColor : null,
            ),
            title: const Text('Группы'),
            selected: _currentView == ViewMode.groups,
            onTap: () {
              if (_currentView != ViewMode.groups) {
                setState(() => _currentView = ViewMode.groups);
              }
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.campaign,
              color: _currentView == ViewMode.channels ? Theme.of(context).primaryColor : null,
            ),
            title: const Text('Каналы'),
            selected: _currentView == ViewMode.channels,
            onTap: () {
              if (_currentView != ViewMode.channels) {
                setState(() => _currentView = ViewMode.channels);
              }
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выйти'),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  void _showEditMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Создать группу'),
              onTap: () {
                Navigator.pop(context);
                _showCreateGroupDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: const Text('Создать канал'),
              onTap: () {
                Navigator.pop(context);
                _showCreateChannelDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Пригласить в VartChat'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Функция в разработке')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts),
              title: const Text('Все пользователи'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentView = ViewMode.contacts;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Build ----------------

  Widget _buildListScaffold({required bool isWide}) {
    return Scaffold(
      key: const ValueKey('__list__'),
      appBar: AppBar(
        title: Text('VartChat — ${widget.username}'),
        bottom: isWide
            ? null
            : PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: _connectionIndicator(isWide: isWide),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showEditMenu,
        tooltip: 'Управление',
        child: const Icon(Icons.edit),
      ),
      drawer: _buildDrawer(),
      drawerEnableOpenDragGesture: _selectedChat == null,
      body: _buildCurrentList(),
    );
  }

  Widget _connectionIndicator({required bool isWide}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.wsService.isConnected ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isConnecting
                ? (isWide ? 'Подключение...' : 'Соединение...')
                : (widget.wsService.isConnected ? 'Подключено' : 'Отключено'),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            'Сервер: $_serverAddress',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return Scaffold(
            appBar: AppBar(
              title: Text('VartChat — ${widget.username}'),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _showEditMenu,
              tooltip: 'Управление',
              child: const Icon(Icons.edit),
            ),
            drawer: _buildDrawer(),
            body: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: 280, child: _buildCurrentList()),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _selectedChat != null
                            ? _buildChatScreen(_selectedChat!, isWide: true)
                            : const Center(child: Text('Выберите чат')),
                      ),
                    ],
                  ),
                ),
                _connectionIndicator(isWide: true),
              ],
            ),
          );
        }

        // Мобилка: список — базовый слой, чат наезжает справа через
        // AnimatedSwitcher. ChatScreen НЕ пересоздаётся при новых сообщениях
        // (ключ и _selectedChat не меняются), позиция скролла сохраняется.
        // Мобилка: Stack, чат поверх списка, анимация через AnimatedPositioned.
        final width = constraints.maxWidth;
        print('[NAV] build mobile: _selectedChat=$_selectedChat _lastRenderedChat=$_lastRenderedChat _chatOpen=$_chatOpen width=$width');
        return PopScope(
          canPop: _selectedChat == null,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_selectedChat != null) {
              _closeChat();
            }
          },
          child: Stack(
            children: [
              // Список всегда внизу.
              _buildListScaffold(isWide: false),

              // Чат поверх — пока _lastRenderedChat не null.
              if (_lastRenderedChat != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: _chatOpen ? 0 : width,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: _buildChatScreen(_lastRenderedChat!, isWide: false),
                ),
            ],
          ),
        );
      },
    );
  }
}