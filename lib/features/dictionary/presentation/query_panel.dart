import 'package:flutter/material.dart';

class QueryPanel extends StatelessWidget {
  const QueryPanel({
    required this.controller,
    required this.isLoading,
    required this.onExplain,
    super.key,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '输入单词、短语或句子',
                hintStyle: TextStyle(color: Colors.black38),
              ),
              onSubmitted: (_) => onExplain(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                const Text('默认模型', style: TextStyle(color: Colors.black54)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: isLoading ? null : onExplain,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward, size: 18),
                  label: Text(isLoading ? '解释中' : '解释'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
