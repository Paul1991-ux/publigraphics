# ── test-scientific_index.R ───────────────────────────────────────────────────
# Tests for scientific_index.R: SII computation, scoring, card, radar, evolution.
# ──────────────────────────────────────────────────────────────────────────────

# --- Helper: build minimal classified data matching the 19-column schema -----
make_test_data <- function() {
  tibble::tibble(
    pg_id           = paste0("t_", 1:12),
    type_raw        = c(rep("article", 4), "book", "incollection",
                        "inproceedings", "inproceedings",
                        "phdthesis", "misc", "misc", "misc"),
    type_classified = c(rep("article", 4), "book", "book_chapter",
                        "seminar", "conference",
                        "thesis_supervised", "project", "award", "media"),
    title           = paste("Title", 1:12),
    authors         = rep("Doe J, Smith A, Lee B", 12),
    year            = c(2018, 2019, 2020, 2022, 2019, 2021,
                        2020, 2021, 2019, 2020, 2022, 2023),
    journal         = c("Nature", "Science", "PNAS", "AER",
                        rep(NA_character_, 8)),
    journal_or_venue = c("Nature", "Science", "PNAS", "American Economic Review",
                         "MIT Press", "Cambridge University Press",
                         "NBER Workshop", "AEA Annual Meeting",
                         rep(NA_character_, 4)),
    cited_by        = c(150, 80, 40, 10, 2000, 50,
                        NA, NA, NA, NA, NA, NA),
    venue           = c(rep(NA_character_, 6),
                        "NBER", "AEA Meeting",
                        rep(NA_character_, 4)),
    role            = rep(NA_character_, 12),
    type            = rep(NA_character_, 12),
    doi             = rep(NA_character_, 12),
    url             = rep(NA_character_, 12),
    abstract        = rep(NA_character_, 12),
    keywords        = rep(NA_character_, 12),
    pages           = rep(NA_character_, 12),
    isbn            = rep(NA_character_, 12),
    note            = rep(NA_character_, 12)
  )
}


# =============================================================================
# pg_score_articles — returns data with article_score column
# =============================================================================
test_that("pg_score_articles adds article_score column", {
  data <- make_test_data()
  result <- pg_score_articles(data)

  expect_s3_class(result, "tbl_df")
  expect_true("article_score" %in% names(result))

  # Only article rows have scores
  article_scores <- result$article_score[result$type_classified == "article"]
  expect_true(all(!is.na(article_scores)))
  expect_true(all(article_scores >= 0 & article_scores <= 100))

  # Non-article rows should be NA
  non_article_scores <- result$article_score[result$type_classified != "article"]
  expect_true(all(is.na(non_article_scores)))
})

test_that("pg_score_articles handles no articles gracefully", {
  data <- make_test_data() |>
    dplyr::filter(.data$type_classified != "article")
  result <- pg_score_articles(data)

  # Returns data unchanged

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), nrow(data))
})


# =============================================================================
# pg_score_books
# =============================================================================
test_that("pg_score_books adds book_score column", {
  data <- make_test_data()
  result <- pg_score_books(data)

  expect_s3_class(result, "tbl_df")
  expect_true("book_score" %in% names(result))

  book_scores <- result$book_score[result$type_classified %in% c("book", "book_chapter")]
  expect_true(all(!is.na(book_scores)))
  expect_true(all(book_scores >= 0 & book_scores <= 100))
})


# =============================================================================
# pg_score_seminars
# =============================================================================
test_that("pg_score_seminars adds seminar_score column", {
  data <- make_test_data()
  result <- pg_score_seminars(data)

  expect_s3_class(result, "tbl_df")
  expect_true("seminar_score" %in% names(result))

  sem_scores <- result$seminar_score[result$type_classified %in% c("seminar", "conference")]
  expect_true(all(!is.na(sem_scores)))
})


# =============================================================================
# pg_score_supervision
# =============================================================================
test_that("pg_score_supervision adds supervision_score column", {
  data <- make_test_data()
  result <- pg_score_supervision(data)

  expect_s3_class(result, "tbl_df")
  expect_true("supervision_score" %in% names(result))
})


# =============================================================================
# pg_score_projects
# =============================================================================
test_that("pg_score_projects adds project_score column", {
  data <- make_test_data()
  result <- pg_score_projects(data)

  expect_s3_class(result, "tbl_df")
  expect_true("project_score" %in% names(result))
})


# =============================================================================
# pg_score_recognition
# =============================================================================
test_that("pg_score_recognition adds recognition_score column", {
  data <- make_test_data()
  result <- pg_score_recognition(data)

  expect_s3_class(result, "tbl_df")
  expect_true("recognition_score" %in% names(result))
})


# =============================================================================
# pg_compute_sii
# =============================================================================
test_that("pg_compute_sii returns full SII structure", {
  data <- make_test_data()
  result <- pg_compute_sii(data)

  expect_type(result, "list")
  expect_true("sii" %in% names(result))
  expect_true("dimensions" %in% names(result))
  expect_true("metadata" %in% names(result))

  # SII is numeric 0-100
  expect_true(is.numeric(result$sii))
  expect_true(result$sii >= 0 && result$sii <= 100)

  # Dimensions is a data frame with expected columns
  dims <- result$dimensions
  expect_s3_class(dims, "data.frame")
  expect_true(all(c("dimension", "score", "weight", "label_fr", "label_en") %in%
                    names(dims)))
  expect_equal(nrow(dims), 6L)

  # Metadata includes weights
  expect_true("weights" %in% names(result$metadata))
})

test_that("pg_compute_sii handles empty data", {
  data <- make_test_data() |> dplyr::slice(0)
  result <- pg_compute_sii(data)

  expect_true(is.numeric(result$sii))
  expect_equal(result$sii, 0)
})

test_that("pg_compute_sii respects custom weights", {
  data <- make_test_data()
  w <- c(PIS = 1.0, BIS = 0.0, KDS = 0.0, SS = 0.0, PFS = 0.0, RS = 0.0)
  result <- pg_compute_sii(data, weights = w)

  # SII should equal the PIS dimension score since it has weight 1.0
  pis_score <- result$dimensions$score[result$dimensions$dimension == "PIS"]
  expect_equal(result$sii, round(pis_score, 1), tolerance = 0.1)
})


# =============================================================================
# pg_sii_card
# =============================================================================
test_that("pg_sii_card returns valid HTML string", {
  data <- make_test_data()
  sii_result <- pg_compute_sii(data)
  html <- pg_sii_card(sii_result, lang = "fr")

  expect_type(html, "character")
  expect_true(nchar(html) > 100)
  expect_true(grepl("pg-sii-card", html, fixed = TRUE))
  expect_true(grepl("pg-sii-score-circle", html, fixed = TRUE))
  expect_true(grepl("pg-sii-dimensions", html, fixed = TRUE))
})

test_that("pg_sii_card returns empty string for NULL dimensions", {
  result <- list(sii = 50, dimensions = NULL)
  html <- pg_sii_card(result)
  expect_equal(html, "")
})


# =============================================================================
# pg_sii_radar
# =============================================================================
test_that("pg_sii_radar returns a ggplot", {
  data <- make_test_data()
  sii_result <- pg_compute_sii(data)
  p <- pg_sii_radar(sii_result)

  expect_s3_class(p, "gg")
})


# =============================================================================
# pg_sii_evolution
# =============================================================================
test_that("pg_sii_evolution returns a ggplot", {
  data <- make_test_data()
  sii_result <- pg_compute_sii(data)
  p <- pg_sii_evolution(sii_result)

  expect_s3_class(p, "gg")
})
