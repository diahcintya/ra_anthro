# =============================================================================
# Project paths
# =============================================================================

# Set ANTHRO_DATA_PATH to override the default raw-data directory, for example:
# Sys.setenv(ANTHRO_DATA_PATH = "/path/to/ra_summer2026/dataset")
#
# Raw survey files (MICS6, DHS, MICS2000, per country) live under this root,
# in research/ra_summer2026/dataset/<country>/ -- the same Drive location
# ra_su26 uses, since this project's countries were found there too. Several
# are still zipped (Bolivia's dhs2008.zip, Namibia's DHS archives, Botswana's
# nested MICS2000 zip); 01_import_dictionary.R unzips those into a local
# cache under intermediate_path rather than modifying the Drive originals.

default_data_path <- file.path(
  Sys.getenv("HOME"),
  "My Drive",
  "research",
  "ra_summer2026",
  "dataset"
)

data_path <- Sys.getenv("ANTHRO_DATA_PATH", unset = default_data_path)

intermediate_path <- "intermediate"
harmonized_path <- "harmonized_outcomes"
raw_cache_path <- file.path(intermediate_path, "raw_cache")
crosswalk_path <- "crosswalks"

ensure_project_output_dirs <- function(...) {
  paths <- c(...)
  invisible(lapply(paths, dir.create, showWarnings = FALSE, recursive = TRUE))
}
