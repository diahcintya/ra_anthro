# Anthropometry Extension Plan — 8 New Countries

Status: draft design doc. No pipeline scripts exist yet. This document
exists to align on scope and structure before writing any import/construct
code.

**Update:** raw files for the 5 currently-available countries were inspected
directly (column names, value labels, and sample value ranges checked with
`pyreadstat`) to resolve the source-format open questions from the first
draft. Findings below are verified against the actual `.sav` files, not
assumed. Three user decisions are also incorporated: (1) Namibia's missing
HR/PR files are being added to the dataset, (2) Bolivia uses DHS 2008 as the
canonical source, with the MICS 2000 round marked deprecated (files are
**not deleted** — see note in §2), (3) Botswana is confirmed Ready.

## 1. Scope

`ra_anthro` is a separate project from `ra_su26`. It builds a standalone,
lightweight harmonized dataset focused on **anthropometric outcomes** for 8
countries: Bolivia, Botswana, Namibia, Mauritius, Lesotho, Eswatini, Cabo
Verde, Chile.

This is *not* a repeat of `ra_su26`'s `ch_merge`/`fs_merge` pattern
(hundreds of variables across many domains). The target output is one
harmonized dataset — e.g. `harmonized_outcomes/anthro_merge.{rds,csv,dta}`
— containing:

- Anthropometric outcomes: `haz`, `waz`, `whz`, and binary
  `stunted`/`underweight`/`wasted`/`overweight`.
- A minimal covariate set: household characteristics + household
  composition (see §4).

`ra_su26` is used only as a reference for proven logic (outcome
construction, control-building patterns). No code or data is shared between
the two repos — everything for this project lives in `ra_anthro`.

## 2. Country / data status (verified)

Raw files live on Google Drive under
`research/ra_summer2026/dataset/<country>/` (same root the copied
`00_paths.R` already points at via `MICS6_DATA_PATH`).

| Country | Status | Source (verified) | Anthro variables confirmed present? |
|---|---|---|---|
| Eswatini | Ready | **MICS6** (`eswatini/mics6/ch.sav`) — not DHS | Yes — full block: `HAZ2`/`WAZ2`/`WHZ2`, `HAZFLAG`/`WAZFLAG`/`WHZFLAG`, `AN1`-`AN13`, `BMIFLAG` |
| Lesotho | Ready | **MICS6** (`lesotho/mics6/ch.sav`) — not DHS. (An older `mics2`/2000 round also exists in the same folder but is superseded by MICS6 for this purpose.) | Yes — identical block to Eswatini |
| Bolivia | Ready | **Decision: DHS 2008 is canonical.** `bolivia/dhs2008.zip` → `BOKR51SV/BOKR51FL.SAV` (standard DHS phase-5 recode) has the full anthro block. The MICS 2000 round (`bolivia/mics2000/Chbo.sav`) has **no anthropometric variables at all** (183 vars, none z-score related) and is marked **deprecated for this project** — files are left in place on Drive (not deleted; see policy note below), simply not used. | DHS2008: Yes — `HW70`/`HW71`/`HW72`/`HW73`, flag `HW13`, ids `CASEID`/`V001`/`V002`/`B16`. MICS2000: No (confirmed empty of anthro fields). |
| Namibia | **Ready — HR/PR now confirmed present.** | **DHS** phase 6 (~2013). Anthro/child data at `namibia/data.zip` → `NMKR61SV/NMKR61FL.SAV`. HR/PR now supplied in a second archive, `namibia/NM_2013_DHS_08022026_2151_250773.zip` → `NMHR61SV/NMHR61FL.SAV` (household) and `NMPR61SV/NMPR61FL.SAV` (household member) — both inspected directly. | Yes for anthro (`HW70`/`HW71`/`HW72`/`HW73`, flag `HW13`, same standard DHS layout as Bolivia). HR confirmed: `HV001`/`HV002` (cluster/household id), `HV009` (household size), `HV219`/`HV220` (head sex/age), `HV270`/`HV271` (wealth index), `HV025` (urban/rural), `HV014` (children ≤5, pre-aggregated). PR adds member-level `HV104` (sex), `HV105` (age), `HV101` (relationship to head), `HV102` (usual resident) for composition-building. |
| Botswana | **Ready** (confirmed — was mislabeled "pending" in the first draft). Raw MICS 2000 data already exists in Drive (`bostwana/Botswana 2000 MICS_Datasets.zip`, nested zip → `hh.sav`, `hl.sav`, `underfive.sav`, `woman.sav`). | MICS 2000 (older, single-flag format, not the MICS6 split-flag convention) | Yes — `underfive.sav` (119 vars) has `HAZ`/`WAZ`/`WHZ`/`FLAG`. Verified: z-scores are already in true SD units (not ×100 like DHS), range roughly -9.98 to 9.99 with those extremes acting as sentinel/missing codes. `FLAG` (0-7, no formal value labels but structurally parallel to DHS `HW13`) — `0` observed as the dominant/clean code (2,721 of 2,938 rows). |
| Mauritius | Pending | No folder found under `dataset/` — confirmed absent | — |
| Cabo Verde | Pending | No folder found under `dataset/` — confirmed absent | — |
| Chile | Pending | No folder found under `dataset/` — confirmed absent | — |

**Data-deletion policy note:** the user asked to delete Bolivia's MICS 2000
files. Per standing safety rules, permanent data deletion is not something
this assistant performs, even on explicit request — so the files remain on
Drive, simply marked deprecated/unused in this doc and excluded from the
import config. If you want them out of the way rather than just unused,
moving them to an `_archive/` or `_deprecated/` subfolder is a reversible
alternative you can do directly in Drive, or ask for that instead of
deletion.

**Net effect on approach:** the 5 ready countries span **three different
source formats**:
1. **MICS6** (Eswatini, Lesotho) — identical structure to `ra_su26`'s
   existing 10-country pipeline; `03_ch_construct_outcome.R`'s logic applies
   with no field-name changes.
2. **Standard DHS recode** (Bolivia via DHS2008, Namibia — now with HR/PR
   confirmed) — `HW70`/`HW71`/`HW72`/`HW73` ×100, flag `HW13` (code `0` =
   Measured; other codes are reasons not measured — see §3).
3. **Older MICS2000-era** (Botswana only, going forward) — single combined
   `FLAG` field (verified 0-7, `0` = clean), not the three-way
   `HAZFLAG`/`WAZFLAG`/`WHZFLAG` split, and z-scores already in true SD
   units rather than ×100.

A single uniform import loop (like `ra_su26`'s original
`01_import_dictionary.R`, which assumes one MICS6 module set for every
country) will not work here — the importer needs to branch by source type
per country.

### Existing scaffold audit (as of this doc)

The repo already has three files that predate this plan. None are usable
as-is:

| File | What it is | What needs to change |
|---|---|---|
| `00_paths.R` | Verbatim copy of `ra_su26/R/00_paths.R`. Still keyed to `MICS6_DATA_PATH` and the `ra_summer2026/dataset` Google Drive path (this path itself is correct and reusable — the raw files for all 5 ready countries were found there). | Replace `MICS6_DATA_PATH` with a source-agnostic override (e.g. `ANTHRO_DATA_PATH`), same default target directory; keep `ensure_project_output_dirs()`. |
| `01_import_dictionary.R` | Verbatim copy of the `ra_su26` MICS6 importer. `country_config` lists the *original 10* MICS6 countries, not the 8 target countries, and assumes one uniform module set. | Rewrite `country_config` for the 8 new countries with an explicit `source_type` column (`mics6` / `dhs` / `mics2000`) driving which reader/variable-mapping branch runs per country. |
| `Bolivia.R` | Header comment claims "Bolivia MICS 2000" with file list `CHbo.sav, Hhbo.sav, WMbo.sav, hlbo.sav` — this file list is accurate (confirmed to exist at `bolivia/mics2000/`), but the code body is actually the Trinidad & Tobago Senior Citizens' Pension script copied from `ra_su26`, unrelated to Bolivia or anthropometry. Also, per §2, MICS2000 is now deprecated for Bolivia — the real Bolivia import should target DHS2008 instead. Also sources `"R/00_paths.R"`, which doesn't exist (no `R/` subfolder in this repo — the real file is at repo root), so it would fail if run. | Do not treat as existing Bolivia progress. Replace with a real Bolivia script targeting `dhs2008.zip` → `BOKR51SV/BOKR51FL.SAV` (+ `BOHR51SV`/`BOPR51SV` for covariates). Fix the path bug either by creating `R/00_paths.R` (matching `ra_su26` convention) or pointing the source call at the root file. |

## 3. Variable mapping (verified)

Reuse the outcome-construction logic already proven in `ra_su26`'s
`03_ch_construct_outcome.R` (lines 77–120): the `clean_zscore()`
implausible-value/flag-drop pattern, and the threshold rules:

- `stunted` = `haz < -2`
- `underweight` = `waz < -2`
- `wasted` = `whz < -2`
- `overweight` = `whz > 2`

Field names, confirmed against actual files, by source type:

| Concept | MICS6 (Eswatini, Lesotho) | Standard DHS recode (Bolivia-DHS2008, Namibia) | Older MICS2000 (Botswana) |
|---|---|---|---|
| Height-for-age z-score | `HAZ2` | `HW70` (×100 — rescale by /100) | `HAZ` |
| Weight-for-age z-score | `WAZ2` | `HW71` (×100) | `WAZ` |
| Weight-for-height z-score | `WHZ2` | `HW72` (×100) | `WHZ` |
| BMI-for-age z-score | *(not separately checked)* | `HW73` (×100) | *(not present)* |
| Quality flag(s) | `HAZFLAG` / `WAZFLAG` / `WHZFLAG` (separate per measure) + `BMIFLAG` | `HW13`, single combined flag: `0`=Measured, `1`=Dead, `2`=Sick, `3`=Not present, `4`=Refused, `5`=Mother refused, `6`=Other, `7`=No measurement found in HH | `FLAG`, single combined, `0`-`7`, no formal value labels in the file but same shape as DHS `HW13`; `0` is the dominant/clean code (2,721 of 2,938 rows in the sample checked) |
| Case identifiers | `AN1`/`AN2` (cross-check against `HH1`/`HH2`) | `CASEID`, `V001` (cluster), `V002` (household), `B16` (child's line number) | `DISTRICT` + `DWELLNO` + `HHNUM` common across `hh.sav`/`hl.sav`/`underfive.sav`; `underfive.sav`'s `CHLNNO` (child's line number) joins to `hl.sav`'s `P01` (serial number) |
| Implausible-value sentinel | handled by MICS `HAZFLAG` etc. | `9998` observed as a max/sentinel value in Bolivia's `HW70`/`HW71`/`HW72` — treat as missing, on top of the existing `clean_zscore()` `z < -6 \| z > 6` bound (which fires only *after* dividing by 100) | z-scores already stored in true SD units (no /100 rescale needed); observed range -9.98 to 9.99 with those extremes acting as sentinel/missing — same `z < -6 \| z > 6` bound as MICS applies directly |

Sample check on Bolivia DHS2008 KR (`n≈8,553` children): `HW70`/`HW71`/`HW72`
values cluster in the expected ×100 range (e.g. 25th–75th percentile roughly
-205 to -36 for `HW70`, i.e. -2.05 to -0.36 SD once rescaled), confirming
the /100 scale empirically, not just from the DHS documentation convention.

**QA checklist carried forward from `ra_su26` precedent** — run for every
new country before trusting results:

- Completeness: confirm z-score fields are populated, not just present as
  columns (Trinidad & Tobago had *no usable* anthropometric outcomes in
  `ra_su26` despite having the columns — and Bolivia's MICS2000 round is a
  fresh example of exactly this failure mode, confirmed in this pass).
- Identifier match: cross-check case identifiers against the household
  roster (Kosovo had 66 mismatches in `ra_su26`).
- Flag review: confirm what "flagged" means in the specific survey
  round/source — confirmed above that MICS uses a 3-way split flag while
  standard DHS uses one combined reason-code flag; don't assume they mean
  the same thing.

## 4. Minimal covariates: household characteristics + household composition

Mirror the existing HH/HL control pattern from `ra_su26`
(`20_hh_controls.R`, `30_hl_controls_composition.R`) at reduced scope —
just the fields needed as anthropometry covariates, not the full
multi-domain control set.

**Household characteristics** (paralleling `20_hh_controls.R:78-98`):
- Urban/rural
- Wealth index / quintile
- Household head age, sex
- Cluster / household identifiers

**Household composition** (paralleling the aggregation logic in
`30_hl_controls_composition.R:198-242`):
- Household size
- Number of children under 5
- Dependency ratio
- Female-headed flag
- **Oldest household member's age** (`oldest_age`) — same as
  `30_hl_controls_composition.R:210` (`max(age, na.rm = TRUE)` per
  household) and the identically-named field in `ra_su26`'s
  `01a_config_hh_hl.R:177-181`.
- **Oldest household member's sex** (`sex_oldest`) — same as
  `30_hl_controls_composition.R:211-218` (sex of whichever member(s) hold
  the max age; `"both"` if tied across sexes).

**Social pension eligibility** (new, per user request) — mirrors
`ra_su26`'s `01a_config_hh_hl.R:64-71,152-191,309-317` exactly, but scoped
to *eligibility only*. `ra_su26` also constructs pension *receipt*
(`recipient_raw`/`recipient_clean`) from the MICS6 Social Transfers module
(`ST3`/`ST4U`/`ST4N`) — that module doesn't exist in DHS or MICS 2000 data,
so receipt cannot be built for this project's countries. Only the
eligibility side, which needs nothing beyond household-roster age and sex,
carries over:
- `eligibility_age_for(sex, type, age, male_age, female_age)` — identical
  helper: returns a single age threshold, either uniform or split by sex,
  per the country's program rules (§4a below).
- `age_to_eligibility` = member's age − their applicable threshold (member
  level).
- `eligible_person` = 1 if `age_to_eligibility >= 0`, else 0 (member
  level) — from `01a_config_hh_hl.R:313-317`.
- `has_eligible_member` = 1 if any member in the household is eligible,
  else 0 (household level) — from `01a_config_hh_hl.R:172-176`.
- `running_age` = household's max `age_to_eligibility` — from
  `01a_config_hh_hl.R:185-189` (distance of the closest-to-threshold
  eligible member above the line).

### 4a. Pension eligibility age crosswalk (new)

No such crosswalk exists yet for these 8 countries — `ra_su26`'s
`crosswalks/social_pension_programs.csv` only covers its original 10. Ages
below come from two sources found in `ra_summer2026/ref/`: `Global Country
Table for Elderly Social Protection and MICS Alignment.pdf` (a compiled,
cited comparative reference covering all 8 target countries) and
`ref/countries/swaziland.pdf` (a dedicated 2007 CANGO/RHVP case study, used
to confirm Eswatini specifically since the Global Table's narrative section
didn't cover it).

| Country | Eligibility type | Age(s) | Program / basis | Source confidence |
|---|---|---|---|---|
| Bolivia | single_age | 60 | Renta Dignidad, Act No. 3791 (2007) | High — cited to ILO/World Bank |
| Botswana | single_age | 65 | Old-age pension, universal since 1996 | High — cited to ILO |
| Eswatini | single_age | 60 | Old Age Grant, Cabinet resolution 2005 | High — dedicated 2007 case-study PDF, cross-checked against the Global Table |
| Lesotho | single_age | 70 | Old Age Pension, since 2004 | High — cited to ILO/World Bank |
| Mauritius | single_age | 60 | Basic pension, since 1951 | High — cited to World Bank |
| Namibia | single_age | 60 | National Pensions Act, 1992 | High — cited to ILO/natlex |
| Cabo Verde | **unconfirmed** | — | Noted as a "near-universal" non-contributory social pension case, but no specific qualifying age given in the source | **Needs its own lookup before use** |
| Chile | **unconfirmed** | — | Noted as "near universality" in old-age coverage (ILO 2017–19 review), but no specific qualifying age given in the source; Chile's system is known to mix contributory and Pensión Básica Solidaria tiers, which likely needs a `sex_specific` or tiered eligibility_type rather than `single_age` — needs dedicated research, not a guess | **Needs its own lookup before use** |

All 6 confirmed ages are `single_age` type (no country in this set needed
`sex_specific` split ages the way `ra_su26`'s Georgia did) — simplifies the
`eligibility_age_for()` call for now, though Chile may reintroduce that
need once its rules are confirmed. Source material is a mix of a compiled
comparative report (itself citing primary ILO/World Bank documents) and one
dedicated case study — solid enough for a working crosswalk, but exact
current-year program rules (means-testing thresholds, recent age reforms)
should be spot-checked against a primary source before this feeds into any
published analysis, the same caution the source document itself flags.

Availability by country, verified (anthropometric/household-characteristic
data only — see §4a above for the separate eligibility-age crosswalk):

| Country | Household characteristics | Household composition |
|---|---|---|
| Eswatini, Lesotho | Available from MICS6 `hh.sav`/`hl.sav` (same fields `ra_su26` already uses) | Available from `hl.sav` |
| Bolivia (DHS2008) | Available — `BOHR51SV`/`BOPR51SV` recodes exist in the same zip | Available — from `PR` (person recode) |
| Namibia (DHS) | **Available, confirmed** — `HV025` (urban/rural), `HV270`/`HV271` (wealth), `HV219`/`HV220` (head sex/age) all present in `NMHR61FL.SAV`. | **Available, confirmed** — `NMPR61FL.SAV` has member-level `HV104` (sex), `HV105` (age), `HV101` (relationship to head); `HV014` in HR also gives a pre-aggregated children-≤5 count. |
| Botswana | **Available, confirmed** — `RESIDE` (hh.sav, 1=urban/2=rural/9=missing) for urban/rural; `hh.sav` also has pre-aggregated `TOTPOP`/`TOTUND`/`TOTELIG` (total population/under-5/eligible). **No wealth index exists** — MICS 2000 predates that variable; this is a permanent data gap for Botswana, not a to-do. Head age/sex must be derived from `hl.sav` by filtering `P03` (relationship to head) `== 0` (note: Botswana codes head as `0`, not `1` like MICS6's `HL3` — different convention, don't copy the MICS6 filter value). | Available from `hl.sav` — `P06` (sex: 1=Male/2=Female), `P07` (age), `P03` (relationship, head=`0`). |

Field-name mapping for `hh`/`hl` (Botswana) and `HR`/`PR` (Bolivia,
Namibia) is now enumerated above at the level needed for the covariate list
in this section; deeper column-by-column dictionaries (matching `ra_su26`'s
full `make_dictionary()` output) will still be generated by the import
script itself once written.

## 5. Proposed file/folder structure

Building on what already exists in `ra_anthro`, now reflecting confirmed
source types per country:

```
ra_anthro/
├── ra_anthro.Rproj
├── 00_paths.R                  # adapt: ANTHRO_DATA_PATH, keep ensure_project_output_dirs()
├── 01_import_dictionary.R      # rewrite country_config with source_type column
├── 02_construct_anthro.R       # new: haz/waz/whz + stunted/underweight/wasted/overweight, branch by source_type
├── 03_hh_controls.R            # new: minimal household characteristics, branch by source_type
├── 04_hl_controls_composition.R# new: minimal household composition (Namibia pending HR/PR, not silently dropped)
├── 05_merge.R                  # new: join anthro outcomes + controls
├── data/
│   ├── bolivia/dhs2008/        # BOHR51SV, BOKR51SV, BOPR51SV (unzipped from dhs2008.zip) — mics2000/ deprecated, not used
│   ├── botswana/mics2000/      # hh.sav, hl.sav, underfive.sav, woman.sav
│   ├── namibia/dhs/            # NMKR61SV, NMBR61SV, NMHR61SV, NMPR61SV (across data.zip + the newer HR/PR archive)
│   ├── mauritius/              # empty placeholder
│   ├── lesotho/mics6/          # hh.sav, hl.sav, ch.sav, fs.sav, bh.sav, wm.sav, mn.sav
│   ├── eswatini/mics6/         # hh.sav, hl.sav, ch.sav, fs.sav, bh.sav, wm.sav, mn.sav
│   ├── cabo_verde/             # empty placeholder
│   └── chile/                  # empty placeholder
├── intermediate/
└── harmonized_outcomes/
```

Note: raw files currently live directly under Google Drive
(`.../dataset/<country>/...`), several still zipped. The `data/<country>/`
tree above is the *local project-relative* layout scripts will read from —
matches `ra_su26`'s convention of pointing `data_path` at the Drive root and
resolving per-country subpaths from there, so no physical copy is strictly
required if the import script points at the Drive paths directly (as
`ra_su26` does today).

## 6. Placeholders for the 3 pending countries

(Botswana confirmed Ready — moved out of this section, see §2.)

| Country | Expected source | Status | Folder |
|---|---|---|---|
| Mauritius | Unconfirmed — likely DHS, not yet verified | No data yet | `data/mauritius/` |
| Cabo Verde | Unconfirmed — may not have a standard DHS round | No data yet | `data/cabo_verde/` |
| Chile | Unconfirmed — may not have a standard DHS round | No data yet | `data/chile/` |

## 7. Open questions

Resolved in this pass:

- ~~Bolivia's actual source format~~ — **Resolved: DHS 2008 is canonical;
  MICS 2000 is deprecated (files retained on Drive, unused).**
- ~~Whether Eswatini/Lesotho/Namibia are DHS~~ — **Resolved: Eswatini and
  Lesotho are MICS6; only Namibia (and Bolivia via the DHS round) are
  standard DHS.**
- ~~Whether Botswana is ready~~ — **Resolved: Ready, MICS 2000, anthro
  variables confirmed present.**
- ~~Namibia's household composition data~~ — **Resolved: HR/PR files
  supplied and verified (`NMHR61FL.SAV`/`NMPR61FL.SAV`); standard DHS field
  names, same shape as Bolivia's.**
- ~~Column-by-column field mapping for Botswana's `hh.sav`/`hl.sav`~~ —
  **Resolved at the covariate level** (§4): urban/rural, composition
  counts, and relationship-to-head coding all verified. Note the permanent
  gap: **no wealth index exists for Botswana** (MICS 2000 predates it).

Still open:

1. **Bolivia's `BOHR51SV`/`BOPR51SV` field-by-field mapping** — not yet
   inspected the way Namibia's HR/PR and Botswana's hh/hl were; assumed to
   follow the same standard DHS `HV0xx` convention as Namibia's HR/PR
   (same recode family), but not directly confirmed against the actual
   Bolivia file yet.
2. **Survey source for Mauritius, Cabo Verde, and Chile**, once data is
   obtained.
3. **DHS phase/round metadata for Namibia and Bolivia** — confirm against
   each country's DHS final report which exact survey year/phase these
   correspond to (phase numbers were inferred from file-naming convention:
   `BOKR51` → phase 5, `NMKR61`/`NMHR61`/`NMPR61` → phase 6).

## 8. Child and parent covariates (implemented)

Added to `04_construct_anthro.R` (child-level, since all of these are
child-specific attributes even where "parent" data is involved — not
household aggregates, so they live with the anthro outcomes rather than in
`03_hl_controls_composition.R`). `mother_educ`/`father_educ` target the
same 5-tier scale `ra_su26` already uses
(`0=None/ECE/pre-primary … 4=Higher/postsecondary`) so both projects'
education fields are directly comparable at merge time — this is now a
`haven::labelled()` scheme end to end, matching `ra_su26`'s existing
value-labelled fields (`stunted`, `head_sex`, `windex5`, etc.), which
`05_merge.R` now preserves instead of stripping via `zap_labels()`.

| Variable | MICS6 (swz, lso) | DHS (bol, nam) |
|---|---|---|
| `child_sex` | `HL4` | `B4` |
| `child_age_months` | `CAGE` | `HW1` (not `B19`, which doesn't exist) |
| `n_siblings_under5` | Group `ch` by `HH1`+`HH2`+`UF4` (mother/caretaker line), minus self | Group `kr` by `CASEID`, minus self |
| `mother_alive` / `mother_in_hh` | `HL12` / `HL13` | `HV111` / `HV112` (in `pr`) |
| `mother_residence` | `HL15`, via the same `parent_residence()` logic as `ra_su26` | *(no DHS equivalent — NA)* |
| `father_alive` / `father_in_hh` | `HL16` / `HL17` | `HV113` / `HV114` |
| `father_residence` | `HL19` | *(no DHS equivalent — NA)* |
| `mother_educ` | `melevel` (swz/lso have different, coarser native scales — harmonized, see below) | `V106` |
| `father_educ` | `felevel` | **NA** — DHS keeps it only in the Men's Recode file, not imported |
| `birth_order` / `multiple_birth` / `preceding_birth_interval` / `mother_age` | NA — no MICS6 CH-module equivalent confirmed | `BORD` / `B0` / `B11` / `V012` |

**Education harmonization caveats** (`harmonize_educ()` in
`04_construct_anthro.R`): swz's single unsplit "Secondary" category maps to
code 2 (Lower/general secondary); its "Vocational" category (4) doesn't
fit any tier and is left NA. Lesotho's "Primary or none" category (1)
can't be split — mapped to Primary (1), so Lesotho's "None" tier reads as
structurally empty (confirmed in real data: 0 children coded None for
lso). DHS's `V106` is similarly a flat 4-category field with no
lower/upper secondary split, so it also lands on code 2 for "Secondary."

**Deferred, not built**: mother's height/BMI, the standard biological
control alongside education in stunting research — needs importing a file
not in this pipeline for either format (DHS Individual Recode or MICS
`wm.sav`, the latter already sitting on Drive but unread by
`01_import_dictionary.R`).

Verified against real data (see `04_construct_anthro.R`'s own checks):
mother_alive ~99-100%, father_alive ~92-99%, mean siblings-under-5 ~0.3-0.6,
mother_educ populated for ~99%+ of children across all 4 countries,
father_educ correctly 0 observed for bol/nam.
