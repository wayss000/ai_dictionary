import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AiDictionaryApp());

class AiDictionaryApp extends StatelessWidget {
  const AiDictionaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Dictionary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
        ),
      ),
      home: const DictionaryPage(),
    );
  }
}

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  final _queryController = TextEditingController(text: 'transformer');
  String _languagePair = '自动识别 → 中文';
  bool _isLoading = false;
  bool _hasResult = true;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _explain() async {
    if (_queryController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasResult = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasResult = true;
    });
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(
      const ClipboardData(text: 'Transformer：变换器；转换器；在 AI 语境中通常指一种神经网络架构。'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('结果已复制')));
  }

  Future<void> _selectLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('选择语言组合'),
              subtitle: Text('输入语言 → 输出语言'),
            ),
            for (final pair in [
              '自动识别 → 中文',
              '英语 → 中文',
              '中文 → 英语',
              '日语 → 中文',
              '韩语 → 英语',
            ])
              ListTile(
                leading: Icon(
                  pair == _languagePair
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
    if (selected != null) setState(() => _languagePair = selected);
  }

  Future<void> _openSettings() async {
    await showDialog<void>(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                  sliver: SliverToBoxAdapter(child: _buildHeader()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  sliver: SliverToBoxAdapter(child: _buildQueryCard()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
                  sliver: SliverToBoxAdapter(child: _buildResultCard()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          onPressed: _selectLanguage,
          icon: const Icon(Icons.translate, size: 18),
          label: Text(_languagePair),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _openSettings,
          tooltip: '设置',
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }

  Widget _buildQueryCard() {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _queryController,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '输入单词、短语或句子',
                hintStyle: TextStyle(color: Colors.black38),
              ),
              onSubmitted: (_) => _explain(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                const Text('默认模型', style: TextStyle(color: Colors.black54)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _explain,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward, size: 18),
                  label: Text(_isLoading ? '解释中' : '解释'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_isLoading) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (!_hasResult) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transformer',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '变换器；转换器；Transformer 模型',
                        style: TextStyle(fontSize: 17),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _copyResult,
                  tooltip: '复制结果',
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
            const Divider(height: 32),
            _ResultSection(
              title: '当前语境',
              child: const Text(
                '在人工智能语境中，Transformer 通常指一种用于处理序列数据的神经网络架构，也是许多现代大语言模型的基础。',
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
            ),
            const SizedBox(height: 20),
            _ResultSection(
              title: '词性',
              child: const Text('名词', style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 20),
            _ResultSection(
              title: '例句',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transformer models process sequential data.',
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                  Text(
                    'Transformer 模型处理序列数据。',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
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
                  onPressed: _explain,
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text('重新解释'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.child});

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
