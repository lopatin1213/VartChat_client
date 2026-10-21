import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_chat_markdown/flutter_ai_chat_markdown.dart';
import 'package:flutter_sdui_kit/flutter_sdui_kit.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/websocket_service.dart';

typedef ChatMsg = ({
int id,
int clientMsgId, // <--- ДОБАВЛЕНО СЮДА
String sender,
String text,
bool isMe,
int timestamp,
int replyToId,
bool readMe,
bool readAny,
int? views,
bool edited,
});

typedef ReplyPreview = ({String sender, String text, bool isMe});

enum ChannelRole { creator, subscriber, guest }

class ChatScreen extends StatefulWidget {
  final WebSocketService wsService;
  final String chatName;
  final String username;

  final List<ChatMsg> messages;

  final void Function(String text) onSendMessage;
  final void Function(int msgId)? onDeleteMessage;
  final void Function(int msgId)? onHideForMe;
  final void Function(int msgId, String newText)? onEditMessage;
  final String Function(String username)? resolveDisplayName;
  final void Function(List<int> msgIds)? onMarkRead;

  final ScrollController? scrollController;
  final VoidCallback? onBack;
  final bool isWide;

  final String? titleOverride;
  final bool isOnline;
  final int? lastSeen;

  final ChannelRole? channelRole;
  final VoidCallback? onSubscribe;
  final TextEditingController controller;
  final FocusNode? focusNode;

  final ReplyPreview? activeReply;
  final void Function(int msgId)? onSetReply;
  final VoidCallback? onCancelReply;
  final ReplyPreview? Function(int replyToId)? resolveReply;

  const ChatScreen({
    super.key,
    required this.wsService,
    required this.chatName,
    required this.username,
    required this.messages,
    required this.onSendMessage,
    required this.controller,
    this.onDeleteMessage,
    this.onHideForMe,
    this.onEditMessage,
    this.onMarkRead,
    this.resolveDisplayName,
    this.scrollController,
    this.focusNode,
    this.onBack,
    this.isWide = false,
    this.titleOverride,
    this.isOnline = false,
    this.lastSeen,
    this.channelRole,
    this.onSubscribe,
    this.activeReply,
    this.onSetReply,
    this.onCancelReply,
    this.resolveReply,
  });

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  Timer? _presenceTimer;

  final Set<int> _selectedIds = <int>{};
  final Map<int, GlobalKey> _msgKeys = {};
  int? _highlightedMsgId;

  int? _mdDisabledForId;
  int? _editingMsgId;
  String? _savedDraft;

  int _scrollGeneration = 0;

  bool _isAtBottom = true;
  int _lastMessagesLength = 0;

  static final ValueNotifier<bool> _intrinsicWidthDisabled = ValueNotifier<bool>(false);
  static bool _errorHandlerInstalled = false;

  static void _installErrorHandler() {
    if (_errorHandlerInstalled) return;
    _errorHandlerInstalled = true;

    final original = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final text = details.exceptionAsString();
      final isDryBaselineBug = text.contains('does not implement "computeDryBaseline"') ||
          (text.contains('computeDryBaseline') && text.contains('RenderLine'));
      if (isDryBaselineBug && !_intrinsicWidthDisabled.value) {
        debugPrint('[WORKAROUND] computeDryBaseline bug detected — IntrinsicWidth in message bubbles disabled for this session.');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_intrinsicWidthDisabled.value) _intrinsicWidthDisabled.value = true;
        });
      }
      if (original != null) {
        original(details);
      } else {
        FlutterError.presentError(details);
      }
    };
  }

  @override
  void initState() {
    super.initState();
    _lastMessagesLength = widget.messages.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fn = widget.focusNode;
      if (fn != null && fn.canRequestFocus && fn.hasFocus) {
        Timer(const Duration(milliseconds: 50), () {
          fn.requestFocus();
        });
      }
    });

    final sc = widget.scrollController;
    if (sc != null) sc.addListener(_onScrollListener);

    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (widget.titleOverride == null) return;
      if (widget.isOnline) return;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScrollListener);
      widget.scrollController?.addListener(_onScrollListener);
    }
    if (oldWidget.chatName != widget.chatName) {
      _editingMsgId = null;
      _savedDraft = null;
    }
    _handleNewMessages();
  }

  @override
  void dispose() {
    if (_editingMsgId != null) {
      final draft = _savedDraft ?? '';
      widget.controller.text = draft;
      widget.controller.selection = TextSelection.collapsed(offset: draft.length);
    }
    _presenceTimer?.cancel();
    widget.scrollController?.removeListener(_onScrollListener);
    _msgKeys.clear();
    super.dispose();
  }

  void _onScrollListener() {
    final sc = widget.scrollController;
    if (sc == null || !sc.hasClients) return;
    final atBottom = sc.offset < 80;
    if (atBottom != _isAtBottom) {
      setState(() => _isAtBottom = atBottom);
    }
    if (atBottom) {
      _sendReadForVisible();
    }
  }

  void _sendReadForVisible() {
    if (widget.onMarkRead == null) return;
    final ids = <int>[];
    for (final m in widget.messages) {
      if (m.isMe) continue;
      if (m.id == 0) continue;
      if (m.readMe) continue;
      if (widget.chatName.startsWith('#') && m.readAny) continue;
      ids.add(m.id);
    }
    if (ids.isEmpty) return;
    widget.onMarkRead!(ids);
  }

  void _handleNewMessages() {
    final len = widget.messages.length;
    if (len <= _lastMessagesLength) {
      _lastMessagesLength = len;
      return;
    }
    final newOnes = widget.messages.sublist(_lastMessagesLength);
    _lastMessagesLength = len;

    if (_isAtBottom && widget.onMarkRead != null) {
      final ids = <int>[];
      for (final m in newOnes) {
        if (m.isMe) continue;
        if (m.id == 0) continue;
        if (m.readMe) continue;
        ids.add(m.id);
      }
      if (ids.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onMarkRead!(ids);
        });
      }
    }

    if (newOnes.isNotEmpty && newOnes.last.isMe && _editingMsgId == null) {
      _scrollToBottom();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String? _buildPresenceSubtitle() {
    if (widget.titleOverride == null) return null;
    if (widget.isOnline) return 'в сети';

    final ls = widget.lastSeen;
    if (ls == null || ls == 0) return null;

    final now = DateTime.now();
    final dt = DateTime.fromMillisecondsSinceEpoch(ls);
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'был(а) менее минуты назад';
    if (diff.inMinutes < 60) return 'был(а) ${diff.inMinutes} мин назад';

    if (_isSameDay(now, dt)) {
      return 'был(а) в ${DateFormat('HH:mm').format(dt)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(yesterday, dt)) {
      return 'был(а) вчера';
    }

    return 'был(а) ${DateFormat('d MMM', 'ru').format(dt)}';
  }

  String _senderLabel(String sender) {
    if (widget.chatName.startsWith('&')) return widget.chatName.substring(1);
    return widget.resolveDisplayName?.call(sender) ?? sender;
  }

  String _autoLink(String text) {
    final codeParts = <String>[];
    var result = text.replaceAllMapped(RegExp(r'```[\s\S]*?```|`[^`\n]+`'), (m) {
      codeParts.add(m.group(0)!);
      return '\x00${codeParts.length - 1}\x00';
    });

    final linkParts = <String>[];
    result = result.replaceAllMapped(RegExp(r'\[[^\]]*\]\([^)]+\)'), (m) {
      linkParts.add(m.group(0)!);
      return '\x01${linkParts.length - 1}\x01';
    });

    final urlRegex = RegExp(r'https?://[^\s<>()]+|www\.[^\s<>()]+|\b[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\.[a-zA-Z]{2,})+(?:/[^\s<>()]*)?');

    result = result.replaceAllMapped(urlRegex, (m) {
      var url = m.group(0)!;
      while (url.isNotEmpty && '.,;:!?'.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
      }
      if (url.isEmpty) return m.group(0)!;
      final tld = url.split('.').last;
      if (tld.length < 2 || RegExp(r'^\d+$').hasMatch(tld)) return m.group(0)!;
      final href = url.startsWith('http') ? url : 'https://$url';
      return '[$url]($href)';
    });

    for (var i = 0; i < linkParts.length; i++) {
      result = result.replaceAll('\x01$i\x01', linkParts[i]);
    }
    for (var i = 0; i < codeParts.length; i++) {
      result = result.replaceAll('\x00$i\x00', codeParts[i]);
    }
    return result;
  }

  void _wrapSelection(String prefix, String suffix, {String placeholder = 'текст'}) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    if (!sel.isValid) {
      final insert = '$prefix$placeholder$suffix';
      widget.controller.text = text + insert;
      widget.controller.selection = TextSelection.collapsed(offset: text.length + prefix.length + placeholder.length);
      return;
    }
    final selected = sel.textInside(text);
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    final insert = selected.isEmpty ? '$prefix$placeholder$suffix' : '$prefix$selected$suffix';
    widget.controller.text = before + insert + after;
    final newOffset = selected.isEmpty ? before.length + prefix.length + placeholder.length : before.length + insert.length;
    widget.controller.selection = TextSelection.collapsed(offset: newOffset);
  }

  void _insertLink() {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final selected = sel.isValid ? sel.textInside(text) : '';
    final label = selected.isEmpty ? 'текст' : selected;
    final insert = '[$label](https://)';
    if (sel.isValid) {
      final before = text.substring(0, sel.start);
      final after = text.substring(sel.end);
      widget.controller.text = before + insert + after;
      widget.controller.selection = TextSelection.collapsed(offset: before.length + label.length + 3);
    } else {
      widget.controller.text = text + insert;
      widget.controller.selection = TextSelection.collapsed(offset: text.length + insert.length);
    }
  }

  void _insertLinePrefix(String prefix) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;

    if (!sel.isValid) {
      final newText = text + '\n$prefix';
      widget.controller.text = newText;
      widget.controller.selection = TextSelection.collapsed(offset: newText.length);
      return;
    }

    if (sel.isCollapsed) {
      final lineStart = sel.start > 0 ? text.lastIndexOf('\n', sel.start - 1) + 1 : 0;
      final newText = text.substring(0, lineStart) + prefix + text.substring(lineStart);
      widget.controller.text = newText;
      widget.controller.selection = TextSelection.collapsed(offset: sel.start + prefix.length);
      return;
    }

    final selected = sel.textInside(text);
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    final lines = selected.split('\n');

    String newTextBlock;

    // Если это нумерованный список ("1. "), делаем автоинкремент
    if (prefix == '1. ') {
      final newLines = <String>[];
      for (int i = 0; i < lines.length; i++) {
        newLines.add('${i + 1}. ${lines[i]}');
      }
      newTextBlock = newLines.join('\n');
    } else {
      // Для цитат ("> ") и маркеров ("- ") просто ставим префикс
      newTextBlock = lines.map((line) => '$prefix$line').join('\n');
    }

    widget.controller.text = before + newTextBlock + after;

    // Оставляем выделение на измененном тексте
    widget.controller.selection = TextSelection(
      baseOffset: sel.start,
      extentOffset: sel.start + newTextBlock.length,
    );
  }

  void _insertBlock(String block) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final selected = sel.isValid ? sel.textInside(text) : '';
    final content = selected.isEmpty ? 'код' : selected;
    final insert = '$block\n$content\n$block';
    if (sel.isValid) {
      final before = text.substring(0, sel.start);
      final after = text.substring(sel.end);
      widget.controller.text = before + insert + after;
      widget.controller.selection = TextSelection.collapsed(offset: before.length + insert.length);
    } else {
      widget.controller.text = text + insert;
      widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
    }
  }

  Widget _buildFormattingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolbarButton(Icons.format_bold, 'Жирный', () => _wrapSelection('**', '**', placeholder: 'жирный')),
            _toolbarButton(Icons.format_italic, 'Курсив', () => _wrapSelection('*', '*', placeholder: 'курсив')),
            _toolbarButton(Icons.code, 'Инлайн-код', () => _wrapSelection('`', '`', placeholder: 'код')),
            _toolbarButton(Icons.data_object, 'Блок кода', () => _insertBlock('```')),
            _toolbarButton(Icons.link, 'Ссылка', _insertLink),
            _toolbarButton(Icons.format_quote, 'Цитата', () => _insertLinePrefix('> ')),
            _toolbarButton(Icons.format_list_bulleted, 'Список', () => _insertLinePrefix('- ')),
            _toolbarButton(Icons.format_list_numbered, 'Нумерованный список', () => _insertLinePrefix('1. ')),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final formatter = DateFormat('d MMMM yyyy', 'ru');
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(50)),
        child: Text(formatter.format(date), style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ),
    );
  }

  bool _canDelete(bool isMe) {
    final chatKey = widget.chatName;
    if (chatKey.startsWith('#')) return false;
    if (chatKey.startsWith('&')) return widget.channelRole == ChannelRole.creator;
    return isMe;
  }

  bool _canEdit(bool isMe) {
    final chatKey = widget.chatName;
    if (chatKey.startsWith('&')) return widget.channelRole == ChannelRole.creator;
    return isMe;
  }

  bool _canDeleteAllSelected() {
    if (_selectedIds.isEmpty) return false;
    final chatKey = widget.chatName;
    if (chatKey.startsWith('#')) return false;
    if (chatKey.startsWith('&')) return widget.channelRole == ChannelRole.creator;
    for (final msg in widget.messages) {
      if (_selectedIds.contains(msg.id) && !msg.isMe) return false;
    }
    return true;
  }

  bool _canHideForMe() => !widget.chatName.startsWith('&');

  bool _canHideAllSelected() {
    if (_selectedIds.isEmpty) return false;
    return _canHideForMe();
  }

  void _enterSelection(int msgId) => setState(() => _selectedIds.add(msgId));
  void _toggleSelection(int msgId) {
    setState(() {
      if (_selectedIds.contains(msgId)) {
        _selectedIds.remove(msgId);
      } else {
        _selectedIds.add(msgId);
      }
    });
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(() {
      _selectedIds.clear();
      _mdDisabledForId = null;
    });
  }

  String _buildCopyText() {
    final buf = StringBuffer();
    int? prevIdx;
    String? prevLabel;
    int? prevTs;

    for (int i = 0; i < widget.messages.length; i++) {
      final msg = widget.messages[i];
      if (!_selectedIds.contains(msg.id)) continue;

      final label = _senderLabel(msg.sender);
      final isAdjacent = prevIdx != null && i == prevIdx + 1;
      final sameSender = prevLabel == label;
      final withinMinute = prevTs != null && (msg.timestamp - prevTs).abs() <= 60000;
      final continueBlock = isAdjacent && sameSender && withinMinute;

      if (continueBlock) {
        buf.writeln();
        buf.writeln(msg.text);
      } else {
        if (prevIdx != null) buf.writeln();
        final dt = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
        final ds = DateFormat('dd.MM.yyyy HH:mm').format(dt);
        buf.writeln('$ds $label:');
        buf.writeln(msg.text);
      }

      prevIdx = i;
      prevLabel = label;
      prevTs = msg.timestamp;
    }

    var s = buf.toString();
    while (s.endsWith('\n')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  void _copySelected() {
    if (_selectedIds.isEmpty) return;
    final text = _buildCopyText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Скопировано сообщений: ${_selectedIds.length}')));
    setState(() => _selectedIds.clear());
  }

  void _deleteSelected() {
    final ids = List<int>.from(_selectedIds);
    setState(() => _selectedIds.clear());
    for (final id in ids) {
      widget.onDeleteMessage?.call(id);
    }
  }

  void _hideSelectedForMe() {
    final ids = List<int>.from(_selectedIds);
    setState(() => _selectedIds.clear());
    for (final id in ids) {
      widget.onHideForMe?.call(id);
    }
  }

  void _handleTap(int msgId, String text, bool isMe, Offset globalPos) {
    if (!mounted) return;
    if (_mdDisabledForId != null) {
      if (_mdDisabledForId != msgId) {
        setState(() {
          _mdDisabledForId = null;
          _selectedIds.clear();
        });
      }
      return;
    }
    if (_selectedIds.isNotEmpty) {
      _toggleSelection(msgId);
      return;
    }
    final size = MediaQuery.of(context).size;
    final position = RelativeRect.fromLTRB(globalPos.dx, globalPos.dy, size.width - globalPos.dx, size.height - globalPos.dy);
    _showContextMenu(msgId, text, isMe, position);
  }

  void _handleLongPress(int msgId) {
    if (_mdDisabledForId != null) {
      setState(() {
        _mdDisabledForId = null;
        _selectedIds.clear();
      });
      return;
    }
    if (_selectedIds.isEmpty) {
      _enterSelection(msgId);
      return;
    }
    if (_selectedIds.contains(msgId) && _selectedIds.length == 1) {
      setState(() => _mdDisabledForId = msgId);
      return;
    }
    _toggleSelection(msgId);
  }

  Future<void> _showContextMenu(int msgId, String text, bool isMe, RelativeRect position) async {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(value: 'reply', height: 44, child: Row(children: [Icon(Icons.reply, size: 20), SizedBox(width: 12), Text('Ответить')])),
      const PopupMenuItem<String>(value: 'copy', height: 44, child: Row(children: [Icon(Icons.copy, size: 20), SizedBox(width: 12), Text('Копировать')])),
    ];
    if (msgId != 0 && _canEdit(isMe)) {
      items.add(const PopupMenuItem<String>(value: 'edit', height: 44, child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 12), Text('Редактировать')])));
    }
    if (_canDelete(isMe)) {
      items.add(const PopupMenuItem<String>(value: 'delete', height: 44, child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 12), Text('Удалить у всех', style: TextStyle(color: Colors.red))])));
    }
    if (_canHideForMe()) {
      items.add(const PopupMenuItem<String>(value: 'hide', height: 44, child: Row(children: [Icon(Icons.delete_outline, size: 20, color: Colors.red), SizedBox(width: 12), Text('Удалить у себя', style: TextStyle(color: Colors.red))])));
    }

    final result = await showMenu<String>(context: context, position: position, items: items);
    if (!mounted) return;
    if (result == 'reply') {
      if (_editingMsgId != null) _cancelEdit();
      widget.onSetReply?.call(msgId);
    } else if (result == 'copy') {
      _copyText(text);
    } else if (result == 'edit') {
      _startEdit(msgId, text);
    } else if (result == 'delete') {
      widget.onDeleteMessage?.call(msgId);
    } else if (result == 'hide') {
      widget.onHideForMe?.call(msgId);
    }
  }

  void _startEdit(int msgId, String text) {
    if (!mounted) return;
    if (_editingMsgId == msgId) {
      widget.focusNode?.requestFocus();
      return;
    }
    if (_editingMsgId == null) _savedDraft = widget.controller.text;
    if (widget.activeReply != null) widget.onCancelReply?.call();
    setState(() {
      _editingMsgId = msgId;
      _selectedIds.clear();
      _mdDisabledForId = null;
      widget.controller.text = text;
      widget.controller.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode?.requestFocus();
    });
  }

  void _cancelEdit() {
    if (_editingMsgId == null) return;
    final draft = _savedDraft ?? '';
    setState(() {
      _editingMsgId = null;
      _savedDraft = null;
      widget.controller.text = draft;
      widget.controller.selection = TextSelection.collapsed(offset: draft.length);
    });
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован')));
  }

  void _scrollToBottom() {
    final sc = widget.scrollController;
    if (sc == null || !sc.hasClients) return;
    final distance = sc.offset;
    if (distance <= 0.5) return;
    final durationMs = distance.clamp(80.0, 300.0).toInt();
    sc.animateTo(0, duration: Duration(milliseconds: durationMs), curve: Curves.easeOutCubic);
  }

  Future<void> _scrollToMessage(int targetId) async {
    final gen = ++_scrollGeneration;

    setState(() => _highlightedMsgId = targetId);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _highlightedMsgId == targetId) setState(() => _highlightedMsgId = null);
    });

    final key = _msgKeys.putIfAbsent(targetId, () => GlobalKey());
    if (key.currentContext != null) {
      try {
        await Scrollable.ensureVisible(key.currentContext!, duration: const Duration(milliseconds: 300), alignment: 0.5, curve: Curves.easeOutCubic);
      } catch (_) {}
      return;
    }

    final msgs = widget.messages;
    final idx = msgs.indexWhere((m) => m.id == targetId);
    if (idx < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сообщение не в загруженной истории')));
        if (_highlightedMsgId == targetId) setState(() => _highlightedMsgId = null);
      }
      return;
    }

    final sc = widget.scrollController;
    if (sc == null || !sc.hasClients) return;

    final revIndex = msgs.length - 1 - idx;
    double avgHeight = 72.0;
    const maxAttempts = 6;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted || gen != _scrollGeneration) return;
      final estimated = (revIndex * avgHeight).clamp(0.0, sc.position.maxScrollExtent);
      try {
        await sc.animateTo(estimated, duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic);
      } catch (_) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted || gen != _scrollGeneration) return;

      final ctx = _msgKeys[targetId]?.currentContext;
      if (ctx != null) {
        try {
          await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 180), alignment: 0.5, curve: Curves.easeOutCubic);
        } catch (_) {}
        return;
      }
      avgHeight *= 0.6;
    }
  }

  bool _mayContainWidgetSpan(String text) {
    if (RegExp(r'\$\$[^$]+\$\$').hasMatch(text)) return true;
    if (RegExp(r'\$[^$\n]+\$').hasMatch(text)) return true;
    return false;
  }

  bool _isImageMarkdown(String text) {
    return RegExp(r'!\[[^\]]*\]\([^)]+\)').hasMatch(text.trim());
  }

  Widget _buildReplyQuoteInBubble(ReplyPreview quote, bool isMe, Color textColor) {
    final accent = isMe ? Colors.green[800]! : Theme.of(context).colorScheme.primary;

    // Если цитата - это картинка, рисуем миниатюру
    if (_isImageMarkdown(quote.text)) {
      final match = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').firstMatch(quote.text.trim());
      final url = match?.group(2) ?? '';
      final alt = match?.group(1) ?? 'Картинка';

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: isMe ? 0.06 : 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _senderLabel(quote.sender),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: accent),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  url,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60, height: 60, color: Colors.black12,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, size: 20, color: textColor.withValues(alpha: 0.7)),
                        if (alt.isNotEmpty && alt != 'Картинка')
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(alt, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: textColor)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Обычный текст: очищаем ссылки
    var cleanText = quote.text.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: isMe ? 0.06 : 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _senderLabel(quote.sender),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: accent),
            ),
            Text(
              cleanText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcons(ChatMsg m, Color textColor) {
    final isChannel = widget.chatName.startsWith('&');
    final children = <Widget>[];

    if (isChannel && m.views != null) {
      children.add(Icon(Icons.visibility, size: 12, color: textColor.withValues(alpha: 0.7)));
      children.add(const SizedBox(width: 2));
      children.add(Text('${m.views}', style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7))));
    }

    if (m.isMe && !isChannel) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 4));
      final IconData icon;
      final Color color;
      if (m.id == 0) {
        icon = Icons.access_time;
        color = textColor.withValues(alpha: 0.5);
      } else if (m.readAny) {
        icon = Icons.done_all;
        color = Colors.blue[700]!;
      } else {
        icon = Icons.done;
        color = textColor.withValues(alpha: 0.7);
      }
      children.add(Icon(icon, size: 12, color: color));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildMessageBubble(
      int msgId,
      String sender,
      String text,
      bool isMe,
      int timestamp,
      int replyToId,
      bool readMe,
      bool readAny,
      int? views,
      bool edited,
      bool isGroupOrChannel,
      double maxWidth,
      ) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final backgroundColor = isMe ? Colors.green[100] : Theme.of(context).colorScheme.secondary;
    final textColor = isMe ? Colors.black87 : Theme.of(context).colorScheme.onSecondary;
    final isSelected = _selectedIds.contains(msgId);
    final isHighlighted = _highlightedMsgId == msgId;
    final mdDisabled = _mdDisabledForId == msgId;
    final isBeingEdited = _editingMsgId == msgId;

    final markdownTheme = MarkdownTheme.chatGptLight.copyWith(
      paragraph: TextStyle(color: textColor, fontSize: 14),
      code: TextStyle(color: textColor, backgroundColor: Colors.black.withValues(alpha: 0.1), fontFamily: 'monospace', fontSize: 13),
      codeBackground: isMe ? Colors.black.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.2),
      codeRadius: BorderRadius.circular(8),
      codePadding: const EdgeInsets.all(12),
      codeHighlightTheme: 'darcula', // <--- ТЕМА PYCHARM
      showCodeLanguageLabel: true,
      showCodeCopyButton: true,
      linkStyle: TextStyle(color: isMe ? Colors.blue[800] : Colors.blue[200], decoration: TextDecoration.underline),
      blockquote: TextStyle(color: textColor.withValues(alpha: 0.8)),
      blockquoteBar: textColor.withValues(alpha: 0.3),
      showCaret: false,
      tokenFadeIn: Duration.zero,
      blockSpacing: 6.0,
    );

    ReplyPreview? quote;
    if (replyToId != 0 && widget.resolveReply != null) {
      quote = widget.resolveReply!(replyToId);
    }

    Widget body;
    if (mdDisabled) {
      body = SelectionArea(child: Text(text, style: TextStyle(color: textColor, fontSize: 14)));
    } else {
      body = MarkdownRenderer(data: _autoLink(text), theme: markdownTheme, onTapLink: (url) => _openLink(url));
    }

    final bubbleContent = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
        border: isSelected
            ? Border.all(color: Colors.blue, width: 2)
            : isHighlighted
            ? Border.all(color: Colors.orange, width: 2.5)
            : isBeingEdited
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe && isGroupOrChannel)
            Text(_senderLabel(sender), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor)),
          if (quote != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _scrollToMessage(replyToId),
              child: _buildReplyQuoteInBubble(quote, isMe, textColor),
            ),
          body,
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(DateFormat('HH:mm').format(date), style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7))),
                if (edited) ...[
                  const SizedBox(width: 4),
                  Text('изм.', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: textColor.withValues(alpha: 0.7))),
                ],
                const SizedBox(width: 4),
                _buildStatusIcons(
                  (
                  id: msgId,
                  clientMsgId: 0, // не используется в UI
                  sender: sender,
                  text: text,
                  isMe: isMe,
                  timestamp: timestamp,
                  replyToId: replyToId,
                  readMe: readMe,
                  readAny: readAny,
                  views: views,
                  edited: edited,
                  ),
                  textColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final forceNoIntrinsic = _mayContainWidgetSpan(text);

    if (mdDisabled) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: LayoutErrorBoundary(
          nodeType: 'message_bubble',
          child: ValueListenableBuilder<bool>(
            valueListenable: _intrinsicWidthDisabled,
            child: bubbleContent,
            builder: (context, disabled, child) {
              if (disabled || forceNoIntrinsic) return child!;
              return IntrinsicWidth(child: child);
            },
          ),
        ),
      );
    }

    final gestureWrapped = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(msgId, text, isMe, details.globalPosition),
      onLongPress: () => _handleLongPress(msgId),
      child: bubbleContent,
    );

    final keyedBubble = KeyedSubtree(
      key: _msgKeys.putIfAbsent(msgId, () => GlobalKey()),
      child: gestureWrapped,
    );

    Widget swipeable = keyedBubble;
    if (widget.onSetReply != null) {
      swipeable = Dismissible(
        key: ValueKey('reply_swipe_$msgId'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (dir) async {
          if (_editingMsgId != null) _cancelEdit();
          widget.onSetReply!.call(msgId);
          return false;
        },
        background: const SizedBox.shrink(),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 28),
          child: Icon(Icons.reply, color: Theme.of(context).colorScheme.primary, size: 24),
        ),
        child: keyedBubble,
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: LayoutErrorBoundary(
        nodeType: 'message_bubble',
        child: ValueListenableBuilder<bool>(
          valueListenable: _intrinsicWidthDisabled,
          child: swipeable,
          builder: (context, disabled, child) {
            if (disabled || forceNoIntrinsic) return child!;
            return IntrinsicWidth(child: child);
          },
        ),
      ),
    );
  }

  Widget _buildReplyPreviewBar() {
    final reply = widget.activeReply;
    if (reply == null) return const SizedBox.shrink();

    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!), left: BorderSide(color: accent, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_senderLabel(reply.sender), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: accent)),
                Text(reply.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Отменить ответ',
            onPressed: widget.onCancelReply,
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreviewBar() {
    final msgId = _editingMsgId;
    if (msgId == null) return const SizedBox.shrink();

    String previewText = '';
    for (final m in widget.messages) {
      if (m.id == msgId) {
        previewText = m.text;
        break;
      }
    }

    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!), left: BorderSide(color: accent, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Редактирование', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: accent)),
                Text(previewText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Отменить редактирование',
            onPressed: _cancelEdit,
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(EdgeInsets padding) {
    final isEditing = _editingMsgId != null;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                // Перехватываем чистый Enter (и Enter на нумпаде)
                const SingleActivator(LogicalKeyboardKey.enter): () {
                  _sendMessage();
                },
                const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
                  _sendMessage();
                },
                // Ctrl+Enter и Shift+Enter автоматически НЕ перехватываются
                // и уходят в TextField как перенос строки (\n)
              },
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                decoration: InputDecoration(
                  hintText: isEditing ? 'Редактирование...' : 'Сообщение...',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.send),
            tooltip: isEditing ? 'Сохранить' : 'Отправить',
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(EdgeInsets padding) {
    return Container(
      padding: EdgeInsets.only(bottom: padding.bottom, left: 12, right: 12, top: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onSubscribe,
            icon: const Icon(Icons.add),
            label: const Text('Подписаться'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomArea(EdgeInsets inputPadding) {
    final isChannel = widget.chatName.startsWith('&');
    final isEditing = _editingMsgId != null;

    Widget previewBar;
    if (isEditing) {
      previewBar = _buildEditPreviewBar();
    } else {
      previewBar = _buildReplyPreviewBar();
    }

    if (!isChannel) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          previewBar,
          _buildFormattingToolbar(),
          _buildInputField(inputPadding),
        ],
      );
    }

    final role = widget.channelRole ?? ChannelRole.guest;
    switch (role) {
      case ChannelRole.creator:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            previewBar,
            _buildFormattingToolbar(),
            _buildInputField(inputPadding),
          ],
        );
      case ChannelRole.subscriber:
        return const SizedBox.shrink();
      case ChannelRole.guest:
        return _buildSubscribeButton(inputPadding);
    }
  }

  AppBar _buildNormalAppBar() {
    final String displayName = widget.titleOverride ?? widget.chatName.replaceFirst(RegExp(r'^[#&]'), '');
    final bool isGroup = widget.chatName.startsWith('#');
    final bool isChannel = widget.chatName.startsWith('&');
    final IconData leadingIcon = isGroup ? Icons.group : (isChannel ? Icons.campaign : Icons.person);

    final presenceSubtitle = _buildPresenceSubtitle();

    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          Icon(leadingIcon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(displayName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18)),
                if (presenceSubtitle != null)
                  Text(
                    presenceSubtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: widget.isOnline ? FontWeight.w600 : FontWeight.normal,
                      color: widget.isOnline ? Colors.green : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      leading: widget.onBack != null
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack)
          : null,
    );
  }

  AppBar _buildSelectionAppBar() {
    final canDeleteAll = _canDeleteAllSelected();
    final canHideAll = _canHideAllSelected();
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Отмена', onPressed: _clearSelection),
      title: Text('Выбрано: ${_selectedIds.length}'),
      actions: [
        IconButton(icon: const Icon(Icons.copy), tooltip: 'Копировать', onPressed: _copySelected),
        if (canDeleteAll) IconButton(icon: const Icon(Icons.delete), tooltip: 'Удалить у всех', onPressed: _deleteSelected),
        if (canHideAll) IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Удалить у себя', onPressed: _hideSelectedForMe),
      ],
    );
  }

  int _unreadCount() {
    var n = 0;
    for (final m in widget.messages) {
      if (m.isMe) continue;
      if (m.readMe) continue;
      n++;
    }
    return n;
  }

  Widget _buildScrollToBottomButton() {
    final n = _unreadCount();
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          _scrollToBottom();
          _sendReadForVisible();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.keyboard_arrow_down, size: 24, color: Theme.of(context).colorScheme.primary),
              if (n > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        n > 99 ? '99+' : '$n',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.messages;
    final isGroupOrChannel = widget.chatName.startsWith('#') || widget.chatName.startsWith('&');
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = widget.isWide ? screenWidth * 0.5 : screenWidth * 0.75;

    final List<Widget> items = [];
    DateTime? lastDate;
    for (int i = 0; i < msgs.length; i++) {
      final msg = msgs[i];
      final msgDate = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
      if (lastDate == null || !_isSameDay(lastDate, msgDate)) {
        items.add(_buildDateDivider(msgDate));
        lastDate = msgDate;
      }
      items.add(_buildMessageBubble(
        msg.id,
        msg.sender,
        msg.text,
        msg.isMe,
        msg.timestamp,
        msg.replyToId,
        msg.readMe,
        msg.readAny,
        msg.views,
        msg.edited,
        isGroupOrChannel,
        maxBubbleWidth,
      ));
    }

    final inputPadding = EdgeInsets.only(bottom: widget.isWide ? 8 : 58, left: 8, right: 8, top: 8);
    final appBar = _selectedIds.isEmpty ? _buildNormalAppBar() : _buildSelectionAppBar();
    final canPop = _selectedIds.isEmpty && _mdDisabledForId == null && _editingMsgId == null;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_editingMsgId != null) {
          _cancelEdit();
        } else if (_mdDisabledForId != null) {
          setState(() {
            _mdDisabledForId = null;
            _selectedIds.clear();
          });
        } else if (_selectedIds.isNotEmpty) {
          _clearSelection();
        }
      },
      child: Scaffold(
        appBar: appBar,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: widget.scrollController,
                    reverse: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) => items[items.length - 1 - index],
                  ),
                  if (!_isAtBottom && msgs.isNotEmpty)
                    Positioned(right: 16, bottom: 16, child: _buildScrollToBottomButton()),
                ],
              ),
            ),
            _buildBottomArea(inputPadding),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    if (_editingMsgId != null) {
      final id = _editingMsgId!;
      widget.onEditMessage?.call(id, text);
      _cancelEdit();
      return;
    }

    widget.onSendMessage(text);
    widget.controller.clear();
    _scrollToBottom();
  }

  Future<void> _openLink(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть: $href')));
    }
  }
}