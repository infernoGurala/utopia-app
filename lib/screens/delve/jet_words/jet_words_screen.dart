import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../../models/delve_word_model.dart';
import '../../../providers/delve_theme_provider.dart';
import '../../../providers/delve_inventory_provider.dart';
import '../../../providers/delve_deck_provider.dart';
import 'word_list_tile.dart';
import 'add_word_sheet.dart';

class JetWordsScreen extends StatelessWidget {
  const JetWordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DelveThemeProvider>().currentTheme;

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 120, // Taller to fit heading
            title: Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('semantic', 
                    style: TextStyle(
                      fontFamily: 'OrangeAvenue',
                      color: theme.text, 
                      fontSize: 48, 
                      letterSpacing: -0.4,
                      fontFeatures: const [
                        FontFeature.enable('liga'),
                        FontFeature.enable('dlig'),
                        FontFeature.enable('swsh'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Your vocabulary hangar', 
                    style: GoogleFonts.marcellus(
                      color: theme.textSecondary, 
                      fontSize: 14,
                      letterSpacing: 1.0,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              indicatorColor: theme.accent,
              labelColor: theme.accent,
              unselectedLabelColor: theme.textSecondary,
              dividerColor: theme.divider,
              tabs: const [
                Tab(text: 'Inventory'),
                Tab(text: 'Archive'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildList(context, isArchive: false),
              _buildList(context, isArchive: true),
            ],
          ),
          floatingActionButton: const _AnimatedFAB(),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, {required bool isArchive}) {
    final provider = context.watch<InventoryProvider>();
    final words = isArchive ? provider.archive : provider.inventory;
    final theme = context.read<DelveThemeProvider>().currentTheme;

    if (words.isEmpty) {
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) => Opacity(opacity: val, child: child),
          child: Text(
            isArchive ? 'No words archived yet.' : 'Your inventory is empty.',
            style: TextStyle(color: theme.textSecondary),
          ),
        ),
      );
    }

    if (isArchive) {
      // Archive displays as a standard flat list
      return ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 120),
        itemCount: words.length,
        itemBuilder: (context, index) {
          final word = words[index];
          return Dismissible(
            key: ValueKey('archive_${word.id}'),
            direction: DismissDirection.endToStart,
            background: _buildDeleteBackground(theme),
            onDismissed: (_) {
              context.read<InventoryProvider>().removeWord(word.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${word.word}" removed from archive.')),
              );
            },
            child: _animateTile(
              index: index,
              child: WordListTile(
                word: word,
                onEdit: () => _showEditSheet(context, word),
              ),
            ),
          );
        },
      );
    } else {
      // Inventory displays as Active Deck (if exists) + Folders + loose cards
      final activeDeck = context.watch<DeckProvider>().activeDeck;
      
      final int fullDecks = words.length ~/ 15;
      final int looseWords = words.length % 15;
      final int totalItems = fullDecks + looseWords;

      return ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 120),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          int offsetIndex = index;

          if (offsetIndex < fullDecks) {
            // Render a Curated Deck Folder
            final startIdx = offsetIndex * 15;
            final deckWords = words.sublist(startIdx, startIdx + 15);
            final isActive = activeDeck != null && 
                deckWords.every((w) => activeDeck.allWordIds.contains(w.id));

            return _animateTile(
              index: index,
              child: _buildFolderTile(context, offsetIndex + 1, deckWords, theme, isActive: isActive),
            );
          } else {
            // Render loose word card
            final wordIndex = (fullDecks * 15) + (offsetIndex - fullDecks);
            final word = words[wordIndex];
            
            return Dismissible(
              key: ValueKey('inv_${word.id}'),
              direction: DismissDirection.endToStart,
              background: _buildDeleteBackground(theme),
              onDismissed: (_) {
                context.read<InventoryProvider>().removeWord(word.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${word.word}" removed from inventory.')),
                );
              },
              child: _animateTile(
                index: index,
                child: WordListTile(
                  word: word,
                  onEdit: () => _showEditSheet(context, word),
                ),
              ),
            );
          }
        },
      );
    }
  }

  Widget _animateTile({required int index, required Widget child}) {
    final delay = (index * 50).clamp(0, 400);
    return TweenAnimationBuilder<double>(
      key: ValueKey('anim_$index'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  void _showEditSheet(BuildContext context, Word word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddWordSheet(existingWord: word),
    );
  }


  Widget _buildActionIcon({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  void _confirmAbandon(BuildContext context) {
    final theme = context.read<DelveThemeProvider>().currentTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardBackground,
        title: Text('Abandon current deck?', style: TextStyle(color: theme.text)),
        content: const Text('All progress for this 13-day cycle will be lost. The words will remain in your inventory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Studying'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DeckProvider>().abandonDeck();
            },
            child: const Text('Abandon', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteBackground(theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
    );
  }

  Widget _buildFolderTile(BuildContext context, int deckNumber, List<Word> deckWords, theme, {bool isActive = false}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? theme.accent.withValues(alpha: 0.5) : theme.divider,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: theme.accent.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: ExpansionTile(
          iconColor: theme.accent,
          collapsedIconColor: theme.textSecondary,
          leading: Icon(Icons.folder_special_rounded, color: theme.accent),
          title: Row(
            children: [
              Text(
                'Curated Deck $deckNumber',
                style: GoogleFonts.marcellus(
                  color: theme.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: GoogleFonts.inter(
                      color: theme.accent,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '15 Words Ready',
            style: GoogleFonts.inter(
              color: theme.accent.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          children: [
            ...deckWords.map((w) => WordListTile(
              word: w,
              onEdit: () => _showEditSheet(context, w),
            )),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _confirmDeleteFolder(context, deckWords, deckNumber),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  label: const Text('Delete Entire Deck', style: TextStyle(color: Colors.redAccent)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, List<Word> words, int number) {
    final theme = context.read<DelveThemeProvider>().currentTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardBackground,
        title: Text('Delete Curated Deck $number?', style: TextStyle(color: theme.text)),
        content: Text('This will permanently delete all 15 words in this deck. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final provider = context.read<InventoryProvider>();
              for (final w in words) {
                provider.removeWord(w.id);
              }
            },
            child: const Text('Delete All 15', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _AnimatedFAB extends StatefulWidget {
  const _AnimatedFAB();

  @override
  State<_AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<_AnimatedFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DelveThemeProvider>().currentTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 80.0),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withValues(alpha: 0.3 * (1.1 - _pulseAnimation.value) * 10),
                  blurRadius: 20 * _pulseAnimation.value,
                  spreadRadius: 5 * _pulseAnimation.value,
                ),
              ],
            ),
            child: Transform.scale(
              scale: _pulseAnimation.value,
              child: FloatingActionButton(
                backgroundColor: theme.accent,
                foregroundColor: theme.isDark ? Colors.black : Colors.white,
                elevation: 0,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AddWordSheet(),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          );
        },
      ),
    );
  }
}
