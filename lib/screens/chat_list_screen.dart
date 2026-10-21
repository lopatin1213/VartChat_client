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
import '../services/fcm_service.dart';
import '../models/message.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

enum ViewMode { chats, contacts, groups, channels }

typedef _OutboxItem = ({
String chatKey,
String text,
int replyToId,
int timestamp,
int clientMsgId,
});

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
  static const int _historyPageSize = 1000;
  static const double _scrollTopThreshold = 400;
  static const Duration _getMsgBatchDelay = Duration(milliseconds: 150);

  List<({String phone, String username, String displayName})> _contacts = [];
  List<String> _groups = [];
  final Map<String, bool> _groupMembership = {}; // <--- Статус участия в группах
  List<String> _channels = [];

  final Set<String> _onlineUsers = {};
  final Map<String, int> _lastSeen = {};
  Map<String, ({String creator, bool isSubscribed})> _channelInfo = {};

  String? _selectedChat;
  String? _lastRenderedChat;
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
  final Map<String, ScrollController> _scrollControllers = {};

  final Map<String, List<ChatMsg>> _messages = {};

  final Map<int, ReplyPreview> _replyCache = {};
  final Set<int> _requestedReplyIds = {};
  final Map<int, Set<int>> _pendingGetMsg = {};
  Timer? _getMsgTimer;
  final Map<String, int> _replyToMsgId = {};

  final Map<String, bool> _fullyLoaded = {};
  final Set<String> _historyLoading = {};

  final List<_OutboxItem> _outbox = [];

  static const List<int> _reconnectDelays = [1, 5, 10, 30, 60];

  int _getDelayForAttempt(int attempt) {
    if (attempt < _reconnectDelays.length) return _reconnectDelays[attempt];
    return 60;
  }

  TextEditingController _getController(String chatKey) {
    return _draftControllers.putIfAbsent(chatKey, () => TextEditingController());
  }

  ScrollController _getScrollController(String chatKey) {
    return _scrollControllers.putIfAbsent(chatKey, () {
      final sc = ScrollController();
      sc.addListener(() => _onScroll(chatKey, sc));
      return sc;
    });
  }

  void _disposeScrollController(String chatKey) {
    final sc = _scrollControllers.remove(chatKey);
    sc?.dispose();
    _fullyLoaded.remove(chatKey);
    _historyLoading.remove(chatKey);
    _replyToMsgId.remove(chatKey);
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

  String _chatKeyFor(String sender, String recipient, bool isMe) {
    if (recipient.startsWith('#') || recipient.startsWith('&')) return recipient;
    return isMe ? recipient : sender;
  }

  String _recipientFor(ChatMsg m, String chatKey) {
    if (chatKey.startsWith('#') || chatKey.startsWith('&')) return chatKey;
    return m.isMe ? chatKey : widget.username;
  }

  bool _hasMessageById(String chatKey, int id) {
    final msgs = _messages[chatKey];
    if (msgs == null) return false;
    return msgs.any((m) => m.id == id);
  }

  ReplyPreview? _getReplyData(String chatKey) {
    final id = _replyToMsgId[chatKey];
    if (id == null) return null;
    final msgs = _messages[chatKey];
    if (msgs != null) {
      for (final m in msgs) {
        if (m.id == id) {
          return (sender: m.sender, text: m.text, isMe: m.isMe);
        }
      }
    }
    return _replyCache[id];
  }

  ReplyPreview? _resolveReplyFor(String chatKey, int replyToId) {
    final msgs = _messages[chatKey];
    if (msgs != null) {
      for (final m in msgs) {
        if (m.id == replyToId) {
          return (sender: m.sender, text: m.text, isMe: m.isMe);
        }
      }
    }
    return _replyCache[replyToId];
  }

  int _unreadFor(String chatKey) {
    final msgs = _messages[chatKey];
    if (msgs == null || msgs.isEmpty) return 0;
    final kind = _kindForChat(chatKey);
    if (kind == Protocol.MSG_KIND_CHANNEL) return 0;

    int count = 0;
    for (final m in msgs) {
      if (m.isMe) continue;
      if (kind == Protocol.MSG_KIND_PERSONAL && !m.readMe) count++;
      if (kind == Protocol.MSG_KIND_GROUP && !m.readAny) count++;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadServerAddress();
    _loadMessagesFromHive();
    _subscribeToMessages();
    _refreshChats();

    _periodicTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
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
    _reconnectTimer?.cancel();
    _getMsgTimer?.cancel();
    _pendingGetMsg.clear();
    _replyCache.clear();
    _requestedReplyIds.clear();
    _outbox.clear();
    for (final c in _draftControllers.values) {
      c.dispose();
    }
    for (final sc in _scrollControllers.values) {
      sc.dispose();
    }
    _chatFocusNode.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _wasInBackground = true;
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final wasBg = _wasInBackground;
    _wasInBackground = false;
    if (!wasBg || _reconnectInProgress) return;

    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _isConnecting = false;

    // Та самая рабочая проверка
    if (!widget.wsService.isConnected) {
      _scheduleReconnect();
    }
  }

  Future<void> _loadServerAddress() async {
    final addr = await StorageService.getServer();
    if (addr != null) setState(() => _serverAddress = addr);
  }

  void _loadMessagesFromHive() {
    final allMessages = DatabaseService.getAllMessages();
    allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (var msg in allMessages) {
      final chatKey = _chatKeyFor(msg.sender, msg.recipient, msg.isMe);
      _messages.putIfAbsent(chatKey, () => []);
      _messages[chatKey]!.add((
      id: msg.id,
      clientMsgId: 0,
      sender: msg.sender,
      text: msg.text,
      isMe: msg.isMe,
      timestamp: msg.timestamp.millisecondsSinceEpoch,
      replyToId: msg.replyToId,
      readMe: msg.readMe,
      readAny: msg.readAny,
      views: msg.views,
      edited: msg.edited,
      ));
    }
  }

  void _mergeMessage(
      int id,
      int clientMsgId,
      String sender,
      String recipient,
      String text,
      bool isMe,
      int timestamp,
      int replyToId,
      bool readMe,
      bool readAny,
      int? views,
      bool edited,
      ) {
    final chatKey = _chatKeyFor(sender, recipient, isMe);
    final list = _messages.putIfAbsent(chatKey, () => []);

    int idx = -1;

    // 1. СНАЧАЛА ищем локальное сообщение по clientMsgId
    if (clientMsgId != 0) {
      idx = list.indexWhere((m) => m.clientMsgId == clientMsgId);
    }

    // 2. Если не нашли, ищем по реальному ID
    if (idx < 0 && id != 0) {
      idx = list.indexWhere((m) => m.id == id);
    }

    ChatMsg merged;
    if (idx >= 0) {
      final old = list[idx];
      final newText = edited ? text : old.text;
      final newEdited = old.edited || edited;
      merged = (
      id: id != 0 ? id : old.id,
      clientMsgId: old.clientMsgId,
      sender: old.sender,
      text: newText,
      isMe: old.isMe,
      timestamp: old.timestamp,
      replyToId: old.replyToId != 0 ? old.replyToId : replyToId,
      readMe: old.readMe || readMe,
      readAny: old.readAny || readAny,
      views: views ?? old.views,
      edited: newEdited,
      );
      list[idx] = merged;
    } else {
      merged = (
      id: id,
      clientMsgId: clientMsgId,
      sender: sender,
      text: text,
      isMe: isMe,
      timestamp: timestamp,
      replyToId: replyToId,
      readMe: readMe,
      readAny: readAny,
      views: views,
      edited: edited,
      );
      list.add(merged);
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    if (merged.id == 0) return;

    final message = ChatMessage(
      id: merged.id,
      sender: merged.sender,
      recipient: _recipientFor(merged, chatKey),
      text: merged.text,
      isMe: merged.isMe,
      timestamp: DateTime.fromMillisecondsSinceEpoch(merged.timestamp),
      replyToId: merged.replyToId,
      readMe: merged.readMe,
      readAny: merged.readAny,
      views: merged.views,
      edited: merged.edited,
    );
    DatabaseService.saveMessage(message);
  }

  void _sendReadForChat(String chatKey) {
    final msgs = _messages[chatKey];
    if (msgs == null || msgs.isEmpty) return;
    final kind = _kindForChat(chatKey);
    final ids = <int>[];
    for (final m in msgs) {
      if (m.isMe || m.id == 0) continue;
      if (kind == Protocol.MSG_KIND_PERSONAL && m.readMe) continue;
      if (kind == Protocol.MSG_KIND_GROUP && m.readAny) continue;
      ids.add(m.id);
    }
    if (ids.isEmpty) return;
    final items = ids.map((id) => (kind: kind, msgId: id)).toList();
    try {
      widget.wsService.sendRead(items);
    } catch (e) {
      return;
    }
    _markLocalRead(chatKey, ids);
  }

  void _markRead(String chatKey, List<int> msgIds) {
    if (msgIds.isEmpty) return;
    final kind = _kindForChat(chatKey);
    final items = msgIds.map((id) => (kind: kind, msgId: id)).toList();
    try {
      widget.wsService.sendRead(items);
    } catch (e) {
      return;
    }
    _markLocalRead(chatKey, msgIds);
  }

  void _markLocalRead(String chatKey, List<int> ids) {
    if (!mounted) return;
    final list = _messages[chatKey];
    if (list == null) return;

    setState(() {
      for (final id in ids) {
        final idx = list.indexWhere((m) => m.id == id);
        if (idx < 0) continue;
        final m = list[idx];
        if (m.readMe) continue;
        final updated = (
        id: m.id,
        clientMsgId: m.clientMsgId,
        sender: m.sender,
        text: m.text,
        isMe: m.isMe,
        timestamp: m.timestamp,
        replyToId: m.replyToId,
        readMe: true,
        readAny: m.readAny,
        views: m.views,
        edited: m.edited,
        );
        list[idx] = updated;
        DatabaseService.saveMessage(ChatMessage(
          id: m.id, sender: m.sender, recipient: _recipientFor(m, chatKey),
          text: m.text, isMe: m.isMe, timestamp: DateTime.fromMillisecondsSinceEpoch(m.timestamp),
          replyToId: m.replyToId, readMe: true, readAny: m.readAny, views: m.views, edited: m.edited,
        ));
      }
    });
  }

  void _handleReadIncoming(Uint8List payload) {
    final items = Protocol.parseReadPacket(payload);
    if (items.isEmpty || !mounted) return;

    setState(() {
      for (final it in items) {
        for (final entry in _messages.entries) {
          final list = entry.value;
          for (var i = 0; i < list.length; i++) {
            final m = list[i];
            if (m.id != it.msgId || m.readAny) continue;
            list[i] = (
            id: m.id, clientMsgId: m.clientMsgId, sender: m.sender, text: m.text, isMe: m.isMe,
            timestamp: m.timestamp, replyToId: m.replyToId, readMe: m.readMe, readAny: true, views: m.views, edited: m.edited,
            );
            DatabaseService.saveMessage(ChatMessage(
              id: m.id, sender: m.sender, recipient: _recipientFor(m, entry.key),
              text: m.text, isMe: m.isMe, timestamp: DateTime.fromMillisecondsSinceEpoch(m.timestamp),
              replyToId: m.replyToId, readMe: m.readMe, readAny: true, views: m.views, edited: m.edited,
            ));
          }
        }
      }
    });
  }

  void _scheduleGetMsg(int kind, int msgId) {
    if (msgId == 0 || _requestedReplyIds.contains(msgId)) return;
    _requestedReplyIds.add(msgId);
    _pendingGetMsg.putIfAbsent(kind, () => <int>{}).add(msgId);
    _getMsgTimer?.cancel();
    _getMsgTimer = Timer(_getMsgBatchDelay, _flushGetMsg);
  }

  void _flushGetMsg() {
    _getMsgTimer = null;
    if (_pendingGetMsg.isEmpty) return;

    final snapshot = Map<int, Set<int>>.from(_pendingGetMsg);
    _pendingGetMsg.clear();

    for (final entry in snapshot.entries) {
      final parts = <String>['/getmsg', '${entry.key}'];
      for (final id in entry.value) {
        parts.add('$id');
      }
      try {
        widget.wsService.sendCommand(parts.join(' '));
      } catch (e) {
        print('[REPLY] Ошибка /getmsg: $e');
      }
    }
  }

  void _subscribeToMessages() {
    _subscription?.cancel();
    _subscription = widget.wsService.onMessage.listen(
      _handleIncomingMessage,
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
  }

  void _refreshChats() {
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
    if (!mounted || _reconnectTimer != null || _isConnecting || _reconnectInProgress) return;
    final delaySeconds = _getDelayForAttempt(_reconnectAttempts);
    setState(() => _isConnecting = true);

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      _performReconnect();
    });
  }

  Future<void> _performReconnect() async {
    if (!mounted || _reconnectInProgress) return;
    _reconnectInProgress = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;

    try {
      await widget.wsService.reconnect();
      _reconnectAttempts = 0;

      setState(() {
        _fullyLoaded.clear();
        _historyLoading.clear();
        _onlineUsers.clear();
        _lastSeen.clear();
        _channelInfo.clear();
        _contacts.clear();
        _pendingGetMsg.clear();
        _requestedReplyIds.clear();
      });
      _getMsgTimer?.cancel();

      // 1. СНАЧАЛА подписываемся на стрим
      _subscribeToMessages();

      // 2. И ТОЛЬКО ПОТОМ шлем токен
      final token = await StorageService.getToken();
      if (token != null) {
        await widget.wsService.sendToken(token, fcmToken: FcmService.token);
      } else {
        _logout();
        return;
      }

      _refreshChats();

      if (mounted) setState(() => _isConnecting = false);

      _flushOutbox();

      if (_selectedChat != null) {
        _fullyLoaded[_selectedChat!] = false;
        _historyLoading.remove(_selectedChat);
        _requestHistoryInitial(_selectedChat!);
      }
    } catch (e) {
      if (e.toString().contains('Токен не найден')) {
        _logout();
        return;
      }
      _reconnectAttempts++;
      if (mounted) setState(() => _isConnecting = false);
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

      if (type == Protocol.MSG_TYPE_LOGOUT) {
        final reason = Protocol.parseLogoutFromServer(payload);
        _reconnectTimer?.cancel();
        _periodicTimer?.cancel();
        _subscription?.cancel();
        StorageService.clearAll();
        DatabaseService.clearData();
        widget.wsService.disconnect();
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        return;
      }

      if (type == Protocol.MSG_TYPE_SYSTEM) {
        final text = Protocol.readString(payload, 0);

        if (text.startsWith('[Система] history_done|')) {
          final rest = text.substring('[Система] history_done|'.length);
          final parts = rest.split('|');
          if (parts.length >= 2) {
            final chatKey = parts[0];
            final count = int.tryParse(parts[1]) ?? 0;
            if (mounted) {
              setState(() {
                _historyLoading.remove(chatKey);
                if (count < _historyPageSize) _fullyLoaded[chatKey] = true;
              });
            }
          }
          return;
        }

        if (text.contains('Недействительный токен') || text.contains('Ошибка восстановления') ||
            text.contains('Неверный телефон') || text.contains('Сессия не найдена')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $text')));
          _logout();
          return;
        }

        if (text.contains('Неверный пароль')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Неверный пароль — аккаунт не удалён', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        if (text.startsWith('[Система] Пользователь ')) {
          final isOnline = text.endsWith(' подключился');
          final isOffline = text.endsWith(' отключился');
          if (isOnline || isOffline) {
            const prefix = '[Система] Пользователь ';
            final suffix = isOnline ? ' подключился' : ' отключился';
            final name = text.substring(prefix.length, text.length - suffix.length).trim();
            if (name.isNotEmpty) {
              setState(() {
                if (isOnline) {
                  _onlineUsers.add(name);
                  _lastSeen.remove(name);
                } else {
                  _onlineUsers.remove(name);
                  _lastSeen[name] = DateTime.now().millisecondsSinceEpoch;
                }
              });
            }
            return;
          }
        }

        if (text.startsWith('[Система] Пользователей онлайн')) {
          if (!mounted) return;
          if (text.contains('Нет пользователей онлайн')) {
            setState(() => _onlineUsers.clear());
          } else {
            final colonIdx = text.indexOf(':');
            if (colonIdx != -1) {
              final names = text.substring(colonIdx + 1).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              setState(() => _onlineUsers..clear()..addAll(names));
            }
          }
          return;
        }

        if (text.startsWith('[Система] Пользователи:')) {
          final usersPart = text.replaceFirst('[Система] Пользователи:', '').trim();
          if (!mounted) return;
          if (usersPart == 'Нет зарегистрированных пользователей') {
            setState(() { _contacts = []; _lastSeen.clear(); });
          } else {
            final items = usersPart.split(',').map((s) => s.trim()).toList();
            final parsedList = <({String phone, String username, String displayName})>[];
            final newLastSeen = <String, int>{};
            for (final item in items) {
              final parts = item.split('|');
              if (parts.length >= 2) {
                final phone = parts[0].trim();
                final username = parts[1].trim();
                final displayName = parts.length > 2 && parts[2].trim().isNotEmpty ? parts[2].trim() : username;
                final lastSeen = parts.length > 3 ? int.tryParse(parts[3].trim()) : null;
                if (username.isNotEmpty) {
                  parsedList.add((phone: phone, username: username, displayName: displayName));
                  if (lastSeen != null && lastSeen > 0) newLastSeen[username] = lastSeen;
                }
              }
            }
            setState(() { _contacts = parsedList; _lastSeen..clear()..addAll(newLastSeen); });
          }
          if (_isConnecting && mounted) setState(() => _isConnecting = false);
          return;
        }

        if (text.startsWith('[Система] Все группы') || text.startsWith('[Система] Ваши группы:')) {
          if (!mounted) return;
          String groupsPart;
          if (text.startsWith('[Система] Все группы')) {
            final colonIdx = text.indexOf(':');
            groupsPart = colonIdx != -1 ? text.substring(colonIdx + 1).trim() : '';
          } else {
            groupsPart = text.replaceFirst('[Система] Ваши группы:', '').trim();
          }
          if (groupsPart.isEmpty || groupsPart == 'Вы не состоите ни в одной группе' || groupsPart == 'Нет ни одной группы') {
            setState(() { _groups = []; _groupMembership.clear(); });
          } else {
            final items = groupsPart.split(',').map((s) => s.trim()).toList();
            final names = <String>[];
            final memberships = <String, bool>{};
            for (final item in items) {
              final parts = item.split('|');
              final name = parts[0].trim();
              if (name.isNotEmpty) {
                names.add(name);
                final isMember = parts.length > 2 ? parts[2].trim() == '1' : true;
                memberships[name] = isMember;
              }
            }
            setState(() { _groups = names; _groupMembership..clear()..addAll(memberships); });
          }
          if (_isConnecting && mounted) setState(() => _isConnecting = false);
          return;
        }

        if (text.startsWith('[Система] Все каналы') || text.startsWith('[Система] Ваши каналы:')) {
          final isNewFormat = text.startsWith('[Система] Все каналы');
          String channelsPart = isNewFormat
              ? (text.indexOf(':') != -1 ? text.substring(text.indexOf(':') + 1).trim() : '')
              : text.replaceFirst('[Система] Ваши каналы:', '').trim();
          if (channelsPart.isEmpty || channelsPart == 'Вы не подписаны ни на один канал' || channelsPart == 'Нет ни одного канала') {
            setState(() { _channels = []; _channelInfo = {}; });
          } else {
            final names = <String>[];
            final infoMap = <String, ({String creator, bool isSubscribed})>{};
            for (final item in channelsPart.split(',').map((s) => s.trim())) {
              final parts = item.split('|');
              final name = parts[0].trim();
              if (name.isNotEmpty) {
                final creator = parts.length > 1 ? parts[1].trim() : '';
                final isSub = isNewFormat ? (parts.length > 2 && parts[2].trim() == '1') : true;
                names.add(name);
                infoMap[name] = (creator: creator, isSubscribed: isSub);
              }
            }
            setState(() { _channels = names; _channelInfo = infoMap; });
          }
          if (_isConnecting && mounted) setState(() => _isConnecting = false);
          return;
        }
      } else if (type == Protocol.MSG_TYPE_READ) {
        _handleReadIncoming(payload);
        return;
      } else if (type == Protocol.MSG_TYPE_USER) {
        final p = Protocol.parseUserPacket(payload);
        final key = widget.wsService.sessionKey;
        if (key == null) return;

        CryptoService.decryptAesGcm(p.encrypted, key, p.nonce).then((plaintext) {
          final text = utf8.decode(plaintext, allowMalformed: true);
          final isMe = p.sender == widget.username;
          if (!mounted) return;

          setState(() {
            _mergeMessage(p.msgId, p.clientMsgId, p.sender, p.recipient, text, isMe, p.timestamp, p.replyToId, p.flagMe, p.flagAny, p.views, p.edited);

            if (p.msgId != 0) {
              _replyCache[p.msgId] = (sender: p.sender, text: text, isMe: isMe);
              _requestedReplyIds.remove(p.msgId);
            }

            if (isMe && p.msgId > 0 && !p.edited) {
              final chatKey = _chatKeyFor(p.sender, p.recipient, isMe);
              final idx = _outbox.indexWhere((it) => it.chatKey == chatKey && it.clientMsgId == p.clientMsgId);
              if (idx >= 0) {
                _outbox.removeAt(idx);
              }
            }
          });

          if (p.replyToId != 0) {
            final chatKey = _chatKeyFor(p.sender, p.recipient, isMe);
            if (!_hasMessageById(chatKey, p.replyToId) && !_replyCache.containsKey(p.replyToId)) {
              _scheduleGetMsg(_kindForChat(chatKey), p.replyToId);
            }
          }
        }).catchError((e) => print('Ошибка расшифровки: $e'));
      } else if (type == Protocol.MSG_TYPE_DELETE) {
        if (payload.length < 9) return;
        final msgId = ByteData.sublistView(payload, 0, 8).getInt64(0, Endian.big);

        if (msgId == 0 && payload.length >= 14) {
          final kind = payload[8];
          final dtype = payload[9];
          final nameLen = ByteData.sublistView(payload, 10, 14).getUint32(0, Endian.big);
          if (payload.length >= 14 + nameLen) {
            final name = utf8.decode(payload.sublist(14, 14 + nameLen), allowMalformed: true);
            String chatKey = name;
            if (kind == Protocol.MSG_KIND_GROUP) chatKey = '#$name';
            if (kind == Protocol.MSG_KIND_CHANNEL) chatKey = '&$name';
            _deleteChatLocally(chatKey);
          }
          return;
        }

        setState(() {
          for (final entry in _messages.entries) {
            entry.value.removeWhere((m) => m.id == msgId);
          }
          for (final entry in _messages.entries) {
            final list = entry.value;
            for (var i = 0; i < list.length; i++) {
              final m = list[i];
              if (m.replyToId == msgId) {
                list[i] = (
                id: m.id, clientMsgId: m.clientMsgId, sender: m.sender, text: m.text, isMe: m.isMe,
                timestamp: m.timestamp, replyToId: 0, readMe: m.readMe, readAny: m.readAny, views: m.views, edited: m.edited,
                );
              }
            }
          }
          _replyCache.remove(msgId);
          _replyToMsgId.removeWhere((_, id) => id == msgId);
        });
        DatabaseService.deleteMessage(msgId);
      }
    } catch (e) {
      print('Ошибка обработки пакета: $e');
    }
  }

  void _requestHistoryInitial(String chatKey) {
    if (_fullyLoaded[chatKey] == true || _historyLoading.contains(chatKey)) return;
    _historyLoading.add(chatKey);
    try {
      widget.wsService.sendCommand('/history $chatKey');
    } catch (e) {
      _historyLoading.remove(chatKey);
    }
  }

  void _requestHistoryOlder(String chatKey) {
    if (_fullyLoaded[chatKey] == true || _historyLoading.contains(chatKey)) return;
    final msgs = _messages[chatKey];
    if (msgs == null || msgs.isEmpty) return;
    final oldestId = msgs.first.id;
    if (oldestId == 0) return;
    _historyLoading.add(chatKey);
    try {
      widget.wsService.sendCommand('/history $chatKey $oldestId');
    } catch (e) {
      _historyLoading.remove(chatKey);
    }
  }

  void _onScroll(String chatKey, ScrollController sc) {
    if (!sc.hasClients || _fullyLoaded[chatKey] == true || _historyLoading.contains(chatKey)) return;
    final pos = sc.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels >= pos.maxScrollExtent - _scrollTopThreshold) _requestHistoryOlder(chatKey);
  }

  void _deleteMessage(String chatKey, int msgId) {
    if (msgId == 0) return;
    try {
      widget.wsService.sendDeleteMessage(msgId, _kindForChat(chatKey), type: 0);
    } catch (e) {
      print('[ChatList] Ошибка отправки delete: $e');
    }
  }

  void _hideMessageForMe(String chatKey, int msgId) {
    setState(() {
      for (final entry in _messages.entries) {
        entry.value.removeWhere((m) => m.id == msgId);
      }
      _replyToMsgId.removeWhere((_, id) => id == msgId);
    });
    DatabaseService.deleteMessage(msgId);
    try {
      widget.wsService.sendDeleteMessage(msgId, _kindForChat(chatKey), type: 1);
    } catch (e) {
      print('[ChatList] Ошибка отправки hide: $e');
    }
  }

  void _deleteChatLocally(String chatKey) {
    setState(() {
      _messages.remove(chatKey);
      if (_selectedChat == chatKey) _closeChat();
      _disposeScrollController(chatKey);
    });
    final all = DatabaseService.getAllMessages();
    for (final m in all) {
      if (_chatKeyFor(m.sender, m.recipient, m.isMe) == chatKey) {
        DatabaseService.deleteMessage(m.id);
      }
    }
  }

  void _sendMessage(String chatKey, String text) {
    final replyToId = _replyToMsgId[chatKey] ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final clientMsgId = DateTime.now().microsecondsSinceEpoch;

    setState(() {
      _mergeMessage(0, clientMsgId, widget.username, chatKey, text, true, now, replyToId, true, false, null, false);
      if (replyToId != 0) _replyToMsgId.remove(chatKey);
    });
    _getController(chatKey).clear();

    final item = (chatKey: chatKey, text: text, replyToId: replyToId, timestamp: now, clientMsgId: clientMsgId);
    _outbox.add(item);
    _trySendOutboxItem(item);
  }

  void _editMessage(String chatKey, int msgId, String newText) {
    if (msgId == 0) return;
    final list = _messages[chatKey];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == msgId);
    if (idx < 0) return;
    final old = list[idx];
    if (old.text == newText) return;

    setState(() {
      final updated = (
      id: old.id, clientMsgId: old.clientMsgId, sender: old.sender, text: newText, isMe: old.isMe,
      timestamp: old.timestamp, replyToId: old.replyToId, readMe: old.readMe, readAny: old.readAny, views: old.views, edited: true,
      );
      list[idx] = updated;
      DatabaseService.saveMessage(ChatMessage(
        id: old.id, sender: old.sender, recipient: _recipientFor(old, chatKey), text: newText, isMe: old.isMe,
        timestamp: DateTime.fromMillisecondsSinceEpoch(old.timestamp), replyToId: old.replyToId, readMe: old.readMe,
        readAny: old.readAny, views: old.views, edited: true,
      ));
    });

    try {
      widget.wsService.sendEditMessage(msgId, _kindForChat(chatKey), newText);
    } catch (e) {
      print('[EDIT] Ошибка отправки: $e');
    }
  }

  void _trySendOutboxItem(_OutboxItem item) {
    if (!widget.wsService.isConnected) return;
    try {
      widget.wsService.sendEncryptedMessage(
        item.chatKey, item.text, replyToId: item.replyToId, timestamp: item.timestamp, clientMsgId: item.clientMsgId,
      );
    } catch (e) {
      print('[OUTBOX] не ушло: $e');
    }
  }

  void _flushOutbox() {
    if (_outbox.isEmpty || !widget.wsService.isConnected) return;
    final copy = List<_OutboxItem>.from(_outbox);
    for (final item in copy) {
      _trySendOutboxItem(item);
    }
  }

  void _setReplyTo(String chatKey, int msgId) => setState(() => _replyToMsgId[chatKey] = msgId);
  void _cancelReply(String chatKey) => setState(() => _replyToMsgId.remove(chatKey));

  String _displayNameFor(String username) {
    for (final c in _contacts) {
      if (c.username == username) return c.displayName;
    }
    return username;
  }

  ChannelRole _getChannelRole(String chatKey) {
    if (!chatKey.startsWith('&')) return ChannelRole.subscriber;
    final info = _channelInfo[chatKey.substring(1)];
    if (info == null) return ChannelRole.subscriber;
    if (info.creator == widget.username) return ChannelRole.creator;
    return info.isSubscribed ? ChannelRole.subscriber : ChannelRole.guest;
  }

  void _subscribeToChannel(String channelName) {
    widget.wsService.sendCommand('/subscribe $channelName');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Подписка на канал "$channelName"...')));
    Future.delayed(const Duration(seconds: 1), () => mounted ? _refreshChats() : null);
  }

  void _joinGroup(String groupName) {
    widget.wsService.sendCommand('/joingroup $groupName');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Вступление в группу "$groupName"...')),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _refreshChats();
    });
  }

  Future<void> _logout() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _outbox.clear();
    try {
      final token = await StorageService.getToken();
      if (token != null) await widget.wsService.sendLogout(token);
    } catch (e) {}
    await widget.wsService.resetSession();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _showDeleteAccountDialog() async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text('Аккаунт и все ваши сообщения будут удалены безвозвратно через 7 дней.\n\nВы точно хотите удалить аккаунт?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Удалить')),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    final password = await showDialog<String>(context: context, builder: (ctx) => const _PasswordPromptDialog());
    if (password == null || password.isEmpty || !mounted) return;

    try {
      final token = await StorageService.getToken();
      if (token != null) await widget.wsService.sendDeleteAccount(token, password);
      await Future.delayed(const Duration(milliseconds: 600));
    } catch (e) {
      print('[UI] Ошибка отправки delete_account: $e');
    }
  }

  void _showChatActions(String chatKey) {
    final isGroup = chatKey.startsWith('#');
    final isChannel = chatKey.startsWith('&');
    final kind = _kindForChat(chatKey);
    final rawName = chatKey.replaceFirst(RegExp(r'^[#&]'), '');

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить у себя'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteChatLocally(chatKey);
                widget.wsService.sendDeleteChat(kind, rawName, type: 1);
              },
            ),
            if (isGroup || isChannel)
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: Text(isGroup ? 'Выйти из группы' : 'Отписаться от канала'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteChatLocally(chatKey);
                  widget.wsService.sendDeleteChat(kind, rawName, type: 1);
                },
              ),
            if (!isGroup && !isChannel || isGroup || isChannel)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(isGroup ? 'Распустить группу' : (isChannel ? 'Удалить канал' : 'Удалить у всех')),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteChatLocally(chatKey);
                  widget.wsService.sendDeleteChat(kind, rawName, type: 0);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать группу'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Название группы'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.wsService.sendCommand('/creategroup $name');
                Navigator.pop(context);
                Future.delayed(const Duration(seconds: 1), () => mounted ? _refreshChats() : null);
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
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Название канала'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.wsService.sendCommand('/createchannel $name');
                Navigator.pop(context);
                Future.delayed(const Duration(seconds: 1), () => mounted ? _refreshChats() : null);
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
        CircleAvatar(radius: 20, child: Icon(icon, size: 20)),
        if (isOnline)
          Positioned(
            right: -1, bottom: -1,
            child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: Colors.green, shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentList() {
    switch (_currentView) {
      case ViewMode.contacts:
        if (_contacts.isEmpty) return const Center(child: Text('Нет зарегистрированных пользователей'));
        return ListView.builder(
          itemCount: _contacts.length,
          itemBuilder: (context, index) {
            final contact = _contacts[index];
            return ListTile(
              leading: _buildAvatarWithStatus(contact.username, Icons.person),
              title: Text(contact.displayName),
              subtitle: Text(contact.phone),
              onTap: () {
                if (!_messages.containsKey(contact.username)) _messages[contact.username] = [];
                setState(() => _currentView = ViewMode.chats);
                _openChat(contact.username);
              },
            );
          },
        );

      case ViewMode.groups:
        if (_groups.isEmpty) return const Center(child: Text('Нет ни одной группы'));
        return ListView.builder(
          itemCount: _groups.length,
          itemBuilder: (context, index) {
            final groupName = _groups[index];
            final isMember = _groupMembership[groupName] ?? false;

            return ListTile(
              leading: const Icon(Icons.group),
              title: Text(groupName),
              subtitle: const Text('Нажмите для входа'),
              onTap: () {
                final chatKey = '#$groupName';
                if (!_messages.containsKey(chatKey)) _messages[chatKey] = [];
                setState(() => _currentView = ViewMode.chats);
                _openChat(chatKey);
              },
              // Никаких текстовых кнопок, только иконка выхода для тех, кто в группе
              trailing: isMember
                  ? IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () {
                  widget.wsService.sendCommand('/leavegroup $groupName');
                  Future.delayed(const Duration(seconds: 1), () => mounted ? _refreshChats() : null);
                },
              )
                  : null,
            );
          },
        );

      case ViewMode.channels:
        if (_channels.isEmpty) return const Center(child: Text('Нет ни одного канала'));
        return ListView.builder(
          itemCount: _channels.length,
          itemBuilder: (context, index) {
            final channelName = _channels[index];
            final info = _channelInfo[channelName];
            final isOwner = info?.creator == widget.username;
            final isSubscribed = info?.isSubscribed ?? false;
            final String subtitle = isOwner ? 'Ваш канал' : (isSubscribed ? 'Вы подписаны' : 'Не подписан');

            return ListTile(
              leading: const Icon(Icons.campaign),
              title: Text(channelName),
              subtitle: Text(subtitle),
              onTap: () {
                final chatKey = '&$channelName';
                if (!_messages.containsKey(chatKey)) _messages[chatKey] = [];
                setState(() => _currentView = ViewMode.chats);
                _openChat(chatKey);
              },
              trailing: isSubscribed
                  ? IconButton(icon: const Icon(Icons.exit_to_app), onPressed: () {
                widget.wsService.sendCommand('/unsubscribe $channelName');
                Future.delayed(const Duration(seconds: 1), () => mounted ? _refreshChats() : null);
              })
                  : IconButton(icon: const Icon(Icons.add), onPressed: () => _subscribeToChannel(channelName)),
            );
          },
        );

      case ViewMode.chats:
      default:
        final chatEntries = _messages.entries.where((entry) => entry.value.isNotEmpty).toList()
          ..sort((a, b) => b.value.last.timestamp.compareTo(a.value.last.timestamp));
        if (chatEntries.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey), SizedBox(height: 16), Text('Нет чатов. Начните общение!')],
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
            final String displayName = isPersonal ? _displayNameFor(chatKey) : chatKey.replaceFirst(RegExp(r'^[#&]'), '');
            final IconData icon = isGroup ? Icons.group : (isChannel ? Icons.campaign : Icons.person);
            final leading = isPersonal ? _buildAvatarWithStatus(chatKey, icon) : Icon(icon);
            final unread = _unreadFor(chatKey);

            return ListTile(
              leading: leading,
              title: Text(displayName),
              subtitle: Text(lastMessage.text, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(lastMessage.timestamp)),
                    style: TextStyle(fontSize: 12, color: unread > 0 ? Colors.green : Colors.grey),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(10)),
                      child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ]
                ],
              ),
              onTap: () => _openChat(chatKey),
              onLongPress: () => _showChatActions(chatKey),
            );
          },
        );
    }
  }

  void _openChat(String chatKey) {
    if (_selectedChat == chatKey) return;
    if (_selectedChat != null) _disposeScrollController(_selectedChat!);
    setState(() {
      _selectedChat = chatKey;
      _lastRenderedChat = chatKey;
      _chatOpen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _chatOpen = true);
      final sc = _scrollControllers[chatKey];
      if (sc != null && sc.hasClients) sc.jumpTo(0);
      _requestHistoryInitial(chatKey);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _selectedChat == chatKey) _sendReadForChat(chatKey);
      });
    });
  }

  void _closeChat() {
    if (_selectedChat == null) return;
    final chatKey = _selectedChat!;
    setState(() {
      _chatOpen = false;
      _selectedChat = null;
    });
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted && _selectedChat == null) {
        setState(() => _lastRenderedChat = null);
        _disposeScrollController(chatKey);
      }
    });
  }

  Widget _buildChatScreen(String chatKey, {required bool isWide}) {
    final isChannel = chatKey.startsWith('&');
    final isGroup = chatKey.startsWith('#');

    // Проверяем, состоим ли мы в группе
    final groupName = isGroup ? chatKey.substring(1) : null;
    final isMember = isGroup ? (_groupMembership[groupName] ?? true) : true;

    final role = isChannel ? _getChannelRole(chatKey) : null;
    final channelName = isChannel ? chatKey.substring(1) : null;
    final activeReply = _getReplyData(chatKey);

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
      onEditMessage: (msgId, newText) => _editMessage(chatKey, msgId, newText),
      onMarkRead: (ids) => _markRead(chatKey, ids),
      resolveDisplayName: _resolveDisplayName,
      isWide: isWide,
      onBack: _closeChat,
      titleOverride: (!isGroup && !isChannel) ? _displayNameFor(chatKey) : null,
      isOnline: _onlineUsers.contains(chatKey),
      lastSeen: _lastSeen[chatKey],
      channelRole: role,
      onSubscribe: channelName != null ? () => _subscribeToChannel(channelName) : null,

      isGroupMember: isMember,
      onJoinGroup: groupName != null ? () => _joinGroup(groupName) : null,

      activeReply: activeReply,
      onSetReply: (msgId) => _setReplyTo(chatKey, msgId),
      onCancelReply: () => _cancelReply(chatKey),
      resolveReply: (replyToId) => _resolveReplyFor(chatKey, replyToId),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('VartChat', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.username, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.chat, color: _currentView == ViewMode.chats ? Theme.of(context).primaryColor : null),
            title: const Text('Чаты'),
            selected: _currentView == ViewMode.chats,
            onTap: () { setState(() => _currentView = ViewMode.chats); Navigator.pop(context); },
          ),
          ListTile(
            leading: Icon(Icons.contacts, color: _currentView == ViewMode.contacts ? Theme.of(context).primaryColor : null),
            title: const Text('Контакты'),
            selected: _currentView == ViewMode.contacts,
            onTap: () { setState(() => _currentView = ViewMode.contacts); Navigator.pop(context); },
          ),
          ListTile(
            leading: Icon(Icons.group, color: _currentView == ViewMode.groups ? Theme.of(context).primaryColor : null),
            title: const Text('Группы'),
            selected: _currentView == ViewMode.groups,
            onTap: () { setState(() => _currentView = ViewMode.groups); Navigator.pop(context); },
          ),
          ListTile(
            leading: Icon(Icons.campaign, color: _currentView == ViewMode.channels ? Theme.of(context).primaryColor : null),
            title: const Text('Каналы'),
            selected: _currentView == ViewMode.channels,
            onTap: () { setState(() => _currentView = ViewMode.channels); Navigator.pop(context); },
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Выйти'), onTap: () { Navigator.pop(context); _logout(); }),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Удалить аккаунт', style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(context); _showDeleteAccountDialog(); },
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
            ListTile(leading: const Icon(Icons.group_add), title: const Text('Создать группу'), onTap: () { Navigator.pop(context); _showCreateGroupDialog(); }),
            ListTile(leading: const Icon(Icons.rss_feed), title: const Text('Создать канал'), onTap: () { Navigator.pop(context); _showCreateChannelDialog(); }),
            ListTile(leading: const Icon(Icons.contacts), title: const Text('Все пользователи'), onTap: () { Navigator.pop(context); setState(() => _currentView = ViewMode.contacts); }),
          ],
        ),
      ),
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
            width: 10, height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.wsService.isConnected ? Colors.green : Colors.red),
          ),
          const SizedBox(width: 8),
          Text(
            _isConnecting ? (isWide ? 'Подключение...' : 'Соединение...') : (widget.wsService.isConnected ? 'Подключено' : 'Отключено'),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text('Сервер: $_serverAddress', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildListScaffold({required bool isWide}) {
    return Scaffold(
      key: const ValueKey('__list__'),
      appBar: AppBar(
        title: Text('VartChat — ${widget.username}'),
        bottom: isWide ? null : PreferredSize(preferredSize: const Size.fromHeight(30), child: _connectionIndicator(isWide: isWide)),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showEditMenu, tooltip: 'Управление', child: const Icon(Icons.edit)),
      drawer: _buildDrawer(),
      drawerEnableOpenDragGesture: _selectedChat == null,
      body: _buildCurrentList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return Scaffold(
            appBar: AppBar(title: Text('VartChat — ${widget.username}')),
            drawer: _buildDrawer(),
            body: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 280,
                        child: Stack(
                          children: [
                            _buildCurrentList(),
                            Positioned(
                              right: 16, bottom: 16,
                              child: FloatingActionButton(onPressed: _showEditMenu, tooltip: 'Управление', child: const Icon(Icons.edit)),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _selectedChat != null ? _buildChatScreen(_selectedChat!, isWide: true) : const Center(child: Text('Выберите чат')),
                      ),
                    ],
                  ),
                ),
                _connectionIndicator(isWide: true),
              ],
            ),
          );
        }

        final width = constraints.maxWidth;
        return PopScope(
          canPop: _selectedChat == null,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_selectedChat != null) _closeChat();
          },
          child: Stack(
            children: [
              _buildListScaffold(isWide: false),
              if (_lastRenderedChat != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: _chatOpen ? 0 : width,
                  top: 0, bottom: 0, width: width,
                  child: _buildChatScreen(_lastRenderedChat!, isWide: false),
                ),
            ],
          ),
        );
      },
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(context, _ctrl.text.trim()), child: const Text('Подтвердить')),
      ],
    );
  }
}