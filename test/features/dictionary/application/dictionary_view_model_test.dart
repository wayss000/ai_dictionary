import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dictionary/features/dictionary/data/llm_config.dart';
import 'package:ai_dictionary/features/dictionary/application/dictionary_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses the default language pair', () async {
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.languagePair, DictionaryViewModel.defaultLanguagePair);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.hasResult, isFalse);
    expect(viewModel.modelLabel, '默认模型');
    expect(viewModel.profiles, isEmpty);

    viewModel.dispose();
  });

  test('updates the selected language pair', () async {
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);

    viewModel.selectLanguagePair('日语 → 中文');

    expect(viewModel.languagePair, '日语 → 中文');
    viewModel.dispose();
  });

  test('explain reports an error when model is not configured', () async {
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);
    final states = <bool>[];
    viewModel.addListener(() => states.add(viewModel.isLoading));

    await viewModel.explain('transformer');

    // 日志保存会触发额外通知，因此只断言首尾状态。
    expect(states.first, isTrue);
    expect(states.last, isFalse);
    expect(viewModel.hasResult, isFalse);
    expect(viewModel.hasError, isTrue);
    expect(viewModel.errorMessage, contains('尚未配置模型'));
    // 失败调用也会记入日志。
    expect(viewModel.logs, hasLength(1));
    expect(viewModel.logs.first.success, isFalse);
    viewModel.dispose();
  });

  test('migrates legacy single config into a profile', () async {
    SharedPreferences.setMockInitialValues({
      'llm_config_v1':
          '{"baseUrl":"https://api.example.com/v1","apiKey":"sk-test","model":"test-model"}',
    });
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.profiles, hasLength(1));
    expect(viewModel.activeProfileId, 'legacy');
    expect(viewModel.modelLabel, 'test-model');
    expect(viewModel.config.isConfigured, isTrue);
    viewModel.dispose();
  });

  test('saveProfile adds and activates; activateProfile switches', () async {
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);

    await viewModel.saveProfile(const LlmConfig(
      id: 'a',
      name: 'A',
      baseUrl: 'https://a.com/v1',
      apiKey: 'k-a',
      model: 'model-a',
    ));
    await viewModel.saveProfile(const LlmConfig(
      id: 'b',
      name: 'B',
      baseUrl: 'https://b.com/v1',
      apiKey: 'k-b',
      model: 'model-b',
    ));

    expect(viewModel.profiles, hasLength(2));
    // 新保存的配置自动生效。
    expect(viewModel.activeProfileId, 'b');
    expect(viewModel.modelLabel, 'B');

    await viewModel.activateProfile('a');
    expect(viewModel.activeProfileId, 'a');
    expect(viewModel.modelLabel, 'A');

    // 删除生效配置后自动切到剩余配置。
    await viewModel.deleteProfile('a');
    expect(viewModel.activeProfileId, 'b');

    viewModel.dispose();
  });

  test('add and delete language pairs with selection fallback', () async {
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);

    await viewModel.addLanguagePair('法语 → 中文');
    expect(viewModel.languagePairs, contains('法语 → 中文'));
    expect(viewModel.languagePairs, hasLength(6));

    // 重复添加会被去重。
    await viewModel.addLanguagePair('法语 → 中文');
    expect(viewModel.languagePairs, hasLength(6));

    // 删除生效组合后自动切到第一个剩余组合。
    await viewModel.deleteLanguagePair('自动识别 → 中文');
    expect(viewModel.languagePairs, isNot(contains('自动识别 → 中文')));
    expect(viewModel.languagePair, '英语 → 中文');

    // 至少保留一个组合。
    await viewModel.deleteLanguagePair('英语 → 中文');
    await viewModel.deleteLanguagePair('中文 → 英语');
    await viewModel.deleteLanguagePair('日语 → 中文');
    await viewModel.deleteLanguagePair('韩语 → 英语');
    await viewModel.deleteLanguagePair('法语 → 中文');
    expect(viewModel.languagePairs, hasLength(1));
    expect(viewModel.languagePair, '法语 → 中文');

    viewModel.dispose();
  });

  test('clearLogs empties the call logs', () async {
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);

    await viewModel.explain('transformer');
    expect(viewModel.logs, isNotEmpty);

    await viewModel.clearLogs();
    expect(viewModel.logs, isEmpty);

    viewModel.dispose();
  });
}
