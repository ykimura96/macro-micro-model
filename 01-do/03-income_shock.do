*/ * / * / * / * / * / * / * / * / * / * / * / * / * / * / 
*
*   3. Apply industry-level growth
*
* / * / * / * / * / * / * / * / * / * / * / * / * / * / *\

/*
Description:
* 1. Merge distribution, employment-share, and macro growth inputs
* 2. Impute missing output shares using fmlogit
* 3. Impute missing growth rates using group means
* 4. Compute distribution-sensitive and non-distribution-sensitive welfare paths

Input:
* 1kbins (2025)
* Industry growth rates (Johan)
* Income group classification (PIP)

Output:
* 1. $output\sectoralgrowthdist.dta
* 2. $output\sectoralgrowthdist_clean.dta
* 3. $output\temp\imputed_output_shares.dta
*/

//income group classification
use "$temp\pip_incgroup.dta", clear
    keep code incgroup
    tempfile incgroup
save `incgroup', replace

//population 
use "$temp\pip_all.dta", clear
    keep if reporting_level=="national" | code=="ARG"
    keep if year==2025

    duplicates drop code year pop, force
    keep year code reporting_level welfare_type pop mean 

tempfile pop
save `pop', replace


//Get 2025 distribution
use "$input\GlobalDist1000bins_1981_2050_20260922_2021_01_02_PROD.dta", clear
    keep if inrange(year, 2025, 2026)
    keep year code quantile welf pop region_code
    reshape wide welf pop, i(code quantile) j(year)
    xtile perc = quantile, nq(100)

    merge m:1 code using `incgroup', nogen
    merge m:1 code using `pop', nogen

//Share working & output in each sector
merge m:1 code perc using "$temp\IndustrySharePredicted_fin.dta", nogen keepusing(share1 share2 share3)
merge m:1 code using "$temp\mpo_2026.dta", nogen


//tags
gen mpo_cat=!missing(agri_gr_2026)         //tag if have sector data (from MPO)

//1. Predict missing output shares
    encode incgroup, gen(inc_g)
    encode region_code, gen(region)
    egen regxinc=group(inc_g region), label

    bys regxinc: egen has_shagri_regxinc = max(!missing(sh_agri_2026) & mpo_cat==1)

    //if has regxinc values
    fmlogit sh_agri_2026 sh_ind_2026 sh_serv_2026, etavar(i.regxinc)
    predict p1 p2 p3 

    gen n=sh_agri_2026!=.
    replace n=. if n==0

    replace sh_agri_2026=p1 if sh_agri_2026==. & has_shagri_regxinc==1
    replace sh_ind_2026=p2 if sh_ind_2026==. & has_shagri_regxinc==1
    replace sh_serv_2026=p3 if sh_serv_2026==. & has_shagri_regxinc==1

    preserve 
    keep region_code incgroup regxinc p? n
    collapse (mean) p1 p2 p3 (firstnm) region_code incgroup (count) num=n alln=p1, by(regxinc)
    tempfile imputed_regxinc
    save `imputed_regxinc', replace
    restore

    tabstat p1 p2 p3, by(regxinc)

    drop p?

    //if no regxinc values
    fmlogit sh_agri_2026 sh_ind_2026 sh_serv_2026, etavar(i.inc_g)
    predict p1 p2 p3

    replace sh_agri_2026=p1 if sh_agri_2026==.
    replace sh_ind_2026=p2 if sh_ind_2026==.
    replace sh_serv_2026=p3 if sh_serv_2026==.

    preserve 
    keep region_code incgroup regxinc p? n
    collapse (mean) p1 p2 p3 (count) num=n alln=p1, by(incgroup)
    gen region_code = "na"
    append using `imputed_regxinc'
    save "$output\temp\imputed_output_shares.dta", replace
    restore

    tabstat p1 p2 p3, by(inc_g)

    drop p? n


// 2. Predict missing growth rates
// If missing sectoral growth rate, use average growth rate by region x income group
// If still missing, replace with income group average 
foreach v of varlist agri_gr_???? ind_gr_???? serv_gr_???? {
    bys incgroup region_code quantile: egen `v'_m = mean(`v')
    bys incgroup quantile: egen `v'_incg = mean(`v')
    replace `v' = `v'_m if missing(`v')
    replace `v' = `v'_incg if missing(`v')

    drop `v'_m
    drop `v'_incg
}   


// 3. Calculate growth rates
    sort code quantile
        

    //b. percentile sector income share factors
    gen double inc_pct_agri_2026 = welf2025*share1    
    gen double inc_pct_ind_2026 = welf2025*share2
    gen double inc_pct_serv_2026 = welf2025*share3

    foreach x in agri ind serv {
        by code: egen tot_inc_`x'_2026 = total(inc_pct_`x'_2026)
        gen double `x'_inc_sh_pct_2026 = inc_pct_`x'_2026 / tot_inc_`x'_2026
    }


    //c. percentile income share factors (y1/y1+...+yp)
    by code: egen tot_welf_2025 = total(welf2025)
    gen sh_welf_pct_2025 = welf2025/tot_welf_2025


    //d. pct-level sector growth rates
    foreach x in agri ind serv {
        gen double `x'_pct_gr_2026 = `x'_inc_sh_pct_2026 * sh_`x'_2026 * `x'_gr_2026
    }

    egen double pct_gr_2026 = rowtotal(agri_pct_gr_2026 ind_pct_gr_2026 serv_pct_gr_2026)
    replace pct_gr_2026 = 0.7*pct_gr_2026 if welfare_type==1
    gen double pct_gr_scaled_2026 = pct_gr_2026/sh_welf_pct_2025


    //e. welfare
    gen welf_sect_2026 = welf2025*(1+pct_gr_scaled_2026)


    //f. non-distribution sensitive growth rate
    by code: gen double sectoral_growth_2026 = (agri_gr_2026*sh_agri_2026) + (ind_gr_2026*sh_ind_2026) + (serv_gr_2026*sh_serv_2026)
    replace sectoral_growth_2026 = 0.7*sectoral_growth_2026 if welfare_type==1
    gen welf_sect_nd_2026 = welf2025*(1+sectoral_growth_2026)


//clean up and save 
order code quantile 
drop year

foreach x in welf pop {
forval yr = 2025/2026 {
    label var `x'`yr' "`x' from PIP 1000-bins"
}
}

label var welf_sect_2026 "distribution sensitive growth'"
label var welf_sect_nd_2026 "non-distributional growth'"

save "$output\sectoralgrowthdist.dta", replace

keep code quantile welf2025 pct_gr_scaled_2026 sectoral_growth_2026 welf_sect_2026 welf_sect_nd_2026
order code quantile welf2025 pct_gr_scaled_2026 sectoral_growth_2026 welf_sect_2026 welf_sect_nd_2026


label var pct_gr_scaled_2026 "Distribution-sensitive growth rate"
label var sectoral_growth_2026 "Non-distribution-sensitive growth rate"
label var welf_sect_2026 "Distribution-sensitive welfare"
label var welf_sect_nd_2026 "Non-distribution-sensitive welfare"

save "$output\sectoralgrowthdist_clean.dta", replace


