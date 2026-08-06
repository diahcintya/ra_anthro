# Household composition and social-pension eligibility --------------------------
#
# Goal:
#   Build household composition covariates (size, number of children under
#   5, dependency ratio, oldest member's age/sex, household head's
#   age/sex, female-headed flag) and social-pension eligibility, from
#   member-level rosters.
#
# Note: pension *receipt* (ra_su26's recipient_raw/recipient_clean) needs
# the MICS6 Social Transfers module, which doesn't exist for DHS/MICS 2000
# sources -- only eligibility (age/sex against the program's threshold) is
# built here.
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
#   - crosswalks/social_pension_programs.csv
#
# Outputs:
#   - intermediate/hl_controls_member.rds
#   - intermediate/hl_controls_composition.rds

# Load library -------------------------------------------------------------
packages <- c("tidyverse", "haven")
invisible(lapply(packages, library, character.only = TRUE))

# Setup ----------------------------------------------------------------------
source("00_paths.R")
anthro_setup <- readRDS(file.path(intermediate_path, "anthro_setup.rds"))
raw <- anthro_setup$anthro_raw

pension_config <- read_csv(
  file.path(crosswalk_path, "social_pension_programs.csv"),
  col_types = cols(
    .default = col_character(),
    eligibility_age = col_double(),
    male_age = col_double(),
    female_age = col_double()
  )
)

# Helper functions -------------------------------------------------------------

znum <- function(x) as.numeric(zap_labels(x))

clean_range <- function(x, lower, upper) {
  if_else(is.finite(x) & between(x, lower, upper), x, NA_real_)
}

eligibility_age_for <- function(sex, type, age, male_age, female_age) {
  case_when(
    type == "sex_specific" & sex == 1 ~ male_age,
    type == "sex_specific" & sex == 2 ~ female_age,
    type == "single_age" ~ age,
    TRUE ~ NA_real_
  )
}

# Value labels matching ra_su26's existing conventions, so the two
# projects' outputs combine cleanly at merge time without relabeling.
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
      is_head = znum(HL3) == 1
    )
}

hl_member_dhs <- function(country_code, pr) {
  pr %>%
    transmute(
      country_code,
      hh_id = paste(country_code, znum(HV001), znum(HV002), sep = "_"),
      age = clean_range(znum(HV105), 0, 98),
      sex = clean_range(znum(HV104), 1, 2),
      is_head = znum(HV101) == 1
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

# Add social-pension eligibility --------------------------------------------

hl_controls_member <- hl_controls_member %>%
  left_join(pension_config, by = "country_code") %>%
  mutate(
    eligibility_age_person = eligibility_age_for(
      sex, eligibility_type, eligibility_age, male_age, female_age
    ),
    age_to_eligibility = age - eligibility_age_person,
    eligible_person = case_when(
      !is.na(age_to_eligibility) & age_to_eligibility >= 0 ~ 1L,
      !is.na(age_to_eligibility) & age_to_eligibility < 0 ~ 0L,
      TRUE ~ NA_integer_
    )
  ) %>%
  select(
    country_code, hh_id, age, sex, is_head,
    age_to_eligibility, eligible_person
  )

# Aggregate household composition ---------------------------------------------

hl_controls_composition <- hl_controls_member %>%
  group_by(country_code, hh_id) %>%
  summarise(
    n_member = n(),
    n_children_under5 = sum(age < 5, na.rm = TRUE),
    n_working_age = sum(between(age, 15, 64), na.rm = TRUE),
    dependency_ratio = if_else(
      n_working_age > 0,
      (sum(age < 15, na.rm = TRUE) + sum(age >= 65, na.rm = TRUE)) / n_working_age,
      NA_real_
    ),
    oldest_age = if (all(is.na(age))) NA_real_ else max(age, na.rm = TRUE),
    sex_oldest = {
      oldest_sexes <- unique(sex[age == oldest_age & !is.na(sex)])
      if (length(oldest_sexes) == 2) {
        "both"
      } else if (length(oldest_sexes) == 1) {
        if (oldest_sexes == 1) "men" else "women"
      } else {
        NA_character_
      }
    },
    head_age = age[is_head][1],
    head_sex = labelled(case_when(
      sex[is_head][1] == 1 ~ 1,
      sex[is_head][1] == 2 ~ 0,
      TRUE ~ NA_real_
    ), head_sex_lbl),
    female_headed = labelled(as.integer(head_sex == 0), yn_lbl),
    has_eligible_member = labelled(case_when(
      all(is.na(age_to_eligibility)) ~ NA_integer_,
      any(eligible_person == 1, na.rm = TRUE) ~ 1L,
      TRUE ~ 0L
    ), yn_lbl),
    running_age = if (all(is.na(age_to_eligibility))) {
      NA_real_
    } else {
      max(age_to_eligibility, na.rm = TRUE)
    },
    .groups = "drop"
  )

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
  )

hl_controls_composition <- bind_rows(hl_controls_composition, hl_controls_composition_bwa)

# Validate -----------------------------------------------------------------
stopifnot(
  !anyDuplicated(hl_controls_composition$hh_id),
  all(hl_controls_member$sex %in% c(1, 2, NA)),
  all(hl_controls_composition$sex_oldest %in% c("men", "women", "both", NA)),
  all(hl_controls_composition$female_headed %in% c(0, 1, NA))
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
