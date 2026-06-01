import 'package:shared_models/shared_models.dart';

class AuthResult {
  final UserModel user;
  final String token;

  const AuthResult({required this.user, required this.token});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        token: json['token'] as String,
      );
}
