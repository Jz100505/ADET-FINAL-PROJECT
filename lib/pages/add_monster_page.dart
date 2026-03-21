import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class AddMonsterPage extends StatefulWidget {
  const AddMonsterPage({super.key});

  @override
  State<AddMonsterPage> createState() => _AddMonsterPageState();
}

class _AddMonsterPageState extends State<AddMonsterPage>
    with TickerProviderStateMixin {

  // ─── Form ──────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl   = TextEditingController();
  final TextEditingController _typeCtrl   = TextEditingController();
  final TextEditingController _radiusCtrl = TextEditingController(text: '100');

  final FocusNode _nameFocus   = FocusNode();
  final FocusNode _typeFocus   = FocusNode();
  final FocusNode _radiusFocus = FocusNode();

  final MapController  _mapController  = MapController();
  final ImagePicker    _imagePicker    = ImagePicker();

  // ─── State ─────────────────────────────────────────────────
  LatLng  _selectedPoint = const LatLng(15.144985, 120.588702);
  File?   _selectedImage;
  String  _selectedType = 'Fire';
  bool    _isSaving          = false;
  bool    _isUploadingImage  = false;
  bool    _isPickingImage    = false;
  bool    _isGettingLocation = false;

  static const List<String> _monsterTypes = [
    'Fire','Water','Grass','Electric',
    'Psychic','Ice','Rock','Ghost','Dragon','Normal',
  ];

  // ─── Animations ────────────────────────────────────────────
  late AnimationController _entranceAnim;
  late AnimationController _submitAnim;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _submitScale;

  double get _radiusMeters =>
      double.tryParse(_radiusCtrl.text.trim()) ?? 100.0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setInitialLocation();
  }

  void _initAnimations() {
    _entranceAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _submitAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));

    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceAnim, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entranceAnim, curve: Curves.easeOut));
    _submitScale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(
            parent: _submitAnim, curve: Curves.easeInOut));

    _entranceAnim.forward();
  }

  // ─── GPS ───────────────────────────────────────────────────
  Future<void> _setInitialLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled.');

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final pt = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;
      setState(() => _selectedPoint = pt);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(pt, 17);
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('GPS not available: $e', const Color(0xFFE24B4A));
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  // ─── Image ─────────────────────────────────────────────────
  Future<void> _captureImage() async {
    try {
      setState(() => _isPickingImage = true);
      final picked = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 55, maxWidth: 1280, maxHeight: 1280);
      if (picked == null) return;
      setState(() => _selectedImage = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to open camera: $e', const Color(0xFFE24B4A));
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() => _isPickingImage = true);
      final picked = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 55, maxWidth: 1280, maxHeight: 1280);
      if (picked == null) return;
      setState(() => _selectedImage = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to open gallery: $e', const Color(0xFFE24B4A));
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // ─── Save ──────────────────────────────────────────────────
  Future<void> _saveMonster() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    setState(() => _isSaving = true);
    await _submitAnim.forward();

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        setState(() => _isUploadingImage = true);
        imageUrl = await ApiService.uploadMonsterImage(_selectedImage!);
        setState(() => _isUploadingImage = false);
      }

      final result = await ApiService.addMonster(
        monsterName:       _nameCtrl.text.trim(),
        monsterType:       _selectedType,
        spawnLatitude:     _selectedPoint.latitude,
        spawnLongitude:    _selectedPoint.longitude,
        spawnRadiusMeters: _radiusMeters,
        pictureUrl:        imageUrl,
      );

      if (!mounted) return;
      await _submitAnim.reverse();

      if (result['success'] == true) {
        HapticFeedback.mediumImpact();
        _showSuccessSheet();
      } else {
        _showSnackBar(
            result['message']?.toString() ?? 'Failed', const Color(0xFFE24B4A));
      }
    } catch (e) {
      if (!mounted) return;
      await _submitAnim.reverse();
      _showSnackBar('Error: $e', const Color(0xFFE24B4A));
    } finally {
      if (mounted) setState(() { _isSaving = false; _isUploadingImage = false; });
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _SuccessSheet(
        monsterName: _nameCtrl.text.trim(),
        monsterType: _selectedType,
        onDone: () { Navigator.pop(context); Navigator.pop(context); },
        onAddAnother: () {
          Navigator.pop(context);
          _formKey.currentState?.reset();
          _nameCtrl.clear();
          _radiusCtrl.text = '100';
          setState(() { _selectedImage = null; _selectedType = 'Fire'; });
          _setInitialLocation();
          _entranceAnim.forward(from: 0);
        },
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline, color: Colors.white, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: color,
    ));
  }

  @override
  void dispose() {
    _entranceAnim.dispose();
    _submitAnim.dispose();
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _radiusCtrl.dispose();
    _nameFocus.dispose();
    _typeFocus.dispose();
    _radiusFocus.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // _isGettingLocation intentionally excluded — GPS running in background
    // should NOT prevent the user from submitting the form.
    final busy = _isSaving || _isUploadingImage || _isPickingImage;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: _buildAppBar(),
        body: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  // ── Identity ──
                  _sectionLabel('Identity'),
                  _FocusField(
                    focusNode: _nameFocus,
                    child: TextFormField(
                      controller: _nameCtrl,
                      focusNode:  _nameFocus,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_typeFocus),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Monster name is required';
                        if (v.trim().length < 2) return 'Name is too short';
                        return null;
                      },
                      decoration: _dec(
                          hint: 'e.g. Flamewing',
                          label: 'Monster Name',
                          icon: Icons.edit_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTypeSelector(),

                  // ── Spawn Location ──
                  const SizedBox(height: 20),
                  _sectionLabel('Spawn Location'),
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D9E75).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF1D9E75).withValues(alpha: 0.25),
                          width: 0.5),
                    ),
                    child: const Row(children: [
                      Icon(Icons.location_on_outlined,
                          color: Color(0xFF1D9E75), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap on the map to set the monster spawn point',
                          style: TextStyle(
                              color: Color(0xFF1D9E75),
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ),
                  // Map
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 320,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedPoint,
                          initialZoom: 16,
                          onTap: (_, point) =>
                              setState(() => _selectedPoint = point),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.haumonsters',
                          ),
                          CircleLayer(circles: [
                            CircleMarker(
                              point: _selectedPoint,
                              radius: _radiusMeters,
                              useRadiusInMeter: true,
                              color: const Color(0xFF1D9E75).withValues(alpha: 0.15),
                              borderStrokeWidth: 2,
                              borderColor: const Color(0xFF1D9E75),
                            ),
                          ]),
                          MarkerLayer(markers: [
                            Marker(
                              point: _selectedPoint,
                              width: 60, height: 60,
                              child: const Icon(Icons.location_pin,
                                  size: 50, color: Color(0xFFE53935)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Coords display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF2C2C2C), width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _coordChip('LAT',
                            _selectedPoint.latitude.toStringAsFixed(5)),
                        Container(width: 0.5, height: 30,
                            color: const Color(0xFF2C2C2C)),
                        _coordChip('LNG',
                            _selectedPoint.longitude.toStringAsFixed(5)),
                        Container(width: 0.5, height: 30,
                            color: const Color(0xFF2C2C2C)),
                        _coordChip('RAD',
                            '${_radiusMeters.toStringAsFixed(0)}m'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Radius field
                  _FocusField(
                    focusNode: _radiusFocus,
                    child: TextFormField(
                      controller: _radiusCtrl,
                      focusNode:  _radiusFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => _saveMonster(),
                      validator: (v) {
                        final r = double.tryParse(v ?? '');
                        if (r == null || r <= 0) return 'Enter a valid radius';
                        return null;
                      },
                      decoration: _dec(
                        hint: '100',
                        label: 'Spawn Radius (meters)',
                        icon: Icons.radar,
                        suffix: const Text('m',
                            style: TextStyle(
                                color: Color(0xFF616161), fontSize: 13)),
                      ),
                    ),
                  ),

                  // ── Photo ──
                  const SizedBox(height: 20),
                  _sectionLabel('Monster Photo (Optional)'),
                  if (_selectedImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(_selectedImage!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    Expanded(
                      child: _photoButton(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        color: const Color(0xFF378ADD),
                        onTap: busy ? null : _captureImage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _photoButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        color: const Color(0xFF7F77DD),
                        onTap: busy ? null : _pickFromGallery,
                      ),
                    ),
                  ]),

                  // ── Submit ──
                  const SizedBox(height: 28),
                  ScaleTransition(
                    scale: _submitScale,
                    child: ElevatedButton(
                      onPressed: busy ? null : _saveMonster,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        disabledBackgroundColor:
                            const Color(0xFFE53935).withValues(alpha: 0.4),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isSaving
                            ? SizedBox(
                                key: const ValueKey('load'),
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                  value: _isUploadingImage ? null : null,
                                ),
                              )
                            : Row(
                                key: const ValueKey('label'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_circle_outline,
                                      size: 19),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isUploadingImage
                                        ? 'Uploading Image...'
                                        : 'Save Monster',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Add Monster'),
      actions: [
        IconButton(
          icon: Icon(Icons.my_location,
              color: _isGettingLocation
                  ? const Color(0xFFE53935)
                  : const Color(0xFF9E9E9E),
              size: 20),
          onPressed: _isGettingLocation ? null : _setInitialLocation,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: const Color(0xFF2C2C2C)),
      ),
    );
  }

  // ─── Type Selector ─────────────────────────────────────────
  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Monster Type',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9E9E9E))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _monsterTypes.map((type) {
            final selected = _selectedType == type;
            final color    = _typeColor(type);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.18)
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? color.withValues(alpha: 0.6)
                        : const Color(0xFF2C2C2C),
                    width: selected ? 1.0 : 0.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? color : const Color(0xFF424242),
                        width: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(type,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? color
                              : const Color(0xFF757575))),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────────
  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161),
                letterSpacing: 1.2)),
        const SizedBox(width: 10),
        const Expanded(
            child: Divider(color: Color(0xFF2C2C2C), thickness: 0.5)),
      ]),
    );
  }

  Widget _coordChip(String label, String value) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF616161),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
              fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: onTap == null ? color.withValues(alpha: 0.4) : color, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: onTap == null ? color.withValues(alpha: 0.4) : color,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  InputDecoration _dec({
    required String hint,
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF616161), size: 18),
      suffixIcon: suffix != null
          ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: suffix)
          : null,
      suffixIconConstraints: const BoxConstraints(),
    );
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':     return const Color(0xFFE53935);
      case 'water':    return const Color(0xFF378ADD);
      case 'grass':    return const Color(0xFF1D9E75);
      case 'electric': return const Color(0xFFEF9F27);
      case 'psychic':  return const Color(0xFF7F77DD);
      case 'ice':      return const Color(0xFF5DCAA5);
      case 'rock':     return const Color(0xFF888780);
      case 'ghost':    return const Color(0xFF534AB7);
      case 'dragon':   return const Color(0xFFD85A30);
      default:         return const Color(0xFF9E9E9E);
    }
  }
}

// ─── Focus Glow Wrapper ────────────────────────────────────
class _FocusField extends StatefulWidget {
  final FocusNode focusNode;
  final Widget    child;
  const _FocusField({required this.focusNode, required this.child});

  @override
  State<_FocusField> createState() => _FocusFieldState();
}

class _FocusFieldState extends State<_FocusField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _focused
            ? [BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: 0.15),
                blurRadius: 10,
                spreadRadius: 1)]
            : [],
      ),
      child: widget.child,
    );
  }
}

// ─── Success Bottom Sheet ──────────────────────────────────
class _SuccessSheet extends StatefulWidget {
  final String monsterName;
  final String monsterType;
  final VoidCallback onDone;
  final VoidCallback onAddAnother;

  const _SuccessSheet({
    required this.monsterName,
    required this.monsterType,
    required this.onDone,
    required this.onAddAnother,
  });

  @override
  State<_SuccessSheet> createState() => _SuccessSheetState();
}

class _SuccessSheetState extends State<_SuccessSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double>   _iconScale;
  late Animation<double>   _contentFade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _anim,
            curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)));
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _anim,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));
    _anim.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 28),
        ScaleTransition(
          scale: _iconScale,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF1D9E75).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF1D9E75).withValues(alpha: 0.4),
                  width: 1.5),
            ),
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF1D9E75), size: 36),
          ),
        ),
        const SizedBox(height: 20),
        FadeTransition(
          opacity: _contentFade,
          child: Column(children: [
            const Text('Monster Added!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 6),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF757575), height: 1.5),
                children: [
                  TextSpan(
                      text: widget.monsterName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' has been added to the '),
                  TextSpan(
                      text: widget.monsterType,
                      style: const TextStyle(color: Colors.white)),
                  const TextSpan(text: ' collection.'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: widget.onDone,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0),
              child: const Text('Back to Home',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: widget.onAddAnother,
              style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44)),
              child: const Text('Add Another Monster',
                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14)),
            ),
          ]),
        ),
      ]),
    );
  }
}