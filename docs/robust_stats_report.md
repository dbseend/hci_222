# Robust reference statistics - legacy vs robust (generated)

Source: `cairo_price_dataset_augmented_2026_05_13.json`; stat date 2026-05-13; decay tau = 14 d; source weights {'user_market': 1.0, 'government': 0.8, 'web': 0.5, 'manual_seed': 0.3}; seed 222. Regenerate with `python3 scripts/compute_robust_stats.py`.

## 1. Data composition
- Observations: 3689 (real web/government 60, manual/derived 29, synthetic 3600 = 97.6%)
- Product-unit groups: 25; with >=1 real observation: 22
- Median shift caused by synthetic data (all-data weighted median vs real-only median): median +14.6%, range -36.3% to +53.5%

## 2. Outlier robustness (5% of samples x5)
Relative drift of the price at which a quote turns `warning`:
- Legacy (mean + 1.5 sd): mean 96.1%, max 116.2%
- Robust (median + 1.5 sigma_r): mean 1.7%, max 4.2%

## 3. Verdict behaviour on simulated quotes (k x real-only median)
- Verdict agreement legacy vs robust: 126/132 = 95.5%
- Overcharge quotes (k >= 1.5) still labelled `safe`: legacy 1, robust 2 of 66

| k | legacy safe/neg/warn | robust safe/neg/warn |
|---|---|---|
| 0.8 | 20/2/0 | 20/2/0 |
| 1 | 18/3/1 | 18/3/1 |
| 1.2 | 9/10/3 | 9/10/3 |
| 1.5 | 1/10/11 | 2/8/12 |
| 2 | 0/2/20 | 0/0/22 |
| 3 | 0/0/22 | 0/0/22 |

## 4. Per-product reference (first 25 rows)
| product | unit | n | real | mean | median | sd | sigma_r | confidence |
|---|---|---|---|---|---|---|---|---|
| apple | kg | 149 | 5 | 107.1 | 106.0 | 22.8 | 20.9 | 40 |
| avocado | kg | 147 | 3 | 243.2 | 250.1 | 30.1 | 25.8 | 41 |
| banana | kg | 149 | 4 | 49.6 | 49.5 | 11.6 | 10.1 | 38 |
| blueberry | kg | 147 | 2 | 1105.7 | 1123.6 | 214.0 | 186.0 | 36 |
| camel_doll | pcs | 148 | 3 | 530.5 | 520.1 | 141.6 | 153.0 | 30 |
| cherry | kg | 147 | 0 | 232.0 | 238.5 | 29.2 | 26.6 | 0 |
| cherry_tomato | kg | 147 | 2 | 130.8 | 130.5 | 29.4 | 28.4 | 32 |
| dates | kg | 147 | 2 | 31.8 | 32.5 | 4.3 | 3.7 | 38 |
| fruit | kg | 147 | 0 | 57.4 | 58.3 | 12.3 | 12.3 | 0 |
| grape | kg | 148 | 3 | 52.8 | 52.3 | 8.1 | 9.7 | 36 |
| grapefruit | kg | 147 | 2 | 15.9 | 16.2 | 2.7 | 2.7 | 35 |
| guava | kg | 147 | 2 | 36.1 | 35.3 | 6.9 | 6.9 | 34 |
| kiwi | kg | 147 | 3 | 195.4 | 198.8 | 23.1 | 20.4 | 41 |
| lemon | kg | 148 | 3 | 37.8 | 37.5 | 6.9 | 7.0 | 36 |
| mandarin | kg | 147 | 2 | 23.5 | 23.6 | 4.1 | 4.4 | 34 |
| mango | kg | 147 | 2 | 52.0 | 52.7 | 9.7 | 8.3 | 36 |
| orange | kg | 148 | 2 | 19.7 | 19.7 | 3.2 | 3.3 | 35 |
| peach | kg | 147 | 3 | 42.5 | 43.8 | 6.9 | 6.7 | 38 |
| pineapple | pcs | 147 | 1 | 232.5 | 238.5 | 30.0 | 27.3 | 36 |
| plum | kg | 147 | 0 | 201.0 | 207.0 | 24.2 | 21.1 | 0 |
| pomegranate | kg | 147 | 2 | 37.1 | 37.1 | 6.5 | 5.3 | 37 |
| rockmelon | kg | 148 | 3 | 20.9 | 20.9 | 5.0 | 5.4 | 32 |
| strawberry | kg | 148 | 3 | 31.0 | 28.9 | 20.3 | 6.8 | 34 |
| tomato | kg | 151 | 6 | 24.4 | 24.7 | 7.7 | 4.6 | 43 |
| watermelon | kg | 147 | 2 | 10.8 | 10.4 | 2.2 | 2.1 | 33 |
