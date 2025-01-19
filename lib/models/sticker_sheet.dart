import 'package:flutter/material.dart';

class StickerSheet {
  final String id;
  final String name;
  final int price;
  final List<Sticker> stickers;

  StickerSheet({
    required this.id,
    required this.name,
    required this.price,
    required this.stickers,
  });
}

class Sticker {
  final String id;
  final String imagePath;
  bool isUsed;
  Offset position;

  Sticker({
    required this.id,
    required this.imagePath,
    this.isUsed = false,
    this.position = const Offset(0, 0),
  });
}
