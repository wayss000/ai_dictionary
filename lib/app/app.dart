import 'package:flutter/material.dart';

import '../features/dictionary/presentation/dictionary_page.dart';
import 'theme.dart';

class AiDictionaryApp extends StatelessWidget {
  const AiDictionaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Dictionary',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const DictionaryPage(),
    );
  }
}
