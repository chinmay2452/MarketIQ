
/* ============================================================
   PROJECT: MarketIQ
   MODULE: Sales Intelligence
   PROGRAM: 01_descriptive_statistics.sas

   PURPOSE:
   1. Load SALES from SASDQREF
   2. Inspect dataset structure
   3. Calculate descriptive statistics
   4. Check missing values
   5. Analyse sales distribution and outliers
   6. Identify highest-value sales records
   7. Calculate product-level sales summaries
   ============================================================ */


/* STEP 1: LOAD SALES DATA */

data work.sales;
    set SASDQREF.SALES;

    /* Convert character date into SAS numeric date */
    if not missing(strip(DATE)) then
        SALES_DATE = input(strip(DATE), mmddyy10.);

    format SALES_DATE date9.;
run;


/* STEP 2: VERIFY DATASET STRUCTURE */

title "MarketIQ - Sales Dataset Structure";

proc contents data=work.sales varnum;
run;


/* STEP 3: DISPLAY SAMPLE RECORDS */

title "MarketIQ - Sample Sales Records";

proc print data=work.sales(obs=15);
run;


/* STEP 4: DESCRIPTIVE STATISTICS */

title "MarketIQ - Sales Descriptive Statistics";

proc means data=work.sales
    n nmiss mean median std min q1 q3 max maxdec=2;

    var "TOTAL SALES"n;

run;


/* STEP 5: MISSING VALUE ANALYSIS */

title "MarketIQ - Numeric Missing Value Analysis";

proc means data=work.sales n nmiss;
run;


/* Key categorical and date missing values */

proc sql;

    title "MarketIQ - Important Field Completeness";

    select
        count(*) as TOTAL_RECORDS,

        sum(missing(COMPANY)) as MISSING_COMPANY,

        sum(missing(CONTACT)) as MISSING_CONTACT,

        sum(missing(DATE)) as MISSING_DATE,

        sum(missing(SALES_DATE)) as INVALID_OR_MISSING_SALES_DATE,

        sum(missing("PRODUCT CODE TYPE"n))
            as MISSING_PRODUCT_TYPE

    from work.sales;

quit;


/* STEP 6: SALES DISTRIBUTION AND OUTLIERS */

title "MarketIQ - Sales Distribution Analysis";

proc univariate data=work.sales;

    var "TOTAL SALES"n;

    histogram "TOTAL SALES"n / normal;

    inset n mean median std min max / position=ne;

run;


/* STEP 7: HIGHEST-VALUE SALES RECORDS */

proc sort data=work.sales
    out=work.sales_sorted;

    by descending "TOTAL SALES"n;

run;

title "MarketIQ - Top 15 Sales Records";

proc print data=work.sales_sorted(obs=15);

    var ID COMPANY DATE SALES_DATE
        "TOTAL SALES"n
        "PRODUCT  NUMBER"n
        "PRODUCT CODE"n;

run;


/* STEP 8: PRODUCT-LEVEL SALES SUMMARY */

proc sql;

    create table work.product_sales_summary as

    select
        "PRODUCT  NUMBER"n as PRODUCT_NUMBER,

        count(*) as TRANSACTION_COUNT,

        sum("TOTAL SALES"n)
            as TOTAL_REVENUE format=comma18.2,

        mean("TOTAL SALES"n)
            as AVERAGE_SALES format=comma18.2

    from work.sales

    group by "PRODUCT  NUMBER"n

    order by calculated TOTAL_REVENUE desc;

quit;

title "MarketIQ - Top Products by Sales";

proc print data=work.product_sales_summary(obs=15);
run;


/* STEP 9: OVERALL SALES SUMMARY */

title "MarketIQ - Overall Sales Summary";

proc sql;

    select
        count(*) as TOTAL_RECORDS,

        sum("TOTAL SALES"n)
            as TOTAL_REVENUE format=comma18.2,

        mean("TOTAL SALES"n)
            as AVERAGE_SALES format=comma18.2,

        median("TOTAL SALES"n)
            as MEDIAN_SALES format=comma18.2,

        min("TOTAL SALES"n)
            as MINIMUM_SALE format=comma18.2,

        max("TOTAL SALES"n)
            as MAXIMUM_SALE format=comma18.2

    from work.sales;

quit;


/* STEP 10: COMPLETION */

title "MarketIQ - Descriptive Statistics Completed";

%put NOTE: MarketIQ Program 01 completed successfully.;

title;
