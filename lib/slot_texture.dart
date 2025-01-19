//TEXTURA EM UM ARQUIVO SEPARADO

import 'package:flutter/material.dart';

class SlotTexture extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.5, // Ajuste a opacidade conforme necessário
        child: Image.asset(
          'assets/plastic_texture.png', // Caminho da textura de plástico
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
