import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/dictionary/presentation/dictionary_page.dart';
import 'app_strings.dart';
import 'theme.dart';

class AiDictionaryApp extends StatefulWidget {
  const AiDictionaryApp({super.key});

  @override
  State<AiDictionaryApp> createState() => _AiDictionaryAppState();
}

class _AiDictionaryAppState extends State<AiDictionaryApp> {
  static const _localeKey = 'app_locale';
  late final _preferences = SharedPreferences.getInstance();
  Locale _locale = AppStrings.simplifiedChinese;

  @override
  void initState() {
    super.initState();
    _restoreLocale();
  }

  Future<void> _restoreLocale() async {
    try {
      final preferences = await _preferences;
      if (mounted &&
          preferences.getString(_localeKey) ==
              AppStrings.english.toLanguageTag()) {
        setState(() => _locale = AppStrings.english);
      }
    } on Exception catch (error) {
      debugPrint('Could not restore the app language: $error');
    }
  }

  Future<bool> _selectLocale(Locale locale) async {
    final preferences = await _preferences;
    final saved = await preferences.setString(
      _localeKey,
      locale.toLanguageTag(),
    );
    if (saved && mounted) setState(() => _locale = locale);
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Dictionary',
      locale: _locale,
      supportedLocales: const [
        AppStrings.simplifiedChinese,
        AppStrings.english,
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: DictionaryPage(onLocaleSelected: _selectLocale),
    );
  }
}
