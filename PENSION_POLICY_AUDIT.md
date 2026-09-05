# Pension Policy Audit

## Result

The survey-year age thresholds are verified for the five `ra_anthro`
sources. They are stored in `crosswalks/pension_policy_audit.csv` and only
rows marked `verified_survey_year` enter the construction.

| Survey | Program | Age | Evidence for the survey year |
|---|---|---:|---|
| Bolivia DHS 2008 | Renta Dignidad | 60 | [Law 3791](https://www.lexivox.org/norms/BO-L-3791.html) sets age 60 and effectiveness from 1 January 2008; [DS 29400](https://www.lexivox.org/norms/BO-DS-29400.html) regulates payment. |
| Namibia DHS 2013 | Basic State Pension | 60 | [National Pensions Act 10 of 1992](https://www.npc.gov.na/wp-content/uploads/2022/06/National-Pension-Act-10-of-1992.pdf), corroborated by the [government Old Age Grant page](https://mgecw.gov.na/old-age-grants-). |
| Lesotho MICS 2018 | Old Age Pension | 70 | The [2019/20 Budget Speech](https://www.gov.ls/wp-content/uploads/2019/03/Budget-2019-Lesotho-Final.pdf) says the age was 70 and a reduction was planned only from FY2020/21. |
| Eswatini MICS 2021-22 | Old Age Grant | 60 | The [2019/20-2021/22 National Development Plan](https://www.gov.sz/images/CabinetMinisters/NDP-2019-20-to-2021-22-final.pdf) describes a universal grant for people aged 60+. |
| Botswana MICS 2000 | Old Age Pension | 65 | The [Government of Botswana service page](https://www.gov.bw/allowances/old-age-pension-allowance) gives age 65; an official [DailyNews record](https://dailynews.gov.bw/news-detail/76281) states that the universal program began in 1996. |

## Construction

For each usual-resident household member:

`age_to_eligibility = age - survey-year eligibility age`

The household fields are:

- `has_eligible_member = 1` when at least one observed member is at or above
  the threshold; `0` when observed members are all below; `NA` when none can
  be assessed.
- `running_age` is the maximum member-level `age_to_eligibility`. Zero is the
  age cutoff used in a regression-discontinuity design.

These are **age-based program-eligibility proxies**, not verified receipt or
full administrative eligibility. Citizenship, residence duration, other-grant
rules, and registration are not consistently observed. Household roster ages
are recorded in completed years, so `running_age` is discrete and heaped.

The four countries already in the main merge receive audited values. Botswana
receives the policy metadata in its recovery file, but household eligibility
and running age remain `NA` because its member roster is unreliable. The ten
inherited `ra_su26` countries remain `pending_historical_audit`.
