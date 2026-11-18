import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 语言组合仓库：可配置的语言组合列表 + 当前生效的组合。
class LanguagePairStore {
  const LanguagePairStore({this.pairs = defaultPairs, this.selected = defaultPair});

  static const defaultPair = '自动识别 → 中文';
  static const defaultPairs = [
    '自动识别 → 中文',
    '英语 → 中文',
    '中文 → 英语',
    '日语 → 中文',
    '韩语 → 英语',
  ];

  static const _pairsKey = 'llm_lang_pairs_v1';
  static const _selectedKey = 'llm_lang_selected_v1';

  final List<String> pairs;
  final String selected;

  /// 从本地读取；未保存过或数据异常时回退到默认组合。
  static Future<LanguagePairStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    var pairs = defaultPairs;
    final raw = prefs.getString(_pairsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        final decoded = [
          for (final item in list)
            if (item is String && item.trim().isNotEmpty) item.trim(),
        ];
        if (decoded.isNotEmpty) pairs = decoded;
      } catch (_) {}
    }

    var selected = prefs.getString(_selectedKey) ?? defaultPair;
    if (!pairs.contains(selected)) {
      selected = pairs.first;
    }
    return LanguagePairStore(pairs: pairs, selected: selected);
  }

  LanguagePairStore copyWith({List<String>? pairs, String? selected}) {
    return LanguagePairStore(
      pairs: pairs ?? this.pairs,
      selected: selected ?? this.selected,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pairsKey, jsonEncode(pairs));
    await prefs.setString(_selectedKey, selected);
  }
}
