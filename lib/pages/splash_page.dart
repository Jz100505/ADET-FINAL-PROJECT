import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';

// ─── Palette ─────────────────────────────────────────────────
const _bg        = Color(0xFF07050E);
const _accentRed = Color(0xFFE53935);
const _accentPur = Color(0xFF7F77DD);
const _gridLine  = Color(0xFF14112A);

// ─────────────────────────────────────────────────────────────
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {

  // ── Controllers ────────────────────────────────────────────
  late final AnimationController _particleCtrl; // particles — infinite
  late final AnimationController _radarCtrl;    // rings + sweep — infinite
  late final AnimationController _outerRingCtrl;// rotating dashed ring — infinite
  late final AnimationController _pulseCtrl;    // core orb pulse — infinite
  late final AnimationController _revealCtrl;   // logo reveal — once
  late final AnimationController _shimmerCtrl;  // logo shimmer — repeat
  late final AnimationController _loadCtrl;     // loading bar — once

  // ── Derived animations ──────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _loadingOpacity;
  late final Animation<double> _coreGlow;
  late final Animation<double> _shimmer;

  final List<_Particle> _particles = [];
  final Random _rng = Random(42);

  @override
  void initState() {
    super.initState();

    _buildParticles();

    // ── Infinite loops ────────────────────────────────────
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();

    _radarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat();

    _outerRingCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _coreGlow = Tween<double>(begin: 0.55, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    // ── One-shot reveal ───────────────────────────────────
    _revealCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(
            parent: _revealCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.elasticOut)));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _revealCtrl,
            curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _revealCtrl,
            curve: const Interval(0.38, 0.70, curve: Curves.easeOut)));
    _loadingOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _revealCtrl,
            curve: const Interval(0.58, 0.90, curve: Curves.easeOut)));

    _loadCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));

    // ── Sequence ──────────────────────────────────────────
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _revealCtrl.forward();
      Future.delayed(const Duration(milliseconds: 950), () {
        if (mounted) _loadCtrl.forward();
      });
    });

    // ── Navigate to LoginPage ─────────────────────────────
    Future.delayed(const Duration(milliseconds: 4200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, __, ___) => const LoginPage(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
            child: child,
          ),
        ),
      );
    });
  }

  void _buildParticles() {
    const colors = [
      Color(0xFFE53935), // fire
      Color(0xFF378ADD), // water
      Color(0xFF1D9E75), // grass
      Color(0xFFEF9F27), // electric
      Color(0xFF7F77DD), // psychic
      Color(0xFF5DCAA5), // ice
      Color(0xFFD85A30), // dragon
      Color(0xFFE53935), // extra fire weight
      Color(0xFF7F77DD), // extra psychic weight
    ];
    for (int i = 0; i < 55; i++) {
      _particles.add(_Particle(
        x:      _rng.nextDouble(),
        y:      _rng.nextDouble(),
        size:   _rng.nextDouble() * 3.0 + 1.2,
        speed:  _rng.nextDouble() * 0.28 + 0.04,
        color:  colors[_rng.nextInt(colors.length)],
        phase:  _rng.nextDouble(),
        driftX: (_rng.nextDouble() - 0.5) * 0.12,
        twinkle: _rng.nextDouble(),
      ));
    }
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _radarCtrl.dispose();
    _outerRingCtrl.dispose();
    _pulseCtrl.dispose();
    _revealCtrl.dispose();
    _shimmerCtrl.dispose();
    _loadCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [

          // ── L1: Particle field ───────────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(
                particles: _particles,
                t: _particleCtrl.value,
              ),
              size: size,
            ),
          ),

          // ── L2: Radar rings + sweep beam ─────────────────
          Center(
            child: AnimatedBuilder(
              animation: _radarCtrl,
              builder: (_, __) => CustomPaint(
                painter: _RadarPainter(t: _radarCtrl.value),
                size: Size(size.width * 0.88, size.width * 0.88),
              ),
            ),
          ),

          // ── L3: Outer rotating ring ───────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _outerRingCtrl,
              builder: (_, __) => CustomPaint(
                painter: _OuterRingPainter(t: _outerRingCtrl.value),
                size: Size(size.width * 0.88, size.width * 0.88),
              ),
            ),
          ),

          // ── L4: Core orb glow ─────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _coreGlow,
              builder: (_, __) => Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentRed.withValues(alpha: 0.06 * _coreGlow.value),
                  boxShadow: [
                    BoxShadow(
                      color: _accentRed.withValues(alpha: 0.40 * _coreGlow.value),
                      blurRadius: 48 * _coreGlow.value,
                      spreadRadius: 6 * _coreGlow.value,
                    ),
                    BoxShadow(
                      color: _accentPur.withValues(alpha: 0.22 * _coreGlow.value),
                      blurRadius: 80 * _coreGlow.value,
                      spreadRadius: 18 * _coreGlow.value,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.catching_pokemon_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),

          // ── L5: Logo + subtitle + loading ─────────────────
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 168), // push below orb

                // ── HAU label
                AnimatedBuilder(
                  animation: _logoOpacity,
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: const Text(
                      'H A U',
                      style: TextStyle(
                        color: _accentRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // ── MONSTERS (shimmer sweep)
                AnimatedBuilder(
                  animation: Listenable.merge([_logoScale, _shimmer]),
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment(_shimmer.value - 1, 0),
                          end: Alignment(_shimmer.value + 1, 0),
                          colors: const [
                            Colors.white,
                            Color(0xFFE0DCFF),
                            Colors.white,
                            Color(0xFFFFFFFF),
                          ],
                          stops: const [0.0, 0.45, 0.55, 1.0],
                        ).createShader(bounds),
                        child: const Text(
                          'MONSTERS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 7,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── CONTROL CENTER
                AnimatedBuilder(
                  animation: _subtitleOpacity,
                  builder: (_, __) => Opacity(
                    opacity: _subtitleOpacity.value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 0.5,
                          color: const Color(0xFF3A355A),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'CONTROL CENTER',
                          style: TextStyle(
                            color: Color(0xFF5E5A80),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 24,
                          height: 0.5,
                          color: const Color(0xFF3A355A),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 52),

                // ── Loading bar + label
                AnimatedBuilder(
                  animation: Listenable.merge([_loadingOpacity, _loadCtrl]),
                  builder: (_, __) {
                    final loadVal = CurvedAnimation(
                      parent: _loadCtrl,
                      curve: Curves.easeInOutCubic,
                    ).value;

                    return Opacity(
                      opacity: _loadingOpacity.value,
                      child: Column(children: [

                        // Bar track + fill
                        SizedBox(
                          width: 200,
                          child: Stack(children: [
                            // Track
                            Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1830),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // Fill
                            FractionallySizedBox(
                              widthFactor: loadVal,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_accentRed, _accentPur],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _accentRed.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: _accentPur.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 14),

                        // Status label cycles through messages
                        _LoadingLabel(progress: loadVal),
                      ]),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── L6: Version tag (bottom) ──────────────────────
          Positioned(
            bottom: 32, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _loadingOpacity,
              builder: (_, __) => Opacity(
                opacity: _loadingOpacity.value * 0.35,
                child: const Text(
                  'v1.0.0  ·  6ADET Finals',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF2E2B45),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cycling loading label
// ─────────────────────────────────────────────────────────────
class _LoadingLabel extends StatelessWidget {
  final double progress;
  const _LoadingLabel({required this.progress});

  @override
  Widget build(BuildContext context) {
    const msgs = [
      'Initializing radar systems...',
      'Scanning monster signatures...',
      'Calibrating capture protocols...',
      'Systems ready.',
    ];
    final idx = (progress * (msgs.length - 0.01)).floor()
        .clamp(0, msgs.length - 1);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        msgs[idx],
        key: ValueKey(idx),
        style: const TextStyle(
          color: Color(0xFF4A4568),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Particle data
// ─────────────────────────────────────────────────────────────
class _Particle {
  final double x, size, speed, phase, driftX, twinkle;
  double y;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
    required this.phase,
    required this.driftX,
    required this.twinkle,
  });
}

// ─────────────────────────────────────────────────────────────
// Particle painter
// ─────────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  const _ParticlePainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Wrap upward motion
      final yPos = ((p.y - t * p.speed - p.phase * 0.25) % 1.0 + 1.0) % 1.0;
      final xPos = ((p.x +
              sin((t * 2 * pi) + p.phase * 2 * pi) * p.driftX * 0.4 +
              p.driftX * t * 0.5) %
          1.0 +
          1.0) %
          1.0;

      final px = xPos * size.width;
      final py = yPos * size.height;

      // Fade-in at top edge
      final edgeFade = yPos < 0.06 ? yPos / 0.06 : 1.0;
      // Twinkle
      final twink = 0.55 + 0.45 * sin((t * 2 * pi * 1.7) + p.twinkle * 2 * pi);
      final alpha = edgeFade * twink;

      // Soft glow halo
      canvas.drawCircle(
        Offset(px, py),
        p.size * 3.0,
        Paint()
          ..color = p.color.withValues(alpha: alpha * 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2.8),
      );

      // Bright core
      canvas.drawCircle(
        Offset(px, py),
        p.size,
        Paint()..color = p.color.withValues(alpha: alpha * 0.88),
      );

      // Tiny specular highlight
      if (p.size > 2.5) {
        canvas.drawCircle(
          Offset(px - p.size * 0.28, py - p.size * 0.28),
          p.size * 0.28,
          Paint()..color = Colors.white.withValues(alpha: alpha * 0.55),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────
// Radar rings + rotating sweep beam painter
// ─────────────────────────────────────────────────────────────
class _RadarPainter extends CustomPainter {
  final double t; // 0→1

  const _RadarPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // ── Static grid rings ───────────────────────────────
    final gridPaint = Paint()
      ..color = _gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(c, maxR * i / 4, gridPaint);
    }

    // ── Crosshair + diagonals ───────────────────────────
    final linePaint = Paint()
      ..color = _gridLine
      ..strokeWidth = 0.35;
    const r = 10000.0;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), linePaint);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), linePaint);
    final d = maxR * 0.707;
    canvas.drawLine(Offset(c.dx - d, c.dy - d), Offset(c.dx + d, c.dy + d), linePaint);
    canvas.drawLine(Offset(c.dx + d, c.dy - d), Offset(c.dx - d, c.dy + d), linePaint);

    // ── Sweep beam (trailing arc + bright edge) ─────────
    final sweepAngle = t * 2 * pi - pi / 2; // starts at 12 o'clock
    const trailSpan = 1.1; // radians of trailing glow

    // Gradient arc trail (clipped to circle)
    canvas.save();
    canvas.clipRect(Rect.fromCircle(center: c, radius: maxR));
    for (int i = 0; i < 60; i++) {
      final frac = i / 60.0;
      final angle = sweepAngle - trailSpan * (1 - frac);
      final alpha = frac * frac * 0.22;
      final sweepPaint = Paint()
        ..color = _accentRed.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(
          c.dx + maxR * cos(angle),
          c.dy + maxR * sin(angle),
        )
        ..lineTo(
          c.dx + maxR * cos(angle + trailSpan / 60),
          c.dy + maxR * sin(angle + trailSpan / 60),
        )
        ..close();
      canvas.drawPath(path, sweepPaint);
    }
    canvas.restore();

    // Bright leading edge line
    final edgePaint = Paint()
      ..color = _accentRed.withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawLine(
      c,
      Offset(c.dx + maxR * cos(sweepAngle), c.dy + maxR * sin(sweepAngle)),
      edgePaint,
    );

    // ── Pulsing expand rings (3 staggered) ──────────────
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3.0) % 1.0;
      final radius = phase * maxR;
      final opacity = pow(1.0 - phase, 2.5).toDouble() * 0.55;
      if (opacity < 0.01) continue;

      // Glow layer
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = _accentRed.withValues(alpha: opacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      // Sharp ring
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = _accentRed.withValues(alpha: opacity * 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────
// Outer rotating segmented ring painter
// ─────────────────────────────────────────────────────────────
class _OuterRingPainter extends CustomPainter {
  final double t;
  const _OuterRingPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 + 14;

    // Rotating direction: clockwise for outer, counter for inner
    const segments = 48;
    const gapFrac  = 0.25; // fraction of each segment that is gap

    for (int i = 0; i < segments; i++) {
      final startAngle = (i / segments) * 2 * pi + t * 2 * pi;
      final sweepAngle = (1.0 - gapFrac) / segments * 2 * pi;

      // Alternate brightness
      final isBright = i % 4 == 0;
      final alpha = isBright ? 0.55 : 0.18;

      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = (isBright ? _accentRed : _accentPur).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isBright ? 1.5 : 0.8
          ..strokeCap = StrokeCap.round,
      );
    }

    // Inner counter-rotating ring (slower, dashed)
    final r2 = size.width / 2 + 5;
    for (int i = 0; i < 24; i++) {
      final startAngle = (i / 24) * 2 * pi - t * 2 * pi * 0.4;
      final sweepAngle = 0.55 / 24 * 2 * pi;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r2),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = _accentPur.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_OuterRingPainter old) => old.t != t;
}