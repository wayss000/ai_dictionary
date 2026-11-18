import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 一个提示词模板：发给大模型的 system 提示词。
///
/// 模板内容支持占位符：{word}（用户输入的单词）、{language}（语言方向）。
class PromptTemplate {
  const PromptTemplate({
    required this.id,
    required this.name,
    required this.content,
  });

  /// 内置默认模板 id；该模板可编辑，但提供一键恢复默认内容。
  static const defaultPromptId = 'default';

  static const defaultName = '默认词典提示词';

  static const defaultContent = '''
你是词典。按用户给的语言方向简要解释输入内容，只输出JSON，无任何其他文字：
{"term":"查询词","translation":"译文","context":"一句话语境解释","partOfSpeech":"词性","examples":[{"original":"例句","translated":"例句译文"}]}
每个字段必须简短：translation一个含义即可，context不超过20字，examples最多1条。没有内容就输出空字符串或空数组。
语言方向：{language}
待解释内容：{word}''';

  final String id;
  final String name;

  /// 提示词模板原文（含占位符）。
  final String content;

  /// 是否为内置默认模板。
  bool get isDefault => id == defaultPromptId;

  /// 将模板与本次查询结合，生成最终发给大模型的提示词。
  ///
  /// 若模板中没有 {word} 占位符，会在末尾追加待解释内容，确保单词一定发送给模型。
  String render({required String word, required String languagePair}) {
    var text = content
        .replaceAll('{word}', word)
        .replaceAll('{language}', languagePair);
    if (!content.contains('{word}') && word.isNotEmpty) {
      text = '${text.trimRight()}\n待解释内容：$word';
    }
    return text;
  }

  PromptTemplate copyWith({String? id, String? name, String? content}) {
    return PromptTemplate(
      id: id ?? this.id,
      name: (name ?? this.name).trim(),
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'content': content};

  factory PromptTemplate.fromJson(Map<String, dynamic> json) => PromptTemplate(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    content: json['content'] as String? ?? '',
  );
}

/// 提示词模板仓库：本地持久化全部模板 + 当前生效的模板 id。
class PromptStore {
  const PromptStore({
    this.templates = const [defaultTemplate],
    this.selectedId,
  });

  static const _key = 'llm_prompts_v1';

  final List<PromptTemplate> templates;
  final String? selectedId;

  static const defaultTemplate = PromptTemplate(
    id: PromptTemplate.defaultPromptId,
    name: PromptTemplate.defaultName,
    content: PromptTemplate.defaultContent,
  );

  /// 当前生效的模板；找不到时优先回退到列表内的默认模板，最后回退到内置默认模板。
  PromptTemplate get selected {
    for (final template in templates) {
      if (template.id == selectedId) return template;
    }
    for (final template in templates) {
      if (template.isDefault) return template;
    }
    return defaultTemplate;
  }

  static String newPromptId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  /// 从本地读取；为空时返回仅含默认模板的仓库。
  static Future<PromptStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const PromptStore();
    try {
      final list = jsonDecode(raw) as List;
      final templates = [
        for (final item in list)
          if (item is Map<String, dynamic> &&
              (item['content'] as String? ?? '').isNotEmpty)
            PromptTemplate.fromJson(item),
      ];
      if (templates.isEmpty) return const PromptStore();
      var selectedId = prefs.getString('${_key}_selected');
      if (selectedId == null || !templates.any((t) => t.id == selectedId)) {
        selectedId = templates.first.id;
      }
      return PromptStore(templates: templates, selectedId: selectedId);
    } catch (_) {
      return const PromptStore();
    }
  }

  PromptStore copyWith({List<PromptTemplate>? templates, String? selectedId}) {
    return PromptStore(
      templates: templates ?? this.templates,
      selectedId: selectedId ?? this.selectedId,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final t in templates) t.toJson()]),
    );
    final id = selectedId;
    if (id == null) {
      await prefs.remove('${_key}_selected');
    } else {
      await prefs.setString('${_key}_selected', id);
    }
  }
}
