import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../models/news_brief.dart';
import '../models/news_category.dart';
import 'cache_service.dart';

/// Repository for fetching and caching daily news briefs.
///
/// Uses the Focus Supabase project (config/supabase-focus-1 in Firestore)
/// to query the `news_briefs` table directly. No edge functions needed.
class NewsBriefRepository {
  static final NewsBriefRepository _instance = NewsBriefRepository._internal();
  factory NewsBriefRepository() => _instance;
  NewsBriefRepository._internal();

  supa.SupabaseClient? _client;
  bool _initialized = false;
  bool _initializing = false;

  // ──────────────────── Initialization ────────────────────

  /// Initialize the Supabase client from Firestore config/supabase-focus-1.
  /// Returns true if the client is ready for use.
  Future<bool> _ensureInitialized() async {
    if (_initialized && _client != null) return true;
    if (_initializing) {
      // Wait for the in-progress initialization to finish
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_initialized && _client != null) return true;
        if (!_initializing) break;
      }
      return _initialized && _client != null;
    }

    _initializing = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('supabase-focus-1')
          .get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('NewsBriefRepository: Firestore config [supabase-focus-1] not found.');
        _initializing = false;
        return false;
      }

      final data = doc.data()!;
      final url = data['url'] as String?;
      final anonKey = data['anon_key'] as String?;

      if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
        debugPrint('NewsBriefRepository: Config missing url or anon_key.');
        _initializing = false;
        return false;
      }

      _client = supa.SupabaseClient(url, anonKey);
      _initialized = true;
      _initializing = false;
      debugPrint('NewsBriefRepository: Initialized with Supabase URL: $url');
      return true;
    } catch (e) {
      debugPrint('NewsBriefRepository: Initialization failed: $e');
      _initializing = false;
      return false;
    }
  }

  // ──────────────────── Categories ────────────────────

  /// Returns the hardcoded default category list.
  Future<List<NewsCategory>> getActiveCategories() async {
    return [
      NewsCategory(slug: 'world', label: 'World', displayOrder: 1),
      NewsCategory(slug: 'tech', label: 'Tech', displayOrder: 2),
      NewsCategory(slug: 'ai', label: 'AI', displayOrder: 3),
      NewsCategory(slug: 'science', label: 'Science', displayOrder: 4),
      NewsCategory(slug: 'india', label: 'India', displayOrder: 5),
      NewsCategory(slug: 'movies', label: 'Movies', displayOrder: 6),
      NewsCategory(slug: 'entertainment', label: 'Entertainment', displayOrder: 7),
      NewsCategory(slug: 'social_media', label: 'Social Media', displayOrder: 8),
      NewsCategory(slug: 'sports', label: 'Sports', displayOrder: 9),
      NewsCategory(slug: 'politics', label: 'Politics', displayOrder: 10),
      NewsCategory(slug: 'economy', label: 'Economy', displayOrder: 11),
    ];
  }

  // ──────────────────── Public API ────────────────────

  /// Fetches today's news briefs.
  ///
  /// Flow:
  /// 1. If today's cache exists → return it instantly, refresh in background.
  /// 2. If no cache → fetch from Supabase (blocking).
  /// 3. If Supabase fails → try yesterday's cache as fallback.
  /// 4. If nothing → return empty map.
  Future<Map<String, List<NewsBrief>>> getTodaysBriefs() async {
    final todayStr = _todayDateString();
    final cacheKey = 'news_briefs_$todayStr';

    // 1. Try today's cache first
    final cached = await _loadFromCache(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      debugPrint('NewsBriefRepository: Cache HIT for $todayStr');
      // Refresh in background (non-blocking)
      _refreshInBackground(cacheKey);
      return cached;
    }

    // 2. No cache — fetch from Supabase directly
    debugPrint('NewsBriefRepository: Cache MISS — fetching from Supabase...');
    final fresh = await _fetchFromSupabase(cacheKey);
    if (fresh.isNotEmpty) return fresh;

    // 3. Supabase failed — try yesterday's cache
    debugPrint('NewsBriefRepository: Supabase fetch failed, trying yesterday cache...');
    final yesterdayStr = _yesterdayDateString();
    final fallback = await _loadFromCache('news_briefs_$yesterdayStr');
    if (fallback != null && fallback.isNotEmpty) {
      debugPrint('NewsBriefRepository: Yesterday cache fallback HIT');
      return fallback;
    }

    debugPrint('NewsBriefRepository: No news data available');
    return {};
  }

  /// Force refresh: fetches from Supabase and replaces cache.
  /// Falls back to cached data if Supabase fails.
  Future<Map<String, List<NewsBrief>>> forceRefreshTodaysBriefs() async {
    final todayStr = _todayDateString();
    final cacheKey = 'news_briefs_$todayStr';

    debugPrint('NewsBriefRepository: Force refreshing...');
    final fresh = await _fetchFromSupabase(cacheKey);
    if (fresh.isNotEmpty) return fresh;

    // Fallback to any cached data
    debugPrint('NewsBriefRepository: Force refresh failed, trying cache fallback...');
    final cached = await _loadFromCache(cacheKey);
    if (cached != null && cached.isNotEmpty) return cached;

    final yesterdayStr = _yesterdayDateString();
    final fallback = await _loadFromCache('news_briefs_$yesterdayStr');
    if (fallback != null && fallback.isNotEmpty) return fallback;

    return {};
  }

  /// Clears ALL news cache entries.
  Future<void> clearNewsCache() async {
    try {
      await CacheService().deleteAppSettingsByPrefix('news_briefs_');
      debugPrint('NewsBriefRepository: Cleared all news cache entries');
    } catch (e) {
      debugPrint('NewsBriefRepository: Failed to clear cache: $e');
    }
  }

  /// Queries Supabase for the latest fetched_at timestamp.
  Future<DateTime?> getLastFetchedAt() async {
    final ready = await _ensureInitialized();
    if (!ready || _client == null) return null;

    try {
      final res = await _client!
          .from('news_briefs')
          .select('fetched_at')
          .eq('is_active', true)
          .order('fetched_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty) {
        final raw = res[0]['fetched_at'];
        if (raw != null) {
          return DateTime.tryParse(raw.toString());
        }
      }
    } catch (e) {
      debugPrint('NewsBriefRepository: getLastFetchedAt failed: $e');
    }
    return null;
  }

  // ──────────────────── Private: Supabase ────────────────────

  /// Fetches news briefs from Supabase `news_briefs` table directly.
  /// Queries for today's date (fetched_date), active only, ordered by
  /// category and display_order.
  Future<Map<String, List<NewsBrief>>> _fetchFromSupabase(String cacheKey) async {
    final ready = await _ensureInitialized();
    if (!ready || _client == null) {
      debugPrint('NewsBriefRepository: Supabase client not available');
      return {};
    }

    try {
      // Query for the most recent fetched_date that has active articles
      final response = await _client!
          .from('news_briefs')
          .select()
          .eq('is_active', true)
          .order('fetched_date', ascending: false)
          .order('category')
          .order('display_order')
          .limit(200);

      if (response.isEmpty) {
        debugPrint('NewsBriefRepository: Supabase returned empty');
        return {};
      }

      debugPrint('NewsBriefRepository: Supabase returned ${response.length} rows');

      // Parse all rows
      final allBriefs = response
          .map((row) => NewsBrief.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      // Find the most recent fetched_date to use as "today's" data
      String? latestDate;
      for (final brief in allBriefs) {
        if (brief.fetchedDate.isNotEmpty) {
          if (latestDate == null || brief.fetchedDate.compareTo(latestDate) > 0) {
            latestDate = brief.fetchedDate;
          }
        }
      }

      if (latestDate == null) {
        debugPrint('NewsBriefRepository: No valid fetched_date found in data');
        return {};
      }

      debugPrint('NewsBriefRepository: Using latest fetched_date: $latestDate');

      // Filter to only the latest date's briefs
      final todayBriefs = allBriefs
          .where((b) => b.fetchedDate == latestDate)
          .toList();

      debugPrint('NewsBriefRepository: ${todayBriefs.length} briefs for date $latestDate');

      // Cache the result
      try {
        final jsonToCache = jsonEncode(todayBriefs.map((b) => b.toMap()).toList());
        await CacheService().saveAppSetting(cacheKey, jsonToCache);
        debugPrint('NewsBriefRepository: Cached ${todayBriefs.length} briefs');
      } catch (e) {
        debugPrint('NewsBriefRepository: Cache write failed: $e');
      }

      return _groupBriefsByCategory(todayBriefs);
    } catch (e) {
      debugPrint('NewsBriefRepository: Supabase query failed: $e');
      return {};
    }
  }

  /// Background refresh — non-blocking, best-effort.
  Future<void> _refreshInBackground(String cacheKey) async {
    try {
      await _fetchFromSupabase(cacheKey);
    } catch (e) {
      debugPrint('NewsBriefRepository: Background refresh failed: $e');
    }
  }

  // ──────────────────── Private: Cache ────────────────────

  /// Loads briefs from the local cache for the given key.
  Future<Map<String, List<NewsBrief>>?> _loadFromCache(String cacheKey) async {
    try {
      final cachedJson = await CacheService().getAppSetting(cacheKey);
      if (cachedJson == null || cachedJson.isEmpty) return null;

      final decoded = jsonDecode(cachedJson);
      if (decoded is! List || decoded.isEmpty) return null;

      final list = decoded
          .map((item) => NewsBrief.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      return _groupBriefsByCategory(list);
    } catch (e) {
      debugPrint('NewsBriefRepository: Cache read failed ($cacheKey): $e');
      return null;
    }
  }

  // ──────────────────── Private: Helpers ────────────────────

  /// Groups a flat list of NewsBrief items by category, filtering out
  /// placeholder/empty entries and sorting by displayOrder.
  Map<String, List<NewsBrief>> _groupBriefsByCategory(List<NewsBrief> list) {
    final Map<String, List<NewsBrief>> grouped = {};

    for (final brief in list) {
      // Filter out empty placeholder cards
      final headlineLower = brief.headline.trim().toLowerCase();
      final sourceLower = brief.sourceName.trim().toLowerCase();

      final isPlaceholder = brief.headline.trim().isEmpty ||
          headlineLower == 'none' ||
          headlineLower.contains('no articles found') ||
          headlineLower.contains('no article found') ||
          sourceLower == 'none';

      if (isPlaceholder) {
        debugPrint('NewsBriefRepository: Filtered out placeholder: "${brief.headline}"');
        continue;
      }

      grouped.putIfAbsent(brief.category, () => []);
      grouped[brief.category]!.add(brief);
    }

    // Sort each category's list by displayOrder
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }

    return grouped;
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayDateString() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }
}
