import 'package:flutter/foundation.dart';

import '../data/llm_config.dart';
import '../data/llm_service.dart';

class DictionaryViewModel extends ChangeNotifier {
  DictionaryViewModel({LlmService? llmService})
      : _llmService = llmService ?? LlmService() {
    _loadConfig();
  }

  final LlmService _llmService;

  static const defaultLanguagePair = '自动识别 → 中文';

  LlmConfig _config = const LlmConfig();
  String _languagePair = defaultLanguagePair;
  bool _isLoading = false;
  bool _hasResult = false;
  bool _hasError = false;
  String? _errorMessage;
  DictionaryResult? _result;
  bool _isDisposed = false;

  LlmConfig get config => _config;
  String get languagePair => _languagePair;
  bool get isLoading => _isLoading;
  bool get hasResult => _hasResult;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  DictionaryResult? get result => _result;

  /// 界面上展示的模型名：已配置显示真实模型名，否则显示“默认模型”。
  String get modelLabel =>
      _config.isConfigured ? _config.model.trim() : '默认模型';

  Future<void> _loadConfig() async {
    _config = await LlmConfig.load();
    _notify();
  }

  /// 设置面板保存后调用，立即刷新内存中的配置并持久化。
  Future<void> updateConfig(LlmConfig config) async {
    _config = config;
    await config.save();
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

    try {
      final result = await _llmService.explain(
        config: _config,
        query: query.trim(),
        languagePair: _languagePair,
      );
      if (_isDisposed) return;
      _result = result;
      _hasResult = true;
    } on LlmException catch (error) {
      if (_isDisposed) return;
      _hasError = true;
      _errorMessage = error.message;
    } catch (error) {
      if (_isDisposed) return;
      _hasError = true;
      _errorMessage = '请求出错：$error';
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
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
