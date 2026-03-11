# ── llm_narratives.R ──────────────────────────────────────────────────────────
# Batch orchestration of AI-generated narrative summaries via the Anthropic
# Claude API, with caching, rate limiting, and progress reporting.
# Exported: pg_run_all_narratives, pg_check_api_key.
# ──────────────────────────────────────────────────────────────────────────────


# ── 1. pg_run_all_narratives ─────────────────────────────────────────────────

#' Generate AI Narrative Summaries for All Productions
#'
#' Iterates over rows of a classified dataset and dispatches each item to the
#' appropriate narrative generator ([pg_narrative_article()] for articles,
#' [pg_narrative_seminar()] for seminars). Results are merged back into the
#' input tibble as new columns. Supports optional disk caching (via the
#' \pkg{digest} package) to avoid redundant API calls, built-in rate limiting,
#' and a CLI progress bar.
#'
#' @param data A tibble produced by [pg_classify()]. Must contain at least the
#'   columns `pg_id`, `type_classified`, `title`, and `abstract`.
#' @param api_key Character. Anthropic API key. **Never logged or printed.**
#' @param lang Character. Language for the narratives: `"fr"` (default) or
#'   `"en"`.
#' @param cache_dir Character or `NULL`. Path to a directory used for caching
#'   narrative results as `.rds` files. If `NULL` (the default) no caching is
#'   performed. When a cache directory is provided, each result is keyed by
#'   `digest::digest(list(pg_id, abstract, lang))`. Requires the \pkg{digest}
#'   package (listed in `Suggests`).
#' @param types_to_process Character vector. Production types to process.
#'   Defaults to `c("article", "seminar", "book")`. Rows whose
#'   `type_classified` is not in this vector are silently skipped.
#' @param max_items Numeric. Maximum number of items to process (default
#'   `Inf`, meaning all eligible rows). Useful for testing or quota management.
#'
#' @return The input `data` tibble augmented with six new columns:
#'   \describe{
#'     \item{narrative_problematique}{Character. Research question / central theme.}
#'     \item{narrative_pertinence}{Character. Importance and context.}
#'     \item{narrative_resultat}{Character. Main findings / contribution.}
#'     \item{narrative_question_ouverte}{Character. Open question for reflection.}
#'     \item{narrative_lang}{Character. Language code used for generation.}
#'     \item{narrative_cached}{Logical. `TRUE` if the result was loaded from cache.}
#'   }
#'   Rows that were not processed (wrong type or beyond `max_items`) receive
#'   `NA_character_` for the narrative columns.
#'
#' @details
#' ## Dispatch rules
#'
#' | `type_classified` | Generator called              | Mapping to output columns          |
#' |-------------------|-------------------------------|------------------------------------|
#' | `article`         | [pg_narrative_article()]      | Direct mapping (same 4 keys)       |
#' | `book`            | [pg_narrative_article()]      | Treated as article (title+abstract)|
#' | `seminar`         | [pg_narrative_seminar()]      | Mapped from seminar-specific keys  |
#'
#' For seminars, the four seminar-specific keys (`question_centrale`,
#' `audience_ciblee`, `positionnement_debat`, `apport_original`) are mapped
#' onto the canonical output columns (`narrative_problematique`,
#' `narrative_pertinence`, `narrative_resultat`,
#' `narrative_question_ouverte`).
#'
#' ## Caching
#'
#' When `cache_dir` is provided, the function creates the directory if it does
#' not exist, then for each item computes a cache key with
#' `digest::digest(list(pg_id, abstract, lang))`. If a matching `.rds` file
#' exists it is loaded directly; otherwise the API is called and the result
#' saved.
#'
#' ## Rate limiting
#'
#' A 0.5-second pause ([Sys.sleep()]) is inserted between consecutive API
#' calls to respect Anthropic rate limits.
#'
#' @examples
#' \dontrun{
#' library(publigraphics)
#' data <- pg_read_bib("refs.bib") |> pg_classify()
#' enriched <- pg_run_all_narratives(
#'   data,
#'   api_key   = Sys.getenv("ANTHROPIC_API_KEY"),
#'   lang      = "fr",
#'   cache_dir = "narrative_cache",
#'   max_items = 5
#' )
#' enriched |> dplyr::select(title, narrative_problematique)
#' }
#'
#' @export
pg_run_all_narratives <- function(data,
                                  api_key,
                                  lang = "fr",
                                  cache_dir = NULL,
                                  types_to_process = NULL,
                                  max_items = Inf) {

  # ── Default types ──────────────────────────────────────────────────────────
  if (is.null(types_to_process)) {
    types_to_process <- c("article", "seminar", "book")
  }

  # ── Input validation ───────────────────────────────────────────────────────
  tryCatch({

    if (!inherits(data, "data.frame")) {
      pg_msg(
        "error",
        "L'argument 'data' doit etre un data.frame ou un tibble.",
        "Argument 'data' must be a data.frame or tibble."
      )
      stop("pg_run_all_narratives: invalid input type.", call. = FALSE)
    }

    required_cols <- c("pg_id", "type_classified", "title")
    missing_cols  <- setdiff(required_cols, colnames(data))
    if (length(missing_cols) > 0L) {
      pg_msg(
        "error",
        glue("Colonnes manquantes : {paste(missing_cols, collapse = ', ')}."),
        glue("Missing columns: {paste(missing_cols, collapse = ', ')}.")
      )
      stop(
        glue("pg_run_all_narratives: missing columns: ",
             "{paste(missing_cols, collapse = ', ')}."),
        call. = FALSE
      )
    }

    if (missing(api_key) || is.null(api_key) || nchar(api_key) == 0L) {
      pg_msg(
        "error",
        "Cle API Anthropic manquante ou vide.",
        "Anthropic API key is missing or empty."
      )
      stop("pg_run_all_narratives: API key is missing.", call. = FALSE)
    }

    if (!lang %in% c("fr", "en")) {
      pg_msg(
        "warn",
        glue("Langue '{lang}' non reconnue, utilisation de 'fr'."),
        glue("Language '{lang}' not recognised, defaulting to 'fr'.")
      )
      lang <- "fr"
    }

    # ── Ensure abstract column exists ──────────────────────────────────────
    if (!"abstract" %in% colnames(data)) {
      data[["abstract"]] <- NA_character_
    }

    # ── Initialise output columns with NA ──────────────────────────────────
    data[["narrative_problematique"]]  <- NA_character_
    data[["narrative_pertinence"]]     <- NA_character_
    data[["narrative_resultat"]]       <- NA_character_
    data[["narrative_question_ouverte"]] <- NA_character_
    data[["narrative_lang"]]           <- NA_character_
    data[["narrative_cached"]]         <- NA

    # ── Identify eligible rows ─────────────────────────────────────────────
    eligible_idx <- which(data[["type_classified"]] %in% types_to_process)

    if (length(eligible_idx) == 0L) {
      pg_msg(
        "warn",
        "Aucune production eligible pour la narration.",
        "No eligible productions for narrative generation."
      )
      return(data)
    }

    # Apply max_items cap
    if (is.finite(max_items) && max_items > 0L) {
      eligible_idx <- eligible_idx[seq_len(min(length(eligible_idx),
                                               as.integer(max_items)))]
    }

    total <- length(eligible_idx)

    pg_msg(
      "info",
      glue("Generation de narrations pour {total} production(s)..."),
      glue("Generating narratives for {total} production(s)...")
    )

    # ── Set up caching ─────────────────────────────────────────────────────
    use_cache <- !is.null(cache_dir)

    if (use_cache) {
      if (!requireNamespace("digest", quietly = TRUE)) {
        pg_msg(
          "warn",
          "Le package 'digest' est requis pour le cache. Cache desactive.",
          "Package 'digest' is required for caching. Cache disabled."
        )
        use_cache <- FALSE
      } else {
        fs::dir_create(cache_dir)
      }
    }

    # ── Counters ───────────────────────────────────────────────────────────
    n_success  <- 0L
    n_fallback <- 0L
    n_cached   <- 0L

    # ── Progress bar ───────────────────────────────────────────────────────
    cli::cli_progress_bar(
      format = paste0(
        "Narratives {cli::pb_current}/{cli::pb_total} ",
        "[{cli::pb_bar}] {cli::pb_percent} | ",
        "ETA: {cli::pb_eta}"
      ),
      total = total,
      clear = FALSE
    )

    # ── Main loop ──────────────────────────────────────────────────────────
    for (iter_pos in seq_along(eligible_idx)) {

      i <- eligible_idx[iter_pos]
      row_i       <- data[i, ]
      row_type    <- as.character(row_i[["type_classified"]])
      row_pg_id   <- as.character(row_i[["pg_id"]])
      row_abstract <- as.character(row_i[["abstract"]])
      if (is.na(row_abstract)) row_abstract <- ""

      from_cache <- FALSE

      # ── Check cache ────────────────────────────────────────────────────
      if (use_cache) {
        cache_key  <- digest::digest(list(row_pg_id, row_abstract, lang))
        cache_file <- file.path(cache_dir, paste0(cache_key, ".rds"))

        if (file.exists(cache_file)) {
          cached_result <- tryCatch(
            readRDS(cache_file),
            error = function(e) NULL
          )

          if (!is.null(cached_result) && inherits(cached_result, "data.frame")) {
            narr <- cached_result
            from_cache <- TRUE
            n_cached   <- n_cached + 1L
          }
        }
      }

      # ── Call API if not cached ─────────────────────────────────────────
      if (!from_cache) {

        narr <- tryCatch({

          if (row_type %in% c("article", "book")) {
            # Dispatch to article narrative generator
            pg_narrative_article(
              article_row = row_i,
              api_key     = api_key,
              lang        = lang
            )
          } else if (row_type == "seminar") {
            # Dispatch to seminar narrative generator
            pg_narrative_seminar(
              seminar_row = row_i,
              api_key     = api_key,
              lang        = lang
            )
          } else {
            # Unexpected type that slipped through; return NA tibble
            NULL
          }

        }, error = function(e) {
          pg_msg(
            "warn",
            glue("Erreur narrative pour '{pg_truncate(as.character(row_i$title), 40L)}' : {conditionMessage(e)}"),
            glue("Narrative error for '{pg_truncate(as.character(row_i$title), 40L)}': {conditionMessage(e)}")
          )
          NULL
        })

        # Rate limiting between API calls
        if (iter_pos < total) {
          Sys.sleep(0.5)
        }
      }

      # ── Map result to canonical columns ────────────────────────────────
      if (!is.null(narr) && inherits(narr, "data.frame") && nrow(narr) > 0L) {

        # Determine if this is a successful result (has at least one non-NA)
        if (row_type == "seminar") {
          # Map seminar-specific keys to canonical column names
          prob_val <- narr[["question_centrale"]]    %||% NA_character_
          pert_val <- narr[["audience_ciblee"]]       %||% NA_character_
          res_val  <- narr[["positionnement_debat"]]  %||% NA_character_
          qo_val   <- narr[["apport_original"]]       %||% NA_character_
        } else {
          # Article / book: direct mapping
          prob_val <- narr[["problematique"]]    %||% NA_character_
          pert_val <- narr[["pertinence"]]       %||% NA_character_
          res_val  <- narr[["resultat"]]         %||% NA_character_
          qo_val   <- narr[["question_ouverte"]] %||% NA_character_
        }

        has_content <- !all(is.na(c(prob_val, pert_val, res_val, qo_val)))

        data[["narrative_problematique"]][i]    <- as.character(prob_val)
        data[["narrative_pertinence"]][i]       <- as.character(pert_val)
        data[["narrative_resultat"]][i]         <- as.character(res_val)
        data[["narrative_question_ouverte"]][i] <- as.character(qo_val)
        data[["narrative_lang"]][i]             <- lang
        data[["narrative_cached"]][i]           <- from_cache

        if (has_content) {
          n_success <- n_success + 1L
        } else {
          n_fallback <- n_fallback + 1L
        }

        # ── Save to cache if new ───────────────────────────────────────
        if (use_cache && !from_cache) {
          tryCatch(
            saveRDS(narr, cache_file),
            error = function(e) {
              pg_msg(
                "warn",
                glue("Impossible d'ecrire le cache : {conditionMessage(e)}"),
                glue("Unable to write cache file: {conditionMessage(e)}")
              )
            }
          )
        }

      } else {
        # Narrative generation failed entirely
        n_fallback <- n_fallback + 1L
        data[["narrative_cached"]][i] <- FALSE
      }

      cli::cli_progress_update()
    }

    cli::cli_progress_done()

    # ── Final summary ──────────────────────────────────────────────────────
    cli::cli_alert_success(
      paste0(
        "{n_success} resume(s) genere(s) | ",
        "{n_success} summar{ifelse(n_success == 1L, 'y', 'ies')} generated"
      )
    )

    if (n_cached > 0L) {
      cli::cli_alert_info(
        paste0(
          "{n_cached} charge(s) depuis le cache | ",
          "{n_cached} loaded from cache"
        )
      )
    }

    if (n_fallback > 0L) {
      cli::cli_alert_warning(
        paste0(
          "{n_fallback} fallback(s) (API indisponible) | ",
          "{n_fallback} fallback(s) (API unavailable)"
        )
      )
    }

    data

  }, error = function(e) {
    if (!grepl("^pg_run_all_narratives:", e$message)) {
      pg_msg(
        "error",
        glue("Erreur inattendue dans pg_run_all_narratives : {e$message}"),
        glue("Unexpected error in pg_run_all_narratives: {e$message}")
      )
    }
    stop(e)
  })
}


# ── 2. pg_check_api_key ─────────────────────────────────────────────────────

#' Check Validity of an Anthropic API Key
#'
#' Performs a minimal, low-cost call to the Anthropic Messages API endpoint
#' (`/v1/messages`) to verify whether the supplied API key is valid. The call
#' requests only 1 token so that virtually no quota is consumed.
#'
#' **Security**: the API key is never logged, printed, or included in any
#' message. Only the HTTP status code is inspected.
#'
#' @param api_key Character. The Anthropic API key to validate.
#'
#' @return Logical. `TRUE` if the key appears valid (HTTP 200 or 400, which
#'   indicates the key was accepted but the request body was incomplete),
#'   `FALSE` if the key is rejected (HTTP 401). Returns `FALSE` with a
#'   warning for any other HTTP status or network error.
#'
#' @examples
#' \dontrun{
#' valid <- pg_check_api_key(Sys.getenv("ANTHROPIC_API_KEY"))
#' if (valid) message("API key is valid")
#' }
#'
#' @export
pg_check_api_key <- function(api_key) {

  tryCatch({

    # ── Input guard ────────────────────────────────────────────────────────
    if (missing(api_key) || is.null(api_key) || !is.character(api_key) ||
        nchar(api_key) == 0L) {
      pg_msg(
        "warn",
        "Cle API vide ou absente.",
        "API key is empty or missing."
      )
      return(FALSE)
    }

    # ── Minimal request (1 token) ──────────────────────────────────────────
    body_list <- list(
      model      = "claude-sonnet-4-20250514",
      max_tokens = 1L,
      messages   = list(
        list(role = "user", content = ".")
      )
    )

    resp <- httr2::request("https://api.anthropic.com/v1/messages") |>
      httr2::req_headers(
        `x-api-key`        = api_key,
        `anthropic-version` = "2023-06-01",
        `content-type`      = "application/json"
      ) |>
      httr2::req_body_json(body_list) |>
      httr2::req_timeout(15) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()

    status <- httr2::resp_status(resp)

    if (status %in% c(200L, 400L)) {
      # 200 = successful call; 400 = valid key but malformed body
      pg_msg(
        "success",
        "Cle API Anthropic valide.",
        "Anthropic API key is valid."
      )
      return(TRUE)
    }

    if (status == 401L) {
      pg_msg(
        "warn",
        "Cle API Anthropic invalide (HTTP 401).",
        "Anthropic API key is invalid (HTTP 401)."
      )
      return(FALSE)
    }

    # Any other status
    pg_msg(
      "warn",
      glue("Verification de la cle API : statut HTTP inattendu ({status})."),
      glue("API key check: unexpected HTTP status ({status}).")
    )
    return(FALSE)

  }, error = function(e) {
    pg_msg(
      "warn",
      glue("Erreur reseau lors de la verification de la cle API : {conditionMessage(e)}"),
      glue("Network error during API key check: {conditionMessage(e)}")
    )
    return(FALSE)
  })
}
