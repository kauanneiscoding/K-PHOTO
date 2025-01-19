import 'package:flutter/material.dart';
import '../models/sticker_sheet.dart';
import '../data_storage_service.dart';
import '../currency_service.dart';
import '../pages/sticker_sheet_page.dart';

class PurchaseStickerSheetDialog extends StatelessWidget {
  final StickerSheet sheet;
  final DataStorageService dataStorageService;
  final VoidCallback onPurchase;

  const PurchaseStickerSheetDialog({
    Key? key,
    required this.sheet,
    required this.dataStorageService,
    required this.onPurchase,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sheet.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.pink[300],
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: sheet.stickers.map((sticker) {
                  return Image.asset(
                    sticker.imagePath,
                    fit: BoxFit.contain,
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  '${sheet.price}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (await CurrencyService.hasEnoughStarCoins(sheet.price)) {
                  await CurrencyService.spendStarCoins(sheet.price);

                  // Adiciona os stickers à lista de comprados
                  for (var sticker in sheet.stickers) {
                    await dataStorageService
                        .addPurchasedSticker(sticker.imagePath);
                  }

                  onPurchase();
                  Navigator.pop(context);

                  // Abre a cartela
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StickerSheetPage(
                        sheet: sheet,
                        onStickerApplied: (sticker) async {
                          // Aqui você pode adicionar lógica adicional quando o sticker for aplicado
                        },
                      ),
                    ),
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cartela comprada com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Star-Coins insuficientes!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[300],
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(
                'Comprar Cartela',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
