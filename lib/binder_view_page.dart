import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:k_photo/data_storage_service.dart';
import 'binder_page.dart';
import 'edit_binder_page.dart';
import 'models/keychain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BinderViewPage extends StatefulWidget {
  final String binderId;
  final String binderCover;
  final String binderSpine;
  final int binderIndex;
  final DataStorageService dataStorageService;

  const BinderViewPage({
    super.key,
    required this.binderId,
    required this.binderCover,
    required this.binderSpine,
    required this.binderIndex,
    required this.dataStorageService,
  });

  @override
  _BinderViewPageState createState() => _BinderViewPageState();
}

class _BinderViewPageState extends State<BinderViewPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragPosition = 0.0;
  bool isOpen = false;
  String coverAsset = '';
  String spineAsset = '';
  String? keychainAsset;
  final _supabaseClient = Supabase.instance.client;
  final GlobalKey _capaKey = GlobalKey(); // Chave para acessar o RenderBox da capa
  List<Map<String, dynamic>> _stickersOnBinder = [];
  String? _selectedStickerId; // ID do sticker atualmente selecionado

  // Adicione esta lista de keychains disponíveis
  final List<Keychain> availableKeychains = [
    Keychain(id: '1', imagePath: 'assets/keychain/keychain1.png'),
    Keychain(id: '2', imagePath: 'assets/keychain/keychain2.png'),
    Keychain(id: '3', imagePath: 'assets/keychain/keychain3.png'),
  ];

  String? currentKeychain;

  // Dimensões reais da imagem da capa
  double _imageWidth = 800.0; // Valor padrão, será substituído
  double _imageHeight = 1200.0; // Valor padrão, será substituído
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    coverAsset = widget.binderCover;
    spineAsset = widget.binderSpine;
    _loadBinderData();
    _loadStickers();
    _loadImageDimensions();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Atualizar o estado do binder para aberto
    widget.dataStorageService.updateBinderState(widget.binderId, true);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BinderPage(
              binderId: widget.binderId,
              dataStorageService: widget.dataStorageService,
            ),
          ),
        );
      }
    });
    _loadBinderData();
  }

  Future<void> _loadBinderData() async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) return;

    final binder = await _supabaseClient
        .from('binders')
        .select()
        .eq('id', widget.binderId)
        .eq('user_id', userId)
        .maybeSingle();

    if (binder != null) {
      setState(() {
        coverAsset = binder['cover_asset'];
        spineAsset = binder['spine_asset'];
        keychainAsset = binder['keychain_asset'];
      });
    }
  }
  
  Future<void> _loadStickers() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return;
      
      debugPrint('🔍 Buscando adesivos para o binder: ${widget.binderId}');
      
      final response = await _supabaseClient
          .from('binder_stickers')
          .select()
          .eq('binder_id', widget.binderId)
          .eq('user_id', userId);
          
      debugPrint('📦 Resposta do banco de dados: $response');
          
      if (mounted) {
        setState(() {
          _stickersOnBinder = List<Map<String, dynamic>>.from(response.map((sticker) {
            // Log detalhado do sticker recebido
            debugPrint('📝 Sticker recebido: ${sticker.toString()}');
            
            // Tenta obter as coordenadas de diferentes campos (para compatibilidade)
            final x = _getStickerCoordinate(sticker, 'x');
            final y = _getStickerCoordinate(sticker, 'y');
            
            // Tenta obter a posição dos campos antigos se os atuais forem zero
            final effectiveX = x != 0.0 ? x : _getStickerCoordinate(sticker, 'position_x');
            final effectiveY = y != 0.0 ? y : _getStickerCoordinate(sticker, 'position_y');
            
            debugPrint('📍 Coordenadas processadas - x: $effectiveX, y: $effectiveY');
            
            final stickerData = {
              'id': sticker['id'] ?? '',
              'image_path': sticker['image_path'] ?? '',
              'x': effectiveX,
              'y': effectiveY,
              'scale': _getStickerCoordinate(sticker, 'scale', defaultValue: 1.0),
              'rotation': _getStickerCoordinate(sticker, 'rotation'),
            };
            
            debugPrint('🎨 Sticker processado: $stickerData');
            return stickerData;
          }));
          
          debugPrint('✅ Adesivos carregados: ${_stickersOnBinder.length} itens');
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar adesivos: $e');
    }
  }

  void _showKeychainPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Escolha um chaveiro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[300],
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Opção para remover o keychain
                  GestureDetector(
                    onTap: () async {
                      await widget.dataStorageService.saveBinderKeychain(
                        widget.binderId,
                        '',
                      );
                      setState(() {
                        currentKeychain = null;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.remove_circle, color: Colors.grey[400]),
                    ),
                  ),
                  // Lista de keychains disponíveis
                  ...availableKeychains.map((keychain) => GestureDetector(
                        onTap: () async {
                          await widget.dataStorageService.saveBinderKeychain(
                            widget.binderId,
                            keychain.imagePath,
                          );
                          setState(() {
                            currentKeychain = keychain.imagePath;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: currentKeychain == keychain.imagePath
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
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToEditBinder() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditBinderPage(
          binderId: widget.binderId,
          currentCover: coverAsset,
          currentSpine: spineAsset,
          currentKeychain: keychainAsset,
          onCoversChanged: (cover, spine, keychain) async {
            await widget.dataStorageService.updateBinderCovers(
              widget.binderId,
              cover,
              spine,
            );
            await widget.dataStorageService.saveBinderKeychain(
              widget.binderId,
              keychain ?? '',
            );
            
            // Notificar atualização do binder
            widget.dataStorageService.notifyBinderUpdate();

            setState(() {
              coverAsset = cover;
              spineAsset = spine;
              keychainAsset = keychain;
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Atualizar o estado do binder para fechado quando a página é fechada
    widget.dataStorageService.updateBinderState(widget.binderId, false);
    _controller.dispose();
    super.dispose();
  }

  // Carrega as dimensões reais da imagem da capa
  Future<void> _loadImageDimensions() async {
    if (_isLoadingImage) return;
    
    _isLoadingImage = true;
    
    try {
      final coverAsset = widget.binderCover;
      final image = await _getImage(coverAsset);
      
      if (mounted) {
        setState(() {
          _imageWidth = image.image.width.toDouble();
          _imageHeight = image.image.height.toDouble();
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar dimensões da imagem: $e');
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }
  
  // Obtém as dimensões da imagem
  Future<ImageInfo> _getImage(String assetPath) async {
    final completer = Completer<ImageInfo>();
    final image = AssetImage(assetPath);
    
    image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, _) {
        if (!completer.isCompleted) {
          completer.complete(info);
        }
      }),
    );
    
    return completer.future;
  }

  // Método auxiliar para obter coordenadas de forma segura
  double _getStickerCoordinate(Map<String, dynamic> sticker, String key, {double defaultValue = 0.0}) {
    try {
      // Mapeia os campos antigos para os novos nomes
      final fieldMap = {
        'x': 'position_x',
        'y': 'position_y',
        'position_x': 'position_x',
        'position_y': 'position_y',
        'scale': 'scale',
        'rotation': 'rotation',
      };
      
      final fieldName = fieldMap[key] ?? key;
      
      if (!sticker.containsKey(fieldName)) {
        debugPrint('⚠️ Campo não encontrado: $fieldName (procurado como $key)');
        return defaultValue;
      }
      
      final value = sticker[fieldName];
      if (value == null) {
        debugPrint('⚠️ Valor nulo para o campo: $fieldName');
        return defaultValue;
      }
      
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
        debugPrint('⚠️ Não foi possível converter o valor para double: $value');
      }
      
      return defaultValue;
    } catch (e) {
      debugPrint('⚠️ Erro ao processar coordenada $key: $e');
      return defaultValue;
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition -=
          details.primaryDelta! / MediaQuery.of(context).size.width;
      _dragPosition = _dragPosition.clamp(0.0, 1.0);
      _controller.value = _dragPosition;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragPosition > 0.5) {
      _controller.forward();
      setState(() {
        isOpen = true;
      });
    } else {
      _controller.reverse();
      setState(() {
        isOpen = false;
      });
    }
    _dragPosition = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Binder ${widget.binderId} - Index ${widget.binderIndex}'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/edit-binder',
                arguments: {
                  'binderId': widget.binderId,
                  'cover': coverAsset,
                  'spine': spineAsset,
                  'keychain': keychainAsset,
                  'dataStorageService': widget.dataStorageService,
                },
              ).then((_) {
                // Recarregar os dados do binder após a edição
                _loadBinderData();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink[700],
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size(100, 36),
              fixedSize: Size(100, 36),
            ),
            child: Text(
              'EDITAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: Center(
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: MediaQuery.of(context).size.height * 0.8,
                          child: Transform(
                            alignment: Alignment.centerLeft,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(_animation.value * pi),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Stack(
                                  children: [
                                    // Capa do binder
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        key: _capaKey, // Adiciona a chave aqui para acessar o RenderBox
                                        width: MediaQuery.of(context).size.width * 0.8,
                                        height: MediaQuery.of(context).size.height * 0.8,
                                        child: Image.asset(
                                          coverAsset,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Image.asset(
                                              'assets/default_cover.png',
                                              fit: BoxFit.contain,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    // Adesivos
                                    ..._stickersOnBinder.map((sticker) {
                                      try {
                                        // Coordenadas do adesivo (já convertidas para double no _loadStickers)
                                        final x = sticker['x'] as double;
                                        final y = sticker['y'] as double;
                                        final imagePath = sticker['image_path'] as String;
                                        final scale = sticker['scale'] as double;
                                        final rotation = sticker['rotation'] as double;
                                        
                                        // Obtém o render box da capa para cálculos precisos
                                        final RenderBox? renderBox = _capaKey.currentContext?.findRenderObject() as RenderBox?;
                                        if (renderBox == null) {
                                          debugPrint('⚠️ Não foi possível obter o render box da capa');
                                          return const SizedBox.shrink();
                                        }
                                        
                                        // Obtém o tamanho do container da capa
                                        final Size containerSize = renderBox.size;
                                        
                                        // Usa as dimensões reais da imagem carregadas
                                        final double imageWidth = _imageWidth;
                                        final double imageHeight = _imageHeight;
                                        
                                        // Calcula o tamanho renderizado da imagem dentro do container
                                        final double widthRatio = containerSize.width / imageWidth;
                                        final double heightRatio = containerSize.height / imageHeight;
                                        final double imageScale = widthRatio < heightRatio ? widthRatio : heightRatio;
                                        
                                        final double renderedWidth = imageWidth * imageScale;
                                        final double renderedHeight = imageHeight * imageScale;
                                        
                                        // Calcula o offset para centralizar a imagem
                                        final double offsetX = (containerSize.width - renderedWidth) / 2;
                                        final double offsetY = (containerSize.height - renderedHeight) / 2;
                                        
                                        debugPrint('  - Cálculo do Offset Y:');
                                        debugPrint('     * Altura do Container: ${containerSize.height}');
                                        debugPrint('     * Altura Renderizada: $renderedHeight');
                                        debugPrint('     * Offset Y Calculado: $offsetY');
                                        
                                        // Tamanho base do adesivo (50x50) multiplicado pela escala
                                        const double baseStickerSize = 50.0;
                                        final double stickerSize = baseStickerSize * scale;
                                        
                                        // 1. Converte a posição normalizada (0-1) para coordenadas na imagem renderizada
                                        final double imageX = x * renderedWidth;
                                        final double imageY = y * renderedHeight;
                                        
                                        // 2. Calcula a posição do canto superior esquerdo do adesivo
                                        //    centralizado no ponto de ancoragem (x,y)
                                        final double stickerLeft = imageX - (stickerSize / 2);
                                        final double stickerTop = imageY - (stickerSize / 2);
                                        
                                        // 2.1. Ajusta para não ultrapassar os limites da imagem
                                        //      mas mantendo a posição centralizada quando possível
                                        final double adjustedLeft = stickerLeft.clamp(
                                          -stickerSize * 0.5, // Permite até metade do adesivo fora à esquerda
                                          renderedWidth - stickerSize * 0.5 // Permite até metade do adesivo fora à direita
                                        );
                                        
                                        final double adjustedTop = stickerTop.clamp(
                                          -stickerSize * 0.5, // Permite até metade do adesivo acima
                                          renderedHeight - stickerSize * 0.5 // Permite até metade do adesivo abaixo
                                        );
                                        
                                        // 3. Ajusta para a posição final no container
                                        final double finalLeft = adjustedLeft + offsetX;
                                        final double finalTop = adjustedTop + offsetY;
                                        
                                        // Debug
                                        debugPrint('📊 Posicionamento do adesivo:');
                                        debugPrint('  - Dimensões da imagem: ${_imageWidth}x${_imageHeight}');
                                        debugPrint('  - Dimensões renderizadas: ${renderedWidth.toStringAsFixed(1)}x${renderedHeight.toStringAsFixed(1)}');
                                        debugPrint('  - Posição normalizada: (${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)})');
                                        debugPrint('  - Posição na imagem: (${imageX.toStringAsFixed(1)}, ${imageY.toStringAsFixed(1)})');
                                        debugPrint('  - Posição do canto do adesivo: (${stickerLeft.toStringAsFixed(1)}, ${stickerTop.toStringAsFixed(1)})');
                                        debugPrint('  - Posição ajustada: (${adjustedLeft.toStringAsFixed(1)}, ${adjustedTop.toStringAsFixed(1)})');
                                        debugPrint('  - Offset da imagem: (${offsetX.toStringAsFixed(1)}, ${offsetY.toStringAsFixed(1)})');
                                        debugPrint('  - Posição final: (${finalLeft.toStringAsFixed(1)}, ${finalTop.toStringAsFixed(1)})');
                                        debugPrint('  - Tamanho do adesivo: ${stickerSize.toStringAsFixed(1)} (scale: $scale)');
                                        
                                        // Cálculo detalhado para debug
                                        debugPrint('🔍 Cálculo detalhado:');
                                        debugPrint('  1. Posição normalizada: (${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)})');
                                        debugPrint('  2. Para coordenadas de imagem:');
                                        debugPrint('     * X: ${x.toStringAsFixed(4)} * ${renderedWidth.toStringAsFixed(1)} = ${imageX.toStringAsFixed(1)}');
                                        debugPrint('     * Y: ${y.toStringAsFixed(4)} * ${renderedHeight.toStringAsFixed(1)} = ${imageY.toStringAsFixed(1)}');
                                        debugPrint('  3. Ajustando para o canto do adesivo (-${(stickerSize / 2).toStringAsFixed(1)}):');
                                        debugPrint('     * X: ${imageX.toStringAsFixed(1)} - ${(stickerSize / 2).toStringAsFixed(1)} = ${(imageX - (stickerSize / 2)).toStringAsFixed(1)}');
                                        debugPrint('     * Y: ${imageY.toStringAsFixed(1)} - ${(stickerSize / 2).toStringAsFixed(1)} = ${(imageY - (stickerSize / 2)).toStringAsFixed(1)}');
                                        debugPrint('  3. Ajustando para o canto do adesivo:');
                                        debugPrint('     * X: ${imageX.toStringAsFixed(1)} - ${(stickerSize / 2).toStringAsFixed(1)} = ${stickerLeft.toStringAsFixed(1)}');
                                        debugPrint('     * Y: ${imageY.toStringAsFixed(1)} - ${(stickerSize / 2).toStringAsFixed(1)} = ${stickerTop.toStringAsFixed(1)}');
                                        debugPrint('  4. Limitando aos limites da imagem:');
                                        debugPrint('     * X: ${stickerLeft.toStringAsFixed(1)} → limitado entre ${(-stickerSize * 0.5).toStringAsFixed(1)} e ${(renderedWidth - stickerSize * 0.5).toStringAsFixed(1)} = ${adjustedLeft.toStringAsFixed(1)}');
                                        debugPrint('     * Y: ${stickerTop.toStringAsFixed(1)} → limitado entre ${(-stickerSize * 0.5).toStringAsFixed(1)} e ${(renderedHeight - stickerSize * 0.5).toStringAsFixed(1)} = ${adjustedTop.toStringAsFixed(1)}');
                                        debugPrint('  5. Aplicando offset do container:');
                                        debugPrint('     * X final: ${adjustedLeft.toStringAsFixed(1)} + ${offsetX.toStringAsFixed(1)} = ${finalLeft.toStringAsFixed(1)}');
                                        debugPrint('     * Y final: ${adjustedTop.toStringAsFixed(1)} + ${offsetY.toStringAsFixed(1)} = ${finalTop.toStringAsFixed(1)}');
                                        
                                        return Positioned(
                                          left: finalLeft,
                                          top: finalTop,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedStickerId = sticker['id']?.toString();
                                              });
                                            },
                                            child: Transform.rotate(
                                              angle: rotation,
                                              child: Transform.scale(
                                                scale: scale,
                                                child: Image.asset(
                                                  imagePath,
                                                  width: baseStickerSize,
                                                  height: baseStickerSize,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        debugPrint('❌ Erro ao renderizar sticker: $e');
                                        return const SizedBox.shrink();
                                      }
                                    }).toList(),
                                  ],
                                ),
                                if (keychainAsset != null &&
                                    keychainAsset!.isNotEmpty)
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left:
                                            MediaQuery.of(context).size.width *
                                                -0.079,
                                        top:
                                            MediaQuery.of(context).size.height *
                                                0.069,
                                        child: Transform(
                                          transform: Matrix4.identity()
                                            ..rotateZ(0)
                                            ..translate(-78.0, 10.0),
                                          alignment: Alignment.topLeft,
                                          child: SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.60,
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.60,
                                            child: Image.asset(
                                              keychainAsset!,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
