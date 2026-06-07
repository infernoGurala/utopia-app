import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../providers/delve_deck_provider.dart';
import '../../providers/delve_inventory_provider.dart';
import '../../providers/delve_session_provider.dart';
import '../../providers/delve_theme_provider.dart';
import '../../models/delve_word_model.dart';
import 'word/word_screen.dart';
import 'jet_words/add_word_sheet.dart';
import 'jet_words/word_list_tile.dart';

class DelveShell extends StatefulWidget {
  const DelveShell({super.key});

  @override
  State<DelveShell> createState() => _DelveShellState();
}

class _DelveShellState extends State<DelveShell> {
  String _searchQuery = '';
  bool _showArchive = false;
  final Set<int> _expandedDecks = {};

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeDeck = deckProvider.activeDeck;
    final words = _showArchive ? inventoryProvider.archive : inventoryProvider.inventory;

    // Filter words based on search
    final filteredWords = words.where((w) {
      final query = _searchQuery.toLowerCase();
      return w.word.toLowerCase().contains(query) ||
             w.meaning.toLowerCase().contains(query);
    }).toList();

    // Chunk filtered words into groups of 15
    final List<List<Word>> chunks = [];
    for (var i = 0; i < filteredWords.length; i += 15) {
      final end = (i + 15 > filteredWords.length) ? filteredWords.length : i + 15;
      chunks.add(filteredWords.sublist(i, end));
    }

    final List<dynamic> displayItems = [];
    int deckCounter = 0;
    for (final chunk in chunks) {
      if (chunk.length == 15) {
        displayItems.add({
          'type': 'deck',
          'deckIndex': deckCounter++,
          'words': chunk,
        });
      } else {
        for (final word in chunk) {
          displayItems.add({
            'type': 'word',
            'word': word,
          });
        }
      }
    }

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Delve Vocabulary',
          style: GoogleFonts.playfairDisplay(
            color: U.text,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          if (activeDeck != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: U.text),
              color: U.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'reset') {
                  deckProvider.resetDeckToDayOne();
                } else if (val == 'reset_session') {
                  deckProvider.resetTodaysSession();
                } else if (val == 'abandon') {
                  _confirmAbandon(context, deckProvider);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'reset_session',
                  child: Text('Reset Today\'s Session', style: GoogleFonts.plusJakartaSans(color: U.text)),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: Text('Reset Deck to Day 1', style: GoogleFonts.plusJakartaSans(color: U.text)),
                ),
                PopupMenuItem(
                  value: 'abandon',
                  child: Text('Abandon Deck', style: GoogleFonts.plusJakartaSans(color: U.red)),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Section 1: Active Deck Learning Status Card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildDeckStatusCard(context, deckProvider, inventoryProvider, isDark),
            ),

            // ── Tab Bar Toggle (Inventory vs Archive) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _buildTabButton('My Inventory (${inventoryProvider.inventory.length})', !_showArchive),
                  const SizedBox(width: 12),
                  _buildTabButton('Archived (${inventoryProvider.archive.length})', _showArchive),
                ],
              ),
            ),

            // ── Search Input ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: U.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: U.border.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 14),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: _showArchive ? 'Search archive...' : 'Search your vocabulary...',
                    hintStyle: GoogleFonts.plusJakartaSans(color: U.dim, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: U.dim, size: 20),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            // ── Section 2: Words List ──
            Expanded(
              child: displayItems.isEmpty
                  ? _buildEmptyInventoryState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: displayItems.length,
                      itemBuilder: (context, idx) {
                        final item = displayItems[idx];
                        if (item['type'] == 'deck') {
                          return _buildStackedDeck(item['deckIndex'] as int, item['words'] as List<Word>);
                        } else {
                          final word = item['word'] as Word;
                          return WordListTile(
                            word: word,
                            onEdit: () => _showEditSheet(context, word),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditSheet(context, null),
        backgroundColor: U.teal,
        foregroundColor: isDark ? Colors.black : Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Word',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showArchive = !label.startsWith('My Inventory');
            _expandedDecks.clear();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? U.teal.withValues(alpha: 0.12) : U.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? U.teal.withValues(alpha: 0.35) : U.border.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? U.teal : U.sub,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeckStatusCard(
    BuildContext context,
    DeckProvider deckProvider,
    InventoryProvider inventoryProvider,
    bool isDark,
  ) {
    final activeDeck = deckProvider.activeDeck;

    if (activeDeck == null) {
      // Waiting State: No active deck
      final canStart = inventoryProvider.inventory.length >= 15;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: U.border.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: U.teal, size: 18),
                const SizedBox(width: 8),
                Text(
                  '13-DAY STUDY CYCLE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: U.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              canStart ? 'Ready to Start Studying' : 'Add Words to Start Deck',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: U.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              canStart
                  ? 'You have enough words in your inventory to begin a customized 13-day study deck.'
                  : 'Delve builds a 13-day learning cycle. You need at least 15 words in your inventory (Current: ${inventoryProvider.inventory.length}/15).',
              style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (canStart)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    deckProvider.createDeckFromWords(inventoryProvider.getRandomWords(15));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: U.teal,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Initialize Day 1 Deck', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => inventoryProvider.loadStarterDeck(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: U.teal.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.bolt_rounded, color: U.teal, size: 16),
                  label: Text('Load 15 Starter Words', style: GoogleFonts.plusJakartaSans(color: U.teal, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      );
    }

    // Active Deck State
    final isTestDay = activeDeck.currentDay == 13;
    final completedToday = activeDeck.isSessionCompletedToday;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: U.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: U.teal, size: 18),
              const SizedBox(width: 8),
              Text(
                isTestDay ? 'DECISIVE TEST DAY' : 'DAY ${activeDeck.currentDay} OF 13',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: U.teal,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: U.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ACTIVE CYCLE',
                  style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: U.teal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            completedToday ? 'Today\'s Session Completed!' : (isTestDay ? 'Ready to Prove Your Knowledge' : 'Daily Word Session Ready'),
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: U.text,
            ),
          ),
          const SizedBox(height: 6),
          if (completedToday)
            Text(
              'Awesome work! You\'ve finished your session for today. Come back tomorrow to unlock the next day.',
              style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 12, height: 1.4),
            )
          else
            Text(
              isTestDay
                  ? 'This is the final test day. Complete this spelling and recall review to archive learned words.'
                  : 'Spend 2 minutes reviewing today\'s target words to lock them into long-term retention.',
              style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 12, height: 1.4),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: U.teal.withValues(alpha: 0.7), size: 12),
              const SizedBox(width: 6),
              Text(
                'Cycle: ${_formatDate(activeDeck.startedAt)} — ${_formatDate(activeDeck.startedAt.add(const Duration(days: 12)))}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: U.sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: activeDeck.currentDay / 13.0,
              backgroundColor: U.border.withValues(alpha: 0.1),
              color: U.teal,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),
          if (!completedToday)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiProvider(
                        providers: [
                          ChangeNotifierProvider.value(value: context.read<DelveThemeProvider>()),
                          ChangeNotifierProvider.value(value: context.read<DeckProvider>()),
                          ChangeNotifierProvider.value(value: context.read<InventoryProvider>()),
                          ChangeNotifierProvider.value(value: context.read<SessionProvider>()),
                        ],
                        child: Scaffold(
                          backgroundColor: U.bg,
                          appBar: AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            leading: IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            title: Text(
                              'Daily Session',
                              style: GoogleFonts.playfairDisplay(
                                color: U.text,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          body: const WordScreen(),
                        ),
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: U.teal,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isTestDay ? 'Start Test Session' : 'Begin Daily Review',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyInventoryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, color: U.dim, size: 48),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty ? 'No matching words found' : 'Your vocabulary hangar is empty',
            style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, Word? word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<DelveThemeProvider>()),
          ChangeNotifierProvider.value(value: context.read<InventoryProvider>()),
        ],
        child: AddWordSheet(existingWord: word),
      ),
    ).then((_) => setState(() {}));
  }

  void _confirmAbandon(BuildContext context, DeckProvider deckProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Abandon study cycle?', style: GoogleFonts.playfairDisplay(color: U.text, fontWeight: FontWeight.bold)),
        content: Text(
          'All progress for this 13-day cycle will be lost. The words will remain in your inventory.',
          style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Studying', style: GoogleFonts.plusJakartaSans(color: U.sub)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              deckProvider.abandonDeck();
              setState(() {});
            },
            child: Text('Abandon', style: GoogleFonts.plusJakartaSans(color: U.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedDeck(int deckIndex, List<Word> deckWords) {
    final isExpanded = _expandedDecks.contains(deckIndex);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        if (!isExpanded) ...[
          Positioned(
            left: 28,
            right: 28,
            bottom: 0,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: U.card.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: U.border.withValues(alpha: 0.15)),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 4,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: U.card.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: U.border.withValues(alpha: 0.2)),
              ),
            ),
          ),
        ],
        Container(
          margin: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: U.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isExpanded ? U.teal.withValues(alpha: 0.4) : U.border.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isExpanded ? 0.05 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: U.teal.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.style_rounded, color: U.teal, size: 24),
                ),
                title: Text(
                  'Deck ${deckIndex + 1}',
                  style: GoogleFonts.playfairDisplay(
                    color: U.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${deckWords.length} Words • Tap to ${isExpanded ? 'collapse' : 'expand'}',
                  style: GoogleFonts.plusJakartaSans(
                    color: U.sub,
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: U.dim,
                ),
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedDecks.remove(deckIndex);
                    } else {
                      _expandedDecks.add(deckIndex);
                    }
                  });
                },
              ),
              if (isExpanded) ...[
                Divider(color: U.border.withValues(alpha: 0.15), height: 1),
                Container(
                  color: U.bg.withValues(alpha: 0.2),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: deckWords.length,
                    itemBuilder: (context, idx) {
                      final word = deckWords[idx];
                      return WordListTile(
                        word: word,
                        onEdit: () => _showEditSheet(context, word),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
  }
}
