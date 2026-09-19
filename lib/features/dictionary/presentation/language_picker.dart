import 'package:flutter/material.dart';

Future<String?> showLanguagePicker(
  BuildContext context, {
  required String selectedLanguagePair,
}) {
  const languagePairs = [
    '自动识别 → 中文',
    '英语 → 中文',
    '中文 → 英语',
    '日语 → 中文',
    '韩语 → 英语',
  ];

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('选择语言组合'), subtitle: Text('输入语言 → 输出语言')),
          for (final pair in languagePairs)
            ListTile(
              leading: Icon(
                pair == selectedLanguagePair
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(pair),
              onTap: () => Navigator.of(context).pop(pair),
            ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('管理语言组合'),
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
