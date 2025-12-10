---
description: How to hot restart the Flutter app in the iOS simulator
---

# Hot Restart Workflow

When the user asks for a hot restart, follow these steps:

## CRITICAL: You MUST Have a Running Flutter Process

Hot restart ONLY works if `flutter run` is already running in the background. You cannot hot restart a dead/exited process.

---

## Step 1: Check for Running Flutter Process

First, check if there's an active `flutter run` command by looking at recent command IDs in the conversation. If a previous `flutter run` command exited (status: DONE with exit code), you need to start a fresh one.

---

## Step 2A: If Flutter is NOT Running - Start It

// turbo

```bash
flutter devices
```

Get the device ID (e.g., `13D17C50-32C8-4301-9A0F-FF0389AD40BD` for iPhone 17 simulator), then:

```bash
flutter run -d <DEVICE_ID>
```

Wait for the app to launch and the Flutter run key commands to appear. Save the **Background command ID** - you'll need it.

---

## Step 2B: If Flutter IS Running - Send Hot Restart

Use the `send_command_input` tool (NOT a shell command!) with:

- **CommandId**: The background command ID from the original `flutter run`
- **Input**: `R\n` (capital R followed by newline)
- **SafeToAutoRun**: true
- **WaitMs**: 3000

Example tool call:

```
send_command_input(
  CommandId: "82298843-c7e2-43cf-99cc-92ea5223acfd",
  Input: "R\n",
  SafeToAutoRun: true,
  WaitMs: 3000
)
```

---

## Common Mistakes to AVOID

1. **DO NOT** try to run `send_command_input` as a shell command - it's a TOOL, not a CLI command
2. **DO NOT** try to hot restart a process that has exited (status: DONE)
3. **DO NOT** use SIGUSR2 signals - they don't work for Flutter hot restart
4. **DO NOT** use lowercase `r` - that's hot reload, not hot restart. Use capital `R`

---

## Quick Reference

| Scenario | Action |
|----------|--------|
| `flutter run` is running | Use `send_command_input` with `R\n` |
| `flutter run` exited | Run `flutter run -d <DEVICE_ID>` again |
| Build errors | Fix errors first, then run `flutter run` |
| Need device ID | Run `flutter devices` first |

---

## Verification

After hot restart, you should see in the output:

```
Performing hot restart...
Restarted application in XXXms.
```

If you see this, the hot restart was successful!
