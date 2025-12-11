/// 线索实体
class Clue {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? source;
  final String status;
  final String? owner;
  final String? remark;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Clue({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.source,
    required this.status,
    this.owner,
    this.remark,
    this.createdAt,
    this.updatedAt,
  });

  /// 线索状态
  static const statusNew = 'new';
  static const statusFollowing = 'following';
  static const statusConverted = 'converted';
  static const statusInvalid = 'invalid';

  /// 获取状态显示文本
  String get statusText {
    switch (status) {
      case statusNew:
        return '新线索';
      case statusFollowing:
        return '跟进中';
      case statusConverted:
        return '已转化';
      case statusInvalid:
        return '无效';
      default:
        return status;
    }
  }

  /// 是否可以转化为客户
  bool get canConvert => status == statusNew || status == statusFollowing;

  Clue copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? source,
    String? status,
    String? owner,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Clue(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      source: source ?? this.source,
      status: status ?? this.status,
      owner: owner ?? this.owner,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
