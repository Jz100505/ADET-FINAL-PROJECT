import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';

class DeleteMonsterPage extends StatefulWidget {
  const DeleteMonsterPage({super.key});

  @override
  State<DeleteMonsterPage> createState() => _DeleteMonsterPageState();
}

class _DeleteMonsterPageState extends State<DeleteMonsterPage>
    with SingleTickerProviderStateMixin {

  late Future<List<Monster>> _monstersFuture;
  late AnimationController   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _loadMonsters();
  }

  @override
  void dispose() { _fadeAnim.dispose(); super.dispose(); }

  void _loadMonsters() {
    _monstersFuture = ApiService.getMonsters();
    _monstersFuture.then((_) {
      if (mounted) _fadeAnim.forward(from: 0);
    });
  }

  Future<void> _refresh() async {
    setState(() => _loadMonsters());
  }

  Future<void> _deleteMonster(Monster monster) async {
    // Polished animated confirmation dialog
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFE24B4A), size: 24),
          SizedBox(width: 10),
          Text('Delete Monster',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ]),
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
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      HapticFeedback.mediumImpact();
      final result =
          await ApiService.deleteMonster(monsterId: monster.monsterId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            result['success'] == true
                ? Icons.check_circle_outline
                : Icons.error_outline,
            color: Colors.white, size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(result['message']?.toString() ?? 'Done')),
        ]),
        backgroundColor: result['success'] == true
            ? const Color(0xFF1D9E75)
            : const Color(0xFFE24B4A),
      ));

      if (result['success'] == true) _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: const Color(0xFFE24B4A),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Delete Monsters'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Color(0xFF9E9E9E)),
              onPressed: _refresh,
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: const Color(0xFF2C2C2C)),
          ),
        ),
        body: FutureBuilder<List<Monster>>(
          future: _monstersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFE24B4A)));
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFE24B4A), size: 48),
                    const SizedBox(height: 12),
                    Text('Error: ${snapshot.error}',
                        style: const TextStyle(
                            color: Color(0xFF616161), fontSize: 14),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE24B4A)),
                    ),
                  ],
                ),
              );
            }

            final monsters = snapshot.data ?? [];

            if (monsters.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, color: Color(0xFF424242), size: 56),
                    SizedBox(height: 12),
                    Text('No monsters found',
                        style: TextStyle(
                            color: Color(0xFF616161), fontSize: 15)),
                  ],
                ),
              );
            }

            return FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                color: const Color(0xFFE24B4A),
                backgroundColor: const Color(0xFF1E1E1E),
                onRefresh: _refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: monsters.length,
                  itemBuilder: (context, index) {
                    final monster = monsters[index];
                    final typeColor = _typeColor(monster.monsterType);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF2C2C2C), width: 0.5),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: monster.pictureUrl != null &&
                                monster.pictureUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 44, height: 44,
                                  child: Image.network(
                                    monster.pictureUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatarFallback(
                                            monster.monsterName, typeColor),
                                  ),
                                ),
                              )
                            : _avatarFallback(monster.monsterName, typeColor),
                        title: Text(monster.monsterName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: typeColor.withValues(alpha: 0.3),
                                    width: 0.5),
                              ),
                              child: Text(
                                  monster.monsterType.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: typeColor,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.7)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ID: ${monster.monsterId}',
                              style: const TextStyle(
                                  color: Color(0xFF757575), fontSize: 11),
                            ),
                          ]),
                        ),
                        trailing: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFE24B4A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFE24B4A)
                                    .withValues(alpha: 0.3),
                                width: 0.5),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.delete_outline,
                                color: Color(0xFFE24B4A), size: 16),
                            onPressed: () => _deleteMonster(monster),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _avatarFallback(String name, Color color) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
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
