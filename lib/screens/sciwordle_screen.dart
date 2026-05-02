import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../main.dart';
import '../models/sciwordle_model.dart';
import '../services/sciwordle_service.dart';
import 'sciwordle_leaderboard.dart';
import 'sciwordle_stats_screen.dart';
import 'how_to_play_screen.dart';

class SciwordleScreen extends StatefulWidget {
  const SciwordleScreen({super.key});

  @override
  State<SciwordleScreen> createState() => _SciwordleScreenState();
}

class _SciwordleScreenState extends State<SciwordleScreen>
    with TickerProviderStateMixin {
  static const int _maxAttempts = 6;

  final SciwordleService _service = SciwordleService();
  final FocusNode _focusNode = FocusNode();
  late ConfettiController _confettiController;

  SciwordleQuestion? _question;
  SciwordlePlayerScore? _playerScore;
  final List<SciwordleGuessResult> _guesses = [];
  String _currentGuess = '';
  bool _gameOver = false;
  bool _won = false;
  int? _pointsEarned;
  bool _alreadyPlayedToday = false;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _inputError;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _loadGame();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadGame() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.fetchTodaysQuestion(),
        _service.fetchPlayerScore(),
        _service.hasPlayedToday(),
        _service.fetchGuessProgress(),
      ]);
      final question = results[0] as SciwordleQuestion?;
      final playerScore = results[1] as SciwordlePlayerScore;
      final alreadyPlayed = results[2] as bool;
      final savedProgress = results[3] as SciwordleProgressData?;

      setState(() {
        _question = question;
        _playerScore = playerScore;
        _alreadyPlayedToday = alreadyPlayed;
        if (alreadyPlayed) _gameOver = true;
        _loading = false;
      });

      // Restore in-progress guesses if the user backed out mid-game
      if (!alreadyPlayed &&
          question != null &&
          savedProgress != null &&
          savedProgress.answer == question.answer) {
        final restoredGuesses = <SciwordleGuessResult>[];
        for (final word in savedProgress.guesses) {
          restoredGuesses.add(
            _service.checkGuess(guess: word, answer: question.answer),
          );
        }
        final lastCorrect = restoredGuesses.isNotEmpty &&
            restoredGuesses.last.letters.every(
              (l) => l.status == LetterStatus.correct,
            );
        final usedAll = restoredGuesses.length >= _maxAttempts;
        setState(() {
          _guesses.clear();
          _guesses.addAll(restoredGuesses);
          if (lastCorrect || usedAll) {
            // The game had actually ended but progress wasn't cleared.
            // Mark as game over and let saveGameResult handle the rest.
            _gameOver = true;
            _won = lastCorrect;
            _alreadyPlayedToday = true;
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _addLetter(String letter) {
    if (_question == null || _gameOver || _submitting) return;
    if (_currentGuess.length < _question!.answer.length) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentGuess += letter.toLowerCase();
        _inputError = null;
      });
    }
  }

  void _removeLetter() {
    if (_currentGuess.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
      });
    }
  }

  Future<void> _submitGuess() async {
    if (_question == null || _gameOver || _submitting) return;

    if (_currentGuess.isEmpty) {
      setState(() => _inputError = 'Enter a guess');
      HapticFeedback.heavyImpact();
      _shakeCurrentRow();
      return;
    }
    if (_currentGuess.length != _question!.answer.length) {
      setState(
        () => _inputError = '${_question!.answer.length} letters needed',
      );
      HapticFeedback.heavyImpact();
      _shakeCurrentRow();
      return;
    }

    setState(() => _submitting = true);

    final result = _service.checkGuess(
      guess: _currentGuess,
      answer: _question!.answer,
    );
    final isCorrect = result.letters.every(
      (l) => l.status == LetterStatus.correct,
    );
    final newGuesses = [..._guesses, result];
    final attemptNumber = newGuesses.length;
    final isLastAttempt = attemptNumber == _maxAttempts;
    final gameOver = isCorrect || isLastAttempt;

    int? pointsEarned;
    SciwordlePlayerScore? refreshedScore;
    if (gameOver) {
      try {
        pointsEarned = await _service.saveGameResult(
          attemptNumber: isCorrect ? attemptNumber : null,
        );
        refreshedScore = await _service.fetchPlayerScore();
        // Clear in-progress data since the game is finished
        await _service.clearGuessProgress();
      } catch (_) {
        pointsEarned = 0;
      }
    } else {
      // Game still in progress — persist the guesses so they can't cheat
      final guessWords = newGuesses
          .map((g) => g.letters.map((l) => l.letter).join())
          .toList();
      await _service.saveGuessProgress(
        guesses: guessWords,
        answer: _question!.answer,
      );
    }

    setState(() {
      _guesses.clear();
      _guesses.addAll(newGuesses);
      _currentGuess = '';
      _gameOver = gameOver;
      _won = isCorrect;
      _pointsEarned = pointsEarned;
      if (refreshedScore != null) {
        _playerScore = refreshedScore;
      }
      _alreadyPlayedToday = gameOver;
      _submitting = false;
    });

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      _confettiController.play();
    } else if (isLastAttempt) {
      HapticFeedback.heavyImpact();
    }
  }

  void _shakeCurrentRow() {
    _shakeController.forward(from: 0);
  }

  Map<String, LetterStatus> get _letterStatuses {
    final map = <String, LetterStatus>{};
    for (final guess in _guesses) {
      for (final letter in guess.letters) {
        final existing = map[letter.letter];
        if (existing == LetterStatus.correct) continue;
        if (existing == LetterStatus.present &&
            letter.status == LetterStatus.absent)
          continue;
        map[letter.letter] = letter.status;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        foregroundColor: U.text,
        elevation: 0,
        title: Text(
          'SciWordle',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: U.text),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart_rounded, color: U.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SciwordleStatsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: U.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.leaderboard_outlined, color: U.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SciwordleLeaderboardScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? Center(child: CircularProgressIndicator(color: U.primary))
              : _error != null
              ? _buildError()
              : _question == null
              ? _buildNoQuestion()
              : _buildGame(),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.2,
              shouldLoop: false,
              colors: const [
                Color(0xFF4ADE80),
                Color(0xFFFFB300),
                Color(0xFF60A5FA),
                Color(0xFFF472B6),
                Color(0xFFA78BFA),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: U.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Couldn\'t load',
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loadGame,
            style: FilledButton.styleFrom(
              backgroundColor: U.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoQuestion() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, color: U.dim, size: 64),
          const SizedBox(height: 16),
          Text(
            'No question yet',
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back at midnight',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGame() {
    final question = _question!;
    final answerLength = question.answer.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_playerScore != null) _buildScoreBar(),
              const SizedBox(height: 16),
              _buildQuestionCard(question),
              const SizedBox(height: 20),
              if (_alreadyPlayedToday && _pointsEarned == null) ...[
                _buildAlreadyPlayed(),
                const SizedBox(height: 20),
              ],
              if (_gameOver && _pointsEarned != null) ...[
                _buildResultCard(),
                const SizedBox(height: 16),
              ],
              if (!_alreadyPlayedToday) ...[
                _buildGuessGrid(answerLength),
                if (_inputError != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _inputError!,
                      style: GoogleFonts.outfit(color: U.red, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (!_gameOver && !_alreadyPlayedToday) _buildKeyboard(answerLength),
      ],
    );
  }

  Widget _buildScoreBar() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SciwordleStatsScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: U.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              '${_playerScore!.streak}',
              style: GoogleFonts.outfit(
                color: const Color(0xFFF9E2AF),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 24),
            Container(width: 1, height: 20, color: U.border),
            const SizedBox(width: 24),
            Text(
              '${_playerScore!.totalScore} pts',
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

  Widget _buildQuestionCard(SciwordleQuestion question) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.science_outlined, color: U.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                question.category,
                style: GoogleFonts.outfit(
                  color: U.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.question,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: U.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${question.answer.length} letters',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyPlayed() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.border),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: U.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Come back tomorrow!',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    if (_won) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          final opacity = value.clamp(0.0, 1.0);
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A3A1A), const Color(0xFF0D260D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_buildAttemptBadge()],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFF4ADE80),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${_pointsEarned}',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF4ADE80),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
      ),
      child: Column(
        children: [
          Icon(Icons.science_outlined, color: U.sub, size: 40),
          const SizedBox(height: 12),
          Text(
            'You missed the word, but your streak still moved.',
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: U.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: U.primary.withValues(alpha: 0.24)),
            ),
            child: Text(
              '+${_pointsEarned ?? 0} pts participation bonus',
              style: GoogleFonts.outfit(
                color: U.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Current streak: ${_playerScore?.streak ?? 0}',
            style: GoogleFonts.outfit(
              color: U.sub,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Answer: ${_question!.answer.toUpperCase()}',
            style: GoogleFonts.outfit(
              color: U.dim,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptBadge() {
    final attempts = _guesses.length;
    final labels = [
      'Genius!',
      'Magnificent!',
      'Impressive!',
      'Splendid!',
      'Great!',
      'Phew!',
    ];
    final gradients = [
      [const Color(0xFFFFD700), const Color(0xFFFFA500)],
      [const Color(0xFFFFD700), const Color(0xFFFFA500)],
      [const Color(0xFFC0C0C0), const Color(0xFF808080)],
      [const Color(0xFFCD7F32), const Color(0xFF8B4513)],
      [const Color(0xFF60A5FA), const Color(0xFF2563EB)],
      [const Color(0xFF60A5FA), const Color(0xFF2563EB)],
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradients[attempts - 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradients[attempts - 1][0].withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            labels[attempts - 1],
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$attempts ${attempts == 1 ? 'try' : 'tries'}',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuessGrid(int answerLength) {
    return Column(
      children: [
        ...List.generate(_maxAttempts, (i) {
          if (i < _guesses.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FlipRow(result: _guesses[i], rowIndex: i),
            );
          }
          if (i == _guesses.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCurrentRow(answerLength, isActive: true),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildCurrentRow(answerLength, isActive: false),
          );
        }),
      ],
    );
  }

  Widget _buildCurrentRow(int length, {required bool isActive}) {
    final animation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0)).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
        );

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final shake = _shakeController.isAnimating
            ? Offset(animation.value.dx * 10, 0)
            : Offset.zero;
        return Transform.translate(offset: shake, child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(length, (i) {
          if (isActive && i < _currentGuess.length) {
            return _buildTile(
              _currentGuess[i].toUpperCase(),
              U.primary.withValues(alpha: 0.2),
              U.primary,
              U.text,
              isActive: isActive,
            );
          }
          return _buildTile(
            '',
            U.surface,
            isActive ? U.primary : U.border,
            U.text,
            isActive: isActive,
          );
        }),
      ),
    );
  }

  Widget _buildTile(
    String letter,
    Color bg,
    Color border,
    Color textColor, {
    bool isActive = false,
  }) {
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 2),
      ),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.outfit(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboard(int answerLength) {
    final rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
    final statuses = _letterStatuses;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(
        color: U.card,
        border: Border(top: BorderSide(color: U.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          ...rows.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: () {
                  final letters = row.split('');
                  if (rowIndex == 2) {
                    final widgets = <Widget>[];
                    widgets.add(
                      _buildKey(
                        '⌫',
                        U.surface,
                        U.text,
                        _removeLetter,
                        width: 50,
                      ),
                    );
                    for (int i = 0; i < letters.length; i++) {
                      widgets.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _buildKey(
                            letters[i],
                            _getKeyBg(letters[i], statuses),
                            _getKeyTextColor(letters[i], statuses),
                            () => _addLetter(letters[i]),
                            width: 32,
                          ),
                        ),
                      );
                    }
                    widgets.add(
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _buildKey(
                          'ENTER',
                          U.primary,
                          Colors.white,
                          () => _submitGuess(),
                          width: 60,
                        ),
                      ),
                    );
                    return widgets;
                  }
                  return letters.map((letter) {
                    final status = statuses[letter.toLowerCase()];
                    final (bg, textColor) = _getKeyColors(status);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildKey(
                        letter,
                        bg,
                        textColor,
                        () => _addLetter(letter),
                        width: 32,
                      ),
                    );
                  }).toList();
                }(),
              ),
            );
          }),
        ],
      ),
      ),
    );
  }

  (Color, Color) _getKeyColors(LetterStatus? status) {
    return switch (status) {
      LetterStatus.correct => (const Color(0xFF4ADE80), Colors.white),
      LetterStatus.present => (const Color(0xFFF9E2AF), Colors.black87),
      LetterStatus.absent => (U.surface, U.dim),
      null => (U.card, U.text),
    };
  }

  Color _getKeyBg(String letter, Map<String, LetterStatus> statuses) {
    final status = statuses[letter.toLowerCase()];
    return _getKeyColors(status).$1;
  }

  Color _getKeyTextColor(String letter, Map<String, LetterStatus> statuses) {
    final status = statuses[letter.toLowerCase()];
    return _getKeyColors(status).$2;
  }

  Widget _buildKey(
    String label,
    Color bg,
    Color textColor,
    VoidCallback onTap, {
    double width = 32,
  }) {
    return GestureDetector(
      onTap: _submitting ? null : onTap,
      child: Container(
        width: width,
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: U.border),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: textColor,
              fontSize: label.length > 1 ? 11 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FlipRow extends StatefulWidget {
  final SciwordleGuessResult result;
  final int rowIndex;

  const _FlipRow({required this.result, required this.rowIndex});

  @override
  State<_FlipRow> createState() => _FlipRowState();
}

class _FlipRowState extends State<_FlipRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;
  int _revealIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _startReveal();
  }

  void _startReveal() async {
    for (int i = 0; i < widget.result.letters.length; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() => _revealIndex = i + 1);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.result.letters.length, (i) {
        final letter = widget.result.letters[i];
        final (bg, border, textColor) = switch (letter.status) {
          LetterStatus.correct => (
            const Color(0xFF4ADE80),
            const Color(0xFF4ADE80),
            Colors.white,
          ),
          LetterStatus.present => (
            const Color(0xFFF9E2AF),
            const Color(0xFFF9E2AF),
            Colors.black87,
          ),
          LetterStatus.absent => (U.surface, U.border, U.dim),
        };

        final isRevealed = i < _revealIndex;

        return AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final angle = isRevealed ? 0.0 : 3.14159;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(isRevealed ? 0.0 : angle),
              child: Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isRevealed ? bg : U.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRevealed ? border : U.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    letter.letter.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: isRevealed ? textColor : U.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
