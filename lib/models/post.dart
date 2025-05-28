class Post {
  final String? id;
  final String userId;
  final String content;
  final String? mediaUrl;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? selectedFrame;
  final DateTime createdAt;
  
  int likesCount;
  int livesCount;
  int commentsCount = 0;
  List<Map<String, dynamic>> comments;
  bool isLiked;
  bool isReposted;

  Post({
    this.id,
    required this.userId,
    required this.content,
    this.mediaUrl,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.selectedFrame,
    DateTime? createdAt,
    int? likesCount,
    int? livesCount,
    int? commentsCount,
    List<Map<String, dynamic>>? comments,
    bool? isLiked,
    bool? isReposted,
  }) : createdAt = createdAt ?? DateTime.now(),
       likesCount = likesCount ?? 0,
       livesCount = livesCount ?? 0,
       commentsCount = commentsCount ?? 0,
       comments = comments ?? [],
       isLiked = isLiked ?? false,
       isReposted = isReposted ?? false;

  /// Converts the Post to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'media_url': mediaUrl,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'selected_frame': selectedFrame,
      'likes_count': likesCount,
      'lives_count': livesCount,
      'comments_count': comments.length,
      'is_liked': isLiked ? 1 : 0,
      'is_reposted': isReposted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a Post from a Map (from database or API)
  factory Post.fromMap(Map<String, dynamic> map) {
    final createdAt = map['created_at'] is String 
        ? DateTime.parse(map['created_at']) 
        : (map['created_at'] ?? DateTime.now());
    
    // Processa o comments_count
    final commentsCount = (map['comments_count'] ?? 0) is int
        ? map['comments_count'] ?? 0
        : int.tryParse(map['comments_count'].toString()) ?? 0;
        
    return Post(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString() ?? map['autor'] ?? 'unknown',
      content: map['content'] ?? map['conteudo'] ?? '',
      mediaUrl: map['media_url'] ?? map['midia_url'] ?? map['midia'],
      username: map['username'],
      displayName: map['display_name'],
      avatarUrl: map['avatar_url'],
      selectedFrame: map['selected_frame'],
      createdAt: createdAt is DateTime ? createdAt : DateTime.now(),
      likesCount: (map['likes_count'] ?? map['curtidas'] ?? 0) is int 
          ? map['likes_count'] ?? map['curtidas'] ?? 0 
          : int.tryParse(map['likes_count'].toString()) ?? 0,
      livesCount: (map['lives_count'] ?? map['republicacoes'] ?? 0) is int
          ? map['lives_count'] ?? map['republicacoes'] ?? 0
          : int.tryParse(map['lives_count'].toString()) ?? 0,
      commentsCount: commentsCount,
      isLiked: map['is_liked'] == true || map['is_liked'] == 1,
      isReposted: map['is_reposted'] == true || map['is_reposted'] == 1,
    );
  }
  
  /// Creates a copy of the Post with updated fields
  Post copyWith({
    String? id,
    String? userId,
    String? content,
    String? mediaUrl,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? selectedFrame,
    DateTime? createdAt,
    int? likesCount,
    int? livesCount,
    int? commentsCount,
    List<Map<String, dynamic>>? comments,
    bool? isLiked,
    bool? isReposted,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      selectedFrame: selectedFrame ?? this.selectedFrame,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      livesCount: livesCount ?? this.livesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
      isReposted: isReposted ?? this.isReposted,
    );
  }
}
