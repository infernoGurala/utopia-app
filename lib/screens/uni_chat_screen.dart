import 'dart:async';
import 'package:flutter/material.dart';
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
                  return Center(child: CircularProgressIndicator(color: U.primary));
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
                    return Align(
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
                                    style: GoogleFonts.outfit(color: U.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            Text(
                              data['text'] ?? '',
                              style: GoogleFonts.outfit(color: isMe ? U.bg : U.text, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
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
