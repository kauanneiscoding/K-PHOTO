import 'package:flutter/material.dart';
import 'dart:math';
import 'data_storage_service.dart';
import 'widgets/animated_photocard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_service.dart';
import 'main.dart';
import 'services/frame_service.dart';

class StorePage extends StatefulWidget {
  final DataStorageService dataStorageService;

  const StorePage({Key? key, required this.dataStorageService})
      : super(key: key);

  @override
  _StorePageState createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  List<String>? _revealedPhotocards;
  List<String> _ownedFrames = []; // 1️⃣ Lista local para molduras compradas
  late BuildContext _pageContext; // Referência segura ao contexto da página
  int _gridKey = 0; // Chave numérica para forçar reconstrução

  @override
  void initState() {
    super.initState();
    // Inicializa o FrameService com o ID do usuário atual
    final userId = widget.dataStorageService.getCurrentUserId();
    if (userId != null) {
      FrameService.setCurrentUserId(userId);
    }
    _loadFrames(); // 2️⃣ Carrega as molduras compradas
  }

  Future<void> _loadFrames() async {
    print('StorePage: Carregando molduras compradas...');
    final frames = await FrameService.getPurchasedFrames();
    print('StorePage: ${frames.length} molduras encontradas no banco');
    setState(() {
      _ownedFrames = frames;
      print('StorePage: Lista local atualizada com ${_ownedFrames.length} itens: $_ownedFrames');
    });
  }

  @override
  Widget build(BuildContext context) {
    _pageContext = context; // Salva referência segura ao contexto
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
                          builder: (context) => FramesShopPage(
                            ownedFrames: _ownedFrames,
                            onFramePurchased: (framePath) {
                              setState(() {
                                _ownedFrames.add(framePath);
                                _gridKey++;
                              });
                            },
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
      builder: (dialogContext) => MysteryBoxDialog(
        dataStorageService: widget.dataStorageService,
        storePageContext: context,  // Passa o contexto da StorePage, não do diálogo
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

  // Método auxiliar para processar compra de moldura
  Future<void> _purchaseFrame(int frameIndex, int price, bool useStarCoins, BuildContext context) async {
    try {
      // 1. Salva no banco
      if (useStarCoins) {
        await CurrencyService.spendStarCoins(price);
      } else {
        await CurrencyService.spendKCoins(price);
      }
      
      await FrameService.purchaseFrame('assets/frame/frame_${frameIndex + 1}.png');

      // 4️⃣ Quando comprar: atualiza a lista local diretamente
      if (mounted) {
        setState(() {
          _ownedFrames.add('assets/frame/frame_${frameIndex + 1}.png');
          _gridKey++; // Incrementa chave para forçar reconstrução do GridView
        });
      }

      // Verificação segura antes de usar o ScaffoldMessenger
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moldura comprada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Verificação segura antes de mostrar erro
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao comprar moldura: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
  final BuildContext? storePageContext;

  const MysteryBoxDialog({
    Key? key,
    required this.dataStorageService,
    this.storePageContext,
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
            print('MysteryBoxDialog: Botão Abrir pressionado');
            Navigator.pop(context);
            // Chama o método sem await - o contexto ainda é válido neste momento
            if (widget.storePageContext != null) {
              _openMysteryBox(widget.storePageContext!);
            }
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
  print('MysteryBoxDialog: _openMysteryBox chamado');
  try {
    final currentKCoins = await CurrencyService.getKCoins();
    if (currentKCoins < 300) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('K-coins insuficientes! Você precisa de 300 K-coins.'),
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
      print('StorePage: Processando card $i');
      int cardNumber = random.nextInt(102) + 1;
      String cardPath = _getPhotocardPath(cardNumber);
      newPhotocards.add(cardPath);
      print('StorePage: Card $i gerado: $cardPath');

      bool addedToSharedPile =
          await widget.dataStorageService.addToSharedPile(cardPath);
      print('StorePage: Card $i adicionado ao shared pile: $addedToSharedPile');
      if (addedToSharedPile) {
        addedToMount.add(cardPath);
      } else {
        addedToBackpack.add(cardPath);
      }
    }

    print('StorePage: Loop concluído. Total cards: ${newPhotocards.length}');
    print('StorePage: Mostrando diálogo de revelação (sem verificar mounted)...');

    // Mostra o diálogo de revelação - o contexto da StorePage ainda é válido
    print('StorePage: Photocards para revelar: ${newPhotocards.length}');
    print('StorePage: Tentando mostrar showDialog...');
    
    try {
      await showDialog(
        context: context,  // Usa o contexto passado como parâmetro
        barrierDismissible: true,  // Permite fechar clicando fora
        builder: (dialogContext) {
          print('StorePage: Criando RevealDialog...');
          return RevealDialog(
            photocards: newPhotocards,
            dataStorageService: widget.dataStorageService,
          );
        },
      );
      print('StorePage: showDialog concluído');
    } catch (e) {
      print('StorePage: Erro no showDialog: $e');
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

  @override
  void initState() {
    super.initState();
    print('RevealDialog: initState chamado com ${widget.photocards.length} cards');
  }

  void _onCardRevealed(String photocard) {
    print('RevealDialog: Card revelado: $photocard');
    setState(() {
      _revealedCards.add(photocard);
    });
    
    // Mostra mensagem de sucesso quando todos os cards forem revelados
    if (_revealedCards.length == widget.photocards.length) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Parabéns! Você ganhou ${widget.photocards.length} photocards!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('RevealDialog: build chamado');
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
                    'Revelando seus photocards!',
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
                print('RevealDialog: Criando AnimatedPhotocard para $photocard');
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

// Página separada para a loja de molduras
class FramesShopPage extends StatefulWidget {
  final List<String> ownedFrames;
  final Function(String) onFramePurchased;

  const FramesShopPage({
    Key? key,
    required this.ownedFrames,
    required this.onFramePurchased,
  }) : super(key: key);

  @override
  State<FramesShopPage> createState() => _FramesShopPageState();
}

class _FramesShopPageState extends State<FramesShopPage> {
  int _gridKey = 0;

  Future<void> _purchaseFrame(int frameIndex, int price, bool useStarCoins, BuildContext context) async {
    try {
      // 1. Salva no banco
      if (useStarCoins) {
        await CurrencyService.spendStarCoins(price);
      } else {
        await CurrencyService.spendKCoins(price);
      }
      
      await FrameService.purchaseFrame('assets/frame/frame_${frameIndex + 1}.png');

      // 2. Atualiza estado local e notifica página principal
      if (mounted) {
        setState(() {
          _gridKey++;
        });
        
        // Notifica a StorePage sobre a compra
        widget.onFramePurchased('assets/frame/frame_${frameIndex + 1}.png');
      }

      // Verificação segura antes de usar o ScaffoldMessenger
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moldura comprada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao comprar moldura: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Loja de Molduras'),
      ),
      body: GridView.builder(
        key: ValueKey(_gridKey), // Força reconstrução com chave numérica
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          // Calcular preço: 50 star-coins para molduras 1, 4, 5; 100*(index+1) k-coins para outras
          final frameNumber = index + 1;
          final useStarCoins = (frameNumber == 1 || frameNumber == 4 || frameNumber == 5);
          final price = useStarCoins ? 50 : (100 * frameNumber);
          
          // Verificação direta na lista local
          bool isPurchased = widget.ownedFrames.contains(
            'assets/frame/frame_${index + 1}.png'
          );
          
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        useStarCoins ? 'assets/starcoin.png' : 'assets/kcoin.png',
                        width: 20,
                        height: 20,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '$price',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.pink[300],
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (await (useStarCoins 
                          ? CurrencyService.hasEnoughStarCoins(price)
                          : CurrencyService.hasEnoughKCoins(price))) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('Confirmar compra'),
                              content: Text('Deseja comprar esta moldura por $price ${useStarCoins ? "star-coins" : "k-coins"}?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _purchaseFrame(index, price, useStarCoins, context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.pink[300],
                                  ),
                                  child: Text('Confirmar'),
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Saldo insuficiente!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[300],
                      padding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      'Comprar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ] else
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
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
      ),
    );
  }
}
