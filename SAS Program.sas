
/* ============================================
   MarketIQ - Step 1: SAS Environment Discovery
   ============================================ */

/* 1. Display all assigned SAS libraries */
libname _all_ list;


/* 2. List available libraries and their engines */
proc sql;
    title "MarketIQ - Available SAS Libraries";

    select
        libname,
        engine,
        path
    from dictionary.libnames
    order by libname;

quit;


/* 3. Discover all accessible datasets */
proc sql;
    title "MarketIQ - Available SAS Datasets";

    select
        libname,
        memname,
        memtype,
        nobs,
        crdate
    from dictionary.tables
    where memtype = 'DATA'
    order by libname, memname;

quit;


/* 4. Check WORK library configuration */
proc options option=work;
run;

title;
