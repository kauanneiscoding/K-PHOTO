class Comment {
  int? id;
  int postId;
  String userId;
  String userName;
  String content;
  DateTime createdAt;

  Comment({
    this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'user_name': userName,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      postId: map['post_id'],
      userId: map['user_id'],
      userName: map['user_name'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
