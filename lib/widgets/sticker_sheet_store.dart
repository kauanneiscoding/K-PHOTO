import 'package:flutter/material.dart';
import '../data_storage_service.dart';
import '../models/sticker_sheet.dart';
import 'purchase_sticker_sheet_dialog.dart';

class StickerSheetStore extends StatelessWidget {
  final DataStorageService dataStorageService;
  final VoidCallback onPurchase;
  final List<StickerSheet> availableSheets = [
    StickerSheet(
      id: '1',
      name: 'Cartela Básica',
      price: 50,
      stickers: [
        Sticker(id: '1', imagePath: 'assets/sticker/sticker1.png'),
        Sticker(id: '2', imagePath: 'assets/sticker/sticker2.png'),
        Sticker(id: '3', imagePath: 'assets/sticker/sticker3.png'),
      ],
    ),
    StickerSheet(
      id: '2',
      name: 'Cartela Premium',
      price: 100,
      stickers: [
        Sticker(id: '4', imagePath: 'assets/sticker/sticker4.png'),
        Sticker(id: '5', imagePath: 'assets/sticker/sticker5.png'),
        Sticker(id: '6', imagePath: 'assets/sticker/sticker6.png'),
      ],
    ),
  ];

  StickerSheetStore({
    Key? key,
    required this.dataStorageService,
    required this.onPurchase,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        return StickerSheetCard(
          sheet: availableSheets[index],
          onTap: () => _showPurchaseDialog(context, availableSheets[index]),
        );
      },
      itemCount: availableSheets.length,
    );
  }

  void _showPurchaseDialog(BuildContext context, StickerSheet sheet) {
    showDialog(
      context: context,
      builder: (context) => PurchaseStickerSheetDialog(
        sheet: sheet,
        dataStorageService: dataStorageService,
        onPurchase: onPurchase,
      ),
    );
  }
}

class StickerSheetCard extends StatelessWidget {
  final StickerSheet sheet;
  final VoidCallback onTap;

  const StickerSheetCard({
    Key? key,
    required this.sheet,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              sheet.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  '${sheet.price}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: sheet.stickers.map((sticker) {
                return Image.asset(
                  sticker.imagePath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
