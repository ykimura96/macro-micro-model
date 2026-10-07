/* / * / * / / * / * / * / * / * / * / * / * / * / * / * / * /
*
*   Prep MPO data
*
*/ * / * / * / * / * / * / * / * / * / * / * / * / * / * / */

/* Description:
* 1. Prepare MPO macro data for scenario construction
* 2. Compute per-capita GDP and sector growth rates
* 3. Rescale growth rates to match June GEP assumptions
*
* Input:
* 1. $input\mpo.dta
* 2. $input\GDP_GEP_2026_06_internal.xlsx
* 3. $input\UNpop1950-2050_MediumJuly2024.dta
* 4. $pop (Population_202606_3PR.dta)
*
* Output:
* 1. $temp\mpo_2026.dta
*/

use "$input\mpo.dta", clear

//per capita
    gen double gdp = yrNYGDPMKTPKN/yrSPPOPTOTL
    gen double agri = yrNVAGRTOTLKN/yrSPPOPTOTL
    gen double ind = yrNVINDTOTLKN/yrSPPOPTOTL
    gen double serv = yrNVSRVTOTLKN/yrSPPOPTOTL

//scale to GDP
gen double tot_sectors = agri + ind + serv

replace agri = agri*gdp/tot_sectors if tot_sectors>0 & !missing(gdp, tot_sectors)
replace ind = ind*gdp/tot_sectors if tot_sectors>0 & !missing(gdp, tot_sectors)
replace serv = serv*gdp/tot_sectors if tot_sectors>0 & !missing(gdp, tot_sectors)

drop tot_sectors

//growth rate 
    sort code year 
    foreach var of varlist gdp agri ind serv {
        bys code (year): gen double `var'_gr = (`var'/`var'[_n-1] - 1)
        label var `var' "Per capita `var' (constant LCU)"
        label var `var'_gr "Growth rate of `var'"
    }

//share of each sector in total GDP
foreach x in agri ind serv gdp {
    gen double sh_`x' = `x'/gdp
    label var sh_`x' "Share of `x' in GDP"
}


//check implied growth rate = GDP growth rate
gen gr=(sh_agri[_n-1]*agri_gr)+(sh_ind[_n-1]*ind_gr)+(sh_serv[_n-1]*serv_gr)

ren yrSPPOPTOTL pop_mpo
drop yr*

//scale to June GEP GDP growth rate
preserve
import excel using ///
	"$input\GDP_GEP_2026_06_internal.xlsx", cellrange(A2) firstrow clear
ren Countrycode code
drop Countryname
drop if missing(code) | strlen(code)>50	
tostring C-H, replace
foreach var of varlist C-H {
	local yr: variable label `var'
	local yr = substr("`yr'",1,4)
	ren `var' gdp_gep_jun26_growth`yr'
	replace   gdp_gep_jun26_growth`yr' = "" if gdp_gep_jun26_growth`yr'==".."
}
destring 	 gdp_gep_jun26_growth*, replace	
reshape long gdp_gep_jun26_growth, i(code) j(year)

// Right now the data is not per capita. They use UN median variant forecasts. Merge with this data to turn it into per capita. 
merge 1:1 code year 		 using "$input\UNpop1950-2050_MediumJuly2024.dta", nogen keep(1 3)
keep if data_level == "national"
bysort code (year): gen gdppc_gep_jun26_growth = ((1+gdp_gep_jun26_growth/100)*unpop[_n-1]/unpop-1)*100
keep code year  		gdppc_gep_jun26_growth
label var 				gdppc_gep_jun26_growth "GEP GDP/capita 2026m06 growth"
isid code year
compress

tempfile gdp_gep_jun26
save `gdp_gep_jun26', replace

restore
merge 1:1 code year using `gdp_gep_jun26', nogen
drop if gdp==.

//scale 
replace gdppc_gep_jun26_growth = gdppc_gep_jun26_growth/100
gen scale = gdppc_gep_jun26_growth/gdp_gr
foreach var of varlist gdp_gr agri_gr ind_gr serv_gr {
    replace `var' = `var'*scale if !missing(`var', scale)
}

    preserve
    keep if year==2026
    ren * *_2026
    ren code_2026 code
    drop year_2026 sh_*
    save "$temp\mpo_2026.dta", replace
    restore


    preserve
    keep if year==2025
    keep code sh_*

    ren * *_2026
    ren code_2026 code

    merge 1:1 code using "$temp\mpo_2026.dta", nogen
    save "$temp\mpo_2026.dta", replace
    restore


