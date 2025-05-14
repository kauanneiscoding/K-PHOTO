import 'package:flutter/material.dart';
import 'data_storage_service.dart'; // Importando o serviço de armazenamento de dados
import 'backpack_dialog.dart'; // Adicione esta linha
import 'dart:math' show pi;

class BinderPage extends StatefulWidget {
  final String binderId; // Identificação do binder, único para cada um
  final DataStorageService dataStorageService; // Adicione esta linha

  const BinderPage({
    Key? key,
    required this.binderId,
    required this.dataStorageService, // Adicione esta linha
  }) : super(key: key);

  @override
  _BinderPageState createState() => _BinderPageState();
}

class _BinderPageState extends State<BinderPage> with WidgetsBindingObserver {
  static const int TOTAL_PAGES = 5;
  static const double cardWidth = 75.0;
  static const double cardHeight = 115.0;
  static const double borderRadius = 8.0;

  late PageController _pageController;
  int currentPage = 0;
  double _dragPosition = 0.0;
  List<List<Map<String, String?>>> binderPages = List.generate(
    TOTAL_PAGES,
    (_) => List.generate(
      4,
      (index) => {'imagePath': null, 'instanceId': null},
    ),
  );
  List<Map<String, String>> cardDeck = [];
  int? selectedCardIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    print('Iniciando BinderPage - binderId: ${widget.binderId}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _saveCurrentState();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      print('Iniciando carregamento do binder ${widget.binderId}');
      await _loadBinderSlots();
      await _loadSharedPile();

      await widget.dataStorageService.printAllLocations();

      print(
          'Dados inicializados: ${binderPages.length} páginas, ${binderPages[currentPage].length} slots, ${cardDeck.length} cards no monte');
    } catch (e) {
      print('Erro ao inicializar dados: $e');
    }
  }

  Future<void> _loadBinderSlots() async {
    try {
      final slots =
          await widget.dataStorageService.loadBinderPhotocards(widget.binderId);
      print('Carregando slots do binder: ${slots.length} cards encontrados');

      if (mounted) {
        setState(() {
          // Reseta todos os slots de todas as páginas
          binderPages = List.generate(
            TOTAL_PAGES,
            (_) => List.generate(
              4,
              (index) => {'imagePath': null, 'instanceId': null},
            ),
          );

          // Preenche os slots com os dados do banco
          for (var slot in slots) {
            final pageNumber = slot['page_number'] as int? ?? 0;
            final slotIndex = slot['slot_index'] as int;
            if (pageNumber >= 0 &&
                pageNumber < TOTAL_PAGES &&
                slotIndex >= 0 &&
                slotIndex < 4) {
              binderPages[pageNumber][slotIndex] = {
                'imagePath': slot['image_path'] as String,
                'instanceId': slot['instance_id'] as String,
              };
              print(
                  'Slot $slotIndex da página $pageNumber carregado: ${slot['image_path']} (${slot['instance_id']})');
            }
          }
        });
      }
    } catch (e) {
      print('Erro ao carregar slots do binder: $e');
    }
  }

  Future<void> _loadSharedPile() async {
    try {
      final sharedPile = await widget.dataStorageService.getSharedPileCards();
      print('Monte compartilhado carregado: ${sharedPile.length} cards');

      // Converter List<Map<String, dynamic>> para List<Map<String, String>>
      final convertedPile = sharedPile.map((card) => {
        'imagePath': card['image_path'] as String,
        'instanceId': card['instance_id'] as String,
      }).toList();

      if (mounted) {
        setState(() {
          cardDeck = convertedPile;
        });
      }
    } catch (e) {
      print('Erro ao carregar monte compartilhado: $e');
    }
  }

  Future<void> _saveBinderSlot(int index, String? imagePath,
      {String? instanceId, int? pageNumber}) async {
    try {
      // Se não tiver instanceId e tiver imagePath, gera um novo
      if (instanceId == null && imagePath != null) {
        instanceId = await widget.dataStorageService.addToInventory(
          imagePath,
          'binder',
          binderId: widget.binderId,
          slotIndex: index,
          pageNumber: pageNumber ?? currentPage,
        );
      }

      // Só atualiza se tiver um instanceId
      if (instanceId != null) {
        await widget.dataStorageService.savePhotocardPosition(
          widget.binderId,
          pageNumber ?? currentPage,
          index,
          imagePath,
          instanceId: instanceId,
        );

        setState(() {
          binderPages[pageNumber ?? currentPage][index] = {
            'imagePath': imagePath,
            'instanceId': instanceId,
          };
        });

        await _refreshSharedPile();
        print('Slot $index da página ${pageNumber ?? currentPage} atualizado com sucesso');
      }
    } catch (e) {
      print('Erro ao salvar slot do binder: $e');
      rethrow;
    }
  }

  Future<void> _throwPhotocardToMount(int index, int pageIndex) async {
    final slotData = binderPages[pageIndex][index];
    final instanceId = slotData['instanceId'];

    if (instanceId != null) {
      try {
        // Move diretamente o card existente para o monte
        await widget.dataStorageService.updateCardLocation(
          instanceId,
          'shared_pile',
        );

        setState(() {
          binderPages[pageIndex][index] = {
            'imagePath': null,
            'instanceId': null,
          };
        });

        await _refreshSharedPile();
        print('📤 Photocard movido para o monte (ID: $instanceId)');
      } catch (e) {
        print('Erro ao mover photocard para o monte: $e');
      }
    }
  }

  Future<void> _onDrop(int index, Map<String, String> card) async {
    try {
      if (mounted) {
        // Remove o photocard do deck visualmente
        setState(() {
          cardDeck.removeWhere(
              (deckCard) => deckCard['instanceId'] == card['instanceId']);
        });

        // Atualiza o banco de dados
        final instanceId = card['instanceId'];
        if (instanceId != null) {
          await widget.dataStorageService.updateCardLocation(
            instanceId,
            'binder',
            binderId: widget.binderId,
            slotIndex: index,
          );
        }

        // Atualiza o slot visualmente
        setState(() {
          binderPages[currentPage][index] = {
            'imagePath': card['imagePath'],
            'instanceId': card['instanceId'],
          };
        });

        // Atualiza o monte após a mudança
        await _refreshSharedPile();

        print('Photocard movido com sucesso para o slot $index');
      }
    } catch (e) {
      print('Erro ao mover photocard: $e');
      if (mounted) {
        setState(() {
          cardDeck.add(card);
          binderPages[currentPage][index] = {
            'imagePath': null,
            'instanceId': null,
          };
        });
      }
    }
  }

  Future<void> _onSlotTap(int index) async {
    final instanceId = binderPages[currentPage][index]['instanceId'];

    if (instanceId != null) {
      try {
        await widget.dataStorageService.moveSpecificCardToPile(instanceId);

        setState(() {
          binderPages[currentPage][index] = {
            'imagePath': null,
            'instanceId': null,
          };
        });

        await _refreshSharedPile();
      } catch (e) {
        print('❌ Erro ao mover card do binder para o monte: $e');
      }
    }
  }

  Future<void> _onSharedCardTap(Map<String, dynamic> card) async {
    try {
      // Procura por um slot vazio na página atual
      final emptySlotIndex = binderPages[currentPage].indexWhere(
          (slot) => slot['imagePath'] == null);

      if (emptySlotIndex != -1) {
        // Move card para o slot vazio no Supabase
        await widget.dataStorageService.updateCardLocation(
          card['instance_id'],
          'binder',
          binderId: widget.binderId,
          pageNumber: currentPage,
          slotIndex: emptySlotIndex,
        );

        // Atualiza o estado local da UI
        setState(() {
          binderPages[currentPage][emptySlotIndex] = {
            'imagePath': card['image_path'],
            'instanceId': card['instance_id'],
          };
        });

        // Atualiza visualmente o monte
        await _refreshSharedPile();
      } else {
        print('⚠️ Não há slots vazios na página atual');
      }
    } catch (e) {
      print('❌ Erro ao mover card do monte para o binder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Binder ${widget.binderId} - Página ${currentPage + 1}'),
        actions: [
          // Botão da mochila com DragTarget
          DragTarget<Map<String, String>>(
            onWillAccept: (data) =>
                data != null &&
                (data['fromLocation'] == 'binder' ||
                    data['fromLocation'] == 'shared_pile'),
            onAccept: (data) async {
              if (data['fromLocation'] == 'shared_pile') {
                // Move o card do monte para a mochila
                await widget.dataStorageService.moveCardBetweenBackpackAndPile(
                  data['instanceId']!,
                  'shared_pile',
                );
              } else {
                // Move o card do binder para a mochila
                await widget.dataStorageService.moveCardBetweenBackpackAndPile(
                  data['instanceId']!,
                  'binder',
                );
              }
              // Atualiza o monte
              await _refreshSharedPile();
            },
            builder: (context, candidateData, rejectedData) {
              return IconButton(
                icon: Icon(
                  Icons.backpack,
                  color: candidateData.isNotEmpty ? Colors.pink[300] : null,
                  size: 32,
                ),
                padding: EdgeInsets.all(8),
                iconSize: 32,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => BackpackDialog(
                      dataStorageService: widget.dataStorageService,
                      onMountUpdated: () async {
                        await _refreshSharedPile();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child:
                Image.asset('assets/binder_background.png', fit: BoxFit.cover),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragPosition -=
                    details.primaryDelta! / MediaQuery.of(context).size.width;
                _dragPosition = _dragPosition.clamp(0.0, 1.0);
                _pageController.jumpTo(
                    currentPage * MediaQuery.of(context).size.width +
                        _dragPosition * MediaQuery.of(context).size.width);
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragPosition > 0.5) {
                _pageController.animateToPage(
                  currentPage + 1,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              } else if (_dragPosition < -0.5) {
                _pageController.animateToPage(
                  currentPage - 1,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              } else {
                _pageController.animateToPage(
                  currentPage,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
              _dragPosition = 0.0;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: TOTAL_PAGES,
              onPageChanged: (page) {
                setState(() {
                  currentPage = page;
                  selectedCardIndex = null;
                });
              },
              itemBuilder: (context, pageIndex) {
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 1.0;
                    if (_pageController.position.haveDimensions) {
                      value = _pageController.page! - pageIndex;
                      value = (1 - (value.abs() * .5)).clamp(0.0, 1.0);
                    }
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(pi * (1 - value)),
                      alignment: value > 0.5
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Stack(
                        children: [
                          // Layout dos slots da página atual
                          for (int i = 0; i < 4; i++)
                            Positioned(
                              left: i % 2 == 0 ? 53 : 207,
                              top: i < 2 ? 132 : 355,
                              child: _buildSlot(i, pageIndex),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Monte de cards (mantido fixo durante a navegação)
          Positioned(
            right: 0,
            top: 100,
            child: Container(
              width: 90,
              padding: EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  Text(
                    'Monte (${cardDeck.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(172, 223, 37, 99),
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildCardDeck(),
                ],
              ),
            ),
          ),
          // Indicadores de página
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                TOTAL_PAGES,
                (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentPage == index
                        ? Colors.pink[300]
                        : Colors.grey[300],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(int index, int pageIndex) {
    const double verticalOffset = -40;
    return Container(
      width: 141,
      height: 210,
      margin: EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey),
        borderRadius: BorderRadius.circular(8.0),
        color: binderPages[pageIndex][index]['imagePath'] == null
            ? Colors.grey[300]
            : Colors.transparent,
      ),
      child: Stack(
        children: [
          DragTarget<Map<String, String>>(
            onWillAccept: (data) {
              return binderPages[pageIndex][index]['imagePath'] == null;
            },
            onAccept: (data) async {
              await _saveBinderSlot(
                index,
                data['imagePath'],
                instanceId: data['instanceId'],
                pageNumber: pageIndex,
              );
            },
            builder: (context, candidateData, rejectedData) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (binderPages[pageIndex][index]['imagePath'] != null)
                    AnimatedPositioned(
                      duration: Duration(milliseconds: 300),
                      top: selectedCardIndex == index ? verticalOffset : 0,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCardIndex =
                                selectedCardIndex == index ? null : index;
                          });
                        },
                        child: _buildCardWidget(index, pageIndex),
                      ),
                    ),
                  if (binderPages[pageIndex][index]['imagePath'] == null)
                    Center(child: Text('Slot Vazio')),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.5,
                        child: Transform.scale(
                          scale: 1.02,
                          child: Transform.translate(
                            offset: Offset(0, 0.9),
                            child: Image.asset(
                              'assets/plastic_texture.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (binderPages[pageIndex][index]['imagePath'] != null &&
              selectedCardIndex != index)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Icon(Icons.layers, color: Colors.pink[300]),
                onPressed: () async {
                  final instanceId =
                      binderPages[pageIndex][index]['instanceId'];
                  if (instanceId != null) {
                    await widget.dataStorageService
                        .moveSpecificCardToPile(instanceId);
                    setState(() {
                      binderPages[pageIndex][index] = {
                        'imagePath': null,
                        'instanceId': null,
                      };
                      selectedCardIndex = null;
                    });
                    await widget.dataStorageService.savePhotocardPosition(
                      widget.binderId,
                      pageIndex,
                      index,
                      null,
                      instanceId: instanceId,
                    );
                    await _refreshSharedPile();
                  }
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                iconSize: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardWidget(int index, int pageIndex) {
    if (selectedCardIndex == index) {
      // Card está levantado, permite arrastar para o monte e mochila
      return Draggable<Map<String, String>>(
        data: {
          'imagePath': binderPages[pageIndex][index]['imagePath']!,
          'instanceId': binderPages[pageIndex][index]['instanceId']!,
          'fromPage': pageIndex.toString(),
          'fromSlot': index.toString(),
          'fromLocation': 'binder',
        },
        feedback: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.asset(
              binderPages[pageIndex][index]['imagePath']!,
              width: 141,
              height: 210,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 141,
                  height: 210,
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image, color: Colors.grey[500]),
                );
              },
            ),
          ),
        ),
        childWhenDragging: Container(),
        onDragCompleted: () {
          setState(() {
            binderPages[pageIndex][index] = {
              'imagePath': null,
              'instanceId': null,
            };
            selectedCardIndex = null;
          });
          _saveBinderSlot(index, null, pageNumber: pageIndex);
        },
        onDraggableCanceled: (velocity, offset) {
          print(
              'Arrasto cancelado, mantendo card no slot $index da página $pageIndex');
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.asset(
            binderPages[pageIndex][index]['imagePath']!,
            width: 141,
            height: 210,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 141,
                height: 210,
                color: Colors.grey[300],
                child: Icon(Icons.broken_image, color: Colors.grey[500]),
              );
            },
          ),
        ),
      );
    } else {
      // Card não está levantado
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          binderPages[pageIndex][index]['imagePath']!,
          width: 141,
          height: 210,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 141,
              height: 210,
              color: Colors.grey[300],
              child: Icon(Icons.broken_image, color: Colors.grey[500]),
            );
          },
        ),
      );
    }
  }

  Widget _buildCardDeck() {
    return DragTarget<Map<String, String>>(
      onWillAccept: (data) {
        // Verifica se o card vem do binder
        if (data?['fromLocation'] == 'binder') {
          // Verifica se há espaço no monte de forma síncrona
          final currentCount = cardDeck.length;
          if (currentCount >= 10) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('O monte está cheio'),
                backgroundColor: Colors.orange,
              ),
            );
            return false; // Rejeita o drag se o monte estiver cheio
          }
        }
        return true; // Aceita o drag em outros casos
      },
      onAccept: (data) async {
        if (data['fromLocation'] == 'binder') {
          // Move para o monte (só chega aqui se houver espaço)
          await widget.dataStorageService
              .moveSpecificCardToPile(data['instanceId']!);
          await _refreshSharedPile();
        }
      },
      onLeave: (data) {
        // Quando o drag é cancelado, não faz nada (mantém o card no lugar)
        print('Drag cancelado, mantendo card no lugar original');
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          height: MediaQuery.of(context).size.height - 200,
          child: ListView.builder(
            itemCount: cardDeck.length,
            itemBuilder: (context, index) {
              final card = cardDeck[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Draggable<Map<String, String>>(
                  data: {
                    ...card,
                    'fromLocation': 'shared_pile',
                  },
                  feedback: Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: Image.asset(
                        card['imagePath']!,
                        width: cardWidth,
                        height: cardHeight,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: Image.asset(
                        card['imagePath']!,
                        width: cardWidth,
                        height: cardHeight,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Image.asset(
                      card['imagePath']!,
                      width: cardWidth,
                      height: cardHeight,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveCurrentState();
    }
  }

  Future<void> _saveCurrentState() async {
    try {
      // Salva cada slot de cada página
      for (int pageIndex = 0; pageIndex < TOTAL_PAGES; pageIndex++) {
        for (int slotIndex = 0; slotIndex < 4; slotIndex++) {
          if (binderPages[pageIndex][slotIndex]['imagePath'] != null) {
            final instanceId = binderPages[pageIndex][slotIndex]['instanceId'];
            if (instanceId != null) {
              await widget.dataStorageService.updateCardLocation(
                instanceId,
                'binder',
                binderId: widget.binderId,
                slotIndex: slotIndex,
                pageNumber: pageIndex,
              );
            }
          } else {
            // Limpa o slot se estiver vazio
            // Skip updating empty slots as they don't have an instanceId
          }
        }
      }

      // Salva o estado do monte
      for (var card in cardDeck) {
        final instanceId = card['instanceId'];
        if (instanceId != null) {
          await widget.dataStorageService.updateCardLocation(
            instanceId,
            'shared_pile',
          );
        }
      }

      print('Estado do binder salvo com sucesso');
      await widget.dataStorageService.printAllLocations(); // Para debug
    } catch (e) {
      print('Erro ao salvar estado do binder: $e');
    }
  }

  Future<void> _showPhotocardSelectionDialog(
      BuildContext context, int slotIndex) async {
    final availableCards =
        await widget.dataStorageService.getAvailablePhotocards();
    final cardCounts =
        await widget.dataStorageService.getBackpackPhotocardsCount();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Selecione um Photocard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink[300],
                  ),
                ),
                const SizedBox(height: 16),
                if (availableCards.isEmpty)
                  const Text(
                    'Nenhum photocard disponível na mochila',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: availableCards.length,
                      itemBuilder: (context, index) {
                        final card = availableCards[index];
                        final count = cardCounts[card['imagePath']] ?? 0;

                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                Navigator.of(context).pop();
                                await _saveBinderSlot(
                                  slotIndex,
                                  card['imagePath'],
                                  instanceId: card['instanceId'],
                                );
                                // Atualiza o monte após colocar o card no slot
                                await _refreshSharedPile();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    card['imagePath']!,
                                    fit: BoxFit.cover,
                                  ),
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
                  ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _refreshSharedPile() async {
    try {
      final updatedPile = await widget.dataStorageService.getSharedPile();
      
      // Converter List<Map<String, dynamic>> para List<Map<String, String>>
      final convertedPile = updatedPile.map((card) => {
        'imagePath': card['image_path'] as String,
        'instanceId': card['instance_id'] as String,
      }).toList();

      if (mounted) {
        setState(() {
          cardDeck = convertedPile;
        });
      }
      print('Monte atualizado: ${convertedPile.length} cards');
    } catch (e) {
      print('Erro ao atualizar monte: $e');
    }
  }
}

class PageFlipPhysics extends ScrollPhysics {
  const PageFlipPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  PageFlipPhysics applyTo(ScrollPhysics? ancestor) {
    return PageFlipPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 50,
        stiffness: 100,
        damping: 1,
      );

  @override
  double getPage(ScrollMetrics position) {
    return position.pixels / position.viewportDimension;
  }

  @override
  double getPixels(ScrollMetrics position, double page) {
    return page * position.viewportDimension;
  }

  @override
  double getTargetPixels(
      ScrollMetrics position, Tolerance tolerance, double velocity) {
    double page = getPage(position);
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return getPixels(position, page.roundToDouble());
  }
}
