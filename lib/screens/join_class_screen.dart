import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../services/class_service.dart';

class JoinClassScreen extends StatefulWidget {
  final String classCode;
  const JoinClassScreen({super.key, required this.classCode});

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen>
    with SingleTickerProviderStateMixin {
  final ClassService _classService = ClassService();
  bool _joining = false;
  bool _joined = false;
  String? _error;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _joinClass() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'You must be signed in to join a class.');
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      await _classService.joinClassByCode(widget.classCode, user.uid);
      if (mounted) {
        setState(() {
          _joining = false;
          _joined = true;
        });
        // Pop back to root after a brief delay so the user sees success
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _joining = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: U.text),
        title: Text(
          'Join Class',
          style: GoogleFonts.outfit(
            color: U.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  return Opacity(
                    opacity: _pulseAnim.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: U.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: U.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _joined
                        ? Icons.check_rounded
                        : Icons.group_add_rounded,
                    color: _joined ? U.green : U.primary,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                _joined
                    ? 'You\'re in!'
                    : 'You\'ve been invited',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: U.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _joined
                    ? 'Successfully joined the class.'
                    : 'Someone shared a class link with you.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: U.sub,
                ),
              ),
              const SizedBox(height: 32),

              // Class code card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: U.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: U.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'CLASS CODE',
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.classCode,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: U.primary,
                        letterSpacing: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: U.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: U.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.outfit(
                      color: U.red,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Join button
              if (!_joined)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _joining ? null : _joinClass,
                    icon: _joining
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: U.bg,
                            ),
                          )
                        : const Icon(Icons.login_rounded, size: 18),
                    label: Text(
                      _joining ? 'Joining...' : 'Join Class',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: U.primary,
                      foregroundColor: U.bg,
                      disabledBackgroundColor:
                          U.primary.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

              // Success checkmark
              if (_joined)
                Icon(Icons.check_circle_rounded,
                    color: U.green, size: 48),
            ],
          ),
        ),
      ),
    );
  }
}
