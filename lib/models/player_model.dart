class Player {
  final int playerId;
  final String playerName;
  final String username;
  final String password;
  final String? createdAt;

  Player({
    required this.playerId,
    required this.playerName,
    required this.username,
    required this.password,
    this.createdAt,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      playerId: int.tryParse(json['player_id'].toString()) ?? 0,
      playerName: json['player_name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'player_id': playerId,
      'player_name': playerName,
      'username': username,
      'password': password,
      'created_at': createdAt,
    };
  }
}