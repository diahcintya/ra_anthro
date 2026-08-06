# Exploratory: Lesotho (MICS6) -------------------------------------------------
#
# Quick look at Lesotho's raw MICS6 files: dictionary + key anthropometry
# and covariate variables. Not part of the production pipeline (01-05).
#
# An older MICS2/2000 round also exists (lesotho/mics2/) but MICS6 is the
# round used everywhere else in this project -- it's the one with a full
# anthropometry block. See ANTHRO_EXTENSION_PLAN.md.

packages <- c("tidyverse", "haven")
invisible(lapply(packages, library, character.only = TRUE))

source("00_paths.R")

country_dir <- file.path(data_path, "lesotho", "mics6")
hh <- read_sav(file.path(country_dir, "hh.sav"))
ch <- read_sav(file.path(country_dir, "ch.sav"))

# Dictionary -----------------------------------------------------------------

make_dictionary <- function(data) {
  tibble(column_name = names(data), description = map_chr(data, ~ attr(.x, "label") %||% NA_character_))
}

write_csv(make_dictionary(ch), file.path(intermediate_path, "dictionary_lso_ch.csv"))

# Quick checks -----------------------------------------------------------------

cat("CH: ", nrow(ch), "children, HAZFLAG:\n")
print(table(as.numeric(zap_labels(ch$HAZFLAG)), useNA = "ifany"))
ch %>% transmute(haz = as.numeric(zap_labels(HAZ2))) %>% summary()

cat("\nHH: ", nrow(hh), "households, wealth quintile (windex5):\n")
print(table(as.numeric(zap_labels(hh$windex5)), useNA = "ifany"))
