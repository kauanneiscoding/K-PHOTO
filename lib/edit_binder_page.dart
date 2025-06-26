import 'package:flutter/material.dart';
import 'models/keychain.dart';
import 'services/supabase_service.dart';
import 'package:uuid/uuid.dart';  // Importar o pacote UUID

class EditBinderPage extends StatefulWidget {
  final String binderId;
  final String currentCover;
  final String currentSpine;
  final String? currentKeychain;
  final Function(String cover, String spine, String? keychain) onCoversChanged;

  const EditBinderPage({
    Key? key,
    required this.binderId,
    required this.currentCover,
    required this.currentSpine,
    this.currentKeychain,
    required this.onCoversChanged,
  }) : super(key: key);

  @override
  State<EditBinderPage> createState() => _EditBinderPageState();
}

class _EditBinderPageState extends State<EditBinderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String selectedCover;
  late String selectedSpine;
  String? selectedKeychain;
  
  // Estado dos adesivos
  List<Map<String, dynamic>> _stickersOnBinder = [];
  String? _selectedStickerId;
  Offset? _dragPosition;
  double _scale = 1.0;
  double _baseScale = 1.0;



  Future<void> _loadStickers() async {
    try {
      // Usa o ID do binder atual (você precisará adicionar um binderId ao widget)
      final binderId = await _getCurrentBinderId();
      if (binderId != null) {
        final loaded = await SupabaseService().loadStickersFromSupabase(binderId);
        if (mounted) {
          setState(() {
            _stickersOnBinder = loaded;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar adesivos: $e');
    }
  }
  
  /// Adiciona um novo adesivo à capa
  // Gera um ID único para uma instância de adesivo
  String generateStickerInstanceId(String binderId, String stickerId, double x, double y) {
    // Usa um hash dos parâmetros para criar um ID consistente
    final uniqueString = '${binderId}_${stickerId}_${x.toStringAsFixed(2)}_${y.toStringAsFixed(2)}';
    return uniqueString.hashCode.toString();
  }

  void _addOrUpdateSticker(String stickerPath, Offset position, {String? existingId}) {
  final uuid = const Uuid();

  // Formata o caminho do sticker para garantir que esteja no formato correto
  String formatStickerPath(String path) {
    // Se já começar com 'assets/stickers/', retorna como está
    if (path.startsWith('assets/stickers/')) {
      return path;
    }
    // Se for apenas 'sticker1', 'sticker2', etc., adiciona o caminho completo
    if (path.startsWith('sticker')) {
      final number = path.replaceAll('sticker', '');
      return 'assets/stickers/sticker_$number.png';
    }
    // Se for apenas um número, adiciona o prefixo e sufixo
    if (int.tryParse(path) != null) {
      return 'assets/stickers/sticker_$path.png';
    }
    // Caso contrário, retorna como está
    return path;
  }

  final formattedPath = formatStickerPath(stickerPath);

  if (existingId != null) {
    final existingIndex = _stickersOnBinder.indexWhere((s) => s['id'] == existingId);
    if (existingIndex != -1) {
      setState(() {
        _stickersOnBinder[existingIndex]['x'] = position.dx;
        _stickersOnBinder[existingIndex]['y'] = position.dy;
      });
      _saveStickers(); // Atualiza posição no Supabase
      return;
    }
  }

  // Adiciona novo adesivo
  final newSticker = {
    'id': uuid.v4(), // ID novo e único
    'image_path': formattedPath, // Usa o caminho formatado
    'x': position.dx,
    'y': position.dy,
    'scale': 1.0,
    'rotation': 0.0,
    'created_at': DateTime.now().toIso8601String(),
  };

  setState(() {
    _stickersOnBinder.add(newSticker);
  });

  _saveStickers().catchError((error) {
    debugPrint('❌ Erro ao salvar adesivo novo: $error');
    setState(() {
      _stickersOnBinder.remove(newSticker);
    });
  });
}


  /// Salva os adesivos no Supabase
  Future<void> _saveStickers() async {
    try {
      final binderId = await _getCurrentBinderId();
      if (binderId != null) {
        // Mantém todos os stickers, mesmo com a mesma imagem
        final stickersToSave = _stickersOnBinder.map((sticker) => ({
          'id': sticker['id'],
          'image_path': sticker['image_path'],
          'x': sticker['x'],
          'y': sticker['y'],
          'created_at': sticker['created_at'],
        })).toList();
        
        await SupabaseService().saveStickersToSupabase(binderId, stickersToSave);
        debugPrint('✅ Adesivos salvos com sucesso');
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar adesivos: $e');
      rethrow;
    }
  }
  
  void _updateStickerPosition(String id, Offset position) async {
    setState(() {
      final index = _stickersOnBinder.indexWhere((s) => s['id'] == id);
      if (index != -1) {
        _stickersOnBinder[index]['x'] = position.dx;
        _stickersOnBinder[index]['y'] = position.dy;
      }
    });

    // Salvar as alterações no Supabase
    try {
      await _saveStickers();
    } catch (e) {
      debugPrint('❌ Erro ao salvar sticker após redimensionamento: $e');
    }
  }
  
  // Método auxiliar para obter o ID do binder atual
  // Você precisará implementar isso de acordo com sua lógica de negócios
  Future<String?> _getCurrentBinderId() async {
    return widget.binderId;
  }

  final List<Map<String, String>> availableCovers = [
    {
      'cover': 'assets/capas/capabinder1.png',
      'spine': 'assets/capas/lombadabinder1.png',
    },
    {
      'cover': 'assets/capas/capabinder2.png',
      'spine': 'assets/capas/lombadabinder2.png',
    },
    {
      'cover': 'assets/capas/capabinder3.png',
      'spine': 'assets/capas/lombadabinder3.png',
    },
    {
      'cover': 'assets/capas/capabinder4.png',
      'spine': 'assets/capas/lombadabinder4.png',
    },
  ];

  final List<Keychain> availableKeychains = [
    Keychain(
      id: '1',
      imagePath: 'assets/keychain/keychain1.png',
      size: 50.0,
    ),
    Keychain(
      id: '2',
      imagePath: 'assets/keychain/keychain2.png',
      size: 50.0,
    ),
    Keychain(
      id: '3',
      imagePath: 'assets/keychain/keychain3.png',
      size: 50.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Inicializa as capas selecionadas com os valores atuais
    selectedCover = widget.currentCover;
    selectedSpine = widget.currentSpine;
    selectedKeychain = widget.currentKeychain;
    
    // Inicializa o controlador de abas
    _tabController = TabController(length: 3, vsync: this);
    
    // Carrega os adesivos do binder
    _loadStickers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Binder'),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveStickers(); // 🔧 salva os adesivos no Supabase
              widget.onCoversChanged(
                  selectedCover, selectedSpine, selectedKeychain);
              Navigator.pop(context);
            },
            child: Text(
              'Salvar',
              style: TextStyle(
                color: Colors.pink[300],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Visualização da capa e chaveiro
          Center(
            child: GestureDetector(
              onPanUpdate: (details) {
                if (_selectedStickerId != null && _dragPosition != null) {
                  setState(() {
                    _dragPosition = details.globalPosition;
                  });
                }
              },
              onPanEnd: (details) {
                if (_selectedStickerId != null) {
                  // Atualiza a posição do sticker existente
                  final stickerIndex = _stickersOnBinder.indexWhere(
                    (s) => s['image_path'] == _selectedStickerId
                  );
                  
                  if (stickerIndex != -1) {
                    final existingId = _stickersOnBinder[stickerIndex]['id'];
                    _addOrUpdateSticker(
                      _selectedStickerId!, 
                      details.localPosition,
                      existingId: existingId,
                    );
                  } else {
                    _addOrUpdateSticker(_selectedStickerId!, details.localPosition);
                  }
                  
                  setState(() {
                    _selectedStickerId = null;
                    _dragPosition = null;
                  });
                }
              },
              child: Stack(
                children: [
                  // Capa do binder
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: MediaQuery.of(context).size.height * 0.7,
                      margin: EdgeInsets.only(bottom: 160),
                      child: Image.asset(
                        selectedCover,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  // Adesivos na capa
                  ..._stickersOnBinder.map((sticker) {
                    final stickerId = sticker['image_path'] as String? ?? '';
                    final x = (sticker['x'] as num?)?.toDouble() ?? 0.0;
                    final y = (sticker['y'] as num?)?.toDouble() ?? 0.0;
                    
                    return Positioned(
                      left: x,
                      top: y,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedStickerId = sticker['id'];
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            final index = _stickersOnBinder.indexWhere((s) => s['id'] == sticker['id']);
                            if (index != -1) {
                              _stickersOnBinder[index]['x'] = (sticker['x'] as double) + details.delta.dx;
                              _stickersOnBinder[index]['y'] = (sticker['y'] as double) + details.delta.dy;
                            }
                          });
                        },
                        onPanEnd: (details) {
                          if (_dragPosition != null && _selectedStickerId != null) {
                            final RenderBox box = context.findRenderObject() as RenderBox;
                            final localPosition = box.globalToLocal(_dragPosition!);
                            _addOrUpdateSticker(
                              sticker['image_path'],
                              localPosition,
                              existingId: sticker['id'],
                            );
                          }

                          setState(() {
                            _selectedStickerId = null;
                            _dragPosition = null;
                          });
                        },
                        child: Image.asset(
                          sticker['image_path'],
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: Icon(Icons.star, color: Colors.grey[400]),
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
                  if (_selectedStickerId != null && _dragPosition != null)
                    Positioned(
                      left: _dragPosition!.dx - 30,
                      top: _dragPosition!.dy - 30,
                      child: Opacity(
                        opacity: 0.7,
                        child: Image.asset(
                          'assets/stickers/sticker_${_selectedStickerId!.replaceAll('sticker', '')}.png',
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: Icon(Icons.star, color: Colors.grey[400]),
                            );
                          },
                        ),
                      ),
                    ),
                  // Chaveiro
                  if (selectedKeychain != null && selectedKeychain!.isNotEmpty)
                    Positioned(
                      left: MediaQuery.of(context).size.width * 0.02,
                      top: MediaQuery.of(context).size.height * 0.025,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..rotateZ(0)
                          ..translate(-78.0, 10.0),
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.60,
                          height: MediaQuery.of(context).size.width * 0.60,
                          child: Image.asset(
                            selectedKeychain!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Barra de navegação inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.pink[300],
                    labelColor: Colors.pink[300],
                    unselectedLabelColor: Colors.grey[600],
                    tabs: [
                      Tab(text: 'Capas'),
                      Tab(text: 'Chaveiros'),
                      Tab(text: 'Adesivos'),
                    ],
                  ),
                  Container(
                    height: 150,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Aba de Capas
                        ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.all(8),
                          children: availableCovers.map((cover) {
                            final isSelected = selectedCover == cover['cover'];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedCover = cover['cover']!;
                                  selectedSpine = cover['spine']!;
                                });
                              },
                              child: Container(
                                width: 100,
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.pink[300]!
                                        : Colors.grey[300]!,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.asset(
                                  cover['cover']!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        // Aba de Chaveiros
                        ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.all(8),
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedKeychain = null;
                                });
                              },
                              child: Container(
                                width: 80,
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedKeychain == null
                                        ? Colors.pink[300]!
                                        : Colors.grey[300]!,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.remove_circle,
                                    color: Colors.grey[400]),
                              ),
                            ),
                            ...availableKeychains.map((keychain) =>
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedKeychain = keychain.imagePath;
                                    });
                                  },
                                  child: Container(
                                    width: 80,
                                    margin: EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: selectedKeychain ==
                                                keychain.imagePath
                                            ? Colors.pink[300]!
                                            : Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Image.asset(
                                      keychain.imagePath,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                )),
                          ],
                        ),
                        // Aba de Adesivos
                        SizedBox(
                          height: 80,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: List.generate(8, (index) {
                              final stickerId = 'sticker${index + 1}';
                              return GestureDetector(
                                onTapDown: (details) {
                                  setState(() {
                                    _selectedStickerId = stickerId;
                                    _dragPosition = details.globalPosition;
                                  });
                                },
                                onPanUpdate: (details) {
                                  setState(() {
                                    _dragPosition = details.globalPosition;
                                  });
                                },
                                onPanEnd: (details) {
                                  if (_dragPosition != null && _selectedStickerId != null) {
                                    final RenderBox box = context.findRenderObject() as RenderBox;
                                    final localPosition = box.globalToLocal(_dragPosition!);
                                    _addOrUpdateSticker(_selectedStickerId!, localPosition);
                                  }

                                  setState(() {
                                    _selectedStickerId = null;
                                    _dragPosition = null;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Image.asset(
                                    'assets/stickers/sticker_${stickerId.replaceAll('sticker', '')}.png',
                                    width: 50,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Exibe um placeholder se a imagem não for encontrada
                                      return Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey[200],
                                        child: Icon(Icons.star, color: Colors.grey[400]),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
