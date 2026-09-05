# Covariate availability audit ------------------------------------------------

packages <- c("tidyverse", "haven")
invisible(lapply(packages, library, character.only = TRUE))

source("00_paths.R")

anthro <- readRDS(file.path(harmonized_path, "anthro_full_eligible.rds"))

covariates <- tribble(
  ~variable, ~role,
  "survey_weight", "survey_design",
  "psu", "survey_design",
  "stratum", "survey_design",
  "region_code", "survey_design",
  "urban_rural", "household",
  "windex5", "household",
  "n_member", "household_composition",
  "n_children_under5", "household_composition",
  "n_working_age", "household_composition",
  "dependency_ratio", "household_composition",
  "oldest_age", "household_composition",
  "sex_oldest", "household_composition",
  "head_age", "household",
  "head_sex", "household",
  "female_headed", "household",
  "child_sex", "child",
  "child_age_months", "child",
  "n_coresident_children_under5", "child_household",
  "n_biological_siblings_under5", "child_family",
  "mother_alive", "parent",
  "mother_in_hh", "parent",
  "mother_residence", "parent",
  "mother_educ", "parent",
  "father_alive", "parent",
  "father_in_hh", "parent",
  "father_residence", "parent",
  "father_educ", "parent",
  "birth_order", "birth_history",
  "multiple_birth", "birth_history",
  "preceding_birth_interval", "birth_history",
  "mother_age", "birth_history",
  "program_name", "pension",
  "eligibility_age", "pension",
  "running_age", "pension",
  "has_eligible_member", "pension"
)

covariate_availability <- map_dfr(covariates$variable, function(variable) {
  anthro %>%
    group_by(country_code, survey_id, survey_name) %>%
    summarise(
      variable = variable,
      n_children = n(),
      n_nonmissing = sum(!is.na(.data[[variable]])),
      n_missing = n_children - n_nonmissing,
      missing_pct = n_missing / n_children * 100,
      pension_policy_status = first(pension_policy_status),
      .groups = "drop"
    )
}) %>%
  left_join(covariates, by = "variable") %>%
  mutate(
    availability_status = case_when(
      role == "pension" & pension_policy_status == "pending_historical_audit" ~
        "pending_historical_policy_audit",
      n_nonmissing == 0 ~ "N/A - unavailable in source",
      n_missing > 0 ~ "available with item missingness",
      TRUE ~ "available"
    )
  ) %>%
  arrange(variable, country_code)

covariate_summary <- covariate_availability %>%
  group_by(variable, role) %>%
  summarise(
    n_surveys = n(),
    n_surveys_available = sum(n_nonmissing > 0),
    available_all_surveys = all(n_nonmissing > 0),
    .groups = "drop"
  )

stopifnot(
  nrow(covariate_availability) == nrow(covariates) * n_distinct(anthro$survey_id),
  all(covariate_availability$n_children > 0)
)

write_csv(
  covariate_availability,
  file.path(harmonized_path, "covariate_availability.csv"),
  na = "N/A"
)
write_csv(
  covariate_summary,
  file.path(harmonized_path, "covariate_availability_summary.csv"),
  na = "N/A"
)
