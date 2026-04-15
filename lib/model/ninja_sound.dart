import 'package:auraninja/model/sound_category.dart';

class NinjaSound {
  final String name;
  final String category;
  final dynamic icon; // IconData | String (emoji or http URL)
  final String path;
  final bool isUserAdded;

  NinjaSound({
    required this.name,
    required this.category,
    required this.icon,
    required this.path,
    this.isUserAdded = false,
  });

  static NinjaSound empty =
      NinjaSound(path: '', name: '', category: '', icon: '');

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'icon': icon is String ? icon as String : '',
        'path': path,
        'isUserAdded': isUserAdded,
      };

  factory NinjaSound.fromJson(Map<String, dynamic> json) => NinjaSound(
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        icon: json['icon'] as String? ?? '📻',
        path: json['path'] as String? ?? '',
        isUserAdded: json['isUserAdded'] as bool? ?? true,
      );
}

extension NinjaSoundType on NinjaSound {
  bool get isStream => path.startsWith('http');
  bool get isBinaural => category == SoundCategory.binaural;
  bool get isNoise => category == SoundCategory.noise;
  bool get isExclusive => SoundCategory.exclusive.contains(category);
}
