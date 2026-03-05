#!/bin/bash

# Test runner script for Dynamic eMode Router
# Usage: ./scripts/test.sh [unit|integration|simulation|coverage|all]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function for colored output
print_step() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    print_error "Forge not found. Please install Foundry first."
    exit 1
fi

# Default to all if no argument provided
TEST_TYPE=${1:-all}

case $TEST_TYPE in
    "unit")
        print_step "Running unit tests..."
        forge test --match-path "test/unit/*" -vv
        print_success "Unit tests completed"
        ;;
    
    "integration")
        print_step "Running integration tests..."
        if [[ -z "$ETH_RPC_URL" ]]; then
            print_warning "ETH_RPC_URL not set. Integration tests may fail."
            print_warning "Set it with: export ETH_RPC_URL='https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY'"
        fi
        forge test --match-path "test/integration/*" --fork-url "${ETH_RPC_URL:-https://eth-mainnet.g.alchemy.com/v2/demo}" -vv
        print_success "Integration tests completed"
        ;;
    
    "simulation")
        print_step "Running simulation tests..."
        forge test --match-path "test/simulation/*" -vvv
        print_success "Simulation tests completed"
        ;;
    
    "coverage")
        print_step "Running test coverage analysis..."
        forge coverage --report lcov
        
        if command -v genhtml &> /dev/null; then
            genhtml lcov.info -o coverage --branch-coverage
            print_success "Coverage report generated in ./coverage/index.html"
        else
            print_warning "genhtml not found. Install lcov for HTML reports: brew install lcov"
            print_success "Coverage data saved to lcov.info"
        fi
        ;;
    
    "all")
        print_step "Running all tests..."
        
        # Run unit tests first (fast)
        print_step "1/3 Unit tests..."
        forge test --match-path "test/unit/*"
        
        # Run integration tests if RPC available
        if [[ -n "$ETH_RPC_URL" ]]; then
            print_step "2/3 Integration tests..."
            forge test --match-path "test/integration/*" --fork-url "$ETH_RPC_URL"
        else
            print_warning "Skipping integration tests (ETH_RPC_URL not set)"
        fi
        
        # Run simulation tests
        print_step "3/3 Simulation tests..."
        forge test --match-path "test/simulation/*"
        
        # Generate coverage
        print_step "Generating coverage report..."
        forge coverage --report summary
        
        print_success "All tests completed!"
        ;;
    
    *)
        echo "Usage: $0 [unit|integration|simulation|coverage|all]"
        echo ""
        echo "Test types:"
        echo "  unit        - Fast isolated function tests"
        echo "  integration - Tests against real Aave (requires ETH_RPC_URL)"
        echo "  simulation  - Stress tests and market scenarios"
        echo "  coverage    - Generate test coverage report"
        echo "  all         - Run all test suites (default)"
        exit 1
        ;;
esac