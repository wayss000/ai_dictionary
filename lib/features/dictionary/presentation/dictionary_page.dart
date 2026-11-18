import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/dictionary_view_model.dart';
import '../data/llm_service.dart';
import 'dictionary_result_card.dart';
import 'dictionary_settings_dialog.dart';
import 'language_picker.dart';
import 'query_panel.dart';

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  final _queryController = TextEditingController(text: 'transformer');
  late final DictionaryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DictionaryViewModel();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  String _resultToPlainText(DictionaryResult result) {
    final buffer = StringBuffer()
      ..writeln('${result.term}：${result.translation}');
    if (result.context.isNotEmpty) {
      buffer.writeln('当前语境：${result.context}');
    }
    if (result.partOfSpeech.isNotEmpty) {
      buffer.writeln('词性：${result.partOfSpeech}');
    }
    for (final example in result.examples) {
      buffer
        ..writeln(example.original)
        ..writeln(example.translated);
    }
    return buffer.toString().trim();
  }

  Future<void> _copyResult() async {
    final result = _viewModel.result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: _resultToPlainText(result)));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('结果已复制')));
  }

  Future<void> _selectLanguage() async {
    final selected = await showLanguagePicker(
      context,
      selectedLanguagePair: _viewModel.languagePair,
    );
    if (selected != null) _viewModel.selectLanguagePair(selected);
  }

  Future<void> _openSettings() {
    return showDictionarySettingsDialog(
      context,
      initialConfig: _viewModel.config,
      onSave: _viewModel.updateConfig,
    );
  }

  void _explain() => _viewModel.explain(_queryController.text);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFFF8F8FC),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                    sliver: SliverToBoxAdapter(
                      child: DictionaryHeader(
                        languagePair: _viewModel.languagePair,
                        onLanguagePressed: _selectLanguage,
                        onSettingsPressed: _openSettings,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    sliver: SliverToBoxAdapter(
                      child: QueryPanel(
                        controller: _queryController,
                        isLoading: _viewModel.isLoading,
                        modelLabel: _viewModel.modelLabel,
                        onExplain: _explain,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
                    sliver: SliverToBoxAdapter(
                      child: DictionaryResultCard(
                        isLoading: _viewModel.isLoading,
                        hasResult: _viewModel.hasResult,
                        hasError: _viewModel.hasError,
                        errorMessage: _viewModel.errorMessage,
                        result: _viewModel.result,
                        onCopy: _copyResult,
                        onRetry: _explain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DictionaryHeader extends StatelessWidget {
  const DictionaryHeader({
    required this.languagePair,
    required this.onLanguagePressed,
    required this.onSettingsPressed,
    super.key,
  });

  final String languagePair;
  final VoidCallback onLanguagePressed;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Dictionary',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Text('理解词义，也理解语境', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onLanguagePressed,
          icon: const Icon(Icons.translate, size: 18),
          label: Text(languagePair),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSettingsPressed,
          tooltip: '设置',
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}
