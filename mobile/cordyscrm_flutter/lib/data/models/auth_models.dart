import '../../domain/entities/user.dart';

/// 登录请求
class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
      };
}

/// 登录响应
class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserModel user;

  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken'] ?? json['access_token'] ?? '',
      refreshToken: json['refreshToken'] ?? json['refresh_token'] ?? '',
      expiresIn: json['expiresIn'] ?? json['expires_in'] ?? 7200,
      user: UserModel.fromJson(json['user'] ?? {}),
    );
  }
}

/// 用户模型
class UserModel {
  final int id;
  final String username;
  final String? name;
  final String? email;
  final String? phone;
  final String? avatar;
  final String? organizationId;
  final List<String> roles;
  final List<String> permissions;

  const UserModel({
    required this.id,
    required this.username,
    this.name,
    this.email,
    this.phone,
    this.avatar,
    this.organizationId,
    this.roles = const [],
    this.permissions = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      avatar: json['avatar'],
      organizationId: json['organizationId'],
      roles: List<String>.from(json['roles'] ?? []),
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
        'organizationId': organizationId,
        'roles': roles,
        'permissions': permissions,
      };

  /// 转换为领域实体
  User toEntity() => User(
        id: id,
        username: username,
        name: name,
        email: email,
        phone: phone,
        avatar: avatar,
        organizationId: organizationId,
        roles: roles,
        permissions: permissions,
      );
}
