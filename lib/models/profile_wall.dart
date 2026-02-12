class ProfileWallSlot {
  final int position; // 0, 1, 2 para as 3 posições do mural
  final String? photocardInstanceId;
  final String? photocardImagePath;
  final DateTime? placedAt;

  ProfileWallSlot({
    required this.position,
    this.photocardInstanceId,
    this.photocardImagePath,
    this.placedAt,
  });

  factory ProfileWallSlot.fromMap(Map<String, dynamic> map) {
    return ProfileWallSlot(
      position: map['position'] as int,
      photocardInstanceId: map['photocard_instance_id'] as String?,
      photocardImagePath: map['photocard_image_path'] as String?,
      placedAt: map['placed_at'] != null 
          ? DateTime.parse(map['placed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'photocard_instance_id': photocardInstanceId,
      'photocard_image_path': photocardImagePath,
      'placed_at': placedAt?.toIso8601String(),
    };
  }

  bool get isEmpty => photocardInstanceId == null;
}
