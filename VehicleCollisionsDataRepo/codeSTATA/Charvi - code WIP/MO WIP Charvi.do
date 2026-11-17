/*******************************************************************************
Program: MO.do
Current Lead:
Major Versions/Revisions:
09/17/2026 [ ]: created, modelled on ID.do and IA.do. Year folders discovered
  from the directory rather than listed. 2002 built and verified against the
  raw files.

09/18/2026 [ ]: 2003-2024 added. Each change below was forced by a specific
  year rather than chosen in advance, which is why the file looks the way it
  does.

  WHAT THE DATA CHANGED
  - INJURY BREAKDOWN MOVED FROM THE CRASH FILE TO THE PERSON FILE. 2024's
    NumberDisablingInjuries and NumberMinorInjuries are 2,134 injuries short,
    4.3%, while its NumberInjured is exact. Severity now takes the UNION of
    both sources at each level, PDO as the residual (NOTE 3, NOTE 2).
  - COVERAGE FLAGS, split in two. 2010's vehicles export is missing 97% of
    Highway Patrol crashes, so its species split is unusable while its animal
    union survives on the crash side. animal_data_usable and
    species_data_usable are separate for that reason; bc_split_usable is the
    person-side equivalent (NOTE 9).
  - ALCOHOL FROM ContribCircCd 18, the only impairment measure spanning the
    panel: AlcoholUseInd is new for 2012 and blank before it. Both are
    published, with drug and dui companions (NOTE 6).
  - ANIMAL SIDES PUBLISHED SEPARATELY, and ContribCircCd 31 added as a THIRD
    source but deliberately NOT folded into animal_collision, being a
    circumstance rather than a strike (NOTE 4).
  - SKIP THE YEAR, NOT THE RUN. One record in 2003 ended a 21-year build, so
    delivery checks became bounded reports and then per-year skips, with every
    skipped year named after the save (NOTE 8).

  WHAT THE DELIVERY CHANGED, none of it load-bearing now (NOTE 10)
  - 2016 is xlsx; 2017-2018 spell the folder with a Z; 2018 uses singular file
    names, US dates with a two-digit year, and unpadded CrashType; 2019-2022
    have no header row and are named by position; 2023 has animalcd singular.

  WHAT THE CODEBOOK SETTLED
  - AnimalCd 60 Deer confirmed; 61 Farm Animal and 62 Dog CORRECTED, having
    been guessed the wrong way round. Pooled counts were unaffected.
  - County code map, CrashType 01 and the KABCO injury levels all confirmed.
  - Blank PersonalInjuryLevel is "Short Form Or Non-Participant", not the
    duplicated vehicle rows previously assumed.

  BUGS IN THIS FILE, not in the data, kept here because each was found by a
  failed run rather than by reading
  - fix_bom renamed column 1 unconditionally, disguising a missing header as a
    missing column
  - char(34) inside a quoted string broke the donor header reader, r(101);
    the donor mechanism is gone, replaced by a stated position map
  - import_named read with varnames(1) before checking for a header, which
    broke 2020's persons file with r(3300)
  - a continue statement sat inside a nested foreach, so a year marked as
    failed carried on building anyway
  - str1 and str3 declarations would silently TRUNCATE a wider code into a
    valid-looking one
  - an assert compared against missing, which is larger than any number in
    Stata, so it passed trivially on blanked rows
*******************************************************************************/

/*******************************************************************************
DATA NOTES - READ BEFORE USING THE PANEL

Output: dataSTATA/dvcs_MO_county_year_YYYY_YYYY.dta, 115 Missouri counties
(114 counties + St. Louis City) by however many year folders are present.

1. THREE FILES PER YEAR, ALL KEYED ON CrashId, in
   dataRAW/DVCs/MO/YYYY_De-Personalised_with_VIN_Extract:
     crashes    one row per crash   (date, county, injury counts, crash type)
     vehicles   one row per vehicle (AnimalCd1-4 = species struck)
     persons    one row per person  (PersonalInjuryLevel = KABCO)
   Verified 2002: 185,907 crashes, 342,515 vehicles, 368,227 persons; CrashId
   unique in crashes and present in all three files with no orphans.

   FILE NAMES AND FOLDER NAMES VARY BY DELIVERY; see NOTE 10 for the full
   list. EVERY YEAR IS CSV EXCEPT 2016, WHICH IS XLSX. Same three names, same
   column names, same 49/39/119 columns, and every cell stored as text, so the
   only difference is the import command. Section 0B discovers the extension and
   import_any dispatches on it; both paths read all columns as string so the
   types are identical across the seam. Verified 2016: 158,098 crashes,
   288,544 vehicles, 401,954 persons, again with no orphans in either
   direction. Nothing else in this file is year-specific.

2. NO CRASH SEVERITY FIELD. MO carries injury COUNTS, not a KABCO crash code,
   so severity is derived, taking the UNION of the crash file and the person
   file at each level:
     fatal   NumberKilled > 0
     major   else, person level 2 > 0 OR NumberDisablingInjuries > 0
     minor   else, person levels 3+4 > 0 OR NumberInjured > 0
     PDO     the residual
   PDO as the residual is what makes the four partition total_all_cause BY
   CONSTRUCTION; the union at each level means neither a short crash-file
   category (2024, NOTE 3) nor a missing person row can demote a crash.

   KABCO B and C are pooled into minor to match AZ and ID, with person level 3
   and 4 also carried separately as visible_injuries and possible_injuries, and
   possible_injury_collision (worst person injury is C) is a SUBSET of
   minor_injury_collision, as in ID.

3. WHICH FILE WINS, AND WHY IT IS NOT THE SAME ANSWER EVERYWHERE.
   total_all_cause, total_fatalities and the severity flags come from the CRASH
   file. The injury BREAKDOWN -- major_injuries, minor_injuries,
   visible_injuries, possible_injuries, total_injuries -- comes from the PERSON
   file. That split is not tidiness, it is what the data forced:

     2002  person and crash agree on fatalities and disabling in EVERY crash;
           minor differs on 9
     2003  fatalities agree everywhere; disabling differs on 1 (crashid
           0030028803, Clay County, 6 March), minor on 10
     2019  level 2 sums to 4,491 and level 1 to 881, matching the crash file
           exactly
     2024  THE CATEGORY COLUMNS BREAK. NumberDisablingInjuries is 5,286 against
           5,434 at person level 2, and NumberMinorInjuries is 41,728 against
           43,714 at levels 3+4: short by 2,134 injured people, 4.3% of the
           year. But NumberInjured is 49,149 against 49,148 for levels 2+3+4,
           so the TOTAL is sound and only the split is broken

   An earlier version of this file took the breakdown from the crash file and
   asserted it against the person file. That cost 2003 to one record and would
   have published 2024 four percent light on injuries had it not stopped first.

   THE TWO IDENTITIES THAT ARE STILL ENFORCED are the cross-file ones that hold
   in every year measured, 2024 included: NumberKilled == person level 1, and
   NumberInjured == person levels 2+3+4. Those can only hold if both files
   describe the same crashes, so they are bounded at 0.1% of the year and a
   break skips the year. The crash file's own category columns are now merely
   REPORTED against the person file each year, since 2024 proves they can be
   short without anything else being wrong.

   SEVERITY TAKES THE UNION of both sources at each level, so neither a short
   category column nor a missing person row can demote a crash, and PDO stays
   the residual so the partition still holds by construction.

4. ANIMAL IDENTIFICATION IS THE UNION of the crash side (CrashType == 01) and
   the vehicle side (any AnimalCd non-blank), matching animal_collision in the
   other state files. THE UNION EARNS ITS KEEP, and increasingly so:

     year  crash side  vehicle side  crash only  veh only   union    share
     2002       5,081         5,120           0        39   5,120    2.75%
     2003       4,742         4,777           0        35   4,777    2.61%
     2016       4,684         4,695           8        19   4,703    2.97%
     2017       4,916         4,906          15         5   4,921    3.21%
     2018       4,734         4,727          14         7   4,741    3.18%
     2020       4,352         4,358           3         9   4,361    3.32%
     2024       3,517         3,525           0         8   3,525    2.62%

   WATCH 2024. Its animal union is 3,525 against 4,250 in 2023, down 17%,
   while total crashes fell only 1.8%. BOTH sides fall together, crash side
   3,517 and vehicle side 3,525, and the AnimalCd fill rate drops to 1.4% from
   1.7-1.9% in every other year. Two independent sources moving together
   argues against a plumbing fault and for something real or a reporting
   change at source, but it is the largest single-year move in the panel and
   should be confirmed before 2024 carries any weight in a trend.

   In 2002 and 2003 the crash side adds nothing; from 2016 both sides
   contribute and the crash-side-only column grows. Either side alone would
   lose crashes. The disagreement is printed each year; a large
   crash-side-only count means AnimalCd stopped being populated.

   THE SPECIES CODES ARE NOW FROM THE CODEBOOK, not inferred:
     60 = Deer        61 = Farm Animal    62 = Dog
     63 = Other Animal                    U  = Unknown
   The deer inference was right, and had been reached from seasonality alone:
   82% of 2002 animal crashes, peaking at 1,025 in November against ~230 in
   March. The 61/62 guess was WRONG IN BOTH DIRECTIONS, having had 61 as dog
   and 62 as livestock. Only the pooled non-deer count was ever published, so
   no number changed, but the split is now deer (wild), farm animal plus dog
   (domestic) and other, which is the wild / non-wild division ID carries.
   Code U and any crash-side-only crash go to animal_species_unknown_coll.

   A THIRD ANIMAL SOURCE EXISTS AND IS NOT IN THE UNION. ContribCircCd 31 is
   "Animal(s) In Roadway". In 2018 it flags 5,590 crashes against a two-side
   union of 4,741, of which 4,416 are already in the union and 1,174 ARE NOT:
   a three-way union would be 5,915, a quarter larger. It is published as
   animal_circ_side and deliberately NOT folded into animal_collision, because
   it is a different concept: a circumstance that contributed to a crash, which
   includes swerving to avoid an animal and hitting something else, whereas
   AnimalCd is defined as the animal STRUCK. Whether a swerve-to-avoid belongs
   in a DVC count is the analyst's call, and both counts are there to make it.

   THE SPECIES SPLIT HAS NO SECOND SOURCE, unlike animal_collision itself.
   Species comes only from AnimalCd, so a year whose vehicles file is short
   loses it, while the union survives on its crash side. That asymmetry is why
   section 2 carries species_data_usable separately from animal_data_usable:
   2010's union is sound and its deer count is half missing.

   THE SUBFAMILIES DO NOT ALWAYS PARTITION animal_collision, which is why the
   assert is an inequality rather than an equality. They do partition in 2002,
   2003, 2016 and 2024: 2003 splits 3,831 deer + 934 non-deer + 12 unknown =
   4,777, and 2016 has 21 crashes with two animal-coded vehicles but every pair
   carries the SAME species, so 3,806 + 871 + 26 = 4,703 exactly.

   2017 IS THE EXCEPTION: 4,032 + 853 + 37 = 4,922 against a union of 4,921,
   because crashid 2170047795 carries two vehicles with DIFFERENT species, V1
   a deer and V2 code 61. Summing the three subfamilies double counts that
   crash, so they are not a decomposition of animal_collision. The year loop
   counts any such crash and reports it. ID warned this was possible; 2017 is
   where it happened, and the inequality is what let the year build.

5. COUNTY CODE TO FIPS. MO codes counties 1-115 alphabetically with "St."
   read as "Saint", 96 unused, and St. Louis City as 116. That order is the
   FIPS order, so fips = 29 + (2*code - 1) holds for 1-95 and 98-115, with two
   exceptions: code 97 Ste. Genevieve is 29186 (inserted out of sequence) and
   code 116 St. Louis City is 29510. 29191, 29193 and 29231 - what the formula
   would give for 96, 97 and 116 - are not Missouri FIPS, which is the
   confirmation that the correspondence is real.

   CONFIRMED AGAINST THE CODEBOOK, which lists all 115 codes with 96 absent
   and 999 for unknown, exactly as inferred. Every spot check matches,
   including the awkward ones: 60 McDonald before 61 Macon, and 92 St. Charles,
   93 St. Clair, 94 St. Francois, 95 St. Louis, 97 Ste. Genevieve, 98 Saline.

   Originally verified against 2002 mean crash coordinates and top routes
   at 15 codes
   spread across the range: 1 Adair, 3 Atchison, 10 Boone, 16 Cape Girardeau,
   35 Dunklin, 48 Jackson, 60 McDonald, 61 Macon (Mc sorts before Ma, as in
   FIPS), 77 Ozark, 83 Platte, 95 St. Louis County, 97 Ste. Genevieve,
   98 Saline, 114 Worth, 116 St. Louis City.

   County 999 is unknown (2 crashes in 2002) and is dropped and reported.

6. IMPAIRMENT HAS TWO SOURCES AND ONLY ONE OF THEM SPANS THE PANEL.

   AlcoholUseInd, in the person file, is the officer's judgement that someone
   involved had used alcohol. The codebook says NEW FOR 2012, which is exactly
   what the build measured before the codebook arrived: coverage 0% every year
   from 2002 to 2011 and 81.6% in 2012. The column EXISTS in the earlier
   files and is blank on every row, so reading blank as "no alcohol" would
   report zero alcohol crashes for a decade. It stays MISSING there.
     Y = Yes   N = No   U = Unknown   NA = Not applicable

   ContribCircCd 1-12, also in the person file, carries 18 = Alcohol and
   19 = Drugs, and it runs the WHOLE PANEL. That is the measure to use for
   anything spanning 2012, and it is why alcohol_circ_collision,
   drug_circ_collision and dui_circ_collision exist.

   WHICH IS BROADER, where both exist: AlcoholUseInd. In 2018, code 18 flags
   4,957 crashes and Y flags 5,707, with 4,954 in common and only 3 crashes
   flagged 18 without Y. 2020 is the same shape: 5,273 against 5,946, eight
   crashes flagged 18 without Y. So code 18 is very nearly a SUBSET of Y and
   is the narrower, more conservative measure. For 2002-2011 it is the only
   one there is.

   MEASURED ACROSS THE PANEL, and the answer is reassuring: there is NO STEP
   at 2012 where AlcoholUseInd appears, and the two measures hold a stable
   ratio wherever both exist.
     year  circ%  ind%  ind/circ      year  circ%  ind%  ind/circ
     2002   4.57     -         -      2016   3.35  3.86      1.15
     2006   4.76     -         -      2019   3.24  3.71      1.15
     2010   4.16     -         -      2020   4.01  4.52      1.13
     2012   4.27  4.89      1.15      2024   3.62  4.36      1.20
   The circ measure drifts down from about 4.6% early to about 3.6% late, with
   2020 rising on BOTH measures, which matches the documented pandemic
   increase in impaired driving and shows up independently in fatalities
   (987 in 2020 on 26,000 fewer crashes than 2019). The ind measure runs
   13-20% above circ throughout, so the two are not interchangeable in level,
   only in trend.

   HOW TO CHOOSE. A series that must be comparable across 2012 should use
   alcohol_circ_collision alone. A study confined to 2012 onward should prefer
   alcohol_collision, with alcohol_unknown_collision beside it for the bound.
   Mixing them across the seam builds a step change into the series.

   THE U PROBLEM REMAINS on the AlcoholUseInd side: 16.3% of 2016 drivers are
   coded U, so alcohol_collision is a floor and alcohol_unknown_collision is
   the headroom. See the crash-level split in the run log.

   NA IS NOT A GAP, IT IS PASSENGERS: 111,755 of 2016's 111,824 NA rows are
   PersonInvolvementCode 2. And the not-applicable code changes spelling, NA
   in 2016 and 2024 and BLANK in 2017 and 2018, so the coverage test excludes
   both and the figures stay comparable: 83.8% in 2017, 83.7% in 2016, 84.6%
   in 2018, 87.3% in 2020, 88.3% in 2024.

7. LAT/LONG IS PRESENT BUT UNUSED. 24% of 2002 crashes have 0/0 coordinates.
   County comes from the County field, not from a spatial join, so no shapefile
   step is needed (unlike IA).

8. WHAT ERRORS AND WHAT ONLY REPORTS. Facts that hold BY CONSTRUCTION are hard
   asserts: the severity partition, the species subfamilies, the 115-county
   balance, the crosswalk merge. Facts about the DELIVERY are reported and
   bounded at 0.1% of the year: crash-versus-person injury disagreements
   (NOTE 3), crashes with no vehicle or person record, blank counties or dates,
   and unplaceable county codes.

   ABOVE THE BOUND, THE YEAR IS SKIPPED, NOT THE RUN. One unreadable file, one
   renamed column, one duplicated crash id or one partial year costs that year
   and nothing else, and every skip is named with its reason in the log and
   again in the accounting printed after the save. NOTHING IS EVER DROPPED
   SILENTLY: if a year is not in "YEARS IN THE PANEL" it appears in one of the
   four lists beneath it. The only remaining hard stops are the ones that mean
   the code or the crosswalk is wrong rather than the data: no resolvable year
   at all, a FIPS the crosswalk does not hold, or a by-construction assert.

   Measured so far, all far under the threshold: 2002 nine minor-injury
   disagreements, 2003 one disabling and ten minor, and nothing else in 2002,
   2003 or 2016 trips any bound.

9. THE DELIVERY IS NOT UNIFORM. Separate the two kinds of problem, because
   they have different remedies:

   A CONVENTION PROBLEM is the file being shaped differently from what this
   code assumed. Every one has been handled; see NOTE 10 for the list. Nothing
   is lost.

   A DATA FAULT is the delivery itself being incomplete or inconsistent. Only
   THREE years have one:
     2010  the vehicles export is missing one class of crash, costing the
           species split (detail below). THE ONLY YEAR WITH A COLUMN BLANKED
     2024  the crash file's injury CATEGORY columns are 4.3% short, which is
           why the breakdown is now person-sourced (NOTE 3)
     2018  280 crashes (0.19%) have neither a vehicle nor a person record, so
           its coverage columns sit just under 1. Small, but real
   Everything else that stopped a run was a convention, not a fault.

   ALL 23 YEARS HAVE NOW BEEN THROUGH THE BUILD. 2002-2018, 2023 and 2024 are
   in the panel and measured; 2019-2022 were detected as headerless and failed
   only on a quoting bug in the header reader, since removed. 2019
   and 2020 have since been read directly and both confirm the positional
   template, so 2021 and 2022 are the only years never inspected.

   THE ANIMAL SHARE RISES WHEN TOTAL CRASHES FALL, which is arithmetic rather
   than ecology and matters for reading the series: 2020 has the highest share
   in the panel at 3.32% on the lowest crash count, 131,420. Deer strikes did
   not rise in 2020; driving fell. Use the counts, not the share, unless
   exposure is in the denominator.

     year  convention to handle          what was measured         evidence
     2002  -                             9 category divergences    files
     2003  -                             1 disabling, 10 minor     files
     2004  -                             none reported             log
     2005  -                             none reported             log
     2006  -                             4 and 4                   log
     2007  -                             10, 1 and 9               log
     2008  -                             4 and 4; 1 county 999     log
     2009  -                             2 and 2                   log
     2010  -                             EXPORT INCOMPLETE         files
     2011  -                             1 and 1                   log
     2012  -                             12, 1 and 13              log
     2013  -                             6 and 6                   log
     2014  -                             4, 1 and 3                log
     2015  -                             12 and 12                 log
     2016  xlsx                          24, 4 and 23              files
     2017  folder spelled with a Z       nothing                   files
     2018  Z folder, singular file       83 and 1; 280 crashes     files
           names, US dates, unpadded     with no child records
           CrashType
     2019  no header row in any file     reconciles exactly        files
     2020  no header row (INFERRED)      unknown                   log only
     2021  no header row (INFERRED)      unknown                   log only
     2022  no header row (INFERRED)      unknown                   log only
     2023  animalcd singular, 115-col    unknown                   log only
           vehicles (INFERRED)
     2024  131-col vehicles              CATEGORIES 4.3% SHORT     files

   READ THE MEASURED COLUMN WITH CARE. Those counts come from the first full
   run, which enforced DIFFERENT identities from the ones enforced now: it
   checked the crash file against itself and its minor category against the
   person file. NOTE 3 changed the enforced pair to NumberKilled == level 1 and
   NumberInjured == levels 2+3+4. Those two are verified on 2002, 2003, 2016,
   2017, 2018, 2019 and 2024; for the log-only years the NEXT run is their
   first test. The old counts are still informative about the size of the
   crash-versus-person divergence, which is now reported rather than enforced.

   ALCOHOL IS MISSING BEFORE 2012, not zero: coverage is 0% from 2002 to 2011
   and 81.6% in 2012, the first year the field is populated (NOTE 6).

   Detail on each year:

     2002-2009  clean csv, built
     2010       BUILT WITH species_data_usable == 0, the union intact. NOT a
                truncated or misparsed file: 218,913 physical lines match the
                218,912 rows Stata read exactly. The vehicles export DROPPED
                ONE CLASS OF CRASH. By the first digit of CrashId, which
                encodes the reporting source:
                  0  municipal and county (KCPD, St. Louis PD)  98,264 crashes,
                     0.0% missing a vehicle record
                  2  smaller municipalities        19,849 crashes, 11.6% missing
                  3  HIGHWAY PATROL (MOMHPCC00, MOMHPDD00, MOMHPAA00 = Troops
                     C, D, A)                      33,283 crashes, 96.7% missing
                The person file is COMPLETE: all 151,404 crashes have person
                rows, and those rows cite 51,379 VehicleIds absent from
                vehicles.csv. So the records exist and were not exported.
                The missing class is the RURAL one, which is where deer are:
                7.68% animal rate on prefix 3 against 1.58% on prefix 0.
                Consequences: the vehicle side gives 1,758 animal crashes, 59%
                short, but CrashType 01 is in the crash file and complete, so
                the UNION is 4,319 against 4,553 in 2009 and 4,376 in 2011.
                animal_collision therefore stands and only the species split
                goes missing. See the two flags in section 2
     2011-2016  clean, built (2016 is xlsx)
     2017       clean csv, built. Verified: 153,422 crashes, 115 counties, 12
                months, no orphans, BOTH enforced identities exactly zero,
                animal union 4,921 (3.21%). Carries the one multi-species
                crash in NOTE 4
     2018       clean once the conventions in NOTE 10 are handled: singular
                file names, a Z in the folder name, US dates and unpadded
                CrashType. Verified: 149,100 crashes, 115 counties, 12 months,
                both enforced identities inside the bound (83 and 1 against a
                149-row bound), animal union 4,741 (3.18%), species partition
                exact. 280 crashes (0.19%) have neither a vehicle nor a person
                record, so the coverage columns will show slightly under 1
     2019       ALL THREE FILES HAVE NO HEADER ROW. Line 1 is a data record,
                so varnames(1) made column names out of a VIN, MO, FORD, BLU.
                Field counts are the usual 49/39/119 and the column ORDER
                matches the headered years, so import_named re-reads them with
                varnames(nonames) and name_by_position names the dozen columns
                the build needs. Two cross-FILE identities pin the layout down:
                NumberDisablingInjuries summing to 4,491 and NumberKilled to
                881, equal to the person file's level 2 and level 1 counts.
                CONFIRMED against the files
     2020       Skipped once more before it built, and for a third distinct
                reason: its persons file broke import delimited itself with
                r(3300) when read as though it had a header. That is fixed by
                checking for a header BEFORE importing rather than after.
                CONFIRMED AGAINST THE FILES, and it is the second independent
                test of the positional template. All three files headerless,
                49/39/119 fields, and every field lands where the 2002-2018
                layout says: County on crashes column 14 (115 distinct, led by
                095, 048, 116), CrashType on column 4, AlcoholUseInd on persons
                column 12, AnimalCd1 on vehicles column 53 with only the five
                known codes. The identities are exact: NumberKilled 987 equals
                person level 1, and NumberInjured 47,904 equals levels 2+3+4.
                Built: 131,420 crashes, 12 months, no orphans, partition holds,
                animal union 4,361 (3.32%), species split exact, alcohol
                coverage 87.3%
     2021-2022  BUILT positionally and behaving like their neighbours: deer
                shares of 83.8% and 84.3%, animal unions of 4,499 and 4,386,
                species vocabulary clean. Never read directly, but the two
                backstops both passed: name_by_position refuses a file whose
                column COUNT does not match the map, and the vocabulary gate
                would catch a same-width file whose ORDER differed, since
                AnimalCd1 would then hold something other than 60/61/62/63/U Whether their crash and
                person files also lack a header is UNKNOWN; import_named
                handles either way. Whether their column ORDER matches the
                map is also unknown, and the species vocabulary gate is the
                backstop: a misaligned AnimalCd column yields codes outside
                60/61/62/63/U and the year's animal columns go missing rather
                than wrong
     2023       BUILT. The vehicles file names the column animalcd, SINGULAR,
                where every other year has animalcd1-4, and carries 115
                columns rather than 119; its persons file has 37 columns and
                590,018 rows with PersonalInjuryLevel 57.7% filled, the
                post-2019 pattern. Verified on the run: 136,834 crashes, 115
                counties, 12 months, no orphans, 1 crash violating the injured
                identity, alcohol coverage 87.6%, animal union 4,250 (3.11%),
                and the crash-file minor category 236 injuries short of the
                person file, under the 1% threshold
     2024       BUILT after the sourcing change in NOTE 3. Its crash-file
                category columns are short by 2,134 injured people (4.3%),
                which is what the 1,527 crashes violating NumberInjured ==
                minor + disabling were. The person file is complete, so the
                breakdown now comes from there. Verified: 134,390 crashes,
                115 counties, 12 months, no orphans, both enforced identities
                hold (1 crash out of 134,390 on the injured total, 0 on
                fatalities), alcohol coverage 88.3%, animal union 3,525 (2.62%)

   2024's vehicles file has 131 columns, up from 119, and still carries
   animalcd1-4 under a proper header, so it needs no positional naming.

   THE BLANK PersonalInjuryLevel ROWS ARE OWNERS AND NON-PARTICIPANTS. The
   codebook gives blank as "Short Form Or Non-Participant (Owners, No
   Drivers)", so they are people recorded without an injury assessment, not
   duplicated vehicle rows. The count happening to sit near the vehicle row
   count is a coincidence of one owner per vehicle. Harmless either way, since
   p_k through p_c count only levels 1-4, but the earlier explanation below
   was wrong about the cause.

   FROM 2019 THE PERSONS FILE CARRIES EXTRA ROWS and this is NOT a defect.
   2019 has 678,191 person rows for 157,072 crashes, of which 285,929 have a
   BLANK PersonalInjuryLevel against 285,880 vehicle rows: about one extra row
   per vehicle. 2024 shows the same pattern (245,325 blank against 245,288
   vehicle rows). They are harmless here because p_k through p_c count only
   levels 1-4 and worst, alc_yes and alc_u are maxima, so a blank row
   contributes zero. 2019's person counts still reconcile exactly with the
   crash file: level 2 sums to 4,491 and level 1 to 881, matching
   NumberDisablingInjuries and NumberKilled. An earlier version of this note
   blamed 2024's failure on these rows, which was wrong.

   WHAT THE FIRST FULL RUN TAUGHT: "skip the year" is too blunt for a source
   problem that touches only some columns. A truncated vehicles file should
   cost the animal columns, not the fatalities. Hence the coverage flags in
   section 2 -- understated is not the same as low, so the affected columns go
   missing and the rest of the year is published.

10. THE DELIVERY'S NAMING AND FORMATTING CONVENTIONS ALL VARY, and each one
    cost a year or a run before it was found. None of them is load-bearing now:

      folder spelling   2017 and 2018 are De-Personalized, with a Z; every
                        other year is De-Personalised, with an S. Years are
                        now found by the LEADING FOUR DIGITS of any
                        subdirectory, so the word does not matter. Those two
                        years were reported as "no folder at all" for several
                        runs while the folders sat there
      file names        2018 is crash.csv, person.csv, vehicle.csv, SINGULAR;
                        every other year is plural. The search stem is the
                        singular form, which covers both
      file format       2016 is xlsx, the rest csv (NOTE 1)
      header row        2019-2022 have none (NOTE 9)
      date format       2018 is US month-first with a two-digit year,
                        "1/5/18 4:55 PM"; the rest are ISO. Both are parsed
      zero padding      2018 writes CrashType as 1, earlier years as 01, so
                        the test is real(trim(crashtype)) == 1 rather than a
                        string comparison
      column names      2023 has animalcd, singular, for animalcd1-4;
                        2017-2018 rename VIN to VehicleVIN
      not-applicable    2016 and 2024 write NA, 2017 and 2018 leave it blank
                        (NOTE 6)

    THE PATTERN WORTH REMEMBERING: every one of these was a convention I had
    inferred from the first year I happened to look at. Where a convention can
    vary, the code now either accepts every variant it has seen or discovers
    the answer from the file itself.

EDITING CAUTION: do not write an asterisk immediately followed by a forward
slash anywhere in this block. That sequence closes the comment and Stata parses
the rest of the documentation as commands.
*******************************************************************************/

/*-----------------SECTION 0: setup --------------*/

cap log close _all
clear all
set more off, permanently
set maxvar 32767
set scheme s1mono

* 2016 is delivered as xlsx and the workbooks are 40-80MB, above what import
* excel will read without this
set excelxlsxlargefile on

* set before the do-file to run from a root not listed here
if "$rootDir" == "" {
  foreach d in /mnt/data_d/Dropbox/Research ///
               C:/Dropbox/Research          ///
               D:/Dropbox/Research {
    if "$rootDir" == "" {
      local dirok = 0
      mata: st_local("dirok", strofreal(direxists("`d'")))
      if `dirok' == 1 global rootDir "`d'"
    }
  }
}

if "$rootDir" == "" {
  di as error "No research directory found. Checked:"
  di as error "  /mnt/data_d/Dropbox/Research"
  di as error "  C:/Dropbox/Research"
  di as error "  D:/Dropbox/Research"
  di as error `"Set it by hand first:  global rootDir "/your/path/Research""'
  error 601
}

global path "$rootDir/VehicleCollisionsDataRepo"
global working_data "$path/dataSTATA"
global raw "$path/dataRAW/DVCs/MO"

local pathok = 0
mata: st_local("pathok", strofreal(direxists("$path")))
if `pathok' == 0 {
  di as error "$path does not exist. rootDir resolved to $rootDir."
  error 601
}

local rawok = 0
mata: st_local("rawok", strofreal(direxists("$raw")))
if `rawok' == 0 {
  di as error "$raw does not exist."
  error 601
}

di as text "Research directory: $rootDir"

cap mkdir "$path/logs"
log using "$path/logs/clean_MO.log", replace text

* share of person rows needing a non-blank AlcoholUseInd before a year's
* alcohol_collision is treated as real rather than missing
local alc_min_coverage 0.50

* Every year is csv except 2016, which is xlsx. Both paths import ALL COLUMNS
* AS STRING so the two give identical types: the leading zeros on crashid,
* county and crashtype survive, and nothing is read as numeric in one year and
* as text in another
capture program drop import_any
program define import_any
    args f
    local ext = lower(substr("`f'", strrpos("`f'", ".") + 1, .))
    if inlist("`ext'", "csv", "txt") {
        import delimited using "`f'", varnames(1) case(lower) ///
            stringcols(_all) clear
    }
    else if inlist("`ext'", "xlsx", "xls") {
        import excel using "`f'", firstrow case(lower) allstring clear
    }
    else {
        di as error "Cannot import .`ext'; expected csv, txt, xlsx or xls:"
        di as error "  `f'"
        error 601
    }
    di as text "  read `=_N' row(s) from `f'"
end

* all three CSVs start with a UTF-8 BOM, so column 1 can import under a mangled
* name depending on the Stata version
capture program drop fix_bom
program define fix_bom
    args want
    capture confirm variable `want'
    if _rc != 0 {
        unab allv : _all
        local v1 : word 1 of `allv'
        * ONLY when the existing name ENDS WITH the wanted one, i.e. it is the
        * wanted name with BOM bytes stuck on the front. The first version
        * renamed column 1 unconditionally, which quietly relabelled the
        * headerless 2019-2022 vehicles files as though they had a header and
        * made a missing-header problem look like a missing-column problem
        if substr("`v1'", -strlen("`want'"), .) == "`want'" {
            di as error "  `want' arrived as `v1', renaming (UTF-8 BOM)"
            rename `v1' `want'
        }
    }
end

* Sets $missing_vars to whichever of the named variables are NOT in memory, so
* a delivery that renames or drops a column is reported by name and its year
* skipped, rather than dying on the keep
capture program drop have_vars
program define have_vars
    global missing_vars ""
    foreach v in `0' {
        capture confirm variable `v', exact
        if _rc != 0 global missing_vars "$missing_vars `v'"
    }
end

* Sets $headerless to 1 when line 1 of a delimited file does not contain the
* name its first column should have. 2019-2022 have NO header row at all:
* line 1 of vehicles.csv is "0190010001V1 ",0190010001,"1FTFW1EV2AFB14986",MO,
* so varnames(1) turns a data record into column names
capture program drop is_headerless
program define is_headerless
    args f token
    global headerless 0
    local ext = lower(substr("`f'", strrpos("`f'", ".") + 1, .))
    if !inlist("`ext'", "csv", "txt") exit
    tempname fh
    capture file open `fh' using "`f'", read text
    if _rc != 0 exit
    file read `fh' line1
    file close `fh'
    * capture, because a header line can run past 2,000 characters and this is
    * a detector: if it cannot read the line, leave the import alone and let
    * the column check downstream report what is actually missing
    capture local hit = strpos(lower(`"`macval(line1)'"'), "`token'")
    if _rc != 0 {
        di as error "    (could not scan line 1 of this file)"
        exit
    }
    if `hit' == 0 global headerless 1
end

* COLUMN POSITIONS for the headerless years. 2019-2022 have no header row but
* are otherwise the standard layout, so the dozen columns this file actually
* needs are taken by position and the other hundred are ignored.
*
* This replaces a donor mechanism that read a header from a year that had one
* and copied its names across. That worked in principle and failed twice in
* practice, both times in the machinery rather than the data. Stating the
* positions is shorter, needs no second file open, and puts the assumption
* where a reader can check it.
*
* EVERY POSITION BELOW IS VERIFIED against the headers of 2018, which has all
* three files headed and at the standard widths, and against the values
* themselves in 2019 and 2020 (NOTE 9). The map is keyed on the column COUNT,
* so a delivery of a different width is refused rather than misread: 2023's
* 115-column vehicles file and 2024's 131-column one would not be named from
* here, and neither needs to be, since both carry headers.
capture program drop name_by_position
program define name_by_position
    args fam k
    global posmap_ok 0
    local map ""
    if "`fam'" == "crashes"  & `k' == 49 {
        local map "1 crashid 4 crashtype 5 crashdate 6 crashdateunk"
        local map "`map' 10 numberinjured 11 numberminorinjuries"
        local map "`map' 12 numberdisablinginjuries 13 numberkilled 14 county"
    }
    if "`fam'" == "persons"  & `k' == 39 {
        local map "1 personid 3 crashid 7 personalinjurylevel 12 alcoholuseind"
        local map "`map' 17 contribcirccd1 18 contribcirccd2 19 contribcirccd3"
        local map "`map' 20 contribcirccd4 21 contribcirccd5 22 contribcirccd6"
        local map "`map' 23 contribcirccd7 24 contribcirccd8 25 contribcirccd9"
        local map "`map' 26 contribcirccd10 27 contribcirccd11 28 contribcirccd12"
    }
    if "`fam'" == "vehicles" & `k' == 119 {
        local map "1 vehicleid 2 crashid 53 animalcd1 54 animalcd2"
        local map "`map' 55 animalcd3 56 animalcd4"
    }
    if "`map'" == "" {
        di as error "    no position map for a `k'-column `fam' file"
        exit
    }

    local n : word count `map'
    forvalues i = 1(2)`n' {
        local pos : word `i' of `map'
        local j   = `i' + 1
        local nm  : word `j' of `map'
        capture rename v`pos' `nm'
        if _rc != 0 {
            di as error "    could not rename v`pos' to `nm'"
            exit
        }
    }

    * A gross misalignment shows up here before anything downstream sees it.
    * Every map names a crashid, and a crash id is never blank
    qui count if trim(crashid) == ""
    if r(N) > 0 {
        di as error "    crashid blank on `r(N)' row(s) after positional naming;"
        di as error "    the layout does not match the map"
        exit
    }
    global posmap_ok 1
    di as text "    named `fam' columns by position"
end

* Import, and if the file turns out to have no header row, re-read it and name
* the needed columns by position. The verification that the positions are the
* right ones sits on name_by_position above
capture program drop import_named
program define import_named
    args f token fam
    global pos_named 0

    * LOOK BEFORE READING. The first version imported with varnames(1) and only
    * then asked whether the file had a header, which means handing Stata a
    * data row and asking it to build variable names out of "1 ", NA, "  " and
    * a date. 2019, 2021 and 2022 survived that; 2020's persons file did not,
    * failing with r(3300) argument out of range inside import delimited before
    * the headerless check could run. Reading line 1 costs nothing and settles
    * it, so the file is now imported once, the right way
    is_headerless "`f'" "`token'"
    if $headerless == 0 {
        import_any "`f'"
        exit
    }

    di as error "    NO HEADER ROW; reading with positional names"
    import delimited using "`f'", varnames(nonames) stringcols(_all) clear
    di as text "  read `=_N' row(s) from `f'"
    name_by_position "`fam'" `=c(k)'
    if $posmap_ok == 0 exit
    global pos_named 1
end

* Prints the first two RAW lines of a delimited file, for when the column
* names come out wrong. 2019-2022 vehicles.csv parses to 119 columns whose
* names are data values (a VIN, MO, FORD, BLU), which is what a header line
* truncated after its first field and joined to the first data record looks
* like. Only the names are visible from inside Stata; the bytes settle it
capture program drop show_head
program define show_head
    args f
    local ext = lower(substr("`f'", strrpos("`f'", ".") + 1, .))
    if !inlist("`ext'", "csv", "txt") {
        di as error "    (not a delimited file, cannot show raw lines)"
        exit
    }
    tempname fh
    capture file open `fh' using "`f'", read text
    if _rc != 0 {
        di as error "    (could not reopen the file to show its first lines)"
        exit
    }
    di as error "    first two raw lines, truncated to 200 characters:"
    forvalues i = 1/2 {
        file read `fh' rawline
        if r(eof) == 0 {
            capture noisily di as error "    `i'| " substr(`"`macval(rawline)'"', 1, 200)
        }
    }
    file close `fh'
end

* Share of rows with a non-blank value, for the columns this file depends on.
* A column that EXISTS BUT IS EMPTY is the trap: AlcoholUseInd is present in
* every year's persons file and blank on all of 2002 and 2003, and read as
* "no alcohol" it would report zero alcohol crashes for two years. Named here
* rather than discovered downstream. Call before destring, while all string
capture program drop report_filled
program define report_filled
    syntax varlist
    foreach v of varlist `varlist' {
        qui count if trim(`v') != ""
        local pc = 100 * r(N) / _N
        if r(N) == 0 {
            di as error "    EMPTY COLUMN: `v' is blank on all `=_N' row(s)"
        }
        else if `pc' < 99.9 {
            di as text "    `v': " %5.1f `pc' "% filled"
        }
    }
end

* collapse writes "(sum) x" as the variable label of everything it touches
capture program drop strip_collapse_labels
program define strip_collapse_labels
    foreach v of varlist _all {
        local lbl : variable label `v'
        if substr("`lbl'", 1, 6) == "(sum) " | substr("`lbl'", 1, 6) == "(max) " {
            label var `v' ""
        }
    }
end

/*-----------------SECTION 0B: locate the year folders --------------*/

* crosswalk sits in dataSTATA/_AUX in some state files and dataSTATA in others
global xwalk ""
foreach f in "$path/dataSTATA/_AUX/state_county_identifiers.dta" ///
             "$path/dataSTATA/state_county_identifiers.dta" {
    if "$xwalk" == "" {
        capture confirm file "`f'"
        if _rc == 0 global xwalk "`f'"
    }
}
if "$xwalk" == "" {
    di as error "state_county_identifiers.dta not found in dataSTATA or dataSTATA/_AUX"
    error 601
}
di as text "County crosswalk: $xwalk"

* Years are discovered from the LEADING FOUR DIGITS of any subdirectory, not
* from a name pattern. The first version globbed *De-Personalised* and so could
* not see 2017_De-Personalized_with_VIN_Extract or its 2018 twin, which are
* spelled with a Z. Those two years were reported as "no folder at all" for
* several runs when the folders were there all along. A convention that varies
* by delivery has no business being load-bearing
local folders : dir "$raw" dirs "*"
local years ""
foreach fd of local folders {
    local y = real(substr("`fd'", 1, 4))
    if !missing(`y') {
        if `y' >= 1990 & `y' <= 2100 local years `years' `y'
    }
}
local years : list sort years
local years : list uniq years
local nyears : word count `years'

if `nyears' == 0 {
    di as error "No subdirectory of $raw starts with a year. Contents:"
    capture noisily dir "$raw"
    error 601
}

di as text "`nyears' year folder(s) found: `years'"

* resolve the three files per year before reading any of them. The extension
* is discovered rather than assumed: every year is csv except 2016, which is
* xlsx. csv is tried first, so a folder holding both keeps the csv
local years_ok ""
local years_skip ""
foreach yr of local years {
    * Taking the last match would pick between a folder and its backup copy
    * without saying so, which is the same mistake as choosing between two
    * candidate files
    local ydir ""
    local ndir = 0
    foreach fd of local folders {
        if substr("`fd'", 1, 4) == "`yr'" {
            local ydir "$raw/`fd'"
            local ++ndir
        }
    }
    local yrok = 1
    if `ndir' > 1 {
        di as error "  `yr': `ndir' directories start with `yr', refusing to choose:"
        foreach fd of local folders {
            if substr("`fd'", 1, 4) == "`yr'" di as error "        `fd'"
        }
        local yrok = 0
    }
    * 2018 names its files crash.csv, person.csv and vehicle.csv, SINGULAR,
    * where every other year is plural. The stem is the singular form so one
    * pattern covers both, and the capitalised variant is tried because dir's
    * matching is case-sensitive on Linux
    foreach pair in "crashes crash Crash" ///
                    "persons person Person" ///
                    "vehicles vehicle Vehicle" {
        local f : word 1 of `pair'
        global `f'_`yr' ""
        local tried ""
        foreach ext in csv xlsx xls txt {
            local tried "`tried' `ext'"
            forvalues w = 2/3 {
                local stem : word `w' of `pair'
                if "${`f'_`yr'}" == "" {
                    local hits : dir "`ydir'" files "`stem'*.`ext'"
                    local nh : word count `hits'
                    if `nh' == 1 {
                        local h : word 1 of `hits'
                        global `f'_`yr' "`ydir'/`h'"
                    }
                    else if `nh' > 1 {
                        * picking one of several silently is how a panel ends
                        * up built from a superseded export
                        di as error "  `yr': `nh' candidates for `stem'*.`ext', refusing to choose:"
                        foreach h of local hits {
                            di as error "        `h'"
                        }
                        local yrok = 0
                    }
                }
            }
        }
        if "${`f'_`yr'}" == "" & `yrok' == 1 {
            di as error "  `yr': no `f' file in `ydir' (tried`tried')"
            local yrok = 0
        }
    }
    if `yrok' == 1 {
        di as text "  ok: `yr'"
        foreach f in crashes persons vehicles {
            di as text "        ${`f'_`yr'}"
        }
        local years_ok `years_ok' `yr'
    }
    else {
        di as error "  `yr': contents of `ydir':"
        capture noisily dir "`ydir'/"
        local years_skip `years_skip' `yr'
    }
}

if "`years_ok'" == "" {
    di as error "No year could be resolved. Nothing has been read."
    error 601
}

* A year that cannot be resolved is SKIPPED, not fatal, so one odd folder does
* not cost the other twenty. Reported here and again at the save, because a
* year quietly absent from the panel is the failure mode to avoid
if "`years_skip'" != "" {
    di as error _newline "{hline 70}"
    di as error "SKIPPED YEAR(S), files not resolved: `years_skip'"
    di as error "Either rename the files, or set the global by hand and rerun, e.g."
    di as error `"  global crashes_2016 "$raw/2016_.../<file>.xlsx""'
    di as error "{hline 70}"
}

local years `years_ok'
local nyears : word count `years'

* A missing FOLDER is a different problem from an unreadable one, and worth
* naming separately since the panel carries a hole either way. This reported
* 2017 and 2018 for several runs, which turned out to be the Z spelling in
* NOTE 10 rather than a real gap, so read it as "no directory starts with this
* year" and check the directory listing before believing it
local ymin : word 1 of `years'
local ymax : word `nyears' of `years'
local gaps ""
forvalues y = `ymin'/`ymax' {
    if strpos(" `years' ", " `y' ") == 0 local gaps `gaps' `y'
}
if "`gaps'" != "" {
    di as error "NO FOLDER AT ALL FOR: `gaps'"
    di as error "The panel will jump across that gap. Check the years in the"
    di as error "output before using it as a continuous series."
}

* Which files have no header row, reported here rather than discovered one at
* a time inside the build
foreach yr of local years {
    foreach pair in "crashes crashid" "persons personid" "vehicles vehicleid" {
        local f : word 1 of `pair'
        local tok : word 2 of `pair'
        local pth "${`f'_`yr'}"
        local ext = lower(substr("`pth'", strrpos("`pth'", ".") + 1, .))
        if inlist("`ext'", "csv", "txt") {
            is_headerless "`pth'" "`tok'"
            if $headerless == 1 ///
                di as error "  `yr' `f': no header row, columns will be named by position"
        }
    }
}

di as text _newline "Building `nyears' year(s): `years'"

/*-----------------SECTION 1: crash level to county-year, one year at a time --*/

* count variables that a county with no crashes should carry as a structural
* zero rather than as missing
local countvars total_all_cause ///
                fatal_collision ///
                major_injury_collision ///
                minor_injury_collision ///
                possible_injury_collision ///
                injury_collision ///
                pdo_collision ///
                total_fatalities ///
                major_injuries ///
                minor_injuries ///
                visible_injuries ///
                possible_injuries ///
                total_injuries ///
                animal_collision ///
                animal_crash_side ///
                animal_veh_side ///
                deer_collision ///
                domestic_animal_collision ///
                other_animal_collision ///
                nondeer_animal_collision ///
                animal_species_unknown_coll ///
                fatal_animal_collision ///
                major_injury_animal_collision ///
                minor_injury_animal_collision ///
                possible_injury_animal_coll ///
                injury_animal_collision ///
                pdo_animal ///
                animal_fatalities ///
                animal_major_injuries ///
                animal_minor_injuries ///
                animal_injuries ///
                n_date_unknown ///
                crashes_with_vehicle_rec ///
                crashes_with_person_rec

tempfile panel vehyr peryr
local started = 0
local years_built ""
local years_failed ""
local years_partial ""
local years_nohdr ""

foreach yr of local years {

    di as text _newline "=== `yr' ==="

    * ---- vehicles: one species per crash ----
    * Every read and every schema check below can skip the year instead of
    * ending the run. A year that cannot be built is named in the summary at
    * the save, so the panel is never quietly short of a year
    capture noisily import_named "${vehicles_`yr'}" vehicleid vehicles
    local rc = _rc
    if `rc' != 0 {
        di as error "  `yr': could not read the vehicles file (error `rc'), year skipped"
        local years_failed `years_failed' `yr'
        continue
    }
    if "$pos_named" == "1" & strpos(" `years_nohdr' ", " `yr' ") == 0 {
        local years_nohdr `years_nohdr' `yr'
    }
    capture fix_bom vehicleid
    have_vars crashid
    * 2023 names the column animalcd, singular, where every other year has
    * animalcd1-4. Requiring animalcd1 by name cost a year whose data was
    * intact, so the requirement is ANY animalcd* and the wildcard does the rest
    capture unab anivars : animalcd*
    if _rc != 0 global missing_vars "$missing_vars animalcd*"
    if "$missing_vars" != "" {
        di as error "  `yr': vehicles file is missing:$missing_vars"
        qui ds
        di as error "  columns present: `r(varlist)'"
        show_head "${vehicles_`yr'}"
        local years_failed `years_failed' `yr'
        continue
    }
    di as text "  `yr': animal column(s) `anivars'"
    keep crashid `anivars'
    report_filled `:word 1 of `anivars''

    * str10, not str3: a wider code in a later delivery would be TRUNCATED into
    * a valid-looking one by a narrow type, which is worse than a new code
    gen str10 species = ""
    foreach v of varlist animalcd* {
        qui replace species = trim(`v') if species == "" & trim(`v') != ""
    }

    * a second species on the same vehicle is lost by taking the first
    gen byte multi_species = 0
    foreach v of varlist animalcd* {
        qui replace multi_species = 1 if trim(`v') != "" & trim(`v') != species
    }
    count if multi_species == 1
    if r(N) > 0 di as error "  `yr': `r(N)' vehicle(s) carry a second species code, only the first is kept"

    * 2002 codes are 60/61/62/63/U; anything new lands in the unknown bucket
    tab species

    * A VOCABULARY GATE, not just a warning. Every built year so far shows only
    * those five codes, so a column full of unrecognised values means this is
    * not the column the build thinks it is -- the likeliest cause being a
    * positionally-named year whose layout does not match the map. A few odd
    * codes are a codebook question; a column of them makes the vehicle side
    * meaningless, which is what animal_data_usable == 0 records in section 2
    count if species != ""
    local n_coded = r(N)
    count if !inlist(species, "", "60", "61", "62", "63", "U")
    local n_odd = r(N)
    gen byte animal_codes_recognised = 1
    if `n_odd' > 0 {
        di as error "  `yr': `n_odd' of `n_coded' coded vehicle(s) carry a species code not seen in 2002"
        tab species if !inlist(species, "", "60", "61", "62", "63", "U")
        if `n_odd' > 0.01 * max(`n_coded', 1) {
            di as error "  That is over 1% of the coded vehicles. Treating this year's animal"
            di as error "  columns as unmeasurable rather than publishing them."
            replace animal_codes_recognised = 0
        }
    }

    * The codebook names these: 60 Deer, 61 Farm Animal, 62 Dog, 63 Other
    * Animal, U Unknown. An earlier version of this file guessed 61 was dog and
    * 62 livestock, which had them the wrong way round; the POOLED non-deer
    * count was unaffected, but the split now follows the codebook. Deer is the
    * wild family and farm animal plus dog the domestic one, which is the split
    * ID carries as wild_animal and non_wild_animal
    gen byte veh_animal   = species != ""
    gen byte veh_deer     = species == "60"
    gen byte veh_domestic = inlist(species, "61", "62")
    gen byte veh_other    = species == "63"
    gen byte veh_spunk    = veh_animal & !veh_deer & !veh_domestic & !veh_other

    assert veh_deer + veh_domestic + veh_other + veh_spunk == veh_animal

    collapse (max) veh_animal veh_deer veh_domestic veh_other veh_spunk ///
             (min) animal_codes_recognised, by(crashid)
    strip_collapse_labels
    save `vehyr', replace

    * ---- persons: B/C split, worst injury, alcohol coverage ----
    capture noisily import_named "${persons_`yr'}" personid persons
    local rc = _rc
    if `rc' != 0 {
        di as error "  `yr': could not read the persons file (error `rc'), year skipped"
        local years_failed `years_failed' `yr'
        continue
    }
    capture fix_bom personid
    have_vars crashid personalinjurylevel alcoholuseind
    if "$missing_vars" != "" {
        di as error "  `yr': persons file is missing:$missing_vars"
        qui ds
        di as error "  columns present: `r(varlist)'"
        show_head "${persons_`yr'}"
        local years_failed `years_failed' `yr'
        continue
    }
    * ContribCircCd is OPTIONAL: a year without it loses the circumstance-based
    * impairment measure, not the year
    capture unab circvars : contribcirccd*
    if _rc != 0 {
        di as error "  `yr': no ContribCircCd column; circumstance measures left missing"
        local circvars ""
    }
    keep crashid personalinjurylevel alcoholuseind `circvars'
    report_filled personalinjurylevel alcoholuseind

    gen str4 lvl = trim(personalinjurylevel)
    gen byte p_k = lvl == "1"
    gen byte p_a = lvl == "2"
    gen byte p_b = lvl == "3"
    gen byte p_c = lvl == "4"
    gen byte worst = 4*p_k + 3*p_a + 2*p_b + 1*p_c

    gen byte alc_yes = trim(alcoholuseind) == "Y"
    gen byte alc_no  = trim(alcoholuseind) == "N"
    gen byte alc_u   = trim(alcoholuseind) == "U"

    * NA means not applicable and is almost entirely PASSENGERS (2016: 111,755
    * of 111,824 NA rows are PersonInvolvementCode 2), so it is excluded from
    * the denominator instead of counted as a gap. Coverage is Y-or-N among the
    * rows that could carry an answer: 0% in 2002, 83.7% in 2016
    gen byte alc_asked = !inlist(trim(alcoholuseind), "", "NA")
    gen byte alc_known = alc_yes | alc_no

    * ---- impairment and animals from the CIRCUMSTANCE codes (NOTE 6, NOTE 4)
    * ContribCircCd 1-12 carries 18 = Alcohol, 19 = Drugs and 31 = Animal(s)
    * In Roadway. It runs the WHOLE PANEL, where AlcoholUseInd is new for 2012,
    * so this is the only impairment measure that spans 2002-2024
    gen byte circ_alcohol = 0
    gen byte circ_drug    = 0
    gen byte circ_animal  = 0
    foreach v of local circvars {
        qui replace circ_alcohol = 1 if trim(`v') == "18"
        qui replace circ_drug    = 1 if trim(`v') == "19"
        qui replace circ_animal  = 1 if trim(`v') == "31"
    }
    gen byte circ_any = 0
    foreach v of local circvars {
        qui replace circ_any = 1 if trim(`v') != ""
    }
    * PARTICIPANTS ARE THE DENOMINATOR. From 2019 the person file carries the
    * short-form non-participant rows, 42.5% of rows in 2020, which have no
    * circumstance by definition. Against all rows the coverage looks like it
    * collapses from 73% to 43% in 2019; against rows that carry an injury
    * level it is 73.1% in 2018 and 74.4% in 2020, i.e. unchanged
    qui summ circ_any if lvl != "", meanonly
    di as text "  `yr': a contributing circumstance is coded on " %5.1f 100*r(mean) ///
               "% of participant rows"

    qui summ alc_asked, meanonly
    local n_asked = r(sum)
    qui summ alc_known, meanonly
    local alc_cov = cond(`n_asked' > 0, r(sum) / `n_asked', 0)
    di as text "  `yr': alcohol status known on " %5.1f 100*`alc_cov' ///
               "% of the `n_asked' person row(s) that could carry one"

    collapse (sum) p_k p_a p_b p_c ///
             (max) worst alc_yes alc_u circ_alcohol circ_drug circ_animal circ_any, ///
             by(crashid)
    strip_collapse_labels
    save `peryr', replace

    * ---- crashes ----
    capture noisily import_named "${crashes_`yr'}" crashid crashes
    local rc = _rc
    if `rc' != 0 {
        di as error "  `yr': could not read the crashes file (error `rc'), year skipped"
        local years_failed `years_failed' `yr'
        continue
    }
    capture fix_bom crashid
    have_vars crashid crashdate crashdateunk crashtype county ///
              numberinjured numberminorinjuries numberdisablinginjuries numberkilled
    if "$missing_vars" != "" {
        di as error "  `yr': crashes file is missing:$missing_vars"
        qui ds
        di as error "  columns present: `r(varlist)'"
        show_head "${crashes_`yr'}"
        local years_failed `years_failed' `yr'
        continue
    }
    keep crashid crashdate crashdateunk crashtype county ///
         numberinjured numberminorinjuries numberdisablinginjuries numberkilled
    report_filled crashtype county crashdate numberinjured ///
                  numberminorinjuries numberdisablinginjuries numberkilled

    destring numberinjured numberminorinjuries numberdisablinginjuries ///
             numberkilled, replace

    * severity is derived from these four, so a blank is not a zero
    count if missing(numberinjured, numberminorinjuries, ///
                     numberdisablinginjuries, numberkilled)
    if r(N) > 0 {
        di as error "  `yr': `r(N)' crash(es) with a blank injury count."
        di as error "  Severity cannot be derived, so the year is skipped."
        di as error "  Decide how to treat these, then rerun."
        local years_failed `years_failed' `yr'
        continue
    }

    gen int county_code = real(trim(county))
    gen byte date_unknown = trim(crashdateunk) == "U"

    * ---- date parsing (NOTE 10) ----
    * TWO FORMATS IN THE DELIVERY. Every year but 2018 writes ISO,
    * "2002-01-06 00:35:00.0000000" or "2019-01-01 21:34". 2018 writes US
    * month-first with a TWO-DIGIT year, "1/5/18 4:55 PM", on all 149,100 rows.
    * Reading the year as substr(1,4) made it missing on every 2018 row, which
    * would have skipped the year for a 100% blank-date rate
    gen str25 dstr = trim(crashdate)
    gen int year  = .
    gen int month = .

    * ISO: a dash sits in position 5
    replace year  = real(substr(dstr, 1, 4)) if substr(dstr, 5, 1) == "-"
    replace month = real(substr(dstr, 6, 2)) if substr(dstr, 5, 1) == "-"

    * US M/D/Y: month before the first slash, year after the second, and the
    * year token ends at the space before the time
    gen int s1 = strpos(dstr, "/")
    gen str25 rest = substr(dstr, s1 + 1, .) if s1 > 0
    gen int s2 = strpos(rest, "/")
    gen str25 ytok = substr(rest, s2 + 1, .) if s2 > 0
    gen int sp = strpos(ytok, " ")
    replace ytok = substr(ytok, 1, sp - 1) if sp > 0
    replace month = real(substr(dstr, 1, s1 - 1)) if missing(month) & s1 > 1
    replace year  = real(ytok)                    if missing(year)  & s2 > 0

    * a two-digit year, in a delivery that spans 2002-2024
    replace year = year + 2000 if year < 100 & !missing(year)

    drop dstr rest ytok s1 s2 sp
    di as text "  `yr': parsed year(s) below"
    tab year, missing

    duplicates drop
    duplicates tag crashid, gen(dup_id)
    count if dup_id > 0
    if r(N) > 0 {
        di as error "  `yr': `r(N)' row(s) share a CrashId but differ in content, year skipped"
        local years_failed `years_failed' `yr'
        continue
    }
    drop dup_id

    * A crash with no county or no date cannot be placed in a county-year.
    * Bounded like the other delivery checks rather than asserted
    count if missing(county_code, year)
    if r(N) > 0 {
        local nblank = r(N)
        di as error "  `yr': `nblank' crash(es) with a blank county or date, dropped"
        if `nblank' > 0.001 * _N {
            di as error "  More than 0.1% of the year, so the year is skipped. Check the"
            di as error "  County and CrashDate columns."
            local years_failed `years_failed' `yr'
            continue
        }
        drop if missing(county_code, year)
    }

    * Rows dated outside the folder year are dropped, not just reported: the
    * neighbouring folder carries that year too, so keeping them would put two
    * rows in the panel for one county-year
    count if year != `yr'
    if r(N) > 0 {
        local nwrongyr = r(N)
        di as error "  `yr': `nwrongyr' crash(es) dated outside the folder year, dropped"
        tab year
        if `nwrongyr' > 0.5 * _N {
            di as error "  That is most of the folder. The `yr' folder does not hold"
            di as error "  `yr' data, so the year is skipped."
            local years_failed `years_failed' `yr'
            continue
        }
        drop if year != `yr'
    }

    count if date_unknown == 1
    di as text "  `yr': `r(N)' crash(es) flagged CrashDateUnk == U"

    * 999 is unknown, 96 is unused, anything else out of 1-116 is not a county
    gen byte noplace = !inrange(county_code, 1, 116) | county_code == 96
    count if noplace
    if r(N) > 0 {
        local nnoplace = r(N)
        di as text "  `yr': `nnoplace' crash(es) with an unplaceable county code, dropped"
        tab county_code if noplace
        if `nnoplace' > 0.001 * _N {
            di as error "  More than 0.1% of the year, so the year is skipped. Check the"
            di as error "  county column against the code list in NOTE 5."
            local years_failed `years_failed' `yr'
            continue
        }
    }
    drop if noplace
    drop noplace

    * a partial year reads as a collapse in collisions rather than as missing
    egen ym_tag = tag(year month)
    bysort year: egen months_present = total(ym_tag)
    count if months_present < 12
    if r(N) > 0 {
        di as error "  `yr': only `=months_present[1]' month(s) present, year dropped"
        tab month
    }
    drop if months_present < 12
    drop ym_tag months_present
    if _N == 0 {
        local years_partial `years_partial' `yr'
        continue
    }

    * A crash with no vehicle record contributes a zero to the animal side.
    * 2010 is the case that matters: NOT a truncated or misparsed file, but an
    * export that DROPPED ONE CLASS OF CRASH. 34,464 of 151,404 crashes (22.8%)
    * have no vehicle record, and by the first digit of CrashId, which encodes
    * the reporting source, they are almost all one source: prefix 3, the
    * Highway Patrol, is 96.7% missing while prefix 0, municipal and county, is
    * 0.0% missing. The person file is complete and cites 51,379 VehicleIds
    * that are absent from vehicles.csv, so the records exist unexported.
    *
    * TWO CONSEQUENCES, and section 2 treats them separately. The missing class
    * is the rural one, so the vehicle side loses 59% of its animal crashes and
    * the SPECIES split is unusable. But CrashType is in the crash file and
    * complete, so the UNION holds: 4,319 against 4,553 in 2009 and 4,376 in
    * 2011. Skipping the year, as the first version did, threw away a sound
    * animal count along with intact fatalities and injuries. See NOTE 9
    merge 1:1 crashid using `vehyr', keep(1 3)
    gen byte crashes_with_vehicle_rec = _merge == 3
    count if _merge == 1
    local nveh = r(N)
    if `nveh' > 0 {
        di as error "  `yr': `nveh' crash(es) (" %4.1f 100*`nveh'/_N "%) with no vehicle record"
        foreach v in veh_animal veh_deer veh_domestic veh_other veh_spunk {
            qui replace `v' = 0 if _merge == 1
        }
        qui replace animal_codes_recognised = 1 if _merge == 1
    }
    drop _merge

    * Same treatment on the person side, which supplies the B/C split, the
    * worst injury level and the alcohol flags. Symmetric on purpose: a
    * truncated persons file in some later year should cost those columns for
    * that year, not the year
    merge 1:1 crashid using `peryr', keep(1 3)
    gen byte crashes_with_person_rec = _merge == 3
    count if _merge == 1
    local nper = r(N)
    if `nper' > 0 {
        di as error "  `yr': `nper' crash(es) (" %4.1f 100*`nper'/_N "%) with no person record"
        foreach v in p_k p_a p_b p_c worst alc_yes alc_u ///
                     circ_alcohol circ_drug circ_animal circ_any {
            qui replace `v' = 0 if _merge == 1
        }
    }
    drop _merge

    * ---- injuries ----
    * THE BREAKDOWN COMES FROM THE PERSON FILE, THE TOTALS FROM THE CRASH FILE,
    * and 2024 is why. Its NumberMinorInjuries and NumberDisablingInjuries are
    * short by 2,134 injured people, while NumberInjured is complete:
    *   killed        955 crash file  =    955 person level 1  (0 mismatches)
    *   disabling   5,286             <  5,434 person level 2
    *   minor      41,728             < 43,714 person levels 3+4
    *   INJURED    49,149             = 49,148 person levels 2+3+4  (1 mismatch)
    * So the category columns are the unreliable ones and the person file
    * reconciles with the crash file's total. Sourcing the breakdown from
    * persons changes 2002-2019 by a handful of crashes a year and recovers
    * 4.3% of 2024's injuries
    rename numberkilled total_fatalities
    rename p_b visible_injuries
    rename p_c possible_injuries
    gen int major_injuries = p_a
    gen int minor_injuries = visible_injuries + possible_injuries
    gen int total_injuries = major_injuries + minor_injuries

    * THE TWO CROSS-FILE IDENTITIES THAT MUST HOLD, now that the breakdown is
    * person-sourced: the crash file's fatality and total-injured counts
    * against the person file's levels. Both hold in every year measured,
    * 2024 included, and a break means the two files no longer describe the
    * same crashes
    *
    * A flag, not a continue, because `continue' inside this inner foreach
    * would advance to the next CHECK rather than skip the year
    local yearbad = 0
    foreach chk in "numberinjured == major_injuries + minor_injuries" ///
                   "total_fatalities == p_k" {
        count if !(`chk')
        if r(N) > 0 {
            local nmm = r(N)
            di as error "  `yr': `nmm' crash(es) violate  `chk'"
            if `nmm' > 0.001 * _N {
                di as error "  More than 0.1% of the year. These columns are meant to describe"
                di as error "  the same crash, so a gap this size means one of them is not the"
                di as error "  column this file thinks it is."
                local yearbad = 1
            }
        }
    }
    if `yearbad' == 1 {
        di as error "  `yr': skipped on the injury reconciliation above"
        local years_failed `years_failed' `yr'
        continue
    }

    * DIVERGENCE FROM THE CRASH FILE'S CATEGORY COLUMNS. Reported, never a
    * gate: these are the columns 2024 leaves short, so a large divergence is
    * information about the delivery rather than a reason to stop
    qui summ numberdisablinginjuries, meanonly
    local cf_major = r(sum)
    qui summ numberminorinjuries, meanonly
    local cf_minor = r(sum)
    qui summ major_injuries, meanonly
    local pf_major = r(sum)
    qui summ minor_injuries, meanonly
    local pf_minor = r(sum)
    if `cf_major' != `pf_major' | `cf_minor' != `pf_minor' {
        di as text "  `yr': injury breakdown, person file vs crash-file columns"
        di as text "        disabling " %8.0fc `pf_major' " vs " %8.0fc `cf_major' ///
                   "   minor " %8.0fc `pf_minor' " vs " %8.0fc `cf_minor'
        local shortfall = (`pf_major' + `pf_minor') - (`cf_major' + `cf_minor')
        if abs(`shortfall') > 0.01 * (`pf_major' + `pf_minor' + 1) {
            di as error "        the crash-file categories are off by `shortfall' injuries,"
            di as error "        over 1%; the person file is used, see NOTE 3"
        }
    }

    * ---- severity, derived from the injury counts (NOTE 2) ----
    * The UNION of both sources at each level, so neither a short crash-file
    * category (2024) nor a missing person row can demote a crash. PDO is the
    * RESIDUAL and possible is intersected with minor, so the partition and the
    * subset both hold BY CONSTRUCTION. Built the obvious way, the kind of
    * record that broke 2003 -- a disabling injury with NumberInjured == 0 --
    * would set both major and pdo and the sum would come to 2
    gen byte total_all_cause        = 1
    gen byte fatal_collision        = total_fatalities > 0
    gen byte major_injury_collision = !fatal_collision ///
                                      & (major_injuries > 0 | numberdisablinginjuries > 0)
    gen byte minor_injury_collision = !fatal_collision & !major_injury_collision ///
                                      & (numberinjured > 0 | minor_injuries > 0)
    gen byte pdo_collision          = !fatal_collision & !major_injury_collision ///
                                      & !minor_injury_collision

    gen byte possible_injury_collision = minor_injury_collision & worst == 1

    gen byte injury_collision = major_injury_collision | minor_injury_collision

    assert fatal_collision + major_injury_collision + minor_injury_collision ///
           + pdo_collision == total_all_cause
    assert possible_injury_collision <= minor_injury_collision

    * ---- animal (NOTE 4) ----
    gen byte crash_side = real(trim(crashtype)) == 1
    count if crash_side == 1 & veh_animal == 0
    local xonly = r(N)
    count if crash_side == 0 & veh_animal == 1
    di as text "  `yr': crash-side only `xonly', vehicle-side only `r(N)'"
    if `xonly' > 100 di as error "  `yr': `xonly' animal crashes carry no species code, check AnimalCd"

    qui count if veh_animal == 1
    if r(N) == 0 di as error "  `yr': NO crash has a species code; animal_collision is the crash side alone"
    qui count if crash_side == 1
    if r(N) == 0 di as error "  `yr': NO crash is typed 01; animal_collision is the vehicle side alone"

    * Both sides are PUBLISHED, not just used, so a reader can see which one
    * produced the count. If one of them ever goes to zero for a whole year the
    * union silently becomes the other, which is exactly how ID's animal series
    * came to be identically zero across 2020 without anyone noticing
    gen byte animal_crash_side = crash_side
    gen byte animal_veh_side   = veh_animal

    gen byte animal_collision            = crash_side | veh_animal
    gen byte deer_collision              = veh_deer
    gen byte domestic_animal_collision   = veh_domestic
    gen byte other_animal_collision      = veh_other
    gen byte nondeer_animal_collision    = veh_domestic | veh_other
    gen byte animal_species_unknown_coll = animal_collision & !veh_deer ///
                                           & !veh_domestic & !veh_other

    * The subfamilies partition animal_collision unless one crash carries both
    * a deer and a non-deer strike. 2017 has exactly one, crashid 2170047795,
    * so this counts rather than asserts and the assert below is an inequality
    count if deer_collision + nondeer_animal_collision ///
             + animal_species_unknown_coll != animal_collision
    if r(N) > 0 di as error "  `yr': `r(N)' crash(es) carry two species, subfamilies do not partition"
    assert deer_collision + nondeer_animal_collision ///
           + animal_species_unknown_coll >= animal_collision

    gen byte fatal_animal_collision        = animal_collision*fatal_collision
    gen byte major_injury_animal_collision = animal_collision*major_injury_collision
    gen byte minor_injury_animal_collision = animal_collision*minor_injury_collision
    gen byte possible_injury_animal_coll   = animal_collision*possible_injury_collision
    gen byte injury_animal_collision       = animal_collision*injury_collision
    gen byte pdo_animal                    = animal_collision*pdo_collision

    * cond(), not multiplication: 0*. is missing in Stata, and a non-animal
    * crash with missing injury data is a structural zero
    gen animal_fatalities     = cond(animal_collision == 1, total_fatalities, 0)
    gen animal_major_injuries = cond(animal_collision == 1, major_injuries, 0)
    gen animal_minor_injuries = cond(animal_collision == 1, minor_injuries, 0)
    gen animal_injuries       = cond(animal_collision == 1, total_injuries, 0)

    * ---- impairment from the circumstance codes, every year (NOTE 6) ----
    * Verified against AlcoholUseInd on the two years where both exist: in
    * 2018 code 18 flags 4,957 crashes and Y flags 5,707, with 4,954 in common
    * and only 3 crashes flagged 18 without Y; 2020 is the same shape. So code
    * 18 is very nearly a SUBSET of Y and is the NARROWER measure. It is the
    * only one available before 2012, which is the point
    gen byte alcohol_circ_collision = circ_alcohol
    gen byte drug_circ_collision    = circ_drug
    gen byte dui_circ_collision     = circ_alcohol | circ_drug
    gen byte animal_circ_side       = circ_animal

    * a year with no ContribCircCd column at all cannot say zero
    qui summ circ_any, meanonly
    local circ_ok = r(max) == 1
    if `circ_ok' == 0 {
        di as error "  `yr': no contributing circumstance coded anywhere; those measures set missing"
        foreach v in alcohol_circ_collision drug_circ_collision ///
                     dui_circ_collision animal_circ_side {
            replace `v' = .
        }
    }

    * ---- alcohol, only where the field is populated (NOTE 6) ----
    * alcohol_collision is a FLOOR, not an estimate: it counts crashes with at
    * least one person flagged Y, and a crash whose only driver is coded U is
    * counted as a zero. alcohol_unknown_collision carries those separately so
    * the true rate can be bounded rather than guessed at
    if `alc_cov' >= `alc_min_coverage' {
        gen byte alcohol_collision         = alc_yes
        gen byte alcohol_unknown_collision = !alc_yes & alc_u
    }
    else {
        di as error "  `yr': alcohol status known on under `alc_min_coverage' of eligible rows, alcohol left missing"
        gen byte alcohol_collision         = .
        gen byte alcohol_unknown_collision = .
    }

    rename date_unknown n_date_unknown

    if _N == 0 {
        di as error "  `yr': no crashes left after the drops above, year skipped"
        local years_failed `years_failed' `yr'
        continue
    }

    collapse (sum) `countvars' alcohol_collision alcohol_unknown_collision ///
                   alcohol_circ_collision drug_circ_collision ///
                   dui_circ_collision animal_circ_side ///
             (min) animal_codes_recognised, by(county_code year)
    strip_collapse_labels

    * collapse(sum) turns an all-missing column into zeros
    if `alc_cov' < `alc_min_coverage' {
        replace alcohol_collision         = .
        replace alcohol_unknown_collision = .
    }
    if `circ_ok' == 0 {
        foreach v in alcohol_circ_collision drug_circ_collision ///
                     dui_circ_collision animal_circ_side {
            replace `v' = .
        }
    }

    assert fatal_collision + major_injury_collision + minor_injury_collision ///
           + pdo_collision == total_all_cause

    if `started' == 1 append using `panel'
    save `panel', replace
    local started = 1
    local years_built `years_built' `yr'
}

if `started' == 0 {
    di as error "No year produced any rows. Every year was skipped; see the"
    di as error "reasons above. Nothing has been saved."
    error 2000
}

di as text _newline "{hline 70}"
di as text "Years built: `years_built'"
if "`years_failed'" != "" di as error "Years skipped during the build: `years_failed'"
if "`years_partial'" != "" di as error "Years skipped as partial: `years_partial'"
di as text "{hline 70}"

/*-----------------SECTION 2: balance the panel and assign FIPS --------------*/

use `panel', clear
isid county_code year
levelsof year, local(panel_years)

* 115 counties every year; a county with no crashes is a structural zero
tempfile yrs skel
keep year
duplicates drop
save `yrs', replace

clear
set obs 115
gen int county_code = _n
replace county_code = county_code + 1 if _n >= 96
cross using `yrs'
save `skel', replace

merge 1:1 county_code year using `panel'
assert _merge != 2
drop _merge

qui foreach v of local countvars {
    replace `v' = 0 if missing(`v')
}

* a filled-in county in a year that does have alcohol data is a zero, not a gap
bysort year: egen byte alc_year_ok = max(!missing(alcohol_collision))
qui foreach v in alcohol_collision alcohol_unknown_collision {
    replace `v' = 0 if missing(`v') & alc_year_ok == 1
}
drop alc_year_ok

bysort year: egen byte circ_year_ok = max(!missing(dui_circ_collision))
qui foreach v in alcohol_circ_collision drug_circ_collision dui_circ_collision ///
             animal_circ_side {
    replace `v' = 0 if missing(`v') & circ_year_ok == 1
}
drop circ_year_ok

isid county_code year

/* [> coverage, and blanking what coverage does not support <] */

* Share of this county-year's crashes that had a vehicle or a person record.
* Where it is below 1 the derived counts are mechanically understated, because
* a crash with no source record contributes a zero rather than a missing
* cond(), because a county-year with no crashes gives 0/0 = missing, and
* missing >= 0.99 is TRUE in Stata: the flags below would have come out usable
* by accident. No crashes means nothing is understated, so coverage is 1
gen vehicle_record_coverage = cond(total_all_cause > 0, ///
    crashes_with_vehicle_rec / total_all_cause, 1)
gen person_record_coverage  = cond(total_all_cause > 0, ///
    crashes_with_person_rec  / total_all_cause, 1)
* TWO DIFFERENT FAILURE MODES, and 2010 proves they need separate flags.
*
* Low vehicle COVERAGE degrades only what the vehicle file alone can say.
* animal_collision is a union with the crash side, which lives in the crash
* file and is complete, so it survives: 2010's union is 4,319 against 4,553 in
* 2009 and 4,376 in 2011, even though its vehicle side gives only 1,758. The
* SPECIES columns have no second source and are roughly half short, so they go
* missing. The union is then a FLOOR, understated only by crashes the vehicle
* side alone would have caught, which is 4 crashes in 2010 and 5 to 39 in the
* years with full coverage
*
* An unrecognised CODE VOCABULARY is different: it means the column is not the
* column we think, so veh_animal is meaningless and must not feed the union
* either. Then everything animal goes, and animal_crash_side is what is left
gen byte animal_data_usable  = animal_codes_recognised == 1
gen byte species_data_usable = vehicle_record_coverage >= 0.99 ///
                               & animal_codes_recognised == 1
gen byte bc_split_usable    = person_record_coverage  >= 0.99

di as text _newline "Source-record coverage by year. Derived counts are usable at or near 1:"
tabstat vehicle_record_coverage person_record_coverage, by(year) ///
    statistics(mean min) format(%9.4f)

* UNDERSTATED IS NOT THE SAME AS LOW, so an unsupported column goes MISSING
* rather than being published short. animal_crash_side is never blanked: it
* comes from CrashType in the crash file, so it stays the usable animal
* measure for a year whose vehicles file is short
*
* species only: no second source, so short vehicle coverage kills them
local speciesonly deer_collision ///
                  domestic_animal_collision ///
                  other_animal_collision ///
                  nondeer_animal_collision ///
                  animal_species_unknown_coll

* the union family: survives short coverage, dies on a bad vocabulary
local unionfam animal_collision ///
               animal_veh_side ///
               fatal_animal_collision ///
               major_injury_animal_collision ///
               minor_injury_animal_collision ///
               possible_injury_animal_coll ///
               injury_animal_collision ///
               pdo_animal ///
               animal_fatalities ///
               animal_major_injuries ///
               animal_minor_injuries ///
               animal_injuries

count if species_data_usable == 0
if r(N) > 0 {
    di as error "WARNING: `r(N)' county-year(s) cannot support the species split."
    qui levelsof year if species_data_usable == 0, local(bad_species_years)
    di as error "Affected years: `bad_species_years'"
    di as error "deer_collision and the other species columns are set to missing."
    di as error "animal_collision survives as a FLOOR, because its crash side is"
    di as error "complete; animal_crash_side and animal_veh_side show each side."
    qui foreach v of local speciesonly {
        replace `v' = . if species_data_usable == 0
    }
}

count if animal_data_usable == 0
if r(N) > 0 {
    di as error "WARNING: `r(N)' county-year(s) have an unrecognised AnimalCd"
    di as error "vocabulary, so the vehicle side cannot be trusted at all."
    qui levelsof year if animal_data_usable == 0, local(bad_animal_years)
    di as error "Affected years: `bad_animal_years'"
    di as error "Every animal column is set to missing except animal_crash_side."
    qui foreach v of local unionfam {
        replace `v' = . if animal_data_usable == 0
    }
}

* Now that the breakdown is person-sourced, short person coverage costs the
* injury MAGNITUDES too, not just the B/C split. total_fatalities is exempt:
* it comes from the crash file and agrees with the person file in every year
local pederived visible_injuries ///
                possible_injuries ///
                possible_injury_collision ///
                major_injuries ///
                minor_injuries ///
                total_injuries ///
                animal_major_injuries ///
                animal_minor_injuries ///
                animal_injuries

count if bc_split_usable == 0
if r(N) > 0 {
    di as error "WARNING: `r(N)' county-year(s) have incomplete person coverage."
    qui levelsof year if bc_split_usable == 0, local(bad_bc_years)
    di as error "Affected years: `bad_bc_years'"
    di as error "The injury breakdown is set to missing there. total_all_cause,"
    di as error "total_fatalities and the severity flags are unaffected."
    qui foreach v of local pederived {
        replace `v' = . if bc_split_usable == 0
    }
}

* NOTE 5: alphabetical order is the FIPS order, with two documented exceptions
gen str5 fips = "29" + string(2*county_code - 1, "%03.0f")
replace fips = "29186" if county_code == 97
replace fips = "29510" if county_code == 116
assert length(fips) == 5

gen str2 state_letter_code = "MO"

/*-----------------SECTION 3: merge county identifiers --------------*/

merge m:1 state_letter_code fips using "$xwalk", keep(1 3)
count if _merge == 1
if r(N) > 0 {
    list county_code fips if _merge == 1, noobs
    di as error "the county code(s) above did not match the crosswalk"
}
assert _merge == 3
drop _merge

drop if county_name == ""

* a wholesale shift in the crosswalk would show up as a break in alphabetical
* order; codes 60/61 (McDonald/Macon) and 92-116 (St./Ste./Saline) are
* legitimately out of strict order, so they are excluded from the check
local y1 : word 1 of `panel_years'
preserve
    keep if year == `y1'
    keep if county_code <= 59 | inrange(county_code, 62, 91)
    sort county_name
    gen seq = _n
    sort county_code
    gen rank = _n
    count if seq != rank
    if r(N) > 0 {
        list county_code county_name seq rank if seq != rank
        di as error "CROSSWALK WARNING: county_code is not alphabetical in county_name."
        di as error "Check the code-to-FIPS mapping in section 2 before using the panel."
    }
    else di as text "Crosswalk check passed: county_code matches alphabetical order."
restore

/*-----------------SECTION 4: checks, labels, save --------------*/

foreach v of local countvars {
    assert `v' >= 0 if !missing(`v')
}
assert alcohol_collision >= 0 if !missing(alcohol_collision)
assert alcohol_unknown_collision >= 0 if !missing(alcohol_unknown_collision)
assert alcohol_collision + alcohol_unknown_collision <= total_all_cause ///
    if !missing(alcohol_collision)

* alcohol is present in some years and absent in others, so the two must be
* missing or present together
assert missing(alcohol_collision) == missing(alcohol_unknown_collision)

assert fatal_collision + major_injury_collision + minor_injury_collision ///
       + pdo_collision == total_all_cause
assert total_injuries == major_injuries + minor_injuries if bc_split_usable == 1
assert crashes_with_vehicle_rec <= total_all_cause
assert crashes_with_person_rec  <= total_all_cause

assert possible_injury_collision <= minor_injury_collision if bc_split_usable == 1

assert animal_collision <= total_all_cause ///
       & animal_crash_side <= animal_collision ///
       & animal_veh_side   <= animal_collision ///
       & animal_collision  <= animal_crash_side + animal_veh_side ///
       & animal_collision  >= fatal_animal_collision ///
       if animal_data_usable == 1

* the species inequality only where the species columns are real. Missing is
* larger than any number in Stata, so left unconditional this would pass
* trivially on a blanked year rather than checking anything
assert deer_collision + nondeer_animal_collision ///
       + animal_species_unknown_coll >= animal_collision ///
       if species_data_usable == 1
assert nondeer_animal_collision >= domestic_animal_collision ///
       & nondeer_animal_collision >= other_animal_collision ///
       if species_data_usable == 1
assert alcohol_circ_collision <= dui_circ_collision ///
       & drug_circ_collision    <= dui_circ_collision ///
       & dui_circ_collision     <= total_all_cause ///
       if !missing(dui_circ_collision)
assert animal_circ_side <= total_all_cause if !missing(animal_circ_side)

* blanked uniformly, not partly
assert missing(deer_collision) & missing(nondeer_animal_collision) ///
       & missing(domestic_animal_collision) & missing(other_animal_collision) ///
       & missing(animal_species_unknown_coll) if species_data_usable == 0
count if animal_data_usable == 0
if r(N) > 0 {
    assert missing(animal_collision) & missing(animal_injuries) ///
           if animal_data_usable == 0
}
assert missing(visible_injuries) & missing(possible_injuries) ///
       & missing(major_injuries) & missing(total_injuries) if bc_split_usable == 0

* animal_crash_side survives the blanking and must stay a real count
assert !missing(animal_crash_side) & animal_crash_side <= total_all_cause

bysort year: gen n_counties = _N
assert n_counties == 115
drop n_counties

preserve
    * A blanked column sums to zero, which would read as "no deer crashes in
    * 2010" rather than "not measurable in 2010". But blanking the YEAR because
    * a couple of county-years are short overstates the damage: 2018 lost its
    * whole deer share to 2 cells out of 115. So the share is taken over the
    * cells that SURVIVE, and blanked only when too few of them do
    gen byte species_blank = species_data_usable == 0
    gen deer_usable   = deer_collision   if species_data_usable == 1
    gen animal_usable = animal_collision if species_data_usable == 1
    collapse (sum) total_all_cause total_fatalities animal_crash_side ///
                   animal_collision deer_usable animal_usable species_blank ///
             (min) animal_data_usable, by(year)

    replace animal_collision = . if animal_data_usable == 0
    gen animal_share = 100 * animal_collision / total_all_cause
    gen deer_share   = 100 * deer_usable / animal_usable
    replace deer_share = . if species_blank > 11
    format animal_share deer_share %5.1f
    format total_all_cause total_fatalities animal_crash_side ///
           animal_collision %12.0gc
    di as text _newline "ANNUAL TOTALS  (animal_collision is blank where the"
    di as text "vehicles file is short; animal_crash_side still stands)"
    label var species_blank "county-years with no species split"
    list year total_all_cause total_fatalities animal_crash_side ///
         animal_collision animal_share deer_share species_blank, ///
         noobs abbrev(18)
    di as text "species_blank counts the county-years whose species split is"
    di as text "missing, out of 115. deer_share is taken over the cells that"
    di as text "survive, and blanked only when more than 11 of 115 are gone."
restore

* THE IMPAIRMENT SERIES SIDE BY SIDE, because the two measures do not cover
* the same years and the seam is the thing to look at. circ comes from
* ContribCircCd 18 and runs the whole panel; ind comes from AlcoholUseInd and
* starts in 2012. If they track each other from 2012 on, the circ series can
* be trusted before it. If the circ series jumps at some year, that is a
* change in reporting practice, not in drinking
preserve
    gen byte ind_missing = missing(alcohol_collision)
    collapse (sum) total_all_cause alcohol_circ_collision dui_circ_collision ///
                   alcohol_collision alcohol_unknown_collision ///
             (max) ind_missing, by(year)
    foreach v in alcohol_collision alcohol_unknown_collision {
        replace `v' = . if ind_missing == 1
    }
    gen circ_pct = 100 * alcohol_circ_collision / total_all_cause
    gen ind_pct  = 100 * alcohol_collision      / total_all_cause
    gen unk_pct  = 100 * alcohol_unknown_collision / total_all_cause
    format circ_pct ind_pct unk_pct %6.2f
    format total_all_cause alcohol_circ_collision dui_circ_collision ///
           alcohol_collision %12.0gc
    di as text _newline "ALCOHOL, THE TWO MEASURES (NOTE 6)"
    di as text "circ = ContribCirc 18, all years.  ind = AlcoholUseInd Y, 2012 on."
    di as text "unk_pct is the headroom on ind: no Y but at least one U."
    list year total_all_cause alcohol_circ_collision circ_pct ///
         alcohol_collision ind_pct unk_pct dui_circ_collision, ///
         noobs abbrev(16)
restore

label var total_all_cause             "All-cause collisions"
label var fatal_collision             "Fatal collisions"
label var major_injury_collision      "Disabling-injury collisions"
label var minor_injury_collision      "Minor-injury collisions (KABCO B or C)"
label var possible_injury_collision   "Possible-injury collisions (C only, subset of minor)"
label var injury_collision            "Injury collisions"
label var pdo_collision               "Property-damage-only collisions"
label var total_fatalities            "Persons killed"
label var major_injuries              "Disabling injuries, KABCO A, from the person file"
label var minor_injuries              "Minor injuries, KABCO B + C, from the person file"
label var visible_injuries            "Visible injuries (KABCO B)"
label var possible_injuries           "Possible injuries (KABCO C)"
label var total_injuries              "Injuries, disabling + minor"
label var animal_collision            "Animal-related collisions (crash or vehicle side)"
label var animal_crash_side           "Animal collisions, CrashType 01 alone, never blanked"
label var animal_veh_side             "Animal collisions, AnimalCd alone"
label var deer_collision              "Deer collisions, AnimalCd 60, the wild family"
label var domestic_animal_collision   "Farm animal or dog, AnimalCd 61 and 62"
label var other_animal_collision      "Other animal, AnimalCd 63"
label var nondeer_animal_collision    "Non-deer animal collisions, AnimalCd 61-63"
label var animal_species_unknown_coll "Animal collisions with no species code"
label var alcohol_collision           "Alcohol-involved collisions, a FLOOR (>=1 person coded Y)"
label var alcohol_unknown_collision   "No Y but >=1 person coded U: the upper bound on alcohol"
label var animal_circ_side            "Animal collisions, ContribCirc 31, a THIRD source"
label var alcohol_circ_collision      "Alcohol, ContribCirc 18: the only measure spanning 2002-2024"
label var drug_circ_collision         "Drugs, ContribCirc 19"
label var dui_circ_collision          "Alcohol or drugs, ContribCirc 18 or 19"
label var n_date_unknown              "Crashes flagged CrashDateUnk == U"
label var crashes_with_vehicle_rec    "Crashes with a vehicle record"
label var crashes_with_person_rec     "Crashes with a person record"
label var vehicle_record_coverage     "Share of crashes with a vehicle record"
label var person_record_coverage      "Share of crashes with a person record"
label var animal_data_usable          "1 = AnimalCd vocabulary recognised, union usable"
label var species_data_usable         "1 = vehicle coverage >= 0.99 too, species split usable"
label var animal_codes_recognised     "0 = AnimalCd vocabulary was unrecognised that year"
label var bc_split_usable             "1 = person coverage >= 0.99, B/C split usable"
label var county_code                 "MO county code, 1-116"

sort county_name year, stable
order state_letter_code ///
      state_name ///
      county_name ///
      state_fips ///
      county_fips ///
      fips ///
      county_code ///
      year ///
      animal_data_usable ///
      species_data_usable ///
      animal_codes_recognised ///
      bc_split_usable ///
      vehicle_record_coverage ///
      person_record_coverage ///
      crashes_with_vehicle_rec ///
      crashes_with_person_rec ///
      total_all_cause ///
      total_fatalities ///
      total_injuries ///
      major_injuries ///
      minor_injuries ///
      visible_injuries ///
      possible_injuries ///
      fatal_collision ///
      major_injury_collision ///
      minor_injury_collision ///
      possible_injury_collision ///
      injury_collision ///
      pdo_collision ///
      animal_collision ///
      animal_crash_side ///
      animal_veh_side ///
      animal_circ_side ///
      deer_collision ///
      domestic_animal_collision ///
      other_animal_collision ///
      nondeer_animal_collision ///
      animal_species_unknown_coll ///
      fatal_animal_collision ///
      major_injury_animal_collision ///
      minor_injury_animal_collision ///
      possible_injury_animal_coll ///
      injury_animal_collision ///
      pdo_animal ///
      animal_fatalities ///
      animal_major_injuries ///
      animal_minor_injuries ///
      animal_injuries ///
      alcohol_collision ///
      alcohol_unknown_collision ///
      alcohol_circ_collision ///
      drug_circ_collision ///
      dui_circ_collision ///
      n_date_unknown

qui summ year
local t1 = r(min)
local t2 = r(max)

compress
save "$working_data/dvcs_MO_county_year_`t1'_`t2'.dta", replace

di as text _newline "Saved: $working_data/dvcs_MO_county_year_`t1'_`t2'.dta"
di as text "Log:   $path/logs/clean_MO.log"

* Repeated here because the reasons are hundreds of log lines back by now, and
* a year quietly absent from the panel is the failure mode this file is most
* concerned with. Anything listed below is NOT in the saved panel
di as text _newline "{hline 70}"
di as text "YEARS IN THE PANEL: `years_built'"
if "`years_skip'" != "" {
    di as error "Folder present, files not resolved:  `years_skip'"
}
if "`years_failed'" != "" {
    di as error "Skipped during the build:            `years_failed'"
}
if "`years_partial'" != "" {
    di as error "Skipped as under 12 months:          `years_partial'"
}
if "`years_nohdr'" != "" {
    di as text  "Named positionally, no header row:   `years_nohdr'"
}
if "`gaps'" != "" {
    di as error "No folder at all:                    `gaps'"
}
if "`years_skip'`years_failed'`years_partial'`gaps'" == "" {
    di as text "Every folder found was built. No gaps."
}
di as text "{hline 70}"

cap log close
