import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/player_model.dart';
import '../services/local_db_service.dart';
import 'add_player_page.dart';
import 'edit_player_page.dart';

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

enum _SortOrder { newest, oldest, atoz }

// ─────────────────────────────────────────────────────────────
class PlayersListPage extends StatefulWidget {
  const PlayersListPage({super.key});

  @override
  State<PlayersListPage> createState() => _PlayersListPageState();
}

class _PlayersListPageState extends State<PlayersListPage>
    with SingleTickerProviderStateMixin {

  late Future<List<Player>> _playersFuture;
  late AnimationController  _fadeCtrl;
  late Animation<double>    _fadeAnim;

  String _search = '';
  _SortOrder _sort = _SortOrder.oldest;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _playersFuture = LocalDbService.instance.getPlayers();
    _playersFuture.then((_) {
      if (mounted) _fadeCtrl.forward(from: 0);
    });
  }

  Future<void> _refresh() async => setState(() => _load());

  // ── Delete ────────────────────────────────────────────────
  Future<void> _delete(Player player) async {
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
          Text('Delete Player',
              style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: _textSecondary, fontSize: 13, height: 1.5),
            children: [
              const TextSpan(text: 'Remove '),
              TextSpan(text: player.playerName,
                  style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
              const TextSpan(text: '? Their catch history will also be deleted.'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE24B4A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    HapticFeedback.mediumImpact();
    final result = await LocalDbService.instance.deletePlayer(player.playerId);
    if (!mounted) return;

    _snack(
      result['success'] == true
          ? '${player.playerName} removed.'
          : result['message']?.toString() ?? 'Failed',
      result['success'] == true ? _accentGreen : _accentRed,
    );
    if (result['success'] == true) _refresh();
  }

  // ── Navigate to edit ──────────────────────────────────────
  Future<void> _edit(Player player) async {
    final updated = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, a, __) => EditPlayerPage(player: player),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
    if (updated == true) _refresh();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFFE53935), Color(0xFF378ADD), Color(0xFF1D9E75),
      Color(0xFFEF9F27), Color(0xFF7F77DD), Color(0xFF5DCAA5),
      Color(0xFFD85A30),
    ];
    return name.isNotEmpty ? colors[name.codeUnitAt(0) % colors.length] : _textMuted;
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: Column(children: [
          // ── Admin disclaimer banner ──────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF9F27).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFEF9F27).withValues(alpha: 0.30),
                width: 0.5,
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.admin_panel_settings_outlined,
                    color: Color(0xFFEF9F27), size: 15),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Admin feature — in a production app this section '
                    'would not be accessible to regular users.',
                    style: TextStyle(
                      color: Color(0xFFEF9F27),
                      fontSize: 11,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search bar
          _buildSearchBar(),
          // List
          Expanded(
            child: FutureBuilder<List<Player>>(
              future: _playersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accentRed, strokeWidth: 2));
                }
                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }
                final all = snapshot.data ?? [];
                var players = _search.isEmpty
                    ? List<Player>.from(all)
                    : all.where((p) =>
                        p.playerName.toLowerCase().contains(_search.toLowerCase()) ||
                        p.username.toLowerCase().contains(_search.toLowerCase())).toList();

                // Apply sort
                switch (_sort) {
                  case _SortOrder.newest:
                    players.sort((a, b) => b.playerId.compareTo(a.playerId));
                    break;
                  case _SortOrder.oldest:
                    players.sort((a, b) => a.playerId.compareTo(b.playerId));
                    break;
                  case _SortOrder.atoz:
                    players.sort((a, b) =>
                        a.playerName.toLowerCase().compareTo(b.playerName.toLowerCase()));
                    break;
                }

                if (all.isEmpty) return _buildEmpty();
                if (players.isEmpty) return _buildNoResults();

                return FadeTransition(
                  opacity: _fadeAnim,
                  child: RefreshIndicator(
                    color: _accentRed,
                    backgroundColor: _elevated,
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: players.length,
                      itemBuilder: (_, i) => _PlayerCard(
                        player: players[i],
                        avatarColor: _avatarColor(players[i].playerName),
                        onEdit:   () => _edit(players[i]),
                        onDelete: () => _delete(players[i]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final added = await Navigator.push<bool>(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 320),
                pageBuilder: (_, a, __) => const AddPlayerPage(),
                transitionsBuilder: (_, a, __, child) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
            );
            if (added == true) _refresh();
          },
          backgroundColor: _accentRed,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.person_add_rounded, size: 22),
        ),
      ),
    );
  }

  PopupMenuItem<_SortOrder> _sortMenuItem(
      _SortOrder value, String label, IconData icon) {
    final active = _sort == value;
    return PopupMenuItem<_SortOrder>(
      value: value,
      child: Row(children: [
        Icon(icon,
            size: 15,
            color: active ? _accentRed : _textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
              color: active ? _accentRed : _textSecondary,
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            )),
        if (active) ...[
          const Spacer(),
          const Icon(Icons.check_rounded, size: 13, color: _accentRed),
        ],
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _bg,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textSecondary, size: 18),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Column(children: [
      Text('PLAYERS',
          style: TextStyle(color: _textMuted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
      SizedBox(height: 1),
      Text('Manage Accounts',
          style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
    ]),
    centerTitle: true,
    actions: [
      // Filter / sort button
      Padding(
        padding: const EdgeInsets.only(right: 4),
        child: PopupMenuButton<_SortOrder>(
          onSelected: (val) => setState(() => _sort = val),
          color: const Color(0xFF1A1A26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _border),
          ),
          offset: const Offset(0, 44),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _sort != _SortOrder.oldest
                  ? _accentRed.withValues(alpha: 0.15)
                  : _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _sort != _SortOrder.oldest
                    ? _accentRed.withValues(alpha: 0.40)
                    : _border,
                width: 0.5,
              ),
            ),
            child: Icon(
              Icons.sort_rounded,
              size: 17,
              color: _sort != _SortOrder.oldest
                  ? _accentRed
                  : _textSecondary,
            ),
          ),
          itemBuilder: (_) => [
            _sortMenuItem(_SortOrder.oldest, 'Oldest First', Icons.arrow_upward_rounded),
            _sortMenuItem(_SortOrder.newest, 'Newest First', Icons.arrow_downward_rounded),
            _sortMenuItem(_SortOrder.atoz,   'A to Z',       Icons.sort_by_alpha_rounded),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: _refresh,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border, width: 0.5),
            ),
            child: const Icon(Icons.refresh_rounded, color: _textSecondary, size: 17),
          ),
        ),
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(0.5),
      child: Container(height: 0.5, color: _border),
    ),
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Container(
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: _textPrimary, fontSize: 13),
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search by name or username…',
          hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _textMuted, size: 17),
          suffixIcon: _search.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                  child: const Icon(Icons.close_rounded, color: _textMuted, size: 16),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    ),
  );

  Widget _buildError(String err) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: _accentRed, size: 40),
        const SizedBox(height: 12),
        const Text('Could not load players',
            style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(err, style: const TextStyle(color: _textSecondary, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _refresh,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border, width: 0.5)),
            child: const Text('Retry', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _accentBlue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.group_outlined, color: _textMuted, size: 32),
        ),
        const SizedBox(height: 20),
        const Text('No Players Yet',
            style: TextStyle(color: _textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
          'Tap the + button to add the first\nlocal account on this device.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.5),
        ),
      ]),
    ),
  );

  Widget _buildNoResults() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.search_off_rounded, color: _textMuted, size: 36),
      const SizedBox(height: 12),
      Text('No results for "$_search"',
          style: const TextStyle(color: _textSecondary, fontSize: 14)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
// PLAYER CARD
// ─────────────────────────────────────────────────────────────
class _PlayerCard extends StatefulWidget {
  final Player    player;
  final Color     avatarColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlayerCard({
    required this.player,
    required this.avatarColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'player_avatar_${widget.player.playerId}.jpg');
      if (File(path).existsSync()) {
        if (mounted) setState(() => _avatarPath = path);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = widget.avatarColor;
    final player      = widget.player;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(children: [
            // Avatar accent bar
            Container(width: 3, color: avatarColor),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(children: [
                  // Avatar — shows photo if available, else initial letter
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: avatarColor.withValues(alpha: 0.22), width: 0.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _avatarPath != null
                          ? Image.file(
                              File(_avatarPath!),
                              width: 46, height: 46,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _initialFallback(player.playerName, avatarColor),
                            )
                          : _initialFallback(player.playerName, avatarColor),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(player.playerName,
                            style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.alternate_email,
                              size: 11, color: _textMuted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(player.username,
                                style: const TextStyle(
                                    color: _textSecondary, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                        if (player.createdAt != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 10, color: _textMuted),
                            const SizedBox(width: 3),
                            Text(
                              _formatDate(player.createdAt!),
                              style: const TextStyle(
                                  color: _textMuted, fontSize: 10),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Action buttons
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionBtn(
                          icon: Icons.edit_outlined,
                          color: _accentBlue,
                          onTap: widget.onEdit),
                      const SizedBox(height: 6),
                      _ActionBtn(
                          icon: Icons.delete_outline,
                          color: const Color(0xFFE24B4A),
                          onTap: widget.onDelete),
                    ],
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _initialFallback(String name, Color color) => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
    ),
  );

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length > 10 ? raw.substring(0, 10) : raw;
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 0.5),
      ),
      child: Icon(icon, size: 15, color: color),
    ),
  );
}