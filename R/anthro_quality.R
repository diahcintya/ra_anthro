# WHO 2006 anthropometric quality and missingness rules -----------------------

who_plausible <- function(z, lower, upper) {
  is.finite(z) & z >= lower & z <= upper
}

measurement_missing_reason <- function(
    source_type, value, source_result, anthro_eligible, recorded) {
  dplyr::case_when(
    is.na(anthro_eligible) ~ "structurally_unavailable",
    anthro_eligible == 0 ~ "not_anthropometry_eligible",
    recorded == 1 ~ NA_character_,
    source_type == "mics6" & value == 99.3 ~ "child_not_present",
    source_type == "mics6" & value %in% c(99.4, 999.4) ~ "child_refused",
    source_type == "mics6" & value %in% c(99.5, 999.5) ~ "respondent_refused",
    source_type == "mics6" & value %in% c(99.6, 999.6) ~ "other_measurement_failure",
    source_type == "mics6" & value %in% c(99.9, 999.9) ~ "no_response",
    source_type == "dhs" & source_result == 1 ~ "child_dead",
    source_type == "dhs" & source_result == 2 ~ "child_sick",
    source_type == "dhs" & source_result == 3 ~ "child_not_present",
    source_type == "dhs" & source_result == 4 ~ "child_refused",
    source_type == "dhs" & source_result == 5 ~ "mother_refused",
    source_type == "dhs" & source_result == 6 ~ "other_measurement_failure",
    source_type == "dhs" & source_result == 7 ~ "no_measurement_record_in_household",
    TRUE ~ "measurement_missing_unspecified"
  )
}

zscore_missing_reason <- function(
    cleaned_z, source_z, source_flag, anthro_eligible,
    child_sex, child_age_months, position_missing,
    primary_measurement_reason, secondary_measurement_reason = NA_character_,
    lower, upper, position_required = FALSE, age_required = TRUE) {
  dplyr::case_when(
    !is.na(cleaned_z) ~ NA_character_,
    is.na(anthro_eligible) ~ "structurally_unavailable",
    anthro_eligible == 0 ~ "not_anthropometry_eligible",
    position_required & position_missing == 1 ~ "measurement_position_missing",
    !is.na(primary_measurement_reason) ~ primary_measurement_reason,
    !is.na(secondary_measurement_reason) ~ secondary_measurement_reason,
    is.na(child_sex) ~ "child_sex_missing",
    age_required & is.na(child_age_months) ~ "child_age_missing",
    !is.na(source_flag) & source_flag != 0 ~ "source_flagged",
    is.na(source_z) ~ "source_zscore_missing",
    !who_plausible(source_z, lower, upper) ~ "who_biologically_implausible",
    TRUE ~ "invalid_unspecified"
  )
}

apply_anthro_quality <- function(data) {
  data %>%
    mutate(
      weight_recorded = as.numeric(
        is.finite(source_weight_kg) & dplyr::between(source_weight_kg, 0.5, 50)
      ),
      height_recorded = as.numeric(
        is.finite(source_height_cm) & dplyr::between(source_height_cm, 30, 150)
      ),
      anthro_measured = as.numeric(weight_recorded == 1 & height_recorded == 1),
      anthro_position_missing = as.numeric(
        (
          height_recorded == 1 |
            who_plausible(source_haz, -6, 6) |
            who_plausible(source_whz, -5, 5)
        ) & !source_measurement_position %in% c(1, 2)
      ),
      weight_missing_reason = measurement_missing_reason(
        source_type, source_weight_kg, source_anthro_result,
        anthro_eligible, weight_recorded
      ),
      height_missing_reason = measurement_missing_reason(
        source_type, source_height_cm, source_anthro_result,
        anthro_eligible, height_recorded
      ),
      haz = if_else(
        anthro_eligible == 1 &
          (is.na(source_haz_flag) | source_haz_flag == 0) &
          anthro_position_missing == 0 &
          who_plausible(source_haz, -6, 6),
        source_haz,
        NA_real_
      ),
      waz = if_else(
        anthro_eligible == 1 &
          (is.na(source_waz_flag) | source_waz_flag == 0) &
          who_plausible(source_waz, -6, 5),
        source_waz,
        NA_real_
      ),
      whz = if_else(
        anthro_eligible == 1 &
          (is.na(source_whz_flag) | source_whz_flag == 0) &
          anthro_position_missing == 0 &
          who_plausible(source_whz, -5, 5),
        source_whz,
        NA_real_
      ),
      haz_missing_reason = zscore_missing_reason(
        haz, source_haz, source_haz_flag, anthro_eligible,
        child_sex, child_age_months, anthro_position_missing,
        height_missing_reason,
        lower = -6, upper = 6, position_required = TRUE
      ),
      waz_missing_reason = zscore_missing_reason(
        waz, source_waz, source_waz_flag, anthro_eligible,
        child_sex, child_age_months, anthro_position_missing,
        weight_missing_reason,
        lower = -6, upper = 5
      ),
      whz_missing_reason = zscore_missing_reason(
        whz, source_whz, source_whz_flag, anthro_eligible,
        child_sex, child_age_months, anthro_position_missing,
        weight_missing_reason, height_missing_reason,
        lower = -5, upper = 5, position_required = TRUE,
        age_required = FALSE
      ),
      anthro_valid_haz = as.numeric(!is.na(haz)),
      anthro_valid_waz = as.numeric(!is.na(waz)),
      anthro_valid_whz = as.numeric(!is.na(whz)),
      anthro_valid = as.numeric(
        anthro_valid_haz == 1 | anthro_valid_waz == 1 | anthro_valid_whz == 1
      ),
      stunted = haven::labelled(as.numeric(haz < -2), c(No = 0, Yes = 1)),
      underweight = haven::labelled(as.numeric(waz < -2), c(No = 0, Yes = 1)),
      wasted = haven::labelled(as.numeric(whz < -2), c(No = 0, Yes = 1)),
      overweight = haven::labelled(as.numeric(whz > 2), c(No = 0, Yes = 1))
    )
}
