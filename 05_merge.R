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

shared_cols <- c(
  "country_code", "hh_id",
  "haz", "waz", "whz", "stunted", "underweight", "wasted", "overweight",
  "urban_rural", "windex5", "head_age", "head_sex",
  "oldest_age", "sex_oldest", "dependency_ratio", "female_headed",
  "eligibility_type", "eligibility_age", "has_eligible_member",
  "child_sex", "child_age_months", "n_siblings_under5",
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
  left_join(
    read_csv(file.path(crosswalk_path, "social_pension_programs.csv"), col_types = cols(.default = "c")) %>%
      select(country_code, eligibility_type, eligibility_age),
    by = "country_code"
  ) %>%
  mutate(eligibility_age = as.numeric(eligibility_age), source = "ra_anthro") %>%
  select(all_of(shared_cols), source)

# ra_su26's 10 countries -------------------------------------------------------
# ra_su26 already has most of these fields under matching names/labels
# (mother_alive, mother_educ, etc.); "sex"/"age_months" are renamed to this
# project's child_sex/child_age_months. Fields ra_su26 doesn't have
# (n_siblings_under5 and the DHS-only birth-history variables) are NA.

ch_su26 <- readRDS("../ra_su26/harmonized_outcomes/social_pension_ch_merged.rds")

anthro_merge_su26 <- ch_su26 %>%
  mutate(
    hh_id = paste(country_code, HH1, HH2, sep = "_"),
    child_sex = sex,
    child_age_months = age_months,
    n_siblings_under5 = NA_real_,
    birth_order = NA_real_,
    multiple_birth = labelled(NA_real_, c(No = 0, Yes = 1)),
    preceding_birth_interval = NA_real_,
    mother_age = NA_real_,
    source = "ra_su26"
  ) %>%
  select(all_of(shared_cols), source)

# Combine ------------------------------------------------------------------
anthro_merge <- bind_rows(anthro_merge_new, anthro_merge_su26)

# Validate -----------------------------------------------------------------
stopifnot(
  n_distinct(anthro_merge$country_code) == 14,
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
