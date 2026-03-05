# Dynamic eMode Router Test Suite

Comprehensive testing framework for the Dynamic eMode Router protocol.

## Structure

```
test/
├── unit/                          # Isolated component tests
│   ├── RouterEModeSwitch.t.sol    # eMode switching logic
│   ├── RouterBorrowLogic.t.sol    # Borrowing calculations
│   └── RouterCollateral.t.sol     # Collateral management
├── integration/                   # Full system tests
│   ├── AaveForkTest.t.sol         # Tests against real Aave mainnet
│   └── MultiUserScenario.t.sol    # Multi-user interactions
├── simulation/                    # Stress testing
│   └── PriceCollapseScenario.t.sol # Extreme market conditions
├── helpers/                       # Shared utilities
│   ├── BaseTest.sol               # Common test setup
│   └── MockPriceOracle.sol        # Price simulation
├── Counter.t.sol                  # Legacy (can be removed)
└── DynamicEModeRouter.t.sol       # Legacy (migrate to new structure)
```

## Running Tests

### Unit Tests (Fast - Run These First)
```bash
forge test --match-path "test/unit/*"
```

### Integration Tests (Requires RPC)
```bash
# Set up environment
export ETH_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"

# Run fork tests
forge test --match-path "test/integration/*" --fork-url $ETH_RPC_URL
```

### Simulation Tests (Stress Testing)
```bash
forge test --match-path "test/simulation/*" -vvv
```

### All Tests
```bash
forge test
```

## Test Development Workflow

### 1. Start with Unit Tests
- Test individual functions in isolation
- Fast feedback loop
- Easy debugging
- Should achieve 90%+ coverage of core logic

### 2. Add Integration Tests
- Test against real Aave pools via forking
- Validate assumptions about Aave behavior
- Test gas costs on real network conditions

### 3. Stress Test with Simulations
- Test extreme market conditions
- Generate the statistical data for your paper
- Validate router safety under crash scenarios

## Key Metrics to Track

These tests should generate the numbers for your paper:

| Metric | Test File | What It Measures |
|--------|-----------|------------------|
| Capital efficiency (X%) | `RouterBorrowLogic.t.sol` | LTV improvement vs static eMode |
| Liquidation risk reduction (Y%) | `PriceCollapseScenario.t.sol` | Safety improvement |
| Gas cost optimization (Z%) | `AaveForkTest.t.sol` | Efficiency vs manual switching |
| Worst case liquidation delta (Q) | `PriceCollapseScenario.t.sol` | Maximum loss scenario |

## Test Data for Paper

Tests should output data to `/analysis/data/results.csv` for Python analysis:

```csv
test_name,metric,value,confidence_interval,scenario
test_OptimalEModeSelection,capital_efficiency_improvement,23.4,±2.1,normal_market
test_LUNACollapseScenario,liquidation_risk_reduction,31.2,±4.3,extreme_stress
test_Fork_GasCosts,gas_cost_reduction,18.7,±1.8,mainnet_conditions
```

## Coverage Goals

- **Unit tests**: 90%+ line coverage
- **Integration tests**: All major user flows
- **Simulation tests**: Historical crash scenarios + Monte Carlo

## Next Steps

1. **Fill in unit test TODOs** - Start with `RouterEModeSwitch.t.sol`
2. **Set up fork testing** - Get an Alchemy/Infura key
3. **Implement BaseTest helpers** - Mock tokens and setup
4. **Add data export** - Connect to Python analysis layer
5. **Measure coverage** - `forge coverage`

## Historical Blocks for Fork Testing

| Event | Block Number | Date | Purpose |
|-------|-------------|------|---------|
| LUNA Collapse | 14,742,283 | May 9, 2022 | Extreme stress test |
| FTX Collapse | 15,977,624 | Nov 9, 2022 | Liquidity crisis |
| Banking Crisis | 16,837,283 | Mar 10, 2023 | Correlation breakdown |
| Recent Normal | 19,000,000 | Jan 2024 | Baseline testing |

Use these for realistic stress testing in `AaveForkTest.t.sol`.