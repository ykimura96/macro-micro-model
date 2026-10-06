# macro-micro-model
Distribution sensitive macro-micro nonwcasting model

## Input files

Before the do-file descriptions, this section lists the key external inputs used by the pipeline.

- Core distribution and population inputs (in `github/02-input`):

  - `GlobalDist1000bins_1981_2050_20260922_2021_01_02_PROD.dta`

    - Source: [Poverty and Inequality Platform: 1000 Binned Global Distribution](https://datacatalog.worldbank.org/search/dataset/0064304/1000-binned-global-distribution)
  - `GlobalDist1000bins_1981_2050_20260922_2021_01_02_PROD_jangep.dta`

    - Between the March 2026 and September 2026 updates in PIP, four additional economy-years were added to the PIP database. Hence, this file contains the 1000-distribution data using the 2025 data from the September 2026 vintage and applies the growth rates between 2025 and 2026 from the March 2026 vintage. You can read more about the changes between the March 2026 and September 2026 vintages here: [September 2026 Update to the Poverty and Inequality Platform (PIP)](https://documents.worldbank.org/en/publication/documents-reports/documentdetail/099045009172613939).
  - `UNpop1950-2050_MediumJuly2024.dta`

    - Source: [Population Division, United Nations](https://population.un.org/wpp/Download/Standard/CSV/)
- Macro and sector inputs:

  - `mpo.dta`
    - Source: [April Macro Poverty Outlook](https://www.worldbank.org/en/publication/macro-poverty-outlook)
    - This file was compiled by the Distributional Impact of Policies unit.
  - `GDP_GEP_2026_06_internal.xlsx`
    - This file was compiled by the Prosperity Group, where the growth rates in the[ June Global Economic Prospects report](https://thedocs.worldbank.org/en/doc/2b672b3b0415d6b66c45b66579db4ef5-0050012026/original/GEP-Jun-2026.pdf) has been converted from financial to calendar year.
  - `IndustryShareByDecile.dta`
    - This file compiles the industry shares by deciles from country surveys in the Global Monitoring Database.
- Price-shock inputs:

  - `foodenergy_all.dta`
    - This file compiles the quintile-level food and energy shares from country surveys.
- Inputs generated via the PIP command in `00-master.do` and saved into `github/03-output/temp`:

  - `pip_incgroup.dta`
  - `pip_all.dta`
  - `pip_all_povlines.dta`
  - `pip_wb_povlines.dta`

If any of these files are missing, the relevant downstream do-file will fail.

## Files in this folder

1. `00-master.do`

- Description:
  - Sets global paths for the replication package.
  - Creates required output folders.
  - Checks and installs required user-written commands.
  - Downloads PIP source data used by downstream scripts.
  - Runs the full pipeline in sequence.
- Input:
  - Repository folder structure under `github`.
  - Internet access for PIP command calls.
- Output:
  - `pip_incgroup.dta`, `pip_all.dta`, `pip_all_povlines.dta`, `pip_wb_povlines.dta` in `03-output/temp`.
  - All downstream outputs from `01-mpo.do` to `06-graphs.do`.

2. `01-mpo.do`

- Description:
  - Prepares MPO macro and sector growth inputs.
  - Converts growth to per-capita terms and aligns with June GEP growth.
- Input:
  - `mpo.dta`, `GDP_GEP_2026_06_internal.xlsx`, `UNpop1950-2050_MediumJuly2024.dta`, and `$pop`.
- Output:
  - `03-output/temp/mpo_2026.dta`.

3. `02-emp_share.do`

- Description:
  - Predicts missing employment shares across sectors.
  - Uses multinomial fractional logit models by region-income-percentile groups and income-percentile groups.
- Input:
  - `03-output/temp/pip_incgroup.dta`, `03-output/temp/pip_all.dta`, `02-input/IndustryShareByDecile.dta`.
- Output:
  - `03-output/temp/IndustrySharePredicted.dta`.
  - `03-output/temp/IndustrySharePredicted_fin.dta`.

4. `03-income_shock.do`

- Description:
  - Merges base welfare distribution, macro growth, and employment-share inputs.
  - Predicts missing output shares and fills missing growth rates.
  - Computes distribution-sensitive and non-distribution-sensitive welfare projections.
- Input:
  - `02-input/GlobalDist1000bins_1981_2050_20260922_2021_01_02_PROD.dta`.
  - `03-output/temp/pip_incgroup.dta`, `03-output/temp/pip_all.dta`.
  - `03-output/temp/IndustrySharePredicted_fin.dta`, `03-output/temp/mpo_2026.dta`.
- Output:
  - `03-output/sectoralgrowthdist.dta`.
  - `03-output/sectoralgrowthdist_clean.dta`.
  - `03-output/temp/imputed_output_shares.dta`.

5. `04-price_shock.do`

- Description:
  - Builds country-specific food and energy exposure profiles.
  - Applies exposure-based price shock adjustments to growth and welfare.
- Input:
  - `02-input/foodenergy_all.dta`.
  - `03-output/sectoralgrowthdist_clean.dta`.
  - PIP country list from `pip tables`.
- Output:
  - `03-output/temp/budget_slope.dta`.
  - `03-output/dist_price_shock.dta`.

6. `05-poverty.do`

- Description:
  - Combines growth scenarios and historical poverty series.
  - Computes poverty headcounts and number of poor for key poverty lines.
  - Saves country-, regional-, and global-level poverty outputs.
- Input:
  - `03-output/sectoralgrowthdist_clean.dta`, `03-output/dist_price_shock.dta`.
  - `02-input/GlobalDist1000bins_1981_2050_20260922_2021_01_02_PROD_jangep.dta`.
  - `03-output/temp/pip_all_povlines.dta`, `03-output/temp/pip_wb_povlines.dta`.
- Output:
  - `03-output/country_level_poverty.dta`.
  - `03-output/regional_level_poverty.dta`.
  - `03-output/global_level_poverty.dta`.

7. `06-graphs.do`

- Description:
  - Reproduces figures and tables used in the technical note.
  - Exports graph and table outputs.
- Input:
  - `02-input/IndustryShareByDecile.dta`, `02-input/foodenergy_all.dta`.
  - `02-input/GlobalDist1000bins_1981_2050_20260922_2021_01_02_PROD.dta`.
  - `03-output/sectoralgrowthdist.dta`, `03-output/sectoralgrowthdist_clean.dta`, `03-output/dist_price_shock.dta`.
  - `03-output/country_level_poverty.dta`, `03-output/global_level_poverty.dta`.
  - `03-output/temp/imputed_output_shares.dta`, `03-output/temp/mpo_2026.dta`.
- Output:
  - Graph files in `03-output/graphs`.
  - Table workbook `03-output/graphs/tables.xlsx`.

## How to run

Run only `00-master.do`. It orchestrates the complete sequence:

- `01-mpo.do`
- `02-emp_share.do`
- `03-income_shock.do`
- `04-price_shock.do`
- `05-poverty.do`
- `06-graphs.do`

## Expected folder structure

The master file assumes this repository layout under the `github` folder:

- `01-do`
- `02-input`
- `03-output`

## Notes

- The pipeline expects access to the PIP data command used in `00-master.do`.
- If command installation fails due to network or permissions, install manually and rerun the master script.
