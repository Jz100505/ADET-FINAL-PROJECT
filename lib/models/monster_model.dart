class Monster {
  final int monsterId;
  final String monsterName;
  final String monsterType;
  final double spawnLatitude;
  final double spawnLongitude;
  final double spawnRadiusMeters;
  final String? pictureUrl;

  Monster({
    required this.monsterId,
    required this.monsterName,
    required this.monsterType,
    required this.spawnLatitude,
    required this.spawnLongitude,
    required this.spawnRadiusMeters,
    this.pictureUrl,
  });

  factory Monster.fromJson(Map<String, dynamic> json) {
    return Monster(
      monsterId: int.tryParse(json['monster_id'].toString()) ?? 0,
      monsterName: json['monster_name']?.toString() ?? '',
      monsterType: json['monster_type']?.toString() ?? '',
      spawnLatitude: double.tryParse(json['spawn_latitude'].toString()) ?? 0.0,
      spawnLongitude:
          double.tryParse(json['spawn_longitude'].toString()) ?? 0.0,
      spawnRadiusMeters:
          double.tryParse(json['spawn_radius_meters'].toString()) ?? 0.0,
      pictureUrl: json['picture_url']?.toString(),
    );
  }
}
