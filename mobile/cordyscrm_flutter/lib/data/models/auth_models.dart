import '../../domain/entities/user.dart';

/// 登录请求
class LoginRequest {
  final String username;
  final String password;
  final String platform;

  const LoginRequest({
    required this.username,
    required this.password,
    this.platform = 'mobile',
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'platform': platform,
      };
}

/// 登录响应
/// 后端返回包装格式: { code: 100200, data: SessionUser }
class LoginResponse {
  final String csrfToken;
  final String sessionId;
  final UserModel user;

  const LoginResponse({
    required this.csrfToken,
    required this.sessionId,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // 后端返回格式: { code: 100200, data: { ...SessionUser } }
    final data = json['data'] as Map<String, dynamic>? ?? json;
    
    return LoginResponse(
      csrfToken: data['csrfToken']?.toString() ?? '',
      sessionId: data['sessionId']?.toString() ?? '',
      user: UserModel.fromJson(data),
    );
  }

  /// 使用 sessionId 作为 accessToken
  String get accessToken => sessionId;

  /// 使用 csrfToken 作为 refreshToken
  String get refreshToken => csrfToken;
}

/// 用户模型
/// 对应后端 UserDTO/SessionUser
class UserModel {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? avatar;
  final String? organizationId;
  final List<String> roles;
  final List<String> permissions;

  const UserModel({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.avatar,
    this.organizationId,
    this.roles = const [],
    this.permissions = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // 从 permissionIds 提取权限列表
    final permissionIds = json['permissionIds'];
    final permissions = permissionIds is List
        ? permissionIds.map((e) => e.toString()).toList()
        : <String>[];

    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      avatar: json['avatar'],
      organizationId: json['lastOrganizationId'],
      roles: <String>[],
      permissions: permissions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
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
        id: int.tryParse(id) ?? 0,
        username: name ?? id,
        name: name,
        email: email,
        phone: phone,
        avatar: avatar,
        organizationId: organizationId,
        roles: roles,
        permissions: permissions,
      );
}
