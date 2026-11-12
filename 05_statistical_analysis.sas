
/* ============================================================
   PROJECT: MarketIQ
   MODULE: Statistical & Predictive Analytics
   PROGRAM: 05_statistical_analysis.sas

   ANALYSES:
   1. Prepare integrated analysis dataset
   2. Descriptive statistics by product code type
   3. Welch two-sample t-test
   4. Chi-square test of association
   5. One-way ANOVA with Levene's test
   6. Final dataset validation

   DATA SOURCES:
   SASDQREF.SALES
   SASDQREF.PURCHASE

   ============================================================ */


/* STEP 1: IDENTIFY SOURCE VARIABLE NAMES */

/* Metadata lookup avoids problems with SAS variables
   containing spaces, such as TOTAL SALES. */

proc sql noprint;

    select nliteral(name)
    into :sales_amount_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'SALES'
      and upcase(strip(name)) = 'TOTAL SALES';

    select nliteral(name)
    into :product_type_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'SALES'
      and upcase(strip(name)) = 'PRODUCT CODE TYPE';

    select nliteral(name)
    into :department_var trimmed
    from dictionary.columns
    where libname = 'SASDQREF'
      and memname = 'PURCHASE'
      and upcase(strip(name)) = 'DEPARTMENT';

quit;


/* STEP 2: CREATE INTEGRATED ANALYSIS DATASET */

/* Join using the validated common transaction ID.
   One output row represents one matched transaction. */

proc sql;

    create table work.marketiq_analysis as

    select
        s.ID,
        s.&sales_amount_var as SALES_AMOUNT,
        s.&product_type_var as PRODUCT_CODE_TYPE,
        p.&department_var as DEPARTMENT

    from SASDQREF.SALES as s

    inner join SASDQREF.PURCHASE as p
        on s.ID = p.ID;

quit;


/* STEP 3: CREATE ANALYSIS GROUPS */

/* Log transformation is used because sales values
   are strongly right-skewed. */

data work.marketiq_analysis;

    set work.marketiq_analysis;

    if SALES_AMOUNT > 0 then
        LOG_SALES = log(SALES_AMOUNT);
    else
        LOG_SALES = .;

    length DEPARTMENT_GROUP $10;

    if strip(DEPARTMENT) = "A" then
        DEPARTMENT_GROUP = "A";

    else if strip(DEPARTMENT) = "I" then
        DEPARTMENT_GROUP = "I";

    else
        DEPARTMENT_GROUP = "OTHER";

run;


/* STEP 4: CHECK GROUP DISTRIBUTIONS */

/* Inspect group sizes before performing inferential tests. */

title "MarketIQ - Product Code Type Distribution";

proc freq data=work.marketiq_analysis;

    tables PRODUCT_CODE_TYPE / missing;

run;


title "MarketIQ - Department Group Distribution";

proc freq data=work.marketiq_analysis;

    tables DEPARTMENT_GROUP / missing;

run;


/* STEP 5: DESCRIPTIVE STATISTICS BY PRODUCT TYPE */

title "MarketIQ - Sales Statistics by Product Code Type";

proc means data=work.marketiq_analysis
    n nmiss mean median std min max maxdec=2;

    class PRODUCT_CODE_TYPE;

    var SALES_AMOUNT LOG_SALES;

run;


/* STEP 6: WELCH TWO-SAMPLE T-TEST */

/* Compare log-transformed sales for product types A and I.
   Welch's test uses the Satterthwaite method and does not
   require equal population variances. */

title "MarketIQ - Welch T-Test: Product Types A vs I";

proc ttest data=work.marketiq_analysis;

    where PRODUCT_CODE_TYPE in ("A", "I")
      and not missing(LOG_SALES);

    class PRODUCT_CODE_TYPE;

    var LOG_SALES;

run;


/* STEP 7: CHI-SQUARE TEST OF ASSOCIATION */

/* Examine the association between department group
   and product code type A or I.

   Rare product types are excluded from this test. */

title "MarketIQ - Chi-Square: Department vs Product Type";

proc freq data=work.marketiq_analysis;

    where PRODUCT_CODE_TYPE in ("A", "I")
      and not missing(DEPARTMENT_GROUP);

    tables DEPARTMENT_GROUP * PRODUCT_CODE_TYPE
        / chisq expected cellchi2;

run;


/* STEP 8: ONE-WAY ANOVA */

/* Compare mean log sales across department groups.
   Levene's test checks the equal-variance assumption. */

title "MarketIQ - ANOVA: Sales Across Departments";

proc glm data=work.marketiq_analysis;

    where not missing(LOG_SALES)
      and not missing(DEPARTMENT_GROUP);

    class DEPARTMENT_GROUP;

    model LOG_SALES = DEPARTMENT_GROUP;

    means DEPARTMENT_GROUP / hovtest=levene;

run;

quit;


/* STEP 9: FINAL DATASET VALIDATION */

title "MarketIQ - Statistical Analysis Dataset Validation";

proc sql;

    select
        count(*) as TOTAL_RECORDS,
        count(distinct ID) as UNIQUE_RECORDS,
        sum(missing(SALES_AMOUNT)) as MISSING_SALES,
        sum(missing(LOG_SALES)) as MISSING_LOG_SALES,
        sum(missing(PRODUCT_CODE_TYPE)) as MISSING_PRODUCT_TYPES,
        sum(missing(DEPARTMENT)) as MISSING_DEPARTMENTS,
        mean(SALES_AMOUNT) as AVERAGE_SALES format=comma18.2

    from work.marketiq_analysis;

quit;


/* END */

title;

%put NOTE: MarketIQ statistical analysis completed.;
