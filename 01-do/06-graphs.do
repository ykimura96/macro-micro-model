*/ * / * / * / * / * / * / * / * / * / * / * / * / * / * / 
*
*   6. Replicate figures & tables in technical note
*
* / * / * / * / * / * / * / * / * / * / * / * / * / * / *\

/* Description:
* 1. Reproduce figures and tables for the technical note
* 2. Compile chart-ready series from model outputs
* 3. Export graphs and tables to output folders
*
* Input:
* 1. $input\IndustryShareByDecile.dta
* 2. $input\foodenergy_all.dta
* 3. $input\GlobalDist1000bins_1990_2026_20260922_2021_01_02_PROD.dta
* 4. $output\sectoralgrowthdist_clean.dta
* 5. $output\sectoralgrowthdist.dta
* 6. $output\dist_price_shock.dta
* 7. $output\country_level_poverty.dta
* 8. $output\global_level_poverty.dta
* 9. $output\temp\imputed_output_shares.dta
*
* Output:
* 1. Graph files in $output\graphs\
* 2. Table outputs in $output\graphs\tables.xlsx
*/

* Figure 1: Employment shares across welfare distribution
    use "$input\IndustryShareByDecile.dta", clear
    forval i =1/3 {
        replace share`i' = share`i' + share4/3 if share4>0
    }

    #delim ;
    twoway (lpoly share1 perc, degree(2) bwidth(12)) 
    (lpoly share2 perc, degree(2) bwidth(12)) (lpoly share3 perc, degree(2) bwidth(12)) if code=="BRA",
    legend(order(1 "Agriculture" 2 "Industry" 3 "Services") row(1) pos(6) size(vsmall)) 
    title("Brazil (2024)") ytitle("Share of population in sector") xtitle("Welfare percentile")
    xsize(60) ysize(48) ;
    #delim cr
    graph export "$output\graphs\figure1a.png", replace

    #delim ;
    twoway (lpoly share1 perc, degree(2) bwidth(12)) 
    (lpoly share2 perc, degree(2) bwidth(12)) (lpoly share3 perc, degree(2) bwidth(12)) if code=="IDN",
    legend(order(1 "Agriculture" 2 "Industry" 3 "Services") row(1) pos(6) size(vsmall)) 
    title("Indonesia (2025)") ytitle("Share of population in sector") xtitle("Welfare percentile")
    xsize(60) ysize(48) ;
    #delim cr
    graph export "$output\graphs\figure1b.png", replace


* Table 1: Sectoral growth rates per capita (%), 2025
    use "$temp\mpo_2026.dta", clear
    foreach x of varlist *_gr_2026 {
        gen pct_`x' = `x'*100
    }
    tabstat pct_*_2026 if inlist(code, "BRA", "IDN"), by(code)  format(%9.2f)

    preserve
        keep if inlist(code, "BRA", "IDN")
        collapse (mean) pct_*_2026, by(code)
        foreach v of varlist pct_*_2026 {
            replace `v' = round(`v', .01)
        }

        local t1xlsx "$output\graphs\tables.xlsx"
        capture confirm file "`t1xlsx'"
        if _rc {
            export excel code pct_*_2026 using "`t1xlsx'", firstrow(variables) sheet("T1") cell(A1) replace
        }
        else {
            export excel code pct_*_2026 using "`t1xlsx'", firstrow(variables) sheet("T1") cell(A1) sheetmodify
        }
    restore


* Figure 2: Growth incidence curves
    use "$output\sectoralgrowthdist_clean.dta", clear

    sort code quantile
    by code: gen perc = ceil(_n/10)
    keep if inlist(code, "BRA", "IDN")
    keep code perc pct_gr_scaled_2026
    collapse (mean) pct_gr_scaled_2026, by(code perc)
    replace pct_gr_scaled_2026 = pct_gr_scaled_2026*100

    #delim ;
    twoway (lpoly pct_gr_scaled_2026 perc if code=="BRA", degree(2) bwidth(12))
    (lpoly pct_gr_scaled_2026 perc if code=="IDN", degree(2) bwidth(12)),
    legend(order(1 "Brazil" 2 "Indonesia") row(1) pos(6) size(vsmall)) 
    ytitle("Growth rate, %") xtitle("Welfare percentile") yscale(range(0 3.5)) ylabel(0(1)3.5)
    xsize(60) ysize(48) ;
    #delim cr
    graph export "$output\graphs\figure2.png", replace


* Figure 3: Food and energy expenditure shares and growth rates 
    use "$input\foodenergy_all.dta", clear

    keep if inlist(code, "IDN", "UGA")

    egen foodenergy = rowtotal(foodshare energyshare)

    tempfile foodenergy
    save `foodenergy', replace

    *GIC 
    use "$output\dist_price_shock.dta", clear
    sort code quantile
    gen quintile=ceil(quantile/200)

    merge m:1 code quintile using `foodenergy', keep(3) nogen keepusing(foodenergy)

    keep code quintile foodenergy g2026 welf_pshock_2026
    collapse (mean) g2026 welf_pshock_2026 foodenergy, by(code quintile)

    replace g2026=g2026*100
    tempfile gic
    save `gic', replace

    *Get mean growth 
    use "$output\sectoralgrowthdist_clean.dta", clear
    //create income shares by quintile
    gen quintile=ceil(quantile/200)
    bysort code: egen allwelf = total(welf2025)
    bysort code quintile: egen welf_q = total(welf2025)
    gen inc_share=welf_q/allwelf
    keep code sectoral_growth_2026 inc_share quintile
    collapse (firstnm) sectoral_growth_2026 inc_share, by(code quintile)

    merge 1:1 code quintile using `gic', keep(3) nogen
    replace sectoral_growth_2026=sectoral_growth_2026*100

    //Format for graph
    gen foodenergy_x = quintile - 0.15
    gen inc_share_x = quintile + 0.15
    gen quintile_x = quintile
    replace quintile_x = quintile - 0.15 if quintile==1
    replace quintile_x = quintile + 0.15 if quintile==5

    //IDN
    #delim ;
    twoway (bar foodenergy quintile if code=="IDN", yaxis(1) barwidth(0.3)) 
    (line g2026 quintile_x if code=="IDN", lcolor(red) lwidth(medthick) yaxis(2))
    (line sectoral_growth_2026 quintile_x if code=="IDN", lcolor(green) lwidth(medthick) yaxis(2)),
    legend(order(1 "Food & Energy Share" 
    2 "Distributional growth 2026" 3 "GDP growth 2026") 
    symxsize(4) keygap(0.5) pos(6) size(vsmall) row(1))
    ylabel(0(0.2)1, axis(1)) ylabel(0(1)5, axis(2))
    xlabel(1(1)5)
    xsize(60) ysize(48) 
    title("Indonesia (2025)") ytitle("Food & Energy Shares") ytitle("Growth rate (2026), %", axis(2)) xtitle("Welfare quintile");
    #delim cr
    graph export "$output\graphs\figure3a.png", replace

    //UGA
    #delim ;
    twoway (bar foodenergy quintile if code=="UGA", yaxis(1) barwidth(0.3)) 
    (line g2026 quintile_x if code=="UGA", lcolor(red) lwidth(medthick) yaxis(2))
    (line sectoral_growth_2026 quintile_x if code=="UGA", lcolor(green) lwidth(medthick) yaxis(2)),
    legend(order(1 "Food & Energy Share" 
    2 "Distributional growth 2026" 3 "GDP growth 2026") 
    symxsize(4) keygap(0.5) pos(6) size(vsmall) row(1))
    ylabel(0(0.2)1, axis(1)) ylabel(0(1)5, axis(2))
    xlabel(1(1)5)
    xsize(60) ysize(48) 
    title("Uganda (2024)") ytitle("Food & Energy Shares") ytitle("Growth rate (2026), %", axis(2)) xtitle("Welfare quintile");
    #delim cr
    graph export "$output\graphs\figure3b.png", replace


*Figure 4: Projected number of poeple living under $3 (2021PPP)/day
    use "$output\global_level_poverty.dta", clear

    keep if inrange(year, 2023, 2026)
        foreach x in sect pshock {
            replace npoor_`x'_300 = npoor_pip_300 if year == 2025
        }

    // Extract 2026 values for labeling
        foreach x in jan pip sect pshock {
            summ npoor_`x'_300 if year == 2026, meanonly
            local val_`x' = r(mean)
        }

    #delimit ;
        twoway ///
            (line npoor_pip_300 year if year<=2025, lcolor(navy) lwidth(medthick))
            (line npoor_pip_300 year if year >= 2025, lpattern(dash) lcolor(navy)   lwidth(medium))
            (line npoor_jan_300 year if year >= 2025, lpattern(dash) lcolor(eltblue)   lwidth(medium))
            (line npoor_sect_300 year if year >= 2025, lpattern(dash) lcolor(red)    lwidth(medium))
            (line npoor_pshock_300 year if year >= 2025, lpattern(dash) lcolor(green)  lwidth(medium)),
            text(`val_pip' 2026.05 "`=string(`val_pip', "%9.0f")'", color(navy) placement(e) size(medium)) 
            text(`val_jan' 2026.05 "`=string(`val_jan', "%9.0f")'", color(eltblue) placement(e) size(medium))
            text(`val_sect' 2026.05 "`=string(`val_sect', "%9.0f")'", color(red) placement(e) size(medium))
            text(`val_pshock' 2026.05 "`=string(`val_pshock', "%9.0f")'", color(green) placement(e) size(medium)) 
            xlabel(2023(1)2026, angle(45)) yscale(range(800 850))
            ylabel(800(10)850, format(%9.0f)) 
            legend(order(1 "Baseline" 
                        3 "Pre-war growth projections" 
                        4 "Income shock" 
                        5 "Price shock")
                size(medium) col(1) pos(2) row(4) ring(0) symxsize(2)) 
            xtitle("") ytitle("Number of people (millions) in extreme poverty") xsize(60) ysize(48) 
            plotregion(margin(r=8));        
    #delimit cr
        graph export "$output\graphs\figure4.png", replace

* Figure 5: Additional number of extreme poor compared to PIP
    use "$input\GlobalDist1000bins_1990_2026_20260922_2021_01_02_PROD.dta", clear
        keep if year==2025
        sort code quantile
        drop if welf>3
        keep code quantile 
        collapse (max) quantile, by(code)
        replace quantile = quantile/10
        keep if inlist(code, "NGA", "COD", "PAK", "TZA")
    tempfile pctpov
    save   `pctpov', replace

    use "$output\country_level_poverty.dta", clear

    //highest npoor (acc to June GEP)
    gsort -npoor_pip_300
    br code npoor_*_300 if year==2026

    foreach scenario in sect pshock {
        gen npoor_vs_junegep_`scenario' = npoor_`scenario'_300 - npoor_pip_300 if year>2025
        gen npoor_vs_junegep_pct_`scenario' = (npoor_`scenario'_300 - npoor_pip_300) / npoor_pip_300 * 100 if year>2025
    }

    //NGA, COD, PAK, TZA
    keep if year==2026
    keep if inlist(code, "NGA", "COD", "PAK", "TZA")
    keep year code npoor_vs_junegep_* npoor_vs_junegep_pct_*
    merge 1:1 code using `pctpov', keepusing(quantile) nogen

    // Create numeric x position for countries
    gen xpos = .
    replace xpos = 1 if code == "PAK"
    replace xpos = 2 if code == "TZA"
    replace xpos = 3 if code == "NGA"
    replace xpos = 4 if code == "COD"

    // Create offset x positions for each bar series
    gen xpos_sect = xpos - 0.1
    gen xpos_pshock = xpos + 0.1
    gen xpos_pov = xpos


    // Extract values for text labels with vertical adjustment
    local text_opts ""
    forval i=1/4 {
        foreach s in sect pshock {
            local val = npoor_vs_junegep_`s'[`i']
            if !missing(`val') {
                local lab = string(`val', "%9.1f")
                // Position labels at the exact bar position
                local x_pos = xpos_`s'[`i']-0.01
                // Add vertical offset: positive values go higher, negative values go lower
                if `val' >= 0 {
                    local ypos = `val' + 0.1
                }
                else {
                    local ypos = `val' - 0.1
                }
                local text_opts `text_opts' text(`ypos' `x_pos' "`lab'", justification(left) size(small))
            }
        }
    }

    #delimit ;
    twoway 
        (bar npoor_vs_junegep_sect xpos_sect, barwidth(0.2) color(red))
        (bar npoor_vs_junegep_pshock xpos_pshock, barwidth(0.2) color(green))
        (scatter quantile xpos, yaxis(2) msymbol(D) msize(medium) 
        mcolor(#566D7E%60) mlcolor(#566D7E) mlwidth(medthick)),
        `text_opts'
        xlabel(1 "PAK" 2 "TZA" 3 "NGA" 4 "COD", axis(1))
        yline(0, lcolor(black) lwidth(thin) lpattern(solid))
        yscale(lwidth(vthin) axis(1))
        yscale(lwidth(vthin) axis(2))
        yscale(range(-45 100) axis(2))
        ylabel(, format(%9.1f) axis(1))
        ylabel(0(20)100, format(%9.0f) axis(2))
        ytitle("Additional number of poor (millions) vs June GEP", axis(1))
        ytitle("% in extreme poverty in 2025", axis(2))
        /*title("Poverty: Change relative to June GEP scenario (2026)")
        subtitle("$3 line")*/
        legend(order(1 "Income shock"
                    2 "Price shock"
                    3 "Poverty rate")
                row(1) pos(6) size(small) symxsize(2))
        plotregion(style(none))
        xscale(noline)
        xsize(85) ysize(48);
    #delimit cr
    graph export "$output\graphs\figure5.png", replace


* Figure 6: Country-level sector and GDP growth rates
    use "$output\sectoralgrowthdist.dta", clear
        keep if inlist(code, "NGA", "COD", "PAK", "TZA") & quantile==1
        keep code agri_gr_2026 ind_gr_2026 serv_gr_2026 sectoral_growth_2026
        foreach x in agri_gr_2026 ind_gr_2026 serv_gr_2026 sectoral_growth_2026 {
            replace `x' = `x' * 100
        }

    gen xpos = .
    replace xpos = 1 if code == "PAK"
    replace xpos = 2 if code == "TZA"
    replace xpos = 3 if code == "NGA"
    replace xpos = 4 if code == "COD"

    // Create offset x positions for each bar series
    gen xpos_3 = xpos - 0.25
    gen xpos_4 = xpos + 0.25
    gen xpos_5 = xpos


    // Extract values for text labels with vertical adjustment
    local text_opts ""
    forval i=1/4 {
        foreach s in agri ind serv {
            local val = `s'_gr_2026[`i']
            if !missing(`val') {
                local lab = string(`val', "%9.1f")
                // Position labels at the exact bar position
                if "`s'"=="agri" {
                    local x_pos = xpos_3[`i']
                }
                else if "`s'"=="ind" {
                    local x_pos = xpos_5[`i']
                }
                else {
                    local x_pos = xpos_4[`i']
                }
                // Add vertical offset: positive values go higher, negative values go lower
                if `val' >= 0 {
                    local ypos = `val' + 0.3
                }
                else {
                    local ypos = `val' - 0.3
                }
                local text_opts `text_opts' text(`ypos' `x_pos' "`lab'", justification(left) size(small))
            }
        }
    }

    #delimit ;
    twoway 
        (bar agri_gr_2026 xpos_3, barwidth(0.25))
        (bar ind_gr_2026 xpos_5, barwidth(0.25) )
        (bar serv_gr_2026 xpos_4, barwidth(0.25))
        (scatter sectoral_growth_2026 xpos, msymbol(D) msize(medium) 
        mcolor(#566D7E%60) mlcolor(#566D7E) mlwidth(medthick)),
        `text_opts'
        xlabel(1 "PAK" 2 "TZA" 3 "NGA" 4 "COD", axis(1))
        yline(0, lcolor(black) lwidth(thin) lpattern(solid))
        yscale(lwidth(vthin) axis(1))
        ylabel(, format(%9.0f) axis(1))
        ytitle("Growth rate, %", axis(1))
        /*title("Poverty: Change relative to June GEP scenario (2026)")
        subtitle("$3 line")*/
        legend(order(1 "Agriculture"
                    2 "Industry"
                    3 "Service"
                    4 "GDP")
                row(1) pos(6) size(small) symxsize(2))
        plotregion(style(none))
        xscale(noline)
        xsize(85) ysize(48);
    #delimit cr
    graph export "$output\graphs\figure6.png", replace


* Figure 7: Country-level growth incidence curves: Pakistan & Tanzania
    use "$output\sectoralgrowthdist_clean.dta", clear
    merge 1:1 code quantile using "$output\dist_price_shock.dta", nogen

    sort code quantile
    by code: gen perc = ceil(_n/10)
    keep if inlist(code, "PAK", "TZA")
    replace pct_gr_scaled_2026 = pct_gr_scaled_2026*100
    replace sectoral_growth_2026 = sectoral_growth_2026*100
    replace g2026 = g2026*100

    keep code perc welf2025 pct_gr_scaled_2026 sectoral_growth_2026 g2026

    collapse (mean) welf2025 pct_gr_scaled_2026 sectoral_growth_2026 g2026, by(code perc)

    // Marker point: percentile where welfare is closest to 3 from below, by country
    gen gap3 = 3 - welf2025 if welf2025 < 3
    bys code: egen min_gap3 = min(gap3)
    gen marker_w3 = gap3 == min_gap3 & !missing(gap3)
    bys code (perc): replace marker_w3 = 0 if marker_w3 == 1 & sum(marker_w3) > 1
    drop gap3 min_gap3

    // Fit lpoly values at observed percentiles so markers sit on the plotted curve
    gen double perc_lpoly = .
    gen double pct_gr_lpoly = .
    foreach c in PAK TZA {
        capture drop x_lp y_lp
        lpoly pct_gr_scaled_2026 perc if code=="`c'", degree(2) bwidth(12) nograph at(perc) generate(x_lp y_lp)
        replace perc_lpoly = x_lp if code=="`c'"
        replace pct_gr_lpoly = y_lp if code=="`c'"
        drop x_lp y_lp
    }

    capture drop pct_gr_tick_lo pct_gr_tick_hi
    gen double pct_gr_tick_lo = 1.3 if marker_w3==1 & code=="TZA"
    replace pct_gr_tick_lo = 0.8 if marker_w3==1 & code=="PAK"
    gen double pct_gr_tick_hi = 2.3 if marker_w3==1 & code=="TZA"
    replace pct_gr_tick_hi = 1.08 if marker_w3==1 & code=="PAK"


    #delim ;
    twoway (rspike pct_gr_tick_hi pct_gr_tick_lo perc_lpoly if code=="PAK" & marker_w3==1, lcolor(#4895ef%20) lwidth(thick))
    (rspike pct_gr_tick_hi pct_gr_tick_lo perc_lpoly if code=="TZA" & marker_w3==1, lcolor(#f66420%20) lwidth(thick))
    (lpoly pct_gr_scaled_2026 perc if code=="PAK", degree(2) bwidth(12) lcolor(#1d2d44) lpattern(shortdash_dot))
    (lpoly pct_gr_scaled_2026 perc if code=="TZA", degree(2) bwidth(12) lcolor(#e85d04) lpattern(shortdash_dot))
    (line g2026 perc if code=="PAK", lcolor(#3e5c76) lwidth(thin) lpattern(dash))
    (line g2026 perc if code=="TZA", lcolor(#f48c06) lwidth(thin) lpattern(dash))
    (line sectoral_growth_2026 perc if code=="PAK", lcolor(#4895ef) lwidth(thin))
    (line sectoral_growth_2026 perc if code=="TZA", lcolor(#f66420) lwidth(thin)),
    legend(order(7 "Pakistan" 8 "Tanzania") row(1) pos(6) size(medium)) 
    ytitle("Growth rate, %") xtitle("Welfare percentile") yscale(range(0.8 3)) ylabel(1 (0.5) 3)
    xsize(60) ysize(48) ;
    #delim cr
    graph export "$output\graphs\figure7.png", replace


* B1: Predicted output shares
* B1a. By income and region
use "$output\temp\imputed_output_shares.dta", clear

gen order = 1 if incgroup=="Low income"
replace order = 2 if incgroup=="Lower middle income"
replace order = 3 if incgroup=="Upper middle income"
replace order = 4 if incgroup=="High income"

replace num= num/1000
replace alln = alln/1000
gen perc = num/alln *100

forval x = 1/3 {
    replace p`x' = p`x'*100
}

sort order region_code 

br incgroup region_code num perc p1 p2 p3 if region_code!="na"

    rename incgroup income_group
    rename region_code region
    rename perc pct_data
    rename p1 agriculture
    rename p2 industry
    rename p3 services

    foreach v in alln pct_data agriculture industry services {
        replace `v' = round(`v', 1)
    }

    label var income_group "Income group"
    label var region "Region"
    label var alln "N"
    label var pct_data "%data"
    label var agriculture "Agriculture"
    label var industry "Industry"
    label var services "Services"

    preserve
    keep if region!="na"
    keep income_group region alln pct_data agriculture industry services
    local b1xlsx "$output\graphs\tables.xlsx"

    capture confirm file "`b1xlsx'"
    if _rc {
        export excel income_group region alln pct_data agriculture industry services using "`b1xlsx'", firstrow(varlabels) sheet("B1a") cell(A1) replace
    }
    else {
        export excel income_group region alln pct_data agriculture industry services using "`b1xlsx'", firstrow(varlabels) sheet("B1a") cell(A1) sheetmodify
    }
    restore

* B1b: Predicted output shares by income only
    keep if region=="na"
    keep income_group alln pct_data agriculture industry services
        local b1xlsx "$output\graphs\tables.xlsx"

    capture confirm file "`b1xlsx'"
    if _rc {
        export excel income_group alln pct_data agriculture industry services using "`b1xlsx'", firstrow(varlabels) sheet("B1b") cell(A1) replace
    }
    else {
        export excel income_group alln pct_data agriculture industry services using "`b1xlsx'", firstrow(varlabels) sheet("B1b") cell(A1) sheetmodify
    }


* Figure B1: Predicted shares of employment by sector
    use "$temp\IndustrySharePredicted_fin.dta", clear

    keep perc s? s_inc? incgroup
    collapse (mean) s_inc?, by(incgroup perc)

    *Agriculture
    #delimit ;
        twoway (lpoly s_inc1 perc if incgroup=="Low income", degree(2) bwidth(12) lcolor(navy))
            (lpoly s_inc1 perc if incgroup=="Lower middle income", degree(2) bwidth(12) lcolor(red)) 
            (lpoly s_inc1 perc if incgroup=="Upper middle income", degree(2) bwidth(12) lcolor(green)) 
            (lpoly s_inc1 perc if incgroup=="High income", degree(2) bwidth(12) lcolor(orange)),
            legend(order(1 "Low income" 2 "Lower middle income" 3 "Upper middle income" 4 "High income") size(small) row(1) pos(6) symxsize(2))
            ytitle("share of employment") title("Agriculture")
            xtitle("Welfare percentile")  xsize(60) ysize(48)  ;
    #delimit cr
    graph export "$output\graphs\figureB1a.png", replace

    *Industry
    #delimit ;
        twoway (lpoly s_inc2 perc if incgroup=="Low income", degree(2) bwidth(12) lcolor(navy))
            (lpoly s_inc2 perc if incgroup=="Lower middle income", degree(2) bwidth(12) lcolor(red)) 
            (lpoly s_inc2 perc if incgroup=="Upper middle income", degree(2) bwidth(12) lcolor(green)) 
            (lpoly s_inc2 perc if incgroup=="High income", degree(2) bwidth(12) lcolor(orange)),
            legend(order(1 "Low income" 2 "Lower middle income" 3 "Upper middle income" 4 "High income") size(small) row(1) pos(6) symxsize(2))
            ytitle("share of employment") title("Industry")
            xtitle("Welfare percentile")  xsize(60) ysize(48)  ;
    #delimit cr
    graph export "$output\graphs\figureB1b.png", replace

    *Services
    #delimit ;
        twoway (lpoly s_inc3 perc if incgroup=="Low income", degree(2) bwidth(12) lcolor(navy))
            (lpoly s_inc3 perc if incgroup=="Lower middle income", degree(2) bwidth(12) lcolor(red)) 
            (lpoly s_inc3 perc if incgroup=="Upper middle income", degree(2) bwidth(12) lcolor(green)) 
            (lpoly s_inc3 perc if incgroup=="High income", degree(2) bwidth(12) lcolor(orange)),
            legend(order(1 "Low income" 2 "Lower middle income" 3 "Upper middle income" 4 "High income") size(small) row(1) pos(6) symxsize(2))
            ytitle("share of employment") title("Services")
            xtitle("Welfare percentile")  xsize(60) ysize(48)  ;
    #delimit cr
    graph export "$output\graphs\figureB1c.png", replace

    *Other
    #delimit ;
        twoway (lpoly s_inc4 perc if incgroup=="Low income", degree(2) bwidth(12) lcolor(navy))
            (lpoly s_inc4 perc if incgroup=="Lower middle income", degree(2) bwidth(12) lcolor(red)) 
            (lpoly s_inc4 perc if incgroup=="Upper middle income", degree(2) bwidth(12) lcolor(green)) 
            (lpoly s_inc4 perc if incgroup=="High income", degree(2) bwidth(12) lcolor(orange)),
            legend(order(1 "Low income" 2 "Lower middle income" 3 "Upper middle income" 4 "High income") size(small) row(1) pos(6) symxsize(2))
            ytitle("share of employment") title("Other")
            xtitle("Welfare percentile")  xsize(60) ysize(48)  ;
    #delimit cr
    graph export "$output\graphs\figureB1d.png", replace


* Figure C1: Projected no. of people living under $4.20
    use "$output\global_level_poverty.dta", clear

    keep if inrange(year, 2023, 2026)
        quietly destring npoor_*_420, replace force
        foreach x in jan sect pshock {
            replace npoor_`x'_420 = npoor_pip_420 if year == 2025
        }

        // Extract 2026 values for labeling
        foreach x in jan pip sect pshock {
            summ npoor_`x'_420 if year == 2026, meanonly
            local val_`x' = r(mean)
        }

        local text_2 ""
        local text_1 ""
        local text_3 ""
        local text_4 ""
        local y_pip = `val_pip' + 1
        local y_jan = `val_jan' - 2
        local y_sect = `val_sect' + 1
        local y_pshock = `val_pshock' + 4
        local lab_pip : display %9.0f `val_pip'
        local lab_jan : display %9.0f `val_jan'
        local lab_sect : display %9.0f `val_sect'
        local lab_pshock : display %9.0f `val_pshock'
        if !missing(`val_pip') local text_2 `"text(`y_pip' 2026 "`lab_pip'", color(navy) placement(e) size(small))"'
        if !missing(`val_jan') local text_1 `"text(`y_jan' 2026 "`lab_jan'", color(eltblue) placement(e) size(small))"'
        if !missing(`val_sect') local text_3 `"text(`y_sect' 2026 "`lab_sect'", color(red) placement(e) size(small))"'
        if !missing(`val_pshock') local text_4 `"text(`y_pshock' 2026 "`lab_pshock'", color(green) placement(e) size(small))"'

    #delimit ;
        twoway ///
            (line npoor_pip_420 year if year<=2025, lcolor(navy) lwidth(medthick))
            (line npoor_pip_420 year if year >= 2025, lpattern(dash) lcolor(navy)   lwidth(medium))
            (line npoor_jan_420 year if year >= 2025, lpattern(dash) lcolor(eltblue)   lwidth(medium))
            (line npoor_sect_420 year if year >= 2025, lpattern(dash) lcolor(red)    lwidth(medium))
            (line npoor_pshock_420 year if year >= 2025, lpattern(dash) lcolor(green)  lwidth(medium)),
            `text_2'
            `text_1'
            `text_3'
            `text_4'
            xlabel(2023(1)2026, angle(45)) yscale(range(1400 1600))
            ylabel(1400(50)1600, format(%9.0f)) 
            legend(order(1 "Baseline" 
                        3 "Pre-war growth projections" 
                        4 "Income shock" 
                        5 "Price shock")
                size(medium) col(1) pos(2) row(4) ring(0) symxsize(2)) 
            xtitle("") ytitle("Number of people (millions)") xsize(60) ysize(48) 
            plotregion(margin(r=10));
        
        #delimit cr
        graph export "$output\graphs\figureC1.png", replace

* Figure C2: Projected no. of people living under $8.30
    use "$output\global_level_poverty.dta", clear

    keep if inrange(year, 2023, 2026)
        foreach x in jan sect pshock {
            replace npoor_`x'_830 = npoor_pip_830 if year == 2025
        }

        // Extract 2026 values for labeling
        foreach x in jan sect pshock pip {
            summ npoor_`x'_830 if year == 2026, meanonly
            local val_`x' = r(mean)
        }

        local text_2 ""
        local text_1 ""
        local text_3 ""
        local text_4 ""
        local y_pip = `val_pip'
        local y_jan = `val_jan' - 2
        local y_sect = `val_sect' + 4
        local y_pshock = `val_pshock' + 3
        local lab_pip : display %9.0f `val_pip'
        local lab_jan : display %9.0f `val_jan'
        local lab_sect : display %9.0f `val_sect'
        local lab_pshock : display %9.0f `val_pshock'
        if !missing(`val_pip') local text_2 `"text(`y_pip' 2026 "`lab_pip'", color(navy) placement(e) size(medsmall))"'
        if !missing(`val_jan') local text_1 `"text(`y_jan' 2026 "`lab_jan'", color(eltblue) placement(e) size(medsmall))"'
        if !missing(`val_sect') local text_3 `"text(`y_sect' 2026 "`lab_sect'", color(red) placement(e) size(medsmall))"'
        if !missing(`val_pshock') local text_4 `"text(`y_pshock' 2026 "`lab_pshock'", color(green) placement(e) size(medsmall))"'

    #delimit ;
        twoway ///
            (line npoor_pip_830 year if year<=2025, lcolor(navy) lwidth(medthick))
            (line npoor_pip_830 year if year >= 2025, lpattern(dash) lcolor(navy)   lwidth(medium))
            (line npoor_jan_830 year if year >= 2025, lpattern(dash) lcolor(eltblue)   lwidth(medium))
            (line npoor_sect_830 year if year >= 2025, lpattern(dash) lcolor(red)    lwidth(medium))
            (line npoor_pshock_830 year if year >= 2025, lpattern(dash) lcolor(green)  lwidth(medium)),
            `text_2'
            `text_1'
            `text_3'
            `text_4'
            xlabel(2023(1)2026, angle(45)) yscale(range(3650 3800))
            ylabel(3650(50)3800, format(%9.0f)) 
            legend(order(1 "Baseline" 
                        3 "Pre-war growth projections" 
                        4 "Income shock" 
                        5 "Price shock")
                size(medium) col(1) pos(2) row(4) ring(0) symxsize(2)) 
            xtitle("") ytitle("Number of people (millions)") xsize(60) ysize(48) 
            plotregion(margin(r=10));
        
        #delimit cr
        graph export "$output\graphs\figureC2.png", replace