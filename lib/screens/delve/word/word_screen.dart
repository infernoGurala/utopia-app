import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/delve_theme_provider.dart';
import '../../../providers/delve_deck_provider.dart';
import '../../../providers/delve_session_provider.dart';
import '../../../providers/delve_inventory_provider.dart';
import '../../../models/delve_deck_model.dart';
import '../../../models/delve_session_model.dart';
import 'day_indicator.dart';
import 'swipe_card.dart';
import 'active_card.dart';
import 'fan_out_intro.dart';
import '../../../models/delve_word_model.dart';

class WordScreen extends StatelessWidget {
  const WordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final isWaiting = deckProvider.activeDeck == null;

    return SafeArea(
      child: isWaiting
          ? const _WaitingState()
          : const _ActiveDeckState(),
    );
  }
}

// =============================================================================
// WAITING STATE — No active deck, need ≥15 words
// =============================================================================

class _WaitingState extends StatelessWidget {
  const _WaitingState();

  @override
  Widget build(BuildContext context) {
    final theme = context.read<DelveThemeProvider>().currentTheme;
    final inventory = context.watch<InventoryProvider>();
    final canStart = inventory.inventory.length >= 15;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24), // Soft round square
              child: Image.asset(
                theme.isDark ? 'logos/white.png' : 'logos/black.png',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.eco_rounded,
                  size: 80,
                  color: theme.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            canStart ? 'Ready to begin.' : 'Add more words\nto begin your next deck.',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: theme.text,
              fontSize: 28,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${inventory.inventory.length} words in inventory',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: theme.textSecondary,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
          if (!canStart) ...[
            const SizedBox(height: 8),
            Text(
              '${15 - inventory.inventory.length} more needed',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.accent.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
          const Spacer(),
          if (canStart)
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  context.read<DeckProvider>().createDeckFromWords(
                        inventory.getRandomWords(15),
                      );
                },
                child: Text(
                  'Begin New Deck',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.accent.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => context.read<InventoryProvider>().loadStarterDeck(),
                icon: Icon(Icons.auto_awesome_motion_rounded, color: theme.accent, size: 20),
                label: Text(
                  'Load Starter Deck',
                  style: GoogleFonts.inter(
                    color: theme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 100), // Space for bottom nav
        ],
      ),
    );
  }
}

// =============================================================================
// ACTIVE DECK STATE — Routes to the correct sub-state
// =============================================================================

class _ActiveDeckState extends StatelessWidget {
  const _ActiveDeckState();

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final deck = context.watch<DeckProvider>().activeDeck!;

    // 1. Today's session already completed → show completion message
    if (deck.isSessionCompletedToday) {
      if (deck.currentDay == 13) {
        // Test day completed — show results
        return _TestDayResults(session: sessionProvider.currentSession);
      }
      return _SessionCompleteState(day: deck.currentDay);
    }

    // 2. Session exists and is in progress → continue it
    if (sessionProvider.currentSession != null &&
        sessionProvider.currentSession!.day == deck.currentDay &&
        sessionProvider.currentSession!.status == SessionStatus.inProgress) {
      return _InSessionState(
        session: sessionProvider.currentSession!,
        deck: deck,
      );
    }

    // 3. No session yet today → show "Begin Session" screen
    return _BeginSessionState(deck: deck);
  }
}

// =============================================================================
// BEGIN SESSION — "Begin Today's Session" button
// =============================================================================

class _BeginSessionState extends StatelessWidget {
  final Deck deck;
  const _BeginSessionState({required this.deck});

  @override
  Widget build(BuildContext context) {
    final theme = context.read<DelveThemeProvider>().currentTheme;
    final isTestDay = deck.currentDay == 13;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Day indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              isTestDay ? 'Test Day' : 'Day ${deck.currentDay} of 13',
              style: GoogleFonts.inter(
                color: theme.accent,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            isTestDay ? 'Prove what\nyou know.' : 'Your words\nare waiting.',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: theme.text,
              fontSize: 36,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            isTestDay
                ? 'All 15 words. AI-validated.'
                : '5 cards to review. 2 to prove.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: theme.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),

          const Spacer(flex: 2),

          // Begin button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                final archiveIds = context.read<InventoryProvider>().archive.map((w) => w.id).toList();
                context
                    .read<SessionProvider>()
                    .startSession(deck, const Uuid().v4(), archiveIds);
              },
              child: Text(
                isTestDay ? 'Begin Test' : 'Begin Session',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// =============================================================================
// IN SESSION — Active card display with progress
// =============================================================================

class _InSessionState extends StatefulWidget {
  final Session session;
  final Deck deck;

  const _InSessionState({required this.session, required this.deck});

  @override
  State<_InSessionState> createState() => _InSessionStateState();
}

class _InSessionStateState extends State<_InSessionState> {
  bool _showIntro = false;

  @override
  void initState() {
    super.initState();
    // Only show intro if no cards have been completed yet in this session
    if (widget.session.completedCards == 0) {
      _showIntro = true;
    }
  }

  void _completeCard(ActiveCardResult result) {
    final sessionProvider = context.read<SessionProvider>();
    sessionProvider.completeCurrentCard(result);

    final session = sessionProvider.currentSession;
    if (session != null && session.status == SessionStatus.completed) {
      final deck = context.read<DeckProvider>().activeDeck;
      if (deck != null) {
        _processSessionCompletion(context, deck, sessionProvider);
      }
    }
  }

  void _processSessionCompletion(
    BuildContext context,
    Deck deck,
    SessionProvider sessionProvider,
  ) {
    final deckProvider = context.read<DeckProvider>();
    final inventoryProvider = context.read<InventoryProvider>();

    if (deck.currentDay == 13) {
      // Test Day: process pass/fail for all 15 words
      final results = sessionProvider.getSessionResults();
      for (final wordId in results['passed']!) {
        inventoryProvider.archiveWord(wordId);
      }
      for (final wordId in results['failed']!) {
        final word = inventoryProvider.getWordById(wordId);
        if (word != null) {
          inventoryProvider.updateWord(
            word.copyWith(failCount: word.failCount + 1),
          );
        }
      }
    } else {
      // Days 1-12: process the 2 archive active cards
      final results = sessionProvider.getSessionResults();
      for (final wordId in results['failed']!) {
        final word = inventoryProvider.getWordById(wordId);
        if (word != null) {
          // Move from archive back to inventory
          inventoryProvider.restoreWords([wordId]);
          // And increment failCount
          inventoryProvider.updateWord(
            word.copyWith(
              archivedAt: null,
              failCount: word.failCount + 1,
            ),
          );
        }
      }
    }

    // Mark session date on the deck
    deckProvider.markSessionCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DelveThemeProvider>().currentTheme;
    final sessionProvider = context.watch<SessionProvider>();
    
    // Find the first non-completed card
    final currentCardIndex = widget.session.cards.indexWhere((c) => !c.isCompleted);
    
    if (currentCardIndex == -1) {
      return const SizedBox();
    }
    
    // Safety check for index out of bounds
    if (currentCardIndex >= widget.session.cards.length) return const SizedBox();

    final currentSessionCard = widget.session.cards[currentCardIndex];
    final word = context.read<InventoryProvider>().getWordById(
      currentSessionCard.wordId,
    );

    if (word == null && currentSessionCard.wordId != 'empty_archive') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sessionProvider.completeCurrentCard(ActiveCardResult.passed);
      });
      return const Center(child: CircularProgressIndicator());
    }

    if (_showIntro) {
      final inventory = context.read<InventoryProvider>();
      final introWords = widget.session.cards
          .map((c) => inventory.getWordById(c.wordId))
          .whereType<Word>()
          .toList();

      return FanOutIntro(
        words: introWords,
        onComplete: () {
          setState(() {
            _showIntro = false;
          });
        },
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 48.0),
              child: DayIndicator(
                day: widget.session.day,
                totalCards: widget.session.cards.length,
                completedCards: widget.session.completedCards,
              ),
            ),
            Expanded(
              child: Center(
                child: currentSessionCard.type == CardType.swipe
                    ? SwipeCard(
                        key: ValueKey('${widget.session.id}_$currentCardIndex'),
                        word: word!,
                        onComplete: () => _completeCard(ActiveCardResult.passed),
                        onDismissed: () => _completeCard(ActiveCardResult.passed),
                      )
                    : currentSessionCard.wordId == 'empty_archive'
                        ? _buildEmptyArchiveCard(context, sessionProvider, theme)
                        : ActiveCard(
                            key: ValueKey('${widget.session.id}_$currentCardIndex'),
                            word: word!,
                            onSubmit: (pass) => _completeCard(
                              pass ? ActiveCardResult.passed : ActiveCardResult.failed,
                            ),
                          ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 120),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyArchiveCard(BuildContext context, SessionProvider provider, dynamic theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.archive_outlined, size: 64, color: theme.textSecondary),
          const SizedBox(height: 24),
          Text(
            'Archive Empty',
            style: TextStyle(
              color: theme.text,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'There are no words in your archive yet to evaluate.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              _completeCard(ActiveCardResult.passed);
            },
            child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// =================================================================================================
// SESSION COMPLETE — Day 1-12 finished
// =============================================================================

class _SessionCompleteState extends StatelessWidget {
  final int day;
  const _SessionCompleteState({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = context.read<DelveThemeProvider>().currentTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Checkmark
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.accent.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.check_rounded,
                color: theme.accent,
                size: 36,
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'Done for today.',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                color: theme.text,
                fontSize: 32,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              day < 12
                  ? 'Return tomorrow for Day ${day + 1}.'
                  : 'Tomorrow is Test Day.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.textSecondary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            
            // Start Over Button
            OutlinedButton.icon(
              onPressed: () => _showConfirmDialog(
                context,
                title: 'Start Over?',
                content: 'You will be able to retake today\'s words immediately. Your progress for today will be cleared.',
                confirmLabel: 'Start Over',
                onConfirm: () {
                  context.read<DeckProvider>().resetTodaysSession();
                  context.read<SessionProvider>().endSession();
                },
              ),
              icon: Icon(Icons.refresh_rounded, size: 18, color: theme.accent),
              label: Text(
                'Start over today\'s session',
                style: GoogleFonts.inter(
                  color: theme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.accent.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    final theme = context.read<DelveThemeProvider>().currentTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          title,
          style: GoogleFonts.marcellus(
            color: theme.text,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          content,
          style: GoogleFonts.inter(
            color: theme.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: theme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.isDark ? Colors.white : Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              confirmLabel,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TEST DAY RESULTS — Day 13 finished, show pass/fail breakdown
// =============================================================================

class _TestDayResults extends StatelessWidget {
  final Session? session;
  const _TestDayResults({this.session});

  @override
  Widget build(BuildContext context) {
    final theme = context.read<DelveThemeProvider>().currentTheme;
    final inventoryProvider = context.read<InventoryProvider>();

    // Count results from the session
    int passedCount = 0;
    int failedCount = 0;
    List<String> passedWords = [];
    List<String> failedWords = [];

    if (session != null) {
      for (final card in session!.cards) {
        final word = inventoryProvider.getWordById(card.wordId);
        final wordText = word?.word ?? '???';
        if (card.result == ActiveCardResult.passed) {
          passedCount++;
          passedWords.add(wordText);
        } else {
          failedCount++;
          failedWords.add(wordText);
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(),

          Text(
            'Deck Complete.',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: theme.text,
              fontSize: 32,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _ResultBox(
                  count: passedCount,
                  label: 'Archived',
                  color: const Color(0xFF2DD4A0),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ResultBox(
                  count: failedCount,
                  label: 'Returned',
                  color: const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Word lists
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (passedWords.isNotEmpty) ...[
                    Text(
                      'Learned',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF2DD4A0),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: passedWords
                          .map((w) => _WordChip(word: w, passed: true))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (failedWords.isNotEmpty) ...[
                    Text(
                      'Back to inventory',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF6B6B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: failedWords
                          .map((w) => _WordChip(word: w, passed: false))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Finish button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                final deckProvider = context.read<DeckProvider>();
                final sessionProvider = context.read<SessionProvider>();
                deckProvider.completeDeck();
                sessionProvider.endSession();
              },
              child: Text(
                'Continue',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 100),
        ],
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _ResultBox({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<DelveThemeProvider>().currentTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 36,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: theme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  final bool passed;

  const _WordChip({required this.word, required this.passed});

  @override
  Widget build(BuildContext context) {
    final color = passed ? const Color(0xFF2DD4A0) : const Color(0xFFFF6B6B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        word,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
