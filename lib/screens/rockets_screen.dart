import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../main.dart';
import '../services/focus_supabase_service.dart';

class RocketsScreen extends StatefulWidget {
  const RocketsScreen({super.key});

  @override
  State<RocketsScreen> createState() => _RocketsScreenState();
}

class _RocketsScreenState extends State<RocketsScreen> {
  final _supabaseService = FocusSupabaseService();
  List<Map<String, dynamic>> _rockets = [];
  bool _isLoadingList = true;
  Timer? _pollingTimer;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadRockets();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRockets() async {
    if (_userId.isEmpty) return;
    try {
      await _supabaseService.initialize();
      if (_supabaseService.client == null) {
        if (mounted) setState(() => _isLoadingList = false);
        return;
      }

      final data = await _supabaseService.client!
          .from('focus_rockets')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _rockets = List<Map<String, dynamic>>.from(data as List);
          _isLoadingList = false;
        });
        _checkAndStartPolling();
      }
    } catch (e) {
      debugPrint('Rockets: Failed to load rockets: $e');
      if (mounted) {
        setState(() => _isLoadingList = false);
      }
    }
  }

  void _checkAndStartPolling() {
    final hasGenerating = _rockets.any((r) {
      final urls = r['supabase_audio_urls'] as List?;
      return urls == null || urls.isEmpty;
    });

    if (hasGenerating) {
      if (_pollingTimer == null || !_pollingTimer!.isActive) {
        _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }
          await _pollRocketsStatus();
        });
      }
    } else {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  Future<void> _pollRocketsStatus() async {
    if (_userId.isEmpty || _supabaseService.client == null) return;
    try {
      final data = await _supabaseService.client!
          .from('focus_rockets')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false);

      if (mounted) {
        final newRockets = List<Map<String, dynamic>>.from(data as List);
        
        bool completedAny = false;
        for (final nr in newRockets) {
          final oldr = _rockets.firstWhere((r) => r['id'] == nr['id'], orElse: () => {});
          if (oldr.isNotEmpty) {
            final oldUrls = oldr['supabase_audio_urls'] as List?;
            final newUrls = nr['supabase_audio_urls'] as List?;
            final wasGenerating = oldUrls == null || oldUrls.isEmpty;
            final isDone = newUrls != null && newUrls.isNotEmpty;
            if (wasGenerating && isDone) {
              completedAny = true;
            }
          }
        }

        setState(() {
          _rockets = newRockets;
        });

        if (completedAny) {
          HapticFeedback.lightImpact();
        }

        _checkAndStartPolling();
      }
    } catch (e) {
      debugPrint('Rockets polling failed: $e');
    }
  }

  Future<void> _deleteRocket(String rocketId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: Text(
          'Delete Rocket',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete this Rocket session?',
          style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.dim, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.outfit(color: U.red, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (_supabaseService.client != null) {
          await _supabaseService.client!.from('focus_rockets').delete().eq('id', rocketId);
          setState(() {
            _rockets.removeWhere((r) => r['id'] == rocketId);
          });
          _checkAndStartPolling();
        }
      } catch (e) {
        debugPrint('Failed to delete rocket: $e');
      }
    }
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateRocketSheet(
        userId: _userId,
        supabaseService: _supabaseService,
        onCreated: () {
          _loadRockets();
        },
      ),
    );
  }

  void _openPlayer(Map<String, dynamic> rocket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmbeddedPlayerScreen(
          rocket: rocket,
          userId: _userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: U.surface,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: U.bg,
        appBar: AppBar(
          backgroundColor: U.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          ),
          title: Text(
            'Rockets',
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _openCreateSheet,
              icon: Icon(Icons.add_rounded, color: U.primary, size: 24),
              tooltip: 'New Rocket',
            ),
          ],
        ),
        body: _isLoadingList
            ? Center(
                child: CircularProgressIndicator(color: U.primary, strokeWidth: 2.5),
              )
            : _rockets.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rocket_launch_outlined, color: U.dim.withValues(alpha: 0.5), size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'No rockets generated yet',
                            style: GoogleFonts.outfit(color: U.text, fontSize: 15, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create a rocket session by pasting text. The server will synthesize TTS speech slide-by-slide in the background.',
                            style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _openCreateSheet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: U.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            label: Text(
                              'CREATE ROCKET',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: _rockets.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final r = _rockets[index];
                      final urls = r['supabase_audio_urls'] as List?;
                      final isGenerating = urls == null || urls.isEmpty;
                      
                      final voiceName = (r['voice'] as String? ?? 'af_bella')
                          .replaceAll('af_', '')
                          .replaceAll('am_', '')
                          .replaceAll('bf_', '')
                          .replaceAll('bm_', '');
                      final speedVal = r['speed'] ?? 1.0;
                      final wordCount = (r['raw_text'] as String? ?? '').trim().split(RegExp(r'\s+')).length;
                      
                      return GestureDetector(
                        onTap: isGenerating ? null : () => _openPlayer(r),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: U.card,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: U.border, width: 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            r['title'] ?? 'Untitled Rocket',
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.newsreader(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400,
                                              fontStyle: FontStyle.italic,
                                              color: U.text,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ),
                                        if (isGenerating) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: U.peach.withValues(alpha: 0.1),
                                              border: Border.all(color: U.peach.withValues(alpha: 0.3), width: 0.5),
                                            ),
                                            child: Text(
                                              'GENERATING',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: U.peach,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.5.seconds),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _deleteRocket(r['id']),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.delete_outline_rounded, color: U.dim, size: 18),
                                    tooltip: 'Delete Rocket',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r['raw_text'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: U.sub,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '$wordCount words',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: U.dim, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '•',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: U.dim),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '$voiceName (${speedVal}x)',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: U.dim, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  if (isGenerating)
                                    Text(
                                      'synthesizing speech…',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        color: U.peach,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 800.ms).fadeOut(delay: 600.ms, duration: 800.ms)
                                  else
                                    Text(
                                      r['created_at'] != null 
                                          ? DateTime.parse(r['created_at']).toLocal().toString().split(' ')[0]
                                          : '',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: U.dim),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _CreateRocketSheet extends StatefulWidget {
  final String userId;
  final FocusSupabaseService supabaseService;
  final VoidCallback onCreated;

  const _CreateRocketSheet({
    required this.userId,
    required this.supabaseService,
    required this.onCreated,
  });

  @override
  State<_CreateRocketSheet> createState() => _CreateRocketSheetState();
}

class _CreateRocketSheetState extends State<_CreateRocketSheet> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  String _selectedVoice = 'af_bella';
  double _selectedSpeed = 1.0;
  bool _isCreating = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final text = _textController.text.trim();
    if (title.isEmpty || text.isEmpty) {
      setState(() => _errorMessage = 'Please complete all fields.');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = '';
    });

    try {
      final rocketId = const Uuid().v4();
      
      // 1. Immediately insert placeholder record natively in Supabase so user gets live visual feedback
      if (widget.supabaseService.client != null) {
        await widget.supabaseService.client!.from('focus_rockets').insert({
          'id': rocketId,
          'user_id': widget.userId,
          'title': title,
          'raw_text': text,
          'voice': _selectedVoice,
          'speed': _selectedSpeed,
          'timings': [],
          'groq_styles': [],
          'supabase_audio_urls': [],
          'cloudinary_audio_urls': []
        });
      }

      // 2. Fetch connection secrets from Firestore and Remote Config
      final doc = await FirebaseFirestore.instance.collection('config').doc('supabase-focus-1').get();
      final supabaseUrl = doc.data()?['url'] as String? ?? '';
      final supabaseAnonKey = doc.data()?['anon_key'] as String? ?? '';

      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();
      final cloudName = remoteConfig.getString('cloudinary_cloud_name');
      final apiKey = remoteConfig.getString('cloudinary_api_key');
      final apiSecret = remoteConfig.getString('cloudinary_api_secret');

      // 3. Post fire-and-forget payload directly to our FastAPI Kokoro TTS server
      final response = await http.post(
        Uri.parse('https://infernoGurala-rocket-tts.hf.space/api/rockets/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'raw_text': text,
          'voice': _selectedVoice,
          'speed': _selectedSpeed,
          'user_id': widget.userId,
          'rocket_id': rocketId,
          'supabase_url': supabaseUrl,
          'supabase_anon_key': supabaseAnonKey,
          'cloudinary_cloud_name': cloudName,
          'cloudinary_api_key': apiKey,
          'cloudinary_api_secret': apiSecret,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('TTS engine synthesis start rejected by server.');
      }

      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Failed to launch rocket synthesis: $e');
      setState(() {
        _isCreating = false;
        _errorMessage = 'Failed to initiate background synthesis. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: U.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: U.border, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Launch New Rocket',
                style: GoogleFonts.outfit(color: U.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close_rounded, color: U.dim, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_errorMessage.isNotEmpty) ...[
            Text(_errorMessage, style: GoogleFonts.plusJakartaSans(color: U.red, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _titleController,
            style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Session Title',
              labelStyle: GoogleFonts.outfit(color: U.dim, fontSize: 12),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: U.border, width: 0.5)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: U.primary, width: 0.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            maxLines: 5,
            style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Reading Material Content',
              labelStyle: GoogleFonts.outfit(color: U.dim, fontSize: 12),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: U.border, width: 0.5)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: U.primary, width: 0.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEURAL VOICE', style: GoogleFonts.outfit(color: U.dim, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedVoice,
                      dropdownColor: U.surface,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: U.border, width: 0.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 12.5, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'af_bella', child: Text('Bella (US Female)')),
                        DropdownMenuItem(value: 'af_sarah', child: Text('Sarah (US Female)')),
                        DropdownMenuItem(value: 'am_adam', child: Text('Adam (US Male)')),
                        DropdownMenuItem(value: 'bf_emma', child: Text('Emma (UK Female)')),
                        DropdownMenuItem(value: 'bm_george', child: Text('George (UK Male)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedVoice = v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TARGET SPEED', style: GoogleFonts.outfit(color: U.dim, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<double>(
                      value: _selectedSpeed,
                      dropdownColor: U.surface,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: U.border, width: 0.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 12.5, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                        DropdownMenuItem(value: 0.9, child: Text('0.9x')),
                        DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                        DropdownMenuItem(value: 1.15, child: Text('1.15x')),
                        DropdownMenuItem(value: 1.3, child: Text('1.3x')),
                        DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedSpeed = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: U.primary,
                disabledBackgroundColor: U.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 0,
              ),
              child: _isCreating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      'LAUNCH SPEECH READER',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class WordToken {
  final String word;
  final int startIndex;
  final int endIndex;
  final String className;
  final double startTime;
  final double endTime;

  WordToken({
    required this.word,
    required this.startIndex,
    required this.endIndex,
    required this.className,
    required this.startTime,
    required this.endTime,
  });
}

List<String> parseText(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  final result = <String>[];
  final lines = raw.split(RegExp(r'\n+'));
  for (final line in lines) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty) continue;
    final sentences = trimmedLine.split(RegExp(r'(?<=[.!?])\s+'));
    for (final s in sentences) {
      final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (t.length > 1) {
        result.add(t);
      }
    }
  }
  return result;
}

const Set<String> _stopWords = {
  'a','an','the','is','are','was','were','be','been','being','have','has','had','do','does','did','will','would','could','should','may','might','shall','can','it','its','this','that','these','those','i','we','you','he','she','they','me','us','him','her','them','my','our','your','his','their','what','which','who','whom','whose','when','where','why','how','all','both','each','few','more','most','other','some','such','no','nor','not','only','own','same','so','than','too','very','just','but','and','or','for','of','to','in','on','at','by','as','with','from','up','about','into','through','during','before','after','above','below','between','out','off','over','under','then','once','here','there','any','also','if','although','because','since','while','though'
};

int getKeyScore(String w) {
  final c = w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (c.length <= 2 || _stopWords.contains(c)) return 0;
  if (c.length >= 8) return 3;
  if (c.length >= 5) return 2;
  return 1;
}

String classifyWord(String word, List<String> lineWords, int idx) {
  final w = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (w.length <= 2 || _stopWords.contains(w)) return 'w-plain';
  if (idx > 0 && word.isNotEmpty && word[0] == word[0].toUpperCase() && RegExp(r'[A-Z]').hasMatch(word[0])) {
    return 'w-term';
  }
  
  final scored = <MapEntry<int, int>>[];
  for (int i = 0; i < lineWords.length; i++) {
    final score = getKeyScore(lineWords[i]);
    if (score > 0) {
      scored.add(MapEntry(i, score));
    }
  }
  
  if (scored.isEmpty) return 'w-plain';
  scored.sort((a, b) => b.value.compareTo(a.value));
  
  final topN = (scored.length * 0.35).ceil().clamp(1, scored.length);
  final topIdx = scored.take(topN).map((x) => x.key).toSet();
  
  if (topIdx.contains(idx)) {
    return getKeyScore(word) >= 3 ? 'w-key' : 'w-strong';
  }
  return 'w-plain';
}

List<WordToken> prepareWordTokens(String text, Map<String, dynamic>? groqStyles, List<dynamic>? slideTimings) {
  if (text.trim().isEmpty) return [];
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final tokens = <WordToken>[];
  int searchIndex = 0;

  for (int i = 0; i < words.length; i++) {
    final w = words[i];
    int idx = text.indexOf(w, searchIndex);
    if (idx == -1) {
      idx = text.toLowerCase().indexOf(w.toLowerCase(), searchIndex);
    }
    if (idx == -1) {
      idx = searchIndex;
    }

    String className = 'w-plain';
    if (groqStyles != null) {
      final normalized = w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (groqStyles[normalized] != null) {
        className = groqStyles[normalized] as String;
      } else {
        className = classifyWord(w, words, i);
      }
    } else {
      className = classifyWord(w, words, i);
    }

    double start = 0;
    double end = 0;
    if (slideTimings != null && i < slideTimings.length) {
      final timing = slideTimings[i];
      if (timing is Map) {
        start = (timing['start'] ?? 0).toDouble();
        end = (timing['end'] ?? 0).toDouble();
      }
    }

    tokens.add(WordToken(
      word: w,
      startIndex: idx,
      endIndex: idx + w.length,
      className: className,
      startTime: start,
      endTime: end,
    ));

    searchIndex = idx + w.length;
  }

  return tokens;
}

class EmbeddedPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> rocket;
  final String userId;

  const EmbeddedPlayerScreen({
    super.key,
    required this.rocket,
    required this.userId,
  });

  @override
  State<EmbeddedPlayerScreen> createState() => _EmbeddedPlayerScreenState();
}

class _EmbeddedPlayerScreenState extends State<EmbeddedPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _slides = [];
  int _currentSlideIndex = 0;
  List<WordToken> _currentTokens = [];
  int _activeWordIndex = -1;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  bool _isLoadingAudio = false;
  String? _errorMessage;

  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _slides = parseText(widget.rocket['raw_text'] as String?);

    _positionSubscription = _audioPlayer.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _audioPosition = pos;
        });
      }
      _highlightWordAtTime(pos.inMilliseconds.toDouble());
    });

    _audioPlayer.durationStream.listen((dur) {
      if (mounted && dur != null) {
        setState(() {
          _audioDuration = dur;
        });
      }
    });

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
      if (state.processingState == ProcessingState.completed) {
        _handleSlideEnded();
      }
    });

    _playbackSpeed = (widget.rocket['speed'] as num?)?.toDouble() ?? 1.0;
    _playSlide(0);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _highlightWordAtTime(double elapsedMs) {
    if (_currentTokens.isEmpty) return;
    int activeIdx = -1;
    for (int i = 0; i < _currentTokens.length; i++) {
      final token = _currentTokens[i];
      if (elapsedMs >= token.startTime && elapsedMs < token.endTime) {
        activeIdx = i;
        break;
      }
    }
    if (activeIdx != _activeWordIndex) {
      if (mounted) {
        setState(() {
          _activeWordIndex = activeIdx;
        });
      }
    }
  }

  void _handleSlideEnded() {
    final nextSlide = _currentSlideIndex + 1;
    if (nextSlide < _slides.length) {
      _playSlide(nextSlide);
    } else {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _activeWordIndex = -1;
        });
      }
    }
  }

  Future<void> _playSlide(int slideIndex) async {
    if (_slides.isEmpty || slideIndex < 0 || slideIndex >= _slides.length) return;

    setState(() {
      _currentSlideIndex = slideIndex;
      _isLoadingAudio = true;
      _errorMessage = null;
      _activeWordIndex = -1;
      _audioPosition = Duration.zero;
      _audioDuration = Duration.zero;
    });

    try {
      final urls = widget.rocket['supabase_audio_urls'] as List?;
      final fallbackUrls = widget.rocket['cloudinary_audio_urls'] as List?;

      String? audioUrl;
      if (urls != null && slideIndex < urls.length) {
        audioUrl = urls[slideIndex] as String?;
      }
      if ((audioUrl == null || audioUrl.isEmpty) && fallbackUrls != null && slideIndex < fallbackUrls.length) {
        audioUrl = fallbackUrls[slideIndex] as String?;
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception("No audio file generated for slide $slideIndex yet.");
      }

      final slideText = _slides[slideIndex];
      Map<String, dynamic>? groqStyles;
      final stylesList = widget.rocket['groq_styles'] as List?;
      if (stylesList != null && slideIndex < stylesList.length) {
        final styles = stylesList[slideIndex];
        if (styles is Map) {
          groqStyles = Map<String, dynamic>.from(styles);
        }
      }

      List<dynamic>? timings;
      final timingsList = widget.rocket['timings'] as List?;
      if (timingsList != null && slideIndex < timingsList.length) {
        final timingData = timingsList[slideIndex];
        if (timingData is List) {
          timings = timingData;
        }
      }

      setState(() {
        _currentTokens = prepareWordTokens(slideText, groqStyles, timings);
      });

      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.setSpeed(_playbackSpeed);

      if (_isPlaying) {
        _audioPlayer.play();
      }

      setState(() {
        _isLoadingAudio = false;
      });
    } catch (e) {
      debugPrint("Native Player Slide Load Error: $e");
      setState(() {
        _isLoadingAudio = false;
        _errorMessage = "Unable to stream audio for this slide.";
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      if (_audioPlayer.processingState == ProcessingState.idle) {
        _playSlide(_currentSlideIndex);
      } else {
        _audioPlayer.play();
      }
    }
  }

  void _seekToWord(int wordIdx) {
    if (wordIdx < 0 || wordIdx >= _currentTokens.length) return;
    final token = _currentTokens[wordIdx];
    _audioPlayer.seek(Duration(milliseconds: token.startTime.toInt()));
    setState(() {
      _activeWordIndex = wordIdx;
    });
  }

  void _handlePrevSlide() {
    if (_currentSlideIndex > 0) {
      _playSlide(_currentSlideIndex - 1);
    }
  }

  void _handleNextSlide() {
    if (_currentSlideIndex < _slides.length - 1) {
      _playSlide(_currentSlideIndex + 1);
    }
  }

  void _handleSpeedChange(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    _audioPlayer.setSpeed(speed);
  }

  TextStyle _getWordStyle(String className) {
    switch (className) {
      case 'w-key':
        return GoogleFonts.plusJakartaSans(
          color: U.peach,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        );
      case 'w-strong':
        return GoogleFonts.plusJakartaSans(
          color: U.teal,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        );
      case 'w-term':
        return GoogleFonts.plusJakartaSans(
          color: U.gold,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        );
      case 'w-plain':
      default:
        return GoogleFonts.plusJakartaSans(
          color: U.text.withValues(alpha: 0.8),
          fontSize: 20,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _audioDuration.inMilliseconds > 0
        ? (_audioPosition.inMilliseconds / _audioDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF141416),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF141416),
        appBar: AppBar(
          backgroundColor: const Color(0xFF141416),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          ),
          title: Text(
            widget.rocket['title'] ?? 'Speed Reader',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: U.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: U.primary.withValues(alpha: 0.4), width: 0.5),
                ),
                child: Text(
                  (widget.rocket['voice'] as String? ?? 'bella')
                      .replaceAll('af_', '')
                      .replaceAll('am_', '')
                      .toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: U.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Centered Reading Stage
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: U.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: U.border, width: 0.5),
                    ),
                    child: _errorMessage != null
                        ? Center(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.plusJakartaSans(color: U.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _isLoadingAudio
                            ? Center(
                                child: CircularProgressIndicator(color: U.primary, strokeWidth: 2.5),
                              )
                            : Wrap(
                                alignment: WrapAlignment.start,
                                runSpacing: 12,
                                spacing: 6,
                                children: List.generate(_currentTokens.length, (index) {
                                  final token = _currentTokens[index];
                                  final isActive = index == _activeWordIndex;
                                  final tokenStyle = _getWordStyle(token.className);

                                  return GestureDetector(
                                    onTap: () => _seekToWord(index),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isActive ? 6 : 2,
                                        vertical: isActive ? 3 : 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive ? U.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        token.word,
                                        style: isActive
                                            ? tokenStyle.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              )
                                            : tokenStyle,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                  ),
                ),
              ),
            ),

            // Timers & Playback Progress Slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: U.border.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(U.primary),
                    minHeight: 3.5,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_audioPosition.inMinutes}:${(_audioPosition.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: GoogleFonts.plusJakartaSans(color: U.dim, fontSize: 11),
                      ),
                      Text(
                        '${_audioDuration.inMinutes}:${(_audioDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: GoogleFonts.plusJakartaSans(color: U.dim, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Controls Panel
            Container(
              color: const Color(0xFF141416),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Playback Speed Selector Popup
                      PopupMenuButton<double>(
                        initialValue: _playbackSpeed,
                        tooltip: 'Playback Speed',
                        onSelected: _handleSpeedChange,
                        icon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: U.border, width: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.speed_rounded, color: U.sub, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${_playbackSpeed.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}x',
                                style: GoogleFonts.outfit(color: U.text, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        color: U.surface,
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 0.75, child: Text('0.75x')),
                          PopupMenuItem(value: 0.9, child: Text('0.9x')),
                          PopupMenuItem(value: 1.0, child: Text('1.0x')),
                          PopupMenuItem(value: 1.15, child: Text('1.15x')),
                          PopupMenuItem(value: 1.25, child: Text('1.25x')),
                          PopupMenuItem(value: 1.5, child: Text('1.5x')),
                          PopupMenuItem(value: 2.0, child: Text('2.0x')),
                        ],
                      ),

                      // Slides Progress indicator
                      Text(
                        'Slide ${_slides.isEmpty ? 0 : _currentSlideIndex + 1} of ${_slides.length}',
                        style: GoogleFonts.plusJakartaSans(
                          color: U.sub,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Empty placeholder to balance Row layout
                      const SizedBox(width: 50),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Prev Slide Button
                      IconButton(
                        onPressed: _currentSlideIndex > 0 ? _handlePrevSlide : null,
                        iconSize: 28,
                        disabledColor: U.dim.withValues(alpha: 0.3),
                        icon: Icon(Icons.skip_previous_rounded, color: _currentSlideIndex > 0 ? Colors.white : null),
                      ),
                      const SizedBox(width: 24),

                      // Play/Pause Big Floating Button
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: U.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: U.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Next Slide Button
                      IconButton(
                        onPressed: _currentSlideIndex < _slides.length - 1 ? _handleNextSlide : null,
                        iconSize: 28,
                        disabledColor: U.dim.withValues(alpha: 0.3),
                        icon: Icon(Icons.skip_next_rounded, color: _currentSlideIndex < _slides.length - 1 ? Colors.white : null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
