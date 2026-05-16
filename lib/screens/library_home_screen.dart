import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/class_model.dart';
import '../widgets/bouncing_loader.dart';
import '../services/class_service.dart';
import '../services/supabase_global_service.dart';
import 'class_detail_screen.dart';
import 'class_settings_screen.dart';
import 'community_notes_screen.dart';
import 'timetable_screen.dart';

class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({super.key});

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  final ClassService _classService = ClassService();
  final SupabaseGlobalService _globalService = SupabaseGlobalService.instance;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: U.bg,
      body: Stack(
        children: [
          // Background Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: Opacity(
              opacity: isDark ? 0.3 : 0.6,
              child: Image.asset(
                'assets/semesters/background.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          // Gradient fade for background
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.2,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.25,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    U.bg.withValues(alpha: 0.0),
                    U.bg,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Semesters',
                              style: GoogleFonts.playfairDisplay(
                                color: U.text,
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.normal,
                                letterSpacing: -1,
                              ),
                            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                            const SizedBox(height: 4),
                            Text(
                              'Access your academic resources',
                              style: GoogleFonts.outfit(color: U.dim, fontSize: 14, fontWeight: FontWeight.w400),
                            ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedOpacity(
                            opacity: (_isLoading || _isSyncing) ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 400),
                            child: SizedBox(
                              width: 30,
                              child: LinearProgressIndicator(
                                backgroundColor: U.border,
                                valueColor: AlwaysStoppedAnimation<Color>(U.primary),
                                minHeight: 2,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: U.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(Icons.calendar_month_rounded, color: U.text, size: 20),
                              tooltip: 'Timetable',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const TimetableScreen()),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ).animate().fadeIn(delay: 200.ms, duration: 500.ms).scale(curve: Curves.easeOutBack),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
              child: _isLoading && _classes.isEmpty
                  ? Center(child: BouncingLoader(color: U.primary))
                  : RefreshIndicator(
                      color: U.primary,
                      backgroundColor: U.surface,
                      onRefresh: () => _loadData(forceRefresh: true),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                        childAspectRatio: 0.75,
                        children: <Widget>[
                          // ── Community Notes (Design A) ──
                          _buildCommunityTile(context),

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

                          // ── New Class ──
                          _buildActionTile(
                            label: 'NEW CLASS',
                            icon: Icons.add_circle_outline,
                            onTap: _showNewClassMenu,
                          ),
                        ].asMap().entries.map((e) {
                          return e.value.animate()
                            .fadeIn(delay: (100 + e.key * 50).ms, duration: 500.ms)
                            .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
      ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Community Notes
  // ──────────────────────────────────────────────────────────────────
  Widget _buildCommunityTile(BuildContext context) {
    return _buildModernCard(
      context: context,
      title: 'COMMUNITY',
      description: 'Connect, collaborate\nand grow together',
      icon: Icons.people_alt_rounded,
      color: U.blue,
      topRightBracket: true,
      backgroundShape: Icon(Icons.bubble_chart, size: 100, color: U.blue.withValues(alpha: 0.04)),
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
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Class card — Design K "Corner Bracket"
  // ──────────────────────────────────────────────────────────────────
  Widget _buildClassTile(BuildContext context, ClassModel c) {
    final isPinned = _pinnedClassIds.contains(c.classId);
    return GestureDetector(
      onLongPress: () => _showClassLongPressMenu(c),
      child: _buildModernCard(
        context: context,
        title: c.name.toUpperCase(),
        description: 'Explore notes, PYQs\nand study material',
        icon: Icons.menu_book_rounded,
        color: U.peach,
        topRightBracket: false,
        backgroundShape: Icon(Icons.settings, size: 110, color: U.peach.withValues(alpha: 0.05)),
        showPin: isPinned,
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
                        builder: (_) => ClassSettingsScreen(classModel: c, userRole: isOwner ? 'writer' : 'reader'),
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
    return _buildModernCard(
      context: context,
      title: label,
      description: 'Create a new class\nand get started',
      icon: Icons.add_circle_outline,
      color: U.teal,
      topRightBracket: false,
      backgroundShape: Icon(Icons.layers, size: 110, color: U.teal.withValues(alpha: 0.05)),
      onTap: onTap,
    );
  }

  Widget _buildModernCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool topRightBracket,
    Widget? backgroundShape,
    bool showPin = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: U.surface,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Shapes
              if (backgroundShape != null)
                Positioned(
                  right: -25,
                  bottom: -25,
                  child: backgroundShape,
                ),
              // Corner Bracket
              Positioned(
                top: 0,
                right: topRightBracket ? 0 : null,
                left: topRightBracket ? null : 0,
                child: CustomPaint(
                  size: const Size(48, 48),
                  painter: _SolidTrianglePainter(color: color, topRight: topRightBracket),
                ),
              ),
              if (showPin)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Icon(Icons.push_pin_rounded, size: 18, color: color.withValues(alpha: 0.6)),
                ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circular Icon
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: U.surface,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white,
                            color.withValues(alpha: 0.08),
                          ]
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.15),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                          const BoxShadow(
                            color: Colors.white,
                            blurRadius: 12,
                            spreadRadius: 4,
                            offset: Offset(-4, -4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(icon, color: color, size: 28),
                      ),
                    ),
                    const Spacer(),
                    // Title
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: U.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Dash
                    Container(
                      width: 24,
                      height: 3,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Description
                    Text(
                      description,
                      style: GoogleFonts.outfit(
                        color: U.dim,
                        fontSize: 10.5,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Bottom Left Arrow
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(Icons.arrow_forward_rounded, color: color, size: 16),
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

  void _showNewClassMenu() {
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
            decoration: BoxDecoration(color: U.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.group_add_outlined, color: U.text),
            title: Text('Join a Class', style: GoogleFonts.outfit(color: U.text)),
            subtitle: Text('Enter a 6-character code', style: GoogleFonts.outfit(color: U.sub, fontSize: 13)),
            onTap: () {
              Navigator.pop(ctx);
              _showJoinClassSheet();
            },
          ),
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: U.primary),
            title: Text('Create a Class', style: GoogleFonts.outfit(color: U.primary)),
            subtitle: Text('Start a new shared folder', style: GoogleFonts.outfit(color: U.sub, fontSize: 13)),
            onTap: () {
              Navigator.pop(ctx);
              _showCreateClassSheet();
            },
          ),
          const SizedBox(height: 24),
        ],
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
                                  await SupabaseGlobalService.instance.createFolder(
                                    '${_universityId}/${newClass.classId}',
                                    'Notes',
                                    'class',
                                    _universityId,
                                    newClass.classId,
                                    user.uid,
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
                              String rawCode = codeController.text.trim();
                              if (rawCode.contains('/join/')) {
                                rawCode = rawCode.split('/join/').last;
                              }
                              
                              final code = rawCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
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
                                        e.toString().replaceAll('Exception: ', ''),
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



class _SolidTrianglePainter extends CustomPainter {
  final Color color;
  final bool topRight;

  _SolidTrianglePainter({required this.color, required this.topRight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color, color.withValues(alpha: 0.5)],
        begin: topRight ? Alignment.topRight : Alignment.topLeft,
        end: topRight ? Alignment.bottomLeft : Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    if (topRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(0, size.height);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SolidTrianglePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.topRight != topRight;
  }
}
