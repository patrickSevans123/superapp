class AuthResult {
  final Map<String, dynamic> user;
  final String token;

  const AuthResult({required this.user, required this.token});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        user: json['user'] as Map<String, dynamic>,
        token: json['token'] as String,
      );
}
