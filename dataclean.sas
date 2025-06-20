/******************************************************************************
* Program Name: MedTrace_002_Data_Cleaning_Revised.sas
* Study: RAPID-WATER-FLOW Trial (MedTrace-002)
* Purpose: Comprehensive data cleaning program to flag data entry issues
* Author: Clinical Research Statistician
* Date: Current Date
* 
* REVISED to work with actual data structure
******************************************************************************/

%let study = MedTrace-002;
%let libpath = C:\Users\SandeepSaha\OneDrive - Cardiovascular Clinical Science Foundation\MedTrace\Data\19_MedTrace-002_SASExtract_18-06-2025;
%let outpath = C:\Users\SandeepSaha\OneDrive - Cardiovascular Clinical Science Foundation\MedTrace\Data\cleaned;

/* Define libraries */
libname raw "&libpath";
libname clean "&outpath";

/* Create format library for the study */
proc format;
    /* Yes/No formats */
    value $ynfmt
        'YES' = 'Yes'
        'NO' = 'No'
        ' ' = 'Missing';
    
    /* Sex format */
    value $sexfmt
        'MALE' = 'Male'
        'FEMALE' = 'Female'
        'UNKNOWN' = 'Unknown'
        ' ' = 'Missing';
run;

/******************************************************************************
* 1. DEMOGRAPHICS (DM) DATA CLEANING
******************************************************************************/
data clean.dm_clean dm_issues;
    set raw.dm;
    length issue_flag $500 USUBJID $50;
    issue_flag = '';
    
    /* Create USUBJID from SUBJID */
    USUBJID = SUBJID;
    
    /* Check for missing required fields */
    if missing(SUBJID) then issue_flag = catx('; ', issue_flag, 'Missing Subject ID');
    if missing(SEX) then issue_flag = catx('; ', issue_flag, 'Missing Sex');
    if missing(RACE) then issue_flag = catx('; ', issue_flag, 'Missing Race');
    if missing(ETHNIC) then issue_flag = catx('; ', issue_flag, 'Missing Ethnicity');
    
    /* Calculate age from birth date if available */
    if not missing(BRTHDAT) then do;
        /* Convert character date to SAS date */
        if index(BRTHDAT, '/') > 0 then do;
            AGE = floor((today() - input(BRTHDAT, anydtdte32.))/365.25);
        end;
        else if length(compress(BRTHDAT)) = 4 then do;
            /* Only year provided */
            AGE = year(today()) - input(BRTHDAT, 4.);
        end;
        
        /* Age range checks (18-85 per protocol) */
        if not missing(AGE) then do;
            if AGE < 18 then issue_flag = catx('; ', issue_flag, 'Age < 18 (Below inclusion criteria)');
            if AGE > 85 then issue_flag = catx('; ', issue_flag, 'Age > 85 (Exceeds inclusion criteria)');
        end;
    end;
    else do;
        issue_flag = catx('; ', issue_flag, 'Birth date missing - cannot calculate age');
    end;
    
    /* Check for screen failures */
/*    if DMRIYN = 'NO' then issue_flag = catx('; ', issue_flag, 'Screen failure');*/
    
    /* Check WOCBP consistency */
    if SEX = 'MALE' and CHILDPOT = 'YES' then 
        issue_flag = catx('; ', issue_flag, 'Male subject marked as childbearing potential');
    
    if issue_flag ne '' then output dm_issues;
    output clean.dm_clean;
run;

/* Report demographics issues */
proc print data=dm_issues(obs=20);
    var USUBJID SITE SEX CHILDPOT ETHNIC RACE issue_flag;
    title "Demographics Data Issues (First 20)";
run;

/******************************************************************************
* 2. VITAL SIGNS (VS) DATA CLEANING
******************************************************************************/
data clean.vs_clean vs_issues;
    set raw.vs;
    length issue_flag $500 USUBJID $50;
    issue_flag = '';
    
    /* Create USUBJID - extract from PATIENT field if needed */
    if index(PATIENT, '-') > 0 then do;
        USUBJID = scan(PATIENT, -1, ' ');
    end;
    
    /* Check if VS performed */
    if VSPERF = 'NO' and missing(VSREASND) then 
        issue_flag = catx('; ', issue_flag, 'VS not performed but no reason given');
    
    /* Vital signs range checks when performed */
    if VSPERF = 'YES' then do;
        /* Temperature checks */
        if not missing(TEMP_VSORRES) then do;
            /* Handle both Celsius and Fahrenheit */
            if TEMP_VSORRES > 50 then do; /* Likely Fahrenheit */
                TEMP_C = (TEMP_VSORRES - 32) * 5/9;
                if TEMP_C < 35 or TEMP_C > 42 then
                    issue_flag = catx('; ', issue_flag, 'Temperature out of range');
            end;
            else do; /* Celsius */
                if TEMP_VSORRES < 35 or TEMP_VSORRES > 42 then
                    issue_flag = catx('; ', issue_flag, 'Temperature out of range (35-42C)');
            end;
        end;
        
        /* Blood pressure checks */
        if not missing(SYSBP_VSORRES) then do;
            if SYSBP_VSORRES < 70 or SYSBP_VSORRES > 250 then
                issue_flag = catx('; ', issue_flag, 'Systolic BP out of range (70-250 mmHg)');
        end;
        else issue_flag = catx('; ', issue_flag, 'Systolic BP missing when VS performed');
        
        if not missing(DIABP_VSORRES) then do;
            if DIABP_VSORRES < 40 or DIABP_VSORRES > 150 then
                issue_flag = catx('; ', issue_flag, 'Diastolic BP out of range (40-150 mmHg)');
        end;
        else issue_flag = catx('; ', issue_flag, 'Diastolic BP missing when VS performed');
        
        /* BP logic check */
        if not missing(SYSBP_VSORRES) and not missing(DIABP_VSORRES) then do;
            if SYSBP_VSORRES <= DIABP_VSORRES then
                issue_flag = catx('; ', issue_flag, 'Systolic BP <= Diastolic BP');
        end;
        
        /* Heart rate checks */
        if not missing(PULSE_VSORRES) then do;
            if PULSE_VSORRES < 30 or PULSE_VSORRES > 200 then
                issue_flag = catx('; ', issue_flag, 'Heart rate out of range (30-200 bpm)');
        end;
        else issue_flag = catx('; ', issue_flag, 'Heart rate missing when VS performed');
        
        /* Check for missing date/time */
        if missing(VSDAT) then issue_flag = catx('; ', issue_flag, 'VS date missing');
        if missing(VSTIM) then issue_flag = catx('; ', issue_flag, 'VS time missing');
    end;
    
    if issue_flag ne '' then output vs_issues;
    output clean.vs_clean;
run;

/* Report vital signs issues */
proc print data=vs_issues(obs=20);
    var USUBJID VSDAT VSTIM SYSBP_VSORRES DIABP_VSORRES PULSE_VSORRES issue_flag;
    title "Vital Signs Data Issues (First 20)";
run;

/* Additional vital signs datasets */

/* 2a. Pre-procedure vital signs (VSPRE) */
data clean.vspre_clean vspre_issues;
    set raw.vspre;
    length issue_flag $500 USUBJID $50;
    issue_flag = '';

    if index(PATIENT, '-') > 0 then USUBJID = scan(PATIENT, -1, ' ');

    if VSPERF = 'NO' and missing(VSREASND) then
        issue_flag = catx('; ', issue_flag, 'VS not performed but no reason given');

    if VSPERF = 'YES' then do;
        if not missing(TEMP_VSORRES) then do;
            if TEMP_VSORRES > 50 then do;
                TEMP_C = (TEMP_VSORRES - 32) * 5/9;
                if TEMP_C < 35 or TEMP_C > 42 then
                    issue_flag = catx('; ', issue_flag, 'Temperature out of range');
            end;
            else if TEMP_VSORRES < 35 or TEMP_VSORRES > 42 then
                issue_flag = catx('; ', issue_flag, 'Temperature out of range (35-42C)');
        end;

        if not missing(SYSBP_VSORRES) then do;
            if SYSBP_VSORRES < 70 or SYSBP_VSORRES > 250 then
                issue_flag = catx('; ', issue_flag, 'Systolic BP out of range (70-250 mmHg)');
        end;
        else issue_flag = catx('; ', issue_flag, 'Systolic BP missing when VS performed');

        if not missing(DIABP_VSORRES) then do;
            if DIABP_VSORRES < 40 or DIABP_VSORRES > 150 then
                issue_flag = catx('; ', issue_flag, 'Diastolic BP out of range (40-150 mmHg)');
        end;
        else issue_flag = catx('; ', issue_flag, 'Diastolic BP missing when VS performed');

        if not missing(SYSBP_VSORRES) and not missing(DIABP_VSORRES) then do;
            if SYSBP_VSORRES <= DIABP_VSORRES then
                issue_flag = catx('; ', issue_flag, 'Systolic BP <= Diastolic BP');
        end;

        if not missing(PULSE_VSORRES) then do;
            if PULSE_VSORRES < 30 or PULSE_VSORRES > 200 then
                issue_flag = catx('; ', issue_flag, 'Heart rate out of range (30-200 bpm)');
        end;
        else issue_flag = catx('; ', issue_flag, 'Heart rate missing when VS performed');

        if missing(VSDAT) then issue_flag = catx('; ', issue_flag, 'VS date missing');
        if missing(VSTIM) then issue_flag = catx('; ', issue_flag, 'VS time missing');
    end;

    if issue_flag ne '' then output vspre_issues;
    output clean.vspre_clean;
run;

proc print data=vspre_issues(obs=20);
    var USUBJID VSDAT VSTIM SYSBP_VSORRES DIABP_VSORRES PULSE_VSORRES issue_flag;
    title "VSPRE Data Issues (First 20)";
run;

/* 2b. Post-procedure vital signs (VSPOST) */
data clean.vspost_clean vspost_issues;
    set raw.vspost;
    length issue_flag $500 USUBJID $50;
    issue_flag = '';

    if index(PATIENT, '-') > 0 then USUBJID = scan(PATIENT, -1, ' ');

    if STRESS_VSPERF = 'NO' and missing(STRESS_VSREASND) then
        issue_flag = catx('; ', issue_flag, 'VS not performed but no reason given');

    if STRESS_VSPERF = 'YES' then do;
        if not missing(STRESS_TEMP_VSORRES) then do;
            if STRESS_TEMP_VSORRES > 50 then do;
                TEMP_C = (STRESS_TEMP_VSORRES - 32) * 5/9;
                if TEMP_C < 35 or TEMP_C > 42 then
                    issue_flag = catx('; ', issue_flag, 'Temperature out of range');
            end;
            else if STRESS_TEMP_VSORRES < 35 or STRESS_TEMP_VSORRES > 42 then
                issue_flag = catx('; ', issue_flag, 'Temperature out of range (35-42C)');
        end;

        if not missing(STRESS_SYSBP_VSORRES) then do;
            if STRESS_SYSBP_VSORRES < 70 or STRESS_SYSBP_VSORRES > 250 then
                issue_flag = catx('; ', issue_flag, 'Systolic BP out of range (70-250 mmHg)');
        end;
        else issue_flag = catx('; ', issue_flag, 'Systolic BP missing when VS performed');

        if not missing(STRESS_DIABP_VSORRES) then do;
            if STRESS_DIABP_VSORRES < 40 or STRESS_DIABP_VSORRES > 150 then
                issue_flag = catx('; ', issue_flag, 'Diastolic BP out of range (40-150 mmHg)');
        end;
        else issue_flag = catx('; ', issue_flag, 'Diastolic BP missing when VS performed');

        if not missing(STRESS_SYSBP_VSORRES) and not missing(STRESS_DIABP_VSORRES) then do;
            if STRESS_SYSBP_VSORRES <= STRESS_DIABP_VSORRES then
                issue_flag = catx('; ', issue_flag, 'Systolic BP <= Diastolic BP');
        end;

        if not missing(STRESS_PULSE_VSORRES) then do;
            if STRESS_PULSE_VSORRES < 30 or STRESS_PULSE_VSORRES > 200 then
                issue_flag = catx('; ', issue_flag, 'Heart rate out of range (30-200 bpm)');
        end;
        else issue_flag = catx('; ', issue_flag, 'Heart rate missing when VS performed');

        if missing(STRESS_VSDAT) then issue_flag = catx('; ', issue_flag, 'VS date missing');
        if missing(STRESS_VSTIM) then issue_flag = catx('; ', issue_flag, 'VS time missing');
    end;

    if issue_flag ne '' then output vspost_issues;
    output clean.vspost_clean;
run;

proc print data=vspost_issues(obs=20);
    var USUBJID STRESS_VSDAT STRESS_VSTIM STRESS_SYSBP_VSORRES STRESS_DIABP_VSORRES STRESS_PULSE_VSORRES issue_flag;
    title "VSPOST Data Issues (First 20)";
run;

/******************************************************************************
* 3. ECG (EG) DATA CLEANING
******************************************************************************/
data clean.eg_clean eg_issues;
    set raw.eg;
    length issue_flag $500 USUBJID $50;
    issue_flag = '';
    
    /* Extract USUBJID from PATIENT field */
    if index(PATIENT, '-') > 0 then do;
        USUBJID = scan(PATIENT, -1, ' ');
    end;
    
    /* Check for missing required fields */
    if missing(EGDAT) then issue_flag = catx('; ', issue_flag, 'ECG date missing');
    if missing(EGTIM) then issue_flag = catx('; ', issue_flag, 'ECG time missing');
    
    /* Check if ECG interpretation is abnormal */
    if index(upcase(EGCNOVR), 'ABNORMAL') > 0 then 
        issue_flag = catx('; ', issue_flag, 'Abnormal ECG - requires review');
    
    if issue_flag ne '' then output eg_issues;
    output clean.eg_clean;
run;

/******************************************************************************
* 4. MEDICAL HISTORY (MH) DATA CLEANING
******************************************************************************/
data clean.mh_clean mh_issues;
    set raw.mh;
    length issue_flag $500 USUBJID $50;
    issue_flag = '';
    
    /* Extract USUBJID from PATIENT field */
    if index(PATIENT, '-') > 0 then do;
        USUBJID = scan(PATIENT, -1, ' ');
    end;
    
    /* Check for missing required fields */
    if missing(MHTERM) then issue_flag = catx('; ', issue_flag, 'Medical history term missing');
    if missing(MHCAT) then issue_flag = catx('; ', issue_flag, 'Medical history category missing');
    
    /* Date logic checks */
    if not missing(MHSTDAT) and not missing(MHENDAT) then do;
        if input(MHSTDAT, anydtdte32.) > input(MHENDAT, anydtdte32.) then
            issue_flag = catx('; ', issue_flag, 'Start date after end date');
    end;
    
    /* Check ongoing status consistency */
    if MHONGO = 'YES' and not missing(MHENDAT) then
        issue_flag = catx('; ', issue_flag, 'Marked as ongoing but has end date');
    
    if MHONGO = 'NO' and missing(MHENDAT) then
        issue_flag = catx('; ', issue_flag, 'Not ongoing but missing end date');
    
    if issue_flag ne '' then output mh_issues;
    output clean.mh_clean;
run;

/******************************************************************************
* 5. ADVERSE EVENTS (AE) DATA CLEANING
******************************************************************************/
data clean.ae_clean ae_issues;
    set raw.ae;
    length issue_flag $500 USUBJID $50;
    issue_flag = '';
    
    /* Extract USUBJID from PATIENT field */
    if index(PATIENT, '-') > 0 then do;
        USUBJID = scan(PATIENT, -1, ' ');
    end;
    
    /* Check for missing required fields */
    if missing(AETERM) then issue_flag = catx('; ', issue_flag, 'AE term missing');
    if missing(AESTDAT) then issue_flag = catx('; ', issue_flag, 'AE start date missing');
    
    /* Date/time logic checks */
    if not missing(AESTDAT) and not missing(AEENDAT) then do;
        if input(AESTDAT, anydtdte32.) > input(AEENDAT, anydtdte32.) then
            issue_flag = catx('; ', issue_flag, 'AE start date after end date');
    end;
    
    /* Check SAE consistency */
    if AESER = 'YES' then do; /* Serious AE */
        if missing(SAEREAS) then
            issue_flag = catx('; ', issue_flag, 'SAE marked but no seriousness criteria');
    end;
    
    /* Check relationship to study drug */
    if missing(AEREL) and missing(AERELPR) and missing(AERELUD) and missing(AERELAD) then 
        issue_flag = catx('; ', issue_flag, 'Relationship to study drug missing');
    

    
    if issue_flag ne '' then output ae_issues;
    output clean.ae_clean;
run;

/******************************************************************************
* 6. CONCOMITANT MEDICATIONS (CM) DATA CLEANING
******************************************************************************/
data clean.cm_clean cm_issues;
    set raw.cm;
    length issue_flag $500 USUBJID $50;
    issue_flag = '';
    
    /* Extract USUBJID from PATIENT field */
    if index(PATIENT, '-') > 0 then do;
        USUBJID = scan(PATIENT, -1, ' ');
    end;
    
    /* Check for missing required fields */
    if missing(CMTRT) then issue_flag = catx('; ', issue_flag, 'Medication name missing');
    if missing(CMSTDAT) then issue_flag = catx('; ', issue_flag, 'Start date missing');
    
    /* Date logic checks */
    if not missing(CMSTDAT) and not missing(CMENDAT) then do;
        if input(CMSTDAT, anydtdte32.) > input(CMENDAT, anydtdte32.) then
            issue_flag = catx('; ', issue_flag, 'CM start date after end date');
    end;
    
    /* Check ongoing status */
    if CMONGO = 'YES' and not missing(CMENDAT) then
        issue_flag = catx('; ', issue_flag, 'Marked as ongoing but has end date');
    
    /* Check dose information */
    if missing(CMDOSE) then issue_flag = catx('; ', issue_flag, 'Dose missing');
    if missing(CMDOSU) then issue_flag = catx('; ', issue_flag, 'Dose unit missing');
    
    if issue_flag ne '' then output cm_issues;
    output clean.cm_clean;
run;

/******************************************************************************
* 7. PROTOCOL DEVIATIONS (DV) DATA CLEANING
******************************************************************************/
data clean.dv_clean dv_issues;
    set raw.dv;
    length issue_flag $500 USUBJID $50;
    issue_flag = '';
    
    /* Use SUBJID as USUBJID */
    USUBJID = SUBJID;
    
    /* Check for missing required fields */
    if missing(DVTERM) and missing(DVEXPL) then 
        issue_flag = catx('; ', issue_flag, 'Deviation description missing');
    if missing(DVDAT) then issue_flag = catx('; ', issue_flag, 'Deviation date missing');
    
    /* Check for volume-related deviations (common in this study) */
    if index(upcase(DVEXPL), '20 ML') > 0 and index(upcase(DVEXPL), '35 ML') > 0 then
        issue_flag = catx('; ', issue_flag, 'Volume deviation - incorrect infusion volume');
    
    /* Check for QC-related deviations */
    if index(upcase(DVEXPL), 'QC') > 0 then
        issue_flag = catx('; ', issue_flag, 'QC procedure deviation');
    
    if issue_flag ne '' then output dv_issues;
    output clean.dv_clean;
run;

/******************************************************************************
* 8. EXPOSURE (EX) DATA CLEANING - 15O-H2O Administration
******************************************************************************/
data clean.ex_clean ex_issues;
    set raw.ex;
    length issue_flag $500 USUBJID $50;
    issue_flag = '';
    
    /* Extract USUBJID from PATIENT field */
    if index(PATIENT, '-') > 0 then do;
        USUBJID = scan(PATIENT, -1, ' ');
    end;
    
    /* Check for required administration info */
    if missing(EXSTDAT) then issue_flag = catx('; ', issue_flag, 'Dose date missing');
    if missing(EXSTTIM) then issue_flag = catx('; ', issue_flag, 'Dose time missing');
    
    /* Check for rest/stress indicators */
    if missing(EXCAT) and missing(EXTRT) then 
        issue_flag = catx('; ', issue_flag, 'Cannot determine if rest or stress dose');
    
    /* Check QC status */
    if index(upcase(EXORRES), 'FAIL') > 0 then
        issue_flag = catx('; ', issue_flag, 'QC failure noted');
    
    if issue_flag ne '' then output ex_issues;
    output clean.ex_clean;
run;

/******************************************************************************
* SUMMARY REPORT OF ALL DATA ISSUES
******************************************************************************/

/* Count issues by domain */
proc sql;
    create table issue_summary as
    select 'DM' as domain, count(*) as issue_count from dm_issues
    union
    select 'VS', count(*) from vs_issues
    union
    select 'VSPRE', count(*) from vspre_issues
    union
    select 'VSPOST', count(*) from vspost_issues
    union
    select 'EG', count(*) from eg_issues
    union
    select 'MH', count(*) from mh_issues
    union
    select 'AE', count(*) from ae_issues
    union
    select 'CM', count(*) from cm_issues
    union
    select 'DV', count(*) from dv_issues
    union
    select 'EX', count(*) from ex_issues
    order by issue_count desc;
quit;

proc print data=issue_summary;
    title "Summary of Data Issues by Domain";
run;

/* Create summary statistics */
proc sql;
    create table data_quality_summary as
    select 'Total Records Processed' as Metric, 
           sum(count) as Count from
           (select count(*) as count from raw.dm
            union select count(*) from raw.vs
             union select count(*) from raw.vspre
             union select count(*) from raw.vspost
            union select count(*) from raw.eg
            union select count(*) from raw.mh
            union select count(*) from raw.ae
            union select count(*) from raw.cm
            union select count(*) from raw.dv
            union select count(*) from raw.ex)
    union
    select 'Total Issues Found', sum(issue_count) from issue_summary
    union
    select 'Screen Failures', count(*) from raw.dm where DMRIYN = 'NO';
quit;

proc print data=data_quality_summary;
    title "Data Quality Summary";
run;

/* Export key issues to Excel */
proc export data=issue_summary
    outfile="&outpath\MedTrace_002_Issue_Summary_&sysdate9..xlsx"
    dbms=xlsx replace;
    sheet="Summary";
run;

/* Create a combined issues report for review */
data all_issues_report;
    length domain $10 USUBJID $50 issue_description $500;
    set dm_issues(in=a keep=USUBJID issue_flag)
        vs_issues(in=b keep=USUBJID issue_flag)
        eg_issues(in=c keep=USUBJID issue_flag)
         vspre_issues(in=bp keep=USUBJID issue_flag)
         vspost_issues(in=bq keep=USUBJID issue_flag)
        mh_issues(in=d keep=USUBJID issue_flag)
        ae_issues(in=e keep=USUBJID issue_flag)
        cm_issues(in=f keep=USUBJID issue_flag)
        dv_issues(in=g keep=USUBJID issue_flag)
        ex_issues(in=h keep=USUBJID issue_flag);
    
    if a then domain = 'DM';
    else if b then domain = 'VS';
     else if bp then domain = 'VSPRE';
     else if bq then domain = 'VSPOST';
    else if c then domain = 'EG';
    else if d then domain = 'MH';
    else if e then domain = 'AE';
    else if f then domain = 'CM';
    else if g then domain = 'DV';
    else if h then domain = 'EX';
    
    issue_description = issue_flag;
    drop issue_flag;
run;

/* Sort and export detailed issues */
proc sort data=all_issues_report;
    by domain USUBJID;
run;

proc export data=all_issues_report
    outfile="&outpath\MedTrace_002_Detailed_Issues_&sysdate9..xlsx"
    dbms=xlsx replace;
    sheet="Detailed_Issues";
run;

/* Final log */
%put NOTE: Data cleaning completed for MedTrace-002;
%put NOTE: Issues summary saved to &outpath;
%put NOTE: Total domains processed: 10;

/******************************************************************************
* END OF PROGRAM
******************************************************************************/
