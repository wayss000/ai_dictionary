import 'package:flutter_test/flutter_test.dart';

import 'package:ai_dictionary/main.dart';

void main() {
  testWidgets('shows the dictionary workspace', (tester) async {
    await tester.pumpWidget(const AiDictionaryApp());

    expect(find.text('AI Dictionary'), findsOneWidget);
    expect(find.text('自动识别 → 中文'), findsOneWidget);
    expect(find.text('transformer'), findsOneWidget);
    expect(find.text('解释'), findsOneWidget);
    expect(find.text('Transformer'), findsOneWidget);
  });

  testWidgets('can change the language pair', (tester) async {
    await tester.pumpWidget(const AiDictionaryApp());

    await tester.tap(find.text('自动识别 → 中文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日语 → 中文'));
    await tester.pumpAndSettle();

    expect(find.text('日语 → 中文'), findsOneWidget);
  });
}
