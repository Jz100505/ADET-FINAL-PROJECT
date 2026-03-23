import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/player_ranking_model.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';

const _bg        = Color(0xFF0F0D22);
const _heroGlow  = Color(0xFF1E1840);
const _cardBg    = Color(0xFF1C1A35);
const _elevated  = Color(0xFF252245);
const _border    = Color(0xFF2B2850);
const _gold      = Color(0xFFFFD700);
const _silver    = Color(0xFFAAB8CC);
const _bronze    = Color(0xFFCC8844);
const _accentPur = Color(0xFF8B5CF6);
const _textPri   = Colors.white;
const _textSec   = Color(0xFF7A77A8);
const _textMute  = Color(0xFF3E3C60);

class MonsterListPage extends StatefulWidget {
  const MonsterListPage({super.key});
  @override
  State<MonsterListPage> createState() => _MonsterListPageState();
}

class _MonsterListPageState extends State<MonsterListPage>
    with TickerProviderStateMixin {

  late Future<List<PlayerRanking>> _rankingsFuture;
  // Stats card data
  int _totalCatches  = 0;
  int _totalHunters  = 0;
  int _totalMonsters = 0;
  late final AnimationController _confettiCtrl;
  late final AnimationController _heroCtrl;
  late final AnimationController _listCtrl;
  late final Animation<double> _heroFade;
  late final Animation<double> _heroSlide;
  late final List<_ConfettiBit> _bits;
  final _rng = Random(7);

  @override
  void initState() {
    super.initState();
    _bits = _makeConfetti();
    _confettiCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _heroFade  = CurvedAnimation(parent: _heroCtrl, curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    _heroSlide = CurvedAnimation(parent: _heroCtrl, curve: const Interval(0.0, 0.70, curve: Curves.easeOutCubic));
    _listCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _load();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _heroCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _rankingsFuture = LocalDbService.instance.getLocalRankings();
    _rankingsFuture.then((rankings) {
      if (!mounted) return;
      // Compute stats from rankings list
      final catches = rankings.fold<int>(0, (sum, p) => sum + p.catchCount);
      setState(() {
        _totalCatches = catches;
        _totalHunters = rankings.length;
      });
      // Fetch total monsters from server (non-blocking)
      ApiService.getMonsters().then((monsters) {
        if (mounted) setState(() => _totalMonsters = monsters.length);
      }).catchError((_) {});
      _heroCtrl.forward();
      Future.delayed(const Duration(milliseconds: 350),
          () { if (mounted) _listCtrl.forward(); });
    });
  }

  Future<void> _refresh() async {
    _heroCtrl.reset();
    _listCtrl.reset();
    setState(() => _load());
  }

  List<_ConfettiBit> _makeConfetti() {
    const cols = [
      Color(0xFFFFD700), Color(0xFF8B5CF6), Color(0xFF06B6D4),
      Color(0xFFF97316), Color(0xFFEC4899), Color(0xFFA3E635),
      Color(0xFFFFD700), Color(0xFF8B5CF6),
    ];
    return List.generate(60, (_) => _ConfettiBit(
      x: _rng.nextDouble(), y: _rng.nextDouble() * 0.55,
      speed: _rng.nextDouble() * 0.08 + 0.03,
      rotSpd: (_rng.nextDouble() - 0.5) * 4.0,
      wobble: _rng.nextDouble() * 0.8 + 0.3,
      w: _rng.nextDouble() * 5 + 3, h: _rng.nextDouble() * 10 + 5,
      color: cols[_rng.nextInt(cols.length)],
      phase: _rng.nextDouble(), ribbon: _rng.nextBool(),
    ));
  }

  Color _avatarColor(String name) {
    const colors = [Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFF10B981),
      Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF3B82F6),
      Color(0xFFEC4899), Color(0xFF84CC16)];
    return name.isNotEmpty ? colors[name.codeUnitAt(0) % colors.length] : _textMute;
  }

  Color _medal(int rank) => rank == 1 ? _gold : rank == 2 ? _silver : _bronze;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<List<PlayerRanking>>(
        future: _rankingsFuture,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _accentPur, strokeWidth: 2));
          }
          if (snap.hasError) return _errorView(snap.error.toString());
          final r = snap.data ?? [];
          if (r.isEmpty) return _emptyView();
          return _pageView(r);
        },
      ),
    );
  }

  Widget _pageView(List<PlayerRanking> r) {
    return Stack(children: [
      // Confetti layer
      AnimatedBuilder(
        animation: _confettiCtrl,
        builder: (_, __) => SizedBox.expand(
          child: CustomPaint(painter: _ConfettiPainter(_bits, _confettiCtrl.value)),
        ),
      ),
      // Radial hero glow
      Positioned(
        top: -100, left: 0, right: 0,
        child: Center(
          child: Container(
            width: 380, height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_heroGlow.withValues(alpha: 0.75), Colors.transparent],
                radius: 0.72,
              ),
            ),
          ),
        ),
      ),
      // Main layout
      Positioned.fill(
        child: Column(children: [
          _appBar(),
          Expanded(flex: 46, child: _heroSection(r)),
          Expanded(flex: 54, child: _bottomCard(r)),
        ]),
      ),
    ]);
  }

  Widget _appBar() => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(children: [
        _iconBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
        const Expanded(
          child: Column(children: [
            Text('LEADERBOARD', style: TextStyle(color: _accentPur, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
            SizedBox(height: 2),
            Text('Top Monster Hunters', style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w900)),
          ]),
        ),
        _iconBtn(Icons.refresh_rounded, _refresh),
      ]),
    ),
  );

  Widget _iconBtn(IconData icon, VoidCallback fn) => GestureDetector(
    onTap: fn,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 0.5),
      ),
      child: Icon(icon, color: _textSec, size: 16),
    ),
  );

  Widget _heroSection(List<PlayerRanking> r) => AnimatedBuilder(
    animation: _heroCtrl,
    builder: (_, __) => Opacity(
      opacity: _heroFade.value,
      child: Transform.translate(
        offset: Offset(0, 28 * (1 - _heroSlide.value)),
        child: Column(
          children: [
            // ── Stats card ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                      width: 0.5),
                ),
                child: Row(children: [
                  _statCell(
                    icon: Icons.catching_pokemon_rounded,
                    color: _gold,
                    value: '$_totalCatches',
                    label: 'Catches',
                  ),
                  _statDivider(),
                  _statCell(
                    icon: Icons.group_rounded,
                    color: _accentPur,
                    value: '$_totalHunters',
                    label: 'Hunters',
                  ),
                  _statDivider(),
                  _statCell(
                    icon: Icons.pets_rounded,
                    color: const Color(0xFF06B6D4),
                    value: _totalMonsters > 0 ? '$_totalMonsters' : '—',
                    label: 'Monsters',
                  ),
                ]),
              ),
            ),

            // ── Podium row ───────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: r.length >= 2
                        ? _podiumPlayer(r[1], rank: 2)
                        : const SizedBox()),
                    Expanded(child: _podiumPlayer(r[0], rank: 1)),
                    Expanded(child: r.length >= 3
                        ? _podiumPlayer(r[2], rank: 3)
                        : const SizedBox()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _statCell({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) =>
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.0)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: _textSec,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4)),
        ]),
      );

  Widget _statDivider() => Container(
        width: 0.5, height: 44,
        color: Colors.white.withValues(alpha: 0.08),
      );

  Widget _podiumPlayer(PlayerRanking player, {required int rank}) {
    final isFirst   = rank == 1;
    final medal     = _medal(rank);
    final avatarClr = _avatarColor(player.playerName);
    final avatarD   = isFirst ? 78.0 : 60.0;
    final initial   = player.playerName.isNotEmpty ? player.playerName[0].toUpperCase() : '?';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Extra top space for 1st — makes centre column taller,
        // so Row crossAxisAlignment.end naturally elevates it
        if (isFirst) const SizedBox(height: 22),

        // Crown pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: medal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: medal.withValues(alpha: 0.28), width: 0.5),
          ),
          child: Icon(Icons.workspace_premium_rounded, color: medal, size: isFirst ? 22.0 : 17.0),
        ),

        const SizedBox(height: 8),

        // Avatar with glowing medal ring
        Container(
          width: avatarD, height: avatarD,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: avatarClr.withValues(alpha: 0.14),
            border: Border.all(color: medal, width: isFirst ? 2.5 : 2.0),
            boxShadow: [
              BoxShadow(color: medal.withValues(alpha: isFirst ? 0.45 : 0.28), blurRadius: isFirst ? 24 : 14, spreadRadius: isFirst ? 3 : 1),
              BoxShadow(color: avatarClr.withValues(alpha: 0.15), blurRadius: isFirst ? 32 : 20),
            ],
          ),
          child: Center(
            child: Text(initial, style: TextStyle(color: avatarClr, fontSize: isFirst ? 28 : 22, fontWeight: FontWeight.w900)),
          ),
        ),

        const SizedBox(height: 10),

        // Name
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            player.playerName.length > 10 ? '${player.playerName.substring(0, 9)}…' : player.playerName,
            style: TextStyle(color: _textPri, fontSize: isFirst ? 14.0 : 12.0, fontWeight: FontWeight.w800, letterSpacing: 0.2),
            textAlign: TextAlign.center, maxLines: 1,
          ),
        ),

        const SizedBox(height: 5),

        // Catch pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: medal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: medal.withValues(alpha: 0.30), width: 0.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.catching_pokemon, color: medal, size: 10),
            const SizedBox(width: 4),
            Text('${player.catchCount}', style: TextStyle(color: medal, fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _bottomCard(List<PlayerRanking> r) {
    final rest = r.length > 3 ? r.sublist(3) : <PlayerRanking>[];
    return Container(
      decoration: const BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 28, offset: Offset(0, -6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Container(width: 3, height: 16,
                decoration: BoxDecoration(color: _accentPur, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text(rest.isEmpty ? 'ALL HUNTERS' : 'OTHER HUNTERS',
                style: const TextStyle(color: _textSec, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentPur.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentPur.withValues(alpha: 0.22), width: 0.5),
                ),
                child: Text('${r.length} hunters',
                  style: const TextStyle(color: _accentPur, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          const SizedBox(height: 14),
          const Divider(color: _border, height: 0.5, thickness: 0.5),

          Expanded(
            child: rest.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_outline, color: _textMute, size: 32),
                      const SizedBox(height: 8),
                      const Text('No other hunters yet', style: TextStyle(color: _textSec, fontSize: 13)),
                    ]),
                  )
                : AnimatedBuilder(
                    animation: _listCtrl,
                    builder: (_, __) => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                      itemCount: rest.length,
                      separatorBuilder: (_, __) => const Divider(color: _border, height: 1, thickness: 0.5),
                      itemBuilder: (_, i) {
                        final delay = (i * 0.12).clamp(0.0, 0.85);
                        final frac  = Interval(delay, (delay + 0.3).clamp(0.0, 1.0), curve: Curves.easeOut)
                            .transform(_listCtrl.value);
                        return Opacity(
                          opacity: frac,
                          child: Transform.translate(
                            offset: Offset(20 * (1 - frac), 0),
                            child: _listRow(rest[i], rank: i + 4),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _listRow(PlayerRanking player, {required int rank}) {
    final aColor  = _avatarColor(player.playerName);
    final initial = player.playerName.isNotEmpty ? player.playerName[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(children: [
        SizedBox(width: 26,
          child: Text('$rank', textAlign: TextAlign.center,
            style: const TextStyle(color: _textMute, fontSize: 13, fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: aColor.withValues(alpha: 0.12), shape: BoxShape.circle,
            border: Border.all(color: aColor.withValues(alpha: 0.30), width: 1.5),
          ),
          child: Center(child: Text(initial, style: TextStyle(color: aColor, fontSize: 16, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(player.playerName,
                style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.catching_pokemon, color: _textMute, size: 10),
                const SizedBox(width: 4),
                Text('${player.catchCount} monster${player.catchCount == 1 ? '' : 's'} caught',
                  style: const TextStyle(color: _textSec, fontSize: 11)),
              ]),
            ],
          ),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _elevated, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border, width: 0.5),
          ),
          child: Text('${player.catchCount}', textAlign: TextAlign.center,
            style: const TextStyle(color: _textSec, fontSize: 17, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }

  Widget _errorView(String err) => Center(
    child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64,
          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 28)),
        const SizedBox(height: 16),
        const Text('Could not load rankings', style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(err, style: const TextStyle(color: _textSec, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        GestureDetector(onTap: _refresh,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, color: _textSec, size: 15),
              SizedBox(width: 8),
              Text('Retry', style: TextStyle(color: _textSec, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          )),
      ])),
  );

  Widget _emptyView() => Center(
    child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _gold.withValues(alpha: 0.14), width: 0.5)),
          child: const Icon(Icons.emoji_events_outlined, color: _textMute, size: 36)),
        const SizedBox(height: 20),
        const Text('No Rankings Yet', style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        const Text('Catch monsters to appear\non the leaderboard.',
          textAlign: TextAlign.center, style: TextStyle(color: _textSec, fontSize: 13, height: 1.55)),
      ])),
  );
}

// ── Confetti model ────────────────────────────────────────────
class _ConfettiBit {
  final double x, y, speed, rotSpd, wobble, w, h, phase;
  final Color color;
  final bool ribbon;
  const _ConfettiBit({
    required this.x, required this.y, required this.speed, required this.rotSpd,
    required this.wobble, required this.w, required this.h,
    required this.color, required this.phase, required this.ribbon,
  });
}

// ── Confetti painter ──────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiBit> bits;
  final double t;
  const _ConfettiPainter(this.bits, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      final rawY = (b.y + t * b.speed) % 0.62;
      final px   = (b.x + sin(t * b.wobble * 2 * pi + b.phase * 2 * pi) * 0.035) * size.width;
      final py   = rawY * size.height;
      final alpha = rawY < 0.48 ? 0.82 : 0.82 * (1.0 - (rawY - 0.48) / 0.14);
      if (alpha <= 0.01) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(t * b.rotSpd * 2 * pi + b.phase * 2 * pi);
      final paint = Paint()..color = b.color.withValues(alpha: alpha);

      if (b.ribbon) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.w, height: b.h), const Radius.circular(1.5)),
          paint,
        );
      } else {
        canvas.drawPath(
          Path()..moveTo(0, -b.h/2)..lineTo(b.w/2, 0)..lineTo(0, b.h/2)..lineTo(-b.w/2, 0)..close(),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}