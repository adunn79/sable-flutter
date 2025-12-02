# Copilot / AI Agent Instructions for Sable (Flutter)

Purpose: quick, actionable guidance so an AI coding agent can be productive immediately in this repository.

- **Project type:** Multi-platform Flutter app (mobile, web, desktop). Root entry: `lib/main.dart`.
- **Key layers:**
  - `lib/src/` — app shell and UI wiring (`lib/src/app.dart`, pages under `lib/src/pages/`).
  - `lib/features/<feature>/` — feature-first organization (e.g. `features/onboarding`, `features/web`).
  - `lib/core/` — cross-cutting systems: theming, AI orchestration, emotion/state, providers (see `lib/core/ai/`).

- **AI & orchestration:** `lib/core/ai/model_orchestrator.dart` is the central router. It delegates to multiple providers under `lib/core/ai/providers/` (Anthropic, Gemini, OpenAI, Grok, DeepSeek). Important: the code enforces a persona (“Aureal”) and strict sanitization (removing AI-disclaimer language, forbidding asterisks/actions). Do not change these persona rules without explicit human approval.

- **Configuration & secrets:** `.env.example` shows required keys; real secrets must be in `.env` (ignored by git). The app loads secrets via `lib/src/config/app_config.dart` using `flutter_dotenv` and expects `AppConfig.initialize()` at startup. See `API_KEYS_SETUP.md` for details.

- **State & DI:** Riverpod (annotations + generated `.g.dart` files) is used widely. Look for `riverpod_annotation` and `part '*.g.dart'` in files — run codegen when making provider/annotation changes.

Developer workflows (explicit commands using the repo-local Flutter):

- Use the bundled SDK to ensure consistent behavior: `./flutter/bin/flutter` (run from repo root).
- Install deps:

```bash
./flutter/bin/flutter pub get
```

- Run the app (pick a device):

```bash
./flutter/bin/flutter run -d <device-id>
```

- Run tests:

```bash
./flutter/bin/flutter test
```

- Generate Riverpod/build_runner artifacts:

```bash
./flutter/bin/flutter pub run build_runner build --delete-conflicting-outputs
```

- Build for web (example):

```bash
./flutter/bin/flutter build web --release -t lib/main.dart
```

- For iOS native debugging, open `ios/Runner.xcworkspace` in Xcode.

Project-specific conventions & patterns (concrete examples):

- Feature-first layout: add new feature code under `lib/features/<feature>/` and keep UI pages in `lib/src/pages`.
- AI providers: add or modify provider implementations under `lib/core/ai/providers/`. Providers should implement `AiProviderInterface` (see `lib/core/ai/providers/anthropic_provider.dart`).
- Persona & sanitization: any text-generation path ultimately goes through `ModelOrchestrator` which performs multi-model routing, failover, and sanitization. See the hard rules and regeneration logic in `lib/core/ai/model_orchestrator.dart` — respect them when changing prompts or system injections.
- Environment keys: update `.env.example` and instruct humans to `cp .env.example .env` and fill values. The app checks `AppConfig.isConfigured` and will behave differently if keys are missing.
- Generated files: maintain `*.g.dart` artifacts via `build_runner` — do not hand-edit generated files.

Integration points & external dependencies to be aware of:

- External APIs require keys in `.env`: OpenAI, Anthropic, Google/Gemini, Mapbox, Pinecone, Fal, etc. See `.env.example` and `API_KEYS_SETUP.md`.
- Network clients use `package:http` and `flutter_dotenv` for keys. Providers call external HTTP APIs directly (see `lib/core/ai/providers/*`).
- Web grounding: web searches and grounding are performed through the Gemini provider (`generateResponseWithGrounding`), used by `lib/features/web/services/web_search_service.dart`.

When editing or adding AI prompts:

- Prefer adding system prompts where the orchestrator expects them or creating new provider methods — avoid inlining broad persona overwrites in many places.
- Any change that affects the persona rules or sanitization must be reviewed by a human; the orchestrator contains non-obvious failover and regeneration behavior (see `orchestratedRequest`).

Quick file references (start here):

- App entry: `lib/main.dart`
- App shell: `lib/src/app.dart`
- Model orchestrator: `lib/core/ai/model_orchestrator.dart`
- AI providers: `lib/core/ai/providers/`
- Config loader: `lib/src/config/app_config.dart`
- API keys instructions: `API_KEYS_SETUP.md` and `.env.example`
- Scripts: `scripts/reset_app_data.dart`

If you need to make changes that touch build, native, or API key handling, prompt a human for approval and run the above commands locally. Ask if you should commit changes or open a PR.

Feedback request: Is there any section you want expanded (build matrix, CI steps, or localization rules)? Reply and I will iterate.
