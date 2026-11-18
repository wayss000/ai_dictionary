import 'package:flutter/material.dart';

import '../data/llm_service.dart';

class DictionaryResultCard extends StatelessWidget {
  const DictionaryResultCard({
    required this.isLoading,
    required this.hasResult,
    required this.hasError,
    required this.errorMessage,
    required this.result,
    required this.onCopy,
    required this.onRetry,
    super.key,
  });

  final bool isLoading;
  final bool hasResult;
  final bool hasError;
  final String? errorMessage;
  final DictionaryResult? result;
  final VoidCallback onCopy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _LoadingResultCard();
    if (hasError) {
      return _ErrorResultCard(message: errorMessage ?? '请求失败，请重试。', onRetry: onRetry);
    }
    final result = this.result;
    if (!hasResult || result == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultHeading(result: result, onCopy: onCopy),
            const Divider(height: 32),
            if (result.context.isNotEmpty) ...[
              ResultSection(
                title: '当前语境',
                child: Text(
                  result.context,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (result.partOfSpeech.isNotEmpty) ...[
              ResultSection(
                title: '词性',
                child: Text(result.partOfSpeech, style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(height: 20),
            ],
            if (result.examples.isNotEmpty)
              ResultSection(
                title: '例句',
                child: _ExampleText(
                  examples: result.examples,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            if (result.context.isEmpty &&
                result.partOfSpeech.isEmpty &&
                result.examples.isEmpty)
              ResultSection(
                title: '解释',
                child: Text(
                  result.translation,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ),
            const SizedBox(height: 24),
            _ResultFooter(model: result.model, onRetry: onRetry),
          ],
        ),
      ),
    );
  }
}

class _LoadingResultCard extends StatelessWidget {
  const _LoadingResultCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorResultCard extends StatelessWidget {
  const _ErrorResultCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                const Text('解释失败', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              message,
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultHeading extends StatelessWidget {
  const _ResultHeading({required this.result, required this.onCopy});

  final DictionaryResult result;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                result.term,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              if (result.translation.isNotEmpty) ...[
                const SizedBox(height: 6),
                SelectableText(
                  result.translation,
                  style: const TextStyle(fontSize: 17),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: onCopy,
          tooltip: '复制结果',
          icon: const Icon(Icons.copy_outlined),
        ),
      ],
    );
  }
}

class _ExampleText extends StatelessWidget {
  const _ExampleText({required this.examples, required this.color});

  final List<WordExample> examples;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final example in examples) ...[
          SelectableText(
            example.original,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          SelectableText(
            example.translated,
            style: TextStyle(fontSize: 15, height: 1.5, color: color),
          ),
          if (example != examples.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ResultFooter extends StatelessWidget {
  const _ResultFooter({required this.model, required this.onRetry});

  final String model;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '由 $model 生成，AI 解释可能存在偏差，请结合上下文判断。',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('重新解释'),
        ),
      ],
    );
  }
}

class ResultSection extends StatelessWidget {
  const ResultSection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
