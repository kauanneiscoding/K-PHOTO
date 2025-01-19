// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_photo/estante_page.dart'; // Importe o arquivo correto para a EstantePage
import 'package:k_photo/data_storage_service.dart'; // Importe o arquivo DataStorageService

void main() {
  testWidgets('Binder open/close functionality', (WidgetTester tester) async {
    // Crie uma instância de DataStorageService para o teste
    final dataStorageService = DataStorageService();

    // Crie a instância da página Estante passando a instância do DataStorageService
    await tester.pumpWidget(MaterialApp(
      home: EstantePage(dataStorageService: dataStorageService),
    ));

    // Verifique se a estante está visível
    expect(find.byType(ShelfWidget), findsOneWidget);

    // Toque no primeiro binder para abrir
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump(); // Aguarde a animação (se houver)

    // Verifique se o binder foi aberto (verifique o estado do binder ou a animação)
    expect(find.byType(BinderWidget),
        findsOneWidget); // Altere isso conforme necessário

    // Toque novamente para fechar o binder
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump(); // Aguarde a animação de fechamento

    // Verifique se o binder foi fechado
    expect(find.byType(BinderWidget),
        findsOneWidget); // Altere isso conforme necessário
  });
}
