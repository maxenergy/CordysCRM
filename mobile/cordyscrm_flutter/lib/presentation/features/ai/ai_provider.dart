import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/ai_repository_impl.dart';
import '../../../domain/entities/call_script.dart';
import '../../../domain/entities/company_portrait.dart';
import '../../../domain/repositories/ai_repository.dart';

// ==================== Repository Provider ====================

/// AI 仓库 Provider
final aiRepositoryProvider = Provider<AIRepository>((ref) {
  // TODO: 生产环境替换为 AIRepositoryImpl
  return MockAIRepository();
});

// ==================== Portrait State ====================

/// 画像状态
class PortraitState {
  const PortraitState({
    this.portrait,
    this.isLoading = false,
    this.error,
  });

  final CompanyPortrait? portrait;
  final bool isLoading;
  final String? error;

  bool get hasData => portrait != null;
  bool get hasError => error != null;

  PortraitState copyWith({
    CompanyPortrait? portrait,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearPortrait = false,
  }) {
    return PortraitState(
      portrait: clearPortrait ? null : (portrait ?? this.portrait),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 画像状态 Provider（按客户 ID）
final portraitProvider = StateNotifierProvider.family<
    PortraitNotifier, PortraitState, String>((ref, customerId) {
  return PortraitNotifier(ref.read(aiRepositoryProvider), customerId);
});

/// 画像状态 Notifier
class PortraitNotifier extends StateNotifier<PortraitState> {
  PortraitNotifier(this._repository, this._customerId)
      : super(const PortraitState()) {
    _loadCached();
  }

  final AIRepository _repository;
  final String _customerId;

  /// 加载缓存的画像
  Future<void> _loadCached() async {
    final cached = await _repository.getCachedPortrait(_customerId);
    if (cached != null) {
      state = state.copyWith(portrait: cached);
    }
  }

  /// 生成或刷新画像
  Future<void> generatePortrait() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final portrait = await _repository.generatePortrait(_customerId);
      state = state.copyWith(portrait: portrait, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '生成画像失败: $e',
      );
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ==================== Script State ====================

/// 话术生成状态
class ScriptState {
  const ScriptState({
    this.scene = ScriptScene.firstContact,
    this.channel = ScriptChannel.phone,
    this.tone = ScriptTone.professional,
    this.selectedTemplateId,
    this.generatedScript,
    this.isGenerating = false,
    this.error,
    this.history = const [],
  });

  final ScriptScene scene;
  final ScriptChannel channel;
  final ScriptTone tone;
  final String? selectedTemplateId;
  final CallScript? generatedScript;
  final bool isGenerating;
  final String? error;
  final List<CallScript> history;

  bool get hasScript => generatedScript != null;
  bool get hasError => error != null;

  ScriptState copyWith({
    ScriptScene? scene,
    ScriptChannel? channel,
    ScriptTone? tone,
    String? selectedTemplateId,
    CallScript? generatedScript,
    bool? isGenerating,
    String? error,
    List<CallScript>? history,
    bool clearError = false,
    bool clearScript = false,
    bool clearTemplate = false,
  }) {
    return ScriptState(
      scene: scene ?? this.scene,
      channel: channel ?? this.channel,
      tone: tone ?? this.tone,
      selectedTemplateId:
          clearTemplate ? null : (selectedTemplateId ?? this.selectedTemplateId),
      generatedScript:
          clearScript ? null : (generatedScript ?? this.generatedScript),
      isGenerating: isGenerating ?? this.isGenerating,
      error: clearError ? null : (error ?? this.error),
      history: history ?? this.history,
    );
  }
}

/// 话术生成 Provider（按客户 ID）
final scriptProvider = StateNotifierProvider.family<
    ScriptNotifier, ScriptState, String>((ref, customerId) {
  return ScriptNotifier(ref.read(aiRepositoryProvider), customerId);
});

/// 话术生成 Notifier
class ScriptNotifier extends StateNotifier<ScriptState> {
  ScriptNotifier(this._repository, this._customerId)
      : super(const ScriptState()) {
    _loadHistory();
  }

  final AIRepository _repository;
  final String _customerId;

  /// 加载历史记录
  Future<void> _loadHistory() async {
    final history = await _repository.getScriptHistory(
      customerId: _customerId,
      limit: 10,
    );
    state = state.copyWith(history: history);
  }

  /// 设置场景
  void setScene(ScriptScene scene) {
    state = state.copyWith(scene: scene);
  }

  /// 设置渠道
  void setChannel(ScriptChannel channel) {
    state = state.copyWith(channel: channel);
  }

  /// 设置语气
  void setTone(ScriptTone tone) {
    state = state.copyWith(tone: tone);
  }

  /// 设置模板
  void setTemplate(String? templateId) {
    state = state.copyWith(
      selectedTemplateId: templateId,
      clearTemplate: templateId == null,
    );
  }

  /// 生成话术
  Future<void> generateScript() async {
    state = state.copyWith(isGenerating: true, clearError: true);

    try {
      final script = await _repository.generateScript(
        customerId: _customerId,
        scene: state.scene,
        channel: state.channel,
        tone: state.tone,
        templateId: state.selectedTemplateId,
      );

      final newHistory = [script, ...state.history];
      if (newHistory.length > 10) {
        newHistory.removeLast();
      }

      state = state.copyWith(
        generatedScript: script,
        isGenerating: false,
        history: newHistory,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: '生成话术失败: $e',
      );
    }
  }

  /// 更新话术内容（用户编辑）
  void updateScriptContent(String content) {
    if (state.generatedScript != null) {
      state = state.copyWith(
        generatedScript: state.generatedScript!.copyWith(content: content),
      );
    }
  }

  /// 从历史记录加载
  void loadFromHistory(CallScript script) {
    state = state.copyWith(
      generatedScript: script,
      scene: script.scene,
      channel: script.channel,
      tone: script.tone,
    );
  }

  /// 保存为模板
  Future<bool> saveAsTemplate(String name) async {
    if (state.generatedScript == null) return false;

    try {
      await _repository.saveAsTemplate(
        script: state.generatedScript!,
        name: name,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存模板失败: $e');
      return false;
    }
  }

  /// 清除生成的话术
  void clearScript() {
    state = state.copyWith(clearScript: true);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ==================== Templates Provider ====================

/// 话术模板列表 Provider
final templatesProvider = FutureProvider<List<ScriptTemplate>>((ref) async {
  final repository = ref.read(aiRepositoryProvider);
  return repository.getTemplates();
});
