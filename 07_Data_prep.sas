
 /***********************************************************************
 PROJECT  : MarketIQ - Customer & Marketing Decision Intelligence
 FILE     : 07_marketiq_data_preparation.sas

 PURPOSE  :
   1. Source data profiling
   2. Data cleaning and quality assessment
   3. Date conversion and monthly feature engineering
   4. Product-level feature engineering
   5. Supplier-level feature engineering
   6. Integrated transaction intelligence
   7. Final validation and analytical summaries

 SOURCE DATASETS:
   SASDQREF.SALES
   SASDQREF.PRODUCT_SALES
   SASDQREF.PURCHASE

 IMPORTANT:
   - Original source datasets are never modified.
   - No transaction records are deleted.
   - Missing values are flagged, not blindly imputed.
   - Purchase amount is not treated as profit or margin.
   - Product number is extracted positionally because of
     name-resolution issues in the SAS session.

 ***********************************************************************/


/***********************************************************************
 SECTION 0 - ENVIRONMENT AND SOURCE VALIDATION
 ***********************************************************************/

options validvarname=any;

%macro check_source(ds=);

    %if not %sysfunc(exist(&ds)) %then %do;
        %put ERROR: Required source dataset &ds does not exist.;
        %abort cancel;
    %end;

%mend;

%check_source(ds=SASDQREF.SALES);
%check_source(ds=SASDQREF.PRODUCT_SALES);
%check_source(ds=SASDQREF.PURCHASE);


/***********************************************************************
 SECTION 1 - MISSING VALUE PROFILING
 ***********************************************************************/

%macro profile(ds=, output=);

    proc contents data=&ds
        out=work._metadata(keep=name type varnum)
        noprint;
    run;

    proc sql noprint;
        select name, type
        into :var1-:var999, :type1-:type999
        from work._metadata
        order by varnum;

        %let n=&sqlobs;
    quit;

    proc sql;
        create table &output as

        %do i=1 %to &n;

            select
                "&ds" as DATASET_NAME length=40,
                "&&var&i" as VARIABLE_NAME length=64,

                case
                    when &&type&i=1 then "NUMERIC"
                    else "CHARACTER"
                end as VARIABLE_TYPE length=10,

                sum(missing("&&var&i"n)) as MISSING_COUNT,
                count(*) - calculated MISSING_COUNT
                    as NONMISSING_COUNT

            from &ds

            %if &i < &n %then union all;

        %end;
        ;
    quit;

%mend;

%profile(ds=SASDQREF.SALES, output=WORK.PROFILE_SALES);
%profile(ds=SASDQREF.PRODUCT_SALES, output=WORK.PROFILE_PRODUCT);
%profile(ds=SASDQREF.PURCHASE, output=WORK.PROFILE_PURCHASE);

data WORK.MARKETIQ_MISSING_PROFILE;
    set WORK.PROFILE_SALES
        WORK.PROFILE_PRODUCT
        WORK.PROFILE_PURCHASE;
run;

proc print data=WORK.MARKETIQ_MISSING_PROFILE noobs;
    title "MarketIQ - Missing Value Analysis";
run;


/***********************************************************************
 SECTION 2 - DATA CLEANING
 ***********************************************************************/

/* 2.1 SALES */

data WORK.SALES_CLEAN;
    set SASDQREF.SALES;

    DATE_MISSING=missing(DATE);
    COMPANY_MISSING=missing(COMPANY);
    CONTACT_MISSING=missing(CONTACT);

    LOCATION_MISSING=
        missing(CITY) or missing(STATE);

    /* Gender is entirely missing in the source. */
    drop GENDER;
run;


/* 2.2 PRODUCT SALES */

data WORK.PRODUCT_SALES_CLEAN;
    set SASDQREF.PRODUCT_SALES;
run;


/* 2.3 PURCHASE */

data WORK.PURCHASE_CLEAN;
    set SASDQREF.PURCHASE;

    ORDER_DATE_MISSING=missing('ORDER DATE'n);
    COMPANY_MISSING=missing(COMPANY);
    CONTACT_MISSING=missing(CONTACT);

    SUPPLIER_NAME_MISSING=
        missing('SUPPLIER NAME'n);

    SUPPLIER_NUMBER_MISSING=
        missing('SUPPLIER NUMBER'n);

    LOCATION_MISSING=
        missing(CITY) or missing(STATE);
run;


/***********************************************************************
 SECTION 3 - CLEANED DATASET RECORD VALIDATION
 ***********************************************************************/

proc sql;
    title "MarketIQ - Cleaned Dataset Record Validation";

    select "SALES_CLEAN" as DATASET length=30,
           count(*) as TOTAL_RECORDS
    from WORK.SALES_CLEAN

    union all

    select "PRODUCT_SALES_CLEAN",
           count(*)
    from WORK.PRODUCT_SALES_CLEAN

    union all

    select "PURCHASE_CLEAN",
           count(*)
    from WORK.PURCHASE_CLEAN;
quit;


/***********************************************************************
 SECTION 4 - POST-CLEANING DATA QUALITY VALIDATION
 ***********************************************************************/

/* 4.1 SALES */

proc sql;
    title "MarketIQ - SALES Data Validation";

    select
        count(*) as TOTAL_RECORDS,
        sum(DATE_MISSING) as MISSING_DATES,
        sum(COMPANY_MISSING) as MISSING_COMPANIES,
        sum(CONTACT_MISSING) as MISSING_CONTACTS,
        sum(LOCATION_MISSING) as MISSING_LOCATIONS
    from WORK.SALES_CLEAN;
quit;


/* 4.2 PURCHASE */

proc sql;
    title "MarketIQ - PURCHASE Data Validation";

    select
        count(*) as TOTAL_RECORDS,
        sum(ORDER_DATE_MISSING) as MISSING_ORDER_DATES,
        sum(SUPPLIER_NAME_MISSING) as MISSING_SUPPLIER_NAMES,
        sum(SUPPLIER_NUMBER_MISSING) as MISSING_SUPPLIER_NUMBERS
    from WORK.PURCHASE_CLEAN;
quit;


/* 4.3 Critical transaction fields */

proc sql;
    title "MarketIQ - Critical Transaction Validation";

    select
        count(*) as TOTAL_RECORDS,
        sum(missing('TOTAL SALES'n)) as MISSING_SALES,
        sum(missing(ID)) as MISSING_IDS
    from WORK.SALES_CLEAN;
quit;


/***********************************************************************
 SECTION 5 - SALES DATE FORMAT INSPECTION
 ***********************************************************************/

proc freq data=WORK.SALES_CLEAN;
    tables DATE / missing;
    title "MarketIQ - Sales Date Format Inspection";
run;


/***********************************************************************
 SECTION 6 - DATE CONVERSION AND PREPARATION
 ***********************************************************************/

data WORK.SALES_DATED;
    set WORK.SALES_CLEAN;

    SALES_DATE=input(strip(DATE), mmddyy10.);
    format SALES_DATE date9.;

    MONTH_DATE=intnx('month', SALES_DATE, 0, 'b');
    format MONTH_DATE monyy7.;

    if missing(SALES_DATE) then DATE_MISSING=1;
    else DATE_MISSING=0;
run;

proc sql;
    title "MarketIQ - Date Conversion Validation";

    select
        count(*) as TOTAL_RECORDS,
        sum(missing(SALES_DATE)) as MISSING_SAS_DATES,
        count(SALES_DATE) as VALID_SAS_DATES
    from WORK.SALES_DATED;
quit;


/***********************************************************************
 SECTION 7 - MONTHLY SALES FEATURE ENGINEERING
 ***********************************************************************/

proc sql;
    create table WORK.MONTHLY_SALES_FEATURES as
    select
        MONTH_DATE,
        count(*) as TRANSACTION_COUNT,

        sum('TOTAL SALES'n)
            as MONTHLY_REVENUE format=comma18.2,

        mean('TOTAL SALES'n)
            as AVG_TRANSACTION_VALUE format=comma18.2,

        min('TOTAL SALES'n)
            as MIN_TRANSACTION_VALUE format=comma18.2,

        max('TOTAL SALES'n)
            as MAX_TRANSACTION_VALUE format=comma18.2

    from WORK.SALES_DATED

    where not missing(SALES_DATE)

    group by MONTH_DATE
    order by MONTH_DATE;
quit;

proc print data=WORK.MONTHLY_SALES_FEATURES noobs;
    title "MarketIQ - Monthly Sales Features";
run;


/***********************************************************************
 SECTION 8 - PRODUCT-LEVEL FEATURE ENGINEERING
 ***********************************************************************/

/*
 Original SALES numeric variable order:
   1. ID
   2. TOTAL SALES
   3. PRODUCT NUMBER

 Original SALES character variable order:
   1. COMPANY
   2. CONTACT
   3. GENDER
   4. ADDRESS
   5. CITY
   6. STATE
   7. PHONE
   8. DATE
   9. PRODUCT CODE
  10. PRODUCT CODE TYPE

 Positional extraction avoids the name-resolution issue.
*/

data WORK.SALES_PRODUCT_BASE;
    set SASDQREF.SALES;

    array numeric_fields {*} _numeric_;
    array character_fields {*} _character_;

    ID_VALUE=numeric_fields[1];
    SALES_VALUE=numeric_fields[2];
    PRODUCT_NUMBER=numeric_fields[3];

    PRODUCT_CODE=character_fields[9];
    PRODUCT_CODE_TYPE=character_fields[10];

    keep ID_VALUE PRODUCT_NUMBER PRODUCT_CODE
         PRODUCT_CODE_TYPE SALES_VALUE;
run;


/* Aggregate at product-number level */

proc sql;
    create table WORK.PRODUCT_FEATURES_BASE as
    select
        PRODUCT_NUMBER,

        count(*) as TRANSACTION_COUNT,

        count(distinct PRODUCT_CODE)
            as DISTINCT_PRODUCT_CODES,

        count(distinct PRODUCT_CODE_TYPE)
            as PRODUCT_TYPE_VARIANTS,

        sum(SALES_VALUE)
            as TOTAL_REVENUE,

        mean(SALES_VALUE)
            as AVG_TRANSACTION_VALUE,

        min(SALES_VALUE)
            as MIN_TRANSACTION_VALUE,

        max(SALES_VALUE)
            as MAX_TRANSACTION_VALUE

    from WORK.SALES_PRODUCT_BASE

    group by PRODUCT_NUMBER;
quit;


/* Revenue contribution */

proc sql;
    create table WORK.PRODUCT_FEATURES as
    select *,
        TOTAL_REVENUE /
        (select sum(TOTAL_REVENUE)
         from WORK.PRODUCT_FEATURES_BASE)
        as REVENUE_CONTRIBUTION format=percent8.2

    from WORK.PRODUCT_FEATURES_BASE
    order by TOTAL_REVENUE desc;
quit;


/* Product validation */

proc sql;
    title "MarketIQ - Product Feature Validation";

    select
        count(*) as PRODUCT_GROUPS,
        sum(TRANSACTION_COUNT) as TOTAL_TRANSACTIONS,
        sum(TOTAL_REVENUE) as TOTAL_REVENUE
            format=comma18.2
    from WORK.PRODUCT_FEATURES;
quit;


/* Top 20 products */

proc print data=WORK.PRODUCT_FEATURES(obs=20) noobs;
    title "MarketIQ - Top 20 Product Performance";
run;


/***********************************************************************
 SECTION 9 - SUPPLIER-LEVEL FEATURE ENGINEERING
 ***********************************************************************/

/*
 Original PURCHASE numeric variable order:
   1. ID
   2. ITEM AMOUNT
   3. PO NUMBER

 Original PURCHASE character variable order:
   1. COMPANY
   2. CONTACT
   3. ADDRESS
   4. ADDRESS2
   5. CITY
   6. STATE
   7. PHONE
   8. ORDER DATE
   9. SUPPLIER NAME
  10. SUPPLIER NUMBER
  11. DEPARTMENT
*/

data WORK.SUPPLIER_BASE;
    set SASDQREF.PURCHASE;

    array numeric_fields {*} _numeric_;
    array character_fields {*} _character_;

    ID_VALUE=numeric_fields[1];
    ITEM_AMOUNT_VALUE=numeric_fields[2];

    SUPPLIER_NAME=
        upcase(compbl(strip(character_fields[9])));

    SUPPLIER_NUMBER=
        strip(character_fields[10]);

    DEPARTMENT_NAME=
        upcase(compbl(strip(character_fields[11])));

    if missing(SUPPLIER_NAME) then
        SUPPLIER_NAME='UNKNOWN';

    keep ID_VALUE SUPPLIER_NAME SUPPLIER_NUMBER
         DEPARTMENT_NAME ITEM_AMOUNT_VALUE;
run;


/* Supplier aggregation */

proc sql;
    create table WORK.SUPPLIER_FEATURES_BASE as
    select
        SUPPLIER_NAME,

        count(*) as TRANSACTION_COUNT,

        count(distinct SUPPLIER_NUMBER)
            as DISTINCT_SUPPLIER_NUMBERS,

        sum(missing(SUPPLIER_NUMBER))
            as MISSING_SUPPLIER_NUMBERS,

        count(distinct DEPARTMENT_NAME)
            as DEPARTMENT_VARIANTS,

        sum(ITEM_AMOUNT_VALUE)
            as TOTAL_PURCHASE_AMOUNT,

        mean(ITEM_AMOUNT_VALUE)
            as AVG_PURCHASE_AMOUNT,

        min(ITEM_AMOUNT_VALUE)
            as MIN_PURCHASE_AMOUNT,

        max(ITEM_AMOUNT_VALUE)
            as MAX_PURCHASE_AMOUNT

    from WORK.SUPPLIER_BASE

    group by SUPPLIER_NAME;
quit;


/* Supplier contribution */

proc sql;
    create table WORK.SUPPLIER_FEATURES as
    select *,
        TOTAL_PURCHASE_AMOUNT /
        (select sum(TOTAL_PURCHASE_AMOUNT)
         from WORK.SUPPLIER_FEATURES_BASE)
        as PURCHASE_CONTRIBUTION format=percent8.2

    from WORK.SUPPLIER_FEATURES_BASE
    order by TOTAL_PURCHASE_AMOUNT desc;
quit;


/* Supplier validation */

proc sql;
    title "MarketIQ - Supplier Feature Validation";

    select
        count(*) as SUPPLIER_GROUPS,
        sum(TRANSACTION_COUNT) as TOTAL_TRANSACTIONS,
        sum(TOTAL_PURCHASE_AMOUNT)
            as TOTAL_PURCHASE_AMOUNT format=comma18.2

    from WORK.SUPPLIER_FEATURES;
quit;


/* Top 20 suppliers */

proc print data=WORK.SUPPLIER_FEATURES(obs=20) noobs;
    title "MarketIQ - Top 20 Supplier Intelligence";
run;


/***********************************************************************
 SECTION 10 - TRANSACTION-LEVEL DATA INTEGRATION
 ***********************************************************************/

proc sql;
    create table WORK.ID_MATCH_VALIDATION as
    select count(*) as MATCHED_IDS
    from WORK.SALES_PRODUCT_BASE as S
    inner join WORK.SUPPLIER_BASE as P
        on S.ID_VALUE=P.ID_VALUE;
quit;


/* Integrated transaction intelligence */

proc sql;
    create table WORK.MARKETIQ_TXN_INTEL as
    select
        S.ID_VALUE as ID,
        S.PRODUCT_NUMBER,
        S.PRODUCT_CODE,
        S.PRODUCT_CODE_TYPE,
        S.SALES_VALUE,
        P.SUPPLIER_NAME,
        P.SUPPLIER_NUMBER,
        P.DEPARTMENT_NAME,
        P.ITEM_AMOUNT_VALUE
    from WORK.SALES_PRODUCT_BASE as S
    inner join WORK.SUPPLIER_BASE as P
        on S.ID_VALUE=P.ID_VALUE;
quit;


/* Integrated dataset validation */

proc sql;
    select
        count(*) as TOTAL_RECORDS,
        count(distinct ID) as UNIQUE_TRANSACTIONS,
        count(distinct PRODUCT_NUMBER) as DISTINCT_PRODUCTS,
        count(distinct SUPPLIER_NAME) as DISTINCT_SUPPLIERS,
        sum(SALES_VALUE) as TOTAL_SALES_REVENUE format=comma18.2,
        sum(ITEM_AMOUNT_VALUE) as TOTAL_PURCHASE_AMOUNT format=comma18.2
    from WORK.MARKETIQ_TXN_INTEL;
quit;


/* Inspect integrated records */

proc print data=WORK.MARKETIQ_TXN_INTEL(obs=20) noobs;
    title "MarketIQ - Integrated Transaction Intelligence";
run;


/***********************************************************************
 SECTION 11 - PRODUCT TYPE PERFORMANCE
 ***********************************************************************/

proc sql;
    create table WORK.PRODUCT_TYPE_PERFORMANCE as
    select
        PRODUCT_CODE_TYPE,
        count(*) as TRANSACTION_COUNT,
        count(distinct PRODUCT_NUMBER) as DISTINCT_PRODUCTS,
        sum(SALES_VALUE) as TOTAL_REVENUE format=comma18.2,
        mean(SALES_VALUE) as AVG_TRANSACTION_VALUE format=comma18.2

    from WORK.SALES_PRODUCT_BASE

    group by PRODUCT_CODE_TYPE
    order by TOTAL_REVENUE desc;
quit;

proc print data=WORK.PRODUCT_TYPE_PERFORMANCE noobs;
    title "MarketIQ - Product Type Performance";
run;


/***********************************************************************
 SECTION 12 - DEPARTMENT PERFORMANCE
 ***********************************************************************/

proc sql;
    create table WORK.DEPARTMENT_PERFORMANCE as
    select
        DEPARTMENT_NAME,
        count(*) as TRANSACTION_COUNT,
        count(distinct SUPPLIER_NAME) as DISTINCT_SUPPLIERS,
        sum(ITEM_AMOUNT_VALUE)
            as TOTAL_PURCHASE_AMOUNT format=comma18.2,
        mean(ITEM_AMOUNT_VALUE)
            as AVG_PURCHASE_AMOUNT format=comma18.2

    from WORK.SUPPLIER_BASE

    group by DEPARTMENT_NAME
    order by TOTAL_PURCHASE_AMOUNT desc;
quit;

proc print data=WORK.DEPARTMENT_PERFORMANCE noobs;
    title "MarketIQ - Department Performance";
run;


/***********************************************************************
 SECTION 13 - TRANSACTION OUTLIER REVIEW
 ***********************************************************************/

/* Flag unusually large sales transactions.
   This is an investigation flag, not an automatic deletion rule. */

proc univariate data=WORK.SALES_PRODUCT_BASE noprint;
    var SALES_VALUE;
    output out=WORK.SALES_OUTLIER_LIMITS
        pctlpts=25 75
        pctlpre=P_;
run;

data WORK.SALES_OUTLIER_LIMITS;
    set WORK.SALES_OUTLIER_LIMITS;

    IQR=P_75-P_25;
    UPPER_OUTLIER_LIMIT=P_75+(1.5*IQR);

    keep P_25 P_75 IQR UPPER_OUTLIER_LIMIT;
run;

proc sql;
    create table WORK.SALES_OUTLIER_REVIEW as
    select
        S.ID_VALUE as ID,
        S.PRODUCT_NUMBER,
        S.PRODUCT_CODE,
        S.SALES_VALUE,
        L.UPPER_OUTLIER_LIMIT

    from WORK.SALES_PRODUCT_BASE as S,
         WORK.SALES_OUTLIER_LIMITS as L

    where S.SALES_VALUE > L.UPPER_OUTLIER_LIMIT

    order by S.SALES_VALUE desc;
quit;

proc print data=WORK.SALES_OUTLIER_REVIEW(obs=30) noobs;
    title "MarketIQ - Unusually Large Transactions for Review";
run;



/***************************************************************
 SECTION 14 - FINAL DATASET SUMMARY
***************************************************************/

proc sql;
    title "MarketIQ - Final Data Preparation Summary";

    select "SALES_CLEAN" as DATASET length=45,
           count(*) as RECORDS
    from WORK.SALES_CLEAN

    union all

    select "PRODUCT_SALES_CLEAN",
           count(*)
    from WORK.PRODUCT_SALES_CLEAN

    union all

    select "PURCHASE_CLEAN",
           count(*)
    from WORK.PURCHASE_CLEAN

    union all

    select "SALES_DATED",
           count(*)
    from WORK.SALES_DATED

    union all

    select "MONTHLY_SALES_FEATURES",
           count(*)
    from WORK.MONTHLY_SALES_FEATURES

    union all

    select "SALES_PRODUCT_BASE",
           count(*)
    from WORK.SALES_PRODUCT_BASE

    union all

    select "PRODUCT_FEATURES",
           count(*)
    from WORK.PRODUCT_FEATURES

    union all

    select "SUPPLIER_BASE",
           count(*)
    from WORK.SUPPLIER_BASE

    union all

    select "SUPPLIER_FEATURES",
           count(*)
    from WORK.SUPPLIER_FEATURES

    union all

    select "MARKETIQ_TXN_INTEL",
           count(*)
    from WORK.MARKETIQ_TXN_INTEL;

quit;


/***************************************************************
 SECTION 15 - FINAL CRITICAL VALIDATION
***************************************************************/

proc sql noprint;

    select count(*)
    into :SALES_RECORDS
    from WORK.SALES_CLEAN;

    select count(*)
    into :PURCHASE_RECORDS
    from WORK.PURCHASE_CLEAN;

    select count(*)
    into :PRODUCT_GROUPS
    from WORK.PRODUCT_FEATURES;

    select count(*)
    into :SUPPLIER_GROUPS
    from WORK.SUPPLIER_FEATURES;

    select count(*)
    into :INTEGRATED_RECORDS
    from WORK.MARKETIQ_TXN_INTEL;

    select count(distinct ID)
    into :INTEGRATED_UNIQUE_IDS
    from WORK.MARKETIQ_TXN_INTEL;

quit;


data WORK.MARKETIQ_FINAL_VALIDATION;

    SALES_RECORDS = &SALES_RECORDS;
    PURCHASE_RECORDS = &PURCHASE_RECORDS;
    PRODUCT_GROUPS = &PRODUCT_GROUPS;
    SUPPLIER_GROUPS = &SUPPLIER_GROUPS;
    INTEGRATED_RECORDS = &INTEGRATED_RECORDS;
    INTEGRATED_UNIQUE_IDS = &INTEGRATED_UNIQUE_IDS;

run;


proc print data=WORK.MARKETIQ_FINAL_VALIDATION noobs;
    title "MarketIQ - Final Critical Validation";
run;


/***************************************************************
 END OF PROGRAM
 MARKETIQ - CUSTOMER & MARKETING DECISION INTELLIGENCE
***************************************************************/
