import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MinecraftWorldLoader extends StatefulWidget {
  final double scale;
  final double? progress;
  final int? forcedDesignIndex;

  const MinecraftWorldLoader({
    super.key,
    this.scale = 1.0,
    this.progress,
    this.forcedDesignIndex,
  });

  @override
  State<MinecraftWorldLoader> createState() => _MinecraftWorldLoaderState();
}

class _MinecraftWorldLoaderState extends State<MinecraftWorldLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _seed;
  late _PixelArt _selectedDesign;

  @override
  void initState() {
    super.initState();
    _seed = DateTime.now().microsecondsSinceEpoch;
    final rng = math.Random(_seed);
    final designs = _PixelArt.all;
    final index = widget.forcedDesignIndex ?? rng.nextInt(designs.length);
    _selectedDesign = designs[index];

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.progress == null) {
      _controller.animateTo(0.96, curve: Curves.easeOutCubic);
    }
  }

  @override
  void didUpdateWidget(MinecraftWorldLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != null && widget.progress != oldWidget.progress) {
      _controller.animateTo(
        widget.progress!.clamp(0.0, 1.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final p = (widget.progress ?? _controller.value).clamp(0.0, 1.0);
        final pct = (p * 100).round();
        return SizedBox.expand(
          child: ColoredBox(
            color: const Color(0xFF3B2B1A),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: const _DirtPainter())),
                Positioned.fill(child: CustomPaint(painter: const _VignettePainter())),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedDesign.subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.pressStart2p(
                          color: const Color(0xFFE0E0E0),
                          fontSize: 11 * widget.scale,
                          height: 1.2,
                          shadows: [Shadow(color: Colors.black, offset: Offset(2 * widget.scale, 2 * widget.scale))],
                        ),
                      ),
                      SizedBox(height: 14 * widget.scale),
                      Text(
                        '$pct%',
                        style: GoogleFonts.pressStart2p(
                          color: Colors.white,
                          fontSize: 16 * widget.scale,
                          height: 1.0,
                          shadows: [Shadow(color: const Color(0xFF2B2B2B), offset: Offset(2 * widget.scale, 2 * widget.scale))],
                        ),
                      ),
                      SizedBox(height: 14 * widget.scale),
                      // Minecraft 3D bevel box
                      Container(
                        width: 208 * widget.scale,
                        height: 208 * widget.scale,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B8B8B),
                          border: Border(
                            top: BorderSide(color: const Color(0xFF373737), width: 4 * widget.scale),
                            left: BorderSide(color: const Color(0xFF373737), width: 4 * widget.scale),
                            right: BorderSide(color: const Color(0xFFFFFFFF), width: 4 * widget.scale),
                            bottom: BorderSide(color: const Color(0xFFFFFFFF), width: 4 * widget.scale),
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 16 * widget.scale, spreadRadius: 2 * widget.scale)],
                        ),
                        padding: EdgeInsets.all(4 * widget.scale),
                        child: Container(
                          color: Colors.black,
                          child: CustomPaint(
                            size: Size(192 * widget.scale, 192 * widget.scale),
                            painter: _ChunkPainter(progress: p, seed: _seed, design: _selectedDesign),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PIXEL ART DATA — every row verified to be exactly 16 chars
// ═══════════════════════════════════════════════════════════════════

class _PixelArt {
  final String subtitle;
  final Map<String, Color> palette;
  final List<String> rows;
  const _PixelArt(this.subtitle, this.palette, this.rows);

  /// All available designs. Complex ones (yin-yang) are generated mathematically.
  static List<_PixelArt> get all => [
    _creeper, _heart, _indianFlag, _smiley,
    _skull, _emc2, _cryingEmoji, _yinYang(),
  ];

  // 1. CREEPER — canonical 2x scale of Minecraft 8×8 face texture
  static const _creeper = _PixelArt('Loading Creeper Realm...', {
    'G': Color(0xFF4AAD31), 'K': Color(0xFF222222),
  }, [
    'GGGGGGGGGGGGGGGG', 'GGGGGGGGGGGGGGGG',
    'GGKKKKGGGGKKKKGG', 'GGKKKKGGGGKKKKGG',
    'GGKKKKGGGGKKKKGG', 'GGKKKKGGGGKKKKGG',
    'GGGGGGKKKKGGGGGG', 'GGGGGGKKKKGGGGGG',
    'GGGGKKKKKKKKGGGG', 'GGGGKKKKKKKKGGGG',
    'GGGGKKKKKKKKGGGG', 'GGGGKKKKKKKKGGGG',
    'GGGGKKGGGGKKGGGG', 'GGGGKKGGGGKKGGGG',
    'GGGGGGGGGGGGGGGG', 'GGGGGGGGGGGGGGGG',
  ]);

  // 2. HEART — symmetric pixel heart, dark crimson BG
  static const _heart = _PixelArt('Generating Love...', {
    'R': Color(0xFFFF2255), '.': Color(0xFF1A0A10),
  }, [
    '................', '................',
    '.RRRR......RRRR.', 'RRRRRR....RRRRRR',
    'RRRRRRR..RRRRRRR', 'RRRRRRRRRRRRRRRR',
    '.RRRRRRRRRRRRRR.', '..RRRRRRRRRRRR..',
    '...RRRRRRRRRR...', '....RRRRRRRR....',
    '.....RRRRRR.....', '......RRRR......',
    '.......RR.......', '................',
    '................', '................',
  ]);

  // 3. INDIAN FLAG — Tiranga with Ashoka Chakra
  static const _indianFlag = _PixelArt('Loading Bharat...', {
    'O': Color(0xFFFF9933), 'W': Color(0xFFF0F0F0),
    'G': Color(0xFF138808), 'N': Color(0xFF000080),
  }, [
    'OOOOOOOOOOOOOOOO', 'OOOOOOOOOOOOOOOO',
    'OOOOOOOOOOOOOOOO', 'OOOOOOOOOOOOOOOO',
    'OOOOOOOOOOOOOOOO', 'WWWWWWNNNWWWWWWW',
    'WWWWWNWWWNWWWWWW', 'WWWWWNNNNNWWWWWW',
    'WWWWWNWWWNWWWWWW', 'WWWWWWNNNWWWWWWW',
    'WWWWWWWWWWWWWWWW', 'GGGGGGGGGGGGGGGG',
    'GGGGGGGGGGGGGGGG', 'GGGGGGGGGGGGGGGG',
    'GGGGGGGGGGGGGGGG', 'GGGGGGGGGGGGGGGG',
  ]);

  // 4. SMILEY — yellow circle, eyes, smile, warm dark BG
  static const _smiley = _PixelArt('Generating Vibes...', {
    'Y': Color(0xFFFFCC00), 'K': Color(0xFF442200), '.': Color(0xFF1A140E),
  }, [
    '....YYYYYYYY....', '..YYYYYYYYYYYY..',
    '.YYYYYYYYYYYYYY.', 'YYYYYYYYYYYYYYYY',
    'YYYKKYYYYYYKKYYY', 'YYYKKYYYYYYKKYYY',
    'YYYYYYYYYYYYYYYY', 'YYYYYYYYYYYYYYYY',
    'YYYYKYYYYYYKYYYY', 'YYYYYKKKKKKYYYYY',
    '.YYYYYYYYYYYYYY.', '.YYYYYYYYYYYYYY.',
    '..YYYYYYYYYYYY..', '....YYYYYYYY....',
    '................', '................',
  ]);

  // 5. SKULL — white skull, deep purple BG
  static const _skull = _PixelArt('Entering Danger Zone...', {
    'W': Color(0xFFFFFFFF), 'K': Color(0xFF111111), '.': Color(0xFF1C101A),
  }, [
    '................', '....KKKKKKKK....',
    '..KKWWWWWWWWKK..', '..KWWWWWWWWWWK..',
    '..KWWWWWWWWWWK..', '..KWWKKWWKKWWK..',
    '..KWWKKWWKKWWK..', '..KWWWWWWWWWWK..',
    '..KWWWWKKWWWWK..', '..KKWWWWWWWWKK..',
    '....KWKWWKWK....', '....KKKKKKKK....',
    '................', '................',
    '................', '................',
  ]);

  // 6. E=mc² — pixel font on chalkboard green
  static const _emc2 = _PixelArt('Calculating E=mc\u00B2...', {
    'K': Color(0xFFFFFFFF), 'R': Color(0xFFDD1111), '.': Color(0xFF0D1B0E),
  }, [
    '................', '................',
    '................', '................',
    '..............RR', '...............R',
    'KKK.....K.KKKKRR', 'K...KKK.KKKK....',
    'KKK.....K.KK....', 'K...KKK.K.KK....',
    'KKK.....K.KKKK..', '................',
    '................', '................',
    '................', '................',
  ]);

  // 7. CRYING EMOJI — yellow face, blue tears, dark BG
  static const _cryingEmoji = _PixelArt('Fetching Attendance...', {
    'Y': Color(0xFFFFCC00), 'O': Color(0xFFFF8C00), 'K': Color(0xFF442200),
    'B': Color(0xFF0099FF), 'W': Color(0xFFFFFFFF), '.': Color(0xFF1A140E),
  }, [
    '....OOOOOOOO....', '..OOYYYYYYYYOO..',
    '.OYYYYYYYYYYYYO.', 'YYYYYYYYYYYYYYYY',
    'YYYKKYYYYYYKKYYY', 'YYYKKYYYYYYKKYYY',
    'YYYBBYYYYYYBBYYY', 'YYYBBYYYYYYBBYYY',
    'YYYBBYKKKKYBBYYY', 'YYYBBYKWWKYBBYYY',
    '.YYBBYYYYYYBBYY.', '.YYBBYYYYYYBBYY.',
    '..YYYYYYYYYYYY..', '....YYYYYYYY....',
    '................', '................',
  ]);

  // 8. YIN-YANG — generated mathematically for perfect S-curve
  static _PixelArt _yinYang() {
    const n = 16;
    const cx = 7.5, cy = 7.5, r = 7.0, sr = 3.5;
    final rows = <String>[];
    for (int y = 0; y < n; y++) {
      final sb = StringBuffer();
      for (int x = 0; x < n; x++) {
        final dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy > r * r) { sb.write('.'); continue; }
        final inTop = dx * dx + (dy + sr) * (dy + sr) <= sr * sr;
        final inBot = dx * dx + (dy - sr) * (dy - sr) <= sr * sr;
        bool yang = inTop ? true : (inBot ? false : dx >= 0);
        // Dots: black dot in yang area, white dot in yin area
        if ((x == 7 || x == 8) && y == 4) { sb.write('K'); }
        else if ((x == 7 || x == 8) && y == 11) { sb.write('W'); }
        else { sb.write(yang ? 'W' : 'K'); }
      }
      rows.add(sb.toString());
    }
    return _PixelArt('Balancing World...', {
      'K': const Color(0xFF111111), 'W': const Color(0xFFEEEEEE), '.': const Color(0xFF181C20),
    }, rows);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PAINTERS
// ═══════════════════════════════════════════════════════════════════

class _DirtPainter extends CustomPainter {
  const _DirtPainter();
  static const _t = [3,2,4,3,2,5,3,2, 2,1,3,2,4,3,1,3, 4,3,0,2,3,1,4,2, 3,5,3,1,2,3,2,4, 2,3,4,3,0,2,3,1, 1,2,3,5,3,4,2,3, 3,4,2,3,2,1,3,5, 2,3,1,4,3,2,4,3];
  static const _p = [Color(0xFF593D29),Color(0xFF6B4C35),Color(0xFF7B5B3F),Color(0xFF8B6A4F),Color(0xFF9A7B5A),Color(0xFF5E4230)];

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = _p[3]);
    const ps = 4.0;
    for (double ty = 0; ty < s.height; ty += 32) {
      for (double tx = 0; tx < s.width; tx += 32) {
        for (int py = 0; py < 8; py++) {
          for (int px = 0; px < 8; px++) {
            c.drawRect(Rect.fromLTWH(tx + px * ps, ty + py * ps, ps, ps), Paint()..color = _p[_t[py * 8 + px]]);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _VignettePainter extends CustomPainter {
  const _VignettePainter();
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..shader = RadialGradient(
      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.85)],
      stops: const [0.3, 0.75, 1.0],
    ).createShader(Offset.zero & s));
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _ChunkPainter extends CustomPainter {
  final double progress;
  final int seed;
  final _PixelArt design;
  _ChunkPainter({required this.progress, required this.seed, required this.design});

  @override
  void paint(Canvas canvas, Size size) {
    final nr = design.rows.length;
    final nc = design.rows[0].length;
    final total = nr * nc;
    final cw = size.width / nc, ch = size.height / nr;

    // Gray unloaded bg + grid
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF7A7A7A));
    final gp = Paint()..color = const Color(0xFF686868)..strokeWidth = 0.5;
    for (int i = 1; i < nc; i++) {
      canvas.drawLine(Offset(i * cw, 0), Offset(i * cw, size.height), gp);
    }
    for (int j = 1; j < nr; j++) {
      canvas.drawLine(Offset(0, j * ch), Offset(size.width, j * ch), gp);
    }

    // Load order
    final order = _buildOrder(nr, nc);
    final show = (progress * total).round().clamp(0, total);

    // Draw loaded chunks
    for (int i = 0; i < show; i++) {
      final idx = order[i];
      final cx = idx % nc, cy = idx ~/ nc;
      final ch2 = design.rows[cy][cx];
      final color = design.palette[ch2] ?? const Color(0xFF7A7A7A);
      canvas.drawRect(Rect.fromLTWH(cx * cw, cy * ch, cw + 0.5, ch + 0.5), Paint()..color = color);
    }

    // Grid overlay
    final go = Paint()..color = const Color(0xFF000000).withValues(alpha: 0.2)..strokeWidth = 0.3;
    for (int i = 1; i < nc; i++) {
      canvas.drawLine(Offset(i * cw, 0), Offset(i * cw, size.height), go);
    }
    for (int j = 1; j < nr; j++) {
      canvas.drawLine(Offset(0, j * ch), Offset(size.width, j * ch), go);
    }

    // Frontier border
    if (show > 0 && show < total) {
      _drawBorder(canvas, order, show, cw, ch, nr, nc);
    }
  }

  List<int> _buildOrder(int nr, int nc) {
    final cx = nc / 2.0, cy = nr / 2.0;
    final rng = math.Random(seed);
    final e = <_E>[];
    for (int y = 0; y < nr; y++) {
      for (int x = 0; x < nc; x++) {
        final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        e.add(_E(y * nc + x, (d + (rng.nextDouble() - 0.5) * (1.8 + d * 0.3)).clamp(0, double.infinity)));
      }
    }
    e.sort((a, b) => a.d.compareTo(b.d));
    return e.map((v) => v.i).toList();
  }

  void _drawBorder(Canvas c, List<int> order, int show, double cw, double ch, int nr, int nc) {
    final loaded = <int>{};
    for (int i = 0; i < show; i++) {
      loaded.add(order[i]);
    }
    final gp = Paint()..color = const Color(0xFF00FF00)..style = PaintingStyle.stroke..strokeWidth = 1.6;
    final np = Paint()..color = const Color(0xFF1A237E)..style = PaintingStyle.stroke..strokeWidth = 2.0;
    for (final idx in loaded) {
      final x = idx % nc, y = idx ~/ nc;
      final l = x * cw, t = y * ch, r = l + cw, b = t + ch;
      if (y == 0 || !loaded.contains((y-1)*nc+x)) { c.drawLine(Offset(l,t), Offset(r,t), np); c.drawLine(Offset(l,t+1), Offset(r,t+1), gp); }
      if (y == nr-1 || !loaded.contains((y+1)*nc+x)) { c.drawLine(Offset(l,b), Offset(r,b), np); c.drawLine(Offset(l,b-1), Offset(r,b-1), gp); }
      if (x == 0 || !loaded.contains(y*nc+(x-1))) { c.drawLine(Offset(l,t), Offset(l,b), np); c.drawLine(Offset(l+1,t), Offset(l+1,b), gp); }
      if (x == nc-1 || !loaded.contains(y*nc+(x+1))) { c.drawLine(Offset(r,t), Offset(r,b), np); c.drawLine(Offset(r-1,t), Offset(r-1,b), gp); }
    }
  }

  @override
  bool shouldRepaint(covariant _ChunkPainter o) => o.progress != progress || o.seed != seed;
}

class _E { final int i; final double d; const _E(this.i, this.d); }
