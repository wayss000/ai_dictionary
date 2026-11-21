import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'chatgpt_plan.dart';
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
    this.rawFallback,
  });

  final String term;
  final String translation;
  final String context;
  final String partOfSpeech;
  final List<WordExample> examples;
  final String model;
  final String? rawFallback;
}

class WordExample {
  const WordExample({required this.original, required this.translated});

  final String original;
  final String translated;
}

/// 一次解释调用的完整返回：结构化结果 + 模型原始输出与 token 用量。
class ExplainResponse {
  const ExplainResponse({
    required this.result,
    required this.results,
    required this.rawOutput,
    required this.finalPrompt,
    this.promptTokens,
    this.completionTokens,
  });

  /// 多条结果中的第一条（用于兼容只展示单条结果的调用方）。
  final DictionaryResult result;

  /// 模型返回的全部结构化结果；一次翻译多个词语时会包含多条。
  final List<DictionaryResult> results;

  final String rawOutput;

  /// 本次实际发送给大模型的完整提示词（模板填充占位符后的内容）。
  final String finalPrompt;
  final int? promptTokens;
  final int? completionTokens;
}

/// 调用大模型失败时抛出的异常。
class LlmException implements Exception {
  LlmException(this.message, {this.englishMessage});

  final String? englishMessage;

  final String message;

  @override
  String toString() => message;
}

/// OpenAI 兼容接口的大模型客户端。
class LlmService {
  LlmService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 调用 /chat/completions，让模型输出结构化 JSON 的词典解释。
  ///
  /// [systemPrompt] 是提示词模板与本次查询结合后的最终提示词，作为 system 消息发送；
  /// 用户输入的 [query] 作为 user 消息发送。
  Future<ExplainResponse> explain({
    required LlmConfig config,
    required String query,
    required String systemPrompt,
  }) async {
    if (!config.isConfigured) {
      throw LlmException(
        '尚未配置模型，请点击右上角设置填写 API 地址、API Key 和模型名称。',
        englishMessage:
            'No model configured. In Settings, enter the API URL, API key, and model name.',
      );
    }

    if (config.provider == LlmProvider.chatGpt) {
      final response = await ChatGptPlan.instance.infer(
        id: config.id,
        model: config.model,
        input: query,
        instructions: systemPrompt,
        timeout: Duration(seconds: config.effectiveTimeoutSeconds),
      );
      _ensureContent(response.text);
      final results = _parseResults(response.text, config.model);
      return ExplainResponse(
        result: results.first,
        results: results,
        rawOutput: response.text,
        finalPrompt: systemPrompt,
        promptTokens: response.inputTokens,
        completionTokens: response.outputTokens,
      );
    }

    final endpoint = _chatEndpoint(config.baseUrl);
    final timeout = Duration(seconds: config.effectiveTimeoutSeconds);
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
            'max_tokens': 2048,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': query},
            ],
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException(
        '请求失败（HTTP ${response.statusCode}）：${_briefError(response.body)}',
        englishMessage:
            'Request failed (HTTP ${response.statusCode}): ${_briefError(response.body)}',
      );
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw LlmException(
        '模型未返回任何结果。',
        englishMessage: 'The model returned no results.',
      );
    }
    final choice = choices.first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;
    final content = message['content'] as String? ?? '';
    _ensureContent(content, finishReason: choice['finish_reason'] as String?);

    final usage = data['usage'];
    int? promptTokens;
    int? completionTokens;
    if (usage is Map<String, dynamic>) {
      promptTokens = usage['prompt_tokens'] as int?;
      completionTokens = usage['completion_tokens'] as int?;
    }

    final results = _parseResults(content, config.model);
    return ExplainResponse(
      result: results.first,
      results: results,
      rawOutput: content,
      finalPrompt: systemPrompt,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  void _ensureContent(String content, {String? finishReason}) {
    if (content.trim().isNotEmpty) return;
    if (finishReason == 'length') {
      throw LlmException(
        '模型未返回正文，生成可能因 token 上限而中断。请重试或切换模型。',
        englishMessage:
            'The model returned no text and may have reached the token limit. Retry or switch models.',
      );
    }
    final reason = finishReason == null || finishReason.isEmpty
        ? ''
        : '（结束原因：$finishReason）';
    final englishReason = finishReason == null || finishReason.isEmpty
        ? ''
        : ' (finish reason: $finishReason)';
    throw LlmException(
      '模型返回了空内容$reason，请重试或切换模型。',
      englishMessage:
          'The model returned empty content$englishReason. Retry or switch models.',
    );
  }

  /// 只验证配置是否可用（发起一次极小的对话请求）。
  Future<void> testConnection(LlmConfig config) async {
    if (!config.isConfigured) {
      throw LlmException(
        '请先填写 API Key 和模型名称。',
        englishMessage: 'Enter the API key and model name first.',
      );
    }
    if (config.provider == LlmProvider.chatGpt) {
      await ChatGptPlan.instance.infer(
        id: config.id,
        model: config.model,
        input: 'Reply with OK.',
        instructions: 'Keep your reply brief.',
        timeout: Duration(seconds: config.effectiveTimeoutSeconds),
      );
      return;
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
        .timeout(Duration(seconds: config.effectiveTimeoutSeconds));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException(
        '连接失败（HTTP ${response.statusCode}）：${_briefError(response.body)}',
        englishMessage:
            'Connection failed (HTTP ${response.statusCode}): ${_briefError(response.body)}',
      );
    }
  }

  /// 解析模型输出，支持单个对象或对象数组（多个词语翻译）。
  ///
  /// 永远至少返回一条结果：解析失败时返回一条携带原始文本的兜底结果。
  List<DictionaryResult> _parseResults(String rawContent, String model) {
    Object? decoded;
    try {
      decoded = _extractJsonValue(rawContent);
    } on LlmException {
      return [_fallbackResult(rawContent, model)];
    }

    if (decoded is List) {
      final results = <DictionaryResult>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final result = _resultFromMap(item, model);
          // 跳过既没有 term 也没有 translation 的空对象，避免展示空白条目。
          if (result.term.isNotEmpty || result.translation.isNotEmpty) {
            results.add(result);
          }
        }
      }
      if (results.isNotEmpty) return results;
      return [_fallbackResult(rawContent, model)];
    }

    if (decoded is Map<String, dynamic>) {
      final result = _resultFromMap(decoded, model);
      // 单个对象缺少 term 时视为格式不完整，回退展示原始文本。
      if (result.term.isEmpty) {
        return [_fallbackResult(rawContent, model)];
      }
      return [result];
    }

    return [_fallbackResult(rawContent, model)];
  }

  DictionaryResult _resultFromMap(Map<String, dynamic> json, String model) {
    final examples = <WordExample>[];
    if (json['examples'] is List) {
      for (final item in json['examples'] as List) {
        if (item is Map<String, dynamic>) {
          final original = item['original']?.toString() ?? '';
          final translated = item['translated']?.toString() ?? '';
          if (original.isNotEmpty) {
            examples.add(
              WordExample(original: original, translated: translated),
            );
          }
        }
      }
    }
    return DictionaryResult(
      term: json['term']?.toString() ?? '',
      translation: json['translation']?.toString() ?? '',
      context: json['context']?.toString() ?? '',
      partOfSpeech: json['partOfSpeech']?.toString() ?? '',
      examples: examples,
      model: model,
    );
  }

  DictionaryResult _fallbackResult(String rawContent, String model) {
    return DictionaryResult(
      term: '',
      translation: '',
      context: '',
      partOfSpeech: '',
      examples: const [],
      model: model,
      rawFallback: rawContent,
    );
  }

  /// 从模型输出中提取 JSON 对象或数组（容忍 markdown 代码块与 `<think>` 包裹）。
  Object? _extractJsonValue(String raw) {
    var content = raw
        .trim()
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .trim();
    final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$');
    final match = fence.firstMatch(content);
    if (match != null) content = match.group(1)!.trim();

    Object? tryDecode(String text) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic> || decoded is List) return decoded;
      } catch (_) {}
      return null;
    }

    final direct = tryDecode(content);
    if (direct != null) return direct;

    // 直接解析失败时，截取最外层 { } 或 [ ] 再试一次。
    final objStart = content.indexOf('{');
    final objEnd = content.lastIndexOf('}');
    if (objStart >= 0 && objEnd > objStart) {
      final decoded = tryDecode(content.substring(objStart, objEnd + 1));
      if (decoded != null) return decoded;
    }
    final arrStart = content.indexOf('[');
    final arrEnd = content.lastIndexOf(']');
    if (arrStart >= 0 && arrEnd > arrStart) {
      final decoded = tryDecode(content.substring(arrStart, arrEnd + 1));
      if (decoded != null) return decoded;
    }

    throw LlmException(
      '无法解析模型返回的数据，请重试。',
      englishMessage:
          'Could not read the data returned by the model. Try again.',
    );
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
