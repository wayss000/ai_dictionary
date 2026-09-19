import 'package:flutter_test/flutter_test.dart';

import 'package:ai_dictionary/features/dictionary/application/dictionary_view_model.dart';

void main() {
  test('uses the default language pair', () {
    final viewModel = DictionaryViewModel();

    expect(viewModel.languagePair, DictionaryViewModel.defaultLanguagePair);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.hasResult, isTrue);

    viewModel.dispose();
  });

  test('updates the selected language pair', () {
    final viewModel = DictionaryViewModel();

    viewModel.selectLanguagePair('日语 → 中文');

    expect(viewModel.languagePair, '日语 → 中文');
    viewModel.dispose();
  });

  test('explain transitions from loading to result', () async {
    final viewModel = DictionaryViewModel();
    final states = <bool>[];
    viewModel.addListener(() => states.add(viewModel.isLoading));

    await viewModel.explain('transformer');

    expect(states, [true, false]);
    expect(viewModel.hasResult, isTrue);
    viewModel.dispose();
  });
}
