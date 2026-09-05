# Analytical Specification

Status: Approved  
Scope: Child-level anthropometry harmonization and regression datasets  
Out of scope for the current work: `shiny_app/`

## 1. Purpose

The project will construct nationally representative, child-level datasets
for anthropometric regression and estimation. It will harmonize data from
the eight `ra_anthro` target countries and, where appropriate, combine them
with the ten countries prepared by `ra_su26`.

The primary outcomes are:

- Height-for-age z-score (`haz`)
- Weight-for-age z-score (`waz`)
- Weight-for-height z-score (`whz`)
- Stunting
- Underweight
- Wasting
- Overweight

The project will retain household, parental, survey-design, source, and
pension-eligibility variables needed for later analysis. This specification
defines the analytical rules; it does not select a final regression model.

## 2. Unit of observation

The intended unit of observation is one child in one survey.

Every harmonized record must have:

- A survey identifier
- A country identifier
- A household identifier
- A child identifier that is unique within the survey
- A link to the original source identifier when available

Household identifiers alone are not child identifiers because more than one
eligible child may live in the same household.

## 3. Target population

The primary target population is:

> Living, usual-resident children aged 0 through 59 completed months at the
> time of the survey.

The following concepts must be represented separately rather than inferred
from the presence of a row in a source file:

- `living_child`: the child was alive at the survey date.
- `usual_resident`: the child was a usual member of the sampled household.
- `age_eligible`: the child's age was 0-59 completed months.
- `sample_eligible`: all three conditions above were satisfied.
- `anthro_eligible`: the child was selected or expected to receive an
  anthropometric measurement under the survey protocol.
- `anthro_measured`: the required physical measurement was attempted and
  recorded.
- `anthro_valid`: the resulting anthropometric observation passed the
  applicable quality and plausibility rules.

When a source contains records outside the target population, those records
may be retained in a source-level staging dataset for auditing, but they must
not enter the primary harmonized child population.

## 4. Analytical datasets

The pipeline will eventually produce distinct datasets rather than using one
file for every purpose.

### 4.1 Full eligible-child dataset

Contains one row for every child who satisfies `sample_eligible`, including
children whose anthropometric outcomes are missing. This is the appropriate
dataset for:

- Measurement-response analysis
- Missingness analysis
- Sample-flow reporting
- Comparing measured and unmeasured eligible children

### 4.2 Valid-anthropometry dataset

Contains children from the full eligible-child dataset with at least one
valid harmonized anthropometric outcome. Outcome-specific regressions must
use the valid sample for that particular outcome, since a child may have a
valid WAZ but missing HAZ or WHZ.

### 4.3 Common-covariate pooled dataset

Contains the variables that can be defined comparably across the countries
included in a particular pooled model. It must not convert structurally
unavailable covariates to zero.

### 4.4 Country-specific extended datasets

May retain additional variables available only in particular sources, such
as DHS birth-history variables. These variables will not automatically be
required in pooled specifications.

## 5. Anthropometric standard

All harmonized anthropometric outcomes will use the WHO 2006 Child Growth
Standards.

Where a source already supplies WHO-2006 z-scores, the pipeline will retain
both the original source value and the cleaned harmonized value.

Where raw measurements are available, z-scores will be reconstructed using:

- Child sex
- Exact age at measurement, preferably in days and otherwise in completed
  months
- Weight in kilograms
- Recumbent length or standing height in centimeters
- Measurement position

The reconstruction method and software version must be documented.

## 6. Missing measurement position

When the record-level measurement position is missing and cannot be
established from authoritative survey documentation:

- Retain the child in the full eligible-child dataset.
- Retain the raw height or length measurement.
- Calculate WAZ when sex, age, and weight are otherwise valid.
- Set harmonized HAZ and WHZ to missing.
- Set `anthro_position_missing = 1`.
- Record the reason in the anthropometry audit.

The pipeline must not silently infer measurement position solely from age.
If survey documentation establishes a deterministic measurement protocol,
use of that protocol must be recorded as a documented source-level rule, not
as an undocumented record-level assumption.

## 7. Anthropometric quality rules

Quality assessment must be outcome-specific and follow the selected WHO
methodology. The current single `-6` to `+6` rule will not be assumed to be
valid for every outcome.

The harmonized data will distinguish:

- Missing raw measurement
- Measurement not attempted
- Measurement refused or otherwise unavailable
- Source-flagged measurement
- Missing measurement position
- Biologically implausible z-score
- Valid measurement

Source flags must be retained even when the harmonized procedure constructs
its own validity flag.

## 8. Binary outcome definitions

Subject to valid outcome-specific z-scores:

- `stunted = 1` when `haz < -2`; otherwise `0`.
- `underweight = 1` when `waz < -2`; otherwise `0`.
- `wasted = 1` when `whz < -2`; otherwise `0`.
- `overweight = 1` when `whz > 2`; otherwise `0`.

If the required z-score is missing, its binary outcome must also be missing.
Missing outcomes must never be coded as zero.

## 9. Survey design information

All source variables that may be required for nationally representative
estimation must be retained, including:

- Original survey weight
- Analysis-ready survey weight
- A within-country normalized version of the weight
- Primary sampling unit
- Sampling stratum
- Region or other published estimation domain
- Urban/rural residence

No final pooled-country weighting strategy is selected in this
specification. Population-expansion weights will not be constructed until a
specific pooled estimand is defined. Original design information must be
preserved so that the decision remains possible later.

## 10. Household membership and composition

Household composition variables will describe usual residents unless a
specific analysis explicitly defines a different population.

This rule applies to:

- Household size
- Number of children under five
- Working-age member count
- Dependency ratio
- Oldest household member
- Household-head characteristics
- Presence of a pension-eligible member

Visitors and non-usual residents must not change these variables in the
primary harmonized definition.

## 11. Sibling measures

Deceased children must not be counted as living under-five siblings.

Where supported by the source data, retain two distinct concepts:

- `n_biological_siblings_under5`: other living biological siblings aged
  0-59 months, whether or not they live in the sampled household.
- `n_coresident_children_under5`: other usual-resident children aged 0-59
  months in the sampled household.

If a source cannot support a definition, the corresponding value must be
missing and documented as structurally unavailable.

## 12. Covariate missingness

Unavailable covariates will be represented by `NA`.

The project will distinguish:

- Item missingness: the survey collected the variable, but the value is
  missing for a particular record.
- Structural unavailability: the survey did not collect the variable or did
  not provide the required source module.
- Inapplicability: the concept does not apply to the record.

A survey-by-variable availability matrix will document structural gaps.
Where useful for regression diagnostics, availability indicators may be
created separately, but they will not replace the missing values themselves.

No automatic imputation is authorized by this specification.

## 13. Pension eligibility

Pension eligibility will be defined using the rules in effect during each
survey's fieldwork period, not current eligibility rules.

Before these variables are used in regression, a separate historical-policy
audit must verify:

- Program name
- Legal basis
- Effective dates
- Eligibility age
- Sex-specific provisions
- Means testing or contribution requirements
- Major reforms relevant to the survey date
- Primary or authoritative sources

Unverified country-year rules must remain missing until reviewed and
approved.

## 14. Cross-country comparability

Differences in survey year are acceptable, but every dataset must retain its
survey year and source. Analyses must not interpret pooled estimates as a
single-period cross-section unless survey-year differences are explicitly
handled.

Source-specific variables may be retained in extended datasets, but the
meaning and coding of every variable in a pooled regression must be
comparable across included countries.

## 15. Botswana-specific staging rule

Botswana MICS 2000 will first be treated as a recovery exercise:

- Unambiguous singleton child records may be retained provisionally.
- Exact duplicates may be collapsed only under documented rules.
- Conflicting duplicate child keys must be quarantined unless an objective
  source field resolves them.
- No conflicting record may be chosen arbitrarily.
- WHO-2006 outcomes must be reconstructed from raw measurements when the
  required inputs are available.

Botswana BFHS 2007-2008 will later be implemented separately and will not
silently overwrite the recovered MICS dataset.

## 16. Required audit outputs

Each country must eventually have an audit containing:

- Source records received
- Target-population exclusions
- Eligible children
- Anthropometry-eligible children
- Measured children
- Valid observations by outcome
- Duplicate and identifier problems
- Household and parent join rates
- Weight, PSU, and stratum completeness
- Covariate availability
- Weighted and unweighted prevalence
- Comparison with published estimates where available

## 17. Deferred decisions

The following decisions are intentionally deferred until the relevant
analysis is specified:

- The final pooled-country weighting strategy
- The exact common covariate set for each regression family
- Imputation or other missing-data methods
- Whether recovered Botswana MICS 2000 or BFHS 2007-2008 becomes the
  canonical Botswana source
- Treatment of countries for which compatible child-level microdata cannot
  be obtained

## 18. Explicit exclusions from the current work

The current work will not modify, regenerate, test, or validate:

- `shiny_app/app.R`
- `shiny_app/prepare_data.R`
- `shiny_app/country_summary.csv`
- Dashboard titles, maps, or visualizations

The Shiny application may remain out of sync with the analytical pipeline
until a separate dashboard task is authorized.
