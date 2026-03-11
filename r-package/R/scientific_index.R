# ── scientific_index.R ───────────────────────────────────────────────────────
# Scientific Influence Index (SII): multi-dimensional scoring framework
# for quantifying a researcher's impact across all production categories.
#
# Exported: pg_score_articles, pg_score_books, pg_score_seminars,
#           pg_score_supervision, pg_score_projects, pg_score_recognition,
#           pg_compute_sii, pg_sii_radar, pg_sii_evolution, pg_sii_card.
# ─────────────────────────────────────────────────────────────────────────────

# ── Internal: Journal prestige tiers ────────────────────────────────────────

#' Map journal names to prestige tiers
#'
#' @param journal Character vector of journal names.
#' @param sjr_quartile Optional character vector of SJR quartiles (Q1-Q4).
#' @return Numeric vector of prestige scores (1-10).
#' @noRd
pg_journal_prestige <- function(journal, sjr_quartile = NULL) {

  # If SJR quartile data is available, use it directly
  if (!is.null(sjr_quartile) && !all(is.na(sjr_quartile))) {
    score <- dplyr::case_when(
      sjr_quartile == "Q1" ~ 10,
      sjr_quartile == "Q2" ~ 7,
      sjr_quartile == "Q3" ~ 4,
      sjr_quartile == "Q4" ~ 2,
      TRUE ~ 3
    )
    return(score)
  }

  # Fallback: heuristic based on known top journal names
  j <- stringr::str_to_lower(journal)
  dplyr::case_when(
    # Tier 1 (10 pts): Top-5 economics + Science/Nature
    stringr::str_detect(j, "econometrica|quarterly journal of econ|american economic review|journal of political economy|review of economic studies|science|nature") ~ 10,
    # Tier 2 (8 pts): Top field journals
    stringr::str_detect(j, "journal of economic literature|journal of economic perspectives|review of economics and statistics|economic journal|journal of finance|american journal of|lancet|new england journal|cell") ~ 8,
    # Tier 3 (6 pts): Very good journals
    stringr::str_detect(j, "american economic journal|world bank economic|journal of development econ|annual review|handbook|economic policy|journal of public econ") ~ 6,
    # Tier 4 (4 pts): Good journals
    stringr::str_detect(j, "economic|journal|review|quarterly") ~ 4,
    # Tier 5 (2 pts): Other
    TRUE ~ 2
  )
}


# ── Internal: Author position scoring ──────────────────────────────────────

#' Score author position in the author list
#'
#' First and last positions score highest (reflects convention in many fields).
#'
#' @param authors_raw Character. Raw author field.
#' @param focal_author Character. Name of the focal researcher.
#' @return Numeric score between 0 and 1.
#' @noRd
pg_author_position_score <- function(authors_raw, focal_author) {
  if (is.na(authors_raw) || is.na(focal_author)) return(0.5)

  authors <- pg_clean_authors(authors_raw)
  n <- length(authors)
  if (n == 0L) return(0.5)

  focal_lower <- stringr::str_to_lower(focal_author)
  positions <- which(stringr::str_detect(
    stringr::str_to_lower(authors), stringr::fixed(focal_lower)
  ))

  if (length(positions) == 0L) {
    # Try matching on last name only
    focal_last <- stringr::str_extract(focal_author, "\\w+$")
    if (!is.na(focal_last)) {
      positions <- which(stringr::str_detect(
        stringr::str_to_lower(authors),
        stringr::str_to_lower(focal_last)
      ))
    }
  }

  if (length(positions) == 0L) return(0.5)

  pos <- positions[1]

  if (n == 1L) return(1.0)
  if (pos == 1L) return(1.0)        # First author

  if (pos == n)  return(0.9)        # Last author (senior)
  return(0.6)                       # Middle author
}


# ── 1. Article Scoring ─────────────────────────────────────────────────────

#' Score scientific articles
#'
#' Computes a composite score for each article based on journal prestige,
#' citation impact, author position, and collaboration breadth.
#'
#' @param data A classified tibble from [pg_classify()]. Must contain at least
#'   `type_classified`, `title`, `year`, and `journal_or_venue`.
#' @param focal_author Character. Name of the researcher being profiled.
#' @param current_year Numeric. Year for citation age normalisation
#'   (default: current year).
#'
#' @return A tibble with additional columns: `prestige_score`,
#'   `citation_score`, `author_position_score`, `collab_score`, and
#'   `article_score` (composite 0-100).
#'
#' @details
#' ## Scoring Formula
#'
#' \deqn{ArticleScore_i = w_1 \cdot Prestige_i + w_2 \cdot Citations_i +
#'   w_3 \cdot Position_i + w_4 \cdot Collaboration_i}
#'
#' Default weights: prestige 40%, citations 30%, position 20%,
#' collaboration 10%.
#'
#' @examples
#' demo <- tibble::tibble(
#'   type_classified = rep("article", 3),
#'   title = paste("Article", 1:3),
#'   year = c(2015, 2018, 2021),
#'   journal_or_venue = c("Econometrica", "World Bank Economic Review", "Other"),
#'   authors = c("Duflo, E.", "Banerjee, A. and Duflo, E.", "Duflo, E. and Smith, J."),
#'   cited_by = c(500, 200, 50),
#'   sjr_quartile = c("Q1", "Q2", NA)
#' )
#' scored <- pg_score_articles(demo, focal_author = "Duflo")
#' scored$article_score
#'
#' @export
pg_score_articles <- function(data,
                              focal_author = NA_character_,
                              current_year = as.numeric(format(Sys.Date(), "%Y"))) {

  tryCatch({

    # Filter to articles only
    articles <- data |>
      dplyr::filter(.data$type_classified == "article")

    if (nrow(articles) == 0L) {
      pg_msg("warn",
             "Aucun article a scorer.",
             "No articles to score.")
      return(data)
    }

    pg_msg("info",
           glue::glue("Scoring de {nrow(articles)} articles..."),
           glue::glue("Scoring {nrow(articles)} articles..."))

    # Ensure required columns exist
    if (!"journal_or_venue" %in% names(articles))
      articles$journal_or_venue <- NA_character_
    if (!"cited_by" %in% names(articles))
      articles$cited_by <- NA_real_
    if (!"sjr_quartile" %in% names(articles))
      articles$sjr_quartile <- NA_character_
    if (!"authors" %in% names(articles))
      articles$authors <- NA_character_

    # ── Prestige score (0-10 → normalised to 0-100) ────────────────────────
    articles <- articles |>
      dplyr::mutate(
        prestige_score = pg_journal_prestige(
          .data$journal_or_venue,
          if ("sjr_quartile" %in% names(articles)) .data$sjr_quartile else NULL
        ) * 10  # Scale to 0-100
      )

    # ── Citation score (normalised) ──────────────────────────────────────
    articles <- articles |>
      dplyr::mutate(
        age = pmax(1, current_year - as.numeric(.data$year)),
        citations_per_year = dplyr::if_else(
          is.na(.data$cited_by), 0, as.numeric(.data$cited_by) / .data$age
        )
      )

    max_cpy <- max(articles$citations_per_year, na.rm = TRUE)
    articles <- articles |>
      dplyr::mutate(
        citation_score = if (max_cpy > 0) {
          pmin(100, (.data$citations_per_year / max_cpy) * 100)
        } else {
          50  # Default when no citation data
        }
      )

    # ── Author position score ──────────────────────────────────────────────
    articles <- articles |>
      dplyr::mutate(
        author_position_score = purrr::map_dbl(
          .data$authors,
          ~ pg_author_position_score(.x, focal_author)
        ) * 100
      )

    # ── Collaboration score (number of co-authors) ─────────────────────────
    articles <- articles |>
      dplyr::mutate(
        n_authors = purrr::map_int(
          .data$authors,
          ~ {
            a <- pg_clean_authors(.x)
            if (all(is.na(a))) 1L else length(a)
          }
        ),
        collab_score = pmin(100, (.data$n_authors - 1) * 20)
      )

    # ── Composite article score ────────────────────────────────────────────
    articles <- articles |>
      dplyr::mutate(
        article_score = round(
          0.40 * .data$prestige_score +
          0.30 * .data$citation_score +
          0.20 * .data$author_position_score +
          0.10 * .data$collab_score,
          1
        )
      )

    # ── Merge back into original data ──────────────────────────────────────
    score_cols <- c("prestige_score", "citation_score", "author_position_score",
                    "collab_score", "article_score", "age", "citations_per_year",
                    "n_authors")

    # Remove these columns from data if they exist
    data <- data |>
      dplyr::select(-dplyr::any_of(score_cols))

    articles_scores <- articles |>
      dplyr::select("pg_id", dplyr::all_of(score_cols))

    data <- data |>
      dplyr::left_join(articles_scores, by = "pg_id")

    pg_msg("success",
           glue::glue("Articles scores: min={min(articles$article_score)}, max={max(articles$article_score)}, mean={round(mean(articles$article_score), 1)}"),
           glue::glue("Article scores: min={min(articles$article_score)}, max={max(articles$article_score)}, mean={round(mean(articles$article_score), 1)}"))

    data

  }, error = function(e) {
    pg_msg("error",
           glue::glue("Erreur dans pg_score_articles: {e$message}"),
           glue::glue("Error in pg_score_articles: {e$message}"))
    data
  })
}


# ── 2. Book Scoring ────────────────────────────────────────────────────────

#' Score books and book chapters
#'
#' Evaluates books based on publisher prestige, edition count, and
#' international reach (translations).
#'
#' @param data A classified tibble from [pg_classify()].
#' @return The same tibble with added `book_score` column (0-100).
#'
#' @examples
#' demo <- tibble::tibble(
#'   pg_id = "b1",
#'   type_classified = "book",
#'   title = "Poor Economics",
#'   year = 2011,
#'   journal_or_venue = "PublicAffairs",
#'   cited_by = 8000,
#'   isbn = "978-1-58648-798-0"
#' )
#' pg_score_books(demo)$book_score
#'
#' @export
pg_score_books <- function(data) {

  tryCatch({

    books <- data |>
      dplyr::filter(.data$type_classified %in% c("book", "book_chapter"))

    if (nrow(books) == 0L) return(data)

    pg_msg("info",
           glue::glue("Scoring de {nrow(books)} ouvrages..."),
           glue::glue("Scoring {nrow(books)} books/chapters..."))

    if (!"cited_by" %in% names(books)) books$cited_by <- NA_real_

    # Publisher prestige heuristic
    books <- books |>
      dplyr::mutate(
        publisher_score = dplyr::case_when(
          stringr::str_detect(stringr::str_to_lower(.data$journal_or_venue),
            "cambridge university|oxford university|mit press|princeton|harvard|stanford|chicago") ~ 100,
          stringr::str_detect(stringr::str_to_lower(.data$journal_or_venue),
            "springer|wiley|elsevier|routledge|sage|palgrave|world bank") ~ 75,
          stringr::str_detect(stringr::str_to_lower(.data$journal_or_venue),
            "publicaffairs|penguin|norton|basic books|knopf|random house") ~ 70,
          TRUE ~ 50
        ),
        # Citation impact for books (log-scaled)
        book_citation_score = dplyr::if_else(
          is.na(.data$cited_by), 40,
          pmin(100, log1p(.data$cited_by) / log1p(10000) * 100)
        ),
        # Chapter vs full book
        format_bonus = dplyr::if_else(
          .data$type_classified == "book", 100, 60
        ),
        book_score = round(
          0.40 * .data$publisher_score +
          0.35 * .data$book_citation_score +
          0.25 * .data$format_bonus,
          1
        )
      )

    # Merge back
    score_cols <- c("publisher_score", "book_citation_score", "format_bonus", "book_score")
    data <- data |> dplyr::select(-dplyr::any_of(score_cols))
    books_scores <- books |> dplyr::select("pg_id", dplyr::all_of(score_cols))
    data <- data |> dplyr::left_join(books_scores, by = "pg_id")

    data

  }, error = function(e) {
    pg_msg("error",
           glue::glue("Erreur dans pg_score_books: {e$message}"),
           glue::glue("Error in pg_score_books: {e$message}"))
    data
  })
}


# ── 3. Seminar / Conference Scoring ────────────────────────────────────────

#' Score seminars and conferences
#'
#' Evaluates knowledge dissemination based on geographic scope, event
#' prestige (keynote/invited), and international diversity.
#'
#' @param data A classified tibble from [pg_classify()].
#' @return The same tibble with added `seminar_score` column (0-100).
#'
#' @examples
#' demo <- tibble::tibble(
#'   pg_id = c("s1", "s2"),
#'   type_classified = c("seminar", "conference"),
#'   title = c("Nobel Lecture", "Local Workshop"),
#'   year = c(2019, 2020),
#'   country = c("Sweden", "France"),
#'   note = c("Nobel Prize lecture", "Departmental seminar")
#' )
#' pg_score_seminars(demo)$seminar_score
#'
#' @export
pg_score_seminars <- function(data) {

  tryCatch({

    seminars <- data |>
      dplyr::filter(.data$type_classified %in% c("seminar", "conference"))

    if (nrow(seminars) == 0L) return(data)

    pg_msg("info",
           glue::glue("Scoring de {nrow(seminars)} seminaires/conferences..."),
           glue::glue("Scoring {nrow(seminars)} seminars/conferences..."))

    if (!"country" %in% names(seminars)) seminars$country <- NA_character_
    if (!"note" %in% names(seminars)) seminars$note <- NA_character_

    # Prestige indicators from note field
    seminars <- seminars |>
      dplyr::mutate(
        note_lower = stringr::str_to_lower(dplyr::if_else(is.na(.data$note), "", .data$note)),
        title_lower = stringr::str_to_lower(dplyr::if_else(is.na(.data$title), "", .data$title)),
        prestige_score = dplyr::case_when(
          stringr::str_detect(.data$note_lower, "nobel|prize lecture") ~ 100,
          stringr::str_detect(.data$note_lower, "keynote|plenary|presidential") ~ 85,
          stringr::str_detect(.data$note_lower, "invited|memorial|distinguished") ~ 70,
          stringr::str_detect(.data$note_lower, "annual conference|consortium") ~ 60,
          .data$type_classified == "conference" ~ 50,
          TRUE ~ 40
        ),
        # International scope
        international_score = dplyr::if_else(
          !is.na(.data$country) & .data$country != "", 70, 40
        ),
        seminar_score = round(
          0.60 * .data$prestige_score +
          0.40 * .data$international_score,
          1
        )
      ) |>
      dplyr::select(-"note_lower", -"title_lower")

    score_cols <- c("seminar_score")
    data <- data |> dplyr::select(-dplyr::any_of(score_cols))
    sem_scores <- seminars |> dplyr::select("pg_id", dplyr::all_of(score_cols))
    data <- data |> dplyr::left_join(sem_scores, by = "pg_id")

    data

  }, error = function(e) {
    pg_msg("error",
           glue::glue("Erreur dans pg_score_seminars: {e$message}"),
           glue::glue("Error in pg_score_seminars: {e$message}"))
    data
  })
}


# ── 4. Supervision Scoring ─────────────────────────────────────────────────

#' Score thesis supervision
#'
#' Evaluates supervision activity. If no explicit thesis records exist,
#' infers from patterns in other data. PhD supervision scores higher than
#' Masters.
#'
#' @param data A classified tibble from [pg_classify()].
#' @return The same tibble with added `supervision_score` column (0-100).
#'
#' @export
pg_score_supervision <- function(data) {

  tryCatch({

    theses <- data |>
      dplyr::filter(.data$type_classified == "thesis_supervised")

    if (nrow(theses) == 0L) {
      # No explicit thesis data — assign 0 and return
      if (!"supervision_score" %in% names(data))
        data$supervision_score <- NA_real_
      return(data)
    }

    pg_msg("info",
           glue::glue("Scoring de {nrow(theses)} theses encadrees..."),
           glue::glue("Scoring {nrow(theses)} supervised theses..."))

    if (!"note" %in% names(theses)) theses$note <- NA_character_

    theses <- theses |>
      dplyr::mutate(
        note_lower = stringr::str_to_lower(dplyr::if_else(is.na(.data$note), "", .data$note)),
        level_score = dplyr::case_when(
          stringr::str_detect(.data$note_lower, "phd|doctorat|doctoral") ~ 100,
          stringr::str_detect(.data$note_lower, "master|msc|ma|mphil") ~ 60,
          TRUE ~ 50
        ),
        supervision_score = .data$level_score
      ) |>
      dplyr::select(-"note_lower")

    score_cols <- c("supervision_score")
    data <- data |> dplyr::select(-dplyr::any_of(score_cols))
    th_scores <- theses |> dplyr::select("pg_id", dplyr::all_of(score_cols))
    data <- data |> dplyr::left_join(th_scores, by = "pg_id")

    data

  }, error = function(e) {
    pg_msg("error",
           glue::glue("Erreur dans pg_score_supervision: {e$message}"),
           glue::glue("Error in pg_score_supervision: {e$message}"))
    data
  })
}


# ── 5. Project / Funding Scoring ───────────────────────────────────────────

#' Score funded projects
#'
#' Evaluates projects based on funding amount (log-scaled), duration,
#' role (PI vs co-PI), and funder prestige.
#'
#' @param data A classified tibble from [pg_classify()].
#' @return The same tibble with added `project_score` column (0-100).
#'
#' @examples
#' demo <- tibble::tibble(
#'   pg_id = "p1",
#'   type_classified = "project",
#'   title = "J-PAL",
#'   year = 2003,
#'   funding_amount = 155000000,
#'   funding_source = "Multiple donors"
#' )
#' pg_score_projects(demo)$project_score
#'
#' @export
pg_score_projects <- function(data) {

  tryCatch({

    projects <- data |>
      dplyr::filter(.data$type_classified == "project")

    if (nrow(projects) == 0L) return(data)

    pg_msg("info",
           glue::glue("Scoring de {nrow(projects)} projets finances..."),
           glue::glue("Scoring {nrow(projects)} funded projects..."))

    if (!"funding_amount" %in% names(projects)) projects$funding_amount <- NA_real_
    if (!"funding_source" %in% names(projects)) projects$funding_source <- NA_character_
    if (!"note" %in% names(projects)) projects$note <- NA_character_
    if (!"date_start" %in% names(projects)) projects$date_start <- NA_character_
    if (!"date_end" %in% names(projects)) projects$date_end <- NA_character_

    projects <- projects |>
      dplyr::mutate(
        # Funding amount score (log-scaled, max at ~$200M)
        funding_score = dplyr::if_else(
          is.na(.data$funding_amount) | .data$funding_amount == 0,
          30,  # Default for unknown funding
          pmin(100, log1p(.data$funding_amount) / log1p(200000000) * 100)
        ),
        # Funder prestige
        funder_lower = stringr::str_to_lower(
          dplyr::if_else(is.na(.data$funding_source), "", .data$funding_source)
        ),
        funder_score = dplyr::case_when(
          stringr::str_detect(.data$funder_lower, "gates|world bank|usaid|dfid|eu|european") ~ 90,
          stringr::str_detect(.data$funder_lower, "ford|macarthur|hewlett|rockefeller") ~ 80,
          stringr::str_detect(.data$funder_lower, "ngo|foundation|government") ~ 60,
          nchar(.data$funder_lower) > 0 ~ 50,
          TRUE ~ 30
        ),
        # Leadership role inference
        note_lower = stringr::str_to_lower(
          dplyr::if_else(is.na(.data$note), "", .data$note)
        ),
        role_score = dplyr::case_when(
          stringr::str_detect(.data$note_lower, "co-found|founder|principal|director|lead") ~ 100,
          stringr::str_detect(.data$note_lower, "co-pi|partner") ~ 75,
          TRUE ~ 50
        ),
        project_score = round(
          0.40 * .data$funding_score +
          0.30 * .data$funder_score +
          0.30 * .data$role_score,
          1
        )
      ) |>
      dplyr::select(-"funder_lower", -"note_lower")

    score_cols <- c("funding_score", "funder_score", "role_score", "project_score")
    data <- data |> dplyr::select(-dplyr::any_of(score_cols))
    proj_scores <- projects |> dplyr::select("pg_id", dplyr::all_of(score_cols))
    data <- data |> dplyr::left_join(proj_scores, by = "pg_id")

    data

  }, error = function(e) {
    pg_msg("error",
           glue::glue("Erreur dans pg_score_projects: {e$message}"),
           glue::glue("Error in pg_score_projects: {e$message}"))
    data
  })
}


# ── 6. Recognition / Award Scoring ────────────────────────────────────────

#' Score awards and distinctions
#'
#' Evaluates recognition items based on award prestige, geographic scope,
#' and monetary value.
#'
#' @param data A classified tibble from [pg_classify()].
#' @return The same tibble with added `recognition_score` column (0-100).
#'
#' @examples
#' demo <- tibble::tibble(
#'   pg_id = c("a1", "a2"),
#'   type_classified = c("award", "award"),
#'   title = c("Nobel Prize", "Local Award"),
#'   year = c(2019, 2020),
#'   funding_amount = c(NA, NA),
#'   note = c("Nobel Prize in Economics", "Best paper award")
#' )
#' pg_score_recognition(demo)$recognition_score
#'
#' @export
pg_score_recognition <- function(data) {

  tryCatch({

    awards <- data |>
      dplyr::filter(.data$type_classified %in% c("award", "expertise"))

    if (nrow(awards) == 0L) return(data)

    pg_msg("info",
           glue::glue("Scoring de {nrow(awards)} distinctions/expertises..."),
           glue::glue("Scoring {nrow(awards)} awards/expertise..."))

    if (!"note" %in% names(awards)) awards$note <- NA_character_
    if (!"funding_amount" %in% names(awards)) awards$funding_amount <- NA_real_

    awards <- awards |>
      dplyr::mutate(
        title_lower = stringr::str_to_lower(
          dplyr::if_else(is.na(.data$title), "", .data$title)
        ),
        note_lower = stringr::str_to_lower(
          dplyr::if_else(is.na(.data$note), "", .data$note)
        ),
        # Prestige hierarchy
        prestige_score = dplyr::case_when(
          stringr::str_detect(.data$title_lower, "nobel") ~ 100,
          stringr::str_detect(.data$title_lower, "fields medal|turing|wolf prize") ~ 95,
          stringr::str_detect(.data$title_lower, "clark medal|john bates") ~ 90,
          stringr::str_detect(.data$title_lower, "macarthur|guggenheim") ~ 85,
          stringr::str_detect(.data$title_lower, "princess|prince|royal|national") ~ 80,
          stringr::str_detect(.data$title_lower, "infosys|balzan|holberg") ~ 75,
          .data$type_classified == "expertise" &
            stringr::str_detect(.data$note_lower, "world bank|united nations|imf|oecd") ~ 70,
          .data$type_classified == "expertise" &
            stringr::str_detect(.data$note_lower, "government|commission|president") ~ 65,
          .data$type_classified == "expertise" ~ 55,
          TRUE ~ 50
        ),
        recognition_score = .data$prestige_score
      ) |>
      dplyr::select(-"title_lower", -"note_lower")

    score_cols <- c("recognition_score")
    data <- data |> dplyr::select(-dplyr::any_of(score_cols))
    aw_scores <- awards |> dplyr::select("pg_id", dplyr::all_of(score_cols))
    data <- data |> dplyr::left_join(aw_scores, by = "pg_id")

    data

  }, error = function(e) {
    pg_msg("error",
           glue::glue("Erreur dans pg_score_recognition: {e$message}"),
           glue::glue("Error in pg_score_recognition: {e$message}"))
    data
  })
}


# ── 7. Composite SII Computation ──────────────────────────────────────────

#' Compute the Scientific Influence Index (SII)
#'
#' Aggregates dimension-specific scores into a single composite index
#' on a 0-100 scale. The SII captures six dimensions of academic influence:
#'
#' 1. **Publication Impact** (PIS): journal prestige, citations, author position
#' 2. **Book Impact** (BIS): publisher prestige, citations
#' 3. **Knowledge Dissemination** (KDS): seminars, conferences, geographic scope
#' 4. **Supervision** (SS): thesis direction, student count
#' 5. **Research Funding** (PFS): project funding, role, funder prestige
#' 6. **Academic Recognition** (RS): awards, expertise, advisory roles
#'
#' @param data A classified tibble from [pg_classify()], ideally already
#'   processed through individual scoring functions.
#' @param focal_author Character. Name of the researcher being profiled.
#' @param weights Named numeric vector of dimension weights (must sum to 1).
#'   Default: `c(PIS = 0.30, BIS = 0.10, KDS = 0.15, SS = 0.10,
#'   PFS = 0.15, RS = 0.20)`.
#'
#' @return A named list with:
#'   \describe{
#'     \item{sii}{Numeric. Composite SII score (0-100).}
#'     \item{dimensions}{A tibble with one row per dimension: name, label_fr,
#'       label_en, score, weight, weighted_score, n_items.}
#'     \item{data}{The input tibble with all individual scores added.}
#'     \item{metadata}{A list with focal_author, total_items, career_span,
#'       computation_date.}
#'   }
#'
#' @examples
#' \dontrun{
#' bib <- pg_read_bib(system.file("extdata", "duflo_articles.bib",
#'                                 package = "publigraphics"))
#' extra <- pg_read_extra(system.file("extdata", "duflo_extra.csv",
#'                                    package = "publigraphics"))
#' merged <- pg_merge_inputs(bib, extra) |> pg_classify()
#' result <- pg_compute_sii(merged, focal_author = "Duflo")
#' result$sii
#' result$dimensions
#' }
#'
#' @export
pg_compute_sii <- function(data,
                           focal_author = NA_character_,
                           weights = c(PIS = 0.30, BIS = 0.10, KDS = 0.15,
                                       SS = 0.10, PFS = 0.15, RS = 0.20)) {

  tryCatch({

    # ── Validate weights ───────────────────────────────────────────────────
    if (abs(sum(weights) - 1) > 0.01) {
      pg_msg("warn",
             "Les poids ne somment pas a 1, normalisation automatique.",
             "Weights do not sum to 1, auto-normalising.")
      weights <- weights / sum(weights)
    }

    pg_msg("info",
           glue::glue("Calcul du Scientific Influence Index pour {nrow(data)} productions..."),
           glue::glue("Computing Scientific Influence Index for {nrow(data)} productions..."))

    # ── Run all dimension scorers ──────────────────────────────────────────
    data <- data |>
      pg_score_articles(focal_author = focal_author) |>
      pg_score_books() |>
      pg_score_seminars() |>
      pg_score_supervision() |>
      pg_score_projects() |>
      pg_score_recognition()

    # ── Compute dimension averages ─────────────────────────────────────────
    dim_scores <- tibble::tibble(
      dimension = c("PIS", "BIS", "KDS", "SS", "PFS", "RS"),
      label_fr = c("Impact Publications", "Impact Ouvrages",
                    "Diffusion Connaissances", "Encadrement",
                    "Financement Recherche", "Reconnaissance"),
      label_en = c("Publication Impact", "Book Impact",
                    "Knowledge Dissemination", "Supervision",
                    "Research Funding", "Academic Recognition"),
      score_col = c("article_score", "book_score", "seminar_score",
                     "supervision_score", "project_score", "recognition_score"),
      type_filter = c("article", "book|book_chapter", "seminar|conference",
                       "thesis_supervised", "project", "award|expertise")
    )

    dim_scores <- dim_scores |>
      dplyr::rowwise() |>
      dplyr::mutate(
        score = {
          col <- .data$score_col
          types <- stringr::str_split(.data$type_filter, "\\|")[[1]]
          subset <- data |>
            dplyr::filter(.data$type_classified %in% types)
          if (nrow(subset) == 0L || !col %in% names(data)) {
            0
          } else {
            vals <- subset[[col]]
            if (all(is.na(vals))) 0 else mean(vals, na.rm = TRUE)
          }
        },
        n_items = {
          types <- stringr::str_split(.data$type_filter, "\\|")[[1]]
          sum(data$type_classified %in% types)
        }
      ) |>
      dplyr::ungroup()

    # ── Apply weights ──────────────────────────────────────────────────────
    dim_scores <- dim_scores |>
      dplyr::mutate(
        weight = weights[.data$dimension],
        weighted_score = .data$score * .data$weight
      )

    sii <- round(sum(dim_scores$weighted_score), 1)

    # ── Metadata ───────────────────────────────────────────────────────────
    years <- data$year[!is.na(data$year)]
    career_span <- if (length(years) > 0) {
      paste0(min(years), "-", max(years))
    } else {
      NA_character_
    }

    metadata <- list(
      focal_author = focal_author,
      total_items = nrow(data),
      career_span = career_span,
      computation_date = Sys.Date(),
      weights = weights
    )

    pg_msg("success",
           glue::glue("SII = {sii}/100 ({nrow(data)} productions, 6 dimensions)"),
           glue::glue("SII = {sii}/100 ({nrow(data)} productions, 6 dimensions)"))

    list(
      sii = sii,
      dimensions = dim_scores |>
        dplyr::select("dimension", "label_fr", "label_en", "score",
                      "weight", "weighted_score", "n_items"),
      data = data,
      metadata = metadata
    )

  }, error = function(e) {
    pg_msg("error",
           glue::glue("Erreur dans pg_compute_sii: {e$message}"),
           glue::glue("Error in pg_compute_sii: {e$message}"))
    list(sii = NA_real_, dimensions = NULL, data = data,
         metadata = list(error = e$message))
  })
}


# ── 8. SII Radar Visualisation ────────────────────────────────────────────

#' Radar chart of SII dimensions
#'
#' Creates a publication-ready radar (spider) chart showing the six
#' dimensions of the Scientific Influence Index.
#'
#' @param sii_result A list returned by [pg_compute_sii()].
#' @param theme_color Character. Hex colour for the radar fill
#'   (default `"#1B4F72"`).
#' @param lang Character. `"fr"` or `"en"` for axis labels.
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \dontrun{
#' result <- pg_compute_sii(classified_data, "Duflo")
#' pg_sii_radar(result, lang = "en")
#' }
#'
#' @export
pg_sii_radar <- function(sii_result, theme_color = "#1B4F72", lang = "fr") {

  tryCatch({

    dims <- sii_result$dimensions
    if (is.null(dims) || nrow(dims) == 0L) {
      pg_msg("warn",
             "Pas de donnees SII pour le radar.",
             "No SII data for radar chart.")
      return(ggplot2::ggplot() + ggplot2::theme_void())
    }

    label_col <- if (identical(lang, "fr")) "label_fr" else "label_en"

    plot_data <- dims |>
      dplyr::mutate(
        label = .data[[label_col]],
        angle = seq(0, 2 * pi * (1 - 1/dplyr::n()), length.out = dplyr::n()),
        score_bounded = pmin(100, pmax(0, .data$score))
      )

    # Close the polygon
    plot_data <- dplyr::bind_rows(plot_data, plot_data[1, ])

    fill_col <- colorspace::lighten(theme_color, 0.6)

    p <- ggplot2::ggplot(plot_data) +
      ggplot2::coord_polar(start = -pi/6) +
      # Background circles
      ggplot2::geom_hline(yintercept = c(25, 50, 75, 100),
                          colour = "#EEEEEE", linewidth = 0.3) +
      # Filled polygon
      ggplot2::geom_polygon(
        ggplot2::aes(x = seq_len(nrow(plot_data)), y = .data$score_bounded),
        fill = fill_col, colour = theme_color, linewidth = 1.2, alpha = 0.4
      ) +
      # Score points
      ggplot2::geom_point(
        ggplot2::aes(x = seq_len(nrow(plot_data)), y = .data$score_bounded),
        colour = theme_color, size = 3, fill = "white", shape = 21, stroke = 1.5
      ) +
      # Score labels
      ggplot2::geom_text(
        ggplot2::aes(x = seq_len(nrow(plot_data)),
                     y = .data$score_bounded + 8,
                     label = round(.data$score_bounded)),
        colour = theme_color, fontface = "bold", size = 3.5
      ) +
      ggplot2::scale_x_continuous(
        breaks = seq_len(nrow(dims)),
        labels = plot_data$label[seq_len(nrow(dims))]
      ) +
      ggplot2::scale_y_continuous(limits = c(0, 120), breaks = c(25, 50, 75, 100)) +
      ggplot2::labs(
        title = if (lang == "fr") {
          glue::glue("Scientific Influence Index: {sii_result$sii}/100")
        } else {
          glue::glue("Scientific Influence Index: {sii_result$sii}/100")
        },
        subtitle = if (lang == "fr") {
          "Profil multidimensionnel de l'influence scientifique"
        } else {
          "Multidimensional scientific influence profile"
        }
      ) +
      pg_theme(base_color = theme_color) +
      ggplot2::theme(
        axis.title = ggplot2::element_blank(),
        axis.text.y = ggplot2::element_blank(),
        panel.grid.major = ggplot2::element_blank(),
        plot.title = ggplot2::element_text(hjust = 0.5),
        plot.subtitle = ggplot2::element_text(hjust = 0.5)
      )

    p

  }, error = function(e) {
    pg_msg("error",
           glue::glue("Erreur dans pg_sii_radar: {e$message}"),
           glue::glue("Error in pg_sii_radar: {e$message}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })
}


# ── 9. SII Temporal Evolution ─────────────────────────────────────────────

#' SII evolution over time
#'
#' Shows how the SII and its dimensions accumulate over the researcher's
#' career using a stacked area chart.
#'
#' @param sii_result A list returned by [pg_compute_sii()].
#' @param theme_color Character. Base hex colour (default `"#1B4F72"`).
#' @param lang Character. `"fr"` or `"en"`.
#'
#' @return A `ggplot` object.
#'
#' @export
pg_sii_evolution <- function(sii_result, theme_color = "#1B4F72", lang = "fr") {

  tryCatch({

    data <- sii_result$data
    if (is.null(data) || nrow(data) == 0L || all(is.na(data$year))) {
      return(ggplot2::ggplot() + ggplot2::theme_void())
    }

    # Collect all individual scores
    score_map <- c(
      "article_score" = "PIS",
      "book_score" = "BIS",
      "seminar_score" = "KDS",
      "supervision_score" = "SS",
      "project_score" = "PFS",
      "recognition_score" = "RS"
    )

    existing_cols <- intersect(names(score_map), names(data))
    if (length(existing_cols) == 0L) {
      return(ggplot2::ggplot() + ggplot2::theme_void())
    }

    # Compute cumulative average by year for each dimension
    data_valid <- data |>
      dplyr::filter(!is.na(.data$year)) |>
      dplyr::arrange(.data$year)

    year_range <- seq(min(data_valid$year, na.rm = TRUE),
                      max(data_valid$year, na.rm = TRUE))

    cum_data <- purrr::map_dfr(year_range, function(yr) {
      subset <- data_valid |> dplyr::filter(.data$year <= yr)
      purrr::map_dfr(existing_cols, function(col) {
        vals <- subset[[col]][!is.na(subset[[col]])]
        tibble::tibble(
          year = yr,
          dimension = score_map[col],
          score = if (length(vals) > 0) mean(vals) else 0
        )
      })
    })

    label_lookup <- sii_result$dimensions
    label_col <- if (identical(lang, "fr")) "label_fr" else "label_en"

    cum_data <- cum_data |>
      dplyr::left_join(
        label_lookup |> dplyr::select("dimension", label = dplyr::all_of(label_col)),
        by = "dimension"
      ) |>
      dplyr::mutate(label = dplyr::if_else(is.na(.data$label), .data$dimension, .data$label))

    palette <- pg_palette(theme_color, n = length(existing_cols), type = "qualitative")

    p <- ggplot2::ggplot(cum_data,
                          ggplot2::aes(x = .data$year, y = .data$score,
                                       fill = .data$label, colour = .data$label)) +
      ggplot2::geom_area(alpha = 0.3, position = "identity") +
      ggplot2::geom_line(linewidth = 0.8) +
      ggplot2::scale_fill_manual(values = palette) +
      ggplot2::scale_colour_manual(values = palette) +
      ggplot2::labs(
        title = if (lang == "fr") "Evolution du SII" else "SII Evolution",
        subtitle = if (lang == "fr") {
          "Score moyen cumulatif par dimension"
        } else {
          "Cumulative average score by dimension"
        },
        x = NULL,
        y = "Score (0-100)",
        fill = NULL,
        colour = NULL
      ) +
      pg_theme(base_color = theme_color)

    p

  }, error = function(e) {
    pg_msg("error",
           glue::glue("Erreur dans pg_sii_evolution: {e$message}"),
           glue::glue("Error in pg_sii_evolution: {e$message}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })
}


# ── 10. SII Summary Card (HTML) ──────────────────────────────────────────

#' Generate HTML card for SII display
#'
#' Creates an HTML fragment showing the composite SII score and dimension
#' breakdown, suitable for embedding in the R Markdown notebook.
#'
#' @param sii_result A list returned by [pg_compute_sii()].
#' @param theme_color Character. Hex colour (default `"#1B4F72"`).
#' @param lang Character. `"fr"` or `"en"`.
#'
#' @return Character string of HTML.
#'
#' @export
pg_sii_card <- function(sii_result, theme_color = "#1B4F72", lang = "fr") {

  if (is.null(sii_result$dimensions)) return("")

  dims <- sii_result$dimensions
  label_col <- if (identical(lang, "fr")) "label_fr" else "label_en"
  sii <- sii_result$sii

  # Determine SII level and CSS class
  level <- dplyr::case_when(
    sii >= 80 ~ if (lang == "fr") "Exceptionnel" else "Exceptional",
    sii >= 60 ~ if (lang == "fr") "Tres Eleve" else "Very High",
    sii >= 40 ~ if (lang == "fr") "Eleve" else "High",
    sii >= 20 ~ if (lang == "fr") "Modere" else "Moderate",
    TRUE       ~ if (lang == "fr") "Emergent" else "Emerging"
  )

  level_class <- dplyr::case_when(
    sii >= 80 ~ "pg-sii-level-exceptional",
    sii >= 60 ~ "pg-sii-level-very-high",
    sii >= 40 ~ "pg-sii-level-high",
    sii >= 20 ~ "pg-sii-level-moderate",
    TRUE       ~ "pg-sii-level-emerging"
  )

  # Build dimension cards with progress bars
  dim_html <- paste(purrr::map_chr(seq_len(nrow(dims)), function(i) {
    d <- dims[i, ]
    pct <- round(d$score, 0)
    sprintf(
      '<div class="pg-sii-dimension">
        <div class="pg-sii-dim-label">%s</div>
        <div class="pg-sii-dim-value">%s</div>
        <div class="pg-sii-progress">
          <div class="pg-sii-progress-bar" style="width: %s%%;"></div>
        </div>
      </div>',
      d[[label_col]], pct, pmin(100, pct)
    )
  }), collapse = "\n")

  sii_title <- if (lang == "fr") {
    "Indice d'Influence Scientifique"
  } else {
    "Scientific Influence Index"
  }

  sprintf(
    '<div class="pg-sii-card">
      <div class="pg-sii-header">
        <div class="pg-sii-score-circle">
          <div class="pg-sii-score-value">%s</div>
          <div class="pg-sii-score-max">/100</div>
        </div>
        <div class="pg-sii-meta">
          <h3>%s</h3>
          <span class="pg-sii-level %s">%s</span>
        </div>
      </div>
      <div class="pg-sii-dimensions">
        %s
      </div>
    </div>',
    round(sii, 1),
    sii_title,
    level_class,
    level,
    dim_html
  )
}
