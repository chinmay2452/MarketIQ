
/* ============================================================
   PROJECT: MarketIQ
   MODULE: Sales Intelligence
   PROGRAM: 02_sales_trend_analysis.sas
   ============================================================ */


/* STEP 1: CREATE NUMERIC SAS DATE */

data work.sales_trend_base;

    set SASDQREF.SALES;

    length SALES_DATE_NUM 8;

    if not missing(strip(DATE)) then
        SALES_DATE_NUM = input(strip(DATE), mmddyy10.);
    else
        SALES_DATE_NUM = .;

    format SALES_DATE_NUM date9.;

run;


/* STEP 2: VERIFY DATE TYPE */

title "MarketIQ - Date Conversion Validation";

proc contents data=work.sales_trend_base varnum;
run;

proc means data=work.sales_trend_base
    n nmiss min max;

    var SALES_DATE_NUM;

run;


/* STEP 3: CHECK DATE AVAILABILITY */

title "MarketIQ - Sales Date Availability";

proc sql;

    select
        count(*) as TOTAL_RECORDS,

        sum(not missing(SALES_DATE_NUM))
            as VALID_DATES,

        sum(missing(SALES_DATE_NUM))
            as MISSING_DATES

    from work.sales_trend_base;

quit;


/* STEP 4: CREATE MONTHLY SALES SUMMARY */

proc sql;

    create table work.monthly_sales as

    select
        intnx('month', SALES_DATE_NUM, 0, 'b')
            as SALES_MONTH format=monyy7.,

        count(*) as TRANSACTION_COUNT,

        sum("TOTAL SALES"n)
            as TOTAL_REVENUE format=comma18.2,

        mean("TOTAL SALES"n)
            as AVERAGE_SALE format=comma18.2,

        min("TOTAL SALES"n)
            as MINIMUM_SALE format=comma18.2,

        max("TOTAL SALES"n)
            as MAXIMUM_SALE format=comma18.2

    from work.sales_trend_base

    where not missing(SALES_DATE_NUM)

    group by calculated SALES_MONTH

    order by calculated SALES_MONTH;

quit;


/* STEP 5: VERIFY MONTHLY DATASET */

title "MarketIQ - Monthly Dataset Validation";

proc contents data=work.monthly_sales varnum;
run;


/* STEP 6: DISPLAY MONTHLY SUMMARY */

title "MarketIQ - Monthly Sales Performance";

proc print data=work.monthly_sales noobs;
run;


/* STEP 7: MONTHLY REVENUE TREND */

title "MarketIQ - Monthly Revenue Trend";

proc sgplot data=work.monthly_sales;

    series x=SALES_MONTH
           y=TOTAL_REVENUE
           / markers
             lineattrs=(thickness=2);

    xaxis label="Sales Month";

    yaxis label="Total Revenue" grid;

run;


/* STEP 8: MONTHLY TRANSACTION VOLUME */

title "MarketIQ - Monthly Transaction Volume";

proc sgplot data=work.monthly_sales;

    vbar SALES_MONTH /
        response=TRANSACTION_COUNT
        datalabel;

    xaxis label="Sales Month";

    yaxis label="Number of Transactions" grid;

run;


/* STEP 9: MONTHLY REVENUE RANKING */

proc sort data=work.monthly_sales
    out=work.monthly_sales_ranked;

    by descending TOTAL_REVENUE;

run;

title "MarketIQ - Monthly Sales Ranking";

proc print data=work.monthly_sales_ranked noobs;

    var SALES_MONTH
        TOTAL_REVENUE
        TRANSACTION_COUNT
        AVERAGE_SALE;

run;


/* STEP 10: AGGREGATION VALIDATION */

title "MarketIQ - Monthly Aggregation Validation";

proc sql;

    select
        sum(TRANSACTION_COUNT)
            as MONTHLY_RECORD_COUNT,

        sum(TOTAL_REVENUE)
            as MONTHLY_TOTAL_REVENUE format=comma18.2,

        count(*) as NUMBER_OF_MONTHS

    from work.monthly_sales;

quit;


%put NOTE: MarketIQ Program 02 execution completed.;

title;
