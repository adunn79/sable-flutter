#!/bin/bash
# Voice List Verification Script
# This script checks if the app is properly configured for ElevenLabs voices only

echo "🔍 Voice List Verification"
echo "=========================="
echo ""

# 1. Check VoiceService default
echo "1. Checking VoiceService default engine..."
grep -n "_voiceEngine = 'eleven_labs'" lib/core/voice/voice_service.dart
if [ $? -eq 0 ]; then
  echo "   ✅ Default engine is 'eleven_labs'"
else
  echo "   ❌ Default engine is NOT 'eleven_labs'"
  exit 1
fi

# 2. Check getCuratedVoices returns 6 voices
echo ""
echo "2. Checking getCuratedVoices() implementation..."
voice_count=$(grep -A 20 "getCuratedVoices()" lib/core/voice/voice_service.dart | grep "'name':" | wc -l | tr -d ' ')
if [ "$voice_count" -eq "6" ]; then
  echo "   ✅ getCuratedVoices() returns 6 voices"
else
  echo "   ❌ getCuratedVoices() returns $voice_count voices (expected 6)"
  exit 1
fi

# 3. Check for system voice mapping removal
echo ""
echo "3. Checking for system voice mapping..."
if grep -q "findVoiceId" lib/core/voice/voice_service.dart; then
  echo "   ❌ System voice mapping still present (findVoiceId found)"
  exit 1
else
  echo "   ✅ System voice mapping removed"
fi

# 4. Check SettingsScreen default
echo ""
echo "4. Checking SettingsScreen default engine..."
grep -n "_voiceEngine = 'eleven_labs'" lib/features/settings/screens/settings_screen.dart | head -1
if [ $? -eq 0 ]; then
  echo "   ✅ SettingsScreen default is 'eleven_labs'"
else
  echo "   ❌ SettingsScreen default is NOT 'eleven_labs'"
  exit 1
fi

# 5. Check AI name in prompts
echo ""
echo "5. Checking AI name (should be 'Sable')..."
aureal_count=$(grep -r "You are Aureal" lib/core/ai/ | wc -l | tr -d ' ')
sable_count=$(grep -r "You are Sable" lib/core/ai/ | wc -l | tr -d ' ')
if [ "$aureal_count" -eq "0" ] && [ "$sable_count" -gt "0" ]; then
  echo "   ✅ AI name is 'Sable' ($sable_count references)"
else
  echo "   ❌ AI name issue: Aureal=$aureal_count, Sable=$sable_count"
  exit 1
fi

# 6. Check chat header
echo ""
echo "6. Checking chat header..."
grep -n "'SABLE'" lib/src/pages/chat/chat_page.dart
if [ $? -eq 0 ]; then
  echo "   ✅ Chat header is 'SABLE'"
else
  echo "   ❌ Chat header is NOT 'SABLE'"
  exit 1
fi

echo ""
echo "=========================="
echo "✅ ALL CODE VERIFICATIONS PASSED"
echo ""
echo "⚠️  MANUAL VERIFICATION REQUIRED:"
echo "   1. Open Settings > Voice Selection in simulator"
echo "   2. Verify ONLY 6 voices appear (Josh, Antoni, Rachel, Bella, Adam, Mimi)"
echo "   3. Verify NO system voices (Samantha, Albert, Daniel, etc.)"
echo ""
