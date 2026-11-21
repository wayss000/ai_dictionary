import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_strings.dart';

import '../application/dictionary_view_model.dart';
import '../data/llm_call_log.dart';
import '../data/chatgpt_plan.dart';
import '../data/llm_config.dart';
import '../data/llm_service.dart';
import '../data/prompt_store.dart';

/// 打开词典设置面板。
Future<void> showDictionarySettingsDialog(
  BuildContext context, {
  required DictionaryViewModel viewModel,
  required Future<bool> Function(Locale) onLocaleSelected,
  int initialTab = 0,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SettingsPanel(
      viewModel: viewModel,
      initialTab: initialTab,
      onLocaleSelected: onLocaleSelected,
    ),
  );
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({
    required this.viewModel,
    required this.onLocaleSelected,
    required this.initialTab,
  });

  final Future<bool> Function(Locale) onLocaleSelected;

  final DictionaryViewModel viewModel;
  final int initialTab;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  AppStrings get l10n => AppStrings.of(context);

  String _errorDetails(Object error) {
    if (!l10n.isEnglish) return error.toString();
    return switch (error) {
      LlmException(:final englishMessage) => englishMessage ?? error.toString(),
      ChatGptPlanException(:final englishMessage) =>
        englishMessage ?? error.toString(),
      _ => error.toString(),
    };
  }

  String? _editingId;
  bool _savingLocale = false;
  LlmProvider _provider = LlmProvider.custom;
  String? _draftChatGptId;
  Map<String, String> _chatGptModels = {};
  String? _chatGptEmail;
  bool _isLoadingModels = false;
  bool _isSaving = false;
  Completer<void>? _loginCancellation;

  bool get _busy => _isTesting || _isLoadingModels || _isSaving;

  void _discardDraft() {
    final id = _draftChatGptId;
    _draftChatGptId = null;
    if (id != null) {
      unawaited(ChatGptPlan.instance.disconnect(id).catchError((Object _) {}));
    }
  }

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
  String? _editingPair;

  bool _obscureApiKey = true;
  bool _isTesting = false;
  String Function()? _testMessage;
  bool _testSucceeded = false;

  @override
  void dispose() {
    final cancellation = _loginCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    if (!_isSaving && !_isLoadingModels) _discardDraft();
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
    _discardDraft();
    setState(() {
      _editingId = profile.id;
      _provider = profile.provider;
      _chatGptModels = {};
      _chatGptEmail = null;
      _nameController.text = profile.name;
      _baseUrlController.text = profile.baseUrl;
      _apiKeyController.text = profile.apiKey;
      _modelController.text = profile.model;
      _timeoutController.text = profile.timeoutSeconds.toString();
      _testMessage = null;
    });
    if (profile.provider == LlmProvider.chatGpt) {
      unawaited(_loadChatGptModels());
    }
  }

  void _resetForm() {
    _discardDraft();
    setState(() {
      _editingId = null;
      _provider = LlmProvider.custom;
      _chatGptModels = {};
      _chatGptEmail = null;
      _nameController.clear();
      _baseUrlController.clear();
      _apiKeyController.clear();
      _modelController.clear();
      _timeoutController.text = '60';
      _testMessage = null;
    });
  }

  Future<void> _loadChatGptModels({bool signIn = false}) async {
    final id = _editingId ?? (_draftChatGptId ??= LlmConfigStore.newId());
    final cancellation = signIn ? Completer<void>() : null;
    _loginCancellation = cancellation;
    setState(() {
      _isLoadingModels = true;
      _chatGptModels = {};
      _testMessage = null;
    });
    var signingIn = signIn;
    try {
      if (signIn) {
        final email = await ChatGptPlan.instance.signIn(
          id,
          cancelled: cancellation!.future,
        );
        if (!mounted) return;
        setState(() {
          _chatGptEmail = email;
          _loginCancellation = null;
        });
        signingIn = false;
      }
      final models = await ChatGptPlan.instance.models(id);
      if (models.isEmpty) {
        throw ChatGptPlanException(
          const AppStrings(AppStrings.simplifiedChinese).noAvailableModels,
          englishMessage: const AppStrings(
            AppStrings.english,
          ).noAvailableModels,
        );
      }
      if (!mounted) return;
      setState(() {
        _chatGptModels = models;
        if (!models.containsKey(_modelController.text)) {
          final luna = models.keys.where(
            (model) => model.toLowerCase().contains('luna'),
          );
          _modelController.text = _editingId == null
              ? luna.firstOrNull ?? models.keys.first
              : '';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testSucceeded = false;
        _testMessage = () => l10n.stageFailed(
          signingIn ? l10n.finishSignIn : l10n.loadModels,
          _errorDetails(error),
        );
      });
    } finally {
      _loginCancellation = null;
      if (mounted) {
        setState(() => _isLoadingModels = false);
      } else {
        _discardDraft();
      }
    }
  }

  bool get _canSave =>
      _modelController.text.trim().isNotEmpty &&
      (_provider == LlmProvider.chatGpt
          ? _chatGptModels.containsKey(_modelController.text)
          : _apiKeyController.text.trim().isNotEmpty);

  LlmConfig _buildConfig() => LlmConfig(
    id: _editingId ?? _draftChatGptId ?? LlmConfigStore.newId(),
    provider: _provider,
    name: _nameController.text,
    baseUrl: _baseUrlController.text,
    apiKey: _provider == LlmProvider.custom ? _apiKeyController.text : '',
    model: _modelController.text,
    timeoutSeconds:
        int.tryParse(_timeoutController.text) ??
        LlmConfig.defaultTimeoutSeconds,
  );

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testMessage = null;
    });
    try {
      final service = LlmService();
      try {
        await service.testConnection(_buildConfig());
      } finally {
        service.dispose();
      }
      if (!mounted) return;
      setState(() {
        _testSucceeded = true;
        _testMessage = () => l10n.connectionSucceeded;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testSucceeded = false;
        _testMessage = () => _errorDetails(error);
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.viewModel.saveProfile(_buildConfig());
      _draftChatGptId = null;
      if (!mounted) return;
      _resetForm();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.savedAndActive)));
    } catch (error) {
      if (!mounted) {
        _discardDraft();
        return;
      }
      setState(() {
        _testSucceeded = false;
        _testMessage = () => _errorDetails(error);
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete(LlmConfig profile) async {
    setState(() => _isSaving = true);
    try {
      if (profile.provider == LlmProvider.chatGpt) {
        await ChatGptPlan.instance.disconnect(profile.id);
      }
      await widget.viewModel.deleteProfile(profile.id);
      if (!mounted) return;
      if (_editingId == profile.id) _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleted(profile.displayName))),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testSucceeded = false;
        _testMessage = () => _errorDetails(error);
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
            Text(l10n.settings),
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
                  4 => _buildInterfaceLanguageTab(),
                  _ => _buildModelTab(theme),
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    return SizedBox(
      width: l10n.isEnglish ? 148 : 128,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _sideItem(theme, 0, Icons.tune_outlined, l10n.modelSettings),
          _sideItem(theme, 1, Icons.receipt_long_outlined, l10n.callLogs),
          _sideItem(theme, 2, Icons.translate_outlined, l10n.languagePairs),
          _sideItem(
            theme,
            3,
            Icons.description_outlined,
            l10n.promptManagement,
          ),
          _sideItem(theme, 4, Icons.language, l10n.interfaceLanguage),
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
                  color: selected ? theme.colorScheme.primary : Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterfaceLanguageTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        RadioGroup<Locale>(
          groupValue: l10n.locale,
          onChanged: (locale) {
            if (locale != null) _changeLocale(locale);
          },
          child: Column(
            children: [
              RadioListTile<Locale>(
                value: AppStrings.simplifiedChinese,
                title: const Text('简体中文'),
                enabled: !_savingLocale,
              ),
              RadioListTile<Locale>(
                value: AppStrings.english,
                title: const Text('English'),
                enabled: !_savingLocale,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _changeLocale(Locale locale) async {
    if (_savingLocale || locale == l10n.locale) return;
    setState(() => _savingLocale = true);
    var saved = false;
    try {
      saved = await widget.onLocaleSelected(locale);
    } on Exception catch (error) {
      debugPrint(error.toString());
    }
    if (!mounted) return;
    setState(() => _savingLocale = false);
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.languageSaveFailed)));
    }
  }

  Widget _buildModelTab(ThemeData theme) {
    final viewModel = widget.viewModel;
    // 用 ListView 让整个页签可滚动，避免内容过高时按钮被裁切。
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          l10n.savedModels,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 4),
        if (viewModel.profiles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.noModels,
              style: const TextStyle(color: Colors.black38),
            ),
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
          _editingId == null ? l10n.addModel : l10n.editModel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_editingId == null) ...[
          SegmentedButton<LlmProvider>(
            segments: [
              ButtonSegment(
                value: LlmProvider.custom,
                label: Text(l10n.customModel),
              ),
              ButtonSegment(
                value: LlmProvider.chatGpt,
                label: Text(l10n.signIn),
              ),
            ],
            selected: {_provider},
            onSelectionChanged: _busy
                ? null
                : (selection) {
                    _resetForm();
                    setState(() => _provider = selection.single);
                  },
          ),
          const SizedBox(height: 12),
        ],
        _buildField(
          label: l10n.optionalName,
          hint: l10n.modelNameExample,
          controller: _nameController,
        ),
        const SizedBox(height: 10),
        if (_provider == LlmProvider.custom) ...[
          _buildField(
            label: l10n.apiUrl,
            hint: l10n.apiUrlExample,
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
                tooltip: _obscureApiKey ? l10n.show : l10n.hide,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildField(
            label: l10n.modelName,
            hint: l10n.modelExample,
            controller: _modelController,
          ),
          const SizedBox(height: 10),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _loadChatGptModels(signIn: true),
                child: Text(
                  _editingId == null && _chatGptEmail == null
                      ? l10n.continueWithChatGpt
                      : l10n.signInAgain,
                ),
              ),
              if (_editingId != null || _chatGptEmail != null)
                OutlinedButton(
                  onPressed: _busy ? null : () => _loadChatGptModels(),
                  child: Text(l10n.reloadModels),
                ),
              if (_isLoadingModels) ...[
                Text(
                  _loginCancellation != null
                      ? l10n.waitingForSignIn
                      : l10n.loadingModels,
                ),
                if (_loginCancellation != null)
                  TextButton(
                    onPressed: () {
                      final cancellation = _loginCancellation;
                      if (cancellation != null && !cancellation.isCompleted) {
                        cancellation.complete();
                      }
                    },
                    child: Text(l10n.cancelSignIn),
                  ),
              ] else if (_chatGptEmail != null)
                Text(_chatGptEmail!),
            ],
          ),
          const SizedBox(height: 8),
          if (_chatGptModels.isEmpty)
            Text(_chatGptEmail == null ? l10n.signInHelp : l10n.signedInHelp)
          else
            DropdownButtonFormField<String>(
              key: ValueKey(_chatGptModels),
              isExpanded: true,
              initialValue: _chatGptModels.containsKey(_modelController.text)
                  ? _modelController.text
                  : null,
              decoration: InputDecoration(labelText: l10n.chatGptModel),
              items: [
                for (final entry in _chatGptModels.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (model) => setState(() {
                      _modelController.text = model ?? '';
                      _testMessage = null;
                    }),
            ),
          const SizedBox(height: 10),
        ],
        _buildField(
          label: l10n.timeout,
          hint: l10n.timeoutHint,
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
                  _testMessage!(),
                  style: TextStyle(
                    fontSize: 13,
                    color: _testSucceeded
                        ? Colors.green
                        : theme.colorScheme.error,
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
              onPressed: _busy || !_canSave ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check, size: 16),
              label: Text(l10n.testConnection),
            ),
            const Spacer(),
            if (_editingId != null)
              TextButton(
                onPressed: _busy ? null : _resetForm,
                child: Text(l10n.cancelEdit),
              ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: _busy || !_canSave ? null : _save,
              icon: const Icon(Icons.check, size: 16),
              label: Text(
                _editingId == null ? l10n.saveAndActivate : l10n.saveChanges,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _provider == LlmProvider.chatGpt ? l10n.planUsage : l10n.apiKeyHelp,
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
        Text(
          l10n.savedPairs,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
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
                          l10n.pairName(pair),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: pair == viewModel.languagePair
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (pair == viewModel.languagePair) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.active,
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ],
                  ),
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _startPairEdit(pair),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: l10n.edit,
                      ),
                      IconButton(
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
                            ? l10n.keepOnePair
                            : l10n.delete,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        Text(
          _editingPair == null ? l10n.addPair : l10n.editPair,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildField(
          label: l10n.pairLabel,
          hint: l10n.pairExample,
          controller: _langController,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            if (_editingPair != null)
              TextButton(
                onPressed: _resetPairForm,
                child: Text(l10n.cancelEdit),
              ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: _langController.text.trim().isEmpty
                  ? null
                  : _savePair,
              icon: Icon(
                _editingPair == null ? Icons.add : Icons.check,
                size: 16,
              ),
              label: Text(_editingPair == null ? l10n.add : l10n.saveChanges),
            ),
          ],
        ),
      ],
    );
  }

  void _startPairEdit(String pair) {
    setState(() {
      _editingPair = pair;
      _langController.text = pair;
    });
  }

  void _resetPairForm() {
    setState(() {
      _editingPair = null;
      _langController.clear();
    });
  }

  Future<void> _savePair() async {
    final text = _langController.text.trim();
    if (text.isEmpty) return;
    final editing = _editingPair;
    if (editing != null) {
      await widget.viewModel.updateLanguagePair(editing, text);
    } else {
      await widget.viewModel.addLanguagePair(text);
    }
    if (!mounted) return;
    _resetPairForm();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.pairSaved)));
  }

  /// 提示词管理页签：切换 / 新增 / 编辑 / 删除提示词模板。
  Widget _buildPromptTab(ThemeData theme) {
    final viewModel = widget.viewModel;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          l10n.savedPrompts,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
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
          _editingPromptId == null ? l10n.addPrompt : l10n.editPrompt,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildField(
          label: l10n.optionalName,
          hint: l10n.promptNameExample,
          controller: _promptNameController,
        ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.promptContent,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _promptContentController,
              maxLines: 8,
              minLines: 4,
              // 提示词保存按钮的启用状态依赖内容，输入时需要实时刷新。
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.promptHint,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_editingPromptId != null &&
                PromptTemplate.builtInIds.contains(_editingPromptId!))
              TextButton.icon(
                onPressed: () async {
                  final builtIn = PromptStore.builtInById(_editingPromptId!);
                  if (builtIn == null) return;
                  _promptContentController.text = builtIn.content;
                  _promptNameController.text = builtIn.name;
                  await widget.viewModel.restoreBuiltInPrompt(builtIn.id);
                  _resetPromptForm();
                },
                icon: const Icon(Icons.restore, size: 16),
                label: Text(l10n.resetPrompt),
              ),
            const Spacer(),
            if (_editingPromptId != null)
              TextButton(
                onPressed: _resetPromptForm,
                child: Text(l10n.cancelEdit),
              ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: _promptContentController.text.trim().isEmpty
                  ? null
                  : _savePrompt,
              icon: const Icon(Icons.check, size: 16),
              label: Text(
                _editingPromptId == null
                    ? l10n.saveAndActivate
                    : l10n.saveChanges,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.promptHelp,
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
              _promptName(template),
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
            Text(
              l10n.active,
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
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
            tooltip: l10n.edit,
          ),
          IconButton(
            onPressed: template.isBuiltIn ||
                    viewModel.promptTemplates.length <= 1
                ? null
                : () => _deletePrompt(template),
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: template.isBuiltIn ||
                      viewModel.promptTemplates.length <= 1
                  ? Colors.black26
                  : theme.colorScheme.error,
            ),
            tooltip: template.isBuiltIn
                ? l10n.builtInPromptCannotDelete
                : viewModel.promptTemplates.length <= 1
                    ? l10n.keepOnePrompt
                    : l10n.delete,
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

  String _promptName(PromptTemplate template) {
    // 内置模板若仍使用其默认名称，则展示本地化名称；用户改过名则保留用户命名。
    final builtInName = template.builtInDefaultName;
    if (builtInName != null && template.name == builtInName) {
      if (template.id == PromptTemplate.defaultPromptId) {
        return l10n.wordTranslationPrompt;
      }
      if (template.id == PromptTemplate.sentencePromptId) {
        return l10n.sentenceTranslationPrompt;
      }
    }
    return template.name.trim().isEmpty ? l10n.untitledPrompt : template.name;
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
        ? l10n.untitledPrompt
        : _promptNameController.text.trim();
    await widget.viewModel.savePrompt(
      PromptTemplate(id: id, name: name, content: content),
    );
    if (!mounted) return;
    _resetPromptForm();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.promptSaved)));
  }

  Future<void> _deletePrompt(PromptTemplate template) async {
    final viewModel = widget.viewModel;
    if (viewModel.promptTemplates.length <= 1) return;
    await viewModel.deletePrompt(template.id);
    if (!mounted) return;
    if (_editingPromptId == template.id) _resetPromptForm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.deleted(_promptName(template)))),
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
            Text(
              l10n.active,
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${profile.model} · ${profile.provider == LlmProvider.chatGpt ? l10n.chatGptPlan : profile.baseUrl}',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _busy ? null : () => _startEdit(profile),
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: l10n.edit,
          ),
          IconButton(
            onPressed: _busy ? null : () => _delete(profile),
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: theme.colorScheme.error,
            ),
            tooltip: l10n.delete,
          ),
        ],
      ),
    );
  }

  Widget _buildLogTab(ThemeData theme) {
    final logs = widget.viewModel.logs;
    if (logs.isEmpty) {
      return Center(
        child: Text(l10n.noLogs, style: const TextStyle(color: Colors.black38)),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Text(
              l10n.recentCalls(logs.length),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.viewModel.clearLogs,
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: Text(l10n.clear),
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
      if (log.promptTokens != null) l10n.inputTokens(log.promptTokens!),
      if (log.completionTokens != null)
        l10n.outputTokens(log.completionTokens!),
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
        '${log.success ? '' : ' · ${l10n.failed}'}',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      children: [
        if ((log.systemPrompt ?? '').isNotEmpty) ...[
          Text(
            l10n.prompt,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            log.systemPrompt!,
            style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black54),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.input,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 4),
              SelectableText(
                log.input,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.output,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 4),
              SelectableText(
                log.output,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: log.success ? Colors.black87 : theme.colorScheme.error,
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
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          // 输入时触发重建，让依赖 controller 文本的按钮及时更新启用状态。
          onChanged: (_) => setState(() {}),
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
