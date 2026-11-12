
/* ============================================================
   PROJECT: MarketIQ
   MODULE: Product Intelligence
   PROGRAM: 03_product_intelligence.sas

   PURPOSE:
   1. Rank products by total revenue
   2. Calculate transaction counts
   3. Calculate average sales per product
   4. Calculate product revenue contribution
   5. Compare product code types
   6. Visualise top-performing products

   SOURCE: SASDQREF.SALES
   ============================================================ */



/* STEP 1: PREPARE PRODUCT ANALYSIS DATA */

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

quit;


%put NOTE: Product variable = &product_var;
%put NOTE: Sales variable = &sales_var;
%put NOTE: Code type variable = &type_var;


data work.product_base;

    set SASDQREF.SALES;

    PRODUCT_NUMBER = &product_var;
    TOTAL_SALES = &sales_var;
    PRODUCT_CODE_TYPE = &type_var;

    keep ID PRODUCT_NUMBER TOTAL_SALES PRODUCT_CODE_TYPE;

run;


/* STEP 2: CALCULATE TOTAL REVENUE */

proc sql noprint;

    select sum(TOTAL_SALES)
    into :total_revenue trimmed
    from work.product_base;

quit;

%put NOTE: Overall sales revenue = &total_revenue;


/* STEP 3: PRODUCT-LEVEL PERFORMANCE */

proc sql;

    create table work.product_summary as

    select
        PRODUCT_NUMBER,

        count(*) as TRANSACTION_COUNT,

        sum(TOTAL_SALES)
            as TOTAL_REVENUE format=comma18.2,

        mean(TOTAL_SALES)
            as AVERAGE_SALE format=comma18.2,

        min(TOTAL_SALES)
            as MINIMUM_SALE format=comma18.2,

        max(TOTAL_SALES)
            as MAXIMUM_SALE format=comma18.2,

        calculated TOTAL_REVENUE / &total_revenue * 100
            as REVENUE_CONTRIBUTION format=8.2

    from work.product_base

    group by PRODUCT_NUMBER

    order by calculated TOTAL_REVENUE desc;

quit;


/* STEP 4: DISPLAY TOP 15 PRODUCTS */

title "MarketIQ - Top 15 Products by Revenue";

proc print data=work.product_summary(obs=15) noobs;

    var PRODUCT_NUMBER
        TRANSACTION_COUNT
        TOTAL_REVENUE
        AVERAGE_SALE
        REVENUE_CONTRIBUTION;

run;


/* STEP 5: PRODUCT REVENUE COMPARISON */

title "MarketIQ - Top 15 Products by Revenue";

proc sgplot data=work.product_summary(obs=15);

    hbar PRODUCT_NUMBER /
        response=TOTAL_REVENUE
        categoryorder=respdesc
        datalabel;

    xaxis label="Total Revenue" grid;
    yaxis label="Product Number";

run;


/* STEP 6: PRODUCT TRANSACTION VOLUME */

title "MarketIQ - Product Transaction Volume";

proc sgplot data=work.product_summary(obs=15);

    hbar PRODUCT_NUMBER /
        response=TRANSACTION_COUNT
        categoryorder=respdesc
        datalabel;

    xaxis label="Number of Transactions" grid;
    yaxis label="Product Number";

run;


/* STEP 7: PRODUCT CODE TYPE ANALYSIS */

proc sql;

    create table work.product_type_summary as

    select
        case
            when missing(PRODUCT_CODE_TYPE)
                then "UNKNOWN"
            else strip(PRODUCT_CODE_TYPE)
        end as PRODUCT_CODE_TYPE length=255,

        count(*) as TRANSACTION_COUNT,

        sum(TOTAL_SALES)
            as TOTAL_REVENUE format=comma18.2,

        mean(TOTAL_SALES)
            as AVERAGE_SALE format=comma18.2

    from work.product_base

    group by calculated PRODUCT_CODE_TYPE

    order by calculated TOTAL_REVENUE desc;

quit;


title "MarketIQ - Product Code Type Performance";

proc print data=work.product_type_summary noobs;

run;


/* STEP 8: PRODUCT CODE TYPE REVENUE COMPARISON */

title "MarketIQ - Revenue by Product Code Type";

proc sgplot data=work.product_type_summary;

    vbar PRODUCT_CODE_TYPE /
        response=TOTAL_REVENUE
        datalabel;

    yaxis label="Total Revenue" grid;
    xaxis label="Product Code Type";

run;


/* STEP 9: PRODUCT SUMMARY STATISTICS */

title "MarketIQ - Product Sales Statistics";

proc means data=work.product_summary
    n mean median std min max maxdec=2;

    var TOTAL_REVENUE TRANSACTION_COUNT AVERAGE_SALE;

run;


/* STEP 10: PRODUCT ANALYSIS VALIDATION */

title "MarketIQ - Product Analysis Validation";

proc sql;

    select
        count(*) as TOTAL_SOURCE_RECORDS,
        sum(TOTAL_SALES) as SOURCE_REVENUE format=comma18.2
    from work.product_base;

    select
        sum(TRANSACTION_COUNT) as PRODUCT_TRANSACTION_COUNT,
        sum(TOTAL_REVENUE) as PRODUCT_TOTAL_REVENUE format=comma18.2,
        count(*) as DISTINCT_PRODUCTS
    from work.product_summary;

quit;


/* COMPLETION */

%put NOTE: MarketIQ Product Intelligence analysis completed successfully.;

title;
