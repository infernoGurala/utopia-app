import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

class EventChatScreen extends StatefulWidget {
  final EventModel event;
  const EventChatScreen({super.key, required this.event});

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.event.id == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    await EventService.instance.sendChatMessage(widget.event.id!, text);

    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.title,
              style: GoogleFonts.outfit(color: U.text, fontSize: 18, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Event Chat',
              style: GoogleFonts.outfit(color: U.teal, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.event.id != null
                ? StreamBuilder<List<EventChatMessage>>(
                    stream: EventService.instance.streamChat(widget.event.id!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return Center(child: CircularProgressIndicator(color: U.primary));
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forum_outlined, size: 48, color: U.dim),
                              const SizedBox(height: 12),
                              Text('No messages yet', style: GoogleFonts.outfit(color: U.sub, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Start the conversation!', style: GoogleFonts.outfit(color: U.dim, fontSize: 13)),
                            ],
                          ),
                        );
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.userId == currentUid;
                          return _buildMessageBubble(msg, isMe);
                        },
                      );
                    },
                  )
                : Center(
                    child: Text('Chat not available', style: GoogleFonts.outfit(color: U.sub)),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        border: Border(top: BorderSide(color: U.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.outfit(color: U.text),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.outfit(color: U.sub),
                  filled: true,
                  fillColor: U.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: U.primary,
              radius: 24,
              child: IconButton(
                icon: _isSending
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: U.bg, strokeWidth: 2))
                    : Icon(Icons.send_rounded, color: U.bg, size: 20),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(EventChatMessage msg, bool isMe) {
    final timeStr = msg.createdAt != null
        ? '${msg.createdAt!.hour}:${msg.createdAt!.minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: msg.isOrganizer ? U.primary.withValues(alpha: 0.2) : U.dim.withValues(alpha: 0.2),
              child: Icon(
                msg.isOrganizer ? Icons.business_center_rounded : Icons.person_rounded,
                size: 16,
                color: msg.isOrganizer ? U.primary : U.dim,
              ),
            ),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? U.primary : U.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: U.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            msg.userName,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: msg.isOrganizer ? U.primary : U.sub,
                            ),
                          ),
                          if (msg.isOrganizer) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified_rounded, color: U.teal, size: 12),
                          ],
                        ],
                      ),
                    ),
                  Text(
                    msg.message,
                    style: GoogleFonts.outfit(color: isMe ? U.bg : U.text, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: GoogleFonts.outfit(
                      color: isMe ? U.bg.withValues(alpha: 0.7) : U.dim,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
