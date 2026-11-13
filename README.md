# MarketIQ — Sales, Product & Supplier Intelligence Platform

## 1. Project Overview

MarketIQ is a data analytics platform developed using SAS Viya. It analyzes sales, product and supplier-related data to generate business insights through descriptive statistics, trend analysis, product intelligence, supplier analysis, statistical testing and predictive modeling.

The project uses SAS Viya for data preparation, statistical analysis, visualization and machine learning.

### Objectives

- Analyze sales performance and transaction patterns.
- Identify high-performing products.
- Understand supplier-associated purchase amounts.
- Examine statistical relationships between business variables.
- Explore predictive models for sales analysis.
- Present analytical findings to support business decision-making.

## 2. Technology Stack

| Component | Technology |
|---|---|
| Analytics platform | SAS Viya for Learners |
| Programming | SAS |
| Data preparation | SAS Studio |
| Visualization | SAS Visual Analytics / PROC SGPLOT |
| Statistical analysis | SAS procedures |
| Predictive modeling | SAS Model Studio (planned) |
| Source control | GitHub (planned integration) |
| CI/CD | Jenkins (planned integration) |

## 3. Data Sources

The project uses datasets available through the `SASDQREF` library.

| Dataset | Observations | Role |
|---|---:|---|
| SALES | 5,002 | Transaction and sales analysis |
| PURCHASE | 5,002 | Supplier and department analysis |
| PRODUCT_SALES | 5,002 | Product-related reference data |
| NC_CUSTOMER | 797 | Separate customer reference dataset |

### Data relationships and limitations

- SALES and PURCHASE contain 5,002 matching transaction IDs.
- SALES and PURCHASE monetary amounts match row by row: `TOTAL SALES` equals `ITEM AMOUNT`.
- SALES and PRODUCT_SALES share matching IDs, although some product attributes differ.
- NC_CUSTOMER has 797 overlapping IDs, but its location fields do not align reliably with SALES. It is therefore not treated as a validated sales-customer relationship.

The six completed programs use the validated SAS source tables directly. Temporary transformed datasets are created in the SAS `WORK` library for analysis; these do not replace the original source datasets.

## 4. Six Completed SAS Programs

### 01 — Descriptive Statistics

**Program:** `01_descriptive_statistics.sas`

Purpose:
- Inspect the SALES dataset.
- Examine variable attributes and missing values.
- Calculate descriptive statistics.
- Identify high-value transactions.
- Summarize product-level sales.

Key findings:
- Total transactions: 5,002.
- Total recorded sales: 33,074,141.34.
- Average transaction amount: 6,612.18.
- Median transaction amount: 3,233.70.
- Standard deviation: 18,312.17.
- Maximum transaction: 912,341.00.
- Valid dates: 3,276.
- Missing dates: 1,726.

Sales values are strongly right-skewed. The largest transaction should be investigated rather than automatically removed as an outlier.

### 02 — Sales Trend Analysis

**Program:** `02_sales_trend_analysis.sas`

Purpose:
- Convert character dates into numeric SAS dates.
- Aggregate sales by month.
- Analyze monthly transaction counts and revenue.
- Visualize monthly sales patterns.

Key findings:
- Valid dated transactions: 3,276.
- Missing dates: 1,726.
- Monthly observations: 13.
- Date range: May 1997 to May 1998.
- Revenue across valid dated transactions: 21,739,377.94.

The monthly revenue does not represent the full dataset revenue because 1,726 transactions have missing dates.

May 1998 recorded the highest monthly revenue among the valid dated records: 4,267,159.86.

### 03 — Product Intelligence

**Program:** `03_product_intelligence.sas`

Purpose:
- Aggregate transactions by product number.
- Calculate transaction count, total revenue and average sale.
- Rank products by revenue.
- Examine product code type distributions.
- Validate product-level totals against source totals.

Key findings:

| Product | Transactions | Revenue |
|---|---:|---:|
| 51 | 908 | 5,347,860.06 |
| 320 | 224 | 1,680,591.80 |
| 257 | 225 | 1,601,983.00 |
| 432 | 259 | 1,592,239.10 |
| 28 | 193 | 1,232,886.90 |

Additional findings:
- Distinct products: 148.
- Total product-level revenue: 33,074,141.34.
- Product-level transaction count: 5,002.

Product-level revenue and transaction counts reconcile with the source SALES dataset.

### 04 — Supplier Intelligence

**Program:** `04_supplier_intelligence.sas`

Purpose:
- Analyze supplier-associated purchase amounts.
- Aggregate transactions by normalized supplier name.
- Calculate supplier contribution percentages.
- Analyze department-level purchase amounts.
- Examine supplier concentration.

Key findings:
- Transactions: 5,002.
- Total recorded purchase amount: 33,074,141.34.
- Distinct normalized supplier names: 251.
- Largest supplier by recorded amount: CR GIBSON.
- CR GIBSON recorded amount: 4,221,942.96.
- CR GIBSON contribution: 12.77%.
- Top ten supplier contribution: approximately 45.14%.

Department A represents the largest recorded department amount, with 23,915,422.10.

**Interpretation limitation:** PURCHASE.ITEM AMOUNT matches SALES.TOTAL SALES for all 5,002 IDs. These figures should be described as supplier-associated purchase amounts recorded in the dataset, not verified supplier costs, profit or procurement efficiency.

### 05 — Statistical Analysis

**Program:** `05_statistical_analysis.sas`

Analyses:
1. Integrated sales and purchase analysis dataset.
2. Descriptive statistics by product code type.
3. Welch two-sample t-test.
4. Chi-square test of association.
5. One-way ANOVA with Levene's test.

Key results:

**Welch t-test — Product types A vs I**
- t-statistic: 1.03.
- p-value: 0.3034.
- Mean log-sales difference: 0.0359.
- 95% confidence interval: -0.0325 to 0.1044.

There is insufficient evidence of a difference in mean log sales between product types A and I.

**Chi-square — Department vs Product Type**
- Chi-square: 4,646.7615.
- p-value: less than 0.0001.
- Cramér's V: 0.9667.

Detailed validation showed exact correspondence between department and product type A/I for 4,679 transactions in the restricted comparison. The strong association is therefore substantially driven by the dataset structure and should not be interpreted as an independent business relationship.

**One-way ANOVA — Department Groups**
- F-statistic: 1.70.
- p-value: 0.1823.
- R-squared: 0.000681.
- Levene's test p-value: 0.1405.

There is insufficient evidence that mean log sales differ across the three department groups.

### 06 — Correlation and Regression

**Program:** `06_correlation_regression.sas`

Purpose:
- Calculate product-level Pearson and Spearman correlations.
- Prepare transaction-level regression data.
- Model log-transformed sales using time and product code type.
- Evaluate training and validation performance.

Product-level analysis:
- Distinct products: 148.
- Pearson correlation between transaction count and total revenue: 0.98542.
- Spearman correlation between transaction count and total revenue: 0.95567.
- Pearson correlation between transaction count and average sale: 0.03896.
- Spearman correlation between transaction count and average sale: 0.41939.

Total revenue is mathematically related to transaction count and average sale. These correlations are descriptive and should not be treated as independent causal evidence.

Regression dataset:
- Records: 3,246.
- Training observations: 2,278.
- Validation observations: 968.
- Target variable: LOG_SALES.
- Predictors: YEARS_FROM_START and PRODUCT_CODE_TYPE.

Regression performance:

| Metric | Result |
|---|---:|
| R-squared | 0.0005 |
| Adjusted R-squared | -0.0004 |
| Training ASE | 0.95433 |
| Validation ASE | 0.91762 |
| Root MSE | 0.97754 |

Neither predictor was statistically significant:
- YEARS_FROM_START p-value: 0.2800.
- PRODUCT_CODE_TYPE A p-value: 0.8653.

The intercept-only model achieved validation ASE of 0.9170, compared with 0.9176 for the full model.

The current regression model does not demonstrate predictive improvement over the baseline. It is retained as an initial modeling experiment, not as a production-ready predictive model.

## 5. Overall Data Quality and Analytical Limitations

1. Sales dates are missing for 1,726 of 5,002 transactions.
2. Sales values are strongly right-skewed.
3. One unusually large transaction requires investigation.
4. SALES and PURCHASE monetary amounts match row by row; profit and cost claims are not supported.
5. The customer reference dataset has not been validated as a transaction-level customer relationship.
6. Department and product code type have a strong structural correspondence.
7. The initial regression model has very low explanatory power.
8. Correlations between mathematically related aggregated measures must be interpreted carefully.

## 6. Project Status

| Module | Status |
|---|---|
| Descriptive Statistics | Completed |
| Sales Trend Analysis | Completed |
| Product Intelligence | Completed |
| Supplier Intelligence | Completed |
| Statistical Analysis | Completed |
| Correlation & Regression | Completed |
| SAS Model Studio | Next phase |
| Visual Analytics Dashboard | Planned |
| GitHub integration | Planned |
| Jenkins CI/CD integration | Planned |

## 7. Next Phase — Predictive Modeling

The next phase will use SAS Model Studio to investigate more meaningful predictive models.

The objective is to establish a reliable baseline, evaluate candidate algorithms, prevent data leakage and assess performance on unseen data.

Model selection and evaluation will depend on the prediction target and the fields that can be validated.

---

**MarketIQ — Sales, Product & Supplier Intelligence Platform**

Developed using SAS Viya.
