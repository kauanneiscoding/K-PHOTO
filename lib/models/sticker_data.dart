// lib/models/sticker_data.dart

class StickerData {
  final String id;
  final String imagePath;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  StickerData({
    required this.id,
    required this.imagePath,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'image_path': imagePath,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
      };

  factory StickerData.fromMap(Map<String, dynamic> map) => StickerData(
        id: map['id'],
        imagePath: map['image_path'],
        x: map['x']?.toDouble() ?? 0.0,
        y: map['y']?.toDouble() ?? 0.0,
        scale: map['scale']?.toDouble() ?? 1.0,
        rotation: map['rotation']?.toDouble() ?? 0.0,
      );
}
