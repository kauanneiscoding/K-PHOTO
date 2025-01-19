import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/photocard.dart';
import '../models/photocard_model.dart';
import '../data_storage_service.dart';

class PhotocardMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DataStorageService _storageService = DataStorageService();

  Future<void> migratePhotocards() async {
    // Abrir banco de dados local
    Database database = await openDatabase(
      join(await getDatabasesPath(), DataStorageService.dbName),
      version: DataStorageService.dbVersion,
    );

    // Buscar todos os photocards
    List<Map<String, dynamic>> localPhotocards = await database.query('photocards');

    for (var localPhotocard in localPhotocards) {
      // Converter Photocard local para PhotocardModel do Firebase
      PhotocardModel firebasePhotocard = PhotocardModel(
        title: localPhotocard['instance_id'], // Usando instance_id como título temporário
        imageUrl: localPhotocard['image_path'],
        artist: 'Desconhecido', // Você pode querer adicionar mais campos
        album: 'Álbum Migrado',
        group: 'Grupo Desconhecido',
        description: 'Photocard migrado do banco de dados local',
      );

      // Adicionar ao Firestore
      await _firestore.collection('photocards').add(firebasePhotocard.toMap());
    }

    print('Migração concluída: ${localPhotocards.length} photocards transferidos');
  }

  // Método para verificar se a migração já foi feita
  Future<bool> isPhotocardsAlreadyMigrated() async {
    QuerySnapshot snapshot = await _firestore.collection('photocards').get();
    return snapshot.docs.isNotEmpty;
  }
}
