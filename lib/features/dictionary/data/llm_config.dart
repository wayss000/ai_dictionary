import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 一个大模型配置档案（OpenAI 兼容接口）。
class LlmConfig {
  const LlmConfig({
    required this.id,
    this.name = '',
    this.baseUrl = defaultBaseUrl,
    this.apiKey = '',
    this.model = defaultModel,
    this.timeoutSeconds = defaultTimeoutSeconds,
  });

  static const defaultBaseUrl = 'https://api.openai.com/v1';
  static const defaultModel = 'gpt-4o-mini';
  static const defaultTimeoutSeconds = 60;

  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;

  /// 请求超时时间（秒）。
  final int timeoutSeconds;

  /// 实际生效的超时时间，最小 5 秒。
  int get effectiveTimeoutSeconds => timeoutSeconds < 5 ? 5 : timeoutSeconds;

  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  /// 展示名：未填 name 时用模型名。
  String get displayName => name.trim().isNotEmpty ? name.trim() : model.trim();

  LlmConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    int? timeoutSeconds,
  }) {
    return LlmConfig(
      id: id ?? this.id,
      name: (name ?? this.name).trim(),
      baseUrl: (baseUrl ?? this.baseUrl).trim(),
      apiKey: (apiKey ?? this.apiKey).trim(),
      model: (model ?? this.model).trim(),
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'timeoutSeconds': timeoutSeconds,
      };

  factory LlmConfig.fromJson(Map<String, dynamic> json) => LlmConfig(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? defaultBaseUrl,
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? defaultModel,
        timeoutSeconds: json['timeoutSeconds'] as int? ?? defaultTimeoutSeconds,
      );
}

/// 多模型配置仓库：保存全部配置档案 + 当前生效的档案 id。
class LlmConfigStore {
  const LlmConfigStore({this.profiles = const [], this.activeId});

  static const _profilesKey = 'llm_profiles_v2';
  static const _activeKey = 'llm_active_v2';

  /// 旧版单配置 key，首次加载时迁移。
  static const _legacyKey = 'llm_config_v1';

  final List<LlmConfig> profiles;
  final String? activeId;

  LlmConfig? get active {
    for (final profile in profiles) {
      if (profile.id == activeId) return profile;
    }
    return null;
  }

  static String newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  /// 从本地读取配置；旧版单配置自动迁移为一个档案。
  static Future<LlmConfigStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    var profiles = <LlmConfig>[];
    var activeId = prefs.getString(_activeKey);

    final raw = prefs.getString(_profilesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        profiles = [
          for (final item in list)
            if (item is Map<String, dynamic>) LlmConfig.fromJson(item),
        ];
      } catch (_) {}
    } else {
      final legacyRaw = prefs.getString(_legacyKey);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        try {
          final legacy = LlmConfig.fromJson(
            jsonDecode(legacyRaw) as Map<String, dynamic>,
          );
          if (legacy.model.trim().isNotEmpty) {
            profiles = [
              LlmConfig(
                id: 'legacy',
                name: legacy.model,
                baseUrl: legacy.baseUrl,
                apiKey: legacy.apiKey,
                model: legacy.model,
              ),
            ];
            activeId = 'legacy';
          }
        } catch (_) {}
      }
    }

    if (profiles.isNotEmpty &&
        (activeId == null || !profiles.any((p) => p.id == activeId))) {
      activeId = profiles.first.id;
    }
    if (profiles.isEmpty) activeId = null;

    return LlmConfigStore(profiles: profiles, activeId: activeId);
  }

  LlmConfigStore copyWith({List<LlmConfig>? profiles, String? activeId}) {
    return LlmConfigStore(
      profiles: profiles ?? this.profiles,
      activeId: activeId ?? this.activeId,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode([for (final p in profiles) p.toJson()]),
    );
    if (activeId == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, activeId!);
    }
  }
}
