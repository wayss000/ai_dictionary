import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QueryPanel extends StatelessWidget {
  const QueryPanel({
    required this.controller,
    required this.isLoading,
    required this.modelLabel,
    required this.onExplain,
    super.key,
  });

  final TextEditingController controller;
  final bool isLoading;
  final String modelLabel;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '原文',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Shortcuts(
              // 回车键触发"解释"，Shift + 回车保留换行。
              shortcuts: {
                SingleActivator(LogicalKeyboardKey.enter):
                    const _ExplainIntent(),
              },
              child: Actions(
                actions: {
                  _ExplainIntent: CallbackAction<_ExplainIntent>(
                    onInvoke: (_) {
                      onExplain();
                      return null;
                    },
                  ),
                },
                child: TextField(
                  controller: controller,
                  minLines: 2,
                  style: theme.textTheme.titleLarge?.copyWith(height: 1.4),
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: '输入单词、短语或句子',
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    modelLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: 'Enter 翻译 · Shift + Enter 换行',
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : onExplain,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward, size: 18),
                    label: Text(isLoading ? '翻译中' : '翻译'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplainIntent extends Intent {
  const _ExplainIntent();
}
