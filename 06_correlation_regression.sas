
/* ============================================================
   PROJECT: MarketIQ
   MODULE: Statistical & Predictive Analytics
   PROGRAM: 06_correlation_regression.sas

   PURPOSE:
   1. Analyse product-level correlations
   2. Measure Pearson and Spearman relationships
   3. Prepare transaction-level regression data
   4. Build a regression model
   5. Evaluate model performance using validation data

   INPUT:
   SASDQREF.SALES

   ============================================================ */


/* STEP 1: IDENTIFY SOURCE VARIABLE NAMES */

/* Metadata-driven lookup handles SAS column names
   containing spaces. */

proc sql noprint;

    select nliteral(name)
    into :product_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'SALES'
      and upcase(strip(name)) = 'PRODUCT NUMBER';

    select nliteral(name)
    into :sales_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'SALES'
      and upcase(strip(name)) = 'TOTAL SALES';

    select nliteral(name)
    into :type_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'SALES'
      and upcase(strip(name)) = 'PRODUCT CODE TYPE';

    select nliteral(name)
    into :date_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'SALES'
      and upcase(strip(name)) = 'DATE';

quit;


/* STEP 2: PREPARE SALES DATA */

/* Convert character DATE into a numeric SAS date.
   Retain only the variables required for this program. */

data work.sales_base;

    set SASDQREF.SALES;

    PRODUCT_NUMBER = &product_var;
    SALES_AMOUNT = &sales_var;
    PRODUCT_CODE_TYPE = &type_var;

    if not missing(strip(&date_var)) then
        SALES_DATE = input(strip(&date_var), mmddyy10.);
    else
        SALES_DATE = .;

    format SALES_DATE date9.;

    keep ID PRODUCT_NUMBER SALES_AMOUNT
         PRODUCT_CODE_TYPE SALES_DATE;

run;


/* STEP 3: CREATE PRODUCT-LEVEL SUMMARY */

title "MarketIQ - Product-Level Summary";

proc sql;

    create table work.product_correlation as

    select
        PRODUCT_NUMBER,
        count(*) as TRANSACTION_COUNT,
        sum(SALES_AMOUNT) as TOTAL_REVENUE format=comma18.2,
        mean(SALES_AMOUNT) as AVERAGE_SALE format=comma18.2

    from work.sales_base

    where not missing(PRODUCT_NUMBER)
      and not missing(SALES_AMOUNT)

    group by PRODUCT_NUMBER;

quit;


/* STEP 4: PRODUCT-LEVEL PEARSON AND SPEARMAN CORRELATION */

/* Examine relationships among product transaction count,
   total revenue and average sale.

   Note: TOTAL_REVENUE is mathematically related to
   TRANSACTION_COUNT and AVERAGE_SALE. Correlations involving
   these variables are descriptive, not independent evidence. */

title "MarketIQ - Product-Level Pearson and Spearman Correlation";

proc corr data=work.product_correlation
    pearson spearman;

    var TRANSACTION_COUNT TOTAL_REVENUE AVERAGE_SALE;

run;


/* STEP 5: DISPLAY PRODUCT CORRELATION DATA */

title "MarketIQ - Product Correlation Dataset";

proc print data=work.product_correlation(obs=15);

run;


/* STEP 6: IDENTIFY FIRST VALID SALES DATE */

/* Use the earliest valid date in the source data
   as the reference point for the time variable. */

proc sql noprint;

    select min(SALES_DATE)
    into :first_sales_date trimmed
    from work.sales_base
    where not missing(SALES_DATE);

quit;


/* STEP 7: PREPARE REGRESSION DATA */

/* Retain valid dated transactions belonging to the
   two adequately represented product types A and I.

   LOG_SALES reduces the influence of right-skewed sales.
   YEARS_FROM_START measures elapsed time in years. */

data work.regression_data;

    set work.sales_base;

    if missing(SALES_DATE) then delete;

    if PRODUCT_CODE_TYPE not in ("A", "I") then delete;

    if missing(SALES_AMOUNT) or SALES_AMOUNT <= 0 then delete;

    LOG_SALES = log(SALES_AMOUNT);

    YEARS_FROM_START =
        (SALES_DATE - &first_sales_date) / 365.25;

run;


/* STEP 8: CHECK REGRESSION DATA */

title "MarketIQ - Regression Dataset Summary";

proc contents data=work.regression_data;

run;


proc means data=work.regression_data
    n nmiss mean std min max maxdec=3;

    var LOG_SALES YEARS_FROM_START;

run;


title "MarketIQ - Regression Dataset by Product Type";

proc freq data=work.regression_data;

    tables PRODUCT_CODE_TYPE / missing;

run;


/* STEP 9: BUILD REGRESSION MODEL */

/* Validation partition reserves 30% of observations
   for model evaluation.

   Predictors:
   - YEARS_FROM_START
   - PRODUCT_CODE_TYPE

   Target:
   - LOG_SALES

   SELECTION=NONE retains the specified predictors. */

title "MarketIQ - Regression Model";

proc glmselect data=work.regression_data
    plots=all
    seed=2026;

    partition fraction(validate=0.30);

    class PRODUCT_CODE_TYPE;

    model LOG_SALES =
        YEARS_FROM_START
        PRODUCT_CODE_TYPE
        / selection=none;

run;


/* STEP 10: COMPLETION MESSAGE */

title;

%put NOTE: MarketIQ correlation and regression analysis completed.;


/* END */
