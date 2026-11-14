/***************************************************************
 PROJECT : MarketIQ - Customer & Marketing Decision Intelligence
 FILE    : 08_marketiq_advanced_business_analytics.sas

 PURPOSE :
   SECTION 16 - ADVANCED BUSINESS ANALYTICS

   16.1 Product Revenue Concentration Analysis
   16.2 Supplier Dependency Analysis
   16.3 Monthly Sales Growth Analysis
   16.4 Product Performance Ranking
   16.5 Business Recommendation Indicators

 PREREQUISITES :
   1. Run 07_marketiq_data_preparation.sas first.
   2. Run this program in the SAME SAS session.
   3. The following WORK datasets must exist:
        WORK.PRODUCT_FEATURES
        WORK.SUPPLIER_FEATURES
        WORK.SALES_PRODUCT_BASE
        WORK.SUPPLIER_BASE
        WORK.MONTHLY_SALES_FEATURES

 IMPORTANT :
   - This program does not modify source datasets.
   - This program does not modify the completed Section 0-15
     data-preparation program.
   - WORK datasets are temporary and are session-specific.
   - Purchase amount is not interpreted as profit, cost,
     or margin.
   - Business indicators are descriptive rule-based flags.
     They are not causal findings or automated decisions.
***************************************************************/


/***************************************************************
 SECTION 16.1 - PRODUCT REVENUE CONCENTRATION ANALYSIS
***************************************************************/

/* Rank products by total revenue. */

proc sort data=WORK.PRODUCT_FEATURES
          out=WORK.PRODUCT_CONCENTRATION;
    by descending TOTAL_REVENUE;
run;


/* Calculate ranking and cumulative revenue contribution. */

data WORK.PRODUCT_CONCENTRATION;

    set WORK.PRODUCT_CONCENTRATION;

    PRODUCT_RANK = _N_;

    retain CUMULATIVE_REVENUE 0;
    retain CUMULATIVE_REVENUE_SHARE 0;

    CUMULATIVE_REVENUE + TOTAL_REVENUE;
    CUMULATIVE_REVENUE_SHARE + REVENUE_CONTRIBUTION;

    if PRODUCT_RANK <= 10 then
        TOP_10_PRODUCT = "YES";
    else
        TOP_10_PRODUCT = "NO";

    format TOTAL_REVENUE comma18.2;
    format REVENUE_CONTRIBUTION percent8.2;
    format CUMULATIVE_REVENUE comma18.2;
    format CUMULATIVE_REVENUE_SHARE percent8.2;

run;


/* Display the top 20 products. */

proc print data=WORK.PRODUCT_CONCENTRATION(obs=20) noobs;

    var PRODUCT_RANK
        PRODUCT_NUMBER
        TRANSACTION_COUNT
        TOTAL_REVENUE
        REVENUE_CONTRIBUTION
        CUMULATIVE_REVENUE_SHARE
        TOP_10_PRODUCT;

    title "MarketIQ - Product Revenue Concentration Analysis";

run;


/* Validate product count and total revenue. */

proc sql;

    title "MarketIQ - Product Concentration Validation";

    select
        count(*) as TOTAL_PRODUCTS,
        sum(TOTAL_REVENUE) as TOTAL_REVENUE
            format=comma18.2,
        max(CUMULATIVE_REVENUE_SHARE)
            as FINAL_CUMULATIVE_SHARE
            format=percent8.2
    from WORK.PRODUCT_CONCENTRATION;

quit;


/***************************************************************
 SECTION 16.2 - SUPPLIER DEPENDENCY ANALYSIS
***************************************************************/

/* Rank suppliers by recorded purchase amount. */

proc sort data=WORK.SUPPLIER_FEATURES
          out=WORK.SUPPLIER_CONCENTRATION;
    by descending TOTAL_PURCHASE_AMOUNT;
run;


/* Calculate supplier contribution and cumulative share. */

data WORK.SUPPLIER_CONCENTRATION;

    set WORK.SUPPLIER_CONCENTRATION;

    SUPPLIER_RANK = _N_;

    retain CUMULATIVE_PURCHASE_AMOUNT 0;
    retain CUMULATIVE_PURCHASE_SHARE 0;

    CUMULATIVE_PURCHASE_AMOUNT + TOTAL_PURCHASE_AMOUNT;
    CUMULATIVE_PURCHASE_SHARE + PURCHASE_CONTRIBUTION;

    if SUPPLIER_RANK <= 10 then
        TOP_10_SUPPLIER = "YES";
    else
        TOP_10_SUPPLIER = "NO";

    format TOTAL_PURCHASE_AMOUNT comma18.2;
    format PURCHASE_CONTRIBUTION percent8.2;
    format CUMULATIVE_PURCHASE_AMOUNT comma18.2;
    format CUMULATIVE_PURCHASE_SHARE percent8.2;

run;


/* Display the top 20 suppliers. */

proc print data=WORK.SUPPLIER_CONCENTRATION(obs=20) noobs;

    var SUPPLIER_RANK
        SUPPLIER_NAME
        TRANSACTION_COUNT
        TOTAL_PURCHASE_AMOUNT
        PURCHASE_CONTRIBUTION
        CUMULATIVE_PURCHASE_SHARE
        TOP_10_SUPPLIER;

    title "MarketIQ - Supplier Dependency Analysis";

run;


/* Validate supplier count and recorded purchase amount. */

proc sql;

    title "MarketIQ - Supplier Concentration Validation";

    select
        count(*) as TOTAL_SUPPLIERS,
        sum(TRANSACTION_COUNT) as TOTAL_TRANSACTIONS,
        sum(TOTAL_PURCHASE_AMOUNT)
            as TOTAL_PURCHASE_AMOUNT format=comma18.2,
        max(CUMULATIVE_PURCHASE_SHARE)
            as FINAL_CUMULATIVE_SHARE format=percent8.2
    from WORK.SUPPLIER_CONCENTRATION;

quit;


/***************************************************************
 SECTION 16.3 - MONTHLY SALES GROWTH ANALYSIS
***************************************************************/

/* Ensure months are in chronological order. */

proc sort data=WORK.MONTHLY_SALES_FEATURES
          out=WORK.MONTHLY_SALES_GROWTH;
    by MONTH_DATE;
run;


/* Calculate month-over-month change and growth rate.
   The first month has no prior month, so its growth is missing. */

data WORK.MONTHLY_SALES_GROWTH;

    set WORK.MONTHLY_SALES_GROWTH;

    PREVIOUS_MONTH_REVENUE = lag(MONTHLY_REVENUE);

    if _N_ = 1 then
        PREVIOUS_MONTH_REVENUE = .;

    if not missing(PREVIOUS_MONTH_REVENUE) then do;

        MONTHLY_REVENUE_CHANGE =
            MONTHLY_REVENUE - PREVIOUS_MONTH_REVENUE;

        if PREVIOUS_MONTH_REVENUE ne 0 then
            MONTHLY_GROWTH_RATE =
                MONTHLY_REVENUE_CHANGE / PREVIOUS_MONTH_REVENUE;
        else
            MONTHLY_GROWTH_RATE = .;

    end;
    else do;
        MONTHLY_REVENUE_CHANGE = .;
        MONTHLY_GROWTH_RATE = .;
    end;

    format MONTH_DATE monyy7.;
    format MONTHLY_REVENUE comma18.2;
    format PREVIOUS_MONTH_REVENUE comma18.2;
    format MONTHLY_REVENUE_CHANGE comma18.2;
    format MONTHLY_GROWTH_RATE percent8.2;

run;


/* Display monthly growth analysis. */

proc print data=WORK.MONTHLY_SALES_GROWTH noobs;

    var MONTH_DATE
        TRANSACTION_COUNT
        MONTHLY_REVENUE
        PREVIOUS_MONTH_REVENUE
        MONTHLY_REVENUE_CHANGE
        MONTHLY_GROWTH_RATE;

    title "MarketIQ - Monthly Sales Growth Analysis";

run;


/* Validate the number of months and dated revenue. */

proc sql;

    title "MarketIQ - Monthly Growth Validation";

    select
        count(*) as MONTHS_ANALYZED,
        sum(TRANSACTION_COUNT) as DATED_TRANSACTIONS,
        sum(MONTHLY_REVENUE) as DATED_REVENUE
            format=comma18.2,
        sum(missing(MONTHLY_GROWTH_RATE))
            as MONTHS_WITHOUT_GROWTH_RATE
    from WORK.MONTHLY_SALES_GROWTH;

quit;


/***************************************************************
 SECTION 16.4 - PRODUCT PERFORMANCE RANKING
***************************************************************/

/* Rank products by transaction count. */

proc sort data=WORK.PRODUCT_FEATURES
          out=WORK._PRODUCT_BY_VOLUME;
    by descending TRANSACTION_COUNT;
run;

data WORK._PRODUCT_VOLUME_RANK;

    set WORK._PRODUCT_BY_VOLUME;

    VOLUME_RANK = _N_;

    keep PRODUCT_NUMBER VOLUME_RANK;

run;


/* Rank products by average transaction value. */

proc sort data=WORK.PRODUCT_FEATURES
          out=WORK._PRODUCT_BY_AVG;
    by descending AVG_TRANSACTION_VALUE;
run;

data WORK._PRODUCT_AVG_RANK;

    set WORK._PRODUCT_BY_AVG;

    AVG_VALUE_RANK = _N_;

    keep PRODUCT_NUMBER AVG_VALUE_RANK;

run;


/* Rank products by total revenue. */

proc sort data=WORK.PRODUCT_FEATURES
          out=WORK._PRODUCT_BY_REVENUE;
    by descending TOTAL_REVENUE;
run;

data WORK._PRODUCT_REVENUE_RANK;

    set WORK._PRODUCT_BY_REVENUE;

    REVENUE_RANK = _N_;

    keep PRODUCT_NUMBER REVENUE_RANK;

run;


/* Combine the three rankings with the original product measures. */

proc sort data=WORK.PRODUCT_FEATURES
          out=WORK._PRODUCT_FEATURES_SORTED;
    by PRODUCT_NUMBER;
run;

proc sort data=WORK._PRODUCT_VOLUME_RANK;
    by PRODUCT_NUMBER;
run;

proc sort data=WORK._PRODUCT_AVG_RANK;
    by PRODUCT_NUMBER;
run;

proc sort data=WORK._PRODUCT_REVENUE_RANK;
    by PRODUCT_NUMBER;
run;

data WORK.PRODUCT_PERFORMANCE_RANKS;

    merge WORK._PRODUCT_FEATURES_SORTED
          WORK._PRODUCT_VOLUME_RANK
          WORK._PRODUCT_AVG_RANK
          WORK._PRODUCT_REVENUE_RANK;

    by PRODUCT_NUMBER;

run;


/* Display the leading products under each ranking measure. */

proc sort data=WORK.PRODUCT_PERFORMANCE_RANKS
          out=WORK._PRODUCT_RANKS_BY_REVENUE;
    by REVENUE_RANK;
run;

proc print data=WORK._PRODUCT_RANKS_BY_REVENUE(obs=20) noobs;

    var PRODUCT_NUMBER
        TRANSACTION_COUNT
        TOTAL_REVENUE
        AVG_TRANSACTION_VALUE
        VOLUME_RANK
        AVG_VALUE_RANK
        REVENUE_RANK;

    title "MarketIQ - Product Performance Rankings";

run;


/* Validate that all products received all three ranks. */

proc sql;

    title "MarketIQ - Product Ranking Validation";

    select
        count(*) as TOTAL_PRODUCTS,
        sum(missing(VOLUME_RANK)) as MISSING_VOLUME_RANKS,
        sum(missing(AVG_VALUE_RANK)) as MISSING_AVG_RANKS,
        sum(missing(REVENUE_RANK)) as MISSING_REVENUE_RANKS
    from WORK.PRODUCT_PERFORMANCE_RANKS;

quit;


/***************************************************************
 SECTION 16.5 - BUSINESS RECOMMENDATION INDICATORS
***************************************************************/

/* Derive descriptive product thresholds from the observed
   product-level data. The mean and median are calculated from
   all products in this dataset. */

proc sql noprint;

    select
        mean(AVG_TRANSACTION_VALUE),
        median(TRANSACTION_COUNT)
    into
        :OVERALL_MEAN_AVG_VALUE,
        :MEDIAN_PRODUCT_TRANSACTIONS
    from WORK.PRODUCT_FEATURES;

quit;


/* Create transparent product-level business indicators.

   TOP_REVENUE_PRODUCT:
       Product is among the top 10 by total revenue.

   ABOVE_AVERAGE_TRANSACTION_VALUE:
       Product average transaction value exceeds the
       overall mean product average transaction value.

   BELOW_MEDIAN_TRANSACTION_VOLUME:
       Product transaction count is below the median
       transaction count across products.

   These are descriptive screening flags, not causal claims. */

data WORK.PRODUCT_BUSINESS_INDICATORS;

    set WORK.PRODUCT_CONCENTRATION;

    if PRODUCT_RANK <= 10 then
        TOP_REVENUE_PRODUCT = "YES";
    else
        TOP_REVENUE_PRODUCT = "NO";

    if AVG_TRANSACTION_VALUE > &OVERALL_MEAN_AVG_VALUE then
        ABOVE_AVERAGE_TRANSACTION_VALUE = "YES";
    else
        ABOVE_AVERAGE_TRANSACTION_VALUE = "NO";

    if TRANSACTION_COUNT < &MEDIAN_PRODUCT_TRANSACTIONS then
        BELOW_MEDIAN_TRANSACTION_VOLUME = "YES";
    else
        BELOW_MEDIAN_TRANSACTION_VOLUME = "NO";

    format AVG_TRANSACTION_VALUE comma18.2;
    format TOTAL_REVENUE comma18.2;

run;


/* Create supplier-level descriptive indicators.

   TOP_PURCHASE_AMOUNT_SUPPLIER:
       Supplier is among the top 10 by recorded purchase amount.

   HIGH_PURCHASE_CONTRIBUTION:
       Supplier contributes at least 5 percent of the
       total recorded purchase amount.

   MISSING_SUPPLIER_NUMBER_PRESENT:
       One or more supplier-number values are missing
       for this supplier name. */

data WORK.SUPPLIER_BUSINESS_INDICATORS;

    set WORK.SUPPLIER_CONCENTRATION;

    if SUPPLIER_RANK <= 10 then
        TOP_PURCHASE_AMOUNT_SUPPLIER = "YES";
    else
        TOP_PURCHASE_AMOUNT_SUPPLIER = "NO";

    if PURCHASE_CONTRIBUTION >= 0.05 then
        HIGH_PURCHASE_CONTRIBUTION = "YES";
    else
        HIGH_PURCHASE_CONTRIBUTION = "NO";

    if MISSING_SUPPLIER_NUMBERS > 0 then
        MISSING_SUPPLIER_NUMBER_PRESENT = "YES";
    else
        MISSING_SUPPLIER_NUMBER_PRESENT = "NO";

    format TOTAL_PURCHASE_AMOUNT comma18.2;
    format PURCHASE_CONTRIBUTION percent8.2;

run;


/* Display product business indicators. */

proc print data=WORK.PRODUCT_BUSINESS_INDICATORS(obs=20) noobs;

    var PRODUCT_NUMBER
        TRANSACTION_COUNT
        TOTAL_REVENUE
        AVG_TRANSACTION_VALUE
        TOP_REVENUE_PRODUCT
        ABOVE_AVERAGE_TRANSACTION_VALUE
        BELOW_MEDIAN_TRANSACTION_VOLUME;

    title "MarketIQ - Product Business Indicators";

run;


/* Display supplier business indicators. */

proc print data=WORK.SUPPLIER_BUSINESS_INDICATORS(obs=20) noobs;

    var SUPPLIER_NAME
        TRANSACTION_COUNT
        TOTAL_PURCHASE_AMOUNT
        PURCHASE_CONTRIBUTION
        TOP_PURCHASE_AMOUNT_SUPPLIER
        HIGH_PURCHASE_CONTRIBUTION
        MISSING_SUPPLIER_NUMBER_PRESENT;

    title "MarketIQ - Supplier Business Indicators";

run;


/* Final Section 16 validation. */

proc sql noprint;

    select count(*) into :PRODUCT_CONCENTRATION_ROWS
    from WORK.PRODUCT_CONCENTRATION;

    select count(*) into :SUPPLIER_CONCENTRATION_ROWS
    from WORK.SUPPLIER_CONCENTRATION;

    select count(*) into :MONTHLY_GROWTH_ROWS
    from WORK.MONTHLY_SALES_GROWTH;

    select count(*) into :PRODUCT_RANKING_ROWS
    from WORK.PRODUCT_PERFORMANCE_RANKS;

    select count(*) into :PRODUCT_INDICATOR_ROWS
    from WORK.PRODUCT_BUSINESS_INDICATORS;

    select count(*) into :SUPPLIER_INDICATOR_ROWS
    from WORK.SUPPLIER_BUSINESS_INDICATORS;

quit;


data WORK.MARKETIQ_ADVANCED_VALIDATION;

    PRODUCT_CONCENTRATION_ROWS = &PRODUCT_CONCENTRATION_ROWS;
    SUPPLIER_CONCENTRATION_ROWS = &SUPPLIER_CONCENTRATION_ROWS;
    MONTHLY_GROWTH_ROWS = &MONTHLY_GROWTH_ROWS;
    PRODUCT_RANKING_ROWS = &PRODUCT_RANKING_ROWS;
    PRODUCT_INDICATOR_ROWS = &PRODUCT_INDICATOR_ROWS;
    SUPPLIER_INDICATOR_ROWS = &SUPPLIER_INDICATOR_ROWS;

run;


proc print data=WORK.MARKETIQ_ADVANCED_VALIDATION noobs;

    title "MarketIQ - Advanced Business Analytics Final Validation";

run;


/***************************************************************
 END OF SECTION 16
 MARKETIQ - ADVANCED BUSINESS ANALYTICS
***************************************************************/
