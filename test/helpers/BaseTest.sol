// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DynamicEModeRouter} from "../DynamicEModeRouter.t.sol";

/**
 * @title BaseTest
 * @notice Shared test setup and utilities for all test suites
 */
abstract contract BaseTest is Test {
    DynamicEModeRouter router;
    
    // Common test addresses
    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address liquidator = makeAddr("liquidator");
    
    // Common test tokens (will be set up in setUp)
    address WETH;
    address WSTETH;
    address USDC;
    address USDT;
    
    // Test amounts
    uint256 constant INITIAL_BALANCE = 1000e18;
    uint256 constant DEPOSIT_AMOUNT = 100e18;
    uint256 constant BORROW_AMOUNT = 50e18;
    
    function setUp() public virtual {
        // Deploy router
        vm.startPrank(owner);
        router = new DynamicEModeRouter(owner);
        vm.stopPrank();
        
        _setupTestTokens();
        _setupUserBalances();
        _labelAddresses();
    }
    
    /// @dev Set up mock ERC20 tokens for testing
    function _setupTestTokens() internal {
        // TODO: Deploy or mock common test tokens
        // WETH = address(new MockERC20("Wrapped ETH", "WETH", 18));
        // WSTETH = address(new MockERC20("Wrapped Staked ETH", "wstETH", 18));
        // USDC = address(new MockERC20("USD Coin", "USDC", 6));
        // USDT = address(new MockERC20("Tether USD", "USDT", 6));
    }
    
    /// @dev Give test users initial token balances
    function _setupUserBalances() internal {
        address[] memory users = _getTestUsers();
        
        for (uint256 i = 0; i < users.length; i++) {
            // TODO: Set up initial balances for test tokens
            // deal(WETH, users[i], INITIAL_BALANCE);
            // deal(WSTETH, users[i], INITIAL_BALANCE);
            // deal(USDC, users[i], INITIAL_BALANCE * 1e6 / 1e18); // Adjust for decimals
        }
    }
    
    /// @dev Label addresses for better trace output
    function _labelAddresses() internal {
        vm.label(address(router), "DynamicEModeRouter");
        vm.label(owner, "Owner");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(liquidator, "Liquidator");
    }
    
    /// @dev Get array of test users for loops
    function _getTestUsers() internal view returns (address[] memory) {
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = liquidator;
        return users;
    }
    
    /// @dev Helper to simulate time passage
    function _warpTime(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }
    
    /// @dev Helper to simulate block advancement
    function _mineBlocks(uint256 numBlocks) internal {
        vm.roll(block.number + numBlocks);
    }
    
    /// @dev Helper to check router state
    function _assertRouterState(
        address user,
        uint8 expectedCategory,
        string memory message
    ) internal {
        // TODO: Add router state assertions
        // uint8 actualCategory = router.getUserEModeCategory(user);
        // assertEq(actualCategory, expectedCategory, message);
    }
    
    /// @dev Helper to simulate market conditions
    function _setMarketCondition(string memory condition) internal {
        // TODO: Set up different market conditions for testing
        // "normal", "high_volatility", "correlation_breakdown", etc.
    }
}