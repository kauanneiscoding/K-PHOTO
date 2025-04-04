import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k_photo/data_storage_service.dart';
import 'binder_view_page.dart';

class EstantePage extends StatefulWidget {
  final DataStorageService dataStorageService;

  const EstantePage({
    super.key,
    required this.dataStorageService,
  });

  @override
  State<EstantePage> createState() => _EstantePageState();
}

class _EstantePageState extends State<EstantePage> {
  static const double fixedHeight = 300;
  static const double binderSpineWidth = fixedHeight * 0.0957536;
  static const double binderCoverWidth = fixedHeight * 0.65;
  bool showInventory = false;
  List<Binder> _binders = [];
  StreamSubscription? _binderUpdateSubscription;
  bool _isLoading = true;

  int _generateStyleIndex(String binderId) {
    return binderId.hashCode.abs() % 4 + 1;
  }

  @override
  void initState() {
    super.initState();
    _refreshBinders();
    // Escutar atualizações de binders
    _binderUpdateSubscription = widget.dataStorageService.binderUpdateController.stream.listen((_) {
      print('EstantePage: Recebeu notificação de atualização de binder');
      _refreshBinders();
    });
  }

  @override
  void dispose() {
    _binderUpdateSubscription?.cancel();
    super.dispose();
  }

  // New method to log all binders
  void _logAllBinders() async {
    try {
      final binders = await widget.dataStorageService.getAllBinders();
      
      print('=== Binders Inventory ===');
      print('Total Binders: ${binders.length}');
      
      for (var binder in binders) {
        print('Binder ID: ${binder['id']}');
        print('Cover Asset: ${binder['cover_asset'] ?? 'No cover'}');
        print('Spine Asset: ${binder['spine_asset'] ?? 'No spine'}');
        print('---');
      }
      
      print('=== End of Binder Inventory ===');
    } catch (e) {
      print('Error logging binders: $e');
    }
  }

  Future<void> _refreshBinders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('DEBUG: Iniciando _refreshBinders()');
      final binderMaps = await widget.dataStorageService.getAllBinders();
      print('DEBUG: Binders obtidos do banco: ${binderMaps.length}');

      // Converter mapas de binders para objetos Binder
      final updatedBinders = binderMaps.map((binderData) {
        final binderId = binderData['id'].toString();
        final styleIndex = _generateStyleIndex(binderId);
        final defaultCoverAsset = 'assets/capas/capabinder$styleIndex.png';
        final defaultSpineAsset = 'assets/capas/lombadabinder$styleIndex.png';

        return Binder(
          binderName: binderId,
          isOpen: false,
          coverAsset: binderData['cover_asset'] as String? ?? defaultCoverAsset,
          spineAsset: binderData['spine_asset'] as String? ?? defaultSpineAsset,
          keychainAsset: binderData['keychain_asset'] as String?,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _binders = updatedBinders;
        _isLoading = false;
      });

      print('DEBUG: _refreshBinders() concluído com ${_binders.length} binders');
    } catch (e) {
      print('ERROR: Erro em _refreshBinders(): $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // New method to find a binder by its ID
  Binder? findBinderById(String id) {
    try {
      return _binders.firstWhere((binder) => binder.binderName == id);
    } catch (e) {
      print('Binder with ID $id not found');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Minha Estante'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: Icon(Icons.menu_book, color: Colors.pink[300]),
              onPressed: () async {
                final canAddBinder = await widget.dataStorageService.canAddMoreBinders();
                if (!canAddBinder) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Limite máximo de 15 binders atingido'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Verificar saldo de K-COINS
                final userCoins = await widget.dataStorageService.getUserCoins();
                const binderCost = 1500;

                if (userCoins < binderCost) {
                  await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Saldo Insuficiente', style: TextStyle(color: Colors.red)),
                        content: Text('Você precisa de $binderCost K-COINS para comprar um novo binder. Seu saldo atual é $userCoins K-COINS.'),
                        actions: <Widget>[
                          TextButton(
                            child: Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }

                // Confirmar compra do binder
                final confirmPurchase = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Comprar Binder', style: TextStyle(color: Colors.pink)),
                      content: Text('Deseja comprar um novo binder por $binderCost K-COINS?'),
                      actions: <Widget>[
                        TextButton(
                          child: Text('Cancelar'),
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                          child: Text('Comprar', style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            Navigator.of(context).pop(true);
                          },
                        ),
                      ],
                    );
                  },
                );

                // Se usuário cancelar, sair
                if (confirmPurchase != true) return;

                // Deduzir K-COINS
                await widget.dataStorageService.deductUserCoins(binderCost);

                // Adicionar novo binder e obter seu ID
                final newBinderId = await widget.dataStorageService.addNewBinder();
                print('Binder purchased with ID: $newBinderId');

                // Notificar sobre a atualização do binder
                widget.dataStorageService.notifyBinderUpdate();

                // Atualizar a lista de binders
                await _refreshBinders();

                // Mostrar mensagem de sucesso
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Binder comprado com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              tooltip: 'Adicionar novo binder',
            ),
          ],
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[300]!),
          ),
        ),
      );
    }

    // Add a safety check to prevent empty or null list
    if (_binders.isEmpty) {
      print('Warning: No binders to display');
      return Center(
        child: Text(
          'Nenhum binder encontrado',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Minha Estante'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.menu_book, color: Colors.pink[300]),
            onPressed: () async {
              final canAddBinder = await widget.dataStorageService.canAddMoreBinders();
              if (!canAddBinder) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Limite máximo de 15 binders atingido'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Verificar saldo de K-COINS
              final userCoins = await widget.dataStorageService.getUserCoins();
              const binderCost = 1500;

              if (userCoins < binderCost) {
                await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Saldo Insuficiente', style: TextStyle(color: Colors.red)),
                      content: Text('Você precisa de $binderCost K-COINS para comprar um novo binder. Seu saldo atual é $userCoins K-COINS.'),
                      actions: <Widget>[
                        TextButton(
                          child: Text('OK'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
                return;
              }

              // Confirmar compra do binder
              final confirmPurchase = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Comprar Binder', style: TextStyle(color: Colors.pink)),
                    content: Text('Deseja comprar um novo binder por $binderCost K-COINS?'),
                    actions: <Widget>[
                      TextButton(
                        child: Text('Cancelar'),
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                        child: Text('Comprar', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ],
                  );
                },
              );

              // Se usuário cancelar, sair
              if (confirmPurchase != true) return;

              // Deduzir K-COINS
              await widget.dataStorageService.deductUserCoins(binderCost);

              // Adicionar novo binder e obter seu ID
              final newBinderId = await widget.dataStorageService.addNewBinder();
              print('Binder purchased with ID: $newBinderId');

              // Notificar sobre a atualização do binder
              widget.dataStorageService.notifyBinderUpdate();

              // Atualizar a lista de binders
              await _refreshBinders();

              // Mostrar mensagem de sucesso
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Binder comprado com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            tooltip: 'Adicionar novo binder',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            for (var binder in _binders) {
              binder.isOpen = false;
            }
          });
        },
        behavior: HitTestBehavior.translucent,
        child: Center(
          child: Container(
            height: 400,
            padding: EdgeInsets.only(bottom: 50, top: 50),
            child: ShelfWidget(
              binders: _binders,
              dataStorageService: widget.dataStorageService,
              onBinderUpdate: (updatedBinders) {
                setState(() {
                  _binders = updatedBinders;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ShelfWidget extends StatefulWidget {
  final List<Binder> binders;
  final DataStorageService dataStorageService;
  final Function(List<Binder>)? onBinderUpdate;

  const ShelfWidget({
    Key? key,
    required this.binders,
    required this.dataStorageService,
    this.onBinderUpdate,
  }) : super(key: key);

  @override
  _ShelfWidgetState createState() => _ShelfWidgetState();
}

class _ShelfWidgetState extends State<ShelfWidget> {
  List<Binder> _binders = [];
  StreamSubscription? _binderUpdateSubscription;

  int _generateStyleIndex(String binderId) {
    return binderId.hashCode.abs() % 4 + 1;
  }

  @override
  void initState() {
    super.initState();
    _binders = List.from(widget.binders);
    _loadBinderCovers();

    // Escutar atualizações de binders
    _binderUpdateSubscription = widget.dataStorageService.binderUpdateController.stream.listen((_) async {
      print('ShelfWidget: Recebeu notificação de atualização de binder');
      await _loadBinderCovers();
      
      // Notificar o pai sobre a atualização
      widget.onBinderUpdate?.call(_binders);
    });
  }

  @override
  void dispose() {
    _binderUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBinderCovers() async {
    try {
      final binderMaps = await widget.dataStorageService.getAllBinders();
      
      // Converter mapas de binders para objetos Binder
      final loadedBinders = binderMaps.map((binderData) {
        final binderId = binderData['id'].toString();
        final styleIndex = _generateStyleIndex(binderId);
        final defaultCoverAsset = 'assets/capas/capabinder$styleIndex.png';
        final defaultSpineAsset = 'assets/capas/lombadabinder$styleIndex.png';

        return Binder(
          binderName: binderId,
          isOpen: false,
          coverAsset: binderData['cover_asset'] as String? ?? defaultCoverAsset,
          spineAsset: binderData['spine_asset'] as String? ?? defaultSpineAsset,
          keychainAsset: binderData['keychain_asset'] as String?,
        );
      }).toList();

      // Atualizar o estado
      if (mounted) {
        setState(() {
          _binders = loadedBinders;
        });

        // Notificar o pai sobre a atualização
        widget.onBinderUpdate?.call(_binders);
      }
    } catch (e) {
      print('Erro ao carregar capas dos binders: $e');
    }
  }

  Future<void> _toggleBinder(int index) async {
    setState(() {
      if (_binders[index].isOpen) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BinderViewPage(
              binderId: _binders[index].binderName,
              binderCover: _binders[index].coverAsset,
              binderSpine: _binders[index].spineAsset,
              binderIndex: index,
              dataStorageService: widget.dataStorageService,
            ),
          ),
        ).then((_) {
          // Recarrega as capas quando voltar da edição
          _loadBinderCovers();
          // Fecha o binder com animação
          setState(() {
            _binders[index].isOpen = false;
          });
        });
      } else {
        // Fechar todos os outros binders e abrir o selecionado
        for (int i = 0; i < _binders.length; i++) {
          _binders[i].isOpen = i == index;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Add a safety check to prevent empty or null list
    if (_binders.isEmpty) {
      print('Warning: No binders to display');
      return Center(
        child: Text(
          'Nenhum binder encontrado',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(left: 20.0),
      clipBehavior: Clip.none,
      scrollDirection: Axis.horizontal,
      // Ensure itemCount matches the actual number of binders
      itemCount: _binders.length,
      itemBuilder: (context, index) {
        // Add additional safety checks
        if (index < 0 || index >= _binders.length) {
          print('Invalid binder index: $index');
          return SizedBox.shrink();
        }

        try {
          final binder = _binders[index];

          return GestureDetector(
            onTap: () {
              _toggleBinder(index);
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              child: AnimatedBinderWrapper(
                isOpen: binder.isOpen,
                child: BinderWidget(
                  binder: binder,
                  isOpen: binder.isOpen,
                ),
              ),
            ),
          );
        } catch (e) {
          print('Error displaying binder at index $index: $e');
          return SizedBox.shrink();
        }
      },
    );
  }
}

class BinderWidget extends StatefulWidget {
  final Binder binder;
  final bool isOpen;

  const BinderWidget({
    Key? key,
    required this.binder,
    required this.isOpen,
  }) : super(key: key);

  @override
  _BinderWidgetState createState() => _BinderWidgetState();
}

class _BinderWidgetState extends State<BinderWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _swingController;
  late Animation<double> _animation;
  late Animation<double> _swingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _swingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -pi / 2, end: 0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_controller);

    _swingAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(
      CurvedAnimation(
        parent: _swingController,
        curve: Curves.easeInOut,
      ),
    );

    // Começar sempre mostrando a lombada
    _controller.value = 0.0;
  }

  @override
  void didUpdateWidget(BinderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimationState();
  }

  void _updateAnimationState() {
    if (widget.isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _swingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(_EstantePageState.binderSpineWidth, 0),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(_animation.value)
              ..translate(0.0, 0.0, 0.0),
            alignment: Alignment.centerLeft,
            child: _buildBinderContent(),
          );
        },
      ),
    );
  }

  Widget _buildBinderContent() {
    final keychainSize = _EstantePageState.binderSpineWidth * 3.5;

    return Stack(
      children: [
        Container(
          width: _EstantePageState.binderCoverWidth,
          height: _EstantePageState.fixedHeight,
          child: Image.asset(
            widget.binder.coverAsset,
            fit: BoxFit.fill,
          ),
        ),
        Transform(
          transform: Matrix4.identity()
            ..rotateY(pi / 2)
            ..translate(-_EstantePageState.binderSpineWidth, 0.0, 0.0),
          alignment: Alignment.centerLeft,
          child: Container(
            width: _EstantePageState.binderSpineWidth,
            height: _EstantePageState.fixedHeight,
            child: Image.asset(
              widget.binder.spineAsset,
              fit: BoxFit.fill,
            ),
          ),
        ),
        if (widget.binder.keychainAsset != null &&
            widget.binder.keychainAsset!.isNotEmpty)
          AnimatedBuilder(
            animation: _swingAnimation,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..rotateY(pi / 2)
                  ..translate(-_EstantePageState.binderSpineWidth, 0.0, 0.0)
                  ..rotateZ(_swingAnimation.value),
                alignment: Alignment.topCenter,
                child: Container(
                  width: _EstantePageState.binderSpineWidth,
                  height: _EstantePageState.fixedHeight + keychainSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: (_EstantePageState.binderSpineWidth -
                                keychainSize) /
                            2,
                        top: -keychainSize * 0.2,
                        child: SizedBox(
                          width: keychainSize,
                          height: keychainSize,
                          child: Image.asset(
                            widget.binder.keychainAsset!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class AnimatedBinderWrapper extends StatelessWidget {
  final Widget child;
  final bool isOpen;
  final Duration duration;

  const AnimatedBinderWrapper({
    Key? key,
    required this.child,
    required this.isOpen,
    this.duration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      width: isOpen ? 240 : _EstantePageState.binderSpineWidth + 5,
      child: child,
    );
  }
}

class Binder {
  final String coverAsset;
  final String spineAsset;
  bool isOpen;
  final String? keychainAsset;
  final String binderName; // Agora é obrigatório

  Binder({
    required this.coverAsset,
    required this.spineAsset,
    required this.binderName, // Agora é obrigatório
    this.isOpen = false,
    this.keychainAsset,
  });
}
