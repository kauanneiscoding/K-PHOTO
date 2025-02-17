class Binder {
  final String id;
  final String slots;
  final String coverAsset;
  final String spineAsset;
  final String? keychainAsset;
  final String binderName;
  final String createdAt;
  final String updatedAt;
  final int isOpen;
  final String userId;

  Binder({
    required this.id,
    required this.slots,
    required this.coverAsset,
    required this.spineAsset,
    this.keychainAsset,
    required this.binderName,
    required this.createdAt,
    required this.updatedAt,
    required this.isOpen,
    required this.userId,
  });

  factory Binder.fromMap(Map<String, dynamic> map) {
    return Binder(
      id: map['id'] as String,
      slots: map['slots'] as String,
      coverAsset: map['cover_asset'] as String,
      spineAsset: map['spine_asset'] as String,
      keychainAsset: map['keychain_asset'] as String?,
      binderName: map['binder_name'] as String,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isOpen: map['is_open'] as int,
      userId: map['user_id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'slots': slots,
      'cover_asset': coverAsset,
      'spine_asset': spineAsset,
      'keychain_asset': keychainAsset,
      'binder_name': binderName,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_open': isOpen,
      'user_id': userId,
    };
  }
}
