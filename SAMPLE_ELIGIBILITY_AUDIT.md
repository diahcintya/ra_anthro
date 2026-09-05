# Sample Eligibility Audit

Status: Step 3 implementation review  
Primary output: `harmonized_outcomes/anthro_full_eligible.rds`

## Implemented population rule

The primary population contains living, usual-resident children aged 0-59
completed months. Children are not excluded because their anthropometric
measurement or outcome is missing.

The source-universe merge remains available as `anthro_merge.rds`. The
primary eligible-child dataset and the dataset with at least one valid
anthropometric outcome are separate outputs.

## Source-specific construction

| Source | Living child | Usual resident | Age 0-59 | Anthropometry eligibility |
|---|---|---|---|---|
| MICS6 | Defined by inclusion in the under-five child questionnaire and linked household roster | Defined by household-roster membership | Defined by the under-five questionnaire universe; exact `CAGE` is retained separately and may be missing | All sample-eligible children under the MICS protocol; Trinidad and Tobago is `NA` because its available child file has no anthropometry block |
| DHS KR/PR | `B5 == 1` | Positive `B16` linked to a PR member with `HV102 == 1`; children not listed in the sampled household are coded nonresident | `V008 - B3` between 0 and 59 months | Sample-eligible child with a populated anthropometry-block age (`HW1`), which distinguishes Namibia's anthropometry subsample from children outside that block |

For DHS, `HW1` is not used as the primary child age because it is absent for
children outside the anthropometry block. The survey-independent age measure
is interview century-month code (`V008`) minus birth century-month code
(`B3`). `HW1` is retained as `anthro_age_months`.

## Measurement and validity fields

- `weight_recorded`: a nonsentinel raw weight was recorded.
- `height_recorded`: a nonsentinel raw height or length was recorded.
- `anthro_measured`: both weight and height/length were recorded.
- `anthro_position_missing`: height/length was recorded but its position was
  not coded as lying or standing.
- `anthro_valid_haz`, `anthro_valid_waz`, `anthro_valid_whz`: the current
  cleaned outcome is nonmissing.
- `anthro_valid`: at least one of HAZ, WAZ, or WHZ is currently valid.

Raw measurements, source z-scores, source flags, and measurement position are
retained so the outcome-specific WHO quality rules can be revised in the next
step without returning to the raw files.

## Current sample flow

| Stage | Children |
|---|---:|
| Source-universe records | 57,903 |
| Primary sample eligible | 56,069 |
| At least one valid anthropometric outcome after WHO quality review | 47,707 |

The DHS source universes include deceased and nonresident children:

| Country | Source records | Living usual-resident age-eligible | Not living | Not usual resident | Eligibility unresolved |
|---|---:|---:|---:|---:|---:|
| Bolivia | 8,605 | 8,026 | 412 | 166 | 1 |
| Namibia | 5,046 | 3,791 | 228 | 1,025 | 2 |

The three unresolved DHS records have positive household line numbers but no
definitive linked residence status. They remain outside the primary dataset
with `sample_eligible = NA`; they are not silently treated as residents or
nonresidents.

Country-level details, including measurement and outcome-specific validity
counts, are written to
`harmonized_outcomes/anthro_sample_flow_country.csv`.
