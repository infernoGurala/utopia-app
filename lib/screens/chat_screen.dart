import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/chat_emoji_catalog.dart';
import '../services/chat_service.dart';
import '../services/game_champion_service.dart';
import '../services/notification_service.dart';
import '../widgets/game_champion_badge.dart';
import 'note_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  final String otherUserId;
  final String displayName;
  final String email;
  final String? photoUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _chatStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _otherUserStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  Timer? _typingDebounce;
  bool _sending = false;
  bool _emojiPickerOpen = false;
  bool _typingActive = false;
  String? _lastError;
  Map<String, dynamic>? _replyTo;
  String? _editingMessageId;
  final List<ChatEmoji> _draftEmojis = [];

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _chatId => _chatService.chatIdFor(_currentUid, widget.otherUserId);

  void _closeEmojiPicker({bool focusComposer = false}) {
    if (_emojiPickerOpen) {
      setState(() => _emojiPickerOpen = false);
    }
    if (focusComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _composerFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _chatStream = _chatService.chatStream(_chatId);
    _otherUserStream = _chatService.userStream(widget.otherUserId);
    _messagesStream = _chatService.messagesStream(_chatId);
    NotificationService.setActiveChat(_chatId);
    unawaited(_chatService.markChatRead(widget.otherUserId));
    _messageController.addListener(_handleComposerChanged);
  }

  @override
  void dispose() {
    NotificationService.setActiveChat(null);
    _typingDebounce?.cancel();
    unawaited(
      _chatService.setTypingState(
        otherUserId: widget.otherUserId,
        isTyping: false,
      ),
    );
    _messageController.removeListener(_handleComposerChanged);
    _composerFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    final hasText =
        _messageController.text.trim().isNotEmpty || _draftEmojis.isNotEmpty;
    if (hasText != _typingActive) {
      _typingActive = hasText;
      unawaited(
        _chatService.setTypingState(
          otherUserId: widget.otherUserId,
          isTyping: hasText,
        ),
      );
    }

    _typingDebounce?.cancel();
    if (!hasText) {
      return;
    }

    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _typingActive = false;
      unawaited(
        _chatService.setTypingState(
          otherUserId: widget.otherUserId,
          isTyping: false,
        ),
      );
    });
  }

  void _toggleEmojiPicker() {
    if (_emojiPickerOpen) {
      _closeEmojiPicker(focusComposer: true);
      return;
    }
    _composerFocusNode.unfocus();
    setState(() => _emojiPickerOpen = true);
  }

  void _insertEmoji(ChatEmoji emoji) {
    setState(() {
      _draftEmojis.add(emoji);
    });
    _handleComposerChanged();
  }

  void _removeDraftEmoji(int index) {
    setState(() {
      _draftEmojis.removeAt(index);
    });
    _handleComposerChanged();
  }

  Future<bool> _handleBackNavigation() async {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (_emojiPickerOpen) {
      _closeEmojiPicker();
      return false;
    }
    if (_composerFocusNode.hasFocus || keyboardVisible) {
      _composerFocusNode.unfocus();
      return false;
    }
    return true;
  }

  bool get _isEditing => _editingMessageId != null;

  void _cancelComposerMode() {
    _replyTo = null;
    _editingMessageId = null;
  }

  Future<void> _showOwnMessageActions({
    required String messageId,
    required String text,
    required bool isDeleted,
    required bool canEdit,
  }) async {
    if (isDeleted) {
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: U.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                _MessageActionTile(
                  icon: canEdit ? Icons.edit_outlined : Icons.block_outlined,
                  label: canEdit ? 'Edit message' : 'Edit unavailable',
                  color: canEdit ? U.primary : U.sub,
                  onTap: () =>
                      Navigator.of(context).pop(canEdit ? 'edit' : null),
                ),
                const SizedBox(height: 8),
                _MessageActionTile(
                  icon: Icons.undo_rounded,
                  label: 'Unsend message',
                  color: U.red,
                  onTap: () => Navigator.of(context).pop('unsend'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'edit') {
      final parsedEmojis = ChatEmojiCatalog.extractEmojis(text);
      final parsedText = ChatEmojiCatalog.stripEmojiTokens(text);
      setState(() {
        _editingMessageId = messageId;
        _replyTo = null;
        _lastError = null;
        _draftEmojis
          ..clear()
          ..addAll(parsedEmojis);
      });
      _messageController
        ..text = parsedText
        ..selection = TextSelection.collapsed(offset: parsedText.length);
      _handleComposerChanged();
      return;
    }

    if (action == 'unsend') {
      try {
        await _chatService.unsendMessage(
          otherUserId: widget.otherUserId,
          messageId: messageId,
        );
        if (mounted && _editingMessageId == messageId) {
          setState(() {
            _messageController.clear();
            _draftEmojis.clear();
            _cancelComposerMode();
          });
        }
      } catch (e) {
        if (!mounted) {
          return;
        }
        final message = e is FirebaseException
            ? (e.message ?? e.code)
            : 'Could not unsend message';
        setState(() => _lastError = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: U.red,
            content: Text(message, style: GoogleFonts.outfit(color: U.bg)),
          ),
        );
      }
    }
  }

  void _openNoteShare(Map<String, dynamic> noteShare) {
    final filePath = (noteShare['filePath'] ?? '').toString();
    if (filePath.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteViewerScreen(
          title: (noteShare['noteTitle'] ?? 'Shared note').toString(),
          filePath: filePath,
          folderPath: (noteShare['folderPath'] ?? '').toString(),
          initialSegmentId: (noteShare['segmentId'] ?? '').toString(),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    final composedText = [
      if (text.isNotEmpty) text,
      if (_draftEmojis.isNotEmpty)
        _draftEmojis.map((emoji) => emoji.token).join(' '),
    ].join(text.isNotEmpty && _draftEmojis.isNotEmpty ? ' ' : '');
    if (_sending || composedText.trim().isEmpty) {
      return;
    }

    setState(() => _sending = true);
    try {
      if (_isEditing) {
        await _chatService.editMessage(
          otherUserId: widget.otherUserId,
          messageId: _editingMessageId!,
          text: composedText,
        );
      } else {
        await _chatService.sendMessage(
          otherUserId: widget.otherUserId,
          text: composedText,
          replyTo: _replyTo,
        );
      }
      if (mounted) {
        setState(() {
          _lastError = null;
          _replyTo = null;
          _editingMessageId = null;
          _draftEmojis.clear();
        });
      }
      _typingDebounce?.cancel();
      _typingActive = false;
      unawaited(
        _chatService.setTypingState(
          otherUserId: widget.otherUserId,
          isTyping: false,
        ),
      );
      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is FirebaseException
            ? (e.message ?? e.code)
            : 'Could not send message';
        setState(() => _lastError = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: U.red,
            content: Text(message, style: GoogleFonts.outfit(color: U.bg)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final navigator = Navigator.of(context);
        final canLeave = await _handleBackNavigation();
        if (canLeave && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: U.bg,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: U.bg,
          titleSpacing: 0,
          title: StreamBuilder<Map<String, int>>(
            stream: GameChampionService.topScoreRanksStream(),
            builder: (context, scoreRanksSnapshot) {
              return StreamBuilder<Map<String, int>>(
                stream: GameChampionService.topStreakRanksStream(),
                builder: (context, streakRanksSnapshot) {
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _chatStream,
                    builder: (context, chatSnapshot) {
                      return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        stream: _otherUserStream,
                        builder: (context, userSnapshot) {
                          final chatData = chatSnapshot.data?.data();
                          final userData = userSnapshot.data?.data();
                          final isOtherTyping =
                              (chatData?['typing_${widget.otherUserId}'] ??
                                  false) ==
                              true;
                          final lastSeen = userData?['lastSeen'];
                          final scoreRank =
                              scoreRanksSnapshot.data?[widget.otherUserId];
                          final streakRank =
                              streakRanksSnapshot.data?[widget.otherUserId];
                          final isOnline =
                              lastSeen is Timestamp &&
                              DateTime.now().difference(lastSeen.toDate()) <=
                                  const Duration(minutes: 5);
                          final subtitle = isOtherTyping
                              ? 'typing...'
                              : (isOnline
                                    ? 'Online'
                                    : _lastSeenLabel(
                                        lastSeen,
                                        fallback: widget.email,
                                      ));

                          return Row(
                            children: [
                              ChampionAvatarBadge(
                                scoreRank: scoreRank,
                                streakRank: streakRank,
                                email: widget.email,
                                showGlow: false,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: U.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                  backgroundImage:
                                      widget.photoUrl != null &&
                                          widget.photoUrl!.isNotEmpty
                                      ? NetworkImage(widget.photoUrl!)
                                      : null,
                                  child:
                                      widget.photoUrl == null ||
                                          widget.photoUrl!.isEmpty
                                      ? Text(
                                          widget.displayName.isEmpty
                                              ? 'U'
                                              : widget.displayName[0]
                                                    .toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            color: U.primary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ChampionNameText(
                                      name: widget.displayName,
                                      scoreRank: scoreRank,
                                      streakRank: streakRank,
                                      email: widget.email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: U.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: isOtherTyping || isOnline
                                            ? U.primary
                                            : U.sub,
                                        fontSize: 11,
                                        fontWeight: isOtherTyping || isOnline
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        body: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            bottom: _emojiPickerOpen ? 0 : keyboardInset,
          ),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: U.primary,
                          strokeWidth: 1.6,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      final subtitle = error is FirebaseException
                          ? (error.message ?? error.code)
                          : 'Try opening this chat again.';
                      return _ChatEmptyState(
                        icon: Icons.forum_outlined,
                        title: 'Could not load messages',
                        subtitle: subtitle,
                      );
                    }

                    final messages = (snapshot.data?.docs ?? const []).where((
                      doc,
                    ) {
                      final data = doc.data();
                      return (data['deleted'] ?? false) != true;
                    }).toList();
                    if (messages.isEmpty) {
                      return const _ChatEmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No messages yet',
                        subtitle: 'Start the conversation.',
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      unawaited(_chatService.markChatRead(widget.otherUserId));
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data = messages[index].data();
                        final senderId = (data['senderId'] ?? '').toString();
                        final isMe = senderId == _currentUid;
                        final messageType = (data['type'] ?? 'text').toString();
                        final noteShare =
                            data['noteShare'] as Map<String, dynamic>?;
                        return _MessageBubble(
                          messageId: messages[index].id,
                          isMe: isMe,
                          messageType: messageType,
                          text: (data['text'] ?? '').toString(),
                          timestamp: data['timestamp'] as Timestamp?,
                          isRead: (data['read'] ?? false) == true,
                          isEdited: (data['edited'] ?? false) == true,
                          isDeleted: (data['deleted'] ?? false) == true,
                          noteShare: noteShare,
                          replyTo: data['replyTo'] as Map<String, dynamic>?,
                          avatarLetter: isMe
                              ? (FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.displayName ??
                                        'U')
                                    .characters
                                    .first
                                    .toUpperCase()
                              : (widget.displayName.isEmpty
                                    ? 'U'
                                    : widget.displayName.characters.first
                                          .toUpperCase()),
                          avatarPhotoUrl: isMe
                              ? FirebaseAuth.instance.currentUser?.photoURL
                              : widget.photoUrl,
                          onReply: () {
                            setState(() {
                              _replyTo = {
                                'messageId': messages[index].id,
                                'senderId': senderId,
                                'senderName': isMe
                                    ? (FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.displayName ??
                                          'You')
                                    : widget.displayName,
                                'text': (data['deleted'] ?? false) == true
                                    ? 'Message unsent'
                                    : messageType == 'note_share'
                                    ? 'Shared ${(noteShare?['noteTitle'] ?? 'note').toString()}'
                                    : (data['text'] ?? '').toString(),
                              };
                            });
                          },
                          onLongPress: isMe
                              ? () => _showOwnMessageActions(
                                  messageId: messages[index].id,
                                  text: (data['text'] ?? '').toString(),
                                  isDeleted: (data['deleted'] ?? false) == true,
                                  canEdit: messageType == 'text',
                                )
                              : null,
                          onOpenNoteShare: noteShare == null
                              ? null
                              : () => _openNoteShare(noteShare),
                        );
                      },
                    );
                  },
                ),
              ),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _chatStream,
                builder: (context, snapshot) {
                  final isOtherTyping =
                      (snapshot.data?.data()?['typing_${widget.otherUserId}'] ??
                          false) ==
                      true;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: isOtherTyping
                        ? Padding(
                            key: const ValueKey('typing_indicator'),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: U.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                  backgroundImage:
                                      widget.photoUrl != null &&
                                          widget.photoUrl!.isNotEmpty
                                      ? NetworkImage(widget.photoUrl!)
                                      : null,
                                  child:
                                      widget.photoUrl == null ||
                                          widget.photoUrl!.isEmpty
                                      ? Text(
                                          widget.displayName.isEmpty
                                              ? 'U'
                                              : widget.displayName[0]
                                                    .toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            color: U.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                const _TypingIndicatorBubble(),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('typing_indicator_empty'),
                          ),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                decoration: BoxDecoration(
                  color: U.bg,
                  border: Border(top: BorderSide(color: U.border, width: 0.5)),
                ),
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: U.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: U.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isEditing || _replyTo != null) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    8,
                                    6,
                                    8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: U.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: U.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: _isEditing
                                              ? U.peach
                                              : U.primary,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _isEditing
                                                  ? 'Editing message'
                                                  : (_replyTo?['senderName'] ??
                                                            'Reply')
                                                        .toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                color: _isEditing
                                                    ? U.peach
                                                    : U.primary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            if (_isEditing)
                                              Text(
                                                'Send to save changes',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.outfit(
                                                  color: U.sub,
                                                  fontSize: 12,
                                                ),
                                              )
                                            else
                                              ChatEmojiCatalog.buildInlinePreview(
                                                (_replyTo?['text'] ?? '')
                                                    .toString(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                fontSize: 12,
                                                textColor: U.sub,
                                                emojiSize: 16,
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(
                                          () => _cancelComposerMode(),
                                        ),
                                        splashRadius: 18,
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: U.sub,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_draftEmojis.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 8,
                                    top: 2,
                                  ),
                                  child: Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: List.generate(
                                      _draftEmojis.length,
                                      (index) {
                                        final emoji = _draftEmojis[index];
                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 4,
                                                top: 2,
                                              ),
                                              child: Image.asset(
                                                emoji.assetPath,
                                                width: 22,
                                                height: 22,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            Positioned(
                                              right: -2,
                                              top: -4,
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _removeDraftEmoji(index),
                                                child: Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    color: U.surface,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: U.border,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.close_rounded,
                                                    color: U.sub,
                                                    size: 11,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                              TextField(
                                focusNode: _composerFocusNode,
                                onTap: () {
                                  if (_emojiPickerOpen) {
                                    _closeEmojiPicker();
                                  }
                                },
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 5,
                                style: GoogleFonts.outfit(
                                  color: U.text,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: _isEditing
                                      ? 'Edit message'
                                      : 'Type a message',
                                  hintStyle: GoogleFonts.outfit(
                                    color: U.sub,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (_lastError != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _lastError!,
                                  style: GoogleFonts.outfit(
                                    color: U.red,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _toggleEmojiPicker,
                          splashRadius: 22,
                          icon: Icon(
                            _emojiPickerOpen
                                ? Icons.keyboard_rounded
                                : Icons.emoji_emotions_outlined,
                            color: U.primary,
                          ),
                        ),
                        IconButton(
                          onPressed: _sending ? null : _send,
                          splashRadius: 22,
                          icon: _sending
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: U.primary,
                                    strokeWidth: 1.6,
                                  ),
                                )
                              : Icon(
                                  _isEditing
                                      ? Icons.check_rounded
                                      : Icons.send_rounded,
                                  color: U.primary,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_emojiPickerOpen)
                _EmojiPickerPanel(onEmojiSelected: _insertEmoji),
            ],
          ),
        ),
      ),
    );
  }

  String _lastSeenLabel(dynamic raw, {required String fallback}) {
    if (raw is! Timestamp) {
      return fallback;
    }

    final diff = DateTime.now().difference(raw.toDate());
    if (diff.inMinutes < 1) {
      return 'Last seen just now';
    }
    if (diff.inMinutes < 60) {
      return 'Last seen ${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return 'Last seen ${diff.inHours}h ago';
    }
    return 'Last seen ${diff.inDays}d ago';
  }
}

class _EmojiPickerPanel extends StatefulWidget {
  const _EmojiPickerPanel({required this.onEmojiSelected});

  final ValueChanged<ChatEmoji> onEmojiSelected;

  @override
  State<_EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<_EmojiPickerPanel> {
  String _categoryKey = ChatEmojiCatalog.categories.first.key;

  @override
  Widget build(BuildContext context) {
    final activeCategory = ChatEmojiCatalog.categories.firstWhere(
      (category) => category.key == _categoryKey,
      orElse: () => ChatEmojiCatalog.categories.first,
    );
    final emojis = ChatEmojiCatalog.forCategory(activeCategory.key);
    return Container(
      height: 332,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: BoxDecoration(
        color: U.surface,
        border: Border(top: BorderSide(color: U.border, width: 0.5)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ChatEmojiCatalog.categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = ChatEmojiCatalog.categories[index];
                final selected = category.key == activeCategory.key;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _categoryKey = category.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? U.primary.withValues(alpha: 0.16)
                          : U.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? U.primary : U.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          category.icon,
                          size: 18,
                          color: selected ? U.primary : U.sub,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category.label,
                          style: GoogleFonts.outfit(
                            color: selected ? U.primary : U.sub,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              itemCount: emojis.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final emoji = emojis[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => widget.onEmojiSelected(emoji),
                  child: Container(
                    decoration: BoxDecoration(
                      color: U.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: U.border),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          emoji.assetPath,
                          width: 26,
                          height: 26,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.messageId,
    required this.isMe,
    required this.messageType,
    required this.text,
    required this.timestamp,
    required this.isRead,
    required this.isEdited,
    required this.isDeleted,
    required this.avatarLetter,
    required this.onReply,
    this.onLongPress,
    this.onOpenNoteShare,
    this.noteShare,
    this.avatarPhotoUrl,
    this.replyTo,
  });

  final String messageId;
  final bool isMe;
  final String messageType;
  final String text;
  final Timestamp? timestamp;
  final bool isRead;
  final bool isEdited;
  final bool isDeleted;
  final String avatarLetter;
  final String? avatarPhotoUrl;
  final VoidCallback onReply;
  final VoidCallback? onLongPress;
  final VoidCallback? onOpenNoteShare;
  final Map<String, dynamic>? noteShare;
  final Map<String, dynamic>? replyTo;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  static const double _maxSwipeOffset = 34;
  static const double _replyTriggerOffset = 22;
  double _dragOffset = 0;

  bool get _isMe => widget.isMe;

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.isDeleted) {
      return;
    }
    final delta = details.primaryDelta ?? 0;
    final nextOffset = (_dragOffset + delta)
        .clamp(_isMe ? -_maxSwipeOffset : 0, _isMe ? 0 : _maxSwipeOffset)
        .toDouble();
    if (nextOffset != _dragOffset) {
      setState(() => _dragOffset = nextOffset);
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (widget.isDeleted) {
      if (_dragOffset != 0) {
        setState(() => _dragOffset = 0);
      }
      return;
    }
    final triggered = _isMe
        ? _dragOffset <= -_replyTriggerOffset
        : _dragOffset >= _replyTriggerOffset;
    if (triggered) {
      widget.onReply();
    }
    if (_dragOffset != 0) {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = _isMe
        ? Color.alphaBlend(U.primary.withValues(alpha: 0.14), U.card)
        : U.card;
    final singleEmojiAssetPath = _singleEmojiAssetPath();
    final avatar = CircleAvatar(
      radius: 14,
      backgroundColor: _isMe ? U.primary.withValues(alpha: 0.18) : U.border,
      backgroundImage:
          widget.avatarPhotoUrl != null && widget.avatarPhotoUrl!.isNotEmpty
          ? NetworkImage(widget.avatarPhotoUrl!)
          : null,
      child: widget.avatarPhotoUrl == null || widget.avatarPhotoUrl!.isEmpty
          ? Text(
              widget.avatarLetter,
              style: GoogleFonts.outfit(
                color: _isMe ? U.primary : U.text,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        children: [
          Positioned.fill(
            child: _ReplySwipeBackground(
              isMe: _isMe,
              progress: (_dragOffset.abs() / _maxSwipeOffset).clamp(0, 1),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: widget.onLongPress,
              onHorizontalDragUpdate: _handleHorizontalDragUpdate,
              onHorizontalDragEnd: _handleHorizontalDragEnd,
              child: Row(
                mainAxisAlignment: _isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!_isMe) ...[avatar, const SizedBox(width: 8)],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: _isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (singleEmojiAssetPath != null &&
                            widget.replyTo == null &&
                            widget.messageType == 'text')
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 2,
                            ),
                            child: Image.asset(
                              singleEmojiAssetPath,
                              width: 42,
                              height: 42,
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.replyTo != null) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      8,
                                      10,
                                      8,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: U.surface.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: U.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (widget.replyTo?['senderName'] ??
                                                  'Reply')
                                              .toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            color: U.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        ChatEmojiCatalog.buildInlinePreview(
                                          (widget.replyTo?['text'] ?? '')
                                              .toString(),
                                          fontSize: 12,
                                          textColor: U.sub,
                                          emojiSize: 16,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                _buildMessageContent(),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isEdited && !widget.isDeleted) ...[
                              Text(
                                'edited',
                                style: GoogleFonts.outfit(
                                  color: U.sub,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _formatTime(widget.timestamp),
                              style: GoogleFonts.outfit(
                                color: U.sub,
                                fontSize: 11,
                              ),
                            ),
                            if (_isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                widget.isRead
                                    ? Icons.done_all_rounded
                                    : Icons.done_rounded,
                                size: 15,
                                color: widget.isRead ? U.primary : U.sub,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_isMe) ...[const SizedBox(width: 8), avatar],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp? raw) {
    if (raw == null) {
      return 'Sending...';
    }
    final date = raw.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final meridiem = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $meridiem';
  }

  Widget _buildMessageContent() {
    if (widget.isDeleted) {
      return Text(
        'Message unsent',
        style: GoogleFonts.outfit(
          color: U.sub,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    if (widget.messageType == 'note_share' && widget.noteShare != null) {
      return _NoteShareCard(
        noteShare: widget.noteShare!,
        onTap: widget.onOpenNoteShare,
      );
    }
    return ChatEmojiCatalog.buildInlinePreview(
      widget.text,
      fontSize: 14,
      textColor: U.text,
      emojiSize: 16,
    );
  }

  String? _singleEmojiAssetPath() {
    if (widget.isDeleted || widget.messageType != 'text') {
      return null;
    }
    return ChatEmojiCatalog.singleEmojiAssetPath(widget.text);
  }
}

class _NoteShareCard extends StatelessWidget {
  const _NoteShareCard({required this.noteShare, this.onTap});

  final Map<String, dynamic> noteShare;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final noteTitle = (noteShare['noteTitle'] ?? 'Shared note').toString();
    final preview = (noteShare['segmentPreview'] ?? '').toString();
    final segmentType = (noteShare['segmentType'] ?? 'section').toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: U.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: U.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: U.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.notes_rounded, color: U.primary, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noteTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Shared ${segmentType.replaceAll('_', ' ')}',
                        style: GoogleFonts.outfit(
                          color: U.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.open_in_new_rounded, size: 16, color: U.sub),
              ],
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: U.sub,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageActionTile extends StatelessWidget {
  const _MessageActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: U.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplySwipeBackground extends StatelessWidget {
  const _ReplySwipeBackground({required this.isMe, required this.progress});

  final bool isMe;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: 0.9 + (progress * 0.12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: U.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: U.primary.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.reply_rounded, color: U.primary, size: 18),
          ),
        ),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: U.dim),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatefulWidget {
  const _TypingIndicatorBubble();

  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: U.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final progress = (_controller.value + (index * 0.18)) % 1.0;
                final emphasized = Curves.easeInOutCubicEmphasized.transform(
                  progress < 0.5 ? progress * 2 : (1 - progress) * 2,
                );
                final scale = 0.72 + (emphasized * 0.45);
                final opacity = 0.35 + (emphasized * 0.65);
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: U.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
