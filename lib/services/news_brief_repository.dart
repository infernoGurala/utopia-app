import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/news_brief.dart';
import '../models/news_category.dart';
import 'cache_service.dart';

class NewsBriefRepository {
  static final NewsBriefRepository _instance = NewsBriefRepository._internal();
  factory NewsBriefRepository() => _instance;
  NewsBriefRepository._internal();

  /// Fetches active news categories.
  /// First checks local cache. If missing, attempts to fetch from Supabase.
  /// If Supabase fails or offline, falls back to yesterday's cache, and then 
  /// to the hardcoded default list.
  Future<List<NewsCategory>> getActiveCategories() async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final cacheKey = 'news_categories_$todayStr';

    // 1. Check local CacheService
    try {
      final cachedJson = await CacheService().getAppSetting(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        debugPrint('NewsBriefRepository: Category Cache HIT for $todayStr');
        final decoded = jsonDecode(cachedJson);
        if (decoded is List) {
          return decoded.map((item) => NewsCategory.fromMap(Map<String, dynamic>.from(item))).toList();
        }
      }
    } catch (e) {
      debugPrint('NewsBriefRepository: Category cache read failed: $e');
    }

    // 2. Try fetching from Supabase
    try {
      debugPrint('NewsBriefRepository: Category Cache MISS. Fetching from Supabase...');
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('news_categories')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      if (response != null && response is List && response.isNotEmpty) {
        final list = response.map((row) => NewsCategory.fromMap(Map<String, dynamic>.from(row))).toList();

        // Cache the raw list
        try {
          final jsonToCache = jsonEncode(list.map((c) => c.toMap()).toList());
          await CacheService().saveAppSetting(cacheKey, jsonToCache);
          debugPrint('NewsBriefRepository: Successfully cached fresh Supabase categories');
        } catch (cacheErr) {
          debugPrint('NewsBriefRepository: Category cache write failed: $cacheErr');
        }

        return list;
      }
    } catch (e) {
      debugPrint('NewsBriefRepository: Supabase category fetch failed with exception: $e');
    }

    // 3. Fallback to yesterday's cache if today's is empty and DB failed
    try {
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final yesterdayKey = 'news_categories_$yesterdayStr';
      final cachedJson = await CacheService().getAppSetting(yesterdayKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        debugPrint('NewsBriefRepository: Category fallback to yesterday\'s cache HIT');
        final decoded = jsonDecode(cachedJson);
        if (decoded is List) {
          return decoded.map((item) => NewsCategory.fromMap(Map<String, dynamic>.from(item))).toList();
        }
      }
    } catch (e) {
      debugPrint('NewsBriefRepository: Stale category cache lookup failed: $e');
    }

    // 4. Ultimate hardcoded default fallback list
    debugPrint('NewsBriefRepository: Category ultimate fallback to default hardcoded list');
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

  /// Fetches the news briefs for today.
  /// First checks local cache. If missing, attempts to fetch from Supabase.
  /// If Supabase fails (e.g. table not created yet) or offline, falls back to a 
  /// beautifully curated set of local mock briefs for today.
  Future<Map<String, List<NewsBrief>>> getTodaysBriefs() async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final cacheKey = 'news_briefs_$todayStr';

    // 1. Check local CacheService
    try {
      final cachedJson = await CacheService().getAppSetting(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        debugPrint('NewsBriefRepository: Cache HIT for $todayStr');
        final decoded = jsonDecode(cachedJson);
        if (decoded is List) {
          final list = decoded.map((item) => NewsBrief.fromMap(Map<String, dynamic>.from(item))).toList();
          return _groupBriefsByCategory(list);
        }
      }
    } catch (e) {
      debugPrint('NewsBriefRepository: Cache read failed: $e');
    }

    // 2. Try fetching from Supabase
    try {
      debugPrint('NewsBriefRepository: Cache MISS. Fetching latest batch from Supabase...');
      final supabase = Supabase.instance.client;
      
      final latestBatchRes = await supabase
          .from('news_briefs')
          .select('fetched_at')
          .eq('is_active', true)
          .order('fetched_at', ascending: false)
          .limit(1);

      if (latestBatchRes != null && latestBatchRes is List && latestBatchRes.isNotEmpty) {
        final latestFetchedAt = latestBatchRes[0]['fetched_at'];
        debugPrint('NewsBriefRepository: Latest batch timestamp found: $latestFetchedAt');

        final response = await supabase
            .from('news_briefs')
            .select()
            .eq('fetched_at', latestFetchedAt)
            .eq('is_active', true)
            .order('display_order', ascending: true);

        debugPrint('NewsBriefRepository: Supabase response length: ${response is List ? response.length : "Not a list"}');

        if (response != null && response is List && response.isNotEmpty) {
          final list = response.map((row) => NewsBrief.fromMap(Map<String, dynamic>.from(row))).toList();
          
          // Cache the raw list
          try {
            final jsonToCache = jsonEncode(list.map((b) => b.toMap()).toList());
            await CacheService().saveAppSetting(cacheKey, jsonToCache);
            debugPrint('NewsBriefRepository: Successfully cached fresh Supabase briefs');
          } catch (cacheErr) {
            debugPrint('NewsBriefRepository: Cache write failed: $cacheErr');
          }

          return _groupBriefsByCategory(list);
        }
      } else {
        debugPrint('NewsBriefRepository: No active news briefings found in database');
      }
    } catch (e) {
      debugPrint('NewsBriefRepository: Supabase fetch failed with exception: $e');
    }

    // 3. Fallback to yesterday's cache if today's is empty and DB failed
    try {
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final yesterdayKey = 'news_briefs_$yesterdayStr';
      final cachedJson = await CacheService().getAppSetting(yesterdayKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        debugPrint('NewsBriefRepository: Fallback to yesterday\'s cache HIT');
        final decoded = jsonDecode(cachedJson);
        if (decoded is List) {
          final list = decoded.map((item) => NewsBrief.fromMap(Map<String, dynamic>.from(item))).toList();
          return _groupBriefsByCategory(list);
        }
      }
    } catch (e) {
      debugPrint('NewsBriefRepository: Stale cache lookup failed: $e');
    }

    // 4. Ultimate Fallback: Generate premium, curated local mock data for today!
    // Note: To avoid the cache trap, we NEVER cache local mock data. Only real Supabase data is cached.
    debugPrint('NewsBriefRepository: Generating high-quality local mock fallback briefs...');
    final mockBriefs = _generateMockBriefs(todayStr);
    return _groupBriefsByCategory(mockBriefs);
  }

  /// Clears today's news cache and fetches fresh briefs directly from Supabase.
  Future<Map<String, List<NewsBrief>>> forceRefreshTodaysBriefs() async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final cacheKey = 'news_briefs_$todayStr';

    // 1. Clear local cache
    try {
      await CacheService().deleteAppSetting(cacheKey);
      debugPrint('NewsBriefRepository: Cleared local cache for force refresh');
    } catch (e) {
      debugPrint('NewsBriefRepository: Cache clear failed: $e');
    }

    // 2. Fetch from Supabase
    try {
      debugPrint('NewsBriefRepository: Force fetching latest batch from Supabase...');
      final supabase = Supabase.instance.client;

      final latestBatchRes = await supabase
          .from('news_briefs')
          .select('fetched_at')
          .eq('is_active', true)
          .order('fetched_at', ascending: false)
          .limit(1);

      if (latestBatchRes != null && latestBatchRes is List && latestBatchRes.isNotEmpty) {
        final latestFetchedAt = latestBatchRes[0]['fetched_at'];
        debugPrint('NewsBriefRepository: Latest batch timestamp found for refresh: $latestFetchedAt');

        final response = await supabase
            .from('news_briefs')
            .select()
            .eq('fetched_at', latestFetchedAt)
            .eq('is_active', true)
            .order('display_order', ascending: true);

        debugPrint('NewsBriefRepository: Force fetch response length: ${response is List ? response.length : "Not a list"}');

        if (response != null && response is List && response.isNotEmpty) {
          final list = response.map((row) => NewsBrief.fromMap(Map<String, dynamic>.from(row))).toList();
          
          // Cache the raw list
          try {
            final jsonToCache = jsonEncode(list.map((b) => b.toMap()).toList());
            await CacheService().saveAppSetting(cacheKey, jsonToCache);
            debugPrint('NewsBriefRepository: Successfully cached fresh Supabase briefs after force refresh');
          } catch (cacheErr) {
            debugPrint('NewsBriefRepository: Cache write failed: $cacheErr');
          }

          return _groupBriefsByCategory(list);
        }
      } else {
        debugPrint('NewsBriefRepository: No active news briefings found for force refresh');
      }
    } catch (e) {
      debugPrint('NewsBriefRepository: Force fetch from Supabase failed with exception: $e');
    }

    // 3. Fallback to today's mock data (WITHOUT caching it)
    debugPrint('NewsBriefRepository: Force refresh fallback to local mock data');
    final mockBriefs = _generateMockBriefs(todayStr);
    return _groupBriefsByCategory(mockBriefs);
  }

  /// Queries Supabase for the latest fetched_at timestamp (last edge function run).
  Future<DateTime?> getLastFetchedAt() async {
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('news_briefs')
          .select('fetched_at')
          .eq('is_active', true)
          .order('fetched_at', ascending: false)
          .limit(1);

      debugPrint('NewsBriefRepository: getLastFetchedAt raw response: $res');
      if (res is List && res.isNotEmpty) {
        final raw = res[0]['fetched_at'];
        debugPrint('NewsBriefRepository: getLastFetchedAt raw value: $raw');
        if (raw != null) {
          return DateTime.tryParse(raw.toString());
        }
      }
    } catch (e) {
      debugPrint('NewsBriefRepository: getLastFetchedAt failed: $e');
    }
    return null;
  }

  /// Groups a flat list of NewsBrief items by their category field dynamically.
  Map<String, List<NewsBrief>> _groupBriefsByCategory(List<NewsBrief> list) {
    final Map<String, List<NewsBrief>> grouped = {};
    final now = DateTime.now();

    for (final brief in list) {
      // Filter out empty placeholder cards generated by the AI when no articles were found
      final headlineLower = brief.headline.trim().toLowerCase();
      final sourceLower = brief.sourceName.trim().toLowerCase();
      
      final isPlaceholder = brief.headline.isEmpty ||
          headlineLower == "none" ||
          headlineLower.contains("no articles found") ||
          headlineLower.contains("no article found") ||
          sourceLower == "none";

      if (isPlaceholder) {
        debugPrint('NewsBriefRepository: Filtered out empty placeholder brief under category "${brief.category}"');
        continue;
      }

      // Filter out news briefs older than 24 hours (age >= 24h)
      final age = now.difference(brief.publishedAt);
      if (age.inHours >= 24) {
        debugPrint('NewsBriefRepository: Filtered out stale brief (> 24h old): "${brief.headline}" (${brief.publishedAt})');
        continue;
      }

      if (!grouped.containsKey(brief.category)) {
        grouped[brief.category] = [];
      }
      grouped[brief.category]!.add(brief);
    }

    // Sort categories' lists by displayOrder
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }

    return grouped;
  }

  /// Generates a set of wowed mock news briefs for todays date.
  List<NewsBrief> _generateMockBriefs(String todayStr) {
    final List<NewsBrief> briefs = [];
    final now = DateTime.now();

    // ── WORLD ──
    briefs.add(NewsBrief(
      id: 'mock-w1',
      category: 'world',
      sourceName: 'Reuters',
      originalTitle: 'Global Climate Summit Reaches Landmark Accord on Renewable Subsidies',
      headline: 'Global Climate Summit Reaches Landmark Accord on Green Subsidies',
      keyFact: 'Over 140 nations agreed to triple clean energy funding by 2030.',
      summary: 'Delegates at the global climate summit have finalized a historic agreement. The deal mandates an unprecedented acceleration of wind and solar infrastructure. Economists estimate the initiative will mobilize \$2.5 trillion in private sector climate investments.',
      publishedAt: now.subtract(const Duration(hours: 2)),
      fetchedDate: todayStr,
      displayOrder: 1,
      imageUrl: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=500',
    ));
    briefs.add(NewsBrief(
      id: 'mock-w2',
      category: 'world',
      sourceName: 'BBC',
      originalTitle: 'SpaceX Starship Successfully Completes First Fully Reusable Orbital Test Flight',
      headline: 'SpaceX Starship Completes Historic Fully Reusable Orbital Flight',
      keyFact: 'Both booster and spacecraft achieved flawless ocean splashdown landings.',
      summary: 'SpaceX\'s giant Starship rocket successfully flew around the Earth before splashing down in the Indian Ocean. This landmark orbital flight marks the first time both stages have completed controlled recovery descents. Mars missions are now targeted for 2028.',
      publishedAt: now.subtract(const Duration(hours: 4)),
      fetchedDate: todayStr,
      displayOrder: 2,
      imageUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=500',
    ));
    briefs.add(NewsBrief(
      id: 'mock-w3',
      category: 'world',
      sourceName: 'AP News',
      originalTitle: 'Deep-Sea Expedition Discovers 50 New Marine Species in Mariana Trench',
      headline: 'Deep-Sea Probe Finds 50 New Marine Species in Mariana Trench',
      keyFact: 'Bioluminescent organisms discovered at depths exceeding 8,000 meters.',
      summary: 'An oceanographic research vessel has mapped undocumented hydrothermal ecosystems. Robotic submersibles recovered genetic samples of previously unclassified organisms. Scientists believe these findings could unlock breakthroughs in biochemistry and marine pharmacology.',
      publishedAt: now.subtract(const Duration(hours: 6)),
      fetchedDate: todayStr,
      displayOrder: 3,
    ));

    // ── SCIENCE & TECH ──
    briefs.add(NewsBrief(
      id: 'mock-t1',
      category: 'tech',
      sourceName: 'TechCrunch',
      originalTitle: 'OpenAI Unveils GPT-5 featuring Real-time Multimodal Reasoning Engine',
      headline: 'OpenAI Launches GPT-5 with Real-Time Reasoning Engine',
      keyFact: 'The model achieves near-human performance in advanced mathematical reasoning.',
      summary: 'OpenAI has released its next-generation artificial intelligence model. The architecture natively processes video, code, and audio inputs simultaneously. Developers report response latencies have dropped by 60%, opening up applications in live diagnostics.',
      publishedAt: now.subtract(const Duration(hours: 1)),
      fetchedDate: todayStr,
      displayOrder: 1,
      imageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500',
    ));
    briefs.add(NewsBrief(
      id: 'mock-t2',
      category: 'tech',
      sourceName: 'The Verge',
      originalTitle: 'Apple Announces First Solid-State Battery MacBook with 48-Hour Life',
      headline: 'Apple Announces Solid-State Battery MacBook with 48-Hour Battery Life',
      keyFact: 'New silicon and solid batteries double battery capacity without adding weight.',
      summary: 'Apple shocked the PC industry by unveiling a MacBook powered by solid-state battery technology. The laptop maintains a super-thin profile while offering two full days of intensive runtime. Thermal efficiency improvements have also completely eliminated cooling fans.',
      publishedAt: now.subtract(const Duration(hours: 3)),
      fetchedDate: todayStr,
      displayOrder: 2,
      imageUrl: 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=500',
    ));
    briefs.add(NewsBrief(
      id: 'mock-t3',
      category: 'tech',
      sourceName: 'Reuters Tech',
      originalTitle: 'Quantum Computing Startup Achieves 1000 Logical Qubits Milestone',
      headline: 'Quantum Startup Achieves 1,000 Logical Qubits Milestone',
      keyFact: 'Advanced error correction unlocks active simulation of molecular structures.',
      summary: 'A leading quantum hardware firm has demonstrated a processor with active error correction. The 1000-logical-qubit benchmark allows researchers to run complex chemical simulations. This milestone drastically accelerates discovery times for sustainable battery materials.',
      publishedAt: now.subtract(const Duration(hours: 5)),
      fetchedDate: todayStr,
      displayOrder: 3,
    ));

    // ── ECONOMY ──
    briefs.add(NewsBrief(
      id: 'mock-e1',
      category: 'economy',
      sourceName: 'Bloomberg',
      originalTitle: 'Federal Reserve Holds Rates Steady and Signals Multiple Cuts in Q3',
      headline: 'Federal Reserve Signals Multiple Rate Cuts Starting Q3',
      keyFact: 'Core inflation dropped closer to the central bank\'s 2.0% target.',
      summary: 'The U.S. central bank kept interest rates unchanged at its meeting today. However, the Chairman confirmed that macroeconomic cooling justifies policy easing. Wall Street reacted positively with indices rising to all-time highs on rate cut expectations.',
      publishedAt: now.subtract(const Duration(hours: 2)),
      fetchedDate: todayStr,
      displayOrder: 1,
      imageUrl: 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=500',
    ));
    briefs.add(NewsBrief(
      id: 'mock-e2',
      category: 'economy',
      sourceName: 'Reuters',
      originalTitle: 'Global Semiconductor Supply Chain Fully Stabilizes, Lowering Chip Costs',
      headline: 'Global Semiconductor Chain Stabilizes, Slashing Tech Costs',
      keyFact: 'Manufacturing additions in Asia and US have ended years of chip shortages.',
      summary: 'Industrial surveys show global microchip lead times have returned to normal. New fabrication plants have added vast production capacities. Hardware manufacturers anticipate minor retail price reductions on consumer electronics throughout the year.',
      publishedAt: now.subtract(const Duration(hours: 4)),
      fetchedDate: todayStr,
      displayOrder: 2,
    ));
    briefs.add(NewsBrief(
      id: 'mock-e3',
      category: 'economy',
      sourceName: 'BBC Business',
      originalTitle: 'European Central Bank Announces Digital Euro Pilot Phase Success',
      headline: 'ECB Declares Digital Euro Pilot Program A Success',
      keyFact: 'Trial achieved instant settlement speeds across multiple European borders.',
      summary: 'The European Central Bank completed its cross-border retail payments test. Over 500,000 transactions were successfully processed using a secure digital ledger. Officials are now drafting a regulatory framework for public deployment by late 2027.',
      publishedAt: now.subtract(const Duration(hours: 7)),
      fetchedDate: todayStr,
      displayOrder: 3,
    ));

    // ── SPORTS ──
    briefs.add(NewsBrief(
      id: 'mock-s1',
      category: 'sports',
      sourceName: 'ESPN',
      originalTitle: 'Olympic Committee Announces Inclusion of E-Sports for 2028 Games',
      headline: 'IOC Approves E-Sports for 2028 Los Angeles Olympics',
      keyFact: 'Strict guidelines implemented to exclude games containing graphic violence.',
      summary: 'The International Olympic Committee voted to add virtual sports to the 2028 lineup. Competitive structures will be co-organized with international gaming associations. This historic shift aims to engage younger global demographics in traditional athletic festivals.',
      publishedAt: now.subtract(const Duration(hours: 3)),
      fetchedDate: todayStr,
      displayOrder: 1,
      imageUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=500',
    ));
    briefs.add(NewsBrief(
      id: 'mock-s2',
      category: 'sports',
      sourceName: 'BBC Sport',
      originalTitle: 'Real Madrid Clinches Historic 16th UEFA Champions League Title',
      headline: 'Real Madrid Secures Historic 16th Champions League Crown',
      keyFact: 'Stunning late double-strike completed a dramatic 2-1 comeback.',
      summary: 'Real Madrid demonstrated their European pedigree once again in London. Trailing until the 84th minute, two counter-attacking goals turned the match around. Fans celebrated late into the night across Spain as historic milestones were established.',
      publishedAt: now.subtract(const Duration(hours: 5)),
      fetchedDate: todayStr,
      displayOrder: 2,
    ));
    briefs.add(NewsBrief(
      id: 'mock-s3',
      category: 'sports',
      sourceName: 'Reuters',
      originalTitle: 'Formula 1 Unveils 100% Sustainable Fuel Regulations for Next Season',
      headline: 'Formula 1 Mandates 100% Sustainable Fuels from Next Season',
      keyFact: 'Synthetic bio-fuels will match performance of current petroleum fuels.',
      summary: 'Formula 1 organizers announced mandatory eco-fuel rules starting next championship. The new carbon-neutral fuels will be manufactured from municipal waste and carbon capture. This initiative forms the cornerstone of F1\'s Net-Zero Carbon 2030 plan.',
      publishedAt: now.subtract(const Duration(hours: 8)),
      fetchedDate: todayStr,
      displayOrder: 3,
    ));

    // ── CULTURE ──
    briefs.add(NewsBrief(
      id: 'mock-c1',
      category: 'culture',
      sourceName: 'BBC Culture',
      originalTitle: 'Metropolitan Museum of Art Restores Lost Leonardo da Vinci Sketch',
      headline: 'Metropolitan Museum Restores Unknown Da Vinci Sketch',
      keyFact: 'Infrared imaging verified underdrawing beneath a 16th-century painting.',
      summary: 'Art curators have successfully uncovered a hidden sketch by Leonardo da Vinci. The drawing was hidden under layers of paint on a secondary Renaissance canvas. The restored sketch will be unveiled in a special public exhibition starting next month.',
      publishedAt: now.subtract(const Duration(hours: 4)),
      fetchedDate: todayStr,
      displayOrder: 1,
    ));
    briefs.add(NewsBrief(
      id: 'mock-c2',
      category: 'culture',
      sourceName: 'Reuters',
      originalTitle: 'Cannes Film Festival Awards Palme d\'Or to Independent Sci-Fi Masterpiece',
      headline: 'Palme d\'Or Awarded to Independent Sci-Fi Masterpiece',
      keyFact: 'First low-budget science fiction film to win the top prize.',
      summary: 'The prestigious Cannes jury surprised critics by awarding the Palme d\'Or to a sci-fi film. The movie was praised for its deep philosophical themes and practical visual effects. Audiences gave the director an emotional ten-minute standing ovation during the ceremony.',
      publishedAt: now.subtract(const Duration(hours: 6)),
      fetchedDate: todayStr,
      displayOrder: 2,
    ));
    briefs.add(NewsBrief(
      id: 'mock-c3',
      category: 'culture',
      sourceName: 'AP Arts',
      originalTitle: 'Global Book Sales Surge as Physical Reading Rooms Gain Popularity',
      headline: 'Global Book Sales Surge as Physical Reading Rooms Trend',
      keyFact: 'Independent bookstores report a 35% growth in physical sales.',
      summary: 'A cultural survey highlights a dramatic resurgence in physical book reading. Younger demographics are establishing offline book clubs and quiet cafes in major cities. Publishers are responding by increasing the production of high-quality hardcover editions.',
      publishedAt: now.subtract(const Duration(hours: 9)),
      fetchedDate: todayStr,
      displayOrder: 3,
    ));

    // ── INDIA ──
    briefs.add(NewsBrief(
      id: 'mock-i1',
      category: 'india',
      sourceName: 'The Hindu',
      originalTitle: 'ISRO Successfully Launches Aditya-L2 Solar Mission with Advanced Payloads',
      headline: 'ISRO Successfully Launches Aditya-L2 Solar Observatory',
      keyFact: 'Launch vehicle successfully inserted satellite into precise Lagrange orbit.',
      summary: 'The Indian Space Research Organisation has successfully launched Aditya-L2. The scientific mission is equipped with highly sensitive instruments to study solar winds. Telemetry data indicates all solar panel arrays have deployed flawlessly.',
      publishedAt: now.subtract(const Duration(hours: 2)),
      fetchedDate: todayStr,
      displayOrder: 1,
      imageUrl: 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=500',
    ));
    briefs.add(NewsBrief(
      id: 'mock-i2',
      category: 'india',
      sourceName: 'NDTV',
      originalTitle: 'India Achieves 50% Renewable Energy Capacity Target Ahead of Schedule',
      headline: 'India Hits 50% Renewable Power Goal Ahead of Target',
      keyFact: 'Massive solar park expansions in western deserts accelerated the milestone.',
      summary: 'The Ministry of Power announced that India has met its clean energy target early. Total solar and wind installations have crossed 250 gigawatts of capacity. Focus now shifts to deploying large-scale battery storage facilities across grid networks.',
      publishedAt: now.subtract(const Duration(hours: 4)),
      fetchedDate: todayStr,
      displayOrder: 2,
    ));
    briefs.add(NewsBrief(
      id: 'mock-i3',
      category: 'india',
      sourceName: 'Press Trust of India',
      originalTitle: 'National High-Speed Rail Corridor Expansion Approved for South India',
      headline: 'Cabinet Approves High-Speed Rail Corridor for South India',
      keyFact: '350 km/h bullet train link will connect Bangalore and Hyderabad.',
      summary: 'The Union Cabinet has approved a mega high-speed rail corridor project. The dedicated track will reduce commute times between major tech hubs to two hours. Construction contracts will prioritize indigenous manufacturing and engineering skills.',
      publishedAt: now.subtract(const Duration(hours: 6)),
      fetchedDate: todayStr,
      displayOrder: 3,
    ));

    return briefs;
  }
}
