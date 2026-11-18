import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 大模型连接配置（OpenAI 兼容接口）。
class LlmConfig {
  const LlmConfig({
    this.baseUrl = defaultBaseUrl,
    this.apiKey = '',
    this.model = defaultModel,
  });

  static const defaultBaseUrl = 'https://api.openai.com/v1';
  static const defaultModel = 'gpt-4o-mini';

  static const _storageKey = 'llm_config_v1';

  /// API 根地址，例如 https://api.openai.com/v1
  final String baseUrl;

  /// API Key（本地持久化，不上传）。
  final String apiKey;

  /// 模型名称，例如 gpt-4o-mini、deepseek-chat 等。
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  LlmConfig copyWith({String? baseUrl, String? apiKey, String? model}) {
    return LlmConfig(
      baseUrl: (baseUrl ?? this.baseUrl).trim(),
      apiKey: (apiKey ?? this.apiKey).trim(),
      model: (model ?? this.model).trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
      };

  factory LlmConfig.fromJson(Map<String, dynamic> json) => LlmConfig(
        baseUrl: json['baseUrl'] as String? ?? defaultBaseUrl,
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? defaultModel,
      );

  /// 从本地持久化存储读取配置。
  static Future<LlmConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const LlmConfig();
    try {
      return LlmConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const LlmConfig();
    }
  }

  /// 保存配置到本地持久化存储。
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(toJson()));
  }
}
