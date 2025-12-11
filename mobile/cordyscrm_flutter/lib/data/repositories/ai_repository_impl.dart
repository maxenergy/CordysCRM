import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/call_script.dart';
import '../../domain/entities/company_portrait.dart';
import '../../domain/repositories/ai_repository.dart';

/// AI 仓库实现
class AIRepositoryImpl implements AIRepository {
  AIRepositoryImpl({
    required Dio dio,
    String basePath = '/api/ai',
  })  : _dio = dio,
        _basePath = basePath;

  final Dio _dio;
  final String _basePath;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  // 本地缓存
  final Map<String, CompanyPortrait> _portraitCache = {};
  final List<CallScript> _scriptHistory = [];

  @override
  Future<CompanyPortrait> generatePortrait(String customerId) async {
    _logger.d('生成企业画像: customerId=$customerId');

    try {
      final response = await _dio.post(
        '$_basePath/portrait/generate',
        data: {'customerId': customerId},
      );

      if (response.statusCode == 200) {
        final portrait = CompanyPortrait.fromJson(
          response.data as Map<String, dynamic>,
        );
        _portraitCache[customerId] = portrait;
        _logger.i('画像生成成功');
        return portrait;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: '生成失败: ${response.statusCode}',
      );
    } on DioException catch (e) {
      _logger.e('生成画像失败: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<CompanyPortrait?> getCachedPortrait(String customerId) async {
    return _portraitCache[customerId];
  }

  @override
  Future<CallScript> generateScript({
    required String customerId,
    required ScriptScene scene,
    required ScriptChannel channel,
    required ScriptTone tone,
    String? templateId,
  }) async {
    _logger.d('生成话术: scene=${scene.name}, channel=${channel.name}');

    try {
      final response = await _dio.post(
        '$_basePath/script/generate',
        data: {
          'customerId': customerId,
          'scene': scene.name,
          'channel': channel.name,
          'tone': tone.name,
          if (templateId != null) 'templateId': templateId,
        },
      );

      if (response.statusCode == 200) {
        final script = CallScript.fromJson(
          response.data as Map<String, dynamic>,
        );
        _scriptHistory.insert(0, script);
        if (_scriptHistory.length > 20) {
          _scriptHistory.removeLast();
        }
        _logger.i('话术生成成功');
        return script;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: '生成失败: ${response.statusCode}',
      );
    } on DioException catch (e) {
      _logger.e('生成话术失败: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<List<ScriptTemplate>> getTemplates({
    ScriptScene? scene,
    ScriptChannel? channel,
  }) async {
    _logger.d('获取话术模板');

    try {
      final response = await _dio.get(
        '$_basePath/script/templates',
        queryParameters: {
          if (scene != null) 'scene': scene.name,
          if (channel != null) 'channel': channel.name,
        },
      );

      if (response.statusCode == 200) {
        final list = (response.data as List<dynamic>)
            .map((e) => ScriptTemplate.fromJson(e as Map<String, dynamic>))
            .toList();
        return list;
      }

      return [];
    } catch (e) {
      _logger.e('获取模板失败: $e');
      return [];
    }
  }

  @override
  Future<ScriptTemplate> saveAsTemplate({
    required CallScript script,
    required String name,
  }) async {
    _logger.d('保存话术为模板: $name');

    try {
      final response = await _dio.post(
        '$_basePath/script/templates',
        data: {
          'name': name,
          'content': script.content,
          'scene': script.scene.name,
          'channel': script.channel.name,
          'tone': script.tone.name,
        },
      );

      if (response.statusCode == 200) {
        return ScriptTemplate.fromJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw Exception('保存失败');
    } catch (e) {
      _logger.e('保存模板失败: $e');
      rethrow;
    }
  }

  @override
  Future<List<CallScript>> getScriptHistory({
    String? customerId,
    int limit = 10,
  }) async {
    if (customerId != null) {
      return _scriptHistory
          .where((s) => s.customerId == customerId)
          .take(limit)
          .toList();
    }
    return _scriptHistory.take(limit).toList();
  }
}

/// Mock AI 仓库实现
class MockAIRepository implements AIRepository {
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  final _uuid = const Uuid();

  final Map<String, CompanyPortrait> _portraitCache = {};
  final List<CallScript> _scriptHistory = [];

  @override
  Future<CompanyPortrait> generatePortrait(String customerId) async {
    _logger.d('[Mock] 生成企业画像: customerId=$customerId');

    await Future.delayed(const Duration(seconds: 2));

    final portrait = CompanyPortrait(
      customerId: customerId,
      generatedAt: DateTime.now(),
      basicInfo: const PortraitBasicInfo(
        industry: '互联网/软件',
        scale: '中型企业（100-500人）',
        mainProducts: '企业管理软件、CRM系统、数据分析平台',
        foundedYear: '2015',
        employeeCount: '约300人',
        annualRevenue: '5000万-1亿',
      ),
      insights: const [
        BusinessInsight(
          title: '数字化转型需求强烈',
          confidence: 0.85,
          source: '行业报告分析',
          description: '该企业所在行业正处于数字化转型关键期，对企业管理软件需求旺盛',
        ),
        BusinessInsight(
          title: '预算充足，决策周期短',
          confidence: 0.72,
          source: '历史交易数据',
          description: '根据同类客户分析，该规模企业通常有较充足的IT预算',
        ),
        BusinessInsight(
          title: '存在扩展合作机会',
          confidence: 0.68,
          source: '业务分析',
          description: '客户业务增长迅速，未来可能有更多系统集成需求',
        ),
      ],
      risks: const [
        RiskAlert(
          title: '竞争对手已接触',
          level: RiskLevel.medium,
          description: '据悉竞争对手已与该客户有过初步接触',
          category: '竞争风险',
        ),
        RiskAlert(
          title: '决策链较长',
          level: RiskLevel.low,
          description: '该企业采购决策需要多部门审批',
          category: '流程风险',
        ),
      ],
      opinions: const [
        PublicOpinion(
          title: '公司获得B轮融资',
          source: '36氪',
          sentiment: Sentiment.positive,
        ),
        PublicOpinion(
          title: '行业竞争加剧',
          source: '行业周刊',
          sentiment: Sentiment.neutral,
        ),
      ],
    );

    _portraitCache[customerId] = portrait;
    return portrait;
  }

  @override
  Future<CompanyPortrait?> getCachedPortrait(String customerId) async {
    return _portraitCache[customerId];
  }

  @override
  Future<CallScript> generateScript({
    required String customerId,
    required ScriptScene scene,
    required ScriptChannel channel,
    required ScriptTone tone,
    String? templateId,
  }) async {
    _logger.d('[Mock] 生成话术');

    await Future.delayed(const Duration(seconds: 1));

    final contents = {
      ScriptScene.firstContact: '''您好，我是XX公司的销售顾问小王。

了解到贵公司在企业管理方面有一些需求，我们公司专注于为中型企业提供一站式CRM解决方案，已经服务了超过500家企业客户。

不知道您现在方便聊几分钟吗？我想简单了解一下贵公司目前的业务情况，看看我们是否能够提供一些帮助。''',
      ScriptScene.productIntro: '''我们的CRM系统主要有以下几个核心优势：

1. 客户管理一体化：从线索到成交，全流程可视化管理
2. AI智能分析：自动生成客户画像，精准预测商机
3. 移动办公：随时随地处理业务，提升工作效率
4. 数据安全：银行级加密，确保数据安全

目前我们正在做年终促销活动，新客户可以享受8折优惠，您看是否有兴趣了解一下？''',
      ScriptScene.meetingInvite: '''基于我们之前的沟通，我觉得我们的产品确实能够帮助贵公司解决目前面临的问题。

为了让您更直观地了解我们的系统，我想邀请您参加一次产品演示会议。届时我们的产品专家会为您详细介绍系统功能，并针对贵公司的具体需求进行定制化演示。

您看这周三或周四下午方便吗？大概需要1个小时左右。''',
      ScriptScene.followUp: '''您好，上次我们聊过之后，不知道您对我们的产品有什么想法？

如果您还有任何疑问，我可以为您详细解答。另外，我们最近推出了一些新功能，可能对贵公司的业务有帮助，有时间的话我可以给您介绍一下。

期待您的回复！''',
    };

    final script = CallScript(
      id: _uuid.v4(),
      content: contents[scene] ?? '',
      scene: scene,
      channel: channel,
      tone: tone,
      customerId: customerId,
      createdAt: DateTime.now(),
    );

    _scriptHistory.insert(0, script);
    if (_scriptHistory.length > 20) {
      _scriptHistory.removeLast();
    }

    return script;
  }

  @override
  Future<List<ScriptTemplate>> getTemplates({
    ScriptScene? scene,
    ScriptChannel? channel,
  }) async {
    return [
      const ScriptTemplate(
        id: 'tpl_001',
        name: '标准首次接触话术',
        content: '您好，我是{{公司名称}}的{{职位}}{{姓名}}...',
        scene: ScriptScene.firstContact,
        isSystem: true,
      ),
      const ScriptTemplate(
        id: 'tpl_002',
        name: '产品介绍模板',
        content: '我们的{{产品名称}}主要有以下优势...',
        scene: ScriptScene.productIntro,
        isSystem: true,
      ),
    ];
  }

  @override
  Future<ScriptTemplate> saveAsTemplate({
    required CallScript script,
    required String name,
  }) async {
    return ScriptTemplate(
      id: _uuid.v4(),
      name: name,
      content: script.content,
      scene: script.scene,
      channel: script.channel,
      tone: script.tone,
    );
  }

  @override
  Future<List<CallScript>> getScriptHistory({
    String? customerId,
    int limit = 10,
  }) async {
    if (customerId != null) {
      return _scriptHistory
          .where((s) => s.customerId == customerId)
          .take(limit)
          .toList();
    }
    return _scriptHistory.take(limit).toList();
  }
}
