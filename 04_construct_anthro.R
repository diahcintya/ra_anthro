# Anthropometric outcomes + child/parent covariates ------------------------------
#
# Goal:
#   Build harmonized anthropometric z-scores and outcome indicators, plus
#   child-level covariates (sex, age, siblings under 5, parent alive/
#   in-household/residence/education), across MICS6 and DHS sources.
#
# mother_educ/father_educ target the same 5-tier scale ra_su26 already uses
# (0=None/ECE/pre-primary ... 4=Higher/postsecondary) so both projects'
# education fields are directly comparable at merge time. swz/lso only have
# a single unsplit "Secondary" category (mapped to 2); Lesotho's "Primary
# or none" category can't be split (mapped to 1, Primary); swz's vocational
# category doesn't fit any tier cleanly and is left NA.
#
# Note: father_educ is NA for Bolivia/Namibia -- DHS keeps it only in the
# separate Men's Recode file, not imported in this project. Likewise
# mother_residence/father_residence (needs a residence-elsewhere field that
# only MICS6 has) and birth_order/multiple_birth/preceding_birth_interval/
# mother_age (DHS birth-history fields with no MICS6 CH-module equivalent
# confirmed) are source-asymmetric -- see ANTHRO_EXTENSION_PLAN.md.
#
# Note: Botswana's underfive.sav has the same visit-log corruption found in
# its other MICS 2000 files (101 of 106 duplicated child records disagree
# on age, 102 on HAZ) -- excluded, same as ra_su26 excluded Trinidad &
# Tobago for having no usable anthropometric outcomes.
#
# Inputs:
#   - intermediate/anthro_setup.rds
#
# Outputs:
#   - intermediate/anthro_outcomes.rds

# Load library -------------------------------------------------------------
packages <- c("tidyverse", "haven")
invisible(lapply(packages, library, character.only = TRUE))

# Setup ----------------------------------------------------------------------
source("00_paths.R")
source("R/anthro_quality.R")
anthro_setup <- readRDS(file.path(intermediate_path, "anthro_setup.rds"))
raw <- anthro_setup$anthro_raw
country_config <- anthro_setup$country_config

# Helper functions -------------------------------------------------------------

znum <- function(x) as.numeric(zap_labels(x))

clean_range <- function(x, lower, upper) {
  if_else(is.finite(x) & between(x, lower, upper), x, NA_real_)
}

clean_zscore <- function(z, flag) {
  z <- ifelse(z < -6 | z > 6, NA_real_, z)
  ifelse(is.na(flag) | flag == 0, z, NA_real_)
}

valid_weight <- function(x) {
  if_else(is.finite(x) & x > 0, x, NA_real_)
}

normalize_weight <- function(x) {
  positive_mean <- mean(x[is.finite(x) & x > 0], na.rm = TRUE)
  if (!is.finite(positive_mean)) return(rep(NA_real_, length(x)))
  x / positive_mean
}

combine_eligibility <- function(...) {
  values <- do.call(cbind, lapply(list(...), as.numeric))
  ifelse(
    rowSums(values == 0, na.rm = TRUE) > 0,
    0,
    ifelse(rowSums(is.na(values)) > 0, NA_real_, 1)
  )
}

label_text <- function(x) {
  if (inherits(x, c("haven_labelled", "labelled"))) {
    as.character(haven::as_factor(x, levels = "labels"))
  } else {
    as.character(x)
  }
}

country_meta <- function(country_code) {
  out <- country_config %>% filter(.data$country_code == .env$country_code)
  stopifnot(nrow(out) == 1)
  out
}

# 1/2-coded "Yes/No" fields (e.g. MICS6's HL12/HL13/HL16/HL17): 1 -> Yes,
# 2 -> No, anything else (DK/no response) -> NA.
yesno_12 <- function(x) case_when(x == 1 ~ 1, x == 2 ~ 0, TRUE ~ NA_real_)

yn_lbl <- c(No = 0, Yes = 1)
educ_lbl <- c(
  "None/ECE/pre-primary" = 0, "Primary" = 1, "Lower/general secondary" = 2,
  "Upper secondary" = 3, "Higher/postsecondary" = 4
)

harmonize_educ <- function(country_code, level) {
  case_when(
    country_code == "swz" & level == 0 ~ 0,
    country_code == "swz" & level == 1 ~ 1,
    country_code == "swz" & level == 2 ~ 2,
    country_code == "swz" & level == 3 ~ 4,
    country_code == "lso" & level == 1 ~ 1,
    country_code == "lso" & level == 2 ~ 2,
    country_code == "lso" & level == 3 ~ 4,
    country_code %in% c("bol", "nam") & level %in% 0:1 ~ level,
    country_code %in% c("bol", "nam") & level == 2 ~ 2,
    country_code %in% c("bol", "nam") & level == 3 ~ 4,
    TRUE ~ NA_real_
  )
}

# Mirrors ra_su26's parent_residence() -- same alive/in-household/
# elsewhere-code field structure, MICS6 only (DHS has no "where do they
# live if absent" field).
parent_residence <- function(alive, in_hh, elsewhere) {
  case_when(
    alive == 0 ~ "deceased",
    in_hh == 1 ~ "in_household",
    alive == 1 & in_hh == 0 & elsewhere == 1 ~ "abroad",
    alive == 1 & in_hh == 0 & elsewhere == 2 ~ "another_household_same_or_unspecified_area",
    alive == 1 & in_hh == 0 & elsewhere == 3 ~ "another_household_other_area",
    alive == 1 & in_hh == 0 & elsewhere == 4 ~ "institution"
  )
}

# Per-source builders ------------------------------------------------------
# Each returns one row per child: hh_id, anthro z-scores, and child/parent
# covariates.

anthro_mics6 <- function(country_code, ch, hl, region_var) {
  meta <- country_meta(country_code)
  survey_id_value <- meta$survey_id[[1]]

  parents <- hl %>%
    transmute(
      HH1 = znum(HH1), HH2 = znum(HH2), HL1 = znum(HL1),
      roster_matched = 1,
      roster_age_years = znum(HL6),
      mother_alive_yn = yesno_12(znum(HL12)),
      mother_in_hh_yn = yesno_12(znum(HL13)),
      mother_residence = parent_residence(mother_alive_yn, mother_in_hh_yn, znum(HL15)),
      father_alive_yn = yesno_12(znum(HL16)),
      father_in_hh_yn = yesno_12(znum(HL17)),
      father_residence = parent_residence(father_alive_yn, father_in_hh_yn, znum(HL19)),
      mother_educ = harmonize_educ(country_code, znum(melevel)),
      father_educ = harmonize_educ(country_code, znum(felevel))
    )

  ch %>%
    mutate(HH1 = znum(HH1), HH2 = znum(HH2), LN = znum(LN), UF4 = znum(UF4)) %>%
    left_join(parents, by = c("HH1", "HH2", "LN" = "HL1")) %>%
    transmute(
      country_code,
      survey_id = survey_id_value,
      survey_name = meta$survey_name[[1]],
      survey_year = as.integer(znum(UF7Y)),
      survey_year_source = znum(UF7Y),
      source_type = meta$source_type[[1]],
      source_file = meta$anthro_source_file[[1]],
      source_child_id = paste(HH1, HH2, LN, sep = "_"),
      child_id = paste(survey_id, source_child_id, sep = "_"),
      hh_id = paste(country_code, HH1, HH2, sep = "_"),
      living_child = 1,
      usual_resident = if_else(roster_matched == 1, 1, NA_real_),
      age_eligible = 1,
      sample_eligible = combine_eligibility(living_child, usual_resident, age_eligible),
      anthro_eligible = sample_eligible,
      eligibility_basis = "MICS under-five questionnaire and household roster",
      living_source_var = "under-five questionnaire universe",
      residence_source_var = "household roster membership",
      age_eligibility_source_var = "under-five questionnaire universe",
      survey_weight_raw = znum(chweight),
      survey_weight = valid_weight(survey_weight_raw),
      psu = znum(psu),
      stratum = znum(stratum),
      region_code = znum(.data[[region_var]]),
      region_name = label_text(.data[[region_var]]),
      weight_source_var = "chweight",
      psu_source_var = "psu",
      stratum_source_var = "stratum",
      source_weight_kg = znum(AN8),
      source_height_cm = znum(AN11),
      source_measurement_position = znum(AN12),
      source_haz = znum(HAZ2),
      source_waz = znum(WAZ2),
      source_whz = znum(WHZ2),
      source_haz_flag = znum(HAZFLAG),
      source_waz_flag = znum(WAZFLAG),
      source_whz_flag = znum(WHZFLAG),
      source_anthro_result = NA_real_,
      anthro_age_months = znum(CAGE),
      weight_recorded = as.numeric(is.finite(source_weight_kg) & between(source_weight_kg, 0.5, 50)),
      height_recorded = as.numeric(is.finite(source_height_cm) & between(source_height_cm, 30, 150)),
      anthro_measured = as.numeric(weight_recorded == 1 & height_recorded == 1),
      anthro_position_missing = as.numeric(height_recorded == 1 & !source_measurement_position %in% c(1, 2)),
      haz = clean_zscore(znum(HAZ2), znum(HAZFLAG)),
      waz = clean_zscore(znum(WAZ2), znum(WAZFLAG)),
      whz = clean_zscore(znum(WHZ2), znum(WHZFLAG)),
      child_sex = if_else(znum(HL4) == 1, "men", if_else(znum(HL4) == 2, "women", NA_character_)),
      child_age_months = clean_range(znum(CAGE), 0, 59),
      child_roster_age_years = roster_age_years,
      n_biological_siblings_under5 = NA_real_,
      n_siblings_under5 = n_biological_siblings_under5,
      mother_alive = labelled(mother_alive_yn, yn_lbl),
      mother_in_hh = labelled(mother_in_hh_yn, yn_lbl),
      mother_residence,
      father_alive = labelled(father_alive_yn, yn_lbl),
      father_in_hh = labelled(father_in_hh_yn, yn_lbl),
      father_residence,
      mother_educ = labelled(mother_educ, educ_lbl),
      father_educ = labelled(father_educ, educ_lbl),
      birth_order = NA_real_,
      multiple_birth = labelled(NA_real_, yn_lbl),
      preceding_birth_interval = NA_real_,
      mother_age = NA_real_
    )
}

anthro_dhs <- function(country_code, kr, pr) {
  meta <- country_meta(country_code)
  survey_id_value <- meta$survey_id[[1]]

  parents <- pr %>%
    transmute(
      HV001 = znum(HV001), HV002 = znum(HV002), HVIDX = znum(HVIDX),
      roster_matched = 1,
      roster_age_years = znum(HV105),
      usual_resident_source = znum(HV102),
      mother_alive_yn = if_else(znum(HV111) %in% c(0, 1), znum(HV111), NA_real_),
      mother_in_hh_yn = as.numeric(znum(HV112) > 0),
      father_alive_yn = if_else(znum(HV113) %in% c(0, 1), znum(HV113), NA_real_),
      father_in_hh_yn = as.numeric(znum(HV114) > 0)
    )

  kr %>%
    mutate(
      HV001 = znum(V001), HV002 = znum(V002), B16 = znum(B16),
      case_id_source = str_squish(as.character(CASEID)),
      age_at_interview_months = znum(V008) - znum(B3),
      living_biological_u5 = znum(B5) == 1 & between(age_at_interview_months, 0, 59)
    ) %>%
    left_join(parents, by = c("HV001", "HV002", "B16" = "HVIDX")) %>%
    group_by(CASEID) %>%
    mutate(
      n_biological_siblings_under5 =
        sum(living_biological_u5, na.rm = TRUE) - as.integer(living_biological_u5)
    ) %>%
    ungroup() %>%
    transmute(
      country_code,
      survey_id = survey_id_value,
      survey_name = meta$survey_name[[1]],
      survey_year = as.integer(znum(V007)),
      survey_year_source = znum(V007),
      source_type = meta$source_type[[1]],
      source_file = meta$anthro_source_file[[1]],
      source_child_id = paste(case_id_source, znum(BIDX), sep = "_"),
      child_id = paste(survey_id, source_child_id, sep = "_"),
      hh_id = paste(country_code, HV001, HV002, sep = "_"),
      living_child = case_when(znum(B5) == 1 ~ 1, znum(B5) == 0 ~ 0, TRUE ~ NA_real_),
      usual_resident = case_when(
        living_child == 0 ~ 0,
        is.na(B16) | B16 <= 0 ~ 0,
        roster_matched == 1 & usual_resident_source %in% c(0, 1) ~ usual_resident_source,
        TRUE ~ NA_real_
      ),
      age_eligible = case_when(
        is.finite(age_at_interview_months) & between(age_at_interview_months, 0, 59) ~ 1,
        is.finite(age_at_interview_months) ~ 0,
        TRUE ~ NA_real_
      ),
      sample_eligible = combine_eligibility(living_child, usual_resident, age_eligible),
      anthro_eligible = case_when(
        sample_eligible == 0 ~ 0,
        sample_eligible == 1 & !is.na(znum(HW1)) ~ 1,
        sample_eligible == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      eligibility_basis = "DHS birth history, household roster, and anthropometry block",
      living_source_var = "B5",
      residence_source_var = "B16 + PR.HV102",
      age_eligibility_source_var = "V008 - B3",
      survey_weight_raw = znum(V005),
      survey_weight = valid_weight(survey_weight_raw / 1e6),
      psu = znum(V021),
      stratum = znum(V022),
      region_code = znum(V024),
      region_name = label_text(V024),
      weight_source_var = "V005",
      psu_source_var = "V021",
      stratum_source_var = "V022",
      source_weight_kg = znum(HW2) / 10,
      source_height_cm = znum(HW3) / 10,
      source_measurement_position = znum(HW15),
      source_haz = znum(HW70) / 100,
      source_waz = znum(HW71) / 100,
      source_whz = znum(HW72) / 100,
      source_haz_flag = znum(HW13),
      source_waz_flag = znum(HW13),
      source_whz_flag = znum(HW13),
      source_anthro_result = znum(HW13),
      anthro_age_months = znum(HW1),
      weight_recorded = as.numeric(is.finite(source_weight_kg) & between(source_weight_kg, 0.5, 50)),
      height_recorded = as.numeric(is.finite(source_height_cm) & between(source_height_cm, 30, 150)),
      anthro_measured = as.numeric(weight_recorded == 1 & height_recorded == 1),
      anthro_position_missing = as.numeric(height_recorded == 1 & !source_measurement_position %in% c(1, 2)),
      haz = clean_zscore(znum(HW70) / 100, znum(HW13)),
      waz = clean_zscore(znum(HW71) / 100, znum(HW13)),
      whz = clean_zscore(znum(HW72) / 100, znum(HW13)),
      child_sex = if_else(znum(B4) == 1, "men", if_else(znum(B4) == 2, "women", NA_character_)),
      child_age_months = clean_range(age_at_interview_months, 0, 59),
      child_roster_age_years = roster_age_years,
      n_biological_siblings_under5,
      n_siblings_under5 = n_biological_siblings_under5,
      mother_alive = labelled(mother_alive_yn, yn_lbl),
      mother_in_hh = labelled(mother_in_hh_yn, yn_lbl),
      mother_residence = NA_character_,
      father_alive = labelled(father_alive_yn, yn_lbl),
      father_in_hh = labelled(father_in_hh_yn, yn_lbl),
      father_residence = NA_character_,
      mother_educ = labelled(harmonize_educ(country_code, znum(V106)), educ_lbl),
      father_educ = labelled(NA_real_, educ_lbl),
      birth_order = znum(BORD),
      multiple_birth = labelled(as.numeric(znum(B0) > 0), yn_lbl),
      preceding_birth_interval = znum(B11),
      mother_age = znum(V012)
    )
}

# Build ------------------------------------------------------------------------

anthro_outcomes <- bind_rows(
  anthro_mics6("swz", raw$swz$ch, raw$swz$hl, "HH7"),
  anthro_mics6("lso", raw$lso$ch, raw$lso$hl, "HH7A"),
  anthro_dhs("bol", raw$bol$kr, raw$bol$pr),
  anthro_dhs("nam", raw$nam$kr, raw$nam$pr)
) %>%
  group_by(country_code, survey_id) %>%
  mutate(survey_weight_normalized = normalize_weight(survey_weight)) %>%
  ungroup() %>%
  apply_anthro_quality()

# Validate -----------------------------------------------------------------
stopifnot(
  !anyDuplicated(anthro_outcomes$child_id),
  all(!is.na(anthro_outcomes$survey_id)),
  all(!is.na(anthro_outcomes$source_child_id)),
  all(anthro_outcomes$living_child %in% c(0, 1, NA)),
  all(anthro_outcomes$usual_resident %in% c(0, 1, NA)),
  all(anthro_outcomes$age_eligible %in% c(0, 1, NA)),
  all(anthro_outcomes$sample_eligible %in% c(0, 1, NA)),
  all(anthro_outcomes$anthro_eligible %in% c(0, 1, NA)),
  all(anthro_outcomes$anthro_measured %in% c(0, 1, NA)),
  all(anthro_outcomes$anthro_valid %in% c(0, 1, NA)),
  all(anthro_outcomes$survey_weight > 0 | is.na(anthro_outcomes$survey_weight)),
  all(anthro_outcomes$survey_weight_normalized > 0 | is.na(anthro_outcomes$survey_weight_normalized)),
  all(between(anthro_outcomes$haz, -6, 6) | is.na(anthro_outcomes$haz)),
  all(anthro_outcomes$stunted %in% c(0, 1, NA)),
  all(anthro_outcomes$wasted %in% c(0, 1, NA)),
  all(anthro_outcomes$child_sex %in% c("men", "women", NA)),
  all(anthro_outcomes$n_siblings_under5 >= 0 | is.na(anthro_outcomes$n_siblings_under5))
)

# Save -----------------------------------------------------------------------
ensure_project_output_dirs(intermediate_path)

saveRDS(
  anthro_outcomes,
  file.path(intermediate_path, "anthro_outcomes.rds")
)
