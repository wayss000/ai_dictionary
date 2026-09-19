# AI Dictionary · Agent Instructions

This file is the repository-level operating guide for coding agents. Read it before changing code. Keep it short, executable, and current; update it when a recurring mistake or a new project rule appears.

## Project overview

AI Dictionary is a Flutter application for macOS first, with a reusable mobile UI and domain layer. It translates and explains words, phrases, and sentences with a user-selected large language model. The user can choose source/target languages, save multiple model profiles, edit the prompt, and configure caching.

Supported model shapes include OpenAI-compatible HTTP APIs, Ollama, Anthropic, and future custom providers. The app must not depend on a bundled dictionary or a bundled local model.

The repository is intentionally multi-platform:

- macos/: macOS host project and platform integration.
- ios/, android/: mobile host projects kept buildable as shared code evolves.
- lib/: shared Dart application code.
- test/: unit and widget tests.
- .github/workflows/: CI and build artifacts.

## Commands

Run these from the repository root. Do not claim a check passed unless its command completed successfully.

    flutter pub get
    dart format --output=none --set-exit-if-changed lib test
    flutter analyze
    flutter test --reporter expanded
    flutter build macos --release

For a focused test during development:

    flutter test test/path/to_test.dart

Before committing, also run:

    git diff --check
    git status --short

The macOS build requires a macOS runner with the Flutter macOS toolchain. An SSH shell without a GUI can edit and test Dart code, but cannot by itself visually verify a native macOS window.

## Flutter version and dependencies

- Use the Flutter stable channel for development and CI. Do not switch to beta or main without an explicit reason recorded in the change.
- Keep the Dart SDK constraint in pubspec.yaml aligned with the CI Flutter version.
- Prefer Flutter SDK APIs and small, maintained packages. Add a dependency only when it removes meaningful platform or maintenance work.
- After changing pubspec.yaml, run flutter pub get and inspect the diff before committing.
- Do not commit build/, .dart_tool/, secrets, local databases, generated credentials, or personal IDE state.

## Architecture

Use feature-first organization with Flutter's recommended UI/data separation. The default flow is:

    View -> ViewModel -> Repository -> Service / local data source

Use a domain/use-case class only when logic is complex, combines multiple repositories, or is reused. Do not create empty layers for ceremony.

Recommended target structure:

    lib/
    ├── main.dart                         # bootstrap only
    ├── app/
    │   ├── app.dart                       # MaterialApp, theme, routing
    │   └── theme.dart
    ├── core/
    │   ├── errors/
    │   ├── logging/
    │   ├── storage/
    │   └── ui/                            # genuinely shared UI primitives
    ├── features/
    │   ├── dictionary/
    │   │   ├── data/
    │   │   │   ├── dictionary_repository.dart
    │   │   │   └── dictionary_repository_impl.dart
    │   │   ├── domain/
    │   │   │   ├── dictionary_request.dart
    │   │   │   └── dictionary_result.dart
    │   │   └── presentation/
    │   │       ├── dictionary_view.dart
    │   │       ├── dictionary_view_model.dart
    │   │       ├── query_panel.dart
    │   │       └── result_card.dart
    │   ├── language/
    │   ├── model_profiles/
    │   ├── prompts/
    │   ├── cache/
    │   └── history/
    └── services/
        ├── ai/
        │   ├── ai_provider.dart
        │   ├── openai_compatible_provider.dart
        │   ├── ollama_provider.dart
        │   └── anthropic_provider.dart
        └── platform/

Rules:

- main.dart only wires the app and calls runApp; it must not contain screen layout or feature state.
- Views render state and forward user actions. They may contain layout logic and simple show/hide conditions, but no HTTP, storage, cache, prompt construction, or provider selection.
- ViewModels own UI state and commands such as explain, retry, copyResult, and selectLanguage.
- Repositories are the source of truth for application data and own cache, retry, refresh, and error mapping policy.
- Services are stateless adapters for HTTP APIs, local files, Keychain, Ollama, and platform APIs.
- Repository interfaces are abstract so tests can use fakes and development environments can swap implementations.
- Keep platform code out of shared domain code. Use a maintained plugin first; use a platform channel or Pigeon only when native APIs are required. Platform channel messages must remain asynchronous and typed.

## AI provider contract

The dictionary feature depends on an abstraction, never on a vendor SDK directly. The contract should be equivalent to:

    abstract interface class AiProvider {
      Future<DictionaryResult> explain(
        DictionaryRequest request,
        ModelProfile profile,
      );
    }

- Provider adapters own endpoint format, authentication headers, timeout, streaming, response decoding, and provider-specific error mapping.
- Business code receives one normalized DictionaryResult and one normalized error model.
- Ollama must support a configurable base URL; default to http://localhost:11434.
- Model profiles must support multiple saved profiles and one selected default.
- Prefer structured JSON responses. Validate required fields and surface malformed output as a user-readable error.
- Never log API keys, authorization headers, raw prompts containing sensitive user text, or complete provider responses in release mode.
- The request must carry query text, source language, target language, optional context, selected model profile, and the active prompt template.

## Product behavior

- The first release uses a normal application window. Do not add a global hotkey unless explicitly requested.
- The language selector stays in the top-right area and represents source language -> target language. It must support auto-detect and saved language pairs.
- Translation and explanation output follow the selected target language; never hard-code Chinese in domain models or prompt construction.
- The first release supports copy result, retry/re-explain, history, multiple model profiles, editable default prompts, restore-default prompt, and configurable cache behavior.
- Cache and history are separate concerns. Cache is an optimization; history is user-visible data.
- Cache keys must include query, source language, target language, model profile identity, model name, and prompt version.
- Settings that contain keys or tokens must mask values and use secure platform storage. Do not persist secrets in plain JSON or shared preferences.
- Loading, empty, success, partial, and error states must be explicit. Errors need a recovery action where possible.

## Dart and Flutter style

- Run dart format; do not hand-format around it.
- Keep public APIs and serialized models explicitly typed; avoid dynamic outside controlled decoding boundaries.
- Use UpperCamelCase for types, lowerCamelCase for members, and descriptive names such as DictionaryViewModel, DictionaryRepository, and OllamaService.
- Prefer immutable state objects and replace collections rather than mutating shared state.
- Keep widgets small and named. Extract a widget when a section has its own meaning, state, or test target.
- Dispose controllers, focus nodes, streams, timers, and subscriptions owned by a State object.
- Do not perform asynchronous work from build; do not update state after disposal; check mounted where needed.
- Comments explain decisions and constraints, not syntax. Every TODO must state the intended follow-up.
- Use accessible labels/tooltips for icon-only controls and keep keyboard submission paths usable on desktop.

## Testing requirements

Follow the testing pyramid and prefer fakes over real network calls:

- Unit-test every service, repository, and ViewModel method with meaningful logic.
- Widget-test views for initial, loading, empty, success, error, language selection, copy, and retry behavior.
- Test provider request construction, JSON decoding, error mapping, cache keys, and configuration migration.
- Never call a real cloud model or Ollama from tests or CI. Use fake providers and deterministic fixtures.
- A new feature is incomplete until its main success path and failure path are covered.
- If macOS-only behavior changes, run the macOS build on a macOS runner or explicitly report that the local environment could not verify it.

## Security and privacy

- Treat user queries and model responses as potentially sensitive.
- Never commit API keys, tokens, certificates, provisioning profiles, or signed artifacts.
- Use Keychain/secure storage for credentials and provide a way to delete them.
- Avoid sending clipboard text automatically without an explicit user action.
- Do not include sensitive query content in analytics or normal logs.
- Review third-party packages and licenses before adding them; the repository currently contains GPL-3.0 licensing obligations.

## Git and CI workflow

- Keep main buildable.
- Make one focused commit per completed work block.
- Use imperative English commit subjects with a conventional prefix, for example:
  - docs: define agent instructions
  - feat: add dictionary view model
  - test: cover provider response parsing
  - ci: build macos artifact on main
- Do not mix formatting-only churn with a feature unless formatting is required by the change.
- The GitHub Actions workflow must run on pushes and pull requests targeting main, run format/analyze/test, build a macOS Release app on a macOS runner, and upload a zip artifact.
- Do not claim that a GitHub workflow passed unless its run is observable in GitHub Actions.

## Completion checklist

Before reporting completion:

1. Read the relevant existing code and nearest AGENTS.md.
2. Make the smallest coherent change that satisfies the request.
3. Run formatting, analysis, focused tests, and the full relevant test suite.
4. Run git diff --check and inspect git status --short.
5. Review for secrets, accidental generated files, and unrelated changes.
6. Report changed files, checks actually run, known limitations, and the commit hash if a commit was created.

## References

This project guide follows the open AGENTS.md convention and adapts Flutter's current architecture and platform-integration guidance:

- https://www.agentsmd.ai/
- https://docs.flutter.dev/app-architecture/guide
- https://docs.flutter.dev/app-architecture/recommendations
- https://docs.flutter.dev/platform-integration/platform-channels
- https://docs.flutter.dev/install/upgrade
