import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/class_model.dart';
import '../services/class_service.dart';
import '../services/github_global_service.dart';
import 'class_detail_screen.dart';
import 'class_settings_screen.dart';
import 'community_notes_screen.dart';
import 'notification_history_screen.dart';
import 'sciwordle_screen.dart';
import 'timetable_screen.dart';

class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({super.key});

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  final ClassService _classService = ClassService();
  final GitHubGlobalService _githubGlobalService = GitHubGlobalService();

  static const _moodWords = [
    'focus',
    'clarity',
    'rhythm',
    'revision',
    'momentum',
    'depth',
    'calm',
    'signal',
  ];

  String get _moodWord =>
      _moodWords[DateTime.now().microsecondsSinceEpoch % _moodWords.length];

  String _universityId = '';
  List<ClassModel> _classes = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isLoadingActive = false;
  final Map<String, String> _ownerNames = {};
  Set<String> _pinnedClassIds = {};

  @override
  void initState() {
    super.initState();
    _loadPinnedClasses();
    _loadData();
  }

  // ── Pinned classes persistence ──
  Future<void> _loadPinnedClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = prefs.getStringList('pinned_class_ids');
    if (pinned != null && mounted) {
      setState(() => _pinnedClassIds = pinned.toSet());
    }
  }

  Future<void> _savePinnedClasses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_class_ids', _pinnedClassIds.toList());
  }

  void _togglePin(String classId) {
    setState(() {
      if (_pinnedClassIds.contains(classId)) {
        _pinnedClassIds.remove(classId);
      } else {
        _pinnedClassIds.add(classId);
      }
    });
    _savePinnedClasses();
    HapticFeedback.lightImpact();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // Guard against duplicate concurrent calls
    if (_isLoadingActive) return;
    _isLoadingActive = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      debugPrint('LIBRARY: Loading for user=${user.uid}');

      setState(() {
        if (forceRefresh) {
          _isSyncing = true;
        } else if (_classes.isEmpty) {
          _isLoading = true;
        } else {
          _isSyncing = true;
        }
      });

      // ── Phase 1: Cache-first (instant) ──
      if (!forceRefresh) {
        try {
          final cachedUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.cache));

          final cachedUniId =
              cachedUserDoc.data()?['selectedUniversityId'] as String?;
          if (cachedUniId != null) {
            _universityId = cachedUniId;
            final cachedClasses =
                await _classService.getClassesForUser(user.uid, universityId: _universityId, fromCache: true);
            if (mounted && cachedClasses.isNotEmpty) {
              setState(() {
                _classes = cachedClasses;
                _isLoading = false;
              });
            }
          }
        } catch (_) {
          // Cache miss — fall through to server fetch
        }
      }

      // ── Phase 2: Server sync ──
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));

      final uniId = userDoc.data()?['selectedUniversityId'] as String?;

      if (uniId != null) {
        _universityId = uniId;
        unawaited(_githubGlobalService.ensureUniversityFolderExists(uniId));
        unawaited(_preloadCommunityIcons());
      }

      final classes = await _classService.getClassesForUser(user.uid, universityId: _universityId);

      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
          _isSyncing = false;
        });
      }

      // Fetch owner display names for all classes
      _fetchOwnerNames(classes);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSyncing = false;
        });
      }
    } finally {
      _isLoadingActive = false;
    }
  }

  /// Preload community icons seamlessly to local memory so CommunityNotesScreen has zero pop-in.
  Future<void> _preloadCommunityIcons() async {
    if (_universityId.isEmpty) return;
    final path = '$_universityId/Community/.icons.json';
    try {
      final content = await _githubGlobalService.getFileContentRaw(path);
      if (content.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache_$path', content);
      }
    } catch (_) {}
  }

  /// Fetch display names for class owners and cache them.
  Future<void> _fetchOwnerNames(List<ClassModel> classes) async {
    final uidsToFetch = <String>{};
    for (final c in classes) {
      if (c.creatorUid.isNotEmpty && !_ownerNames.containsKey(c.creatorUid)) {
        uidsToFetch.add(c.creatorUid);
      }
    }
    if (uidsToFetch.isEmpty) return;
    for (final uid in uidsToFetch) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final name = doc.data()?['displayName'] as String? ?? '';
        if (mounted && name.isNotEmpty) {
          setState(() => _ownerNames[uid] = name);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Utopia',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: U.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedOpacity(
                        opacity: (_isLoading || _isSyncing) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 50,
                            child: LinearProgressIndicator(
                              backgroundColor: U.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                U.primary,
                              ),
                              minHeight: 2,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.calendar_today_rounded, color: U.sub, size: 20),
                        tooltip: 'Timetable',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TimetableScreen()),
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.notifications_none_rounded, color: U.sub, size: 22),
                        tooltip: 'Notifications',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_moodWord ',
                        style: GoogleFonts.outfit(
                          color: U.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '•',
                        style: GoogleFonts.outfit(color: U.dim, fontSize: 13),
                      ),
                      Text(
                        ' Library',
                        style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading && _classes.isEmpty
                  ? Center(child: CircularProgressIndicator(color: U.primary))
                  : RefreshIndicator(
                      color: U.primary,
                      backgroundColor: U.surface,
                      onRefresh: () => _loadData(forceRefresh: true),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        childAspectRatio: 1.0,
                        children: [
                          // ── Community Notes (Design A) ──
                          _buildCommunityTile(context),

                          // ── SciWordle (Design I) ──
                          _buildSciWordleTile(context),

                          // ── User classes (pinned first) ──
                          ...(() {
                            final sorted = List<ClassModel>.from(_classes);
                            sorted.sort((a, b) {
                              final aPinned = _pinnedClassIds.contains(a.classId);
                              final bPinned = _pinnedClassIds.contains(b.classId);
                              if (aPinned && !bPinned) return -1;
                              if (!aPinned && bPinned) return 1;
                              return 0;
                            });
                            return sorted;
                          })().map(
                            (c) => _buildClassTile(context, c),
                          ),

                          // ── Create / Join ──
                          _buildActionTile(
                            label: 'CREATE',
                            icon: Icons.add_circle_outline,
                            onTap: _showCreateClassSheet,
                          ),
                          _buildActionTile(
                            label: 'JOIN',
                            icon: Icons.group_add_outlined,
                            onTap: _showJoinClassSheet,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Community Notes — Design A "Centered Ring"
  // ──────────────────────────────────────────────────────────────────
  Widget _buildCommunityTile(BuildContext context) {
    final accent = U.teal;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityNotesScreen(
              universityFolderName: _universityId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              U.surface,
              Color.lerp(U.surface, U.bg, 0.65)!,
            ],
          ),
          border: Border.all(color: U.border.withValues(alpha: 0.6), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            children: [
              Positioned(
                right: -10, bottom: -10,
                child: Icon(Icons.groups_rounded, size: 75, color: accent.withValues(alpha: 0.05)),
              ),
              Positioned(
                top: 0, left: 20, right: 20,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(colors: [
                      accent.withValues(alpha: 0.0),
                      accent.withValues(alpha: 0.45),
                      accent.withValues(alpha: 0.0),
                    ]),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.08),
                          border: Border.all(color: accent.withValues(alpha: 0.22), width: 1),
                        ),
                        child: Icon(Icons.groups_rounded, color: accent, size: 26),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'COMMUNITY',
                        style: GoogleFonts.outfit(
                          color: U.text, fontSize: 11.5,
                          letterSpacing: 1.8, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // SciWordle — Design I "Radial Glow"
  // ──────────────────────────────────────────────────────────────────
  Widget _buildSciWordleTile(BuildContext context) {
    final accent = U.primary;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SciwordleScreen()),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Color.lerp(U.bg, U.surface, 0.3),
          border: Border.all(color: U.border.withValues(alpha: 0.4), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.12),
                          accent.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: accent, size: 32),
                    const SizedBox(height: 14),
                    Text(
                      'SCIWORDLE',
                      style: GoogleFonts.outfit(
                        color: U.text, fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Class card — Design K "Corner Bracket"
  // ──────────────────────────────────────────────────────────────────
  Widget _buildClassTile(BuildContext context, ClassModel c) {
    final accent = U.peach;
    final isPinned = _pinnedClassIds.contains(c.classId);
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassDetailScreen(
              classModel: c,
              universityFolderName: _universityId,
            ),
          ),
        );
        if (mounted) {
          _loadData(forceRefresh: true);
        }
      },
      onLongPress: () => _showClassLongPressMenu(c),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: U.surface,
          border: Border.all(
            color: isPinned
                ? U.primary.withValues(alpha: 0.35)
                : U.border.withValues(alpha: 0.45),
            width: isPinned ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: CustomPaint(
            painter: _CornerBracketPainter(accent.withValues(alpha: 0.4)),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, color: accent, size: 30),
                      const SizedBox(height: 12),
                      Text(
                        c.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: U.text, fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      if (_ownerNames[c.creatorUid] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _ownerNames[c.creatorUid]!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: U.sub,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Pin indicator
                if (isPinned)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: U.primary.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Long press context menu for class cards
  // ──────────────────────────────────────────────────────────────────
  void _showClassLongPressMenu(ClassModel c) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final isOwner = c.creatorUid == user.uid;
    final isPinned = _pinnedClassIds.contains(c.classId);

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: U.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: U.border.withValues(alpha: 0.5), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: U.peach.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: U.peach, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: GoogleFonts.outfit(
                            color: U.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isOwner ? 'Owner' : 'Member',
                          style: GoogleFonts.outfit(
                            color: U.sub,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: U.border.withValues(alpha: 0.5), height: 1),
            // ── Pin / Unpin ──
            _buildMenuOption(
              icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              label: isPinned ? 'Unpin Class' : 'Pin Class',
              subtitle: isPinned ? 'Remove from top of list' : 'Keep at top of class list',
              color: U.primary,
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(c.classId);
              },
            ),
            // ── Properties (owner only) ──
            if (isOwner)
              _buildMenuOption(
                icon: Icons.settings_outlined,
                label: 'Properties',
                subtitle: 'Manage writers, share code, delete',
                color: U.sub,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassSettingsScreen(classModel: c),
                    ),
                  );
                },
              ),
            // ── Exit class (non-owner only) ──
            if (!isOwner)
              _buildMenuOption(
                icon: Icons.exit_to_app_rounded,
                label: 'Exit Class',
                subtitle: 'Leave this class permanently',
                color: U.red,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmExitClass(c);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: color == U.red ? U.red : U.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: U.dim,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: U.dim, size: 18),
          ],
        ),
      ),
    );
  }

  void _confirmExitClass(ClassModel c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: U.red, size: 24),
            const SizedBox(width: 10),
            Text(
              'Exit Class',
              style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to leave "${c.name}"?\n\nYou will need the class code to rejoin.',
          style: GoogleFonts.outfit(color: U.sub, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                await _classService.leaveClass(c.classId, user.uid);
                // Remove from local pinned list if pinned
                _pinnedClassIds.remove(c.classId);
                _savePinnedClasses();
                // Refresh class list
                await _loadData(forceRefresh: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Left "${c.name}" successfully.'),
                      backgroundColor: U.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to leave class: $e'),
                      backgroundColor: U.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: U.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Exit', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Action tiles — Create / Join
  // ──────────────────────────────────────────────────────────────────
  Widget _buildActionTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: U.surface,
          border: Border.all(color: U.border.withValues(alpha: 0.35), width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: U.sub, size: 28),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: U.sub, fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateClassSheet() {
    final TextEditingController nameController = TextEditingController();
    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a Class',
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.outfit(color: U.text),
                    decoration: InputDecoration(
                      hintText: 'Class name',
                      hintStyle: GoogleFonts.outfit(color: U.sub),
                      filled: true,
                      fillColor: U.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: U.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: U.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: isCreating
                        ? Center(
                            child: CircularProgressIndicator(color: U.primary),
                          )
                        : FilledButton(
                            onPressed: () async {
                              try {
                                final name = nameController.text.trim();
                                if (name.isEmpty) return;

                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null || _universityId.isEmpty)
                                  return;

                                setSheetState(() => isCreating = true);
                                final newClass = await _classService
                                    .createClass(name, _universityId, user.uid);

                                try {
                                  await _githubGlobalService
                                      .ensureClassFolderExists(
                                        _universityId,
                                        newClass.classId,
                                      );
                                } catch (_) {}

                                final classes = await _classService
                                    .getClassesForUser(user.uid, universityId: _universityId);
                                if (mounted && mounted) {
                                  setState(() => _classes = classes);
                                  if (Navigator.canPop(bottomSheetContext)) {
                                    Navigator.pop(bottomSheetContext);
                                  }
                                }
                              } catch (e) {
                                setSheetState(() => isCreating = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to create class: $e',
                                      ),
                                      backgroundColor: U.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: U.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Create',
                              style: GoogleFonts.outfit(
                                color: U.bg,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showJoinClassSheet() {
    final TextEditingController codeController = TextEditingController();
    bool isJoining = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join a Class',
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    ],
                    style: GoogleFonts.outfit(color: U.text),
                    decoration: InputDecoration(
                      hintText: 'Enter 6-character class code',
                      hintStyle: GoogleFonts.outfit(color: U.sub),
                      filled: true,
                      fillColor: U.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: U.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: U.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: isJoining
                        ? Center(
                            child: CircularProgressIndicator(color: U.primary),
                          )
                        : FilledButton(
                            onPressed: () async {
                              final code = codeController.text
                                  .trim()
                                  .toUpperCase();
                              if (code.length != 6) return;

                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;

                              setSheetState(() => isJoining = true);
                              try {
                                await _classService.joinClassByCode(
                                  code,
                                  user.uid,
                                );
                                final classes = await _classService
                                    .getClassesForUser(user.uid, universityId: _universityId);
                                if (mounted) {
                                  setState(() => _classes = classes);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Joined successfully!'),
                                    ),
                                  );
                                  if (Navigator.canPop(bottomSheetContext)) {
                                    Navigator.pop(bottomSheetContext);
                                  }
                                }
                              } catch (e) {
                                setSheetState(() => isJoining = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Class not found. Check the code.',
                                      ),
                                      backgroundColor: U.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: U.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Join',
                              style: GoogleFonts.outfit(
                                color: U.bg,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}



class _CornerBracketPainter extends CustomPainter {
  _CornerBracketPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const len = 22.0;
    const inset = 14.0;

    // Top-left bracket
    canvas.drawLine(const Offset(inset, inset), const Offset(inset + len, inset), paint);
    canvas.drawLine(const Offset(inset, inset), const Offset(inset, inset + len), paint);

    // Bottom-right bracket
    canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset - len, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
