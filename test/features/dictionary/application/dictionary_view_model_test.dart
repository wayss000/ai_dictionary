import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_dictionary/features/dictionary/application/dictionary_view_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses the default language pair', () async {
    final viewModel = DictionaryViewModel();
    // 等待异步加载配置完成。
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.languagePair, DictionaryViewModel.defaultLanguagePair);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.hasResult, isFalse);
    expect(viewModel.modelLabel, '默认模型');

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

    expect(states, [true, false]);
    expect(viewModel.hasResult, isFalse);
    expect(viewModel.hasError, isTrue);
    expect(viewModel.errorMessage, contains('尚未配置模型'));
    viewModel.dispose();
  });

  test('modelLabel reflects the loaded configuration', () async {
    SharedPreferences.setMockInitialValues({
      'llm_config_v1': '{"baseUrl":"https://api.example.com/v1","apiKey":"sk-test","model":"test-model"}',
    });
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.modelLabel, 'test-model');
    expect(viewModel.config.isConfigured, isTrue);
    viewModel.dispose();
  });
}
