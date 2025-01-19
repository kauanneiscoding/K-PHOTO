class User {
  final String id;
  final String email;
  final String username;
  final String passwordHash;
  final DateTime createdAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.passwordHash,
    required this.createdAt,
    this.lastLogin,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'password_hash': passwordHash,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      username: map['username'],
      passwordHash: map['password_hash'],
      createdAt: DateTime.parse(map['created_at']),
      lastLogin:
          map['last_login'] != null ? DateTime.parse(map['last_login']) : null,
    );
  }
}
