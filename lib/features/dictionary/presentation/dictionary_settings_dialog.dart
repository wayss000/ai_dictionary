import 'package:flutter/material.dart';

import '../application/dictionary_view_model.dart';
import '../data/llm_call_log.dart';
import '../data/llm_config.dart';
import '../data/llm_service.dart';

/// 打开设置面板：模型配置（多模型切换）+ 调用日志。
Future<void> showDictionarySettingsDialog(
  BuildContext context, {
  required DictionaryViewModel viewModel,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SettingsPanel(viewModel: viewModel),
  );
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({required this.viewModel});

  final DictionaryViewModel viewModel;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  String? _editingId;
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();

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
    super.dispose();
  }

  void _startEdit(LlmConfig profile) {
    setState(() {
      _editingId = profile.id;
      _nameController.text = profile.name;
      _baseUrlController.text = profile.baseUrl;
      _apiKeyController.text = profile.apiKey;
      _modelController.text = profile.model;
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
      builder: (context, _) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.tune, size: 22),
              const SizedBox(width: 8),
              const Text('设置'),
            ],
          ),
          content: SizedBox(
            width: 580,
            height: 520,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: '模型配置'),
                    Tab(text: '调用日志'),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildModelTab(theme),
                      _buildLogTab(theme),
                    ],
                  ),
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
      ),
    );
  }

  Widget _buildModelTab(ThemeData theme) {
    final viewModel = widget.viewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已保存的模型（点选切换生效）',
            style:
                theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
        const SizedBox(height: 4),
        Flexible(
          child: viewModel.profiles.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('还没有配置，在下方新增一个模型配置。',
                      style: TextStyle(color: Colors.black38)),
                )
              : RadioGroup<String>(
                  groupValue: viewModel.activeProfileId,
                  onChanged: (value) {
                    if (value != null) viewModel.activateProfile(value);
                  },
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final profile in viewModel.profiles)
                        _profileTile(theme, profile),
                    ],
                  ),
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
