# Household composition --------------------------------------------------------
#
# Goal:
#   Build household composition covariates (size, number of children under
#   5, dependency ratio, oldest member's age/sex, household head's
#   age/sex, female-headed flag) from usual-resident member rosters.
#
# Note: Botswana's hl.sav member roster is unreliable -- the same
# (household, line number) key holds different people's age/sex across its
# duplicate rows (4,823 of 4,922 duplicated members disagree on age), and
# there's no field to resolve which row is correct. Botswana is therefore
# excluded from the member roster; its household size and number of
# children under 5 are taken from hh.sav's own pre-aggregated TOTPOP/TOTUND
# instead, and all other composition fields are left NA.
#
# Inputs:
#   - intermediate/anthro_setup.rds
#
# Outputs:
#   - intermediate/hl_controls_member.rds
#   - intermediate/hl_controls_composition.rds

# Load library -------------------------------------------------------------
packages <- c("tidyverse", "haven")
invisible(lapply(packages, library, character.only = TRUE))

# Setup ----------------------------------------------------------------------
source("00_paths.R")
source("R/household_composition.R")
source("R/pension_eligibility.R")
anthro_setup <- readRDS(file.path(intermediate_path, "anthro_setup.rds"))
raw <- anthro_setup$anthro_raw
policy <- read_csv(
  file.path(crosswalk_path, "pension_policy_audit.csv"),
  show_col_types = FALSE
)

# Helper functions -------------------------------------------------------------

znum <- function(x) as.numeric(zap_labels(x))

clean_range <- function(x, lower, upper) {
  if_else(is.finite(x) & between(x, lower, upper), x, NA_real_)
}

yn_lbl <- c(No = 0, Yes = 1)
head_sex_lbl <- c(Female = 0, Male = 1)

# Per-source member rosters -------------------------------------------------
# Each returns one row per household member: hh_id, age, sex (1 = male,
# 2 = female -- consistent across sources), is_head. Household head is
# coded differently per source, so it's resolved here.

hl_member_mics6 <- function(country_code, hl) {
  hl %>%
    transmute(
      country_code,
      hh_id = paste(country_code, znum(HH1), znum(HH2), sep = "_"),
      age = clean_range(znum(HL6), 0, 98),
      sex = clean_range(znum(HL4), 1, 2),
      is_head = znum(HL3) == 1,
      usual_resident = 1
    )
}

hl_member_dhs <- function(country_code, pr) {
  pr %>%
    transmute(
      country_code,
      hh_id = paste(country_code, znum(HV001), znum(HV002), sep = "_"),
      age = clean_range(znum(HV105), 0, 98),
      sex = clean_range(znum(HV104), 1, 2),
      is_head = znum(HV101) == 1,
      usual_resident = znum(HV102)
    )
}

# Build member roster ------------------------------------------------------
# Botswana omitted -- see note above.

hl_controls_member <- bind_rows(
  hl_member_mics6("swz", raw$swz$hl),
  hl_member_mics6("lso", raw$lso$hl),
  hl_member_dhs("bol", raw$bol$pr),
  hl_member_dhs("nam", raw$nam$pr)
)

# Aggregate household composition ---------------------------------------------

pension <- construct_pension_eligibility(hl_controls_member, policy)

hl_controls_composition <- construct_household_composition(hl_controls_member) %>%
  left_join(pension$households, by = c("country_code", "hh_id")) %>%
  left_join(pension$policy, by = "country_code") %>%
  mutate(has_eligible_member = labelled(has_eligible_member, yn_lbl))

# Botswana: household size / children under 5 only, from hh.sav's own
# pre-aggregated counts -- see note above for why the roster isn't used.

hl_controls_composition_bwa <- raw$bwa$hh %>%
  mutate(hh_id = paste("bwa", znum(DISTRICT), znum(DWELLNO), znum(HHNUM), sep = "_")) %>%
  group_by(hh_id) %>%
  slice_max(znum(M1VISITS), n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(
    country_code = "bwa",
    hh_id,
    n_member = clean_range(znum(TOTPOP), 1, Inf),
    n_age_missing = NA_integer_,
    n_children_under5 = clean_range(znum(TOTUND), 0, Inf),
    n_working_age = NA_real_,
    dependency_ratio = NA_real_,
    oldest_age = NA_real_,
    sex_oldest = NA_character_,
    head_age = NA_real_,
    head_sex = labelled(NA_real_, head_sex_lbl),
    female_headed = labelled(NA_integer_, yn_lbl),
    has_eligible_member = labelled(NA_integer_, yn_lbl),
    running_age = NA_real_
  ) %>%
  left_join(pension$policy, by = "country_code")

hl_controls_composition <- bind_rows(hl_controls_composition, hl_controls_composition_bwa)

# Validate -----------------------------------------------------------------
stopifnot(
  !anyDuplicated(hl_controls_composition$hh_id),
  all(hl_controls_member$sex %in% c(1, 2, NA)),
  all(hl_controls_member$usual_resident %in% c(0, 1, NA)),
  all(hl_controls_composition$sex_oldest %in% c("men", "women", "both", NA)),
  all(hl_controls_composition$female_headed %in% c(0, 1, NA)),
  all(hl_controls_composition$has_eligible_member %in% c(0, 1, NA)),
  all(hl_controls_composition$pension_policy_status == "verified_survey_year")
)

# Save -----------------------------------------------------------------------
ensure_project_output_dirs(intermediate_path)

saveRDS(
  hl_controls_member,
  file.path(intermediate_path, "hl_controls_member.rds")
)

saveRDS(
  hl_controls_composition,
  file.path(intermediate_path, "hl_controls_composition.rds")
)
