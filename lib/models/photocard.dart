class Photocard {
  final String imagePath;
  final String instanceId;
  final String binderId;
  final int slotIndex;
  final int pageNumber;

  Photocard({
    required this.imagePath,
    required this.instanceId,
    required this.binderId,
    required this.slotIndex,
    required this.pageNumber,
  });

  factory Photocard.fromMap(Map<String, dynamic> map) {
    return Photocard(
      imagePath: map['image_path'] as String,
      instanceId: map['instance_id'] as String,
      binderId: map['binder_id'] as String,
      slotIndex: map['slot_index'] as int,
      pageNumber: map['page_number'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'image_path': imagePath,
      'instance_id': instanceId,
      'binder_id': binderId,
      'slot_index': slotIndex,
      'page_number': pageNumber,
    };
  }
}
