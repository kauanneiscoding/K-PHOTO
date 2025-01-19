import 'package:flutter/material.dart';

class BinderDetailPage extends StatelessWidget {
  final int binderIndex;

  const BinderDetailPage({super.key, required this.binderIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalhes do Binder ${binderIndex + 1}'),
      ),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width *
              0.8, // Define uma largura de 80% da tela
          height: MediaQuery.of(context).size.height *
              0.8, // Define uma altura de 80% da tela
          child: Image.asset(
            'assets/capas/capabinder${binderIndex + 1}.png', // Capa do binder correspondente
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
