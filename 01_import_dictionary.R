# Script's description: --------------------------------------------------------
# - Imports raw anthropometry-relevant files for the 5 currently-available
#   countries, across three source formats (see ANTHRO_EXTENSION_PLAN.md):
#     - MICS6:     Eswatini, Lesotho          (hh.sav, hl.sav, ch.sav)
#     - DHS:       Bolivia (2008), Namibia    (HR/PR/KR .SAV, zipped)
#     - MICS 2000: Botswana                   (hh.sav, hl.sav, underfive.sav,
#                                               nested zip)
# - Writes a combined data dictionary and basic import-check summary.
# - Saves all imported modules + metadata to intermediate/anthro_setup.rds
#   for later scripts (02_construct_anthro.R etc.) to read back.

# Load library -----------------------------------------------------------------
packages <- c("tidyverse", "haven", "labelled")
invisible(lapply(packages, library, character.only = TRUE))

# Path -------------------------------------------------------------------------
source("00_paths.R")
stopifnot(dir.exists(data_path))

ensure_project_output_dirs(intermediate_path, raw_cache_path)

# Helper functions -------------------------------------------------------------

make_dictionary <- function(data) {
  tibble(
    column_name = names(data),
    description = map_chr(data, ~ {
      label <- attr(.x, "label")
      if (is.null(label)) NA_character_ else as.character(label)
    }),
    value_labels = map_chr(data, ~ {
      labels <- labelled::val_labels(.x)
      if (is.null(labels)) {
        NA_character_
      } else {
        paste(
          paste0(unname(labels), ":", names(labels)),
          collapse = ";"
        )
      }
    })
  )
}

write_dictionary_csv <- function(data, path) {
  write_csv(data, file = path, na = "NA", quote = "all")
}

# Extract a zip into a cache subfolder (keyed by zip filename, under
# cache_subdir) if not already extracted; returns the extraction directory.
# Leaves the original zip on Drive untouched.
ensure_unzipped <- function(zip_path, cache_subdir) {
  stopifnot(file.exists(zip_path))
  target_dir <- file.path(
    raw_cache_path,
    cache_subdir,
    tools::file_path_sans_ext(basename(zip_path))
  )
  if (!dir.exists(target_dir) || length(list.files(target_dir, recursive = TRUE)) == 0) {
    dir.create(target_dir, showWarnings = FALSE, recursive = TRUE)
    unzip(zip_path, exdir = target_dir)
  }
  target_dir
}

# Find a file within a directory tree whose name matches a regex
# (case-insensitive); returns the first match or NULL if none found.
find_file <- function(dir, pattern) {
  hits <- list.files(
    dir, pattern = pattern, recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )
  if (length(hits) == 0) NULL else hits[[1]]
}

read_sav_safe <- function(path) {
  if (is.null(path)) return(NULL)
  read_sav(path)
}

# Per-source-type readers --------------------------------------------------------

# MICS6 (Eswatini, Lesotho): hh/hl/ch already unzipped on Drive.
read_mics6_country <- function(paths) {
  country_dir <- file.path(data_path, paths[[1]])
  stopifnot(dir.exists(country_dir))
  list(
    hh = read_sav(file.path(country_dir, "hh.sav")),
    hl = read_sav(file.path(country_dir, "hl.sav")),
    ch = read_sav(file.path(country_dir, "ch.sav"))
  )
}

# Standard DHS recode (Bolivia 2008, Namibia): HR/PR/KR files, zipped, split
# across one or more archives (Namibia's HR/PR arrived in a second archive
# from its KR/BR archive). HR/PR are optional -- if genuinely absent for a
# country, hr/pr come back NULL rather than erroring; KR (anthro outcomes)
# is required.
read_dhs_country <- function(paths, cache_subdir) {
  zip_paths <- file.path(data_path, paths)
  dirs <- map_chr(zip_paths, ~ ensure_unzipped(.x, cache_subdir))

  find_in_dirs <- function(pattern) {
    for (d in dirs) {
      hit <- find_file(d, pattern)
      if (!is.null(hit)) return(hit)
    }
    NULL
  }

  kr_path <- find_in_dirs("KR\\d+FL\\.SAV$")
  if (is.null(kr_path)) {
    stop("No Children's Recode (KR) file found for DHS country in: ", paste(dirs, collapse = ", "))
  }

  list(
    hr = read_sav_safe(find_in_dirs("HR\\d+FL\\.SAV$")),
    pr = read_sav_safe(find_in_dirs("PR\\d+FL\\.SAV$")),
    kr = read_sav(kr_path)
  )
}

# Older MICS 2000 (Botswana): outer zip contains an inner zip with the
# actual .sav files.
read_mics2000_botswana <- function(paths, cache_subdir) {
  outer_zip <- file.path(data_path, paths[[1]])
  outer_dir <- ensure_unzipped(outer_zip, cache_subdir)

  inner_zip <- find_file(outer_dir, "\\.zip$")
  if (is.null(inner_zip)) {
    stop("No inner zip found inside: ", outer_zip)
  }
  inner_dir <- ensure_unzipped(inner_zip, cache_subdir)

  list(
    hh = read_sav(find_file(inner_dir, "^hh\\.sav$")),
    hl = read_sav(find_file(inner_dir, "^hl\\.sav$")),
    underfive = read_sav(find_file(inner_dir, "^underfive\\.sav$"))
  )
}

# Country setup ------------------------------------------------------------------
# See ANTHRO_EXTENSION_PLAN.md §2 for the verified source-format audit this
# config is based on. Bolivia's MICS 2000 round is intentionally excluded --
# it has no anthropometric variables; DHS 2008 is the canonical Bolivia source.

country_config <- tibble(
  country_code = c("swz", "lso", "bol", "bwa", "nam"),
  country = c("Eswatini", "Lesotho", "Bolivia", "Botswana", "Namibia"),
  source_type = c("mics6", "mics6", "dhs", "mics2000", "dhs"),
  survey_id = c(
    "swz_mics_2021_2022", "lso_mics_2018", "bol_dhs_2008",
    "bwa_mics_2000", "nam_dhs_2013"
  ),
  survey_name = c(
    "Eswatini Multiple Indicator Cluster Survey 2021-2022",
    "Lesotho Multiple Indicator Cluster Survey 2018",
    "Bolivia Demographic and Health Survey 2008",
    "Botswana Multiple Indicator Cluster Survey 2000",
    "Namibia Demographic and Health Survey 2013"
  ),
  survey_start_year = c(2021L, 2018L, 2008L, 2000L, 2013L),
  survey_end_year = c(2022L, 2018L, 2008L, 2000L, 2013L),
  anthro_source_file = c(
    "eswatini/mics6/ch.sav",
    "lesotho/mics6/ch.sav",
    "BOKR51FL.SAV",
    "underfive.sav",
    "NMKR61FL.SAV"
  ),
  paths = list(
    "eswatini/mics6",
    "lesotho/mics6",
    "bolivia/dhs2008.zip",
    "bostwana/Botswana 2000 MICS_Datasets.zip",
    c("namibia/data.zip", "namibia/NM_2013_DHS_08022026_2151_250773.zip")
  )
)

country_name_map <- country_config %>%
  select(country_code, country) %>%
  deframe()

# Import raw data ------------------------------------------------------------

import_country <- function(source_type, paths, country_code) {
  switch(
    source_type,
    mics6 = read_mics6_country(paths),
    dhs = read_dhs_country(paths, cache_subdir = country_code),
    mics2000 = read_mics2000_botswana(paths, cache_subdir = country_code),
    stop("Unknown source_type: ", source_type)
  )
}

anthro_raw <- country_config %>%
  mutate(data = pmap(list(source_type, paths, country_code), import_country)) %>%
  select(country_code, data) %>%
  deframe()

# Data dictionaries -----------------------------------------------------------
# Module names differ by source_type (hh/hl/ch vs hr/pr/kr vs hh/hl/underfive)
# so dictionaries are built by iterating whatever modules each country has.

dd_all <- imap_dfr(anthro_raw, function(modules, country_code) {
  imap_dfr(modules, function(module_data, module_name) {
    if (is.null(module_data)) return(tibble())
    make_dictionary(module_data) %>%
      mutate(country_code = country_code, module = module_name, .before = 1)
  })
})

write_dictionary_csv(dd_all, file.path(intermediate_path, "anthro_dictionary_all.csv"))

# Basic import checks ----------------------------------------------------------

module_nrows <- imap_dfr(anthro_raw, function(modules, country_code) {
  imap_dfr(modules, function(module_data, module_name) {
    tibble(
      country_code = country_code,
      country = unname(country_name_map[country_code]),
      module = module_name,
      n_rows = if (is.null(module_data)) NA_integer_ else nrow(module_data),
      n_cols = if (is.null(module_data)) NA_integer_ else ncol(module_data)
    )
  })
})

write_csv(
  module_nrows,
  file.path(intermediate_path, "module_nrows.csv")
)

# Save setup objects for later scripts -----------------------------------------

anthro_setup <- list(
  country_config = country_config,
  country_name_map = country_name_map,
  anthro_raw = anthro_raw,
  dd_all = dd_all,
  module_nrows = module_nrows
)

saveRDS(
  anthro_setup,
  file.path(intermediate_path, "anthro_setup.rds")
)
