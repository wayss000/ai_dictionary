# AI Dictionary 项目规范

## 1. 项目目标

AI Dictionary 是一个以大模型为核心的多语言词典与语义解释应用。用户输入单词、短语或句子后，可以选择输入语言、目标语言和模型配置，获得翻译、语境解释、词性、例句以及必要的说明。

第一期目标平台是 macOS，业务层和界面层必须保持移动端可复用。应用不依赖内置词库，也不把某一种云模型写死在业务代码中；云端模型、本地 Ollama 和 OpenAI-compatible 服务都属于正式支持范围。

## 2. 技术边界

- 使用 Flutter/Dart；平台特有能力通过 Flutter plugin、platform channel 或独立 platform adapter 隔离。
- 共享业务代码放在 `lib/`；macOS 特有代码放在 `macos/` 或 `lib/platform/macos/`；移动端特有代码不得渗透到共享 domain 层。
- AI Provider 必须通过抽象接口接入，业务层不得直接依赖某个厂商 SDK 或 HTTP endpoint。
- 模型配置、语言配置、提示词配置、缓存策略和历史记录都必须是数据驱动的，不能散落在 Widget 中。
- API Key 等敏感信息只能通过安全存储；不得提交到 Git、日志、测试快照或错误消息。
- 应用不内置大模型、语音模型或大型词库；允许使用正常的 Flutter 第三方依赖，发布包目标为几十 MB 到 100 MB 以内。

## 3. 分层结构

推荐依赖方向：

```text
presentation -> application/controller -> domain -> data/services
```

- `presentation`：页面、组件、状态展示和用户交互；不得直接发 HTTP 请求。
- `application`：用例、控制器、加载/错误/成功状态和跨页面编排。
- `domain`：请求、结果、模型配置、语言配置等纯 Dart 模型和接口；不得依赖 Flutter UI。
- `data/services`：Provider 实现、本地存储、缓存、历史记录和平台适配。
- `core`：错误类型、日志、常量、序列化和通用工具；避免变成无边界的工具箱。

## 4. Dart 与 Flutter 规范

- 遵守 `dart format` 和 `flutter analyze`；提交前必须运行它们。
- 类型优先：公共 API、Provider、状态对象和序列化模型必须声明明确类型。
- 类名使用 `UpperCamelCase`，变量/方法使用 `lowerCamelCase`，常量使用 `lowerCamelCase` 或项目既有 lint 推荐形式。
- Widget 保持小而专一；复杂页面拆成有名字的组件，不在 `build` 中堆积业务逻辑。
- 异步操作必须有 loading、success、empty 和 error 状态；禁止吞掉异常。
- 用户可见文案集中管理或至少避免散落在底层服务中。默认面向中文用户，但界面和模型输出不得假设只能使用中文。
- 优先使用不可变数据对象；修改状态时创建新值，不直接修改共享集合。
- 注释解释“为什么”，不要重复代码本身；TODO 必须包含明确的后续意图。

## 5. AI Provider 约束

所有 Provider 都应实现统一能力：

```dart
abstract class AiProvider {
  Future<DictionaryResult> explain(
    DictionaryRequest request,
    ModelProfile profile,
  );
}
```

- Provider 负责协议、鉴权、超时、响应解析和 Provider-specific 错误映射。
- 上层只处理统一的 `DictionaryResult` 和统一错误类型。
- 支持 OpenAI-compatible、Ollama、Anthropic 和未来的自定义 HTTP Provider。
- Ollama 默认地址为 `http://localhost:11434`，但必须允许用户修改。
- 模型输出优先使用结构化 JSON；解析失败时要给出可理解的错误，必要时允许安全的文本降级展示。
- 请求必须携带输入语言、目标语言、查询内容、上下文（如果有）和当前提示词模板。
- 不记录完整 API Key；日志中的模型请求只允许在显式 debug 模式下输出，并且要脱敏。

## 6. 配置与数据约束

- 一个用户可以保存多个 `ModelProfile`，并指定一个默认配置。
- 语言组合、模型配置和提示词配置都有稳定 ID；不要用展示名称作为唯一标识。
- 默认提示词必须可恢复；用户修改后要能明确区分默认值和自定义值。
- 缓存开关必须可配置。缓存 key 至少包含查询内容、输入语言、目标语言、模型配置 ID、模型名称和提示词版本。
- 缓存与历史记录是两个概念：缓存服务性能，历史服务用户查看和管理。
- 设置页面的敏感字段默认隐藏；清空缓存、清空历史等操作必须有明确反馈。

## 7. macOS 与移动端交互约束

- 第一版使用普通应用窗口，不要求全局快捷键。
- 菜单栏、窗口管理、系统服务等 macOS 能力只能通过平台层接入，不能让 domain 层知道 macOS API。
- 移动端预留分享入口和剪贴板入口，但不为了抽象而提前加入平台无关的复杂层。
- 语言切换器位于主界面右上角，显示“输入语言 → 输出语言”，支持自动识别和保存常用语言组合。
- 查询页面必须支持输入、加载、结果、空状态和错误状态。
- 查询结果至少支持复制和重新解释；操作反馈不能只依赖日志。

## 8. 测试与质量门槛

- domain 模型、Provider 请求构造、JSON 解析、缓存 key 和配置迁移优先写单元测试。
- Widget 测试覆盖语言切换、加载状态、错误状态和结果操作。
- 测试不得调用真实云模型；使用 mock/fake Provider。
- 每个功能块完成后运行格式化、静态分析和相关测试。
- macOS 构建需要在具备 macOS Flutter 工具链的机器上验证；Linux/SSH 环境不能假定可以完成原生 macOS 构建。

## 9. Git 与交付规范

- `main` 保持可构建；每个完整功能块单独提交。
- Commit 使用简短英文动词开头，例如 `docs: add project conventions`、`feat: add dictionary domain models`、`ci: add macos build workflow`。
- 不把临时文件、密钥、构建目录、IDE 配置和本地数据库提交到仓库。
- GitHub Actions 至少验证格式、分析、测试，并在 macOS runner 上构建 main 分支产物。
- CI 产物应上传为 workflow artifact；签名、公证和发布暂不假设已经配置证书。
