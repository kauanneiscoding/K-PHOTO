import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

Future<void> uploadPhotocards() async {
  // Inicializar Firebase
  await Firebase.initializeApp();

  final storage = FirebaseStorage.instance;
  final photocardDir = Directory('c:/Users/ADMIN/k_photo/assets/photocards');

  if (!photocardDir.existsSync()) {
    print('❌ Diretório não encontrado: ${photocardDir.path}');
    return;
  }

  try {
    final photocards = photocardDir.listSync()
        .where((file) => file.path.endsWith('.png'))
        .toList();

    print('📸 Encontrados ${photocards.length} photocards para upload');

    for (var file in photocards) {
      final fileName = path.basename(file.path);
      final Reference storageRef = 
          storage.ref().child('photocards/$fileName');

      try {
        await storageRef.putFile(File(file.path));
        print('✅ Uploaded: $fileName');
      } catch (e) {
        print('❌ Erro ao fazer upload de $fileName: $e');
      }
    }

    print('🎉 Upload de photocards concluído!');
  } catch (e) {
    print('❌ Erro geral no upload: $e');
  }
}

void main() async {
  try {
    await uploadPhotocards();
  } catch (e) {
    print('❌ Erro fatal: $e');
  }
  exit(0);
}
