import 'package:flutter/material.dart';
import '../models/sticker_sheet.dart';

class StickerSheetView extends StatefulWidget {
  final StickerSheet sheet;
  final Function(Sticker) onStickerPeel;

  const StickerSheetView({
    Key? key,
    required this.sheet,
    required this.onStickerPeel,
  }) : super(key: key);

  @override
  State<StickerSheetView> createState() => _StickerSheetViewState();
}

class _StickerSheetViewState extends State<StickerSheetView> {
  Map<String, bool> peelProgress = {};
  Map<String, Offset> dragStart = {};

  @override
  void initState() {
    super.initState();
    for (var sticker in widget.sheet.stickers) {
      peelProgress[sticker.id] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: widget.sheet.stickers.map((sticker) {
          if (sticker.isUsed) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(Icons.check, color: Colors.grey[400]),
              ),
            );
          }

          return GestureDetector(
            onPanStart: (details) {
              dragStart[sticker.id] = details.localPosition;
              setState(() {
                peelProgress[sticker.id] = true;
              });
            },
            onPanUpdate: (details) {
              if (!peelProgress[sticker.id]!) return;

              final dragDistance =
                  (details.localPosition - dragStart[sticker.id]!).distance;
              if (dragDistance > 50) {
                widget.onStickerPeel(sticker);
                setState(() {
                  sticker.isUsed = true;
                  peelProgress[sticker.id] = false;
                });
              }
            },
            onPanEnd: (details) {
              setState(() {
                peelProgress[sticker.id] = false;
              });
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(peelProgress[sticker.id]! ? 0.2 : 0.0)
                ..rotateY(peelProgress[sticker.id]! ? 0.2 : 0.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: peelProgress[sticker.id]!
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          offset: Offset(2, 2),
                        )
                      ]
                    : null,
              ),
              child: Image.asset(
                sticker.imagePath,
                fit: BoxFit.contain,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
