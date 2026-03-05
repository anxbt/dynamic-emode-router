// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockPriceOracle
 * @notice Mock oracle for testing price scenarios
 */
contract MockPriceOracle {
    mapping(address => uint256) private _prices;
    mapping(address => uint256) private _volatility;
    
    event PriceUpdated(address indexed asset, uint256 newPrice);
    event VolatilityUpdated(address indexed asset, uint256 newVolatility);
    
    /// @dev Set price for an asset
    function setPrice(address asset, uint256 price) external {
        _prices[asset] = price;
        emit PriceUpdated(asset, price);
    }
    
    /// @dev Set volatility for an asset (basis points, e.g., 500 = 5%)
    function setVolatility(address asset, uint256 volatilityBps) external {
        _volatility[asset] = volatilityBps;
        emit VolatilityUpdated(asset, volatilityBps);
    }
    
    /// @dev Get current price of an asset
    function getAssetPrice(address asset) external view returns (uint256) {
        uint256 price = _prices[asset];
        require(price > 0, "Price not set");
        return price;
    }
    
    /// @dev Get volatility of an asset
    function getAssetVolatility(address asset) external view returns (uint256) {
        return _volatility[asset];
    }
    
    /// @dev Simulate gradual price change over blocks
    function simulatePriceChange(
        address asset,
        uint256 targetPrice,
        uint256 durationBlocks
    ) external {
        uint256 currentPrice = _prices[asset];
        require(currentPrice > 0, "Initial price not set");
        
        // TODO: Implement gradual price change logic
        // This would be used in stress tests to simulate crashes
    }
    
    /// @dev Simulate correlation breakdown between assets
    function simulateCorrelationBreakdown(
        address asset1,
        address asset2,
        uint256 divergencePercent
    ) external {
        // TODO: Implement correlation breakdown simulation
        // Make two previously correlated assets diverge
    }
    
    /// @dev Batch set prices for multiple assets
    function batchSetPrices(
        address[] calldata assets,
        uint256[] calldata prices
    ) external {
        require(assets.length == prices.length, "Array length mismatch");
        
        for (uint256 i = 0; i < assets.length; i++) {
            _prices[assets[i]] = prices[i];
            emit PriceUpdated(assets[i], prices[i]);
        }
    }
}