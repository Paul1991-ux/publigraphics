# ── parse_inputs.R ────────────────────────────────────────────────────────────
# Functions for reading, normalising, and merging bibliographic and
# supplementary input data into a standardised tibble schema.
# ──────────────────────────────────────────────────────────────────────────────

# ── Column schema ---------------------------------------------------------
# Every tibble returned by pg_read_bib(), pg_read_extra(), or
# pg_merge_inputs() contains the following columns (in order):
#
#   pg_id, type_raw, type_classified, title, authors, year,
#   journal_or_venue, abstract, keywords, doi, url, isbn, city, country,
#   institution, note, cited_by, source, date_added
# --------------------------------------------------------------------------

#' Build an empty standardised tibble with the publigraphics schema
#'
#' Returns a zero-row tibble whose column names and types match the
#' canonical publigraphics data schema.
#'
#' @return A zero-row [tibble::tibble] with 19 columns.
#' @noRd
pg_empty_schema <- function() {


tibble::tibble(
    pg_id            = character(0L),
    type_raw         = character(0L),
    type_classified  = character(0L),
    title            = character(0L),
    authors          = list(),
    year             = integer(0L),
    journal_or_venue = character(0L),
    abstract         = character(0L),
    keywords         = list(),
    doi              = character(0L),
    url              = character(0L),
    isbn             = character(0L),
    city             = character(0L),
    country          = character(0L),
    institution      = character(0L),
    note             = character(0L),
    cited_by         = integer(0L),
    source           = character(0L),
    date_added       = as.Date(character(0L))
  )
}

# ── Helpers (non-exported) ------------------------------------------------

#' Generate a deterministic short UUID
#'
#' Uses a combination of the row index, the current date, and a
#' pseudo-random suffix seeded with `set.seed(2024L)` to produce
#' reproducible identifiers when no BibTeX key is available.
#'
#' @param n Integer. Number of identifiers to generate.
#' @param prefix Character. Prefix string (default `"pg_"`).
#'
#' @return Character vector of length `n`.
#' @noRd
pg_generate_ids <- function(n, prefix = "pg_") {
  set.seed(2024L)
  suffixes <- formatC(sample.int(1e6L, size = n, replace = FALSE),
                      width = 6L, flag = "0")
  paste0(prefix, format(Sys.Date(), "%Y%m%d"), "_", suffixes)
}

#' Detect file format from extension
#'
#' @param path Character. File path.
#'
#' @return Character. One of `"bib"`, `"ris"`, `"csv"`, `"xlsx"`, or `NA`.
#' @noRd
pg_detect_format <- function(path) {
  ext <- tolower(tools::file_ext(path))
  switch(ext,
    bib  = "bib",
    ris  = "ris",
    csv  = "csv",
    xlsx = "xlsx",
    NA_character_
  )
}

#' Safely extract a column from a data frame, returning NA if absent
#'
#' @param df A data frame.
#' @param col Character. Column name.
#' @param transform An optional function applied to the column.
#'
#' @return Vector of values or `NA` of the same length as `nrow(df)`.
#' @noRd
pg_safe_col <- function(df, col, transform = NULL) {
  if (col %in% names(df)) {
    vals <- df[[col]]
    if (!is.null(transform)) vals <- transform(vals)
    vals
  } else {
    rep(NA_character_, nrow(df))
  }
}

#' Normalise keywords from a raw string
#'
#' Splits a comma- or semicolon-separated keyword string into a trimmed
#' character vector.
#'
#' @param kw_raw Character(1). Raw keyword string.
#'
#' @return Character vector, or `NA` if input is empty/missing.
#' @noRd
pg_clean_keywords <- function(kw_raw) {
  if (is.null(kw_raw) || length(kw_raw) == 0L || is.na(kw_raw) ||
      nchar(stringr::str_trim(kw_raw)) == 0L) {
    return(NA_character_)
  }
  kw_raw |>
    stringr::str_replace_all("[;,]", ",") |>
    strsplit(",", fixed = TRUE) |>
    unlist() |>
    stringr::str_trim() |>
    (\(x) x[nchar(x) > 0L])()
}

# ── pg_read_bib -----------------------------------------------------------

#' Read a bibliographic file into a standardised tibble
#'
#' Parses BibTeX (`.bib`), RIS (`.ris`), CSV (`.csv`), or Excel (`.xlsx`)
#' files and maps their fields to the canonical publigraphics data schema.
#' Format is auto-detected from the file extension unless overridden with
#' the `format` argument.
#'
#' @param path Character. Path to the bibliography file.
#' @param format Character. File format: `"auto"` (default), `"bib"`,
#'   `"ris"`, `"csv"`, or `"xlsx"`.
#' @param encoding Character. File encoding (default `"UTF-8"`).
#'
#' @return A [tibble::tibble] with the 19-column publigraphics schema.
#'   Column `source` is set to `"bib"` for all rows.
#'
#' @details
#' **BibTeX** files are parsed with [bib2df::bib2df()].
#' The `BIBTEXKEY` column is used as `pg_id`; the `CATEGORY` column becomes
#' `type_raw` (prefixed with `@@` if not already present). Author fields are
#' normalised via the internal helper `pg_clean_authors()`.
#'
#' **CSV** files are expected to contain columns whose names match (case
#' insensitively) the schema field names. Unrecognised columns are silently
#' dropped and missing columns default to `NA`.
#'
#' **XLSX** files are read with [readxl::read_excel()] using the same
#' column-matching logic as CSV files.
#'
#' **RIS** format support is planned; currently raises an informative error.
#'
#' @examples
#' # Using the bundled demo BibTeX file
#' bib_path <- system.file("extdata", "demo_refs.bib", package = "publigraphics")
#' if (nzchar(bib_path)) {
#'   refs <- pg_read_bib(bib_path)
#'   print(refs)
#' }
#'
#' @export
pg_read_bib <- function(path, format = "auto", encoding = "UTF-8") {

  # ---- Validate path -----------------------------------------------------
  if (!fs::file_exists(path)) {
    pg_msg("error",
           fr = glue::glue("Fichier introuvable : {path}"),
           en = glue::glue("File not found: {path}"))
    stop(glue::glue("File not found: {path}"), call. = FALSE)
  }

  # ---- Detect format -----------------------------------------------------
  if (identical(format, "auto")) {
    format <- pg_detect_format(path)
    if (is.na(format)) {
      pg_msg("error",
             fr = "Extension de fichier non reconnue.",
             en = "Unrecognised file extension.")
      stop("Unrecognised file extension. Use the `format` argument.", call. = FALSE)
    }
    pg_msg("info",
           fr = glue::glue("Format detecte : {format}"),
           en = glue::glue("Detected format: {format}"))
  }

  # ---- Dispatch -----------------------------------------------------------
  result <- tryCatch(
    switch(format,
      bib  = pg_read_bib_bibtex(path, encoding),
      csv  = pg_read_bib_csv(path, encoding),
      xlsx = pg_read_bib_xlsx(path, encoding),
      ris  = {
        pg_msg("warn",
               fr = "Le format RIS n'est pas encore supporte.",
               en = "RIS format is not yet supported.")
        stop("RIS format is not yet supported.", call. = FALSE)
      },
      {
        stop(glue::glue("Unknown format: {format}"), call. = FALSE)
      }
    ),
    error = function(e) {
      pg_msg("error",
             fr = glue::glue("Erreur de lecture : {conditionMessage(e)}"),
             en = glue::glue("Read error: {conditionMessage(e)}"))
      stop(conditionMessage(e), call. = FALSE)
    }
  )

  pg_msg("success",
         fr = glue::glue("{nrow(result)} references importees depuis '{basename(path)}'."),
         en = glue::glue("{nrow(result)} references imported from '{basename(path)}'."))

  result
}

# ── BibTeX reader (internal) ──

#' Parse a BibTeX file into the publigraphics schema
#' @noRd
pg_read_bib_bibtex <- function(path, encoding = "UTF-8") {

  raw <- tryCatch(
    bib2df::bib2df(path, separate_names = FALSE),
    error = function(e) {
      pg_msg("error",
             fr = glue::glue("bib2df a echoue : {conditionMessage(e)}"),
             en = glue::glue("bib2df failed: {conditionMessage(e)}"))
      stop(conditionMessage(e), call. = FALSE)
    }
  )

  if (nrow(raw) == 0L) {
    pg_msg("warn",
           fr = "Le fichier BibTeX ne contient aucune entree.",
           en = "The BibTeX file contains no entries.")
    return(pg_empty_schema())
  }

  # Uppercase column names for consistent matching (bib2df returns uppercase)
  names(raw) <- toupper(names(raw))

  n <- nrow(raw)

  # Extract pg_id: prefer BIBTEXKEY, else generate

  pg_id <- if ("BIBTEXKEY" %in% names(raw)) {
    raw[["BIBTEXKEY"]]
  } else {
    pg_generate_ids(n)
  }

  # type_raw: the CATEGORY column (bib2df names it CATEGORY)
  type_raw <- if ("CATEGORY" %in% names(raw)) {
    ifelse(
      grepl("^@", raw[["CATEGORY"]]),
      tolower(raw[["CATEGORY"]]),
      paste0("@", tolower(raw[["CATEGORY"]]))
    )
  } else {
    rep(NA_character_, n)
  }

  # Authors: bib2df may return a list column or character column
  authors <- if ("AUTHOR" %in% names(raw)) {
    auth_col <- raw[["AUTHOR"]]
    if (is.list(auth_col)) {
      purrr::map(auth_col, function(a) {
        if (is.null(a) || all(is.na(a))) return(NA_character_)
        a_vec <- unlist(a)
        a_vec <- stringr::str_trim(a_vec)
        a_vec[nchar(a_vec) > 0L]
      })
    } else {
      purrr::map(auth_col, pg_clean_authors)
    }
  } else {
    replicate(n, NA_character_, simplify = FALSE)
  }

  # Year: integer
  year_vals <- if ("YEAR" %in% names(raw)) {
    suppressWarnings(as.integer(raw[["YEAR"]]))
  } else {
    rep(NA_integer_, n)
  }

  # Keywords: KEYWORDS column
  keywords <- if ("KEYWORDS" %in% names(raw)) {
    purrr::map(raw[["KEYWORDS"]], pg_clean_keywords)
  } else {
    replicate(n, NA_character_, simplify = FALSE)
  }

  # Journal / venue: look in JOURNAL, BOOKTITLE, PUBLISHER
  journal_or_venue <- dplyr::coalesce(
    pg_safe_col(raw, "JOURNAL"),
    pg_safe_col(raw, "BOOKTITLE"),
    pg_safe_col(raw, "PUBLISHER")
  )

  # Assemble
  tibble::tibble(
    pg_id            = pg_id,
    type_raw         = type_raw,
    type_classified  = NA_character_,
    title            = pg_safe_col(raw, "TITLE"),
    authors          = authors,
    year             = year_vals,
    journal_or_venue = journal_or_venue,
    abstract         = pg_safe_col(raw, "ABSTRACT"),
    keywords         = keywords,
    doi              = pg_safe_col(raw, "DOI"),
    url              = pg_safe_col(raw, "URL"),
    isbn             = pg_safe_col(raw, "ISBN"),
    city             = pg_safe_col(raw, "ADDRESS"),
    country          = NA_character_,
    institution      = pg_safe_col(raw, "INSTITUTION"),
    note             = pg_safe_col(raw, "NOTE"),
    cited_by         = NA_integer_,
    source           = "bib",
    date_added       = lubridate::today()
  )
}

# ── CSV reader (internal) ──

#' Parse a CSV bibliography file into the publigraphics schema
#' @noRd
pg_read_bib_csv <- function(path, encoding = "UTF-8") {

  raw <- tryCatch(
    readr::read_csv(path, locale = readr::locale(encoding = encoding),
                    show_col_types = FALSE),
    error = function(e) {
      pg_msg("error",
             fr = glue::glue("Lecture CSV echouee : {conditionMessage(e)}"),
             en = glue::glue("CSV read failed: {conditionMessage(e)}"))
      stop(conditionMessage(e), call. = FALSE)
    }
  )

  if (nrow(raw) == 0L) {
    pg_msg("warn",
           fr = "Le fichier CSV ne contient aucune ligne.",
           en = "The CSV file contains no rows.")
    return(pg_empty_schema())
  }

  # Normalise column names to lower_snake
  names(raw) <- tolower(names(raw)) |>
    stringr::str_replace_all("[^a-z0-9]+", "_") |>
    stringr::str_remove_all("^_|_$")

  n <- nrow(raw)

  # Map columns with best-effort matching
  pg_id <- if ("pg_id" %in% names(raw)) {
    raw[["pg_id"]]
  } else if ("bibtexkey" %in% names(raw)) {
    raw[["bibtexkey"]]
  } else {
    pg_generate_ids(n)
  }

  # Authors: expect comma-separated in a single column
  authors <- if ("authors" %in% names(raw)) {
    purrr::map(raw[["authors"]], function(a) {
      if (is.na(a)) return(NA_character_)
      stringr::str_trim(unlist(strsplit(a, ";|\\s+and\\s+", perl = TRUE)))
    })
  } else if ("author" %in% names(raw)) {
    purrr::map(raw[["author"]], function(a) {
      if (is.na(a)) return(NA_character_)
      stringr::str_trim(unlist(strsplit(a, ";|\\s+and\\s+", perl = TRUE)))
    })
  } else {
    replicate(n, NA_character_, simplify = FALSE)
  }

  # Keywords
  keywords <- if ("keywords" %in% names(raw)) {
    purrr::map(raw[["keywords"]], pg_clean_keywords)
  } else {
    replicate(n, NA_character_, simplify = FALSE)
  }

  # Year
  year_vals <- if ("year" %in% names(raw)) {
    suppressWarnings(as.integer(raw[["year"]]))
  } else {
    rep(NA_integer_, n)
  }

  # Warn about missing expected columns
  expected <- c("title", "year", "authors", "author")
  missing <- setdiff(expected, names(raw))
  if (length(missing) > 0L) {
    pg_msg("warn",
           fr = glue::glue("Colonnes manquantes dans le CSV : {paste(missing, collapse = ', ')}"),
           en = glue::glue("Missing columns in CSV: {paste(missing, collapse = ', ')}"))
  }

  tibble::tibble(
    pg_id            = pg_id,
    type_raw         = pg_safe_col(raw, "type_raw",
                                   function(x) tolower(as.character(x))),
    type_classified  = NA_character_,
    title            = pg_safe_col(raw, "title"),
    authors          = authors,
    year             = year_vals,
    journal_or_venue = dplyr::coalesce(
      pg_safe_col(raw, "journal_or_venue"),
      pg_safe_col(raw, "journal"),
      pg_safe_col(raw, "venue")
    ),
    abstract         = pg_safe_col(raw, "abstract"),
    keywords         = keywords,
    doi              = pg_safe_col(raw, "doi"),
    url              = pg_safe_col(raw, "url"),
    isbn             = pg_safe_col(raw, "isbn"),
    city             = pg_safe_col(raw, "city"),
    country          = pg_safe_col(raw, "country"),
    institution      = pg_safe_col(raw, "institution"),
    note             = pg_safe_col(raw, "note"),
    cited_by         = if ("cited_by" %in% names(raw)) {
      suppressWarnings(as.integer(raw[["cited_by"]]))
    } else {
      rep(NA_integer_, n)
    },
    source           = "bib",
    date_added       = lubridate::today()
  )
}

# ── XLSX reader (internal) ──

#' Parse an XLSX bibliography file into the publigraphics schema
#' @noRd
pg_read_bib_xlsx <- function(path, encoding = "UTF-8") {

  if (!requireNamespace("readxl", quietly = TRUE)) {
    pg_msg("error",
           fr = "Le package 'readxl' est requis pour lire les fichiers XLSX.",
           en = "Package 'readxl' is required to read XLSX files.")
    stop("Package 'readxl' is required to read XLSX files.", call. = FALSE)
  }

  raw <- tryCatch(
    readxl::read_excel(path),
    error = function(e) {
      pg_msg("error",
             fr = glue::glue("Lecture XLSX echouee : {conditionMessage(e)}"),
             en = glue::glue("XLSX read failed: {conditionMessage(e)}"))
      stop(conditionMessage(e), call. = FALSE)
    }
  )

  if (nrow(raw) == 0L) {
    pg_msg("warn",
           fr = "Le fichier XLSX ne contient aucune ligne.",
           en = "The XLSX file contains no rows.")
    return(pg_empty_schema())
  }

  # Normalise column names to lower_snake
  names(raw) <- tolower(names(raw)) |>
    stringr::str_replace_all("[^a-z0-9]+", "_") |>
    stringr::str_remove_all("^_|_$")

  n <- nrow(raw)

  pg_id <- if ("pg_id" %in% names(raw)) {
    raw[["pg_id"]]
  } else if ("bibtexkey" %in% names(raw)) {
    raw[["bibtexkey"]]
  } else {
    pg_generate_ids(n)
  }

  authors <- if ("authors" %in% names(raw)) {
    purrr::map(raw[["authors"]], function(a) {
      if (is.na(a)) return(NA_character_)
      stringr::str_trim(unlist(strsplit(as.character(a), ";|\\s+and\\s+",
                                        perl = TRUE)))
    })
  } else if ("author" %in% names(raw)) {
    purrr::map(raw[["author"]], function(a) {
      if (is.na(a)) return(NA_character_)
      stringr::str_trim(unlist(strsplit(as.character(a), ";|\\s+and\\s+",
                                        perl = TRUE)))
    })
  } else {
    replicate(n, NA_character_, simplify = FALSE)
  }

  keywords <- if ("keywords" %in% names(raw)) {
    purrr::map(raw[["keywords"]], pg_clean_keywords)
  } else {
    replicate(n, NA_character_, simplify = FALSE)
  }

  year_vals <- if ("year" %in% names(raw)) {
    suppressWarnings(as.integer(raw[["year"]]))
  } else {
    rep(NA_integer_, n)
  }

  tibble::tibble(
    pg_id            = pg_id,
    type_raw         = pg_safe_col(raw, "type_raw",
                                   function(x) tolower(as.character(x))),
    type_classified  = NA_character_,
    title            = pg_safe_col(raw, "title"),
    authors          = authors,
    year             = year_vals,
    journal_or_venue = dplyr::coalesce(
      pg_safe_col(raw, "journal_or_venue"),
      pg_safe_col(raw, "journal"),
      pg_safe_col(raw, "venue")
    ),
    abstract         = pg_safe_col(raw, "abstract"),
    keywords         = keywords,
    doi              = pg_safe_col(raw, "doi"),
    url              = pg_safe_col(raw, "url"),
    isbn             = pg_safe_col(raw, "isbn"),
    city             = pg_safe_col(raw, "city"),
    country          = pg_safe_col(raw, "country"),
    institution      = pg_safe_col(raw, "institution"),
    note             = pg_safe_col(raw, "note"),
    cited_by         = if ("cited_by" %in% names(raw)) {
      suppressWarnings(as.integer(raw[["cited_by"]]))
    } else {
      rep(NA_integer_, n)
    },
    source           = "bib",
    date_added       = lubridate::today()
  )
}

# ── pg_read_extra ---------------------------------------------------------

#' Read a supplementary CSV file for non-bibliographic items
#'
#' Reads a CSV file containing supplementary research outputs such as
#' seminars, funded projects, supervised theses, and awards that are not
#' captured in standard bibliographic databases. The data are mapped to
#' the canonical publigraphics schema with `source = "extra"`.
#'
#' @param path Character. Path to the supplementary CSV file.
#' @param encoding Character. File encoding (default `"UTF-8"`).
#'
#' @return A [tibble::tibble] with the 19-column publigraphics schema.
#'   Column `source` is set to `"extra"` for all rows.
#'
#' @details
#' The CSV file is expected to contain some or all of the following columns
#' (case insensitive): `type`, `title`, `year`, `city`, `country`,
#' `institution`, `note`, `date_start`, `date_end`, `funding_amount`,
#' `funding_source`. Missing columns default to `NA`.
#'
#' The `type` column is stored in `type_raw`; the `funding_amount` and
#' `funding_source` columns are concatenated into the `note` field if
#' present.
#'
#' @examples
#' # Using the bundled demo extra CSV
#' extra_path <- system.file("extdata", "demo_extra.csv",
#'                           package = "publigraphics")
#' if (nzchar(extra_path)) {
#'   extras <- pg_read_extra(extra_path)
#'   print(extras)
#' }
#'
#' @export
pg_read_extra <- function(path, encoding = "UTF-8") {

  # ---- Validate path -----------------------------------------------------
  if (!fs::file_exists(path)) {
    pg_msg("error",
           fr = glue::glue("Fichier introuvable : {path}"),
           en = glue::glue("File not found: {path}"))
    stop(glue::glue("File not found: {path}"), call. = FALSE)
  }

  # ---- Read CSV ----------------------------------------------------------
  raw <- tryCatch(
    readr::read_csv(path, locale = readr::locale(encoding = encoding),
                    show_col_types = FALSE),
    error = function(e) {
      pg_msg("error",
             fr = glue::glue("Lecture CSV echouee : {conditionMessage(e)}"),
             en = glue::glue("CSV read failed: {conditionMessage(e)}"))
      stop(conditionMessage(e), call. = FALSE)
    }
  )

  if (nrow(raw) == 0L) {
    pg_msg("warn",
           fr = "Le fichier supplementaire ne contient aucune ligne.",
           en = "The supplementary file contains no rows.")
    return(pg_empty_schema())
  }

  # Normalise column names
  names(raw) <- tolower(names(raw)) |>
    stringr::str_replace_all("[^a-z0-9]+", "_") |>
    stringr::str_remove_all("^_|_$")

  n <- nrow(raw)

  # Generate IDs
  pg_id <- pg_generate_ids(n, prefix = "extra_")

  # Year
  year_vals <- if ("year" %in% names(raw)) {
    suppressWarnings(as.integer(raw[["year"]]))
  } else {
    rep(NA_integer_, n)
  }

  # Build note: combine note + funding info
  base_note <- pg_safe_col(raw, "note")
  funding_amt <- pg_safe_col(raw, "funding_amount")
  funding_src <- pg_safe_col(raw, "funding_source")

  note_combined <- purrr::pmap_chr(
    list(base_note, funding_amt, funding_src),
    function(n_val, amt, src) {
      parts <- character(0L)
      if (!is.na(n_val) && nchar(stringr::str_trim(n_val)) > 0L) {
        parts <- c(parts, n_val)
      }
      if (!is.na(amt) && nchar(stringr::str_trim(as.character(amt))) > 0L) {
        parts <- c(parts, glue::glue("Funding: {amt}"))
      }
      if (!is.na(src) && nchar(stringr::str_trim(src)) > 0L) {
        parts <- c(parts, glue::glue("Source: {src}"))
      }
      if (length(parts) == 0L) return(NA_character_)
      paste(parts, collapse = " | ")
    }
  )

  # Type raw
  type_raw <- if ("type" %in% names(raw)) {
    tolower(as.character(raw[["type"]]))
  } else {
    rep(NA_character_, n)
  }

  # Assemble
  result <- tibble::tibble(
    pg_id            = pg_id,
    type_raw         = type_raw,
    type_classified  = NA_character_,
    title            = pg_safe_col(raw, "title"),
    authors          = replicate(n, NA_character_, simplify = FALSE),
    year             = year_vals,
    journal_or_venue = NA_character_,
    abstract         = NA_character_,
    keywords         = replicate(n, NA_character_, simplify = FALSE),
    doi              = NA_character_,
    url              = NA_character_,
    isbn             = NA_character_,
    city             = pg_safe_col(raw, "city"),
    country          = pg_safe_col(raw, "country"),
    institution      = pg_safe_col(raw, "institution"),
    note             = note_combined,
    cited_by         = NA_integer_,
    source           = "extra",
    date_added       = lubridate::today()
  )

  pg_msg("success",
         fr = glue::glue("{nrow(result)} elements supplementaires importes depuis '{basename(path)}'."),
         en = glue::glue("{nrow(result)} supplementary items imported from '{basename(path)}'."))

  result
}

# ── pg_merge_inputs -------------------------------------------------------

#' Merge and deduplicate bibliographic and supplementary data
#'
#' Combines data from [pg_read_bib()] and optionally [pg_read_extra()]
#' into a single standardised tibble. Duplicates are detected by
#' case-insensitive, whitespace-trimmed title comparison; the first
#' occurrence (from `bib_data`) is retained.
#'
#' @param bib_data A tibble produced by [pg_read_bib()].
#' @param extra_data A tibble produced by [pg_read_extra()], or `NULL`
#'   (default) if no supplementary data are available.
#'
#' @return A [tibble::tibble] with the 19-column publigraphics schema.
#'   Rows are ordered by `year` (descending) then `title` (ascending).
#'
#' @details
#' Deduplication compares the normalised title (`tolower(str_trim(title))`)
#' across both data sets. When a title appears in both `bib_data` and
#' `extra_data`, only the `bib_data` row is kept because bibliographic
#' sources generally carry richer metadata.
#'
#' @examples
#' bib_path   <- system.file("extdata", "demo_refs.bib",
#'                           package = "publigraphics")
#' extra_path <- system.file("extdata", "demo_extra.csv",
#'                           package = "publigraphics")
#' if (nzchar(bib_path) && nzchar(extra_path)) {
#'   bib_data   <- pg_read_bib(bib_path)
#'   extra_data <- pg_read_extra(extra_path)
#'   merged     <- pg_merge_inputs(bib_data, extra_data)
#'   print(merged)
#' }
#'
#' @export
pg_merge_inputs <- function(bib_data, extra_data = NULL) {

  # ---- Validate inputs ---------------------------------------------------
  if (!inherits(bib_data, "data.frame")) {
    pg_msg("error",
           fr = "bib_data doit etre un data.frame ou tibble.",
           en = "bib_data must be a data.frame or tibble.")
    stop("bib_data must be a data.frame or tibble.", call. = FALSE)
  }

  expected_cols <- names(pg_empty_schema())
  missing_bib <- setdiff(expected_cols, names(bib_data))
  if (length(missing_bib) > 0L) {
    pg_msg("error",
           fr = glue::glue("Colonnes manquantes dans bib_data : {paste(missing_bib, collapse = ', ')}"),
           en = glue::glue("Missing columns in bib_data: {paste(missing_bib, collapse = ', ')}"))
    stop(
      glue::glue("Missing columns in bib_data: {paste(missing_bib, collapse = ', ')}"),
      call. = FALSE
    )
  }

  # If no extra data, just return bib sorted
  if (is.null(extra_data)) {
    pg_msg("info",
           fr = "Aucune donnee supplementaire fournie ; renvoi des references bibliographiques seules.",
           en = "No supplementary data provided; returning bibliographic references only.")

    result <- bib_data |>
      dplyr::arrange(dplyr::desc(.data$year), .data$title)

    return(result)
  }

  # Validate extra_data
  if (!inherits(extra_data, "data.frame")) {
    pg_msg("error",
           fr = "extra_data doit etre un data.frame ou tibble.",
           en = "extra_data must be a data.frame or tibble.")
    stop("extra_data must be a data.frame or tibble.", call. = FALSE)
  }

  missing_extra <- setdiff(expected_cols, names(extra_data))
  if (length(missing_extra) > 0L) {
    pg_msg("error",
           fr = glue::glue("Colonnes manquantes dans extra_data : {paste(missing_extra, collapse = ', ')}"),
           en = glue::glue("Missing columns in extra_data: {paste(missing_extra, collapse = ', ')}"))
    stop(
      glue::glue("Missing columns in extra_data: {paste(missing_extra, collapse = ', ')}"),
      call. = FALSE
    )
  }

  # ---- Combine ------------------------------------------------------------
  combined <- tryCatch(
    dplyr::bind_rows(bib_data, extra_data),
    error = function(e) {
      pg_msg("error",
             fr = glue::glue("Erreur lors de la fusion : {conditionMessage(e)}"),
             en = glue::glue("Merge error: {conditionMessage(e)}"))
      stop(conditionMessage(e), call. = FALSE)
    }
  )

  n_before <- nrow(combined)

  # ---- Deduplicate by normalised title ------------------------------------
  combined <- combined |>
    dplyr::mutate(
      .title_norm = stringr::str_trim(tolower(.data$title))
    ) |>
    dplyr::distinct(.data$.title_norm, .keep_all = TRUE) |>
    dplyr::select(-".title_norm")

  n_after <- nrow(combined)
  n_dupes <- n_before - n_after

  if (n_dupes > 0L) {
    pg_msg("info",
           fr = glue::glue("{n_dupes} doublon(s) supprime(s) par titre."),
           en = glue::glue("{n_dupes} duplicate(s) removed by title."))
  }

  # ---- Sort and return ----------------------------------------------------
  result <- combined |>
    dplyr::arrange(dplyr::desc(.data$year), .data$title)

  pg_msg("success",
         fr = glue::glue("Fusion terminee : {nrow(result)} entrees uniques."),
         en = glue::glue("Merge complete: {nrow(result)} unique entries."))

  result
}
