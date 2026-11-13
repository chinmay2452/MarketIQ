
/* ============================================================
   PROJECT: MarketIQ
   MODULE: Statistical & Predictive Analytics
   PROGRAM: 06_correlation_regression.sas

   PURPOSE:
   1. Product-level correlation analysis
   2. Pearson and Spearman relationships
   3. Transaction-level regression preparation
   4. Regression modelling
   5. Validation performance evaluation

   SOURCE: SASDQREF.SALES
   ============================================================ */


/* STEP 1: PREPARE SOURCE DATA */

data work.sales_base;

    set SASDQREF.SALES;

    PRODUCT_NUMBER = 'PRODUCT NUMBER'n;
    SALES_AMOUNT = 'TOTAL SALES'n;
    PRODUCT_CODE_TYPE = 'PRODUCT CODE TYPE'n;

    /* Convert character date into SAS numeric date */

    if not missing(strip('DATE'n)) then
        SALES_DATE = input(strip('DATE'n), mmddyy10.);
    else
        SALES_DATE = .;

    format SALES_DATE date9.;

    keep ID PRODUCT_NUMBER SALES_AMOUNT
         PRODUCT_CODE_TYPE SALES_DATE;

run;


/* STEP 2: VERIFY SOURCE DATA */

title "MarketIQ - Sales Data Validation";

proc sql;

    select
        count(*) as TOTAL_RECORDS,
        count(SALES_DATE) as VALID_DATES,
        sum(missing(SALES_DATE)) as MISSING_DATES,
        sum(SALES_AMOUNT) as TOTAL_REVENUE
            format=comma18.2

    from work.sales_base;

quit;


/* STEP 3: CREATE PRODUCT-LEVEL SUMMARY */

title "MarketIQ - Product-Level Summary";

proc sql;

    create table work.product_correlation as

    select
        PRODUCT_NUMBER,

        count(*) as TRANSACTION_COUNT,

        sum(SALES_AMOUNT) as TOTAL_REVENUE
            format=comma18.2,

        mean(SALES_AMOUNT) as AVERAGE_SALE
            format=comma18.2

    from work.sales_base

    where not missing(PRODUCT_NUMBER)
      and not missing(SALES_AMOUNT)

    group by PRODUCT_NUMBER;

quit;


/* STEP 4: PEARSON AND SPEARMAN CORRELATION */

title "MarketIQ - Pearson and Spearman Correlation";

proc corr data=work.product_correlation
    pearson spearman;

    var TRANSACTION_COUNT TOTAL_REVENUE AVERAGE_SALE;

run;


/* STEP 5: DISPLAY PRODUCT CORRELATION DATA */

title "MarketIQ - Product Correlation Dataset";

proc print data=work.product_correlation(obs=15) noobs;

run;


/* STEP 6: IDENTIFY FIRST VALID SALES DATE */

proc sql;

    create table work.date_reference as

    select min(SALES_DATE) as FIRST_SALES_DATE
    from work.sales_base
    where not missing(SALES_DATE);

quit;


/* STEP 7: PREPARE REGRESSION DATA */

data work.regression_data;

    if _n_ = 1 then
        set work.date_reference;

    set work.sales_base;

    if missing(SALES_DATE) then delete;

    if PRODUCT_CODE_TYPE not in ("A", "I") then delete;

    if missing(SALES_AMOUNT) or SALES_AMOUNT <= 0 then delete;

    LOG_SALES = log(SALES_AMOUNT);

    YEARS_FROM_START =
        (SALES_DATE - FIRST_SALES_DATE) / 365.25;

    drop FIRST_SALES_DATE;

run;


/* STEP 8: REGRESSION DATA VALIDATION */

title "MarketIQ - Regression Dataset Structure";

proc contents data=work.regression_data;

run;


title "MarketIQ - Regression Dataset Statistics";

proc means data=work.regression_data
    n nmiss mean std min max maxdec=3;

    var LOG_SALES YEARS_FROM_START;

run;


title "MarketIQ - Regression Dataset by Product Type";

proc freq data=work.regression_data;

    tables PRODUCT_CODE_TYPE / missing;

run;


/* STEP 9: REGRESSION MODEL WITH VALIDATION */

title "MarketIQ - Regression Model";

proc glmselect
    data=work.regression_data
    plots=all
    seed=2026;

    /* Reserve 30% for validation */

    partition fraction(validate=0.30);

    class PRODUCT_CODE_TYPE;

    model LOG_SALES =
        YEARS_FROM_START
        PRODUCT_CODE_TYPE
        / selection=none;

run;


/* STEP 10: FINAL REGRESSION DATA CHECK */

title "MarketIQ - Regression Analysis Summary";

proc sql;

    select
        count(*) as REGRESSION_OBSERVATIONS,

        sum(PRODUCT_CODE_TYPE = "A") as TYPE_A_RECORDS,

        sum(PRODUCT_CODE_TYPE = "I") as TYPE_I_RECORDS,

        min(YEARS_FROM_START) as MIN_YEARS,

        max(YEARS_FROM_START) as MAX_YEARS

    from work.regression_data;

quit;


/* COMPLETION */

%put NOTE: MarketIQ correlation and regression analysis completed successfully.;

title;

/* END OF PROGRAM */
