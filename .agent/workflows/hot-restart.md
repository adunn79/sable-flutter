# Hot Restart & Build Workflow

## 🛑 EXPERT WARNING: Xcode 26.2 SDK Issue

**Do not attempt to run `flutter run` or `xcodebuild` from the terminal for iOS Simulators on this machine.**

### Diagnosis

- The installed Xcode SDK is **26.2**.
- The installed Simulators are **iOS 18.6** (and 26.0/26.1).
- The **iOS 26.2 Simulator Runtime** is MISSING.
- `xcodebuild` (CLI) strictly enforces that the SDK version (26.2) must match the Runtime version. It rejects target iOS 18.6 as "Ineligible" or "Unable to find destination".

### Solution

- **ALWAYS use the Xcode GUI** to run the app on simulators.
  - Open `ios/Runner.xcworkspace`.
  - Select "iPhone 16 Pro" (or desired sim).
  - Click the **Play** button.
- Verification via CLI is impossible until the iOS 26.2 Runtime is installed via Xcode > Settings > Components.

---

## Standard Workflow (If Environment Fixed)

1. **Boot Simulator**

    ```bash
    xcrun simctl boot <DEVICE_UUID>
    ```

2. **Run Flutter App**

    ```bash
    flutter run -d <DEVICE_UUID>
    ```

3. **Hot Restart**
    - Ensure the app is running in the terminal.
    - Call the `send_command_input` tool with `R\n` (newline is critical).
    - **Do NOT** try to type `R` into a shell command. It must be sent to the running process.

## Troubleshooting

- **"iOS 26.2 is not installed":** You are missing the runtime component. Install it or use Xcode GUI.
- **"Device locked":** Simulator needs to be unlocked or is in a bad state. Reboot it.
- **Crash on Start:** Check `deploy-ipad.md` - known issue with debug builds on iOS 26 devices (use release build for physical devices).
