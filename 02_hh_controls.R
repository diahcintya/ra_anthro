# Household characteristics ----------------------------------------------------
#
# Goal:
#   Build minimal household-characteristic covariates (urban/rural, wealth)
#   across the three raw source formats (MICS6, DHS, MICS 2000).
#
# Inputs:
#   - intermediate/anthro_setup.rds
#
# Outputs:
#   - intermediate/hh_controls.rds

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

windex5_lbl <- c(
  "Lowest wealth quintile" = 1, "Second wealth quintile" = 2,
  "Middle wealth quintile" = 3, "Fourth wealth quintile" = 4,
  "Highest wealth quintile" = 5
)

# Per-source builders ------------------------------------------------------
# Each returns one row per household: hh_id (join key used across all
# control/outcome scripts), urban_rural (1 = urban, 2 = rural), windex5
# (1-5, NA where a wealth index doesn't exist).

hh_controls_mics6 <- function(country_code, hh) {
  hh %>%
    transmute(
      country_code,
      hh_id = paste(country_code, znum(HH1), znum(HH2), sep = "_"),
      urban_rural = clean_range(znum(HH6), 1, 2),
      windex5 = labelled(clean_range(znum(windex5), 1, 5), windex5_lbl)
    )
}

hh_controls_dhs <- function(country_code, hr) {
  hr %>%
    transmute(
      country_code,
      hh_id = paste(country_code, znum(HV001), znum(HV002), sep = "_"),
      urban_rural = clean_range(znum(HV025), 1, 2),
      windex5 = labelled(clean_range(znum(HV270), 1, 5), windex5_lbl)
    )
}

hh_controls_mics2000_botswana <- function(country_code, hh) {
  # hh.sav has multiple rows per household (a visit-attempt log, tracked by
  # M1VISITS) -- keep only the last visit attempt per household.
  hh %>%
    mutate(hh_id = paste(country_code, znum(DISTRICT), znum(DWELLNO), znum(HHNUM), sep = "_")) %>%
    group_by(hh_id) %>%
    slice_max(znum(M1VISITS), n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    transmute(
      country_code,
      hh_id,
      urban_rural = clean_range(znum(RESIDE), 1, 2),
      windex5 = labelled(NA_real_, windex5_lbl) # not available: MICS 2000 predates the wealth index
    )
}

# Build ------------------------------------------------------------------------

hh_controls <- bind_rows(
  hh_controls_mics6("swz", raw$swz$hh),
  hh_controls_mics6("lso", raw$lso$hh),
  hh_controls_dhs("bol", raw$bol$hr),
  hh_controls_dhs("nam", raw$nam$hr),
  hh_controls_mics2000_botswana("bwa", raw$bwa$hh)
)

# Validate -----------------------------------------------------------------
stopifnot(
  !anyDuplicated(hh_controls$hh_id),
  all(hh_controls$urban_rural %in% c(1, 2, NA)),
  all(hh_controls$windex5 %in% c(1:5, NA))
)

# Save -----------------------------------------------------------------------
ensure_project_output_dirs(intermediate_path)

saveRDS(
  hh_controls,
  file.path(intermediate_path, "hh_controls.rds")
)
