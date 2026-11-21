import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 一个提示词模板：发给大模型的 system 提示词。
///
/// 模板内容支持占位符：{word}（用户输入的单词/短句）、{language}（语言方向）。
class PromptTemplate {
  const PromptTemplate({
    required this.id,
    required this.name,
    required this.content,
  });

  /// 内置"词语翻译"模板 id；可编辑，也可一键恢复默认内容。
  static const defaultPromptId = 'default';

  /// 内置"短句翻译"模板 id；可编辑，也可一键恢复默认内容。
  static const sentencePromptId = 'sentence';

  /// 全部内置模板 id。内置模板不可删除，但可编辑与一键恢复。
  static const Set<String> builtInIds = {defaultPromptId, sentencePromptId};

  static const defaultName = '词语翻译';
  static const sentenceName = '短句翻译';

  /// 历史上默认模板用过的名字。加载时若内置模板仍叫这些名字，会归一化为当前默认名，
  /// 让旧版本用户无感升级到"词语翻译"这个新名称。
  static const Set<String> legacyDefaultNames = {'默认词典提示词'};

  static const defaultContent = '''
你是词典。按用户给的语言方向解释输入的词语，只输出JSON，无任何其他文字。
输入只有一个词语时输出单个对象：
{"term":"查询词","translation":"译文","context":"一句话语境解释","partOfSpeech":"词性","examples":[{"original":"例句","translated":"例句译文"}]}
输入有多个词语时（每行或用逗号分隔一个）输出数组，每个词语一个对象：
[{"term":"词1","translation":"译1"},{"term":"词2","translation":"译2"}]
每个字段必须简短：translation一个含义即可，context不超过20字，examples最多1条。没有内容就输出空字符串或空数组。
语言方向：{language}
待解释内容：{word}''';

  static const sentenceContent = '''
你是翻译。按用户给的语言方向翻译输入的短句，只输出JSON，无任何其他文字：
{"term":"原句","translation":"译文","context":"可选的简要说明，没有则留空字符串"}
term 字段必须原样保留用户输入的原句，translation 给出自然通顺的译文。
语言方向：{language}
待翻译内容：{word}''';

  final String id;
  final String name;

  /// 提示词模板原文（含占位符）。
  final String content;

  /// 是否为内置"词语翻译"模板。
  bool get isDefault => id == defaultPromptId;

  /// 是否为任意内置模板（内置模板不可删除）。
  bool get isBuiltIn => builtInIds.contains(id);

  /// 若为内置模板，返回其内置默认名称（供 UI 本地化展示与恢复判断）。
  String? get builtInDefaultName {
    if (id == defaultPromptId) return defaultName;
    if (id == sentencePromptId) return sentenceName;
    return null;
  }

  /// 若为内置模板，返回其内置默认内容（供"一键恢复"使用）。
  String? get builtInDefaultContent {
    if (id == defaultPromptId) return defaultContent;
    if (id == sentencePromptId) return sentenceContent;
    return null;
  }

  /// 将模板与本次查询结合，生成最终发给大模型的提示词。
  ///
  /// 若模板中没有 {word} 占位符，会在末尾追加待解释内容，确保输入一定发送给模型。
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
    this.templates = builtInTemplates,
    this.selectedId,
  });

  static const _key = 'llm_prompts_v1';

  static const defaultTemplate = PromptTemplate(
    id: PromptTemplate.defaultPromptId,
    name: PromptTemplate.defaultName,
    content: PromptTemplate.defaultContent,
  );

  static const sentenceTemplate = PromptTemplate(
    id: PromptTemplate.sentencePromptId,
    name: PromptTemplate.sentenceName,
    content: PromptTemplate.sentenceContent,
  );

  /// 全部内置模板（新用户的初始模板集合）。
  static const List<PromptTemplate> builtInTemplates = [
    defaultTemplate,
    sentenceTemplate,
  ];

  final List<PromptTemplate> templates;
  final String? selectedId;

  /// 按 id 查找内置模板的默认实例，找不到返回 null。
  static PromptTemplate? builtInById(String id) {
    for (final template in builtInTemplates) {
      if (template.id == id) return template;
    }
    return null;
  }

  /// 当前生效的模板；找不到时优先回退到内置"词语翻译"模板，最后回退到内置默认模板。
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

  /// 从本地读取；为空时返回仅含内置模板的仓库。
  ///
  /// 加载时会补齐缺失的内置模板（让旧版本用户也拿到"短句翻译"），并把仍使用历史默认名的
  /// 内置模板归一化为新名称"词语翻译"。
  static Future<PromptStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    List<PromptTemplate> templates = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        templates = [
          for (final item in list)
            if (item is Map<String, dynamic> &&
                (item['content'] as String? ?? '').isNotEmpty)
              PromptTemplate.fromJson(item),
        ];
      } catch (_) {
        templates = [];
      }
    }
    if (templates.isEmpty) return const PromptStore();

    // 补齐缺失的内置模板，并把历史默认名归一化为当前默认名。
    for (final builtIn in PromptStore.builtInTemplates) {
      final index = templates.indexWhere((t) => t.id == builtIn.id);
      if (index < 0) {
        templates.add(builtIn);
      } else {
        final stored = templates[index];
        final defaultName = builtIn.builtInDefaultName;
        if (defaultName != null &&
            PromptTemplate.legacyDefaultNames.contains(stored.name.trim())) {
          templates[index] = stored.copyWith(name: defaultName);
        }
      }
    }

    var selectedId = prefs.getString('${_key}_selected');
    if (selectedId == null || !templates.any((t) => t.id == selectedId)) {
      selectedId = templates.first.id;
    }
    return PromptStore(templates: templates, selectedId: selectedId);
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
