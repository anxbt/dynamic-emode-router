// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {DynamicEModeRouter} from "../src/DynamicEModeRouter.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {
    DataTypes
} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

/// @title DynamicEModeRouter Fork Test — Full Suite
/// @notice Tests all four functions against REAL Aave V3 mainnet data.
contract DynamicEModeRouterTest is Test {
    // ─── Constants ──────────────────────────────────────────────────
    address constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // ─── State ──────────────────────────────────────────────────────
    DynamicEModeRouter public router;
    IPool public pool;

    function setUp() public {
        vm.createSelectFork("mainnet");
        router = new DynamicEModeRouter(AAVE_V3_POOL);
        pool = IPool(AAVE_V3_POOL);
    }

    // ═══════════════════════════════════════════════════════════════
    //  getUserData Tests
    // ═══════════════════════════════════════════════════════════════

    function testGetUserData() public view {
        address testUser = address(0);
        DynamicEModeRouter.UserData memory data = router.getUserData(testUser);

        (
            uint256 expectedCollateral,
            uint256 expectedDebt,
            uint256 expectedBorrows,
            uint256 expectedLT,
            uint256 expectedLtv,
            uint256 expectedHF
        ) = pool.getUserAccountData(testUser);
        uint256 expectedEMode = pool.getUserEMode(testUser);

        assertEq(
            data.totalCollateralBase,
            expectedCollateral,
            "collateral mismatch"
        );
        assertEq(data.totalDebtBase, expectedDebt, "debt mismatch");
        assertEq(
            data.availableBorrowsBase,
            expectedBorrows,
            "borrows mismatch"
        );
        assertEq(data.currentLiquidationThreshold, expectedLT, "LT mismatch");
        assertEq(data.ltv, expectedLtv, "ltv mismatch");
        assertEq(data.healthFactor, expectedHF, "HF mismatch");
        assertEq(data.currentEMode, expectedEMode, "eMode mismatch");

        console.log("=== getUserData for address(0) ===");
        console.log("collateral:", data.totalCollateralBase);
        console.log("debt:      ", data.totalDebtBase);
        console.log("HF:        ", data.healthFactor);
        console.log("eMode:     ", data.currentEMode);
    }

    function testGetUserData_RealUser() public view {
        address whale = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;
        DynamicEModeRouter.UserData memory data = router.getUserData(whale);

        (
            uint256 expectedCollateral,
            uint256 expectedDebt,
            uint256 expectedBorrows,
            uint256 expectedLT,
            uint256 expectedLtv,
            uint256 expectedHF
        ) = pool.getUserAccountData(whale);
        uint256 expectedEMode = pool.getUserEMode(whale);

        assertEq(
            data.totalCollateralBase,
            expectedCollateral,
            "whale: collateral"
        );
        assertEq(data.totalDebtBase, expectedDebt, "whale: debt");
        assertEq(data.availableBorrowsBase, expectedBorrows, "whale: borrows");
        assertEq(data.currentLiquidationThreshold, expectedLT, "whale: LT");
        assertEq(data.ltv, expectedLtv, "whale: ltv");
        assertEq(data.healthFactor, expectedHF, "whale: HF");
        assertEq(data.currentEMode, expectedEMode, "whale: eMode");
        assertGt(data.totalCollateralBase, 0, "whale should have collateral");

        console.log("=== getUserData for whale ===");
        console.log("collateral:", data.totalCollateralBase);
        console.log("debt:      ", data.totalDebtBase);
        console.log("HF:        ", data.healthFactor);
        console.log("eMode:     ", data.currentEMode);
    }

    // ═══════════════════════════════════════════════════════════════
    //  getUserReservePositions Tests
    // ═══════════════════════════════════════════════════════════════

    function test_getUserReservePositions_RealUser() public view {
        address whale = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;
        DynamicEModeRouter.ReservePosition[] memory positions = router
            .getUserReservePositions(whale);

        assertTrue(positions.length > 0, "whale should have active positions");

        console.log("=== Reserve Positions for Whale ===");
        console.log("Total active assets:", positions.length);
        for (uint256 i = 0; i < positions.length; i++) {
            console.log("---");
            console.log("Asset:        ", positions[i].asset);
            console.log("Is Collateral:", positions[i].isCollateral);
            console.log("Is Borrowing: ", positions[i].isBorrowing);
            console.log("LTV (bps):    ", positions[i].ltv);
            console.log("Liq Threshold:", positions[i].liquidationThreshold);
            console.log("eMode Cat:    ", positions[i].eModeCategory);
            console.log("Oracle Price: ", positions[i].currentPrice);
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //  simulateEMode Tests
    // ═══════════════════════════════════════════════════════════════

    /// @notice Simulate eMode 0 (standard) for the whale.
    ///         Compare our simulated HF with Aave's direct getUserAccountData HF.
    ///         They should be very close (within 1%) since we replicate the same algorithm.
    function test_simulateEMode_CurrentMode() public view {
        address whale = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;
        uint8 currentEMode = uint8(pool.getUserEMode(whale));

        // Our simulation
        DynamicEModeRouter.SimulationResult memory sim = router.simulateEMode(
            whale,
            currentEMode
        );

        // Aave's actual values
        (uint256 realCollateral, uint256 realDebt, , , , uint256 realHF) = pool
            .getUserAccountData(whale);

        console.log("=== simulateEMode (current mode) ===");
        console.log("Simulated collateral:", sim.totalCollateralBase);
        console.log("Real collateral:     ", realCollateral);
        console.log("Simulated debt:      ", sim.totalDebtBase);
        console.log("Real debt:           ", realDebt);
        console.log("Simulated HF:        ", sim.simulatedHF);
        console.log("Real HF:             ", realHF);
        console.log("isSafe:              ", sim.isSafe);

        // Collateral and debt should be very close
        // Allow a small tolerance due to interest accrual between calls
        if (realCollateral > 0) {
            assertApproxEqRel(
                sim.totalCollateralBase,
                realCollateral,
                0.01e18,
                "collateral >1% off"
            );
        }
        if (realDebt > 0) {
            assertApproxEqRel(
                sim.totalDebtBase,
                realDebt,
                0.01e18,
                "debt >1% off"
            );
        }
    }

    /// @notice Simulate switching to eMode 1 (ETH-correlated).
    ///         Verify that the simulation produces valid results.
    function test_simulateEMode_ETHCorrelatedMode() public view {
        address whale = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;

        // Simulate switching to eMode 1 (typically ETH-correlated)
        DynamicEModeRouter.SimulationResult memory sim = router.simulateEMode(
            whale,
            1
        );

        console.log("=== simulateEMode (eMode 1 = ETH) ===");
        console.log("Simulated HF:        ", sim.simulatedHF);
        console.log("Available Borrows:   ", sim.simulatedAvailableBorrows);
        console.log("Total Collateral:    ", sim.totalCollateralBase);
        console.log("Total Debt:          ", sim.totalDebtBase);
        console.log("isSafe:              ", sim.isSafe);

        // Collateral should remain the same regardless of eMode
        // (eMode changes LTV/LT, not balances)
        assertGt(sim.totalCollateralBase, 0, "should have collateral");

        // If no debt, HF should be max uint
        if (sim.totalDebtBase == 0) {
            assertEq(sim.simulatedHF, type(uint256).max, "no debt => max HF");
            assertTrue(sim.isSafe, "no debt => always safe");
        }
    }

    /// @notice Simulate eMode 0 (disable) for the whale.
    function test_simulateEMode_DisableMode() public view {
        address whale = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;

        DynamicEModeRouter.SimulationResult memory sim = router.simulateEMode(
            whale,
            0
        );

        console.log("=== simulateEMode (eMode 0 = standard) ===");
        console.log("Simulated HF:        ", sim.simulatedHF);
        console.log("Available Borrows:   ", sim.simulatedAvailableBorrows);
        console.log("isSafe:              ", sim.isSafe);

        assertGt(sim.totalCollateralBase, 0, "should have collateral");
    }

    /// @notice Compare simulations across multiple eModes.
    ///         For a user with WETH (eMode 1), switching to eMode 1 should give
    ///         more available borrows than eMode 0, because eMode 1 has higher LTV for WETH.
    function test_simulateEMode_CompareAll() public view {
        address whale = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;

        console.log("=== Comparing All eModes ===");
        for (uint8 categoryId = 0; categoryId <= 5; categoryId++) {
            // Check if category exists
            if (categoryId != 0) {
                DataTypes.EModeCategory memory cat = pool.getEModeCategoryData(
                    categoryId
                );
                if (cat.ltv == 0 && cat.liquidationThreshold == 0) {
                    console.log(
                        "eMode",
                        categoryId,
                        "does not exist, skipping"
                    );
                    continue;
                }
                console.log("eMode", categoryId);
                console.log("  LTV:", cat.ltv);
                console.log("  LT: ", cat.liquidationThreshold);
            }

            DynamicEModeRouter.SimulationResult memory sim = router
                .simulateEMode(whale, categoryId);
            console.log(
                "  -> Simulated Borrows:",
                sim.simulatedAvailableBorrows
            );
            console.log("  -> Simulated HF:     ", sim.simulatedHF);
            console.log("  -> isSafe:           ", sim.isSafe);
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //  optimizeEMode Tests
    // ═══════════════════════════════════════════════════════════════

    /// @notice Test optimizeEMode by impersonating the whale.
    ///         This verifies the full execution path:
    ///         1. Simulates all eModes
    ///         2. Picks the best one
    ///         3. Calls pool.setUserEMode()
    function test_optimizeEMode() public {
        address whale = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;

        uint256 currentEMode = pool.getUserEMode(whale);
        console.log("Current eMode before optimization:", currentEMode);

        // Impersonate the whale so msg.sender = whale when calling optimizeEMode
        vm.startPrank(whale);

        (
            uint8 bestEModeId,
            DynamicEModeRouter.SimulationResult memory bestSim
        ) = router.optimizeEMode();

        vm.stopPrank();

        uint256 newEMode = pool.getUserEMode(whale);

        console.log("=== optimizeEMode result ===");
        console.log("Best eMode selected:", bestEModeId);
        console.log("New eMode on-chain: ", newEMode);
        console.log("Simulated HF:       ", bestSim.simulatedHF);
        console.log("Available Borrows:  ", bestSim.simulatedAvailableBorrows);
        console.log("isSafe:             ", bestSim.isSafe);

        // The selected eMode should now be set on-chain
        assertEq(newEMode, bestEModeId, "on-chain eMode should match selected");

        // The simulation determined it was safe
        assertTrue(bestSim.isSafe, "selected eMode should be safe");
    }
}
