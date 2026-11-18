import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/llm_call_log.dart';
import '../data/llm_config.dart';
import '../data/llm_service.dart';

class DictionaryViewModel extends ChangeNotifier {
  DictionaryViewModel({LlmService? llmService})
      : _llmService = llmService ?? LlmService() {
    _init();
  }

  final LlmService _llmService;

  static const defaultLanguagePair = '自动识别 → 中文';

  LlmConfigStore _store = const LlmConfigStore();
  List<LlmCallLog> _logs = [];
  String _languagePair = defaultLanguagePair;
  bool _isLoading = false;
  bool _hasResult = false;
  bool _hasError = false;
  String? _errorMessage;
  DictionaryResult? _result;
  bool _isDisposed = false;

  LlmConfig get config => _store.active ?? const LlmConfig(id: '');
  List<LlmConfig> get profiles => _store.profiles;
  String? get activeProfileId => _store.activeId;
  List<LlmCallLog> get logs => List.unmodifiable(_logs);
  String get languagePair => _languagePair;
  bool get isLoading => _isLoading;
  bool get hasResult => _hasResult;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  DictionaryResult? get result => _result;

  /// 界面上展示的模型名：已配置显示真实模型名，否则显示“默认模型”。
  String get modelLabel {
    final active = _store.active;
    if (active == null || !active.isConfigured) return '默认模型';
    return active.displayName;
  }

  Future<void> _init() async {
    _store = await LlmConfigStore.load();
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
    await LlmCallLogStore.save(_logs);
    _notify();
  }

  void selectLanguagePair(String languagePair) {
    if (_languagePair == languagePair) return;
    _languagePair = languagePair;
    notifyListeners();
  }

  Future<void> explain(String query) async {
    if (query.trim().isEmpty || _isLoading) return;

    _isLoading = true;
    _hasResult = false;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    final input = '语言方向：$_languagePair\n待解释内容：${query.trim()}';
    final model = _store.active?.model ?? '未配置';
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _llmService.explain(
        config: _store.active ?? const LlmConfig(id: ''),
        query: query.trim(),
        languagePair: _languagePair,
      );
      stopwatch.stop();
      if (_isDisposed) return;
      _result = response.result;
      _hasResult = true;
      await _addLog(
        LlmCallLog(
          time: DateTime.now(),
          query: query.trim(),
          languagePair: _languagePair,
          model: model,
          durationMs: stopwatch.elapsedMilliseconds,
          success: true,
          input: input,
          output: response.rawOutput,
          promptTokens: response.promptTokens,
          completionTokens: response.completionTokens,
        ),
      );
    } on TimeoutException {
      stopwatch.stop();
      if (_isDisposed) return;
      final seconds = _store.active?.effectiveTimeoutSeconds ?? 60;
      _hasError = true;
      _errorMessage = '请求超时（$seconds 秒）。可在设置中调大该模型的超时时间，或换用更快的模型。';
      await _addLog(_errorLog(query.trim(), model, stopwatch, '超时（$seconds 秒），请求未完成'));
    } on LlmException catch (error) {
      stopwatch.stop();
      if (_isDisposed) return;
      _hasError = true;
      _errorMessage = error.message;
      await _addLog(_errorLog(query.trim(), model, stopwatch, error.message));
    } catch (error) {
      stopwatch.stop();
      if (_isDisposed) return;
      _hasError = true;
      _errorMessage = '请求出错：$error';
      await _addLog(_errorLog(query.trim(), model, stopwatch, error.toString()));
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  LlmCallLog _errorLog(
      String input, String model, Stopwatch stopwatch, String message) {
    return LlmCallLog(
      time: DateTime.now(),
      query: input,
      languagePair: _languagePair,
      model: model,
      durationMs: stopwatch.elapsedMilliseconds,
      success: false,
      input: input,
      output: message,
    );
  }

  Future<void> _addLog(LlmCallLog log) async {
    _logs = [log, ..._logs];
    if (_logs.length > LlmCallLogStore.limit) {
      _logs = _logs.sublist(0, LlmCallLogStore.limit);
    }
    await LlmCallLogStore.save(_logs);
    _notify();
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
