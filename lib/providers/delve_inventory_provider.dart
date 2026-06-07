import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/delve_word_model.dart';
import '../services/delve_groq_service.dart';
import '../services/delve_supabase_service.dart';

class InventoryProvider extends ChangeNotifier {
  static const String _inventoryKey = 'delve_inventory';
  static const String _archiveKey = 'delve_archive';

  List<Word> _inventory = [];
  List<Word> _archive = [];
  final _groqService = GroqService();
  final _supabaseService = DelveSupabaseService();
  String? _uid;
  bool _isLoaded = false;

  List<Word> get inventory => _inventory;
  List<Word> get archive => _archive;
  bool get isLoaded => _isLoaded;

  InventoryProvider() {
    _loadLocalData();
  }

  // ---------------------------------------------------------------------------
  // Initialization with user UID
  // ---------------------------------------------------------------------------

  /// Called after successful login to load user's data from Supabase.
  Future<void> initForUser(String uid) async {
    _uid = uid;
    await _loadFromCloud(uid);
  }

  /// Called on sign-out to clear data.
  void clearUserData() {
    _uid = null;
    _inventory = [];
    _archive = [];
    _isLoaded = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  /// Load from SharedPreferences (fast local cache).
  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final invString = prefs.getString(_inventoryKey);
    if (invString != null) {
      final List<dynamic> jsonList = jsonDecode(invString);
      _inventory = jsonList.map((e) => Word.fromJson(e)).toList();
    }

    final archString = prefs.getString(_archiveKey);
    if (archString != null) {
      final List<dynamic> jsonList = jsonDecode(archString);
      _archive = jsonList.map((e) => Word.fromJson(e)).toList();
    }
    
    _isLoaded = true;
    notifyListeners();
  }

  /// Load from Supabase (cloud truth) and merge with local.
  Future<void> _loadFromCloud(String uid) async {
    try {
      final cloudInventory = await _supabaseService.getInventory(uid);
      final cloudArchive = await _supabaseService.getArchive(uid);

      if (cloudInventory.isNotEmpty || cloudArchive.isNotEmpty) {
        // Cloud has data — use it as source of truth
        _inventory = cloudInventory;
        _archive = cloudArchive;
      } else if (_inventory.isNotEmpty || _archive.isNotEmpty) {
        // Local has data but cloud is empty — push local to cloud
        for (final word in _inventory) {
          await _supabaseService.addWordToInventory(uid, word);
        }
        for (final word in _archive) {
          await _supabaseService.addWordToArchive(uid, word);
        }
      }

      _isLoaded = true;
      notifyListeners();
      _saveLocalCache();
      _backfillMissingData();
    } catch (e) {
      debugPrint('Failed to load from Supabase: $e');
      // Fall back to local data
      _isLoaded = true;
      notifyListeners();
    }
  }

  void _backfillMissingData() async {
    // Sequentially fetch missing partOfSpeech to avoid rate limits
    for (var i = 0; i < _inventory.length; i++) {
      final word = _inventory[i];
      if (word.partOfSpeech == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchPartOfSpeechForWord(word);
      }
    }
    for (var i = 0; i < _archive.length; i++) {
      final word = _archive[i];
      if (word.partOfSpeech == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchPartOfSpeechForWord(word);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------------------

  Future<void> _saveLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _inventoryKey,
      jsonEncode(_inventory.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _archiveKey,
      jsonEncode(_archive.map((e) => e.toJson()).toList()),
    );
  }

  // ---------------------------------------------------------------------------
  // Word Operations
  // ---------------------------------------------------------------------------

  void addWord(Word word) {
    _inventory.add(word);
    notifyListeners();
    _saveLocalCache();
    
    // Sync to cloud
    if (_uid != null) {
      _supabaseService.addWordToInventory(_uid!, word).catchError((e) {
        debugPrint('Failed to sync addWord to Supabase: $e');
      });
    }

    if (word.partOfSpeech == null) {
      _fetchPartOfSpeechForWord(word);
    }
  }

  Future<void> _fetchPartOfSpeechForWord(Word word) async {
    final pos = await _groqService.fetchPartOfSpeech(word.word);
    if (pos != null && pos.isNotEmpty) {
      updateWord(word.copyWith(partOfSpeech: pos));
    }
  }

  void updateWord(Word updatedWord) {
    var index = _inventory.indexWhere((w) => w.id == updatedWord.id);
    if (index != -1) {
      _inventory[index] = updatedWord;
      // Sync to cloud
      if (_uid != null) {
        _supabaseService
            .updateInventoryWord(_uid!, updatedWord)
            .catchError((e) {
          debugPrint('Failed to sync updateWord to Supabase: $e');
        });
      }
    } else {
      index = _archive.indexWhere((w) => w.id == updatedWord.id);
      if (index != -1) {
        _archive[index] = updatedWord;
        if (_uid != null) {
          _supabaseService
              .updateArchiveWord(_uid!, updatedWord)
              .catchError((e) {
            debugPrint('Failed to sync updateArchiveWord to Supabase: $e');
          });
        }
      }
    }
    notifyListeners();
    _saveLocalCache();
  }

  void removeWord(String id) {
    _inventory.removeWhere((w) => w.id == id);
    _archive.removeWhere((w) => w.id == id);
    notifyListeners();
    _saveLocalCache();

    if (_uid != null) {
      _supabaseService.deleteInventoryWord(id).catchError((e) {
        debugPrint('Failed to sync removeWord to Supabase: $e');
      });
    }
  }

  void archiveWord(String id) {
    final index = _inventory.indexWhere((w) => w.id == id);
    if (index != -1) {
      final word = _inventory.removeAt(index);
      final archivedWord = word.copyWith(archivedAt: DateTime.now());
      _archive.add(archivedWord);
      notifyListeners();
      _saveLocalCache();

      if (_uid != null) {
        _supabaseService.addWordToArchive(_uid!, word).catchError((e) {
          debugPrint('Failed to sync archiveWord to Supabase: $e');
        });
      }
    }
  }

  List<Word> getRandomWords(int count) {
    if (_inventory.length < count) return [];
    final shuffled = List<Word>.from(_inventory)..shuffle();
    return shuffled.take(count).toList();
  }

  Word? getWordById(String id) {
    try {
      return _inventory.firstWhere((w) => w.id == id);
    } catch (_) {
      try {
        return _archive.firstWhere((w) => w.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Word? findDuplicate(String word) {
    final search = word.trim().toLowerCase();
    try {
      return _inventory.firstWhere((w) => w.word.trim().toLowerCase() == search);
    } catch (_) {
      try {
        return _archive.firstWhere((w) => w.word.trim().toLowerCase() == search);
      } catch (_) {
        return null;
      }
    }
  }

  void loadStarterDeck() {
    final initialWords = [
      {'word': 'Ephemeral', 'meaning': 'Lasting for a very short time'},
      {'word': 'Solitude', 'meaning': 'The state of being alone, often peacefully'},
      {'word': 'Reverie', 'meaning': 'A state of being pleasantly lost in thought'},
      {'word': 'Laconic', 'meaning': 'Using very few words to express a lot'},
      {'word': 'Wanderlust', 'meaning': 'A strong desire to travel and explore the world'},
      {'word': 'Serendipity', 'meaning': 'Finding something good without looking for it'},
      {'word': 'Melancholy', 'meaning': 'A deep, thoughtful sadness'},
      {'word': 'Resilience', 'meaning': 'The ability to recover quickly from difficulties'},
      {'word': 'Luminous', 'meaning': 'Full of light; glowing'},
      {'word': 'Catharsis', 'meaning': 'The release of strong emotions through an experience'},
      {'word': 'Threshold', 'meaning': 'The point just before something begins or changes'},
      {'word': 'Liminal', 'meaning': 'Occupying a transitional or in-between space'},
      {'word': 'Fervent', 'meaning': 'Having or showing intense passion or feeling'},
      {'word': 'Tempest', 'meaning': 'A violent, chaotic storm'},
      {'word': 'Cognition', 'meaning': 'The mental process of acquiring knowledge and understanding'},
    ];

    final uuid = const Uuid();
    for (var w in initialWords) {
      addWord(Word(
        id: uuid.v4(),
        word: w['word']!,
        meaning: w['meaning']!,
        addedAt: DateTime.now(),
      ));
    }
  }
}
