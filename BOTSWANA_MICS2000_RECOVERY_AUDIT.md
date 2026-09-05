# Botswana MICS 2000 Recovery Audit

## Decision

The recovered MICS 2000 file is **provisional and not yet the canonical
Botswana regression source**. It is kept separate from the 14-country merge.

| Check | Result |
|---|---:|
| Source under-five rows | 3,004 |
| Unique child keys | 2,890 |
| Retained singleton keys | 2,784 |
| Exact duplicate rows | 0 |
| Conflicting duplicate keys | 106 |
| Rows quarantined | 220 |
| Retained children with a unique roster match | 2,052 |
| Living, usual-resident children aged 0-59 identifiable | 1,935 |
| Eligible children with valid WHO-2006 WAZ | 1,897 |
| Valid WHO-2006 HAZ / WHZ | 0 / 0 |

No duplicate-key group was exact across the source row. The child file has no
visit number, while duplicate records conflict on age, measurements, interview
date, and weight. Therefore no record within a conflict was selected.

## Anthropometry

The report confirms that the supplied `WAZ`, `HAZ`, and `WHZ` use the old
[NCHS reference](https://microdata.worldbank.org/index.php/catalog/4124/related-materials),
so they are retained only as `source_*_nchs`. WHO-2006 WAZ is reconstructed
from sex, completed age in months, and weight using CRAN `anthro` 1.1.0, the
[package recommended by WHO](https://www.who.int/toolkits/child-growth-standards/software).

Measurement position is not present. Under the approved rule, harmonized HAZ
and WHZ are therefore `NA`; raw height remains available. WAZ does not require
measurement position.

## Remaining limitations

- Only children whose roster member key is also unique can be classified as a
  usual resident. Other retained singletons remain in staging with
  `usual_resident = NA` and `sample_eligible = NA`.
- The child file has a block weight but no defensible explicit PSU or stratum
  variable. `WGHT`, `DISTRICT`, and source identifiers are retained; `psu` and
  `stratum` remain `NA`.
- Excluding conflicting records and children without a reliable roster link
  may affect national representativeness. BFHS 2007-08 should be evaluated as
  the preferred Botswana source in a new script, as planned.
