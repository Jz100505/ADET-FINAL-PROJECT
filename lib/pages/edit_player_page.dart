import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/player_model.dart';
import '../services/local_db_service.dart';

class EditPlayerPage extends StatefulWidget {
  final Player player;

  const EditPlayerPage({super.key, required this.player});

  @override
  State<EditPlayerPage> createState() => _EditPlayerPageState();
}

class _EditPlayerPageState extends State<EditPlayerPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _playerNameController;
  late final TextEditingController _usernameController;
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _changePassword = false;
  File? _pickedImage;
  String? _existingAvatarPath;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _playerNameController =
        TextEditingController(text: widget.player.playerName);
    _usernameController =
        TextEditingController(text: widget.player.username);

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
    _loadExistingAvatar();
  }

  Future<void> _loadExistingAvatar() async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'player_avatar_${widget.player.playerId}.jpg');
      if (File(path).existsSync()) {
        setState(() => _existingAvatarPath = path);
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: source, imageQuality: 75, maxWidth: 512, maxHeight: 512);
      if (picked == null || !mounted) return;

      // Save to app documents dir keyed by player ID
      final dir     = await getApplicationDocumentsDirectory();
      final destPath = p.join(dir.path, 'player_avatar_${widget.player.playerId}.jpg');
      final saved   = await File(picked.path).copy(destPath);

      setState(() {
        _pickedImage       = saved;
        _existingAvatarPath = destPath;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not pick image: \$e'),
        backgroundColor: const Color(0xFFE24B4A),
      ));
    }
  }

  void _showImageSourceSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Change Profile Picture',
              style: TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _sourceBtn(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              color: const Color(0xFF378ADD),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            )),
            const SizedBox(width: 12),
            Expanded(child: _sourceBtn(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              color: const Color(0xFF7F77DD),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            )),
          ]),
          if (_existingAvatarPath != null) ...[ 
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                final path = _existingAvatarPath;
                setState(() {
                  _pickedImage        = null;
                  _existingAvatarPath = null;
                });
                if (path != null) {
                  try { File(path).deleteSync(); } catch (_) {}
                }
              },
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE24B4A).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE24B4A).withOpacity(0.25), width: 0.5),
                ),
                child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_outline, color: Color(0xFFE24B4A), size: 18),
                  SizedBox(width: 8),
                  Text('Remove Photo',
                      style: TextStyle(color: Color(0xFFE24B4A),
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ])),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _sourceBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 0.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color,
              fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _playerNameController.dispose();
    _usernameController.dispose();
    _newPasswordController.dispose();
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

  // ── Avatar color by initial ───────────────────────────────────
  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFFE53935),
      const Color(0xFF378ADD),
      const Color(0xFF1D9E75),
      const Color(0xFFEF9F27),
      const Color(0xFF7F77DD),
      const Color(0xFF5DCAA5),
      const Color(0xFFD85A30),
    ];
    final index =
        name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return colors[index];
  }

  Future<void> _updatePlayer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final result = await LocalDbService.instance.updatePlayer(
        playerId: widget.player.playerId,
        playerName: _playerNameController.text.trim(),
        username: _usernameController.text.trim(),
        newPassword: _changePassword && _newPasswordController.text.isNotEmpty
            ? _newPasswordController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 16),
              SizedBox(width: 10),
              Text('Player updated successfully'),
            ]),
            backgroundColor: Color(0xFF1D9E75),
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showError(
            result['message']?.toString() ?? 'Failed to update player');
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
        _passwordStrength(_newPasswordController.text);

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
          title: const Text('Edit Player'),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _updatePlayer,
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
                      'Update',
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
                          final name = value.text.isNotEmpty
                              ? value.text
                              : widget.player.playerName;
                          final color = _avatarColor(name);
                          final initial = name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?';
                          return GestureDetector(
                            onTap: _showImageSourceSheet,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: color.withValues(alpha: 0.3),
                                        width: 1),
                                  ),
                                  child: _existingAvatarPath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(19),
                                          child: Image.file(
                                            File(_existingAvatarPath!),
                                            fit: BoxFit.cover,
                                            width: 72, height: 72,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(initial,
                                                  style: TextStyle(color: color,
                                                      fontSize: 28,
                                                      fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(initial,
                                              style: TextStyle(color: color,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                ),
                                // Edit badge
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF378ADD),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFF121212),
                                        width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 11),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    Center(
                      child: Text(
                        'ID #${widget.player.playerId}',
                        style: const TextStyle(
                          color: Color(0xFF424242),
                          fontSize: 11,
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
                        hintText: 'Enter username',
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

                    // Change Password Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF2C2C2C), width: 0.5),
                      ),
                      child: SwitchListTile(
                        value: _changePassword,
                        onChanged: (val) {
                          setState(() {
                            _changePassword = val;
                            if (!val) {
                              _newPasswordController.clear();
                              _confirmPasswordController.clear();
                            }
                          });
                        },
                        activeColor: const Color(0xFFE53935),
                        title: const Text(
                          'Change Password',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          'Toggle to update this player\'s password',
                          style: TextStyle(
                              color: Color(0xFF616161), fontSize: 11),
                        ),
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _changePassword
                                ? const Color(0xFFE53935)
                                    .withValues(alpha: 0.12)
                                : const Color(0xFF2C2C2C)
                                    .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            color: _changePassword
                                ? const Color(0xFFE53935)
                                : const Color(0xFF616161),
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                    // New Password Fields (animated)
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState: _changePassword
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox(height: 0),
                      secondChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          _FieldLabel(label: 'New Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Enter new password',
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
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (!_changePassword) return null;
                              if (v == null || v.isEmpty) {
                                return 'New password is required';
                              }
                              if (v.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          // Password strength bar
                          if (_newPasswordController.text.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(children: [
                              ...List.generate(4, (i) {
                                final active = i < passwordStrength;
                                return Expanded(
                                  child: Container(
                                    height: 3,
                                    margin: EdgeInsets.only(
                                        right: i < 3 ? 4 : 0),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? _strengthColor(passwordStrength)
                                          : const Color(0xFF2C2C2C),
                                      borderRadius:
                                          BorderRadius.circular(2),
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

                          _FieldLabel(label: 'Confirm New Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _updatePlayer(),
                            decoration: InputDecoration(
                              hintText: 'Re-enter new password',
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
                              if (!_changePassword) return null;
                              if (v == null || v.isEmpty) {
                                return 'Please confirm your new password';
                              }
                              if (v != _newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Update Button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updatePlayer,
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
                                'Update Player',
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