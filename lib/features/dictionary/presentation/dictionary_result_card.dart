import 'package:flutter/material.dart';

import '../../../app/app_strings.dart';

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
    final l10n = AppStrings.of(context);
    if (isLoading) return const _LoadingResultCard();
    if (hasError) {
      return _ErrorResultCard(
        message: errorMessage ?? l10n.requestFailed,
        onRetry: onRetry,
      );
    }
    final result = this.result;
    if (!hasResult || result == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultHeading(result: result, onCopy: onCopy),
            if (result.context.isNotEmpty ||
                result.partOfSpeech.isNotEmpty ||
                result.examples.isNotEmpty)
              const Divider(height: 36),
            if (result.context.isNotEmpty) ...[
              ResultSection(
                title: l10n.context,
                child: Text(
                  result.context,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (result.partOfSpeech.isNotEmpty) ...[
              ResultSection(
                title: l10n.partOfSpeech,
                child: Text(
                  result.partOfSpeech,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (result.examples.isNotEmpty)
              ResultSection(
                title: l10n.examples,
                child: _ExampleText(
                  examples: result.examples,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            const Divider(height: 24),
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
      child: Padding(
        padding: EdgeInsets.all(24),
        child: LinearProgressIndicator(),
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
    final l10n = AppStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.explanationFailed,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              message,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 17),
              label: Text(l10n.retry),
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
    final l10n = AppStrings.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                result.term,
                style: const TextStyle(
                  fontSize: 32,
                  height: 1.18,
                  fontFamilyFallback: ['Georgia', 'Times New Roman'],
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (result.translation.isNotEmpty) ...[
                const SizedBox(height: 6),
                SelectableText(
                  result.translation,
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: onCopy,
          tooltip: l10n.copyResult,
          icon: const Icon(Icons.copy_outlined, size: 18),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 2,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Column(
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
              if (example != examples.last) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultFooter extends StatelessWidget {
  const _ResultFooter({required this.model, required this.onRetry});

  final String model;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.resultAttribution(model),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 17),
          label: Text(l10n.translateAgain),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
