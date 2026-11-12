
/* ============================================================
   PROJECT: MarketIQ
   MODULE: Statistical & Predictive Analytics
   PROGRAM: 06_correlation_regression.sas

   PURPOSE:
   1. Analyse product-level correlations
   2. Measure Pearson and Spearman relationships
   3. Prepare transaction-level regression data
   4. Build a regression model
   5. Evaluate model performance on validation data

   INPUT: SALES.csv
   ============================================================ */


/* STEP 1: IMPORT SALES DATA */

proc import
    datafile="/export/viya/homes/karan.rajput24@vit.edu/MarketIQ/SALES.csv"
    out=work.sales
    dbms=csv
    replace;

    guessingrows=max;
    getnames=yes;

run;


/* STEP 2: CREATE PRODUCT-LEVEL SUMMARY */

proc sql;

    create table work.product_correlation as

    select
        "PRODUCT  NUMBER"n as PRODUCT_NUMBER,

        count(*) as TRANSACTION_COUNT,

        sum("TOTAL SALES"n)
            as TOTAL_REVENUE,

        mean("TOTAL SALES"n)
            as AVERAGE_SALE

    from work.sales

    group by "PRODUCT  NUMBER"n;

quit;


/* STEP 3: PRODUCT-LEVEL CORRELATION */

title "MarketIQ - Product-Level Pearson and Spearman Correlation";

proc corr data=work.product_correlation
    pearson spearman;

    var TRANSACTION_COUNT TOTAL_REVENUE AVERAGE_SALE;

run;


/* STEP 4: DISPLAY PRODUCT CORRELATION DATA */

title "MarketIQ - Product Correlation Dataset";

proc print data=work.product_correlation(obs=15);
run;


/* STEP 5: PREPARE REGRESSION DATA */

data work.regression_data;

    set work.sales;

    /* Remove records without a valid date */

    if missing(DATE) then delete;

    /* Use adequately represented product types */

    if "PRODUCT CODE TYPE"n not in ("A", "I") then delete;

    /* Transform sales to reduce right skewness */

    LOG_SALES = log("TOTAL SALES"n);

    /* Create a time variable in years relative to first date */

    YEARS_FROM_START =
        (DATE - '23MAY1997'd) / 365.25;

run;


/* STEP 6: CHECK REGRESSION DATA */

title "MarketIQ - Regression Dataset Summary";

proc means data=work.regression_data
    n mean std min max maxdec=3;

    var LOG_SALES YEARS_FROM_START;

run;



/* STEP 7: BUILD REGRESSION MODEL */

title "MarketIQ - Regression Model";

proc glmselect data=work.regression_data
    plots=all
    seed=2026;

    partition fraction(validate=0.30);

    class "PRODUCT CODE TYPE"n;

    model LOG_SALES =
        YEARS_FROM_START
        "PRODUCT CODE TYPE"n
        / selection=none;

run;

title;



/* STEP 8: COMPLETION MESSAGE */

%put NOTE: MarketIQ correlation and regression analysis completed.;

