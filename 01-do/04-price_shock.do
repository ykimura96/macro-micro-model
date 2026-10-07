/* / * / * / / * / * / * / * / * / * / * / * / * / * / * / * /
*
*   4. Country-specific shocks
*
*/ * / * / * / * / * / * / * / * / * / * / * / * / * / * / */

/* Description:
* 1. Build country- and quintile-level food/energy exposure profiles
* 2. Impute missing exposure values by region-income and income groups
* 3. Apply price-shock adjustment to growth and welfare distribution
*
* Input:
* 1. $input\foodenergy_all.dta
* 2. $output\sectoralgrowthdist_clean.dta
* 3. PIP country list via pip tables command
*
* Output:
* 1. $output\temp\budget_slope.dta
* 2. $output\dist_price_shock.dta
*/

*0. Initial data
// countries in pip
pip tables, table(country_list) clear
keep country* region* incgroup* 
ren country_name country
ren country_code code
replace country = "Côte d'Ivoire" if code == "CIV"
replace country = "São Tomé and Principe" if code == "STP"
replace country = "Turkey" if code == "TUR"
duplicates drop
expand 5
bys code: gen quintile = _n
tempfile country_list
save `country_list'

//compile region food and energy share data 
use "$input\foodenergy_all.dta", clear

merge m:1 code quintile using `country_list',  nogen keepusing(incgroup*)

// keep the average rate for energy, food is only available for latest data
bys code quintile: egen energy_m = mean( energyshare )
bys code quintile: egen food_m   = mean( foodshare )
collapse (mean) energy_m food_m, by(code region quintile incgroup)

//replace missing by incgroupxregion average
egen regincgroup = group(region incgroup), label
bys regincgroup quintile: egen energy_m_regincgroup    = mean( energy_m )
replace energy_m = energy_m_regincgroup if energy_m == . 
bys regincgroup quintile: egen food_m_regincgroup      = mean( food_m )
replace food_m = food_m_regincgroup if food_m       == .

// replace missing by incgroup average 
bys incgroup quintile: egen energy_m_incgroup    = mean( energy_m )
replace energy_m = energy_m_incgroup if energy_m == . 
bys incgroup quintile: egen food_m_incgroup      = mean( food_m )
replace food_m = food_m_incgroup if food_m       == .

gen food_energy_share  = energy_m + food_m

sort code quintile
save "$output\temp\budget_slope.dta", replace


*2. Combine datasets and predict welfare
*A. Method 1: exposure share = ratio of food&energy share to average
use "$output\temp\budget_slope.dta", clear

keep code food_energy_share quintile 
duplicates drop code quintile, force 
tempfile foodenergyshare
save    `foodenergyshare', replace

// welfare data
use "$output\sectoralgrowthdist_clean.dta", clear
keep code quantile welf2025 sectoral_growth_????
ren sectoral_growth_???? growth_mean????

gen quintile = ceil(quantile/200)
*merge m:1 code using `lastgini',     keep(1 3) nogen keepusing(gini)
merge m:1 code quintile using `foodenergyshare', keep(1 3) nogen
*merge m:1 code quintile using `country_list', keep(1 3) nogen keepusing(incgroup* region*)

ren welf2025 welf_sect_nd_2025

	bys code: egen tot_welf = total(welf_sect_nd_2025)
	gen inc_sh = welf_sect_nd_2025/tot_welf

	bys code: egen lambda_m = mean(food_energy_share)
	gen phi_t = food_energy_share/lambda_m

	gen phi_1 = inc_sh * phi_t
	bys code: egen phi_w = total(phi_1)
	gen phi_s = phi_t - phi_w

	gen g2026_pshock = growth_mean2026 * (1-phi_s)

	gen welf_pshock_2026 = welf_sect_nd_2025 * (1 + g2026_pshock)

	drop tot_welf inc_sh phi_* lambda_m
    

keep code quantile g2026_pshock welf_pshock_2026
sort code quantile
order code quantile g2026_pshock welf_pshock_2026
    
label var welf_pshock_2026  "Welfare in 2026, price shock"
label var g2026_pshock      "Percentile growth rate in 2026, price shock"

save "$output\dist_price_shock.dta", replace

