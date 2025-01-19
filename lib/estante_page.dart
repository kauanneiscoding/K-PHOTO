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
  late List<Binder> _binders;

  @override
  void initState() {
    super.initState();
    _binders = [
      Binder(
        coverAsset: 'assets/capas/capabinder1.png',
        spineAsset: 'assets/capas/lombadabinder1.png',
        isOpen: false,
        keychainAsset: null,
      ),
      Binder(
        coverAsset: 'assets/capas/capabinder2.png',
        spineAsset: 'assets/capas/lombadabinder2.png',
        isOpen: false,
        keychainAsset: null,
      ),
      Binder(
        coverAsset: 'assets/capas/capabinder3.png',
        spineAsset: 'assets/capas/lombadabinder3.png',
        isOpen: false,
        keychainAsset: null,
      ),
      Binder(
        coverAsset: 'assets/capas/capabinder4.png',
        spineAsset: 'assets/capas/lombadabinder4.png',
        isOpen: false,
        keychainAsset: null,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Minha Estante'),
        centerTitle: false,
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
            ),
          ),
        ),
      ),
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

    _updateAnimationState();
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

class Binder {
  final String coverAsset;
  final String spineAsset;
  bool isOpen;
  final String? keychainAsset;
  final String? binderName;

  Binder({
    required this.coverAsset,
    required this.spineAsset,
    this.isOpen = false,
    this.keychainAsset,
    this.binderName,
  });
}

class ShelfWidget extends StatefulWidget {
  final List<Binder> binders;
  final DataStorageService dataStorageService;

  const ShelfWidget({
    Key? key,
    required this.binders,
    required this.dataStorageService,
  }) : super(key: key);

  @override
  _ShelfWidgetState createState() => _ShelfWidgetState();
}

class _ShelfWidgetState extends State<ShelfWidget> {
  late List<Binder> _binders;

  @override
  void initState() {
    super.initState();
    _binders = widget.binders;
    _loadBinderCovers();
  }

  Future<void> _loadBinderCovers() async {
    for (int i = 0; i < _binders.length; i++) {
      final covers =
          await widget.dataStorageService.getBinderCovers(i.toString());
      if (covers != null && mounted) {
        setState(() {
          _binders[i] = Binder(
            coverAsset: covers['cover']!,
            spineAsset: covers['spine']!,
            isOpen: _binders[i].isOpen,
            keychainAsset: covers['keychain'],
            binderName: covers['name'],
          );
        });
      }
    }
  }

  void _toggleBinder(int index) {
    setState(() {
      if (_binders[index].isOpen) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BinderViewPage(
              binderId: index.toString(),
              binderCover: _binders[index].coverAsset,
              binderSpine: _binders[index].spineAsset,
              binderIndex: index,
              dataStorageService: widget.dataStorageService,
            ),
          ),
        ).then((_) {
          // Recarrega as capas quando voltar da edição
          _loadBinderCovers();
        });
      } else {
        for (int i = 0; i < _binders.length; i++) {
          _binders[i].isOpen = i == index;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.only(left: 20.0),
      clipBehavior: Clip.none,
      scrollDirection: Axis.horizontal,
      itemCount: widget.binders.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            _toggleBinder(index);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: AnimatedBinderWrapper(
              isOpen: _binders[index].isOpen,
              child: BinderWidget(
                binder: _binders[index],
                isOpen: _binders[index].isOpen,
              ),
            ),
          ),
        );
      },
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
