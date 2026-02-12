import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:flutter/widgets.dart';
import 'models/keychain.dart';
import 'models/sticker_data.dart';
import 'services/supabase_service.dart';
import 'services/sticker_service.dart';
import 'package:uuid/uuid.dart';

class DraggableSticker extends StatefulWidget {
  final Map<String, dynamic> sticker;
  final Function(String, Offset) onPositionUpdate;
  final Function(String) onRemove;
  final bool isSelected;

  const DraggableSticker({
    Key? key,
    required this.sticker,
    required this.onPositionUpdate,
    required this.onRemove,
    this.isSelected = false,
  }) : super(key: key);

  @override
  _DraggableStickerState createState() => _DraggableStickerState();
}

class _DraggableStickerState extends State<DraggableSticker> {
  late Offset _position;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _position = Offset(
      (widget.sticker['x'] as num).toDouble(),
      (widget.sticker['y'] as num).toDouble(),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      // Notify parent that we're starting to drag
      widget.onPositionUpdate(widget.sticker['id'], _position);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
    });
    
    // Update parent about the drag position for trash can detection
    widget.onPositionUpdate(widget.sticker['id'], _position);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    
    // Check if we should remove the sticker
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      try {
        final Offset position = renderBox.localToGlobal(Offset.zero);
        final double trashCanX = MediaQuery.of(context).size.width - 50; // 50px from right
        final double trashCanY = 90; // 90px from top
        final double distance = (position - Offset(trashCanX, trashCanY)).distance;
        
        if (distance < 60) { // 60px radius around trash can
          widget.onRemove(widget.sticker['id']);
          return; // Early return since the sticker will be removed
        }
      } catch (e) {
        debugPrint('Error calculating trash can distance: $e');
      }
    }
    
    // If we get here, update the position and notify parent dragging has ended
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onPositionUpdate(widget.sticker['id'], _position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: () {
          // Toggle selection on tap
          widget.onPositionUpdate(widget.sticker['id'], _position);
        },
        child: Stack(
          children: [
            Transform.scale(
              scale: (widget.sticker['scale'] as num?)?.toDouble() ?? 1.0,
              child: Transform.rotate(
                angle: (widget.sticker['rotation'] as num?)?.toDouble() ?? 0.0,
                child: Opacity(
                  opacity: _isDragging ? 0.8 : 1.0,
                  child: Image.asset(
                    widget.sticker['image_path'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Selection border
            if (widget.isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blue,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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

class _EditBinderPageState extends State<EditBinderPage> with SingleTickerProviderStateMixin {
  // Key para acessar o tamanho e posição da capa
  final GlobalKey _capaKey = GlobalKey();
  
  // Converte coordenadas da tela para coordenadas relativas à capa
  Offset _getRelativeToCover(Offset screenPosition) {
    final RenderBox? coverBox = _capaKey.currentContext?.findRenderObject() as RenderBox?;
    if (coverBox == null) return screenPosition;
    
    // Obtém a posição da capa na tela
    final coverPosition = coverBox.localToGlobal(Offset.zero);
    final coverSize = coverBox.size;
    
    // Calcula a posição relativa à capa
    final relativeX = (screenPosition.dx - coverPosition.dx) / coverSize.width;
    final relativeY = (screenPosition.dy - coverPosition.dy) / coverSize.height;
    
    return Offset(relativeX, relativeY);
  }
  
  // Converte coordenadas relativas à capa para coordenadas absolutas na tela
  Offset _getAbsoluteFromCover(Offset relativePosition) {
    final RenderBox? renderBox = _capaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      debugPrint('⚠️ RenderBox is null in _getAbsoluteFromCover');
      return Offset.zero;
    }
    
    try {
      final box = renderBox;
      final position = box.localToGlobal(Offset.zero);
      final size = box.size;
      
      debugPrint('📏 Cover position: $position, size: $size');
      
      return Offset(
        position.dx + (relativePosition.dx * size.width),
        position.dy + (relativePosition.dy * size.height),
      );
    } catch (e) {
      debugPrint('❌ Error in _getAbsoluteFromCover: $e');
      return Offset.zero;
    }
  }
  late TabController _tabController;
  late String selectedCover;
  late String selectedSpine;
  String? selectedKeychain;
  
  // Variáveis temporárias para armazenar os caminhos antes de salvar
  String? _tempCoverPath;
  String? _tempKeychainPath;
  
  // Estado dos adesivos
  List<Map<String, dynamic>> _stickersOnBinder = [];
  String? _selectedStickerId;
  Offset? _dragPosition;
  bool _isAddingSticker = false;
  bool _hasUnsavedChanges = false;
  bool _isDraggingSticker = false;
  
  // Controles de transformação
  double _currentRotation = 0.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0; // Mantido para compatibilidade com outros lugares do código



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
    if (!mounted) return;
    final uuid = const Uuid();
    
    debugPrint('➕ Adding/Updating sticker at position: $position');

    // Valida o caminho do sticker
    if (stickerPath.isEmpty) {
      debugPrint('❌ Caminho do sticker vazio');
      return;
    }

  // Formata o caminho do sticker para garantir que esteja no formato correto
  String formatStickerPath(String path) {
    debugPrint('🔧 Formatting sticker path: $path');
    
    // Se já estiver no formato correto, retorna como está
    if (path.startsWith('assets/') && (path.endsWith('.png') || path.endsWith('.jpg'))) {
      debugPrint('✅ Path já está formatado corretamente');
      return path;
    }
    
    // Se for apenas 'sticker1', 'sticker2', etc.
    if (path.startsWith('sticker')) {
      final number = path.replaceAll('sticker', '').replaceAll('_', '');
      final formatted = 'assets/stickers/sticker_$number.png';
      debugPrint('🔄 Convertido para: $formatted');
      return formatted;
    }
    
    // Se for apenas um número
    if (int.tryParse(path) != null) {
      final formatted = 'assets/stickers/sticker_$path.png';
      debugPrint('🔢 Número convertido para: $formatted');
      return formatted;
    }
    
    // Se não for reconhecido, tenta adicionar o caminho base
    if (!path.startsWith('assets/')) {
      final formatted = 'assets/stickers/$path${path.endsWith('.png') ? '' : '.png'}';
      debugPrint('✨ Adicionado caminho base: $formatted');
      return formatted;
    }
    
    debugPrint('⚠️ Retornando path sem modificação: $path');
    return path;
  }

  final formattedPath = formatStickerPath(stickerPath);

  if (existingId != null) {
    final existingIndex = _stickersOnBinder.indexWhere((s) => s['id'] == existingId);
    if (existingIndex != -1) {
      setState(() {
        _stickersOnBinder[existingIndex]['x'] = position.dx;
        _stickersOnBinder[existingIndex]['y'] = position.dy;
        // Mantém os valores existentes de scale e rotation
        _stickersOnBinder[existingIndex]['scale'] = _stickersOnBinder[existingIndex]['scale'] ?? 1.0;
        _stickersOnBinder[existingIndex]['rotation'] = _stickersOnBinder[existingIndex]['rotation'] ?? 0.0;
      });
      _hasUnsavedChanges = true;
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
    _hasUnsavedChanges = true;
  });
}

  /// Salva os adesivos, capas e chaveiros no Supabase
  Future<void> _saveStickers() async {
    try {
      final binderId = await _getCurrentBinderId();
      if (binderId != null) {
        // Converte os mapas para objetos StickerData
        final stickersToSave = _stickersOnBinder.map((sticker) => StickerData(
          id: sticker['id'],
          imagePath: sticker['image_path'],
          x: (sticker['x'] as num).toDouble(),
          y: (sticker['y'] as num).toDouble(),
          scale: (sticker['scale'] as num?)?.toDouble() ?? 1.0,
          rotation: (sticker['rotation'] as num?)?.toDouble() ?? 0.0,
        )).toList();
        
        // Salva os adesivos no Supabase
        final stickerService = StickerService();
        await stickerService.saveStickers(binderId, stickersToSave);
        debugPrint('✅ Adesivos salvos com sucesso');
        
        // Notifica as alterações nas capas e chaveiros
        if (_tempCoverPath != null || _tempKeychainPath != null) {
          widget.onCoversChanged(
            _tempCoverPath ?? selectedCover,
            selectedSpine, // A lombada é atualizada junto com a capa
            _tempKeychainPath ?? selectedKeychain,
          );
          
          // Reseta as variáveis temporárias
          _tempCoverPath = null;
          _tempKeychainPath = null;
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alterações salvas com sucesso!')),
          );
          setState(() {
            _hasUnsavedChanges = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar alterações: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
      rethrow;
    }
  }
  
  // Check if position is over trash can area (top right corner with larger hit area)
  bool _isOverTrashCan(Offset position, BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Tamanho da área de detecção da lixeira
    final double trashCanSize = 100.0; // Tamanho aumentado para facilitar o acerto
    
    // Posição da lixeira (canto superior direito)
    final double trashCanX = size.width - trashCanSize - 16; // 16 pixels de margem
    final double trashCanY = 16.0; // 16 pixels do topo
    
    // Cria um retângulo para a área da lixeira
    final trashCanArea = Rect.fromLTWH(
      trashCanX,
      trashCanY,
      trashCanSize,
      trashCanSize,
    );
    
    // Verifica se a posição está dentro da área da lixeira
    return trashCanArea.contains(position);
  }

  // Handle sticker drop
  // Remove a sticker by its ID
  void _removeSticker(String id) {
    if (!mounted) return;
    
    // Encontra o índice do adesivo a ser removido
    final index = _stickersOnBinder.indexWhere((s) => s['id'] == id);
    if (index == -1) return; // Se não encontrar, sai da função
    
    setState(() {
      // Remove o adesivo da lista
      _stickersOnBinder.removeAt(index);
      _hasUnsavedChanges = true;
      _isDraggingSticker = false;
      _dragPosition = null;
      
      // Se o adesivo removido era o selecionado, limpa a seleção
      if (_selectedStickerId == id) {
        _selectedStickerId = null;
      }
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adesivo removido')),
      );
    }
  }

  void _onStickerDrop(String id, Offset fingerPosition, BuildContext context) {
    try {
      // Verifica se o dedo está sobre a lixeira
      if (_isOverTrashCan(fingerPosition, context)) {
        // Mostra um feedback visual antes de remover
        HapticFeedback.mediumImpact();
        
        // Remove o adesivo após um pequeno atraso para dar feedback visual
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _removeSticker(id);
          }
        });
      } else {
        // Obtém a posição e tamanho da capa
        final RenderBox? renderBox = _capaKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final Size capaSize = renderBox.size;
          final Offset capaPosition = renderBox.localToGlobal(Offset.zero);
          
          // Calcula a posição relativa à capa
          final Offset localPosition = fingerPosition - capaPosition;
          
          // Verifica se o dedo está dentro dos limites da capa
          final bool isInsideCover = localPosition.dx >= 0 && 
                                    localPosition.dy >= 0 &&
                                    localPosition.dx <= capaSize.width &&
                                    localPosition.dy <= capaSize.height;
          
          if (isInsideCover) {
            // Normaliza as coordenadas (0.0 a 1.0)
            final double normalizedX = (localPosition.dx / capaSize.width).clamp(0.0, 1.0);
            final double normalizedY = (localPosition.dy / capaSize.height).clamp(0.0, 1.0);
            
            _updateStickerPosition(id, Offset(normalizedX, normalizedY));
          } else {
            // Se soltou fora da capa, não faz nada (mantém a posição anterior)
            debugPrint('🔄 Adesivo solto fora da capa');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao soltar adesivo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDraggingSticker = false;
        });
      }
    }
  }

  void _updateStickerPosition(String id, Offset normalizedPosition) {
    final index = _stickersOnBinder.indexWhere((s) => s['id'] == id);
    if (index != -1) {
      setState(() {
        // Store normalized position (0.0 to 1.0)
        _stickersOnBinder[index]['x'] = normalizedPosition.dx;
        _stickersOnBinder[index]['y'] = normalizedPosition.dy;
        _hasUnsavedChanges = true;
      });
    }
  }

  void _onStickerScaleUpdate(ScaleUpdateDetails details, String id) {
    if (!mounted) return;
    setState(() {
      final index = _stickersOnBinder.indexWhere((s) => s['id'] == id);
      if (index != -1) {
        _stickersOnBinder[index]['scale'] = _currentScale;
        _hasUnsavedChanges = true;
      }
    });
  }

  void _onStickerRotationUpdate(double angle, String id) {
    if (!mounted) return;
    setState(() {
      final index = _stickersOnBinder.indexWhere((s) => s['id'] == id);
      if (index != -1) {
        _stickersOnBinder[index]['rotation'] = angle;
        _hasUnsavedChanges = true;
      }
    });
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
    
    // Inicializa as variáveis temporárias com os valores atuais
    _tempCoverPath = widget.currentCover;
    _tempKeychainPath = widget.currentKeychain;
    
    // Inicializa o controlador de abas
    _tabController = TabController(length: 3, vsync: this);
    
    // Carrega os adesivos do binder
    _loadStickers();
    _hasUnsavedChanges = false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.pink[50]!, Colors.purple[50]!],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pink[100]!.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone decorativo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.pink[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite,
                  color: Colors.pink[600],
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              // Título
              Text(
                'Opa, espera aí! ✨',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[800],
                ),
              ),
              const SizedBox(height: 12),
              // Mensagem
              Text(
                'Você tem alterações não salvas no seu álbum! O que você gostaria de fazer?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // Botões
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botão Salvar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _saveStickers();
                        if (mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
                      ),
                      child: const Text('Salvar e sair'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Botão Continuar editando
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                      child: const Text('Continuar editando'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Link para descartar
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.pink[600],
                ),
                child: const Text(
                  'Descartar alterações e sair',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar Álbum'),
          actions: [
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Text(
                    'Não salvo',
                    style: TextStyle(
                      color: Colors.orange[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _hasUnsavedChanges ? _saveStickers : null,
              tooltip: 'Salvar alterações',
            ),
          ],
        ),
        body: Stack(
          children: [
            // Conteúdo principal com a visualização do binder
            Stack(
              children: [
                // Trash can icon (visible when dragging a selected sticker)
                if (_isDraggingSticker && _selectedStickerId != null)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.delete_forever,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      if (_selectedStickerId != null && _dragPosition != null) {
                        setState(() {
                          _dragPosition = details.globalPosition;
                        });
                      }
                    },
                    onPanEnd: (details) async {
                      if (_dragPosition != null && _selectedStickerId != null) {
                        setState(() {
                          _isAddingSticker = true;
                        });

                        try {
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final localPosition = box.globalToLocal(_dragPosition!);
                          
                          // Atualiza a posição do sticker existente
                          final stickerIndex = _stickersOnBinder.indexWhere(
                            (s) => s['image_path'] == _selectedStickerId
                          );
                          
                          if (stickerIndex != -1) {
                            final existingId = _stickersOnBinder[stickerIndex]['id'];
                            if (!_isOverTrashCan(details.globalPosition, context)) {
                              _addOrUpdateSticker(
                                _selectedStickerId!, 
                                localPosition,
                                existingId: existingId,
                              );
                            } else {
                              _removeSticker(existingId);
                            }
                          } else {
                            if (!_isOverTrashCan(details.globalPosition, context)) {
                              _addOrUpdateSticker(_selectedStickerId!, localPosition);
                            }
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isAddingSticker = false;
                              _selectedStickerId = null;
                              _isDraggingSticker = false;
                              _dragPosition = null;
                            });
                          }
                        }
                      } else {
                        if (mounted) {
                          setState(() {
                            _selectedStickerId = null;
                            _dragPosition = null;
                          });
                        }
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
                            margin: const EdgeInsets.only(bottom: 160),
                            child: Image.asset(
                              selectedCover,
                              key: _capaKey,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        // Adesivos na capa
                        ..._stickersOnBinder.map((sticker) {
                          try {
                            final x = (sticker['x'] ?? 0.0).toDouble();
                            final y = (sticker['y'] ?? 0.0).toDouble();
                            
                            debugPrint('📍 Sticker original position - x: $x, y: $y');
                            
                            // Cria uma cópia do sticker para não modificar o original
                            final Map<String, dynamic> stickerForRendering = Map<String, dynamic>.from(sticker);
                            
                            // Se as coordenadas já estão em pixels (maiores que 1.0), assume que são absolutas
                            if (x > 1.0 || y > 1.0) {
                              debugPrint('📌 Usando posição absoluta');
                              stickerForRendering['x'] = x;
                              stickerForRendering['y'] = y;
                            } else {
                              debugPrint('📐 Convertendo posição relativa para absoluta');
                              final absolutePosition = _getAbsoluteFromCover(Offset(x, y));
                              debugPrint('🎯 Posição absoluta calculada: $absolutePosition');
                              stickerForRendering['x'] = absolutePosition.dx;
                              stickerForRendering['y'] = absolutePosition.dy;
                            }
                            
                            return DraggableSticker(
                              key: ValueKey(sticker['id']),
                              sticker: stickerForRendering,
                              onPositionUpdate: (id, position) {
                                final index = _stickersOnBinder.indexWhere((s) => s['id'] == id);
                                if (index != -1) {
                                  setState(() {
                                    _isDraggingSticker = true;
                                    final relativePosition = _getRelativeToCover(position);
                                    _stickersOnBinder[index]['x'] = relativePosition.dx;
                                    _stickersOnBinder[index]['y'] = relativePosition.dy;
                                    _selectedStickerId = id; // Select on drag
                                    _hasUnsavedChanges = true;
                                  });
                                }
                              },
                              onRemove: (id) {
                                setState(() {
                                  _stickersOnBinder.removeWhere((s) => s['id'] == id);
                                  _selectedStickerId = null;
                                  _isDraggingSticker = false;
                                  _hasUnsavedChanges = true;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Adesivo removido')),
                                  );
                                });
                              },
                              isSelected: _selectedStickerId == sticker['id'],
                            );
                          } catch (e) {
                            debugPrint('❌ Erro ao renderizar sticker: $e');
                            return const SizedBox.shrink();
                          }
                          

                        }).toList(),
                        if (_selectedStickerId != null && _dragPosition != null) ...[
                          Positioned(
                            left: _dragPosition!.dx - 30,
                            top: _dragPosition!.dy - 30 - MediaQuery.of(context).padding.top,
                            child: Opacity(
                              opacity: 0.8,
                              child: Image.asset(
                                _selectedStickerId!,
                                width: 60,
                                height: 60,
                                errorBuilder: (context, error, stackTrace) {
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          )
                        ],
                        // Chaveiro
                        ...(selectedKeychain != null && selectedKeychain!.isNotEmpty
                          ? [
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
                              )
                            ]
                          : []),
                        // Os controles de transformação foram movidos para a parte inferior da tela
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Controles de transformação (parte inferior da tela)
            if (_selectedStickerId != null) _buildTransformationControls(),
            
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
                                  _tempCoverPath = cover['cover']!;
                                  selectedCover = cover['cover']!;
                                  selectedSpine = cover['spine']!;
                                  _hasUnsavedChanges = true;
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
                                  _tempKeychainPath = null;
                                  selectedKeychain = null;
                                  _hasUnsavedChanges = true;
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
                                      _tempKeychainPath = keychain.imagePath;
                                      selectedKeychain = keychain.imagePath;
                                      _hasUnsavedChanges = true;
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
                                onTapDown: (details) async {
                                  final stickerPath = 'assets/stickers/sticker_${stickerId.replaceAll('sticker', '')}.png';

                                  try {
                                    // Tenta carregar o asset
                                    await rootBundle.load(stickerPath);

                                    // Precarrega a imagem para evitar o frame vazio ou cinza
                                    await precacheImage(AssetImage(stickerPath), context);

                                    // Só define se for válido e já carregado
                                    if (mounted) {
                                      setState(() {
                                        _selectedStickerId = stickerPath;
                                        _dragPosition = details.globalPosition;
                                      });
                                    }
                                  } catch (e) {
                                    debugPrint('❌ Sticker inválido ignorado: $stickerPath');
                                  }
                                },
                                onPanStart: (details) {
                                  setState(() {
                                    _isDraggingSticker = true;
                                    _selectedStickerId = 'assets/stickers/sticker_${stickerId.replaceAll('sticker', '')}.png';
                                    _dragPosition = details.globalPosition;
                                  });
                                },
                                onPanUpdate: (details) {
                                  setState(() {
                                    _dragPosition = details.globalPosition;
                                  });
                                },
                                onPanEnd: (details) {
                                  setState(() {
                                    _isDraggingSticker = false;
                                  });
                                  
                                  if (_dragPosition != null && _selectedStickerId != null) {
                                    // Já temos o caminho completo em _selectedStickerId
                                    if (!_selectedStickerId!.endsWith('.png')) {
                                      debugPrint('❌ Caminho inválido de adesivo: ${_selectedStickerId}');
                                      setState(() {
                                        _selectedStickerId = null;
                                        _dragPosition = null;
                                      });
                                      return;
                                    }
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
    ));
  }

  void _updateSelectedStickerTransformation() {
    if (_selectedStickerId == null) return;

    final index = _stickersOnBinder.indexWhere((s) => s['id'] == _selectedStickerId);
    if (index != -1) {
      setState(() {
        _stickersOnBinder[index]['scale'] = _currentScale;
        _stickersOnBinder[index]['rotation'] = _currentRotation;
        _hasUnsavedChanges = true;
      });
    }
  }

  // Sliders visíveis somente quando um sticker está selecionado
  Widget _buildTransformationControls() {
    if (_selectedStickerId == null) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 179, // Aumentado para posicionar mais para cima e mostrar os dois sliders
      child: Stack(
        children: [
          // Container principal com os controles
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(25.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10.0,
                  spreadRadius: 2.0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Controle de Escala
                Row(
                  children: [
                    const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.grey[600],
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withOpacity(0.2),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                        ),
                        child: Slider(
                          value: _currentScale,
                          min: 0.5,
                          max: 3.0,
                          onChanged: (value) {
                            setState(() {
                              _currentScale = value;
                              final index = _stickersOnBinder.indexWhere((s) => s['id'] == _selectedStickerId);
                              if (index != -1) {
                                _stickersOnBinder[index]['scale'] = value;
                              }
                            });
                          },
                          onChangeEnd: (_) => _updateSelectedStickerTransformation(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(_currentScale * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Controle de Rotação
                Row(
                  children: [
                    const Icon(Icons.rotate_right, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.grey[600],
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withOpacity(0.2),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                        ),
                        child: Slider(
                          value: _currentRotation,
                          min: 0,
                          max: 2 * 3.14159265359,
                          onChanged: (value) {
                            setState(() {
                              _currentRotation = value;
                              final index = _stickersOnBinder.indexWhere((s) => s['id'] == _selectedStickerId);
                              if (index != -1) {
                                _stickersOnBinder[index]['rotation'] = value;
                              }
                            });
                          },
                          onChangeEnd: (_) => _updateSelectedStickerTransformation(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(_currentRotation * 180 / 3.14159265359).toInt()}°',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Botão de fechar posicionado no canto superior direito do painel
          Positioned(
            top: 4,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              padding: const EdgeInsets.all(8.0),
              onPressed: () {
                setState(() {
                  _selectedStickerId = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}