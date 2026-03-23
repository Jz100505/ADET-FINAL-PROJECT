import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/player_model.dart';
import '../models/player_ranking_model.dart';

// ─────────────────────────────────────────────────────────────
// LocalDbService — singleton SQLite service
// Handles ALL account & catch-history operations on-device.
// Monster CRUD remains on the remote MySQL server (ApiService).
// ─────────────────────────────────────────────────────────────
class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  // ── Init ──────────────────────────────────────────────────
  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'haumonsters_local.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        // Players table
        await db.execute('''
          CREATE TABLE players (
            player_id   INTEGER PRIMARY KEY AUTOINCREMENT,
            player_name TEXT    NOT NULL,
            username    TEXT    NOT NULL UNIQUE,
            password_hash TEXT  NOT NULL,
            created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
          )
        ''');

        // Local catch history — links local players to monsters
        // monster_id references the remote server's monsterstbl
        await db.execute('''
          CREATE TABLE local_catches (
            catch_id     INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id    INTEGER NOT NULL,
            monster_id   INTEGER NOT NULL,
            monster_name TEXT    NOT NULL,
            monster_type TEXT    NOT NULL,
            caught_at    TEXT    NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (player_id) REFERENCES players(player_id)
              ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // ── Password ──────────────────────────────────────────────
  String _hash(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // ── Register ──────────────────────────────────────────────
  /// Returns `{'success': true, 'player_id': int}` or
  ///         `{'success': false, 'message': String}`
  Future<Map<String, dynamic>> registerPlayer({
    required String playerName,
    required String username,
    required String password,
  }) async {
    try {
      final db = await database;

      // Check username uniqueness
      final existing = await db.query(
        'players',
        where: 'LOWER(username) = LOWER(?)',
        whereArgs: [username],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return {'success': false, 'message': 'Username already taken'};
      }

      final id = await db.insert('players', {
        'player_name':   playerName,
        'username':      username,
        'password_hash': _hash(password),
      });

      return {'success': true, 'player_id': id, 'message': 'Account created'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ── Login ─────────────────────────────────────────────────
  /// Returns `{'success': true, 'data': {'player_id', 'player_name', 'username'}}`
  /// or      `{'success': false, 'message': String}`
  Future<Map<String, dynamic>> loginPlayer({
    required String username,
    required String password,
  }) async {
    try {
      final db = await database;
      final rows = await db.query(
        'players',
        where: 'LOWER(username) = LOWER(?)',
        whereArgs: [username],
        limit: 1,
      );

      if (rows.isEmpty) {
        return {'success': false, 'message': 'Invalid username or password'};
      }

      final row = rows.first;
      if (row['password_hash'] != _hash(password)) {
        return {'success': false, 'message': 'Invalid username or password'};
      }

      return {
        'success': true,
        'message': 'Login successful',
        'data': {
          'player_id':   row['player_id'],
          'player_name': row['player_name'],
          'username':    row['username'],
        },
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ── Get all players ───────────────────────────────────────
  Future<List<Player>> getPlayers() async {
    final db   = await database;
    final rows = await db.query('players', orderBy: 'created_at ASC, player_id ASC');
    return rows.map((r) => Player(
      playerId:   r['player_id']   as int,
      playerName: r['player_name'] as String,
      username:   r['username']    as String,
      password:   '',              // never expose hash
      createdAt:  r['created_at']  as String?,
    )).toList();
  }

  // ── Get single player ─────────────────────────────────────
  Future<Player?> getPlayer(int playerId) async {
    final db   = await database;
    final rows = await db.query(
      'players',
      where: 'player_id = ?',
      whereArgs: [playerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Player(
      playerId:   r['player_id']   as int,
      playerName: r['player_name'] as String,
      username:   r['username']    as String,
      password:   '',
      createdAt:  r['created_at']  as String?,
    );
  }

  // ── Update player ─────────────────────────────────────────
  Future<Map<String, dynamic>> updatePlayer({
    required int    playerId,
    required String playerName,
    required String username,
    String?         newPassword,
  }) async {
    try {
      final db = await database;

      // Check username uniqueness (excluding self)
      final conflict = await db.query(
        'players',
        where: 'LOWER(username) = LOWER(?) AND player_id != ?',
        whereArgs: [username, playerId],
        limit: 1,
      );
      if (conflict.isNotEmpty) {
        return {'success': false, 'message': 'Username already taken'};
      }

      final values = <String, dynamic>{
        'player_name': playerName,
        'username':    username,
      };
      if (newPassword != null && newPassword.isNotEmpty) {
        values['password_hash'] = _hash(newPassword);
      }

      final count = await db.update(
        'players',
        values,
        where: 'player_id = ?',
        whereArgs: [playerId],
      );

      if (count == 0) return {'success': false, 'message': 'Player not found'};
      return {'success': true, 'message': 'Player updated successfully'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ── Delete player ─────────────────────────────────────────
  Future<Map<String, dynamic>> deletePlayer(int playerId) async {
    try {
      final db = await database;
      final count = await db.delete(
        'players',
        where: 'player_id = ?',
        whereArgs: [playerId],
      );
      if (count == 0) return {'success': false, 'message': 'Player not found'};
      return {'success': true, 'message': 'Player deleted'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ── Record a catch ────────────────────────────────────────
  /// Called after a successful updateMonster on the server side.
  /// Records the catch locally so it appears in local rankings.
  /// Silently ignores if playerId is null (demo mode).
  Future<void> recordCatch({
    required int    playerId,
    required int    monsterId,
    required String monsterName,
    required String monsterType,
  }) async {
    try {
      final db = await database;

      // Verify player exists locally (guard against demo / stale IDs)
      final exists = await db.query(
        'players',
        where: 'player_id = ?',
        whereArgs: [playerId],
        limit: 1,
      );
      if (exists.isEmpty) return;

      await db.insert('local_catches', {
        'player_id':    playerId,
        'monster_id':   monsterId,
        'monster_name': monsterName,
        'monster_type': monsterType,
      });
    } catch (_) {
      // non-fatal — catch still succeeded on server side
    }
  }

  // ── Local rankings ────────────────────────────────────────
  /// Returns top 10 local players ordered by catch count.
  Future<List<PlayerRanking>> getLocalRankings() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        p.player_id,
        p.player_name,
        COUNT(c.catch_id) AS catch_count
      FROM players p
      LEFT JOIN local_catches c ON p.player_id = c.player_id
      GROUP BY p.player_id, p.player_name
      ORDER BY catch_count DESC, p.player_id ASC
      LIMIT 10
    ''');

    return rows.map((r) => PlayerRanking(
      playerId:   r['player_id']   as int,
      playerName: r['player_name'] as String,
      catchCount: (r['catch_count'] as int?) ?? 0,
    )).toList();
  }

  // ── Catch history for a single player ────────────────────
  Future<int> getCatchCount(int playerId) async {
    final db   = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM local_catches WHERE player_id = ?',
      [playerId],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  // ── Wipe DB (dev / testing util) ─────────────────────────
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('local_catches');
    await db.delete('players');
  }
}