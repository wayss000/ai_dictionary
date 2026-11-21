import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.locale);

  static const simplifiedChinese = Locale('zh', 'CN');
  static const english = Locale('en');

  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context));

  final Locale locale;

  bool get isEnglish => locale.languageCode == 'en';

  String _choose(String chinese, String english) =>
      isEnglish ? english : chinese;

  String get settings => _choose('设置', 'Settings');
  String get close => _choose('关闭', 'Close');
  String get modelSettings => _choose('模型配置', 'Models');
  String get callLogs => _choose('调用日志', 'Call logs');
  String get languagePairs => _choose('语言组合', 'Language pairs');
  String get promptManagement => _choose('提示词管理', 'Prompts');
  String get interfaceLanguage => _choose('界面语言', 'App language');
  String get savedModels =>
      _choose('已保存的模型（点选切换生效）', 'Saved models (select one to activate it)');
  String get noModels =>
      _choose('还没有配置，在下方新增一个模型配置。', 'No models configured. Add one below.');
  String get addModel => _choose('新增模型配置', 'Add model configuration');
  String get editModel => _choose('编辑模型配置', 'Edit model configuration');
  String get customModel => _choose('自定义模型', 'Custom model');
  String get signIn => _choose('登录 ChatGPT', 'Sign in to ChatGPT');
  String get optionalName => _choose('名称（选填）', 'Name (optional)');
  String get modelNameExample =>
      _choose('例如 智谱 / 硅基流动', 'e.g. OpenAI / SiliconFlow');
  String get apiUrl => _choose('API 地址', 'API URL');
  String get apiUrlExample =>
      _choose('例如 https://api.openai.com/v1', 'e.g. https://api.openai.com/v1');
  String get show => _choose('显示', 'Show');
  String get hide => _choose('隐藏', 'Hide');
  String get modelName => _choose('模型名称', 'Model name');
  String get modelExample => _choose(
    '例如 glm-4-flash、Qwen/Qwen3.5-4B',
    'e.g. glm-4-flash or Qwen/Qwen3.5-4B',
  );
  String get continueWithChatGpt =>
      _choose('使用 ChatGPT 继续', 'Continue with ChatGPT');
  String get signInAgain => _choose('重新登录 ChatGPT', 'Sign in to ChatGPT again');
  String get reloadModels => _choose('重新加载模型', 'Reload models');
  String get waitingForSignIn =>
      _choose('正在等待 ChatGPT 登录…', 'Waiting for ChatGPT sign-in…');
  String get loadingModels =>
      _choose('正在加载 ChatGPT 模型…', 'Loading ChatGPT models…');
  String get cancelSignIn => _choose('取消登录', 'Cancel sign-in');
  String get signInHelp => _choose(
    '登录并授权套餐用量后，可选择账号可用的模型。',
    'Sign in and authorize plan usage to choose from your available models.',
  );
  String get signedInHelp => _choose(
    '已登录 ChatGPT。加载模型后即可选择。',
    'Signed in to ChatGPT. Load models to choose one.',
  );
  String get chatGptModel => _choose('ChatGPT 模型', 'ChatGPT model');
  String get timeout => _choose('超时时间（秒）', 'Timeout (seconds)');
  String get timeoutHint => _choose('默认 60，最小 5', 'Default: 60. Minimum: 5.');
  String get testConnection => _choose('测试连接', 'Test connection');
  String get cancelEdit => _choose('取消编辑', 'Cancel editing');
  String get saveAndActivate => _choose('保存并生效', 'Save and activate');
  String get saveChanges => _choose('保存修改', 'Save changes');
  String get planUsage => _choose(
    '使用当前 ChatGPT 账号的套餐用量。',
    'Uses your current ChatGPT plan allowance.',
  );
  String get apiKeyHelp => _choose(
    'API Key 保存在本机，用于请求所配置的服务。',
    'Your API key is stored on this device and used to call the configured service.',
  );
  String get savedPairs => _choose(
    '已保存的语言组合（点选切换生效）',
    'Saved language pairs (select one to activate it)',
  );
  String get active => _choose('生效中', 'Active');
  String get keepOnePair =>
      _choose('至少保留一个组合', 'Keep at least one language pair');
  String get delete => _choose('删除', 'Delete');
  String get addPair => _choose('新增语言组合', 'Add language pair');
  String get editPair => _choose('编辑语言组合', 'Edit language pair');
  String get pairLabel =>
      _choose('语言组合（输入语言 → 输出语言）', 'Language pair (source → target)');
  String get pairExample => _choose('例如 法语 → 中文', 'e.g. French → Chinese');
  String get add => _choose('添加', 'Add');
  String get savedPrompts => _choose(
    '已保存的提示词模板（点选切换生效）',
    'Saved prompt templates (select one to activate it)',
  );
  String get addPrompt => _choose('新增提示词模板', 'Add prompt template');
  String get editPrompt => _choose('编辑提示词模板', 'Edit prompt template');
  String get promptNameExample =>
      _choose('例如 简短词典 / 详细解释', 'e.g. Short definition / Detailed explanation');
  String get promptContent => _choose('提示词内容', 'Prompt content');
  String get promptHint => _choose(
    '支持 {word}（用户输入的单词）和 {language}（语言方向）占位符',
    'Supports {word} (user input) and {language} (translation direction).',
  );
  String get resetPrompt => _choose('恢复默认内容', 'Restore default content');
  String get promptHelp => _choose(
    '提示词会与用户输入的单词结合（替换 {word} / {language} 占位符）后，统一发送给当前生效的模型。',
    'The app fills in {word} and {language}, then sends the prompt to the active model.',
  );
  String get untitledPrompt => _choose('未命名模板', 'Untitled template');
  String get keepOnePrompt => _choose('至少保留一个模板', 'Keep at least one template');
  String get edit => _choose('编辑', 'Edit');
  String get promptSaved => _choose('提示词已保存并生效', 'Prompt saved and activated');
  String get pairSaved => _choose('语言组合已保存', 'Language pair saved');
  String get chatGptPlan => _choose('ChatGPT 套餐', 'ChatGPT plan');
  String get noLogs => _choose(
    '暂无调用记录，去解释几个词吧。',
    'No calls yet. Translate something to get started.',
  );
  String get clear => _choose('清空', 'Clear');
  String get failed => _choose('失败', 'Failed');
  String get prompt => _choose('提示词', 'Prompt');
  String get input => _choose('输入', 'Input');
  String get output => _choose('输出', 'Output');
  String get finishSignIn =>
      _choose('完成 ChatGPT 登录', 'Finishing ChatGPT sign-in');
  String get loadModels => _choose('加载 ChatGPT 模型', 'Loading ChatGPT models');
  String get noAvailableModels => _choose(
    '这个 ChatGPT 账号没有可用的模型。',
    'This ChatGPT account has no available models.',
  );
  String get connectionSucceeded =>
      _choose('连接成功，配置可用。', 'Connection successful.');
  String get savedAndActive => _choose('已保存并生效', 'Saved and activated');
  String get selectPair => _choose('选择语言组合', 'Select language pair');
  String get pairDirection => _choose('输入语言 → 输出语言', 'Source → target');
  String get managePairs => _choose('管理语言组合', 'Manage language pairs');
  String get managePairsHelp =>
      _choose('在设置中添加、删除或切换', 'Add, delete, or switch pairs in Settings');
  String get requestFailed =>
      _choose('请求失败，请重试。', 'Request failed. Try again.');
  String get context => _choose('当前语境', 'In context');
  String get partOfSpeech => _choose('词性', 'Part of speech');
  String get examples => _choose('例句', 'Examples');
  String get explanationFailed => _choose('解释失败', 'Translation failed');
  String get retry => _choose('重试', 'Retry');
  String get copyResult => _choose('复制结果', 'Copy result');
  String get translateAgain => _choose('重新解释', 'Translate again');
  String get sourceText => _choose('原文', 'Source text');
  String get queryHint =>
      _choose('输入单词、短语或句子', 'Enter a word, phrase, or sentence');
  String get queryShortcut => _choose(
    'Enter 翻译 · Shift + Enter 换行',
    'Enter to translate · Shift + Enter for a new line',
  );
  String get translating => _choose('翻译中', 'Translating');
  String get translate => _choose('翻译', 'Translate');
  String get copied => _choose('结果已复制', 'Result copied');
  String get defaultModel => _choose('默认模型', 'Default model');
  String get autoToChinese => _choose('自动识别 → 中文', 'Auto-detect → Chinese');
  String get englishToChinese => _choose('英语 → 中文', 'English → Chinese');
  String get chineseToEnglish => _choose('中文 → 英语', 'Chinese → English');
  String get japaneseToChinese => _choose('日语 → 中文', 'Japanese → Chinese');
  String get koreanToEnglish => _choose('韩语 → 英语', 'Korean → English');
  String get languageSaveFailed =>
      _choose('无法保存界面语言。', 'Could not save the app language.');

  String get defaultPromptName =>
      _choose('默认词典提示词', 'Default dictionary prompt');

  String pairName(String pair) => switch (pair) {
    '自动识别 → 中文' => autoToChinese,
    '英语 → 中文' => englishToChinese,
    '中文 → 英语' => chineseToEnglish,
    '日语 → 中文' => japaneseToChinese,
    '韩语 → 英语' => koreanToEnglish,
    _ => pair,
  };

  String deleted(String name) => _choose('已删除 $name', 'Deleted $name');
  String stageFailed(String stage, String error) =>
      _choose('$stage 失败。$error', '$stage failed. $error');
  String recentCalls(int count) =>
      _choose('最近 $count 次调用', 'Recent calls ($count)');
  String inputTokens(int count) => _choose('输入 $count tok', '$count input tok');
  String outputTokens(int count) =>
      _choose('输出 $count tok', '$count output tok');
  String resultAttribution(String model) => _choose(
    '由 $model 生成，AI 解释可能存在偏差，请结合上下文判断。',
    'Generated by $model. AI explanations can be inaccurate. Check the context.',
  );
}
