/*************************************************************************
* Convert "numeric-looking" character variables to numeric, in place
*   -- Accepts + / - signs, decimals, or blanks
*   -- Treats NA, N/A, NULL (any case) as missing (.)
*   -- Leaves a variable unchanged if any non-numeric text is present
* Folder: 19_MedTrace-002_SASExtract_18-06-2025
*************************************************************************/

/* 1. Point the library to your extract folder                          */
libname med
  "C:\Users\SandeepSaha\OneDrive - Cardiovascular Clinical Science Foundation\MedTrace\Data\19_MedTrace-002_SASExtract_18-06-2025";

/* 2. List ONLY the data sets you want processed, separated by spaces   */
%let dsnlist = VS;   /* edit this list */

/* 3. Macro: loop through each named data set and flip char->numeric    */
%macro char2num(lib=med, list=&dsnlist);

  %local i dsn;
  %do i = 1 %to %sysfunc(countw(&list));
    %let dsn = %scan(&list,&i);

    /* Get character variables for this dataset */
    proc sql noprint;
      select name
        into :charvars separated by ' '
      from dictionary.columns
      where libname = upcase("&lib")
        and memname = upcase("&dsn")
        and type = 'char';
    quit;

    %if %symexist(charvars) and %length(&charvars) > 0 %then %do;
      
      /* Test each character variable to see if it's all numeric */
      data _null_;
        set &lib..&dsn end=eof;
        
        %local j varname;
        %do j = 1 %to %sysfunc(countw(&charvars));
          %let varname = %scan(&charvars, &j);
          
          retain is_numeric_&j 1;
          
          /* Check if this value is numeric */
          if not missing(&varname) then do;
            _test_val = strip(&varname);
            if upcase(_test_val) not in ('NA','N/A','ND') then do;
              if not prxmatch('/^[\s]*[\+\-]?[\d]*\.?[\d]*[\s]*$/', _test_val) or 
                 (prxmatch('/^[\s]*$/', _test_val)) then do;
                is_numeric_&j = 0;
              end;
            end;
          end;
        %end;
        
        if eof then do;
          %do j = 1 %to %sysfunc(countw(&charvars));
            call symputx("convert_&j", is_numeric_&j);
          %end;
        end;
      run;

      /* Now create new dataset with converted variables */
      data &lib..&dsn;
        set &lib..&dsn;
        
        %do j = 1 %to %sysfunc(countw(&charvars));
          %let varname = %scan(&charvars, &j);
          
          %if &&convert_&j = 1 %then %do;
            /* Convert this variable */
            if not missing(&varname) then do;
              _test_val = strip(&varname);
              if upcase(_test_val) in ('NA','N/A','NULL') then do;
                _num_&j = .;
              end;
              else if _test_val ne '' then do;
                _num_&j = input(_test_val, best32.);
              end;
              else do;
                _num_&j = .;
              end;
            end;
            else do;
              _num_&j = .;
            end;
            
            drop &varname;
            rename _num_&j = &varname;
          %end;
        %end;
        
        drop _test_val;
      run;
      
    %end;
    
    %put NOTE: Processed dataset &lib..&dsn;
    
  %end;

%mend char2num;

/* -------------------------------------------------------------------- */
%char2num();