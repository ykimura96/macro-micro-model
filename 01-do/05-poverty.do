*/ * / * / * / * / * / * / * / * / * / * / * / * / * / * / 
*
*   5. All Poverty scenarios (historical + proj)
*
* / * / * / * / * / * / * / * / * / * / * / * / * / * / *\

/* The scenarios:
1. Distribution neutral Jan GEP
2. Distribution neutral June GEP
3. Income shock model
4. Price shock model

Description:
1. Calculate poverty under Jan GEP, sector shock, and price shock scenarios
2. Append historical PIP poverty series
3. Build country-, regional-, and global-level poverty outputs

Input:
1. $output\sectoralgrowthdist_clean.dta
2. $output\dist_price_shock.dta
3. $input\GlobalDist1000bins_2026_20260922_2021_01_02_PROD_jangep.dta
4. $temp\pip_all_povlines.dta
5. $temp\pip_wb_povlines.dta

Output:
1. $output\country_level_poverty.dta
2. $output\regional_level_poverty.dta
3. $output\global_level_poverty.dta
*/

*1. Merge income and price shocks
use "$temp/pip_all.dta", clear
    drop if code=="CHN" & reporting_level!="national"
    keep if year==2026
    keep code region_code pop
    replace pop =1000000
tempfile pip
save `pip', replace

use "$output\sectoralgrowthdist_clean.dta", clear
keep code quantile welf_sect_2026

merge 1:1 code quantile using "$output\dist_price_shock.dta", keepusing(welf_pshock_2026) nogen
gen year=2026

merge m:1 code using `pip', nogen keepusing(region_code pop)
tempfile datasofar
save `datasofar', replace

*2. merge with Jan GEP
use "$input\GlobalDist1000bins_2026_20260922_2021_01_02_PROD_jangep.dta", clear
keep if year==2026
keep code quantile year welf
ren welf welf_jan_2026

merge 1:1 code quantile using `datasofar', nogen

* poverty rates
foreach x in jan sect pshock {
    foreach povline in 300 420 830 {
    gen poor_`x'_`povline' = (welf_`x'_2026 < `povline'/100)
}
}

keep code year region_code poor* welf* pop

collapse (firstnm) region_code (mean) poor* [aw=pop], by(year code)

tempfile poverty_scenarios
save `poverty_scenarios', replace



*2. merge with historical data from PIP
use "$temp\pip_all_povlines.dta", clear
keep if inrange(year, 2015, 2026)
drop if code=="CHN" & reporting_level!="national"
keep code year headcount poverty_line pop

recast double pop
replace pop = pop/1000000
format pop %20.12f

replace poverty_line = 300 if poverty_line==3
replace poverty_line = 420 if poverty_line==4.2
replace poverty_line = 830 if poverty_line==8.3
reshape wide headcount, i(code year pop) j(poverty_line)

foreach povline in 300 420 830 {
    ren headcount`povline' poor_pip_`povline'
}
    
merge 1:1 code year using `poverty_scenarios', nogen

* calculate number of poor
foreach x in jan pip sect pshock {
    foreach povline in 300 420 830 {
        gen npoor_`x'_`povline' = poor_`x'_`povline' * pop
    }
}


// Clean up
order code year region_code pop npoor* poor*

capture program drop relable
program define relable
    label var pop    "Population (millions)"

    foreach x in 300 420 830 {
    local pov : display %3.1f (`x'/100)
    label var npoor_pip_`x'     "Number of poor (distribution neutral growth, $`pov')"
    label var npoor_jan_`x'     "Number of poor (January GEP, $`pov')"
    label var npoor_sect_`x'    "Number of poor (sectoral growth shock, $`pov')"
    label var npoor_pshock_`x'  "Number of poor (price shock, $`pov')"

    label var poor_pip_`x'     "Poverty rate (distribution neutral growth, $`pov')"
    label var poor_jan_`x'     "Poverty rate (January GEP, $`pov')"
    label var poor_sect_`x'    "Poverty rate (sectoral growth shock, $`pov')"
    label var poor_pshock_`x'  "Poverty rate (price shock, $`pov')"

    foreach povline in 300 420 830 {
    foreach x in sect pshock jan {
    replace npoor_`x'_`povline' = . if year<2026
    replace poor_`x'_`povline' = . if year<2026
        }
    }

    }
end


*3. Save the merged poverty data
*3a. Country-level
relable
save "$output\country_level_poverty.dta", replace

*3b. Regional
drop *_pip_*
collapse (rawsum) npoor* pop (mean) poor* [aw=pop], by(region_code year)
tempfile datasofar
save `datasofar', replace

use "$temp\pip_wb_povlines.dta", clear
    keep if inrange(year, 2015, 2026)
    keep region_code year poverty_line headcount pop_in_poverty population
    drop if region_code=="WLD"
    ren headcount poor_pip_
    ren pop_in_poverty npoor_pip_
    replace poverty_line = round(poverty_line*100, 1)
    replace npoor_pip_=npoor_pip_/1000000
    replace population = population/1000000
reshape wide poor_pip npoor_pip, i(region_code year population) j(poverty_line)

merge 1:1 region_code year using `datasofar', nogen

relable
order region_code year pop npoor* poor*
save "$output\regional_level_poverty.dta", replace

*3c. Global
collapse (rawsum) npoor* pop (mean) poor* [aw=pop], by(year)
relable
order year pop npoor* poor*
save "$output\global_level_poverty.dta", replace
