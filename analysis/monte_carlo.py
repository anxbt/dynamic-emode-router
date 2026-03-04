import numpy as np

price = 3000
simulations = 10000
days = 30
daily_volatility = 0.05  # 5% daily price movement

results = []
for _ in range(simulations):
    path = [price]
    for d in range(days):
        change = np.random.normal(0, daily_volatility)
        path.append(path[-1] * (1 + change))
    results.append(min(path))  # worst price in this path

liquidation_threshold = 1800
liquidated = sum(1 for p in results if p < liquidation_threshold)
print(f"Liquidation probability: {liquidated/simulations*100:.2f}%")