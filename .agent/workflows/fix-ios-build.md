---
description: how to fix compile errors and get a successful build on iOS simulator
---

# Fixing Compile Errors & Launching iOS Simulator

## 1. Kill Stale Processes (if builds are locking)

```bash
pkill -f flutter; pkill -f dart; pkill -f xcodebuild
```

## 2. Check Build Errors First (Don't Clean Unless Necessary)

```bash
flutter build ios --simulator 2>&1 | head -100
```

Look for specific errors like:

- `Undefined name` → Missing import
- `Not a constant expression` → Remove `const` from runtime values
- `isn't defined for the type` → Wrong property access

## 3. Fix Errors in Code

- Add missing imports
- Remove `const` from Color values that use runtime variables (like `AelianaColors.hyperGold`)
- Fix wrong property names

## 4. Fast Launch (Turbo Mode - No Clean)

// turbo

```bash
./scripts/fast_run.sh
```

## 5. Nuclear Clean Build (Only If Turbo Fails)

```bash
flutter clean && flutter run -d "iPhone 16 Pro"
```

## 6. If Simulator Not Found

```bash
xcrun simctl boot "iPhone 16 Pro"
open -a Simulator
flutter run -d "iPhone 16 Pro"
```

## Key Lessons

- **Don't flutter clean** unless absolutely necessary (saves 5-10 min)
- **Always boot simulator first** before flutter run
- **Check error output carefully** - most issues are missing imports or const misuse
