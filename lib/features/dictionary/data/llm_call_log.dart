import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 一次大模型调用记录。
class LlmCallLog {
  const LlmCallLog({
    required this.time,
    required this.query,
    required this.languagePair,
    required this.model,
    required this.durationMs,
    required this.success,
    required this.input,
    required this.output,
    this.systemPrompt,
    this.promptTokens,
    this.completionTokens,
  });

  final DateTime time;
  final String query;
  final String languagePair;
  final String model;
  final int durationMs;
  final bool success;

  /// 发给大模型的输入内容。
  final String input;

  /// 发给大模型的完整提示词（提示词模板填充占位符后的内容）。
  final String? systemPrompt;

  /// 模型原始输出（失败时为错误信息）。
  final String output;

  final int? promptTokens;
  final int? completionTokens;

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'query': query,
    'languagePair': languagePair,
    'model': model,
    'durationMs': durationMs,
    'success': success,
    'input': input,
    if (systemPrompt != null) 'systemPrompt': systemPrompt,
    'output': output,
    if (promptTokens != null) 'promptTokens': promptTokens,
    if (completionTokens != null) 'completionTokens': completionTokens,
  };

  factory LlmCallLog.fromJson(Map<String, dynamic> json) => LlmCallLog(
    time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
    query: json['query'] as String? ?? '',
    languagePair: json['languagePair'] as String? ?? '',
    model: json['model'] as String? ?? '',
    durationMs: json['durationMs'] as int? ?? 0,
    success: json['success'] as bool? ?? false,
    input: json['input'] as String? ?? '',
    systemPrompt: json['systemPrompt'] as String?,
    output: json['output'] as String? ?? '',
    promptTokens: json['promptTokens'] as int?,
    completionTokens: json['completionTokens'] as int?,
  );
}

/// 调用日志仓库：本地持久化，最多保留最近 30 条。
class LlmCallLogStore {
  static const _key = 'llm_call_logs_v1';
  static const limit = 30;

  static Future<List<LlmCallLog>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) LlmCallLog.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<LlmCallLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = logs.length > limit ? logs.sublist(0, limit) : logs;
    await prefs.setString(
      _key,
      jsonEncode([for (final log in trimmed) log.toJson()]),
    );
  }
}
