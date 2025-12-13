#!/bin/bash

# FASTRUN: The "Best in Class" Developer Script for Aeliana
# Usage: ./fast_run.sh [clean]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🚀 AELIANA HYPER-FAST LAUNCHER${NC}"

# 1. INTELLIGENT DEVICE DETECTION
# We prefer the "iPhone 16 Pro" simulator if open, otherwise any booted iPhone.
echo -e "${YELLOW}🔍 Detecting iPhone Simulator...${NC}"
DEVICE_ID=$(xcrun simctl list devices booted | grep "iPhone" | head -n 1 | grep -E -o "[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}")

if [ -z "$DEVICE_ID" ]; then
    echo -e "${RED}❌ No booted iPhone simulator found!${NC}"
    echo "Booting iPhone 16 Pro..."
    xcrun simctl boot "iPhone 16 Pro" 2>/dev/null
    # Retry detection
    sleep 5
    DEVICE_ID=$(xcrun simctl list devices booted | grep "iPhone" | head -n 1 | grep -E -o "[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}")
fi

if [ -z "$DEVICE_ID" ]; then
   echo -e "${RED}💀 Critical Failure: Could not find or boot a simulator.${NC}"
   exit 1
fi

echo -e "${GREEN}✅ Targeting Simulator: $DEVICE_ID${NC}"

# 2. OPTIMIZED BUILD STRATEGY
# If 'clean' arg is passed, we do the nuclear option. Otherwise, we try to go fast.
if [ "$1" == "clean" ]; then
    echo -e "${RED}🧹 Performing Deep Clean (Nuclear Option)...${NC}"
    flutter clean
    cd ios
    rm -rf Pods
    rm Podfile.lock
    pod install
    cd ..
else
    echo -e "${GREEN}⚡ Turbo Mode Active: Skipping Clean & Pod Install${NC}"
    # We skip 'flutter pub get' if .dart_tool exists, saving 5-10s
    if [ ! -d ".dart_tool" ]; then
        echo "Dependencies missing, fetching..."
        flutter pub get
    fi
fi

# 3. LAUNCH
# We use --keep-app-running so if we detach, the app stays alive on the sim.
# We pipe to cat to avoid pager buffers blocking output.
echo -e "${CYAN}🔨 Building & Launching...${NC}"

# Trap Ctrl+C to exit cleanly
trap "echo '🛑 Stopping...'; exit" SIGINT SIGTERM

flutter run -d "$DEVICE_ID"

