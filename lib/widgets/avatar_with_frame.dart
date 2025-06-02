import 'package:flutter/material.dart';

class AvatarWithFrame extends StatelessWidget {
  final String? imageUrl;
  final String framePath;
  final double size;
  final bool showOnlineStatus;
  final bool isOnline;

  const AvatarWithFrame({
    Key? key,
    this.imageUrl,
    this.framePath = 'assets/frame_none.png',
    this.size = 50.0,
    this.showOnlineStatus = false,
    this.isOnline = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageSize = size * 0.9; // Tamanho da imagem ligeiramente menor que a moldura
    final frameSize = size;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (framePath != 'assets/frame_none.png')
          Stack(
            alignment: Alignment.center,
            children: [
              // Fundo circular para o ícone (quando não há imagem)
              if (imageUrl == null || imageUrl!.isEmpty)
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey,
                  ),
                ),
              
              // Imagem ou ícone recortado
              ClipPath(
                clipper: _MolduraClipper(),
                child: Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: imageUrl != null && imageUrl!.isNotEmpty
                        ? DecorationImage(
                            image: imageUrl!.startsWith('http')
                                ? NetworkImage(imageUrl!) as ImageProvider
                                : AssetImage(imageUrl!) as ImageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (imageUrl == null || imageUrl!.isEmpty)
                      ? Center(
                          child: Icon(
                            Icons.person,
                            color: Colors.pink[300],
                            size: imageSize * (framePath.endsWith('frame_none.png') ? 0.7 : 0.6), // Ícone menor quando tem moldura
                          ),
                        )
                      : null,
                ),
              ),
              
              // Moldura
              Image.asset(
                framePath,
                width: frameSize,
                height: frameSize,
                fit: BoxFit.contain,
              ),
            ],
          )
        else
          // Sem moldura
          CircleAvatar(
            radius: imageSize / 2,
            backgroundColor: Colors.grey[200],
            backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                ? (imageUrl!.startsWith('http')
                    ? NetworkImage(imageUrl!) as ImageProvider
                    : AssetImage(imageUrl!) as ImageProvider)
                : null,
            child: (imageUrl == null || imageUrl!.isEmpty)
                ? Icon(
                    Icons.person,
                    color: Colors.pink[300],
                    size: imageSize * 0.7,
                  )
                : null,
          ),
        
        // Status online
        if (showOnlineStatus && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MolduraClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: (size.width - 4) / 2, // Ligeiramente menor que a moldura
      ));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
