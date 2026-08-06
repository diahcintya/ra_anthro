# Exploratory: Bolivia (DHS 2008) -----------------------------------------------
#
# Quick look at Bolivia's raw DHS files: dictionary + key anthropometry and
# covariate variables. Not part of the production pipeline (01-05); assumes
# 01_import_dictionary.R has already been run once, to populate
# intermediate/raw_cache/bol/.
#
# MICS 2000 is also available for Bolivia (bolivia/mics2000/) but has no
# anthropometric variables at all -- DHS 2008 is the source used everywhere
# else in this project. See ANTHRO_EXTENSION_PLAN.md.

packages <- c("tidyverse", "haven")
invisible(lapply(packages, library, character.only = TRUE))

source("00_paths.R")

cache <- file.path(raw_cache_path, "bol", "dhs2008")
hr <- read_sav(file.path(cache, "BOHR51SV", "BOHR51FL.SAV"))
kr <- read_sav(file.path(cache, "BOKR51SV", "BOKR51FL.SAV"))

# Dictionary -----------------------------------------------------------------

make_dictionary <- function(data) {
  tibble(column_name = names(data), description = map_chr(data, ~ attr(.x, "label") %||% NA_character_))
}

write_csv(make_dictionary(kr), file.path(intermediate_path, "dictionary_bol_kr.csv"))

# Quick checks -----------------------------------------------------------------

cat("KR: ", nrow(kr), "children\n")
kr %>% transmute(haz = as.numeric(zap_labels(HW70)) / 100) %>% summary()

cat("\nHR: ", nrow(hr), "households, wealth quintile (HV270):\n")
print(table(as.numeric(zap_labels(hr$HV270)), useNA = "ifany"))
