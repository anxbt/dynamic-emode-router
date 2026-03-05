// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// ─── Aave V3 Imports ────────────────────────────────────────────────
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {
    DataTypes
} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {
    UserConfiguration
} from "aave-v3-core/contracts/protocol/libraries/configuration/UserConfiguration.sol";
import {
    ReserveConfiguration
} from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
// import {
//     IPoolAddressesProvider
// } from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {
    IPriceOracleGetter
} from "aave-v3-core/contracts/interfaces/IPriceOracleGetter.sol";
import {
    IScaledBalanceToken
} from "aave-v3-core/contracts/interfaces/IScaledBalanceToken.sol";
import {
    IERC20
} from "aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {
    PercentageMath
} from "aave-v3-core/contracts/protocol/libraries/math/PercentageMath.sol";
import {
    WadRayMath
} from "aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol";
import {
    ReentrancyGuard
} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title DynamicEModeRouter
/// @author rishav
/// @notice Routes users to the optimal Aave V3 E-Mode category for their position.
/// @dev The core algorithm replicates GenericLogic.calculateUserAccountData()
///      with a forced eMode category override to simulate HF changes.
contract DynamicEModeRouter is ReentrancyGuard {
    // ─── Library Usages ─────────────────────────────────────────────
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using PercentageMath for uint256;
    using WadRayMath for uint256;

    // ─── State Variables ────────────────────────────────────────────
    IPool public immutable pool;

    // ─── Constants ──────────────────────────────────────────────────
    /// @notice Safety buffer: only switch eMode if simulated HF > 1.05 (WAD).
    uint256 public constant HF_BUFFER = 1.05e18;

    /// @notice Max eMode category ID to scan. Aave V3 mainnet typically has <10 categories.
    uint8 public constant MAX_EMODE_CATEGORY = 10;

    // ─── Events ─────────────────────────────────────────────────────
    event EModeOptimized(
        address indexed user,
        uint8 previousEMode,
        uint8 newEMode,
        uint256 previousHF,
        uint256 newHF
    );

    // ─── Custom Types ───────────────────────────────────────────────
    struct UserData {
        uint256 totalCollateralBase;
        uint256 totalDebtBase;
        uint256 availableBorrowsBase;
        uint256 currentLiquidationThreshold;
        uint256 ltv;
        uint256 healthFactor;
        uint256 currentEMode;
    }

    struct ReservePosition {
        address asset;
        bool isCollateral;
        bool isBorrowing;
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 eModeCategory;
        uint256 currentPrice;
    }

    struct SimulationResult {
        uint256 simulatedHF;
        uint256 simulatedAvailableBorrows;
        uint256 totalCollateralBase;
        uint256 totalDebtBase;
        bool isSafe;
    }

    /// @dev Internal vars struct to avoid "Stack too deep" in simulateEMode.
    ///      This is the EXACT same pattern Aave uses (GenericLogic.CalculateUserAccountDataVars).
    struct SimVars {
        uint256 totalCollateral;
        uint256 totalDebt;
        uint256 weightedLtv;
        uint256 weightedLiqThreshold;
        uint256 assetPrice;
        uint256 assetUnit;
        uint256 ltv;
        uint256 lt;
        uint256 decimals;
        uint256 assetEModeCategory;
        uint256 balanceInBase;
    }

    // ─── Constructor ────────────────────────────────────────────────
    constructor(address _pool) {
        pool = IPool(_pool);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     READ FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Get a user's complete Aave position data in one call.
    function getUserData(
        address user
    ) external view returns (UserData memory data) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = pool.getUserAccountData(user);

        uint256 currentEMode = pool.getUserEMode(user);

        data = UserData({
            totalCollateralBase: totalCollateralBase,
            totalDebtBase: totalDebtBase,
            availableBorrowsBase: availableBorrowsBase,
            currentLiquidationThreshold: currentLiquidationThreshold,
            ltv: ltv,
            healthFactor: healthFactor,
            currentEMode: currentEMode
        });
    }

    /// @notice Gets detailed information for every asset in a user's portfolio.
    function getUserReservePositions(
        address user
    ) external view returns (ReservePosition[] memory positions) {
        DataTypes.UserConfigurationMap memory userConfig = pool
            .getUserConfiguration(user);
        address[] memory reserves = pool.getReservesList();

        uint256 count = 0;
        for (uint256 i = 0; i < reserves.length; i++) {
            if (userConfig.isUsingAsCollateralOrBorrowing(i)) count++;
        }

        positions = new ReservePosition[](count);
        uint256 idx = 0;
        IPriceOracleGetter oracle = IPriceOracleGetter(
            pool.ADDRESSES_PROVIDER().getPriceOracle()
        );

        for (uint256 i = 0; i < reserves.length; i++) {
            if (!userConfig.isUsingAsCollateralOrBorrowing(i)) continue;
            address asset = reserves[i];
            DataTypes.ReserveConfigurationMap memory config = pool
                .getConfiguration(asset);
            (uint256 ltv, uint256 lt, , , , uint256 eModeCategory) = config
                .getParams();

            positions[idx++] = ReservePosition({
                asset: asset,
                isCollateral: userConfig.isUsingAsCollateral(i),
                isBorrowing: userConfig.isBorrowing(i),
                ltv: ltv,
                liquidationThreshold: lt,
                eModeCategory: eModeCategory,
                currentPrice: oracle.getAssetPrice(asset)
            });
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     SIMULATION ENGINE
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Simulate what would happen if a user switched to a different eMode.
    /// @dev Replicates GenericLogic.calculateUserAccountData() with a forced eMode.
    ///      Uses a SimVars struct to avoid "Stack too deep" — the same pattern Aave uses.
    /// @param user The address to simulate for
    /// @param targetEModeId The eMode category to simulate (0 = disable eMode)
    /// @return result The simulation outcome
    function simulateEMode(
        address user,
        uint8 targetEModeId
    ) public view returns (SimulationResult memory result) {
        DataTypes.UserConfigurationMap memory userConfig = pool
            .getUserConfiguration(user);
        address[] memory reserves = pool.getReservesList();
        IPriceOracleGetter oracle = IPriceOracleGetter(
            pool.ADDRESSES_PROVIDER().getPriceOracle()
        );

        // Fetch target eMode config
        uint16 eModeLtv;
        uint16 eModeLiqThreshold;
        if (targetEModeId != 0) {
            DataTypes.EModeCategory memory targetEMode = pool
                .getEModeCategoryData(targetEModeId);
            eModeLtv = targetEMode.ltv;
            eModeLiqThreshold = targetEMode.liquidationThreshold;
        }

        // Use a struct for all loop variables to avoid stack-too-deep
        SimVars memory v;

        for (uint256 i = 0; i < reserves.length; i++) {
            if (!userConfig.isUsingAsCollateralOrBorrowing(i)) continue;

            address asset = reserves[i];
            if (asset == address(0)) continue;

            DataTypes.ReserveData memory reserveData = pool.getReserveData(
                asset
            );
            _decodeReserveParams(asset, v);

            v.assetPrice = oracle.getAssetPrice(asset);

            // ── COLLATERAL ───────────────────────────────────────────
            if (v.lt != 0 && userConfig.isUsingAsCollateral(i)) {
                v.balanceInBase = _getUserBalanceInBaseCurrency(
                    user,
                    reserveData,
                    asset,
                    v.assetPrice,
                    v.assetUnit
                );
                v.totalCollateral += v.balanceInBase;

                // ★ Core eMode decision: does asset match target category?
                bool isInTargetEMode = (targetEModeId != 0 &&
                    v.assetEModeCategory == targetEModeId);

                if (v.ltv != 0) {
                    v.weightedLtv +=
                        v.balanceInBase *
                        (isInTargetEMode ? eModeLtv : v.ltv);
                }
                v.weightedLiqThreshold +=
                    v.balanceInBase *
                    (isInTargetEMode ? eModeLiqThreshold : v.lt);
            }

            // ── DEBT ─────────────────────────────────────────────────
            if (userConfig.isBorrowing(i)) {
                v.totalDebt += _getUserDebtInBaseCurrency(
                    user,
                    reserveData,
                    asset,
                    v.assetPrice,
                    v.assetUnit
                );
            }
        }

        // Weighted averages
        uint256 avgLtv = v.totalCollateral != 0
            ? v.weightedLtv / v.totalCollateral
            : 0;
        uint256 avgLT = v.totalCollateral != 0
            ? v.weightedLiqThreshold / v.totalCollateral
            : 0;

        // Health Factor: collateral * avgLT / totalDebt (in WAD)
        uint256 simulatedHF = v.totalDebt == 0
            ? type(uint256).max
            : v.totalCollateral.percentMul(avgLT).wadDiv(v.totalDebt);

        // Available borrows
        uint256 availableBorrows = 0;
        uint256 maxBorrow = v.totalCollateral.percentMul(avgLtv);
        if (maxBorrow > v.totalDebt) {
            availableBorrows = maxBorrow - v.totalDebt;
        }

        result = SimulationResult({
            simulatedHF: simulatedHF,
            simulatedAvailableBorrows: availableBorrows,
            totalCollateralBase: v.totalCollateral,
            totalDebtBase: v.totalDebt,
            isSafe: simulatedHF > HF_BUFFER
        });
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     ACTION FUNCTION
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Finds and switches to the optimal eMode for msg.sender.
    /// @dev Loops eMode categories 0–MAX_EMODE_CATEGORY, simulates each,
    ///      picks the one maximizing available borrows while staying safe.
    ///
    ///      SAFETY: Only executes if HF > 1.05 AND borrows improve.
    ///      Uses ReentrancyGuard. The caller must be the user (pool.setUserEMode
    ///      operates on msg.sender).
    function optimizeEMode()
        external
        nonReentrant
        returns (uint8 bestEModeId, SimulationResult memory bestSimulation)
    {
        address user = msg.sender;

        uint8 currentEMode = uint8(pool.getUserEMode(user));
        (, , , , , uint256 currentHF) = pool.getUserAccountData(user);

        // Baseline: simulate current eMode
        bestSimulation = simulateEMode(user, currentEMode);
        uint256 bestAvailableBorrows = bestSimulation.simulatedAvailableBorrows;
        bestEModeId = currentEMode;

        // Try every eMode category
        for (
            uint8 categoryId = 0;
            categoryId <= MAX_EMODE_CATEGORY;
            categoryId++
        ) {
            if (categoryId == currentEMode) continue;

            // Skip non-existent categories (ltv == 0 for non-zero categories)
            if (categoryId != 0) {
                DataTypes.EModeCategory memory cat = pool.getEModeCategoryData(
                    categoryId
                );
                if (cat.ltv == 0 && cat.liquidationThreshold == 0) continue;
            }

            SimulationResult memory sim = simulateEMode(user, categoryId);

            if (
                sim.isSafe &&
                sim.simulatedAvailableBorrows > bestAvailableBorrows
            ) {
                bestAvailableBorrows = sim.simulatedAvailableBorrows;
                bestEModeId = categoryId;
                bestSimulation = sim;
            }
        }

        // Execute switch only if different from current
        if (bestEModeId != currentEMode) {
            pool.setUserEMode(bestEModeId);
            emit EModeOptimized(
                user,
                currentEMode,
                bestEModeId,
                currentHF,
                bestSimulation.simulatedHF
            );
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     INTERNAL HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// @dev Decodes reserve configuration params into the SimVars struct.
    function _decodeReserveParams(
        address asset,
        SimVars memory v
    ) internal view {
        DataTypes.ReserveConfigurationMap memory config = pool.getConfiguration(
            asset
        );
        (v.ltv, v.lt, , v.decimals, , v.assetEModeCategory) = config
            .getParams();
        v.assetUnit = 10 ** v.decimals;
    }

    /// @dev Calculates a user's aToken balance in base currency.
    ///      Mirrors GenericLogic._getUserBalanceInBaseCurrency (L254-268).
    ///      Formula: scaledBalance * normalizedIncome * price / assetUnit
    function _getUserBalanceInBaseCurrency(
        address user,
        DataTypes.ReserveData memory reserve,
        address underlyingAsset,
        uint256 assetPrice,
        uint256 assetUnit
    ) internal view returns (uint256) {
        uint256 scaledBalance = IScaledBalanceToken(reserve.aTokenAddress)
            .scaledBalanceOf(user);
        if (scaledBalance == 0) return 0;

        uint256 normalizedIncome = pool.getReserveNormalizedIncome(
            underlyingAsset
        );
        uint256 balance = scaledBalance.rayMul(normalizedIncome) * assetPrice;

        return balance / assetUnit;
    }

    /// @dev Calculates a user's total debt in base currency.
    ///      Mirrors GenericLogic._getUserDebtInBaseCurrency (L221-241).
    ///      Variable debt: scaledBalanceOf * normalizedDebt
    ///      Stable debt: plain balanceOf (interest baked into the token)
    function _getUserDebtInBaseCurrency(
        address user,
        DataTypes.ReserveData memory reserve,
        address underlyingAsset,
        uint256 assetPrice,
        uint256 assetUnit
    ) internal view returns (uint256) {
        // Variable debt
        uint256 userTotalDebt = IScaledBalanceToken(
            reserve.variableDebtTokenAddress
        ).scaledBalanceOf(user);
        if (userTotalDebt != 0) {
            uint256 normalizedDebt = pool.getReserveNormalizedVariableDebt(
                underlyingAsset
            );
            userTotalDebt = userTotalDebt.rayMul(normalizedDebt);
        }

        // Stable debt
        userTotalDebt =
            userTotalDebt +
            IERC20(reserve.stableDebtTokenAddress).balanceOf(user);

        // Convert to base currency
        userTotalDebt = assetPrice * userTotalDebt;

        return userTotalDebt / assetUnit;
    }
}
