import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {

  // ─── State ─────────────────────────────────────────────────
  List<Monster> _monsters      = [];
  bool          _isLoading     = true;
  bool          _isLocating    = false;
  LatLng?       _userLocation;
  Monster?      _selectedMonster;

  final MapController _mapController = MapController();

  // ─── Animations ────────────────────────────────────────────
  late AnimationController _fadeAnim;
  late AnimationController _panelAnim;
  late Animation<double>   _fadeIn;
  late Animation<Offset>   _panelSlide;

  static const LatLng _defaultCenter = LatLng(15.1449, 120.5887); // HAU

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadMonsters();
    _getUserLocation();
  }

  void _initAnimations() {
    _fadeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _panelAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));

    _fadeIn = CurvedAnimation(parent: _fadeAnim, curve: Curves.easeOut);
    _panelSlide = Tween<Offset>(
        begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelAnim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _fadeAnim.dispose();
    _panelAnim.dispose();
    super.dispose();
  }

  // ─── Data ──────────────────────────────────────────────────
  Future<void> _loadMonsters() async {
    setState(() => _isLoading = true);
    try {
      final monsters = await ApiService.getMonsters();
      if (!mounted) return;
      setState(() {
        _monsters  = monsters;
        _isLoading = false;
      });
      _fadeAnim.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to load monsters: $e'),
        backgroundColor: const Color(0xFFE24B4A),
      ));
    }
  }

  // ─── GPS ───────────────────────────────────────────────────
  Future<void> _getUserLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (!mounted) return;
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // silently ignore — map still works without user location
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16);
    } else {
      _getUserLocation();
    }
  }

  void _centerOnMonster(Monster m) {
    _mapController.move(LatLng(m.spawnLatitude, m.spawnLongitude), 17);
  }

  void _selectMonster(Monster m) {
    setState(() => _selectedMonster = m);
    _panelAnim.forward(from: 0);
    _centerOnMonster(m);
  }

  void _dismissPanel() {
    _panelAnim.reverse().then((_) {
      if (mounted) setState(() => _selectedMonster = null);
    });
  }

  // ─── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Stack(
          children: [
            // ── Full-screen Map ──
            _buildMap(),

            // ── Top AppBar overlay ──
            _buildAppBarOverlay(),

            // ── Loading overlay ──
            if (_isLoading)
              Container(
                color: const Color(0xFF121212),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE53935)),
                      SizedBox(height: 16),
                      Text('Loading monsters...',
                          style: TextStyle(
                              color: Color(0xFF9E9E9E), fontSize: 14)),
                    ],
                  ),
                ),
              ),

            // ── Monster count chip ──
            if (!_isLoading)
              Positioned(
                top: MediaQuery.of(context).padding.top + 72,
                left: 16,
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: _buildCountChip(),
                ),
              ),

            // ── FAB cluster (right side) ──
            Positioned(
              right: 16,
              bottom: _selectedMonster != null ? 220 : 32,
              child: AnimatedSlide(
                offset: Offset.zero,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapFab(
                      icon: _isLocating
                          ? Icons.hourglass_empty_rounded
                          : Icons.my_location_rounded,
                      color: const Color(0xFF378ADD),
                      tooltip: 'My Location',
                      onTap: _centerOnUser,
                    ),
                    const SizedBox(height: 10),
                    _MapFab(
                      icon: Icons.refresh_rounded,
                      color: const Color(0xFF1D9E75),
                      tooltip: 'Refresh',
                      onTap: _loadMonsters,
                    ),
                    const SizedBox(height: 10),
                    _MapFab(
                      icon: Icons.fit_screen_rounded,
                      color: const Color(0xFFEF9F27),
                      tooltip: 'Fit All',
                      onTap: _fitAllMonsters,
                    ),
                  ],
                ),
              ),
            ),

            // ── Selected monster detail panel ──
            if (_selectedMonster != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: SlideTransition(
                  position: _panelSlide,
                  child: _buildMonsterPanel(_selectedMonster!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Full-screen Map ───────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: 15.0,
        onTap: (_, __) {
          if (_selectedMonster != null) _dismissPanel();
        },
      ),
      children: [
        // Tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.haumonsters',
        ),

        // Spawn radius circles
        if (!_isLoading)
          FadeTransition(
            opacity: _fadeIn,
            child: CircleLayer(
              circles: _monsters.map((m) {
                final color = _typeColor(m.monsterType);
                return CircleMarker(
                  point: LatLng(m.spawnLatitude, m.spawnLongitude),
                  radius: m.spawnRadiusMeters,
                  useRadiusInMeter: true,
                  color: color.withValues(alpha: 0.12),
                  borderStrokeWidth: 1.5,
                  borderColor: color.withValues(alpha: 0.5),
                );
              }).toList(),
            ),
          ),

        // Monster markers
        if (!_isLoading)
          FadeTransition(
            opacity: _fadeIn,
            child: MarkerLayer(
              markers: [
                // User location marker
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 24, height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF378ADD),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF378ADD).withValues(alpha: 0.4),
                            blurRadius: 8, spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Monster markers
                ..._monsters.map((m) {
                  final color     = _typeColor(m.monsterType);
                  final isSelected = _selectedMonster?.monsterId == m.monsterId;

                  return Marker(
                    point: LatLng(m.spawnLatitude, m.spawnLongitude),
                    width: isSelected ? 56 : 44,
                    height: isSelected ? 56 : 44,
                    child: GestureDetector(
                      onTap: () => _selectMonster(m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color
                              : color.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isSelected ? 3.0 : 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(
                                  alpha: isSelected ? 0.6 : 0.35),
                              blurRadius: isSelected ? 16 : 8,
                              spreadRadius: isSelected ? 3 : 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            m.monsterName.isNotEmpty
                                ? m.monsterName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSelected ? 20 : 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  // ─── App Bar Overlay ───────────────────────────────────────
  Widget _buildAppBarOverlay() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF121212).withValues(alpha: 0.95),
              const Color(0xFF121212).withValues(alpha: 0.0),
            ],
            stops: const [0.55, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Monster Map',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // placeholder for symmetric spacing
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Count Chip ────────────────────────────────────────────
  Widget _buildCountChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C2C2C), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.pets, size: 13, color: Color(0xFF1D9E75)),
        const SizedBox(width: 6),
        Text(
          '${_monsters.length} monster${_monsters.length == 1 ? '' : 's'} on map',
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1D9E75),
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  // ─── Monster Detail Panel ──────────────────────────────────
  Widget _buildMonsterPanel(Monster m) {
    final typeColor = _typeColor(m.monsterType);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! > 300) {
          _dismissPanel();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(
              top: BorderSide(color: Color(0xFF2C2C2C), width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar / image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 64, height: 64,
                          child: m.pictureUrl != null &&
                                  m.pictureUrl!.isNotEmpty
                              ? Image.network(
                                  m.pictureUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _panelAvatar(m, typeColor),
                                )
                              : _panelAvatar(m, typeColor),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Name + type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.monsterName,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: typeColor.withValues(alpha: 0.4),
                                      width: 0.5),
                                ),
                                child: Text(
                                  m.monsterType.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: typeColor,
                                      letterSpacing: 0.8),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      // Close button
                      GestureDetector(
                        onTap: _dismissPanel,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF3A3A3A), width: 0.5),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Color(0xFF9E9E9E), size: 16),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Container(
                    height: 0.5,
                    color: const Color(0xFF2C2C2C),
                  ),
                  const SizedBox(height: 14),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                          child: _statCell(
                              Icons.radar,
                              '${m.spawnRadiusMeters.toStringAsFixed(0)}m',
                              'Spawn Radius',
                              typeColor)),
                      Container(width: 0.5, height: 44,
                          color: const Color(0xFF2C2C2C)),
                      Expanded(
                          child: _statCell(
                              Icons.location_on_outlined,
                              m.spawnLatitude.toStringAsFixed(4),
                              'Latitude',
                              const Color(0xFF9E9E9E))),
                      Container(width: 0.5, height: 44,
                          color: const Color(0xFF2C2C2C)),
                      Expanded(
                          child: _statCell(
                              Icons.location_on_outlined,
                              m.spawnLongitude.toStringAsFixed(4),
                              'Longitude',
                              const Color(0xFF9E9E9E))),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Center on this monster button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _centerOnMonster(m),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: typeColor.withValues(alpha: 0.15),
                        foregroundColor: typeColor,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        side: BorderSide(
                            color: typeColor.withValues(alpha: 0.3),
                            width: 0.5),
                      ),
                      icon: const Icon(Icons.center_focus_strong_rounded,
                          size: 18),
                      label: const Text('Center on Spawn',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelAvatar(Monster m, Color color) {
    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          m.monsterName.isNotEmpty ? m.monsterName[0].toUpperCase() : '?',
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _statCell(
      IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Color(0xFF757575))),
      ],
    );
  }

  // ─── Fit all monsters in view ──────────────────────────────
  void _fitAllMonsters() {
    if (_monsters.isEmpty) return;

    if (_monsters.length == 1) {
      _mapController.move(
        LatLng(_monsters[0].spawnLatitude, _monsters[0].spawnLongitude),
        15,
      );
      return;
    }

    double minLat = _monsters.map((m) => m.spawnLatitude).reduce(
        (a, b) => a < b ? a : b);
    double maxLat = _monsters.map((m) => m.spawnLatitude).reduce(
        (a, b) => a > b ? a : b);
    double minLng = _monsters.map((m) => m.spawnLongitude).reduce(
        (a, b) => a < b ? a : b);
    double maxLng = _monsters.map((m) => m.spawnLongitude).reduce(
        (a, b) => a > b ? a : b);

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Rough zoom estimation based on bounding box size
    final latDelta = maxLat - minLat;
    final lngDelta = maxLng - minLng;
    final maxDelta = latDelta > lngDelta ? latDelta : lngDelta;

    double zoom = 15.0;
    if (maxDelta > 1.0)       zoom = 8.0;
    else if (maxDelta > 0.5)  zoom = 9.0;
    else if (maxDelta > 0.1)  zoom = 11.0;
    else if (maxDelta > 0.05) zoom = 12.0;
    else if (maxDelta > 0.02) zoom = 13.0;
    else if (maxDelta > 0.01) zoom = 14.0;
    else                      zoom = 15.0;

    _mapController.move(LatLng(centerLat, centerLng), zoom);
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

// ─── Map FAB Button ────────────────────────────────────────
class _MapFab extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _MapFab({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2C2C2C), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}