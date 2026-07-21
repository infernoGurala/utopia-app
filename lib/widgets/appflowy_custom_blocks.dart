import 'dart:convert';
import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';

import '../main.dart';
import '../services/file_cache_service.dart';

// ─────────────────────────────────────────────────────────────
// Block Action & Reordering Controls Helper
// ─────────────────────────────────────────────────────────────

Widget buildBlockHeaderControls({
  required BuildContext context,
  required Node node,
  required bool isEditable,
  required EditorState? editorState,
  required VoidCallback? onChanged,
  required String title,
  required IconData icon,
  required Color color,
  Widget? extraTrailing,
}) {
  if (!isEditable) {
    if (extraTrailing != null) return extraTrailing;
    return const SizedBox.shrink();
  }

  final state = editorState;

  return Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          title,
          style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (extraTrailing != null) extraTrailing,
      const Spacer(),
      if (state != null) ...[
        IconButton(
          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
          color: U.primary,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          tooltip: 'Move Up',
          onPressed: () {
            final index = node.path.last;
            if (index > 0) {
              final targetPath = [index - 1];
              final transaction = state.transaction..moveNode(targetPath, node);
              state.apply(transaction);
              onChanged?.call();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.arrow_downward_rounded, size: 18),
          color: U.primary,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          tooltip: 'Move Down',
          onPressed: () {
            final totalCount = state.document.root.children.length;
            final index = node.path.last;
            if (index < totalCount - 1) {
              final targetPath = [index + 1];
              final transaction = state.transaction..moveNode(targetPath, node);
              state.apply(transaction);
              onChanged?.call();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: U.red,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          tooltip: 'Delete Block',
          onPressed: () {
            final transaction = state.transaction..deleteNode(node);
            state.apply(transaction);
            onChanged?.call();
          },
        ),
      ],
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// 1. Q&A Block Component
// ─────────────────────────────────────────────────────────────

class QABlockComponentBuilder extends BlockComponentBuilder {
  final bool isEditable;
  final EditorState? editorState;
  final VoidCallback? onChanged;

  QABlockComponentBuilder({
    this.isEditable = true,
    this.editorState,
    this.onChanged,
  });

  @override
  BlockComponentValidate get validate => (node) => node.type == 'qa_block';

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return QABlockWidget(
      key: ValueKey(context.node.id),
      node: context.node,
      isEditable: isEditable,
      editorState: editorState,
      onChanged: onChanged,
    );
  }
}

class QABlockWidget extends StatefulWidget implements BlockComponentWidget {
  @override
  final Node node;

  final bool isEditable;
  final EditorState? editorState;
  final VoidCallback? onChanged;

  const QABlockWidget({
    super.key,
    required this.node,
    this.isEditable = true,
    this.editorState,
    this.onChanged,
  });

  @override
  BlockComponentActionBuilder get actionBuilder => (context, node) => const SizedBox.shrink();

  @override
  BlockComponentActionBuilder get actionTrailingBuilder => (context, node) => const SizedBox.shrink();

  @override
  BlockComponentConfiguration get configuration => const BlockComponentConfiguration();

  @override
  bool get showActions => false;

  @override
  State<QABlockWidget> createState() => _QABlockWidgetState();
}

class _QABlockWidgetState extends State<QABlockWidget> {
  bool _showAnswer = false;
  late TextEditingController _qController;
  late TextEditingController _aController;

  @override
  void initState() {
    super.initState();
    _qController = TextEditingController(text: (widget.node.attributes['question'] as String?) ?? '');
    _aController = TextEditingController(text: (widget.node.attributes['answer'] as String?) ?? '');
  }

  @override
  void didUpdateWidget(covariant QABlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node != oldWidget.node) {
      _qController.text = (widget.node.attributes['question'] as String?) ?? '';
      _aController.text = (widget.node.attributes['answer'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _qController.dispose();
    _aController.dispose();
    super.dispose();
  }

  void _updateNode() {
    widget.node.attributes['question'] = _qController.text;
    widget.node.attributes['answer'] = _aController.text;
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final question = _qController.text;
    final answer = _aController.text;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isEditable) ...[
            buildBlockHeaderControls(
              context: context,
              node: widget.node,
              isEditable: widget.isEditable,
              editorState: widget.editorState,
              onChanged: widget.onChanged,
              title: 'Q&A Card',
              icon: Icons.help_outline_rounded,
              color: U.blue,
            ),
            const SizedBox(height: 8),
          ],
          widget.isEditable
              ? TextField(
                  controller: _qController,
                  style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Enter question...',
                    hintStyle: GoogleFonts.outfit(color: U.sub),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (_) => _updateNode(),
                )
              : Text(
                  question.isEmpty ? 'Question' : question,
                  style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
          const SizedBox(height: 8),
          if (widget.isEditable) ...[
            TextField(
              controller: _aController,
              maxLines: null,
              style: GoogleFonts.outfit(color: U.text),
              decoration: InputDecoration(
                hintText: 'Enter answer...',
                hintStyle: GoogleFonts.outfit(color: U.sub),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (_) => _updateNode(),
            ),
          ] else ...[
            GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: U.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAnswer ? Icons.visibility_off : Icons.visibility,
                      size: 16,
                      color: U.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _showAnswer ? 'Hide Answer' : 'Reveal Answer',
                        style: GoogleFonts.outfit(color: U.primary, fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showAnswer) ...[
              const SizedBox(height: 8),
              Text(
                answer,
                style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 2. LaTeX Block Component
// ─────────────────────────────────────────────────────────────

class LaTeXBlockComponentBuilder extends BlockComponentBuilder {
  final bool isEditable;
  final EditorState? editorState;
  final VoidCallback? onChanged;

  LaTeXBlockComponentBuilder({
    this.isEditable = true,
    this.editorState,
    this.onChanged,
  });

  @override
  BlockComponentValidate get validate => (node) => node.type == 'latex_block';

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return LaTeXBlockWidget(
      key: ValueKey(context.node.id),
      node: context.node,
      isEditable: isEditable,
      editorState: editorState,
      onChanged: onChanged,
    );
  }
}

class LaTeXBlockWidget extends StatefulWidget implements BlockComponentWidget {
  @override
  final Node node;

  final bool isEditable;
  final EditorState? editorState;
  final VoidCallback? onChanged;

  const LaTeXBlockWidget({
    super.key,
    required this.node,
    this.isEditable = true,
    this.editorState,
    this.onChanged,
  });

  @override
  BlockComponentActionBuilder get actionBuilder => (context, node) => const SizedBox.shrink();

  @override
  BlockComponentActionBuilder get actionTrailingBuilder => (context, node) => const SizedBox.shrink();

  @override
  BlockComponentConfiguration get configuration => const BlockComponentConfiguration();

  @override
  bool get showActions => false;

  @override
  State<LaTeXBlockWidget> createState() => _LaTeXBlockWidgetState();
}

class _LaTeXBlockWidgetState extends State<LaTeXBlockWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: (widget.node.attributes['content'] as String?) ?? '');
  }

  @override
  void didUpdateWidget(covariant LaTeXBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node != oldWidget.node) {
      _controller.text = (widget.node.attributes['content'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateNode() {
    widget.node.attributes['content'] = _controller.text;
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final latex = _controller.text;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isEditable) ...[
            buildBlockHeaderControls(
              context: context,
              node: widget.node,
              isEditable: widget.isEditable,
              editorState: widget.editorState,
              onChanged: widget.onChanged,
              title: 'LaTeX Equation',
              icon: Icons.functions_rounded,
              color: U.primary,
            ),
            const SizedBox(height: 8),
          ],
          if (latex.trim().isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                latex,
                textStyle: TextStyle(color: U.text, fontSize: 16),
                onErrorFallback: (err) => Text(
                  'LaTeX Error: ${err.message}',
                  style: GoogleFonts.outfit(color: U.red, fontSize: 12),
                ),
              ),
            ),
          if (widget.isEditable) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: null,
              style: GoogleFonts.outfit(color: U.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: r'Enter LaTeX formula e.g. E = mc^2',
                hintStyle: GoogleFonts.outfit(color: U.sub),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (_) {
                setState(() {});
                _updateNode();
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 3. Mermaid Block Component
// ─────────────────────────────────────────────────────────────

class MermaidBlockComponentBuilder extends BlockComponentBuilder {
  final bool isEditable;
  final EditorState? editorState;
  final VoidCallback? onChanged;

  MermaidBlockComponentBuilder({
    this.isEditable = true,
    this.editorState,
    this.onChanged,
  });

  @override
  BlockComponentValidate get validate => (node) => node.type == 'mermaid_block';

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return MermaidBlockWidget(
      key: ValueKey(context.node.id),
      node: context.node,
      isEditable: isEditable,
      editorState: editorState,
      onChanged: onChanged,
    );
  }
}

class MermaidBlockWidget extends StatefulWidget implements BlockComponentWidget {
  @override
  final Node node;

  final bool isEditable;
  final EditorState? editorState;
  final VoidCallback? onChanged;

  const MermaidBlockWidget({
    super.key,
    required this.node,
    this.isEditable = true,
    this.editorState,
    this.onChanged,
  });

  @override
  BlockComponentActionBuilder get actionBuilder => (context, node) => const SizedBox.shrink();

  @override
  BlockComponentActionBuilder get actionTrailingBuilder => (context, node) => const SizedBox.shrink();

  @override
  BlockComponentConfiguration get configuration => const BlockComponentConfiguration();

  @override
  bool get showActions => false;

  @override
  State<MermaidBlockWidget> createState() => _MermaidBlockWidgetState();
}

class _MermaidBlockWidgetState extends State<MermaidBlockWidget> {
  late TextEditingController _controller;
  late String _direction;

  @override
  void initState() {
    super.initState();
    _direction = (widget.node.attributes['direction'] as String?) ?? 'TD';
    _controller = TextEditingController(text: (widget.node.attributes['content'] as String?) ?? '');
  }

  @override
  void didUpdateWidget(covariant MermaidBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node != oldWidget.node) {
      _direction = (widget.node.attributes['direction'] as String?) ?? 'TD';
      _controller.text = (widget.node.attributes['content'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateNode() {
    widget.node.attributes['direction'] = _direction;
    widget.node.attributes['content'] = _controller.text;
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isEditable) ...[
            buildBlockHeaderControls(
              context: context,
              node: widget.node,
              isEditable: widget.isEditable,
              editorState: widget.editorState,
              onChanged: widget.onChanged,
              title: 'Mermaid Diagram ($_direction)',
              icon: Icons.account_tree_outlined,
              color: U.green,
              extraTrailing: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: DropdownButton<String>(
                  value: _direction,
                  dropdownColor: U.surface,
                  underline: const SizedBox(),
                  isDense: true,
                  items: ['TD', 'LR', 'RL', 'BT'].map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text(d, style: GoogleFonts.outfit(color: U.text, fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _direction = val);
                      _updateNode();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: U.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'graph $_direction\n${_controller.text}',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
            ),
          ),
          if (widget.isEditable) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: null,
              style: GoogleFonts.outfit(color: U.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'A[Start] --> B[Process]',
                hintStyle: GoogleFonts.outfit(color: U.sub),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (_) {
                setState(() {});
                _updateNode();
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 4. Table Block Component
// ─────────────────────────────────────────────────────────────

class UtopiaTableBlockComponentBuilder extends BlockComponentBuilder {
  final bool isEditable;
  final EditorState? editorState;
  final VoidCallback? onChanged;

  UtopiaTableBlockComponentBuilder({
    this.isEditable = true,
    this.editorState,
    this.onChanged,
  });

  @override
  BlockComponentValidate get validate => (node) => node.type == 'table_block';

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return TableBlockWidget(
      key: ValueKey(context.node.id),
      node: context.node,
      isEditable: isEditable,
      editorState: editorState,
      onChanged: onChanged,
    );
  }
}

class TableBlockWidget extends StatefulWidget implements BlockComponentWidget {
  @override
  final Node node;

  final bool isEditable;
  final EditorState? editorState;
  final VoidCallback? onChanged;

  const TableBlockWidget({
    super.key,
    required this.node,
    this.isEditable = true,
    this.editorState,
    this.onChanged,
  });

  @override
  BlockComponentActionBuilder get actionBuilder => (context, node) => const SizedBox.shrink();

  @override
  BlockComponentActionBuilder get actionTrailingBuilder => (context, node) => const SizedBox.shrink();

  @override
  BlockComponentConfiguration get configuration => const BlockComponentConfiguration();

  @override
  bool get showActions => false;

  @override
  State<TableBlockWidget> createState() => _TableBlockWidgetState();
}

class _TableBlockWidgetState extends State<TableBlockWidget> {
  late List<List<String>> _grid;

  @override
  void initState() {
    super.initState();
    _loadGrid();
  }

  @override
  void didUpdateWidget(covariant TableBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node != oldWidget.node) {
      _loadGrid();
    }
  }

  void _loadGrid() {
    final raw = (widget.node.attributes['data'] as String?) ?? '[]';
    try {
      final List parsed = jsonDecode(raw);
      _grid = parsed.map((row) => (row as List).map((c) => c.toString()).toList()).toList();
    } catch (_) {
      _grid = [
        ['Header 1', 'Header 2'],
        ['Cell 1', 'Cell 2']
      ];
    }
    if (_grid.isEmpty) {
      _grid = [
        ['Header 1', 'Header 2'],
        ['Cell 1', 'Cell 2']
      ];
    }
  }

  void _updateNode() {
    widget.node.attributes['data'] = jsonEncode(_grid);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isEditable) ...[
            buildBlockHeaderControls(
              context: context,
              node: widget.node,
              isEditable: widget.isEditable,
              editorState: widget.editorState,
              onChanged: widget.onChanged,
              title: 'Table',
              icon: Icons.table_chart_outlined,
              color: U.blue,
              extraTrailing: IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () {
                  setState(() {
                    final cols = _grid[0].length;
                    _grid.add(List.generate(cols, (_) => 'Cell'));
                  });
                  _updateNode();
                },
                tooltip: 'Add Row',
              ),
            ),
            const SizedBox(height: 8),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: U.border, width: 1),
              children: List.generate(_grid.length, (r) {
                final isHeader = (r == 0);
                return TableRow(
                  decoration: BoxDecoration(
                    color: isHeader ? U.surface : U.card,
                  ),
                  children: List.generate(_grid[r].length, (c) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      child: widget.isEditable
                          ? TextFormField(
                              initialValue: _grid[r][c],
                              style: GoogleFonts.outfit(
                                color: U.text,
                                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                              onChanged: (val) {
                                _grid[r][c] = val;
                                _updateNode();
                              },
                            )
                          : Text(
                              _grid[r][c],
                              style: GoogleFonts.outfit(
                                color: U.text,
                                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                    );
                  }),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 5. Cloudinary File Attachment Block Component
// ─────────────────────────────────────────────────────────────

class CloudinaryFileBlockComponentBuilder extends BlockComponentBuilder {
  final bool isEditable;
  final EditorState? editorState;
  final VoidCallback? onChanged;

  CloudinaryFileBlockComponentBuilder({
    this.isEditable = true,
    this.editorState,
    this.onChanged,
  });

  @override
  BlockComponentValidate get validate => (node) => node.type == 'cloudinary_file_block';

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return CloudinaryFileBlockWidget(
      key: ValueKey(context.node.id),
      node: context.node,
      isEditable: isEditable,
      editorState: editorState,
      onChanged: onChanged,
    );
  }
}

class CloudinaryFileBlockWidget extends StatefulWidget implements BlockComponentWidget {
  @override
  final Node node;

  final bool isEditable;
  final EditorState? editorState;
  final VoidCallback? onChanged;

  const CloudinaryFileBlockWidget({
    super.key,
    required this.node,
    this.isEditable = true,
    this.editorState,
    this.onChanged,
  });

  @override
  BlockComponentActionBuilder get actionBuilder => (context, node) => const SizedBox.shrink();

  @override
  BlockComponentActionBuilder get actionTrailingBuilder => (context, node) => const SizedBox.shrink();

  @override
  BlockComponentConfiguration get configuration => const BlockComponentConfiguration();

  @override
  bool get showActions => false;

  @override
  State<CloudinaryFileBlockWidget> createState() => _CloudinaryFileBlockWidgetState();
}

class _CloudinaryFileBlockWidgetState extends State<CloudinaryFileBlockWidget> {
  bool _downloading = false;
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkCachedStatus();
  }

  @override
  void didUpdateWidget(covariant CloudinaryFileBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node != oldWidget.node) {
      _checkCachedStatus();
    }
  }

  Future<void> _checkCachedStatus() async {
    final url = (widget.node.attributes['url'] as String?) ?? '';
    if (url.isEmpty) return;

    final fileCache = FileCacheService();
    final cachedPath = await fileCache.getCachedPath(url);

    if (cachedPath != null) {
      final file = File(cachedPath);
      if (file.existsSync()) {
        final length = await file.length();
        final formatted = _formatFileSize(length);
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            if ((widget.node.attributes['file_size'] as String?)?.isEmpty ?? true) {
              widget.node.attributes['file_size'] = formatted;
            }
          });
        }
        return;
      }
    }

    final isCached = await fileCache.isCached(url);
    if (mounted) {
      setState(() => _isDownloaded = isCached);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String url, String name) {
    final ext = url.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return Icons.image;
    if (['zip', 'rar', 'tar', 'gz', '7z'].contains(ext)) return Icons.folder_zip;
    if (['mp3', 'wav', 'aac'].contains(ext)) return Icons.audiotrack;
    if (['mp4', 'mov', 'avi'].contains(ext)) return Icons.video_collection;
    return Icons.insert_drive_file;
  }

  bool _isImageFile(String url, String name) {
    final cleanUrl = url.split('?').first.toLowerCase();
    final ext = cleanUrl.split('.').last;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp', 'svg'].contains(ext)) return true;
    if (url.contains('/image/upload/')) return true;
    final nameExt = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp', 'svg'].contains(nameExt)) return true;
    return false;
  }

  Future<void> _openFile(String url, String name) async {
    if (_downloading) return;

    final fileCache = FileCacheService();
    final cachedPath = await fileCache.getCachedPath(url);

    if (cachedPath != null) {
      if (mounted && !_isDownloaded) {
        setState(() => _isDownloaded = true);
      }
      await OpenFilex.open(cachedPath);
      return;
    }

    setState(() => _downloading = true);
    try {
      final localPath = await fileCache.downloadFile(url);
      if (mounted) {
        setState(() {
          _downloading = false;
          _isDownloaded = (localPath != null);
        });
      }

      if (localPath != null) {
        await OpenFilex.open(localPath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download file.', style: GoogleFonts.outfit(color: U.getContrastColor(U.red))),
              backgroundColor: U.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e', style: GoogleFonts.outfit(color: U.getContrastColor(U.red))),
            backgroundColor: U.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.node.attributes['display_name'] as String?) ?? 'Attachment File';
    final url = (widget.node.attributes['url'] as String?) ?? '';
    final fileSize = widget.node.attributes['file_size'] as String?;
    final subtitleText = (fileSize != null && fileSize.isNotEmpty) ? fileSize : '';
    final isImage = _isImageFile(url, name);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isEditable) ...[
            buildBlockHeaderControls(
              context: context,
              node: widget.node,
              isEditable: widget.isEditable,
              editorState: widget.editorState,
              onChanged: widget.onChanged,
              title: isImage ? 'Image Attachment' : 'File Attachment',
              icon: isImage ? Icons.image_rounded : Icons.attach_file_rounded,
              color: U.primary,
            ),
            const SizedBox(height: 4),
          ],
          if (isImage)
            GestureDetector(
              onTap: () => _openFile(url, name),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      color: U.surface,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(color: U.primary, strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(16),
                    color: U.surface,
                    child: Row(
                      children: [
                        Icon(Icons.broken_image_rounded, color: U.red),
                        const SizedBox(width: 8),
                        Text('Failed to load image', style: GoogleFonts.outfit(color: U.sub)),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: U.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getFileIcon(url, name), color: U.primary, size: 24),
              ),
              title: Text(
                name,
                style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: subtitleText.isNotEmpty
                  ? Text(
                      subtitleText,
                      style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: _downloading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: U.primary),
                    )
                  : IconButton(
                      icon: Icon(
                        _isDownloaded ? Icons.check_circle_outline_rounded : Icons.download_for_offline_outlined,
                        color: _isDownloaded ? U.green : U.primary,
                      ),
                      onPressed: () => _openFile(url, name),
                      tooltip: _isDownloaded ? 'Open File (Downloaded)' : 'Download & Open File',
                    ),
              onTap: () => _openFile(url, name),
            ),
        ],
      ),
    );
  }
}
