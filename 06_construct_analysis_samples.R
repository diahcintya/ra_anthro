# Construct eligible-child analysis datasets and sample-flow audit ------------
#
# Goal:
#   Separate the source-universe staging data from the primary population of
#   living, usual-resident children aged 0-59 months. Retain eligible children
#   with missing anthropometry, and create a second dataset containing children
#   with at least one valid anthropometric outcome.
#
# Input:
#   - harmonized_outcomes/anthro_merge.rds
#
# Outputs:
#   - harmonized_outcomes/anthro_full_eligible.{rds,csv}
#   - harmonized_outcomes/anthro_valid_any.{rds,csv}
#   - harmonized_outcomes/anthro_sample_flow_country.csv
#   - harmonized_outcomes/anthro_missing_reasons_country.csv

packages <- c("tidyverse", "haven")
invisible(lapply(packages, library, character.only = TRUE))

source("00_paths.R")

anthro_source_universe <- readRDS(file.path(harmonized_path, "anthro_merge.rds")) %>%
  mutate(
    sample_exclusion_reason = case_when(
      living_child == 0 ~ "not_living",
      living_child == 1 & usual_resident == 0 ~ "not_usual_resident",
      living_child == 1 & usual_resident == 1 & age_eligible == 0 ~ "outside_0_59_months",
      sample_eligible == 1 ~ NA_character_,
      TRUE ~ "eligibility_unknown"
    )
  )

anthro_full_eligible <- anthro_source_universe %>%
  filter(sample_eligible == 1)

anthro_valid_any <- anthro_full_eligible %>%
  filter(anthro_valid == 1)

anthro_sample_flow_country <- anthro_source_universe %>%
  group_by(country_code, survey_id, survey_name, source_type) %>%
  summarise(
    n_source_records = n(),
    n_living = sum(living_child == 1, na.rm = TRUE),
    n_usual_resident = sum(living_child == 1 & usual_resident == 1, na.rm = TRUE),
    n_age_eligible = sum(
      living_child == 1 & usual_resident == 1 & age_eligible == 1,
      na.rm = TRUE
    ),
    n_sample_eligible = sum(sample_eligible == 1, na.rm = TRUE),
    n_sample_eligibility_unknown = sum(is.na(sample_eligible)),
    n_anthro_eligible = if (all(is.na(anthro_eligible))) {
      NA_integer_
    } else {
      sum(sample_eligible == 1 & anthro_eligible == 1, na.rm = TRUE)
    },
    n_weight_recorded = sum(sample_eligible == 1 & weight_recorded == 1, na.rm = TRUE),
    n_height_recorded = sum(sample_eligible == 1 & height_recorded == 1, na.rm = TRUE),
    n_anthro_measured = sum(sample_eligible == 1 & anthro_measured == 1, na.rm = TRUE),
    n_position_missing = sum(
      sample_eligible == 1 & anthro_position_missing == 1,
      na.rm = TRUE
    ),
    n_valid_haz = sum(sample_eligible == 1 & anthro_valid_haz == 1, na.rm = TRUE),
    n_valid_waz = sum(sample_eligible == 1 & anthro_valid_waz == 1, na.rm = TRUE),
    n_valid_whz = sum(sample_eligible == 1 & anthro_valid_whz == 1, na.rm = TRUE),
    n_valid_any = sum(sample_eligible == 1 & anthro_valid == 1, na.rm = TRUE),
    n_excluded_not_living = sum(sample_exclusion_reason == "not_living", na.rm = TRUE),
    n_excluded_not_usual_resident = sum(
      sample_exclusion_reason == "not_usual_resident",
      na.rm = TRUE
    ),
    n_excluded_outside_age = sum(
      sample_exclusion_reason == "outside_0_59_months",
      na.rm = TRUE
    ),
    .groups = "drop"
  )

anthro_missing_reasons_country <- anthro_full_eligible %>%
  select(country_code, survey_id, haz_missing_reason, waz_missing_reason, whz_missing_reason) %>%
  pivot_longer(
    ends_with("_missing_reason"),
    names_to = "outcome",
    names_pattern = "(haz|waz|whz)_missing_reason",
    values_to = "missing_reason"
  ) %>%
  filter(!is.na(missing_reason)) %>%
  count(country_code, survey_id, outcome, missing_reason, name = "n_children")

stopifnot(
  !anyDuplicated(anthro_full_eligible$child_id),
  !anyDuplicated(anthro_valid_any$child_id),
  all(anthro_full_eligible$sample_eligible == 1),
  all(anthro_valid_any$anthro_valid == 1),
  all(is.na(anthro_full_eligible$haz) == !is.na(anthro_full_eligible$haz_missing_reason)),
  all(is.na(anthro_full_eligible$waz) == !is.na(anthro_full_eligible$waz_missing_reason)),
  all(is.na(anthro_full_eligible$whz) == !is.na(anthro_full_eligible$whz_missing_reason)),
  nrow(anthro_valid_any) <= nrow(anthro_full_eligible),
  sum(anthro_sample_flow_country$n_sample_eligible) == nrow(anthro_full_eligible),
  sum(anthro_sample_flow_country$n_valid_any) == nrow(anthro_valid_any)
)

ensure_project_output_dirs(harmonized_path)

saveRDS(
  anthro_full_eligible,
  file.path(harmonized_path, "anthro_full_eligible.rds")
)
write_csv(
  anthro_full_eligible,
  file.path(harmonized_path, "anthro_full_eligible.csv"),
  na = "N/A"
)

saveRDS(
  anthro_valid_any,
  file.path(harmonized_path, "anthro_valid_any.rds")
)
write_csv(
  anthro_valid_any,
  file.path(harmonized_path, "anthro_valid_any.csv"),
  na = "N/A"
)

write_csv(
  anthro_sample_flow_country,
  file.path(harmonized_path, "anthro_sample_flow_country.csv"),
  na = "N/A"
)

write_csv(
  anthro_missing_reasons_country,
  file.path(harmonized_path, "anthro_missing_reasons_country.csv"),
  na = "N/A"
)
