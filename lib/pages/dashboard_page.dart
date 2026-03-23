import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';
import 'add_monster_page.dart';
import 'edit_monster_page.dart';
import 'edit_monsters_page.dart';
import 'delete_monster_page.dart';
import 'display_rankings_page.dart';
import 'map_page.dart';
import 'catch_monster_page.dart';
import 'players_list_page.dart';
import 'login_page.dart';

// ─── Design tokens ─────────────────────────────────────────
const _bg         = Color(0xFF0D0D14);
const _surface    = Color(0xFF12121A);
const _elevated   = Color(0xFF1A1A26);
const _border     = Color(0xFF252535);
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
class DashboardPage extends StatefulWidget {
  final int?    playerId;
  final String? playerName;
  const DashboardPage({super.key, this.playerId, this.playerName});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────
  List<Monster> _allMonsters      = [];
  List<Monster> _filteredMonsters = [];
  bool          _isLoading        = true;
  String        _searchQuery      = '';
  String        _selectedType     = 'All';
  int           _navIndex         = 0;

  final _searchCtrl  = TextEditingController();
  final _scrollCtrl  = ScrollController();

  // ── Animations ────────────────────────────────────────────
  late AnimationController _headerAnim;
  late AnimationController _listAnim;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;

  static const _types = [
    'All','Fire','Water','Grass','Electric',
    'Psychic','Ice','Rock','Ghost','Dragon',
  ];

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _listAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
            begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _headerAnim, curve: Curves.easeOutCubic));
    _loadData();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _listAnim.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final monsters = await ApiService.getMonsters();
      if (!mounted) return;
      setState(() {
        _allMonsters      = monsters;
        _filteredMonsters = monsters;
        _isLoading        = false;
      });
      _headerAnim.forward(from: 0);
      _listAnim.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Failed to load: $e', _accentRed);
    }
  }

  void _applyFilters() {
    var result = List<Monster>.from(_allMonsters);
    if (_selectedType != 'All') {
      result = result
          .where((m) => m.monsterType.toLowerCase() == _selectedType.toLowerCase())
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((m) =>
              m.monsterName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              m.monsterType.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    setState(() => _filteredMonsters = result);
  }

  // ── Computed ──────────────────────────────────────────────
  int get _available =>
      _allMonsters.where((m) => !m.monsterName.endsWith('(Captured)')).length;
  int get _captured =>
      _allMonsters.where((m) => m.monsterName.endsWith('(Captured)')).length;

  // ── Actions ───────────────────────────────────────────────
  Future<void> _push(Widget page) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
    _loadData();
    if (mounted) setState(() => _navIndex = 0);
  }

  void _onNavTap(int i) {
    if (i == 0) return;
    setState(() => _navIndex = i);
    switch (i) {
      case 1: _push(CatchMonsterPage(playerId: widget.playerId)); break;
      case 2: _push(const MapPage()); break;
      case 3: _push(const MonsterListPage()); break;
    }
  }

  Future<void> _deleteMonster(Monster m) async {
    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (_, a, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: a, child: child),
      ),
      pageBuilder: (_, __, ___) => AlertDialog(
        backgroundColor: _elevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFE24B4A), size: 20),
          SizedBox(width: 10),
          Text('Delete Monster',
              style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: _textSecondary, fontSize: 13, height: 1.5),
            children: [
              const TextSpan(text: 'Remove '),
              TextSpan(
                  text: m.monsterName,
                  style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
              const TextSpan(text: ' from the registry permanently?'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE24B4A),
              minimumSize: const Size(84, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiService.deleteMonster(monsterId: m.monsterId);
      if (!mounted) return;
      _snack(
        res['success'] == true ? '${m.monsterName} removed.' : res['message']?.toString() ?? 'Failed',
        res['success'] == true ? _accentGreen : _accentRed,
      );
      if (res['success'] == true) _loadData();
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e', _accentRed);
    }
  }

  void _logout() => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (r) => false,
      );

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(children: [
          // ── Partial hex grid — header area only, fades out ──
          Positioned(
            top: 0, left: 0, right: 0,
            height: 260,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.transparent],
                stops: [0.45, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: CustomPaint(painter: _HexGridPainter()),
            ),
          ),
          // ── Main content ─────────────────────────────────────
          RefreshIndicator(
          color: _accentRed,
          backgroundColor: _elevated,
          onRefresh: _loadData,
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeader(),
              _buildStatsStrip(),
              _buildHeroActions(),
              _buildSearchAndFilter(),
              _buildRegistryLabel(),
              _buildMonsterList(),
            ],
          ),
        ),
        ]),
        floatingActionButton: _buildFAB(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    final name    = widget.playerName ?? 'Hunter';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'H';

    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _headerFade,
        child: SlideTransition(
          position: _headerSlide,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 18, 20, 16),
            color: _bg,
            child: Row(children: [
              // Avatar — circular with person icon + glow
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentRed.withValues(alpha: 0.12),
                  border: Border.all(
                    color: _accentRed.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentRed.withValues(alpha: 0.22),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _accentRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WELCOME BACK',
                        style: TextStyle(
                            color: _textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4)),
                    const SizedBox(height: 2),
                    Text(name,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4)),
                  ],
                ),
              ),
              // Admin controls button
              _IconBtn(
                icon: Icons.tune_rounded,
                onTap: _showAdminSheet,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Stats strip ───────────────────────────────────────────
  Widget _buildStatsStrip() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _headerFade,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border, width: 0.5),
            ),
            child: Row(children: [
              // Total — neutral blue
              _StatCell(
                value: '${_allMonsters.length}',
                label: 'TOTAL',
                color: _accentBlue,
              ),
              _verticalDivider(),
              // Available — green
              _StatCell(
                value: '$_available',
                label: 'AVAILABLE',
                color: _accentGreen,
              ),
              _verticalDivider(),
              // Captured — red
              _StatCell(
                value: '$_captured',
                label: 'CAPTURED',
                color: _accentRed,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _verticalDivider() =>
      Container(width: 0.5, height: 32, color: _border);

  // ── Hero actions ──────────────────────────────────────────
  Widget _buildHeroActions() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _headerFade,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(children: [
            Expanded(
              child: _HeroCard(
                icon: Icons.catching_pokemon,
                title: 'Catch',
                sub: 'Hunt nearby monsters',
                color: _accentGreen,
                onTap: () => _push(CatchMonsterPage(playerId: widget.playerId)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HeroCard(
                icon: Icons.map_outlined,
                title: 'Map',
                sub: 'View spawn locations',
                color: _accentBlue,
                onTap: () => _push(const MapPage()),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Search + filter ───────────────────────────────────────
  Widget _buildSearchAndFilter() {
    return SliverToBoxAdapter(
      child: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border, width: 0.5),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: _textPrimary, fontSize: 13),
              onChanged: (v) { _searchQuery = v; _applyFilters(); },
              decoration: InputDecoration(
                hintText: 'Search monsters...',
                hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: _textMuted, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: _textMuted, size: 16),
                        onPressed: () { _searchCtrl.clear(); _searchQuery = ''; _applyFilters(); },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
          ),
        ),
        // Type filter chips
        SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 12),
            itemCount: _types.length,
            itemBuilder: (_, i) {
              final t      = _types[i];
              final active = _selectedType == t;
              final color  = _typeColor(t);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedType = t);
                    _applyFilters();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? color.withValues(alpha: 0.16) : _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? color.withValues(alpha: 0.5) : _border,
                        width: active ? 1.0 : 0.5,
                      ),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? color : _textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Registry label ────────────────────────────────────────
  Widget _buildRegistryLabel() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(children: [
          const Text('MONSTER REGISTRY',
              style: TextStyle(
                  color: _textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: _border, thickness: 0.5)),
          const SizedBox(width: 10),
          if (!_isLoading)
            Text('${_filteredMonsters.length}',
                style: const TextStyle(
                    color: _textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ── Monster list ──────────────────────────────────────────
  Widget _buildMonsterList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: _accentRed)),
      );
    }
    if (_filteredMonsters.isEmpty) {
      return SliverFillRemaining(child: _emptyState());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _RPGMonsterCard(
            monster:    _filteredMonsters[i],
            index:      i,
            parentAnim: _listAnim,
            onEdit:     () => _push(EditMonsterPage(monster: _filteredMonsters[i])),
            onDelete:   () => _deleteMonster(_filteredMonsters[i]),
          ),
          childCount: _filteredMonsters.length,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _accentRed.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.search_off_rounded, size: 30, color: _border),
        ),
        const SizedBox(height: 16),
        Text(
          _searchQuery.isNotEmpty
              ? 'No results for "$_searchQuery"'
              : 'No monsters yet',
          style: const TextStyle(color: _textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _push(const AddMonsterPage()),
          icon: const Icon(Icons.add, size: 15),
          label: const Text('Add first monster'),
          style: TextButton.styleFrom(foregroundColor: _accentRed),
        ),
      ]),
    );
  }

  // ── FAB ───────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () => _push(const AddMonsterPage()),
      backgroundColor: _accentRed,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.add, size: 22),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────
  Widget _buildBottomNav() {
    return ClipRect(
      child: Stack(children: [
        // Hex grid background
        Positioned.fill(
          child: CustomPaint(painter: _HexGridPainter()),
        ),
        // Nav content over grid
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D14).withValues(alpha: 0.92),
            border: const Border(
              top: BorderSide(color: Color(0xFF2E2B4A), width: 1.0),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                _NavItem(icon: Icons.home_rounded,        label: 'Home',  index: 0, current: _navIndex, onTap: _onNavTap),
                _NavItem(icon: Icons.catching_pokemon,    label: 'Catch', index: 1, current: _navIndex, onTap: _onNavTap),
                _NavItem(icon: Icons.map_outlined,        label: 'Map',   index: 2, current: _navIndex, onTap: _onNavTap),
                _NavItem(icon: Icons.leaderboard_rounded, label: 'Ranks', index: 3, current: _navIndex, onTap: _onNavTap),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Admin bottom sheet ────────────────────────────────────
  void _showAdminSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _border, width: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: _border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            // Section label
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('ADMIN CONTROLS',
                  style: TextStyle(
                      color: _textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
            ),
            _SheetItem(icon: Icons.add_circle_outline,  label: 'Add Monster',     color: _accentGreen,             onTap: () { Navigator.pop(context); _push(const AddMonsterPage()); }),
            _SheetItem(icon: Icons.edit_outlined,       label: 'Edit Monsters',   color: _accentBlue,              onTap: () { Navigator.pop(context); _push(const EditMonstersPage()); }),
            _SheetItem(icon: Icons.delete_outline,      label: 'Delete Monsters', color: const Color(0xFFE24B4A),  onTap: () { Navigator.pop(context); _push(const DeleteMonsterPage()); }),
            _SheetItem(icon: Icons.group_outlined,      label: 'Manage Players',  color: const Color(0xFF7F77DD),  onTap: () { Navigator.pop(context); _push(const PlayersListPage()); }),
            const SizedBox(height: 4),
            const Divider(color: _border, thickness: 0.5),
            _SheetItem(icon: Icons.logout_rounded,      label: 'Log Out',         color: const Color(0xFFE24B4A),  onTap: () { Navigator.pop(context); _logout(); }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HERO ACTION CARD
// ─────────────────────────────────────────────────────────────
class _HeroCard extends StatefulWidget {
  final IconData  icon;
  final String    title;
  final String    sub;
  final Color     color;
  final VoidCallback onTap;

  const _HeroCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:  (_) => setState(() => _pressed = true),
      onTapUp:    (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale:    _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withValues(alpha: 0.22), width: 1),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 21),
            ),
            const SizedBox(height: 14),
            Text(widget.title,
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(widget.sub,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 10,
                    height: 1.4)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RPG MONSTER CARD
// ─────────────────────────────────────────────────────────────
class _RPGMonsterCard extends StatefulWidget {
  final Monster            monster;
  final int                index;
  final AnimationController parentAnim;
  final VoidCallback?      onEdit;
  final VoidCallback?      onDelete;

  const _RPGMonsterCard({
    required this.monster,
    required this.index,
    required this.parentAnim,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_RPGMonsterCard> createState() => _RPGMonsterCardState();
}

class _RPGMonsterCardState extends State<_RPGMonsterCard> {
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final delay    = (widget.index * 0.055).clamp(0.0, 0.55);
    final end      = (delay + 0.40).clamp(0.0, 1.0);
    final interval = Interval(delay, end, curve: Curves.easeOutCubic);
    _fade  = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: widget.parentAnim, curve: interval));
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: widget.parentAnim, curve: interval));
  }

  @override
  Widget build(BuildContext context) {
    final m          = widget.monster;
    final color      = _typeColor(m.monsterType);
    final isCaptured = m.monsterName.endsWith('(Captured)');

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCaptured
                  ? _accentGreen.withValues(alpha: 0.18)
                  : color.withValues(alpha: 0.14),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(children: [
                // ── Colored left accent bar ──
                Container(
                  width: 3,
                  color: isCaptured ? _accentGreen : color,
                ),
                // ── Card body ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Row(children: [
                      // Avatar
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: color.withValues(alpha: 0.18), width: 0.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: m.pictureUrl != null && m.pictureUrl!.isNotEmpty
                              ? Image.network(m.pictureUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _avatarFallback(m.monsterName, color))
                              : _avatarFallback(m.monsterName, color),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Name row
                            Row(children: [
                              Expanded(
                                child: Text(
                                  m.monsterName,
                                  style: TextStyle(
                                    color: isCaptured ? _textSecondary : _textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    decoration: isCaptured
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: _textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCaptured) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _accentGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('CAUGHT',
                                      style: TextStyle(
                                          color: _accentGreen,
                                          fontSize: 7,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6)),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 5),
                            // Type + radius
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(m.monsterType.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                        letterSpacing: 0.8)),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.radar,
                                  size: 11,
                                  color: Colors.white.withValues(alpha: 0.18)),
                              const SizedBox(width: 3),
                              Text(
                                '${m.spawnRadiusMeters.toStringAsFixed(0)}m',
                                style: const TextStyle(
                                    color: _textSecondary, fontSize: 11),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action buttons
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.onEdit != null)
                            _CardBtn(
                                icon: Icons.edit_outlined,
                                color: _accentBlue,
                                onTap: widget.onEdit!),
                          if (widget.onDelete != null) ...[
                            const SizedBox(height: 6),
                            _CardBtn(
                                icon: Icons.delete_outline,
                                color: const Color(0xFFE24B4A),
                                onTap: widget.onDelete!),
                          ],
                        ],
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(String name, Color color) => Container(
        color: color.withValues(alpha: 0.07),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _StatCell({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          // Icon badge with glow
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.20),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              label == 'TOTAL'
                  ? Icons.pets_rounded
                  : label == 'AVAILABLE'
                      ? Icons.location_on_rounded
                      : Icons.catching_pokemon_rounded,
              color: color,
              size: 15,
            ),
          ),
          const SizedBox(height: 7),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: _textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
        ]),
      );
}

class _CardBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _CardBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.18), width: 0.5),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border, width: 0.5),
          ),
          child: Icon(icon, color: _textSecondary, size: 18),
        ),
      );
}

class _NavItem extends StatelessWidget {
  final IconData       icon;
  final String         label;
  final int            index;
  final int            current;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: selected
                  ? _accentRed.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                size: 22,
                color: selected ? _accentRed : _textMuted),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? _accentRed : _textMuted)),
        ]),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _SheetItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(label,
            style: const TextStyle(
                color: _textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        onTap: onTap,
        minLeadingWidth: 36,
      );
}

// ─────────────────────────────────────────────────────────────
// Hex grid painter — shared with login/register pages
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