import 'package:flutter/material.dart';
import 'data_storage_service.dart';

class BackpackPage extends StatefulWidget {
  final DataStorageService dataStorageService;

  const BackpackPage({
    Key? key,
    required this.dataStorageService,
  }) : super(key: key);

  @override
  State<BackpackPage> createState() => _BackpackPageState();
}

class _BackpackPageState extends State<BackpackPage> {
  late Future<Map<String, int>> _backpackCardsFuture;

  @override
  void initState() {
    super.initState();
    _backpackCardsFuture =
        widget.dataStorageService.getBackpackPhotocardsCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mochila',
          style: TextStyle(color: Colors.pink[300]),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _backpackCardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'Sua mochila está vazia',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            );
          }

          // Agrupa os cards repetidos
          final groupedCards = snapshot.data!;

          return GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.7,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: groupedCards.length,
            itemBuilder: (context, index) {
              final cardPath = groupedCards.keys.elementAt(index);
              final count = groupedCards[cardPath] ?? 0;

              return Stack(
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        cardPath,
                        fit: BoxFit.cover,
                      ),
                    ),
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
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'x$count',
                          style: TextStyle(
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
          );
        },
      ),
    );
  }
}
