#!/bin/bash

# Comprehensive test runner for Sable Flutter app
# Validates all features work without crashes

echo "🧪 Running Sable Flutter Test Suite..."
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
PASSED=0
FAILED=0

# Function to run test and track results
run_test() {
    local test_name=$1
    local test_file=$2
    
    echo ""
    echo "📋 Running: $test_name"
    echo "----------------------------------------"
    
    if flutter test "$test_file"; then
        echo -e "${GREEN}✅ PASSED${NC}: $test_name"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAILED${NC}: $test_name"
        ((FAILED++))
    fi
}

# Run all test suites
run_test "Native Apps Integration Tests" "test/native_apps_integration_test.dart"
run_test "Settings Screen Widget Tests" "test/settings_screen_widget_test.dart"
run_test "Core Services Tests" "test/core_services_test.dart"

# Summary
echo ""
echo "========================================"
echo "📊 TEST SUMMARY"
echo "========================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "Total: $((PASSED + FAILED))"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  Some tests failed. Please review above.${NC}"
    exit 1
fi
