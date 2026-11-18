import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dictionary/features/dictionary/data/llm_config.dart';
import 'package:ai_dictionary/features/dictionary/data/llm_service.dart';
import 'package:ai_dictionary/features/dictionary/data/prompt_store.dart';
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

  testWidgets('a stalled translation times out and can be retried', (
    tester,
  ) async {
    final service = _StallingLlmService();
    final viewModel = DictionaryViewModel(llmService: service);
    addTearDown(viewModel.dispose);
    await tester.pump();
    await viewModel.saveProfile(
      const LlmConfig(
        id: 'chatgpt',
        provider: LlmProvider.chatGpt,
        model: 'gpt-6-luna',
        timeoutSeconds: 5,
      ),
    );

    final initial = viewModel.explain('transformer');
    await tester.pump(const Duration(seconds: 4));
    expect(viewModel.isLoading, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await initial;

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, contains('请求超时（5 秒）'));
    expect(viewModel.logs.single.success, isFalse);

    await viewModel.explain('translate');
    expect(service.calls, 2);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.hasResult, isTrue);
    expect(viewModel.hasError, isFalse);
    expect(viewModel.result?.term, 'translate');
    expect(viewModel.logs.map((log) => log.success), [true, false]);
    await tester.pump();
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

    await viewModel.saveProfile(
      const LlmConfig(
        id: 'a',
        name: 'A',
        baseUrl: 'https://a.com/v1',
        apiKey: 'k-a',
        model: 'model-a',
      ),
    );
    await viewModel.saveProfile(
      const LlmConfig(
        id: 'b',
        name: 'B',
        baseUrl: 'https://b.com/v1',
        apiKey: 'k-b',
        model: 'model-b',
      ),
    );

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

  test('selected prompt falls back to the built-in default', () async {
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.promptTemplates, hasLength(1));
    expect(viewModel.selectedPrompt.id, PromptTemplate.defaultPromptId);
    expect(viewModel.selectedPrompt.content, contains('{word}'));
    expect(viewModel.selectedPrompt.content, contains('{language}'));
    viewModel.dispose();
  });

  test('render fills word and language placeholders', () {
    const template = PromptTemplate(
      id: 't',
      name: 'T',
      content: '语言方向：{language}\n待解释内容：{word}',
    );
    final rendered = template.render(
      word: 'transformer',
      languagePair: '英语 → 中文',
    );
    expect(rendered, contains('语言方向：英语 → 中文'));
    expect(rendered, contains('待解释内容：transformer'));
    expect(rendered, isNot(contains('{word}')));
    expect(rendered, isNot(contains('{language}')));
  });

  test('render appends the word when the template has no {word}', () {
    const template = PromptTemplate(id: 't', name: 'T', content: '你是词典。');
    final rendered = template.render(
      word: 'transformer',
      languagePair: '英语 → 中文',
    );
    expect(rendered, contains('你是词典。'));
    expect(rendered, contains('transformer'));
  });

  test(
    'savePrompt adds and activates; select and delete with fallback',
    () async {
      final viewModel = DictionaryViewModel();
      await Future<void>.delayed(Duration.zero);

      await viewModel.savePrompt(
        const PromptTemplate(
          id: 'p1',
          name: '自定义',
          content: '解释 {word}，语言方向 {language}。',
        ),
      );
      // 新保存的模板自动生效。
      expect(viewModel.promptTemplates, hasLength(2));
      expect(viewModel.selectedPrompt.id, 'p1');

      await viewModel.selectPrompt(PromptTemplate.defaultPromptId);
      expect(viewModel.selectedPrompt.id, PromptTemplate.defaultPromptId);

      // 删除生效模板后自动切到剩余模板。
      await viewModel.deletePrompt(PromptTemplate.defaultPromptId);
      expect(viewModel.promptTemplates, hasLength(1));
      expect(viewModel.selectedPrompt.id, 'p1');

      // 至少保留一个模板：删除最后一个模板会被拒绝。
      await viewModel.deletePrompt('p1');
      expect(viewModel.promptTemplates, hasLength(1));
      expect(viewModel.selectedPrompt.id, 'p1');

      viewModel.dispose();
    },
  );

  test('restoreDefaultPrompt resets the default template content', () async {
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);

    await viewModel.savePrompt(
      const PromptTemplate(
        id: PromptTemplate.defaultPromptId,
        name: '被改过的默认模板',
        content: '自定义内容',
      ),
    );
    expect(viewModel.selectedPrompt.content, '自定义内容');

    await viewModel.restoreDefaultPrompt();
    expect(viewModel.selectedPrompt.name, PromptTemplate.defaultName);
    expect(viewModel.selectedPrompt.content, PromptTemplate.defaultContent);

    viewModel.dispose();
  });

  test('failed explain records the rendered prompt in the log', () async {
    final viewModel = DictionaryViewModel();
    await Future<void>.delayed(Duration.zero);

    await viewModel.explain('transformer');
    expect(viewModel.logs, hasLength(1));
    expect(viewModel.logs.first.systemPrompt, contains('待解释内容：transformer'));
    expect(viewModel.logs.first.input, 'transformer');

    viewModel.dispose();
  });
}

class _StallingLlmService extends LlmService {
  int calls = 0;

  @override
  Future<ExplainResponse> explain({
    required LlmConfig config,
    required String query,
    required String systemPrompt,
  }) async {
    if (++calls == 1) return Completer<ExplainResponse>().future;
    return ExplainResponse(
      result: DictionaryResult(
        term: query,
        translation: '翻译',
        context: '',
        partOfSpeech: '',
        examples: const [],
        model: config.model,
      ),
      rawOutput: '',
      finalPrompt: systemPrompt,
    );
  }
}
