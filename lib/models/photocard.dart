class Photocard {
  final String cardId;
  final String instanceId;
  final String imagePath;

  Photocard({
    required this.cardId,
    required this.instanceId,
    required this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'cardId': cardId,
      'instanceId': instanceId,
      'imagePath': imagePath,
    };
  }

  factory Photocard.fromMap(Map<String, dynamic> map) {
    return Photocard(
      cardId: map['cardId'],
      instanceId: map['instanceId'],
      imagePath: map['imagePath'],
    );
  }
}
