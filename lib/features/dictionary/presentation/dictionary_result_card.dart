import 'package:flutter/material.dart';

class DictionaryResultCard extends StatelessWidget {
  const DictionaryResultCard({
    required this.isLoading,
    required this.hasResult,
    required this.onCopy,
    required this.onRetry,
    super.key,
  });

  final bool isLoading;
  final bool hasResult;
  final VoidCallback onCopy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _LoadingResultCard();
    if (!hasResult) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultHeading(onCopy: onCopy),
            const Divider(height: 32),
            const ResultSection(
              title: '当前语境',
              child: Text(
                '在人工智能语境中，Transformer 通常指一种用于处理序列数据的神经网络架构，也是许多现代大语言模型的基础。',
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
            ),
            const SizedBox(height: 20),
            const ResultSection(
              title: '词性',
              child: Text('名词', style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 20),
            ResultSection(
              title: '例句',
              child: _ExampleText(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 24),
            _ResultFooter(onRetry: onRetry),
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

class _ResultHeading extends StatelessWidget {
  const _ResultHeading({required this.onCopy});

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transformer',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text('变换器；转换器；Transformer 模型', style: TextStyle(fontSize: 17)),
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
  const _ExampleText({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transformer models process sequential data.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        Text(
          'Transformer 模型处理序列数据。',
          style: TextStyle(fontSize: 15, height: 1.5, color: color),
        ),
      ],
    );
  }
}

class _ResultFooter extends StatelessWidget {
  const _ResultFooter({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: Colors.black45),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'AI 解释可能存在偏差，请结合上下文判断。',
            style: TextStyle(color: Colors.black54, fontSize: 12),
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
