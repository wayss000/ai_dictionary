import 'package:flutter/widgets.dart';
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
    expect(find.text('翻译'), findsOneWidget);
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

  testWidgets('switches the interface language and restores it on launch', (
    tester,
  ) async {
    await tester.pumpWidget(const AiDictionaryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('界面语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('App language'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('Auto-detect → Chinese'), findsOneWidget);
    expect(find.text('transformer'), findsOneWidget);

    await tester.tap(find.text('Translate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No model configured.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const AiDictionaryApp());
    await tester.pumpAndSettle();
    expect(find.text('Translate'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('can switch the new model configuration provider', (
    tester,
  ) async {
    await tester.pumpWidget(const AiDictionaryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('新增模型配置'), findsOneWidget);
    expect(find.text('自定义模型'), findsOneWidget);
    expect(find.text('API 地址'), findsOneWidget);
    await tester.tap(find.text('登录 ChatGPT'));
    await tester.pumpAndSettle();

    expect(find.text('使用 ChatGPT 继续'), findsOneWidget);
    expect(find.text('API 地址'), findsNothing);

    await tester.tap(find.text('自定义模型'));
    await tester.pumpAndSettle();

    expect(find.text('API 地址'), findsOneWidget);
    expect(find.text('使用 ChatGPT 继续'), findsNothing);
  });
}
