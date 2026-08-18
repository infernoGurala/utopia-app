import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/utopia_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/uni_chat_service.dart';
import '../widgets/unread_indicator_dot.dart';
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
  String? _editingMessageId;
  Map<String, dynamic>? _replyingToMessage;
  bool _showScrollDown = false;
  bool _hasNewMessagesWhileScrolled = false;
  String? _lastSeenTopDocId;
  late final Stream<QuerySnapshot> _messagesStream;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _currentName => FirebaseAuth.instance.currentUser?.displayName ?? 'Student';
  String get _currentEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _messagesStream = FirebaseFirestore.instance
        .collection('uni_chats')
        .doc(widget.universityId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
    UniChatService().markAsSeen(widget.universityId);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final show = offset > 140.0;
    if (show != _showScrollDown) {
      setState(() => _showScrollDown = show);
    }
    if (offset <= 30.0) {
      if (_hasNewMessagesWhileScrolled) {
        setState(() => _hasNewMessagesWhileScrolled = false);
      }
      UniChatService().markAsSeen(widget.universityId);
    }
  }

  void _scrollToBottom() {
    HapticFeedback.lightImpact();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (_hasNewMessagesWhileScrolled) {
      setState(() => _hasNewMessagesWhileScrolled = false);
    }
    UniChatService().markAsSeen(widget.universityId);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    if (_editingMessageId != null) {
      final msgId = _editingMessageId!;
      setState(() => _sending = true);
      try {
        await FirebaseFirestore.instance
            .collection('uni_chats')
            .doc(widget.universityId)
            .collection('messages')
            .doc(msgId)
            .update({
          'text': text,
          'isEdited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
        _controller.clear();
        setState(() {
          _editingMessageId = null;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to edit message', style: GoogleFonts.outfit(color: U.bg)),
              backgroundColor: U.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }

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
      final payload = <String, dynamic>{
        'text': text,
        'senderId': _currentUid,
        'senderName': _currentName,
        'senderEmail': _currentEmail,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_replyingToMessage != null) {
        payload['replyTo'] = {
          'id': _replyingToMessage!['id'],
          'text': _replyingToMessage!['text'],
          'senderName': _replyingToMessage!['senderName'],
        };
      }

      await FirebaseFirestore.instance
          .collection('uni_chats')
          .doc(widget.universityId)
          .collection('messages')
          .add(payload);

      UniChatService().markAsSeen(widget.universityId);

      _controller.clear();
      _lastSent = DateTime.now();
      setState(() {
        _replyingToMessage = null;
      });
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

  void _startEditing(String messageId, String currentText) {
    setState(() {
      _replyingToMessage = null;
      _editingMessageId = messageId;
      _controller.text = currentText;
      _controller.selection = TextSelection.collapsed(offset: currentText.length);
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _controller.clear();
    });
  }

  void _startReply(Map<String, dynamic> data, String messageId) {
    setState(() {
      _editingMessageId = null;
      _replyingToMessage = {
        'id': messageId,
        'text': data['text'] ?? '',
        'senderName': data['senderName'] ?? 'Student',
      };
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  Future<void> _unsendMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('uni_chats')
          .doc(widget.universityId)
          .collection('messages')
          .doc(messageId)
          .delete();
      if (_editingMessageId == messageId) {
        _cancelEditing();
      }
      if (_replyingToMessage != null && _replyingToMessage!['id'] == messageId) {
        _cancelReply();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message unsent', style: GoogleFonts.outfit(color: U.bg)),
            duration: const Duration(milliseconds: 900),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unsend message', style: GoogleFonts.outfit(color: U.bg)),
            backgroundColor: U.red,
          ),
        );
      }
    }
  }

  void _showMessageOptions(String messageId, Map<String, dynamic> data, bool isMe) {
    final text = (data['text'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: U.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: U.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.reply_rounded, color: U.primary),
                  title: Text('Reply', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _startReply(data, messageId);
                  },
                ),
                if (isMe) ...[
                  ListTile(
                    leading: Icon(Icons.edit_rounded, color: U.primary),
                    title: Text('Edit message', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _startEditing(messageId, text);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.undo_rounded, color: U.red),
                    title: Text('Unsend message', style: GoogleFonts.outfit(color: U.red, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _unsendMessage(messageId);
                    },
                  ),
                ],
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: U.sub),
                  title: Text('Copy text', style: GoogleFonts.outfit(color: U.text)),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied to clipboard', style: GoogleFonts.outfit(color: U.bg)),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    UniChatService().markAsSeen(widget.universityId);
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
    final isDarkTheme = appThemeNotifier.value.isDark;

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        title: Text('Chat to Utopia', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
        foregroundColor: U.text,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: UtopiaLoader(scale: 0.7));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Text('Be the first to say hi!', style: GoogleFonts.outfit(color: U.dim)),
                      );
                    }

                    // Real-time unread synchronization & scroll badge trigger
                    if (docs.isNotEmpty) {
                      final topDoc = docs.first.data() as Map<String, dynamic>;
                      final topSenderId = topDoc['senderId'] as String?;
                      final topTs = topDoc['timestamp'] as Timestamp?;
                      if (_lastSeenTopDocId != docs.first.id && topSenderId != _currentUid && topTs != null) {
                        _lastSeenTopDocId = docs.first.id;
                        if (_showScrollDown) {
                          if (!_hasNewMessagesWhileScrolled) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _hasNewMessagesWhileScrolled = true);
                            });
                          }
                        } else {
                          UniChatService().markAsSeen(widget.universityId);
                        }
                      }
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
                              child: _SwipeToReplyBubble(
                                onReply: () => _startReply(data, docs[index].id),
                                child: GestureDetector(
                                  onLongPress: () => _showMessageOptions(docs[index].id, data, isMe),
                                  onDoubleTap: () => _startReply(data, docs[index].id),
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
                                        if (data['replyTo'] != null) ...[
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isMe
                                                  ? Colors.black.withValues(alpha: 0.15)
                                                  : U.surface.withValues(alpha: 0.7),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border(
                                                left: BorderSide(
                                                  color: isMe ? Colors.white : U.primary,
                                                  width: 3,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  data['replyTo']['senderName'] ?? 'Student',
                                                  style: GoogleFonts.outfit(
                                                    color: isMe ? Colors.white.withValues(alpha: 0.9) : U.primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  data['replyTo']['text'] ?? '',
                                                  style: GoogleFonts.outfit(
                                                    color: isMe ? Colors.white.withValues(alpha: 0.75) : U.sub,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        Text(
                                          data['text'] ?? '',
                                          style: GoogleFonts.outfit(color: isMe ? U.bg : U.text, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_formatTime(ts)}${data['isEdited'] == true ? ' • edited' : ''}',
                                          style: GoogleFonts.outfit(
                                            color: isMe ? U.bg.withValues(alpha: 0.55) : U.dim,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                // ── Floating Scroll-to-Bottom Button ──
                Positioned(
                  bottom: 12,
                  right: 16,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    offset: _showScrollDown ? Offset.zero : const Offset(0, 1.5),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showScrollDown ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !_showScrollDown,
                        child: GestureDetector(
                          onTap: _scrollToBottom,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDarkTheme
                                  ? U.card.withValues(alpha: 0.95)
                                  : Colors.white.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkTheme
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : U.border,
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDarkTheme ? 0.45 : 0.15,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: U.primary,
                                  size: 26,
                                ),
                                if (_hasNewMessagesWhileScrolled)
                                  const Positioned(
                                    top: 2,
                                    right: 2,
                                    child: UnreadIndicatorDot(
                                      size: 9,
                                      color: Color(0xFF2DD4BF),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: U.card,
                border: Border(top: BorderSide(color: U.border.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      color: U.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyingToMessage!['senderName']}',
                          style: GoogleFonts.outfit(
                            color: U.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyingToMessage!['text'] ?? '',
                          style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(Icons.close_rounded, size: 18, color: U.sub),
                  ),
                ],
              ),
            ),
          if (_editingMessageId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: U.card,
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 16, color: U.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editing message',
                      style: GoogleFonts.outfit(color: U.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEditing,
                    child: Icon(Icons.close_rounded, size: 18, color: U.sub),
                  ),
                ],
              ),
            ),
          Container(
            color: U.bg,
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: U.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: U.border.withValues(alpha: 0.5)),
                    ),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      style: GoogleFonts.outfit(color: U.text, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _editingMessageId != null ? 'Edit message...' : 'Message everyone...',
                        hintStyle: GoogleFonts.outfit(color: U.sub, fontSize: 14),
                        filled: true,
                        fillColor: Colors.transparent,
                        prefixIcon: Icon(
                          _editingMessageId != null ? Icons.edit_note_rounded : Icons.forum_outlined,
                          color: U.teal,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: U.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: U.primary.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _sending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _editingMessageId != null ? Icons.check_rounded : Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeToReplyBubble extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const _SwipeToReplyBubble({
    required this.child,
    required this.onReply,
  });

  @override
  State<_SwipeToReplyBubble> createState() => _SwipeToReplyBubbleState();
}

class _SwipeToReplyBubbleState extends State<_SwipeToReplyBubble> {
  double _dragOffset = 0.0;
  bool _triggeredHaptic = false;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx > 0 || _dragOffset > 0) {
      setState(() {
        _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, 70.0);
        if (_dragOffset >= 45.0 && !_triggeredHaptic) {
          _triggeredHaptic = true;
          HapticFeedback.lightImpact();
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset >= 45.0) {
      widget.onReply();
    }
    setState(() {
      _dragOffset = 0.0;
      _triggeredHaptic = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: () {
        setState(() {
          _dragOffset = 0.0;
          _triggeredHaptic = false;
        });
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_dragOffset > 0)
            Positioned(
              left: 8,
              child: Opacity(
                opacity: (_dragOffset / 45.0).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: (_dragOffset / 45.0).clamp(0.5, 1.0),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: U.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      color: U.primary,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
