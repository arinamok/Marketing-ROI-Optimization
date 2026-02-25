# 📊 Marketing Campaign Optimization & ROI Analysis
### Python | SQL Server | Power BI

---
![Dashboard Preview](dashboard/screenshots/exposure_profit_analysis.png)
## Dashboard Preview

### Executive Summary & Exposure Analysis

<p align="center">
  <img src="dashboard/screenshots/dashboard_executive_summary.png" width="400" style="border:1px solid #ccc; box-shadow: 2px 2px 12px #aaa; border-radius:4px;" />
  <img src="dashboard/screenshots/exposure_profit_analysis.png" width="400" style="border:1px solid #ccc; box-shadow: 2px 2px 12px #aaa; border-radius:4px;" />
</p>


## 1. Project Overview

This project evaluates an A/B marketing campaign to determine whether paid advertising drives meaningfully better results than a control group (PSA), and at what frequency level ad spend becomes genuinely profitable, not just behaviorally effective.

**The Business Question:**
> *"Does the paid ad campaign generate significantly higher conversion and ROI than the PSA (control), and what ad exposure level maximizes profitability?"*

**Dataset Source:** [Kaggle – Marketing A/B Testing Dataset](https://www.kaggle.com/datasets/faviovaz/marketing-ab-testing?resource=download&select=marketing_AB.csv)

---

## 2. Dataset & Financial Engineering

**Original dataset columns:** `user_id`, `test_group`, `converted`, `total_ads`, `most_ads_day`, `most_ads_hour`

**The Challenge:** The original dataset was behavioral only. It could tell you *if* users converted, not whether the campaign was actually worth the money.

**The Solution:** A financial simulation layer was engineered in Python using realistic industry benchmarks to unlock ROI analysis:

| Assumption | Value |
|---|---|
| Revenue per conversion | $120 |
| Cost per paid ad impression | $0.05 |
| Cost per PSA impression | $0.02 |

**Engineered columns:** `revenue`, `cost_per_impression`, `total_cost`, `profit`, `roi`

**The Dataset:** `marketing_AB_enhanced.csv` — **588,101 rows · 12 columns**

---

## 3. Data Cleaning & Engineering Pipeline

### Phase 1: Python (`MarketingABTestingDataCleaning.ipynb`)

```python
import pandas as pd

# Load enhanced dataset
df = pd.read_csv('marketing_AB_enhanced.csv')

# Drop unnamed index columns
df = df.loc[:, ~df.columns.str.contains('^unnamed', case=False)]

# Random sample 35,000 rows for SQL Server
df_sample = df.sample(n=35000, random_state=42)

# Rename columns to snake_case
df_sample.columns = [
    'user_id', 'test_group', 'converted', 'total_ads',
    'most_ads_day', 'most_ads_hour', 'revenue',
    'cost_per_impression', 'total_cost', 'profit', 'roi'
]

# Export for SQL import
df_sample.to_csv('marketing_AB_sample.csv', index=False)
```

### Phase 2: SQL Server: Schema Fixes & Validation

Two errors were encountered and resolved during ingestion into SQL Server:

---

**Problem 1: SMALLINT Overflow**

The Import Wizard assigned `SMALLINT` (max: 32,767) to a column containing the value `32,768`, causing a `Microsoft.Data.SqlClient.SqlException` that halted the import entirely.

*Root cause:* `SMALLINT` is a 16-bit integer (2¹⁵ − 1 = 32,767). The dataset contained exactly one value beyond this ceiling.

---

**Problem 2: Incorrect Type Inference**

`cost_per_impression` (containing decimals like `0.05`) was misread as a time-interval format by the Import Wizard.

---

**Resolution: In-Place Schema Optimization:**

```sql
-- Fix financial columns: FLOAT → high-precision DECIMAL
ALTER TABLE marketing_AB_sample ALTER COLUMN revenue             DECIMAL(10,2);
ALTER TABLE marketing_AB_sample ALTER COLUMN cost_per_impression DECIMAL(10,4);
ALTER TABLE marketing_AB_sample ALTER COLUMN total_cost          DECIMAL(10,2);
ALTER TABLE marketing_AB_sample ALTER COLUMN profit              DECIMAL(10,2);
ALTER TABLE marketing_AB_sample ALTER COLUMN roi                 DECIMAL(10,4);

-- Fix integer columns: SMALLINT → INT (prevents overflow recurrence)
ALTER TABLE marketing_AB_sample ALTER COLUMN total_ads      INT;
ALTER TABLE marketing_AB_sample ALTER COLUMN most_ads_hour  INT;
```

**Null Integrity Check:**

```sql
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN user_id    IS NULL THEN 1 ELSE 0 END) AS null_user_id,
    SUM(CASE WHEN test_group IS NULL THEN 1 ELSE 0 END) AS null_test_group,
    SUM(CASE WHEN converted  IS NULL THEN 1 ELSE 0 END) AS null_converted
FROM marketing_AB_sample;
-- ✔ 35,000 rows · 0 nulls
```

---

## 4. Success Metrics

| Metric | Definition |
|---|---|
| Conversion Rate | `SUM(converted) / COUNT(*)` by test group |
| Revenue | `SUM(revenue)` |
| Total Cost | `SUM(total_cost)` |
| Profit | `SUM(profit)` |
| ROI | `AVG(roi)` |
| Lift % | % increase in conversion rate (Ad vs. PSA) |
| Statistical Significance | Two-proportion Z-test (Python) |

---

## 5. Overall Campaign Results (SQL)

```sql
SELECT
    test_group,
    COUNT(*) AS total_users,
    SUM(CAST(converted AS INT)) AS total_conversions,
    CAST(SUM(CAST(converted AS INT)) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS conversion_rate_pct,
    SUM(revenue)    AS total_revenue,
    SUM(total_cost) AS total_cost,
    SUM(profit)     AS total_profit,
    AVG(roi)        AS avg_roi
FROM marketing_AB_sample
GROUP BY test_group;
```

| Metric | PSA (Control) | Ad (Test) |
|---|---|---|
| Total Users | 1,432 | 33,568 |
| Total Conversions | 28 | 841 |
| Conversion Rate | 1.96% | 2.51% |
| Total Revenue | $3,360.00 | $100,920.00 |
| Total Cost | $704.72 | $41,482.25 |
| **Total Profit** | **$2,655.28** | **$59,437.75** |
| Avg ROI | 4.08 | 1.39 |

**Key Insight:** The Ad group generates more absolute revenue but has a lower average ROI (1.39 vs 4.08). Ads drive volume but are less efficient per dollar spent — which is why exposure optimization matters.

---

## 6. Statistical Testing: Two-Proportion Z-Test (Python)

```python
import numpy as np
from statsmodels.stats.proportion import proportions_ztest, confint_proportions_2indep

# Conversions and totals per group
count = np.array([841, 28])       # [ad, psa]
nobs  = np.array([33568, 1432])   # [ad, psa]

stat, pval = proportions_ztest(count, nobs)
ci_low, ci_upp = confint_proportions_2indep(
    count1=count[0], nobs1=nobs[0],
    count2=count[1], nobs2=nobs[1],
    method='agresti-caffo'
)

lift = (ad_conv - psa_conv) / psa_conv * 100
```

| Metric | Value |
|---|---|
| Ad Conversion Rate | 2.51% |
| PSA Conversion Rate | 1.96% |
| **Lift** | **+28.13%** |
| **p-value** | **0.1902** |
| 95% Confidence Interval | (−0.0026, 0.0123) |
| Statistically Significant? | ❌ Not at 95% level |

**Interpretation:** The 28% lift is promising but statistically unconfirmed. The root cause is a severe sample imbalance — 33,568 users in the Ad group vs. only 1,432 in the PSA group (23:1 ratio). The confidence interval crosses zero, meaning the true difference could still be zero or negative. Increasing the PSA sample size is a prerequisite to drawing a valid conclusion.

---

## 7. Exposure Analysis: The "Profit Trap" (SQL)

```sql
SELECT
    CASE
        WHEN total_ads BETWEEN 0   AND 50  THEN '0-50'
        WHEN total_ads BETWEEN 51  AND 200 THEN '51-200'
        ELSE '200+'
    END AS ads_bucket,
    COUNT(*) AS total_users,
    SUM(CAST(converted AS INT)) AS total_conversions,
    CAST(SUM(CAST(converted AS INT)) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS conversion_rate_pct,
    SUM(profit) AS total_profit
FROM marketing_AB_sample
GROUP BY
    CASE
        WHEN total_ads BETWEEN 0   AND 50  THEN '0-50'
        WHEN total_ads BETWEEN 51  AND 200 THEN '51-200'
        ELSE '200+'
    END;
```

| Ads Bucket | Users | Conversion Rate | Lift vs PSA | Total Profit |
|---|---|---|---|---|
| 0–50 | 30,922 | 1.12% | +0.51% | **−$3,495.78** ❌ |
| **51–200** | **3,700** | **12.57%** | **+49.98%** | **+$7,622.21 ✅** |
| 200+ | 378 | 15.61% | +190.00% | **−$2,863.40** ❌ |

**The "Profit Trap":** The 200+ bucket has the highest conversion rate (15.61%) and the most dramatic behavioral lift (190%) — yet it *loses* money. The cost of delivering that many impressions exceeds the revenue generated. The Python analysis revealed the behavioral story. Power BI revealed the financial consequence.

---

## 8. Time-Based Analysis (SQL)

**By Day of Week:**
```sql
SELECT
    most_ads_day,
    COUNT(*) AS total_users,
    SUM(CAST(converted AS INT)) AS total_conversions,
    CAST(SUM(CAST(converted AS INT)) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS conversion_rate_pct
FROM marketing_AB_sample
GROUP BY most_ads_day
ORDER BY CASE most_ads_day
    WHEN 'Monday'    THEN 1 WHEN 'Tuesday'  THEN 2
    WHEN 'Wednesday' THEN 3 WHEN 'Thursday' THEN 4
    WHEN 'Friday'    THEN 5 WHEN 'Saturday' THEN 6
    WHEN 'Sunday'    THEN 7 END;
```

**By Hour of Day:**
```sql
SELECT
    most_ads_hour,
    COUNT(*) AS total_users,
    SUM(CAST(converted AS INT)) AS total_conversions,
    CAST(SUM(CAST(converted AS INT)) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS conversion_rate_pct
FROM marketing_AB_sample
GROUP BY most_ads_hour
ORDER BY most_ads_hour;
```

- **Monday** = highest conversion rate and revenue; performance declines toward Friday with modest weekend recovery
- **Peak conversion window: 14:00–16:00** · Weakest: early morning hours
- Supports a **dayparting strategy** — concentrating high-value ad delivery during peak windows

---

## 9. Power BI: Financial Reality

Connecting behavioral results to cost data in Power BI revealed the full picture the Python notebook could not see alone:

| Metric | Value |
|---|---|
| Total Revenue | $43,450 |
| Total Ad Spend | $42,187 |
| **Net Profit** | **$1,263** |
| **Overall ROI** | **2.99%** |

The campaign is barely breaking even. The 2.99% ROI is almost entirely sustained by the 51–200 exposure segment, while the other two buckets actively destroy value.

---

## 10. Strategic Recommendations

| Action | Rationale | Impact |
|---|---|---|
| **Cap ad frequency at 200/user** | Eliminates the $2,863 loss from over-saturation | Removes the Profit Trap |
| **Reallocate to 51–200 segment** | Only consistently profitable tier | Concentrates budget on proven ROI |
| **Expand PSA sample size** | Required to reach p < 0.05 | Validates statistical significance |
| **Focus spend on Mondays, 14:00–16:00** | Highest-performing day + hour window | Maximizes conversion efficiency |

**Projected Outcome:** Implementing the frequency cap and reallocating budget toward the 51–200 sweet spot is projected to improve campaign ROI from **2.99% → ~18%**.

---

## 📁 Repository Structure

```
├── data/
│   ├── marketing_AB.csv                      # Original Kaggle dataset
│   ├── marketing_AB_enhanced.csv             # + Engineered financial columns
│   └── marketing_AB_sample.csv              # 35,000-row sample used in SQL
├── notebooks/
│   ├── MarketingABTestingDataCleaning.ipynb  # Python: cleaning + sampling
│   └── marketing_AB_test_analysis.ipynb     # Python: A/B testing + lift analysis
├── sql_queries/
│   └── marketing_ab_analysis.sql            # Schema fixes, KPI queries, exposure + time analysis
└── dashboard/
    ├── Data_Visualization.pbix              # Power BI dashboard
    └── screenshots/                         # Executive Summary + Exposure Analysis pages
```

---

*Author: [Your Name]*
*Links: [LinkedIn] · [Portfolio]*

