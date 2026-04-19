import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/github_global_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'note_viewer_screen.dart';

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
  ('Mechanical', [
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
  ]),
  ('Electrical & Electronics', [
    ('electrical', Icons.electrical_services_outlined),
    ('bolt', Icons.bolt_outlined),
    ('memory', Icons.memory_outlined),
    ('developer_board', Icons.developer_board_outlined),
    ('cable', Icons.cable_outlined),
    ('battery', Icons.battery_charging_full_outlined),
    ('sensors', Icons.sensors_outlined),
    ('cell_tower', Icons.cell_tower_outlined),
    ('waves', Icons.waves_outlined),
  ]),
  ('Computer Science', [
    ('code', Icons.code_outlined),
    ('terminal', Icons.terminal_outlined),
    ('storage', Icons.storage_outlined),
    ('cloud', Icons.cloud_outlined),
    ('lan', Icons.lan_outlined),
    ('security', Icons.security_outlined),
    ('bug', Icons.bug_report_outlined),
  ]),
  ('Civil & Architecture', [
    ('architecture', Icons.architecture_outlined),
    ('foundation', Icons.foundation_outlined),
    ('construction', Icons.construction_outlined),
    ('engineering', Icons.engineering_outlined),
    ('terrain', Icons.terrain_outlined),
    ('location_city', Icons.location_city_outlined),
  ]),
  ('Science & Chemistry', [
    ('science', Icons.science_outlined),
    ('biotech', Icons.biotech_outlined),
    ('water_drop', Icons.water_drop_outlined),
    ('eco', Icons.eco_outlined),
    ('opacity', Icons.opacity_outlined),
    ('rocket', Icons.rocket_launch_outlined),
  ]),
  ('Mathematics & Stats', [
    ('math', Icons.functions_outlined),
    ('calculate', Icons.calculate_outlined),
    ('analytics', Icons.analytics_outlined),
    ('bar_chart', Icons.bar_chart_outlined),
  ]),
  ('Academic', [
    ('school', Icons.school_outlined),
    ('book', Icons.menu_book_outlined),
    ('library', Icons.local_library_outlined),
    ('assignment', Icons.assignment_outlined),
    ('quiz', Icons.quiz_outlined),
    ('article', Icons.article_outlined),
    ('bookmark', Icons.collections_bookmark_outlined),
    ('topic', Icons.topic_outlined),
    ('folder', Icons.folder_outlined),
  ]),
  ('Others', [
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
  ]),
];

class CommunityNotesScreen extends StatefulWidget {
  final String universityFolderName;
  const CommunityNotesScreen({super.key, required this.universityFolderName});

  @override
  State<CommunityNotesScreen> createState() => _CommunityNotesScreenState();
}

class _CommunityNotesScreenState extends State<CommunityNotesScreen> {
  final GitHubGlobalService _github = GitHubGlobalService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _syncing = false;
  String _currentPath = '';
  List<String> _pathHistory = [''];
  bool _warningShown = false;
  bool _editModeEnabled = false;
  List<QueryDocumentSnapshot> _pendingDeletions = [];
  final ScrollController _breadcrumbController = ScrollController();

  /// Cached folder-icon overrides: folderPath → iconKey from kFolderIconCatalogue.
  final Map<String, String> _folderIcons = {};

  /// Cached last-modified dates: itemPath → DateTime.
  final Map<String, DateTime> _lastModifiedDates = {};

  /// How deep we are inside the community tree.
  /// 0 = root (programs), 1 = inside a program (semesters), 2+ = courses / files.
  int get _depth => _pathHistory.length - 1;

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
  /// For number overrides (num_X), returns a generic icon — the caller should
  /// check _folderIcons directly to render a number badge instead.
  (IconData, Color) _iconFor(String name, String path) {
    // 1. Check user-set icon override
    final overrideKey = _folderIcons[path];
    if (overrideKey != null) {
      // Number icon — caller renders a badge; return placeholder
      if (overrideKey.startsWith('num_')) {
        return (Icons.tag_outlined, U.teal);
      }
      if (kFolderIconCatalogue.containsKey(overrideKey)) {
        return (kFolderIconCatalogue[overrideKey]!.$1, U.primary);
      }
    }
    // 2. Name-based heuristics (from old library)
    final key = name.toLowerCase();
    if (key.contains('thermo'))        return (Icons.local_fire_department_outlined, U.peach);
    if (key.contains('math') || key.contains('calculus') || key.contains('algebra'))
                                       return (Icons.functions_outlined, U.primary);
    if (key.contains('electric') || key.contains('beee') || key.contains('circuit'))
                                       return (Icons.electrical_services_outlined, U.peach);
    if (key.contains('chemistry') || key.contains('chem'))
                                       return (Icons.science_outlined, U.teal);
    if (key.contains('economics') || key.contains('econ') || key.contains('manage'))
                                       return (Icons.bar_chart_outlined, U.green);
    if (key.contains('code') || key.contains('programming') || key.contains('pps') || key.contains('dsa') || key.contains('algorithm'))
                                       return (Icons.code_outlined, U.primary);
    if (key.contains('iot') || key.contains('sensor') || key.contains('embedded'))
                                       return (Icons.sensors_outlined, U.blue);
    if (key.contains('physics') || key.contains('mechanics') || key.contains('dynamics'))
                                       return (Icons.speed_outlined, U.lavender);
    if (key.contains('civil') || key.contains('structure') || key.contains('concrete'))
                                       return (Icons.architecture_outlined, U.gold);
    if (key.contains('lab'))           return (Icons.biotech_outlined, U.teal);
    if (key.contains('design') || key.contains('drawing') || key.contains('cad'))
                                       return (Icons.draw_outlined, U.sky);
    if (key.contains('network') || key.contains('computer network'))
                                       return (Icons.lan_outlined, U.blue);
    if (key.contains('database') || key.contains('dbms') || key.contains('sql'))
                                       return (Icons.storage_outlined, U.teal);
    if (key.contains('operating') || key.contains('os'))
                                       return (Icons.developer_board_outlined, U.peach);
    if (key.contains('machine') || key.contains('manufacturing') || key.contains('workshop'))
                                       return (Icons.precision_manufacturing_outlined, U.gold);
    if (key.contains('english') || key.contains('communication') || key.contains('language'))
                                       return (Icons.language_outlined, U.sky);
    if (key.contains('exam') || key.contains('prep') || key.contains('question') || key.contains('bank'))
                                       return (Icons.quiz_outlined, U.peach);
    if (key.contains('archive'))       return (Icons.archive_outlined, U.sub);
    if (key.contains('doc'))           return (Icons.school_outlined, U.primary);
    if (key.contains('sem'))           return (Icons.collections_bookmark_outlined, U.lavender);
    if (key.contains('unit'))          return (Icons.topic_outlined, U.teal);
    // fallback
    return (Icons.folder_outlined, U.primary);
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
      _github.getLastModified(path).then((dt) {
        if (dt != null && mounted) {
          setState(() => _lastModifiedDates[path] = dt);
        }
      }).catchError((_) {});
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _fetchUniversityName();
    _listenToDeletions();
    _loadFolderIcons();
  }

  String _universityName = '';

  Future<void> _fetchUniversityName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityFolderName)
          .get();
      debugPrint('COMMUNITY: University doc exists=${doc.exists}, id=${widget.universityFolderName}, data=${doc.data()}');
      if (doc.exists && mounted) {
        setState(() {
          _universityName = doc.data()?['name'] as String? ?? widget.universityFolderName;
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
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Instantly load from local cache to prevent icon pop-in delay
    final cachedStr = prefs.getString('cache_$_iconsJsonPath');
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(cachedStr);
        if (mounted) {
          setState(() {
            _folderIcons.clear();
            for (final entry in data.entries) {
              _folderIcons[entry.key] = entry.value as String;
            }
          });
        }
      } catch (_) {}
    }

    // 2. Fetch fresh data from GitHub in background
    _github.getFileContentRaw(_iconsJsonPath).then((content) {
      if (!mounted || content.isEmpty) return;
      try {
        final Map<String, dynamic> data = jsonDecode(content);
        prefs.setString('cache_$_iconsJsonPath', content); // Update cache
        setState(() {
          _folderIcons.clear();
          for (final entry in data.entries) {
            _folderIcons[entry.key] = entry.value as String;
          }
        });
      } catch (_) {}
    }).catchError((_) {});
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
    setState(() => _folderIcons[folderPath] = iconKey);
    await _saveIconsToGitHub();
  }

  /// Remove icon override and persist to GitHub.
  Future<void> _removeFolderIcon(String folderPath) async {
    setState(() => _folderIcons.remove(folderPath));
    await _saveIconsToGitHub();
  }

  /// Write the current _folderIcons map to GitHub as .icons.json.
  Future<void> _saveIconsToGitHub() async {
    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(_folderIcons);
      
      // Save locally immediately for fast loads
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_$_iconsJsonPath', jsonStr);

      await _github.updateFile(
        path: _iconsJsonPath,
        content: jsonStr,
        message: 'update community folder icons',
      );
    } catch (_) {}
  }

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
              width: 40, height: 4,
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
                  Text('Number', style: GoogleFonts.outfit(color: U.sub, fontSize: 13)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    height: 36,
                    child: TextField(
                      controller: numController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: U.teal, fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '1',
                        hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: U.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Set', style: GoogleFonts.outfit(color: U.teal, fontSize: 13, fontWeight: FontWeight.w600)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: U.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Reset', style: GoogleFonts.outfit(color: U.red, fontSize: 12, fontWeight: FontWeight.w500)),
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

  StreamSubscription? _deletionSubscription;

  void _listenToDeletions() {
    debugPrint('LISTEN: Starting listener for ${widget.universityFolderName}');
    _deletionSubscription = FirebaseFirestore.instance
        .collection('community_deletions')
        .where('universityId', isEqualTo: widget.universityFolderName)
        .snapshots()
        .listen(
          (snapshot) {
            // Show docs that are active: pending/executing/failed (new-style)
            // or legacy docs where isDeleted == false.
            final activeDocs = snapshot.docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final status = data['status'] as String?;
              if (status != null) {
                return status == 'pending' ||
                    status == 'executing' ||
                    status == 'failed';
              }
              // Legacy doc without status field: use isDeleted flag
              return data['isDeleted'] == false;
            }).toList();
            debugPrint(
              'LISTEN: Got ${snapshot.docs.length} total, ${activeDocs.length} active deletions for ${widget.universityFolderName}',
            );
            if (mounted) {
              setState(() {
                _pendingDeletions = activeDocs;
                _sortItems();
              });
            }
          },
          onError: (e) {
            debugPrint('LISTEN ERROR: $e');
          },
        );
  }

  @override
  void dispose() {
    _deletionSubscription?.cancel();
    super.dispose();
  }

  void _sortItems() {
    _items.sort((a, b) {
      final aPath = a['path'] as String? ?? '';
      final bPath = b['path'] as String? ?? '';

      final isADeleted = _pendingDeletions.any(
        (d) => (d.data() as Map<String, dynamic>?)?['path'] == aPath,
      );
      final isBDeleted = _pendingDeletions.any(
        (d) => (d.data() as Map<String, dynamic>?)?['path'] == bPath,
      );

      if (isADeleted && !isBDeleted) return -1;
      if (!isADeleted && isBDeleted) return 1;

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
            Text('Edit Mode', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('I Understand', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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

    final items = await _github.getDirectoryContents(
      requestedPath,
      forceRefresh: forceRefresh,
      onRefresh: (freshItems) {
        // Background refresh completed — only update if we're still on the same path
        if (!mounted || _fullPath != requestedPath) return;
        setState(() {
          _items = freshItems
              .where((item) => !(item['name'] as String).startsWith('.'))
              .toList();
          _sortItems();
          _syncing = false;
        });
      },
    );
    if (!mounted || _fullPath != requestedPath) return;
    setState(() {
      _items = items
          .where((item) => !(item['name'] as String).startsWith('.'))
          .toList();
      _sortItems();
      _loading = false;
      _syncing = false;
    });
    // Fetch last-modified dates in the background after items are available
    _fetchLastModifiedDates();
    if (_depth >= 1) {
      _prefetchSubfolders();
    }
  }

  /// Automatically fetch contents of subfolders in the background to warm the cache.
  void _prefetchSubfolders() {
    for (final item in _items) {
      if (item['type'] == 'dir') {
        final path = item['path'] as String? ?? '';
        if (path.isNotEmpty) {
          _github.getDirectoryContents(path).catchError((_) => <Map<String, dynamic>>[]);
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
    if (targetDepth < 0 || targetDepth >= _depth) return; // no-op if already there or invalid
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

                      // Optimistic Update
                      final originalItems = List<Map<String, dynamic>>.from(
                        _items,
                      );
                      setState(() {
                        _items.insert(0, {
                          'name': ghName,
                          'type': 'dir',
                          'path':
                              '${widget.universityFolderName}/Community/$ghName',
                        });
                        _sortItems();
                      });

                      final success = await _github.createBranchStructure(
                        widget.universityFolderName,
                        ghName,
                      );

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

                      // Optimistic Update
                      final originalItems = List<Map<String, dynamic>>.from(
                        _items,
                      );
                      setState(() {
                        _items.insert(0, {
                          'name': ghName,
                          'type': isFile ? 'file' : 'dir',
                          'path': targetPath,
                          'size': isFile ? 0 : null,
                        });
                        _sortItems();
                      });

                      final success = await _github.createFolder(
                        targetPath,
                        content: isFile
                            ? '# ${name.replaceAll('.md', '')}\n\n'
                            : '# init\n',
                      );

                      if (mounted) {
                        if (!success) {
                          // Revert on failure
                          setState(() {
                            _items = originalItems;
                          });
                        }

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
          bottom: BorderSide(color: U.border.withValues(alpha: 0.5), width: 0.5),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  onTap: () => _navigateToDepth(i + 1), // +1 because depth 0 = root ('')
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
    final displayItems = _items.where((item) {
      final name = item['name'] as String?;
      return name != null && !name.startsWith('.');
    }).toList();
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
            if (_isEditMode)
              IconButton(
                icon: Icon(Icons.add_rounded, color: U.primary, size: 24),
                onPressed: isAtRoot ? _showAddBranchDialog : _showAddItemDialog,
              ),
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
                      color: _isEditMode ? U.primary : U.border.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: _isEditMode
                        ? [
                            BoxShadow(
                              color: U.primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            )
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
                      splashColor: _isEditMode ? U.bg.withValues(alpha: 0.2) : U.primary.withValues(alpha: 0.1),
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) => RotationTransition(
                                turns: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                                child: FadeTransition(opacity: animation, child: child),
                              ),
                              child: Icon(
                                _isEditMode ? Icons.check_circle_rounded : Icons.edit_note_rounded,
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
                                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                                child: Text(
                                  _isEditMode ? 'Done' : 'Edit Mode',
                                  key: ValueKey(_isEditMode),
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: _isEditMode ? FontWeight.w700 : FontWeight.w600,
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
        body: Column(
          children: [
            // ── Breadcrumb bar (visible from semester level onwards) ──
            if (showBreadcrumbs) _buildBreadcrumbBar(),
            // ── Main content ──
            Expanded(
              child: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: U.primary),
                    const SizedBox(height: 16),
                    Text(
                      _kLoadingMessages[Random().nextInt(_kLoadingMessages.length)],
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
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
                child: isAtRoot
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

                          final deletionDoc = _pendingDeletions
                              .where(
                                (d) =>
                                    (d.data()
                                            as Map<String, dynamic>)['path'] ==
                                    path,
                              )
                              .firstOrNull;
                          final isPendingDeletion = deletionDoc != null;
                          final approvals = isPendingDeletion
                              ? List<String>.from(
                                  (deletionDoc!.data() as Map<String, dynamic>)['approvals'] ?? [],
                                )
                              : <String>[];
                          final rejections = isPendingDeletion
                              ? List<String>.from(
                                  (deletionDoc.data() as Map<String, dynamic>)['rejections'] ?? [],
                                )
                              : <String>[];
                          final user = FirebaseAuth.instance.currentUser;
                          final hasApproved =
                              user != null && approvals.contains(user.uid);
                          final hasRejected =
                              user != null && rejections.contains(user.uid);
                          final isRequester =
                              isPendingDeletion &&
                              user != null &&
                              (deletionDoc!.data()
                                      as Map<String, dynamic>)['requesterUid'] ==
                                  user.uid;
                          final effectiveStatus = isPendingDeletion
                              ? _effectiveStatus(deletionDoc!)
                              : 'none';
                          final isExecuting = effectiveStatus == 'executing';

                          return _buildProgramCard(
                            title: _displayName(name),
                            folderPath: path,
                            onTap: () => _navigateToFolder(name),
                            isPendingDeletion: isPendingDeletion,
                            approvalCount: max(0, approvals.length - rejections.length),
                            isExecuting: isExecuting,
                            isEditMode: _isEditMode,
                            lastModified: _lastModifiedDates[path],
                            deletionDoc: deletionDoc,
                            hasApproved: hasApproved,
                            hasRejected: hasRejected,
                            isRequester: isRequester,
                            onEditTap:
                                (!isPendingDeletion && _isEditMode)
                                    ? () => _showRootFolderEditOptions(item)
                                    : null,
                          );
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 116),
                        itemCount: displayItems.length,
                        separatorBuilder: (_, __) => Divider(
                          color: U.border,
                          height: 1,
                          thickness: 0.5,
                          indent: 56,
                        ),
                        itemBuilder: (context, index) {
                          final item = displayItems[index];
                          final name = item['name'] as String;
                          final type = item['type'] as String;
                          final isFolder = type == 'dir';
                          final path = item['path'] as String;

                          final deletionDoc = _pendingDeletions
                              .where((d) => d['path'] == path)
                              .firstOrNull;
                          final isPendingDeletion = deletionDoc != null;
                          final approvals = isPendingDeletion
                              ? List<String>.from(
                                  (deletionDoc!.data() as Map<String, dynamic>)['approvals'] ?? [],
                                )
                              : <String>[];
                          final rejections = isPendingDeletion
                              ? List<String>.from(
                                  (deletionDoc.data() as Map<String, dynamic>)['rejections'] ?? [],
                                )
                              : <String>[];
                          final user = FirebaseAuth.instance.currentUser;
                          final hasApproved =
                              user != null && approvals.contains(user.uid);
                          final hasRejected =
                              user != null && rejections.contains(user.uid);
                          final isRequester =
                              isPendingDeletion &&
                              user != null &&
                              (deletionDoc!.data()
                                      as Map<String, dynamic>)['requesterUid'] ==
                                  user.uid;
                          final effectiveStatus = isPendingDeletion
                              ? _effectiveStatus(deletionDoc!)
                              : 'none';
                          final isExecuting = effectiveStatus == 'executing';
                          final isFailed = effectiveStatus == 'failed';

                          // ── Resolve icon & color ──
                          final iconInfo = _iconFor(name, path);
                          final IconData itemIcon;
                          final Color itemColor;
                          if (isPendingDeletion) {
                            itemIcon = isFolder ? Icons.folder_outlined : Icons.article_outlined;
                            itemColor = U.dim;
                          } else if (isFolder) {
                            itemIcon = iconInfo.$1;
                            itemColor = iconInfo.$2;
                          } else {
                            // Files — use article or number badge style
                            final numBadge = RegExp(r'^(\d+)').firstMatch(name)?.group(1);
                            if (numBadge != null) {
                              itemIcon = Icons.article_outlined;
                              itemColor = U.teal;
                            } else {
                              itemIcon = Icons.article_outlined;
                              itemColor = U.sub;
                            }
                          }

                          // ── Staggered entrance animation (old library style) ──
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 250 + index * 45),
                            curve: Curves.easeOut,
                            builder: (context, v, child) => Opacity(
                              opacity: v,
                              child: Transform.translate(
                                offset: Offset(0, 16 * (1 - v)),
                                child: child,
                              ),
                            ),
                            child: InkWell(
                              onTap: () async {
                                if (isPendingDeletion) {
                                  if (isFailed) {
                                    _showFailedInfo(deletionDoc!);
                                    return;
                                  }
                                  if (isFolder) {
                                    _navigateToFolder(name);
                                    return;
                                  }
                                  final downloadUrl = item['download_url'] as String?;
                                  if (downloadUrl != null && downloadUrl.isNotEmpty) {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NoteViewerScreen(
                                          title: _displayName(name).replaceAll('.md', ''),
                                          filePath: path,
                                          isEditable: false,
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                if (isFolder) {
                                  _navigateToFolder(name);
                                } else {
                                  final downloadUrl = item['download_url'] as String?;
                                  if (downloadUrl != null && downloadUrl.isNotEmpty) {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NoteViewerScreen(
                                          title: _displayName(name).replaceAll('.md', ''),
                                          filePath: path,
                                          isEditable: _isEditMode,
                                        ),
                                      ),
                                    );
                                    if (result is String) {
                                      // silent reload handled by NoteViewerScreen
                                    }
                                  }
                                }
                              },
                              splashColor: itemColor.withValues(alpha: 0.06),
                              highlightColor: itemColor.withValues(alpha: 0.04),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: Row(
                                  children: [
                                    // ── Leading icon / number badge ──
                                    if (!isFolder) ...[
                                      () {
                                        final numBadge = RegExp(r'^(\d+)').firstMatch(name)?.group(1);
                                        if (numBadge != null) {
                                          return Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: U.teal.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                numBadge,
                                                style: GoogleFonts.outfit(
                                                  color: isPendingDeletion ? U.dim : U.teal,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return Icon(itemIcon, color: itemColor, size: 22);
                                      }(),
                                    ] else ...[
                                      // Folder — check for number override
                                      () {
                                        final iconKey = _folderIcons[path];
                                        if (iconKey != null && iconKey.startsWith('num_')) {
                                          final numText = iconKey.replaceFirst('num_', '');
                                          return Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: U.teal.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                numText,
                                                style: GoogleFonts.outfit(
                                                  color: isPendingDeletion ? U.dim : U.teal,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ) as Widget;
                                        }
                                        return Icon(itemIcon, color: itemColor, size: 22) as Widget;
                                      }(),
                                    ],
                                    const SizedBox(width: 16),
                                    // ── Title + subtitle ──
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _displayName(name)
                                                .replaceAll('.md', '')
                                                .replaceAll(RegExp(r'^\d+\s*'), '')
                                                .trim(),
                                            style: GoogleFonts.outfit(
                                              fontSize: isFolder ? 16 : 15,
                                              fontWeight: isFolder ? FontWeight.w600 : FontWeight.w500,
                                              color: isPendingDeletion ? U.dim : U.text,
                                            ),
                                          ),
                                          if (isPendingDeletion)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: _buildDeletionProgressWidget(
                                                max(0, approvals.length - rejections.length),
                                                isExecuting,
                                                isFailed,
                                                _getRequiredApprovals(item['path'] as String? ?? ''),
                                              ),
                                            ),
                                          if (!isPendingDeletion &&
                                              !isFolder &&
                                              item['size'] != null &&
                                              !name.toLowerCase().endsWith('.md'))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                _formatFileSize(item['size'] as int),
                                                style: GoogleFonts.outfit(
                                                  color: U.sub,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          // Show last updated in edit mode for all items
                                          if (_isEditMode &&
                                              !isPendingDeletion &&
                                              _lastModifiedDates.containsKey(path))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 3),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.schedule_rounded,
                                                    size: 11,
                                                    color: U.dim,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatRelativeTime(_lastModifiedDates[path]!),
                                                    style: GoogleFonts.outfit(
                                                      color: U.dim,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // ── Trailing ──
                                    if (isPendingDeletion)
                                      _buildPendingTrailing(
                                        deletionDoc!,
                                        hasApproved,
                                        hasRejected,
                                        isRequester,
                                        isExecuting,
                                        isFailed,
                                      )
                                    else if (_isEditMode)
                                      PopupMenuButton<String>(
                                        color: U.surface,
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Actions',
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Center(
                                            child: Icon(
                                              Icons.more_vert,
                                              color: U.dim,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        splashRadius: 18,
                                        onSelected: (value) {
                                          if (value == 'edit') _showEditOptions(item, isFolder);
                                          if (value == 'icon' && isFolder) _showIconPicker(path);
                                        },
                                        itemBuilder: (ctx) => [
                                          PopupMenuItem(
                                            value: 'edit',
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit_outlined, color: U.text, size: 14),
                                                const SizedBox(width: 6),
                                                Text('Edit', style: GoogleFonts.outfit(color: U.text, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                          if (isFolder)
                                            PopupMenuItem(
                                              value: 'icon',
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.palette_outlined, color: U.primary, size: 14),
                                                  const SizedBox(width: 6),
                                                  Text('Change Icon', style: GoogleFonts.outfit(color: U.primary, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                        ],
                                      )
                                    else
                                      Icon(
                                        Icons.chevron_right,
                                        color: U.dim.withValues(alpha: 0.9),
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _requestDeletion(Map<String, dynamic> item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final path = item['path'] as String;
    final name = item['name'] as String;
    final type = item['type'] as String;

    debugPrint(
      'DELETE REQUEST: path=$path, name=$name, type=$type, uni=${widget.universityFolderName}',
    );

    try {
      await FirebaseFirestore.instance.collection('community_deletions').add({
        'universityId': widget.universityFolderName,
        'path': path,
        'name': name,
        'type': type,
        'requesterUid': user.uid,
        'approvals': <String>[user.uid], // requester automatically counts as first approval
        'rejections': <String>[],
        'isDeleted': false,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('DELETE REQUEST: Successfully added to Firestore');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deletion requested (1/${_getRequiredApprovals(item['path'] as String? ?? '')} approvals).',
            ),
            backgroundColor: U.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('DELETE REQUEST ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request deletion: $e'),
            backgroundColor: U.red,
          ),
        );
      }
    }
  }

  void _showRenameDialog(Map<String, dynamic> item, bool isFolder) {
    final oldName = item['name'] as String;
    final path = item['path'] as String;
    // Show the display name (without __xxxx suffix) in the text field
    final displayOld = _displayName(oldName).replaceAll('.md', '');
    final controller = TextEditingController(
      text: displayOld,
    );
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
                      if (newName.isEmpty ||
                          newName == displayOld)
                        return;

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
                        final oldSuffixMatch = RegExp(r'__[0-9a-f]{4}$').firstMatch(oldName);
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
                      setState(() {
                        final index = _items.indexWhere(
                          (i) => i['path'] == path,
                        );
                        if (index != -1) {
                          _items[index] = {
                            ..._items[index],
                            'name': ghNewName,
                            'path': newPath,
                          };
                        }
                      });

                      final success = await _github.renameItem(path, newPath);

                      if (mounted) {
                        if (!success) {
                          // Revert on failure
                          setState(() {
                            _items = originalItems;
                          });
                        }
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

        final reqApprovals = _getRequiredApprovals(data['path'] as String? ?? '');
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
          txn.update(deletionDoc.reference, {'approvals': approvals, 'rejections': rejections});
        }
      });

      if (shouldExecuteDelete && targetPath != null) {
        try {
          final path = targetPath?.trim();
          if (path == null || path.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to delete item: missing target path.')),
            );
            return;
          }
          await _github.deleteItem(path);
          await deletionDoc.reference.update({
            'isDeleted': true,
            'status': 'executed',
            'executedAt': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File deleted successfully.'),
                backgroundColor: U.green,
              ),
            );
            _load();
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
                content: Text('Deletion failed. Please try again.'),
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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: U.red,
          ),
        );
      }
    }
  }

  void _showEditOptions(Map<String, dynamic> item, bool isFolder) {
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
          const SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: U.text),
            title: Text('Rename', style: GoogleFonts.outfit(color: U.text)),
            onTap: () {
              Navigator.pop(ctx);
              _showRenameDialog(item, isFolder);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: U.red),
            title: Text('Delete', style: GoogleFonts.outfit(color: U.red)),
            onTap: () {
              Navigator.pop(ctx);
              _requestDeletion(item);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Root-folder edit options: rename, change icon, and delete are offered at program level.
  void _showRootFolderEditOptions(Map<String, dynamic> item) {
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
          const SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: U.text),
            title: Text('Rename', style: GoogleFonts.outfit(color: U.text)),
            onTap: () {
              Navigator.pop(ctx);
              _showRenameDialog(item, true); // root is always a folder
            },
          ),
          ListTile(
            leading: Icon(Icons.palette_outlined, color: U.primary),
            title: Text('Change Icon', style: GoogleFonts.outfit(color: U.primary)),
            onTap: () {
              Navigator.pop(ctx);
              final path = item['path'] as String;
              _showIconPicker(path);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: U.red),
            title: Text(
              'Request Deletion',
              style: GoogleFonts.outfit(color: U.red),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _requestDeletion(item);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }



  /// Returns the effective deletion status for a doc.
  /// Handles legacy docs that lack the [status] field by falling back to [isDeleted].
  String _effectiveStatus(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String?;
    if (status != null) return status;
    return (data['isDeleted'] == true) ? 'executed' : 'pending';
  }

  /// Builds the trailing action widget for a pending-deletion list item.
  Widget _buildPendingTrailing(
    QueryDocumentSnapshot deletionDoc,
    bool hasApproved,
    bool hasRejected,
    bool isRequester,
    bool isExecuting,
    bool isFailed,
  ) {
    if (isExecuting) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(color: U.sub, strokeWidth: 2),
      );
    }
    if (isFailed) {
      return Icon(Icons.error_outline, color: U.red, size: 22);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            hasApproved ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt_rounded,
            color: hasApproved ? U.primary : U.sub,
            size: 20,
          ),
          onPressed: hasApproved ? null : () => _approveDeletion(deletionDoc),
        ),
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            hasRejected ? Icons.thumb_down_alt_rounded : Icons.thumb_down_off_alt_rounded,
            color: hasRejected ? U.red : U.sub,
            size: 20,
          ),
          onPressed: hasRejected ? null : () => _rejectDeletion(deletionDoc),
        ),
      ],
    );
  }

  void _rejectDeletion(QueryDocumentSnapshot deletionDoc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final freshSnap = await txn.get(deletionDoc.reference);
        if (!freshSnap.exists) return;

        final data = freshSnap.data() as Map<String, dynamic>;
        final effectiveStatus = data['status'] as String? ?? 'pending';

        if (effectiveStatus != 'pending') return;

        final approvals = List<String>.from(data['approvals'] ?? []);
        final rejections = List<String>.from(data['rejections'] ?? []);

        if (rejections.contains(user.uid)) return;

        // Add to rejections and remove from approvals
        rejections.add(user.uid);
        approvals.remove(user.uid);
        
        final netApprovals = approvals.length - rejections.length;
        if (netApprovals <= 0) {
          // Net approvals reached 0 — deletion request is fully cancelled, folder comes back alive
          txn.delete(deletionDoc.reference);
        } else {
          txn.update(deletionDoc.reference, {
            'approvals': approvals,
            'rejections': rejections,
          });
        }
      });

      if (mounted) {
        // Technically we deleted it if the list was empty, but locally we don't know the final state easily without duplicating logic. 
        // We can just show a generic success.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voted against deletion.'),
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

  void _cancelDeletion(QueryDocumentSnapshot deletionDoc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = deletionDoc.data() as Map<String, dynamic>;
    if (data['requesterUid'] != user.uid) return;

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final freshSnap = await txn.get(deletionDoc.reference);
        if (!freshSnap.exists) return;

        final freshData = freshSnap.data() as Map<String, dynamic>;
        final effectiveStatus = freshData['status'] as String? ?? 'pending';

        // Can only cancel while still pending
        if (effectiveStatus != 'pending') return;

        txn.delete(deletionDoc.reference);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deletion request removed.'),
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

  void _showFailedInfo(QueryDocumentSnapshot deletionDoc) {
    final data = deletionDoc.data() as Map<String, dynamic>;
    final reason = data['failureReason'] as String? ?? 'Unknown error';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.surface,
        title: Text(
          'Deletion Failed',
          style: GoogleFonts.outfit(
            color: U.text,
            fontWeight: FontWeight.w600,
          ),
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
    required String title,
    required String folderPath,
    required VoidCallback onTap,
    bool isPendingDeletion = false,
    int approvalCount = 0,
    bool isExecuting = false,
    bool isEditMode = false,
    DateTime? lastModified,
    QueryDocumentSnapshot? deletionDoc,
    bool hasApproved = false,
    bool hasRejected = false,
    bool isRequester = false,
    VoidCallback? onEditTap,
  }) {
    // Curated color pairs for vibrant gradients
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

    // Select color based on title hash
    final pairIndex = title.hashCode.abs() % colorPairs.length;
    final pair = colorPairs[pairIndex];

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isPendingDeletion
          ? const [Color(0xFF4B4B4B), Color(0xFF3A3A3A)]
          : [pair[0], pair[1]],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: isPendingDeletion
              ? []
              : [
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
                          final resolvedIcon = (iconKey != null && kFolderIconCatalogue.containsKey(iconKey))
                              ? kFolderIconCatalogue[iconKey]!.$1
                              : Icons.collections_bookmark_rounded;
                          return Icon(resolvedIcon, color: Colors.white, size: 22);
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
                    if (lastModified != null && !isPendingDeletion) ...[
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
              // Edit icon overlay when in edit mode (non-pending only)
              if (isEditMode && !isPendingDeletion && onEditTap != null)
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
              // Pending deletion: inline approve/reject or cancel icons
              if (isPendingDeletion && !isExecuting && deletionDoc != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isRequester
                        // Requester sees a cancel button
                        ? GestureDetector(
                            onTap: () => _cancelDeletion(deletionDoc),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          )
                        // Other users see thumbs up/down
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: hasApproved ? null : () => _approveDeletion(deletionDoc),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    hasApproved ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt_rounded,
                                    color: hasApproved ? Colors.greenAccent : Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: hasRejected ? null : () => _rejectDeletion(deletionDoc),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    hasRejected ? Icons.thumb_down_alt_rounded : Icons.thumb_down_off_alt_rounded,
                                    color: hasRejected ? Colors.redAccent : Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              // Pending deletion: progress bar at bottom
              if (isPendingDeletion && !isExecuting)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Text(
                          '$approvalCount/${_getRequiredApprovals(folderPath)} approvals',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      LinearProgressIndicator(
                        value: _getRequiredApprovals(folderPath) > 0
                            ? approvalCount / _getRequiredApprovals(folderPath)
                            : 0.0,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.grey,
                        ),
                        minHeight: 4,
                      ),
                    ],
                  ),
                ),
              if (isPendingDeletion && isExecuting)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    minHeight: 4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a subtitle widget showing deletion progress with a grey progress bar.
  Widget _buildDeletionProgressWidget(
    int approvalCount,
    bool isExecuting,
    bool isFailed,
    int reqApprovals,
  ) {
    if (isExecuting) {
      return Text(
        'Deletion in progress...',
        style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
      );
    }
    if (isFailed) {
      return Text(
        'Deletion failed — tap for details',
        style: GoogleFonts.outfit(color: U.red, fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Pending Deletion ($approvalCount/$reqApprovals approvals)',
          style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: reqApprovals > 0
              ? approvalCount / reqApprovals
              : 0.0,
          backgroundColor: U.border,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.grey),
          minHeight: 3,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
