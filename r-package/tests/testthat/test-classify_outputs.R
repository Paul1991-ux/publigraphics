# ── test-classify_outputs.R ───────────────────────────────────────────────────
# Tests for classify_outputs.R: pg_classify, pg_summary_table.
# ──────────────────────────────────────────────────────────────────────────────

test_that("pg_classify assigns correct types", {
  # Build a test tibble matching the expected input structure for pg_classify
  test_data <- tibble::tibble(
    pg_id           = paste0("test_", 1:7),
    type_raw        = c("article", "book", "incollection", "inproceedings",
                         "techreport", "misc", "misc"),
    type_classified = NA_character_,
    title           = paste("Test title", 1:7),
    year            = 2018:2024,
    type            = c(NA, NA, NA, NA, NA, "media", "project"),
    venue           = rep(NA_character_, 7L),
    role            = rep(NA_character_, 7L)
  )

  result <- pg_classify(test_data)

  expect_equal(result$type_classified[1], "article")
  expect_equal(result$type_classified[2], "book")
  expect_equal(result$type_classified[3], "book_chapter")
  expect_equal(result$type_classified[4], "conference")
  expect_equal(result$type_classified[5], "report")
  expect_equal(result$type_classified[6], "media")
  expect_equal(result$type_classified[7], "project")

  # All rows should have a non-NA type_classified
  expect_true(all(!is.na(result$type_classified)))
})


test_that("pg_classify handles seminar detection", {
  test_data <- tibble::tibble(
    pg_id           = "sem_1",
    type_raw        = "inproceedings",
    type_classified = NA_character_,
    title           = "Talk on Poverty",
    year            = 2022L,
    type            = "seminar",
    venue           = "Seminar on Development",
    role            = NA_character_
  )

  result <- pg_classify(test_data)
  expect_equal(result$type_classified, "seminar")
})


test_that("pg_summary_table returns correct structure", {
  # Use the pre-classified fixture
  summary_tbl <- pg_summary_table(fixture_classified)

  # Is a tibble
  expect_s3_class(summary_tbl, "tbl_df")

  # Has required columns
  expected_cols <- c("type_classified", "label_fr", "label_en",
                      "n", "first_year", "last_year", "pct_total")
  expect_true(all(expected_cols %in% names(summary_tbl)))

  # pct_total sums to approximately 100
  expect_equal(sum(summary_tbl$pct_total), 100, tolerance = 0.5)

  # n values are positive integers
  expect_true(all(summary_tbl$n > 0L))

  # first_year <= last_year for each row
  expect_true(all(summary_tbl$first_year <= summary_tbl$last_year))

  # Sorted by n descending
  expect_true(all(diff(summary_tbl$n) <= 0))
})


test_that("pg_classify handles empty data", {
  # Create an empty tibble with the required column
  empty_data <- tibble::tibble(
    pg_id           = character(0L),
    type_raw        = character(0L),
    type_classified = character(0L),
    title           = character(0L),
    year            = integer(0L)
  )

  # Should not error and should return a tibble with 0 rows
  result <- pg_classify(empty_data)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true("type_classified" %in% names(result))
})


test_that("pg_classify falls back to 'other' for unknown types", {
  test_data <- tibble::tibble(
    pg_id           = "unk_1",
    type_raw        = "unpublished",
    type_classified = NA_character_,
    title           = "Some Working Paper",
    year            = 2023L
  )

  result <- suppressWarnings(pg_classify(test_data))
  expect_equal(result$type_classified, "other")
})
