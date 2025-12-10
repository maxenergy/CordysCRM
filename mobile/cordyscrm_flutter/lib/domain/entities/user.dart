/// 用户实体
class User {
  final int id;
  final String username;
  final String? name;
  final String? email;
  final String? phone;
  final String? avatar;
  final String? organizationId;
  final List<String> roles;
  final List<String> permissions;

  const User({
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

  /// 是否有指定权限
  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }

  /// 是否有指定角色
  bool hasRole(String role) {
    return roles.contains(role);
  }

  /// 显示名称
  String get displayName => name ?? username;
}
