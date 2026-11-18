import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_config.dart';

/// 词典查询结果。
class DictionaryResult {
  const DictionaryResult({
    required this.term,
    required this.translation,
    required this.context,
    required this.partOfSpeech,
    required this.examples,
    required this.model,
  });

  final String term;
  final String translation;
  final String context;
  final String partOfSpeech;
  final List<WordExample> examples;
  final String model;
}

class WordExample {
  const WordExample({required this.original, required this.translated});

  final String original;
  final String translated;
}

/// 调用大模型失败时抛出的异常。
class LlmException implements Exception {
  LlmException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// OpenAI 兼容接口的大模型客户端。
class LlmService {
  LlmService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 60);

  /// 调用 /chat/completions，让模型输出结构化 JSON 的词典解释。
  Future<DictionaryResult> explain({
    required LlmConfig config,
    required String query,
    required String languagePair,
  }) async {
    if (!config.isConfigured) {
      throw LlmException('尚未配置模型，请点击右上角设置填写 API 地址、API Key 和模型名称。');
    }

    final endpoint = _chatEndpoint(config.baseUrl);
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey}',
          },
          body: jsonEncode({
            'model': config.model,
            'temperature': 0.3,
            'max_tokens': 300,
            'messages': [
              {'role': 'system', 'content': _systemPrompt},
              {
                'role': 'user',
                'content': '语言方向：$languagePair\n待解释内容：$query',
              },
            ],
          }),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException('请求失败（HTTP ${response.statusCode}）：${_briefError(response.body)}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw LlmException('模型未返回任何结果。');
    }
    final content =
        ((choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>)['content']
            as String? ??
        '';

    return _parseResult(content, config.model);
  }

  /// 只验证配置是否可用（发起一次极小的对话请求）。
  Future<void> testConnection(LlmConfig config) async {
    if (!config.isConfigured) {
      throw LlmException('请先填写 API Key 和模型名称。');
    }
    final endpoint = _chatEndpoint(config.baseUrl);
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey}',
          },
          body: jsonEncode({
            'model': config.model,
            'max_tokens': 8,
            'messages': [
              {'role': 'user', 'content': 'ping'},
            ],
          }),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException('连接失败（HTTP ${response.statusCode}）：${_briefError(response.body)}');
    }
  }

  DictionaryResult _parseResult(String rawContent, String model) {
    final json = _extractJson(rawContent);
    final examples = <WordExample>[];
    if (json['examples'] is List) {
      for (final item in json['examples'] as List) {
        if (item is Map<String, dynamic>) {
          final original = item['original']?.toString() ?? '';
          final translated = item['translated']?.toString() ?? '';
          if (original.isNotEmpty) {
            examples.add(WordExample(original: original, translated: translated));
          }
        }
      }
    }

    final term = json['term']?.toString() ?? '';
    if (term.isEmpty) {
      throw LlmException('模型返回的数据格式不完整，请重试。');
    }

    return DictionaryResult(
      term: term,
      translation: json['translation']?.toString() ?? '',
      context: json['context']?.toString() ?? '',
      partOfSpeech: json['partOfSpeech']?.toString() ?? '',
      examples: examples,
      model: model,
    );
  }

  /// 从模型输出中提取 JSON（容忍 markdown 代码块与 `<think>` 思考内容包裹）。
  Map<String, dynamic> _extractJson(String raw) {
    var content = raw
        .trim()
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .trim();
    final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$');
    final match = fence.firstMatch(content);
    if (match != null) content = match.group(1)!.trim();

    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // 尝试截取第一个 { 到最后一个 } 之间的内容。
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          final decoded = jsonDecode(content.substring(start, end + 1));
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
    }
    throw LlmException('无法解析模型返回的数据，请重试。');
  }

  String _briefError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final error = data['error'];
        if (error is Map<String, dynamic> && error['message'] != null) {
          return error['message'].toString();
        }
      }
    } catch (_) {}
    final trimmed = body.trim();
    return trimmed.length > 200 ? '${trimmed.substring(0, 200)}…' : trimmed;
  }

  /// 归一化 baseUrl 并拼接 chat/completions 端点。
  String _chatEndpoint(String baseUrl) {
    var url = baseUrl.trim();
    if (url.isEmpty) url = LlmConfig.defaultBaseUrl;
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url.endsWith('/chat/completions') ? url : '$url/chat/completions';
  }

  void dispose() => _client.close();
}

const _systemPrompt = '''
你是词典。按用户给的语言方向简要解释输入内容，只输出JSON，无任何其他文字：
{"term":"查询词","translation":"译文","context":"一句话语境解释","partOfSpeech":"词性","examples":[{"original":"例句","translated":"例句译文"}]}
每个字段必须简短：translation一个含义即可，context不超过20字，examples最多1条。没有内容就输出空字符串或空数组。''';
