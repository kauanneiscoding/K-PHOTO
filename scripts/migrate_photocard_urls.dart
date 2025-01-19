import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:k_photo/data_storage_service.dart';
import 'package:k_photo/firebase_options.dart';
import 'package:k_photo/models/photocard.dart';

Future<void> migratePhotocardUrls() async {
  final dataStorageService = DataStorageService();

  try {
    // Buscar todos os photocards da biblioteca online
    final photocards = await dataStorageService.fetchOnlineLibrary();

    print('📸 Encontrados ${photocards.length} photocards para migração');

    // Atualizar URLs de cada photocard
    for (var photocard in photocards) {
      final updatedPhotocard = await dataStorageService.updatePhotocardWithStorageUrl(photocard);
      
      // Atualizar na biblioteca online
      await dataStorageService.addPhotocardToOnlineLibrary(updatedPhotocard);
      
      print('✅ Atualizado: ${updatedPhotocard.imagePath}');
    }

    print('🎉 Migração de URLs de photocards concluída!');
  } catch (e) {
    print('❌ Erro durante migração: $e');
  }
}

void main() async {
  // Garantir que o binding do Flutter esteja inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await migratePhotocardUrls();

  // Encerrar o processo após a migração
  exit(0);
}
