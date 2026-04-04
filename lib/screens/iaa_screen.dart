// UTOPIA - iaa_screen.dart - Full-screen chat UI for the IAA assistant
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart' show U;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ai_service.dart';
import '../services/attendance_service.dart';
import '../services/cache_service.dart';
import '../services/github_service.dart';
import '../services/secure_storage_service.dart';
import '../services/writer_github_service.dart';

class IAAScreen extends StatefulWidget {
  const IAAScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const IAAScreen());
  }

  @override
  State<IAAScreen> createState() => _IAAScreenState();
}

class _IAAScreenState extends State<IAAScreen> {
  Color get _backgroundColor => U.bg;
  Color get _surfaceColor => U.surface;
  Color get _surfaceElevatedColor => U.card;
  Color get _primaryColor => U.primary;
  Color get _secondaryGlowColor => U.primary.withValues(alpha: 0.8);
  Color get _accentMintColor => U.teal;
  Color get _textPrimaryColor => U.text;
  Color get _textMutedColor => U.sub;
  Color get _errorColor => U.red;
  static const List<String> _suggestions = <String>[
    'What classes today?',
    'Attendance risk?',
    'Summarise BEEE notes',
    'Classes I can skip?',
    'What to study tonight?',
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  bool _isLoading = false;
  bool _initialized = false;
  String? _initErrorMessage;
  String? _timetableJsonCache;
  String? _attendanceSummaryCache;
  List<String>? _notesTitlesCache;
  Timer? _typingTimer;
  int _typingStep = 0;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    try {
      await AIService.initialize();
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _initErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _initialized = false;
        _initErrorMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _errorColor,
          content: Text(
            message,
            style: GoogleFonts.outfit(color: _backgroundColor),
          ),
        ),
      );
    }
  }

  Future<void> _sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty || _isLoading || !_initialized) {
      return;
    }

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: trimmedText, isUser: true));
      _isLoading = true;
    });
    _startTypingIndicator();
    _scrollToBottom();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final contextPayload = await _buildIAAContext(trimmedText);
      final reply = await AIService.sendMessage(
        userMessage: trimmedText,
        timetableJson: contextPayload.timetableJson,
        attendanceSummary: contextPayload.attendanceSummary,
        notesTitles: contextPayload.notesTitles,
        notesContext: contextPayload.notesContext,
        userName: user?.displayName,
      );

      if (!mounted) {
        return;
      }
      _stopTypingIndicator();
      setState(() {
        _messages.add(_ChatMessage(text: reply, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Exception: ', '');
      _stopTypingIndicator();
      setState(() {
        _messages.add(_ChatMessage(text: message, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<_IAAContextPayload> _buildIAAContext(String userMessage) async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _getTimetableJson(),
      _getAttendanceSummary(),
      _getNotesTitles(),
      _getNotesContext(userMessage),
    ]);

    return _IAAContextPayload(
      timetableJson: results[0] as String?,
      attendanceSummary: results[1] as String?,
      notesTitles: results[2] as List<String>?,
      notesContext: results[3] as String?,
    );
  }

  Future<String?> _getTimetableJson() async {
    if (_timetableJsonCache != null) {
      return _timetableJsonCache;
    }

    try {
      final data = await WriterGitHubService.fetchRawJson('timetable.json');
      final rawJson = jsonEncode(data);
      _timetableJsonCache = rawJson;
      return rawJson;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getAttendanceSummary() async {
    if (_attendanceSummaryCache != null) {
      return _attendanceSummaryCache;
    }

    try {
      final credentials = await SecureStorageService.getCredentials();
      if (credentials == null) {
        return null;
      }

      final attendance = await AttendanceService.fetchAttendance(
        credentials['rollNumber'] ?? '',
        credentials['password'] ?? '',
      );
      final subjects = (attendance['subjects'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (subjects.isEmpty) {
        return null;
      }

      final lines = subjects.map((subject) {
        final name = (subject['subject'] ?? 'Subject').toString();
        final attended = (subject['attendedClasses'] as num?)?.toInt() ?? 0;
        final total = (subject['totalClasses'] as num?)?.toInt() ?? 0;
        final percentage = (subject['percentage'] as num?)?.toDouble() ?? 0;
        final note = percentage >= 75
            ? 'Safe.'
            : 'Need ${_classesNeededToRecover(attended, total)} more to reach 75%.';
        return '$name: ${percentage.toStringAsFixed(1)}% '
            '($attended/$total classes). $note';
      }).toList();

      _attendanceSummaryCache = lines.join('\n');
      return _attendanceSummaryCache;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>?> _getNotesTitles() async {
    if (_notesTitlesCache != null) {
      return _notesTitlesCache;
    }

    try {
      final files = await CacheService().getAllFiles();
      if (files.isEmpty) {
        return null;
      }

      _notesTitlesCache = files
          .map((file) {
            final folderPath = (file['folder_path'] ?? '').toString();
            final subject = folderPath
                .split('/')
                .last
                .replaceAll('-', ' ')
                .trim();
            final name = (file['name'] ?? '').toString().trim();
            if (subject.isEmpty) {
              return name;
            }
            return '$subject: $name';
          })
          .where((title) => title.isNotEmpty)
          .take(150)
          .toList();
      return _notesTitlesCache;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getNotesContext(String userMessage) async {
    try {
      final files = await CacheService().getAllFiles();
      if (files.isEmpty) {
        return null;
      }

      final matches =
          files
              .map((file) => _ScoredNoteMatch.fromMessage(userMessage, file))
              .where((match) => match.score > 0)
              .toList()
            ..sort((a, b) => b.score.compareTo(a.score));

      if (matches.isEmpty) {
        return null;
      }

      final githubService = GitHubService();
      final excerpts = <String>[];

      for (final match in matches.take(3)) {
        final content = await githubService.getFileContent(match.path);
        final trimmed = content.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        excerpts.add(
          'Subject: ${match.subject}\n'
          'Title: ${match.title}\n'
          'Excerpt:\n${_bestExcerpt(trimmed, userMessage)}',
        );
      }

      if (excerpts.isEmpty) {
        return null;
      }

      return excerpts.join('\n\n---\n\n');
    } catch (_) {
      return null;
    }
  }

  String _bestExcerpt(String content, String query) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 1800) {
      return normalized;
    }

    final lowerContent = normalized.toLowerCase();
    final tokens = _tokenize(query);
    for (final token in tokens) {
      final index = lowerContent.indexOf(token);
      if (index != -1) {
        final start = index > 500 ? index - 500 : 0;
        final end = (start + 1800).clamp(0, normalized.length);
        return normalized.substring(start, end).trim();
      }
    }

    return normalized.substring(0, 1800).trim();
  }

  List<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .toList();
  }

  int _classesNeededToRecover(int attended, int held) {
    if (held <= 0) {
      return 0;
    }
    final needed = ((0.75 * held) - attended) / (1 - 0.75);
    return needed.ceil().clamp(0, 9999);
  }

  void _clearChat() {
    AIService.clearHistory();
    _stopTypingIndicator();
    setState(() {
      _messages.clear();
      _isLoading = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _startTypingIndicator() {
    _typingTimer?.cancel();
    _typingStep = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted || !_isLoading) {
        return;
      }
      setState(() => _typingStep = (_typingStep + 1) % 3);
    });
  }

  void _stopTypingIndicator() {
    _typingTimer?.cancel();
    _typingTimer = null;
    _typingStep = 0;
  }

  @override
  void dispose() {
    _stopTypingIndicator();
    AIService.clearHistory();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [U.primary.withValues(alpha: 0.3), U.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: U.primary.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(Icons.auto_awesome_rounded, color: U.bg, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IAA',
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Intelligent Academic Assistant',
                  style: GoogleFonts.outfit(
                    color: U.sub,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _clearChat,
            tooltip: 'Clear chat',
            icon: Icon(Icons.refresh_rounded, color: U.primary),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned(
              top: 14,
              left: -20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      U.primary.withValues(alpha: 0.22),
                      _backgroundColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 110,
              right: -36,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      U.teal.withValues(alpha: 0.09),
                      _backgroundColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: _initErrorMessage != null
                      ? _buildErrorState(textTheme)
                      : !_initialized
                      ? _buildLoadingState(textTheme)
                      : Column(
                          children: [
                            if (_messages.isEmpty) _buildWelcomePanel(),
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  _messages.isEmpty ? 18 : 12,
                                  16,
                                  20,
                                ),
                                itemCount:
                                    _messages.length + (_isLoading ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _messages.length) {
                                    return _TypingBubble(
                                      text:
                                          'IAA is thinking${'.' * (_typingStep + 1)}',
                                    );
                                  }
                                  final message = _messages[index];
                                  return _AnimatedMessageBubble(
                                    message: message,
                                    index: index,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
                _buildComposer(textTheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [U.bg, U.primary.withValues(alpha: 0.18), U.bg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: U.border.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: U.primary.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Study smarter',
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ask better. Learn faster.',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'IAA can read your timetable, attendance context, and notes to answer with better academic guidance.',
                  style: GoogleFonts.outfit(
                    color: U.sub,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return _SuggestionCard(
                  label: suggestion,
                  onTap: () => _sendMessage(suggestion),
                  primaryColor: U.primary,
                  accentMintColor: U.teal,
                  textPrimaryColor: U.text,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      U.primary.withValues(alpha: 0.22),
                      U.teal.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: U.primary,
                      strokeWidth: 2.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Connecting to IAA...',
                style: textTheme.titleMedium?.copyWith(
                  color: U.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Preparing your academic context and assistant session.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: U.sub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: _errorColor, size: 34),
            const SizedBox(height: 16),
            Text(
              'IAA is unavailable right now',
              style: textTheme.titleMedium?.copyWith(
                color: U.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _initErrorMessage ?? 'Could not connect to IAA.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: U.sub),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _initializeAI,
              style: FilledButton.styleFrom(
                backgroundColor: U.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: _surfaceColor.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: U.card)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    U.card.withValues(alpha: 0.94),
                    const Color(0xFF26283B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: TextField(
                controller: _controller,
                enabled: _initialized && !_isLoading,
                minLines: 1,
                maxLines: 5,
                style: textTheme.bodyLarge?.copyWith(color: U.text),
                decoration: InputDecoration(
                  hintText:
                      'Ask about classes, notes, attendance, or study plans...',
                  hintStyle: textTheme.bodyMedium?.copyWith(color: U.sub),
                  filled: true,
                  fillColor: Colors.transparent,
                  prefixIcon: Icon(Icons.bolt_rounded, color: U.teal, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: U.primary),
                  ),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _initialized && !_isLoading
                    ? const [Color(0xFF7F77DD), Color(0xFF9C90FF)]
                    : [
                        U.card.withValues(alpha: 0.8),
                        U.card.withValues(alpha: 0.8),
                      ],
              ),
              shape: BoxShape.circle,
              boxShadow: _initialized && !_isLoading
                  ? [
                      BoxShadow(
                        color: U.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              onPressed: _initialized && !_isLoading
                  ? () => _sendMessage(_controller.text)
                  : null,
              icon: Icon(
                _isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.north_east_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IAAContextPayload {
  const _IAAContextPayload({
    this.timetableJson,
    this.attendanceSummary,
    this.notesTitles,
    this.notesContext,
  });

  final String? timetableJson;
  final String? attendanceSummary;
  final List<String>? notesTitles;
  final String? notesContext;
}

class _ScoredNoteMatch {
  const _ScoredNoteMatch({
    required this.path,
    required this.title,
    required this.subject,
    required this.score,
  });

  factory _ScoredNoteMatch.fromMessage(
    String message,
    Map<String, dynamic> file,
  ) {
    final title = (file['name'] ?? '').toString();
    final path = (file['path'] ?? '').toString();
    final folderPath = (file['folder_path'] ?? '').toString();
    final subject = folderPath.split('/').last.replaceAll('-', ' ').trim();
    final haystack = '$title $subject $path'.toLowerCase();
    final tokens = message
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .toSet();

    var score = 0;
    for (final token in tokens) {
      if (title.toLowerCase().contains(token)) {
        score += 5;
      }
      if (subject.toLowerCase().contains(token)) {
        score += 3;
      }
      if (haystack.contains(token)) {
        score += 1;
      }
    }

    return _ScoredNoteMatch(
      path: path,
      title: title,
      subject: subject.isEmpty ? 'General' : subject,
      score: score,
    );
  }

  final String path;
  final String title;
  final String subject;
  final int score;
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}

class _AnimatedMessageBubble extends StatefulWidget {
  const _AnimatedMessageBubble({required this.message, required this.index});

  final _ChatMessage message;
  final int index;

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: _MessageBubble(message: widget.message),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final borderRadius = message.isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          );

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width *
              (message.isUser ? 0.75 : 0.85),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            gradient: message.isUser
                ? LinearGradient(
                    colors: [
                      U.primary.withValues(alpha: 0.92),
                      const Color(0xFF5F58C9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF191B28), Color(0xFF151723)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: borderRadius,
            border: Border.all(
              color: message.isUser
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: message.isUser
                    ? U.primary.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: message.isUser
              ? Text(
                  message.text,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    height: 1.45,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : MarkdownBody(
                  data: message.text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.outfit(
                      color: U.text,
                      height: 1.45,
                      fontSize: 15,
                    ),
                    h1: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    h2: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                    h3: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    strong: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    em: GoogleFonts.outfit(
                      color: U.text,
                      fontStyle: FontStyle.italic,
                    ),
                    listBullet: GoogleFonts.outfit(color: U.text, fontSize: 15),
                    blockquote: GoogleFonts.outfit(
                      color: U.sub,
                      fontSize: 15,
                      height: 1.45,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: U.card.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: U.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    blockSpacing: 10,
                    listIndent: 20,
                    code: GoogleFonts.jetBrainsMono(
                      color: U.teal,
                      fontSize: 13.5,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: U.card.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    a: GoogleFonts.outfit(
                      color: U.teal,
                      decoration: TextDecoration.underline,
                    ),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: U.card.withValues(alpha: 0.9)),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _MessageBubble(message: _ChatMessage(text: text, isUser: false));
  }
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({
    required this.label,
    required this.onTap,
    required this.primaryColor,
    required this.accentMintColor,
    required this.textPrimaryColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color accentMintColor;
  final Color textPrimaryColor;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  late Animation<double> _iconBounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _shadowAnimation = Tween<double>(
      begin: 8.0,
      end: 4.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _iconBounce = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 148,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF171A25),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _controller.isAnimating
                      ? widget.primaryColor.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: Offset(0, _shadowAnimation.value),
                  ),
                  if (_controller.isAnimating)
                    BoxShadow(
                      color: widget.primaryColor.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.scale(
                    scale: _controller.isAnimating ? _iconBounce.value : 1.0,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF252A3B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: widget.accentMintColor,
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: widget.textPrimaryColor,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
