class NinjaSound {
  final String name;
  final String category;
  final dynamic icon; // IconData | String (emoji or http URL)
  final String path;
  final bool isUserAdded;
  final double
      volumeMultiplier; // Volume adjustment (1.0 = normal, >1.0 = louder)

  NinjaSound({
    required this.name,
    required this.category,
    required this.icon,
    required this.path,
    this.isUserAdded = false,
    this.volumeMultiplier = 1.0,
  });

  static NinjaSound empty =
      NinjaSound(path: '', name: '', category: '', icon: '');

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'icon': icon is String ? icon as String : '',
        'path': path,
        'isUserAdded': isUserAdded,
        'volumeMultiplier': volumeMultiplier,
      };

  factory NinjaSound.fromJson(Map<String, dynamic> json) => NinjaSound(
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        icon: json['icon'] as String? ?? '📻',
        path: json['path'] as String? ?? '',
        isUserAdded: json['isUserAdded'] as bool? ?? true,
        volumeMultiplier: (json['volumeMultiplier'] as num?)?.toDouble() ?? 1.0,
      );
}

extension NinjaSoundType on NinjaSound {
  bool get isStream => path.startsWith('http');
  bool get isBinaural => path.contains('binaural');
  bool get isNoise => path.contains('noise');
}
