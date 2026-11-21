import 'dart:convert';

import 'package:ai_dictionary/features/dictionary/data/llm_config.dart';
import 'package:ai_dictionary/features/dictionary/data/llm_service.dart';
import 'package:ai_dictionary/features/dictionary/presentation/dictionary_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<ExplainResponse> explain(
    String? content, {
    String? finishReason,
  }) async {
    final service = LlmService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': content},
                'finish_reason': finishReason,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(service.dispose);
    return service.explain(
      config: const LlmConfig(id: 'test', apiKey: 'key', model: 'model'),
      query: 'word',
      systemPrompt: 'prompt',
    );
  }

  test('empty responses are errors with useful diagnostics', () async {
    for (final content in [null, '', '  \n']) {
      await expectLater(
        explain(content),
        throwsA(
          isA<LlmException>().having(
            (error) => error.message,
            'message',
            contains('空内容'),
          ),
        ),
      );
    }
    await expectLater(
      explain('', finishReason: 'length'),
      throwsA(
        isA<LlmException>().having(
          (error) => error.message,
          'message',
          contains('token'),
        ),
      ),
    );
    await expectLater(
      explain('', finishReason: 'content_filter'),
      throwsA(
        isA<LlmException>().having(
          (error) => error.message,
          'message',
          contains('content_filter'),
        ),
      ),
    );
  });

  testWidgets('shows unparseable output unchanged', (tester) async {
    const raw = '  原始回复\n第二行 {不完整}\n';
    final response = await explain(raw);
    expect(response.rawOutput, raw);
    expect(response.result.rawFallback, raw);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DictionaryResultCard(
            isLoading: false,
            hasResult: true,
            hasError: false,
            errorMessage: null,
            results: [response.result],
            onCopy: () {},
            onRetry: () {},
          ),
        ),
      ),
    );
    expect(find.text(raw), findsOneWidget);
  });

  test('preserves incomplete JSON and parses fenced JSON', () async {
    const incomplete = '{"translation":"译文"}';
    expect((await explain(incomplete)).result.rawFallback, incomplete);
    final result = (await explain(
      '```json\n{"term":"word","translation":"词"}\n```',
    )).result;
    expect(result.rawFallback, isNull);
    expect(result.term, 'word');
    expect(result.translation, '词');
  });

  test('parses a JSON array into multiple results', () async {
    const array = '[{"term":"apple","translation":"苹果"},'
        '{"term":"banana","translation":"香蕉"}]';
    final response = await explain(array);
    expect(response.results, hasLength(2));
    expect(response.result.term, 'apple');
    expect(response.results[1].term, 'banana');
    expect(response.results[1].translation, '香蕉');
  });

  test('skips empty items and falls back when an array yields nothing', () async {
    const sparse = '[{"term":"apple","translation":"苹果"},{"translation":""}]';
    final response = await explain(sparse);
    expect(response.results, hasLength(1));
    expect(response.result.term, 'apple');

    const empty = '[{"translation":""}]';
    final fallback = await explain(empty);
    expect(fallback.results, hasLength(1));
    expect(fallback.result.rawFallback, empty);
  });
}
