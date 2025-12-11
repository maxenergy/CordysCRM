/// 跟进记录实体
class FollowRecord {
  final String id;
  final String? customerId;
  final String? clueId;
  final String content;
  final String? followType;
  final DateTime followAt;
  final String? createdBy;
  final List<String>? images;
  final String? audioUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FollowRecord({
    required this.id,
    this.customerId,
    this.clueId,
    required this.content,
    this.followType,
    required this.followAt,
    this.createdBy,
    this.images,
    this.audioUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// 跟进类型
  static const typePhone = 'phone';
  static const typeVisit = 'visit';
  static const typeWechat = 'wechat';
  static const typeEmail = 'email';
  static const typeOther = 'other';

  /// 获取跟进类型显示文本
  String get followTypeText {
    switch (followType) {
      case typePhone:
        return '电话';
      case typeVisit:
        return '拜访';
      case typeWechat:
        return '微信';
      case typeEmail:
        return '邮件';
      case typeOther:
        return '其他';
      default:
        return followType ?? '其他';
    }
  }

  /// 获取跟进类型图标名称
  String get followTypeIcon {
    switch (followType) {
      case typePhone:
        return 'phone';
      case typeVisit:
        return 'place';
      case typeWechat:
        return 'chat';
      case typeEmail:
        return 'email';
      default:
        return 'note';
    }
  }

  FollowRecord copyWith({
    String? id,
    String? customerId,
    String? clueId,
    String? content,
    String? followType,
    DateTime? followAt,
    String? createdBy,
    List<String>? images,
    String? audioUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FollowRecord(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      clueId: clueId ?? this.clueId,
      content: content ?? this.content,
      followType: followType ?? this.followType,
      followAt: followAt ?? this.followAt,
      createdBy: createdBy ?? this.createdBy,
      images: images ?? this.images,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
