import 'package:flutter/material.dart';
import 'dart:math';
import 'data_storage_service.dart';
import 'widgets/animated_photocard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_service.dart';
import 'main.dart';

class StorePage extends StatefulWidget {
  final DataStorageService dataStorageService;

  const StorePage({Key? key, required this.dataStorageService})
      : super(key: key);

  @override
  _StorePageState createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  List<String>? _revealedPhotocards;
  late Future<List<String>> _framesFuture;

  @override
  void initState() {
    super.initState();
    _framesFuture = widget.dataStorageService.getPurchasedFrames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Loja',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[300],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Itens em Destaque',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
                children: [
                  // Caixa Misteriosa
                  StoreItem(
                    title: 'Caixa Misteriosa',
                    description: '3 Photocards Aleatórios',
                    price: 300,
                    icon: Icons.card_giftcard,
                    onTap: () => _showMysteryBoxDialog(context),
                    dataStorageService: widget.dataStorageService,
                  ),
                  // Outros itens futuros
                  StoreItem(
                    title: 'Pacote Premium',
                    description: 'Em breve',
                    price: 1000,
                    icon: Icons.star,
                    isComingSoon: true,
                    dataStorageService: widget.dataStorageService,
                  ),
                  StoreItem(
                    title: 'Álbum Especial',
                    description: 'Em breve',
                    price: 800,
                    icon: Icons.photo_album,
                    isComingSoon: true,
                    dataStorageService: widget.dataStorageService,
                  ),
                  // Molduras (agora com redirecionamento)
                  StoreItem(
                    title: 'Molduras',
                    description: 'Personalize seu perfil',
                    price: 0,
                    icon: Icons.crop_original,
                    isComingSoon: false,
                    showViewButton: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: Text('Loja de Molduras'),
                            ),
                            body: GridView.builder(
                              padding: EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: 4,
                              itemBuilder: (context, index) {
                                return FutureBuilder<bool>(
                                  future: widget.dataStorageService
                                      .isFramePurchased(
                                          'assets/frame/frame_${index + 1}.png'),
                                  builder: (context, snapshot) {
                                    final bool isPurchased =
                                        snapshot.data ?? false;

                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/frame/frame_${index + 1}.png',
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.contain,
                                          ),
                                          SizedBox(height: 8),
                                          if (!isPurchased) ...[
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Image.asset(
                                                  'assets/kcoin.png',
                                                  width: 20,
                                                  height: 20,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '${100 * (index + 1)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.pink[300],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                if (await CurrencyService
                                                    .hasEnoughKCoins(
                                                        100 * (index + 1))) {
                                                  showDialog(
                                                    context: context,
                                                    builder:
                                                        (BuildContext context) {
                                                      return AlertDialog(
                                                        title: Text(
                                                            'Confirmar compra'),
                                                        content: Text(
                                                            'Deseja comprar esta moldura por ${100 * (index + 1)} K-coins?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                            child: Text(
                                                                'Cancelar'),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed:
                                                                () async {
                                                              await CurrencyService
                                                                  .spendKCoins(100 *
                                                                      (index +
                                                                          1));
                                                              await widget
                                                                  .dataStorageService
                                                                  .addPurchasedFrame(
                                                                      'assets/frame/frame_${index + 1}.png');

                                                              // Fecha o diálogo de confirmação
                                                              Navigator.pop(
                                                                  context);

                                                              // Força uma reconstrução do FutureBuilder
                                                              if (mounted) {
                                                                setState(() {
                                                                  // Atualiza o Future para recarregar o estado das molduras
                                                                  _framesFuture = widget
                                                                      .dataStorageService
                                                                      .getPurchasedFrames();
                                                                });
                                                              }

                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      'Moldura comprada com sucesso!'),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .green,
                                                                ),
                                                              );
                                                            },
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  Colors.pink[
                                                                      300],
                                                            ),
                                                            child: Text(
                                                                'Confirmar'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Saldo insuficiente!'),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.pink[300],
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 16),
                                              ),
                                              child: Text(
                                                'Comprar',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ] else
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.green[100],
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                'Obtido',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    dataStorageService: widget.dataStorageService,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMysteryBoxDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => MysteryBoxDialog(
        dataStorageService: widget.dataStorageService,
      ),
    );
  }

  Future<void> _updateBalance() async {
    // Atualiza o saldo e força uma reconstrução
    if (mounted) {
      setState(() {});
      // Volta para a HomePage para atualizar o saldo
      Navigator.pop(context);
    }
  }

  void _refreshFrameState() {
    if (mounted) {
      setState(() {
        // Força uma reconstrução do widget
      });
    }
  }
}

class StoreItem extends StatelessWidget {
  final String title;
  final String description;
  final int price;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isComingSoon;
  final bool showViewButton;
  final DataStorageService dataStorageService;

  const StoreItem({
    Key? key,
    required this.title,
    required this.description,
    required this.price,
    required this.icon,
    required this.dataStorageService,
    this.onTap,
    this.isComingSoon = false,
    this.showViewButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isComingSoon ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 50,
              color: isComingSoon ? Colors.grey : Colors.pink[300],
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isComingSoon ? Colors.grey : Colors.pink[300],
              ),
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            if (!isComingSoon && !showViewButton)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/kcoin.png',
                    width: 20,
                    height: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '$price',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink[300],
                    ),
                  ),
                ],
              ),
            if (!isComingSoon && showViewButton)
              Text(
                'Ver',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[300],
                ),
              ),
            if (isComingSoon)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Em Breve',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Altere a classe MysteryBoxDialog para ser StatefulWidget
class MysteryBoxDialog extends StatefulWidget {
  final DataStorageService dataStorageService;

  const MysteryBoxDialog({
    Key? key,
    required this.dataStorageService,
  }) : super(key: key);

  @override
  State<MysteryBoxDialog> createState() => _MysteryBoxDialogState();
}

class _MysteryBoxDialogState extends State<MysteryBoxDialog> {
  List<String>? _revealedPhotocards;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Stack(
        children: [
          Center(
            child: Text('Caixa Misteriosa'),
          ),
          Positioned(
            right: -8,
            top: -8,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.grey[600]),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/mystery_box.png',
            height: 100,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.card_giftcard,
              size: 100,
              color: Colors.pink[300],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Deseja abrir a caixa misteriosa por 300 K-coins?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Você receberá 3 photocards aleatórios!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _openMysteryBox(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink[300],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/kcoin.png',
                width: 20,
                height: 20,
              ),
              SizedBox(width: 8),
              Text('300'),
              SizedBox(width: 8),
              Text('Abrir'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _updateBalance() async {
    final kCoins = await CurrencyService.getKCoins();
    final starCoins = await CurrencyService.getStarCoins();

    if (mounted) {
      setState(() {
        // O saldo será atualizado automaticamente quando voltar para a HomePage
      });
    }
  }

  Future<void> _openMysteryBox(BuildContext context) async {
    try {
      final currentKCoins = await CurrencyService.getKCoins();
      if (currentKCoins < 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('K-coins insuficientes! Você precisa de 300 K-coins.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await CurrencyService.spendKCoins(300);

      // Sorteia 3 photocards
      List<String> newPhotocards = [];
      Random random = Random();
      List<String> addedToMount = [];
      List<String> addedToBackpack = [];

      for (int i = 0; i < 3; i++) {
        int cardNumber = random.nextInt(102) + 1;
        String cardPath = _getPhotocardPath(cardNumber);
        newPhotocards.add(cardPath);

        bool addedToSharedPile =
            await widget.dataStorageService.addToSharedPile(cardPath);
        if (addedToSharedPile) {
          addedToMount.add(cardPath);
        } else {
          addedToBackpack.add(cardPath);
        }
      }

      // Mostra o diálogo de revelação
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => RevealDialog(
            photocards: newPhotocards,
            dataStorageService: widget.dataStorageService,
          ),
        );
      }
    } catch (e) {
      print('Erro ao abrir caixa misteriosa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir a caixa misteriosa'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getPhotocardPath(int cardNumber) {
    if (cardNumber >= 1 && cardNumber <= 102) {
      return 'assets/photocards/photocard$cardNumber.png';
    } else {
      throw ArgumentError('Invalid photocard number: $cardNumber');
    }
  }
}

// Modifique apenas a classe RevealDialog
class RevealDialog extends StatefulWidget {
  final List<String> photocards;
  final DataStorageService dataStorageService;

  const RevealDialog({
    Key? key,
    required this.photocards,
    required this.dataStorageService,
  }) : super(key: key);

  @override
  State<RevealDialog> createState() => _RevealDialogState();
}

class _RevealDialogState extends State<RevealDialog> {
  final Set<String> _revealedCards = {};
  bool _showCloseButton = true;

  void _onCardRevealed(String photocard) {
    setState(() {
      _revealedCards.add(photocard);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9;
    final availableWidth = dialogWidth - 48; // Espaço para padding e margens
    final cardWidth = (availableWidth / 3) -
        16; // Divide por 3 cards e deixa espaço entre eles
    final cardHeight = cardWidth * 1.5; // Mantém a proporção

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Center(
                  child: Text(
                    'Toque nas cartas para revelar!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.grey[600],
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widget.photocards.map((photocard) {
                return SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: AnimatedPhotocard(
                    imageUrl: photocard,
                    onFlipComplete: () => _onCardRevealed(photocard),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
