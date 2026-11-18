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
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Shortcuts(
              // 回车键触发"解释"，Shift + 回车保留换行。
              shortcuts: {
                SingleActivator(LogicalKeyboardKey.enter): const _ExplainIntent(),
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
                  minLines: 3,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: '输入单词、短语或句子（按回车解释，Shift+回车换行）',
                    hintStyle: TextStyle(color: Colors.black38),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    modelLabel,
                    style: const TextStyle(color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                  label: Text(isLoading ? '翻译中' : '翻译'),
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
