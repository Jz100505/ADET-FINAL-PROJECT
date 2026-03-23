import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

// ─── Design tokens (shared with dashboard) ────────────────
const _bg            = Color(0xFF0A0A0F);
const _surface       = Color(0xFF12121A);
const _elevated      = Color(0xFF1A1A26);
const _border        = Color(0xFF252535);
const _textPrimary   = Colors.white;
const _textSecondary = Color(0xFF8A8A9A);
const _textMuted     = Color(0xFF4A4A5A);
const _accentRed     = Color(0xFFE53935);
const _accentGreen   = Color(0xFF1D9E75);
const _accentBlue    = Color(0xFF378ADD);

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
    default:         return const Color(0xFF6B6B7B);
  }
}

// ─────────────────────────────────────────────────────────────
class AddMonsterPage extends StatefulWidget {
  const AddMonsterPage({super.key});

  @override
  State<AddMonsterPage> createState() => _AddMonsterPageState();
}

class _AddMonsterPageState extends State<AddMonsterPage>
    with TickerProviderStateMixin {

  // ── Form ──────────────────────────────────────────────────
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '100');
  final _nameFocus  = FocusNode();
  final _radFocus   = FocusNode();

  final _mapCtrl    = MapController();
  final _imgPicker  = ImagePicker();

  // ── State ─────────────────────────────────────────────────
  LatLng  _pin          = const LatLng(15.144985, 120.588702);
  File?   _image;
  String  _type         = 'Fire';
  bool    _saving       = false;
  bool    _uploadingImg = false;
  bool    _pickingImg   = false;
  bool    _gpsLoading   = false;

  static const _types = [
    'Fire','Water','Grass','Electric',
    'Psychic','Ice','Rock','Ghost','Dragon','Normal',
  ];

  // ── Animations ────────────────────────────────────────────
  late AnimationController _entranceCtrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  double get _radius => double.tryParse(_radiusCtrl.text.trim()) ?? 100.0;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _fade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
    _setGpsLocation();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _nameCtrl.dispose();
    _radiusCtrl.dispose();
    _nameFocus.dispose();
    _radFocus.dispose();
    super.dispose();
  }

  // ── GPS ───────────────────────────────────────────────────
  Future<void> _setGpsLocation() async {
    setState(() => _gpsLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      final pt = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = pt);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapCtrl.move(pt, 17);
      });
    } catch (_) {
      if (mounted) _snack('GPS unavailable — tap map to set spawn point', _accentBlue);
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ── Image ─────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource src) async {
    setState(() => _pickingImg = true);
    try {
      final f = await _imgPicker.pickImage(
          source: src, imageQuality: 55, maxWidth: 1280, maxHeight: 1280);
      if (f != null && mounted) setState(() => _image = File(f.path));
    } catch (e) {
      if (mounted) _snack('Could not open ${src == ImageSource.camera ? 'camera' : 'gallery'}: $e', _accentRed);
    } finally {
      if (mounted) setState(() => _pickingImg = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _saving = true);

    try {
      String? imageUrl;
      if (_image != null) {
        setState(() => _uploadingImg = true);
        imageUrl = await ApiService.uploadMonsterImage(_image!);
        setState(() => _uploadingImg = false);
      }

      final result = await ApiService.addMonster(
        monsterName:       _nameCtrl.text.trim(),
        monsterType:       _type,
        spawnLatitude:     _pin.latitude,
        spawnLongitude:    _pin.longitude,
        spawnRadiusMeters: _radius,
        pictureUrl:        imageUrl,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        HapticFeedback.mediumImpact();
        _showSuccessSheet();
      } else {
        _snack(result['message']?.toString() ?? 'Failed to add monster', _accentRed);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', _accentRed);
    } finally {
      if (mounted) setState(() { _saving = false; _uploadingImg = false; });
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _SuccessSheet(
        monsterName: _nameCtrl.text.trim(),
        monsterType: _type,
        onDone: () { Navigator.pop(context); Navigator.pop(context); },
        onAddAnother: () {
          Navigator.pop(context);
          _formKey.currentState?.reset();
          _nameCtrl.clear();
          _radiusCtrl.text = '100';
          setState(() { _image = null; _type = 'Fire'; });
          _setGpsLocation();
          _entranceCtrl.forward(from: 0);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final busy = _saving || _uploadingImg || _pickingImg;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [

                  // ── IDENTITY ──────────────────────────────
                  _SectionLabel('Identity'),
                  const SizedBox(height: 12),

                  // Name field
                  _DarkField(
                    controller:  _nameCtrl,
                    focusNode:   _nameFocus,
                    label:       'Monster Name',
                    hint:        'e.g. Flamewing',
                    icon:        Icons.auto_awesome,
                    inputAction: TextInputAction.next,
                    onSubmit:    (_) => FocusScope.of(context).requestFocus(_radFocus),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Name is required';
                      if (v.trim().length < 2) return 'Too short';
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),
                  _buildTypeSelector(),

                  // ── SPAWN LOCATION ────────────────────────
                  const SizedBox(height: 28),
                  _SectionLabel('Spawn Location'),
                  const SizedBox(height: 12),

                  // Hint banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _accentBlue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _accentBlue.withValues(alpha: 0.18), width: 0.5),
                    ),
                    child: Row(children: [
                      Icon(Icons.touch_app_rounded, color: _accentBlue.withValues(alpha: 0.7), size: 15),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Tap the map to place the spawn point',
                            style: TextStyle(color: _textSecondary, fontSize: 12)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Map
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border, width: 0.5),
                      ),
                      child: FlutterMap(
                        mapController: _mapCtrl,
                        options: MapOptions(
                          initialCenter: _pin,
                          initialZoom: 16,
                          onTap: (_, pt) => setState(() => _pin = pt),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.haumonsters',
                          ),
                          CircleLayer(circles: [
                            CircleMarker(
                              point: _pin,
                              radius: _radius,
                              useRadiusInMeter: true,
                              color: _accentRed.withValues(alpha: 0.12),
                              borderStrokeWidth: 1.5,
                              borderColor: _accentRed.withValues(alpha: 0.5),
                            ),
                          ]),
                          MarkerLayer(markers: [
                            Marker(
                              point: _pin,
                              width: 36, height: 44,
                              child: const Icon(Icons.location_pin,
                                  color: _accentRed, size: 44),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Coord strip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border, width: 0.5),
                    ),
                    child: Row(children: [
                      _CoordChip('LAT', _pin.latitude.toStringAsFixed(5)),
                      Container(width: 0.5, height: 28, color: _border,
                          margin: const EdgeInsets.symmetric(horizontal: 12)),
                      _CoordChip('LNG', _pin.longitude.toStringAsFixed(5)),
                      Container(width: 0.5, height: 28, color: _border,
                          margin: const EdgeInsets.symmetric(horizontal: 12)),
                      _CoordChip('RAD', '${_radius.toStringAsFixed(0)}m'),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Radius field
                  _DarkField(
                    controller:   _radiusCtrl,
                    focusNode:    _radFocus,
                    label:        'Spawn Radius (meters)',
                    hint:         '100',
                    icon:         Icons.radar_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputAction:  TextInputAction.done,
                    onChanged:    (_) => setState(() {}),
                    onSubmit:     (_) => _save(),
                    suffixText:   'm',
                    validator: (v) {
                      final r = double.tryParse(v ?? '');
                      if (r == null || r <= 0) return 'Enter a valid radius';
                      return null;
                    },
                  ),

                  // ── PHOTO ─────────────────────────────────
                  const SizedBox(height: 28),
                  _SectionLabel('Monster Photo', subtitle: 'Optional'),
                  const SizedBox(height: 12),

                  // Image preview
                  if (_image != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(children: [
                        Image.file(_image!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover),
                        // Remove button overlay
                        Positioned(
                          top: 8, right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _image = null),
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Camera / Gallery row
                  Row(children: [
                    Expanded(
                      child: _PhotoBtn(
                        icon:  Icons.camera_alt_outlined,
                        label: 'Camera',
                        color: _accentBlue,
                        disabled: busy,
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PhotoBtn(
                        icon:  Icons.photo_library_outlined,
                        label: 'Gallery',
                        color: const Color(0xFF7F77DD),
                        disabled: busy,
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ]),

                  // ── SUBMIT ────────────────────────────────
                  const SizedBox(height: 32),
                  _SubmitButton(
                    saving:       _saving,
                    uploadingImg: _uploadingImg,
                    onTap:        busy ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          children: [
            Text('Add Monster',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            Text('New registry entry',
                style: TextStyle(
                    color: _textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _gpsLoading ? null : _setGpsLocation,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border, width: 0.5),
                ),
                child: _gpsLoading
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                            color: _accentBlue, strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded,
                        color: _accentBlue, size: 17),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _border),
        ),
      );

  // ── Type selector ─────────────────────────────────────────
  Widget _buildTypeSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Monster Type',
          style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _types.map((t) {
          final selected = _type == t;
          final color    = _typeColor(t);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _type = t);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.14) : _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? color.withValues(alpha: 0.5) : _border,
                  width: selected ? 1.0 : 0.5,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                // Dot indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? color : _border,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(t,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                        color: selected ? color : _textSecondary)),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// REUSABLE FORM WIDGETS
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String  title;
  final String? subtitle;
  const _SectionLabel(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                color: _textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6)),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _border, width: 0.5),
            ),
            child: Text(subtitle!,
                style: const TextStyle(
                    color: _textMuted, fontSize: 8, fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: _border, thickness: 0.5)),
      ]);
}

class _DarkField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final String                label;
  final String                hint;
  final IconData              icon;
  final TextInputType?        keyboardType;
  final TextInputAction?      inputAction;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmit;
  final String?               suffixText;
  final String? Function(String?)? validator;

  const _DarkField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputAction,
    this.onChanged,
    this.onSubmit,
    this.suffixText,
    this.validator,
  });

  @override
  State<_DarkField> createState() => _DarkFieldState();
}

class _DarkFieldState extends State<_DarkField> {
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
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _focused
            ? [BoxShadow(
                color: _accentRed.withValues(alpha: 0.12),
                blurRadius: 12,
                spreadRadius: 1)]
            : [],
      ),
      child: TextFormField(
        controller:     widget.controller,
        focusNode:      widget.focusNode,
        keyboardType:   widget.keyboardType,
        textInputAction: widget.inputAction,
        onChanged:      widget.onChanged,
        onFieldSubmitted: widget.onSubmit,
        validator:      widget.validator,
        style: const TextStyle(color: _textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText:  widget.label,
          hintText:   widget.hint,
          labelStyle: const TextStyle(color: _textSecondary, fontSize: 12),
          hintStyle:  const TextStyle(color: _textMuted, fontSize: 13),
          filled:     true,
          fillColor:  _surface,
          prefixIcon: Icon(widget.icon, color: _textMuted, size: 17),
          suffixIcon: widget.suffixText != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(widget.suffixText!,
                      style: const TextStyle(
                          color: _textMuted, fontSize: 13)))
              : null,
          suffixIconConstraints: const BoxConstraints(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 0.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 0.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accentRed, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE24B4A), width: 1.0)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE24B4A), width: 1.5)),
          errorStyle: const TextStyle(color: Color(0xFFE24B4A), fontSize: 11),
        ),
      ),
    );
  }
}

class _CoordChip extends StatelessWidget {
  final String label;
  final String value;
  const _CoordChip(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: const TextStyle(
                  color: _textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _PhotoBtn extends StatefulWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final bool         disabled;
  final VoidCallback onTap;
  const _PhotoBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.disabled,
    required this.onTap,
  });

  @override
  State<_PhotoBtn> createState() => _PhotoBtnState();
}

class _PhotoBtnState extends State<_PhotoBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final effective = widget.disabled
        ? widget.color.withValues(alpha: 0.25)
        : widget.color;

    return GestureDetector(
      onTapDown:   widget.disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp:     widget.disabled ? null : (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: widget.disabled ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: effective.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: effective.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, color: effective, size: 22),
            const SizedBox(height: 7),
            Text(widget.label,
                style: TextStyle(
                    color: effective,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  final bool saving;
  final bool uploadingImg;
  final VoidCallback? onTap;
  const _SubmitButton({
    required this.saving,
    required this.uploadingImg,
    this.onTap,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;

    return GestureDetector(
      onTapDown:   active ? (_) => setState(() => _pressed = true) : null,
      onTapUp:     active ? (_) { setState(() => _pressed = false); widget.onTap!(); } : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFC62828)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: active ? null : _surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: active
                ? [BoxShadow(
                    color: _accentRed.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 6))]
                : [],
            border: active ? null : Border.all(color: _border, width: 0.5),
          ),
          child: Center(
            child: widget.saving
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5)),
                    const SizedBox(width: 12),
                    Text(
                      widget.uploadingImg ? 'Uploading image…' : 'Saving monster…',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ])
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white, size: 19),
                    SizedBox(width: 10),
                    Text('Save Monster',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2)),
                  ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUCCESS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────
class _SuccessSheet extends StatefulWidget {
  final String       monsterName;
  final String       monsterType;
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
  late AnimationController _ctrl;
  late Animation<double>   _iconScale;
  late Animation<double>   _contentFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _iconScale = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.0, 0.60, curve: Curves.elasticOut)));
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.40, 1.0, curve: Curves.easeOut)));
    _ctrl.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(widget.monsterType);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: const BoxDecoration(
        color: _elevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _border, width: 0.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: _border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 32),

        // Icon
        ScaleTransition(
          scale: _iconScale,
          child: Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              color: _accentGreen.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                  color: _accentGreen.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [BoxShadow(
                color: _accentGreen.withValues(alpha: 0.15),
                blurRadius: 24, spreadRadius: 2)],
            ),
            child: const Icon(Icons.check_rounded,
                color: _accentGreen, size: 36),
          ),
        ),

        const SizedBox(height: 20),

        // Content
        FadeTransition(
          opacity: _contentFade,
          child: Column(children: [
            const Text('Monster Added!',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                    color: _textSecondary, fontSize: 13, height: 1.5),
                children: [
                  TextSpan(
                      text: widget.monsterName,
                      style: TextStyle(
                          color: typeColor, fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' is now registered\nin the monster world.'),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Done button
            GestureDetector(
              onTap: widget.onDone,
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_accentGreen, Color(0xFF158A62)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: _accentGreen.withValues(alpha: 0.25),
                    blurRadius: 16, offset: const Offset(0, 5))],
                ),
                child: const Center(
                  child: Text('Back to Home',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Add another
            GestureDetector(
              onTap: widget.onAddAnother,
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border, width: 0.5),
                ),
                child: const Center(
                  child: Text('Add Another Monster',
                      style: TextStyle(
                          color: _textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}