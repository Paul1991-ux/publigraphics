# ── test-parse_inputs.R ────────────────────────────────────────────────────────
# Tests for parse_inputs.R: pg_read_bib, pg_read_extra, pg_merge_inputs.
# ──────────────────────────────────────────────────────────────────────────────

test_that("pg_read_bib reads demo BibTeX file correctly", {
  skip_on_cran()

  bib_path <- system.file("extdata", "duflo_articles.bib",
                           package = "publigraphics")
  skip_if(nchar(bib_path) == 0L, "Demo BibTeX file not found in package")

  result <- pg_read_bib(bib_path)

  # Is a tibble

  expect_s3_class(result, "tbl_df")

  # Has the expected 19 columns
  expected_cols <- c(
    "pg_id", "type_raw", "type_classified", "title", "authors", "year",
    "journal_or_venue", "abstract", "keywords", "doi", "url", "isbn",
    "city", "country", "institution", "note", "cited_by", "source",
    "date_added"
  )
  expect_true(all(expected_cols %in% names(result)))

  # At least one row parsed

  expect_gt(nrow(result), 0L)

  # Years are numeric (integer)
  expect_type(result$year, "integer")

  # Source column is "bib"
  expect_true(all(result$source == "bib"))
})


test_that("pg_read_extra reads demo CSV correctly", {
  skip_on_cran()

  extra_path <- system.file("extdata", "duflo_extra.csv",
                             package = "publigraphics")
  skip_if(nchar(extra_path) == 0L, "Demo extra CSV file not found in package")

  result <- pg_read_extra(extra_path)

  # Is a tibble
  expect_s3_class(result, "tbl_df")

  # Has the expected 19 columns
  expected_cols <- c(
    "pg_id", "type_raw", "type_classified", "title", "authors", "year",
    "journal_or_venue", "abstract", "keywords", "doi", "url", "isbn",
    "city", "country", "institution", "note", "cited_by", "source",
    "date_added"
  )
  expect_true(all(expected_cols %in% names(result)))

  # Source column is "extra"
  expect_true(all(result$source == "extra"))
})


test_that("pg_merge_inputs combines and deduplicates", {
  # Use fixture data from helper-fixtures.R
  merged <- pg_merge_inputs(fixture_bib, fixture_extra)

  # Is a tibble
  expect_s3_class(merged, "tbl_df")

  # Combined row count (no duplicates in fixtures, so 5 + 3 = 8)
  expect_equal(nrow(merged), nrow(fixture_bib) + nrow(fixture_extra))

  # No duplicate titles (case-insensitive)
  normalised_titles <- tolower(stringr::str_trim(merged$title))
  expect_equal(length(normalised_titles), length(unique(normalised_titles)))

  # Both sources present
  expect_true("bib" %in% merged$source)
  expect_true("extra" %in% merged$source)

  # Sorted by year descending
  years <- merged$year[!is.na(merged$year)]
  expect_true(all(diff(years) <= 0) || length(years) <= 1L)
})


test_that("pg_merge_inputs with bib_data only returns sorted tibble", {
  merged <- pg_merge_inputs(fixture_bib, extra_data = NULL)

  expect_s3_class(merged, "tbl_df")
  expect_equal(nrow(merged), nrow(fixture_bib))
})


test_that("pg_read_bib errors on missing file", {
  expect_error(
    pg_read_bib("nonexistent_file_xyz123.bib"),
    "File not found"
  )
})
