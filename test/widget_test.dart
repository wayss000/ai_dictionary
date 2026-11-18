import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_dictionary/app/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the dictionary workspace', (tester) async {
    await tester.pumpWidget(const AiDictionaryApp());
    await tester.pump();

    expect(find.text('AI Dictionary'), findsOneWidget);
    expect(find.text('自动识别 → 中文'), findsOneWidget);
    expect(find.text('transformer'), findsOneWidget);
    expect(find.text('解释'), findsOneWidget);
    // 未点击解释前不展示结果卡片。
    expect(find.text('Transformer'), findsNothing);
  });

  testWidgets('can change the language pair', (tester) async {
    await tester.pumpWidget(const AiDictionaryApp());
    await tester.pump();

    await tester.tap(find.text('自动识别 → 中文'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('日语 → 中文'));
    await tester.tap(find.text('日语 → 中文'));
    await tester.pumpAndSettle();

    expect(find.text('日语 → 中文'), findsOneWidget);
  });
}
