# Exploratory: Namibia (DHS 2013) -----------------------------------------------
#
# Quick look at Namibia's raw DHS files: dictionary + key anthropometry and
# covariate variables. Not part of the production pipeline (01-05); assumes
# 01_import_dictionary.R has already been run once, to populate
# intermediate/raw_cache/nam/.
#
# Note: this round has a high anthropometry non-response rate -- 2,873 of
# 5,046 children are flagged HW13 = 7 ("No measurement found in HH"). Real
# feature of the survey round, confirmed in ANTHRO_EXTENSION_PLAN.md.

packages <- c("tidyverse", "haven")
invisible(lapply(packages, library, character.only = TRUE))

source("00_paths.R")

hr <- read_sav(file.path(raw_cache_path, "nam", "NM_2013_DHS_08022026_2151_250773", "NMHR61SV", "NMHR61FL.SAV"))
kr <- read_sav(file.path(raw_cache_path, "nam", "data", "NMKR61SV", "NMKR61FL.SAV"))

# Dictionary -----------------------------------------------------------------

make_dictionary <- function(data) {
  tibble(column_name = names(data), description = map_chr(data, ~ attr(.x, "label") %||% NA_character_))
}

write_csv(make_dictionary(kr), file.path(intermediate_path, "dictionary_nam_kr.csv"))

# Quick checks -----------------------------------------------------------------

cat("KR: ", nrow(kr), "children, HW13 (measurement flag):\n")
print(table(as.numeric(zap_labels(kr$HW13)), useNA = "ifany"))
kr %>% transmute(haz = as.numeric(zap_labels(HW70)) / 100) %>% summary()

cat("\nHR: ", nrow(hr), "households, wealth quintile (HV270):\n")
print(table(as.numeric(zap_labels(hr$HV270)), useNA = "ifany"))
