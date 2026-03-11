# ── classify_outputs.R ────────────────────────────────────────────────────────
# Classification of research outputs into canonical types and summary tables.
# ──────────────────────────────────────────────────────────────────────────────

# ── Labels lookup (internal) ─────────────────────────────────────────────────

#' Labels for classified production types
#'
#' @return A tibble with columns `type_classified`, `label_fr`, `label_en`.
#' @noRd
pg_type_labels <- function() {
  tibble(
    type_classified = c(
      "article", "book", "book_chapter", "seminar", "conference",
      "report", "thesis_supervised", "patent", "media", "project",
      "award", "expertise", "other"
    ),
    label_fr = c(
      "Articles", "Ouvrages", "Chapitres", "Seminaires", "Conferences",
      "Rapports", "Theses dirigees", "Brevets", "Medias",
      "Projets finances", "Prix et distinctions", "Expertises", "Autres"
    ),
    label_en = c(
      "Articles", "Books", "Book Chapters", "Seminars", "Conferences",
      "Reports", "Supervised Theses", "Patents", "Media",
      "Funded Projects", "Awards", "Consulting", "Other"
    )
  )
}


# ── pg_classify ──────────────────────────────────────────────────────────────

#' Classify research productions into canonical types
#'
#' Assigns one of 12 canonical types (plus `"other"`) to each row of a
#' merged-input tibble produced by [pg_merge_inputs()]. Classification relies
#' on the BibTeX entry type stored in `type_raw` and, where necessary, on
#' discriminant fields such as `type`, `venue`, and `role`.
#'
#' @param data A tibble produced by [pg_merge_inputs()]. Must contain at least
#'   the column `type_raw` (character). The optional discriminant columns
#'   `type`, `venue`, and `role` are used when present to refine
#'   classification.
#'
#' @return The same tibble with column `type_classified` filled in. Rows that
#'   cannot be mapped to one of the 12 canonical categories receive the value
#'   `"other"` and a bilingual warning is emitted.
#'
#' @details
#' ## Classification rules
#'
#' | `type_classified`    | Source entry types / conditions                          |
#' |----------------------|----------------------------------------------------------|
#' | `article`            | `@article`                                               |
#' | `book`               | `@book`                                                  |
#' | `book_chapter`       | `@incollection`, `@inbook`                               |
#' | `seminar`            | `@inproceedings`/`@conference` with "seminar" in type/venue |
#' | `conference`         | `@inproceedings`/`@conference` (other)                   |
#' | `report`             | `@techreport`, `@report`                                 |
#' | `thesis_supervised`  | `@phdthesis`/`@mastersthesis` with `role == "supervisor"` |
#' | `patent`             | `@patent`, or `@misc` with `type == "patent"`            |
#' | `media`              | `@misc` with `type` in `"media"`, `"podcast"`, `"interview"` |
#' | `project`            | `@misc`/CSV with `type` in `"project"`, `"grant"`        |
#' | `award`              | `@misc`/CSV with `type` in `"award"`, `"prize"`          |
#' | `expertise`          | `@misc`/CSV with `type` in `"expertise"`, `"consulting"` |
#' | `other`              | Everything else (warning emitted)                        |
#'
#' @examples
#' # Build a small demo tibble that mimics pg_merge_inputs() output
#' demo <- tibble::tibble(
#'   id        = paste0("ref_", 1:6),
#'   type_raw  = c("article", "book", "incollection",
#'                  "inproceedings", "misc", "misc"),
#'   type      = c(NA, NA, NA, "seminar", "media", "project"),
#'   venue     = c(NA, NA, NA, "Seminar on Trade", NA, NA),
#'   role      = c(NA, NA, NA, NA, NA, NA),
#'   title     = paste("Title", 1:6),
#'   year      = c(2019, 2020, 2021, 2022, 2023, 2024),
#'   type_classified = NA_character_
#' )
#'
#' classified <- pg_classify(demo)
#' classified$type_classified
#'
#' @export
pg_classify <- function(data) {

 tryCatch({

    # ── Input validation ─────────────────────────────────────────────────────
    if (!inherits(data, "data.frame")) {
      pg_msg(
        "error",
        "L'argument 'data' doit etre un data.frame ou un tibble.",
        "Argument 'data' must be a data.frame or tibble."
      )
      stop("pg_classify: invalid input type.", call. = FALSE)
    }

    if (!"type_raw" %in% colnames(data)) {
      pg_msg(
        "error",
        "La colonne 'type_raw' est absente du jeu de donnees.",
        "Column 'type_raw' is missing from the dataset."
      )
      stop("pg_classify: missing column 'type_raw'.", call. = FALSE)
    }

    # Ensure discriminant columns exist (fill with NA if absent)
    for (col in c("type", "venue", "role", "type_classified")) {
      if (!col %in% colnames(data)) {
        data[[col]] <- NA_character_
      }
    }

    pg_msg(
      "info",
      glue("Classification de {nrow(data)} productions en cours..."),
      glue("Classifying {nrow(data)} productions...")
    )

    # ── Normalise raw values to lower-case for matching ──────────────────────
    raw   <- str_to_lower(str_trim(data$type_raw))
    disc  <- str_to_lower(str_trim(data$type))
    ven   <- str_to_lower(str_trim(data$venue))
    role  <- str_to_lower(str_trim(data$role))

    # ── Vectorised classification ────────────────────────────────────────────
    classified <- rep(NA_character_, nrow(data))

    # 1. article
    classified <- ifelse(
      is.na(classified) & raw == "article",
      "article", classified
    )

    # 2. book
    classified <- ifelse(
      is.na(classified) & raw == "book",
      "book", classified
    )

    # 3. book_chapter
    classified <- ifelse(
      is.na(classified) & raw %in% c("incollection", "inbook"),
      "book_chapter", classified
    )

    # 4. seminar (inproceedings/conference with seminar signal)
    is_proceedings <- raw %in% c("inproceedings", "conference")
    seminar_in_type  <- !is.na(disc) & str_detect(disc, "seminar")
    seminar_in_venue <- !is.na(ven)  & str_detect(ven,  "seminar")
    classified <- ifelse(
      is.na(classified) & is_proceedings & (seminar_in_type | seminar_in_venue),
      "seminar", classified
    )

    # 5. conference (remaining inproceedings/conference)
    classified <- ifelse(
      is.na(classified) & is_proceedings,
      "conference", classified
    )

    # 6. report
    classified <- ifelse(
      is.na(classified) & raw %in% c("techreport", "report"),
      "report", classified
    )

    # 7. thesis_supervised
    is_thesis   <- raw %in% c("phdthesis", "mastersthesis")
    is_supervisor <- !is.na(role) & str_detect(role, "supervisor")
    classified <- ifelse(
      is.na(classified) & is_thesis & is_supervisor,
      "thesis_supervised", classified
    )

    # 8. patent (@patent directly, or @misc with type=="patent")
    classified <- ifelse(
      is.na(classified) & raw == "patent",
      "patent", classified
    )
    classified <- ifelse(
      is.na(classified) & raw == "misc" & !is.na(disc) & disc == "patent",
      "patent", classified
    )

    # 9. media (@misc with type in media/podcast/interview)
    classified <- ifelse(
      is.na(classified) & raw == "misc" & !is.na(disc) &
        disc %in% c("media", "podcast", "interview"),
      "media", classified
    )

    # 10. project (@misc / CSV with type in project/grant)
    classified <- ifelse(
      is.na(classified) & !is.na(disc) & disc %in% c("project", "grant"),
      "project", classified
    )

    # 11. award (@misc / CSV with type in award/prize)
    classified <- ifelse(
      is.na(classified) & !is.na(disc) & disc %in% c("award", "prize"),
      "award", classified
    )

    # 12. expertise (@misc / CSV with type in expertise/consulting)
    classified <- ifelse(
      is.na(classified) & !is.na(disc) &
        disc %in% c("expertise", "consulting"),
      "expertise", classified
    )

    # 13. other (everything remaining)
    n_other <- sum(is.na(classified))
    classified[is.na(classified)] <- "other"

    # Assign back
    data[["type_classified"]] <- classified

    # ── Warning for unclassified items ───────────────────────────────────────
    if (n_other > 0L) {
      other_types <- data |>
        filter(.data$type_classified == "other") |>
        pull(.data$type_raw) |>
        unique() |>
        paste(collapse = ", ")

      pg_msg(
        "warn",
        glue("{n_other} production(s) classee(s) 'other' (types bruts : {other_types})."),
        glue("{n_other} production(s) classified as 'other' (raw types: {other_types}).")
      )
    }

    # ── Success message ──────────────────────────────────────────────────────
    n_types <- length(unique(data$type_classified))
    pg_msg(
      "success",
      glue("Classification terminee : {n_types} types identifies."),
      glue("Classification complete: {n_types} types identified.")
    )

    data

  }, error = function(e) {
    if (!grepl("^pg_classify:", e$message)) {
      pg_msg(
        "error",
        glue("Erreur inattendue dans pg_classify : {e$message}"),
        glue("Unexpected error in pg_classify: {e$message}")
      )
    }
    stop(e)
  })
}


# ── pg_summary_table ─────────────────────────────────────────────────────────

#' Compute a summary table of classified productions
#'
#' Aggregates a classified tibble by `type_classified` and returns one row per
#' type with bilingual labels, count, year range, and percentage of total.
#'
#' @param data A tibble that has already been processed by [pg_classify()].
#'   Must contain columns `type_classified` (character) and `year` (numeric).
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{type_classified}{Character. Canonical type key.}
#'     \item{label_fr}{Character. French display label.}
#'     \item{label_en}{Character. English display label.}
#'     \item{n}{Integer. Number of productions of this type.}
#'     \item{first_year}{Numeric. Earliest publication year.}
#'     \item{last_year}{Numeric. Latest publication year.}
#'     \item{pct_total}{Numeric. Percentage of all productions (0--100).}
#'   }
#'   Rows are sorted by `n` in descending order.
#'
#' @examples
#' # Build a small demo tibble already classified
#' demo <- tibble::tibble(
#'   id              = paste0("ref_", 1:8),
#'   type_raw        = c("article", "article", "article", "book",
#'                        "inproceedings", "inproceedings", "misc", "misc"),
#'   type_classified = c("article", "article", "article", "book",
#'                        "conference", "conference", "media", "project"),
#'   year            = c(2018, 2019, 2021, 2020, 2022, 2023, 2023, 2024)
#' )
#'
#' pg_summary_table(demo)
#'
#' @export
pg_summary_table <- function(data) {

  tryCatch({

    # ── Input validation ─────────────────────────────────────────────────────
    if (!inherits(data, "data.frame")) {
      pg_msg(
        "error",
        "L'argument 'data' doit etre un data.frame ou un tibble.",
        "Argument 'data' must be a data.frame or tibble."
      )
      stop("pg_summary_table: invalid input type.", call. = FALSE)
    }

    required_cols <- c("type_classified", "year")
    missing_cols  <- setdiff(required_cols, colnames(data))
    if (length(missing_cols) > 0L) {
      pg_msg(
        "error",
        glue("Colonnes manquantes : {paste(missing_cols, collapse = ', ')}."),
        glue("Missing columns: {paste(missing_cols, collapse = ', ')}.")
      )
      stop(
        glue("pg_summary_table: missing columns: {paste(missing_cols, collapse = ', ')}."),
        call. = FALSE
      )
    }

    pg_msg(
      "info",
      glue("Construction du tableau recapitulatif pour {nrow(data)} productions..."),
      glue("Building summary table for {nrow(data)} productions...")
    )

    # ── Aggregate ────────────────────────────────────────────────────────────
    total_n <- nrow(data)

    summary_tbl <- data |>
      group_by(.data$type_classified) |>
      summarise(
        n          = n(),
        first_year = min(.data$year, na.rm = TRUE),
        last_year  = max(.data$year, na.rm = TRUE),
        .groups    = "drop"
      ) |>
      mutate(
        pct_total = round(.data$n / total_n * 100, 1)
      ) |>
      arrange(dplyr::desc(.data$n))

    # ── Join bilingual labels ────────────────────────────────────────────────
    labels <- pg_type_labels()

    summary_tbl <- summary_tbl |>
      left_join(labels, by = "type_classified") |>
      select(
        "type_classified", "label_fr", "label_en",
        "n", "first_year", "last_year", "pct_total"
      )

    # Fill any label that did not match (safety net)
    summary_tbl <- summary_tbl |>
      mutate(
        label_fr = ifelse(is.na(.data$label_fr), .data$type_classified, .data$label_fr),
        label_en = ifelse(is.na(.data$label_en), .data$type_classified, .data$label_en)
      )

    pg_msg(
      "success",
      glue("Tableau recapitulatif construit ({nrow(summary_tbl)} types)."),
      glue("Summary table built ({nrow(summary_tbl)} types).")
    )

    summary_tbl

  }, error = function(e) {
    if (!grepl("^pg_summary_table:", e$message)) {
      pg_msg(
        "error",
        glue("Erreur inattendue dans pg_summary_table : {e$message}"),
        glue("Unexpected error in pg_summary_table: {e$message}")
      )
    }
    stop(e)
  })
}
