import 'package:flutter/material.dart';
import 'data_storage_service.dart';

class BackpackDialog extends StatefulWidget {
  final DataStorageService dataStorageService;
  final VoidCallback onMountUpdated;

  const BackpackDialog({
    Key? key,
    required this.dataStorageService,
    required this.onMountUpdated,
  }) : super(key: key);

  @override
  State<BackpackDialog> createState() => _BackpackDialogState();
}

class _BackpackDialogState extends State<BackpackDialog> {
  late Future<List<Map<String, String>>> _backpackCardsFuture;
  late Future<Map<String, List<String>>> _cardCountsFuture;

  @override
  void initState() {
    super.initState();
    _refreshBackpack();
  }

  void _refreshBackpack() {
    _backpackCardsFuture = widget.dataStorageService.getAvailablePhotocards();
    _cardCountsFuture = widget.dataStorageService.getBackpackPhotocardsCount();

    // Log detailed information about backpack cards
    _backpackCardsFuture.then((cards) {
      print('🎒 Backpack Cards Loaded:');
      print('Total Cards: ${cards.length}');
      for (var card in cards) {
        print('📸 Card Details:');
        print('  Instance ID: ${card['instance_id']}');
        print('  Image Path: ${card['image_path']}');
      }
    }).catchError((error) {
      print('❌ Error loading backpack cards: $error');
    });

    // Log detailed information about card counts
    _cardCountsFuture.then((counts) {
      print('🔢 Card Counts:');
      counts.forEach((imagePath, instances) {
        print('📊 Image: $imagePath');
        print('   Count: ${instances.length}');
        print('   Instance IDs: ${instances.join(", ")}');
      });
    }).catchError((error) {
      print('❌ Error loading card counts: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mochila',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink[300],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: () {
                        setState(() {
                          _refreshBackpack();
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, String>>>(
              future: _backpackCardsFuture,
              builder: (context, cardsSnapshot) {
                if (cardsSnapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                if (!cardsSnapshot.hasData || cardsSnapshot.data!.isEmpty) {
                  return const Text('Nenhum photocard na mochila');
                }

                return FutureBuilder<Map<String, List<String>>>(
                  future: _cardCountsFuture,
                  builder: (context, countsSnapshot) {
                    if (!countsSnapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final cardCounts = countsSnapshot.data!;
                    final cards = cardsSnapshot.data!;

                    return Flexible(
                      child: Column(
                        children: [
                          // Lista de cards da mochila
                          Expanded(
                            child: Stack(
                              children: [
                                GridView.builder(
                                  padding: EdgeInsets.only(right: 16),
                                  shrinkWrap: true,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.7,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: cards.length,
                                  itemBuilder: (context, index) {
                                    const double cardWidth = 141.0;
                                    const double cardHeight = 210.0;
                                    const double borderRadius = 15.0;

                                    final card = cards[index];
                                    final count =
                                        cardCounts[card['image_path']]?.length ??
                                            0;

                                    return Stack(
                                      children: [
                                        // Add null check for imagePath
                                        if (card['image_path'] != null) Draggable<Map<String, String>>(
                                          data: {
                                            ...card,
                                            'fromLocation': 'backpack',
                                          },
                                          feedback: Material(
                                            color: Colors.transparent,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      borderRadius),
                                              child: Image.asset(
                                                card['image_path']!,
                                                width: cardWidth,
                                                height: cardHeight,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  print('Error loading image: ${card['image_path']}');
                                                  return Container(
                                                    width: cardWidth,
                                                    height: cardHeight,
                                                    color: Colors.grey,
                                                    child: Icon(Icons.error, color: Colors.red),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                                borderRadius),
                                            child: Image.asset(
                                              card['image_path']!,
                                              width: cardWidth,
                                              height: cardHeight,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                print('Error loading image: ${card['image_path']}');
                                                return Container(
                                                  width: cardWidth,
                                                  height: cardHeight,
                                                  color: Colors.grey,
                                                  child: Icon(Icons.error, color: Colors.red),
                                                );
                                              },
                                            ),
                                          ),
                                        ) else Container(
                                          width: cardWidth,
                                          height: cardHeight,
                                          color: Colors.grey,
                                          child: Icon(Icons.error, color: Colors.red),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Colors.pink[300],
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                'x$count',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                Positioned(
                                  right: -1,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Container(
                                      width: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.pink[300],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Área do monte embaixo
                          Container(
                            margin: EdgeInsets.only(top: 16),
                            child: Column(
                              children: [
                                Text(
                                  'Jogue de volta para o monte',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.pink[300],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DragTarget<Map<String, String>>(
                                  onWillAccept: (data) => true,
                                  onAccept: (data) async {
                                    await widget.dataStorageService
                                        .moveCardBetweenBackpackAndPile(
                                      data['instance_id']!,
                                      data['fromLocation']!,
                                    );
                                    setState(() {
                                      _refreshBackpack();
                                    });
                                    widget.onMountUpdated();
                                  },
                                  builder:
                                      (context, candidateData, rejectedData) {
                                    return Container(
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.arrow_downward,
                                              color: Colors.grey[600],
                                              size: 32,
                                            ),
                                            Text(
                                              'Arraste aqui',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
