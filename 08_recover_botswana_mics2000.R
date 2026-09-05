# Recover unambiguous Botswana MICS 2000 child records -----------------------
# Conflicting child keys are quarantined; no visit is selected arbitrarily.
# Missing measurement position permits WHO-2006 WAZ, but not HAZ or WHZ.

packages <- c("tidyverse", "haven")
invisible(lapply(packages, library, character.only = TRUE))

source("00_paths.R")
.libPaths(c(file.path(intermediate_path, "Rlib"), .libPaths()))
if (!requireNamespace("anthro", quietly = TRUE)) {
  stop("Install CRAN package 'anthro' in intermediate/Rlib before running this script.")
}

raw <- readRDS(file.path(intermediate_path, "anthro_setup.rds"))$anthro_raw$bwa
znum <- function(x) as.numeric(zap_labels(x))
yn_lbl <- c(No = 0, Yes = 1)

children <- raw$underfive %>%
  mutate(
    across(everything(), znum),
    source_row = row_number(),
    source_child_id = paste(DISTRICT, DWELLNO, HHNUM, CHLNNO, sep = "_"),
    child_id = paste("bwa_mics_2000", source_child_id, sep = "_"),
    hh_id = paste("bwa", DISTRICT, DWELLNO, HHNUM, sep = "_")
  ) %>%
  add_count(source_child_id, name = "n_source_rows_per_child_key")

quarantine <- children %>%
  filter(n_source_rows_per_child_key > 1) %>%
  mutate(recovery_status = "quarantined_conflicting_child_key")

conflict_fields <- map_dfr(names(raw$underfive), function(variable) {
  children %>%
    filter(n_source_rows_per_child_key > 1) %>%
    group_by(source_child_id) %>%
    summarise(conflict = n_distinct(.data[[variable]], na.rm = FALSE) > 1, .groups = "drop") %>%
    summarise(variable, n_conflicting_keys = sum(conflict), .groups = "drop")
})

# Use a roster record only when its own household-member key is unique.
roster <- raw$hl %>%
  transmute(
    across(everything(), znum),
    source_child_id = paste(DISTRICT, DWELLNO, HHNUM, P01, sep = "_")
  ) %>%
  add_count(source_child_id, name = "n_roster_rows_per_member_key") %>%
  filter(n_roster_rows_per_member_key == 1) %>%
  select(
    source_child_id, roster_usual_member = P04, roster_sex = P06,
    roster_age_years = P07
  )

recovered <- children %>%
  filter(n_source_rows_per_child_key == 1) %>%
  left_join(roster, by = "source_child_id") %>%
  mutate(
    survey_id = "bwa_mics_2000",
    survey_name = "Botswana Multiple Indicator Cluster Survey 2000",
    survey_year = 2000L,
    source_type = "mics2000",
    source_file = "underfive.sav",
    recovery_status = "retained_singleton_child_key",
    living_child = 1,
    usual_resident = case_when(
      roster_usual_member == 1 ~ 1,
      roster_usual_member == 2 ~ 0,
      TRUE ~ NA_real_
    ),
    child_age_months = if_else(between(AGE, 0, 59), AGE, NA_real_),
    age_eligible = case_when(
      between(AGE, 0, 59) ~ 1,
      is.na(AGE) ~ NA_real_,
      TRUE ~ 0
    ),
    sample_eligible = case_when(
      usual_resident == 1 & age_eligible == 1 ~ 1,
      usual_resident == 0 | age_eligible == 0 ~ 0,
      TRUE ~ NA_real_
    ),
    child_sex_code = if_else(SEX %in% 1:2, SEX, NA_real_),
    child_sex = case_when(SEX == 1 ~ "men", SEX == 2 ~ "women"),
    source_weight_kg = if_else(between(WEIGHT, 0.5, 50), WEIGHT, NA_real_),
    source_height_cm = if_else(between(HEIGHT, 30, 150), HEIGHT, NA_real_),
    source_measurement_position = NA_character_,
    source_waz_nchs = if_else(between(WAZ, -8, 8), WAZ, NA_real_),
    source_haz_nchs = if_else(between(HAZ, -8, 8), HAZ, NA_real_),
    source_whz_nchs = if_else(between(WHZ, -8, 8), WHZ, NA_real_),
    source_anthro_standard = "NCHS reference (not WHO 2006)",
    survey_weight_raw = if_else(is.finite(WGHT) & WGHT > 0, WGHT, NA_real_),
    survey_weight = survey_weight_raw,
    survey_weight_normalized = survey_weight / mean(survey_weight, na.rm = TRUE),
    psu = NA_real_,
    stratum = NA_real_,
    region_code = DISTRICT,
    urban_rural = if_else(RESIDE %in% 1:2, RESIDE, NA_real_)
  )

who <- anthro::anthro_zscores(
  sex = recovered$child_sex_code,
  age = recovered$child_age_months,
  is_age_in_month = TRUE,
  weight = recovered$source_weight_kg,
  lenhei = rep(NA_real_, nrow(recovered)),
  measure = rep(NA_character_, nrow(recovered))
)

recovered <- recovered %>%
  mutate(
    source_waz_who2006 = who$zwei,
    source_waz_who2006_flag = who$fwei,
    waz = if_else(who$fwei == 0 & between(who$zwei, -6, 5), who$zwei, NA_real_),
    haz = NA_real_,
    whz = NA_real_,
    underweight = labelled(if_else(is.na(waz), NA_real_, as.numeric(waz < -2)), yn_lbl),
    stunted = labelled(NA_real_, yn_lbl),
    wasted = labelled(NA_real_, yn_lbl),
    overweight = labelled(NA_real_, yn_lbl),
    anthro_position_missing = as.numeric(!is.na(source_height_cm)),
    anthro_valid_waz = as.numeric(!is.na(waz)),
    anthro_valid_haz = 0,
    anthro_valid_whz = 0,
    anthro_valid = anthro_valid_waz,
    waz_missing_reason = case_when(
      is.na(child_age_months) ~ "age_missing_or_outside_0_59",
      is.na(child_sex_code) ~ "sex_missing",
      is.na(source_weight_kg) ~ "weight_missing_or_invalid",
      is.na(waz) ~ "who_biologically_implausible",
      TRUE ~ NA_character_
    ),
    haz_missing_reason = "measurement_position_unavailable",
    whz_missing_reason = "measurement_position_unavailable",
    pension_policy_status = "verified_survey_year",
    program_name = "Old Age Pension",
    eligibility_type = "single_age",
    eligibility_age = 65,
    has_eligible_member = labelled(NA_real_, yn_lbl),
    running_age = NA_real_
  )

audit <- tibble(
  item = c(
    "source_rows", "unique_child_keys", "singleton_child_keys", "exact_duplicate_rows",
    "conflicting_child_keys", "quarantined_rows", "recovered_rows",
    "recovered_with_unique_roster_match", "eligible_usual_resident_children",
    "eligible_children_with_valid_who2006_waz", "valid_who2006_haz",
    "valid_who2006_whz"
  ),
  value = c(
    nrow(children), n_distinct(children$source_child_id),
    sum(children$n_source_rows_per_child_key == 1),
    sum(duplicated(children[names(raw$underfive)])),
    n_distinct(quarantine$source_child_id), nrow(quarantine), nrow(recovered),
    sum(!is.na(recovered$roster_usual_member)), sum(recovered$sample_eligible == 1, na.rm = TRUE),
    sum(recovered$sample_eligible == 1 & recovered$anthro_valid_waz == 1, na.rm = TRUE), 0, 0
  )
)

stopifnot(
  !anyDuplicated(recovered$child_id),
  nrow(recovered) + nrow(quarantine) == nrow(children),
  !any(recovered$source_child_id %in% quarantine$source_child_id),
  all(recovered$sample_eligible %in% c(0, 1, NA)),
  all(is.na(recovered$haz)), all(is.na(recovered$whz))
)

ensure_project_output_dirs(intermediate_path, harmonized_path)
saveRDS(recovered, file.path(intermediate_path, "bwa_mics2000_recovered_children.rds"))
saveRDS(quarantine, file.path(intermediate_path, "bwa_mics2000_quarantined_duplicates.rds"))
write_csv(recovered, file.path(harmonized_path, "bwa_mics2000_recovered_children.csv"), na = "")
write_csv(quarantine, file.path(harmonized_path, "bwa_mics2000_quarantined_duplicates.csv"), na = "")
write_csv(conflict_fields, file.path(harmonized_path, "bwa_mics2000_duplicate_field_conflicts.csv"))
write_csv(audit, file.path(harmonized_path, "bwa_mics2000_recovery_audit.csv"))
