import '../entities/call_script.dart';
import '../entities/company_portrait.dart';

/// AI 仓库接口
///
/// 定义 AI 画像生成和话术生成功能的抽象接口
abstract class AIRepository {
  /// 生成企业画像
  ///
  /// [customerId] 客户 ID
  Future<CompanyPortrait> generatePortrait(String customerId);

  /// 获取缓存的企业画像
  ///
  /// [customerId] 客户 ID
  /// 返回 null 表示没有缓存
  Future<CompanyPortrait?> getCachedPortrait(String customerId);

  /// 生成话术
  ///
  /// [customerId] 客户 ID
  /// [scene] 场景
  /// [channel] 渠道
  /// [tone] 语气
  /// [templateId] 可选的模板 ID
  Future<CallScript> generateScript({
    required String customerId,
    required ScriptScene scene,
    required ScriptChannel channel,
    required ScriptTone tone,
    String? templateId,
  });

  /// 获取话术模板列表
  ///
  /// [scene] 可选的场景筛选
  /// [channel] 可选的渠道筛选
  Future<List<ScriptTemplate>> getTemplates({
    ScriptScene? scene,
    ScriptChannel? channel,
  });

  /// 保存话术为模板
  ///
  /// [script] 话术
  /// [name] 模板名称
  Future<ScriptTemplate> saveAsTemplate({
    required CallScript script,
    required String name,
  });

  /// 获取话术历史记录
  ///
  /// [customerId] 客户 ID
  /// [limit] 返回数量限制
  Future<List<CallScript>> getScriptHistory({
    String? customerId,
    int limit = 10,
  });
}
