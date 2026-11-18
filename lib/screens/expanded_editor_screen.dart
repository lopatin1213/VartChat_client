import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

class ExpandedEditorScreen extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String text) onSendMessage;

  const ExpandedEditorScreen({
    super.key,
    required this.controller,
    required this.onSendMessage,
  });

  @override
  State<ExpandedEditorScreen> createState() => _ExpandedEditorScreenState();
}

class _ExpandedEditorScreenState extends State<ExpandedEditorScreen> {
  late af.EditorState _editorState;
  late af.EditorScrollController _scrollController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Начальный markdown берём из переданного контроллера основного поля ввода.
    final document = af.markdownToDocument(widget.controller.text);
    _editorState = af.EditorState(document: document);
    _scrollController = af.EditorScrollController(editorState: _editorState);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _editorState.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Конвертируем текущий документ обратно в Markdown.
  String _toMarkdown() => af.documentToMarkdown(_editorState.document);

  /// Сохраняем результат в исходный контроллер и закрываем без отправки.
  void _closeAndSave() {
    widget.controller.text = _toMarkdown();
    Navigator.pop(context);
  }

  /// Конвертируем в Markdown, отправляем и закрываем.
  void _send() {
    final markdown = _toMarkdown();
    widget.onSendMessage(markdown);
    widget.controller.clear();
    Navigator.pop(context);
  }

  /// Программно вставляет таблицу заданного размера в конец документа.
  void _insertTable(int rows, int cols) {
    final table = af.TableNode.fromList(
      List.generate(cols, (_) => List.generate(rows, (_) => '')),
    );
    final transaction = _editorState.transaction;
    transaction.insertNode([_editorState.document.root.children.length], table.node);
    _editorState.apply(transaction);
  }

  // --- Кнопки форматирования ---
  void _toggleAttribute(String key) {
    _editorState.toggleAttribute(key);
  }

  void _insertBlockAfterSelection(void Function(af.EditorState) fn) {
    fn(_editorState);
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
            _toolbarButton(
              Icons.format_bold,
              'Жирный',
                  () => _toggleAttribute(af.AppFlowyRichTextKeys.bold),
            ),
            _toolbarButton(
              Icons.format_italic,
              'Курсив',
                  () => _toggleAttribute(af.AppFlowyRichTextKeys.italic),
            ),
            _toolbarButton(
              Icons.code,
              'Инлайн-код',
                  () => _toggleAttribute(af.AppFlowyRichTextKeys.code),
            ),
            _toolbarButton(
              Icons.strikethrough_s,
              'Зачёркнутый',
                  () => _toggleAttribute(af.AppFlowyRichTextKeys.strikethrough),
            ),
            _toolbarButton(
              Icons.format_list_numbered,
              'Нумерованный список',
                  () => _insertBlockAfterSelection(
                  af.insertNumberedListAfterSelection),
            ),
            _toolbarButton(
              Icons.format_list_bulleted,
              'Маркированный список',
                  () => _insertBlockAfterSelection(
                  af.insertBulletedListAfterSelection),
            ),
            _toolbarButton(
              Icons.format_quote,
              'Цитата',
                  () => _insertBlockAfterSelection(af.insertQuoteAfterSelection),
            ),
            _toolbarButton(
              Icons.looks_one,
              'Заголовок H1',
                  () => _insertBlockAfterSelection(
                  (es) => af.insertHeadingAfterSelection(es, 1)),
            ),
            _toolbarButton(
              Icons.looks_two,
              'Заголовок H2',
                  () => _insertBlockAfterSelection(
                  (es) => af.insertHeadingAfterSelection(es, 2)),
            ),
            _toolbarButton(Icons.table_chart, 'Таблица', _showTableDialog),
          ],
        ),
      ),
    );
  }

  void _showTableDialog() {
    final rowsCtrl = TextEditingController(text: '2');
    final colsCtrl = TextEditingController(text: '2');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вставить таблицу'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rowsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Строки'),
            ),
            TextField(
              controller: colsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Столбцы'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final rows = int.tryParse(rowsCtrl.text) ?? 2;
              final cols = int.tryParse(colsCtrl.text) ?? 2;
              if (rows > 0 && cols > 0 && rows <= 10 && cols <= 10) {
                Navigator.pop(ctx);
                _insertTable(rows, cols);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Размеры от 1 до 10')),
                );
              }
            },
            child: const Text('Вставить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final md = _toMarkdown();
    final byteSize = md.codeUnits.length;
    const maxSize = 64 * 1024;
    final isOverLimit = byteSize > maxSize;
    final sizeStr = (byteSize / 1024).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактор'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeAndSave,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: af.AppFlowyEditor(
                editorState: _editorState,
                editorScrollController: _scrollController,
                editorStyle: const af.EditorStyle.desktop(),
              ),
            ),
            _buildFormattingToolbar(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Text(
                    'Размер: $sizeStr КБ / 64 КБ',
                    style: TextStyle(
                      fontSize: 10,
                      color: isOverLimit ? Colors.red : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: isOverLimit ? null : _send,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Отправить'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}