/*==============================================================================

FILE NAME:   deer_harvest_national_append.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions --
	 Ungulate Population & DVC Panel --
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Stack every state-level cleaned panel in $UngulatePopulationDataRepo/
          dataCLEAN into a single national county-year deer harvest panel 
	  carrying the analysis variables for the preliminary regressions:

              state  county_fips  county_name  year  harvest_total

          plus provenance flags and, from 10/2/2026, the harmonized sex-class
          columns (DECISIONS 15-22):

              harvest_antlered  harvest_antlerless  harvest_female
              harvest_female_adult  harvest_unknown_sex  sexclass_basis

          This is the input file for the weather -> deer harvest
          specifications. Every OTHER state-specific disaggregation (method,
          land ownership, habitat acreage, population indices) is still
          dropped -- those stay in the per-state files and can be re-merged
          later if a specification needs them.

          Two things make this more than an append:

          (1) Only 7 of the 14 agency-direct states carry a source-reported
              harvest_total in a form we can use directly. Seven need
              handling, and three of those (VA, WI, WV) are stored LONG
              with a "Total" stratum that must be SELECTED rather than
              summed.

          (2) The Schuler et al. CWD panel is used as a GAP-FILL source for
              states with no agency-direct harmonization of their own
              (FL, GA, IA, MI, MN). See DECISIONS 8-10 -- this is the part
              of the script most likely to draw questions, and the part
              with the sharpest measurement caveat.

SOURCE FILES USED (all from $UngulatePopulationDataRepo/dataCLEAN, as saved by 
the per-state do files):

  Agency-direct harmonizations (primary):
  
    AR_deer_harmonized_county_year_1988-2014.dta
    
    CA_deer_harmonized_county_year_1927-2009.dta
    
    DE_deer_harmonized_county_year_2010-2025.dta
    
    IN_deer_harmonized_county_year_2005-2016.dta
    
    KY_deer_harmonized_county_year_1990-2015.dta
    
    MD_deer_harmonized_county_year_1931-2014.dta
    
    MO_deer_harmonized_county_year_2002-2014.dta
    
    NC_deer_harmonized_county_year_1976-2014.dta
    
    NY_deer_harmonized_county_year_1954-2023.dta
    
    OH_deer_harmonized_county_year_1980-2014.dta
    
    TN_deer_harmonized_county_year_2005-2015.dta
    
    VA_deer_harmonized_county_year_1947-2014.dta
    
    WI_deer_harmonized_county_year_1960-2015.dta
    
    WV_deer_harmonized_county_year_2001-2020.dta

  Gap-fill source (secondary, non-overlapping states only):
  
    CWD_deer_harmonized_county_year_2000-2021.dta
      -- Schuler et al. (2024) North American Wildlife Agency CWD Testing
         and Ancillary Data. Covers 16 states, 2000-2021. Only its
         harvest_total is used here; the CWD surveillance, captive-cervid,
         regulation and habitat variables stay in that file and can be
         merged onto the panel downstream when a specification calls for
         them.

OUTPUT:

  $UngulatePopulationDataRepo/dataCLEAN/US_deer_harvest_county_year.dta
  
 CHANGELOG:

09/03/2026 — Nicole: First pass. Stacked the 13 agency-direct state panels
                     into one county-year harvest panel, added the CWD
                     gap-fill for FL/GA/IA/MI/MN, and wrote the DECISIONS
                     block below. Section 4 validation (key uniqueness,
                     FIPS/state agreement, source purity) and the Section 5
                     main-sample flags built at the same time.

09/04/2026 — Nicole: Added West Virginia once its harmonization landed,
                     bringing the agency-direct panel to 14 states / 1,087
                     counties / 38,660 observations, which reproduces the
                     data section exactly. Added flag_hand_transcribed for
                     WV's two image-scanned bulletins (DECISIONS 11, 12).

09/16/2026 — Nicole: Clean up pass, no change to data values. Fixed a guard
                     in Section 2n that could never fire: it read a LOCAL
                     `cwdfill' where the list is a GLOBAL, so the assert
                     always passed. Made the CWD imputation marker
                     version-tolerant -- the CWD harmonization now ships a
                     byte harvest_total_imputed in place of the string
                     flag_harvest_total, which would otherwise stop this
                     script on the next run. Added DECISION 14 and a
                     Section 4b listing for the four VA units that are not
                     current Census counties (51515, 51560, 51780, 51999),
                     three of which sit in the main sample. Shortened the
                     data label to Stata's 80-char limit and moved the long
                     form into -notes-, including a note that the panel was
                     rebuilt after AR dropped its 1988-1990 year shift.
                     Header typos fixed.

10/02/2026 — Nicole: Added harmonized sex-class columns (doe harvest bears on 
                     next year's population size): harvest_antlered, 
		     harvest_antlerless, harvest_female, harvest_female_adult, 
		     harvest_unknown_sex, plus sexclass_basis and two flags. 
		     Built here in the append, so the per-state files keep each 
		     agency's own taxonomy. Eleven agency states carry them 
		     (CA DE IN KY MD MO NY OH TN VA WI); AR, NC, and WV do
                     not. No row is added or dropped and harvest_total is
                     unchanged, so every Section 4-5 count still holds.
                     Section 2m (VA) restructured so the 13 fallback
                     county-years carry sex classes as well. DECISIONS 15-22.
		     
		     Added harvest_female for the CWD gap-fill states that
                     ship buck/doe: IA 2001-2020, GA 2016-2021, FL 2018-2020
                     (MI and MN ship totals only). The CWD columns are male
                     and female, not antlered and antlerless -- verified for
                     Iowa against Iowa DNR's published 2020 figures -- so
                     only harvest_female is filled. DECISION 23 added;
                     DECISION 21 and the Section 4h asserts revised to match.

==============================================================================
DECISIONS TAKEN IN THIS SCRIPT
==============================================================================

1. VA STORED LONG BY land_ownership WITH A "Total" STRATUM.

   Rows are Total / Private / Public. Where a source "Total" row exists
   (7,074 of 7,087 county-years) we TAKE IT and ignore Private/Public.
   Note that where all three strata exist, the source Total does NOT
   always equal Private + Public (max discrepancy 601 head). That
   discrepancy is the source file's -- VDWR's public-land tables are
   compiled separately from the county totals -- so we defer to the
   published county total. For the 13 county-years with no Total row we
   fall back to the sum of the ownership strata and set
   flag_total_constructed = 1.

2. VA county_fips IS 3 DIGITS IN THE CLEAN FILE.

   VA_deer_harmonized_county_year_1947-2014.dta stores "001", "003", ...
   -- the county part only, no "51" state prefix. Every other state stores
   the full 5-digit code. We repair it here (prefix "51") rather than upstream 
   so the VA file is not silently changed.

3. WI AND WV STORED LONG BY harvest_method WITH A "Total" STRATUM.

   WI rows are Total / Gun / Bow (/ XBow from 2014); WV rows are Total /
   BuckGun / AntlerlessGun / Bow / Muzzleloader / Unknown. We keep
   method == "Total" only, in both. Verified: WI's Total equals its
   components to within 2 head (agency rounding) and WV's matches exactly,
   so the source totals are internally consistent and nothing is lost by
   taking them.

4. STATES WITH NO SOURCE-REPORTED TOTAL -- total constructed as the sum of
   the reported components, flag_total_constructed = 1:
   
     DE  = antlered + unantlered
     
     MD  = antlered + antlerless
     
     MO  = total_firearm + total_archery   (the only two methods MO reports;
           each already reconciles exactly against its own components)
	   
     CA  = buck + doe_plm                  (see 5)
     
   The 7 states with a source total (AR, IN, KY, NC, NY, OH, TN) keep it
   as reported; flag_total_constructed = 0.

5. CA harvest_doe_plm IS MISSING IN 3,959 OF 4,814 ROWS (82%). 

   PLM (Private Lands Management) doe tags are a late, small, program-specific 
   category; the missings read as "program did not operate in this county-year", 
   not "unrecorded". We therefore treat missing doe_plm as zero WHEN harvest_buck 
   IS PRESENT, so CA total is effectively the buck kill in most years. If those 
   blanks should be read as unknown instead, CA total should be missing in 82% 
   of rows and the state is unusable outside buck-only specifications. Flagged, 
   not resolved. 34 CA county-years have harvest_buck missing too; those stay 
   missing.

6. ZEROS ARE RETAINED AS REPORTED, NOT RECODED TO MISSING.

   KY (14), NC (30), and NY (29) county-years report a harvest of exactly 0.
   These are reported zeros in low-deer counties (and, in NY, the five
   NYC boroughs / closed counties), not placeholder codes. Left alone.

7. THE PANEL IS NOT BALANCED.

   Coverage runs 1927-2025 and is wildly uneven by state. Section 5 builds
   the 2005-2014 main-sample flag rather than dropping anything, so the
   long historical series stay available for the robustness cuts.

8. GAP-FILL IS AT THE STATE LEVEL, NOT THE COUNTY-YEAR LEVEL. 

   A state is EITHER wholly agency-direct OR wholly CWD. We never patch CWD 
   years onto the end of a state we harmonized ourselves, even where CWD would 
   extend it (it would extend AR, TN and VA to 2021, and IN/KY/MD/NC/NY/OH/WI 
   to 2021).

   The two sources are the SAME conceptual quantity -- total county deer
   harvest, same season-start-year convention (verified: alignment is at
   lag 0, not +/-1) -- but they are DIFFERENT COMPILATION VINTAGES, and
   they do not agree. Across the county-years where both are present and
   non-imputed:

       AR   1,050 pairs    63% exact    median ratio 1.000   max diff 5,631
       
       WI   1,151 pairs    28% exact    median ratio 1.004   max diff   329
       
       NY     168 pairs     4% exact    median ratio 1.007   max diff 2,588
       
       TN      94 pairs      0% exact   median ratio 0.969   max diff   601

   The medians say the two series measure the same thing; however the exact-
   match rates say Schuler et al. captured an earlier vintage of the agency
   numbers than the ones we requested directly. Splicing a different vintage 
   onto the END of a county's own time series would put a step in the within-
   county variation and county FE would likely not absorb it. Across states it 
   is far more benign: a level or scale difference that is constant within a 
   state could be absorbed by county FE.

   So: gap-fill whole states, never partial series. source_harvest records
   which compilation each observation came from, so every specification can
   be re-run agency-only as a robustness check (see Section 5).

9. IMPUTED CWD HARVEST VALUES ARE NOT USED.

   CWD's flag_harvest_total marks 1,498 rows "imputed". Of the imputed rows
   that overlap our agency-direct data, ZERO match (vs. 47% of the
   non-imputed rows). They are excluded from harvest_total and parked in 
   harvest_total_cwd_imputed so the sensitivity check is still available. 336 
   of them fall in the gap-fill states.

10. MISSISSIPPI CONTRIBUTES NOTHING AND IS EXCLUDED EXPLICITLY.

    MS appears in the CWD panel (1,804 rows) but has zero non-missing
    harvest values, which is exactly what the data section's footnote
    predicts: MS is the only state with no mandatory game check, estimates
    harvest from voluntary post-season surveys, and publishes a statewide
    figure with no county detail. The CWD panel agrees. Excluded by name
    rather than silently dropped, as a check on that footnote.

11. WEST VIRGINIA IS IN, AND THE PANEL NOW MATCHES THE PAPER EXACTLY.

    WV is stored long by harvest_method (Total / BuckGun / AntlerlessGun /
    Bow / Muzzleloader / Unknown) with the harvest column named simply
    `harvest`. We take the Total stratum; it reconciles against its
    components with a maximum discrepancy of ZERO across all 1,100
    county-years. That contributes 55 counties x 20 years (2001-2020), and
    brings the agency-direct panel to 14 states / 1,087 counties / 38,660
    observations. NOTE: WV's kill_per_sqmi is a harvest-derived INDEX, not a 
    population count (see the appendix insert). It is not used here and must 
    not be treated as a population measure downstream.

12. WV 2001-2005 AND 2011-2015 WERE HAND-TRANSCRIBED FROM IMAGE SCANS.

    Two of the four Big Game Bulletins have no text layer, and the WV
    harmonization transcribed those county tables by hand, verifying every
    figure against the printed district and state subtotals. But five of those 
    years sit INSIDE the 2005-2014 main sample -- 2005, and 2011 through 2014 -- 
    which is 275 county-years, about 2.7% of the sample, and the only hand-read
    data in the panel. flag_hand_transcribed carries the WV source_scanned
    marker through, so every headline result can be re-run dropping it. If
    a coefficient depends on those rows, that needs to be known.

13. THE MAIN SAMPLE IS 1,020 COUNTIES, WHILE THE DATA SECTION SAYS 1,022.

    1,022 counties are PRESENT in all ten years of 2005-2014, but two of
    them carry a missing harvest value in one of those years and so cannot
    actually be estimated on:
    
        29227  MO  Worth County   -- missing 2011
	
        55078  WI  Menominee      -- missing 2014
	
    Menominee is the known structural gap already documented in the WI
    harmonization. main_sample is built on NON-MISSING balance, because
    that is what the regression will actually use, so it returns 1,020. If 
    the text is meant to describe the estimation sample rather than data 
    availability, those two counties and 20 observations should come out of 
    the published figure.

14. THREE VA UNITS ARE NOT CURRENT COUNTIES, AND A FOURTH IS NOT A PLACE AT ALL.

    VDWR's harvest file keeps reporting independent cities that have since
    been absorbed, and the VA panel carries them through 2014:

        51515  Bedford (City of)        merged into Bedford County, 2013
	
        51560  Clifton Forge (City of)  merged into Alleghany County, 2001
	
        51780  South Boston (City of)   reverted to a town, Halifax Co, 1995
	
        51999  "Unknown"                not a place: the source's catch-all
                                        row, 1981-1995, 9 county-years

    51515, 51560 and 51780 are each flagged main_sample for all ten years
    of 2005-2014 -- 30 county-years -- and none of the four will match a
    current county boundary file or a Census county covariate. They are
    therefore silent dropouts at the weather merge rather than visible
    problems here. 51999 is the same object as MO's UNKNOWN row and CA's
    Unknown county, both of which their own harmonizations excluded.

    Nothing is changed here. Section 4b lists them on every run so the decision 
    is not made by forgetting.
    
15. SEX-CLASS COLUMNS: WHAT GOES WHERE.                      [DECIDE: Eyal]

    Two definitions are carried, because the states do not all support
    the one Eyal actually wants:

      harvest_antlered     antlered / adult males
      
      harvest_antlerless   everything else that was classified: ALL females
                           plus male fawns / button bucks
			   
      harvest_female       females of ALL ages (doe fawns included)
      
      harvest_female_adult adult females only -- NY alone can supply it
      
      harvest_unknown_sex  deer the source could not classify

    so that antlered + antlerless + unknown = harvest_total.

    (a) Male fawns / button bucks go in ANTLERLESS and stay out of FEMALE.
        IN, MD, WI and DE already fold them into antlerless and cannot
        separate them, so no other antlerless definition is consistent
        across states.
	
    (b) Unknowns go in NEITHER class. They are under 1% of harvest in
        every state that tracks them (OH 0.7%, VA 0.4%, MO 0.1%), so
        allocating them proportionally would buy nothing.
	
    (c) Female fawns stay IN harvest_female: only NY separates them, and a
        harvested doe fawn is still a female removed from next year's
        breeding population. NY's adult-female series is kept alongside
        for a NY-only check (within county and year the two correlate at
        0.998 in logs).

    Antlerless is the only measure for CA, DE, IN, KY, MD and WI; female
    exists for MO, NY, OH, TN and VA.

    sexclass_basis records how each county-year's columns were obtained:
    
      0 - none   
      
      1 - antlered/antlerless as reported 
      
      2 - built from sex-age classes  
      
      3 - buck/doe as labeled   
      
      4 - antlerless = total - antlered
      
      5 - female only (males not split by antler status)

16. VA ANTLERED / ANTLERLESS ARE ONLY VALID FROM 1994.

    harvest_fawn_male is zero in EVERY VA row before 1994 and positive in
    99% of Total rows in 1994 itself. The antlered share of harvest drops
    from 58% (1993) to 46% (1994) while the all-male share is flat (57.9%
    -> 57.5%). So before 1994 "antlered male" is all males, button bucks
    included. harvest_antlered and harvest_antlerless are therefore
    missing for VA before 1994 (sexclass_basis = 5); harvest_female is
    carried for every year. Section 2m asserts the zero.

17. KY ANTLERLESS IS A RESIDUAL, AND SEVEN ROWS ARE DROPPED.
                                                             
    KY reports total and buck only (buck from 1999), so antlerless =
    total - buck. That is antlerless only if "buck" means ANTLERED; if it
    means all males the residual is female. Buck is 43-49% of the KY
    total (46% pooled). In the five states that separate the classes the
    antlered share is 39-51% and the all-male share 52-56%, so KY sits
    inside the antlered range and below the all-male one. That supports
    the antlered reading without settling it -- confirm with KDFWR (Joe
    McDermott).

    McCreary County (21147) reports buck > total in seven years (2006,
    2008-2013). Both columns are set to missing there rather than left
    with a negative antlerless.

18. CA ANTLERLESS FOLLOWS DECISION 5.                        

    harvest_antlerless is harvest_doe_plm, zero-filled where harvest_buck
    is present -- the same rule the CA total already uses, so the classes
    add to the total. flag_antlerless_zerofill marks the 3,925 filled
    cells. Evidence for reading the blanks as zeros: doe is never a
    RECORDED zero in any of its 855 non-missing cells, so the source
    table appears to list only counties with a kill. 
    
    If we want to read the blanks as unknown instead, set harvest_antlerless to 
    missing where the flag is 1 -- and DECISION 5 should change with it. Note 
    buck EXCLUDES PLM take while doe INCLUDES it (the CA harmonization's
    standing caveat). "Buck/doe" is taken as labeled: sexclass_basis = 3.

19. IN: THE GAP BETWEEN THE TOTAL AND ITS CLASSES IS TREATED AS UNKNOWN.

    IN's source total differs from antlered + antlerless in 72 rows. In
    62 the total is LARGER (1,316 head, nearly all 2012-2013), which is
    what unclassified deer look like, so the positive gap is carried as
    harvest_unknown_sex. In 10 rows the classes exceed the total by 1-4
    head; unknown is set to 0 there and flag_sexclass_nosum = 1.

20. DE AND MO DETAILS.

    DE 2010-2015 antlerless was DERIVED upstream as total - antlered (the
    Boyd file reports only total and antlered): sexclass_basis = 4 for
    those years, 1 for 2022-2025.
    
    MO classes are summed over firearm and archery. MO unknowns are
    nonzero only in 2002-2004, recorded as zero 2005-2011 and untracked
    2012-2014. Ste. Genevieve 2005 archery is off by 2 head in the source
    and is the one MO row with flag_sexclass_nosum = 1.

21. NO SEX CLASSES FOR AR, NC, WV, MI OR MN.

    AR and NC agency files are total-only and WV reports by method. The
    Schuler et al. panel cannot fill them: it ships no buck/doe for AR at
    all, and for NC only 2018-2020, after the NC agency series ends in
    2014 (and borrowing it would mix compilation vintages inside a state,
    which DECISION 8 rules out). For MI and MN the CWD panel ships totals
    only. Section 4h asserts all five are missing, so adding any of them
    later is a conscious edit.
    
22. CAVEATS THAT TRAVEL WITH THE NEW COLUMNS.

    NY: "adult male" is taken as antlered, which is approximate (it
        counts any adult buck without antlers). The male:female fawn
        ratio falls from about 1.2 to 0.9 starting in 2016, which looks
        like a change in how NYSDEC classifies fawns; it moves fawns
        between harvest_female and not-female after 2015.
	
    TN: antlerless males are 11% of antlerless, about half the share in
        MO, OH, VA and NY. If hunters check button bucks in as does, TN
        harvest_female is overstated. Worth asking TWRA.
	
23. CWD GAP-FILL STATES CARRY harvest_female ONLY.      

    The Schuler et al. panel ships harvest_buck and harvest_doe for three
    of the five gap-fill states: IA 2001-2020, GA 2016-2021, and FL
    2018-2020 (3,135 county-years, never on an imputed row). Its metadata
    defines them as MALE and FEMALE harvest, not antlered and antlerless,
    and for Iowa that is verifiably what they are: the 2020 statewide
    sums are doe 51,253 and buck 58,291, which are exactly Iowa DNR's
    published does (51,253) and antlered + button + shed-antlered bucks
    (48,696 + 8,629 + 966). So "buck" contains the button bucks and
    cannot serve as antlered.

    We therefore set harvest_female = harvest_doe and leave antlered and
    antlerless missing: sexclass_basis = 5, the same code as VA before
    1994. harvest_buck is not carried; it is total - female to within 1
    head (three IA 2010 rows are off by 1, left as shipped).

    GA and FL are taken on the metadata's word and are NOT verified
    against the agencies. The panel is not uniform across states -- in
    the overlap with our own files its TN columns behave as male/female
    but its NY buck column tracks adult males -- so if either state's
    "doe" is really antlerless, its harvest_female is overstated by the
    button bucks. FL's doe share is 34% against 49-50% in GA and IA. Both
    lie outside 2005-2014; IA is the only gap-fill state inside it (990
    county-years).

    IA 2001-2005 IS ON A DIFFERENT BASIS. Iowa moved to mandatory harvest
    reporting in 2006 and Iowa DNR states that estimates for 2005 and
    earlier are not comparable with later years. The IA statewide total
    falls from 207,504 (2005) to 150,552 (2006). That affects IA's
    harvest_total as well as harvest_female, and 2005 is inside the main
    sample.

==============================================================================*/

clear all
set more off
set varabbrev off
version 16.1

capture log close

* ---- paths: identical block to every per-state harmonization do file -------
global root "/mnt/data_d/Dropbox/Research/UngulatePopulationDataRepo"
global dataRAW   "$root/dataRAW"
global dataSTATA "$root/dataSTATA"
global dataCLEAN "$root/dataCLEAN"
global codeSTATA "$root/codeSTATA"

di "$root"
di "$dataCLEAN"

cap mkdir "$codeSTATA/logs"
log using "$codeSTATA/logs/deer_harvest_national_append.log", replace text

cap mkdir "$dataSTATA/_append"

* ---- state lists -----------------------------------------------------------
* GLOBALS, not locals: these are defined here in Section 0 but consumed in 
* Sections 2n, 3 and 6. Globals persist across separate executions, so the 
* piecewise and end-to-end runs give the same answer.
global agencylist "AR CA DE IN KY MD MO NC NY OH TN VA WI WV"
global cwdfill    "FL GA IA MI MN"

* ---- fail early and loudly if a source file is not where we expect ---------
* Exact paths, so a renamed or re-dated clean file is caught here rather
* than later. If a per-state harmonization is re-run with a new year range, 
* update the name in BOTH this list and its "use" line.
local _srcfiles                                           ///
    AR/AR_deer_harmonized_county_year_1988-2014           ///
    CA/CA_deer_harmonized_county_year_1927-2009           ///
    DE/DE_deer_harmonized_county_year_2010-2025           ///
    IN/IN_deer_harmonized_county_year_2005-2016           ///
    KY/KY_deer_harmonized_county_year_1990-2015           ///
    MD/MD_deer_harmonized_county_year_1931-2014           ///
    MO/MO_deer_harmonized_county_year_2002-2014           ///
    NC/NC_deer_harmonized_county_year_1976-2014           ///
    NY/NY_deer_harmonized_county_year_1954-2023           ///
    OH/OH_deer_harmonized_county_year_1980-2014           ///
    TN/TN_deer_harmonized_county_year_2005-2015           ///
    VA/VA_deer_harmonized_county_year_1947-2014           ///
    WI/WI_deer_harmonized_county_year_1960-2015           ///
    WV/WV_deer_harmonized_county_year_2001-2020           ///
    CWD_deer_harmonized_county_year_2000-2021

local _missing 0
foreach f of local _srcfiles {
    capture confirm file "$dataCLEAN/`f'.dta"
    if _rc {
        display as error "  not found: $dataCLEAN/`f'.dta"
        local _missing 1
    }
}
if `_missing' {
    display as error "one or more source files are missing -- check $dataCLEAN and its subfolders"
    exit 601
}
local _nsrc : word count `_srcfiles'
display as text "  all `_nsrc' source files located"

/*==============================================================================
* SECTION 1: STANDARDIZE AND STASH ONE STATE
*==============================================================================

  Every state block ends by calling this. It enforces the common schema so
  that the append in Section 3 cannot silently create ragged variables:
  string county_fips, string county_name, int year, double harvest_total.
  
==============================================================================*/

capture program drop stash_state
program define stash_state
    syntax , STate(string) [CONstructed(integer 0) SOurce(string)]

    if "`source'" == "" local source "agency"

    * -- required variables present?
    foreach v in county_fips county_name year harvest_total {
        capture confirm variable `v'
        if _rc {
            display as error "`state': required variable `v' not found"
            exit 111
        }
    }

    * -- county_fips: force to a 5-digit zero-padded string
    capture confirm string variable county_fips
    if _rc {
        tostring county_fips, replace force
    }
    replace county_fips = trim(county_fips)
    * repair 3-digit (county-part-only) codes -- see DECISION 2
    if "`state'" == "VA" {
        replace county_fips = "51" + county_fips if length(county_fips) == 3
    }
    replace county_fips = string(real(county_fips), "%05.0f") ///
        if length(county_fips) < 5 & real(county_fips) < .

    * -- county_name: trim only. Casing is left as the source reported it;
    *    the panel keys on FIPS, and name casing differs across agencies.
    capture confirm string variable county_name
    if !_rc replace county_name = trim(county_name)

    * -- year: several clean files store year as float -- see TN/VA/WI
    capture confirm string variable year
    if !_rc destring year, replace
    replace year = round(year)
    recast int year, force

    recast double harvest_total, force

    capture drop state
    generate str2 state = "`state'"

    * -- VA arrives with a row-level flag already set (Total vs. constructed
    *    from ownership strata); every other state gets the block-level value
    capture confirm variable flag_total_constructed
    if _rc generate byte flag_total_constructed = `constructed'

    * -- provenance: which compilation this observation came from
    capture drop source_harvest
    generate str6 source_harvest = "`source'"

    * -- imputed CWD values are parked, not used -- see DECISION 9
    capture confirm variable harvest_total_cwd_imputed
    if _rc generate double harvest_total_cwd_imputed = .

    * -- WV arrives with a row-level hand-transcription flag -- see DECISION 12
    capture confirm variable flag_hand_transcribed
    if _rc generate byte flag_hand_transcribed = 0

    * -- sex-class columns (DECISION 15). A state block that can build
    *    them leaves them in memory under these exact names; a state with
    *    no sex detail gets them here as missing.
    foreach v in harvest_antlered harvest_antlerless harvest_female ///
                 harvest_female_adult harvest_unknown_sex {
        capture confirm variable `v'
        if _rc generate double `v' = .
        recast double `v'
    }
    capture confirm variable sexclass_basis
    if _rc generate byte sexclass_basis = 0
    * a county-year with no class at all has no basis, whatever its state
    replace sexclass_basis = 0 if mi(harvest_antlered) & ///
        mi(harvest_antlerless) & mi(harvest_female)
    capture confirm variable flag_antlerless_zerofill
    if _rc generate byte flag_antlerless_zerofill = 0

    keep  state county_fips county_name year harvest_total ///
          harvest_antlered harvest_antlerless harvest_female ///
          harvest_female_adult harvest_unknown_sex sexclass_basis ///
          flag_antlerless_zerofill ///
          harvest_total_cwd_imputed flag_total_constructed source_harvest ///
          flag_hand_transcribed
    order state county_fips county_name year harvest_total ///
          harvest_antlered harvest_antlerless harvest_female ///
          harvest_female_adult harvest_unknown_sex sexclass_basis ///
          flag_antlerless_zerofill ///
          harvest_total_cwd_imputed flag_total_constructed source_harvest ///
          flag_hand_transcribed

    * -- the key must be unique BEFORE we append, or the bug hides in the pile
    isid county_fips year

    quietly count
    display as text "  `state' (`source'): " %6.0f r(N) " county-year observations stashed"

    save "$dataSTATA/_append/_std_`state'.dta", replace
end

/*==============================================================================
* SECTION 2: STATE-BY-STATE STANDARDIZATION
*==============================================================================*/

display as text _newline "{hline 78}"
display as text "SECTION 2: standardizing state files"
display as text "{hline 78}"

* -----------------------------------------------------------------------------
* 2a-2g. AGENCY-DIRECT STATES WITH A SOURCE-REPORTED TOTAL
* -----------------------------------------------------------------------------

use "$dataCLEAN/AR/AR_deer_harmonized_county_year_1988-2014.dta", clear
stash_state, state(AR)

use "$dataCLEAN/IN/IN_deer_harmonized_county_year_2005-2016.dta", clear
* -- sex classes (DECISION 19): harvest_antlered and harvest_antlerless
*    already carry the panel names. The source total exceeds their sum in
*    62 rows and falls short in 10; the positive gap is carried as unknown.
generate double harvest_unknown_sex = harvest_total - harvest_antlered - harvest_antlerless
quietly count if harvest_unknown_sex > 0
assert r(N) == 62
quietly count if harvest_unknown_sex < 0
assert r(N) == 10
replace harvest_unknown_sex = 0 if harvest_unknown_sex < 0
generate byte sexclass_basis = 1
stash_state, state(IN)

use "$dataCLEAN/KY/KY_deer_harmonized_county_year_1990-2015.dta", clear
* -- sex classes (DECISION 17): antlerless is the residual total - buck,
*    1999 on. This is antlerless only if KY "buck" means antlered; if it means 
*    all males, the residual is female.
generate byte _bad = harvest_buck > harvest_total & !mi(harvest_buck)
quietly count if _bad
assert r(N) == 7
* all seven are McCreary (21147): buck > total. Set missing, not negative.
assert county_fips == "21147" if _bad
generate double harvest_antlered   = harvest_buck                 if !_bad
generate double harvest_antlerless = harvest_total - harvest_buck if !_bad
generate byte   sexclass_basis     = cond(!mi(harvest_antlerless), 4, 0)
drop _bad
stash_state, state(KY)

use "$dataCLEAN/NC/NC_deer_harmonized_county_year_1976-2014.dta", clear
stash_state, state(NC)

use "$dataCLEAN/NY/NY_deer_harmonized_county_year_1954-2023.dta", clear
* -- sex classes (DECISIONS 15, 22): adult male is taken as antlered; this
*    closes the taxonomy [DECIDE] left open in the NY harmonization.
generate double harvest_antlered     = harvest_adult_male
generate double harvest_female       = harvest_adult_female + harvest_fawn_female
generate double harvest_antlerless   = harvest_fawn_male + harvest_female
generate double harvest_female_adult = harvest_adult_female
assert abs(harvest_antlered + harvest_antlerless - harvest_total) < 1
generate byte   sexclass_basis       = 2
stash_state, state(NY)

use "$dataCLEAN/OH/OH_deer_harmonized_county_year_1980-2014.dta", clear
* -- sex classes (DECISION 15): button bucks are antlerless, not female.
*    harvest_unknown is tracked 1980-2003 and missing 2004-2014.
generate double harvest_antlered    = harvest_buck
generate double harvest_female      = harvest_doe
generate double harvest_antlerless  = harvest_button + harvest_doe
generate double harvest_unknown_sex = harvest_unknown
assert abs(harvest_antlered + harvest_antlerless + ///
    cond(mi(harvest_unknown_sex), 0, harvest_unknown_sex) - harvest_total) < 1
generate byte   sexclass_basis      = 2
stash_state, state(OH)

use "$dataCLEAN/TN/TN_deer_harmonized_county_year_2005-2015.dta", clear
* -- sex classes (DECISIONS 15, 22): harvest_female already carries the
*    panel name. Antlerless males are antlerless, not female.
generate double harvest_antlered   = harvest_antlered_male
generate double harvest_antlerless = harvest_antlerless_male + harvest_female
assert abs(harvest_antlered + harvest_antlerless - harvest_total) < 1
generate byte   sexclass_basis     = 2
stash_state, state(TN)

* -----------------------------------------------------------------------------
* 2h. DELAWARE -- total = antlered + unantlered          DECISION 4
* -----------------------------------------------------------------------------

use "$dataCLEAN/DE/DE_deer_harmonized_county_year_2010-2025.dta", clear
egen double harvest_total = rowtotal(harvest_antlered harvest_unantlered), missing
* -- sex classes (DECISION 20): harvest_antlered already carries the panel
*    name. 2010-2015 unantlered was derived upstream as total - antlered.
generate double harvest_antlerless = harvest_unantlered
generate byte   sexclass_basis     = cond(year <= 2015, 4, 1)
stash_state, state(DE) constructed(1)

* -----------------------------------------------------------------------------
* 2i. MARYLAND -- total = antlered + antlerless          DECISION 4
* -----------------------------------------------------------------------------

use "$dataCLEAN/MD/MD_deer_harmonized_county_year_1931-2014.dta", clear
egen double harvest_total = rowtotal(harvest_antlered harvest_antlerless), missing
* -- sex classes: both columns already carry the panel names, as reported
generate byte sexclass_basis = 1
stash_state, state(MD) constructed(1)

* -----------------------------------------------------------------------------
* 2j. MISSOURI -- total = firearm total + archery total  DECISION 4
*     Verified upstream: harvest_total_firearm reconciles exactly against
*     buck + button buck + doe + unknown, so we sum the two method totals
*     rather than the eight components.
* -----------------------------------------------------------------------------

use "$dataCLEAN/MO/MO_deer_harmonized_county_year_2002-2014.dta", clear

egen double _chk_firearm = rowtotal(harvest_buck_firearm harvest_bbuck_firearm ///
    harvest_doe_firearm harvest_unk_firearm), missing
assert abs(_chk_firearm - harvest_total_firearm) < 1 ///
    if !mi(_chk_firearm, harvest_total_firearm)
drop _chk_firearm

egen double harvest_total = rowtotal(harvest_total_firearm harvest_total_archery), missing

* -- sex classes (DECISIONS 15, 20): summed over firearm and archery with a
*    plain +, so a missing component leaves the class missing (Worth 2011).
*    Unknown is untracked 2012-2014 and stays missing there.
generate double harvest_antlered    = harvest_buck_firearm  + harvest_buck_archery
generate double harvest_female      = harvest_doe_firearm   + harvest_doe_archery
generate double harvest_antlerless  = harvest_bbuck_firearm + harvest_bbuck_archery ///
                                      + harvest_female
generate double harvest_unknown_sex = harvest_unk_firearm   + harvest_unk_archery
generate byte   sexclass_basis      = 2
stash_state, state(MO) constructed(1)

* -----------------------------------------------------------------------------
* 2k. CALIFORNIA -- total = buck + doe (PLM)             DECISION 5
*     Missing doe_plm treated as zero where buck is present. See header.
* -----------------------------------------------------------------------------

use "$dataCLEAN/CA/CA_deer_harmonized_county_year_1927-2009.dta", clear

generate double harvest_total = harvest_buck + cond(mi(harvest_doe_plm), 0, harvest_doe_plm)
replace harvest_total = . if mi(harvest_buck)

quietly count if mi(harvest_doe_plm) & !mi(harvest_buck)
display as text "  CA: " r(N) " county-years with doe_plm missing -> treated as 0 (DECISION 5)"

* -- sex classes (DECISION 18): antlerless takes the same zero-fill as the
*    total, so the classes add up. If the blanks are unknown rather than zero, 
*    replace the fill with:
*        replace harvest_antlerless = . if flag_antlerless_zerofill == 1
generate double harvest_antlered   = harvest_buck
generate double harvest_antlerless = cond(mi(harvest_doe_plm), 0, harvest_doe_plm) ///
    if !mi(harvest_buck)
generate byte   flag_antlerless_zerofill = mi(harvest_doe_plm) & !mi(harvest_buck)
generate byte   sexclass_basis     = cond(!mi(harvest_buck), 3, 0)
quietly count if flag_antlerless_zerofill == 1
assert r(N) == 3925

stash_state, state(CA) constructed(1)

* -----------------------------------------------------------------------------
* 2l. WISCONSIN -- long by harvest_method; keep the "Total" stratum
*                                                        DECISION 3
* -----------------------------------------------------------------------------

use "$dataCLEAN/WI/WI_deer_harmonized_county_year_1960-2015.dta", clear

* -- confirm the source Total really is the sum of the method strata before
*    we rely on it (allow 2 head for the agency's own rounding)
preserve
    egen double _t = rowtotal(harvest_antlered harvest_antlerless), missing
    collapse (sum) _parts = _t if inlist(harvest_method, "Gun", "Bow", "XBow"), ///
        by(county_fips year)
    tempfile _wiparts
    save `_wiparts'
restore
preserve
    keep if harvest_method == "Total"
    egen double _tot = rowtotal(harvest_antlered harvest_antlerless), missing
    merge 1:1 county_fips year using `_wiparts', assert(match) nogenerate
    assert abs(_tot - _parts) <= 2 if !mi(_tot, _parts)
    display as text "  WI: source Total reconciles against Gun+Bow+XBow (<=2 head)"
restore

keep if harvest_method == "Total"
egen double harvest_total = rowtotal(harvest_antlered harvest_antlerless), missing
* -- sex classes: the Total stratum's antlered and antlerless already carry
*    the panel names, as reported
generate byte sexclass_basis = 1
stash_state, state(WI)

* -----------------------------------------------------------------------------
* 2m. VIRGINIA -- long by land_ownership; prefer the "Total" stratum,
*                 fall back to Private + Public where no Total row exists
*                                                        DECISIONS 1, 2
* -----------------------------------------------------------------------------

use "$dataCLEAN/VA/VA_deer_harmonized_county_year_1947-2014.dta", clear

egen double _t = rowtotal(harvest_antlered_male harvest_fawn_male ///
    harvest_female harvest_unknown), missing

* -- sex classes (DECISIONS 15, 16), built row-wise BEFORE the Total-vs-
*    strata split so both paths carry them. harvest_female already has the
*    panel name and is usable in every year. Antlered and antlerless exist
*    only from 1994: before that the source does not separate male fawns,
*    so "antlered male" is all males.
generate double harvest_antlered    = harvest_antlered_male              if year >= 1994
generate double harvest_antlerless  = harvest_fawn_male + harvest_female if year >= 1994
generate double harvest_unknown_sex = harvest_unknown

* -- (i) the source-reported Total rows
preserve
    keep if land_ownership == "Total"
    * DECISION 16 rests on this: no male fawn is recorded before 1994
    assert harvest_fawn_male == 0 if year < 1994
    keep county_fips county_name year _t harvest_antlered ///
        harvest_antlerless harvest_female harvest_unknown_sex
    rename _t harvest_total
    generate byte flag_total_constructed = 0
    tempfile _vatotal
    save `_vatotal'
restore

* -- (ii) county-years with no Total row: sum the ownership strata.
*    The class sums go in under _s_ names so that -merge, update replace-
*    cannot leave a strata sum sitting where the Total row is missing.
keep if land_ownership != "Total"
collapse (sum) harvest_total  = _t                  ///
               _s_antlered    = harvest_antlered    ///
               _s_antlerless  = harvest_antlerless  ///
               _s_female      = harvest_female      ///
               _s_unknown_sex = harvest_unknown_sex ///
         (firstnm) county_name, by(county_fips year)
generate byte flag_total_constructed = 1

merge 1:1 county_fips year using `_vatotal', update replace
* update replace: the source Total wins wherever it exists
quietly count if _merge == 1
display as text "  VA: " r(N) " county-years with no source Total -> summed from ownership strata (DECISION 1)"

* -- the fallback county-years take their sex classes from the strata too.
*    All 13 are 2004-2010, so the 1994 rule does not bind on them.
assert year >= 1994 if _merge == 1
foreach v in antlered antlerless female unknown_sex {
    replace harvest_`v' = _s_`v' if _merge == 1
}
drop _s_antlered _s_antlerless _s_female _s_unknown_sex _merge

generate byte sexclass_basis = cond(year >= 1994, 2, 5)

stash_state, state(VA)

/*-----------------------------------------------------------------------------
* 2n. CWD GAP-FILL STATES                          DECISIONS 8, 9, 10
*
*     States present in the Schuler et al. CWD panel for which we have NO
*     agency-direct harmonization. Whole states only -- we never patch CWD
*     years onto a state we harmonized ourselves. See DECISION 8.
*
*     MS is deliberately excluded: it appears in the CWD panel but has zero
*     non-missing harvest values, exactly as the data section's footnote
*     predicts. See DECISION 10.
*-----------------------------------------------------------------------------*/

* -- $cwdfill and $agencylist are set in Section 0. Fail loudly rather than
*    quietly skipping the gap-fill if Section 0 was not run.
if "$cwdfill" == "" | "$agencylist" == "" {
    display as error "state-list globals not set -- run Section 0 first"
    exit 198
}

use "$dataCLEAN/CWD_deer_harmonized_county_year_2000-2021.dta", clear

* -- guard: if any of these states later gets its own harmonization, this
*    assert fires and forces a conscious decision instead of a silent
*    duplicate. Update `cwdfill' when that happens.
foreach s in $agencylist {
    assert !strpos("$cwdfill", "`s'")
}

* -- confirm MS really is empty before excluding it by name (DECISION 10)
quietly count if state == "MS" & !mi(harvest_total)
assert r(N) == 0
display as text "  CWD: MS confirmed to carry no county-level harvest (DECISION 10)"

generate byte _keep = 0
foreach s of global cwdfill {
    replace _keep = 1 if state == "`s'"
}
keep if _keep == 1
drop _keep

* -- park the imputed values, do not use them (DECISION 9)
* The CWD file ships the imputation marker in one of two shapes depending
* on which version of CWD_deer_harmonization.do produced it:
*   older: string flag_harvest_total == "imputed" / "not imputed"
*   newer: byte  harvest_total_imputed == 1 / 0
capture confirm variable harvest_total_imputed
if !_rc {
    display as text "  CWD: using byte harvest_total_imputed"
    generate byte _imp = (harvest_total_imputed == 1)
}
else {
    capture confirm string variable flag_harvest_total
    if _rc {
        display as error "  CWD file carries neither harvest_total_imputed nor flag_harvest_total"
        exit 111
    }
    display as text "  CWD: using string flag_harvest_total (pre-09/2026 vintage)"
    generate byte _imp = (flag_harvest_total == "imputed")
}

generate double harvest_total_cwd_imputed = harvest_total if _imp == 1
replace harvest_total = . if _imp == 1
drop _imp

quietly count if !mi(harvest_total_cwd_imputed)
display as text "  CWD: " r(N) " imputed harvest values parked, not used (DECISION 9)"

* -- sex classes (DECISION 23): the panel's buck/doe are MALE/FEMALE, so
*    doe is carried as harvest_female and buck is not used -- it contains
*    the button bucks and cannot serve as antlered. IA, GA and FL only; MI
*    and MN ship totals alone. Expected: 3,135 county-years (IA 1,980,
*    GA 954, FL 201); reported, not asserted, like the other CWD counts.
*    GA and FL definitions are unverified against the agency.
assert mi(harvest_buck) == mi(harvest_doe)
* never present on an imputed row, whose total was just parked
assert mi(harvest_doe) if mi(harvest_total)
assert harvest_doe >= 0 & harvest_doe <= harvest_total if !mi(harvest_doe)
generate double harvest_female = harvest_doe
generate byte   sexclass_basis = cond(!mi(harvest_female), 5, 0)
quietly count if !mi(harvest_female)
display as text "  CWD: " r(N) " gap-fill county-years carry harvest_female (DECISION 23)"

* -- drop county-years with nothing to contribute
drop if mi(harvest_total) & mi(harvest_total_cwd_imputed)

generate byte flag_total_constructed = 0

* stash_state keys on one state at a time; loop so the isid check still bites
tempfile _cwdall
save `_cwdall'

foreach s of global cwdfill {
    use `_cwdall', clear
    keep if state == "`s'"
    stash_state, state(`s') source(cwd)
}

/*-----------------------------------------------------------------------------
* 2p. WEST VIRGINIA -- long by harvest_method; keep the "Total" stratum
*                                                   DECISIONS 3, 11, 12
*
*     Same shape as WI, different variable names: the harvest column is
*     `harvest` (not antlered/antlerless), and harvest_method takes six
*     values -- Total, BuckGun, AntlerlessGun, Bow, Muzzleloader, Unknown.
*     Total is the component sum and reconciles EXACTLY (max discrepancy 0
*     across all 1,100 county-years), so taking it loses nothing.
*-----------------------------------------------------------------------------*/

use "$dataCLEAN/WV/WV_deer_harmonized_county_year_2001-2020.dta", clear

* -- confirm Total really is the component sum before relying on it
preserve
    collapse (sum) _parts = harvest if harvest_method != "Total", ///
        by(county_fips year)
    tempfile _wvparts
    save `_wvparts'
restore
preserve
    keep if harvest_method == "Total"
    merge 1:1 county_fips year using `_wvparts', assert(match) nogenerate
    assert abs(harvest - _parts) < 1 if !mi(harvest, _parts)
    display as text "  WV: source Total reconciles exactly against its components"
restore

keep if harvest_method == "Total"
generate double harvest_total = harvest

* -- DECISION 12: two of the four Big Game Bulletins are image scans and
*    their county tables were hand-transcribed (2001-2005 and 2011-2015).
*    The WV do file verified every figure against the printed district and
*    state subtotals, so these are not suspect numbers -- but 2005 and
*    2011-2014 fall INSIDE the 2005-2014 main sample, so the flag is
*    carried into the panel and every headline result should be re-run
*    dropping it.
generate byte flag_hand_transcribed = (source_scanned == 1)

quietly count if flag_hand_transcribed & inrange(year, 2005, 2014)
display as text "  WV: " r(N) " hand-transcribed county-years inside the main window (DECISION 12)"

stash_state, state(WV)

/*==============================================================================
* SECTION 3: APPEND
*==============================================================================*/

display as text _newline "{hline 78}"
display as text "SECTION 3: appending"
display as text "{hline 78}"

local statelist $agencylist $cwdfill
local _nstates : word count `statelist'
display as text "  appending `_nstates' state files: `statelist'"
assert `_nstates' == 19

clear
foreach s of local statelist {
    capture confirm file "$dataSTATA/_append/_std_`s'.dta"
    if _rc {
        display as error "missing standardized file for `s' -- did Section 2 run?"
        exit 601
    }
    append using "$dataSTATA/_append/_std_`s'.dta"
}

compress

/*==============================================================================
* SECTION 4: VALIDATION
*==============================================================================

  Every check below is an assert, not a display: if the panel is wrong the
  script stops here rather than saving a broken file.
  
==============================================================================*/

display as text _newline "{hline 78}"
display as text "SECTION 4: validation"
display as text "{hline 78}"

* -- 4a. the panel key is unique
isid county_fips year

* -- 4b. FIPS codes are well formed and match their state
assert length(county_fips) == 5
assert real(county_fips) < .
assert !regexm(county_fips, "[^0-9]")
* county part 000 would mean a statewide/rollup row survived the cleaning
assert substr(county_fips, 3, 3) != "000"

generate str2 _stfips = substr(county_fips, 1, 2)
generate str2 _expect = ""
replace _expect = "05" if state == "AR"
replace _expect = "06" if state == "CA"
replace _expect = "10" if state == "DE"
replace _expect = "12" if state == "FL"
replace _expect = "13" if state == "GA"
replace _expect = "18" if state == "IN"
replace _expect = "19" if state == "IA"
replace _expect = "21" if state == "KY"
replace _expect = "24" if state == "MD"
replace _expect = "26" if state == "MI"
replace _expect = "27" if state == "MN"
replace _expect = "29" if state == "MO"
replace _expect = "36" if state == "NY"
replace _expect = "37" if state == "NC"
replace _expect = "39" if state == "OH"
replace _expect = "47" if state == "TN"
replace _expect = "51" if state == "VA"
replace _expect = "54" if state == "WV"
replace _expect = "55" if state == "WI"
assert _stfips == _expect
drop _stfips _expect

* -- 4b-ii. units that are not current Census counties (DECISION 14)
*    VDWR keeps reporting three absorbed independent cities, and the VA
*    source's non-geographic catch-all row arrives as 51999. None of the
*    four will match a current county boundary file downstream.
preserve
    keep if inlist(county_fips, "51515", "51560", "51780", "51999")
    if _N > 0 {
        display as error "  DECISION 14: units that are not current counties:"
        contract state county_fips county_name
        list, noobs sep(0)
    }
restore
quietly count if inlist(county_fips, "51515", "51560", "51780") & year >= 2005 & year <= 2014
display as text "  DECISION 14: " r(N) " of their county-years fall in 2005-2014"

* -- 4c. no county appears under two different states
preserve
    contract county_fips state
    bysort county_fips: assert _N == 1
restore

* -- 4d. NO STATE MIXES SOURCES. This is the assert that enforces DECISION 8:
*        if a future edit ever gap-fills a partial series, it fires here.
preserve
    contract state source_harvest
    bysort state: assert _N == 1
restore
display as text "  source purity: no state mixes agency-direct and CWD (DECISION 8)"

* -- 4e. harvest is non-negative; nothing absurd
assert harvest_total >= 0 if !mi(harvest_total)
assert year >= 1927 & year <= 2025

* -- 4f. missingness report (not fatal -- see DECISION 5)
quietly count if mi(harvest_total)
local _nmiss = r(N)
display as text _newline "  county-years with missing harvest_total: `_nmiss'"
if `_nmiss' > 0 {
    tabulate state if mi(harvest_total)
}

* -- 4g. headline dimensions, by source
tabulate state source_harvest, missing

quietly {
    count
    local _N = r(N)
    count if source_harvest == "agency"
    local _Nag = r(N)
    egen _tag = tag(county_fips)
    count if _tag == 1
    local _ncty = r(N)
    count if _tag == 1 & source_harvest == "agency"
    local _nctyag = r(N)
    drop _tag
    levelsof state if source_harvest == "agency", local(_stag)
    local _nstag : word count `_stag'
    summarize year, meanonly
}
local _Ncwd   = `_N' - `_Nag'
local _nctycwd = `_ncty' - `_nctyag'

display as text _newline "  PANEL: `_N' obs | `_ncty' counties | " ///
    %4.0f r(min) "-" %4.0f r(max)
display as text "    agency-direct: `_Nag' obs | `_nctyag' counties | `_nstag' states"
display as text "    CWD gap-fill:  `_Ncwd' obs | `_nctycwd' counties"

* -- the agency-direct block is the piece the data section describes, so it
*    is the piece we assert against. With WV in the folder this now
*    reproduces the published figures exactly.
assert `_nstag' == 14
assert `_Nag'    == 38660
assert `_nctyag' == 1087

* -- CWD gap-fill block. Reported, not asserted: unlike the agency figures,
*    these counts depend on which vintage of the Schuler panel is sitting in
*    $dataCLEAN, so a change here is news rather than a bug. The expected
*    values are 3,811 county-years across 495 counties, of which 3,475 carry
*    a usable (non-imputed) harvest and 336 are imputed rows retained only
*    in harvest_total_cwd_imputed (DECISION 9).
quietly count if source_harvest == "cwd" & !mi(harvest_total)
local _cwduse = r(N)
quietly count if source_harvest == "cwd" & mi(harvest_total)
local _cwdimp = r(N)
display as text "  CWD gap-fill: `_Ncwd' rows across `_nctycwd' counties " ///
    "(`_cwduse' usable, `_cwdimp' imputed-only)"

if `_Ncwd' == 0 {
    display as error "  CWD gap-fill contributed NOTHING -- is $cwdfill set? (Section 0)"
    exit 459
}
if `_Ncwd' != 3811 | `_nctycwd' != 495 {
    display as error "  NOTE: expected 3,811 rows / 495 counties from the CWD" ///
        " gap-fill; got `_Ncwd' / `_nctycwd'. Check the CWD file vintage."
}

* -- structural checks, which must hold whatever the vintage:
*    every parked row carries an imputed value, and no agency row does
assert !mi(harvest_total_cwd_imputed) if source_harvest == "cwd" & mi(harvest_total)
assert mi(harvest_total_cwd_imputed) if source_harvest == "agency"

* -- 4h. sex-class columns (DECISIONS 15-22)
foreach v in harvest_antlered harvest_antlerless harvest_female ///
             harvest_female_adult harvest_unknown_sex {
    assert `v' >= 0 if !mi(`v')
}
* females are a subset of antlerless, adult females a subset of females
assert harvest_female <= harvest_antlerless ///
    if !mi(harvest_female, harvest_antlerless)
assert harvest_female_adult <= harvest_female ///
    if !mi(harvest_female_adult, harvest_female)

* DECISION 21: these carry no sex classes. If one ever does, this fires
* and the header gets updated on purpose rather than by accident.
assert mi(harvest_antlered) & mi(harvest_antlerless) & mi(harvest_female) ///
    if inlist(state, "AR", "NC", "WV", "MI", "MN")
* DECISION 23: the gap-fill states carry female at most, never the
* antlered / antlerless pair or an unknown count
assert mi(harvest_antlered) & mi(harvest_antlerless) & ///
    mi(harvest_unknown_sex) if source_harvest == "cwd"

* basis is 0 exactly when there is nothing to describe
assert (sexclass_basis == 0) == (mi(harvest_antlered) & ///
    mi(harvest_antlerless) & mi(harvest_female))
* female-only blocks: VA before 1994 (DECISION 16) and the CWD gap-fill
* states (DECISION 23)
assert (state == "VA" & year < 1994) | source_harvest == "cwd" ///
    if sexclass_basis == 5
* females can never exceed the total
assert harvest_female <= harvest_total if !mi(harvest_female, harvest_total)

* the classes should add back to the total. Unknown is treated as 0 where
* a state does not track it. Expected exceptions: IN 10, MO 1 = 11 rows
* (DECISIONS 19, 20).
generate double _cls = harvest_antlered + harvest_antlerless + ///
    cond(mi(harvest_unknown_sex), 0, harvest_unknown_sex)
generate byte flag_sexclass_nosum = abs(_cls - harvest_total) >= 1 ///
    if !mi(_cls, harvest_total)
replace flag_sexclass_nosum = 0 if mi(flag_sexclass_nosum)
drop _cls
tabulate state flag_sexclass_nosum if sexclass_basis > 0, missing
quietly count if flag_sexclass_nosum == 1
assert r(N) == 11

* coverage report
tabulate state sexclass_basis, missing

/*==============================================================================
* SECTION 5: MAIN-SAMPLE FLAGS (2005-2014 BALANCED)
*==============================================================================

  We flag rather than drop, so the historical series stay available.

  TWO flags, deliberately:
    main_sample        -- balanced 2005-2014, both sources
    main_sample_agency -- balanced 2005-2014, agency-direct only
  Every headline specification should be re-run on the second as a
  robustness check, per DECISION 8. If the coefficient moves, the CWD
  vintage is doing work it shouldn't.
  
==============================================================================*/

generate byte in_window = inrange(year, 2005, 2014)

* -- balance is defined on NON-MISSING harvest, not mere presence: that is
*    what the regression actually estimates on. See DECISION 13 for the two
*    counties where this matters (MO Worth, WI Menominee).
generate byte _obs_window = in_window & !mi(harvest_total)
bysort county_fips: egen byte _nyr = total(_obs_window)
generate byte main_sample = (_nyr == 10) & _obs_window

* -- the presence-based count, for reconciling against the data section
bysort county_fips: egen byte _nyr_present = total(in_window)
quietly {
    egen _t = tag(county_fips) if _nyr_present == 10
    count if _t == 1
    local _cpresent = r(N)
    count if _t == 1 & source_harvest == "agency"
    local _cpresent_ag = r(N)
    drop _t
}
display as text _newline "  counties PRESENT all 10 years 2005-2014: " ///
    "`_cpresent' total, `_cpresent_ag' agency-direct (DECISION 13)"
drop _nyr _nyr_present _obs_window

generate byte main_sample_agency = main_sample & source_harvest == "agency"

foreach f in main_sample main_sample_agency {
    quietly {
        count if `f'
        local _n = r(N)
        egen _t = tag(county_fips) if `f'
        count if _t == 1
        local _c = r(N)
        drop _t
        levelsof state if `f', local(_s) clean
        local _ns : word count `_s'
    }
    display as text _newline "  `f': `_n' obs | `_ns' states | `_c' counties"
    display as text "    states: `_s'"
}

* -- expected: main_sample 11,190 / 1,119 / 13 ; agency-only 10,200 / 1,020 / 12
quietly count if main_sample_agency
assert r(N) == 10200
assert `_cpresent_ag' == 1022

quietly count if main_sample
local _nmain = r(N)
if `_nmain' != 11190 | `_cpresent' != 1121 {
    display as error "  NOTE: expected 11,190 main-sample obs and 1,121 counties" ///
        " present; got `_nmain' and `_cpresent'. Check the CWD file vintage."
}

tabulate state main_sample, missing

* -- sex-class coverage inside the main sample (report only). Antlerless
*    should cover IN KY MD MO NY OH TN VA WI; female MO NY OH TN VA plus
*    IA (the one CWD gap-fill state in the window, 990 county-years).
display as text _newline "  main_sample county-years with harvest_antlerless:"
tabulate state if main_sample & !mi(harvest_antlerless)
display as text _newline "  main_sample county-years with harvest_female:"
tabulate state if main_sample & !mi(harvest_female)

/* NOTE -- reconciliation against the data section:

   With WV in the folder, the agency-direct panel now reproduces the
   published figures exactly, at both the panel and the main-sample level:

     full agency panel    14 states / 1,087 counties / 38,660 obs

   That is the data section's figure to the observation. The main sample
   agrees too, but only on the presence definition -- 1,022 counties are
   present in all ten years, while 1,020 have a non-missing harvest in all
   ten. See DECISION 13; the two counties are MO Worth and WI Menominee.

     main sample (agency) 12 states / 1,020 counties / 10,200 obs

   The CWD gap-fill sits on top of that and is the one thing the text does
   not currently describe:

     main sample (+ CWD)  13 states / 1,119 counties / 11,190 obs

   The whole of that difference is IOWA -- 99 counties, fully balanced
   2005-2014, non-imputed. It is a real addition to the estimation sample,
   but it is NOT a 15th agency-direct harmonization: it comes from the
   Schuler et al. compilation, not from the Iowa DNR. If IA stays in the
   regressions the data section needs a sentence distinguishing the two,
   and the "we contacted the state wildlife agency in each state in our
   sample" language should not be read to cover it.

   CA (ends 2009) and DE (starts 2010) are the two agency-direct states
   that fall outside the window entirely. FL, GA, MI and MN gap-fill only
   2016-2021 and so contribute nothing to it.

   Robustness flags available on the saved panel:
     main_sample_agency     drops IA (and any future CWD gap-fill state)
     flag_hand_transcribed  marks WV 2005 and 2011-2014 inside the window,
                            275 county-years, the only hand-read data
                            present                                        */


/*==============================================================================
* SECTION 6: LABEL AND SAVE
*==============================================================================*/

bysort county_fips (county_name): replace county_name = county_name[_N] ///
    if county_name == ""
quietly count if county_name == ""
assert r(N) == 0

generate _cname_sort = lower(county_name)
sort state _cname_sort county_fips year
drop _cname_sort

order state county_fips county_name year harvest_total ///
    harvest_antlered harvest_antlerless harvest_female ///
    harvest_female_adult harvest_unknown_sex sexclass_basis ///
    source_harvest flag_total_constructed flag_hand_transcribed ///
    flag_antlerless_zerofill flag_sexclass_nosum ///
    harvest_total_cwd_imputed in_window main_sample main_sample_agency

label variable state                     "State postal abbreviation"
label variable county_fips               "5-digit county FIPS code"
label variable county_name               "County name, as reported by the source"
label variable year                      "Season start year"
label variable harvest_total             "Total deer harvested, all categories combined"
label variable source_harvest            "Compilation: agency-direct harmonization or Schuler et al. CWD panel"
label variable flag_total_constructed    "=1 if total was constructed from components rather than source-reported"
label variable flag_hand_transcribed     "=1 if figure was hand-transcribed from an image-scanned report (WV only)"
label variable harvest_total_cwd_imputed "CWD imputed harvest value, parked and NOT used in harvest_total"
label variable in_window                 "=1 if year in 2005-2014 and harvest observed"
label variable main_sample               "=1 if county balanced across all of 2005-2014 (both sources)"
label variable main_sample_agency        "=1 if balanced 2005-2014 AND agency-direct (robustness sample)"

* -- sex-class columns (DECISIONS 15-22). All labels are under 80 characters.
label variable harvest_antlered          "Antlered deer harvested (antlered or adult males)"
label variable harvest_antlerless        "Antlerless deer harvested: all females plus male fawns/button bucks"
label variable harvest_female            "Female deer harvested, all ages (doe fawns included)"
label variable harvest_female_adult      "Adult female deer harvested, doe fawns excluded (NY only)"
label variable harvest_unknown_sex       "Deer of unknown sex/class: in neither antlered nor antlerless"
label variable sexclass_basis            "How this county-year's sex-class columns were obtained"
label variable flag_antlerless_zerofill  "=1 if antlerless is a blank read as zero (CA only)"
label variable flag_sexclass_nosum       "=1 if antlered + antlerless + unknown differs from harvest_total"

label define sexclass_basis_lbl                 ///
    0 "none"                                    ///
    1 "antlered/antlerless as reported"         ///
    2 "built from sex-age classes"              ///
    3 "buck/doe as labeled"                     ///
    4 "antlerless = total - antlered"           ///
    5 "female only (males not split)"
label values sexclass_basis sexclass_basis_lbl

label data "US county-year deer harvest panel, agency-direct + CWD gap-fill"

notes: Agency-direct state harmonizations, gap-filled at the STATE level with the Schuler et al. CWD panel for FL/GA/IA/MI/MN. The two compilations are never spliced within a state: see DECISION 8 in deer_harvest_national_append.do.
notes: Rebuilt 09/2026 after the AR harmonization dropped its 1988-1990 year shift. AR now runs 1988-2014 with 1990 present (it previously ran 1987-2014 with 1990 absent). AR's 2005-2014 rows are unaffected, so the main sample is unchanged.
notes: Four VA units are not current Census counties and will not match county covariates: 51515, 51560, 51780 (absorbed independent cities, 30 county-years inside 2005-2014) and 51999 (the source's "Unknown" catch-all). See DECISION 14.
notes: Saved as US_deer_harvest_county_year.dta. Dated copies (e.g. US_deer_harvest_county_year_04sep2026.dta) are manual snapshots, not written by this script.
notes: Sex-class columns added 10/2026 for CA DE IN KY MD MO NY OH TN VA WI, plus harvest_female alone for the CWD gap-fill states FL GA IA. harvest_antlerless = all females + male fawns/button bucks; harvest_female = females of all ages and exists only for MO NY OH TN VA FL GA IA. Unknowns are in neither class. See DECISIONS 15-23.
notes harvest_antlered: VA is missing before 1994: the source does not separate male fawns until then, so its antlered-male column is all males (DECISION 16). KY is the source's buck column, 1999 on (DECISION 17). NY is adult males (DECISION 22).
notes harvest_antlerless: KY and DE 2010-2015 are residuals, total minus antlered (sexclass_basis 4). CA is doe harvest with blanks read as zero where buck is present; see flag_antlerless_zerofill (DECISION 18).
notes harvest_female: Agency-direct for MO NY OH TN VA; from the Schuler et al. CWD panel's doe column for IA (verified against Iowa DNR), GA and FL (unverified) -- DECISION 23. IA 2001-2005 predates mandatory reporting and is not comparable with 2006 on. Where antlerless also exists, male fawns make it 11-23 pct larger than female, a margin that falls over time. NY fawn classification appears to change from 2016 (DECISION 22).

compress
save "$dataCLEAN/US_deer_harvest_county_year.dta", replace

describe
summarize harvest_total, detail
bysort source_harvest: summarize harvest_total, detail

* -- clean up the per-state temp files
foreach s in $agencylist $cwdfill {
    capture erase "$dataSTATA/_append/_std_`s'.dta"
}

log close

/*============================================================================*/
