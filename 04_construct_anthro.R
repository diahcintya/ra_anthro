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
anthro_setup <- readRDS(file.path(intermediate_path, "anthro_setup.rds"))
raw <- anthro_setup$anthro_raw

# Helper functions -------------------------------------------------------------

znum <- function(x) as.numeric(zap_labels(x))

clean_range <- function(x, lower, upper) {
  if_else(is.finite(x) & between(x, lower, upper), x, NA_real_)
}

clean_zscore <- function(z, flag) {
  z <- ifelse(z < -6 | z > 6, NA_real_, z)
  ifelse(is.na(flag) | flag == 0, z, NA_real_)
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

anthro_mics6 <- function(country_code, ch, hl) {
  parents <- hl %>%
    transmute(
      HH1 = znum(HH1), HH2 = znum(HH2), HL1 = znum(HL1),
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
    group_by(HH1, HH2, UF4) %>%
    mutate(n_siblings_under5 = n() - 1L) %>%
    ungroup() %>%
    transmute(
      country_code,
      hh_id = paste(country_code, HH1, HH2, sep = "_"),
      haz = clean_zscore(znum(HAZ2), znum(HAZFLAG)),
      waz = clean_zscore(znum(WAZ2), znum(WAZFLAG)),
      whz = clean_zscore(znum(WHZ2), znum(WHZFLAG)),
      child_sex = if_else(znum(HL4) == 1, "men", if_else(znum(HL4) == 2, "women", NA_character_)),
      child_age_months = clean_range(znum(CAGE), 0, 59),
      n_siblings_under5,
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
  parents <- pr %>%
    transmute(
      HV001 = znum(HV001), HV002 = znum(HV002), HVIDX = znum(HVIDX),
      mother_alive_yn = if_else(znum(HV111) %in% c(0, 1), znum(HV111), NA_real_),
      mother_in_hh_yn = as.numeric(znum(HV112) > 0),
      father_alive_yn = if_else(znum(HV113) %in% c(0, 1), znum(HV113), NA_real_),
      father_in_hh_yn = as.numeric(znum(HV114) > 0)
    )

  kr %>%
    mutate(HV001 = znum(V001), HV002 = znum(V002), B16 = znum(B16)) %>%
    left_join(parents, by = c("HV001", "HV002", "B16" = "HVIDX")) %>%
    group_by(CASEID) %>%
    mutate(n_siblings_under5 = n() - 1L) %>%
    ungroup() %>%
    transmute(
      country_code,
      hh_id = paste(country_code, HV001, HV002, sep = "_"),
      haz = clean_zscore(znum(HW70) / 100, znum(HW13)),
      waz = clean_zscore(znum(HW71) / 100, znum(HW13)),
      whz = clean_zscore(znum(HW72) / 100, znum(HW13)),
      child_sex = if_else(znum(B4) == 1, "men", if_else(znum(B4) == 2, "women", NA_character_)),
      child_age_months = clean_range(znum(HW1), 0, 59),
      n_siblings_under5,
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
  anthro_mics6("swz", raw$swz$ch, raw$swz$hl),
  anthro_mics6("lso", raw$lso$ch, raw$lso$hl),
  anthro_dhs("bol", raw$bol$kr, raw$bol$pr),
  anthro_dhs("nam", raw$nam$kr, raw$nam$pr)
) %>%
  mutate(
    stunted = labelled(as.numeric(haz < -2), yn_lbl),
    underweight = labelled(as.numeric(waz < -2), yn_lbl),
    wasted = labelled(as.numeric(whz < -2), yn_lbl),
    overweight = labelled(as.numeric(whz > 2), yn_lbl)
  )

# Validate -----------------------------------------------------------------
stopifnot(
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
