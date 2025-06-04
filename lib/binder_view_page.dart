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

  // Adicione esta lista de keychains disponíveis
  final List<Keychain> availableKeychains = [
    Keychain(id: '1', imagePath: 'assets/keychain/keychain1.png'),
    Keychain(id: '2', imagePath: 'assets/keychain/keychain2.png'),
    Keychain(id: '3', imagePath: 'assets/keychain/keychain3.png'),
  ];

  String? currentKeychain;

  @override
  void initState() {
    super.initState();
    coverAsset = widget.binderCover;
    spineAsset = widget.binderSpine;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

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
                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.8,
                                    height: MediaQuery.of(context).size.height *
                                        0.8,
                                    child: Image.asset(
                                      coverAsset,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Image.asset(
                                          'assets/default_cover.png',
                                          fit: BoxFit.contain,
                                        );
                                      },
                                    ),
                                  ),
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
