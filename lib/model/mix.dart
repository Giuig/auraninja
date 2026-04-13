class Mix {
  final String id;
  final String name;
  final String? icon;
  final List<MixSound> sounds;
  final DateTime createdAt;

  Mix({
    required this.id,
    required this.name,
    this.icon,
    required this.sounds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'sounds': sounds.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Mix.fromJson(Map<String, dynamic> json) => Mix(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String?,
        sounds: (json['sounds'] as List)
            .map((s) => MixSound.fromJson(s as Map<String, dynamic>))
            .toList(),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );
}

class MixSound {
  final String path;
  final double volume;

  MixSound({required this.path, this.volume = 0.5});

  Map<String, dynamic> toJson() => {
        'path': path,
        'volume': volume,
      };

  factory MixSound.fromJson(Map<String, dynamic> json) => MixSound(
        path: json['path'] as String,
        volume:
            json['volume'] != null ? (json['volume'] as num).toDouble() : 0.5,
      );

  bool get isStream => path.startsWith('http');
}
