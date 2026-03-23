import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';

// ─── Design tokens ────────────────────────────────────────────
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
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────
  List<Monster> _monsters     = [];
  bool   _isLoading           = true;
  bool   _isLocating          = false;
  LatLng? _userLocation;
  double? _userAccuracy;       // GPS accuracy in meters
  Monster? _selectedMonster;

  // Filter state
  String _selectedType  = 'All';
  bool   _showCaptured  = false;

  final _mapController = MapController();

  static const _defaultCenter = LatLng(15.1449, 120.5887);
  static const _types = [
    'All','Fire','Water','Grass','Electric',
    'Psychic','Ice','Rock','Ghost','Dragon',
  ];

  // ── Animations ────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _panelCtrl;
  late AnimationController _pulseCtrl;   // GPS ring + selected marker ring
  late AnimationController _filterCtrl;

  late Animation<double> _fadeIn;
  late Animation<Offset> _panelSlide;
  late Animation<double> _pulseAnim;
  late Animation<double> _filterFade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _panelCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    _pulseCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _filterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _fadeIn     = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _panelSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));
    _pulseAnim  = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _filterFade = CurvedAnimation(parent: _filterCtrl, curve: Curves.easeOut);

    _loadMonsters();
    _getUserLocation();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _panelCtrl.dispose();
    _pulseCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  // ── Computed ─────────────────────────────────────────────
  List<Monster> get _filtered {
    return _monsters.where((m) {
      final isCaptured = m.monsterName.endsWith('(Captured)');
      if (isCaptured && !_showCaptured) return false;
      if (_selectedType != 'All' &&
          m.monsterType.toLowerCase() != _selectedType.toLowerCase()) return false;
      return true;
    }).toList();
  }

  int get _activeCount   => _monsters.where((m) => !m.monsterName.endsWith('(Captured)')).length;
  int get _capturedCount => _monsters.where((m) =>  m.monsterName.endsWith('(Captured)')).length;

  bool _isInsideSpawn(Monster m) {
    if (_userLocation == null) return false;
    final d = const Distance().as(
      LengthUnit.Meter,
      _userLocation!,
      LatLng(m.spawnLatitude, m.spawnLongitude),
    );
    return d <= m.spawnRadiusMeters;
  }

  // ── Data ─────────────────────────────────────────────────
  Future<void> _loadMonsters() async {
    setState(() => _isLoading = true);
    try {
      final monsters = await ApiService.getMonsters();
      if (!mounted) return;
      setState(() { _monsters = monsters; _isLoading = false; });
      _fadeCtrl.forward(from: 0);
      _filterCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Failed to load monsters: $e', _accentRed);
    }
  }

  // ── GPS ──────────────────────────────────────────────────
  Future<void> _getUserLocation() async {
    setState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _userAccuracy = pos.accuracy;
      });
    } catch (_) {
      // silently ignore
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── Navigation ───────────────────────────────────────────
  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 17);
    } else {
      _getUserLocation();
    }
  }

  void _centerOnMonster(Monster m) =>
      _mapController.move(LatLng(m.spawnLatitude, m.spawnLongitude), 17);

  void _selectMonster(Monster m) {
    HapticFeedback.selectionClick();
    setState(() => _selectedMonster = m);
    _panelCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _centerOnMonster(m);
    });
  }

  void _dismissPanel() {
    _panelCtrl.reverse().then((_) {
      if (mounted) setState(() => _selectedMonster = null);
    });
  }

  void _fitAll() {
    final visible = _filtered;
    if (visible.isEmpty) return;
    if (visible.length == 1) {
      _mapController.move(LatLng(visible[0].spawnLatitude, visible[0].spawnLongitude), 15);
      return;
    }
    final points = visible.map((m) => LatLng(m.spawnLatitude, m.spawnLongitude)).toList();
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 280),
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(children: [

          // ── Map ────────────────────────────────────────
          _buildMap(),

          // ── Loading overlay ────────────────────────────
          if (_isLoading)
            Container(
              color: _bg,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: _accentRed, strokeWidth: 2),
                  const SizedBox(height: 16),
                  const Text('Loading map…',
                      style: TextStyle(color: _textSecondary, fontSize: 13)),
                ]),
              ),
            ),

          // ── Top overlay (appbar pill + stats + filter) ─
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopOverlay(topPad),
          ),

          // ── FAB group ──────────────────────────────────
          if (!_isLoading)
            Positioned(
              right: 16,
              bottom: _selectedMonster != null ? 280 : 40,
              child: AnimatedSlide(
                offset: Offset.zero,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: _buildFabGroup(),
              ),
            ),

          // ── Bottom detail panel ────────────────────────
          if (_selectedMonster != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SlideTransition(
                position: _panelSlide,
                child: _buildDetailPanel(_selectedMonster!),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Map ──────────────────────────────────────────────────
  Widget _buildMap() {
    final filtered = _filtered;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _defaultCenter,
          initialZoom: 15.0,
          onTap: (_, __) { if (_selectedMonster != null) _dismissPanel(); },
        ),
        children: [
          // OSM tiles
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.haumonsters',
          ),

          // Spawn radius circles
          if (!_isLoading)
            CircleLayer(
              circles: filtered.map((m) {
                final isCaptured = m.monsterName.endsWith('(Captured)');
                final color      = isCaptured ? _textMuted : _typeColor(m.monsterType);
                final isSelected = _selectedMonster?.monsterId == m.monsterId;
                return CircleMarker(
                  point: LatLng(m.spawnLatitude, m.spawnLongitude),
                  radius: m.spawnRadiusMeters,
                  useRadiusInMeter: true,
                  color: isCaptured
                      ? _textMuted.withValues(alpha: 0.04)
                      : isSelected
                          ? color.withValues(alpha: 0.18)
                          : color.withValues(alpha: 0.09),
                  borderStrokeWidth: isCaptured ? 0.5 : (isSelected ? 2.0 : 1.0),
                  borderColor: isCaptured
                      ? _textMuted.withValues(alpha: 0.25)
                      : isSelected
                          ? color.withValues(alpha: 0.70)
                          : color.withValues(alpha: 0.40),
                );
              }).toList(),
            ),

          // GPS accuracy ring
          if (_userLocation != null && _userAccuracy != null)
            CircleLayer(circles: [
              CircleMarker(
                point: _userLocation!,
                radius: _userAccuracy!,
                useRadiusInMeter: true,
                color: _accentBlue.withValues(alpha: 0.06 * _pulseAnim.value),
                borderStrokeWidth: 1.0,
                borderColor: _accentBlue.withValues(alpha: 0.25 * _pulseAnim.value),
              ),
            ]),

          // Markers
          if (!_isLoading)
            MarkerLayer(markers: [
              // User location
              if (_userLocation != null)
                Marker(
                  point: _userLocation!,
                  width: 44, height: 44,
                  child: Stack(alignment: Alignment.center, children: [
                    // Pulse ring
                    Container(
                      width: 44 * _pulseAnim.value,
                      height: 44 * _pulseAnim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _accentBlue.withValues(alpha: 0.35 * (1 - _pulseAnim.value + 0.4)),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Core dot
                    Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: _accentBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [BoxShadow(
                          color: _accentBlue.withValues(alpha: 0.45),
                          blurRadius: 10, spreadRadius: 2)],
                      ),
                    ),
                  ]),
                ),

              // Monster markers
              ...filtered.map((m) {
                final isCaptured = m.monsterName.endsWith('(Captured)');
                final isSelected = _selectedMonster?.monsterId == m.monsterId;
                final color      = isCaptured ? _textMuted : _typeColor(m.monsterType);
                final size       = isSelected ? 54.0 : 42.0;

                return Marker(
                  point: LatLng(m.spawnLatitude, m.spawnLongitude),
                  width: size, height: size,
                  child: GestureDetector(
                    onTap: () => _selectMonster(m),
                    child: Stack(alignment: Alignment.center, children: [
                      // Selected pulse ring
                      if (isSelected)
                        Container(
                          width: 54 * _pulseAnim.value,
                          height: 54 * _pulseAnim.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.withValues(alpha: 0.5 * (1 - _pulseAnim.value + 0.4)),
                              width: 2,
                            ),
                          ),
                        ),
                      // Marker body
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        width:  isSelected ? 48 : 38,
                        height: isSelected ? 48 : 38,
                        decoration: BoxDecoration(
                          color: isCaptured
                              ? _surface
                              : isSelected
                                  ? color
                                  : color.withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCaptured
                                ? _border
                                : Colors.white,
                            width: isSelected ? 2.5 : 1.8,
                          ),
                          boxShadow: [BoxShadow(
                            color: color.withValues(alpha: isCaptured ? 0.10 : isSelected ? 0.55 : 0.30),
                            blurRadius: isSelected ? 18 : 8,
                            spreadRadius: isSelected ? 2 : 0,
                          )],
                        ),
                        child: Center(
                          child: isCaptured
                              ? Icon(Icons.check_rounded, color: _textMuted, size: isSelected ? 20 : 16)
                              : Text(
                                  m.monsterName.isNotEmpty ? m.monsterName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSelected ? 20 : 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            ]),
        ],
      ),
    );
  }

  // ── Top overlay ──────────────────────────────────────────
  Widget _buildTopOverlay(double topPad) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _bg.withValues(alpha: 0.97),
            _bg.withValues(alpha: 0.0),
          ],
          stops: const [0.65, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Appbar pill ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _elevated.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border, width: 0.5),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                // Back
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 48, height: 48,
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _textSecondary, size: 17),
                  ),
                ),
                // Title
                const Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('MONSTER MAP',
                        style: TextStyle(color: _textMuted, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                    SizedBox(height: 1),
                    Text('Spawn Locations',
                        style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                  ]),
                ),
                // GPS / locating
                GestureDetector(
                  onTap: _isLocating ? null : _getUserLocation,
                  child: Container(
                    width: 48, height: 48,
                    child: _isLocating
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: CircularProgressIndicator(color: _accentBlue, strokeWidth: 2))
                        : Icon(
                            _userLocation != null
                                ? Icons.my_location_rounded
                                : Icons.location_searching_rounded,
                            color: _userLocation != null ? _accentBlue : _textMuted,
                            size: 18),
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 8),

          // ── Stats strip ───────────────────────────────
          if (!_isLoading)
            FadeTransition(
              opacity: _filterFade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  _StatPill(
                    icon: Icons.pets,
                    label: '$_activeCount Active',
                    color: _accentGreen,
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    icon: Icons.check_circle_outline,
                    label: '$_capturedCount Captured',
                    color: _textSecondary,
                    onTap: () => setState(() => _showCaptured = !_showCaptured),
                    active: _showCaptured,
                  ),
                  if (_selectedType != 'All') ...[
                    const SizedBox(width: 8),
                    _StatPill(
                      icon: Icons.close_rounded,
                      label: _selectedType,
                      color: _typeColor(_selectedType),
                      onTap: () => setState(() => _selectedType = 'All'),
                    ),
                  ],
                ]),
              ),
            ),

          const SizedBox(height: 8),

          // ── Type filter chips ─────────────────────────
          if (!_isLoading)
            FadeTransition(
              opacity: _filterFade,
              child: SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  itemCount: _types.length,
                  itemBuilder: (_, i) {
                    final t      = _types[i];
                    final active = _selectedType == t;
                    final color  = _typeColor(t);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedType = t);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: active
                                ? color.withValues(alpha: 0.18)
                                : _elevated.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active ? color.withValues(alpha: 0.5) : _border,
                              width: active ? 1.0 : 0.5,
                            ),
                            boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6)],
                          ),
                          child: Text(t,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                                  color: active ? color : _textSecondary)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  // ── FAB group ────────────────────────────────────────────
  Widget _buildFabGroup() {
    return Container(
      decoration: BoxDecoration(
        color: _elevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 0.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _FabItem(
          icon: _isLocating ? Icons.hourglass_empty_rounded : Icons.my_location_rounded,
          color: _accentBlue,
          tooltip: 'My Location',
          onTap: _centerOnUser,
          topRounded: true,
        ),
        Container(height: 0.5, color: _border),
        _FabItem(
          icon: Icons.refresh_rounded,
          color: _accentGreen,
          tooltip: 'Refresh',
          onTap: _loadMonsters,
        ),
        Container(height: 0.5, color: _border),
        _FabItem(
          icon: Icons.fit_screen_rounded,
          color: const Color(0xFFEF9F27),
          tooltip: 'Fit All',
          onTap: _fitAll,
          bottomRounded: true,
        ),
      ]),
    );
  }

  // ── Detail panel ─────────────────────────────────────────
  Widget _buildDetailPanel(Monster m) {
    final isCaptured  = m.monsterName.endsWith('(Captured)');
    final typeColor   = isCaptured ? _textSecondary : _typeColor(m.monsterType);
    final inRange     = _isInsideSpawn(m);
    final displayName = isCaptured
        ? m.monsterName.replaceAll(' (Captured)', '')
        : m.monsterName;

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 250) _dismissPanel();
      },
      child: Container(
        decoration: BoxDecoration(
          color: _elevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 32, offset: const Offset(0, -8))],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: IntrinsicHeight(
            child: Row(children: [
              // Type color accent bar
              Container(width: 4, color: typeColor),

              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: _border, borderRadius: BorderRadius.circular(2)),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    child: Column(children: [

                      // ── Header row ──────────────────────
                      Row(children: [
                        // Avatar
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: typeColor.withValues(alpha: 0.25), width: 0.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: m.pictureUrl != null && m.pictureUrl!.isNotEmpty
                                ? Image.network(m.pictureUrl!, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _panelFallback(displayName, typeColor))
                                : _panelFallback(displayName, typeColor),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Name + type + status
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text(displayName,
                                    style: TextStyle(
                                      color: isCaptured ? _textSecondary : _textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                      decoration: isCaptured ? TextDecoration.lineThrough : null,
                                      decorationColor: _textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                            const SizedBox(height: 5),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(m.monsterType.toUpperCase(),
                                    style: TextStyle(
                                        color: typeColor, fontSize: 9,
                                        fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                              ),
                              const SizedBox(width: 8),
                              if (isCaptured)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _accentGreen.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text('CAPTURED',
                                      style: TextStyle(color: _accentGreen, fontSize: 9,
                                          fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                                )
                              else if (_userLocation != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: inRange
                                        ? _accentGreen.withValues(alpha: 0.12)
                                        : _accentRed.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      width: 5, height: 5,
                                      decoration: BoxDecoration(
                                        color: inRange ? _accentGreen : _accentRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(inRange ? 'IN RANGE' : 'OUT OF RANGE',
                                        style: TextStyle(
                                            color: inRange ? _accentGreen : _accentRed,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6)),
                                  ]),
                                ),
                            ]),
                          ]),
                        ),

                        // Close button
                        GestureDetector(
                          onTap: _dismissPanel,
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: _surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: _border, width: 0.5),
                            ),
                            child: const Icon(Icons.close_rounded, color: _textMuted, size: 15),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 16),
                      Container(height: 0.5, color: _border),
                      const SizedBox(height: 14),

                      // ── Stats row ────────────────────────
                      Row(children: [
                        // Radius (hero)
                        Expanded(
                          child: Column(children: [
                            Text(
                              '${m.spawnRadiusMeters.toStringAsFixed(0)}m',
                              style: TextStyle(
                                  color: typeColor,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 2),
                            const Text('SPAWN RADIUS',
                                style: TextStyle(color: _textMuted, fontSize: 8,
                                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                          ]),
                        ),
                        Container(width: 0.5, height: 44, color: _border),
                        Expanded(
                          child: Column(children: [
                            Text(m.spawnLatitude.toStringAsFixed(4),
                                style: const TextStyle(color: _textPrimary, fontSize: 14,
                                    fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                            const SizedBox(height: 2),
                            const Text('LATITUDE',
                                style: TextStyle(color: _textMuted, fontSize: 8,
                                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                          ]),
                        ),
                        Container(width: 0.5, height: 44, color: _border),
                        Expanded(
                          child: Column(children: [
                            Text(m.spawnLongitude.toStringAsFixed(4),
                                style: const TextStyle(color: _textPrimary, fontSize: 14,
                                    fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                            const SizedBox(height: 2),
                            const Text('LONGITUDE',
                                style: TextStyle(color: _textMuted, fontSize: 8,
                                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                          ]),
                        ),
                      ]),

                      // ── Distance from user (if location available) ──
                      if (_userLocation != null) ...[
                        const SizedBox(height: 12),
                        _buildDistanceBar(m, typeColor, isCaptured),
                      ],

                      const SizedBox(height: 14),

                      // ── Action buttons ───────────────────
                      Row(children: [
                        Expanded(
                          child: _PanelBtn(
                            icon: Icons.center_focus_strong_rounded,
                            label: 'Center',
                            color: typeColor,
                            onTap: () => _centerOnMonster(m),
                          ),
                        ),
                        if (_userLocation != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PanelBtn(
                              icon: Icons.navigation_rounded,
                              label: 'Navigate',
                              color: _accentBlue,
                              onTap: () {
                                _dismissPanel();
                                _fitAll();
                              },
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PanelBtn(
                            icon: Icons.fit_screen_rounded,
                            label: 'Fit All',
                            color: const Color(0xFFEF9F27),
                            onTap: () { _dismissPanel(); _fitAll(); },
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceBar(Monster m, Color typeColor, bool isCaptured) {
    final dist = const Distance().as(
      LengthUnit.Meter,
      _userLocation!,
      LatLng(m.spawnLatitude, m.spawnLongitude),
    );
    final radius   = m.spawnRadiusMeters;
    final progress = (1.0 - (dist / math.max(radius, 1)).clamp(0.0, 1.0)).clamp(0.0, 1.0);
    final inRange  = dist <= radius;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(
          inRange ? 'You are inside the spawn zone' : '${dist.toStringAsFixed(0)}m from spawn center',
          style: TextStyle(
              color: inRange ? _accentGreen : _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          inRange ? 'IN RANGE' : '${(dist - radius).toStringAsFixed(0)}m outside',
          style: TextStyle(
              color: inRange ? _accentGreen : _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(children: [
          Container(height: 5, color: _border),
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (isCaptured ? _textMuted : typeColor).withValues(alpha: 0.5),
                    isCaptured ? _textMuted : typeColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _panelFallback(String name, Color color) => Container(
    color: color.withValues(alpha: 0.07),
    child: Center(child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900),
    )),
  );
}

// ─────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final bool     active;
  final VoidCallback? onTap;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
    this.active = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.12)
            : _elevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.35) : _border,
          width: 0.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: active ? color : _textMuted),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: active ? color : _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _FabItem extends StatefulWidget {
  final IconData icon;
  final Color    color;
  final String   tooltip;
  final VoidCallback onTap;
  final bool topRounded;
  final bool bottomRounded;

  const _FabItem({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.topRounded    = false,
    this.bottomRounded = false,
  });

  @override
  State<_FabItem> createState() => _FabItemState();
}

class _FabItemState extends State<_FabItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: _pressed ? widget.color.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top:    widget.topRounded    ? const Radius.circular(16) : Radius.zero,
            bottom: widget.bottomRounded ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Icon(widget.icon, color: widget.color, size: 19),
      ),
    );
  }
}

class _PanelBtn extends StatefulWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _PanelBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  State<_PanelBtn> createState() => _PanelBtnState();
}

class _PanelBtnState extends State<_PanelBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withValues(alpha: 0.22), width: 0.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, color: widget.color, size: 15),
            const SizedBox(width: 6),
            Text(widget.label,
                style: TextStyle(
                    color: widget.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}