---
description: How to hot restart the Flutter app in the iOS simulator
---

# Hot Restart Workflow

When the user asks for a hot restart, follow these steps:

## Step 1: Find the Device ID

// turbo

```bash
flutter devices
```

Look for the iOS Simulator device ID (e.g., `13D17C50-32C8-4301-9A0F-FF0389AD40BD`).

## Step 2: Launch Flutter Run

```bash
flutter run -d <DEVICE_ID>
```

Example with the iPhone 17 simulator:

```bash
flutter run -d 13D17C50-32C8-4301-9A0F-FF0389AD40BD
```

**Important Notes:**

- This will compile and launch the app fresh
- Wait for "Syncing files to device..." to confirm success
- The command stays running in background - you can send 'R' to it for subsequent hot restarts
- If there are compile errors, they will appear in the output - fix them first

## Alternative: If Flutter Run is Already Running

If you have the background command ID from a previous `flutter run`:

```bash
# Send 'R' character to trigger hot restart
send_command_input with Input: "R\n"
```

## Common Issues

- **SIGUSR2 signal does NOT work** for Flutter hot restart
- Must use the actual `flutter run` command or send 'R' to an existing session
