import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../main.dart';
import '../services/ai_service.dart';

class AnswerViewerScreen extends StatefulWidget {
  final String question;
  final String answer;
  final String filePath;
  final bool useGlobalRepo;
  final int? questionNumber;

  const AnswerViewerScreen({
    super.key,
    required this.question,
    required this.answer,
    required this.filePath,
    this.useGlobalRepo = false,
    this.questionNumber,
  });

  @override
  State<AnswerViewerScreen> createState() => _AnswerViewerScreenState();
}

class _AnswerViewerScreenState extends State<AnswerViewerScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _lunaAIAnswer;
  bool _isLoadingAI = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && _lunaAIAnswer == null && !_isLoadingAI && _aiError == null) {
      _fetchLunaAIAnswer();
    }
  }

  Future<void> _fetchLunaAIAnswer() async {
    setState(() {
      _isLoadingAI = true;
      _aiError = null;
    });

    try {
      final prompt = 'Explain this concept/answer in direct, neat, simple language (8M style direct answer, no fluff, concise ELIF5-style explanation, clear formatting):\n\nQuestion: "${widget.question}"\n\nOriginal Answer Context: "${widget.answer}"';
      final response = await AIService.sendMessage(userMessage: prompt);

      if (mounted) {
        setState(() {
          _lunaAIAnswer = response;
          _isLoadingAI = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = e.toString().replaceFirst('Exception: ', '').trim();
          _isLoadingAI = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appThemeNotifier.value.isDark;

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.surface,
        foregroundColor: U.text,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.sub, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Answer View',
          style: GoogleFonts.outfit(
            color: U.text,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Beautiful Question Card ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: U.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: U.primary.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: U.primary.withValues(alpha: isDark ? 0.05 : 0.02),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: U.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.quiz_outlined, color: U.primary, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              widget.questionNumber != null ? 'QUESTION #${widget.questionNumber}' : 'QUESTION',
                              style: GoogleFonts.outfit(
                                color: U.primary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.question,
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            // ── Sleek Custom Tab Selector ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              height: 46,
              decoration: BoxDecoration(
                color: U.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: U.border, width: 0.5),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [U.primary, U.primary.withValues(alpha: 0.85)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: U.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: U.sub,
                labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                padding: const EdgeInsets.all(4),
                tabs: [
                  const Tab(text: 'Standard Answer'),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 14),
                        const SizedBox(width: 6),
                        const Text('Luna AI Answer'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Tab View Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStandardTab(),
                  _buildAITab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardTab() {
    return _buildMarkdownContent(widget.answer);
  }

  Widget _buildAITab() {
    if (_isLoadingAI) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: U.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: U.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Luna is processing study guide... ✨',
              style: GoogleFonts.outfit(
                color: U.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_aiError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: U.red, size: 36),
              const SizedBox(height: 12),
              Text(
                _aiError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchLunaAIAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: U.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Retry', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    if (_lunaAIAnswer == null) {
      return const SizedBox.shrink();
    }

    return _buildMarkdownContent(_lunaAIAnswer!);
  }

  Widget _buildMarkdownContent(String markdownContent) {
    if (markdownContent.trim().isEmpty) {
      return Center(
        child: Text(
          'No answer content is available yet.',
          style: GoogleFonts.outfit(color: U.dim, fontSize: 13),
        ),
      );
    }

    // Custom inline math processing
    final segments = _parseMathSegments(markdownContent);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        if (segment.isMath) {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Math.tex(
                segment.text,
                textStyle: TextStyle(color: U.text, fontSize: 15),
                onErrorFallback: (e) => Text(
                  '\$\$${segment.text}\$\$',
                  style: GoogleFonts.sourceCodePro(color: U.red, fontSize: 13),
                ),
              ),
            ),
          );
        }

        // Regular Markdown
        return MarkdownBody(
          data: segment.text,
          styleSheet: MarkdownStyleSheet(
            h1: GoogleFonts.outfit(color: U.mdH1, fontSize: 20, fontWeight: FontWeight.w700),
            h2: GoogleFonts.outfit(color: U.mdH2, fontSize: 17, fontWeight: FontWeight.w600),
            h3: GoogleFonts.outfit(color: U.mdH3, fontSize: 15, fontWeight: FontWeight.w600),
            p: GoogleFonts.outfit(color: U.text, fontSize: 14.5, height: 1.7),
            strong: GoogleFonts.outfit(color: U.mdBold, fontWeight: FontWeight.w700, fontSize: 14.5),
            em: GoogleFonts.outfit(color: U.mdItalic, fontStyle: FontStyle.italic, fontSize: 14.5),
            code: GoogleFonts.sourceCodePro(color: U.mdCode, backgroundColor: U.card, fontSize: 12.5),
            codeblockDecoration: BoxDecoration(
              color: U.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: U.border),
            ),
            codeblockPadding: const EdgeInsets.all(12),
            blockquote: GoogleFonts.outfit(color: U.sub, fontSize: 13.5),
            blockquoteDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: U.mdBlockquote, width: 3)),
            ),
            blockquotePadding: const EdgeInsets.only(left: 10),
            listBullet: GoogleFonts.outfit(color: U.sub, fontSize: 14.5),
          ),
        );
      },
    );
  }

  List<_MathSegment> _parseMathSegments(String text) {
    final segments = <_MathSegment>[];
    final pattern = RegExp(r'\$\$(.*?)\$\$', dotAll: true);
    int lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        final plainText = text.substring(lastIndex, match.start);
        if (plainText.trim().isNotEmpty) {
          segments.add(_MathSegment(plainText, false));
        }
      }
      segments.add(_MathSegment(match.group(1)!, true));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final plainText = text.substring(lastIndex);
      if (plainText.trim().isNotEmpty) {
        segments.add(_MathSegment(plainText, false));
      }
    }

    return segments;
  }
}

class _MathSegment {
  final String text;
  final bool isMath;
  _MathSegment(this.text, this.isMath);
}

