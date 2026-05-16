import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class EventChatScreen extends StatefulWidget {
  final String eventName;
  const EventChatScreen({super.key, required this.eventName});

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              widget.eventName,
              style: GoogleFonts.outfit(color: U.text, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              '240 online • Event Chat',
              style: GoogleFonts.outfit(color: U.teal, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              reverse: true, // typical chat view
              children: [
                _buildMessageBubble('Is there parking available at the venue?', 'Alex M.', '10:42 AM', false),
                _buildMessageBubble('Yes, there is a dedicated parking lot behind the auditorium.', 'Organizer', '10:45 AM', false, isOrganizer: true),
                _buildMessageBubble('Awesome, thanks! See you all there.', 'You', '10:46 AM', true),
              ],
            ),
          ),
          Container(
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
                      icon: Icon(Icons.send_rounded, color: U.bg, size: 20),
                      onPressed: () {},
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

  Widget _buildMessageBubble(String message, String sender, String time, bool isMe, {bool isOrganizer = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: isOrganizer ? U.primary.withOpacity(0.2) : U.dim.withOpacity(0.2),
              child: Icon(isOrganizer ? Icons.business_center_rounded : Icons.person_rounded, size: 16, color: isOrganizer ? U.primary : U.dim),
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
                            sender,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOrganizer ? U.primary : U.sub,
                            ),
                          ),
                          if (isOrganizer) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified_rounded, color: U.teal, size: 12),
                          ],
                        ],
                      ),
                    ),
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      color: isMe ? U.bg : U.text,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: GoogleFonts.outfit(
                      color: isMe ? U.bg.withOpacity(0.7) : U.dim,
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
