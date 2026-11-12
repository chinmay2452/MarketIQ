
/* ============================================================
   PROJECT: MarketIQ
   MODULE: Supplier Intelligence
   PROGRAM: 04_supplier_intelligence.sas

   PURPOSE:
   1. Analyse supplier performance
   2. Rank suppliers by purchase amount
   3. Calculate supplier contribution
   4. Analyse department performance
   5. Measure supplier concentration
   6. Visualise supplier and department performance

   SOURCE: SASDQREF.PURCHASE
   ============================================================ */


/* STEP 1: IDENTIFY SOURCE VARIABLES */

proc sql noprint;

    select nliteral(name)
    into :amount_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'PURCHASE'
      and upcase(strip(name)) = 'ITEM AMOUNT';

    select nliteral(name)
    into :supplier_name_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'PURCHASE'
      and upcase(strip(name)) = 'SUPPLIER NAME';

    select nliteral(name)
    into :supplier_number_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'PURCHASE'
      and upcase(strip(name)) = 'SUPPLIER NUMBER';

    select nliteral(name)
    into :department_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'PURCHASE'
      and upcase(strip(name)) = 'DEPARTMENT';

quit;


%put NOTE: Amount variable = &amount_var;
%put NOTE: Supplier name variable = &supplier_name_var;
%put NOTE: Supplier number variable = &supplier_number_var;
%put NOTE: Department variable = &department_var;


/* STEP 2: PREPARE PURCHASE ANALYSIS DATA */

data work.purchase_base;

    set SASDQREF.PURCHASE;

    ITEM_AMOUNT = &amount_var;
    SUPPLIER_NAME = &supplier_name_var;
    SUPPLIER_NUMBER = &supplier_number_var;
    DEPARTMENT = &department_var;

    keep ID ITEM_AMOUNT SUPPLIER_NAME
         SUPPLIER_NUMBER DEPARTMENT;

run;


/* STEP 3: INSPECT PURCHASE DATA */

title "MarketIQ - Purchase Dataset Structure";

proc contents data=work.purchase_base varnum;
run;


/* STEP 4: OVERALL PURCHASE STATISTICS */

title "MarketIQ - Purchase Amount Statistics";

proc means data=work.purchase_base
    n nmiss mean median std min q1 q3 max maxdec=2;

    var ITEM_AMOUNT;

run;


/* STEP 5: CALCULATE TOTAL PURCHASE AMOUNT */

proc sql noprint;

    select sum(ITEM_AMOUNT)
    into :total_purchase trimmed
    from work.purchase_base;

quit;

%put NOTE: Overall purchase amount = &total_purchase;


/* STEP 6: SUPPLIER PERFORMANCE SUMMARY */

proc sql;

    create table work.supplier_summary as

    select
        upcase(compbl(strip(
            coalescec(SUPPLIER_NAME, 'UNKNOWN')
        ))) as SUPPLIER_NAME length=255,

        count(*) as TRANSACTION_COUNT,

        count(distinct SUPPLIER_NUMBER)
            as DISTINCT_SUPPLIER_NUMBERS,

        sum(ITEM_AMOUNT)
            as PURCHASE_AMOUNT format=comma18.2,

        mean(ITEM_AMOUNT)
            as AVERAGE_PURCHASE format=comma18.2,

        calculated PURCHASE_AMOUNT /
            &total_purchase * 100
            as CONTRIBUTION_PERCENT format=8.2

    from work.purchase_base

    group by calculated SUPPLIER_NAME

    order by calculated PURCHASE_AMOUNT desc;

quit;


/* STEP 7: TOP 15 SUPPLIERS */

title "MarketIQ - Top 15 Suppliers by Purchase Amount";

proc print data=work.supplier_summary(obs=15) noobs;

    var SUPPLIER_NAME
        TRANSACTION_COUNT
        DISTINCT_SUPPLIER_NUMBERS
        PURCHASE_AMOUNT
        AVERAGE_PURCHASE
        CONTRIBUTION_PERCENT;

run;


/* STEP 8: SUPPLIER PURCHASE CONTRIBUTION */

title "MarketIQ - Supplier Purchase Contribution";

proc sgplot data=work.supplier_summary(obs=15);

    hbar SUPPLIER_NAME /
        response=PURCHASE_AMOUNT
        categoryorder=respdesc
        datalabel;

    xaxis label="Purchase Amount" grid;
    yaxis label="Supplier";

run;


/* STEP 9: DEPARTMENT PERFORMANCE */

proc sql;

    create table work.department_summary as

    select
        case
            when missing(strip(DEPARTMENT))
                then 'UNKNOWN'
            else strip(DEPARTMENT)
        end as DEPARTMENT length=255,

        count(*) as TRANSACTION_COUNT,

        sum(ITEM_AMOUNT)
            as TOTAL_PURCHASE format=comma18.2,

        mean(ITEM_AMOUNT)
            as AVERAGE_PURCHASE format=comma18.2

    from work.purchase_base

    group by calculated DEPARTMENT

    order by calculated TOTAL_PURCHASE desc;

quit;


title "MarketIQ - Department Purchase Performance";

proc print data=work.department_summary noobs;

run;


/* STEP 10: DEPARTMENT PURCHASE COMPARISON */

title "MarketIQ - Purchase Amount by Department";

proc sgplot data=work.department_summary;

    vbar DEPARTMENT /
        response=TOTAL_PURCHASE
        datalabel;

    yaxis label="Total Purchase Amount" grid;
    xaxis label="Department";

run;


/* STEP 11: SUPPLIER CONCENTRATION */

proc sort data=work.supplier_summary
    out=work.supplier_ranked;

    by descending PURCHASE_AMOUNT;

run;


data work.supplier_concentration;

    set work.supplier_ranked;

    retain CUMULATIVE_AMOUNT 0;

    CUMULATIVE_AMOUNT + PURCHASE_AMOUNT;

    CUMULATIVE_CONTRIBUTION =
        CUMULATIVE_AMOUNT / &total_purchase * 100;

    format CUMULATIVE_AMOUNT comma18.2
           CUMULATIVE_CONTRIBUTION 8.2;

run;


title "MarketIQ - Top 10 Supplier Concentration";

proc print data=work.supplier_concentration(obs=10) noobs;

    var SUPPLIER_NAME
        TRANSACTION_COUNT
        PURCHASE_AMOUNT
        CONTRIBUTION_PERCENT
        CUMULATIVE_CONTRIBUTION;

run;


/* STEP 12: FINAL SUPPLIER ANALYSIS VALIDATION */

title "MarketIQ - Supplier Analysis Validation";

proc sql;

    select
        count(*) as SOURCE_RECORDS,
        sum(ITEM_AMOUNT) as SOURCE_PURCHASE_AMOUNT
            format=comma18.2
    from work.purchase_base;

    select
        sum(TRANSACTION_COUNT) as SUPPLIER_TRANSACTION_COUNT,
        sum(PURCHASE_AMOUNT) as SUPPLIER_TOTAL_PURCHASE
            format=comma18.2,
        count(*) as DISTINCT_SUPPLIER_NAMES
    from work.supplier_summary;

    select
        sum(TRANSACTION_COUNT) as DEPARTMENT_TRANSACTION_COUNT,
        sum(TOTAL_PURCHASE) as DEPARTMENT_TOTAL_PURCHASE
            format=comma18.2
    from work.department_summary;

quit;


/* COMPLETION */

%put NOTE: MarketIQ Supplier Intelligence completed successfully.;

title;
