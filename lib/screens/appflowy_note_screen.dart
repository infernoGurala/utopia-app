import 'dart:async';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/file_upload_service.dart';
import '../services/supabase_notes_service.dart';
import '../utils/appflowy_markdown_converter.dart';
import '../widgets/appflowy_custom_blocks.dart';
import '../widgets/utopia_loading_overlay.dart';

class AppFlowyNoteScreen extends StatefulWidget {
  final String title;
  final String filePath;
  final String? folderPath;
  final String? overrideContent;
  final bool isEditable;
  final bool useGlobalRepo;

  const AppFlowyNoteScreen({
    super.key,
    required this.title,
    required this.filePath,
    this.folderPath,
    this.overrideContent,
    this.isEditable = false,
    this.useGlobalRepo = false,
  });

  @override
  State<AppFlowyNoteScreen> createState() => _AppFlowyNoteScreenState();
}

class _AppFlowyNoteScreenState extends State<AppFlowyNoteScreen> {
  final _notesService = SupabaseNotesService();
  late EditorState _editorState;
  bool _loading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  String _rawMarkdown = '';

  late FocusNode _editorFocusNode;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isEditable;
    _editorFocusNode = FocusNode(canRequestFocus: _isEditing);
    _editorState = EditorState.blank();
    _editorState.editable = _isEditing;
    _loadContent();
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() => _loading = true);
    try {
      if (widget.overrideContent != null) {
        _rawMarkdown = widget.overrideContent!;
      } else {
        _rawMarkdown = await _notesService.getNoteContent(widget.filePath);
      }

      final doc = AppFlowyMarkdownConverter.markdownToDocument(_rawMarkdown);
      _editorState = EditorState(document: doc);
      _editorState.editable = _isEditing;
      _editorState.transactionStream.listen((_) {
        if (!_hasChanges && mounted) {
          setState(() => _hasChanges = true);
        }
      });
    } catch (e) {
      debugPrint('AppFlowyNoteScreen: Error loading content: $e');
      _editorState = EditorState.blank();
      _editorState.editable = _isEditing;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final updatedMarkdown = AppFlowyMarkdownConverter.documentToMarkdown(_editorState.document);
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'unknown';
      final name = user?.displayName ?? user?.email ?? 'User';

      await _notesService.updateNote(
        widget.filePath,
        updatedMarkdown,
        uid,
        name,
      );

      _rawMarkdown = updatedMarkdown;
      _hasChanges = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note saved successfully!', style: GoogleFonts.outfit(color: U.getContrastColor(U.green))),
            backgroundColor: U.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: $e', style: GoogleFonts.outfit(color: U.getContrastColor(U.red))),
            backgroundColor: U.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _handleFileUpload() async {
    final service = FileUploadService();
    try {
      final picked = await service.pickFile();
      if (picked == null) return;

      final (file, originalName) = picked;
      final fileLength = await file.length();
      final formattedSize = _formatFileSize(fileLength);

      if (!mounted) return;
      final displayName = await _askDisplayName(originalName);
      if (displayName == null || displayName.trim().isEmpty) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: U.getContrastColor(U.primary))),
              const SizedBox(width: 12),
              Text('Uploading $displayName...', style: GoogleFonts.outfit(color: U.getContrastColor(U.primary))),
            ],
          ),
          backgroundColor: U.primary,
          duration: const Duration(seconds: 30),
        ),
      );

      final universityId = widget.filePath.contains('/') ? widget.filePath.split('/').first : 'default';
      final downloadUrl = await service.uploadFile(
        file: file,
        originalFilename: originalName,
        universityId: universityId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      final fileNode = Node(
        type: 'cloudinary_file_block',
        attributes: {
          'display_name': displayName,
          'url': downloadUrl,
          'file_size': formattedSize,
        },
      );

      final transaction = _editorState.transaction;
      transaction.insertNodes([_editorState.document.root.children.length], [fileNode]);
      await _editorState.apply(transaction);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File uploaded and added to note!', style: GoogleFonts.outfit(color: U.getContrastColor(U.green))),
          backgroundColor: U.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File upload failed: $e', style: GoogleFonts.outfit(color: U.getContrastColor(U.red))),
          backgroundColor: U.red,
        ),
      );
    }
  }

  Future<String?> _askDisplayName(String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        title: Text('File Display Name', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.outfit(color: U.text),
          decoration: InputDecoration(
            hintText: 'Enter name...',
            hintStyle: GoogleFonts.outfit(color: U.sub),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: U.primary),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Confirm', style: GoogleFonts.outfit(color: U.getContrastColor(U.primary))),
          ),
        ],
      ),
    );
  }

  void _showInsertBlockMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: U.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Insert Text Block', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.title_rounded, color: U.primary),
                title: Text('Heading 1', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertNode(headingNode(level: 1, text: ''));
                },
              ),
              ListTile(
                leading: Icon(Icons.title_rounded, color: U.primary, size: 20),
                title: Text('Heading 2', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertNode(headingNode(level: 2, text: ''));
                },
              ),
              ListTile(
                leading: Icon(Icons.title_rounded, color: U.primary, size: 16),
                title: Text('Heading 3', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertNode(headingNode(level: 3, text: ''));
                },
              ),
              ListTile(
                leading: Icon(Icons.notes_rounded, color: U.sub),
                title: Text('Text Paragraph', style: GoogleFonts.outfit(color: U.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertNode(paragraphNode(text: ''));
                },
              ),
              ListTile(
                leading: Icon(Icons.format_list_bulleted_rounded, color: U.sub),
                title: Text('Bulleted List', style: GoogleFonts.outfit(color: U.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertNode(bulletedListNode(text: ''));
                },
              ),
              ListTile(
                leading: Icon(Icons.format_list_numbered_rounded, color: U.sub),
                title: Text('Numbered List', style: GoogleFonts.outfit(color: U.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertNode(numberedListNode());
                },
              ),
              ListTile(
                leading: Icon(Icons.attach_file_rounded, color: U.blue),
                title: Text('Upload Attachment', style: GoogleFonts.outfit(color: U.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleFileUpload();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _insertNode(Node node) async {
    final transaction = _editorState.transaction;
    transaction.insertNodes([_editorState.document.root.children.length], [node]);
    await _editorState.apply(transaction);
    setState(() => _hasChanges = true);
  }

  Map<String, BlockComponentBuilder> _buildBlockComponentBuilders() {
    final customBuilders = <String, BlockComponentBuilder>{
      'qa_block': QABlockComponentBuilder(isEditable: _isEditing, onChanged: () => setState(() => _hasChanges = true)),
      'latex_block': LaTeXBlockComponentBuilder(isEditable: _isEditing, onChanged: () => setState(() => _hasChanges = true)),
      'mermaid_block': MermaidBlockComponentBuilder(isEditable: _isEditing, onChanged: () => setState(() => _hasChanges = true)),
      'table_block': UtopiaTableBlockComponentBuilder(isEditable: _isEditing, onChanged: () => setState(() => _hasChanges = true)),
      'cloudinary_file_block': CloudinaryFileBlockComponentBuilder(isEditable: _isEditing, onChanged: () => setState(() => _hasChanges = true)),
    };

    final standardBuilders = standardBlockComponentBuilderMap;
    return {...standardBuilders, ...customBuilders};
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unsaved Changes',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'You have unsaved changes. Would you like to save before exiting?',
          style: GoogleFonts.outfit(color: U.sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Discard', style: GoogleFonts.outfit(color: U.red)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: U.primary,
              foregroundColor: U.getContrastColor(U.primary),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save & Exit', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == null) {
      return false;
    }
    if (result == true) {
      await _saveNote();
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: U.bg,
        appBar: AppBar(
          backgroundColor: U.card,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            widget.title,
            style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            if (_isEditing) ...[
              IconButton(
                icon: Icon(Icons.undo_rounded, color: U.text),
                onPressed: () => _editorState.undoManager.undo(),
                tooltip: 'Undo',
              ),
              IconButton(
                icon: Icon(Icons.redo_rounded, color: U.text),
                onPressed: () => _editorState.undoManager.redo(),
                tooltip: 'Redo',
              ),
              IconButton(
                icon: Icon(Icons.add_box_outlined, color: U.primary),
                onPressed: _showInsertBlockMenu,
                tooltip: 'Add Text Block',
              ),
              IconButton(
                icon: Icon(Icons.upload_file, color: U.blue),
                onPressed: _handleFileUpload,
                tooltip: 'Upload Attachment',
              ),
              IconButton(
                icon: Icon(Icons.save, color: _hasChanges ? U.green : U.sub),
                onPressed: _saveNote,
                tooltip: 'Save Note',
              ),
            ],
            IconButton(
              icon: Icon(_isEditing ? Icons.visibility : Icons.edit, color: U.primary),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() {
                  _isEditing = !_isEditing;
                  _editorState.editable = _isEditing;
                  _editorFocusNode.canRequestFocus = _isEditing;
                  if (!_isEditing) {
                    _editorFocusNode.unfocus();
                  }
                });
              },
              tooltip: _isEditing ? 'Switch to Read Mode' : 'Switch to Edit Mode',
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: AppFlowyEditor(
                key: ValueKey(_isEditing),
                editorState: _editorState,
                editable: _isEditing,
                focusNode: _editorFocusNode,
                disableKeyboardService: !_isEditing,
                disableSelectionService: !_isEditing,
                editorStyle: EditorStyle.mobile(
                  cursorColor: U.primary,
                  selectionColor: U.primary.withValues(alpha: 0.2),
                  dragHandleColor: U.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyleConfiguration: TextStyleConfiguration(
                    text: GoogleFonts.outfit(fontSize: 16, color: U.text),
                    bold: const TextStyle(fontWeight: FontWeight.bold),
                    italic: const TextStyle(fontStyle: FontStyle.italic),
                    href: GoogleFonts.outfit(color: U.primary, decoration: TextDecoration.underline),
                    code: GoogleFonts.outfit(color: U.primary, backgroundColor: U.surface),
                  ),
                ),
                blockComponentBuilders: _buildBlockComponentBuilders(),
              ),
            ),
            if (_loading || _isSaving) const UtopiaLoadingOverlay(),
          ],
        ),
      ),
    );
  }
}
