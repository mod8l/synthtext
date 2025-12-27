#!/bin/bash

# AutoMarket OS - Comprehensive Test Runner
# Runs unit tests, integration tests, and performance benchmarks

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TEST_TYPE="${1:-all}"
COVERAGE=false
VERBOSE=false
WATCH=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --coverage)
      COVERAGE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --watch)
      WATCH=true
      shift
      ;;
    *)
      TEST_TYPE="$1"
      shift
      ;;
  esac
done

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║  AutoMarket OS - Test Runner           ║"
echo "║  Version 1.0                           ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Function to run tests
run_unit_tests() {
  echo -e "${YELLOW}Running Unit Tests...${NC}"

  if [ "$WATCH" = true ]; then
    npm run test:unit -- --watch
  elif [ "$VERBOSE" = true ]; then
    npm run test:unit -- --verbose
  else
    npm run test:unit
  fi

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Unit tests passed${NC}"
  else
    echo -e "${RED}✗ Unit tests failed${NC}"
    exit 1
  fi
}

run_integration_tests() {
  echo -e "${YELLOW}Running Integration Tests...${NC}"

  # Check if database is available
  if ! command -v psql &> /dev/null; then
    echo -e "${RED}✗ PostgreSQL client not found${NC}"
    echo "Install PostgreSQL client to run integration tests"
    return 1
  fi

  if [ "$VERBOSE" = true ]; then
    npm run test:integration -- --verbose
  else
    npm run test:integration
  fi

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Integration tests passed${NC}"
  else
    echo -e "${RED}✗ Integration tests failed${NC}"
    exit 1
  fi
}

run_performance_benchmark() {
  echo -e "${YELLOW}Running Performance Benchmarks...${NC}"

  if [ -f "tests/performance/benchmarks.js" ]; then
    node tests/performance/benchmarks.js
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✓ Performance benchmarks completed${NC}"
    else
      echo -e "${RED}✗ Performance benchmarks failed${NC}"
      exit 1
    fi
  else
    echo -e "${YELLOW}⚠ Performance benchmarks not found${NC}"
  fi
}

run_coverage_report() {
  echo -e "${YELLOW}Generating Coverage Report...${NC}"
  npm run test -- --coverage

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Coverage report generated${NC}"
  else
    echo -e "${RED}✗ Coverage report failed${NC}"
    exit 1
  fi
}

print_usage() {
  echo "Usage: ./scripts/run-tests.sh [test-type] [options]"
  echo ""
  echo "Test Types:"
  echo "  unit          - Run unit tests only"
  echo "  integration   - Run integration tests only"
  echo "  performance   - Run performance benchmarks"
  echo "  all           - Run all tests (default)"
  echo ""
  echo "Options:"
  echo "  --coverage    - Generate coverage report"
  echo "  --verbose     - Verbose output"
  echo "  --watch       - Watch mode for unit tests"
  echo ""
  echo "Examples:"
  echo "  ./scripts/run-tests.sh                    # Run all tests"
  echo "  ./scripts/run-tests.sh unit --watch       # Run unit tests in watch mode"
  echo "  ./scripts/run-tests.sh integration        # Run integration tests"
  echo "  ./scripts/run-tests.sh all --coverage     # All tests with coverage"
}

# Check if npm is installed
if ! command -v npm &> /dev/null; then
  echo -e "${RED}✗ npm not found${NC}"
  echo "Please install Node.js and npm"
  exit 1
fi

# Check if package.json exists
if [ ! -f "package.json" ]; then
  echo -e "${RED}✗ package.json not found${NC}"
  echo "Please run this script from the project root directory"
  exit 1
fi

# Main logic
case $TEST_TYPE in
  unit)
    run_unit_tests
    ;;
  integration)
    run_integration_tests
    ;;
  performance)
    run_performance_benchmark
    ;;
  all)
    run_unit_tests
    if [ "$COVERAGE" = true ]; then
      run_coverage_report
    fi
    # Optional: run_performance_benchmark
    ;;
  help|--help|-h)
    print_usage
    ;;
  *)
    echo -e "${RED}Unknown test type: $TEST_TYPE${NC}"
    print_usage
    exit 1
    ;;
esac

# Summary
echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║  Tests Completed Successfully!         ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Print coverage summary if available
if [ "$COVERAGE" = true ] && [ -f "coverage/coverage-summary.json" ]; then
  echo ""
  echo -e "${YELLOW}Coverage Summary:${NC}"
  node -e "
    const summary = require('./coverage/coverage-summary.json').total;
    console.log('Lines:      ' + summary.lines.pct + '%');
    console.log('Statements: ' + summary.statements.pct + '%');
    console.log('Functions:  ' + summary.functions.pct + '%');
    console.log('Branches:   ' + summary.branches.pct + '%');
  "
fi

exit 0
