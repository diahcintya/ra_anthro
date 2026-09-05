# Survey-year, age-based household pension eligibility -----------------------

construct_pension_eligibility <- function(members, policy) {
  verified <- policy %>%
    filter(verification_status == "verified_survey_year") %>%
    select(
      country_code, program_name, eligibility_type, eligibility_age,
      male_age, female_age, pension_policy_status = verification_status
    )

  member_status <- members %>%
    filter(usual_resident == 1) %>%
    inner_join(verified, by = "country_code") %>%
    mutate(
      eligibility_age_person = case_when(
        eligibility_type == "single_age" ~ eligibility_age,
        eligibility_type == "sex_specific" & sex == 1 ~ male_age,
        eligibility_type == "sex_specific" & sex == 2 ~ female_age,
        TRUE ~ NA_real_
      ),
      age_to_eligibility = age - eligibility_age_person
    ) %>%
    group_by(country_code, hh_id) %>%
    summarise(
      running_age = if_else(
        all(is.na(age_to_eligibility)), NA_real_, max(age_to_eligibility, na.rm = TRUE)
      ),
      has_eligible_member = case_when(
        all(is.na(age_to_eligibility)) ~ NA_real_,
        any(age_to_eligibility >= 0, na.rm = TRUE) ~ 1,
        TRUE ~ 0
      ),
      .groups = "drop"
    )

  list(policy = verified, households = member_status)
}
