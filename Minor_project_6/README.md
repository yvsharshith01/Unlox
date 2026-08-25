# QuickCart Warehouse Inventory — Stockout Risk Classification

An end-to-end Supervised Machine Learning project predicting daily SKU-level stockout risks (**Safe**, **At-Risk**, **Imminent**) across 12 dark stores and 60 SKUs over a 30-day operational calendar (October 2026).

---

## Business Problem
In quick-commerce warehousing, stockouts lead to lost revenue and churn. Because missing an actual stockout is far costlier than investigating a false alarm, this project frames stockout risk as an asymmetric-cost classification problem, prioritizing **Recall on the Imminent stockout class**.

---

## Dataset Architecture
- **Fact Table**: `fact_inventory_daily.csv` (21,600 records)
- **Dimension Tables**: `dim_stores.csv`, `dim_skus.csv`, `dim_suppliers.csv`, `dim_events.csv`
- **Target Distribution**: Safe (65.42%), At-Risk (24.01%), Imminent (10.57%)

---

## Key Exploratory Findings
- **Festival Multiplier Effect**: Stockout risk spiked from **9.51% (non-festival)** to **23.31% during Diwali week** (a 2.45x increase).
- **Supplier Reliability**: Low-reliability suppliers (<0.75 score) showed an Imminent stockout rate of **15.83%**, compared to **3.82%** for high-reliability suppliers (>=0.85).
- **Perishability**: Perishable SKUs experienced higher stockout frequency (**12.77%**) versus non-perishables (**9.30%**).

---

## Modeling & Validation Strategy
- **Time-Based Split**: Train on Oct 1–23 (16,560 rows); Test on Oct 24–30 (5,040 rows, covering the Diwali demand surge) to prevent data leakage.
- **Engineered Features**: `reorder_gap`, `days_of_cover_ratio`, `supplier_reliability_clean`, `is_recent_reorder`, `days_since_festival_start`.

### Model Performance Comparison

| Model | Accuracy | Imminent Recall | Imminent F1 | Macro F1 |
| :--- | :---: | :---: | :---: | :---: |
| **Baseline (Majority Class)** | 62.28% | 0.00% | 0.00% | 25.59% |
| **Logistic Regression (Balanced)** | 90.71% | **94.19%** | 82.53% | 85.42% |
| **Random Forest** | 93.27% | 80.65% | 82.40% | 88.72% |
| **XGBoost** | **94.76%** | 78.97% | **82.98%** | **90.47%** |

---

## Key Recommendations
- Deploy **Logistic Regression with balanced class weights** (or threshold-tuned XGBoost) for real-time alerting to maximize the detection of critical stockouts (94.19% Imminent Recall).
- Prioritize buffer stock allocations for perishable inventory sourced from low-reliability vendors during festive demand windows.

---

## How to Run
```bash
git clone [https://github.com/](https://github.com/)<your-username>/quickcart-inventory-stockout-risk.git
cd quickcart-inventory-stockout-risk
pip install -r requirements.txt
jupyter notebook notebooks/stockout_risk_classification.ipynb
