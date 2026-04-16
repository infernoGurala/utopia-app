import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/class_model.dart';
import '../services/class_service.dart';
import '../services/github_global_service.dart';
import 'class_detail_screen.dart';
import 'community_notes_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
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

      // Fetch user doc first to get the universityId
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final uniId = userDoc.data()?['selectedUniversityId'] as String?;
      debugPrint('LIBRARY: selectedUniversityId=$uniId');

      if (uniId != null) {
        _universityId = uniId;
        unawaited(_githubGlobalService.ensureUniversityFolderExists(uniId));
      }

      // Fetch all classes for user
      debugPrint('LIBRARY: Fetching all classes for user');
      final classes = await _classService.getClassesForUser(user.uid);

      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
          _isSyncing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSyncing = false;
        });
      }
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
                    mainAxisSize: MainAxisSize.min,
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
                          _buildCard(
                            title: 'Community Notes',
                            icon: Icons.groups_rounded,
                            backgroundColor: U.card,
                            iconColor: U.teal,
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
                          ),
                          ..._classes.map(
                            (c) => _buildCard(
                              title: c.name,
                              icon: Icons.folder_rounded,
                              backgroundColor: U.surface,
                              iconColor: U.primary,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClassDetailScreen(
                                      classModel: c,
                                      universityFolderName: _universityId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildCard(
                            title: 'Create a Class',
                            icon: Icons.add_circle_outline,
                            backgroundColor: U.surface,
                            iconColor: U.sub,
                            onTap: _showCreateClassSheet,
                          ),
                          _buildCard(
                            title: 'Join a Class',
                            icon: Icons.group_add_outlined,
                            backgroundColor: U.surface,
                            iconColor: U.sub,
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

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 32),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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
                                    .getClassesForUser(user.uid);
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
                                    .getClassesForUser(user.uid);
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
