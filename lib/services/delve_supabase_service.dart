import 'package:flutter/foundation.dart';
import 'focus_supabase_service.dart';
import '../models/delve_word_model.dart';
import '../models/delve_deck_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class DelveSupabaseService {
  static DelveSupabaseService? _instance;
  
  DelveSupabaseService._();
  
  factory DelveSupabaseService() {
    _instance ??= DelveSupabaseService._();
    return _instance!;
  }
  
  supa.SupabaseClient? get _client => FocusSupabaseService().client;
  bool get _initialized => FocusSupabaseService().isInitialized;

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  Future<void> upsertProfile({
    required String uid,
    required String displayName,
    required String email,
  }) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!.from('delve_profiles').upsert({
        'uid': uid,
        'display_name': displayName,
        'email': email,
      }, onConflict: 'uid');
    } catch (e) {
      debugPrint('Delve upsertProfile error: $e');
    }
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    if (!_initialized || _client == null) return null;
    try {
      final response = await _client!
          .from('delve_profiles')
          .select()
          .eq('uid', uid)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Delve getProfile error: $e');
      return null;
    }
  }

  Future<void> incrementDeckStats(String uid, int wordsLearned) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!.rpc('increment_deck_stats', params: {
        'p_uid': uid,
        'p_words': wordsLearned,
      });
    } catch (e) {
      debugPrint('Delve incrementDeckStats error: $e');
      // Fallback: client-side increment
      try {
        final profile = await getProfile(uid);
        if (profile != null) {
          final currentDecks = (profile['total_decks_completed'] as int? ?? 0) + 1;
          final currentWords = (profile['total_words_learned'] as int? ?? 0) + wordsLearned;
          await _client!.from('delve_profiles').update({
            'total_decks_completed': currentDecks,
            'total_words_learned': currentWords,
          }).eq('uid', uid);
        }
      } catch (innerErr) {
        debugPrint('Fallback increment failed: $innerErr');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Inventory
  // ---------------------------------------------------------------------------

  Future<void> addWordToInventory(String uid, Word word) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!.from('delve_inventory').upsert({
        'id': word.id,
        'uid': uid,
        'word': word.word,
        'meaning': word.meaning,
        'ai_meaning': word.aiMeaning,
        'note': word.note,
        'part_of_speech': word.partOfSpeech,
        'added_at': word.addedAt.toIso8601String(),
        'archived_at': word.archivedAt?.toIso8601String(),
        'fail_count': word.failCount,
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Delve addWordToInventory error: $e');
    }
  }

  Future<void> updateInventoryWord(String uid, Word word) async {
    await addWordToInventory(uid, word);
  }

  Future<void> deleteInventoryWord(String id) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!.from('delve_inventory').delete().eq('id', id);
    } catch (e) {
      debugPrint('Delve deleteInventoryWord error: $e');
    }
  }

  Future<List<Word>> getInventory(String uid) async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('delve_inventory')
          .select()
          .eq('uid', uid)
          .order('added_at', ascending: false);
      final List<dynamic> rows = response ?? [];
      return rows.map((row) => _rowToWord(row)).toList();
    } catch (e) {
      debugPrint('Delve getInventory error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Archive
  // ---------------------------------------------------------------------------

  Future<void> addWordToArchive(String uid, Word word) async {
    if (!_initialized || _client == null) return;
    try {
      final archivedWord = word.copyWith(archivedAt: DateTime.now());
      // Delete from inventory and insert/upsert into archive
      await _client!.from('delve_inventory').delete().eq('id', word.id);
      await _client!.from('delve_archive').upsert({
        'id': archivedWord.id,
        'uid': uid,
        'word': archivedWord.word,
        'meaning': archivedWord.meaning,
        'ai_meaning': archivedWord.aiMeaning,
        'note': archivedWord.note,
        'part_of_speech': archivedWord.partOfSpeech,
        'added_at': archivedWord.addedAt.toIso8601String(),
        'archived_at': archivedWord.archivedAt!.toIso8601String(),
        'fail_count': archivedWord.failCount,
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Delve addWordToArchive error: $e');
    }
  }

  Future<List<Word>> getArchive(String uid) async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('delve_archive')
          .select()
          .eq('uid', uid)
          .order('archived_at', ascending: false);
      final List<dynamic> rows = response ?? [];
      return rows.map((row) => _rowToWord(row)).toList();
    } catch (e) {
      debugPrint('Delve getArchive error: $e');
      return [];
    }
  }

  Future<void> updateArchiveWord(String uid, Word word) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!.from('delve_archive').upsert({
        'id': word.id,
        'uid': uid,
        'word': word.word,
        'meaning': word.meaning,
        'ai_meaning': word.aiMeaning,
        'note': word.note,
        'part_of_speech': word.partOfSpeech,
        'added_at': word.addedAt.toIso8601String(),
        'archived_at': word.archivedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'fail_count': word.failCount,
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Delve updateArchiveWord error: $e');
    }
  }

  Future<void> deleteArchiveWord(String id) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!.from('delve_archive').delete().eq('id', id);
    } catch (e) {
      debugPrint('Delve deleteArchiveWord error: $e');
    }
  }

  Future<void> returnToInventory(String uid, Word word) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!.from('delve_archive').delete().eq('id', word.id);
      await _client!.from('delve_inventory').upsert({
        'id': word.id,
        'uid': uid,
        'word': word.word,
        'meaning': word.meaning,
        'ai_meaning': word.aiMeaning,
        'note': word.note,
        'part_of_speech': word.partOfSpeech,
        'added_at': word.addedAt.toIso8601String(),
        'archived_at': null,
        'fail_count': word.failCount,
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Delve returnToInventory error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Active Deck
  // ---------------------------------------------------------------------------

  Future<void> saveActiveDeck(String uid, Deck deck) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!.from('delve_active_deck').upsert({
        'id': deck.id,
        'uid': uid,
        'started_at': deck.startedAt.toIso8601String(),
        'current_day': deck.currentDay,
        'status': deck.status.index,
        'set1_word_ids': deck.set1WordIds,
        'set2_word_ids': deck.set2WordIds,
        'set3_word_ids': deck.set3WordIds,
        'last_session_date': deck.lastSessionDate?.toIso8601String(),
      }, onConflict: 'uid');
    } catch (e) {
      debugPrint('Delve saveActiveDeck error: $e');
    }
  }

  Future<Deck?> getActiveDeck(String uid) async {
    if (!_initialized || _client == null) return null;
    try {
      final response = await _client!
          .from('delve_active_deck')
          .select()
          .eq('uid', uid)
          .maybeSingle();
      if (response == null) return null;
      final data = response;
      return Deck(
        id: data['id'],
        startedAt: DateTime.parse(data['started_at']),
        currentDay: data['current_day'],
        status: DeckStatus.values[data['status']],
        set1WordIds: List<String>.from(data['set1_word_ids']),
        set2WordIds: List<String>.from(data['set2_word_ids']),
        set3WordIds: List<String>.from(data['set3_word_ids']),
        lastSessionDate: data['last_session_date'] != null
            ? DateTime.parse(data['last_session_date'])
            : null,
      );
    } catch (e) {
      debugPrint('Delve getActiveDeck error: $e');
      return null;
    }
  }

  Future<void> deleteActiveDeck(String uid) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!.from('delve_active_deck').delete().eq('uid', uid);
    } catch (e) {
      debugPrint('Delve deleteActiveDeck error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Batch Operations
  // ---------------------------------------------------------------------------

  Future<void> archiveWords(String uid, List<Word> words) async {
    for (final word in words) {
      await addWordToArchive(uid, word);
    }
  }

  Future<void> returnFailedWords(String uid, List<Word> words) async {
    for (final word in words) {
      await addWordToInventory(uid, word.copyWith(failCount: word.failCount + 1));
    }
  }

  Future<void> seedOnboardingWords(String uid, List<Word> words) async {
    for (final word in words) {
      await addWordToInventory(uid, word);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Word _rowToWord(Map<String, dynamic> row) {
    return Word(
      id: row['id'],
      word: row['word'],
      meaning: row['meaning'],
      aiMeaning: row['ai_meaning'],
      note: row['note'],
      partOfSpeech: row['part_of_speech'],
      addedAt: DateTime.parse(row['added_at']),
      archivedAt: row['archived_at'] != null ? DateTime.parse(row['archived_at']) : null,
      failCount: row['fail_count'] ?? 0,
    );
  }
}
