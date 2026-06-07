import 'package:flutter/material.dart';
import '../../../models/delve_word_model.dart';
import '../../../providers/delve_theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../providers/delve_inventory_provider.dart';
import '../../../services/delve_groq_service.dart';

class AddWordSheet extends StatefulWidget {
  final Word? existingWord;

  const AddWordSheet({super.key, this.existingWord});

  @override
  State<AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends State<AddWordSheet> {
  late TextEditingController _wordCtrl;
  late TextEditingController _meaningCtrl;
  late TextEditingController _noteCtrl;
  bool _isGenerating = false;
  final _groqService = GroqService();

  @override
  void initState() {
    super.initState();
    _wordCtrl = TextEditingController(text: widget.existingWord?.word);
    _meaningCtrl = TextEditingController(text: widget.existingWord?.meaning);
    _noteCtrl = TextEditingController(text: widget.existingWord?.note);
  }

  @override
  void dispose() {
    _wordCtrl.dispose();
    _meaningCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save({bool force = false}) {
    final wordText = _wordCtrl.text.trim();
    final meaningText = _meaningCtrl.text.trim();
    if (wordText.isEmpty || meaningText.isEmpty) return;

    final provider = context.read<InventoryProvider>();
    
    // Duplicate check (only if not editing and not forced)
    if (widget.existingWord == null && !force) {
      final duplicate = provider.findDuplicate(wordText);
      if (duplicate != null) {
        _showConflictDialog(duplicate);
        return;
      }
    }

    final newWord = Word(
      id: widget.existingWord?.id ?? const Uuid().v4(),
      word: wordText,
      meaning: meaningText,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      addedAt: widget.existingWord?.addedAt ?? DateTime.now(),
      aiMeaning: widget.existingWord?.aiMeaning,
      failCount: widget.existingWord?.failCount ?? 0,
      archivedAt: widget.existingWord?.archivedAt,
    );

    if (widget.existingWord == null) {
      provider.addWord(newWord);
    } else {
      provider.updateWord(newWord);
    }
    Navigator.of(context).pop();
  }

  void _showConflictDialog(Word existing) {
    final theme = context.read<DelveThemeProvider>().currentTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardBackground,
        title: Text('Conflict detected', style: TextStyle(color: theme.text)),
        content: Text(
          'The word "${existing.word}" already exists in your library. What would you like to do?',
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Update existing word with new meaning/note
              final updated = existing.copyWith(
                meaning: _meaningCtrl.text.trim(),
                note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
              );
              context.read<InventoryProvider>().updateWord(updated);
              Navigator.of(this.context).pop();
            },
            child: Text('Merge/Replace', style: TextStyle(color: theme.accent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _save(force: true); // Add as duplicate anyway (different ID)
            },
            child: Text('Add as new', style: TextStyle(color: theme.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _delete() {
    if (widget.existingWord != null) {
      context.read<InventoryProvider>().removeWord(widget.existingWord!.id);
      Navigator.of(context).pop();
    }
  }

  void _generateAiMeaning() async {
    final word = _wordCtrl.text.trim();
    if (word.isEmpty) return;
    
    setState(() => _isGenerating = true);
    
    final generated = await _groqService.generateMeaning(word);
    
    if (mounted) {
      setState(() {
        if (generated != null && generated.isNotEmpty) {
          // Remove any quotes the AI might have accidentally added
          _meaningCtrl.text = generated.replaceAll('"', '').trim();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI failed to generate a meaning.')),
          );
        }
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DelveThemeProvider>().currentTheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existingWord == null ? 'Add Word' : 'Edit Word',
              style: TextStyle(
                color: theme.text,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _wordCtrl,
              style: TextStyle(color: theme.text),
              decoration: const InputDecoration(labelText: 'Word'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _meaningCtrl,
              style: TextStyle(color: theme.text),
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'What it means to you'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isGenerating ? null : _generateAiMeaning,
                icon: _isGenerating 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
                label: const Text('Generate with AI'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              style: TextStyle(color: theme.text),
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Personal note (optional)'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save Word'),
              ),
            ),
            if (widget.existingWord != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Delete Word'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
