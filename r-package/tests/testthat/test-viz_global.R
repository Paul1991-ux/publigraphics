# ── test-viz_global.R ─────────────────────────────────────────────────────────
# Tests for viz_global.R: pg_radar_productions, pg_stats_banner,
#                         pg_curve_timeline.
# ──────────────────────────────────────────────────────────────────────────────

test_that("pg_radar_productions returns ggplot", {
  skip_on_cran()
  set.seed(2024L)

  result <- pg_radar_productions(fixture_classified)

  expect_s3_class(result, "ggplot")
})


test_that("pg_radar_productions handles single-type data", {
  skip_on_cran()
  set.seed(2024L)

  single_type <- tibble::tibble(
    type_classified = rep("article", 5L),
    year            = 2018:2022
  )

  result <- pg_radar_productions(single_type)
  expect_s3_class(result, "ggplot")
})


test_that("pg_stats_banner returns named list", {
  skip_on_cran()
  set.seed(2024L)

  result <- pg_stats_banner(fixture_classified)

  # Is a list
  expect_type(result, "list")

  # Contains the required keys
  expect_true("n_articles" %in% names(result))
  expect_true("total_productions" %in% names(result))
  expect_true("career_years" %in% names(result))

  # Values are numeric
  expect_true(is.numeric(result$n_articles))
  expect_true(is.numeric(result$total_productions))
  expect_true(is.numeric(result$career_years))

  # n_articles matches the fixture
  n_articles_expected <- sum(fixture_classified$type_classified == "article",
                              na.rm = TRUE)
  expect_equal(result$n_articles, n_articles_expected)

  # total_productions equals nrow of fixture
  expect_equal(result$total_productions, nrow(fixture_classified))

  # career_years is positive (fixture spans 2004-2020)
  expect_gt(result$career_years, 0L)

  # avg_per_year is numeric and non-negative
  expect_true(is.numeric(result$avg_per_year))
  expect_gte(result$avg_per_year, 0)

  # most_productive_year is numeric
  expect_true(is.numeric(result$most_productive_year))

  # n_unique_coauthors is non-negative
  expect_gte(result$n_unique_coauthors, 0L)

  # n_countries_interventions is non-negative
  expect_gte(result$n_countries_interventions, 0L)
})


test_that("pg_curve_timeline returns ggplot", {
  skip_on_cran()
  set.seed(2024L)

  result <- pg_curve_timeline(fixture_classified)

  expect_s3_class(result, "ggplot")
})


test_that("pg_curve_timeline handles data with all NA years gracefully", {
  skip_on_cran()
  set.seed(2024L)

  na_year_data <- tibble::tibble(
    type_classified = c("article", "book"),
    year            = c(NA_integer_, NA_integer_)
  )

  # Should return a ggplot (possibly empty / theme_void) without error
  result <- pg_curve_timeline(na_year_data)
  expect_s3_class(result, "ggplot")
})


test_that("pg_stats_banner handles empty data", {
  skip_on_cran()
  set.seed(2024L)

  empty_data <- tibble::tibble(
    type_classified = character(0L),
    year            = integer(0L),
    title           = character(0L),
    keywords        = list(),
    authors         = list(),
    country         = character(0L)
  )

  result <- pg_stats_banner(empty_data)

  expect_type(result, "list")
  expect_equal(result$total_productions, 0L)
  expect_equal(result$n_articles, 0L)
})
