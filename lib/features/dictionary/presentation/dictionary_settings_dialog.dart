import 'package:flutter/material.dart';

Future<void> showDictionarySettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('设置'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('模型配置、提示词和缓存将在这里管理。'),
          SizedBox(height: 16),
          Text('当前模型', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('默认模型 · OpenAI-compatible'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
