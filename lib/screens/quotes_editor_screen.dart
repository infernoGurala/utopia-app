import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/writer_firestore_service.dart';
import '../widgets/utopia_snackbar.dart';

class QuotesEditorScreen extends StatefulWidget {
  const QuotesEditorScreen({super.key});

  @override
  State<QuotesEditorScreen> createState() => _QuotesEditorScreenState();
}

class _QuotesEditorScreenState extends State<QuotesEditorScreen> {
  bool _loading = true;
  bool _saving = false;
  final List<String> _quotes = [];

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    try {
      final data = await WriterFirestoreService.fetchConfig('quotes');
      final loadedQuotes = <String>[];
      if (data is Map<String, dynamic> && data['quotes'] is List) {
        loadedQuotes.addAll(
          (data['quotes'] as List).map((item) => item.toString()),
        );
      } else if (data is List) {
        loadedQuotes.addAll((data as List).map((item) => item.toString()));
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _quotes
          ..clear()
          ..addAll(loadedQuotes);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      showUtopiaSnackBar(
        context,
        message: 'Could not load quotes',
        tone: UtopiaSnackBarTone.error,
      );
    }
  }

  Future<void> _showAddQuoteDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: U.surface,
          title: Text(
            'Add Quote',
            style: GoogleFonts.outfit(color: U.text),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            style: GoogleFonts.outfit(color: U.text),
            decoration: InputDecoration(
              hintText: 'Type a new quote',
              hintStyle: GoogleFonts.outfit(color: U.dim),
              filled: true,
              fillColor: U.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: U.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: U.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: U.sub),
              ),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  setState(() {
                    _quotes.add(value);
                  });
                }
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: U.primary,
                foregroundColor: U.bg,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _saveQuotes() async {
    setState(() {
      _saving = true;
    });

    try {
      await WriterFirestoreService.updateConfig('quotes', {
        'quotes': _quotes.where((quote) => quote.trim().isNotEmpty).toList(),
      });
      if (!mounted) {
        return;
      }
      showUtopiaSnackBar(
        context,
        message: 'Quotes saved',
        tone: UtopiaSnackBarTone.success,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      showUtopiaSnackBar(
        context,
        message: 'Could not save quotes',
        tone: UtopiaSnackBarTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        foregroundColor: U.text,
        title: const Text('Quotes Pool'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: U.primary))
          : _quotes.isEmpty
          ? Center(
              child: Text(
                'No quotes yet.',
                style: GoogleFonts.outfit(color: U.sub),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _quotes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Card(
                  color: U.card,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      _quotes[index],
                      style: GoogleFonts.outfit(
                        color: U.text,
                        height: 1.5,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () {
                        setState(() {
                          _quotes.removeAt(index);
                        });
                      },
                      icon: Icon(
                        Icons.delete,
                        color: U.red,
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddQuoteDialog,
        backgroundColor: U.primary,
        foregroundColor: U.bg,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _saveQuotes,
              style: FilledButton.styleFrom(
                backgroundColor: U.primary,
                foregroundColor: U.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: U.bg,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ),
      ),
    );
  }
}
