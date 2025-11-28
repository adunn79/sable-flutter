# API Keys Security Setup

## Overview

All API keys have been securely stored in the Flutter project with the following measures:

### Files Created

1. **`.env`** - Contains all actual API keys (excluded from version control)
2. **`.env.example`** - Template file showing required keys (safe to commit)
3. **`lib/src/config/app_config.dart`** - Configuration loader for accessing keys in code

### Security Measures

- ✅ `.env` file added to `.gitignore` to prevent accidental commits
- ✅ `flutter_dotenv` package installed for secure environment variable loading
- ✅ Keys loaded at app startup via `AppConfig.initialize()`
- ✅ Example template provided for team members

### API Keys Stored

- **OpenAI** (The Arbiter) - `AppConfig.openAiKey`
- **Anthropic/Claude** (The Soul) - `AppConfig.anthropicKey`
- **Google/Gemini** (The Agent) - `AppConfig.googleKey`
- **Google Maps & Weather** - `AppConfig.googleMapsKey`
- **Mapbox SDK** - `AppConfig.mapboxKey`
- **Fal Image Generation** - `AppConfig.falKey`
- **Pinecone** - `AppConfig.pineconeKey`

### Usage in Code

```dart
import 'package:sable/src/config/app_config.dart';

// Access API keys
final openAiKey = AppConfig.openAiKey;
final claudeKey = AppConfig.anthropicKey;
```

### Important Notes

- ⚠️ **Never commit the `.env` file** - It's in `.gitignore` for safety
- ✅ The `.env.example` file can be safely committed as a template
- 🔒 All keys are loaded securely at runtime from the `.env` file
