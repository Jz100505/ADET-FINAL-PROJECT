import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/monster_model.dart';
import '../models/player_model.dart';
import '../models/player_ranking_model.dart';

class ApiService {
  static const String baseUrl = "http://3.0.90.110";

  // ════════════════════════════════════════════════════════════
  // INTERNAL HELPER — safe JSON decoder
  // ════════════════════════════════════════════════════════════

  /// Safely decodes a response body to a Map.
  /// If the server returns HTML (error page) or empty body,
  /// returns a well-formed error map instead of throwing.
  static Map<String, dynamic> _parseResponse(http.Response response) {
    final body = response.body.trim();

    if (body.isEmpty) {
      return {
        "success": false,
        "message": "Server returned an empty response (HTTP ${response.statusCode})"
      };
    }

    // Server returned HTML — usually a PHP fatal error or 404 page
    if (!body.startsWith('{') && !body.startsWith('[')) {
      // Try to extract a useful hint from the HTML
      String hint = '';
      final titleMatch =
          RegExp(r'<title>(.*?)<\/title>', caseSensitive: false).firstMatch(body);
      if (titleMatch != null) {
        hint = ' (${titleMatch.group(1)?.trim() ?? ''})';
      }
      return {
        "success": false,
        "message":
            "Server error$hint — check that the PHP file is uploaded and has no syntax errors. HTTP ${response.statusCode}"
      };
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      // Some endpoints wrap in a list — unlikely here but safe to handle
      return {"success": true, "data": decoded};
    } catch (e) {
      return {
        "success": false,
        "message": "Failed to parse server response: $e"
      };
    }
  }

  /// Same as above but for list-returning endpoints (getMonsters, etc.)
  static List<dynamic> _parseListResponse(
      http.Response response, String dataKey) {
    final map = _parseResponse(response);
    if (map['success'] == true) {
      return (map[dataKey] as List?) ?? [];
    }
    throw Exception(map['message'] ?? 'Request failed');
  }

  // ════════════════════════════════════════════════════════════
  // MONSTER APIs
  // ════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> addMonster({
    required String monsterName,
    required String monsterType,
    required double spawnLatitude,
    required double spawnLongitude,
    required double spawnRadiusMeters,
    String? pictureUrl,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/add_monster.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "monster_name":        monsterName,
        "monster_type":        monsterType,
        "spawn_latitude":      spawnLatitude,
        "spawn_longitude":     spawnLongitude,
        "spawn_radius_meters": spawnRadiusMeters,
        "picture_url":         pictureUrl ?? "",
      }),
    );
    return _parseResponse(response);
  }

  static Future<List<Monster>> getMonsters() async {
    final response = await http.get(Uri.parse("$baseUrl/get_monsters.php"));
    final list = _parseListResponse(response, 'data');
    return list.map((e) => Monster.fromJson(e)).toList();
  }

  static Future<String?> uploadMonsterImage(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/upload_monster_image.php"),
    );
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response        = await http.Response.fromStream(streamedResponse);
    final data            = _parseResponse(response);

    if (data["success"] == true) {
      return data["image_url"]?.toString();
    } else {
      throw Exception(data["message"] ?? "Image upload failed");
    }
  }

  static Future<Map<String, dynamic>> updateMonster({
    required int    monsterId,
    required String monsterName,
    required String monsterType,
    required double spawnLatitude,
    required double spawnLongitude,
    required num    spawnRadiusMeters,   // num accepts both int 0 and double
    String? pictureUrl,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/update_monster.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "monster_id":          monsterId,
        "monster_name":        monsterName,
        "monster_type":        monsterType,
        "spawn_latitude":      spawnLatitude,
        "spawn_longitude":     spawnLongitude,
        "spawn_radius_meters": spawnRadiusMeters,
        "picture_url":         pictureUrl ?? "",
      }),
    );
    return _parseResponse(response);
  }

  static Future<Map<String, dynamic>> deleteMonster({
    required int monsterId,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/delete_monster.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"monster_id": monsterId}),
    );
    return _parseResponse(response);
  }

  // ════════════════════════════════════════════════════════════
  // PLAYER APIs
  // ════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> loginPlayer({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login_player.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"username": username, "password": password}),
    );
    return _parseResponse(response);
  }

  static Future<Map<String, dynamic>> addPlayer({
    required String playerName,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/add_player.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "player_name": playerName,
        "username":    username,
        "password":    password,
      }),
    );
    return _parseResponse(response);
  }

  static Future<List<Player>> getPlayers() async {
    final response = await http.get(Uri.parse("$baseUrl/get_players.php"));
    final list = _parseListResponse(response, 'data');
    return list.map((e) => Player.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> updatePlayer({
    required int    playerId,
    required String playerName,
    required String username,
    String? newPassword,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/update_player.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "player_id":    playerId,
        "player_name":  playerName,
        "username":     username,
        "new_password": newPassword ?? "",
      }),
    );
    return _parseResponse(response);
  }

  static Future<Map<String, dynamic>> deletePlayer({
    required int playerId,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/delete_player.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"player_id": playerId}),
    );
    return _parseResponse(response);
  }

  // ════════════════════════════════════════════════════════════
  // RANKINGS API
  // ════════════════════════════════════════════════════════════

  static Future<List<PlayerRanking>> getPlayerRankings() async {
    final response =
        await http.get(Uri.parse("$baseUrl/get_player_rankings.php"));
    final list = _parseListResponse(response, 'data');
    return list.map((e) => PlayerRanking.fromJson(e)).toList();
  }

  // ════════════════════════════════════════════════════════════
  // CATCH MONSTER API
  // ════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════
  // PROFESSOR'S API — registration / login / catches / hunters
  // ════════════════════════════════════════════════════════════

  /// Register a new player via the remote MySQL API.
  static Future<Map<String, dynamic>> register(
      String playerName, String username, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "player_name": playerName,
        "username":    username,
        "password":    password,
      }),
    );
    return _parseResponse(response);
  }

  /// Login a player via the remote MySQL API.
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "password": password,
      }),
    );
    return _parseResponse(response);
  }

  /// Log a monster catch to monster_catchestbl (professor's endpoint).
  /// location_id is created server-side by catch_monster.php automatically;
  /// use this endpoint only if you need to log a catch separately.
  static Future<Map<String, dynamic>> addMonsterCatch({
    required String playerId,
    required String monsterId,
    required String locationId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/add_monster_catch.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "player_id":   playerId,
        "monster_id":  monsterId,
        "location_id": locationId,
        "latitude":    latitude,
        "longitude":   longitude,
      }),
    );
    return _parseResponse(response);
  }

  /// Fetch the Top 10 monster hunters — professor's endpoint (on server).
  /// Note: filename typo "monter" is intentional — that is what the prof uploaded.
  static Future<Map<String, dynamic>> getTopHunters() async {
    final response = await http.get(
      Uri.parse("$baseUrl/top_monter_hunters.php"),
    );
    return _parseResponse(response);
  }

  // ════════════════════════════════════════════════════════════
  // CATCH MONSTER API
  // ════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> catchMonster({
    required int    playerId,
    required int    monsterId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/catch_monster.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "player_id":  playerId,
        "monster_id": monsterId,
        "latitude":   latitude,
        "longitude":  longitude,
      }),
    );
    return _parseResponse(response);
  }
}