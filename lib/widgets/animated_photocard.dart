import 'package:flutter/material.dart';

class AnimatedPhotocard extends StatefulWidget {
  final String imageUrl;
  final VoidCallback onFlipComplete;

  const AnimatedPhotocard({
    Key? key,
    required this.imageUrl,
    required this.onFlipComplete,
  }) : super(key: key);

  @override
  State<AnimatedPhotocard> createState() => _AnimatedPhotocardState();
}

class _AnimatedPhotocardState extends State<AnimatedPhotocard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showFront = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          widget.onFlipComplete();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tamanho fixo para todos os photocards
    const double cardWidth = 141.0;
    const double cardHeight = 210.0;
    const double borderRadius = 15.0;

    return GestureDetector(
      onTap: () {
        if (!_showFront) {
          _controller.forward();
          setState(() => _showFront = true);
        }
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * 3.14;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: angle < 1.57
                ? Container(
                    width: cardWidth,
                    height: cardHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      color: Colors.pink[100],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.favorite,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: Container(
                        width: cardWidth,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 5,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          widget.imageUrl,
                          width: cardWidth,
                          height: cardHeight,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
