# ── test-viz_articles.R ────────────────────────────────────────────────────────
# Tests for viz_articles.R: pg_wordcloud_articles, pg_timeline_articles,
#                           pg_card_article.
# No external API calls are made in these tests.
# ──────────────────────────────────────────────────────────────────────────────

test_that("pg_wordcloud_articles returns list with plot and widget", {
  skip_on_cran()
  skip_if_not_installed("ggwordcloud")
  skip_if_not_installed("wordcloud2")
  skip_if_not_installed("topicmodels")
  skip_if_not_installed("tidytext")

  set.seed(2024L)

  # Use classified fixture data (which contains articles)
  result <- pg_wordcloud_articles(fixture_classified, n_topics = 2L,
                                   max_words = 30L)

  # Returns a list
  expect_type(result, "list")

  # Has the expected named elements
  expect_true("plot" %in% names(result))
  expect_true("widget" %in% names(result))

  # If articles exist in fixture data, plot should be a ggplot
  n_articles <- sum(
    grepl("article", fixture_classified$type_classified, ignore.case = TRUE)
  )
  if (n_articles > 0L) {
    if (!is.null(result$plot)) {
      expect_s3_class(result$plot, "ggplot")
    }
  }
})


test_that("pg_timeline_articles returns ggplot", {
  skip_on_cran()
  set.seed(2024L)

  result <- pg_timeline_articles(fixture_classified,
                                  color_by = "journal_or_venue")

  expect_s3_class(result, "ggplot")
})


test_that("pg_timeline_articles falls back when color_by column is missing", {
  skip_on_cran()
  set.seed(2024L)

  # Request a column that does not exist -- should fall back to "year"
  result <- suppressWarnings(
    pg_timeline_articles(fixture_classified, color_by = "nonexistent_column")
  )

  expect_s3_class(result, "ggplot")
})


test_that("pg_card_article returns HTML string", {
  # Create a mock article row with some NA values
  mock_article <- tibble::tibble(
    title   = "Randomized Experiments in Development",
    author  = "Duflo, Esther",
    journal = "American Economic Review",
    year    = 2006L,
    doi     = "10.1257/aer.96.5.1"
  )

  # Create a mock narrative with some NA values
  mock_narrative <- tibble::tibble(
    problematique    = "How do randomized experiments improve causal inference?",
    pertinence       = NA_character_,
    resultat         = "RCTs provide robust evidence for policy evaluation.",
    question_ouverte = NA_character_
  )

  result <- pg_card_article(mock_article, mock_narrative)

  # Is a character string
  expect_type(result, "character")
  expect_length(result, 1L)

  # Contains the CSS class / identifier for the card
  expect_match(result, "pg-article-card|border-left.*solid|ARTICLE",
               perl = TRUE)

  # Contains the article title
  expect_match(result, "Randomized Experiments", fixed = TRUE)
})


test_that("pg_card_article handles fully NA narrative gracefully", {
  mock_article <- tibble::tibble(
    title   = "Test Article",
    author  = NA_character_,
    journal = NA_character_,
    year    = NA_integer_,
    doi     = NA_character_
  )

  mock_narrative <- tibble::tibble(
    problematique    = NA_character_,
    pertinence       = NA_character_,
    resultat         = NA_character_,
    question_ouverte = NA_character_
  )

  result <- pg_card_article(mock_article, mock_narrative)

  expect_type(result, "character")
  expect_length(result, 1L)
  # Should still produce valid HTML, not an error
  expect_match(result, "<div", fixed = TRUE)
})
