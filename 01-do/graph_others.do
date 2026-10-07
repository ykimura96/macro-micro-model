


* Figure B1: Predicted shares of employment by sector
    use "$temp\IndustrySharePredicted_fin.dta", clear

    xtile quintile = perc, nq(5)

    keep region_code quintile s? s_inc? incgroup
    collapse (mean) s? s_inc?, by(region_code incgroup quintile)

