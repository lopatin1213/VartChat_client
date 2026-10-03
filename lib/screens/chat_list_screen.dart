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
  static const int _historyPageSize = 1000;
  static const double _scrollTopThreshold = 400;
  static const Duration _getMsgBatchDelay = Duration(milliseconds: 150);

  List<({String phone, String username, String displayName})> _contacts = [];
  List<String> _groups = [];
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

  /// Восстановить поле recipient для Hive.
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
    _getMsgTimer?.cancel();
    _getMsgTimer = null;
    _pendingGetMsg.clear();
    _replyCache.clear();
    _requestedReplyIds.clear();
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
      final chatKey = _chatKeyFor(msg.sender, msg.recipient, msg.isMe);
      _messages.putIfAbsent(chatKey, () => []);
      _messages[chatKey]!.add((
      id: msg.id,
      sender: msg.sender,
      text: msg.text,
      isMe: msg.isMe,
      timestamp: msg.timestamp.millisecondsSinceEpoch,
      replyToId: msg.replyToId,
      readMe: msg.readMe,
      readAny: msg.readAny,
      views: msg.views,
      ));
    }
  }

  /// Merge нового/обновлённого сообщения: если id уже есть — обновляем флаги,
  /// иначе добавляем. Текст/ts/sender при merge не перетираем.
  /// Merge нового/обновлённого сообщения: если id уже есть — обновляем флаги,
  /// иначе добавляем. Текст/ts/sender при merge не перетираем.
  /// Если id > 0 и isMe — сначала убираем локальную заглушку (id == 0,
  /// совпадающая по тексту и близкому времени).
  void _mergeMessage(
      int id,
      String sender,
      String recipient,
      String text,
      bool isMe,
      int timestamp,
      int replyToId,
      bool readMe,
      bool readAny,
      int? views,
      ) {
    final chatKey = _chatKeyFor(sender, recipient, isMe);
    final list = _messages.putIfAbsent(chatKey, () => []);

    // Серверное эхо нашего сообщения — убираем локальную заглушку.
    if (id > 0 && isMe) {
      final localIdx = list.indexWhere((m) =>
      m.id == 0 &&
          m.isMe &&
          m.text == text &&
          (m.timestamp - timestamp).abs() < 10000);
      if (localIdx >= 0) {
        list.removeAt(localIdx);
      }
    }

    final idx = id != 0 ? list.indexWhere((m) => m.id == id) : -1;

    ChatMsg merged;
    if (idx >= 0) {
      final old = list[idx];
      merged = (
      id: old.id,
      sender: old.sender,
      text: old.text,
      isMe: old.isMe,
      timestamp: old.timestamp,
      replyToId: old.replyToId != 0 ? old.replyToId : replyToId,
      readMe: old.readMe || readMe,
      readAny: old.readAny || readAny,
      views: views ?? old.views,
      );
      list[idx] = merged;
    } else {
      merged = (
      id: id,
      sender: sender,
      text: text,
      isMe: isMe,
      timestamp: timestamp,
      replyToId: replyToId,
      readMe: readMe,
      readAny: readAny,
      views: views,
      );
      list.add(merged);
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    // Локальные заглушки (id == 0) в Hive не сохраняем — они эфемерные.
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
    );
    DatabaseService.saveMessage(message);
  }

  // ---------- 0x07 (READ) ----------

  void _sendReadForChat(String chatKey) {
    final msgs = _messages[chatKey];
    if (msgs == null || msgs.isEmpty) return;

    final kind = _kindForChat(chatKey);
    final ids = <int>[];
    for (final m in msgs) {
      if (m.isMe) continue;
      if (m.id == 0) continue;
      if (kind == Protocol.MSG_KIND_PERSONAL && m.readMe) continue;
      if (kind == Protocol.MSG_KIND_GROUP && m.readAny) continue;
      // для каналов шлём всех не своих — сервер IGNORE-ит дубликаты
      ids.add(m.id);
    }
    if (ids.isEmpty) return;

    final items = ids.map((id) => (kind: kind, msgId: id)).toList();
    try {
      widget.wsService.sendRead(items);
      print('[READ] Отправлено ${items.length} шт (kind=$kind)');
    } catch (e) {
      print('[READ] Ошибка отправки: $e');
    }
  }

  /// Вызывается из ChatScreen когда пользователь внизу и появились новые.
  void _markRead(String chatKey, List<int> msgIds) {
    if (msgIds.isEmpty) return;
    final kind = _kindForChat(chatKey);
    final items = msgIds.map((id) => (kind: kind, msgId: id)).toList();
    try {
      widget.wsService.sendRead(items);
    } catch (e) {
      print('[READ] Ошибка отправки: $e');
    }
  }

  void _handleReadIncoming(Uint8List payload) {
    final items = Protocol.parseReadPacket(payload);
    if (items.isEmpty) return;
    if (!mounted) return;

    setState(() {
      for (final it in items) {
        for (final entry in _messages.entries) {
          final list = entry.value;
          for (var i = 0; i < list.length; i++) {
            final m = list[i];
            if (m.id != it.msgId) continue;
            if (m.readAny) continue;
            list[i] = (
            id: m.id,
            sender: m.sender,
            text: m.text,
            isMe: m.isMe,
            timestamp: m.timestamp,
            replyToId: m.replyToId,
            readMe: m.readMe,
            readAny: true,
            views: m.views,
            );
            DatabaseService.saveMessage(ChatMessage(
              id: m.id,
              sender: m.sender,
              recipient: _recipientFor(m, entry.key),
              text: m.text,
              isMe: m.isMe,
              timestamp: DateTime.fromMillisecondsSinceEpoch(m.timestamp),
              replyToId: m.replyToId,
              readMe: m.readMe,
              readAny: true,
              views: m.views,
            ));
          }
        }
      }
    });
  }

  // ---------- /getmsg ----------

  void _scheduleGetMsg(int kind, int msgId) {
    if (msgId == 0) return;
    if (_requestedReplyIds.contains(msgId)) return;
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
      final kind = entry.key;
      final ids = entry.value.toList();
      if (ids.isEmpty) continue;
      final parts = <String>['/getmsg', '$kind'];
      for (final id in ids) {
        parts.add('$id');
      }
      final cmd = parts.join(' ');
      print('[REPLY] $cmd');
      try {
        widget.wsService.sendCommand(cmd);
      } catch (e) {
        print('[REPLY] Ошибка /getmsg: $e');
      }
    }
  }

  // ---------- Подписка / реконнект ----------

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

      // НЕ чистим Hive и _messages — дедуп по msgId в _mergeMessage.
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
      _getMsgTimer = null;

      _subscribeToMessages();
      _refreshChats();

      if (mounted) {
        setState(() => _isConnecting = false);
      }

      // Если чат открыт — перезапросим историю.
      final open = _selectedChat;
      if (open != null) {
        _fullyLoaded[open] = false;
        _historyLoading.remove(open);
        _requestHistoryInitial(open);
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

  // ---------- Обработка входящих ----------

  void _handleIncomingMessage(Uint8List data) {
    try {
      final parsed = Protocol.parsePacket(data);
      final type = parsed.type;
      final payload = parsed.payload;

      if (type == Protocol.MSG_TYPE_SYSTEM) {
        final text = Protocol.readString(payload, 0);
        debugPrint('[ChatList] SYSTEM: $text');

        if (text.startsWith('[Система] history_done|')) {
          final rest = text.substring('[Система] history_done|'.length);
          final parts = rest.split('|');
          if (parts.length >= 2) {
            final chatKey = parts[0];
            final count = int.tryParse(parts[1]) ?? 0;
            print('[HIST] history_done chat=$chatKey count=$count');
            if (mounted) {
              setState(() {
                _historyLoading.remove(chatKey);
                if (count < _historyPageSize) {
                  _fullyLoaded[chatKey] = true;
                }
              });
            }
          }
          return;
        }

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
          final name =
          text.substring(prefix.length, text.length - suffix.length).trim();
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
          final name =
          text.substring(prefix.length, text.length - suffix.length).trim();
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
          final usersPart =
          text.replaceFirst('[Система] Пользователи:', '').trim();
          if (!mounted) return;
          if (usersPart == 'Нет зарегистрированных пользователей') {
            setState(() {
              _contacts = [];
              _lastSeen.clear();
            });
          } else {
            final items = usersPart.split(',').map((s) => s.trim()).toList();
            final parsedList =
            <({String phone, String username, String displayName})>[];
            final newLastSeen = <String, int>{};
            for (final item in items) {
              if (item.isEmpty) continue;
              final parts = item.split('|');
              final phone = parts.isNotEmpty ? parts[0].trim() : '';
              final username = parts.length > 1 ? parts[1].trim() : '';
              final displayName =
              parts.length > 2 && parts[2].trim().isNotEmpty
                  ? parts[2].trim()
                  : username;
              final lastSeen =
              parts.length > 3 ? int.tryParse(parts[3].trim()) : null;
              if (username.isEmpty) continue;
              parsedList.add((
              phone: phone,
              username: username,
              displayName: displayName,
              ));
              if (lastSeen != null && lastSeen > 0) {
                newLastSeen[username] = lastSeen;
              }
            }
            setState(() {
              _contacts = parsedList;
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
            groupsPart =
            colonIdx != -1 ? text.substring(colonIdx + 1).trim() : '';
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
            channelsPart =
            colonIdx != -1 ? text.substring(colonIdx + 1).trim() : '';
          } else {
            channelsPart =
                text.replaceFirst('[Система] Ваши каналы:', '').trim();
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
      } else if (type == Protocol.MSG_TYPE_READ) {
        _handleReadIncoming(payload);
        return;
      } else if (type == Protocol.MSG_TYPE_USER) {
        final parsedUser = Protocol.parseUserPacket(payload);
        final sender = parsedUser.sender;
        final recipient = parsedUser.recipient;
        final encrypted = parsedUser.encrypted;
        final nonce = parsedUser.nonce;
        final timestamp = parsedUser.timestamp;
        final msgId = parsedUser.msgId;
        final replyToId = parsedUser.replyToId;
        final flagMe = parsedUser.flagMe;
        final flagAny = parsedUser.flagAny;
        final views = parsedUser.views;

        final key = widget.wsService.sessionKey;
        if (key == null) return;

        CryptoService.decryptAesGcm(encrypted, key, nonce).then((plaintext) {
          final text = utf8.decode(plaintext, allowMalformed: true);
          final isMe = sender == widget.username;
          if (!mounted) return;

          // Мы — получатель. Если сервер прислал flagMe=false, значит для нас
          // это сообщение ещё не прочитано (мы его сейчас прочитаем, потому что
          // оно попало в _handleIncomingMessage — но отметим в 0x07 отдельно).
          setState(() {
            _mergeMessage(
              msgId,
              sender,
              recipient,
              text,
              isMe,
              timestamp,
              replyToId,
              flagMe,
              flagAny,
              views,
            );

            if (msgId != 0) {
              _replyCache[msgId] =
              (sender: sender, text: text, isMe: isMe);
              _requestedReplyIds.remove(msgId);
            }
          });

          if (replyToId != 0) {
            final chatKey = _chatKeyFor(sender, recipient, isMe);
            final kind = _kindForChat(chatKey);
            if (!_hasMessageById(chatKey, replyToId) &&
                !_replyCache.containsKey(replyToId)) {
              _scheduleGetMsg(kind, replyToId);
            }
          }
        }).catchError((e) {
          print('Ошибка расшифровки: $e');
        });
      } else if (type == Protocol.MSG_TYPE_DELETE) {
        if (payload.length < 9) return;
        final msgId =
        ByteData.sublistView(payload, 0, 8).getInt64(0, Endian.big);
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
                id: m.id,
                sender: m.sender,
                text: m.text,
                isMe: m.isMe,
                timestamp: m.timestamp,
                replyToId: 0,
                readMe: m.readMe,
                readAny: m.readAny,
                views: m.views,
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

  // ---------- История ----------

  void _requestHistoryInitial(String chatKey) {
    if (_fullyLoaded[chatKey] == true) return;
    if (_historyLoading.contains(chatKey)) return;
    print('[HIST] Requesting initial history for $chatKey');
    _historyLoading.add(chatKey);
    try {
      widget.wsService.sendCommand('/history $chatKey');
    } catch (e) {
      print('[HIST] Ошибка отправки /history: $e');
      _historyLoading.remove(chatKey);
    }
  }

  void _requestHistoryOlder(String chatKey) {
    if (_fullyLoaded[chatKey] == true) return;
    if (_historyLoading.contains(chatKey)) return;
    final msgs = _messages[chatKey];
    if (msgs == null || msgs.isEmpty) return;
    final oldestId = msgs.first.id;
    if (oldestId == 0) return;
    print('[HIST] Requesting older history for $chatKey before $oldestId');
    _historyLoading.add(chatKey);
    try {
      widget.wsService.sendCommand('/history $chatKey $oldestId');
    } catch (e) {
      print('[HIST] Ошибка отправки /history: $e');
      _historyLoading.remove(chatKey);
    }
  }

  void _onScroll(String chatKey, ScrollController sc) {
    if (!sc.hasClients) return;
    if (_fullyLoaded[chatKey] == true) return;
    if (_historyLoading.contains(chatKey)) return;
    final pos = sc.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels >= pos.maxScrollExtent - _scrollTopThreshold) {
      _requestHistoryOlder(chatKey);
    }
  }

  // ---------- Удаление ----------

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
      _replyToMsgId.removeWhere((_, id) => id == msgId);
    });
    DatabaseService.deleteMessage(msgId);
    try {
      widget.wsService.sendDeleteMessage(msgId, kind, type: 1);
    } catch (e) {
      print('[ChatList] Ошибка отправки hide: $e');
    }
  }

  void _sendMessage(String chatKey, String text) {
    final replyToId = _replyToMsgId[chatKey] ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Локально добавим сообщение сразу — с id=0, покажем часы.
    setState(() {
      _mergeMessage(
        0,
        widget.username,
        chatKey,
        text,
        true,
        now,
        replyToId,
        true,   // readMe для своих всегда true
        false,  // readAny = false → одна галочка после эха
        null,
      );
    });

    widget.wsService.sendEncryptedMessage(chatKey, text, replyToId: replyToId);
    _getController(chatKey).clear();
    if (replyToId != 0) {
      setState(() => _replyToMsgId.remove(chatKey));
    }
  }

  void _setReplyTo(String chatKey, int msgId) {
    setState(() => _replyToMsgId[chatKey] = msgId);
  }

  void _cancelReply(String chatKey) {
    setState(() => _replyToMsgId.remove(chatKey));
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
    if (info == null) return ChannelRole.subscriber;
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
    final isOnline =
        username != widget.username && _onlineUsers.contains(username);
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
          return const Center(
              child: Text('Нет зарегистрированных пользователей'));
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
                    SnackBar(
                        content: Text('Выход из группы "$groupName"...')),
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
                  widget.wsService
                      .sendCommand('/unsubscribe $channelName');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Отписка от канала "$channelName"...')),
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
          ..sort((a, b) =>
              b.value.last.timestamp.compareTo(a.value.last.timestamp));
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

            final leading =
            isPersonal ? _buildAvatarWithStatus(chatKey, icon) : Icon(icon);

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

  void _openChat(String chatKey) {
    if (_selectedChat == chatKey) return;
    if (_selectedChat != null) {
      _disposeScrollController(_selectedChat!);
    }
    setState(() {
      _selectedChat = chatKey;
      _lastRenderedChat = chatKey;
      _chatOpen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _chatOpen = true);
      final sc = _scrollControllers[chatKey];
      if (sc != null && sc.hasClients) {
        sc.jumpTo(0);
      }
      _requestHistoryInitial(chatKey);
      // Отмечаем непрочитанные как прочитанные.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _selectedChat == chatKey) {
          _sendReadForChat(chatKey);
        }
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
      if (!mounted) return;
      if (_selectedChat == null) {
        setState(() => _lastRenderedChat = null);
        _disposeScrollController(chatKey);
      }
    });
  }

  Widget _buildChatScreen(String chatKey, {required bool isWide}) {
    final isChannel = chatKey.startsWith('&');
    final isGroup = chatKey.startsWith('#');
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
      onMarkRead: (ids) => _markRead(chatKey, ids),
      resolveDisplayName: _resolveDisplayName,
      isWide: isWide,
      onBack: _closeChat,
      titleOverride:
      (!isGroup && !isChannel) ? _displayNameFor(chatKey) : null,
      isOnline: _onlineUsers.contains(chatKey),
      lastSeen: _lastSeen[chatKey],
      channelRole: role,
      onSubscribe: channelName != null
          ? () => _subscribeToChannel(channelName)
          : null,
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
                const Text(
                  'VartChat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.username,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.chat,
              color: _currentView == ViewMode.chats
                  ? Theme.of(context).primaryColor
                  : null,
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
              color: _currentView == ViewMode.contacts
                  ? Theme.of(context).primaryColor
                  : null,
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
              color: _currentView == ViewMode.groups
                  ? Theme.of(context).primaryColor
                  : null,
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
              color: _currentView == ViewMode.channels
                  ? Theme.of(context).primaryColor
                  : null,
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
                setState(() => _currentView = ViewMode.contacts);
              },
            ),
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
                              right: 16,
                              bottom: 16,
                              child: FloatingActionButton(
                                onPressed: _showEditMenu,
                                tooltip: 'Управление',
                                child: const Icon(Icons.edit),
                              ),
                            ),
                          ],
                        ),
                      ),
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

        final width = constraints.maxWidth;
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
              _buildListScaffold(isWide: false),
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