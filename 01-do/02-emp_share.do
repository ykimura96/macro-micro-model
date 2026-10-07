*/ * / * / * / * / * / * / * / * / * / * / * / * / * / * / 
*
*   2. Predict missing employment shares
*
* / * / * / * / * / * / * / * / * / * / * / * / * / * / *\

/*
Description:
* 1. Predict missing employment shares by percentile
* 2. Use fmlogit models by region-income-percentile and income-percentile
* 3. Fill missing sector shares and generate final share inputs

Input:
* PIP income group classification
* PIP population data
* Country employment share data from GMD

Output:
* 1. $temp\IndustrySharePredicted.dta
* 2. $temp\IndustrySharePredicted_fin.dta
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
    keep year code reporting_level welfare_type pop mean region_code

merge 1:1 code using `incgroup', nogen

merge 1:m code using "$input\IndustryShareByDecile.dta", nogen

//tags
bysort code: gen empsh_cat = !missing(share1)       //tag if have employment share data (from GMD)
egen   incpct = group(incgroup perc), label

tempfile alldata
save `alldata', replace

bys region_code incgroup perc: keep if _N>1
egen   regxincpct = group(region_code incgroup perc), label

tempfile maindata
save `maindata', replace

// Estimate employment shares per percentile
sum regxincpct
local max = `r(max)'

forval i = 1/`max' {
    preserve
    use `maindata', clear
    keep if regxincpct == `i'
    di "*** `i' of `max' ***"
    cap fmlogit share1 share2 share3 share4, eta(i.regxincpct)
    cap predict s1 s2 s3 s4,  outcome(1 2 3 4)
    collapse s?, by(perc incgroup region_code)
    cap append using `datasofar'
    tempfile datasofar
    save `datasofar', replace
    restore
}
use `datasofar', clear
save "$temp\IndustrySharePredicted.dta", replace

//by incgroup x percentile
use "$temp\pip_incgroup.dta", clear
    keep code incgroup
    tempfile incgroup
save `incgroup', replace

//population 
use "$temp\pip_all.dta", clear
    keep if reporting_level=="national" | code=="ARG"
    keep if year==2025

    duplicates drop code year pop, force
    keep year code reporting_level welfare_type pop mean region_code

merge 1:1 code using `incgroup', nogen

merge 1:m code using "$input\IndustryShareByDecile.dta", nogen

//tags
bysort code: gen empsh_cat = !missing(share1)       //tag if have employment share data (from GMD)
egen   incpct = group(incgroup perc), label

tempfile alldata
save `alldata', replace
use `alldata', clear
    fmlogit share1 share2 share3 share4, eta(i.incpct)
    predict s_inc1 s_inc2 s_inc3 s_inc4,  outcome(1 2 3 4)

    collapse s_inc*, by(perc incgroup)
    tempfile incgroup_perc
    save `incgroup_perc', replace

//put it together
use `alldata', clear
    keep code region_code incgroup 
    duplicates drop code, force
    expand 100
    bys code: gen perc = _n
merge m:1 perc incgroup region_code using "$temp\IndustrySharePredicted.dta", nogen
merge m:1 perc incgroup using `incgroup_perc', nogen
drop if code==""
merge 1:1 code perc using `alldata', nogen

drop if perc==.
ren share? share?_raw

forval i = 1/4 {
    gen share`i' = share`i'_raw
    replace share`i' = s`i' if missing(share`i') 
    replace share`i' = s_inc`i' if missing(share`i')
}

//distribute share of "other" sector to the 3 main sectors
forval i =1/3 {
    replace share`i' = share`i' + share4/3 if share4>0
}

label var s1 "Pred. share in agriculture (regxinc)"
label var s2 "Pred. share in industry (regxinc)"
label var s3 "Pred. share in services (regxinc)"
label var s4 "Pred. share in other (regxinc)"
label var s_inc1 "Pred. share in agriculture (incgroup)"
label var s_inc2 "Pred. share in industry (incgroup)"
label var s_inc3 "Pred. share in services (incgroup)"
label var s_inc4 "Pred. share in other (incgroup)"

save "$temp\IndustrySharePredicted_fin.dta", replace