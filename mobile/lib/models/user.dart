class User {
  final int id;
  final String? username;
  final String? email;
  final String userGroup;
  final bool isAnonymous;
  final bool isBanned;
  final String createdAt;

  User({
    required this.id,
    this.username,
    this.email,
    required this.userGroup,
    required this.isAnonymous,
    required this.isBanned,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String?,
      email: json['email'] as String?,
      userGroup: json['user_group'] as String,
      isAnonymous: json['is_anonymous'] as bool,
      isBanned: json['is_banned'] as bool,
      createdAt: json['created_at'] as String,
    );
  }

  bool get isAdmin => userGroup == 'admin';
}
