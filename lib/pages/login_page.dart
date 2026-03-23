import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local_db_service.dart';
import 'dashboard_page.dart';
import 'register_page.dart';

// ─── Palette ──────────────────────────────────────────────────
const _bg        = Color(0xFF0D0D14);
const _surface   = Color(0xFF16151F);
const _border    = Color(0xFF252333);
const _textPri   = Colors.white;
const _textSec   = Color(0xFF6B6880);
const _red       = Color(0xFFE53935);
const _purple    = Color(0xFF7F77DD);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey            = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading       = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();
    try {
      final result = await LocalDbService.instance.loginPlayer(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        HapticFeedback.mediumImpact();
        final playerData = result['data'];
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, anim, __) => DashboardPage(
              playerId:   playerData?['player_id'],
              playerName: playerData?['player_name'],
            ),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      } else {
        _showError(result['message']?.toString() ?? 'Invalid credentials');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: const Color(0xFFE24B4A),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(children: [

          // ── L1: Hexagon grid background ──────────────────
          Positioned.fill(
            child: CustomPaint(painter: _HexGridPainter()),
          ),

          // ── L2: Top radial glow ───────────────────────────
          Positioned(
            top: -120, left: 0, right: 0,
            child: Center(
              child: Container(
                width: 340, height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _red.withValues(alpha: 0.12),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),

          // ── L3: Form content ──────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 56),

                      // ── Logo ────────────────────────────
                      Center(
                        child: Container(
                          width: 84, height: 84,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _red.withValues(alpha: 0.28),
                                _purple.withValues(alpha: 0.18),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _red.withValues(alpha: 0.45),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _red.withValues(alpha: 0.30),
                                blurRadius: 28,
                                spreadRadius: 2,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: _purple.withValues(alpha: 0.15),
                                blurRadius: 48,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.catching_pokemon,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Title ────────────────────────────
                      const Center(
                        child: Text('HAU Monsters',
                            style: TextStyle(
                              color: _textPri,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            )),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text('Sign in to your account',
                            style: TextStyle(
                              color: _textSec,
                              fontSize: 13,
                              letterSpacing: 0.2,
                            )),
                      ),

                      const SizedBox(height: 44),

                      // ── Form ─────────────────────────────
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // Username
                            _FieldLabel(label: 'Username'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(color: _textPri, fontSize: 14),
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                hintText: 'Enter your username',
                                prefixIcon: Icon(Icons.person_outline,
                                    color: Color(0xFF555268), size: 18),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Username is required'
                                  : null,
                            ),

                            const SizedBox(height: 20),

                            // Password
                            _FieldLabel(label: 'Password'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: _textPri, fontSize: 14),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: Color(0xFF555268), size: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF555268),
                                    size: 18,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 32),

                            // ── Sign In button ───────────────
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2))
                                    : const Text('Sign In',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5)),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Single divider ───────────────
                            Row(children: [
                              const Expanded(child: Divider(color: _border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Text('or',
                                    style: const TextStyle(
                                        color: _textSec, fontSize: 12)),
                              ),
                              const Expanded(child: Divider(color: _border)),
                            ]),

                            const SizedBox(height: 20),

                            // ── Create Account + Demo side by side ──
                            Row(children: [
                              // Create Account
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const RegisterPage()),
                                            ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _textPri,
                                      side: BorderSide(
                                          color: _red.withValues(alpha: 0.45),
                                          width: 1),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      backgroundColor:
                                          _red.withValues(alpha: 0.06),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_add_outlined,
                                            size: 16, color: _red),
                                        SizedBox(height: 3),
                                        Text('Register',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _red)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Demo
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => Navigator.pushReplacement(
                                              context,
                                              PageRouteBuilder(
                                                transitionDuration:
                                                    const Duration(
                                                        milliseconds: 500),
                                                pageBuilder: (_, anim, __) =>
                                                    const DashboardPage(
                                                  playerId:   1,
                                                  playerName: 'Demo Player',
                                                ),
                                                transitionsBuilder:
                                                    (_, anim, __, child) =>
                                                        FadeTransition(
                                                            opacity: anim,
                                                            child: child),
                                              ),
                                            ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _textSec,
                                      side: BorderSide(
                                          color: _border, width: 1),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      backgroundColor:
                                          _surface.withValues(alpha: 0.8),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_outline,
                                            size: 16, color: _textSec),
                                        SizedBox(height: 3),
                                        Text('Demo',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _textSec)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ]),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hex grid background painter
// ─────────────────────────────────────────────────────────────
class _HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C1A2E).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    const r   = 28.0;       // hex circumradius
    final w   = sqrt(3) * r;
    final h   = 2.0 * r;
    final colCount = (size.width  / w).ceil() + 2;
    final rowCount = (size.height / (h * 0.75)).ceil() + 2;

    for (int row = -1; row < rowCount; row++) {
      for (int col = -1; col < colCount; col++) {
        final offsetX = (row % 2 == 0) ? 0.0 : w / 2;
        final cx = col * w + offsetX;
        final cy = row * h * 0.75;
        _drawHex(canvas, paint, cx, cy, r);
      }
    }
  }

  void _drawHex(Canvas canvas, Paint paint, double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = pi / 180 * (60 * i - 30);
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexGridPainter _) => false;
}

// ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
        color: Color(0xFF8A8799),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ));
}