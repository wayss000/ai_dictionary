import 'package:flutter/material.dart';

import '../data/llm_config.dart';
import '../data/llm_service.dart';

/// 打开大模型配置面板。
Future<void> showDictionarySettingsDialog(
  BuildContext context, {
  required LlmConfig initialConfig,
  required Future<void> Function(LlmConfig config) onSave,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ModelSettingsPanel(initialConfig: initialConfig, onSave: onSave),
  );
}

class _ModelSettingsPanel extends StatefulWidget {
  const _ModelSettingsPanel({required this.initialConfig, required this.onSave});

  final LlmConfig initialConfig;
  final Future<void> Function(LlmConfig config) onSave;

  @override
  State<_ModelSettingsPanel> createState() => _ModelSettingsPanelState();
}

class _ModelSettingsPanelState extends State<_ModelSettingsPanel> {
  late final TextEditingController _baseUrlController =
      TextEditingController(text: widget.initialConfig.baseUrl);
  late final TextEditingController _apiKeyController =
      TextEditingController(text: widget.initialConfig.apiKey);
  late final TextEditingController _modelController =
      TextEditingController(text: widget.initialConfig.model);

  bool _obscureApiKey = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testMessage;
  bool _testSucceeded = false;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  LlmConfig _buildConfig() => widget.initialConfig.copyWith(
        baseUrl: _baseUrlController.text,
        apiKey: _apiKeyController.text,
        model: _modelController.text,
      );

  bool get _canSave =>
      _apiKeyController.text.trim().isNotEmpty && _modelController.text.trim().isNotEmpty;

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
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_buildConfig());
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.tune, size: 22),
          const SizedBox(width: 8),
          const Text('模型设置'),
          const SizedBox(width: 8),
          Text('OpenAI 兼容接口',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(
              label: 'API 地址',
              hint: '例如 https://api.openai.com/v1',
              controller: _baseUrlController,
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'API Key',
              hint: 'sk-...',
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              suffix: IconButton(
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
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: '模型名称',
              hint: '例如 gpt-4o-mini、deepseek-chat',
              controller: _modelController,
            ),
            const SizedBox(height: 8),
            Text(
              'API Key 仅保存在本机（shared_preferences），不会上传。',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: 12),
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
                        color: _testSucceeded ? Colors.green : theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTesting || !_canSave ? null : _testConnection,
          child: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('测试连接'),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isSaving || !_canSave ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
