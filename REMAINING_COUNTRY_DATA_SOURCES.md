# Data Sources for the Four Remaining Countries

## Recommended next sources

| Country | Recommended source | Access | Assessment / next action |
|---|---|---|---|
| Botswana | Family Health Survey IV 2007-08 | [IHSN catalog and public-use microdata](https://catalog.ihsn.org/catalog/7414/study-description) | **Preferred.** National two-stage survey, children 0-4, with under-five weight, length, height, household variables, and weights. Build it in a new script; verify PSU, stratum, position, and age before replacing recovered MICS 2000. |
| Chile | ELPI 2010 | [Ministry ELPI 2010 page](https://observatorio.ministeriodesarrollosocial.gob.cl/elpi-primera-ronda) and [data catalog](https://bid-ckan.ministeriodesarrollosocial.gob.cl/dataset/) | **Usable candidate.** Public microdata, national probabilistic child sample and weights. It represents children born Jan 2006-Aug 2009—not every 0-59-month cohort—so document the observed age range and excluded hard-to-reach communes. Confirm raw height/weight and measurement-position fields before harmonization. |
| Cabo Verde | QUIBB 2006; alternatively IDSR 2018 | [QUIBB 2006 child nutrition file](https://www.ine.cv/dircv/index.php/catalog/11/data-dictionary); [IDSR 2018](https://www.ine.cv/dircaboverde/index.php/catalog/1028/study-description) | **Request/download and audit.** QUIBB has 2,690 under-six nutrition records and weights, but the catalog says only derived variables are released; verify the growth reference and exact age. IDSR 2018 has raw anthropometry but covers children 6-71 months, so a 6-59 subset omits young infants. Prefer QUIBB only if WHO-2006-compatible values or raw measures can be obtained; otherwise use IDSR with the coverage limitation stated. |
| Mauritius | National Nutrition Survey 1995 | [Official historical description](https://statsmauritius.govmu.org/Documents/Census_and_Surveys/HPC/2000/Volume_VI-Health.pdf) | **Microdata request required.** The Ministry of Health/Statistics Mauritius confirms a child, adult, and pregnant-woman nutrition survey conducted with WHO and UNICEF, but no public child-level microdata catalog was found. Request anonymized child records, raw age/sex/weight/height/position, household identifiers, sampling weights, PSU/stratum, questionnaires, and sampling report. Do not substitute the 2022 survey: it begins at age 5. |

## Acquisition order

1. Download/request Botswana BFHS 2007-08 and audit its under-five and design
   modules in a separate script.
2. Download Chile ELPI 2010 and inspect anthropometry, exact age, weights, PSU,
   strata, and cohort coverage.
3. Request Cabo Verde QUIBB 2006 files; decide between QUIBB and IDSR 2018 only
   after confirming WHO-2006 reconstructability and age coverage.
4. Send a formal microdata request for Mauritius 1995. Until a child-level file
   and design documentation are received, code Mauritius covariates/outcomes as
   `NA`, not zero.
