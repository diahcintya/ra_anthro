# Covariate Audit

Status: Step 5 implementation review

## Household composition

Household composition now uses usual residents. This excludes 110 non-usual
members from 91 eligible-child households in Bolivia and 297 members from 199
households in Namibia. MICS household rosters are treated as household-member
universes.

Age-dependent household variables are `NA` if any usual resident has missing
age. Household size remains available because it does not require age.

## Under-five family variables

- `n_coresident_children_under5` counts other usual-resident children aged
  under five in the household.
- `n_biological_siblings_under5` counts other living biological siblings aged
  0-59 months in DHS birth histories, including siblings living elsewhere.
- MICS biological sibling counts are `NA` because the imported child and
  roster modules cannot identify nonresident biological siblings.
- Legacy `n_siblings_under5` now equals the biological measure and is therefore
  `NA` for MICS.

Eight DHS children have exact interview ages below 60 months but household
roster age equal to five years. `child_age_months` and
`child_roster_age_years` are both retained; the coresident count uses the
roster age so that household totals remain internally consistent.

## Cross-survey availability

Core child, household, household-composition, geographic, and weight variables
have observations in all 14 surveys. Source-specific gaps remain:

- Biological sibling and DHS birth-history variables: Bolivia and Namibia.
- Parent residence and father education: MICS surveys only.
- Stratum: unavailable for Suriname.
- Pension age, household eligibility, and running age: verified for Bolivia,
  Namibia, Lesotho, and Eswatini. The ten inherited `ra_su26` surveys remain
  pending their own historical audit.

Detailed child counts and item missingness are in
`harmonized_outcomes/covariate_availability.csv`. Unavailable fields are
reported as `N/A - unavailable in source`; unaudited inherited-country pension
fields are reported as `pending_historical_policy_audit`.
