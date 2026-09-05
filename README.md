# ra_anthro

Anthropometric harmonization for a second set of countries (Bolivia,
Botswana, Namibia, Mauritius, Lesotho, Eswatini, Cabo Verde, Chile) —
built alongside, but separate from, `ra_su26`'s 10-country
ch_merge/fs_merge harmonization. Scope is narrower: anthropometric
outcomes (`haz`/`waz`/`whz`, `stunted`/`underweight`/`wasted`/`overweight`)
plus a minimal set of household covariates, not a full multi-domain merge.

Full background, source-format audit, and open questions:
[ANTHRO_EXTENSION_PLAN.md](ANTHRO_EXTENSION_PLAN.md).
The approved analytical population and missing-data rules are recorded in
[ANALYTICAL_SPECIFICATION.md](ANALYTICAL_SPECIFICATION.md).

## Country status

| Country | Status | Source |
|---|---|---|
| Eswatini | In pipeline | MICS6 |
| Lesotho | In pipeline | MICS6 |
| Bolivia | In pipeline | DHS 2008 |
| Namibia | In pipeline | DHS 2013 |
| Botswana | Recovered, provisional | MICS 2000 singleton child keys; conflicts quarantined. BFHS 2007-08 remains the preferred replacement candidate. |
| Mauritius | Pending | No data yet |
| Cabo Verde | Source identified | QUIBB 2006 and IDSR 2018 require a coverage/standard choice |
| Chile | Source identified | ELPI 2010 public microdata |

## Pipeline

Run in order:

| Script | Output |
|---|---|
| `01_import_dictionary.R` | `intermediate/anthro_setup.rds` — raw import across MICS6/DHS/MICS2000 |
| `02_hh_controls.R` | `intermediate/hh_controls.rds` — urban/rural, wealth |
| `03_hl_controls_composition.R` | `intermediate/hl_controls_composition.rds` — household size, oldest member, pension eligibility |
| `04_construct_anthro.R` | `intermediate/anthro_outcomes.rds` — source measures + WHO-quality-controlled outcomes |
| `05_merge.R` | `harmonized_outcomes/anthro_merge.{rds,csv}` — joined with `ra_su26`'s 10 countries, 14 total |
| `06_construct_analysis_samples.R` | Eligible-child dataset, valid-anthropometry dataset, and country sample-flow audit |
| `07_covariate_availability.R` | Survey-by-variable availability and missingness matrix |
| `08_recover_botswana_mics2000.R` | Provisional Botswana singleton-child file, duplicate quarantine, and recovery audit |

Other folders:

- `countries/` — standalone, single-country exploratory scripts (dictionary + quick checks), not part of the numbered pipeline.
- `Rmd/anthro_merge_audit.Rmd` — QA report over the final merge (coverage, completeness, prevalence, known issues). Knit it to check the current state of the data.
- `R/anthro_quality.R` — shared WHO plausibility, measurement-position, and missingness rules.
- `R/household_composition.R` — shared usual-resident household composition rules.
- `R/pension_eligibility.R` — survey-year age-cutoff construction for usual-resident rosters.
- `crosswalks/pension_policy_audit.csv` — verified survey-year rules used in `03_hl_controls_composition.R`.
- `crosswalks/social_pension_programs.csv` — legacy preliminary lookup; retained for provenance but not used.
- `shiny_app/` — interactive dashboard: country dropdown + clickable Leaflet map showing anthropometric outcomes, built on a small aggregated summary (not the raw survey data — see `shiny_app/README.md`). Run with `shiny::runApp("shiny_app")`.

## Setup

Raw files are read from Google Drive by default
(`research/ra_summer2026/dataset/`); override with the `ANTHRO_DATA_PATH`
environment variable. See `00_paths.R`.

Botswana WHO-2006 WAZ reconstruction uses CRAN `anthro`. The recovery script
will use a regular R-library installation or a project-local copy under
`intermediate/Rlib`.
