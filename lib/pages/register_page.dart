import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local_db_service.dart';

// ─── Palette (matches login_page) ────────────────────────────
const _bg      = Color(0xFF0D0D14);
const _surface = Color(0xFF16151F);
const _border  = Color(0xFF252333);
const _textPri = Colors.white;
const _textSec = Color(0xFF6B6880);
const _red     = Color(0xFFE53935);
const _purple  = Color(0xFF7F77DD);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {

  final _formKey                   = GlobalKey<FormState>();
  final _playerNameController      = TextEditingController();
  final _usernameController        = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading              = false;
  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;

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
        .animate(CurvedAnimation(
            parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _playerNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();
    try {
      final result = await LocalDbService.instance.registerPlayer(
        playerName: _playerNameController.text.trim(),
        username:   _usernameController.text.trim(),
        password:   _passwordController.text.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        HapticFeedback.mediumImpact();
        _showSuccess('Account created! You can now sign in.');
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        _showError(result['message']?.toString() ?? 'Registration failed');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: const Color(0xFFE24B4A),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: const Color(0xFF1D9E75),
    ));
  }

  // ── Password strength ────────────────────────────────────────
  int _passwordStrength(String p) {
    int s = 0;
    if (p.length >= 8)                                   s++;
    if (p.contains(RegExp(r'[A-Z]')))                    s++;
    if (p.contains(RegExp(r'[0-9]')))                    s++;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s++;
    return s;
  }

  Color _strengthColor(int s) {
    switch (s) {
      case 1:  return const Color(0xFFE24B4A);
      case 2:  return const Color(0xFFEF9F27);
      case 3:  return const Color(0xFF378ADD);
      case 4:  return const Color(0xFF1D9E75);
      default: return _border;
    }
  }

  String _strengthLabel(int s) {
    switch (s) {
      case 1:  return 'Weak';
      case 2:  return 'Fair';
      case 3:  return 'Good';
      case 4:  return 'Strong';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength(_passwordController.text);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(children: [

          // ── L1: Hex grid ─────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _HexGridPainter()),
          ),

          // ── L2: Top radial glow (purple tint for register) ─
          Positioned(
            top: -120, left: 0, right: 0,
            child: Center(
              child: Container(
                width: 340, height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _purple.withValues(alpha: 0.10),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),

          // ── L3: Content ──────────────────────────────────
          Positioned.fill(
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(children: [

                    // ── Custom app bar ──────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: _textSec, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text('Create Account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _textPri,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 44),
                      ]),
                    ),

                    Container(
                        height: 0.5,
                        color: Colors.white.withValues(alpha: 0.06)),

                    // ── Scrollable form ─────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 28),

                            // ── Logo ───────────────────────
                            Center(
                              child: Container(
                                width: 70, height: 70,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _purple.withValues(alpha: 0.28),
                                      _red.withValues(alpha: 0.18),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: _purple.withValues(alpha: 0.45),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _purple.withValues(alpha: 0.28),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: _red.withValues(alpha: 0.12),
                                      blurRadius: 40,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                    Icons.person_add_outlined,
                                    color: Colors.white, size: 32),
                              ),
                            ),

                            const SizedBox(height: 18),

                            const Center(
                              child: Text('New Hunter',
                                  style: TextStyle(
                                    color: _textPri,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  )),
                            ),
                            const SizedBox(height: 4),
                            const Center(
                              child: Text(
                                  'Fill in your details to get started',
                                  style: TextStyle(
                                      color: _textSec, fontSize: 13)),
                            ),

                            const SizedBox(height: 32),

                            // ── Form ───────────────────────
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [

                                  // Full Name
                                  const _FieldLabel(label: 'Full Name'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _playerNameController,
                                    style: const TextStyle(
                                        color: _textPri, fontSize: 14),
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter your full name',
                                      prefixIcon: Icon(
                                          Icons.badge_outlined,
                                          color: Color(0xFF555268),
                                          size: 18),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Full name is required';
                                      }
                                      if (v.trim().length < 2) {
                                        return 'Name must be at least 2 characters';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 20),

                                  // Username
                                  const _FieldLabel(label: 'Username'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _usernameController,
                                    style: const TextStyle(
                                        color: _textPri, fontSize: 14),
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    decoration: const InputDecoration(
                                      hintText: 'Choose a username',
                                      prefixIcon: Icon(
                                          Icons.alternate_email,
                                          color: Color(0xFF555268),
                                          size: 18),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Username is required';
                                      }
                                      if (v.trim().length < 3) {
                                        return 'Username must be at least 3 characters';
                                      }
                                      if (v.contains(' ')) {
                                        return 'Username cannot contain spaces';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 20),

                                  // Password
                                  const _FieldLabel(label: 'Password'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(
                                        color: _textPri, fontSize: 14),
                                    textInputAction: TextInputAction.next,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: 'Create a password',
                                      prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: Color(0xFF555268),
                                          size: 18),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: const Color(0xFF555268),
                                          size: 18,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Password is required';
                                      }
                                      if (v.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),

                                  // Strength indicator
                                  if (_passwordController
                                      .text.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      ...List.generate(4, (i) {
                                        final active = i < strength;
                                        return Expanded(
                                          child: Container(
                                            height: 3,
                                            margin: EdgeInsets.only(
                                                right: i < 3 ? 4 : 0),
                                            decoration: BoxDecoration(
                                              color: active
                                                  ? _strengthColor(strength)
                                                  : _border,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        );
                                      }),
                                      const SizedBox(width: 10),
                                      Text(_strengthLabel(strength),
                                          style: TextStyle(
                                              color:
                                                  _strengthColor(strength),
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ]),
                                  ],

                                  const SizedBox(height: 20),

                                  // Confirm Password
                                  const _FieldLabel(
                                      label: 'Confirm Password'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller:
                                        _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: const TextStyle(
                                        color: _textPri, fontSize: 14),
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _register(),
                                    decoration: InputDecoration(
                                      hintText: 'Re-enter your password',
                                      prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: Color(0xFF555268),
                                          size: 18),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: const Color(0xFF555268),
                                          size: 18,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please confirm your password';
                                      }
                                      if (v != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 32),

                                  // Create Account button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _register,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20, height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2))
                                          : const Text('Create Account',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  letterSpacing: 0.5)),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Back to Sign In
                                  Center(
                                    child: TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => Navigator.pop(context),
                                      child: Text.rich(TextSpan(
                                        text: 'Already have an account? ',
                                        style: const TextStyle(
                                            color: _textSec, fontSize: 13),
                                        children: [
                                          TextSpan(
                                            text: 'Sign In',
                                            style: TextStyle(
                                              color: _red,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      )),
                                    ),
                                  ),

                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
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
// Hex grid painter — identical to login page
// ─────────────────────────────────────────────────────────────
class _HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C1A2E).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    const r    = 28.0;
    final w    = sqrt(3) * r;
    final h    = 2.0 * r;
    final cols = (size.width  / w).ceil() + 2;
    final rows = (size.height / (h * 0.75)).ceil() + 2;

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final offX = (row % 2 == 0) ? 0.0 : w / 2;
        _drawHex(canvas, paint, col * w + offX, row * h * 0.75, r);
      }
    }
  }

  void _drawHex(Canvas canvas, Paint p, double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = pi / 180 * (60 * i - 30);
      if (i == 0) path.moveTo(cx + r * cos(a), cy + r * sin(a));
      else        path.lineTo(cx + r * cos(a), cy + r * sin(a));
    }
    path.close();
    canvas.drawPath(path, p);
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