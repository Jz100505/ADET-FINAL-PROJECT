import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local_db_service.dart';

class AddPlayerPage extends StatefulWidget {
  const AddPlayerPage({super.key});

  @override
  State<AddPlayerPage> createState() => _AddPlayerPageState();
}

class _AddPlayerPageState extends State<AddPlayerPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
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

  // ── Password Strength ─────────────────────────────────────────
  int _passwordStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;
    return score;
  }

  Color _strengthColor(int strength) {
    switch (strength) {
      case 1:
        return const Color(0xFFE24B4A);
      case 2:
        return const Color(0xFFEF9F27);
      case 3:
        return const Color(0xFF378ADD);
      case 4:
        return const Color(0xFF1D9E75);
      default:
        return const Color(0xFF2C2C2C);
    }
  }

  String _strengthLabel(int strength) {
    switch (strength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  Future<void> _savePlayer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final result = await LocalDbService.instance.registerPlayer(
        playerName: _playerNameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 16),
              SizedBox(width: 10),
              Text('Player added successfully'),
            ]),
            backgroundColor: const Color(0xFF1D9E75),
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showError(result['message']?.toString() ?? 'Failed to add player');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: const Color(0xFFE24B4A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passwordStrength =
        _passwordStrength(_passwordController.text);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed:
                _isLoading ? null : () => Navigator.pop(context),
          ),
          title: const Text('Add Player'),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _savePlayer,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Color(0xFFE53935),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child:
                Container(height: 0.5, color: const Color(0xFF2C2C2C)),
          ),
        ),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Avatar Preview ────────────────────────────
                    Center(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _playerNameController,
                        builder: (_, value, __) {
                          final initial = value.text.isNotEmpty
                              ? value.text[0].toUpperCase()
                              : '?';
                          return Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE53935)
                                    .withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Color(0xFFE53935),
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Center(
                      child: Text(
                        'New Player',
                        style: TextStyle(
                          color: Color(0xFF616161),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Section: Account Info ─────────────────────
                    _SectionHeader(label: 'Account Information'),
                    const SizedBox(height: 14),

                    _FieldLabel(label: 'Full Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _playerNameController,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Enter full name',
                        prefixIcon: Icon(Icons.badge_outlined,
                            color: Color(0xFF616161), size: 18),
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

                    _FieldLabel(label: 'Username'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'Choose a unique username',
                        prefixIcon: Icon(Icons.alternate_email,
                            color: Color(0xFF616161), size: 18),
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

                    const SizedBox(height: 28),

                    // ── Section: Security ─────────────────────────
                    _SectionHeader(label: 'Security'),
                    const SizedBox(height: 14),

                    _FieldLabel(label: 'Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Create a password',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFF616161), size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF616161),
                            size: 18,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
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

                    // Password Strength Bar
                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        ...List.generate(4, (i) {
                          final active = i < passwordStrength;
                          return Expanded(
                            child: Container(
                              height: 3,
                              margin:
                                  EdgeInsets.only(right: i < 3 ? 4 : 0),
                              decoration: BoxDecoration(
                                color: active
                                    ? _strengthColor(passwordStrength)
                                    : const Color(0xFF2C2C2C),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 10),
                        Text(
                          _strengthLabel(passwordStrength),
                          style: TextStyle(
                            color: _strengthColor(passwordStrength),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ]),
                    ],

                    const SizedBox(height: 20),

                    _FieldLabel(label: 'Confirm Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _savePlayer(),
                      decoration: InputDecoration(
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFF616161), size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF616161),
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

                    // ── Save Button ───────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _savePlayer,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Add Player',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF616161),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: Color(0xFF2C2C2C))),
    ]);
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF9E9E9E),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}