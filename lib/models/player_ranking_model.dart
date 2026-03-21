class PlayerRanking {
  final int playerId;
  final String playerName;
  final int catchCount;

  PlayerRanking({
    required this.playerId,
    required this.playerName,
    required this.catchCount,
  });

  factory PlayerRanking.fromJson(Map<String, dynamic> json) {
    return PlayerRanking(
      playerId: int.tryParse(json['player_id'].toString()) ?? 0,
      playerName: json['player_name']?.toString() ?? '',
      catchCount: int.tryParse(json['catch_count'].toString()) ?? 0,
    );
  }
}
