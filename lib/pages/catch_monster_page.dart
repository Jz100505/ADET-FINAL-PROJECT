import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:torch_light/torch_light.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';

// ─── Tokens ───────────────────────────────────────────────────
const _bg       = Color(0xFF0D0D14);
const _surface  = Color(0xFF16151F);
const _elevated = Color(0xFF1E1D2C);
const _border   = Color(0xFF252535);
const _txtPri   = Colors.white;
const _txtSec   = Color(0xFF8A8A9A);
const _txtMute  = Color(0xFF4A4A5A);
const _red      = Color(0xFFE53935);
const _green    = Color(0xFF1D9E75);
const _blue     = Color(0xFF378ADD);

Color _tc(String t) {
  switch (t.toLowerCase()) {
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

class _NM {
  final Monster m;
  double dist;
  _NM(this.m, this.dist);
}

// ─────────────────────────────────────────────────────────────
class CatchMonsterPage extends StatefulWidget {
  final int? playerId;
  const CatchMonsterPage({super.key, this.playerId});
  @override
  State<CatchMonsterPage> createState() => _CatchState();
}

class _CatchState extends State<CatchMonsterPage> with TickerProviderStateMixin {
  double? _lat, _lng;
  bool _locating = false, _scanning = false, _catching = false,
       _hasTorch = false, _scanned = false;
  List<Monster> _all  = [];
  List<_NM>     _near = [];
  final Map<int, double> _burst = {};
  Monster? _selected;
  double _mapFrac = 0.42;

  final _mapCtrl  = MapController();
  final _listCtrl = ScrollController();
  final _audio    = AudioPlayer();
  StreamSubscription<Position>? _gps;
  final _distCalc = const Distance();

  late AnimationController _sweep, _pulse, _idle, _hdrFade, _listIn;
  late Animation<double>   _sweepA, _pulseA, _idleA, _hdrA;

  @override
  void initState() {
    super.initState();
    _sweep   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _pulse   = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _idle    = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _hdrFade = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _listIn  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _sweepA = Tween<double>(begin: 0, end: math.pi * 2)
        .animate(CurvedAnimation(parent: _sweep, curve: Curves.linear));
    _pulseA = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _idleA  = Tween<double>(begin: 0.25, end: 0.55)
        .animate(CurvedAnimation(parent: _idle, curve: Curves.easeInOut));
    _hdrA   = CurvedAnimation(parent: _hdrFade, curve: Curves.easeOut);

    _checkTorch();
    _getGps();
  }

  @override
  void dispose() {
    _sweep.dispose(); _pulse.dispose(); _idle.dispose();
    _hdrFade.dispose(); _listIn.dispose();
    _gps?.cancel(); _mapCtrl.dispose(); _listCtrl.dispose(); _audio.dispose();
    super.dispose();
  }

  // ── GPS ──────────────────────────────────────────────────────
  Future<void> _checkTorch() async {
    try {
      final v = await TorchLight.isTorchAvailable();
      if (mounted) setState(() => _hasTorch = v);
    } catch (_) {}
  }

  Future<void> _getGps() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Location services disabled', _red);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack('Location permission denied', _red);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() { _lat = pos.latitude; _lng = pos.longitude; });
      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 15.5);
      _startGpsStream();
    } catch (e) {
      if (mounted) _snack('GPS error: $e', _red);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _startGpsStream() {
    _gps?.cancel();
    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        for (final n in _near) {
          n.dist = _distCalc.as(LengthUnit.Meter,
              LatLng(_lat!, _lng!), LatLng(n.m.spawnLatitude, n.m.spawnLongitude));
        }
        _near.sort((a, b) => a.dist.compareTo(b.dist));
      });
    });
  }

  // ── Scan ──────────────────────────────────────────────────────
  Future<void> _scan() async {
    if (_scanning) return;
    if (_lat == null) { await _getGps(); return; }
    HapticFeedback.mediumImpact();
    setState(() { _scanning = true; _near = []; _scanned = false; _selected = null; });
    _sweep.repeat(); _listIn.reset();
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() { _lat = pos.latitude; _lng = pos.longitude; });
      _all = await ApiService.getMonsters();
      if (!mounted) return;
      final found = <_NM>[];
      for (final m in _all) {
        if (m.monsterName.endsWith('(Captured)') || m.spawnRadiusMeters <= 0) continue;
        final d = _distCalc.as(LengthUnit.Meter,
            LatLng(_lat!, _lng!), LatLng(m.spawnLatitude, m.spawnLongitude));
        if (d <= m.spawnRadiusMeters) found.add(_NM(m, d));
      }
      found.sort((a, b) => a.dist.compareTo(b.dist));
      setState(() { _near = found; _scanned = true; });
      if (found.isNotEmpty) {
        HapticFeedback.heavyImpact();
        _alarm();
        _listIn.forward(from: 0);
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) _snack('Scan failed: $e', _red);
    } finally {
      if (mounted) {
        _sweep.stop(); _sweep.reset();
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _alarm() async {
    try { await _audio.play(AssetSource('sounds/monster_alarm.mp3')); } catch (_) {}
    if (!_hasTorch) return;
    int f = 0;
    Timer.periodic(const Duration(milliseconds: 400), (t) async {
      if (f >= 8 || !mounted) {
        t.cancel();
        try { await TorchLight.disableTorch(); } catch (_) {}
        return;
      }
      try {
        f.isEven ? await TorchLight.enableTorch() : await TorchLight.disableTorch();
      } catch (_) {}
      f++;
    });
  }

  // ── Catch ──────────────────────────────────────────────────────
  Future<void> _catch(Monster m) async {
    if (_catching || m.monsterName.endsWith('(Captured)')) return;
    setState(() => _catching = true);
    HapticFeedback.lightImpact();
    try {
      final res = await ApiService.updateMonster(
        monsterId: m.monsterId,
        monsterName: '${m.monsterName} (Captured)',
        monsterType: m.monsterType,
        spawnLatitude: m.spawnLatitude,
        spawnLongitude: m.spawnLongitude,
        spawnRadiusMeters: 0,
        pictureUrl: m.pictureUrl,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        HapticFeedback.heavyImpact();
        if (widget.playerId != null) {
          await LocalDbService.instance.recordCatch(
            playerId: widget.playerId!, monsterId: m.monsterId,
            monsterName: m.monsterName, monsterType: m.monsterType,
          );
        }
        _startBurst(m.monsterId);
        setState(() {
          _near.removeWhere((n) => n.m.monsterId == m.monsterId);
          _selected = null;
        });
        await showModalBottomSheet(
          context: context, backgroundColor: Colors.transparent,
          builder: (_) => _CaptureSheet(monster: m),
        );
      } else {
        _snack(res['message']?.toString() ?? 'Failed', _red);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', _red);
    } finally {
      if (mounted) setState(() => _catching = false);
    }
  }

  void _startBurst(int id) {
    setState(() => _burst[id] = 0.0);
    int step = 0;
    Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted || step >= 20) {
        t.cancel();
        if (mounted) setState(() {
          _burst.remove(id);
          _all.removeWhere((m) => m.monsterId == id);
        });
        return;
      }
      step++;
      if (mounted) setState(() => _burst[id] = step / 20);
    });
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _HexPainter())),
          Column(children: [
            _buildHeader(),
            Expanded(child: _SplitPanel(
              frac: _mapFrac,
              onFracChanged: (f) => setState(() => _mapFrac = f),
              top: _buildMap(),
              bottom: _buildList(),
            )),
          ]),
          _buildRadarFAB(),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    final topPad = MediaQuery.of(context).padding.top;
    return FadeTransition(
      opacity: _hdrA,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, topPad + 10, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_bg.withValues(alpha: 0.97), _bg.withValues(alpha: 0.85)]),
          border: Border(bottom: BorderSide(color: _border, width: 0.5)),
        ),
        child: Row(children: [
          _iconBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('HUNT MODE', style: TextStyle(color: _red, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
              Text('Catch Monsters', style: TextStyle(color: _txtPri, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          )),
          if (_scanned) ...[
            _pill('${_near.length} IN RANGE', _near.isEmpty ? _txtMute : _green, Icons.radar_rounded),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: _locating ? null : _getGps,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _surface.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _lat != null ? _blue.withValues(alpha: 0.4) : _border, width: 0.5)),
              child: _locating
                  ? const Padding(padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(color: _blue, strokeWidth: 2))
                  : Icon(
                      _lat != null ? Icons.my_location_rounded : Icons.location_searching_rounded,
                      color: _lat != null ? _blue : _txtMute, size: 17),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────
  Widget _buildMap() {
    final nearIds = _near.map((n) => n.m.monsterId).toSet();
    return AnimatedBuilder(
      animation: _pulseA,
      builder: (_, __) => FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(
          initialCenter: LatLng(_lat ?? 15.1449, _lng ?? 120.5887),
          initialZoom: 15.5,
          onTap: (_, __) => setState(() => _selected = null),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.haumonsters',
          ),
          // Spawn circles — only in-range + selected
          if (_all.isNotEmpty) CircleLayer(
            circles: _all.where((m) =>
              nearIds.contains(m.monsterId) || _selected?.monsterId == m.monsterId
            ).map((m) {
              final sel = _selected?.monsterId == m.monsterId;
              final c   = _tc(m.monsterType);
              return CircleMarker(
                point: LatLng(m.spawnLatitude, m.spawnLongitude),
                radius: m.spawnRadiusMeters > 0 ? m.spawnRadiusMeters : 30,
                useRadiusInMeter: true,
                color: c.withValues(alpha: sel ? 0.18 : 0.09),
                borderStrokeWidth: sel ? 2.0 : 1.0,
                borderColor: c.withValues(alpha: sel ? 0.7 : 0.4),
              );
            }).toList(),
          ),
          // GPS accuracy ring
          if (_lat != null) CircleLayer(circles: [
            CircleMarker(
              point: LatLng(_lat!, _lng!), radius: 18, useRadiusInMeter: true,
              color: _blue.withValues(alpha: 0.07 * _pulseA.value),
              borderStrokeWidth: 1.0,
              borderColor: _blue.withValues(alpha: 0.20 * _pulseA.value),
            ),
          ]),
          MarkerLayer(markers: [
            // User dot
            if (_lat != null) Marker(
              point: LatLng(_lat!, _lng!), width: 40, height: 40,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 40 * _pulseA.value, height: 40 * _pulseA.value,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(
                    color: _blue.withValues(alpha: 0.4 * (1 - _pulseA.value + 0.3)), width: 1.5)),
                ),
                Container(width: 14, height: 14, decoration: BoxDecoration(
                  color: _blue, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)],
                )),
              ]),
            ),
            // Monster markers
            ..._all.map((m) {
              final cap = m.monsterName.endsWith('(Captured)');
              final inR = nearIds.contains(m.monsterId);
              final sel = _selected?.monsterId == m.monsterId;
              final c   = cap ? _txtMute : _tc(m.monsterType);
              final sz  = sel ? 52.0 : inR ? 44.0 : 36.0;
              final bv  = _burst[m.monsterId];
              if (bv != null) {
                return Marker(
                  point: LatLng(m.spawnLatitude, m.spawnLongitude), width: 80, height: 80,
                  child: CustomPaint(painter: _BurstPainter(bv, c)),
                );
              }
              return Marker(
                point: LatLng(m.spawnLatitude, m.spawnLongitude), width: sz, height: sz,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selected = m);
                    _showDetail(m);
                  },
                  child: Stack(alignment: Alignment.center, children: [
                    if (inR && !cap) Container(
                      width: sz * _pulseA.value, height: sz * _pulseA.value,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(
                        color: c.withValues(alpha: 0.45 * (1 - _pulseA.value + 0.3)), width: 2)),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200), curve: Curves.easeOutBack,
                      width: sel ? 46 : inR ? 38 : 30, height: sel ? 46 : inR ? 38 : 30,
                      decoration: BoxDecoration(
                        color: cap ? _surface : inR ? c : c.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: cap ? _border : Colors.white, width: sel ? 2.5 : 1.8),
                        boxShadow: [BoxShadow(
                          color: c.withValues(alpha: cap ? 0.08 : inR ? 0.50 : 0.20),
                          blurRadius: sel ? 20 : inR ? 12 : 6, spreadRadius: sel ? 3 : 0)],
                      ),
                      child: Center(child: cap
                          ? Icon(Icons.check_rounded, color: _txtMute, size: sel ? 18 : 14)
                          : Text(m.monsterName.isNotEmpty ? m.monsterName[0].toUpperCase() : '?',
                              style: TextStyle(color: Colors.white,
                                  fontSize: sel ? 18 : inR ? 14 : 11, fontWeight: FontWeight.w900))),
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

  // ── Monster list ───────────────────────────────────────────────
  Widget _buildList() {
    return Container(
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: _border, width: 0.5)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 6, bottom: 4), width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(children: [
            if (_scanning) ...[
              const SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(color: _red, strokeWidth: 2)),
              const SizedBox(width: 8),
              const Text('SCANNING…', style: TextStyle(
                  color: _red, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ] else if (!_scanned) ...[
              const Icon(Icons.radar_rounded, color: _txtMute, size: 13),
              const SizedBox(width: 6),
              const Text('TAP RADAR TO SCAN', style: TextStyle(
                  color: _txtMute, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
            ] else ...[
              AnimatedBuilder(animation: _pulseA, builder: (_, __) => Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _near.isEmpty ? _txtMute : _green.withValues(alpha: _pulseA.value),
                  boxShadow: _near.isEmpty ? [] : [BoxShadow(
                    color: _green.withValues(alpha: _pulseA.value * 0.5), blurRadius: 5, spreadRadius: 1)],
                ),
              )),
              const SizedBox(width: 8),
              Text(
                _near.isEmpty ? 'NO MONSTERS NEARBY'
                    : '${_near.length} MONSTER${_near.length == 1 ? '' : 'S'} IN RANGE',
                style: TextStyle(
                    color: _near.isEmpty ? _txtMute : _green,
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
            ],
            const Spacer(),
            if (_all.isNotEmpty)
              Text('${_all.length} on map', style: const TextStyle(color: _txtMute, fontSize: 10)),
          ]),
        ),
        Expanded(child: _scanning
            ? const Center(child: CircularProgressIndicator(color: _red, strokeWidth: 2))
            : !_scanned
                ? _hint(Icons.radar_rounded, _red, 'Tap the radar to scan your area')
                : _near.isEmpty
                    ? _hint(Icons.search_off_rounded, _txtMute, 'No monsters in range\nMove closer and scan again')
                    : ListView.builder(
                        controller: _listCtrl,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                        itemCount: _near.length,
                        itemBuilder: (_, i) {
                          final d = (i * 0.09).clamp(0.0, 0.55);
                          final e = (d + 0.42).clamp(0.0, 1.0);
                          final iv = Interval(d, e, curve: Curves.easeOutCubic);
                          return FadeTransition(
                            opacity: Tween<double>(begin: 0, end: 1)
                                .animate(CurvedAnimation(parent: _listIn, curve: iv)),
                            child: SlideTransition(
                              position: Tween<Offset>(
                                  begin: const Offset(0, 0.18), end: Offset.zero)
                                  .animate(CurvedAnimation(parent: _listIn, curve: iv)),
                              child: _NearbyCard(
                                nm: _near[i], catching: _catching,
                                onTap: () {
                                  _mapCtrl.move(LatLng(
                                    _near[i].m.spawnLatitude, _near[i].m.spawnLongitude), 16);
                                  setState(() => _selected = _near[i].m);
                                  _showDetail(_near[i].m);
                                },
                                onCatch: () => _catch(_near[i].m),
                              ),
                            ),
                          );
                        },
                      )),
      ]),
    );
  }

  // ── Radar FAB ──────────────────────────────────────────────────
  Widget _buildRadarFAB() => Positioned(
    bottom: 24, left: 0, right: 0,
    child: Center(child: _RadarFAB(
      sweep: _sweepA, pulse: _pulseA, idle: _idleA,
      scanning: _scanning, hasGps: _lat != null,
      scanned: _scanned, found: _near.length,
      onTap: (_scanning || _locating) ? null : _scan,
    )),
  );

  void _showDetail(Monster m) {
    final cap = m.monsterName.endsWith('(Captured)');
    final nm  = _near.cast<_NM?>()
        .firstWhere((n) => n?.m.monsterId == m.monsterId, orElse: () => null);
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _DetailSheet(
        monster: m, color: cap ? _txtMute : _tc(m.monsterType),
        dist: nm?.dist, inRange: nm != null && !cap, cap: cap,
        catching: _catching,
        onCatch: cap ? null : () { Navigator.pop(context); _catch(m); },
      ),
    );
  }

  // ── Small helpers ──────────────────────────────────────────────
  Widget _iconBtn(IconData icon, VoidCallback fn) => GestureDetector(
    onTap: fn,
    child: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: _surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border, width: 0.5)),
      child: Icon(icon, color: _txtSec, size: 16)),
  );

  Widget _pill(String label, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.5)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 10), const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
    ]),
  );

  Widget _hint(IconData icon, Color color, String msg) => Align(
    alignment: const Alignment(0, -0.45),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 52, height: 52,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.20), width: 0.5)),
          child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 12),
        Text(msg, style: const TextStyle(color: _txtSec, fontSize: 13), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// SPLIT PANEL
// ─────────────────────────────────────────────────────────────
class _SplitPanel extends StatefulWidget {
  final double frac;
  final ValueChanged<double> onFracChanged;
  final Widget top, bottom;
  const _SplitPanel({
    required this.frac, required this.onFracChanged,
    required this.top,  required this.bottom,
  });

  static const double _min = 0.15, _max = 0.82,
      _mSnap = 0.72, _lSnap = 0.22, _def = 0.42;

  @override
  State<_SplitPanel> createState() => _SplitPanelState();
}

class _SplitPanelState extends State<_SplitPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _from = 0, _to = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _ctrl.addListener(() {
      final t = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic).value;
      widget.onFracChanged(_from + (_to - _from) * t);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _snap(double t) {
    _from = widget.frac; _to = t;
    _ctrl.forward(from: 0);
    HapticFeedback.selectionClick();
  }

  void _onTap() {
    final f = widget.frac;
    if (f < 0.35)      _snap(_SplitPanel._def);
    else if (f < 0.60) _snap(_SplitPanel._mSnap);
    else               _snap(_SplitPanel._lSnap);
  }

  void _onDragEnd(DragEndDetails _) {
    final f = widget.frac;
    final opts = [_SplitPanel._def, _SplitPanel._mSnap, _SplitPanel._lSnap];
    _snap(opts.reduce((a, b) => (a - f).abs() < (b - f).abs() ? a : b));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final h = c.maxHeight;
      const divH = 28.0;
      final mapH = h * widget.frac;
      final lstH = (h * (1 - widget.frac) - divH).clamp(0.0, double.infinity);
      final mapBig = widget.frac >= 0.60;
      final lstBig = widget.frac <= 0.35;

      return Column(children: [
        SizedBox(height: mapH, child: widget.top),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onVerticalDragUpdate: (d) {
            // 1.8x amplifier — easier to drag without being hair-trigger
            final nf = (widget.frac + d.delta.dy / h * 1.8)
                .clamp(_SplitPanel._min, _SplitPanel._max);
            widget.onFracChanged(nf);
          },
          onVerticalDragEnd: _onDragEnd,
          child: SizedBox(height: divH, child: Stack(alignment: Alignment.center, children: [
            Positioned(left: 0, right: 0, top: divH / 2,
                child: Container(height: 0.5, color: _border)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: _elevated, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border, width: 0.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.keyboard_arrow_up_rounded, size: 16,
                    color: lstBig ? _blue : _txtMute),
                const SizedBox(width: 6),
                Text(
                  mapBig ? 'LIST  ↓' : lstBig ? 'MAP  ↑' : 'DRAG',
                  style: TextStyle(
                    color: mapBig || lstBig ? _blue : _txtMute,
                    fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.4),
                ),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                    color: mapBig ? _blue : _txtMute),
              ]),
            ),
          ])),
        ),
        SizedBox(height: lstH, child: widget.bottom),
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────
// RADAR FAB
// ─────────────────────────────────────────────────────────────
class _RadarFAB extends StatefulWidget {
  final Animation<double> sweep, pulse, idle;
  final bool scanning, hasGps, scanned;
  final int  found;
  final VoidCallback? onTap;
  const _RadarFAB({
    required this.sweep, required this.pulse, required this.idle,
    required this.scanning, required this.hasGps, required this.scanned,
    required this.found, this.onTap,
  });
  @override
  State<_RadarFAB> createState() => _RadarFABState();
}

class _RadarFABState extends State<_RadarFAB> {
  bool _pressed = false;

  Color get _ringCol => widget.scanning ? _red : widget.found > 0 ? _green
      : widget.hasGps ? _blue : _border;
  Color get _glowCol => widget.scanning ? _red : widget.found > 0 ? _green : _blue;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    return GestureDetector(
      onTapDown:   active ? (_) => setState(() => _pressed = true)  : null,
      onTapUp:     active ? (_) { setState(() => _pressed = false); widget.onTap!(); } : null,
      onTapCancel: active ?  () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0, duration: const Duration(milliseconds: 120),
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.sweep, widget.pulse, widget.idle]),
          builder: (_, __) => Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _elevated.withValues(alpha: 0.95),
              border: Border.all(color: _ringCol.withValues(alpha: 0.55), width: 1.5),
              boxShadow: [
                BoxShadow(color: _glowCol.withValues(alpha: widget.scanning ? 0.45 : 0.18),
                    blurRadius: widget.scanning ? 32 : 18, spreadRadius: widget.scanning ? 4 : 1),
                BoxShadow(color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 20, offset: const Offset(0, 6)),
              ],
            ),
            child: ClipOval(child: CustomPaint(
              painter: _RadarPainter(
                widget.sweep.value, widget.pulse.value, widget.idle.value,
                widget.scanning, widget.found, widget.scanned,
              ),
              child: Center(child: _center()),
            )),
          ),
        ),
      ),
    );
  }

  Widget _center() {
    if (widget.scanning) return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(color: _red, strokeWidth: 2.5)),
      const SizedBox(height: 5),
      const Text('SCAN', style: TextStyle(color: _red, fontSize: 8,
          fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    ]);
    if (widget.found > 0) return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${widget.found}', style: const TextStyle(color: _green, fontSize: 28,
          fontWeight: FontWeight.w900, letterSpacing: -1)),
      const Text('FOUND', style: TextStyle(color: _green, fontSize: 7,
          fontWeight: FontWeight.w900, letterSpacing: 1.8)),
    ]);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(widget.hasGps ? Icons.radar_rounded : Icons.location_off_rounded,
          color: widget.hasGps ? _txtSec : _txtMute, size: 24),
      const SizedBox(height: 3),
      Text(widget.hasGps ? 'SCAN' : 'NO GPS',
          style: TextStyle(color: widget.hasGps ? _txtSec : _txtMute,
              fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────────────────────
class _RadarPainter extends CustomPainter {
  final double sweep, pulse, idle;
  final bool   scanning, scanned;
  final int    found;
  const _RadarPainter(this.sweep, this.pulse, this.idle,
      this.scanning, this.found, this.scanned);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2;
    final Color ring = scanning ? _red : found > 0 ? _green : _txtMute;

    // Rings
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), r * i / 4, Paint()
        ..color = ring.withValues(alpha: scanning ? 0.12 + 0.08 * i / 4 : idle * i / 4 * 0.6)
        ..style = PaintingStyle.stroke ..strokeWidth = 0.5);
    }
    // Crosshairs
    final cp = Paint()..color = ring.withValues(alpha: 0.08)..strokeWidth = 0.5;
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), cp);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), cp);
    final d = r * 0.707;
    canvas.drawLine(Offset(cx - d, cy - d), Offset(cx + d, cy + d), cp);
    canvas.drawLine(Offset(cx + d, cy - d), Offset(cx - d, cy + d), cp);

    // Sweep beam
    if (scanning) {
      canvas.save();
      canvas.clipRect(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      const ts = 1.3;
      for (int i = 0; i < 70; i++) {
        final frac  = i / 70.0;
        final angle = sweep - ts * (1 - frac);
        final path  = ui.Path()
          ..moveTo(cx, cy)
          ..lineTo(cx + r * math.cos(angle), cy + r * math.sin(angle))
          ..lineTo(cx + r * math.cos(angle + ts / 70), cy + r * math.sin(angle + ts / 70))
          ..close();
        canvas.drawPath(path, Paint()
          ..color = _red.withValues(alpha: frac * frac * 0.25)
          ..style = PaintingStyle.fill);
      }
      canvas.restore();
      canvas.drawLine(Offset(cx, cy),
          Offset(cx + r * math.cos(sweep), cy + r * math.sin(sweep)),
          Paint()..color = _red.withValues(alpha: 0.85)..strokeWidth = 1.5
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
    // Pulse ring when found
    if (found > 0 && !scanning) {
      canvas.drawCircle(Offset(cx, cy), r * 0.88 * pulse, Paint()
        ..style = PaintingStyle.stroke ..strokeWidth = 1.8
        ..color = _green.withValues(alpha: 0.45 * pulse));
    }
    // Centre dot
    canvas.drawCircle(Offset(cx, cy), 3.5, Paint()..color = ring.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_RadarPainter o) =>
      o.sweep != sweep || o.pulse != pulse || o.idle != idle ||
      o.scanning != scanning || o.found != found;
}

class _BurstPainter extends CustomPainter {
  final double p;
  final Color  c;
  const _BurstPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2;
    // Expanding ring
    canvas.drawCircle(Offset(cx, cy), r * p, Paint()
      ..color = c.withValues(alpha: (1 - p) * 0.8)
      ..style = PaintingStyle.stroke ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Spokes
    for (int i = 0; i < 8; i++) {
      final a = i / 8 * 2 * math.pi;
      canvas.drawLine(
        Offset(cx + r * 0.08 * math.cos(a), cy + r * 0.08 * math.sin(a)),
        Offset(cx + r * (0.3 + p * 0.65) * math.cos(a), cy + r * (0.3 + p * 0.65) * math.sin(a)),
        Paint()..color = c.withValues(alpha: (1 - p) * 0.65)
            ..strokeWidth = 1.5 ..strokeCap = StrokeCap.round);
    }
    // Centre flash
    if (p < 0.35) {
      canvas.drawCircle(Offset(cx, cy), r * 0.28 * (1 - p), Paint()
        ..color = Colors.white.withValues(alpha: (1 - p / 0.35) * 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.p != p;
}

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C1A2E).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke ..strokeWidth = 0.6;
    const r = 28.0;
    final w = math.sqrt(3) * r, h = 2.0 * r;
    final cols = (size.width / w).ceil() + 2, rows = (size.height / (h * 0.75)).ceil() + 2;
    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final ox = (row % 2 == 0) ? 0.0 : w / 2;
        final path = ui.Path();
        for (int i = 0; i < 6; i++) {
          final a = math.pi / 180 * (60 * i - 30);
          final x = col * w + ox + r * math.cos(a), y = row * h * 0.75 + r * math.sin(a);
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }
  @override
  bool shouldRepaint(_HexPainter _) => false;
}

// ─────────────────────────────────────────────────────────────
// NEARBY CARD
// ─────────────────────────────────────────────────────────────
class _NearbyCard extends StatefulWidget {
  final _NM nm;
  final bool catching;
  final VoidCallback onTap, onCatch;
  const _NearbyCard({
    required this.nm, required this.catching,
    required this.onTap, required this.onCatch,
  });
  @override
  State<_NearbyCard> createState() => _NearbyCardState();
}

class _NearbyCardState extends State<_NearbyCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final m  = widget.nm.m;
    final c  = _tc(m.monsterType);
    final d  = widget.nm.dist;
    final mx = m.spawnRadiusMeters > 0 ? m.spawnRadiusMeters : 1;
    final pr = (1.0 - (d / mx).clamp(0.0, 1.0));
    final lbl = pr > 0.8 ? 'VERY CLOSE' : pr > 0.5 ? 'CLOSE' : pr > 0.25 ? 'NEARBY' : 'DISTANT';

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0, duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.18 + pr * 0.15), width: 0.5),
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.07 + pr * 0.06),
                blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(child: Row(children: [
              Container(width: 3, color: c),
              Expanded(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                // Avatar
                Container(width: 50, height: 50,
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.withValues(alpha: 0.20), width: 0.5)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: m.pictureUrl?.isNotEmpty == true
                        ? Image.network(m.pictureUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fb(m.monsterName, c))
                        : _fb(m.monsterName, c)),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(m.monsterName, style: const TextStyle(color: _txtPri,
                      fontSize: 14, fontWeight: FontWeight.w800),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    _badge(m.monsterType.toUpperCase(), c),
                    const SizedBox(width: 8),
                    Icon(Icons.near_me_rounded, size: 10, color: _txtMute),
                    const SizedBox(width: 3),
                    Text('${d.toStringAsFixed(0)}m',
                        style: const TextStyle(color: _txtSec, fontSize: 11)),
                  ]),
                  const SizedBox(height: 6),
                  // Proximity bar
                  Row(children: [
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
                      child: Stack(children: [
                        Container(height: 3, color: _border),
                        FractionallySizedBox(widthFactor: pr.clamp(0.05, 1.0),
                          child: Container(height: 3, decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [c.withValues(alpha: 0.5), c]),
                            borderRadius: BorderRadius.circular(3)))),
                      ]))),
                    const SizedBox(width: 7),
                    Text(lbl, style: TextStyle(color: c, fontSize: 7,
                        fontWeight: FontWeight.w900, letterSpacing: 0.7)),
                  ]),
                ])),
                const SizedBox(width: 10),
                _CatchBtn(color: c, catching: widget.catching, onTap: widget.onCatch),
              ]))),
            ])),
          ),
        ),
      ),
    );
  }

  Widget _fb(String name, Color c) => Container(
    color: c.withValues(alpha: 0.07),
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w900))));

  Widget _badge(String type, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(4)),
    child: Text(type, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
  );
}

// ─────────────────────────────────────────────────────────────
// DETAIL SHEET
// ─────────────────────────────────────────────────────────────
class _DetailSheet extends StatefulWidget {
  final Monster monster;
  final Color   color;
  final double? dist;
  final bool    inRange, cap, catching;
  final VoidCallback? onCatch;
  const _DetailSheet({
    required this.monster, required this.color, this.dist,
    required this.inRange, required this.cap,
    required this.catching, this.onCatch,
  });
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final m    = widget.monster;
    final c    = widget.color;
    final name = widget.cap ? m.monsterName.replaceAll(' (Captured)', '') : m.monsterName;

    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide,
      child: Container(
        decoration: BoxDecoration(
          color: _elevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: c.withValues(alpha: 0.25), width: 0.5),
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, -6)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(margin: const EdgeInsets.only(bottom: 14), width: 36, height: 4,
                  decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
              // Avatar + info row
              Row(children: [
                Container(width: 68, height: 68,
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.withValues(alpha: 0.25), width: 0.5)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(18),
                    child: m.pictureUrl?.isNotEmpty == true
                        ? Image.network(m.pictureUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fb(name, c))
                        : _fb(name, c)),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(color: widget.cap ? _txtSec : _txtPri,
                      fontSize: 18, fontWeight: FontWeight.w900,
                      decoration: widget.cap ? TextDecoration.lineThrough : null,
                      decorationColor: _txtMute)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    _badge(m.monsterType.toUpperCase(), c),
                    if (widget.cap)    _badge('CAPTURED', _green)
                    else if (widget.inRange) _badge('IN RANGE', _green)
                    else               _badge('OUT OF RANGE', _txtMute),
                  ]),
                  if (widget.dist != null) Padding(padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      const Icon(Icons.near_me_rounded, size: 11, color: _txtMute),
                      const SizedBox(width: 4),
                      Text('${widget.dist!.toStringAsFixed(0)}m away',
                          style: const TextStyle(color: _txtSec, fontSize: 12)),
                    ])),
                ])),
              ]),
              const SizedBox(height: 14),
              Container(height: 0.5, color: _border),
              const SizedBox(height: 12),
              // Stats row
              Row(children: [
                _stat('RADIUS', '${m.spawnRadiusMeters.toStringAsFixed(0)}m', c),
                Container(width: 0.5, height: 36, color: _border),
                _stat('LAT', m.spawnLatitude.toStringAsFixed(4), _txtSec),
                Container(width: 0.5, height: 36, color: _border),
                _stat('LNG', m.spawnLongitude.toStringAsFixed(4), _txtSec),
              ]),
              const SizedBox(height: 14),
              // Action
              if (!widget.cap && widget.onCatch != null)
                _actionBtn(c)
              else if (widget.cap)
                Container(width: double.infinity, height: 52,
                  decoration: BoxDecoration(color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border, width: 0.5)),
                  child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_rounded, color: _green, size: 16),
                    SizedBox(width: 8),
                    Text('Already Captured', style: TextStyle(color: _green,
                        fontSize: 14, fontWeight: FontWeight.w600)),
                  ]))),
            ]),
          ),
        ),
      ),
    ));
  }

  Widget _fb(String name, Color c) => Container(color: c.withValues(alpha: 0.07),
      child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(color: c, fontSize: 26, fontWeight: FontWeight.w900))));

  Widget _badge(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: 0.25), width: 0.5)),
    child: Text(label, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
  );

  Widget _stat(String lbl, String val, Color c) => Expanded(child: Column(children: [
    Text(val, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w700,
        fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
    const SizedBox(height: 2),
    Text(lbl, style: const TextStyle(color: _txtMute, fontSize: 8,
        fontWeight: FontWeight.w700, letterSpacing: 1.1)),
  ]));

  Widget _actionBtn(Color c) {
    final active = widget.inRange && !widget.catching;
    return GestureDetector(
      onTap: active ? widget.onCatch : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          gradient: active ? LinearGradient(
              colors: [c, Color.lerp(c, Colors.black, 0.25)!],
              begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: active ? null : _surface,
          borderRadius: BorderRadius.circular(14),
          border: active ? null : Border.all(color: _border, width: 0.5),
          boxShadow: active ? [BoxShadow(color: c.withValues(alpha: 0.30),
              blurRadius: 18, offset: const Offset(0, 5))] : [],
        ),
        child: Center(child: widget.catching
            ? const Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                SizedBox(width: 10),
                Text('Capturing…', style: TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w700)),
              ])
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.catching_pokemon, color: active ? Colors.white : _txtMute, size: 20),
                const SizedBox(width: 8),
                Text(widget.inRange ? 'Catch Monster' : 'Out of Range',
                    style: TextStyle(color: active ? Colors.white : _txtMute,
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ])),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CAPTURE SHEET
// ─────────────────────────────────────────────────────────────
class _CaptureSheet extends StatefulWidget {
  final Monster monster;
  const _CaptureSheet({required this.monster});
  @override
  State<_CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<_CaptureSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut)));
    _fade  = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));
    _ctrl.forward();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final m = widget.monster;
    final c = _tc(m.monsterType);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: BoxDecoration(color: _elevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _green.withValues(alpha: 0.3), width: 0.5))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 28),
        ScaleTransition(scale: _scale, child: Container(
          width: 78, height: 78,
          decoration: BoxDecoration(color: _green.withValues(alpha: 0.10), shape: BoxShape.circle,
            border: Border.all(color: _green.withValues(alpha: 0.4), width: 2),
            boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.20), blurRadius: 28, spreadRadius: 3)]),
          child: const Icon(Icons.catching_pokemon_rounded, color: _green, size: 38),
        )),
        const SizedBox(height: 20),
        FadeTransition(opacity: _fade, child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: _green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withValues(alpha: 0.25), width: 0.5)),
            child: const Text('MONSTER CAPTURED!', style: TextStyle(color: _green,
                fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
          const SizedBox(height: 14),
          Text(m.monsterName, style: const TextStyle(color: _txtPri, fontSize: 22,
              fontWeight: FontWeight.w900, letterSpacing: -0.3), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
            child: Text(m.monsterType.toUpperCase(), style: TextStyle(color: c, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.0))),
          const SizedBox(height: 8),
          const Text('Added to your collection.', style: TextStyle(color: _txtSec, fontSize: 13)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_green, Color(0xFF158A62)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.28),
                    blurRadius: 18, offset: const Offset(0, 5))]),
              child: const Center(child: Text('Awesome!', style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
            ),
          ),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CATCH BUTTON
// ─────────────────────────────────────────────────────────────
class _CatchBtn extends StatefulWidget {
  final Color color;
  final bool  catching;
  final VoidCallback onTap;
  const _CatchBtn({required this.color, required this.catching, required this.onTap});
  @override
  State<_CatchBtn> createState() => _CatchBtnState();
}

class _CatchBtnState extends State<_CatchBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return GestureDetector(
      onTapDown:   widget.catching ? null : (_) => setState(() => _p = true),
      onTapUp:     widget.catching ? null : (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: widget.catching ? null : ()  => setState(() => _p = false),
      child: AnimatedScale(scale: _p ? 0.88 : 1.0, duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(duration: const Duration(milliseconds: 180),
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: widget.catching ? _surface : c.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: widget.catching ? _border : c.withValues(alpha: 0.40),
                width: widget.catching ? 0.5 : 1.0),
            boxShadow: _p || widget.catching ? []
                : [BoxShadow(color: c.withValues(alpha: 0.20), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: widget.catching
              ? Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: c, strokeWidth: 2.5)))
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.catching_pokemon, color: c, size: 22),
                  const SizedBox(height: 2),
                  Text('CATCH', style: TextStyle(color: c, fontSize: 7,
                      fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ]),
        )),
    );
  }
}