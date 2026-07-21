import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../services/class_service.dart';
import '../models/class_model.dart';
import '../widgets/utopia_loader.dart';
import '../services/supabase_global_service.dart';
import 'class_detail_screen.dart';
import 'class_settings_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final ClassService _classService = ClassService();
  List<ClassModel> _classes = [];
  bool _isLoading = true;
  String _universityId = '';
  Set<String> _pinnedClassIds = {};

  @override
  void initState() {
    super.initState();
    _loadUniversityAndData();
  }

  Future<void> _loadUniversityAndData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load university id
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final uniId = userDoc.data()?['selectedUniversityId'] as String? ?? U.cachedUniversityId;
      _universityId = uniId;

      // Load pinned classes from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final pinned = prefs.getStringList('pinned_classes_ids') ?? [];
      _pinnedClassIds = pinned.toSet();

      // Load classes
      final classes = await _classService.getClassesForUser(user.uid, universityId: _universityId);
      
      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePinnedClasses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_classes_ids', _pinnedClassIds.toList());
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
  }

  Future<void> _refreshData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final classes = await _classService.getClassesForUser(user.uid, universityId: _universityId);
      if (mounted) {
        setState(() {
          _classes = classes;
        });
      }
    } catch (e) {
      debugPrint('Refresh failed: $e');
    }
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
                                if (user == null || _universityId.isEmpty) return;

                                setSheetState(() => isCreating = true);
                                final newClass = await _classService.createClass(name, _universityId, user.uid);

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

                                final classes = await _classService.getClassesForUser(user.uid, universityId: _universityId);
                                if (mounted) {
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
                                      content: Text('Failed to create class: $e'),
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
                                await _classService.joinClassByCode(code, user.uid);
                                final classes = await _classService.getClassesForUser(user.uid, universityId: _universityId);
                                if (mounted) {
                                  setState(() => _classes = classes);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Joined successfully!')),
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
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
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
                    child: Icon(Icons.class_rounded, color: U.peach, size: 20),
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
                          style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: U.border.withValues(alpha: 0.5), height: 1),
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
                    style: GoogleFonts.outfit(color: U.dim, fontSize: 12),
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
                _pinnedClassIds.remove(c.classId);
                _savePinnedClasses();
                await _refreshData();
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

  @override
  Widget build(BuildContext context) {
    final theme = appThemeNotifier.value;
    final isDark = theme.isDark;

    // Sort classes: pinned first, then by name
    final sortedClasses = List<ClassModel>.from(_classes)
      ..sort((a, b) {
        final aPinned = _pinnedClassIds.contains(a.classId);
        final bPinned = _pinnedClassIds.contains(b.classId);
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Classes',
          style: GoogleFonts.outfit(
            color: U.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: U.text),
            onPressed: _showNewClassMenu,
            tooltip: 'Add / Join Class',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: UtopiaLoader(scale: 0.7))
            : sortedClasses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: U.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.group_work_outlined,
                              color: U.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Classes Joined',
                            style: GoogleFonts.outfit(
                              color: U.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your own study group or join an existing class using a code shared by your classmate.',
                            style: GoogleFonts.plusJakartaSans(
                              color: U.sub,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: _showNewClassMenu,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              'Get Started',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: U.primary,
                              foregroundColor: U.bg,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshData,
                    color: U.primary,
                    backgroundColor: U.card,
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.88,
                      ),
                      itemCount: sortedClasses.length,
                      itemBuilder: (context, index) {
                        final c = sortedClasses[index];
                        final isPinned = _pinnedClassIds.contains(c.classId);
                        
                        return GestureDetector(
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
                              _refreshData();
                            }
                          },
                          onLongPress: () => _showClassLongPressMenu(c),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: U.card,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: U.border.withValues(alpha: 0.7),
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDark ? Colors.black : theme.primary)
                                          .withValues(alpha: isDark ? 0.25 : 0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            U.peach.withValues(alpha: 0.18),
                                            U.peach.withValues(alpha: 0.05),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.class_rounded,
                                          color: U.peach,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      c.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: U.text,
                                        letterSpacing: -0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${c.memberCount} member${c.memberCount == 1 ? '' : 's'}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: U.sub,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                              if (isPinned)
                                Positioned(
                                  top: 14,
                                  right: 14,
                                  child: Icon(Icons.push_pin_rounded, size: 14, color: U.primary),
                                ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 350.ms).slideY(
                              begin: 0.1,
                              end: 0,
                              duration: 350.ms,
                              curve: Curves.easeOutCubic,
                            );
                      },
                    ),
                  ),
      ),
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
