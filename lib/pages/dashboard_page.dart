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

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {

  // ─── State ─────────────────────────────────────────────────
  List<Monster> _allMonsters      = [];
  List<Monster> _filteredMonsters = [];
  bool          _isLoading        = true;
  bool          _isSearching      = false;
  String        _searchQuery      = '';
  String        _selectedType     = 'All';

  final TextEditingController _searchCtrl  = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();

  // ─── Animations ────────────────────────────────────────────
  late AnimationController _headerAnim;
  late AnimationController _fabAnim;
  late AnimationController _listAnim;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;
  late Animation<double>   _fabScale;

  static const List<String> _types = [
    'All', 'Fire', 'Water', 'Grass', 'Electric',
    'Psychic', 'Ice', 'Rock', 'Ghost', 'Dragon',
  ];

  // ─── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
  }

  void _initAnimations() {
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _listAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _headerFade = CurvedAnimation(
        parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
        begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _headerAnim, curve: Curves.easeOutCubic));
    _fabScale = CurvedAnimation(
        parent: _fabAnim, curve: Curves.elasticOut);

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.offset > 80 && !_fabAnim.isCompleted) {
        _fabAnim.forward();
      } else if (_scrollCtrl.offset <= 80 && _fabAnim.isCompleted) {
        _fabAnim.reverse();
      }
    });
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _fabAnim.dispose();
    _listAnim.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Data ──────────────────────────────────────────────────
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
      _headerAnim.forward();
      _listAnim.forward();
      _fabAnim.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load monsters: $e', const Color(0xFFE24B4A));
    }
  }

  void _applyFilters() {
    List<Monster> result = List.from(_allMonsters);
    if (_selectedType != 'All') {
      result = result.where((m) =>
          m.monsterType.toLowerCase() == _selectedType.toLowerCase()).toList();
    }
    if (_searchQuery.isNotEmpty) {
      result = result.where((m) =>
          m.monsterName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.monsterType.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    setState(() => _filteredMonsters = result);
  }

  // ─── Delete ────────────────────────────────────────────────
  Future<void> _deleteMonster(Monster monster) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (_, __, ___) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE24B4A), size: 24),
            SizedBox(width: 10),
            Text('Delete Monster',
                style: TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                color: Color(0xFF9E9E9E), fontSize: 14, height: 1.5),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: monster.monsterName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
              const TextSpan(text: '? This cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE24B4A),
              minimumSize: const Size(80, 38),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result =
          await ApiService.deleteMonster(monsterId: monster.monsterId);
      if (!mounted) return;
      _showSnackBar(
        result['success'] == true
            ? '${monster.monsterName} deleted.'
            : result['message']?.toString() ?? 'Failed',
        result['success'] == true
            ? const Color(0xFF1D9E75)
            : const Color(0xFFE24B4A),
      );
      if (result['success'] == true) _loadData();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', const Color(0xFFE24B4A));
    }
  }

  // ─── Navigation ────────────────────────────────────────────
  Future<void> _goTo(Widget screen) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, anim, __) => screen,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
    _loadData();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  // ─── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        drawer: _buildDrawer(),
        body: RefreshIndicator(
          color: const Color(0xFFE53935),
          backgroundColor: const Color(0xFF1E1E1E),
          onRefresh: _loadData,
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              _buildQuickActions(),
              _buildSearchBar(),
              _buildTypeFilter(),
              _buildMonsterList(),
            ],
          ),
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  // ─── Drawer ────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFF2C2C2C), width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFE53935).withValues(alpha: 0.3),
                          width: 0.5),
                    ),
                    child: const Icon(Icons.catching_pokemon,
                        color: Color(0xFFE53935), size: 26),
                  ),
                  const SizedBox(height: 12),
                  const Text('Monster Admin',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('monster@app.local',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12)),
                ],
              ),
            ),
            // Nav items
            _drawerItem(Icons.dashboard_outlined, 'Dashboard',
                () => Navigator.pop(context)),
            _drawerItem(Icons.add_circle_outline, 'Add Monster',
                () { Navigator.pop(context); _goTo(const AddMonsterPage()); }),
            _drawerItem(Icons.edit_outlined, 'Edit Monsters',
                () { Navigator.pop(context); _goTo(const EditMonstersPage()); }),
            _drawerItem(Icons.delete_outline, 'Delete Monsters',
                () { Navigator.pop(context); _goTo(const DeleteMonsterPage()); }),
            _drawerItem(Icons.leaderboard_outlined, 'Top Monster Hunters',
                () { Navigator.pop(context); _goTo(const MonsterListPage()); }),
            _drawerItem(Icons.catching_pokemon_outlined, 'Catch Monsters',
                () { Navigator.pop(context); _goTo(const CatchMonsterPage()); }),
            _drawerItem(Icons.map_outlined, 'Monster Map',
                () { Navigator.pop(context); _goTo(const MapPage()); }),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF9E9E9E), size: 20),
      title: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }

  // ─── Sliver App Bar ────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF9E9E9E)),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF9E9E9E)),
          onPressed: _loadData,
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(
            bottom: BorderSide(color: Color(0xFF2C2C2C), width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      child: SlideTransition(
        position: _headerSlide,
        child: FadeTransition(
          opacity: _headerFade,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE53935).withValues(alpha: 0.3),
                          width: 0.5),
                    ),
                    child: const Icon(Icons.catching_pokemon,
                        color: Color(0xFFE53935), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monster Control Center',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 0.3)),
                      const Text('HAU Admin',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF3A3A3A), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pets,
                            size: 13, color: Color(0xFF1D9E75)),
                        const SizedBox(width: 5),
                        Text(
                          '${_allMonsters.length} monsters',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1D9E75),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(icon: Icons.map_outlined, label: 'Monster\nMap',
          color: const Color(0xFF378ADD),
          onTap: () => _goTo(const MapPage())),
      _QuickAction(icon: Icons.catching_pokemon, label: 'Catch\nMonster',
          color: const Color(0xFF1D9E75),
          onTap: () => _goTo(const CatchMonsterPage())),
      _QuickAction(icon: Icons.leaderboard_outlined, label: 'Leader-\nboard',
          color: const Color(0xFFEF9F27),
          onTap: () => _goTo(const MonsterListPage())),
      _QuickAction(icon: Icons.add_circle_outline, label: 'Add\nMonster',
          color: const Color(0xFFE53935),
          onTap: () => _goTo(const AddMonsterPage())),
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: actions.map((a) => Expanded(
            child: _QuickActionTile(action: a),
          )).toList(),
        ),
      ),
    );
  }

  // ─── Search Bar ────────────────────────────────────────────
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isSearching
                  ? const Color(0xFFE53935).withValues(alpha: 0.5)
                  : const Color(0xFF2C2C2C),
              width: _isSearching ? 1.0 : 0.5,
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onTap: () => setState(() => _isSearching = true),
            onTapOutside: (_) => setState(() => _isSearching = false),
            onChanged: (v) {
              _searchQuery = v;
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: 'Search monsters by name or type...',
              hintStyle:
                  const TextStyle(color: Color(0xFF616161), fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFF616161), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Color(0xFF616161), size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _searchQuery = '';
                        _applyFilters();
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Type Filter ───────────────────────────────────────────
  Widget _buildTypeFilter() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 48,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _types.length,
          itemBuilder: (_, i) {
            final type   = _types[i];
            final active = _selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedType = type);
                  _applyFilters();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFE53935)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? const Color(0xFFE53935)
                          : const Color(0xFF2C2C2C),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color:
                          active ? Colors.white : const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Monster List ──────────────────────────────────────────
  Widget _buildMonsterList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
            child:
                CircularProgressIndicator(color: Color(0xFFE53935))),
      );
    }

    if (_filteredMonsters.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _AnimatedMonsterCard(
            monster: _filteredMonsters[index],
            index: index,
            parentAnim: _listAnim,
            onEdit: () =>
                _goTo(EditMonsterPage(monster: _filteredMonsters[index])),
            onDelete: () => _deleteMonster(_filteredMonsters[index]),
          ),
          childCount: _filteredMonsters.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No monsters match "$_searchQuery"'
                : 'No monsters yet',
            style: const TextStyle(
                color: Color(0xFF616161), fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _goTo(const AddMonsterPage()),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add your first monster'),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE53935)),
          ),
        ],
      ),
    );
  }

  // ─── FAB ───────────────────────────────────────────────────
  Widget _buildFAB() {
    return ScaleTransition(
      scale: _fabScale,
      child: FloatingActionButton.extended(
        onPressed: () => _goTo(const AddMonsterPage()),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Monster',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

// ─── Animated Monster Card ─────────────────────────────────
class _AnimatedMonsterCard extends StatefulWidget {
  final Monster monster;
  final int index;
  final AnimationController parentAnim;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _AnimatedMonsterCard({
    required this.monster,
    required this.index,
    required this.parentAnim,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_AnimatedMonsterCard> createState() => _AnimatedMonsterCardState();
}

class _AnimatedMonsterCardState extends State<_AnimatedMonsterCard> {
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final delay    = (widget.index * 0.08).clamp(0.0, 0.7);
    final end      = (delay + 0.4).clamp(0.0, 1.0);
    final interval = Interval(delay, end, curve: Curves.easeOutCubic);

    _fade  = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: widget.parentAnim, curve: interval));
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: widget.parentAnim, curve: interval));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _MonsterListCard(
          monster: widget.monster,
          onEdit:   widget.onEdit,
          onDelete: widget.onDelete,
        ),
      ),
    );
  }
}

// ─── Monster List Card ─────────────────────────────────────
class _MonsterListCard extends StatelessWidget {
  final Monster monster;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MonsterListCard({
    required this.monster,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(monster.monsterType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2C), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image / avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 68, height: 68,
                child: monster.pictureUrl != null &&
                        monster.pictureUrl!.isNotEmpty
                    ? Image.network(
                        monster.pictureUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _fallback(monster.monsterName, typeColor),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: const Color(0xFF2A2A2A),
                            child: const Center(
                              child: SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFE53935)),
                              ),
                            ),
                          );
                        },
                      )
                    : _fallback(monster.monsterName, typeColor),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(monster.monsterName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  _TypeBadge(type: monster.monsterType),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.radar,
                          size: 12, color: Color(0xFF757575)),
                      const SizedBox(width: 4),
                      Text(
                        '${monster.spawnRadiusMeters.toStringAsFixed(0)}m radius',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF757575)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  _ActionBtn(
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF378ADD),
                    tooltip: 'Edit',
                    onTap: onEdit!,
                  ),
                if (onDelete != null) ...[
                  const SizedBox(height: 6),
                  _ActionBtn(
                    icon: Icons.delete_outline,
                    color: const Color(0xFFE24B4A),
                    tooltip: 'Delete',
                    onTap: onDelete!,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(String name, Color color) {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: color),
        ),
      ),
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

// ─── Type Badge ────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.8),
      ),
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

// ─── Small action button ───────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: color.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ─── Quick Action Data ─────────────────────────────────────
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

// ─── Quick Action Tile ─────────────────────────────────────
class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp:   (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.action.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.action.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: widget.action.color.withValues(alpha: 0.25),
                  width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.action.icon,
                    color: widget.action.color, size: 22),
                const SizedBox(height: 6),
                Text(
                  widget.action.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: widget.action.color,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
