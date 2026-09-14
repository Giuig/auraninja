import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders a NinjaSound icon regardless of its type:
/// - [IconData] → [Icon]
/// - HTTP URL string → [CachedNetworkImage] with 📻 fallback
/// - Emoji/other string → [Text]
///
/// Used by both [SoundCard] and [NewMixSheet] so icon rendering
/// has a single point of change.
Widget buildSoundIcon(dynamic icon, double size, Color color) {
  if (icon is IconData) {
    return Icon(icon, size: size, color: color);
  }
  final str = icon as String? ?? '📻';
  if (str.startsWith('http')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: str,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) =>
            Text('📻', style: TextStyle(fontSize: size * 0.7)),
      ),
    );
  }
  return Center(
    child: Text(str, style: TextStyle(fontSize: size * 0.7, color: color)),
  );
}
