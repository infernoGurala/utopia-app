import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../widgets/professional_loading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/class_model.dart';
import '../services/supabase_global_service.dart';
import '../services/class_service.dart';
import 'class_settings_screen.dart';
import 'note_viewer_screen.dart';
import '../widgets/genz_loading_overlay.dart';


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
class ClassDetailScreen extends StatefulWidget {
  final ClassModel classModel;
  final String universityFolderName;
  const ClassDetailScreen({
    super.key,
    required this.classModel,
    required this.universityFolderName,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final SupabaseGlobalService _github = SupabaseGlobalService.instance;
  List<Map<String, dynamic>> _items = [];
  bool _isEditMode = false;
  bool _warningShown = false;
  Map<String, String> _folderIcons = {};
  bool _isPushing = false;
  bool _loading = true;

  String get _iconsJsonPath => '${widget.universityFolderName}/${widget.classModel.classId}/Notes/.icons.json';

  Future<void> _loadFolderIcons() async {
    try {
      final icons = await _github.getFolderIcons('${widget.universityFolderName}/${widget.classModel.classId}/Notes/');
      if (mounted) {
        setState(() {
          _folderIcons.clear();
          _folderIcons.addAll(icons);
        });
      }
    } catch (_) {}
  }


  String _currentPath = '';
  List<String> _pathHistory = [''];

  String get _fullPath =>
      '${widget.universityFolderName}/${widget.classModel.classId}/Notes/$_currentPath';

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
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return d == 1 ? '1 day ago' : '$d days ago';
    }
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

  String _userRole = 'reader';

  @override
  void initState() {
    super.initState();
    _load();
    _checkRole();
    _fetchOwnerName();
  }

  String _ownerName = '';

  Future<void> _fetchOwnerName() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.classModel.creatorUid).get();
    if (doc.exists && mounted) {
      setState(() {
        _ownerName = doc.data()?['displayName'] ?? 'Unknown Admin';
      });
    }
  }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final role = await _classService.getUserRole(widget.classModel.classId, user.uid);
    if (mounted) setState(() => _userRole = role);
  }

  final ClassService _classService = ClassService();

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    final items = await _github.getDirectoryContents(_fullPath);
    if (!mounted) return;
    setState(() {
      _items = items.where((item) => item['name'] != '.keep' && !item['name'].toString().startsWith('.')).toList();
      _loading = false;
    });
    _loadFolderIcons();
  }

  void _navigateToFolder(String folderName) {
    setState(() {
      _currentPath = '$_currentPath$folderName/';
      _pathHistory.add(_currentPath);
      _loading = true;
    });
    _load();
  }


  Future<void> _setFolderIcon(String folderPath, String iconKey) async {
    setState(() => _isPushing = true);
    _folderIcons[folderPath] = iconKey;
    try {
      await _github.setFolderIcon(folderPath, iconKey);
    } catch (_) {}
    if (mounted) setState(() => _isPushing = false);
  }

  Future<void> _removeFolderIcon(String folderPath) async {
    setState(() => _isPushing = true);
    _folderIcons.remove(folderPath);
    try {
      await _github.setFolderIcon(folderPath, '');
    } catch (_) {}
    if (mounted) setState(() => _isPushing = false);
  }

  static String _displayName(String name) {
    final match = RegExp(r'__[0-9a-f]{4}$').firstMatch(name);
    if (match != null) return name.substring(0, match.start);
    return name;
  }

  static String _uniqueName(String displayName) {
    final code = (DateTime.now().millisecondsSinceEpoch & 0xFFFF).toRadixString(16).padLeft(4, '0');
    return '${displayName}__$code';
  }

  (IconData, Color) _iconFor(String name, String path) {
    final overrideKey = _folderIcons[path];
    if (overrideKey != null) {
      if (overrideKey.startsWith('num_')) {
        return (Icons.tag_outlined, U.teal);
      }
      if (kFolderIconCatalogue.containsKey(overrideKey)) {
        return (kFolderIconCatalogue[overrideKey]!.$1, U.primary);
      }
    }
    
    final key = name.toLowerCase();
    if (key.contains('doc') || key.contains('note')) return (Icons.article_outlined, U.primary);
    if (key.contains('assign')) return (Icons.assignment_outlined, U.peach);
    if (key.contains('quiz') || key.contains('test')) return (Icons.quiz_outlined, U.peach);
    
    return (Icons.folder_outlined, U.primary);
  }

  void _showRenameDialog(Map<String, dynamic> item, bool isFolder) {
    final oldName = item['name'] as String;
    final path = item['path'] as String;
    final displayOld = _displayName(oldName).replaceAll('.md', '');
    final controller = TextEditingController(text: displayOld);
    bool isRenaming = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: U.surface,
          title: Text('Rename', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
          content: TextField(
            controller: controller,
            style: GoogleFonts.outfit(color: U.text),
            decoration: InputDecoration(
              hintText: 'New name', hintStyle: GoogleFonts.outfit(color: U.sub),
              filled: true, fillColor: U.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: U.border)),
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
                      // Only add .md for files
                      if (!isFolder && !newName.endsWith('.md')) newName += '.md';

                      setDialogState(() => isRenaming = true);
                      Navigator.pop(ctx);

                      String ghNewName;
                      if (isFolder) {
                        final oldSuffixMatch = RegExp(r'__[0-9a-f]{4}$').firstMatch(oldName);
                        if (oldSuffixMatch != null) {
                          ghNewName = '$newName${oldSuffixMatch.group(0)}';
                        } else {
                          ghNewName = _uniqueName(newName);
                        }
                      } else {
                        ghNewName = newName;
                      }

                      final parentPath = path.substring(0, path.lastIndexOf('/'));
                      final newPath = parentPath.isEmpty ? ghNewName : '$parentPath/$ghNewName';

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
                          SnackBar(content: Text(success ? 'Renamed to $displayOld' : 'Failed to rename'), backgroundColor: success ? U.green : U.red),
                        );
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: U.primary),
              child: Text(isRenaming ? 'Renaming...' : 'Rename', style: GoogleFonts.outfit(color: U.bg)),
            ),
          ],
        ),
      ),
    );
  }

  void _showIconPicker(String folderPath) {
    final numController = TextEditingController();
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: U.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
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
                        filled: true, fillColor: U.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: U.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: U.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: U.teal)),
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
                      decoration: BoxDecoration(color: U.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
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
                        decoration: BoxDecoration(color: U.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('Reset', style: GoogleFonts.outfit(color: U.red, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: U.border, height: 1, thickness: 0.5),
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
                        child: Text(catName, style: GoogleFonts.outfit(color: U.dim, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8, runSpacing: 8,
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
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected ? U.primary.withValues(alpha: 0.15) : U.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSelected ? U.primary : U.border, width: isSelected ? 1.5 : 0.5),
                                ),
                                child: Icon(icon, color: isSelected ? U.primary : U.sub, size: 20),
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

  void _showDeleteDialog(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final path = item['path'] as String;
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
              if (countdown > 0) setDialogState(() => countdown--);
              else t.cancel();
            });
          }

          return AlertDialog(
            backgroundColor: U.surface,
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: U.red, size: 28),
                const SizedBox(width: 10),
                Text('Delete Item', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
              ],
            ),
            content: Text('Are you sure you want to permanently delete "$displayName"?\n\nThis action cannot be undone.', style: GoogleFonts.outfit(color: U.sub, fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () { timer?.cancel(); Navigator.pop(ctx); },
                child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
              ),
              FilledButton(
                onPressed: countdown > 0 || isDeleting ? null : () async {
                  setDialogState(() => isDeleting = true);
                  Navigator.pop(ctx);
                  
                  setState(() => _isPushing = true);
                  bool success = false;
                  try {
                    if (path.endsWith('.md')) {
                      await _github.deleteNote(path);
                    } else {
                      await _github.deleteFolder(path);
                    }
                    success = true;
                  } catch (e) {
                    debugPrint("Delete failed: $e");
                  }
                  if (success && mounted) {
                    await _load(forceRefresh: true);
                  }
                  if (mounted) setState(() => _isPushing = false);

                  if (mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "$displayName"'), backgroundColor: U.green));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete "$displayName"'), backgroundColor: U.red));
                    }
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: U.red, disabledBackgroundColor: U.red.withOpacity(0.3)),
                child: Text(isDeleting ? 'Deleting...' : (countdown > 0 ? 'Delete in ${countdown}s' : 'Delete Now'), style: GoogleFonts.outfit(color: U.bg)),
              ),
            ],
          );
        },
      ),
    ).then((_) { timer?.cancel(); });
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
          title: Text('Add Item', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('File', style: GoogleFonts.outfit(color: U.text, fontSize: 14)),
                      value: true,
                      groupValue: isFile,
                      onChanged: (v) => setDialogState(() => isFile = v!),
                      activeColor: U.primary,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Folder', style: GoogleFonts.outfit(color: U.text, fontSize: 14)),
                      value: false,
                      groupValue: isFile,
                      onChanged: (v) => setDialogState(() => isFile = v!),
                      activeColor: U.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: GoogleFonts.outfit(color: U.text),
                decoration: InputDecoration(
                  hintText: 'Name', hintStyle: GoogleFonts.outfit(color: U.sub),
                  filled: true, fillColor: U.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: U.border)),
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
              onPressed: isCreating ? null : () async {
                var name = controller.text.trim();
                if (name.isEmpty) return;
                if (isFile && !name.endsWith('.md')) name += '.md';
                final ghName = isFile ? name : _uniqueName(name);

                setDialogState(() => isCreating = true);
                Navigator.pop(ctx);

                final targetPath = isFile ? '$_fullPath$ghName' : '$_fullPath$ghName/.keep';

                setState(() => _isPushing = true);
                final parentPathStr = _fullPath.endsWith('/') ? _fullPath.substring(0, _fullPath.length - 1) : _fullPath;
                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                bool success = false;
                try {
                  if (isFile) {
                    final displayName = name.replaceAll('.md', '');
                    await _github.createNote(parentPathStr, displayName, '# $displayName\n\n', 'class', widget.universityFolderName, widget.classModel.classId, uid);
                  } else {
                    await _github.createFolder(parentPathStr, ghName, 'class', widget.universityFolderName, widget.classModel.classId, uid);
                  }
                  success = true;
                } catch (e) {
                  debugPrint("Create failed: $e");
                }

                if (success && mounted) {
                  await _load(forceRefresh: true);
                }
                if (mounted) setState(() => _isPushing = false);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? '$name created!' : 'Failed to create $name'), backgroundColor: success ? U.green : U.red),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: U.primary),
              child: Text(isCreating ? 'Creating...' : 'Create', style: GoogleFonts.outfit(color: U.bg)),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateBack() {
    if (_pathHistory.length <= 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _pathHistory.removeLast();
      _currentPath = _pathHistory.last;
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAtRoot = _currentPath.isEmpty;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.classModel.name, style: GoogleFonts.outfit()),
            if (_ownerName.isNotEmpty)
              Text(
                'Owned by $_ownerName',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: U.sub,
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
          if (_isEditMode)
            IconButton(
              icon: Icon(Icons.add_rounded, color: U.primary, size: 24),
              onPressed: _showAddItemDialog,
            ),
          if (_userRole == 'writer') ...[
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
                        setState(() => _isEditMode = !_isEditMode);
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
            IconButton(
              icon: Icon(Icons.settings_outlined, color: U.sub),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassSettingsScreen(classModel: widget.classModel, userRole: _userRole),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _loading
                ? ProfessionalLoading(message: 'Loading notes...')
                : _items.isEmpty
                ? Center(
                    child: Text(
                      'No notes yet.',
                      style: GoogleFonts.outfit(color: U.sub),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 116),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => Divider(
                      color: U.border,
                      height: 1,
                      thickness: 0.5,
                      indent: 56,
                    ),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final name = item['name'] as String;
                      final type = item['type'] as String;
                      final path = item['path'] as String;
                      final isFolder = type == 'dir';

                      final displayTitle = _displayName(name).replaceAll('.md', '');
                      final iconData = _iconFor(name, path);

                      final palette = [
                        U.teal,
                        U.teal,
                        U.peach,
                        U.primary,
                        U.blue,
                        U.lavender,
                        U.gold,
                        U.red,
                      ];
                      final itemColor = isFolder ? palette[index % palette.length] : U.sub;

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
                          onTap: () {
                            if (isFolder) {
                              _navigateToFolder(name);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NoteViewerScreen(
                                    title: displayTitle,
                                    filePath: path,
                                    isEditable: _isEditMode && _userRole == 'writer',
                                    useGlobalRepo: true,
                                  ),
                                ),
                              );
                            }
                          },
                          splashColor: itemColor.withOpacity(0.06),
                          highlightColor: itemColor.withOpacity(0.04),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                  () {
                                    final iconKey = _folderIcons[path];
                                    if (iconKey != null && iconKey.startsWith('num_')) {
                                      final numText = iconKey.replaceFirst('num_', '');
                                      return Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(color: itemColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Center(
                                          child: Text(
                                            numText,
                                            style: GoogleFonts.outfit(color: itemColor, fontSize: 12, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      );
                                    }
                                    if (iconKey != null && kFolderIconCatalogue.containsKey(iconKey)) {
                                      return Icon(kFolderIconCatalogue[iconKey]!.$1, color: isFolder ? itemColor : U.primary, size: isFolder ? 26 : 22);
                                    }
                                    return Icon(iconData.$1, color: isFolder ? itemColor : iconData.$2, size: isFolder ? 26 : 22);
                                  }(),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayTitle.trim(),
                                        style: GoogleFonts.outfit(
                                          color: U.text,
                                          fontSize: 16,
                                          fontWeight: isFolder ? FontWeight.w500 : FontWeight.w400,
                                        ),
                                      ),
                                      if (!isFolder && item['size'] != null && !name.toLowerCase().endsWith('.md'))
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _formatFileSize(item['size'] as int),
                                            style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                                          ),
                                        ),
                                      if (_isEditMode && (item['updated_at'] != null || item['created_at'] != null))
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.schedule_rounded, size: 11, color: U.dim),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatRelativeTime(DateTime.parse((item['updated_at'] ?? item['created_at']) as String)),
                                                style: GoogleFonts.outfit(color: U.dim, fontSize: 11, fontWeight: FontWeight.w400),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (_isEditMode && _userRole == 'writer')
                                  PopupMenuButton<String>(
                                    color: U.surface,
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Actions',
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Center(child: Icon(Icons.more_vert, color: U.dim, size: 16)),
                                    ),
                                    splashRadius: 18,
                                    onSelected: (value) {
                                      if (value == 'edit') _showRenameDialog(item, isFolder);
                                      if (value == 'icon') _showIconPicker(path);
                                      if (value == 'delete') _showDeleteDialog(item);
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
                                            Text('Rename', style: GoogleFonts.outfit(color: U.text, fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'icon',
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.palette_outlined, color: U.primary, size: 14),
                                            const SizedBox(width: 6),
                                            Text('Change Icon', style: GoogleFonts.outfit(color: U.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.delete_outline, color: U.red, size: 14),
                                            const SizedBox(width: 6),
                                            Text('Delete', style: GoogleFonts.outfit(color: U.red, fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_isPushing) const GenZLoadingOverlay(),
          ],
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
