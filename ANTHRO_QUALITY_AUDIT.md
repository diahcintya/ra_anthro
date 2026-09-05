# Anthropometry Quality Rules

Status: Step 4 implementation review

## WHO 2006 limits

Quality filtering is outcome-specific:

| Outcome | Valid range |
|---|---:|
| HAZ | -6 to +6 |
| WAZ | -6 to +5 |
| WHZ | -5 to +5 |

Values at the limits are retained. Values beyond them are coded missing with
reason `who_biologically_implausible`. These rules follow the
[WHO Anthro Survey Analyser guidance](https://www.who.int/docs/default-source/child-growth/child-growth-standards/anthro-survey-analyser-quickguide.pdf).

## Measurement position

Lying and standing position codes are retained from `AN12` in MICS and
`HW15` in DHS. If height/length or a source HAZ/WHZ is present but position is
missing:

- HAZ is missing.
- WHZ is missing.
- WAZ remains eligible for use.
- The reason is `measurement_position_missing`.

No position is inferred from age. WHO normally adjusts by 0.7 cm when the
observed position differs from the age-standard position; see the
[WHO child-growth measurement guidance](https://iris.who.int/bitstream/handle/10665/43601/9789241595070_B_eng.pdf?sequence=2).
The source-provided WHO z-scores are retained when position is known; this
step does not recalculate them.

## Missingness fields

The harmonized data retain:

- Raw weight and height/length
- Measurement position
- Original source z-scores and flags
- `weight_missing_reason` and `height_missing_reason`
- `haz_missing_reason`, `waz_missing_reason`, and `whz_missing_reason`

Reasons distinguish structural unavailability, anthropometry ineligibility,
absence, refusal, other measurement failure, missing source z-score, source
flagging, missing position, and WHO implausibility.

## Current eligible-child results

| Outcome | Valid children |
|---|---:|
| HAZ | 46,500 |
| WAZ | 47,470 |
| WHZ | 46,331 |
| At least one valid outcome | 47,707 |

There are 193 eligible records with missing measurement position affecting
HAZ and WHZ. Trinidad and Tobago remains structurally unavailable for all
three anthropometric outcomes.
