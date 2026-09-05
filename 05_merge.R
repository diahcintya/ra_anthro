# Merge anthro outcomes + controls, combine with ra_su26's 10 countries --------
#
# Goal:
#   Join this project's anthro outcomes with its household controls, then
#   stack that with ra_su26's existing 10-country ch_merge to produce one
#   combined anthropometry dataset across all 14 countries.
#
# Both sides use matching haven::labelled() value-label schemes (head_sex,
# stunted/underweight/wasted/overweight, windex5, female_headed,
# has_eligible_member, mother/father alive/in_hh, mother_educ/father_educ)
# so labels are preserved through the merge, not stripped.
#
# Inputs:
#   - intermediate/anthro_outcomes.rds
#   - intermediate/hh_controls.rds
#   - intermediate/hl_controls_composition.rds
#   - ../ra_su26/harmonized_outcomes/social_pension_ch_merged.rds
#   - ../ra_su26/intermediate/mics6_setup.rds (survey-design recovery)
#
# Outputs:
#   - harmonized_outcomes/anthro_merge.rds
#   - harmonized_outcomes/anthro_merge.csv
#   - harmonized_outcomes/anthro_merge_summary_country.csv

# Load library -------------------------------------------------------------
packages <- c("tidyverse", "haven")
invisible(lapply(packages, library, character.only = TRUE))

# Setup ----------------------------------------------------------------------
source("00_paths.R")
source("R/anthro_quality.R")
source("R/household_composition.R")

znum <- function(x) as.numeric(zap_labels(x))

zvar <- function(data, variable) {
  if (variable %in% names(data)) znum(data[[variable]]) else rep(NA_real_, nrow(data))
}

valid_weight <- function(x) {
  if_else(is.finite(x) & x > 0, x, NA_real_)
}

normalize_weight <- function(x) {
  positive_mean <- mean(x[is.finite(x) & x > 0], na.rm = TRUE)
  if (!is.finite(positive_mean)) return(rep(NA_real_, length(x)))
  x / positive_mean
}

label_text <- function(x) {
  if (inherits(x, c("haven_labelled", "labelled"))) {
    as.character(haven::as_factor(x, levels = "labels"))
  } else {
    as.character(x)
  }
}

shared_cols <- c(
  "country_code", "survey_id", "survey_name", "survey_year",
  "survey_year_source", "source_type", "source_file",
  "hh_id", "child_id", "source_child_id",
  "living_child", "usual_resident", "age_eligible", "sample_eligible",
  "anthro_eligible", "eligibility_basis", "living_source_var",
  "residence_source_var", "age_eligibility_source_var",
  "survey_weight_raw", "survey_weight", "survey_weight_normalized",
  "psu", "stratum", "region_code", "region_name",
  "weight_source_var", "psu_source_var", "stratum_source_var",
  "source_weight_kg", "source_height_cm", "source_measurement_position",
  "source_haz", "source_waz", "source_whz",
  "source_haz_flag", "source_waz_flag", "source_whz_flag",
  "source_anthro_result", "anthro_age_months",
  "weight_recorded", "height_recorded", "anthro_measured",
  "weight_missing_reason", "height_missing_reason",
  "anthro_position_missing", "anthro_valid_haz", "anthro_valid_waz",
  "anthro_valid_whz", "anthro_valid",
  "haz_missing_reason", "waz_missing_reason", "whz_missing_reason",
  "haz", "waz", "whz", "stunted", "underweight", "wasted", "overweight",
  "urban_rural", "windex5", "head_age", "head_sex",
  "n_member", "n_age_missing", "n_children_under5", "n_working_age",
  "oldest_age", "sex_oldest", "dependency_ratio", "female_headed",
  "program_name", "eligibility_type", "eligibility_age", "male_age", "female_age",
  "running_age", "has_eligible_member", "pension_policy_status",
  "child_sex", "child_age_months", "child_roster_age_years", "n_siblings_under5",
  "n_biological_siblings_under5", "n_coresident_children_under5",
  "mother_alive", "mother_in_hh", "mother_residence",
  "father_alive", "father_in_hh", "father_residence",
  "mother_educ", "father_educ",
  "birth_order", "multiple_birth", "preceding_birth_interval", "mother_age"
)

# This project's 4 countries --------------------------------------------------

anthro_outcomes <- readRDS(file.path(intermediate_path, "anthro_outcomes.rds"))
hh_controls <- readRDS(file.path(intermediate_path, "hh_controls.rds"))
hl_controls_composition <- readRDS(file.path(intermediate_path, "hl_controls_composition.rds"))

anthro_merge_new <- anthro_outcomes %>%
  left_join(hh_controls, by = c("country_code", "hh_id")) %>%
  left_join(hl_controls_composition, by = c("country_code", "hh_id")) %>%
  mutate(
    n_coresident_children_under5 = pmax(
      n_children_under5 - as.numeric(child_roster_age_years < 5),
      0
    ),
    source = "ra_anthro"
  ) %>%
  select(all_of(shared_cols), source)

# ra_su26's 10 countries -------------------------------------------------------
# ra_su26 already has most of these fields under matching names/labels
# (mother_alive, mother_educ, etc.); "sex"/"age_months" are renamed to this
# project's child_sex/child_age_months. Fields ra_su26 doesn't have
# (n_siblings_under5 and the DHS-only birth-history variables) are NA.

ch_su26 <- readRDS("../ra_su26/harmonized_outcomes/social_pension_ch_merged.rds")
mics6_setup_su26 <- readRDS("../ra_su26/intermediate/mics6_setup.rds")

mics6_composition_su26 <- imap_dfr(mics6_setup_su26$hl_list, function(hl, country_code) {
  hl %>%
    transmute(
      country_code,
      hh_id = paste(country_code, znum(HH1), znum(HH2), sep = "_"),
      age = if_else(between(znum(HL6), 0, 98), znum(HL6), NA_real_),
      sex = if_else(znum(HL4) %in% 1:2, znum(HL4), NA_real_),
      is_head = znum(HL3) == 1,
      usual_resident = 1
    )
}) %>%
  construct_household_composition() %>%
  rename_with(~ paste0("cov_", .x), -c(country_code, hh_id))

# The final ra_su26 child file retained weights and cluster numbers but omitted
# the explicit PSU and stratum fields. Recover them from the corresponding raw
# child modules so downstream survey estimators have the fullest available
# design information. Suriname has neither field in its child module, so HH1 is
# retained as its cluster identifier and stratum remains explicitly unavailable.
mics6_design_su26 <- imap_dfr(mics6_setup_su26$ch_list, function(ch, country_code) {
  psu_var <- intersect(c("psu", "PSU"), names(ch))
  stratum_var <- intersect("stratum", names(ch))

  psu_var <- if (length(psu_var) == 0) "HH1" else psu_var[[1]]
  stratum_var <- if (length(stratum_var) == 0) NA_character_ else stratum_var[[1]]

  ch %>%
    transmute(
      country_code,
      design_HH1 = znum(HH1),
      design_HH2 = znum(HH2),
      design_LN = znum(LN),
      design_psu = znum(.data[[psu_var]]),
      design_stratum = if (is.na(stratum_var)) NA_real_ else znum(.data[[stratum_var]]),
      design_psu_source_var = psu_var,
      design_stratum_source_var = stratum_var,
      source_weight_kg = zvar(ch, "AN8"),
      source_height_cm = zvar(ch, "AN11"),
      source_measurement_position = zvar(ch, "AN12"),
      source_haz = zvar(ch, "HAZ2"),
      source_waz = zvar(ch, "WAZ2"),
      source_whz = zvar(ch, "WHZ2"),
      source_haz_flag = zvar(ch, "HAZFLAG"),
      source_waz_flag = zvar(ch, "WAZFLAG"),
      source_whz_flag = zvar(ch, "WHZFLAG"),
      anthro_age_months = zvar(ch, "CAGE")
    )
})

stopifnot(!anyDuplicated(mics6_design_su26[c("country_code", "design_HH1", "design_HH2", "design_LN")]))

anthro_merge_su26 <- ch_su26 %>%
  mutate(
    design_HH1 = znum(HH1),
    design_HH2 = znum(HH2),
    design_LN = znum(LN),
    hh_id = paste(country_code, znum(HH1), znum(HH2), sep = "_")
  ) %>%
  left_join(
    mics6_design_su26,
    by = c("country_code", "design_HH1", "design_HH2", "design_LN")
  ) %>%
  left_join(mics6_composition_su26, by = c("country_code", "hh_id")) %>%
  mutate(
    survey_id = case_when(
      country_code == "fji" ~ "fji_mics_2021",
      country_code == "geo" ~ "geo_mics_2018",
      country_code == "guy" ~ "guy_mics_2019_2020",
      country_code == "kir" ~ "kir_mics_2018_2019",
      country_code == "kos" ~ "kos_mics_2019_2020",
      country_code == "nep" ~ "nep_mics_2019",
      country_code == "soa" ~ "soa_mics_2019_2020",
      country_code == "sur" ~ "sur_mics_2018",
      country_code == "thai" ~ "thai_mics_2022",
      country_code == "tto" ~ "tto_mics_2022"
    ),
    survey_name = case_when(
      country_code == "fji" ~ "Fiji Multiple Indicator Cluster Survey 2021",
      country_code == "geo" ~ "Georgia Multiple Indicator Cluster Survey 2018",
      country_code == "guy" ~ "Guyana Multiple Indicator Cluster Survey 2019-2020",
      country_code == "kir" ~ "Kiribati Multiple Indicator Cluster Survey 2018-2019",
      country_code == "kos" ~ "Kosovo Multiple Indicator Cluster Survey 2019-2020",
      country_code == "nep" ~ "Nepal Multiple Indicator Cluster Survey 2019",
      country_code == "soa" ~ "Samoa Multiple Indicator Cluster Survey 2019-2020",
      country_code == "sur" ~ "Suriname Multiple Indicator Cluster Survey 2018",
      country_code == "thai" ~ "Thailand Multiple Indicator Cluster Survey 2022",
      country_code == "tto" ~ "Trinidad and Tobago Multiple Indicator Cluster Survey 2022"
    ),
    survey_year_source = znum(UF7Y),
    survey_year = case_when(
      country_code == "nep" ~ 2019L,
      country_code == "thai" ~ 2022L,
      country_code == "geo" ~ 2018L,
      TRUE ~ as.integer(survey_year_source)
    ),
    source_type = "mics6",
    source_file = case_when(
      country_code == "fji" ~ "fiji/mics6/ch.sav",
      country_code == "geo" ~ "georgia/mics6/ch.sav",
      country_code == "guy" ~ "guyana/mics6/ch.sav",
      country_code == "kir" ~ "kiribati/mics6/ch.sav",
      country_code == "kos" ~ "kosovo/mics6/ch.sav",
      country_code == "nep" ~ "nepal/mics6/ch.sav",
      country_code == "soa" ~ "samoa/mics6/ch.sav",
      country_code == "sur" ~ "suriname/mics6/ch.sav",
      country_code == "thai" ~ "thailand/mics6/ch.sav",
      country_code == "tto" ~ "trinidad/mics6/ch.sav"
    ),
    hh_id = paste(country_code, HH1, HH2, sep = "_"),
    source_child_id = paste(znum(HH1), znum(HH2), znum(LN), sep = "_"),
    child_id = paste(survey_id, source_child_id, sep = "_"),
    living_child = 1,
    usual_resident = 1,
    age_eligible = 1,
    sample_eligible = 1,
    anthro_eligible = if_else(country_code == "tto", NA_real_, 1),
    eligibility_basis = "MICS under-five questionnaire and household roster",
    living_source_var = "under-five questionnaire universe",
    residence_source_var = "household roster membership",
    age_eligibility_source_var = "under-five questionnaire universe",
    survey_weight_raw = znum(chweight),
    survey_weight = valid_weight(survey_weight_raw),
    psu = design_psu,
    stratum = design_stratum,
    region_code = znum(HH7),
    region_name = label_text(HH7),
    weight_source_var = "chweight",
    psu_source_var = design_psu_source_var,
    stratum_source_var = design_stratum_source_var,
    source_anthro_result = NA_real_,
    weight_recorded = as.numeric(is.finite(source_weight_kg) & between(source_weight_kg, 0.5, 50)),
    height_recorded = as.numeric(is.finite(source_height_cm) & between(source_height_cm, 30, 150)),
    anthro_measured = as.numeric(weight_recorded == 1 & height_recorded == 1),
    anthro_position_missing = as.numeric(height_recorded == 1 & !source_measurement_position %in% c(1, 2)),
    anthro_valid_haz = as.numeric(!is.na(haz)),
    anthro_valid_waz = as.numeric(!is.na(waz)),
    anthro_valid_whz = as.numeric(!is.na(whz)),
    anthro_valid = as.numeric(anthro_valid_haz == 1 | anthro_valid_waz == 1 | anthro_valid_whz == 1),
    child_sex = sex,
    child_age_months = age_months,
    child_roster_age_years = znum(HL6),
    n_member = cov_n_member,
    n_age_missing = cov_n_age_missing,
    n_children_under5 = cov_n_children_under5,
    n_working_age = cov_n_working_age,
    dependency_ratio = cov_dependency_ratio,
    oldest_age = cov_oldest_age,
    sex_oldest = cov_sex_oldest,
    head_age = cov_head_age,
    head_sex = cov_head_sex,
    female_headed = cov_female_headed,
    n_biological_siblings_under5 = NA_real_,
    n_siblings_under5 = n_biological_siblings_under5,
    n_coresident_children_under5 = pmax(
      n_children_under5 - as.numeric(child_roster_age_years < 5),
      0
    ),
    eligibility_type = NA_character_,
    eligibility_age = NA_real_,
    program_name = NA_character_,
    male_age = NA_real_,
    female_age = NA_real_,
    running_age = NA_real_,
    has_eligible_member = labelled(NA_real_, c(No = 0, Yes = 1)),
    pension_policy_status = "pending_historical_audit",
    birth_order = NA_real_,
    multiple_birth = labelled(NA_real_, c(No = 0, Yes = 1)),
    preceding_birth_interval = NA_real_,
    mother_age = NA_real_,
    source = "ra_su26"
  ) %>%
  apply_anthro_quality() %>%
  group_by(country_code, survey_id) %>%
  mutate(survey_weight_normalized = normalize_weight(survey_weight)) %>%
  ungroup() %>%
  select(all_of(shared_cols), source)

# Combine ------------------------------------------------------------------
anthro_merge <- bind_rows(anthro_merge_new, anthro_merge_su26) %>%
  apply_anthro_quality()

# Validate -----------------------------------------------------------------
stopifnot(
  n_distinct(anthro_merge$country_code) == 14,
  !anyDuplicated(anthro_merge$child_id),
  all(!is.na(anthro_merge$survey_id)),
  all(!is.na(anthro_merge$source_child_id)),
  all(anthro_merge$living_child %in% c(0, 1, NA)),
  all(anthro_merge$usual_resident %in% c(0, 1, NA)),
  all(anthro_merge$age_eligible %in% c(0, 1, NA)),
  all(anthro_merge$sample_eligible %in% c(0, 1, NA)),
  all(anthro_merge$anthro_eligible %in% c(0, 1, NA)),
  all(anthro_merge$anthro_measured %in% c(0, 1, NA)),
  all(anthro_merge$anthro_valid %in% c(0, 1, NA)),
  all(anthro_merge$survey_weight > 0 | is.na(anthro_merge$survey_weight)),
  all(zap_labels(anthro_merge$head_sex) %in% c(0, 1, NA)),
  all(anthro_merge$sex_oldest %in% c("men", "women", "both", NA)),
  all(anthro_merge$child_sex %in% c("men", "women", NA))
)

# Summarize + save --------------------------------------------------------

anthro_merge_summary_country <- anthro_merge %>%
  group_by(source, country_code) %>%
  summarise(
    n_children = n(),
    n_haz_observed = sum(!is.na(haz)),
    stunted_pct = mean(zap_labels(stunted), na.rm = TRUE) * 100,
    wasted_pct = mean(zap_labels(wasted), na.rm = TRUE) * 100,
    underweight_pct = mean(zap_labels(underweight), na.rm = TRUE) * 100,
    overweight_pct = mean(zap_labels(overweight), na.rm = TRUE) * 100,
    .groups = "drop"
  )

ensure_project_output_dirs(harmonized_path)

saveRDS(anthro_merge, file.path(harmonized_path, "anthro_merge.rds"))
write_csv(anthro_merge, file.path(harmonized_path, "anthro_merge.csv"), na = "")
write_csv(anthro_merge_summary_country, file.path(harmonized_path, "anthro_merge_summary_country.csv"), na = "")
