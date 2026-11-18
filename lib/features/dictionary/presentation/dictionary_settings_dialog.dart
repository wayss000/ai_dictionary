import 'package:flutter/material.dart';

import '../application/dictionary_view_model.dart';
import '../data/llm_call_log.dart';
import '../data/llm_config.dart';
import '../data/llm_service.dart';
import '../data/prompt_store.dart';

/// 打开设置面板：模型配置 / 调用日志 / 语言组合 / 提示词管理。
Future<void> showDictionarySettingsDialog(
  BuildContext context, {
  required DictionaryViewModel viewModel,
  int initialTab = 0,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SettingsPanel(viewModel: viewModel, initialTab: initialTab),
  );
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({required this.viewModel, this.initialTab = 0});

  final DictionaryViewModel viewModel;
  final int initialTab;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  String? _editingId;
  String? _editingPromptId;
  late int _selectedTab = widget.initialTab;
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _timeoutController = TextEditingController(text: '60');
  final _langController = TextEditingController();
  final _promptNameController = TextEditingController();
  final _promptContentController = TextEditingController();

  bool _obscureApiKey = true;
  bool _isTesting = false;
  String? _testMessage;
  bool _testSucceeded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _timeoutController.dispose();
    _langController.dispose();
    _promptNameController.dispose();
    _promptContentController.dispose();
    super.dispose();
  }

  void _startEdit(LlmConfig profile) {
    setState(() {
      _editingId = profile.id;
      _nameController.text = profile.name;
      _baseUrlController.text = profile.baseUrl;
      _apiKeyController.text = profile.apiKey;
      _modelController.text = profile.model;
      _timeoutController.text = profile.timeoutSeconds.toString();
      _testMessage = null;
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _baseUrlController.clear();
      _apiKeyController.clear();
      _modelController.clear();
      _timeoutController.text = '60';
      _testMessage = null;
    });
  }

  bool get _canSave =>
      _apiKeyController.text.trim().isNotEmpty &&
      _modelController.text.trim().isNotEmpty;

  LlmConfig _buildConfig() => LlmConfig(
        id: _editingId ?? LlmConfigStore.newId(),
        name: _nameController.text,
        baseUrl: _baseUrlController.text,
        apiKey: _apiKeyController.text,
        model: _modelController.text,
        timeoutSeconds:
            int.tryParse(_timeoutController.text) ?? LlmConfig.defaultTimeoutSeconds,
      );

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testMessage = null;
    });
    try {
      await LlmService().testConnection(_buildConfig());
      setState(() {
        _testSucceeded = true;
        _testMessage = '连接成功，配置可用。';
      });
    } catch (error) {
      setState(() {
        _testSucceeded = false;
        _testMessage = error.toString();
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _save() async {
    await widget.viewModel.saveProfile(_buildConfig());
    if (!mounted) return;
    _resetForm();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存并生效')));
  }

  Future<void> _delete(LlmConfig profile) async {
    await widget.viewModel.deleteProfile(profile.id);
    if (!mounted) return;
    if (_editingId == profile.id) _resetForm();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已删除 ${profile.displayName}')));
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.tune, size: 22),
            const SizedBox(width: 8),
            const Text('设置'),
          ],
        ),
        content: SizedBox(
          width: 640,
          height: 560,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSidebar(theme),
              const VerticalDivider(width: 24),
              Expanded(
                child: switch (_selectedTab) {
                  1 => _buildLogTab(theme),
                  2 => _buildLanguageTab(theme),
                  3 => _buildPromptTab(theme),
                  _ => _buildModelTab(theme),
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    return SizedBox(
      width: 128,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sideItem(theme, 0, Icons.tune_outlined, '模型配置'),
          _sideItem(theme, 1, Icons.receipt_long_outlined, '调用日志'),
          _sideItem(theme, 2, Icons.translate_outlined, '语言组合'),
          _sideItem(theme, 3, Icons.description_outlined, '提示词管理'),
        ],
      ),
    );
  }

  Widget _sideItem(ThemeData theme, int index, IconData icon, String label) {
    final selected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedTab = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.black54,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelTab(ThemeData theme) {
    final viewModel = widget.viewModel;
    // 用 ListView 让整个页签可滚动，避免内容过高时按钮被裁切。
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text('已保存的模型（点选切换生效）',
            style:
                theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
        const SizedBox(height: 4),
        if (viewModel.profiles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('还没有配置，在下方新增一个模型配置。',
                style: TextStyle(color: Colors.black38)),
          )
        else
          RadioGroup<String>(
            groupValue: viewModel.activeProfileId,
            onChanged: (value) {
              if (value != null) viewModel.activateProfile(value);
            },
            child: Column(
              children: [
                for (final profile in viewModel.profiles)
                  _profileTile(theme, profile),
              ],
            ),
          ),
        const Divider(height: 24),
        Text(
          _editingId == null ? '新增模型配置' : '编辑模型配置',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildField(
          label: '名称（选填）',
          hint: '例如 智谱 / 硅基流动',
          controller: _nameController,
        ),
        const SizedBox(height: 10),
        _buildField(
          label: 'API 地址',
          hint: '例如 https://api.openai.com/v1',
          controller: _baseUrlController,
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildField(
                label: 'API Key',
                hint: 'sk-...',
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
              ),
            ),
            IconButton(
              onPressed: () =>
                  setState(() => _obscureApiKey = !_obscureApiKey),
              icon: Icon(
                _obscureApiKey
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              tooltip: _obscureApiKey ? '显示' : '隐藏',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildField(
          label: '模型名称',
          hint: '例如 glm-4-flash、Qwen/Qwen3.5-4B',
          controller: _modelController,
        ),
        const SizedBox(height: 10),
        _buildField(
          label: '超时时间（秒）',
          hint: '默认 60，最小 5',
          controller: _timeoutController,
          keyboardType: TextInputType.number,
        ),
        if (_testMessage != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _testSucceeded ? Icons.check_circle : Icons.error_outline,
                size: 18,
                color: _testSucceeded ? Colors.green : theme.colorScheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _testMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        _testSucceeded ? Colors.green : theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isTesting || !_canSave ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check, size: 16),
              label: const Text('测试连接'),
            ),
            const Spacer(),
            if (_editingId != null)
              TextButton(
                onPressed: _resetForm,
                child: const Text('取消编辑'),
              ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: _isTesting || !_canSave ? null : _save,
              icon: const Icon(Icons.check, size: 16),
              label: Text(_editingId == null ? '保存并生效' : '保存修改'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'API Key 仅保存在本机（shared_preferences），不会上传。',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
        ),
      ],
    );
  }

  Widget _buildLanguageTab(ThemeData theme) {
    final viewModel = widget.viewModel;
    // 与模型配置页签一致，使用 ListView 保证内容可滚动、按钮不被裁切。
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text('已保存的语言组合（点选切换生效）',
            style:
                theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
        const SizedBox(height: 4),
        RadioGroup<String>(
          groupValue: viewModel.languagePair,
          onChanged: (value) {
            if (value != null) viewModel.selectLanguagePair(value);
          },
          child: Column(
            children: [
              for (final pair in viewModel.languagePairs)
                RadioListTile<String>(
                  value: pair,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          pair,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                pair == viewModel.languagePair
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (pair == viewModel.languagePair) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text('生效中',
                            style: TextStyle(
                                fontSize: 12, color: Colors.green)),
                      ],
                    ],
                  ),
                  secondary: IconButton(
                    onPressed: viewModel.languagePairs.length <= 1
                        ? null
                        : () => viewModel.deleteLanguagePair(pair),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: viewModel.languagePairs.length <= 1
                          ? Colors.black26
                          : theme.colorScheme.error,
                    ),
                    tooltip: viewModel.languagePairs.length <= 1
                        ? '至少保留一个组合'
                        : '删除',
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        Text('新增语言组合',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildField(
          label: '语言组合（输入语言 → 输出语言）',
          hint: '例如 法语 → 中文',
          controller: _langController,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            FilledButton.icon(
              onPressed: () async {
                final text = _langController.text.trim();
                if (text.isEmpty) return;
                await widget.viewModel.addLanguagePair(text);
                _langController.clear();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加'),
            ),
          ],
        ),
      ],
    );
  }

  /// 提示词管理页签：切换 / 新增 / 编辑 / 删除提示词模板。
  Widget _buildPromptTab(ThemeData theme) {
    final viewModel = widget.viewModel;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text('已保存的提示词模板（点选切换生效）',
            style:
                theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
        const SizedBox(height: 4),
        RadioGroup<String>(
          groupValue: viewModel.selectedPrompt.id,
          onChanged: (value) {
            if (value != null) viewModel.selectPrompt(value);
          },
          child: Column(
            children: [
              for (final template in viewModel.promptTemplates)
                _promptTile(theme, template),
            ],
          ),
        ),
        const Divider(height: 24),
        Text(
          _editingPromptId == null ? '新增提示词模板' : '编辑提示词模板',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildField(
          label: '名称（选填）',
          hint: '例如 简短词典 / 详细解释',
          controller: _promptNameController,
        ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('提示词内容',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            TextField(
              controller: _promptContentController,
              maxLines: 8,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: '支持 {word}（用户输入的单词）和 {language}（语言方向）占位符',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_editingPromptId == PromptTemplate.defaultPromptId)
              TextButton.icon(
                onPressed: () async {
                  _promptContentController.text =
                      PromptTemplate.defaultContent;
                  _promptNameController.text = PromptTemplate.defaultName;
                  await widget.viewModel.restoreDefaultPrompt();
                  _resetPromptForm();
                },
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('恢复默认内容'),
              ),
            const Spacer(),
            if (_editingPromptId != null)
              TextButton(
                onPressed: _resetPromptForm,
                child: const Text('取消编辑'),
              ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: _promptContentController.text.trim().isEmpty
                  ? null
                  : _savePrompt,
              icon: const Icon(Icons.check, size: 16),
              label: Text(_editingPromptId == null ? '保存并生效' : '保存修改'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '提示词会与用户输入的单词结合（替换 {word} / {language} 占位符）后，统一发送给当前生效的模型。',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
        ),
      ],
    );
  }

  Widget _promptTile(ThemeData theme, PromptTemplate template) {
    final viewModel = widget.viewModel;
    final isActive = viewModel.selectedPrompt.id == template.id;
    return RadioListTile<String>(
      value: template.id,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Flexible(
            child: Text(
              template.name.trim().isEmpty ? '未命名模板' : template.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle, size: 16, color: Colors.green),
            const SizedBox(width: 4),
            const Text('生效中',
                style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ],
      ),
      subtitle: Text(
        template.content.replaceAll('\n', ' '),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(fontSize: 12),
      ),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _startPromptEdit(template),
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: '编辑',
          ),
          IconButton(
            onPressed: viewModel.promptTemplates.length <= 1
                ? null
                : () => _deletePrompt(template),
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: viewModel.promptTemplates.length <= 1
                  ? Colors.black26
                  : theme.colorScheme.error,
            ),
            tooltip: viewModel.promptTemplates.length <= 1
                ? '至少保留一个模板'
                : '删除',
          ),
        ],
      ),
    );
  }

  void _startPromptEdit(PromptTemplate template) {
    setState(() {
      _editingPromptId = template.id;
      _promptNameController.text = template.name;
      _promptContentController.text = template.content;
    });
  }

  void _resetPromptForm() {
    setState(() {
      _editingPromptId = null;
      _promptNameController.clear();
      _promptContentController.clear();
    });
  }

  Future<void> _savePrompt() async {
    final content = _promptContentController.text.trim();
    if (content.isEmpty) return;
    final id = _editingPromptId ?? PromptStore.newPromptId();
    final name = _promptNameController.text.trim().isEmpty
        ? '未命名模板'
        : _promptNameController.text.trim();
    await widget.viewModel
        .savePrompt(PromptTemplate(id: id, name: name, content: content));
    if (!mounted) return;
    _resetPromptForm();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('提示词已保存并生效')));
  }

  Future<void> _deletePrompt(PromptTemplate template) async {
    final viewModel = widget.viewModel;
    if (viewModel.promptTemplates.length <= 1) return;
    await viewModel.deletePrompt(template.id);
    if (!mounted) return;
    if (_editingPromptId == template.id) _resetPromptForm();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 ${template.name.trim().isEmpty ? '未命名模板' : template.name}')));
  }

  Widget _profileTile(ThemeData theme, LlmConfig profile) {
    final viewModel = widget.viewModel;
    final isActive = viewModel.activeProfileId == profile.id;
    return RadioListTile<String>(
      value: profile.id,
      dense: true,
      title: Row(
        children: [
          Flexible(
            child: Text(
              profile.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle, size: 16, color: Colors.green),
            const SizedBox(width: 4),
            const Text('生效中',
                style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ],
      ),
      subtitle: Text(
        '${profile.model} · ${profile.baseUrl}',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _startEdit(profile),
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: '编辑',
          ),
          IconButton(
            onPressed: () => _delete(profile),
            icon: Icon(Icons.delete_outline,
                size: 18, color: theme.colorScheme.error),
            tooltip: '删除',
          ),
        ],
      ),
    );
  }

  Widget _buildLogTab(ThemeData theme) {
    final logs = widget.viewModel.logs;
    if (logs.isEmpty) {
      return const Center(
        child: Text('暂无调用记录，去解释几个词吧。',
            style: TextStyle(color: Colors.black38)),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Text('最近 ${logs.length} 次调用',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.black54)),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.viewModel.clearLogs,
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            children: [for (final log in logs) _logTile(theme, log)],
          ),
        ),
      ],
    );
  }

  Widget _logTile(ThemeData theme, LlmCallLog log) {
    final tokens = [
      if (log.promptTokens != null) '输入 ${log.promptTokens} tok',
      if (log.completionTokens != null) '输出 ${log.completionTokens} tok',
    ].join(' · ');
    final duration = log.durationMs >= 1000
        ? '${(log.durationMs / 1000).toStringAsFixed(1)}s'
        : '${log.durationMs}ms';
    return ExpansionTile(
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      leading: Icon(
        log.success ? Icons.check_circle : Icons.error_outline,
        size: 18,
        color: log.success ? Colors.green : theme.colorScheme.error,
      ),
      title: Text(
        '${log.query.replaceAll('\n', ' ')}（$duration）',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${_formatTime(log.time)} · ${log.model}${tokens.isEmpty ? '' : ' · $tokens'}'
        '${log.success ? '' : ' · 失败'}',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      children: [
        if ((log.systemPrompt ?? '').isNotEmpty) ...[
          const Text('提示词',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          SelectableText(
            log.systemPrompt!,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('输入',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              SelectableText(log.input,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 10),
              const Text('输出',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              SelectableText(
                log.output,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: log.success
                      ? Colors.black87
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
