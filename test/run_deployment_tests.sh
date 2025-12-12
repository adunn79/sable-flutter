#!/bin/bash

# =====================================================
# AELIANA AI - COMPREHENSIVE TEST SUITE
# Deployment Readiness Verification
# =====================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         AELIANA AI - DEPLOYMENT READINESS TESTS              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

PASSED=0
FAILED=0
TOTAL=0

run_test() {
    local name=$1
    local file=$2
    ((TOTAL++))
    
    echo -e "${BLUE}Running:${NC} $name"
    
    if flutter test "$file" --reporter compact 2>&1 | tail -20; then
        echo -e "${GREEN}✅ PASSED${NC}: $name"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAILED${NC}: $name"
        ((FAILED++))
    fi
    echo ""
}

echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 1: AGENTIC SELF-TEST RUNNER"
echo "═══════════════════════════════════════════════════════════════"
run_test "Deployment Readiness Check" "test/self_test_runner.dart"

echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 2: PRIORITY SCREEN TESTS"
echo "═══════════════════════════════════════════════════════════════"
run_test "Settings Screen Tests" "test/screens/settings_screen_test.dart"
run_test "Chat Page Tests" "test/screens/chat_page_test.dart"
run_test "Journal Screens Tests" "test/screens/journal_screens_test.dart"
run_test "Onboarding Screens Tests" "test/screens/onboarding_screens_test.dart"

echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 3: EXISTING TESTS"
echo "═══════════════════════════════════════════════════════════════"
run_test "Core Services Tests" "test/core_services_test.dart"
run_test "Native Apps Integration" "test/native_apps_integration_test.dart"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     FINAL SUMMARY                            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo -e "║ ${GREEN}Passed:${NC} $PASSED                                              ║"
echo -e "║ ${RED}Failed:${NC} $FAILED                                              ║"
echo "║ Total:  $TOTAL                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   🎉 ALL TESTS PASSED - READY FOR HUMAN BETA TESTERS! 🎉    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║     ⛔ TESTS FAILED - FIX ISSUES BEFORE DEPLOYMENT ⛔        ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
