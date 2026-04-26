import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/broadcast_service.dart';
import '../widgets/utopia_snackbar.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  String get _senderName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Writer';

  bool get _canSend =>
      _titleController.text.trim().isNotEmpty &&
      _messageController.text.trim().isNotEmpty &&
      !_sending;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_handleInputChanged);
    _messageController.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleInputChanged);
    _messageController.removeListener(_handleInputChanged);
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendBroadcast() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await BroadcastService.sendBroadcast(
        title: title,
        message: message,
        senderName: _senderName,
      );

      if (!mounted) {
        return;
      }

      _titleController.clear();
      _messageController.clear();
      showUtopiaSnackBar(
        context,
        message: 'Broadcast sent successfully',
        tone: UtopiaSnackBarTone.success,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      showUtopiaSnackBar(
        context,
        message: 'Failed to send broadcast',
        tone: UtopiaSnackBarTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewTitle = _titleController.text.trim().isEmpty
        ? 'Your title will appear here'
        : _titleController.text.trim();
    final previewMessage = _messageController.text.trim().isEmpty
        ? 'Your message preview will appear here.'
        : _messageController.text.trim();

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        foregroundColor: U.text,
        title: const Text('Broadcast Message'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send an urgent message to all students',
                style: GoogleFonts.outfit(color: U.sub),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                maxLength: 60,
                style: GoogleFonts.outfit(color: U.text),
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Lab cancelled today',
                  labelStyle: GoogleFonts.outfit(color: U.text),
                  hintStyle: GoogleFonts.outfit(color: U.dim),
                  filled: true,
                  fillColor: U.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: U.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: U.primary, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                maxLength: 200,
                maxLines: 4,
                style: GoogleFonts.outfit(color: U.text),
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText:
                      'e.g. BEEE lab is cancelled. Report to classroom.',
                  labelStyle: GoogleFonts.outfit(color: U.text),
                  hintStyle: GoogleFonts.outfit(color: U.dim),
                  filled: true,
                  fillColor: U.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: U.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: U.primary, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: U.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📢 Preview',
                        style: GoogleFonts.outfit(
                          color: U.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '📢 $previewTitle',
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$previewMessage\n— $_senderName',
                        style: GoogleFonts.outfit(
                          color: U.sub,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _canSend ? _sendBroadcast : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: U.primary,
                    foregroundColor: U.bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _sending
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: U.bg,
                          ),
                        )
                      : const Text('Send to All Students'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
