# Prepare a small, country-level aggregated summary for the Shiny app ----------
#
# Reads the full child-level anthro_merge.rds (not committed -- see
# .gitignore) and writes a 14-row country_summary.csv (committed) with
# country names/centroids + mean z-scores + outcome prevalence rates. No
# individual-level records leave this script.
#
# Run from the repo root: Rscript shiny_app/prepare_data.R

library(tidyverse)
library(haven)

m <- readRDS("harmonized_outcomes/anthro_merge.rds")

country_lookup <- tribble(
  ~country_code, ~country_name, ~lat, ~lon,
  "bol", "Bolivia", -16.50, -68.15,
  "fji", "Fiji", -17.71, 178.07,
  "geo", "Georgia", 41.72, 44.79,
  "guy", "Guyana", 6.80, -58.16,
  "kir", "Kiribati", 1.45, 173.02,
  "kos", "Kosovo", 42.66, 21.17,
  "lso", "Lesotho", -29.31, 27.48,
  "nam", "Namibia", -22.56, 17.08,
  "nep", "Nepal", 27.72, 85.32,
  "soa", "Samoa", -13.83, -171.76,
  "sur", "Suriname", 5.87, -55.17,
  "swz", "Eswatini", -26.32, 31.13,
  "thai", "Thailand", 13.75, 100.50,
  "tto", "Trinidad and Tobago", 10.65, -61.52
)

country_summary <- m %>%
  group_by(country_code) %>%
  summarise(
    n_children = n(),
    mean_haz = mean(haz, na.rm = TRUE),
    mean_waz = mean(waz, na.rm = TRUE),
    mean_whz = mean(whz, na.rm = TRUE),
    stunted_pct = mean(zap_labels(stunted), na.rm = TRUE) * 100,
    wasted_pct = mean(zap_labels(wasted), na.rm = TRUE) * 100,
    underweight_pct = mean(zap_labels(underweight), na.rm = TRUE) * 100,
    overweight_pct = mean(zap_labels(overweight), na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  inner_join(country_lookup, by = "country_code") %>%
  select(country_code, country_name, lat, lon, n_children, everything())

stopifnot(nrow(country_summary) == 14)

write_csv(country_summary, "shiny_app/country_summary.csv")
