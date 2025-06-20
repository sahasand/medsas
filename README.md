# medsas

This repository contains SAS programs and sample data for cleaning and converting datasets from the RAPID-WATER-FLOW (MedTrace-002) trial.

## Setup

The scripts expect the raw SAS extract in a folder referenced by the `libpath` macro variable.  Output from the cleaning step is written to the directory set in `outpath`.

Edit the following lines at the top of `dataclean.sas` so they point to your local folders:

```
%let libpath = C:\path\to\19_MedTrace-002_SASExtract_18-06-2025;
%let outpath = C:\path\to\cleaned;
```

## Running the programs

Run the data cleaning process with:

```
sas dataclean.sas
```

This generates cleaned datasets and issue reports in `&outpath`.

To convert character variables that contain numeric values to numeric variables, run:

```
sas datatonum.sas
```

Update the `libname` statement in `datatonum.sas` if your data are stored elsewhere.

