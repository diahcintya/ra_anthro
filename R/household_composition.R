# Usual-resident household composition ---------------------------------------

construct_household_composition <- function(members) {
  members %>%
    filter(usual_resident == 1) %>%
    group_by(country_code, hh_id) %>%
    summarise(
      n_member = n(),
      n_age_missing = sum(is.na(age)),
      n_children_under5 = if_else(n_age_missing == 0, sum(age < 5), NA_integer_),
      n_working_age = if_else(n_age_missing == 0, sum(between(age, 15, 64)), NA_integer_),
      dependency_ratio = if_else(
        n_age_missing == 0 & n_working_age > 0,
        (sum(age < 15) + sum(age >= 65)) / n_working_age,
        NA_real_
      ),
      oldest_age = if (n_age_missing == 0) max(age) else NA_real_,
      sex_oldest = {
        oldest_sexes <- if (is.na(oldest_age)) {
          numeric()
        } else {
          unique(sex[!is.na(age) & age == oldest_age & !is.na(sex)])
        }
        if (length(oldest_sexes) == 2) {
          "both"
        } else if (length(oldest_sexes) == 1) {
          if (oldest_sexes == 1) "men" else "women"
        } else {
          NA_character_
        }
      },
      head_age = first(age[is_head], default = NA_real_),
      head_sex = first(sex[is_head], default = NA_real_),
      .groups = "drop"
    ) %>%
    mutate(
      head_sex = haven::labelled(
        case_when(head_sex == 1 ~ 1, head_sex == 2 ~ 0, TRUE ~ NA_real_),
        c(Female = 0, Male = 1)
      ),
      female_headed = haven::labelled(
        case_when(head_sex == 0 ~ 1, head_sex == 1 ~ 0, TRUE ~ NA_real_),
        c(No = 0, Yes = 1)
      )
    )
}
