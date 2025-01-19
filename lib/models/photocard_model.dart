import 'package:cloud_firestore/cloud_firestore.dart';

class PhotocardModel {
  final String? id;
  final String title;
  final String imageUrl;
  final String artist;
  final String album;
  final String group;
  final DateTime dateAdded;
  final int quantity;
  final String? description;

  PhotocardModel({
    this.id,
    required this.title,
    required this.imageUrl,
    required this.artist,
    required this.album,
    required this.group,
    DateTime? dateAdded,
    this.quantity = 1,
    this.description,
  }) : dateAdded = dateAdded ?? DateTime.now();

  // Converter para Map para salvar no Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'artist': artist,
      'album': album,
      'group': group,
      'dateAdded': Timestamp.fromDate(dateAdded),
      'quantity': quantity,
      'description': description,
    };
  }

  // Criar objeto a partir de um documento do Firestore
  factory PhotocardModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data()!;
    return PhotocardModel(
      id: snapshot.id,
      title: data['title'],
      imageUrl: data['imageUrl'],
      artist: data['artist'],
      album: data['album'],
      group: data['group'],
      dateAdded: (data['dateAdded'] as Timestamp).toDate(),
      quantity: data['quantity'] ?? 1,
      description: data['description'],
    );
  }
}
