import 'package:flutter/material.dart';
import 'dart:io';

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
    final hasFrame = framePath != 'assets/frame_none.png';
    
    // Proporções baseadas na profile_page
    final imageSize = size * (110 / 120); // 110/120 = 0.916
    final frameSize = size;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        if (hasFrame)
          Container(
            width: frameSize,
            height: frameSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Imagem ou ícone recortado
                ClipPath(
                  clipper: _MolduraClipper(framePath),
                  child: Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (imageUrl == null || imageUrl!.isEmpty) ? Colors.grey[200] : null,
                      image: imageUrl != null && imageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: imageUrl!.startsWith('http')
                                  ? NetworkImage(imageUrl!) as ImageProvider
                                  : FileImage(File(imageUrl!)) as ImageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (imageUrl == null || imageUrl!.isEmpty)
                        ? Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.pink[300],
                              size: size * 0.5, // Proporcional ao tamanho total
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
            ),
          )
        else
          // Sem moldura
          CircleAvatar(
            radius: size / 2,
            backgroundColor: Colors.grey[200],
            backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                ? (imageUrl!.startsWith('http')
                    ? NetworkImage(imageUrl!) as ImageProvider
                    : FileImage(File(imageUrl!)) as ImageProvider)
                : null,
            child: (imageUrl == null || imageUrl!.isEmpty)
                ? Icon(
                    Icons.person,
                    color: Colors.pink[300],
                    size: size * 0.5, // Proporcional ao tamanho total
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
  final String molduraAsset;

  _MolduraClipper(this.molduraAsset);

  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: (size.width - (20 * (size.width / 110))) / 2, // Ajuste proporcional ao tamanho
      ));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
