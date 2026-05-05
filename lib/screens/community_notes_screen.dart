import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/professional_loading.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/supabase_global_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'note_viewer_screen.dart';
import '../widgets/genz_loading_overlay.dart';
import '../services/trash_service.dart';
import 'trash_screen.dart';

/// Dynamic approvals: Root items need 10, sub items need 3.
int _getRequiredApprovals(String path) {
  if (path.isEmpty) return 3;
  final parts = path.split('/').where((p) => p.trim().isNotEmpty).toList();
  final cIdx = parts.indexOf('Community');
  if (cIdx != -1) {
    final depthAfterCommunity = parts.length - 1 - cIdx;
    // depth 1 means directly inside Community (e.g. aditya-university/Community/ProgramFolder)
    if (depthAfterCommunity <= 1) return 10;
  }
  return 3;
}

/// Fun loading messages — gen-z style.
const List<String> _kLoadingMessages = [
  'cooking up your notes... 👨‍🍳',
  'summoning the knowledge gods...',
  'speedrunning your syllabus...',
  'loading — no cap 🧐',
  'brewing some brainpower... ☕',
  'vibing while we fetch stuff...',
  'hold tight, big brain loading...',
  'manifesting your notes rn... ✨',
  'downloading the semester lore...',
  'fetching notes at 3 AM energy...',
  'the notes are noting... 📝',
  'buffering genius... almost there',
  'ctrl+c ctrl+v from the cloud...',
  'warming up the brain cells...',
  'your notes said brb...',
];

/// ─── Educational / Engineering icon catalogue ───
/// Flat lookup used for resolving stored icon keys.
const Map<String, (IconData, String)> kFolderIconCatalogue = {
  'school': (Icons.school_outlined, 'School'),
  'book': (Icons.menu_book_outlined, 'Book'),
  'library': (Icons.local_library_outlined, 'Library'),
  'assignment': (Icons.assignment_outlined, 'Assignment'),
  'quiz': (Icons.quiz_outlined, 'Quiz'),
  'article': (Icons.article_outlined, 'Article'),
  'bookmark': (Icons.collections_bookmark_outlined, 'Bookmark'),
  'folder': (Icons.folder_outlined, 'Folder'),
  'topic': (Icons.topic_outlined, 'Topic'),
  'math': (Icons.functions_outlined, 'Mathematics'),
  'calculate': (Icons.calculate_outlined, 'Calculate'),
  'analytics': (Icons.analytics_outlined, 'Analytics'),
  'bar_chart': (Icons.bar_chart_outlined, 'Statistics'),
  'science': (Icons.science_outlined, 'Science'),
  'rocket': (Icons.rocket_launch_outlined, 'Rocket'),
  'speed': (Icons.speed_outlined, 'Dynamics'),
  'thermostat': (Icons.thermostat_outlined, 'Thermo'),
  'waves': (Icons.waves_outlined, 'Waves'),
  'compress': (Icons.compress_outlined, 'Mechanics'),
  'straighten': (Icons.straighten_outlined, 'Measure'),
  'electrical': (Icons.electrical_services_outlined, 'Electrical'),
  'bolt': (Icons.bolt_outlined, 'Power'),
  'memory': (Icons.memory_outlined, 'Chip'),
  'developer_board': (Icons.developer_board_outlined, 'Board'),
  'cable': (Icons.cable_outlined, 'Cable'),
  'battery': (Icons.battery_charging_full_outlined, 'Battery'),
  'sensors': (Icons.sensors_outlined, 'Sensors'),
  'cell_tower': (Icons.cell_tower_outlined, 'Tower'),
  'code': (Icons.code_outlined, 'Code'),
  'terminal': (Icons.terminal_outlined, 'Terminal'),
  'storage': (Icons.storage_outlined, 'Database'),
  'cloud': (Icons.cloud_outlined, 'Cloud'),
  'lan': (Icons.lan_outlined, 'Network'),
  'security': (Icons.security_outlined, 'Security'),
  'bug': (Icons.bug_report_outlined, 'Debug'),
  'architecture': (Icons.architecture_outlined, 'Architecture'),
  'foundation': (Icons.foundation_outlined, 'Foundation'),
  'construction': (Icons.construction_outlined, 'Construction'),
  'engineering': (Icons.engineering_outlined, 'Engineering'),
  'terrain': (Icons.terrain_outlined, 'Terrain'),
  'location_city': (Icons.location_city_outlined, 'Structures'),
  'biotech': (Icons.biotech_outlined, 'Biotech'),
  'water_drop': (Icons.water_drop_outlined, 'Fluids'),
  'local_fire': (Icons.local_fire_department_outlined, 'Thermo'),
  'eco': (Icons.eco_outlined, 'Eco'),
  'opacity': (Icons.opacity_outlined, 'Chemistry'),
  'build': (Icons.build_outlined, 'Tools'),
  'handyman': (Icons.handyman_outlined, 'Workshop'),
  'precision_mfg': (Icons.precision_manufacturing_outlined, 'Manufacturing'),
  'settings': (Icons.settings_outlined, 'Gears'),
  'hardware': (Icons.hardware_outlined, 'Hardware'),
  'language': (Icons.language_outlined, 'Language'),
  'psychology': (Icons.psychology_outlined, 'Psychology'),
  'business': (Icons.business_center_outlined, 'Business'),
  'economics': (Icons.trending_up_outlined, 'Economics'),
  'groups': (Icons.groups_outlined, 'Management'),
  'fact_check': (Icons.fact_check_outlined, 'Fact Check'),
  'exam': (Icons.edit_note_outlined, 'Exam'),
  'checklist': (Icons.checklist_outlined, 'Checklist'),
  'category': (Icons.category_outlined, 'Category'),
  'archive': (Icons.archive_outlined, 'Archive'),
  'lightbulb': (Icons.lightbulb_outlined, 'Ideas'),
  'draw': (Icons.draw_outlined, 'Draw'),
  'palette': (Icons.palette_outlined, 'Design'),
  'explore': (Icons.explore_outlined, 'Explore'),
};

/// Categorized icon sections for the picker UI.
const List<(String, List<(String, IconData)>)> kIconCategories = [
  (
    'Mechanical',
    [
      ('speed', Icons.speed_outlined),
      ('thermostat', Icons.thermostat_outlined),
      ('compress', Icons.compress_outlined),
      ('precision_mfg', Icons.precision_manufacturing_outlined),
      ('build', Icons.build_outlined),
      ('hardware', Icons.hardware_outlined),
      ('handyman', Icons.handyman_outlined),
      ('settings', Icons.settings_outlined),
      ('straighten', Icons.straighten_outlined),
      ('local_fire', Icons.local_fire_department_outlined),
    ],
  ),
  (
    'Electrical & Electronics',
    [
      ('electrical', Icons.electrical_services_outlined),
      ('bolt', Icons.bolt_outlined),
      ('memory', Icons.memory_outlined),
      ('developer_board', Icons.developer_board_outlined),
      ('cable', Icons.cable_outlined),
      ('battery', Icons.battery_charging_full_outlined),
      ('sensors', Icons.sensors_outlined),
      ('cell_tower', Icons.cell_tower_outlined),
      ('waves', Icons.waves_outlined),
    ],
  ),
  (
    'Computer Science',
    [
      ('code', Icons.code_outlined),
      ('terminal', Icons.terminal_outlined),
      ('storage', Icons.storage_outlined),
      ('cloud', Icons.cloud_outlined),
      ('lan', Icons.lan_outlined),
      ('security', Icons.security_outlined),
      ('bug', Icons.bug_report_outlined),
    ],
  ),
  (
    'Civil & Architecture',
    [
      ('architecture', Icons.architecture_outlined),
      ('foundation', Icons.foundation_outlined),
      ('construction', Icons.construction_outlined),
      ('engineering', Icons.engineering_outlined),
      ('terrain', Icons.terrain_outlined),
      ('location_city', Icons.location_city_outlined),
    ],
  ),
  (
    'Science & Chemistry',
    [
      ('science', Icons.science_outlined),
      ('biotech', Icons.biotech_outlined),
      ('water_drop', Icons.water_drop_outlined),
      ('eco', Icons.eco_outlined),
      ('opacity', Icons.opacity_outlined),
      ('rocket', Icons.rocket_launch_outlined),
    ],
  ),
  (
    'Mathematics & Stats',
    [
      ('math', Icons.functions_outlined),
      ('calculate', Icons.calculate_outlined),
      ('analytics', Icons.analytics_outlined),
      ('bar_chart', Icons.bar_chart_outlined),
    ],
  ),
  (
    'Academic',
    [
      ('school', Icons.school_outlined),
      ('book', Icons.menu_book_outlined),
      ('library', Icons.local_library_outlined),
      ('assignment', Icons.assignment_outlined),
      ('quiz', Icons.quiz_outlined),
      ('article', Icons.article_outlined),
      ('bookmark', Icons.collections_bookmark_outlined),
      ('topic', Icons.topic_outlined),
      ('folder', Icons.folder_outlined),
    ],
  ),
  (
    'Others',
    [
      ('language', Icons.language_outlined),
      ('psychology', Icons.psychology_outlined),
      ('business', Icons.business_center_outlined),
      ('economics', Icons.trending_up_outlined),
      ('groups', Icons.groups_outlined),
      ('fact_check', Icons.fact_check_outlined),
      ('exam', Icons.edit_note_outlined),
      ('checklist', Icons.checklist_outlined),
      ('category', Icons.category_outlined),
      ('archive', Icons.archive_outlined),
      ('lightbulb', Icons.lightbulb_outlined),
      ('draw', Icons.draw_outlined),
      ('palette', Icons.palette_outlined),
      ('explore', Icons.explore_outlined),
    ],
  ),
];

class CommunityNotesScreen extends StatefulWidget {
  final String universityFolderName;
  const CommunityNotesScreen({super.key, required this.universityFolderName});

  @override
  State<CommunityNotesScreen> createState() => _CommunityNotesScreenState();
}

class _CommunityNotesScreenState extends State<CommunityNotesScreen> {
  final SupabaseGlobalService _github = SupabaseGlobalService.instance;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _syncing = false;
  bool _isPushing = false;
  String _currentPath = '';
  List<String> _pathHistory = [''];
  bool _warningShown = false;
  bool _editModeEnabled = false;
  final ScrollController _breadcrumbController = ScrollController();

  late final TrashService _trashService;
  Set<String> _trashedPaths = {};

  /// Cached folder-icon overrides: folderPath → iconKey from kFolderIconCatalogue.
  final Map<String, String> _folderIcons = {};

  /// Per-user icon color overrides: path → Color hex int.
  final Map<String, int> _iconColors = {};

  /// Per-user pinned program paths (root folders only).
  final Set<String> _pinnedPaths = {};

  /// Cached last-modified dates: itemPath → DateTime.
  final Map<String, DateTime> _lastModifiedDates = {};

  /// How deep we are inside the community tree.
  /// 0 = root (programs), 1 = inside a program (semesters), 2+ = courses / files.
  int get _depth => _pathHistory.length - 1;

  @override
  void initState() {
    super.initState();
    _trashService = TrashService(universityId: widget.universityFolderName);
    _load();
    _fetchUniversityName();
    _loadFolderIcons();
    _loadPinnedPrograms();
    _loadIconColors();
  }

  /// Strip the `__xxxx` uniqueness suffix from a GitHub folder name for display.
  /// Files (.md etc) are returned as-is.
  static String _displayName(String name) {
    // Match trailing __<hex4> pattern (e.g. "Semester 1__a3f2")
    final match = RegExp(r'__[0-9a-f]{4}$').firstMatch(name);
    if (match != null) return name.substring(0, match.start);
    return name;
  }

  /// Generate a unique GitHub-safe folder name by appending __<hex4>.
  static String _uniqueName(String displayName) {
    final code = (DateTime.now().millisecondsSinceEpoch & 0xFFFF)
        .toRadixString(16)
        .padLeft(4, '0');
    return '${displayName}__$code';
  }

  /// Smart icon resolver — checks Firestore override first, then name heuristics.
  /// Default palette for automatic coloring (no two adjacent same).
  static const _autoPalette = <Color>[
    Color(0xFF6366F1), // indigo
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // violet
    Color(0xFF14B8A6), // teal
    Color(0xFFF97316), // orange
  ];

  /// Get a color for an item by index, ensuring no two adjacent are the same.
  Color _colorForIndex(int index) {
    return _autoPalette[index % _autoPalette.length];
  }

  /// For number overrides (num_X), returns a generic icon — the caller should
  /// check _folderIcons directly to render a number badge instead.
  (IconData, Color) _iconFor(String name, String path, {int index = 0}) {
    // 0. Check user-set color override
    final customColorInt = _iconColors[path];

    // 1. Check user-set icon override
    final overrideKey = _folderIcons[path];
    if (overrideKey != null) {
      // Number icon — caller renders a badge; return placeholder
      if (overrideKey.startsWith('num_')) {
        return (
          Icons.tag_outlined,
          customColorInt != null ? Color(customColorInt) : U.teal,
        );
      }
      if (kFolderIconCatalogue.containsKey(overrideKey)) {
        return (
          kFolderIconCatalogue[overrideKey]!.$1,
          customColorInt != null ? Color(customColorInt) : U.primary,
        );
      }
    }

    // If user set a custom color, use it with heuristic icon
    Color resolveColor(Color defaultColor) =>
        customColorInt != null ? Color(customColorInt) : defaultColor;

    // 2. Name-based heuristics (from old library)
    final key = name.toLowerCase();
    if (key.contains('thermo'))
      return (Icons.local_fire_department_outlined, resolveColor(U.peach));
    if (key.contains('math') ||
        key.contains('calculus') ||
        key.contains('algebra'))
      return (Icons.functions_outlined, resolveColor(U.primary));
    if (key.contains('electric') ||
        key.contains('beee') ||
        key.contains('circuit'))
      return (Icons.electrical_services_outlined, resolveColor(U.peach));
    if (key.contains('chemistry') || key.contains('chem'))
      return (Icons.science_outlined, resolveColor(U.teal));
    if (key.contains('economics') ||
        key.contains('econ') ||
        key.contains('manage'))
      return (Icons.bar_chart_outlined, resolveColor(U.green));
    if (key.contains('code') ||
        key.contains('programming') ||
        key.contains('pps') ||
        key.contains('dsa') ||
        key.contains('algorithm'))
      return (Icons.code_outlined, resolveColor(U.primary));
    if (key.contains('iot') ||
        key.contains('sensor') ||
        key.contains('embedded'))
      return (Icons.sensors_outlined, resolveColor(U.blue));
    if (key.contains('physics') ||
        key.contains('mechanics') ||
        key.contains('dynamics'))
      return (Icons.speed_outlined, resolveColor(U.lavender));
    if (key.contains('civil') ||
        key.contains('structure') ||
        key.contains('concrete'))
      return (Icons.architecture_outlined, resolveColor(U.gold));
    if (key.contains('lab'))
      return (Icons.biotech_outlined, resolveColor(U.teal));
    if (key.contains('design') ||
        key.contains('drawing') ||
        key.contains('cad'))
      return (Icons.draw_outlined, resolveColor(U.sky));
    if (key.contains('network') || key.contains('computer network'))
      return (Icons.lan_outlined, resolveColor(U.blue));
    if (key.contains('database') || key.contains('dbms') || key.contains('sql'))
      return (Icons.storage_outlined, resolveColor(U.teal));
    if (key.contains('operating') || key.contains('os'))
      return (Icons.developer_board_outlined, resolveColor(U.peach));
    if (key.contains('machine') ||
        key.contains('manufacturing') ||
        key.contains('workshop'))
      return (Icons.precision_manufacturing_outlined, resolveColor(U.gold));
    if (key.contains('english') ||
        key.contains('communication') ||
        key.contains('language'))
      return (Icons.language_outlined, resolveColor(U.sky));
    if (key.contains('exam') ||
        key.contains('prep') ||
        key.contains('question') ||
        key.contains('bank'))
      return (Icons.quiz_outlined, resolveColor(U.peach));
    if (key.contains('archive'))
      return (Icons.archive_outlined, resolveColor(U.sub));
    if (key.contains('doc'))
      return (Icons.school_outlined, resolveColor(U.primary));
    if (key.contains('sem'))
      return (Icons.collections_bookmark_outlined, resolveColor(U.lavender));
    if (key.contains('unit'))
      return (Icons.topic_outlined, resolveColor(U.teal));
    // fallback — use auto palette so adjacent folders get different colors
    return (
      Icons.folder_outlined,
      customColorInt != null ? Color(customColorInt) : _colorForIndex(index),
    );
  }

  String get _fullPath =>
      '${widget.universityFolderName}/Community/$_currentPath';

  /// Convert a DateTime to a human-readable relative time string.
  static String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.isNegative) return 'just now';
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m == 1 ? '1 min ago' : '$m mins ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return h == 1 ? '1 hour ago' : '$h hours ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) {
      final w = diff.inDays ~/ 7;
      return w == 1 ? '1 week ago' : '$w weeks ago';
    }
    if (diff.inDays < 365) {
      final m = diff.inDays ~/ 30;
      return m == 1 ? '1 month ago' : '$m months ago';
    }
    final y = diff.inDays ~/ 365;
    return y == 1 ? '1 year ago' : '$y years ago';
  }

  /// Fetch last-modified dates for current items in background.
  void _fetchLastModifiedDates() {
    for (final item in _items) {
      final path = item['path'] as String? ?? '';
      if (path.isEmpty) continue;
      // Fire and forget — each call is independent
      _github
          .getLastModified(path)
          .then((dt) {
            if (dt != null && mounted) {
              setState(() => _lastModifiedDates[path] = dt);
            }
          })
          .catchError((_) {});
    }
  }

  String get _pinPrefsKey => 'pinned_programs_${widget.universityFolderName}';
  String get _colorPrefsKey => 'icon_colors_${widget.universityFolderName}';

  Future<void> _loadPinnedPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pinPrefsKey) ?? [];
    if (mounted)
      setState(
        () => _pinnedPaths
          ..clear()
          ..addAll(list),
      );
  }

  Future<void> _savePinnedPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinPrefsKey, _pinnedPaths.toList());
  }

  void _togglePin(String path) {
    setState(() {
      if (_pinnedPaths.contains(path)) {
        _pinnedPaths.remove(path);
      } else {
        _pinnedPaths.add(path);
      }
    });
    _savePinnedPrograms();
  }

  Future<void> _loadIconColors() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_colorPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      final map = Map<String, dynamic>.from(json.decode(raw));
      if (mounted) {
        setState(() {
          _iconColors.clear();
          for (final entry in map.entries) {
            _iconColors[entry.key] = entry.value as int;
          }
        });
      }
    }
  }

  Future<void> _saveIconColors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorPrefsKey, json.encode(_iconColors));
  }

  void _setIconColor(String path, Color color) {
    setState(() => _iconColors[path] = color.value);
    _saveIconColors();
  }

  void _removeIconColor(String path) {
    setState(() => _iconColors.remove(path));
    _saveIconColors();
  }

  String _universityName = '';

  Future<void> _fetchUniversityName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityFolderName)
          .get();
      debugPrint(
        'COMMUNITY: University doc exists=${doc.exists}, id=${widget.universityFolderName}, data=${doc.data()}',
      );
      if (doc.exists && mounted) {
        setState(() {
          _universityName =
              doc.data()?['name'] as String? ?? widget.universityFolderName;
        });
      } else if (mounted) {
        // Fallback: use the folder name itself as display
        setState(() {
          _universityName = widget.universityFolderName;
        });
      }
    } catch (e) {
      debugPrint('COMMUNITY: Failed to fetch university name: $e');
      if (mounted) {
        setState(() {
          _universityName = widget.universityFolderName;
        });
      }
    }
  }

  /// Path to the shared icon metadata file on GitHub.
  String get _iconsJsonPath =>
      '${widget.universityFolderName}/Community/.icons.json';

  /// Load icon overrides from GitHub .icons.json for this university.
  Future<void> _loadFolderIcons() async {
    try {
      final icons = await _github.getFolderIcons(
        '${widget.universityFolderName}/Community/',
      );
      if (mounted) {
        setState(() {
          _folderIcons.clear();
          _folderIcons.addAll(icons);
        });
      }
    } catch (_) {}
  }

  /// Schedule a background reload 2 seconds after a GitHub mutation,
  /// giving the API time to propagate.
  void _scheduleReload() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _load(forceRefresh: true);
    });
  }

  /// Persist icon choice for a folder to GitHub .icons.json (shared for all users).
  Future<void> _setFolderIcon(String folderPath, String iconKey) async {
    setState(() => _isPushing = true);
    _folderIcons[folderPath] = iconKey;
    try {
      await _github.setFolderIcon(folderPath, iconKey);
    } catch (_) {}
    if (mounted) setState(() => _isPushing = false);
  }

  /// Remove icon override and persist to GitHub.
  Future<void> _removeFolderIcon(String folderPath) async {
    setState(() => _isPushing = true);
    _folderIcons.remove(folderPath);
    try {
      await _github.setFolderIcon(folderPath, '');
    } catch (_) {}
    if (mounted) setState(() => _isPushing = false);
  }

  /// Write the current _folderIcons map to GitHub as .icons.json.

  /// Show the icon picker bottom sheet — minimal, categorized, with number input.
  void _showIconPicker(String folderPath) {
    final numController = TextEditingController();
    // Check if current icon is a number
    final currentIcon = _folderIcons[folderPath];
    if (currentIcon != null && currentIcon.startsWith('num_')) {
      numController.text = currentIcon.replaceFirst('num_', '');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: U.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: U.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // ── Number input row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Number',
                    style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    height: 36,
                    child: TextField(
                      controller: numController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: U.teal,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: '1',
                        hintStyle: GoogleFonts.outfit(
                          color: U.dim,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        filled: true,
                        fillColor: U.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: U.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: U.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: U.teal),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final num = numController.text.trim();
                      if (num.isNotEmpty) {
                        _setFolderIcon(folderPath, 'num_$num');
                        Navigator.pop(ctx);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: U.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Set',
                        style: GoogleFonts.outfit(
                          color: U.teal,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (currentIcon != null)
                    GestureDetector(
                      onTap: () {
                        _removeFolderIcon(folderPath);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: U.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Reset',
                          style: GoogleFonts.outfit(
                            color: U.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: U.border, height: 1, thickness: 0.5),
            // ── Categorized icon list ──
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: kIconCategories.length,
                itemBuilder: (ctx, catIndex) {
                  final category = kIconCategories[catIndex];
                  final catName = category.$1;
                  final icons = category.$2;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        child: Text(
                          catName,
                          style: GoogleFonts.outfit(
                            color: U.dim,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: icons.map((entry) {
                            final key = entry.$1;
                            final icon = entry.$2;
                            final isSelected = _folderIcons[folderPath] == key;
                            return GestureDetector(
                              onTap: () {
                                _setFolderIcon(folderPath, key);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? U.primary.withValues(alpha: 0.15)
                                      : U.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? U.primary : U.border,
                                    width: isSelected ? 1.5 : 0.5,
                                  ),
                                ),
                                child: Icon(
                                  icon,
                                  color: isSelected ? U.primary : U.sub,
                                  size: 20,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sortItems() {
    _items.sort((a, b) {
      final aPath = a['path'] as String? ?? '';
      final bPath = b['path'] as String? ?? '';

      // Pinned items always come first
      final aPinned = _pinnedPaths.contains(aPath);
      final bPinned = _pinnedPaths.contains(bPath);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      final aSort = a['sort_index'] as int? ?? 0;
      final bSort = b['sort_index'] as int? ?? 0;

      if (aSort != bSort) {
        return aSort.compareTo(bSort);
      }

      final aIsFolder = a['type'] == 'dir';
      final bIsFolder = b['type'] == 'dir';
      if (aIsFolder && !bIsFolder) return -1;
      if (!aIsFolder && bIsFolder) return 1;

      return (a['name'] as String? ?? '').toLowerCase().compareTo(
        (b['name'] as String? ?? '').toLowerCase(),
      );
    });
  }

  void _enterEditMode() {
    if (_editModeEnabled) {
      setState(() => _editModeEnabled = false);
      return;
    }

    if (_warningShown) {
      setState(() => _editModeEnabled = true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: U.peach, size: 28),
            const SizedBox(width: 10),
            Text(
              'Edit Mode',
              style: GoogleFonts.outfit(
                color: U.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'You are entering edit mode for a shared community folder.\n\nAny changes you request will require approval from others. Please be respectful and maintain the quality of the notes.',
          style: GoogleFonts.outfit(color: U.sub, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _editModeEnabled = true;
                _warningShown = true;
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: U.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'I Understand',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isEditMode => _editModeEnabled;

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      if (_items.isEmpty) {
        _loading = true;
      } else {
        _syncing = true;
      }
    });

    // Capture the path at call time to guard against navigation race conditions
    final requestedPath = _fullPath;

    try {
      final itemsFuture = _github.getDirectoryContents(requestedPath);
      final trashFuture = _trashService.getTrashedPaths().catchError((e) {
        debugPrint("COMMUNITY: Trash fetch failed: $e");
        return <String>{};
      });

      final results = await Future.wait([itemsFuture, trashFuture]);

      if (!mounted || _fullPath != requestedPath) return;

      final fetchedItems = results[0] as List<Map<String, dynamic>>;
      final fetchedTrash = results[1] as Set<String>;

      debugPrint(
        "COMMUNITY: Loaded ${fetchedItems.length} items from GitHub/Supabase",
      );
      debugPrint("COMMUNITY: Loaded ${fetchedTrash.length} trashed paths");

      setState(() {
        _items = fetchedItems
            .where((item) => !(item['name'] as String).startsWith('.'))
            .toList();
        _trashedPaths = fetchedTrash;
        _sortItems();
        _syncing = false;
        _loading = false;
      });
      // Fetch last-modified dates in the background after items are available
      _fetchLastModifiedDates();
      if (_depth >= 1) {
        _prefetchSubfolders();
      }
    } catch (e) {
      debugPrint("COMMUNITY: Load failed: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTrash() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrashScreen(universityId: widget.universityFolderName),
      ),
    );
    // Reload when coming back from trash
    _load(forceRefresh: true);
  }

  /// Automatically fetch contents of subfolders in the background to warm the cache.
  void _prefetchSubfolders() {
    for (final item in _items) {
      if (item['type'] == 'dir') {
        final path = item['path'] as String? ?? '';
        if (path.isNotEmpty) {
          _github
              .getDirectoryContents(path)
              .catchError((_) => <Map<String, dynamic>>[]);
        }
      }
    }
  }

  void _navigateToFolder(String folderName) {
    setState(() {
      _currentPath = '$_currentPath$folderName/';
      _pathHistory.add(_currentPath);
      // Clear old items immediately so previous folder content doesn't flash
      _items = [];
      _loading = true;
    });
    _load();
    _scrollToBreadcrumbEnd();
  }

  List<Map<String, dynamic>> get _displayItems {
    return _items.where((item) {
      final name = item['name'] as String?;
      final path = item['path'] as String?;
      if (name == null || name.startsWith('.')) return false;
      if (path != null && _trashedPaths.contains(path)) return false;
      return true;
    }).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final display = _displayItems;
    final movedItem = display[oldIndex];

    setState(() {
      // Remove from current position
      _items.remove(movedItem);

      // Find where to insert: place before the item currently at newIndex
      if (newIndex < display.length - 1) {
        // The display list hasn't changed yet (we removed from _items, not display)
        final target = display[newIndex >= oldIndex ? newIndex + 1 : newIndex];
        final targetIdx = _items.indexOf(target);
        _items.insert(targetIdx == -1 ? _items.length : targetIdx, movedItem);
      } else {
        _items.add(movedItem);
      }

      // Re-assign sort indices
      for (int i = 0; i < _items.length; i++) {
        _items[i]['sort_index'] = i;
      }
    });

    // Persist to Supabase
    _github.updateSortOrder(_items).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save order'),
            backgroundColor: U.red,
          ),
        );
      }
    });
  }

  void _navigateBack() {
    if (_pathHistory.length <= 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _pathHistory.removeLast();
      _currentPath = _pathHistory.last;
      // Clear old items immediately so previous folder content doesn't flash
      _items = [];
      _loading = true;
    });
    _load();
    _scrollToBreadcrumbEnd();
  }

  /// Jump to a specific depth in the navigation hierarchy.
  /// depth 0 = root (programs), depth 1 = inside a program (semesters), etc.
  void _navigateToDepth(int targetDepth) {
    if (targetDepth < 0 || targetDepth >= _depth)
      return; // no-op if already there or invalid
    setState(() {
      // Trim the history to the target depth + 1 (keeping entries 0..targetDepth)
      _pathHistory = _pathHistory.sublist(0, targetDepth + 1);
      _currentPath = _pathHistory.last;
      _items = [];
      _loading = true;
    });
    _load();
    _scrollToBreadcrumbEnd();
  }

  void _scrollToBreadcrumbEnd() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _breadcrumbController.hasClients) {
        _breadcrumbController.animateTo(
          _breadcrumbController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showAddBranchDialog() {
    final controller = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: U.surface,
          title: Text(
            'Add Branch',
            style: GoogleFonts.outfit(
              color: U.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creates a sample semester, course, and unit structure.',
                style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: GoogleFonts.outfit(color: U.text),
                decoration: InputDecoration(
                  hintText: 'Branch name',
                  hintStyle: GoogleFonts.outfit(color: U.sub),
                  filled: true,
                  fillColor: U.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: U.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
            ),
            FilledButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;

                      final ghName = _uniqueName(name);

                      Navigator.pop(ctx);

                      setState(() => _isPushing = true);
                      bool success = false;
                      try {
                        final uid =
                            FirebaseAuth.instance.currentUser?.uid ?? '';
                        await _github.createFolder(
                          '${widget.universityFolderName}/Community',
                          ghName,
                          'community',
                          widget.universityFolderName,
                          null,
                          uid,
                        );
                        success = true;
                      } catch (e) {
                        debugPrint("Create branch failed: $e");
                      }
                      if (success && mounted) {
                        await _load(forceRefresh: true);
                      }
                      if (mounted) setState(() => _isPushing = false);

                      if (!mounted) return;

                      if (success) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name branch created!'),
                            backgroundColor: U.green,
                          ),
                        );
                        _load(forceRefresh: true);
                        _scheduleReload();
                      } else {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to create $name branch'),
                            backgroundColor: U.red,
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: U.primary),
              child: Text(
                isCreating ? 'Creating...' : 'Create',
                style: GoogleFonts.outfit(color: U.bg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    final controller = TextEditingController();
    bool isCreating = false;
    bool isFile = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: U.surface,
          title: Text(
            'Add Item',
            style: GoogleFonts.outfit(
              color: U.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'File',
                        style: GoogleFonts.outfit(color: U.text, fontSize: 14),
                      ),
                      value: true,
                      groupValue: isFile,
                      activeColor: U.primary,
                      onChanged: (val) => setDialogState(() => isFile = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Folder',
                        style: GoogleFonts.outfit(color: U.text, fontSize: 14),
                      ),
                      value: false,
                      groupValue: isFile,
                      activeColor: U.primary,
                      onChanged: (val) => setDialogState(() => isFile = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                style: GoogleFonts.outfit(color: U.text),
                decoration: InputDecoration(
                  hintText: isFile ? 'File name' : 'Folder name',
                  hintStyle: GoogleFonts.outfit(color: U.sub),
                  filled: true,
                  fillColor: U.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: U.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
            ),
            FilledButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      var name = controller.text.trim();
                      if (name.isEmpty) return;

                      if (isFile && !name.endsWith('.md')) {
                        name += '.md';
                      }

                      // For folders, generate a unique GitHub name
                      final ghName = isFile ? name : _uniqueName(name);

                      setDialogState(() => isCreating = true);
                      Navigator.pop(ctx);

                      final targetPath = isFile
                          ? '$_fullPath$ghName'
                          : '$_fullPath$ghName/.keep';

                      setState(() => _isPushing = true);
                      final parentPathStr = _fullPath.endsWith('/')
                          ? _fullPath.substring(0, _fullPath.length - 1)
                          : _fullPath;
                      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

                      bool success = false;
                      try {
                        if (isFile) {
                          final displayName = name.replaceAll('.md', '');
                          await _github.createNote(
                            parentPathStr,
                            displayName,
                            '# $displayName\n\n',
                            'community',
                            widget.universityFolderName,
                            null,
                            uid,
                          );
                        } else {
                          await _github.createFolder(
                            parentPathStr,
                            ghName,
                            'community',
                            widget.universityFolderName,
                            null,
                            uid,
                          );
                        }
                        success = true;
                      } catch (e) {
                        debugPrint("Create item failed: $e");
                      }
                      if (success && mounted) {
                        await _load(forceRefresh: true);
                      }
                      if (mounted) setState(() => _isPushing = false);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? '$name created!'
                                  : 'Failed to create $name',
                            ),
                            backgroundColor: success ? U.green : U.red,
                          ),
                        );
                        if (success) {
                          _load(forceRefresh: true);
                          _scheduleReload();
                        }
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: U.primary),
              child: Text(
                isCreating ? 'Creating...' : 'Create',
                style: GoogleFonts.outfit(color: U.bg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the breadcrumb path bar for navigation inside program folders.
  /// Visible from depth >= 1 (semester level onwards).
  Widget _buildBreadcrumbBar() {
    // Parse the current path into segments: e.g. 'CSE__a3f2/SEM-1__b4c3/Unit-1__d5e6/'
    // becomes ['CSE__a3f2', 'SEM-1__b4c3', 'Unit-1__d5e6']
    final segments = _currentPath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: U.surface,
        border: Border(
          bottom: BorderSide(
            color: U.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        controller: _breadcrumbController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < segments.length; i++) ...[
              if (i > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: U.dim.withValues(alpha: 0.6),
                  ),
                ),
              ],
              // Last segment = current location (not clickable, highlighted)
              if (i == segments.length - 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: U.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _displayName(segments[i]),
                    style: GoogleFonts.outfit(
                      color: U.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                // Clickable ancestor segment
                GestureDetector(
                  onTap: () =>
                      _navigateToDepth(i + 1), // +1 because depth 0 = root ('')
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _displayName(segments[i]),
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAtRoot = _currentPath.isEmpty;
    final displayItems = _displayItems;
    // Show breadcrumbs from depth >= 1 (inside a program folder, starting at semester level)
    final showBreadcrumbs = _depth >= 1 && !isAtRoot;

    return PopScope(
      canPop: isAtRoot,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateBack();
        }
      },
      child: Scaffold(
        backgroundColor: U.bg,
        appBar: AppBar(
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Utopia Notes',
                      style: GoogleFonts.outfit(
                        color: U.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_universityName.isNotEmpty)
                      Text(
                        _universityName,
                        style: GoogleFonts.outfit(
                          color: U.sub,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedOpacity(
                opacity: (_syncing || _loading) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: SizedBox(
                  width: 40,
                  child: LinearProgressIndicator(
                    backgroundColor: U.border,
                    valueColor: AlwaysStoppedAnimation<Color>(U.primary),
                    minHeight: 1.5,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: U.bg,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: U.text),
            onPressed: _navigateBack,
          ),
          actions: [
            // + button only visible in edit mode (Placed first)
            if (_isEditMode) ...[
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: U.dim,
                  size: 22,
                ),
                tooltip: 'View Trash',
                onPressed: _openTrash,
              ),
              IconButton(
                icon: Icon(Icons.add_rounded, color: U.primary, size: 24),
                onPressed: isAtRoot ? _showAddBranchDialog : _showAddItemDialog,
              ),
            ],
            // Edit mode toggle — Premium Chip
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: _isEditMode ? U.primary : U.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isEditMode
                          ? U.primary
                          : U.border.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: _isEditMode
                        ? [
                            BoxShadow(
                              color: U.primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _enterEditMode();
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: _isEditMode
                          ? U.bg.withValues(alpha: 0.2)
                          : U.primary.withValues(alpha: 0.1),
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) =>
                                  RotationTransition(
                                    turns: Tween<double>(
                                      begin: 0.8,
                                      end: 1.0,
                                    ).animate(animation),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  ),
                              child: Icon(
                                _isEditMode
                                    ? Icons.check_circle_rounded
                                    : Icons.edit_note_rounded,
                                key: ValueKey(_isEditMode),
                                size: 18,
                                color: _isEditMode ? U.bg : U.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.fastOutSlowIn,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                child: Text(
                                  _isEditMode ? 'Done' : 'Edit Mode',
                                  key: ValueKey(_isEditMode),
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: _isEditMode
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: _isEditMode ? U.bg : U.text,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // ── Breadcrumb bar (visible from semester level onwards) ──
                if (showBreadcrumbs) _buildBreadcrumbBar(),
                // ── Main content ──
                Expanded(
                  child: _loading
                      ? ProfessionalLoading(
                          message:
                              _kLoadingMessages[Random().nextInt(
                                _kLoadingMessages.length,
                              )],
                        )
                      : displayItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No notes yet.',
                                style: GoogleFonts.outfit(color: U.sub),
                              ),
                              if (isAtRoot) ...[
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _showAddBranchDialog,
                                  icon: Icon(Icons.add, color: U.bg),
                                  label: Text(
                                    'Add Branch',
                                    style: GoogleFonts.outfit(color: U.bg),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: U.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: U.primary,
                          backgroundColor: U.surface,
                          onRefresh: () => _load(forceRefresh: true),
                          child: (isAtRoot && !_isEditMode)
                              ? GridView.builder(
                                  padding: const EdgeInsets.all(24),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 0.95,
                                      ),
                                  itemCount: displayItems.length,
                                  itemBuilder: (context, index) {
                                    final item = displayItems[index];
                                    final name = item['name'] as String;
                                    final path = item['path'] as String;

                                    return _buildProgramCard(
                                      index: index,
                                      title: _displayName(name),
                                      folderPath: path,
                                      onTap: () => _navigateToFolder(name),
                                      isEditMode: _isEditMode,
                                      lastModified: _lastModifiedDates[path],
                                      onEditTap: _isEditMode
                                          ? () =>
                                                _showRootFolderEditOptions(item)
                                          : null,
                                    );
                                  },
                                )
                              : ReorderableListView.builder(
                                  padding: const EdgeInsets.only(bottom: 116),
                                  itemCount: displayItems.length,
                                  onReorder: _onReorder,
                                  buildDefaultDragHandles: _isEditMode,
                                  itemBuilder: (context, index) {
                                    final item = displayItems[index];
                                    final name = item['name'] as String;
                                    final type = item['type'] as String;
                                    final isFolder = type == 'dir';
                                    final path = item['path'] as String;

                                    // ── Resolve icon & color ──
                                    final iconInfo = _iconFor(
                                      name,
                                      path,
                                      index: index,
                                    );
                                    final IconData itemIcon;
                                    final Color itemColor;
                                    // Check if user has an icon override for this path
                                    final hasIconOverride = _folderIcons
                                        .containsKey(path);
                                    final hasColorOverride = _iconColors
                                        .containsKey(path);
                                    if (isFolder) {
                                      itemIcon = iconInfo.$1;
                                      itemColor = iconInfo.$2;
                                    } else if (hasIconOverride ||
                                        hasColorOverride) {
                                      // Use user-overridden icon/color for files too
                                      itemIcon = hasIconOverride
                                          ? iconInfo.$1
                                          : Icons.article_outlined;
                                      itemColor = iconInfo.$2;
                                    } else {
                                      // Files — use article icon with auto-palette color
                                      itemIcon = Icons.article_outlined;
                                      itemColor = _colorForIndex(index);
                                    }

                                    // ── Staggered entrance animation (old library style) ──
                                    return Column(
                                      key: ValueKey(path),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (index > 0)
                                          Divider(
                                            color: U.border,
                                            height: 1,
                                            thickness: 0.5,
                                            indent: 56,
                                          ),
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0, end: 1),
                                          duration: Duration(
                                            milliseconds: 250 + index * 45,
                                          ),
                                          curve: Curves.easeOut,
                                          builder: (context, v, child) =>
                                              Opacity(
                                                opacity: v,
                                                child: Transform.translate(
                                                  offset: Offset(
                                                    0,
                                                    16 * (1 - v),
                                                  ),
                                                  child: child,
                                                ),
                                              ),
                                          child: InkWell(
                                            onTap: () async {
                                              if (isFolder) {
                                                _navigateToFolder(name);
                                              } else {
                                                final result =
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            NoteViewerScreen(
                                                              title:
                                                                  _displayName(
                                                                    name,
                                                                  ).replaceAll(
                                                                    '.md',
                                                                    '',
                                                                  ),
                                                              filePath: path,
                                                              isEditable:
                                                                  _isEditMode,
                                                              useGlobalRepo:
                                                                  true,
                                                            ),
                                                      ),
                                                    );
                                                if (result is String) {
                                                  // silent reload handled by NoteViewerScreen
                                                }
                                              }
                                            },
                                            splashColor: itemColor.withValues(
                                              alpha: 0.06,
                                            ),
                                            highlightColor: itemColor
                                                .withValues(alpha: 0.04),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 16,
                                                  ),
                                              child: Row(
                                                children: [
                                                  // ── Leading icon / number badge ──
                                                  if (!isFolder) ...[
                                                    () {
                                                      final numBadge =
                                                          RegExp(r'^(\d+)')
                                                              .firstMatch(name)
                                                              ?.group(1);
                                                      if (numBadge != null) {
                                                        return Container(
                                                          width: 32,
                                                          height: 32,
                                                          decoration: BoxDecoration(
                                                            color: U.teal
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              numBadge,
                                                              style: GoogleFonts.outfit(
                                                                color: U.teal,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      return Icon(
                                                        itemIcon,
                                                        color: itemColor,
                                                        size: 22,
                                                      );
                                                    }(),
                                                  ] else ...[
                                                    // Folder — check for number override
                                                    () {
                                                      final iconKey =
                                                          _folderIcons[path];
                                                      if (iconKey != null &&
                                                          iconKey.startsWith(
                                                            'num_',
                                                          )) {
                                                        final numText = iconKey
                                                            .replaceFirst(
                                                              'num_',
                                                              '',
                                                            );
                                                        return Container(
                                                              width: 32,
                                                              height: 32,
                                                              decoration: BoxDecoration(
                                                                color: U.teal
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  numText,
                                                                  style: GoogleFonts.outfit(
                                                                    color:
                                                                        U.teal,
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                            as Widget;
                                                      }
                                                      return Icon(
                                                            itemIcon,
                                                            color: itemColor,
                                                            size: 22,
                                                          )
                                                          as Widget;
                                                    }(),
                                                  ],
                                                  const SizedBox(width: 16),
                                                  // ── Title + subtitle ──
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          _displayName(name)
                                                              .replaceAll(
                                                                '.md',
                                                                '',
                                                              )
                                                              .replaceAll(
                                                                RegExp(
                                                                  r'^\d+\s*',
                                                                ),
                                                                '',
                                                              )
                                                              .trim(),
                                                          style:
                                                              GoogleFonts.outfit(
                                                                fontSize:
                                                                    isFolder
                                                                    ? 16
                                                                    : 15,
                                                                fontWeight:
                                                                    isFolder
                                                                    ? FontWeight
                                                                          .w600
                                                                    : FontWeight
                                                                          .w500,
                                                                color: U.text,
                                                              ),
                                                        ),
                                                        if (!isFolder &&
                                                            item['size'] !=
                                                                null &&
                                                            !name
                                                                .toLowerCase()
                                                                .endsWith(
                                                                  '.md',
                                                                ))
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  top: 2,
                                                                ),
                                                            child: Text(
                                                              _formatFileSize(
                                                                item['size']
                                                                    as int,
                                                              ),
                                                              style:
                                                                  GoogleFonts.outfit(
                                                                    color:
                                                                        U.sub,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                          ),
                                                        // Show last updated in edit mode for all items
                                                        if (_isEditMode &&
                                                            (item['updated_at'] !=
                                                                    null ||
                                                                item['created_at'] !=
                                                                    null))
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  top: 3,
                                                                ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .schedule_rounded,
                                                                  size: 11,
                                                                  color: U.dim,
                                                                ),
                                                                const SizedBox(
                                                                  width: 4,
                                                                ),
                                                                Text(
                                                                  _formatRelativeTime(
                                                                    DateTime.parse(
                                                                      (item['updated_at'] ??
                                                                              item['created_at'])
                                                                          as String,
                                                                    ),
                                                                  ),
                                                                  style: GoogleFonts.outfit(
                                                                    color:
                                                                        U.dim,
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w400,
                                                                  ),
                                                                ),
                                                                if (item['updated_by_name'] !=
                                                                    null) ...[
                                                                  const SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    '•',
                                                                    style: GoogleFonts.outfit(
                                                                      color:
                                                                          U.dim,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Icon(
                                                                    Icons
                                                                        .person_outline_rounded,
                                                                    size: 11,
                                                                    color:
                                                                        U.dim,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Text(
                                                                    item['updated_by_name']
                                                                        as String,
                                                                    style: GoogleFonts.outfit(
                                                                      color:
                                                                          U.dim,
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (_isEditMode)
                                                    GestureDetector(
                                                      onTap: () {
                                                        HapticFeedback.lightImpact();
                                                        _showItemActionSheet(
                                                          item,
                                                          isFolder,
                                                        );
                                                      },
                                                      child: Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          color: U.primary
                                                              .withValues(
                                                                alpha: 0.08,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          Icons
                                                              .more_horiz_rounded,
                                                          color: U.primary,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Icon(
                                                      Icons.chevron_right,
                                                      color: U.dim.withValues(
                                                        alpha: 0.9,
                                                      ),
                                                      size: 18,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ), // closes InkWell
                                        ), // closes TweenAnimationBuilder
                                      ],
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
            if (_isPushing)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    color: U.bg.withValues(alpha: 0.7),
                    child: const ProfessionalLoading(
                      message: 'Saving changes...',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final path = item['path'] as String;
    final isFolder = item['type'] == 'dir';
    final displayName = _displayName(name).replaceAll('.md', '');

    int countdown = 5;
    Timer? timer;
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (timer == null) {
            timer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown > 0) {
                setDialogState(() => countdown--);
              } else {
                t.cancel();
              }
            });
          }

          return AlertDialog(
            backgroundColor: U.surface,
            title: Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: U.red, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Move to Trash',
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Text(
              'Moving "$displayName" to trash. It can be recovered within 30 days from the trash view.',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
              ),
              FilledButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);

                        try {
                          await _trashService.moveToTrash(
                            path: path,
                            name: displayName,
                            type: path.endsWith('.md') ? 'file' : 'dir',
                            universityId: widget.universityFolderName,
                            github: _github,
                          );
                          if (mounted) {
                            Navigator.pop(ctx);
                            _load(forceRefresh: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"$displayName" moved to trash'),
                                backgroundColor: U.teal,
                                action: SnackBarAction(
                                  label: 'VIEW TRASH',
                                  textColor: U.bg,
                                  onPressed: _openTrash,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.pop(ctx);
                            String errorMsg = e.toString();
                            if (errorMsg.contains('permission-denied')) {
                              errorMsg = "Permission Denied: Please check Firestore Security Rules";
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to trash: $errorMsg'),
                                backgroundColor: U.red,
                              ),
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(backgroundColor: U.red),
                child: Text(
                  isDeleting ? 'Trashing...' : 'Move to Trash',
                  style: GoogleFonts.outfit(color: U.bg),
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      timer?.cancel();
    });
  }

  void _showRenameDialog(Map<String, dynamic> item, bool isFolder) {
    final oldName = item['name'] as String;
    final path = item['path'] as String;
    // Show the display name (without __xxxx suffix) in the text field
    final displayOld = _displayName(oldName).replaceAll('.md', '');
    final controller = TextEditingController(text: displayOld);
    bool isRenaming = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: U.surface,
          title: Text(
            'Rename',
            style: GoogleFonts.outfit(
              color: U.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: controller,
            style: GoogleFonts.outfit(color: U.text),
            decoration: InputDecoration(
              hintText: 'New name',
              hintStyle: GoogleFonts.outfit(color: U.sub),
              filled: true,
              fillColor: U.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: U.border),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
            ),
            FilledButton(
              onPressed: isRenaming
                  ? null
                  : () async {
                      var newName = controller.text.trim();
                      if (newName.isEmpty || newName == displayOld) return;

                      if (!isFolder && !newName.endsWith('.md')) {
                        newName += '.md';
                      }

                      setDialogState(() => isRenaming = true);
                      Navigator.pop(ctx);

                      // For folders, preserve the existing __xxxx suffix
                      // instead of generating a new one to avoid creating a
                      // duplicate folder on GitHub.
                      String ghNewName;
                      if (isFolder) {
                        final oldSuffixMatch = RegExp(
                          r'__[0-9a-f]{4}$',
                        ).firstMatch(oldName);
                        if (oldSuffixMatch != null) {
                          // Preserve the existing suffix
                          ghNewName = '$newName${oldSuffixMatch.group(0)}';
                        } else {
                          ghNewName = _uniqueName(newName);
                        }
                      } else {
                        ghNewName = newName;
                      }

                      final parentPath = path.substring(
                        0,
                        path.lastIndexOf('/'),
                      );
                      final newPath = parentPath.isEmpty
                          ? ghNewName
                          : '$parentPath/$ghNewName';

                      // Optimistic Update
                      final originalItems = List<Map<String, dynamic>>.from(
                        _items,
                      );
                      setState(() => _isPushing = true);
                      bool success = false;
                      try {
                        if (path.endsWith('.md')) {
                          await _github.renameNote(path, ghNewName);
                        } else {
                          await _github.renameFolder(path, ghNewName);
                        }
                        success = true;
                      } catch (_) {}
                      if (success && mounted) {
                        await _load(forceRefresh: true);
                      }
                      if (mounted) setState(() => _isPushing = false);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Renamed successfully'
                                  : 'Failed to rename',
                            ),
                            backgroundColor: success ? U.green : U.red,
                          ),
                        );
                        if (success) {
                          _load(forceRefresh: true);
                          _scheduleReload();
                        }
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: U.primary),
              child: Text(
                isRenaming ? 'Renaming...' : 'Rename',
                style: GoogleFonts.outfit(color: U.bg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _approveDeletion(QueryDocumentSnapshot deletionDoc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool shouldExecuteDelete = false;
    String? targetPath;
    int newApprovalCount = 0;

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final freshSnap = await txn.get(deletionDoc.reference);
        if (!freshSnap.exists) return;

        final data = freshSnap.data() as Map<String, dynamic>;
        final effectiveStatus = data['status'] as String? ?? 'pending';

        // Only allow approving if still in pending state
        if (effectiveStatus != 'pending') return;

        final approvals = List<String>.from(data['approvals'] ?? []);
        final rejections = List<String>.from(data['rejections'] ?? []);

        if (approvals.contains(user.uid)) return;

        // Remove from rejections if they had previously rejected
        rejections.remove(user.uid);

        approvals.add(user.uid);
        newApprovalCount = max(0, approvals.length - rejections.length);

        final reqApprovals = _getRequiredApprovals(
          data['path'] as String? ?? '',
        );
        if ((approvals.length - rejections.length) >= reqApprovals) {
          // This client wins the race — transition to executing
          txn.update(deletionDoc.reference, {
            'approvals': approvals,
            'rejections': rejections,
            'status': 'executing',
          });
          shouldExecuteDelete = true;
          targetPath = data['path'] as String?;
        } else {
          txn.update(deletionDoc.reference, {
            'approvals': approvals,
            'rejections': rejections,
          });
        }
      });

      if (shouldExecuteDelete && targetPath != null) {
        try {
          final path = targetPath?.trim();
          if (path == null || path.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to delete item: missing target path.'),
              ),
            );
            return;
          }
          bool deleted = false;
          try {
            if (path.endsWith('.md')) {
              await _github.deleteNote(path);
            } else {
              await _github.deleteFolder(path);
            }
            deleted = true;
          } catch (_) {}
          if (!deleted) {
            throw Exception(
              'Deletion failed — check permissions or network and try again.',
            );
          }
          await deletionDoc.reference.update({
            'isDeleted': true,
            'status': 'executed',
            'executedAt': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Item deleted successfully.'),
                backgroundColor: U.green,
              ),
            );
            _load(forceRefresh: true);
            _scheduleReload();
          }
        } catch (e) {
          await deletionDoc.reference.update({
            'status': 'failed',
            'failureReason': e.toString(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deletion failed: $e'),
                backgroundColor: U.red,
              ),
            );
          }
        }
      } else if (newApprovalCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deletion approved ($newApprovalCount/${_getRequiredApprovals((deletionDoc.data() as Map<String, dynamic>?)?['path'] as String? ?? '')}).',
            ),
            backgroundColor: U.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: U.red),
        );
      }
    }
  }

  /// Unified modern action sheet for editing items (files/folders) at any depth.
  void _showItemActionSheet(Map<String, dynamic> item, bool isFolder) {
    _showEditOptions(item, isFolder);
  }

  void _showEditOptions(Map<String, dynamic> item, bool isFolder) {
    final name = item['name'] as String;
    final path = item['path'] as String;
    final displayName = _displayName(name).replaceAll('.md', '');
    final isPinned = _pinnedPaths.contains(path);
    final isRoot = _currentPath.isEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: U.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // ── Drag handle ──
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: U.dim.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // ── Item header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: U.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: U.primary.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isFolder ? Icons.folder_rounded : Icons.article_rounded,
                      color: U.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.outfit(
                            color: U.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isFolder ? 'Folder' : 'Note',
                          style: GoogleFonts.outfit(
                            color: U.sub,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Divider(
              color: U.border.withValues(alpha: 0.5),
              height: 1,
              indent: 24,
              endIndent: 24,
            ),
            const SizedBox(height: 8),
            // ── Customize section ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CUSTOMIZE',
                  style: GoogleFonts.outfit(
                    color: U.dim,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Quick action row (icon, color, pin) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildQuickAction(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Icon',
                    color: U.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showIconPicker(path);
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildQuickAction(
                    icon: Icons.palette_rounded,
                    label: 'Color',
                    color: U.teal,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showColorPicker(path);
                    },
                  ),
                  if (isRoot) ...[
                    const SizedBox(width: 12),
                    _buildQuickAction(
                      icon: isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      label: isPinned ? 'Unpin' : 'Pin',
                      color: U.gold,
                      isActive: isPinned,
                      onTap: () {
                        Navigator.pop(ctx);
                        _togglePin(path);
                        _sortItems();
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(
              color: U.border.withValues(alpha: 0.5),
              height: 1,
              indent: 24,
              endIndent: 24,
            ),
            const SizedBox(height: 8),
            // ── Actions section ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ACTIONS',
                  style: GoogleFonts.outfit(
                    color: U.dim,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // ── Rename ──
            _buildActionTile(
              icon: Icons.edit_rounded,
              label: 'Rename',
              subtitle: 'Change the display name',
              color: U.blue,
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(item, isFolder);
              },
            ),
            // ── Delete ──
            _buildActionTile(
              icon: Icons.delete_rounded,
              label: 'Delete',
              subtitle: 'Permanently remove this item',
              color: U.red,
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteDialog(item);
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  /// Quick action button for the action sheet (icon, color, pin).
  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : U.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.3)
                  : U.border.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Action tile for rename/delete in the action sheet.
  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        splashColor: color.withValues(alpha: 0.08),
        highlightColor: color.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        color: U.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: U.dim, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker(String path) {
    final colors = <(String, Color)>[
      ('Default', Colors.transparent),
      ('Red', const Color(0xFFF43F5E)),
      ('Rose', const Color(0xFFEC4899)),
      ('Orange', const Color(0xFFF97316)),
      ('Amber', const Color(0xFFF59E0B)),
      ('Yellow', const Color(0xFFEAB308)),
      ('Lime', const Color(0xFF84CC16)),
      ('Green', const Color(0xFF22C55E)),
      ('Emerald', const Color(0xFF10B981)),
      ('Teal', const Color(0xFF14B8A6)),
      ('Cyan', const Color(0xFF06B6D4)),
      ('Sky', const Color(0xFF0EA5E9)),
      ('Blue', const Color(0xFF3B82F6)),
      ('Indigo', const Color(0xFF6366F1)),
      ('Violet', const Color(0xFF8B5CF6)),
      ('Purple', const Color(0xFFA855F7)),
      ('Fuchsia', const Color(0xFFD946EF)),
      ('Pink', const Color(0xFFEC4899)),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: U.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pick a Color',
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((entry) {
                final label = entry.$1;
                final color = entry.$2;
                final isDefault = color == Colors.transparent;
                final isSelected = isDefault
                    ? !_iconColors.containsKey(path)
                    : _iconColors[path] == color.value;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isDefault) {
                      _removeIconColor(path);
                    } else {
                      _setIconColor(path, color);
                    }
                  },
                  child: Tooltip(
                    message: label,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDefault ? U.bg : color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? U.text : U.border,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: isDefault
                          ? Icon(Icons.auto_fix_high, size: 16, color: U.sub)
                          : isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Root-folder edit options — delegates to the unified action sheet.
  void _showRootFolderEditOptions(Map<String, dynamic> item) {
    _showEditOptions(item, true);
  }

  void _showFailedInfo(QueryDocumentSnapshot deletionDoc) {
    final data = deletionDoc.data() as Map<String, dynamic>;
    final reason = data['failureReason'] as String? ?? 'Unknown error';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.surface,
        title: Text(
          'Deletion Failed',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        content: Text(reason, style: GoogleFonts.outfit(color: U.sub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.outfit(color: U.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard({
    required int index,
    required String title,
    required String folderPath,
    required VoidCallback onTap,
    bool isEditMode = false,
    DateTime? lastModified,
    VoidCallback? onEditTap,
  }) {
    final isPinned = _pinnedPaths.contains(folderPath);
    // Curated color pairs for vibrant gradients — guaranteed no two adjacent same
    final colorPairs = [
      [const Color(0xFF6366F1), const Color(0xFFA855F7)], // Indigo -> Purple
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)], // Pink -> Rose
      [const Color(0xFFF59E0B), const Color(0xFFD97706)], // Amber -> Orange
      [const Color(0xFF10B981), const Color(0xFF059669)], // Emerald -> Green
      [const Color(0xFF3B82F6), const Color(0xFF2563EB)], // Blue -> Deep Blue
      [
        const Color(0xFF8B5CF6),
        const Color(0xFF7C3AED),
      ], // Violet -> Dark Violet
    ];

    // Use sequential index to guarantee no two adjacent cards share the same color
    final pair = colorPairs[index % colorPairs.length];

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [pair[0], pair[1]],
    );

    return InkWell(
      onTap: onTap,
      onLongPress: () => _togglePin(folderPath),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: pair[0].withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Abstract background shape
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Icon(
                  Icons.folder_copy_rounded,
                  color: Colors.white.withValues(alpha: 0.05),
                  size: 140,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Builder(
                        builder: (_) {
                          final iconKey = _folderIcons[folderPath];
                          if (iconKey != null && iconKey.startsWith('num_')) {
                            return Text(
                              iconKey.replaceFirst('num_', ''),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            );
                          }
                          final resolvedIcon =
                              (iconKey != null &&
                                  kFolderIconCatalogue.containsKey(iconKey))
                              ? kFolderIconCatalogue[iconKey]!.$1
                              : Icons.collections_bookmark_rounded;
                          return Icon(
                            resolvedIcon,
                            color: Colors.white,
                            size: 22,
                          );
                        },
                      ),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // ── Last updated (always visible on root cards) ──
                    if (lastModified != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatRelativeTime(lastModified),
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Pin badge
              if (isPinned)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.push_pin, color: Colors.white, size: 12),
                  ),
                ),
              // Edit icon overlay when in edit mode
              if (isEditMode && onEditTap != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onEditTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
