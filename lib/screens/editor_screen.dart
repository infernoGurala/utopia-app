import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../main.dart';
import '../services/github_service.dart';
import '../services/writer_github_service.dart';
import '../services/github_global_service.dart';
import '../widgets/utopia_snackbar.dart';

class EditorScreen extends StatefulWidget {
  final String title;
  final String filePath;
  final String initialContent;
  final String folderPath;
  final List<Map<String, dynamic>> notesInFolder;

  const EditorScreen({
    super.key,
    required this.title,
    required this.filePath,
    required this.initialContent,
    this.folderPath = '',
    this.notesInFolder = const [],
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _controller;
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  final LayerLink _toolbarLayerLink = LayerLink();
  bool _saving = false;
  bool _hasChanges = false;
  bool _showPreview = false;
  bool _showAutocomplete = false;
  List<String> _autocompleteSuggestions = [];
  int _autocompleteStartIndex = 0;
  String _autocompleteFilter = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() {
      if (!_hasChanges && _controller.text != widget.initialContent) {
        setState(() => _hasChanges = true);
      }
      _checkForAutocomplete();
    });
  }

  void _checkForAutocomplete() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      _hideAutocomplete();
      return;
    }
    final cursorPos = selection.baseOffset;
    if (cursorPos < 1) {
      _hideAutocomplete();
      return;
    }
    final beforeCursor = text.substring(0, cursorPos);
    final wikiMatch = RegExp(r'\[\[([^\]]*?)$').firstMatch(beforeCursor);
    if (wikiMatch != null) {
      final filter = wikiMatch.group(1) ?? '';
      _showWikiAutocomplete(filter, wikiMatch.start);
    } else {
      _hideAutocomplete();
    }
  }

  void _showWikiAutocomplete(String filter, int startIndex) {
    final suggestions = widget.notesInFolder
        .map((n) => n['name'] as String? ?? '')
        .where((name) => name.toLowerCase().contains(filter.toLowerCase()))
        .take(8)
        .toList();
    if (suggestions.isEmpty) {
      _hideAutocomplete();
      return;
    }
    final sameSuggestions =
        _autocompleteSuggestions.length == suggestions.length &&
        _autocompleteSuggestions.asMap().entries.every(
          (entry) => suggestions[entry.key] == entry.value,
        );
    if (_showAutocomplete &&
        sameSuggestions &&
        _autocompleteStartIndex == startIndex &&
        _autocompleteFilter == filter) {
      return;
    }
    setState(() {
      _showAutocomplete = true;
      _autocompleteSuggestions = suggestions;
      _autocompleteStartIndex = startIndex;
      _autocompleteFilter = filter;
    });
  }

  void _hideAutocomplete() {
    if (_showAutocomplete || _autocompleteSuggestions.isNotEmpty) {
      setState(() {
        _showAutocomplete = false;
        _autocompleteSuggestions = [];
      });
    }
  }

  void _insertAutocompleteSuggestion(String suggestion) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPos);
    final insertPos = beforeCursor.lastIndexOf('[[');
    if (insertPos != -1) {
      final newText =
          text.substring(0, insertPos) +
          '[[$suggestion]]' +
          text.substring(cursorPos);
      final newCursor = insertPos + suggestion.length + 4;
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }
    _hideAutocomplete();
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _editorFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_hasChanges) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final updatedContent = _controller.text;
    final originalContent = widget.initialContent;

    // Pop immediately and return the new content for instant display
    Navigator.pop(context, updatedContent);

    // Continue save in background
    _performBackgroundSave(updatedContent, originalContent, user);
  }

  Future<void> _performBackgroundSave(String content, String originalContent, User user) async {
    try {
      final isCommunityNote = widget.filePath.contains('/Community/');
      
      if (isCommunityNote) {
        final success = await GitHubGlobalService().updateFile(
          path: widget.filePath,
          content: content,
          message: 'Updated ${widget.filePath} by ${user.displayName ?? user.email ?? 'UTOPIA writer'} via UTOPIA app',
        );
        if (!success) throw Exception('Sync failed');
      } else {
        await WriterGitHubService.updateTextFile(
          filename: widget.filePath,
          content: content,
          commitMessage: 'Updated ${widget.filePath} by ${user.displayName ?? user.email ?? 'UTOPIA writer'} via UTOPIA app',
        );
      }
      
      await GitHubService.primeFileContentCache(widget.filePath, content);
    } catch (e) {
      // Background failure - maybe notify via global snackbar service if available
      // For now, we've updated the cache so it will stay "optimistic" locally
    }
  }
  
  void _insertText(String text) {
    final selection = _controller.selection;
    final currentText = _controller.text;
    String newText;
    int newCursorPos;
    if (selection.isValid && selection.start != selection.end) {
      newText = currentText.replaceRange(selection.start, selection.end, text);
      newCursorPos = selection.start + text.length;
    } else if (selection.isValid) {
      newText =
          currentText.substring(0, selection.start) +
          text +
          currentText.substring(selection.end);
      newCursorPos = selection.start + text.length;
    } else {
      newText = currentText + text;
      newCursorPos = newText.length;
    }
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
    _editorFocusNode.requestFocus();
  }

  void _wrapSelection(String prefix, String suffix) {
    final selection = _controller.selection;
    if (!selection.isValid) {
      _insertText('$prefix$suffix');
      return;
    }
    final currentText = _controller.text;
    final selectedText = selection.textInside(currentText);
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      '$prefix$selectedText$suffix',
    );
    if (selectedText.isEmpty) {
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + prefix.length,
        ),
      );
    } else {
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.end + prefix.length,
        ),
      );
    }
    _editorFocusNode.requestFocus();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    if (isCtrlPressed) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyB:
          _wrapSelection('**', '**');
          break;
        case LogicalKeyboardKey.keyI:
          _wrapSelection('*', '*');
          break;
        case LogicalKeyboardKey.keyK:
          _insertText('[](url)');
          break;
        case LogicalKeyboardKey.keyM:
          setState(() => _showPreview = !_showPreview);
          break;
      }
    }
  }

  void _showInsertMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Insert',
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _insertMenuItem(Icons.functions, 'LaTeX Block', () {
                Navigator.pop(context);
                _insertText('\n\$\$\n\\\\LaTeX\n\$\$\n');
              }),
              _insertMenuItem(Icons.code, 'Code Block', () {
                Navigator.pop(context);
                _insertText('\n```\ncode\n```\n');
              }),
              _insertMenuItem(Icons.table_chart_outlined, 'Table', () {
                Navigator.pop(context);
                _insertText(
                  '\n| Header 1 | Header 2 |\n| -------- | -------- |\n| Cell 1   | Cell 2   |\n',
                );
              }),
              _insertMenuItem(Icons.account_tree, 'Mermaid Diagram', () {
                Navigator.pop(context);
                _insertText('\n```mermaid\ngraph TD\n    A --> B\n```\n');
              }),
              _insertMenuItem(Icons.checklist, 'Task List', () {
                Navigator.pop(context);
                _insertText('\n- [ ] Task 1\n- [ ] Task 2\n- [x] Completed\n');
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insertMenuItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: U.primary),
      title: Text(label, style: GoogleFonts.outfit(color: U.text)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: U.card,
        border: Border(top: BorderSide(color: U.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolbarButton(
              Icons.format_bold,
              'Bold',
              () => _wrapSelection('**', '**'),
            ),
            _toolbarButton(
              Icons.format_italic,
              'Italic',
              () => _wrapSelection('*', '*'),
            ),
            _toolbarButton(
              Icons.strikethrough_s,
              'Strikethrough',
              () => _wrapSelection('~~', '~~'),
            ),
            _toolbarButton(Icons.code, 'Code', () => _wrapSelection('`', '`')),
            _toolbarButton(Icons.link, 'Link', () => _insertText('[](url)')),
            _toolbarButton(
              Icons.image,
              'Image',
              () => _insertText('![alt](url)'),
            ),
            _toolbarButton(Icons.title, 'Heading', () => _insertText('\n## ')),
            _toolbarButton(
              Icons.format_list_bulleted,
              'List',
              () => _insertText('\n- '),
            ),
            _toolbarButton(
              Icons.checklist,
              'Task',
              () => _insertText('\n- [ ] '),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 24, color: U.border),
            const SizedBox(width: 8),
            _toolbarButton(
              Icons.functions,
              'LaTeX',
              () => _insertText(r'$' + r'$'),
            ),
            _toolbarButton(
              Icons.table_chart_outlined,
              'Table',
              () => _insertText('\n| H1 | H2 |\n|---|---|\n|   |   |\n'),
            ),
            _toolbarButton(Icons.more_horiz, 'More', _showInsertMenu),
            const SizedBox(width: 8),
            Container(width: 1, height: 24, color: U.border),
            const SizedBox(width: 8),
            _toolbarButton(
              _showPreview ? Icons.edit : Icons.visibility,
              _showPreview ? 'Edit' : 'Preview',
              () {
                setState(() => _showPreview = !_showPreview);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: U.sub,
        onPressed: onTap,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildAutocomplete() {
    if (!_showAutocomplete || _autocompleteSuggestions.isEmpty)
      return const SizedBox.shrink();
    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: U.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _autocompleteSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _autocompleteSuggestions[index];
            return ListTile(
              dense: true,
              leading: Icon(Icons.description_outlined, size: 18, color: U.dim),
              title: Text(
                suggestion,
                style: GoogleFonts.outfit(color: U.text, fontSize: 14),
              ),
              onTap: () => _insertAutocompleteSuggestion(suggestion),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSyntaxHighlightedEditor() {
    return Stack(
      children: [
        TextField(
          controller: _controller,
          focusNode: _editorFocusNode,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          maxLines: null,
          expands: true,
          enableInteractiveSelection: true,
          autocorrect: false,
          enableSuggestions: false,
          textAlignVertical: TextAlignVertical.top,
          style: GoogleFonts.sourceCodePro(
            color: U.text,
            fontSize: 14,
            height: 1.6,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText:
                'Write markdown here...\n\nCtrl+B: Bold | Ctrl+I: Italic | Ctrl+K: Link | Ctrl+M: Preview',
            hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 14),
            contentPadding: const EdgeInsets.all(16),
          ),
          onTap: _hideAutocomplete,
        ),
        _buildAutocomplete(),
      ],
    );
  }

  Widget _buildPreview() {
    return Markdown(
      data: _controller.text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        h1: GoogleFonts.outfit(
          color: U.mdH1,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        h2: GoogleFonts.outfit(
          color: U.mdH2,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        h3: GoogleFonts.outfit(
          color: U.mdH3,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        p: GoogleFonts.outfit(color: U.text, fontSize: 15, height: 1.75),
        strong: GoogleFonts.outfit(
          color: U.mdBold,
          fontWeight: FontWeight.w700,
        ),
        em: GoogleFonts.outfit(color: U.mdItalic, fontStyle: FontStyle.italic),
        code: GoogleFonts.sourceCodePro(
          color: U.mdCode,
          backgroundColor: U.card,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: U.border),
        ),
        blockquote: GoogleFonts.outfit(color: U.sub, fontSize: 14),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: U.mdBlockquote, width: 3)),
        ),
        a: GoogleFonts.outfit(
          color: U.mdLink,
          decoration: TextDecoration.underline,
        ),
      ),
      onTapLink: (text, href, title) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.surface,
        foregroundColor: U.text,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_hasChanges) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: U.card,
                  title: Text(
                    'Unsaved changes',
                    style: GoogleFonts.outfit(color: U.text),
                  ),
                  content: Text(
                    'Leave without saving?',
                    style: GoogleFonts.outfit(color: U.sub),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Stay',
                        style: GoogleFonts.outfit(color: U.primary),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Leave',
                        style: GoogleFonts.outfit(color: U.red),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_hasChanges)
            _saving
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: U.green,
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.check, color: U.green),
                    onPressed: _save,
                  ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            Expanded(
              child: _showPreview
                  ? _buildPreview()
                  : _buildSyntaxHighlightedEditor(),
            ),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }
}
