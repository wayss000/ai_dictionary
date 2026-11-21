import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/chatgpt_plan.dart';
import '../data/llm_call_log.dart';
import '../data/llm_config.dart';
import '../data/llm_service.dart';
import '../data/language_pair_store.dart';
import '../data/prompt_store.dart';

class DictionaryViewModel extends ChangeNotifier {
  DictionaryViewModel({LlmService? llmService})
    : _llmService = llmService ?? LlmService() {
    _init();
  }

  final LlmService _llmService;

  static const defaultLanguagePair = '自动识别 → 中文';

  LlmConfigStore _store = const LlmConfigStore();
  LanguagePairStore _langStore = const LanguagePairStore();
  PromptStore _promptStore = const PromptStore();
  List<LlmCallLog> _logs = [];
  Future<void> _logWrites = Future<void>.value();
  String _languagePair = defaultLanguagePair;
  bool _isLoading = false;
  bool _hasResult = false;
  bool _hasError = false;
  String? _errorMessage;
  String? _englishErrorMessage;
  DictionaryResult? _result;
  bool _isDisposed = false;

  LlmConfig get config => _store.active ?? const LlmConfig(id: '');
  List<LlmConfig> get profiles => _store.profiles;
  String? get activeProfileId => _store.activeId;
  List<String> get languagePairs => _langStore.pairs;
  List<PromptTemplate> get promptTemplates => _promptStore.templates;
  PromptTemplate get selectedPrompt => _promptStore.selected;
  List<LlmCallLog> get logs => List.unmodifiable(_logs);
  String get languagePair => _languagePair;
  bool get isLoading => _isLoading;
  bool get hasResult => _hasResult;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  String? get englishErrorMessage => _englishErrorMessage;
  DictionaryResult? get result => _result;

  /// 界面上展示的模型名：已配置显示真实模型名，否则显示“默认模型”。
  String get modelLabel {
    final active = _store.active;
    if (active == null || !active.isConfigured) return '默认模型';
    return active.displayName;
  }

  Future<void> _init() async {
    _store = await LlmConfigStore.load();
    _langStore = await LanguagePairStore.load();
    _languagePair = _langStore.selected;
    _promptStore = await PromptStore.load();
    _logs = await LlmCallLogStore.load();
    _notify();
  }

  /// 新增或更新一个模型配置；新增的配置自动设为生效。
  Future<void> saveProfile(LlmConfig config) async {
    final profiles = [..._store.profiles];
    final index = profiles.indexWhere((p) => p.id == config.id);
    String? activeId = _store.activeId;
    if (index >= 0) {
      profiles[index] = config;
    } else {
      profiles.add(config);
      activeId = config.id;
    }
    _store = _store.copyWith(profiles: profiles, activeId: activeId);
    await _store.save();
    _notify();
  }

  /// 切换生效的模型配置。
  Future<void> activateProfile(String id) async {
    if (_store.activeId == id) return;
    if (!_store.profiles.any((p) => p.id == id)) return;
    _store = _store.copyWith(activeId: id);
    await _store.save();
    _notify();
  }

  /// 删除一个模型配置；若删除的是生效配置，则切换到第一个剩余配置。
  Future<void> deleteProfile(String id) async {
    final profiles = [..._store.profiles]..removeWhere((p) => p.id == id);
    var activeId = _store.activeId;
    if (activeId == id) {
      activeId = profiles.isEmpty ? null : profiles.first.id;
    }
    _store = LlmConfigStore(profiles: profiles, activeId: activeId);
    await _store.save();
    _notify();
  }

  Future<void> clearLogs() async {
    _logs = [];
    _notify();
    await _persistLogs();
  }

  /// 切换生效的语言组合并持久化。
  Future<void> selectLanguagePair(String languagePair) async {
    if (_languagePair == languagePair) return;
    if (!_langStore.pairs.contains(languagePair)) return;
    _languagePair = languagePair;
    _langStore = _langStore.copyWith(selected: languagePair);
    await _langStore.save();
    _notify();
  }

  /// 新增语言组合（去重）。
  Future<void> addLanguagePair(String languagePair) async {
    final text = languagePair.trim();
    if (text.isEmpty || _langStore.pairs.contains(text)) return;
    _langStore = _langStore.copyWith(pairs: [..._langStore.pairs, text]);
    await _langStore.save();
    _notify();
  }

  /// 修改已有语言组合（去重）；若修改的是生效组合，则同步更新生效项。
  Future<void> updateLanguagePair(String oldPair, String newPair) async {
    final text = newPair.trim();
    if (text.isEmpty || text == oldPair) return;
    if (!_langStore.pairs.contains(oldPair)) return;
    if (_langStore.pairs.contains(text)) return;
    final index = _langStore.pairs.indexOf(oldPair);
    final pairs = [..._langStore.pairs]..[index] = text;
    var selected = _langStore.selected;
    if (selected == oldPair) {
      selected = text;
      _languagePair = text;
    }
    _langStore = LanguagePairStore(pairs: pairs, selected: selected);
    await _langStore.save();
    _notify();
  }

  /// 删除语言组合；若删除的是生效组合则切到第一个剩余组合。至少保留一个。
  Future<void> deleteLanguagePair(String languagePair) async {
    if (_langStore.pairs.length <= 1) return;
    if (!_langStore.pairs.contains(languagePair)) return;
    final pairs = [..._langStore.pairs]..remove(languagePair);
    var selected = _langStore.selected;
    if (selected == languagePair) selected = pairs.first;
    _langStore = LanguagePairStore(pairs: pairs, selected: selected);
    _languagePair = selected;
    await _langStore.save();
    _notify();
  }

  /// 新增或更新一个提示词模板；新增的模板自动设为生效。
  Future<void> savePrompt(PromptTemplate template) async {
    final templates = [..._promptStore.templates];
    var selectedId = _promptStore.selectedId;
    final index = templates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      templates[index] = template;
    } else {
      templates.add(template);
      selectedId = template.id;
    }
    _promptStore = _promptStore.copyWith(
      templates: templates,
      selectedId: selectedId,
    );
    await _promptStore.save();
    _notify();
  }

  /// 切换生效的提示词模板。
  Future<void> selectPrompt(String id) async {
    if (_promptStore.selectedId == id) return;
    if (!_promptStore.templates.any((t) => t.id == id)) return;
    _promptStore = _promptStore.copyWith(selectedId: id);
    await _promptStore.save();
    _notify();
  }

  /// 删除一个提示词模板；若删除的是生效模板则切到第一个剩余模板。至少保留一个。
  Future<void> deletePrompt(String id) async {
    if (_promptStore.templates.length <= 1) return;
    if (!_promptStore.templates.any((t) => t.id == id)) return;
    final templates = [..._promptStore.templates]
      ..removeWhere((t) => t.id == id);
    var selectedId = _promptStore.selectedId;
    if (selectedId == id) selectedId = templates.first.id;
    _promptStore = PromptStore(templates: templates, selectedId: selectedId);
    await _promptStore.save();
    _notify();
  }

  /// 将默认模板恢复为内置内容（仅在编辑默认模板时使用）。
  Future<void> restoreDefaultPrompt() async {
    await savePrompt(PromptStore.defaultTemplate);
  }

  Future<void> explain(String query) async {
    if (query.trim().isEmpty || _isLoading) return;

    _isLoading = true;
    _hasResult = false;
    _hasError = false;
    _errorMessage = null;
    _englishErrorMessage = null;
    notifyListeners();

    final word = query.trim();
    final requestConfig = config;
    final languagePair = _languagePair;
    final seconds = requestConfig.effectiveTimeoutSeconds;
    final model = requestConfig.isConfigured ? requestConfig.model : '未配置';
    var systemPrompt = '';
    final stopwatch = Stopwatch()..start();

    try {
      systemPrompt = selectedPrompt.render(
        word: word,
        languagePair: languagePair,
      );
      final response = await _llmService
          .explain(
            config: requestConfig,
            query: word,
            systemPrompt: systemPrompt,
          )
          .timeout(Duration(seconds: seconds));
      stopwatch.stop();
      if (_isDisposed) return;
      _result = response.result;
      _hasResult = true;
      _addLog(
        LlmCallLog(
          time: DateTime.now(),
          query: word,
          languagePair: languagePair,
          model: model,
          durationMs: stopwatch.elapsedMilliseconds,
          success: true,
          input: word,
          systemPrompt: response.finalPrompt,
          output: response.rawOutput,
          promptTokens: response.promptTokens,
          completionTokens: response.completionTokens,
        ),
      );
    } on TimeoutException {
      stopwatch.stop();
      if (_isDisposed) return;
      _hasError = true;
      _englishErrorMessage =
          'The request timed out after $seconds seconds. Increase the model timeout in Settings or try a faster model.';
      _errorMessage = '请求超时（$seconds 秒）。可在设置中调大该模型的超时时间，或换用更快的模型。';
      _addLog(
        _errorLog(
          word,
          model,
          languagePair,
          stopwatch,
          '超时（$seconds 秒），请求未完成',
          systemPrompt,
        ),
      );
    } on LlmException catch (error) {
      stopwatch.stop();
      if (_isDisposed) return;
      _hasError = true;
      _errorMessage = error.message;
      _englishErrorMessage = error.englishMessage ?? error.message;
      _addLog(
        _errorLog(
          word,
          model,
          languagePair,
          stopwatch,
          error.message,
          systemPrompt,
        ),
      );
    } catch (error) {
      stopwatch.stop();
      if (_isDisposed) return;
      _hasError = true;
      _errorMessage = '请求出错：$error';
      final detail = error is ChatGptPlanException
          ? error.englishMessage ?? error.message
          : error.toString();
      _englishErrorMessage = 'Request error: $detail';
      _addLog(
        _errorLog(
          word,
          model,
          languagePair,
          stopwatch,
          error.toString(),
          systemPrompt,
        ),
      );
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  LlmCallLog _errorLog(
    String input,
    String model,
    String languagePair,
    Stopwatch stopwatch,
    String message, [
    String? systemPrompt,
  ]) {
    return LlmCallLog(
      time: DateTime.now(),
      query: input,
      languagePair: languagePair,
      model: model,
      durationMs: stopwatch.elapsedMilliseconds,
      success: false,
      input: input,
      systemPrompt: systemPrompt,
      output: message,
    );
  }

  void _addLog(LlmCallLog log) {
    _logs = [log, ..._logs];
    if (_logs.length > LlmCallLogStore.limit) {
      _logs = _logs.sublist(0, LlmCallLogStore.limit);
    }
    unawaited(_persistLogs());
  }

  Future<void> _persistLogs() {
    final snapshot = _logs;
    _logWrites = _logWrites.then((_) async {
      try {
        await LlmCallLogStore.save(snapshot);
      } catch (_) {
        debugPrint('无法保存调用日志。');
      }
    });
    return _logWrites;
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _llmService.dispose();
    super.dispose();
  }
}
