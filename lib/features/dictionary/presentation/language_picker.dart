import 'package:flutter/material.dart';

/// 底部弹层中"管理语言组合"的返回信号，主页面收到后跳转设置。
const kManageLanguageSignal = '__manage_language__';

Future<String?> showLanguagePicker(
  BuildContext context, {
  required List<String> languagePairs,
  required String selectedLanguagePair,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('选择语言组合'),
              subtitle: Text('输入语言 → 输出语言'),
            ),
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
              subtitle: const Text('在设置中添加、删除或切换'),
              onTap: () =>
                  Navigator.of(context).pop(kManageLanguageSignal),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
