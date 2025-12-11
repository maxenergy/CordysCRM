/// 话术场景
enum ScriptScene {
  firstContact('首次接触'),
  productIntro('产品介绍'),
  meetingInvite('邀约会议'),
  followUp('跟进回访');

  const ScriptScene(this.label);
  final String label;

  static ScriptScene fromString(String value) {
    return ScriptScene.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => ScriptScene.firstContact,
    );
  }
}

/// 话术渠道
enum ScriptChannel {
  phone('电话'),
  wechat('微信'),
  email('邮件');

  const ScriptChannel(this.label);
  final String label;

  static ScriptChannel fromString(String value) {
    return ScriptChannel.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => ScriptChannel.phone,
    );
  }
}

/// 话术语气
enum ScriptTone {
  professional('专业'),
  enthusiastic('热情'),
  concise('简洁');

  const ScriptTone(this.label);
  final String label;

  static ScriptTone fromString(String value) {
    return ScriptTone.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => ScriptTone.professional,
    );
  }
}

/// 话术实体类
class CallScript {
  const CallScript({
    required this.id,
    required this.content,
    this.scene = ScriptScene.firstContact,
    this.channel = ScriptChannel.phone,
    this.tone = ScriptTone.professional,
    this.customerId,
    this.templateId,
    required this.createdAt,
  });

  /// 话术 ID
  final String id;

  /// 话术内容
  final String content;

  /// 场景
  final ScriptScene scene;

  /// 渠道
  final ScriptChannel channel;

  /// 语气
  final ScriptTone tone;

  /// 关联的客户 ID
  final String? customerId;

  /// 使用的模板 ID
  final String? templateId;

  /// 创建时间
  final DateTime createdAt;

  factory CallScript.fromJson(Map<String, dynamic> json) {
    return CallScript(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      scene: ScriptScene.fromString(json['scene'] as String? ?? ''),
      channel: ScriptChannel.fromString(json['channel'] as String? ?? ''),
      tone: ScriptTone.fromString(json['tone'] as String? ?? ''),
      customerId: json['customerId'] as String?,
      templateId: json['templateId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'scene': scene.name,
      'channel': channel.name,
      'tone': tone.name,
      if (customerId != null) 'customerId': customerId,
      if (templateId != null) 'templateId': templateId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  CallScript copyWith({
    String? id,
    String? content,
    ScriptScene? scene,
    ScriptChannel? channel,
    ScriptTone? tone,
    String? customerId,
    String? templateId,
    DateTime? createdAt,
  }) {
    return CallScript(
      id: id ?? this.id,
      content: content ?? this.content,
      scene: scene ?? this.scene,
      channel: channel ?? this.channel,
      tone: tone ?? this.tone,
      customerId: customerId ?? this.customerId,
      templateId: templateId ?? this.templateId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 话术模板
class ScriptTemplate {
  const ScriptTemplate({
    required this.id,
    required this.name,
    required this.content,
    this.scene,
    this.channel,
    this.tone,
    this.industry,
    this.isSystem = false,
  });

  /// 模板 ID
  final String id;

  /// 模板名称
  final String name;

  /// 模板内容（包含变量占位符）
  final String content;

  /// 适用场景
  final ScriptScene? scene;

  /// 适用渠道
  final ScriptChannel? channel;

  /// 适用语气
  final ScriptTone? tone;

  /// 适用行业
  final String? industry;

  /// 是否为系统模板
  final bool isSystem;

  factory ScriptTemplate.fromJson(Map<String, dynamic> json) {
    return ScriptTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      scene: json['scene'] != null
          ? ScriptScene.fromString(json['scene'] as String)
          : null,
      channel: json['channel'] != null
          ? ScriptChannel.fromString(json['channel'] as String)
          : null,
      tone: json['tone'] != null
          ? ScriptTone.fromString(json['tone'] as String)
          : null,
      industry: json['industry'] as String?,
      isSystem: json['isSystem'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      if (scene != null) 'scene': scene!.name,
      if (channel != null) 'channel': channel!.name,
      if (tone != null) 'tone': tone!.name,
      if (industry != null) 'industry': industry,
      'isSystem': isSystem,
    };
  }
}
