import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:quill_delta_markdown/quill_delta_markdown.dart';

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
  late quill.QuillController _quillController;
  final FocusNode _focusNode = FocusNode();

  static final MarkdownExporter _exporter = MarkdownExporter();
  static final MarkdownImporter _importer = MarkdownImporter();

  @override
  void initState() {
    super.initState();
    // Начальный markdown берём из переданного контроллера основного поля ввода.
    final markdown = widget.controller.text;
    // Если текст пуст, importSync вернёт пустую Delta, а Document обнулять нельзя.
    // Создаём документ только если есть содержимое, иначе — пустой документ с новой строкой.
    late quill.Document document;
    if (markdown.trim().isEmpty) {
      document = quill.Document();
    } else {
      final delta = _importer.importSync(markdown);
      document = quill.Document.fromDelta(delta);
    }
    _quillController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillController.addListener(_onQuillChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onQuillChanged() {
    // Не пересобираем тулбар на каждую правку — это может ломать GlobalKey-элементы
    // внутри QuillSimpleToolbar (ошибка '_elements.contains(element)'). Счётчик размера
    // обновляем только при изменении "размерной" метрики.
    final newLen = _quillController.document.toPlainText().length;
    if (newLen != _lastDocLen) {
      _lastDocLen = newLen;
      if (mounted) setState(() {});
    }
  }

  int _lastDocLen = 0;

  /// Конвертируем текущий Delta-документ обратно в Markdown.
  String _toMarkdown() {
    final delta = _quillController.document.toDelta();
    return _exporter.exportSync(delta);
  }

  /// Сохраняем результат в исходный контроллер основного поля и закрываем
  /// без отправки (кнопка «Назад»).
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

  @override
  void dispose() {
    _quillController.removeListener(_onQuillChanged);
    _quillController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _quillController.document.toPlainText();
    final byteSize = text.codeUnits.length;
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
            quill.QuillSimpleToolbar(
              controller: _quillController,
              config: const quill.QuillSimpleToolbarConfig(
                multiRowsDisplay: true,
                showFontFamily: false,
                showFontSize: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showHeaderStyle: false,
                showAlignmentButtons: false,
                showClearFormat: true,
                showListCheck: false,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: quill.QuillEditor.basic(
                controller: _quillController,
                focusNode: _focusNode,
                config: const quill.QuillEditorConfig(
                  padding: EdgeInsets.all(16),
                  placeholder: 'Введите текст...',
                ),
              ),
            ),
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