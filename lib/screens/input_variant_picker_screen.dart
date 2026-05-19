import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';

/// Temporary screen: shows 5 input field design variants.
/// Delete once the user picks one.
class InputVariantPickerScreen extends StatelessWidget {
  const InputVariantPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        title: Text('Pick your style', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: U.text),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          _VariantBlock(
            number: 1,
            label: 'Ghost Line',
            description: 'Just a bottom divider — Notion-style',
            accentColor: U.teal,
            child: _Variant1(),
          ),
          _VariantBlock(
            number: 2,
            label: 'Frosted Pill',
            description: 'Soft frosted glass pill container',
            accentColor: U.blue,
            child: _Variant2(),
          ),
          _VariantBlock(
            number: 3,
            label: 'Accent Left Border',
            description: 'Bold accent stripe on left — editorial',
            accentColor: U.peach,
            child: _Variant3(),
          ),
          _VariantBlock(
            number: 4,
            label: 'Dashed Outline',
            description: 'Dashed border — lightweight & playful',
            accentColor: U.lavender,
            child: _Variant4(),
          ),
          _VariantBlock(
            number: 5,
            label: 'Floating Label',
            description: 'Label floats above on focus — premium',
            accentColor: U.gold,
            child: _Variant5(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Variant wrapper ─────────────────────────────────────────────────────────

class _VariantBlock extends StatelessWidget {
  final int number;
  final String label;
  final String description;
  final Color accentColor;
  final Widget child;

  const _VariantBlock({
    required this.number,
    required this.label,
    required this.description,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w700, color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: U.text)),
                  Text(description, style: GoogleFonts.outfit(fontSize: 12, color: U.dim)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: U.surface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: U.border.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tasks', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: U.dim, letterSpacing: 0.8)),
                const SizedBox(height: 10),
                child,
                const SizedBox(height: 20),
                Text('Journal', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: U.dim, letterSpacing: 0.8)),
                const SizedBox(height: 10),
                _buildJournalVariant(number, accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalVariant(int v, Color accent) {
    switch (v) {
      case 1:
        return _Ghost_Journal();
      case 2:
        return _FrostedPill_Journal();
      case 3:
        return _AccentBorder_Journal(accent: accent);
      case 4:
        return _Dashed_Journal();
      case 5:
        return _Floating_Journal();
      default:
        return const SizedBox();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VARIANT 1: Ghost Line (Notion-style — pure, no container)
// ─────────────────────────────────────────────────────────────────────────────

class _Variant1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: U.dim.withValues(alpha: 0.12), width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.add, size: 16, color: U.dim.withValues(alpha: 0.35)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: GoogleFonts.outfit(color: U.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'New task',
                hintStyle: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.3), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ghost_Journal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLines: 3,
      minLines: 3,
      style: GoogleFonts.outfit(color: U.text, fontSize: 14, height: 1.65),
      decoration: InputDecoration(
        hintText: 'Write your thoughts...',
        hintStyle: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.28), fontSize: 14),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VARIANT 2: Frosted Pill (soft pill with blur-like background)
// ─────────────────────────────────────────────────────────────────────────────

class _Variant2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: U.text.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Icon(Icons.add, size: 16, color: U.dim.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: GoogleFonts.outfit(color: U.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add a task...',
                hintStyle: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.4), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedPill_Journal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: U.text.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        maxLines: 3,
        minLines: 3,
        style: GoogleFonts.outfit(color: U.text, fontSize: 14, height: 1.65),
        decoration: InputDecoration(
          hintText: 'Write your thoughts...',
          hintStyle: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.35), fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VARIANT 3: Accent Left Border (editorial / Linear-style)
// ─────────────────────────────────────────────────────────────────────────────

class _Variant3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: U.teal.withValues(alpha: 0.5), width: 2)),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: GoogleFonts.outfit(color: U.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add a task...',
                hintStyle: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.35), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          Icon(Icons.add, size: 16, color: U.teal.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

class _AccentBorder_Journal extends StatelessWidget {
  final Color accent;
  const _AccentBorder_Journal({required this.accent});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent.withValues(alpha: 0.45), width: 2)),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: TextField(
        maxLines: 3,
        minLines: 3,
        style: GoogleFonts.outfit(color: U.text, fontSize: 14, height: 1.65),
        decoration: InputDecoration(
          hintText: 'Write your thoughts...',
          hintStyle: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.3), fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VARIANT 4: Dashed Outline
// ─────────────────────────────────────────────────────────────────────────────

class _Variant4 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: U.dim.withValues(alpha: 0.25)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Icon(Icons.add, size: 15, color: U.dim.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                style: GoogleFonts.outfit(color: U.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add a task...',
                  hintStyle: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.32), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dashed_Journal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: U.dim.withValues(alpha: 0.2)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          maxLines: 3,
          minLines: 3,
          style: GoogleFonts.outfit(color: U.text, fontSize: 14, height: 1.65),
          decoration: InputDecoration(
            hintText: 'Write your thoughts...',
            hintStyle: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.28), fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const dash = 5.0;
    const gap = 4.0;
    final radius = const Radius.circular(10);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      radius,
    );
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// VARIANT 5: Floating Label (premium / Material You-inspired)
// ─────────────────────────────────────────────────────────────────────────────

class _Variant5 extends StatefulWidget {
  @override
  State<_Variant5> createState() => _Variant5State();
}

class _Variant5State extends State<_Variant5> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _focused ? U.gold.withValues(alpha: 0.7) : U.dim.withValues(alpha: 0.18),
            width: _focused ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.add, size: 15, color: _focused ? U.gold : U.dim.withValues(alpha: 0.35)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                style: GoogleFonts.outfit(color: U.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add a task...',
                  hintStyle: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.3), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Floating_Journal extends StatefulWidget {
  @override
  State<_Floating_Journal> createState() => _Floating_JournalState();
}

class _Floating_JournalState extends State<_Floating_Journal> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? U.gold.withValues(alpha: 0.65) : U.dim.withValues(alpha: 0.15),
            width: _focused ? 1.5 : 1,
          ),
        ),
        child: TextField(
          maxLines: 3,
          minLines: 3,
          style: GoogleFonts.outfit(color: U.text, fontSize: 14, height: 1.65),
          decoration: InputDecoration(
            hintText: 'Write your thoughts...',
            hintStyle: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.28), fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
      ),
    );
  }
}
