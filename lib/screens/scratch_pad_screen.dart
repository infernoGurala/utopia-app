import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';

enum BlockType { paragraph, h1, h2, todo, bullet }

class NoteBlock {
  String id;
  BlockType type;
  String content;
  bool isCompleted;

  NoteBlock({
    required this.id,
    required this.type,
    required this.content,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
        'isCompleted': isCompleted,
      };

  factory NoteBlock.fromJson(Map<String, dynamic> json) {
    return NoteBlock(
      id: json['id'] as String? ?? UniqueKey().toString(),
      type: BlockType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BlockType.paragraph,
      ),
      content: json['content'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

class ScratchPadScreen extends StatefulWidget {
  const ScratchPadScreen({super.key});

  @override
  State<ScratchPadScreen> createState() => _ScratchPadScreenState();
}

class _ScratchPadScreenState extends State<ScratchPadScreen> {
  List<NoteBlock> _blocks = [];
  String _emoji = '📝';
  bool _showEmojiPicker = false;
  final List<String> _emojiOptions = ['📝', '💡', '🎯', '🚀', '📓', '✍️', '🧠', '📆', '💎', '🎨', '🔥', '🌟'];



  String? _activeFocusBlockId;
  final Map<String, MarkdownTextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadTodayNote();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  MarkdownTextEditingController _getOrCreateController(String blockId, String initialText) {
    if (!_controllers.containsKey(blockId)) {
      _controllers[blockId] = MarkdownTextEditingController(text: initialText);
    }
    return _controllers[blockId]!;
  }

  FocusNode _getOrCreateFocusNode(String blockId) {
    if (!_focusNodes.containsKey(blockId)) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          setState(() {
            _activeFocusBlockId = blockId;
          });
        } else if (_activeFocusBlockId == blockId) {
          setState(() {
            _activeFocusBlockId = null;
          });
        }
      });
      _focusNodes[blockId] = node;
    }
    return _focusNodes[blockId]!;
  }



  List<NoteBlock> _parseMarkdownToBlocks(String markdown) {
    if (markdown.trim().isEmpty) {
      return [NoteBlock(id: UniqueKey().toString(), type: BlockType.paragraph, content: '')];
    }

    final lines = markdown.split('\n');
    final List<NoteBlock> parsed = [];

    for (final line in lines) {
      if (line.startsWith('## ')) {
        parsed.add(NoteBlock(
          id: UniqueKey().toString(),
          type: BlockType.h1,
          content: line.substring(3),
        ));
      } else if (line.startsWith('### ')) {
        parsed.add(NoteBlock(
          id: UniqueKey().toString(),
          type: BlockType.h2,
          content: line.substring(4),
        ));
      } else if (line.startsWith('- [ ] ')) {
        parsed.add(NoteBlock(
          id: UniqueKey().toString(),
          type: BlockType.todo,
          content: line.substring(6),
          isCompleted: false,
        ));
      } else if (line.startsWith('- [x] ')) {
        parsed.add(NoteBlock(
          id: UniqueKey().toString(),
          type: BlockType.todo,
          content: line.substring(6),
          isCompleted: true,
        ));
      } else if (line.startsWith('- ')) {
        parsed.add(NoteBlock(
          id: UniqueKey().toString(),
          type: BlockType.bullet,
          content: line.substring(2),
        ));
      } else {
        parsed.add(NoteBlock(
          id: UniqueKey().toString(),
          type: BlockType.paragraph,
          content: line,
        ));
      }
    }
    return parsed.isEmpty
        ? [NoteBlock(id: UniqueKey().toString(), type: BlockType.paragraph, content: '')]
        : parsed;
  }

  String _compileBlocksToMarkdown(List<NoteBlock> blocks) {
    final List<String> lines = [];
    for (final block in blocks) {
      final content = _controllers[block.id]?.text ?? block.content;
      switch (block.type) {
        case BlockType.h1:
          lines.add('## $content');
          break;
        case BlockType.h2:
          lines.add('### $content');
          break;
        case BlockType.todo:
          lines.add(block.isCompleted ? '- [x] $content' : '- [ ] $content');
          break;
        case BlockType.bullet:
          lines.add('- $content');
          break;
        case BlockType.paragraph:
          lines.add(content);
          break;
      }
    }
    return lines.join('\n');
  }

  Future<void> _loadTodayNote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final emoji = prefs.getString('scratch_pad_emoji_$todayStr') ?? '📝';
      final blocksJson = prefs.getString('scratch_pad_blocks_$todayStr');
      List<NoteBlock> loadedBlocks = [];

      if (blocksJson != null && blocksJson.isNotEmpty) {
        try {
          final List decoded = json.decode(blocksJson);
          loadedBlocks = decoded.map((e) => NoteBlock.fromJson(e)).toList();
        } catch (e) {
          debugPrint('Error decoding block JSON: $e');
        }
      }

      if (loadedBlocks.isEmpty) {
        final content = prefs.getString('scratch_pad_$todayStr') ?? '';
        loadedBlocks = _parseMarkdownToBlocks(content);
      }

      setState(() {
        _emoji = emoji;
        _blocks = loadedBlocks;
        _controllers.clear();
        _focusNodes.clear();
        for (final b in _blocks) {
          _getOrCreateController(b.id, b.content);
          _getOrCreateFocusNode(b.id);
        }
      });
    } catch (e) {
      debugPrint('Error loading today scratch: $e');
    }
  }

  Future<void> _saveEmoji(String em) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setString('scratch_pad_emoji_$todayStr', em);
    } catch (e) {
      debugPrint('Error saving scratch emoji: $e');
    }
  }

  Future<void> _saveNote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final markdownContent = _compileBlocksToMarkdown(_blocks);

      final blocksJson = json.encode(_blocks.map((e) {
        e.content = _controllers[e.id]?.text ?? e.content;
        return e.toJson();
      }).toList());

      if (markdownContent.trim().isEmpty) {
        await prefs.remove('scratch_pad_$todayStr');
        await prefs.remove('scratch_pad_blocks_$todayStr');
      } else {
        await prefs.setString('scratch_pad_$todayStr', markdownContent);
        await prefs.setString('scratch_pad_blocks_$todayStr', blocksJson);
      }
    } catch (e) {
      debugPrint('Error saving scratch note: $e');
    }
  }

  void _insertBlockBelow(NoteBlock currentBlock, BlockType newType) {
    final index = _blocks.indexOf(currentBlock);
    if (index == -1) return;

    final newBlock = NoteBlock(
      id: UniqueKey().toString(),
      type: newType,
      content: '',
    );

    setState(() {
      _blocks.insert(index + 1, newBlock);
      _getOrCreateController(newBlock.id, '');
      _getOrCreateFocusNode(newBlock.id);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newBlock.id]?.requestFocus();
    });

    _saveNote();
  }

  void _insertBlockAbove(NoteBlock currentBlock) {
    final index = _blocks.indexOf(currentBlock);
    if (index == -1) return;

    final newBlock = NoteBlock(
      id: UniqueKey().toString(),
      type: BlockType.paragraph,
      content: '',
    );

    setState(() {
      _blocks.insert(index, newBlock);
      _getOrCreateController(newBlock.id, '');
      _getOrCreateFocusNode(newBlock.id);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newBlock.id]?.requestFocus();
    });

    _saveNote();
  }

  void _deleteBlock(NoteBlock block) {
    if (_blocks.length <= 1) return;

    final index = _blocks.indexOf(block);
    if (index == -1) return;

    final focusIndex = index > 0 ? index - 1 : index + 1;
    final focusBlockId = _blocks[focusIndex].id;

    setState(() {
      _blocks.removeAt(index);
      final c = _controllers.remove(block.id);
      c?.dispose();
      final n = _focusNodes.remove(block.id);
      n?.dispose();

      if (_activeFocusBlockId == block.id) {
        _activeFocusBlockId = null;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[focusBlockId]?.requestFocus();
    });

    _saveNote();
  }

  void _clearText() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Scratch Pad',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to clear today\'s scratch pad? This cannot be undone.',
          style: GoogleFonts.outfit(color: U.sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _blocks = [NoteBlock(id: UniqueKey().toString(), type: BlockType.paragraph, content: '')];
                _controllers.clear();
                _focusNodes.clear();
              });
              _saveNote();
            },
            child: Text('Clear', style: GoogleFonts.outfit(color: U.red)),
          ),
        ],
      ),
    );
  }

  void _shareText() {
    final text = _compileBlocksToMarkdown(_blocks).trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nothing to share yet!', style: GoogleFonts.outfit()),
          backgroundColor: U.primary,
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied scratch note to clipboard!', style: GoogleFonts.outfit()),
        backgroundColor: U.green,
      ),
    );
  }

  Future<List<MapEntry<String, String>>> _getHistoryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final List<MapEntry<String, String>> history = [];
    for (final key in keys) {
      if (key.startsWith('scratch_pad_') && !key.startsWith('scratch_pad_blocks_') && !key.startsWith('scratch_pad_emoji_')) {
        final dateStr = key.replaceFirst('scratch_pad_', '');
        final content = prefs.getString(key);
        if (content != null && content.trim().isNotEmpty) {
          history.add(MapEntry(dateStr, content));
        }
      }
    }
    history.sort((a, b) => b.key.compareTo(a.key));
    return history;
  }

  void _showHistorySheet() async {
    final history = await _getHistoryEntries();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scratch History',
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: U.text),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Historical scratch notes stored locally on your device.',
                style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, color: U.dim, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No past scratches found',
                              style: GoogleFonts.outfit(color: U.dim, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final entry = history[index];
                          final parsedDate = DateTime.tryParse(entry.key);
                          final titleStr = parsedDate != null
                              ? DateFormat('EEEE, MMMM d, yyyy').format(parsedDate)
                              : entry.key;

                          final lines = entry.value.trim().split('\n');
                          final snippet = lines.first.length > 50
                              ? '${lines.first.substring(0, 50)}...'
                              : lines.first;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: U.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: U.border.withValues(alpha: 0.6), width: 0.8),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: U.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.description_outlined, color: U.primary, size: 18),
                              ),
                              title: Text(
                                titleStr,
                                style: GoogleFonts.outfit(
                                  color: U.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  snippet.isEmpty ? '(Empty Note)' : snippet,
                                  style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios_rounded, color: U.dim, size: 12),
                              onTap: () {
                                Navigator.pop(context);
                                _restoreFromHistory(entry.key, entry.value);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _restoreFromHistory(String dateKey, String markdownContent) async {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: U.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 520, maxWidth: 450),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_outlined, color: U.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateKey,
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: U.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: U.border.withValues(alpha: 0.8), width: 0.8),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: MarkdownBody(
                        data: markdownContent,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.outfit(color: U.text, fontSize: 14, height: 1.5),
                          h1: GoogleFonts.outfit(color: U.mdH1, fontWeight: FontWeight.bold, fontSize: 20, height: 1.4),
                          h2: GoogleFonts.outfit(color: U.mdH2, fontWeight: FontWeight.bold, fontSize: 18, height: 1.4),
                          h3: GoogleFonts.outfit(color: U.mdH3, fontWeight: FontWeight.bold, fontSize: 16, height: 1.4),
                          strong: GoogleFonts.outfit(color: U.mdBold, fontWeight: FontWeight.w800),
                          em: GoogleFonts.outfit(color: U.mdItalic, fontStyle: FontStyle.italic),
                          code: GoogleFonts.plusJakartaSans(
                            color: U.mdCode,
                            backgroundColor: U.mdCode.withValues(alpha: 0.08),
                            fontSize: 12,
                          ),
                          blockquote: GoogleFonts.outfit(color: U.mdBlockquote, fontStyle: FontStyle.italic),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(left: BorderSide(color: U.mdBlockquote, width: 3)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: U.text,
                          side: BorderSide(color: U.border.withValues(alpha: 0.8)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: U.primary,
                          foregroundColor: appThemeNotifier.value.isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _blocks = _parseMarkdownToBlocks(markdownContent);
                            _controllers.clear();
                            _focusNodes.clear();
                            for (final b in _blocks) {
                              _getOrCreateController(b.id, b.content);
                              _getOrCreateFocusNode(b.id);
                            }
                          });
                          _saveNote();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Restored scratch note for today!', style: GoogleFonts.outfit()),
                              backgroundColor: U.green,
                            ),
                          );
                        },
                        child: Text('Restore to Today', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _insertMarkdown(String prefix, String suffix) {
    if (_activeFocusBlockId == null) return;
    final controller = _controllers[_activeFocusBlockId];
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    if (!selection.isValid) {
      final endOffset = text.length;
      final newText = '$text$prefix$suffix';
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: endOffset + prefix.length),
      );
      _saveNote();
      return;
    }

    final selectedText = selection.textInside(text);
    final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length),
    );
    _saveNote();
  }

  Widget _buildFloatingToolbar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border.withValues(alpha: 0.3), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: appThemeNotifier.value.isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: U.surface.withValues(alpha: 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolbarButton(Icons.format_bold, () => _insertMarkdown('**', '**'), tooltip: 'Bold'),
                _toolbarButton(Icons.format_italic, () => _insertMarkdown('*', '*'), tooltip: 'Italics'),
                _toolbarButton(Icons.link_rounded, () => _insertMarkdown('[', '](url)'), tooltip: 'Link'),
                _toolbarButton(Icons.code_rounded, () => _insertMarkdown('`', '`'), tooltip: 'Code'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarButton(IconData icon, VoidCallback onPressed, {required String tooltip}) {
    return IconButton(
      icon: Icon(icon, color: U.text, size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 20,
    );
  }

  Widget _buildBlockControls(NoteBlock block, int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.add_rounded, size: 16, color: U.dim),
          onPressed: () => _insertBlockBelow(block, BlockType.paragraph),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          splashRadius: 14,
        ),
        const SizedBox(width: 2),
        PopupMenuButton<String>(
          icon: Icon(Icons.drag_indicator_rounded, size: 16, color: U.dim),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: U.surface,
          onSelected: (action) {
            if (action == 'delete') {
              _deleteBlock(block);
            } else if (action.startsWith('turn_to_')) {
              final typeStr = action.replaceFirst('turn_to_', '');
              final type = BlockType.values.firstWhere((e) => e.name == typeStr);
              setState(() {
                block.type = type;
              });
              _saveNote();
            } else if (action == 'insert_above') {
              _insertBlockAbove(block);
            } else if (action == 'insert_below') {
              _insertBlockBelow(block, BlockType.paragraph);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'turn_to_paragraph',
              child: _buildMenuRow(Icons.short_text_rounded, 'Text'),
            ),
            PopupMenuItem(
              value: 'turn_to_h1',
              child: _buildMenuRow(Icons.title_rounded, 'Heading 1'),
            ),
            PopupMenuItem(
              value: 'turn_to_h2',
              child: _buildMenuRow(Icons.subtitles_rounded, 'Heading 2'),
            ),
            PopupMenuItem(
              value: 'turn_to_todo',
              child: _buildMenuRow(Icons.playlist_add_check_rounded, 'To-do list'),
            ),
            PopupMenuItem(
              value: 'turn_to_bullet',
              child: _buildMenuRow(Icons.format_list_bulleted_rounded, 'Bulleted list'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'insert_above',
              child: _buildMenuRow(Icons.arrow_upward_rounded, 'Insert Above'),
            ),
            PopupMenuItem(
              value: 'insert_below',
              child: _buildMenuRow(Icons.arrow_downward_rounded, 'Insert Below'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: U.red, size: 18),
                  const SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: U.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: U.text, size: 18),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: U.text)),
      ],
    );
  }

  Widget _buildPropertyRow(String label, IconData icon, Widget valueWidget) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: U.sub),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: U.sub,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }

  LinearGradient _getDynamicCoverGradient() {
    final isDark = appThemeNotifier.value.isDark;
    if (isDark) {
      return LinearGradient(
        colors: [
          const Color(0xFF1E1B4B),
          const Color(0xFF2E1065),
          U.bg,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [
          const Color(0xFFEEF2FF),
          const Color(0xFFFDF2F8),
          U.bg,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? iconColor,
  }) {
    final isDark = appThemeNotifier.value.isDark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Icon(
                icon,
                color: iconColor ?? U.text,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockRow(NoteBlock block, int index) {
    final controller = _getOrCreateController(block.id, block.content);
    final focusNode = _getOrCreateFocusNode(block.id);
    final isFocused = _activeFocusBlockId == block.id;

    Widget prefixWidget;
    TextStyle textStyle;

    switch (block.type) {
      case BlockType.h1:
        prefixWidget = const SizedBox(width: 8);
        textStyle = GoogleFonts.outfit(
          color: U.text,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.4,
        );
        break;
      case BlockType.h2:
        prefixWidget = const SizedBox(width: 8);
        textStyle = GoogleFonts.outfit(
          color: U.text,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.4,
        );
        break;
      case BlockType.todo:
        prefixWidget = Padding(
          padding: const EdgeInsets.only(right: 8.0, top: 2.0),
          child: SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: block.isCompleted,
              activeColor: U.primary,
              side: BorderSide(color: U.border, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) {
                setState(() {
                  block.isCompleted = val ?? false;
                });
                _saveNote();
              },
            ),
          ),
        );
        textStyle = GoogleFonts.outfit(
          color: block.isCompleted ? U.sub.withValues(alpha: 0.5) : U.text,
          fontSize: 15.5,
          decoration: block.isCompleted ? TextDecoration.lineThrough : null,
          height: 1.5,
        );
        break;
      case BlockType.bullet:
        prefixWidget = Padding(
          padding: const EdgeInsets.only(left: 6.0, right: 12.0, top: 8.0),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: U.text.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
        );
        textStyle = GoogleFonts.outfit(
          color: U.text,
          fontSize: 15.5,
          height: 1.5,
        );
        break;
      case BlockType.paragraph:
        prefixWidget = const SizedBox(width: 8);
        textStyle = GoogleFonts.outfit(
          color: U.text,
          fontSize: 15.5,
          height: 1.5,
        );
        break;
    }

    return Padding(
      key: ValueKey(block.id),
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: isFocused ? 1.0 : 0.15,
            child: _buildBlockControls(block, index),
          ),
          const SizedBox(width: 4),
          prefixWidget,
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                  if (controller.text.isEmpty) {
                    _deleteBlock(block);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: textStyle,
                cursorColor: U.primary,
                decoration: InputDecoration(
                  hintText: block.type == BlockType.h1
                      ? 'Heading 1'
                      : block.type == BlockType.h2
                          ? 'Heading 2'
                          : block.type == BlockType.todo
                              ? 'To-do'
                              : 'Press Enter or type "/" for commands...',
                  hintStyle: GoogleFonts.outfit(
                    color: U.dim.withValues(alpha: 0.35),
                    fontSize: textStyle.fontSize,
                    fontWeight: textStyle.fontWeight,
                  ),
                  border: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 2.0),
                ),
                onChanged: (val) {
                  if (val == '/h1') {
                    controller.clear();
                    setState(() {
                      block.type = BlockType.h1;
                    });
                    _saveNote();
                  } else if (val == '/h2') {
                    controller.clear();
                    setState(() {
                      block.type = BlockType.h2;
                    });
                    _saveNote();
                  } else if (val == '/todo') {
                    controller.clear();
                    setState(() {
                      block.type = BlockType.todo;
                      block.isCompleted = false;
                    });
                    _saveNote();
                  } else if (val == '/bullet') {
                    controller.clear();
                    setState(() {
                      block.type = BlockType.bullet;
                    });
                    _saveNote();
                  } else if (val == '/text') {
                    controller.clear();
                    setState(() {
                      block.type = BlockType.paragraph;
                    });
                    _saveNote();
                  } else if (val.endsWith('\n')) {
                    final cleanText = val.substring(0, val.length - 1);
                    controller.text = cleanText;
                    _insertBlockBelow(block, BlockType.paragraph);
                  } else {
                    _saveNote();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appThemeNotifier.value.isDark;
    final todayStr = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    final coverGradient = _getDynamicCoverGradient();

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          fillColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        backgroundColor: U.bg,
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: coverGradient,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Transform.translate(
                        offset: const Offset(0, -32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showEmojiPicker = !_showEmojiPicker;
                                });
                              },
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: U.card,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: U.border.withValues(alpha: 0.8),
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _emoji,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                ),
                              ).animate(target: _showEmojiPicker ? 1.0 : 0.0)
                               .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 200.ms, curve: Curves.easeOut),
                            ),
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Container(
                                margin: const EdgeInsets.only(top: 12),
                                height: 50,
                                decoration: BoxDecoration(
                                  color: U.surface.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: U.border.withValues(alpha: 0.5), width: 0.8),
                                ),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  itemCount: _emojiOptions.length,
                                  itemBuilder: (context, index) {
                                    final em = _emojiOptions[index];
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _emoji = em;
                                          _showEmojiPicker = false;
                                        });
                                        _saveEmoji(em);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        alignment: Alignment.center,
                                        child: Text(
                                          em,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              crossFadeState: _showEmojiPicker ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 200),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Today's Scratch Pad",
                              style: GoogleFonts.outfit(
                                color: U.text,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 0.5,
                              color: U.border.withValues(alpha: 0.8),
                            ),
                            _buildPropertyRow(
                              'Date',
                              Icons.calendar_today_outlined,
                              Text(
                                todayStr,
                                style: GoogleFonts.outfit(
                                  color: U.text,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 0.5,
                              color: U.border.withValues(alpha: 0.8),
                            ),
                            const SizedBox(height: 20),
                            
                            // Reorderable list of blocks
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 250),
                              buildDefaultDragHandles: false,
                              itemCount: _blocks.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (oldIndex < newIndex) {
                                    newIndex -= 1;
                                  }
                                  final block = _blocks.removeAt(oldIndex);
                                  _blocks.insert(newIndex, block);
                                });
                                _saveNote();
                              },
                              itemBuilder: (context, index) {
                                final block = _blocks[index];
                                return _buildBlockRow(block, index);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircleActionButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCircleActionButton(
                        icon: Icons.history_toggle_off_rounded,
                        onPressed: _showHistorySheet,
                        tooltip: 'History Log',
                      ),
                      const SizedBox(width: 8),
                      _buildCircleActionButton(
                        icon: Icons.delete_outline_rounded,
                        onPressed: _clearText,
                        tooltip: 'Clear Notes',
                        iconColor: U.red.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      _buildCircleActionButton(
                        icon: Icons.content_copy_rounded,
                        onPressed: _shareText,
                        tooltip: 'Copy Note',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Floating accessory toolbar docked directly above the keyboard
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _activeFocusBlockId != null ? _buildFloatingToolbar() : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class MarkdownTextEditingController extends TextEditingController {
  MarkdownTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final TextStyle defaultStyle = style ?? const TextStyle();
    final List<TextSpan> spans = [];

    final RegExp exp = RegExp(
      r'(\*\*[^*]+\*\*)|' // 1. bold
      r'(\*[^*]+\*)|'     // 2. italic
      r'(==[^=]+==)|'     // 3. highlight
      r'(~~[^~]+~~)|'     // 4. strikethrough
      r'(\[[^\]]+\]\([^)]+\))|' // 5. link
      r'(\$[^\$]+\$)|'     // 6. single latex
      r'(^#{2,4}\s[^\n]*)', // 7. Headings
      multiLine: true,
    );

    int start = 0;
    for (final match in exp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: defaultStyle));
      }

      final String matchText = match.group(0)!;
      final bool isActive = selection.isValid && selection.baseOffset >= match.start && selection.baseOffset <= match.end;

      final Color markerColor = U.dim.withValues(alpha: 0.5);
      final TextStyle visibleMarker = defaultStyle.copyWith(color: markerColor);
      final TextStyle hiddenMarker = defaultStyle.copyWith(color: Colors.transparent, fontSize: 0.01);
      final TextStyle tagStyle = isActive ? visibleMarker : hiddenMarker;

      if (match.group(1) != null) { // Bold
        spans.add(TextSpan(children: [
          TextSpan(text: '**', style: tagStyle),
          TextSpan(text: matchText.substring(2, matchText.length - 2), style: defaultStyle.copyWith(fontWeight: FontWeight.w800)),
          TextSpan(text: '**', style: tagStyle),
        ]));
      } else if (match.group(2) != null) { // Italic
        spans.add(TextSpan(children: [
          TextSpan(text: '*', style: tagStyle),
          TextSpan(text: matchText.substring(1, matchText.length - 1), style: defaultStyle.copyWith(fontStyle: FontStyle.italic)),
          TextSpan(text: '*', style: tagStyle),
        ]));
      } else if (match.group(3) != null) { // Highlight
        spans.add(TextSpan(children: [
          TextSpan(text: '==', style: tagStyle),
          TextSpan(text: matchText.substring(2, matchText.length - 2), style: defaultStyle.copyWith(backgroundColor: Colors.amber.withValues(alpha: 0.2))),
          TextSpan(text: '==', style: tagStyle),
        ]));
      } else if (match.group(4) != null) { // Strikethrough
        spans.add(TextSpan(children: [
          TextSpan(text: '~~', style: tagStyle),
          TextSpan(text: matchText.substring(2, matchText.length - 2), style: defaultStyle.copyWith(decoration: TextDecoration.lineThrough)),
          TextSpan(text: '~~', style: tagStyle),
        ]));
      } else if (match.group(5) != null) { // Link
        final int cbClose = matchText.indexOf(']');
        final int pbOpen = matchText.indexOf('(');
        if (cbClose > 1 && pbOpen == cbClose + 1) {
          spans.add(TextSpan(children: [
            TextSpan(text: '[', style: tagStyle),
            TextSpan(text: matchText.substring(1, cbClose), style: defaultStyle.copyWith(color: U.primary, decoration: TextDecoration.underline)),
            TextSpan(text: ']', style: tagStyle),
            TextSpan(text: matchText.substring(pbOpen), style: isActive ? visibleMarker.copyWith(fontSize: (defaultStyle.fontSize ?? 14) * 0.8) : hiddenMarker),
          ]));
        } else {
          spans.add(TextSpan(text: matchText, style: defaultStyle));
        }
      } else if (match.group(6) != null) { // Latex
        spans.add(TextSpan(children: [
          TextSpan(text: r'$', style: tagStyle),
          TextSpan(text: matchText.substring(1, matchText.length - 1), style: defaultStyle.copyWith(fontFamily: 'Courier', color: U.green)),
          TextSpan(text: r'$', style: tagStyle),
        ]));
      } else if (match.group(7) != null) { // Headings (##, ###, ####)
        final int hashCount = matchText.indexOf(' ');
        final String hashTags = matchText.substring(0, hashCount + 1);
        final String content = matchText.substring(hashCount + 1);

        double fontSize = defaultStyle.fontSize ?? 14;
        if (hashCount == 2) {
          fontSize *= 1.4;
        } else if (hashCount == 3) {
          fontSize *= 1.2;
        } else if (hashCount == 4) {
          fontSize *= 1.1;
        }

        spans.add(TextSpan(children: [
          TextSpan(text: hashTags, style: tagStyle.copyWith(fontSize: fontSize)),
          TextSpan(text: content, style: defaultStyle.copyWith(fontWeight: FontWeight.w700, fontSize: fontSize)),
        ]));
      } else {
        spans.add(TextSpan(text: matchText, style: defaultStyle));
      }
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: defaultStyle));
    }

    return TextSpan(style: style, children: spans);
  }
}
