import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';
import '../services/focus_supabase_service.dart';
import '../widgets/utopia_loader.dart';

class RocketsStageTheme {
  final Color background;
  final Color border;
  final Color prevLineColor;
  final double prevLineOpacity;
  final Color wPlainColor;
  final Color wKeyColor;
  final Color wStrongColor;
  final Color wTermColor;
  final Color activeUnderlineColor;
  final Color activeBoxColor;

  const RocketsStageTheme({
    required this.background,
    required this.border,
    required this.prevLineColor,
    required this.prevLineOpacity,
    required this.wPlainColor,
    required this.wKeyColor,
    required this.wStrongColor,
    required this.wTermColor,
    required this.activeUnderlineColor,
    required this.activeBoxColor,
  });

  static const light = RocketsStageTheme(
    background: Color(0xFFF2EDE4),
    border: Color(0xFFD4C3A3),
    prevLineColor: Color(0xFF2A2520),
    prevLineOpacity: 0.25,
    wPlainColor: Color(0xFF2A2520),
    wKeyColor: Color(0xFF1E1A16),
    wStrongColor: Color(0xFFB85C1E),
    wTermColor: Color(0xFF8A6A00),
    activeUnderlineColor: Color(0xFF2A2520),
    activeBoxColor: Color(0x38B85C1E),
  );

  static const dark = RocketsStageTheme(
    background: Color(0xFF1A1320),
    border: Color(0xFF312347),
    prevLineColor: Color(0xFFDCCBED),
    prevLineOpacity: 0.22,
    wPlainColor: Color(0xFFDCCBED),
    wKeyColor: Color(0xFFF2EBFA),
    wStrongColor: Color(0xFFE8774A),
    wTermColor: Color(0xFFBA8CF7),
    activeUnderlineColor: Color(0xFFF2EBFA),
    activeBoxColor: Color(0x52E8774A),
  );
}

final List<Map<String, dynamic>> _localSampleRockets = [
  {
    'id': 'local-sample-bella',
    'title': '✧ Instant Demo — Bella (US Female)',
    'raw_text': 'The cosmos is within us; we are made of star-stuff, and we are a way for the universe to know itself.',
    'voice': 'af_bella',
    'speed': 1.0,
    'created_at': '2026-05-30T12:00:00Z',
    'groq_styles': [
      {
        'cosmos': 'w-key',
        'star-stuff': 'w-strong',
        'starstuff': 'w-strong',
        'universe': 'w-key'
      }
    ],
    'supabase_audio_urls': ['assets/voices/sample_1.wav'],
    'cloudinary_audio_urls': [],
    'timings': [
      [
        {"start": 0.0, "end": 210.0}, {"start": 210.0, "end": 631.0}, {"start": 631.0, "end": 771.0}, {"start": 771.0, "end": 1192.0}, {"start": 1192.0, "end": 1353.0}, {"start": 1473.0, "end": 1613.0}, {"start": 1613.0, "end": 1824.0}, {"start": 1824.0, "end": 2104.0}, {"start": 2104.0, "end": 2245.0}, {"start": 2245.0, "end": 2917.0}, {"start": 3037.0, "end": 3247.0}, {"start": 3247.0, "end": 3387.0}, {"start": 3387.0, "end": 3598.0}, {"start": 3598.0, "end": 3718.0}, {"start": 3718.0, "end": 3928.0}, {"start": 3928.0, "end": 4139.0}, {"start": 4139.0, "end": 4349.0}, {"start": 4349.0, "end": 4910.0}, {"start": 4910.0, "end": 5051.0}, {"start": 5051.0, "end": 5331.0}, {"start": 5331.0, "end": 5773.0}
      ]
    ]
  },
  {
    'id': 'local-sample-sarah',
    'title': '✧ Instant Demo — Sarah (US Female — Warm)',
    'raw_text': 'Artificial intelligence is the next major step in human evolution, helping us unlock the secrets of the mind.',
    'voice': 'af_sarah',
    'speed': 1.0,
    'created_at': '2026-05-30T12:05:00Z',
    'groq_styles': [
      {
        'intelligence': 'w-key',
        'evolution': 'w-strong',
        'secrets': 'w-key',
        'mind': 'w-strong'
      }
    ],
    'supabase_audio_urls': ['assets/voices/sample_2.wav'],
    'cloudinary_audio_urls': [],
    'timings': [
      [
        {"start": 0.0, "end": 712.0}, {"start": 712.0, "end": 1512.0}, {"start": 1512.0, "end": 1655.0}, {"start": 1655.0, "end": 1869.0}, {"start": 1869.0, "end": 2154.0}, {"start": 2154.0, "end": 2510.0}, {"start": 2510.0, "end": 2795.0}, {"start": 2795.0, "end": 2938.0}, {"start": 2938.0, "end": 3294.0}, {"start": 3294.0, "end": 3957.0}, {"start": 4077.0, "end": 4575.0}, {"start": 4575.0, "end": 4718.0}, {"start": 4718.0, "end": 5146.0}, {"start": 5146.0, "end": 5359.0}, {"start": 5359.0, "end": 5858.0}, {"start": 5858.0, "end": 6001.0}, {"start": 6001.0, "end": 6215.0}, {"start": 6215.0, "end": 6521.0}
      ]
    ]
  },
  {
    'id': 'local-sample-adam',
    'title': '✧ Instant Demo — Adam (US Male — Deep)',
    'raw_text': 'Design is not just what it looks like and feels like; design is how it works.',
    'voice': 'am_adam',
    'speed': 1.0,
    'created_at': '2026-05-30T12:10:00Z',
    'groq_styles': [
      {
        'design': 'w-key',
        'looks': 'w-plain',
        'feels': 'w-strong',
        'works': 'w-key'
      }
    ],
    'supabase_audio_urls': ['assets/voices/sample_3.wav'],
    'cloudinary_audio_urls': [],
    'timings': [
      [
        {"start": 0.0, "end": 407.0}, {"start": 407.0, "end": 542.0}, {"start": 542.0, "end": 746.0}, {"start": 746.0, "end": 1017.0}, {"start": 1017.0, "end": 1288.0}, {"start": 1288.0, "end": 1424.0}, {"start": 1424.0, "end": 1763.0}, {"start": 1763.0, "end": 2035.0}, {"start": 2035.0, "end": 2238.0}, {"start": 2238.0, "end": 2577.0}, {"start": 2577.0, "end": 2869.0}, {"start": 2989.0, "end": 3396.0}, {"start": 3396.0, "end": 3531.0}, {"start": 3531.0, "end": 3735.0}, {"start": 3735.0, "end": 3870.0}, {"start": 3870.0, "end": 4229.0}
      ]
    ]
  }
];

class RocketsScreen extends StatefulWidget {
  const RocketsScreen({super.key});

  @override
  State<RocketsScreen> createState() => _RocketsScreenState();
}

class _RocketsScreenState extends State<RocketsScreen> {
  final _supabaseService = FocusSupabaseService();
  List<Map<String, dynamic>> _rockets = [];
  List<Map<String, dynamic>> _dbRockets = [];
  bool _showSamples = false;
  bool _isLoadingList = true;
  Timer? _pollingTimer;
  String _userId = '';

  // Default player configurations preferences
  double _defaultPlaybackSpeed = 1.0;
  bool _defaultHighlightMode = true;
  bool _defaultIsDarkStage = false;
  bool _defaultWordByWordMode = false;
  bool _defaultShowHistory = true;

  // Folder states
  List<Map<String, dynamic>> _folders = [];
  String? _currentFolderId;
  String? _currentFolderName;

  void _updateRocketsList() {
    setState(() {
      _rockets = [
        if (_showSamples) ..._localSampleRockets,
        ..._dbRockets,
      ];
    });
  }

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

  Future<void> _loadPlayerConfigs() async {
    if (_userId.isEmpty || _supabaseService.client == null) return;
    try {
      final data = await _supabaseService.client!
          .from('rocket_player_configs')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _defaultPlaybackSpeed = (data['playback_speed'] as num?)?.toDouble() ?? 1.0;
          _defaultHighlightMode = data['highlight_mode'] == true;
          _defaultIsDarkStage = data['is_dark_stage'] == true;
          _defaultWordByWordMode = data['word_by_word_mode'] == true;
          _defaultShowHistory = data['show_history'] != false;
          _showSamples = data['show_samples'] != false;
        });
      }
    } catch (e) {
      debugPrint('Rockets: Failed to load player configs: $e');
    }
  }

  Future<void> _loadFolders() async {
    if (_userId.isEmpty || _supabaseService.client == null) return;
    try {
      final data = await _supabaseService.client!
          .from('focus_folders')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _folders = List<Map<String, dynamic>>.from(data as List);
        });
      }
    } catch (e) {
      debugPrint('Rockets: Failed to load folders: $e');
    }
  }

  Future<void> _loadRockets() async {
    if (_userId.isEmpty) return;
    try {
      await _supabaseService.initialize();
      if (_supabaseService.client == null) {
        if (mounted) setState(() => _isLoadingList = false);
        return;
      }

      await _loadPlayerConfigs();
      await _loadFolders();

      final data = await _supabaseService.client!
          .from('focus_rockets')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false);

      if (mounted) {
        _dbRockets = List<Map<String, dynamic>>.from(data as List);
        setState(() {
          _isLoadingList = false;
        });
        _updateRocketsList();
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

        _dbRockets = newRockets;
        _updateRocketsList();

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
          _dbRockets.removeWhere((r) => r['id'] == rocketId);
          _updateRocketsList();
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
        onOpenPlayer: (rocket) {
          _openPlayer(rocket);
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
          defaultPlaybackSpeed: _defaultPlaybackSpeed,
          defaultHighlightMode: _defaultHighlightMode,
          defaultIsDarkStage: _defaultIsDarkStage,
          defaultWordByWordMode: _defaultWordByWordMode,
          defaultShowHistory: _defaultShowHistory,
        ),
      ),
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RocketsSettingsSheet(
        supabaseService: _supabaseService,
        userId: _userId,
        initialPlaybackSpeed: _defaultPlaybackSpeed,
        initialHighlightMode: _defaultHighlightMode,
        initialIsDarkStage: _defaultIsDarkStage,
        initialWordByWordMode: _defaultWordByWordMode,
        initialShowHistory: _defaultShowHistory,
        initialShowSamples: _showSamples,
        onSaved: (speed, highlight, darkStage, wordByWord, showHistory, showSamples) {
          setState(() {
            _defaultPlaybackSpeed = speed;
            _defaultHighlightMode = highlight;
            _defaultIsDarkStage = darkStage;
            _defaultWordByWordMode = wordByWord;
            _defaultShowHistory = showHistory;
            _showSamples = showSamples;
          });
          _updateRocketsList();
        },
      ),
    );
  }

  Future<void> _createFolder(String name) async {
    if (_userId.isEmpty || _supabaseService.client == null) return;
    try {
      final folderId = const Uuid().v4();
      await _supabaseService.client!.from('focus_folders').insert({
        'id': folderId,
        'user_id': _userId,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _loadFolders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder "$name" created successfully')),
      );
    } catch (e) {
      debugPrint('Rockets: Failed to create folder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Please make sure focus_folders table exists (see SQL Setup).')),
      );
    }
  }

  Future<void> _deleteFolder(String id) async {
    if (_userId.isEmpty || _supabaseService.client == null) return;
    try {
      await _supabaseService.client!.from('focus_folders').delete().eq('id', id);
      await _supabaseService.client!.from('focus_rockets').update({'folder_id': null}).eq('folder_id', id);
      
      if (_currentFolderId == id) {
        setState(() {
          _currentFolderId = null;
          _currentFolderName = null;
        });
      }
      
      await _loadFolders();
      await _loadRockets();
    } catch (e) {
      debugPrint('Rockets: Failed to delete folder: $e');
    }
  }

  Future<void> _moveRocketToFolder(String rocketId, String? folderId) async {
    if (_userId.isEmpty || _supabaseService.client == null) return;
    try {
      await _supabaseService.client!.from('focus_rockets').update({'folder_id': folderId}).eq('id', rocketId);
      await _loadRockets();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved successfully')),
      );
    } catch (e) {
      debugPrint('Rockets: Failed to move rocket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Make sure folder_id column exists on focus_rockets (see SQL Setup).')),
      );
    }
  }

  void _showNewFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('New Folder', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter folder name',
            hintStyle: GoogleFonts.plusJakartaSans(color: U.dim),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: U.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.dim, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _createFolder(name);
              }
              Navigator.pop(context);
            },
            child: Text('Create', style: GoogleFonts.outfit(color: U.primary, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMoveRocketDialog(String rocketId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('Move to Folder', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: Icon(Icons.folder_open_rounded, color: U.primary, size: 20),
                title: Text('Main Directory (Root)', style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 13)),
                onTap: () {
                  _moveRocketToFolder(rocketId, null);
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white12, height: 1),
              ..._folders.map((f) => ListTile(
                leading: Icon(Icons.folder_rounded, color: U.peach, size: 20),
                title: Text(f['name'] ?? 'Untitled Folder', style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 13)),
                onTap: () {
                  _moveRocketToFolder(rocketId, f['id']);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _openFolder(String id, String name) {
    setState(() {
      _currentFolderId = id;
      _currentFolderName = name;
    });
  }

  void _goBackToRoot() {
    setState(() {
      _currentFolderId = null;
      _currentFolderName = null;
    });
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: U.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: U.border, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CREATE NEW',
              style: GoogleFonts.outfit(
                color: U.dim,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: U.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.folder_rounded, color: U.primary, size: 20),
              ),
              title: Text('Folder', style: GoogleFonts.outfit(color: U.text, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('Group your rocket sessions', style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showNewFolderDialog();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: U.peach.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.rocket_launch_rounded, color: U.peach, size: 20),
              ),
              title: Text('Rocket Session', style: GoogleFonts.outfit(color: U.text, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('Create a new audio reading speed-run', style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _openCreateSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final currentRockets = _rockets.where((r) {
      final isLocal = (r['id'] as String? ?? '').startsWith('local-sample-');
      if (_currentFolderId == null) {
        if (isLocal) return true;
        return r['folder_id'] == null || r['folder_id'] == '';
      } else {
        if (isLocal) return false;
        return r['folder_id'] == _currentFolderId;
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentFolderId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: U.surface.withValues(alpha: 0.3),
            child: Row(
              children: [
                IconButton(
                  onPressed: _goBackToRoot,
                  icon: Icon(Icons.arrow_back_rounded, color: U.text, size: 20),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentFolderName ?? 'Folder',
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              if (_currentFolderId == null && _folders.isNotEmpty) ...[
                Text(
                  'FOLDERS',
                  style: GoogleFonts.outfit(
                    color: U.dim,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 75,
                  ),
                  itemCount: _folders.length,
                  itemBuilder: (context, index) {
                    final folder = _folders[index];
                    final folderRocketsCount = _dbRockets.where((r) => r['folder_id'] == folder['id']).length;
                    
                    return GestureDetector(
                      onTap: () => _openFolder(folder['id'], folder['name']),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: U.card,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: U.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.folder_rounded, color: U.peach, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    folder['name'] ?? 'Folder',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      color: U.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$folderRocketsCount items',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: U.dim,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _deleteFolder(folder['id']),
                              icon: Icon(Icons.delete_outline_rounded, color: U.dim, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              Text(
                _currentFolderId == null ? 'ROCKETS' : 'SESSIONS',
                style: GoogleFonts.outfit(
                  color: U.dim,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              if (currentRockets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No rocket sessions here.',
                      style: GoogleFonts.plusJakartaSans(color: U.dim, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentRockets.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final r = currentRockets[index];
                    final isLocalSample = (r['id'] as String? ?? '').startsWith('local-sample-');
                    final urls = r['supabase_audio_urls'] as List?;
                    final isGenerating = !isLocalSample && (urls == null || urls.isEmpty);
                    
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
                                if (!isLocalSample) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _showMoveRocketDialog(r['id']),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.drive_file_move_outlined, color: U.dim, size: 18),
                                    tooltip: 'Move to Folder',
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
            ],
          ),
        ),
      ],
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
              onPressed: _openSettingsSheet,
              icon: Icon(Icons.settings_rounded, color: U.text, size: 22),
              tooltip: 'Settings',
            ),
          ],
        ),
        body: _isLoadingList
            ? Center(
                child: CircularProgressIndicator(color: U.primary, strokeWidth: 2.5),
              )
            : _buildBody(),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateMenu,
          backgroundColor: U.primary,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _CreateRocketSheet extends StatefulWidget {
  final String userId;
  final FocusSupabaseService supabaseService;
  final VoidCallback onCreated;
  final Function(Map<String, dynamic>) onOpenPlayer;

  const _CreateRocketSheet({
    required this.userId,
    required this.supabaseService,
    required this.onCreated,
    required this.onOpenPlayer,
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

  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewingVoice;
  bool _loadingVoicePreview = false;

  List<Map<String, dynamic>> _voices = [
    { 'id': "af_bella", 'name': "af_bella [Sweet Female]", 'lang': "en-us" },
    { 'id': "af_sarah", 'name': "af_sarah [Warm Female]", 'lang': "en-us" },
    { 'id': "af_heart", 'name': "af_heart [Emotional/Sweet]", 'lang': "en-us" },
    { 'id': "af_nicole", 'name': "af_nicole [Soft Female]", 'lang': "en-us" },
    { 'id': "af_sky", 'name': "af_sky [Bright Female]", 'lang': "en-us" },
    { 'id': "af_alloy", 'name': "af_alloy [Balanced Female]", 'lang': "en-us" },
    { 'id': "af_aoede", 'name': "af_aoede [Expressive Female]", 'lang': "en-us" },
    { 'id': "af_jessica", 'name': "af_jessica [Sassy Female]", 'lang': "en-us" },
    { 'id': "af_kore", 'name': "af_kore [Cute Female]", 'lang': "en-us" },
    { 'id': "af_river", 'name': "af_river [Chill Female]", 'lang': "en-us" },
    { 'id': "am_adam", 'name': "am_adam [Deep Male]", 'lang': "en-us" },
    { 'id': "am_michael", 'name': "am_michael [Standard Male]", 'lang': "en-us" },
    { 'id': "am_echo", 'name': "am_echo [Clear Male]", 'lang': "en-us" },
    { 'id': "am_eric", 'name': "am_eric [Conversational Male]", 'lang': "en-us" },
    { 'id': "am_fenrir", 'name': "am_fenrir [Deep Male]", 'lang': "en-us" },
    { 'id': "am_liam", 'name': "am_liam [Natural Male]", 'lang': "en-us" },
    { 'id': "am_onyx", 'name': "am_onyx [Deep/Rich Male]", 'lang': "en-us" },
    { 'id': "am_puck", 'name': "am_puck [Energetic Male]", 'lang': "en-us" },
    { 'id': "bf_emma", 'name': "bf_emma [British Female]", 'lang': "en-gb" },
    { 'id': "bf_isabella", 'name': "bf_isabella [British Female]", 'lang': "en-gb" },
    { 'id': "bm_george", 'name': "bm_george [British Male]", 'lang': "en-gb" },
    { 'id': "bm_lewis", 'name': "bm_lewis [British Male]", 'lang': "en-gb" },
    { 'id': "bm_daniel", 'name': "bm_daniel [British Male]", 'lang': "en-gb" },
    { 'id': "bm_fable", 'name': "bm_fable [British Male]", 'lang': "en-gb" },
    { 'id': "jf_alpha", 'name': "jf_alpha [Japanese Female]", 'lang': "ja" },
  ];

  @override
  void initState() {
    super.initState();
    _fetchVoices();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchVoices() async {
    try {
      final res = await http.get(Uri.parse('https://infernoGurala-rocket-tts.hf.space/api/voices'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (data.isNotEmpty) {
          if (mounted) {
            setState(() {
              _voices = List<Map<String, dynamic>>.from(
                data.map((item) => {
                  'id': item['id'] ?? '',
                  'name': item['name'] ?? '',
                  'lang': item['lang'] ?? '',
                })
              );
              final ids = _voices.map((item) => item['id'] as String).toSet();
              if (!ids.contains(_selectedVoice)) {
                _selectedVoice = _voices.first['id'] ?? 'af_bella';
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load voices from server: $e');
    }
  }

  String _formatVoiceName(Map<String, dynamic> voice) {
    final String id = voice['id'] ?? '';
    final String name = voice['name'] ?? '';
    final String lang = voice['lang'] ?? '';

    final String rawName = name
        .split('[')[0]
        .replaceAll('af_', '')
        .replaceAll('am_', '')
        .replaceAll('bf_', '')
        .replaceAll('bm_', '')
        .replaceAll('jf_', '')
        .replaceAll('British', '')
        .trim();

    final String accent = lang == 'ja' ? 'JP' : (lang == 'en-gb' ? 'UK' : 'US');
    final bool isFemale = id.startsWith('af_') || id.startsWith('bf_') || id.startsWith('jf_');
    final String gender = isFemale ? 'Female' : 'Male';

    String desc = '';
    if (name.contains('[') && name.contains(']')) {
      desc = name.split('[')[1].split(']')[0];
      desc = desc.replaceAll('Female', '').replaceAll('Male', '').trim();
    }
    final String descSuffix = desc.isNotEmpty ? ' — $desc' : '';

    return '$rawName ($accent $gender$descSuffix)';
  }

  Future<void> _playVoicePreview(String voiceId) async {
    if (_previewingVoice == voiceId) {
      await _previewPlayer.stop();
      if (mounted) {
        setState(() {
          _previewingVoice = null;
        });
      }
      return;
    }

    await _previewPlayer.stop();
    if (mounted) {
      setState(() {
        _loadingVoicePreview = true;
        _previewingVoice = voiceId;
      });
    }

    try {
      final String assetPath = 'assets/voices/$voiceId.wav';
      try {
        await _previewPlayer.setAudioSource(AudioSource.asset(assetPath));
        _previewPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) {
              setState(() {
                _previewingVoice = null;
              });
            }
          }
        });
        await _previewPlayer.play();
        if (mounted) {
          setState(() {
            _loadingVoicePreview = false;
          });
        }
      } catch (e) {
        debugPrint('Asset preview failed, trying dynamic fallback: $e');
        await _playDynamicFallback(voiceId);
      }
    } catch (e) {
      debugPrint('Voice preview failed: $e');
      if (mounted) {
        setState(() {
          _loadingVoicePreview = false;
          _previewingVoice = null;
        });
      }
    }
  }

  Future<void> _playDynamicFallback(String voiceId) async {
    try {
      final res = await http.get(Uri.parse('https://infernoGurala-rocket-tts.hf.space/api/sample?voice=$voiceId'));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(res.body);
        if (data['audio'] != null) {
          final String base64Audio = data['audio'] as String;
          final Uint8List bytes = base64.decode(base64Audio);
          
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/preview_${voiceId}_${DateTime.now().millisecondsSinceEpoch}.wav');
          await file.writeAsBytes(bytes);

          await _previewPlayer.setFilePath(file.path);
          
          _previewPlayer.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.completed) {
              if (mounted) {
                setState(() {
                  _previewingVoice = null;
                });
              }
            }
          });

          await _previewPlayer.play();
          if (mounted) {
            setState(() {
              _loadingVoicePreview = false;
            });
          }
        } else {
          throw Exception('No audio data returned from server');
        }
      } else {
        throw Exception('Server returned status code ${res.statusCode}');
      }
    } catch (err) {
      debugPrint('Dynamic preview failed: $err');
      if (mounted) {
        setState(() {
          _loadingVoicePreview = false;
          _previewingVoice = null;
          _errorMessage = 'Could not preview voice. Check if TTS server is awake.';
        });
      }
    }
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

      final doc = await FirebaseFirestore.instance.collection('config').doc('supabase-focus-1').get();
      final supabaseUrl = doc.data()?['url'] as String? ?? '';
      final supabaseAnonKey = doc.data()?['anon_key'] as String? ?? '';

      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();
      final cloudName = remoteConfig.getString('cloudinary_cloud_name');
      final apiKey = remoteConfig.getString('cloudinary_api_key');
      final apiSecret = remoteConfig.getString('cloudinary_api_secret');

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
      child: SingleChildScrollView(
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
            // Try Instant Samples Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: U.surface.withValues(alpha: 0.5),
                border: Border.all(color: U.border.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: U.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'TRY INSTANT SAMPLES (NO DELAY)',
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Experience zero-latency reading with pre-cached high-quality voices and perfect word alignments.',
                    style: GoogleFonts.plusJakartaSans(
                      color: U.dim,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _localSampleRockets.map((sample) {
                      final String name = (sample['title'] as String).split('—')[1].trim();
                      return OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onOpenPlayer(sample);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(color: U.border, width: 0.5),
                          backgroundColor: U.surface,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          '✧ Play $name',
                          style: GoogleFonts.outfit(
                            color: U.text,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty) ...[
              Text(_errorMessage, style: GoogleFonts.plusJakartaSans(color: U.red, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _titleController,
              enabled: !_isCreating,
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
              enabled: !_isCreating,
              maxLines: 4,
              style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Reading Material Content',
                labelStyle: GoogleFonts.outfit(color: U.dim, fontSize: 12),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: U.border, width: 0.5)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: U.primary, width: 0.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            // NEURAL VOICE Selection Section (Full Width)
            Text('NEURAL VOICE', style: GoogleFonts.outfit(color: U.dim, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedVoice,
                    dropdownColor: U.surface,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: U.border, width: 0.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 11.5, fontWeight: FontWeight.w600),
                    isExpanded: true, // Prevent dropdown layout overflow inside standard flex limits
                    items: _voices.map((v) {
                      return DropdownMenuItem<String>(
                        value: v['id'],
                        child: Text(
                          _formatVoiceName(v),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _isCreating ? null : (v) {
                      if (v != null) setState(() => _selectedVoice = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 95,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isCreating ? null : () => _playVoicePreview(_selectedVoice),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(color: U.border, width: 0.5),
                      backgroundColor: U.surface.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: _loadingVoicePreview && _previewingVoice == _selectedVoice
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: U.primary),
                          )
                        : Text(
                            _previewingVoice == _selectedVoice ? 'Stop' : 'Preview',
                            style: GoogleFonts.outfit(
                              color: U.text,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // TARGET SPEED Selection Section (Full Width)
            Text('TARGET SPEED', style: GoogleFonts.outfit(color: U.dim, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            DropdownButtonFormField<double>(
              initialValue: _selectedSpeed,
              dropdownColor: U.surface,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: U.border, width: 0.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
              onChanged: _isCreating ? null : (v) {
                if (v != null) setState(() => _selectedSpeed = v);
              },
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
                        style: GoogleFonts.outfit(
                          color: U.primary.computeLuminance() > 0.5 ? const Color(0xFF140C1F) : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
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

  bool hasWordInfo = false;
  if (slideTimings != null && slideTimings.isNotEmpty) {
    final first = slideTimings.first;
    if (first is Map && (first.containsKey('word') || first.containsKey('text'))) {
      hasWordInfo = true;
    }
  }

  int timingIdx = 0;

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

    if (slideTimings != null && slideTimings.isNotEmpty) {
      if (hasWordInfo) {
        final normW = w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        bool found = false;
        while (timingIdx < slideTimings.length) {
          final timing = slideTimings[timingIdx];
          if (timing is Map) {
            final tWord = ((timing['word'] ?? timing['text'] ?? '') as String)
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]'), '');
            
            if (tWord.isEmpty) {
              timingIdx++;
              continue;
            }

            if (normW.contains(tWord) || tWord.contains(normW)) {
              start = (timing['start'] ?? 0).toDouble();
              end = (timing['end'] ?? 0).toDouble();
              found = true;
              timingIdx++;
              break;
            } else {
              if (timingIdx + 1 < slideTimings.length) {
                final nextTiming = slideTimings[timingIdx + 1];
                if (nextTiming is Map) {
                  final nextTWord = ((nextTiming['word'] ?? nextTiming['text'] ?? '') as String)
                      .toLowerCase()
                      .replaceAll(RegExp(r'[^a-z0-9]'), '');
                  if (normW.contains(nextTWord) || nextTWord.contains(normW)) {
                    timingIdx++;
                    start = (nextTiming['start'] ?? 0).toDouble();
                    end = (nextTiming['end'] ?? 0).toDouble();
                    found = true;
                    timingIdx++;
                    break;
                  }
                }
              }
              
              start = (timing['start'] ?? 0).toDouble();
              end = (timing['end'] ?? 0).toDouble();
              found = true;
              timingIdx++;
              break;
            }
          } else {
            timingIdx++;
          }
        }
        
        if (!found && timingIdx < slideTimings.length) {
          final timing = slideTimings[timingIdx];
          if (timing is Map) {
            start = (timing['start'] ?? 0).toDouble();
            end = (timing['end'] ?? 0).toDouble();
          }
          timingIdx++;
        }
      } else {
        if (i < slideTimings.length) {
          final timing = slideTimings[i];
          if (timing is Map) {
            start = (timing['start'] ?? 0).toDouble();
            end = (timing['end'] ?? 0).toDouble();
          }
        }
      }
    }

    if (start == 0 && end == 0 && slideTimings != null && slideTimings.isNotEmpty) {
      final prevEnd = tokens.isNotEmpty ? tokens.last.endTime : 0.0;
      start = prevEnd;
      end = start + w.length * 50.0;
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
  final double defaultPlaybackSpeed;
  final bool defaultHighlightMode;
  final bool defaultIsDarkStage;
  final bool defaultWordByWordMode;
  final bool defaultShowHistory;

  const EmbeddedPlayerScreen({
    super.key,
    required this.rocket,
    required this.userId,
    this.defaultPlaybackSpeed = 1.0,
    this.defaultHighlightMode = true,
    this.defaultIsDarkStage = false,
    this.defaultWordByWordMode = false,
    this.defaultShowHistory = true,
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

  bool _isPreloading = true;
  int _preloadCurrent = 0;
  int _preloadTotal = 0;
  List<String?> _preloadedPaths = [];
  bool _isDarkStage = false;
  bool _highlightMode = true;
  bool _isFocusMode = false;
  bool _wordByWordMode = false;
  int _maxRevealedIndex = -1;
  bool _showHistory = true;

  List<double> _slideDurations = [];
  double _totalDurationMs = 0;

  void _calculateDurations() {
    _slideDurations = List<double>.filled(_slides.length, 0.0);
    final timingsList = widget.rocket['timings'] as List?;
    
    for (int i = 0; i < _slides.length; i++) {
      double slideDur = 0.0;
      if (timingsList != null && i < timingsList.length) {
        final slideTimings = timingsList[i];
        if (slideTimings is List && slideTimings.isNotEmpty) {
          final lastWord = slideTimings.last;
          if (lastWord is Map) {
            final end = lastWord['end'];
            if (end is num) {
              slideDur = end.toDouble();
            }
          }
        }
      }
      
      if (slideDur == 0.0) {
        final wordCount = _slides[i].trim().split(RegExp(r'\s+')).length;
        slideDur = wordCount * 350.0;
      }
      _slideDurations[i] = slideDur;
    }
    
    _totalDurationMs = _slideDurations.isNotEmpty ? _slideDurations.reduce((a, b) => a + b) : 0.0;
  }





  @override
  void initState() {
    super.initState();
    _slides = parseText(widget.rocket['raw_text'] as String?);
    _calculateDurations();

    _positionSubscription = _audioPlayer.positionStream.listen((pos) {
      _audioPosition = pos;
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

    _playbackSpeed = (widget.rocket['speed'] as num?)?.toDouble() ?? widget.defaultPlaybackSpeed;
    _highlightMode = widget.defaultHighlightMode;
    _isDarkStage = widget.defaultIsDarkStage;
    _wordByWordMode = widget.defaultWordByWordMode;
    _showHistory = widget.defaultShowHistory;
    _preloadAudios();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    _cleanUpPreloadedFiles();
    super.dispose();
  }

  void _cleanUpPreloadedFiles() {
    for (final path in _preloadedPaths) {
      if (path != null && !path.startsWith('http') && !path.startsWith('assets/')) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (e) {
          debugPrint('Error deleting preloaded file: $e');
        }
      }
    }
  }

  Future<void> _preloadAudios() async {
    if (mounted) {
      setState(() {
        _isPreloading = true;
        _preloadCurrent = 0;
        _preloadTotal = _slides.length;
        _preloadedPaths = List<String?>.filled(_slides.length, null);
      });
    }

    try {
      final id = widget.rocket['id'] as String? ?? '';
      final isLocalSample = id.startsWith('local-sample-');
      final tempDir = await getTemporaryDirectory();

      final List<Future<void>> downloadFutures = [];
      for (int i = 0; i < _slides.length; i++) {
        downloadFutures.add(() async {
          if (isLocalSample) {
            String assetName = 'assets/voices/sample_1.wav';
            if (id == 'local-sample-bella') {
              assetName = 'assets/voices/sample_1.wav';
            } else if (id == 'local-sample-sarah') {
              assetName = 'assets/voices/sample_2.wav';
            } else if (id == 'local-sample-adam') {
              assetName = 'assets/voices/sample_3.wav';
            }
            _preloadedPaths[i] = assetName;
            if (mounted) {
              setState(() {
                _preloadCurrent++;
              });
            }
          } else {
            String? originalUrl;
            final urls = widget.rocket['supabase_audio_urls'] as List?;
            final fallbackUrls = widget.rocket['cloudinary_audio_urls'] as List?;
            if (urls != null && i < urls.length) {
              originalUrl = urls[i] as String?;
            }
            if ((originalUrl == null || originalUrl.isEmpty) && fallbackUrls != null && i < fallbackUrls.length) {
              originalUrl = fallbackUrls[i] as String?;
            }

            if (originalUrl == null || originalUrl.isEmpty) {
              if (mounted) {
                setState(() {
                  _preloadCurrent++;
                });
              }
              return;
            }

            try {
              final response = await http.get(Uri.parse(originalUrl));
              if (response.statusCode == 200) {
                final file = File('${tempDir.path}/rocket_${id}_slide_$i.mp3');
                await file.writeAsBytes(response.bodyBytes);
                _preloadedPaths[i] = file.path;
              } else {
                _preloadedPaths[i] = originalUrl;
              }
            } catch (e) {
              debugPrint('Preload failed for slide $i: $e');
              _preloadedPaths[i] = originalUrl;
            } finally {
              if (mounted) {
                setState(() {
                  _preloadCurrent++;
                });
              }
            }
          }
        }());
      }

      await Future.wait(downloadFutures);
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
        _playSlide(0);
      }
    } catch (e) {
      debugPrint('Error preloading rocket audios: $e');
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
        _playSlide(0);
      }
    }
  }

  void _highlightWordAtTime(double elapsedMs) {
    if (_isLoadingAudio || _currentTokens.isEmpty) return;
    
    int activeIdx = -1;
    for (int i = 0; i < _currentTokens.length; i++) {
      final token = _currentTokens[i];
      if (elapsedMs >= token.startTime && elapsedMs < token.endTime) {
        activeIdx = i;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _activeWordIndex = activeIdx;
        
        for (int i = 0; i < _currentTokens.length; i++) {
          if (elapsedMs >= _currentTokens[i].startTime - 50) {
            if (i > _maxRevealedIndex) {
              _maxRevealedIndex = i;
            }
          }
        }
      });
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
          _maxRevealedIndex = _currentTokens.length - 1;
        });
      }
    }
  }

  Future<void> _playSlide(int slideIndex) async {
    debugPrint('ROCKET_PLAYER: _playSlide started for index $slideIndex');
    if (_slides.isEmpty || slideIndex < 0 || slideIndex >= _slides.length) {
      debugPrint('ROCKET_PLAYER: _playSlide rejected because _slides empty or index out of range: empty=${_slides.isEmpty}, index=$slideIndex, length=${_slides.length}');
      return;
    }

    setState(() {
      _currentSlideIndex = slideIndex;
      _isLoadingAudio = true;
      _errorMessage = null;
      _activeWordIndex = -1;
      _maxRevealedIndex = -1;
      _audioPosition = Duration.zero;
      _audioDuration = Duration.zero;
    });

    try {
      final audioPathOrUrl = _preloadedPaths.isNotEmpty && slideIndex < _preloadedPaths.length
          ? _preloadedPaths[slideIndex]
          : null;

      debugPrint('ROCKET_PLAYER: slide index $slideIndex audio path: $audioPathOrUrl');

      if (audioPathOrUrl == null || audioPathOrUrl.isEmpty) {
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
      debugPrint('ROCKET_PLAYER: slide index $slideIndex prepared ${_currentTokens.length} word tokens');

      if (audioPathOrUrl.startsWith('assets/')) {
        debugPrint('ROCKET_PLAYER: loading asset: $audioPathOrUrl');
        await _audioPlayer.setAudioSource(AudioSource.asset(audioPathOrUrl));
      } else if (audioPathOrUrl.startsWith('http')) {
        debugPrint('ROCKET_PLAYER: loading url: $audioPathOrUrl');
        await _audioPlayer.setUrl(audioPathOrUrl);
      } else {
        debugPrint('ROCKET_PLAYER: loading local file: $audioPathOrUrl');
        await _audioPlayer.setFilePath(audioPathOrUrl);
      }

      await _audioPlayer.setSpeed(_playbackSpeed);
      debugPrint('ROCKET_PLAYER: audio player configured speed to $_playbackSpeed');

      if (_isPlaying) {
        debugPrint('ROCKET_PLAYER: starting playback');
        _audioPlayer.play();
      }

      setState(() {
        _isLoadingAudio = false;
      });
      debugPrint('ROCKET_PLAYER: slide loading completed successfully');
    } catch (e, stack) {
      debugPrint("Native Player Slide Load Error: $e\n$stack");
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
      _maxRevealedIndex = wordIdx;
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

  void _handleRestart() {
    if (_currentSlideIndex == 0) {
      _audioPlayer.seek(Duration.zero);
      setState(() {
        _activeWordIndex = -1;
        _maxRevealedIndex = -1;
      });
    } else {
      _playSlide(0);
    }
  }

  TextStyle _getWordStyle(String className, RocketsStageTheme stageTheme) {
    switch (className) {
      case 'w-key':
        return GoogleFonts.libreBaskerville(
          color: stageTheme.wKeyColor,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        );
      case 'w-strong':
        return GoogleFonts.libreBaskerville(
          color: stageTheme.wStrongColor,
          fontStyle: FontStyle.italic,
          fontSize: 20,
        );
      case 'w-term':
        return GoogleFonts.libreBaskerville(
          color: stageTheme.wTermColor,
          fontSize: 20,
        );
      case 'w-plain':
      default:
        return GoogleFonts.libreBaskerville(
          color: stageTheme.wPlainColor,
          fontSize: 20,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final RocketsStageTheme stageTheme = _isDarkStage ? RocketsStageTheme.dark : RocketsStageTheme.light;

    debugPrint('ROCKET_PLAYER: build called. _isPreloading=$_isPreloading, _isLoadingAudio=$_isLoadingAudio, _errorMessage=$_errorMessage, tokensCount=${_currentTokens.length}, slidesCount=${_slides.length}, currentSlideIndex=$_currentSlideIndex');

    if (_isPreloading) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: _isDarkStage ? Brightness.light : Brightness.dark,
          statusBarBrightness: _isDarkStage ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: stageTheme.background,
          systemNavigationBarIconBrightness: _isDarkStage ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: stageTheme.background,
          body: Center(
            child: Padding(
               padding: const EdgeInsets.symmetric(horizontal: 40),
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text(
                     'SYSTEM PRE-FLIGHT CHECK',
                     style: GoogleFonts.jetBrainsMono(
                       color: stageTheme.prevLineColor.withValues(alpha: 0.6),
                       fontSize: 10,
                       fontWeight: FontWeight.bold,
                       letterSpacing: 2.5,
                     ),
                   ),
                   const SizedBox(height: 32),
                   UtopiaLoader(scale: 1.2, color: stageTheme.wStrongColor),
                   const SizedBox(height: 32),
                   Text(
                     'Fueling "${widget.rocket['title'] ?? 'Speed Reader'}"',
                     style: GoogleFonts.libreBaskerville(
                       fontStyle: FontStyle.italic,
                       fontWeight: FontWeight.bold,
                       fontSize: 18,
                       color: stageTheme.wPlainColor,
                     ),
                     textAlign: TextAlign.center,
                   ),
                   const SizedBox(height: 12),
                   Text(
                     'Loading tracks: $_preloadCurrent / $_preloadTotal',
                     style: GoogleFonts.jetBrainsMono(
                       color: stageTheme.wStrongColor,
                       fontSize: 10,
                       fontWeight: FontWeight.bold,
                       letterSpacing: 1.0,
                     ),
                   ),
                   const SizedBox(height: 24),
                   Container(
                     width: 220,
                     height: 3,
                     color: stageTheme.prevLineColor.withValues(alpha: 0.1),
                     child: Align(
                       alignment: Alignment.centerLeft,
                       child: AnimatedContainer(
                         duration: const Duration(milliseconds: 100),
                         width: 220 * (_preloadTotal > 0 ? (_preloadCurrent / _preloadTotal) : 0.0),
                         height: 3,
                         color: stageTheme.wStrongColor,
                       ),
                     ),
                   ),
                   const SizedBox(height: 12),
                   Text(
                     'preloading all audio nodes for zero-latency playback',
                     style: GoogleFonts.plusJakartaSans(
                       color: stageTheme.prevLineColor.withValues(alpha: 0.6),
                       fontSize: 9,
                       fontWeight: FontWeight.bold,
                       letterSpacing: 0.5,
                     ),
                     textAlign: TextAlign.center,
                   ),
                 ],
               ),
            ),
          ),
        ),
      );
    }



    final systemOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _isFocusMode
          ? (_isDarkStage ? Brightness.light : Brightness.dark)
          : Brightness.light,
      statusBarBrightness: _isFocusMode
          ? (_isDarkStage ? Brightness.dark : Brightness.light)
          : Brightness.dark,
      systemNavigationBarColor: _isFocusMode ? stageTheme.background : const Color(0xFF141416),
      systemNavigationBarIconBrightness: _isFocusMode
          ? (_isDarkStage ? Brightness.light : Brightness.dark)
          : Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlay,
      child: Scaffold(
        backgroundColor: _isFocusMode ? stageTheme.background : const Color(0xFF141416),
        appBar: AppBar(
          backgroundColor: _isFocusMode ? stageTheme.background : const Color(0xFF141416),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close_rounded,
              color: _isFocusMode ? stageTheme.wPlainColor : Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            widget.rocket['title'] ?? 'Speed Reader',
            style: GoogleFonts.outfit(
              color: _isFocusMode ? stageTheme.wPlainColor : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
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
                      .replaceAll('bf_', '')
                      .replaceAll('bm_', '')
                      .replaceAll('jf_', '')
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
                      color: stageTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isFocusMode ? Colors.transparent : stageTheme.border,
                        width: 0.5,
                      ),
                    ),
                    child: _errorMessage != null
                        ? SizedBox(
                            height: 180,
                            child: Center(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.plusJakartaSans(color: U.red, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _isLoadingAudio
                            ? SizedBox(
                                height: 180,
                                child: Center(
                                  child: CircularProgressIndicator(color: U.primary, strokeWidth: 2.5),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_showHistory && _currentSlideIndex > 0 && _slides.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Text(
                                        _slides[_currentSlideIndex - 1],
                                        style: GoogleFonts.libreBaskerville(
                                          fontStyle: FontStyle.italic,
                                          fontSize: 15,
                                          color: stageTheme.prevLineColor.withValues(alpha: stageTheme.prevLineOpacity),
                                        ),
                                      ),
                                    ),
                                  Wrap(
                                    alignment: WrapAlignment.start,
                                    runSpacing: 12,
                                    spacing: 6,
                                    children: List.generate(_currentTokens.length, (index) {
                                      final token = _currentTokens[index];
                                      final isActive = index == _activeWordIndex;
                                      final tokenStyle = _getWordStyle(token.className, stageTheme);

                                      final isVisible = !_wordByWordMode ||
                                          index <= _maxRevealedIndex ||
                                          (index == 0 && _maxRevealedIndex == -1);

                                      return Visibility(
                                        visible: isVisible,
                                        maintainSize: true,
                                        maintainAnimation: true,
                                        maintainState: true,
                                        child: GestureDetector(
                                          onTap: () => _seekToWord(index),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: (isActive && _highlightMode) ? stageTheme.activeBoxColor : Colors.transparent,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              token.word,
                                              style: isActive && !_highlightMode
                                                  ? tokenStyle.copyWith(
                                                      decoration: TextDecoration.underline,
                                                      decorationColor: stageTheme.activeUnderlineColor,
                                                      decorationThickness: 1.5,
                                                    )
                                                  : tokenStyle,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
            ),

            // Timers & Playback Progress Slider
            if (!_isFocusMode)
              StreamBuilder<Duration>(
                stream: _audioPlayer.positionStream,
                initialData: _audioPosition,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  double elapsed = 0.0;
                  for (int i = 0; i < _currentSlideIndex; i++) {
                    if (i < _slideDurations.length) {
                      elapsed += _slideDurations[i];
                    }
                  }
                  elapsed += position.inMilliseconds.toDouble();
                  
                  final progress = _totalDurationMs > 0 ? (elapsed / _totalDurationMs).clamp(0.0, 1.0) : 0.0;
                  final elapsedDuration = Duration(milliseconds: elapsed.toInt());
                  final totalDuration = Duration(milliseconds: _totalDurationMs.toInt());

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(U.primary),
                          minHeight: 3.5,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${elapsedDuration.inMinutes}:${(elapsedDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                            ),
                            Text(
                              '${totalDuration.inMinutes}:${(totalDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),

            // Controls Panel
            Container(
              color: _isFocusMode ? Colors.transparent : const Color(0xFF141416),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  if (_isFocusMode) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                              color: U.primary.computeLuminance() > 0.5 ? const Color(0xFF140C1F) : Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isFocusMode = false;
                        });
                      },
                      icon: Icon(
                        Icons.center_focus_weak_rounded,
                        color: _isFocusMode ? stageTheme.wPlainColor : Colors.white,
                        size: 16,
                      ),
                      label: Text(
                        'Unfocus',
                        style: GoogleFonts.outfit(
                          color: _isFocusMode ? stageTheme.wPlainColor : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(120, 36),
                        side: BorderSide(
                          color: _isFocusMode ? stageTheme.wPlainColor.withValues(alpha: 0.3) : Colors.white24,
                          width: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ] else ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          PopupMenuButton<double>(
                            initialValue: _playbackSpeed,
                            tooltip: 'Playback Speed',
                            onSelected: _handleSpeedChange,
                            color: U.surface,
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 0.75, child: Text('0.75x')),
                              PopupMenuItem(value: 0.9, child: Text('0.9x')),
                              PopupMenuItem(value: 1.0, child: Text('1.0x')),
                              PopupMenuItem(value: 1.15, child: Text('1.15x')),
                              PopupMenuItem(value: 1.3, child: Text('1.3x')),
                              PopupMenuItem(value: 1.5, child: Text('1.5x')),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white24, width: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.speed_rounded, color: Colors.white70, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_playbackSpeed.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}x',
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Highlight mode Button
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _highlightMode = !_highlightMode;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(color: _highlightMode ? Colors.white : Colors.white24, width: 0.5),
                              backgroundColor: _highlightMode ? Colors.white : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: Text(
                              'Box Highlight',
                              style: GoogleFonts.outfit(
                                color: _highlightMode ? const Color(0xFF141416) : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Dark Stage Button
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isDarkStage = !_isDarkStage;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(color: _isDarkStage ? Colors.white : Colors.white24, width: 0.5),
                              backgroundColor: _isDarkStage ? Colors.white : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: Text(
                              'Dark Stage',
                              style: GoogleFonts.outfit(
                                color: _isDarkStage ? const Color(0xFF141416) : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Word bt Word Button
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _wordByWordMode = !_wordByWordMode;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(color: _wordByWordMode ? Colors.white : Colors.white24, width: 0.5),
                              backgroundColor: _wordByWordMode ? Colors.white : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: Text(
                              'Word bt Word',
                              style: GoogleFonts.outfit(
                                color: _wordByWordMode ? const Color(0xFF141416) : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // History Button
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _showHistory = !_showHistory;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(color: _showHistory ? Colors.white : Colors.white24, width: 0.5),
                              backgroundColor: _showHistory ? Colors.white : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: Text(
                              'History',
                              style: GoogleFonts.outfit(
                                color: _showHistory ? const Color(0xFF141416) : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Slides Progress indicator
                          Text(
                            '${_slides.isEmpty ? 0 : _currentSlideIndex + 1}/${_slides.length}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Restart Button
                        IconButton(
                          onPressed: _handleRestart,
                          iconSize: 22,
                          icon: const Icon(Icons.replay_rounded, color: Colors.white70),
                          tooltip: 'Restart',
                        ),
                        const SizedBox(width: 12),

                        // Prev Slide Button
                        IconButton(
                          onPressed: _currentSlideIndex > 0 ? _handlePrevSlide : null,
                          iconSize: 28,
                          disabledColor: Colors.white12,
                          icon: Icon(Icons.skip_previous_rounded, color: _currentSlideIndex > 0 ? Colors.white : null),
                        ),
                        const SizedBox(width: 12),

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
                              color: U.primary.computeLuminance() > 0.5 ? const Color(0xFF140C1F) : Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Next Slide Button
                        IconButton(
                          onPressed: _currentSlideIndex < _slides.length - 1 ? _handleNextSlide : null,
                          iconSize: 28,
                          disabledColor: Colors.white12,
                          icon: Icon(Icons.skip_next_rounded, color: _currentSlideIndex < _slides.length - 1 ? Colors.white : null),
                        ),
                        const SizedBox(width: 12),

                        // Focus Button
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isFocusMode = true;
                            });
                          },
                          iconSize: 22,
                          icon: const Icon(Icons.center_focus_strong_rounded, color: Colors.white70),
                          tooltip: 'Focus Mode',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RocketsSettingsSheet extends StatefulWidget {
  final FocusSupabaseService supabaseService;
  final String userId;
  final double initialPlaybackSpeed;
  final bool initialHighlightMode;
  final bool initialIsDarkStage;
  final bool initialWordByWordMode;
  final bool initialShowHistory;
  final bool initialShowSamples;
  final Function(double, bool, bool, bool, bool, bool) onSaved;

  const _RocketsSettingsSheet({
    required this.supabaseService,
    required this.userId,
    required this.initialPlaybackSpeed,
    required this.initialHighlightMode,
    required this.initialIsDarkStage,
    required this.initialWordByWordMode,
    required this.initialShowHistory,
    required this.initialShowSamples,
    required this.onSaved,
  });

  @override
  State<_RocketsSettingsSheet> createState() => _RocketsSettingsSheetState();
}

class _RocketsSettingsSheetState extends State<_RocketsSettingsSheet> with SingleTickerProviderStateMixin {
  late double _speed;
  late bool _highlightMode;
  late bool _isDarkStage;
  late bool _wordByWordMode;
  late bool _showHistory;
  late bool _showSamples;

  late TabController _tabController;
  final _sqlController = TextEditingController();
  String _sqlOutput = '';
  bool _isExecutingSql = false;
  bool _isSaving = false;

  static const String _setupSqlScript = '''-- Create exec_sql helper RPC function
create or replace function exec_sql(sql_query text)
returns jsonb language plpgsql security definer as \$\$
declare result jsonb;
begin
    if upper(trim(sql_query)) like 'SELECT%' or upper(trim(sql_query)) like 'WITH%' then
        execute 'select jsonb_agg(t) from (' || sql_query || ') t' into result;
        return coalesce(result, '[]'::jsonb);
    else
        execute sql_query;
        return jsonb_build_object('status', 'success');
    end if;
exception when others then
    return jsonb_build_object('error', SQLERRM);
end;
\$\$;

-- Create focus_folders table
create table if not exists public.focus_folders (
    id text primary key,
    user_id text not null,
    name text not null,
    created_at timestamp with time zone default now() not null
);
alter table public.focus_folders enable row level security;
create policy "Allow all actions for folders" on public.focus_folders for all using (true) with check (true);

-- Add folder_id to focus_rockets
alter table public.focus_rockets add column if not exists folder_id text;

-- Create rocket_player_configs table
create table if not exists public.rocket_player_configs (
    user_id text primary key,
    playback_speed double precision default 1.0,
    highlight_mode boolean default true,
    is_dark_stage boolean default false,
    word_by_word_mode boolean default false,
    show_history boolean default true,
    show_samples boolean default true,
    updated_at timestamp with time zone default now() not null
);
alter table public.rocket_player_configs enable row level security;
create policy "Allow all actions for configurations" on public.rocket_player_configs for all using (true) with check (true);''';

  @override
  void initState() {
    super.initState();
    _speed = widget.initialPlaybackSpeed;
    _highlightMode = widget.initialHighlightMode;
    _isDarkStage = widget.initialIsDarkStage;
    _wordByWordMode = widget.initialWordByWordMode;
    _showHistory = widget.initialShowHistory;
    _showSamples = widget.initialShowSamples;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sqlController.dispose();
    super.dispose();
  }

  Future<void> _saveConfigs() async {
    if (widget.userId.isEmpty || widget.supabaseService.client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Supabase client or User ID is missing.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.supabaseService.client!.from('rocket_player_configs').upsert({
        'user_id': widget.userId,
        'playback_speed': _speed,
        'highlight_mode': _highlightMode,
        'is_dark_stage': _isDarkStage,
        'word_by_word_mode': _wordByWordMode,
        'show_history': _showHistory,
        'show_samples': _showSamples,
        'updated_at': DateTime.now().toIso8601String(),
      });

      widget.onSaved(
        _speed,
        _highlightMode,
        _isDarkStage,
        _wordByWordMode,
        _showHistory,
        _showSamples,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default configurations saved.')),
        );
      }
    } catch (e) {
      debugPrint('Failed to save configs: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving configurations. Ensure database table exists: $e')),
        );
      }
    }
  }

  Future<void> _executeSql() async {
    final query = _sqlController.text.trim();
    if (query.isEmpty) return;

    if (widget.supabaseService.client == null) {
      setState(() {
        _sqlOutput = 'Error: Supabase client is not initialized.';
      });
      return;
    }

    setState(() {
      _isExecutingSql = true;
      _sqlOutput = 'Executing query...';
    });

    try {
      final response = await widget.supabaseService.client!
          .rpc('exec_sql', params: {'sql_query': query});
      
      if (mounted) {
        setState(() {
          _isExecutingSql = false;
          _sqlOutput = const JsonEncoder.withIndent('  ').convert(response);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExecutingSql = false;
          _sqlOutput = 'Execution Error:\n$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1B0F2A),
            Color(0xFF0D0617),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: U.border.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rocket Dashboard Settings',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            indicatorColor: U.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Player Preferences'),
              Tab(text: 'SQL Query Editor'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPlayerTab(),
                _buildSqlTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DEFAULT PLAYBACK SPEED',
                style: GoogleFonts.outfit(
                  color: U.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Speed multiplier used for new sessions',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                  ),
                  DropdownButton<double>(
                    value: _speed,
                    dropdownColor: const Color(0xFF1B0F2A),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 0.75, child: Text('0.75x', style: TextStyle(color: Colors.white, fontSize: 13))),
                      DropdownMenuItem(value: 0.9, child: Text('0.9x', style: TextStyle(color: Colors.white, fontSize: 13))),
                      DropdownMenuItem(value: 1.0, child: Text('1.0x', style: TextStyle(color: Colors.white, fontSize: 13))),
                      DropdownMenuItem(value: 1.15, child: Text('1.15x', style: TextStyle(color: Colors.white, fontSize: 13))),
                      DropdownMenuItem(value: 1.3, child: Text('1.3x', style: TextStyle(color: Colors.white, fontSize: 13))),
                      DropdownMenuItem(value: 1.5, child: Text('1.5x', style: TextStyle(color: Colors.white, fontSize: 13))),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _speed = v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              _buildConfigSwitch(
                title: 'Box Highlight Mode',
                subtitle: 'Draw box highlight around active reading word, otherwise draw underline.',
                value: _highlightMode,
                onChanged: (v) => setState(() => _highlightMode = v),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildConfigSwitch(
                title: 'Dark Stage Theme',
                subtitle: 'Enable dark theme background on the reading stage screen by default.',
                value: _isDarkStage,
                onChanged: (v) => setState(() => _isDarkStage = v),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildConfigSwitch(
                title: 'Word bt Word reveal',
                subtitle: 'Make text appear word-by-word synchronously instead of whole block.',
                value: _wordByWordMode,
                onChanged: (v) => setState(() => _wordByWordMode = v),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildConfigSwitch(
                title: 'Show History line',
                subtitle: 'Show the previous sentence slide in dimmed/opaque style on the stage.',
                value: _showHistory,
                onChanged: (v) => setState(() => _showHistory = v),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildConfigSwitch(
                title: 'Show Offline Samples',
                subtitle: 'List standard pre-aligned sample rockets on main screen.',
                value: _showSamples,
                onChanged: (v) => setState(() => _showSamples = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveConfigs,
            style: ElevatedButton.styleFrom(
              backgroundColor: U.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    'SAVE CONFIGURATIONS',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildConfigSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch.adaptive(
          activeColor: U.primary,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSqlTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Text(
          'SQL QUERY CONSOLE',
          style: GoogleFonts.outfit(
            color: U.primary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sqlController,
          maxLines: 5,
          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'SELECT * FROM focus_rockets LIMIT 5;',
            hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 12),
            filled: true,
            fillColor: Colors.black26,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white10),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: U.primary),
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isExecutingSql ? null : _executeSql,
                icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                label: Text(
                  'EXECUTE QUERY',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: U.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                _sqlController.clear();
                setState(() => _sqlOutput = '');
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                'CLEAR',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'EXECUTION RESULTS',
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: SelectableText(
              _sqlOutput.isEmpty ? 'Console output will appear here after query execution.' : _sqlOutput,
              style: GoogleFonts.jetBrainsMono(
                color: _sqlOutput.startsWith('Execution Error') ? U.red : Colors.greenAccent,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          color: Colors.white.withValues(alpha: 0.02),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.white10),
          ),
          margin: EdgeInsets.zero,
          child: ExpansionTile(
            title: Text(
              'Database Setup Migration Script',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Copy SQL setup code to establish folders & configurations schema.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10),
            ),
            iconColor: Colors.white,
            collapsedIconColor: Colors.white54,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.black26,
                      height: 160,
                      child: SingleChildScrollView(
                        child: Text(
                          _setupSqlScript,
                          style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 9.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: _setupSqlScript));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('SQL setup script copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                      label: Text(
                        'COPY SQL SETUP SCRIPT',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
