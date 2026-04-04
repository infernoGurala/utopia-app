import 'package:flutter/material.dart';

import '../services/writer_github_service.dart';
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
      final data = await WriterGitHubService.fetchRawJson('quotes.json');
      final loadedQuotes = <String>[];
      if (data is Map<String, dynamic> && data['quotes'] is List) {
        loadedQuotes.addAll(
          (data['quotes'] as List).map((item) => item.toString()),
        );
      } else if (data is List) {
        loadedQuotes.addAll(data.map((item) => item.toString()));
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
          backgroundColor: const Color(0xFF313244),
          title: const Text(
            'Add Quote',
            style: TextStyle(color: Color(0xFFCDD6F4)),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(color: Color(0xFFCDD6F4)),
            decoration: InputDecoration(
              hintText: 'Type a new quote',
              hintStyle: const TextStyle(color: Color(0xFF6C7086)),
              filled: true,
              fillColor: const Color(0xFF1E1E2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF45475A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBA6F7)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFFA6ADC8)),
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
                backgroundColor: const Color(0xFFCBA6F7),
                foregroundColor: const Color(0xFF11111B),
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
      await WriterGitHubService.updateJsonFile(
        filename: 'quotes.json',
        jsonData: {
          'quotes': _quotes.where((quote) => quote.trim().isNotEmpty).toList(),
        },
        commitMessage: 'Updated quotes via UTOPIA app',
      );
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
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181825),
        foregroundColor: const Color(0xFFCDD6F4),
        title: const Text('Quotes Pool'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFCBA6F7)),
            )
          : _quotes.isEmpty
          ? const Center(
              child: Text(
                'No quotes yet.',
                style: TextStyle(color: Color(0xFFA6ADC8)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _quotes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Card(
                  color: const Color(0xFF313244),
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      _quotes[index],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFCDD6F4),
                        height: 1.5,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () {
                        setState(() {
                          _quotes.removeAt(index);
                        });
                      },
                      icon: const Icon(
                        Icons.delete,
                        color: Color(0xFFF38BA8),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddQuoteDialog,
        backgroundColor: const Color(0xFFCBA6F7),
        foregroundColor: const Color(0xFF11111B),
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
                backgroundColor: const Color(0xFFCBA6F7),
                foregroundColor: const Color(0xFF11111B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF11111B),
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
