import 'dart:convert';

class SocialMessage {
  final String id;
  final String userId;
  final String username;
  final String message;
  final String timestamp;
  final int likes;
  final int retweets;
  final int comments;
  final List<String> likedBy;
  final List<String> retweetedBy;

  SocialMessage({
    required this.id,
    required this.userId,
    required this.username,
    required this.message,
    required this.timestamp,
    this.likes = 0,
    this.retweets = 0,
    this.comments = 0,
    List<String>? likedBy,
    List<String>? retweetedBy,
  })  : likedBy = likedBy ?? [],
        retweetedBy = retweetedBy ?? [];

  factory SocialMessage.fromMap(Map<String, dynamic> map) {
    return SocialMessage(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String,
      message: map['message'] as String,
      timestamp: map['timestamp'] as String,
      likes: map['likes'] as int? ?? 0,
      retweets: map['retweets'] as int? ?? 0,
      comments: map['comments'] as int? ?? 0,
      likedBy: List<String>.from(
        jsonDecode(map['liked_by'] as String? ?? '[]'),
      ),
      retweetedBy: List<String>.from(
        jsonDecode(map['retweeted_by'] as String? ?? '[]'),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'message': message,
      'timestamp': timestamp,
      'likes': likes,
      'retweets': retweets,
      'comments': comments,
      'liked_by': jsonEncode(likedBy),
      'retweeted_by': jsonEncode(retweetedBy),
    };
  }
}
