
//Create set of initators
use "MIDIP 5.0.dta", clear
drop if insidea==0
ren * *a //This adds "a" to the end of all variable names.
ren dispnuma dispnum
ren incidnuma incidnum
gen reva=(revtype1a!=0) //This designates whether the state is revisionist, but drops the the revision type, which simplifies the process below.
gen fatala=(fatality!=0) //This designates whether an incident had fatalities or not, but drops how many, which simplies the process below. I am assuming that values of -9 (missing) are fatal; you might want to make a different assumption.
save "Incident Initiators.dta", replace

//Create set of targets
use "MIDIP 5.0.dta", clear
drop if insidea==1
ren * *b
ren dispnumb dispnum
ren incidnumb incidnum
gen revb=(revtype1b!=0)
gen fatalb=(fatality!=0)
save "Incident Targets.dta", replace

//Join together initiators and targets to created dyadic incidents.
joinby incidnum using "Incident Initiators.dta"

//Identify start dates for each side
replace stdaya=1 if stdaya==-9 //This is the earliest possible start date.
replace stdayb=1 if stdayb==-9
gen long stdatea=styeara*10000+stmona*100+stdaya
gen long stdateb=styearb*10000+stmonb*100+stdayb
tostring stdatea, replace
tostring stdateb, replace
gen stdatea_td=date(stdatea, "YMD")
format stdatea_td %td
gen stdateb_td=date(stdateb, "YMD")
format stdateb_td %td

//Identify the earliest possible start date of the incident.
egen inc_start=rowmax(stdateb_td stdatea_td)
format inc_start %td
gen year=year(inc_start)

//Identify end dates for each side
replace enddaya=28 if enddaya==-9 //This is the latest possible end date that can be used conveniently.
replace enddayb=28 if enddayb==-9
gen long enddatea=endyeara*10000+endmona*100+enddaya
gen long enddateb=endyearb*10000+endmonb*100+enddayb
tostring enddatea, replace
tostring enddateb, replace
gen enddatea_td=date(enddatea, "YMD")
format enddatea_td %td
gen enddateb_td=date(enddateb, "YMD")
format enddateb_td %td

//Identify the latest possible end date of the incident.
egen inc_end=rowmin(enddateb_td enddatea_td)
format inc_end %td
gen endyear=year(inc_end)

// Make dyadid
gen ccodehigh=ccodea if ccodea>ccodeb
replace ccodehigh=ccodeb if ccodeb>ccodea
gen ccodelow=ccodea if ccodea<ccodeb
replace ccodelow=ccodeb if ccodeb<ccodea
gen dyadid=ccodehigh*1000+ccodelow

sort dispnum dyadid incidnum
save "temp.dta", replace //This will be used to merge in the hostlev, fatal, and rev variables later.

// Collapse incidents into dyadic MIDs
collapse (firstnm) ccodea ccodeb inc_start (max) inc_end, by(dispnum dyadid)

ren inc_start MIDstart
ren inc_end MIDend
gen source="Incidents"
save "Dyadic MID Dataset", replace

// Merge in hostlev, fatal, and rev for each side 
* The somewhat complicated procedure below is necessary to make sure that these variables are accurate for the dyad. If we did not care about accuracy by dyad, we could merge these variables in from MIDA or MIDB.
* This is tricky because in the incident-level data, Side A and B not consistent within a dyadic MID. They change by incident.

use "temp.dta", clear

gen hostlevlow=hostleva if ccodelow==ccodea
replace hostlevlow=hostlevb if ccodelow==ccodeb
gen hostlevhigh=hostleva if ccodehigh==ccodea
replace hostlevhigh=hostlevb if ccodehigh==ccodeb

gen fatallow=fatala if ccodelow==ccodea
replace fatallow=fatalb if ccodelow==ccodeb
gen fatalhigh=fatala if ccodehigh==ccodea
replace fatalhigh=fatalb if ccodehigh==ccodeb

gen revlow=reva if ccodelow==ccodea
replace revlow=revb if ccodelow==ccodeb
gen revhigh=reva if ccodehigh==ccodea
replace revhigh=revb if ccodehigh==ccodeb

sort dispnum dyadid ccodelow ccodehigh
save "temp.dta", replace

collapse (max) hostlevlow fatallow revlow, by (dispnum dyadid ccodelow) //ccodelow is not necessary for the command, but I need to retain the variable.
ren ccodelow ccode
ren hostlevlow hostlev
ren fatallow fatal
ren revlow rev
save "temp2.dta", replace

use "temp.dta", clear
collapse (max) hostlevhigh fatalhigh revhigh, by (dispnum dyadid ccodehigh) 
ren ccodehigh ccode
ren hostlevhigh hostlev
ren fatalhigh fatal
ren revhigh rev
append using "temp2.dta" //This dataset now contains the maximum value of hostlev, fatal, and rev for every country in every dyadic MID.
save "temp.dta", replace

// Now just merge these variables into the dyadic dataset that I already created.
use "Dyadic MID Dataset.dta", clear
ren ccodea ccode
merge 1:1 dispnum dyadid ccode using "temp.dta"
assert _merge!=1
drop if _merge==2
drop _merge
ren ccode ccodea
ren hostlev hostleva
ren fatal fatala
ren rev reva

ren ccodeb ccode
merge 1:1 dispnum dyadid ccode using "temp.dta"
assert _merge!=1
drop if _merge==2
drop _merge
ren ccode ccodeb
ren hostlev hostlevb
ren fatal fatalb
ren rev revb

gen startyear = year(MIDstart)
gen endyear = year(MIDend)

save "Dyadic MID Dataset.dta", replace

gen midduration = MIDend-MIDstart +1

gen length=2014-startyear+1
 expand length
 bys dyadid dispnum : gen year=startyear+_n-1
 bys dyadid year  : egen mid=max(inrange(year,startyear,end))
 *bys dyadid year  : keep if _n==1

keep if inrange(year,2011,2014) 
keep if inrange(year,startyear,endyear)

*gen annualmiddur = midduration if endyear==startyear
*replace annualmiddur = 365 if year>startyear & year<endyear

sort dispnum dyadid year

browse dispnum dyadid MIDstart MIDend year middur /*annualm*/ 

keep ccodea ccodeb MIDstart MIDend startyear endyear year mid midduration /*annualm*/
save "Undirected Dyad-year MID Dataset.dta", replace

rename ccodea ccodea1
rename ccodeb ccodea
rename ccodea ccodeb

save "Undirected Dyad-year MID Dataset.dta"_mirror, replace

append using "Undirected Dyad-year MID Dataset.dta"

egen ddyadyear = group(ccodea ccodeb year)
egen maxmiddur = max(midduration),by(ddyadyear)
replace midduration = maxmiddur
drop maxmiddur ddyadyear
duplicates drop

save "Directed Dyad-year MID Dataset.dta", replace

*Note: If you want annual mid duration, un-comment the annualm variables above. This will get it most of the way there. I found it easier to finish this in excel.
