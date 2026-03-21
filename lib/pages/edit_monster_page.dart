import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';

class EditMonsterPage extends StatefulWidget {
  final Monster monster;
  const EditMonsterPage({super.key, required this.monster});

  @override
  State<EditMonsterPage> createState() => _EditMonsterPageState();
}

class _EditMonsterPageState extends State<EditMonsterPage>
    with TickerProviderStateMixin {

  // ─── Form ──────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _radiusCtrl;

  final FocusNode _nameFocus   = FocusNode();
  final FocusNode _radiusFocus = FocusNode();

  final MapController _mapController = MapController();
  final ImagePicker   _imagePicker   = ImagePicker();

  // ─── State ─────────────────────────────────────────────────
  late LatLng  _selectedPoint;
  late String  _selectedType;
  File?        _selectedImage;
  String?      _currentPictureUrl;
  bool         _hasChanges       = false;
  bool         _isSaving         = false;
  bool         _isUploadingImage = false;
  bool         _isPickingImage   = false;

  static const List<String> _monsterTypes = [
    'Fire','Water','Grass','Electric',
    'Psychic','Ice','Rock','Ghost','Dragon','Normal',
  ];

  // ─── Animations ────────────────────────────────────────────
  late AnimationController _entranceAnim;
  late AnimationController _submitAnim;
  late AnimationController _changesAnim;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _submitScale;
  late Animation<double>   _changesBanner;

  double get _radiusMeters =>
      double.tryParse(_radiusCtrl.text.trim()) ?? 100.0;

  @override
  void initState() {
    super.initState();
    final m = widget.monster;
    _nameCtrl   = TextEditingController(text: m.monsterName);
    _radiusCtrl = TextEditingController(
        text: m.spawnRadiusMeters.toStringAsFixed(2));
    _selectedPoint     = LatLng(m.spawnLatitude, m.spawnLongitude);
    _selectedType      = m.monsterType;
    _currentPictureUrl = m.pictureUrl;

    _initAnimations();
    _listenForChanges();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_selectedPoint, 16);
    });
  }

  void _initAnimations() {
    _entranceAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _submitAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _changesAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));

    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceAnim, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entranceAnim, curve: Curves.easeOut));
    _submitScale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(
            parent: _submitAnim, curve: Curves.easeInOut));
    _changesBanner = CurvedAnimation(
        parent: _changesAnim, curve: Curves.easeOutCubic);

    _entranceAnim.forward();
  }

  void _listenForChanges() {
    void check() {
      final m = widget.monster;
      final changed =
          _nameCtrl.text.trim() != m.monsterName ||
          _selectedType         != m.monsterType  ||
          _selectedPoint.latitude  != m.spawnLatitude   ||
          _selectedPoint.longitude != m.spawnLongitude  ||
          _radiusMeters         != m.spawnRadiusMeters   ||
          _selectedImage        != null;

      if (changed != _hasChanges) {
        setState(() => _hasChanges = changed);
        changed ? _changesAnim.forward() : _changesAnim.reverse();
      }
    }

    _nameCtrl.addListener(check);
    _radiusCtrl.addListener(check);
  }

  // ─── Discard dialog ────────────────────────────────────────
  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (_, __, ___) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF9F27), size: 22),
          SizedBox(width: 10),
          Text('Discard Changes?',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: const Text(
          'You have unsaved changes. Are you sure you want to go back?',
          style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing',
                style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF9F27),
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ─── Image ─────────────────────────────────────────────────
  Future<void> _captureImage() async {
    try {
      setState(() => _isPickingImage = true);
      final picked = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 55, maxWidth: 1280, maxHeight: 1280);
      if (picked == null) return;
      setState(() { _selectedImage = File(picked.path); _hasChanges = true; });
      _changesAnim.forward();
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
      setState(() { _selectedImage = File(picked.path); _hasChanges = true; });
      _changesAnim.forward();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to open gallery: $e', const Color(0xFFE24B4A));
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // ─── Update ────────────────────────────────────────────────
  Future<void> _updateMonster() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }
    if (!_hasChanges) {
      _showSnackBar('No changes to save.', const Color(0xFF2A2A2A));
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    setState(() => _isSaving = true);
    await _submitAnim.forward();

    try {
      String? finalUrl = _currentPictureUrl;
      if (_selectedImage != null) {
        setState(() => _isUploadingImage = true);
        finalUrl = await ApiService.uploadMonsterImage(_selectedImage!);
        setState(() => _isUploadingImage = false);
      }

      final result = await ApiService.updateMonster(
        monsterId:         widget.monster.monsterId,
        monsterName:       _nameCtrl.text.trim(),
        monsterType:       _selectedType,
        spawnLatitude:     _selectedPoint.latitude,
        spawnLongitude:    _selectedPoint.longitude,
        spawnRadiusMeters: _radiusMeters,
        pictureUrl:        finalUrl,
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
      builder: (_) => _EditSuccessSheet(
        monsterName: _nameCtrl.text.trim(),
        monsterType: _selectedType,
        onDone: () { Navigator.pop(context); Navigator.pop(context, true); },
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
    ));
  }

  @override
  void dispose() {
    _entranceAnim.dispose();
    _submitAnim.dispose();
    _changesAnim.dispose();
    _nameCtrl.dispose();
    _radiusCtrl.dispose();
    _nameFocus.dispose();
    _radiusFocus.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final busy = _isSaving || _isUploadingImage || _isPickingImage;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canLeave = await _confirmDiscard();
        if (canLeave && context.mounted) Navigator.pop(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                    // Unsaved changes banner
                    SizeTransition(
                      sizeFactor: _changesBanner,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF9F27).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFEF9F27).withValues(alpha: 0.35),
                              width: 0.5),
                        ),
                        child: const Row(children: [
                          Icon(Icons.edit_note_rounded,
                              color: Color(0xFFEF9F27), size: 16),
                          SizedBox(width: 10),
                          Text('You have unsaved changes',
                              style: TextStyle(
                                  color: Color(0xFFEF9F27),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ),

                    // ID chip
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF2C2C2C), width: 0.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.tag,
                              size: 12, color: Color(0xFF424242)),
                          const SizedBox(width: 4),
                          Text('ID: ${widget.monster.monsterId}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF616161),
                                  fontFamily: 'monospace')),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Identity ──
                    _sectionLabel('Identity'),
                    _FocusField(
                      focusNode: _nameFocus,
                      accentColor: const Color(0xFF378ADD),
                      child: TextFormField(
                        controller: _nameCtrl,
                        focusNode:  _nameFocus,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Name is required';
                          if (v.trim().length < 2) return 'Name is too short';
                          return null;
                        },
                        decoration: _dec(
                            label: 'Monster Name',
                            hint: widget.monster.monsterName,
                            icon: Icons.edit_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildTypeSelector(),

                    // ── Spawn Location ──
                    const SizedBox(height: 20),
                    _sectionLabel('Spawn Location'),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 300,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _selectedPoint,
                            initialZoom: 16,
                            onTap: (_, point) {
                              setState(() => _selectedPoint = point);
                              _listenForChanges();
                            },
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
                                color: const Color(0xFF378ADD)
                                    .withValues(alpha: 0.15),
                                borderStrokeWidth: 2,
                                borderColor: const Color(0xFF378ADD),
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
                    _FocusField(
                      focusNode: _radiusFocus,
                      accentColor: const Color(0xFF378ADD),
                      child: TextFormField(
                        controller: _radiusCtrl,
                        focusNode:  _radiusFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        onChanged: (_) => setState(() {}),
                        onFieldSubmitted: (_) => _updateMonster(),
                        validator: (v) {
                          final r = double.tryParse(v ?? '');
                          if (r == null || r <= 0)
                            return 'Enter a valid radius';
                          return null;
                        },
                        decoration: _dec(
                          label: 'Spawn Radius (meters)',
                          hint: widget.monster.spawnRadiusMeters.toString(),
                          icon: Icons.radar,
                          suffix: const Text('m',
                              style: TextStyle(
                                  color: Color(0xFF616161), fontSize: 13)),
                        ),
                      ),
                    ),

                    // ── Photo ──
                    const SizedBox(height: 20),
                    _sectionLabel('Monster Photo'),
                    // Show new image or existing URL image
                    if (_selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_selectedImage!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover),
                      )
                    else if (_currentPictureUrl != null &&
                        _currentPictureUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          _currentPictureUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: Color(0xFF424242), size: 32),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _hasChanges
                                ? Colors.transparent
                                : const Color(0xFF2C2C2C),
                            width: 0.5,
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: busy ? null : _updateMonster,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasChanges
                                ? const Color(0xFF378ADD)
                                : const Color(0xFF1E1E1E),
                            disabledBackgroundColor:
                                const Color(0xFF378ADD).withValues(alpha: 0.4),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isSaving
                                ? const SizedBox(
                                    key: ValueKey('load'),
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : Row(
                                    key: const ValueKey('label'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _hasChanges
                                            ? Icons.save_outlined
                                            : Icons.check_circle_outline,
                                        size: 19,
                                        color: _hasChanges
                                            ? Colors.white
                                            : const Color(0xFF424242),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isUploadingImage
                                            ? 'Uploading Image...'
                                            : _hasChanges
                                                ? 'Save Changes'
                                                : 'No Changes',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.4,
                                          color: _hasChanges
                                              ? Colors.white
                                              : const Color(0xFF424242),
                                        ),
                                      ),
                                    ],
                                  ),
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
        onPressed: () async {
          final canLeave = await _confirmDiscard();
          if (canLeave && mounted) Navigator.pop(context);
        },
      ),
      title: Column(children: [
        const Text('Edit Monster',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        Text(widget.monster.monsterName,
            style: const TextStyle(fontSize: 11, color: Color(0xFF616161))),
      ]),
      centerTitle: true,
      actions: [
        AnimatedOpacity(
          opacity: _hasChanges ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 250),
          child: IconButton(
            icon: const Icon(Icons.check_rounded,
                color: Color(0xFF1D9E75), size: 22),
            tooltip: 'Save changes',
            onPressed: _hasChanges ? _updateMonster : null,
          ),
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
            final selected  = _selectedType == type;
            final isOriginal = widget.monster.monsterType == type;
            final color      = _typeColor(type);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type);
                _listenForChanges();
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
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? color : const Color(0xFF757575))),
                  if (isOriginal && !selected) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('prev',
                          style: TextStyle(
                              fontSize: 9, color: Color(0xFF616161))),
                    ),
                  ],
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
          Icon(icon,
              color: onTap == null ? color.withValues(alpha: 0.4) : color,
              size: 22),
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
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF616161), size: 18),
      suffixIcon: suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
          : null,
      suffixIconConstraints: const BoxConstraints(),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF2C2C2C), width: 0.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF2C2C2C), width: 0.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF378ADD), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFE24B4A), width: 1.0)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFE24B4A), width: 1.5)),
      errorStyle:
          const TextStyle(color: Color(0xFFE24B4A), fontSize: 11),
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

// ─── Focus Glow Wrapper (Blue Accent) ─────────────────────
class _FocusField extends StatefulWidget {
  final FocusNode focusNode;
  final Widget    child;
  final Color     accentColor;

  const _FocusField({
    required this.focusNode,
    required this.child,
    required this.accentColor,
  });

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
                color: widget.accentColor.withValues(alpha: 0.15),
                blurRadius: 10,
                spreadRadius: 1)]
            : [],
      ),
      child: widget.child,
    );
  }
}

// ─── Edit Success Sheet ─────────────────────────────────────
class _EditSuccessSheet extends StatefulWidget {
  final String monsterName;
  final String monsterType;
  final VoidCallback onDone;

  const _EditSuccessSheet({
    required this.monsterName,
    required this.monsterType,
    required this.onDone,
  });

  @override
  State<_EditSuccessSheet> createState() => _EditSuccessSheetState();
}

class _EditSuccessSheetState extends State<_EditSuccessSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double>   _iconScale;
  late Animation<double>   _contentFade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut)));
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _anim,
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
              color: const Color(0xFF378ADD).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF378ADD).withValues(alpha: 0.4),
                  width: 1.5),
            ),
            child: const Icon(Icons.edit_note_rounded,
                color: Color(0xFF378ADD), size: 34),
          ),
        ),
        const SizedBox(height: 20),
        FadeTransition(
          opacity: _contentFade,
          child: Column(children: [
            const Text('Monster Updated!',
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
                  const TextSpan(text: ' has been updated successfully.'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: widget.onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF378ADD),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Back to Home',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }
}
