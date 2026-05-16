import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/utopia_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'user_profile_screen.dart';

class UniChatScreen extends StatefulWidget {
  final String universityId;
  const UniChatScreen({super.key, required this.universityId});

  @override
  State<UniChatScreen> createState() => _UniChatScreenState();
}

class _UniChatScreenState extends State<UniChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  DateTime? _lastSent;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _currentName => FirebaseAuth.instance.currentUser?.displayName ?? 'Student';
  String get _currentEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    if (_lastSent != null && DateTime.now().difference(_lastSent!).inSeconds < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please wait 3 seconds between messages', style: GoogleFonts.outfit(color: U.bg)),
          backgroundColor: U.red,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance
          .collection('uni_chats')
          .doc(widget.universityId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': _currentUid,
        'senderName': _currentName,
        'senderEmail': _currentEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _controller.clear();
      _lastSent = DateTime.now();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message', style: GoogleFonts.outfit(color: U.bg)),
            backgroundColor: U.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    
    SharedPreferences.getInstance().then((prefs) {
      FirebaseFirestore.instance
          .collection('uni_chats')
          .doc(widget.universityId)
          .collection('messages')
          .count()
          .get()
          .then((aggregate) {
        prefs.setInt('last_seen_unichat_count', aggregate.count ?? 0);
      });
    });
    
    super.dispose();
  }

  String _formatTime(Timestamp? raw) {
    if (raw == null) return 'Sending...';
    final date = raw.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final meridiem = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $meridiem';
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (date.year == now.year) {
      return '${months[date.month - 1]} ${date.day}';
    }
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  bool _shouldShowDateSeparator(List<QueryDocumentSnapshot> docs, int index) {
    // List is reversed, so index 0 is newest
    final currentData = docs[index].data() as Map<String, dynamic>;
    final currentTs = currentData['timestamp'] as Timestamp?;
    if (currentTs == null) return false;

    if (index == docs.length - 1) return true; // Oldest message always shows date

    final nextData = docs[index + 1].data() as Map<String, dynamic>;
    final nextTs = nextData['timestamp'] as Timestamp?;
    if (nextTs == null) return false;

    final currentDate = currentTs.toDate();
    final nextDate = nextTs.toDate();
    return currentDate.year != nextDate.year ||
           currentDate.month != nextDate.month ||
           currentDate.day != nextDate.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        title: Text('Uni Chat', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
        foregroundColor: U.text,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('uni_chats')
                  .doc(widget.universityId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: UtopiaLoader(scale: 0.7));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text('Be the first to say hi!', style: GoogleFonts.outfit(color: U.dim)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUid;
                    final ts = data['timestamp'] as Timestamp?;
                    final showDateSep = _shouldShowDateSeparator(docs, index);

                    return Column(
                      children: [
                        // Date separator (shown above in visual order, but below in reversed list)
                        if (showDateSep && ts != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: U.border, thickness: 0.5)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    _formatDateLabel(ts.toDate()),
                                    style: GoogleFonts.outfit(
                                      color: U.dim,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: U.border, thickness: 0.5)),
                              ],
                            ),
                          ),
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? U.primary : U.card,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: GestureDetector(
                                      onTap: () {
                                        if (data['senderId'] != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => UserProfileScreen(
                                                uid: data['senderId'],
                                                displayName: data['senderName'] ?? 'Student',
                                                email: data['senderEmail'] ?? '',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        data['senderName'] ?? 'Student',
                                        style: GoogleFonts.outfit(color: isMe ? U.bg.withValues(alpha: 0.7) : U.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                Text(
                                  data['text'] ?? '',
                                  style: GoogleFonts.outfit(color: isMe ? U.bg : U.text, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(ts),
                                  style: GoogleFonts.outfit(
                                    color: isMe ? U.bg.withValues(alpha: 0.5) : U.dim,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Container(
            color: U.card,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.paddingOf(context).bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.outfit(color: U.text),
                    decoration: InputDecoration(
                      hintText: 'Message everyone...',
                      hintStyle: GoogleFonts.outfit(color: U.sub),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _send,
                  icon: _sending 
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: U.primary, strokeWidth: 2))
                      : Icon(Icons.send, color: U.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
