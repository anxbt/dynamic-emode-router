# How Senior Engineers Extend Big Protocols (Aave V3 Case Study)

This guide uses your Dynamic E-Mode Router as a running example. It teaches you three things:
1. How to think about extending a big protocol like Aave
2. How to convert raw pseudocode into real Solidity
3. How to use the `aave-v3-core` library you installed

---

## Part 1: The Senior Engineer Mindset

### Step 1 — Read the Source, Not Just the Docs

The docs tell you *what* functions exist. The source tells you *how* they actually work, what edge cases exist, and what data structures you're working with.

You already have the source installed at `lib/aave-v3-core/`. Here are the files you should have open at all times:

| File | Why |
|------|-----|
| [IPool.sol](file:///Users/rishav/Desktop/dynamic-emode-router/lib/aave-v3-core/contracts/interfaces/IPool.sol) | The interface you'll import and call against |
| [DataTypes.sol](file:///Users/rishav/Desktop/dynamic-emode-router/lib/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol) | Every struct you'll work with |
| [GenericLogic.sol](file:///Users/rishav/Desktop/dynamic-emode-router/lib/aave-v3-core/contracts/protocol/libraries/logic/GenericLogic.sol) | **The exact HF calculation** you want to replicate |
| [EModeLogic.sol](file:///Users/rishav/Desktop/dynamic-emode-router/lib/aave-v3-core/contracts/protocol/libraries/logic/EModeLogic.sol) | How eMode category switching works internally |

> [!IMPORTANT]
> Senior engineers don't guess at how a protocol works. They trace through the actual source code path, function by function. This is the single biggest difference between senior and junior protocol devs.

### Step 2 — Trace the Execution Path

Before writing a single line, trace what happens when a user calls `setUserEMode(categoryId)`:

```
User calls Pool.setUserEMode(categoryId)
  └── Pool delegates to EModeLogic.executeSetUserEMode()
        ├── ValidationLogic.validateSetUserEMode()   ← checks borrowed assets are compatible
        ├── Updates storage: usersEModeCategory[msg.sender] = categoryId
        └── If previous category != 0:
              └── ValidationLogic.validateHealthFactor()  ← recalculates HF with new eMode
                    └── GenericLogic.calculateUserAccountData()  ← THE CORE FUNCTION
```

Now you understand the exact chain of logic. Your router needs to **simulate that last function** before calling `setUserEMode`.

### Step 3 — Understand the Data Model Before Writing Code

Senior engineers map out what data they need and where it comes from:

```
What I need                              Where to get it
──────────────────────────────────────   ──────────────────────────────────
User's current HF, collateral, debt  →  pool.getUserAccountData(user)
User's current eMode category        →  pool.getUserEMode(user)
Which reserves the user touches      →  pool.getUserConfiguration(user) → bitmap
List of all reserve addresses         →  pool.getReservesList()
Each reserve's config (LTV, LT, etc) →  pool.getConfiguration(asset)
eMode category config (LTV, LT)      →  pool.getEModeCategoryData(id)
Asset prices                          →  IPriceOracleGetter (from AddressesProvider)
```

> [!TIP]
> Don't skip this mapping step. Draw it on paper even. If you don't know what data you need and where it lives, you will get stuck in the middle of writing code.

---

## Part 2: Using `aave-v3-core` in Your Contract

### Setting Up Imports with Foundry Remappings

Your `foundry.toml` currently has `libs = ["lib"]`, which means Foundry resolves imports from the `lib/` folder. To import Aave's interfaces, you use paths relative to the package root.

Your contract needs these imports:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// The interface you call methods on
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";

// All the structs (EModeCategory, UserConfigurationMap, etc.)
import {DataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

// To decode the UserConfigurationMap bitmap
import {UserConfiguration} from "aave-v3-core/contracts/protocol/libraries/configuration/UserConfiguration.sol";

// To decode ReserveConfigurationMap (get LTV, LT, eMode category from bitmap)
import {ReserveConfiguration} from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";

// For the percentage math used in HF calculation
import {PercentageMath} from "aave-v3-core/contracts/protocol/libraries/math/PercentageMath.sol";
import {WadRayMath} from "aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol";

// Price oracle interface
import {IPriceOracleGetter} from "aave-v3-core/contracts/interfaces/IPriceOracleGetter.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
```

> [!NOTE]
> Foundry auto-resolves `aave-v3-core/...` because the git submodule is at `lib/aave-v3-core/`. You may need to add a remapping in `foundry.toml` if it doesn't resolve:
> ```toml
> remappings = ["aave-v3-core/=lib/aave-v3-core/"]
> ```

You can verify your imports compile with: `forge build`

### Key Aave V3 Functions You'll Call

Here's a cheat sheet of the `IPool` methods relevant to your router:

```solidity
// Returns (totalCollateralBase, totalDebtBase, availableBorrowsBase,
//          currentLiquidationThreshold, ltv, healthFactor)
pool.getUserAccountData(user);

// Returns the user's current eMode category (0 = none)
pool.getUserEMode(user);

// Returns the bitmap of which reserves the user has collateral/borrows in
pool.getUserConfiguration(user);  // → DataTypes.UserConfigurationMap

// Returns the list of all reserve addresses (use to iterate)
pool.getReservesList();

// Returns reserve config for an asset (decode with ReserveConfiguration library)
pool.getConfiguration(asset);    // → DataTypes.ReserveConfigurationMap

// Returns eMode category config (ltv, liquidationThreshold, liquidationBonus, priceSource, label)
pool.getEModeCategoryData(id);   // → DataTypes.EModeCategory

// THE ACTION: switches the user's eMode
pool.setUserEMode(categoryId);
```

---

## Part 3: Converting Your Raw Thoughts Into Code

Now let's walk through your pseudocode comments and translate each one.

### Your Thought → Solidity: `getUserData`

Your raw thought:
```
get current total: totalCollateralBase, totalDebtBase, availableBorrowsBase,
currentLiquidationThreshold, ltv, healthFactor, eMode
```

The issue: `getUserAccountData` returns 6 values as a tuple, not a struct called `UserAccountData`. Here's how you handle this:

```solidity
// Option A: Define your own struct to pack the data neatly
struct UserData {
    uint256 totalCollateralBase;
    uint256 totalDebtBase;
    uint256 availableBorrowsBase;
    uint256 currentLiquidationThreshold;
    uint256 ltv;
    uint256 healthFactor;
    uint256 currentEMode;
}

function getUserData(address user) public view returns (UserData memory) {
    (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    ) = pool.getUserAccountData(user);

    uint256 currentEMode = pool.getUserEMode(user);

    return UserData({
        totalCollateralBase: totalCollateralBase,
        totalDebtBase: totalDebtBase,
        availableBorrowsBase: availableBorrowsBase,
        currentLiquidationThreshold: currentLiquidationThreshold,
        ltv: ltv,
        healthFactor: healthFactor,
        currentEMode: currentEMode
    });
}
```

> [!TIP]
> **Pattern**: When an external function returns a raw tuple, wrap it in your own struct for readability. This is standard practice.

### Your Thought → Solidity: `getUserCurrentReserve`

Your raw thought:
```
- use pool.getUserConfiguration(user) to get which assets
- for every asset fetch and match ltv, lt, price
```

The `UserConfigurationMap` is a **bitmap**. Aave provides a library to decode it. Here's the translation:

```solidity
using UserConfiguration for DataTypes.UserConfigurationMap;
using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

struct ReservePosition {
    address asset;
    bool isCollateral;
    bool isBorrowing;
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 eModeCategory;   // which eMode this asset belongs to
    uint256 currentPrice;
}

function getUserReservePositions(address user) public view returns (ReservePosition[] memory) {
    // Step 1: Get the bitmap of user's active positions
    DataTypes.UserConfigurationMap memory userConfig = pool.getUserConfiguration(user);

    // Step 2: Get full list of reserves to iterate
    address[] memory reserves = pool.getReservesList();

    // Step 3: Count active positions first (Solidity needs fixed array size)
    uint256 count = 0;
    for (uint256 i = 0; i < reserves.length; i++) {
        if (userConfig.isUsingAsCollateralOrBorrowing(i)) {
            count++;
        }
    }

    // Step 4: Build the array
    ReservePosition[] memory positions = new ReservePosition[](count);
    uint256 idx = 0;

    // Get oracle for prices
    address oracle = address(pool.ADDRESSES_PROVIDER().getPriceOracle());

    for (uint256 i = 0; i < reserves.length; i++) {
        if (!userConfig.isUsingAsCollateralOrBorrowing(i)) continue;

        address asset = reserves[i];

        // Decode the bitmap config for this reserve
        DataTypes.ReserveConfigurationMap memory config = pool.getConfiguration(asset);
        (uint256 ltv, uint256 lt, , , , uint256 eModeCategory) = config.getParams();

        positions[idx] = ReservePosition({
            asset: asset,
            isCollateral: userConfig.isUsingAsCollateral(i),
            isBorrowing: userConfig.isBorrowing(i),
            ltv: ltv,
            liquidationThreshold: lt,
            eModeCategory: eModeCategory,
            currentPrice: IPriceOracleGetter(oracle).getAssetPrice(asset)
        });
        idx++;
    }

    return positions;
}
```

> [!IMPORTANT]
> Notice `getParams()` returns 6 values from the bitmap: `(ltv, liquidationThreshold, liquidationBonus, decimals, reserveFactor, eModeCategoryId)`. You skip the ones you don't need with `, ,`.

### Your Thought → Solidity: HF Simulation

Your raw comment was the core idea:
```
REPLICATE THE WEIGHTED AVG WITH FORCED eMODE
- if asset matches category → use Category LTV/LT, else use normal LT
- weighted collateral = sum(value * lt) for all supplies
```

This is literally what [GenericLogic.calculateUserAccountData](file:///Users/rishav/Desktop/dynamic-emode-router/lib/aave-v3-core/contracts/protocol/libraries/logic/GenericLogic.sol#L64-L185) does. Here's the core algorithm extracted and simplified for your simulation:

```solidity
using PercentageMath for uint256;
using WadRayMath for uint256;

struct SimulationResult {
    uint256 simulatedHF;
    uint256 simulatedAvailableBorrows;
    uint256 totalCollateralBase;
    uint256 totalDebtBase;
    bool isSafe;  // HF > buffer threshold
}

uint256 public constant HF_BUFFER = 1.05e18;  // 1.05 in WAD (18 decimals)

function simulateEMode(
    address user,
    uint8 targetEModeId
) public view returns (SimulationResult memory result) {
    // 1. Get the target eMode's LTV and Liquidation Threshold
    DataTypes.EModeCategory memory targetEMode = pool.getEModeCategoryData(targetEModeId);

    // 2. Get user's reserves and oracle
    DataTypes.UserConfigurationMap memory userConfig = pool.getUserConfiguration(user);
    address[] memory reserves = pool.getReservesList();
    address oracle = address(pool.ADDRESSES_PROVIDER().getPriceOracle());

    uint256 totalCollateral;
    uint256 totalDebt;
    uint256 weightedLtv;
    uint256 weightedLiqThreshold;

    // 3. Loop over all reserves — THIS IS THE CORE ALGORITHM from GenericLogic
    for (uint256 i = 0; i < reserves.length; i++) {
        if (!userConfig.isUsingAsCollateralOrBorrowing(i)) continue;

        address asset = reserves[i];
        DataTypes.ReserveConfigurationMap memory config = pool.getConfiguration(asset);
        (uint256 ltv, uint256 lt, , uint256 decimals, , uint256 assetEModeCategory) =
            config.getParams();

        uint256 assetUnit = 10 ** decimals;
        uint256 assetPrice = IPriceOracleGetter(oracle).getAssetPrice(asset);

        // If this asset is supplied as collateral
        if (lt != 0 && userConfig.isUsingAsCollateral(i)) {
            // Get user's aToken balance (simplified — for production use scaledBalanceOf)
            uint256 balanceInBase = _getBalance(user, asset, assetPrice, assetUnit);
            totalCollateral += balanceInBase;

            // ★ THE KEY DECISION: does this asset match the TARGET eMode?
            bool isInTargetEMode = (targetEModeId != 0 && assetEModeCategory == targetEModeId);

            // If it matches → use eMode's better LTV/LT. If not → use normal.
            if (ltv != 0) {
                weightedLtv += balanceInBase * (isInTargetEMode ? targetEMode.ltv : ltv);
            }
            weightedLiqThreshold += balanceInBase *
                (isInTargetEMode ? targetEMode.liquidationThreshold : lt);
        }

        // If this asset is borrowed
        if (userConfig.isBorrowing(i)) {
            totalDebt += _getDebt(user, asset, assetPrice, assetUnit);
        }
    }

    // 4. Calculate weighted averages (same formula as GenericLogic L163-170)
    uint256 avgLtv = totalCollateral != 0 ? weightedLtv / totalCollateral : 0;
    uint256 avgLT = totalCollateral != 0 ? weightedLiqThreshold / totalCollateral : 0;

    // 5. Calculate HF (same formula as GenericLogic L172-176)
    uint256 simulatedHF = totalDebt == 0
        ? type(uint256).max
        : totalCollateral.percentMul(avgLT).wadDiv(totalDebt);

    // 6. Calculate available borrows
    uint256 availableBorrows = 0;
    uint256 maxBorrow = totalCollateral.percentMul(avgLtv);
    if (maxBorrow > totalDebt) {
        availableBorrows = maxBorrow - totalDebt;
    }

    result = SimulationResult({
        simulatedHF: simulatedHF,
        simulatedAvailableBorrows: availableBorrows,
        totalCollateralBase: totalCollateral,
        totalDebtBase: totalDebt,
        isSafe: simulatedHF > HF_BUFFER
    });
}
```

> [!CAUTION]
> The `_getBalance` and `_getDebt` helper functions need to use `scaledBalanceOf` and `getNormalizedIncome`/`getNormalizedDebt` just like [GenericLogic L254-268](file:///Users/rishav/Desktop/dynamic-emode-router/lib/aave-v3-core/contracts/protocol/libraries/logic/GenericLogic.sol#L254-L268) does. Don't use plain `balanceOf` — it won't give you the accrued interest.

---

## Part 4: The Process (Checklist)

Here's the exact workflow senior engineers follow when extending protocols:

### Phase 1 — Understand (Before Any Code)
- [ ] Read the source code of the functions you'll interact with
- [ ] Trace the execution path from user call → internal logic
- [ ] Map out: "what data do I need?" → "where does it live?"
- [ ] Identify which interfaces/libraries you need to import

### Phase 2 — Scaffold (Skeleton First)
- [ ] Write the contract with correct imports (verify with `forge build`)
- [ ] Define your own structs for return types
- [ ] Write function signatures with correct parameter and return types
- [ ] Add NatDoc comments explaining the intent

### Phase 3 — Implement (One Function at a Time)
- [ ] Start with the simplest read-only function (`getUserData`)
- [ ] Test it in a Foundry fork test against real mainnet data
- [ ] Move to the next function only after the previous one compiles + passes
- [ ] For the simulation: copy the algorithm structure from `GenericLogic`, don't invent your own

### Phase 4 — Test Against Reality
- [ ] Write a Foundry fork test that forks mainnet
- [ ] Call your functions against a real user address that has active positions
- [ ] Compare your simulation output against `pool.getUserAccountData()` for the current eMode
- [ ] If they match, your simulation logic is correct

```solidity
// Example fork test structure
function testSimulationMatchesReality() public {
    // Fork mainnet
    vm.createSelectFork("mainnet");

    address realUser = 0x...; // find one on-chain with positions

    // Get current real values
    (,,,, uint256 realLtv, uint256 realHF) = pool.getUserAccountData(realUser);

    // Get current eMode
    uint256 currentEMode = pool.getUserEMode(realUser);

    // Simulate with current eMode (should match!)
    SimulationResult memory sim = router.simulateEMode(realUser, uint8(currentEMode));

    // These should be very close
    assertApproxEqRel(sim.simulatedHF, realHF, 0.01e18); // within 1%
}
```

### Phase 5 — Add the Action
- [ ] Only after simulation is verified, add the `optimizeEMode()` function
- [ ] Simulate first, then call `pool.setUserEMode()` only if safe
- [ ] Add `ReentrancyGuard` from OpenZeppelin
- [ ] Emit events for transparency

---

## Part 5: How Your Remapping & File Structure Should Look

```
dynamic-emode-router/
├── foundry.toml              ← add remappings here if needed
├── src/
│   └── DynamicEModeRouter.sol  ← your contract
├── test/
│   └── DynamicEModeRouter.t.sol ← fork tests
├── lib/
│   ├── aave-v3-core/          ← ✅ already installed
│   ├── forge-std/             ← ✅ already installed
│   └── openzeppelin-contracts/ ← ✅ already installed (for ReentrancyGuard)
```

---

## TL;DR — The Process in One Sentence

> **Read the source → trace the path → map the data → scaffold imports/structs → implement one function at a time → fork-test against reality → then add the action.**

That's how senior protocol engineers work. No guessing, no inventing algorithms from scratch — you **read how Aave already does it**, then you call it or replicate it with your twist (forced eMode simulation).
