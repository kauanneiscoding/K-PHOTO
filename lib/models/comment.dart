class Comment {
  final String? id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;

  // Novos campos obtidos via JOIN com user_profile
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  Comment({
    this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
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
        print('Erro ao converter data: ${map['created_at']}');
      }
    }

    final userProfile = map['user_profile'] ?? {};

    return Comment(
      id: map['id']?.toString(),
      postId: map['post_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      createdAt: parsedDate ?? DateTime.now(),
      username: userProfile['username']?.toString(),
      displayName: userProfile['display_name']?.toString(),
      avatarUrl: userProfile['avatar_url']?.toString(),
    );
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? content,
    DateTime? createdAt,
    String? username,
    String? displayName,
    String? avatarUrl,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
