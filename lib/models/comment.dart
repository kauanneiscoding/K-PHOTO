class Comment {
  final String? id;
  final String postId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;

  Comment({
    this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

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
    DateTime? parsedDate;
    if (map['created_at'] != null) {
      try {
        parsedDate = DateTime.tryParse(map['created_at'].toString());
      } catch (e) {
        print('Error parsing date: ${map['created_at']}');
      }
    }
    
    return Comment(
      id: map['id']?.toString(),
      postId: map['post_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      userName: map['user_name']?.toString() ?? 'Anônimo',
      content: map['content']?.toString() ?? '',
      createdAt: parsedDate ?? DateTime.now(),
    );
  }
  
  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? content,
    DateTime? createdAt,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
