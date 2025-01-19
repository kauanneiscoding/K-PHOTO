import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/photocard_model.dart';

class PhotocardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Referência para a coleção de photocards
  CollectionReference get photocardCollection => 
      _firestore.collection('photocards');

  // Adicionar um novo photocard
  Future<String> addPhotocard(PhotocardModel photocard) async {
    try {
      final docRef = await photocardCollection.add(photocard.toMap());
      return docRef.id;
    } catch (e) {
      print('Erro ao adicionar photocard: $e');
      rethrow;
    }
  }

  // Buscar todos os photocards
  Stream<List<PhotocardModel>> getPhotocards() {
    return photocardCollection
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhotocardModel.fromFirestore(doc, null))
            .toList());
  }

  // Buscar photocards por grupo
  Stream<List<PhotocardModel>> getPhotocardsByGroup(String group) {
    return photocardCollection
        .where('group', isEqualTo: group)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhotocardModel.fromFirestore(doc, null))
            .toList());
  }

  // Buscar photocards por álbum
  Stream<List<PhotocardModel>> getPhotocardsByAlbum(String album) {
    return photocardCollection
        .where('album', isEqualTo: album)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhotocardModel.fromFirestore(doc, null))
            .toList());
  }

  // Atualizar um photocard
  Future<void> updatePhotocard(String id, PhotocardModel photocard) async {
    try {
      await photocardCollection.doc(id).update(photocard.toMap());
    } catch (e) {
      print('Erro ao atualizar photocard: $e');
      rethrow;
    }
  }

  // Deletar um photocard
  Future<void> deletePhotocard(String id) async {
    try {
      await photocardCollection.doc(id).delete();
    } catch (e) {
      print('Erro ao deletar photocard: $e');
      rethrow;
    }
  }

  // Incrementar quantidade de um photocard
  Future<void> incrementQuantity(String id, {int amount = 1}) async {
    try {
      await photocardCollection.doc(id).update({
        'quantity': FieldValue.increment(amount)
      });
    } catch (e) {
      print('Erro ao incrementar quantidade: $e');
      rethrow;
    }
  }
}
