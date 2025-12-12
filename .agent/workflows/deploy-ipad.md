---
description: How to build and deploy Aeliana to Andrew's iPad
---

# Deploy to Andrew's iPad

// turbo-all

## Prerequisites

- Andrew's iPad must be connected (USB preferred for iOS 26+)
- Run `flutter devices` to confirm iPad is visible (device ID: `00008120-001844E40A800032`)

## Steps

1. Clean previous build artifacts

```bash
flutter clean
```

2. Get Flutter dependencies

```bash
flutter pub get
```

3. Install iOS CocoaPods (optional but recommended after clean)

```bash
cd ios && pod install --repo-update && cd ..
```

4. Build and install RELEASE version to iPad

```bash
flutter build ios --release && flutter install -d 00008120-001844E40A800032
```

> **⚠️ iOS 26 Note:** Debug builds crash after ~30 seconds on iOS 26 iPads. Always use release builds for stable deployment.

## Quick Deploy (release - recommended)

```bash
flutter build ios --release && flutter install -d 00008120-001844E40A800032
```

## Debug Deploy (USB required, may crash on iOS 26)

If you need hot reload or debugging, connect iPad via USB:

```bash
flutter run -d 00008120-001844E40A800032 --debug
```

## Troubleshooting

- **Crash after 30s (debug mode)**: Use release build instead
- **mDNS errors**: Disable Personal Hotspot on iPad, ensure Local Network permission is granted
- **Wireless slow/crashing**: Connect iPad via USB for deployment
- **Build errors**: Run `flutter clean` then retry
