import 'package:flutter/material.dart';

import '../../../app/app_strings.dart';

/// 底部弹层中"管理语言组合"的返回信号，主页面收到后跳转设置。
const kManageLanguageSignal = '__manage_language__';

Future<String?> showLanguagePicker(
  BuildContext context, {
  required List<String> languagePairs,
  required String selectedLanguagePair,
}) {
  final l10n = AppStrings.of(context);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.selectPair),
              subtitle: Text(l10n.pairDirection),
            ),
            for (final pair in languagePairs)
              ListTile(
                leading: Icon(
                  pair == selectedLanguagePair
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(l10n.pairName(pair)),
                onTap: () => Navigator.of(context).pop(pair),
              ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l10n.managePairs),
              subtitle: Text(l10n.managePairsHelp),
              onTap: () => Navigator.of(context).pop(kManageLanguageSignal),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
