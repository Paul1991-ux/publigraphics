# ── viz_global.R ──────────────────────────────────────────────────────────────
# Global visualisation and summary functions spanning all production types.
# Exported: pg_radar_productions, pg_curve_timeline, pg_stats_banner.
# ─────────────────────────────────────────────────────────────────────────────


# ── 1. Radar Chart of Productions by Type ────────────────────────────────────

#' Radar Chart of Research Productions by Type
#'
#' Builds a polar (radar) chart showing the distribution of research
#' productions across classified types. Each axis represents a production
#' type and its radial extent is proportional to the count normalised by the
#' most frequent type (score 0--100). Raw counts are annotated next to each
#' vertex.
#'
#' Internally calls [pg_summary_table()] to obtain per-type counts, then
#' normalises them to a 0--100 scale for the polar geometry.
#'
#' @param data A data frame (typically from [pg_classify()]) containing at
#'   least the columns `type_classified` and `year`.
#' @param theme_color Character. Hex colour used for the polygon fill and
#'   border (default `"#1B4F72"`).
#'
#' @return A `ggplot` object with `coord_polar()`.
#'
#' @examples
#' \dontrun{
#' bib <- pg_read_bib("references.bib")
#' all <- pg_merge_inputs(bib) |> pg_classify()
#' pg_radar_productions(all)
#' }
#'
#' @export
pg_radar_productions <- function(data, theme_color = "#1B4F72") {

  set.seed(2024L)

  tryCatch({

    # ── Validate inputs ──────────────────────────────────────────────────────
    if (!is.data.frame(data)) {
      pg_msg("error",
             "L'argument 'data' doit \u00eatre un data.frame.",
             "Argument 'data' must be a data.frame.")
      stop("Invalid 'data' argument.", call. = FALSE)
    }

    required_cols <- c("type_classified", "year")
    missing_cols  <- setdiff(required_cols, names(data))
    if (length(missing_cols) > 0L) {
      pg_msg("error",
             paste0("Colonnes manquantes : ", paste(missing_cols, collapse = ", ")),
             paste0("Missing columns: ", paste(missing_cols, collapse = ", ")))
      stop("Missing required columns.", call. = FALSE)
    }

    if (!pg_hex_valid(theme_color)) {
      pg_msg("warn",
             "Couleur invalide, utilisation de #1B4F72.",
             "Invalid colour, falling back to #1B4F72.")
      theme_color <- "#1B4F72"
    }

    # ── Compute summary via pg_summary_table ─────────────────────────────────
    summary_tbl <- pg_summary_table(data)

    if (nrow(summary_tbl) == 0L) {
      pg_msg("warn",
             "Tableau r\u00e9capitulatif vide, radar impossible.",
             "Summary table is empty, radar chart not possible.")
      return(ggplot2::ggplot() + ggplot2::theme_void())
    }

    pg_msg("info",
           glue("{nrow(summary_tbl)} types pour le radar."),
           glue("{nrow(summary_tbl)} types for radar chart."))

    # ── Normalise: score = n / max(n) * 100 ──────────────────────────────────
    max_n <- max(summary_tbl$n, na.rm = TRUE)
    if (max_n == 0L) max_n <- 1L

    radar_df <- summary_tbl |>
      mutate(
        score = .data$n / max_n * 100,
        label_bilingual = paste0(.data$label_fr, "\n", .data$label_en)
      )

    # ── Create closed polygon dataframe for coord_polar ──────────────────────
    # coord_polar needs the first row duplicated at the end to close the shape
    radar_closed <- bind_rows(radar_df, radar_df |> slice_head(n = 1L))
    radar_closed <- radar_closed |>
      mutate(axis_id = row_number())

    # ── Build radar plot ─────────────────────────────────────────────────────
    n_axes <- nrow(radar_df)

    p <- ggplot2::ggplot(
      radar_closed,
      ggplot2::aes(x = .data$axis_id, y = .data$score)
    ) +
      # Filled polygon
      ggplot2::geom_polygon(
        fill  = theme_color,
        alpha = 0.3
      ) +
      # Border path
      ggplot2::geom_path(
        color     = theme_color,
        linewidth = 1.2
      ) +
      # Vertex points
      ggplot2::geom_point(
        color = theme_color,
        size  = 3
      ) +
      # Annotate raw counts next to each point (exclude the duplicated last row)
      ggplot2::geom_text(
        data = radar_closed |>
          filter(.data$axis_id <= n_axes),
        ggplot2::aes(
          x     = .data$axis_id,
          y     = .data$score + 8,
          label = .data$n
        ),
        color    = theme_color,
        size     = 3.5,
        fontface = "bold"
      ) +
      # Polar coordinates
      ggplot2::coord_polar(start = -pi / 12) +
      # Bilingual axis labels
      ggplot2::scale_x_continuous(
        breaks = seq_len(n_axes),
        labels = radar_df$label_bilingual,
        limits = c(0.5, n_axes + 0.5)
      ) +
      ggplot2::scale_y_continuous(
        limits = c(0, 120),
        breaks = c(0, 25, 50, 75, 100)
      ) +
      pg_theme(base_color = theme_color) +
      ggplot2::labs(
        title   = "Radar des productions | Production Radar",
        caption = "publigraphics"
      ) +
      ggplot2::theme(
        axis.title       = ggplot2::element_blank(),
        axis.text.y      = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        plot.title       = ggplot2::element_text(hjust = 0.5)
      )

    pg_msg("success",
           "Radar des productions g\u00e9n\u00e9r\u00e9 avec succ\u00e8s.",
           "Production radar chart generated successfully.")

    p

  }, error = function(e) {
    pg_msg("error",
           glue("Erreur dans pg_radar_productions : {conditionMessage(e)}"),
           glue("Error in pg_radar_productions: {conditionMessage(e)}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })
}


# ── 2. Curve Timeline of Productions ─────────────────────────────────────────

#' Curve Timeline of Annual Productions
#'
#' Plots a multi-layer timeline of research productions over time. The total
#' annual count is shown as a filled area with a solid line overlay, while
#' individual production types are drawn as dashed lines coloured by category.
#' The most productive year is annotated with a rich-text label via
#' [ggtext::geom_richtext()].
#'
#' @param data A data frame (typically from [pg_classify()]) containing at
#'   least the columns `type_classified` and `year`.
#' @param theme_color Character. Hex colour used for the total area and line
#'   (default `"#1B4F72"`).
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \dontrun{
#' bib <- pg_read_bib("references.bib")
#' all <- pg_merge_inputs(bib) |> pg_classify()
#' pg_curve_timeline(all)
#' }
#'
#' @export
pg_curve_timeline <- function(data, theme_color = "#1B4F72") {

  set.seed(2024L)

  tryCatch({

    # ── Validate inputs ──────────────────────────────────────────────────────
    if (!is.data.frame(data)) {
      pg_msg("error",
             "L'argument 'data' doit \u00eatre un data.frame.",
             "Argument 'data' must be a data.frame.")
      stop("Invalid 'data' argument.", call. = FALSE)
    }

    required_cols <- c("type_classified", "year")
    missing_cols  <- setdiff(required_cols, names(data))
    if (length(missing_cols) > 0L) {
      pg_msg("error",
             paste0("Colonnes manquantes : ", paste(missing_cols, collapse = ", ")),
             paste0("Missing columns: ", paste(missing_cols, collapse = ", ")))
      stop("Missing required columns.", call. = FALSE)
    }

    if (!pg_hex_valid(theme_color)) {
      pg_msg("warn",
             "Couleur invalide, utilisation de #1B4F72.",
             "Invalid colour, falling back to #1B4F72.")
      theme_color <- "#1B4F72"
    }

    # ── Filter rows with valid year ──────────────────────────────────────────
    data_valid <- data |>
      filter(!is.na(.data$year))

    if (nrow(data_valid) == 0L) {
      pg_msg("warn",
             "Aucune production avec ann\u00e9e valide trouv\u00e9e.",
             "No productions with valid year found.")
      return(ggplot2::ggplot() + ggplot2::theme_void())
    }

    pg_msg("info",
           glue("{nrow(data_valid)} productions avec ann\u00e9e valide pour la courbe."),
           glue("{nrow(data_valid)} productions with valid year for the curve."))

    # ── Count productions by year and type ───────────────────────────────────
    by_year_type <- data_valid |>
      mutate(year_num = as.numeric(.data$year)) |>
      count(.data$year_num, .data$type_classified, name = "n")

    # ── Calculate annual total (all categories) ──────────────────────────────
    total_by_year <- data_valid |>
      mutate(year_num = as.numeric(.data$year)) |>
      count(.data$year_num, name = "n")

    # ── Join bilingual labels for the legend ─────────────────────────────────
    labels_tbl <- pg_type_labels()
    by_year_type <- by_year_type |>
      left_join(labels_tbl, by = "type_classified") |>
      mutate(
        type_label = dplyr::if_else(
          !is.na(.data$label_fr) & !is.na(.data$label_en),
          paste0(.data$label_fr, " | ", .data$label_en),
          .data$type_classified
        )
      )

    # ── Identify most productive year ────────────────────────────────────────
    best_year_row <- total_by_year |>
      filter(.data$n == max(.data$n, na.rm = TRUE)) |>
      slice_head(n = 1L)

    best_year  <- best_year_row$year_num
    best_count <- best_year_row$n

    # ── Build colour palette for type lines ──────────────────────────────────
    n_types <- length(unique(by_year_type$type_label))
    type_palette <- pg_palette(theme_color, n = max(n_types, 1L),
                               type = "qualitative")
    names(type_palette) <- unique(by_year_type$type_label)

    # ── Build plot ───────────────────────────────────────────────────────────
    p <- ggplot2::ggplot() +
      # Total area fill
      ggplot2::geom_area(
        data = total_by_year,
        ggplot2::aes(x = .data$year_num, y = .data$n),
        fill  = theme_color,
        alpha = 0.15
      ) +
      # Total solid line
      ggplot2::geom_line(
        data = total_by_year,
        ggplot2::aes(x = .data$year_num, y = .data$n),
        color     = theme_color,
        linewidth = 1.5
      ) +
      # Total points
      ggplot2::geom_point(
        data = total_by_year,
        ggplot2::aes(x = .data$year_num, y = .data$n),
        color = theme_color,
        size  = 2
      ) +
      # Per-type dashed lines
      ggplot2::geom_line(
        data = by_year_type,
        ggplot2::aes(
          x        = .data$year_num,
          y        = .data$n,
          color    = .data$type_label
        ),
        linewidth = 0.8,
        linetype  = "dashed"
      ) +
      # Annotate most productive year
      ggtext::geom_richtext(
        data = best_year_row,
        ggplot2::aes(
          x     = .data$year_num,
          y     = .data$n,
          label = paste0(
            "<b>", best_year, "</b><br>",
            "<span style='font-size:9pt;'>",
            best_count, " productions</span>"
          )
        ),
        fill       = "white",
        label.color = theme_color,
        label.padding = ggplot2::unit(c(4, 6, 4, 6), "pt"),
        label.r    = ggplot2::unit(3, "pt"),
        size       = 3,
        color      = theme_color,
        nudge_y    = max(total_by_year$n, na.rm = TRUE) * 0.12,
        show.legend = FALSE
      ) +
      # Colour scale for type lines
      ggplot2::scale_color_manual(
        values = type_palette,
        name   = "Type"
      ) +
      ggplot2::scale_x_continuous(
        breaks = scales::breaks_pretty(n = 8)
      ) +
      ggplot2::scale_y_continuous(
        expand = ggplot2::expansion(mult = c(0, 0.15))
      ) +
      pg_theme(base_color = theme_color) +
      ggplot2::labs(
        title   = "Courbe chronologique des productions | Production Timeline Curve",
        x       = "Ann\u00e9e | Year",
        y       = "Nombre | Count",
        caption = "publigraphics"
      )

    pg_msg("success",
           "Courbe chronologique g\u00e9n\u00e9r\u00e9e avec succ\u00e8s.",
           "Production timeline curve generated successfully.")

    p

  }, error = function(e) {
    pg_msg("error",
           glue("Erreur dans pg_curve_timeline : {conditionMessage(e)}"),
           glue("Error in pg_curve_timeline: {conditionMessage(e)}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })
}


# ── 3. Statistics Banner ─────────────────────────────────────────────────────

#' Compute a Global Statistics Banner for All Productions
#'
#' Returns a named list of key summary statistics spanning the full research
#' portfolio. This list is designed to populate dashboard banners, summary
#' cards, or infographic headers.
#'
#' Statistics include per-type counts, career duration, average annual output,
#' the most productive year, the top 3 keywords by global TF-IDF, the number
#' of unique co-authors, and the number of distinct countries where
#' interventions took place.
#'
#' @param data A data frame (typically from [pg_classify()]) containing at
#'   least the columns `type_classified`, `year`, `title`, `keywords`, and
#'   `authors`. Additional columns (`country`, `city`) are used when present.
#'
#' @return A named list with the following elements:
#'   \describe{
#'     \item{n_articles}{Integer. Number of articles.}
#'     \item{n_books}{Integer. Number of books.}
#'     \item{n_book_chapters}{Integer. Number of book chapters.}
#'     \item{n_seminars}{Integer. Number of seminars.}
#'     \item{n_conferences}{Integer. Number of conferences.}
#'     \item{n_reports}{Integer. Number of reports.}
#'     \item{n_theses}{Integer. Number of supervised theses.}
#'     \item{n_patents}{Integer. Number of patents.}
#'     \item{n_media}{Integer. Number of media appearances.}
#'     \item{n_projects}{Integer. Number of funded projects.}
#'     \item{n_awards}{Integer. Number of awards.}
#'     \item{n_expertise}{Integer. Number of expertise / consulting items.}
#'     \item{total_productions}{Integer. Total number of productions.}
#'     \item{career_years}{Integer. Career span in years
#'       (`max(year) - min(year) + 1`).}
#'     \item{most_productive_year}{Numeric. Year with the highest output.}
#'     \item{avg_per_year}{Numeric. Average productions per year (1 decimal).}
#'     \item{top_3_keywords}{Character vector of length 3 (or fewer). Top
#'       keywords by global TF-IDF.}
#'     \item{n_unique_coauthors}{Integer. Number of distinct co-authors.}
#'     \item{n_countries_interventions}{Integer. Number of distinct countries
#'       from the `country` column.}
#'   }
#'
#' @examples
#' \dontrun{
#' bib <- pg_read_bib("references.bib")
#' all <- pg_merge_inputs(bib) |> pg_classify()
#' banner <- pg_stats_banner(all)
#' banner$total_productions
#' banner$top_3_keywords
#' }
#'
#' @export
pg_stats_banner <- function(data) {

  set.seed(2024L)

  tryCatch({

    # ── Validate inputs ──────────────────────────────────────────────────────
    if (!is.data.frame(data)) {
      pg_msg("error",
             "L'argument 'data' doit \u00eatre un data.frame.",
             "Argument 'data' must be a data.frame.")
      stop("Invalid 'data' argument.", call. = FALSE)
    }

    if (!"type_classified" %in% names(data)) {
      pg_msg("error",
             "Colonne 'type_classified' manquante.",
             "Column 'type_classified' is missing.")
      stop("Missing required column 'type_classified'.", call. = FALSE)
    }

    pg_msg("info",
           glue("Calcul du bandeau statistique pour {nrow(data)} productions..."),
           glue("Computing stats banner for {nrow(data)} productions..."))

    # ── Helper: safe count by type ───────────────────────────────────────────
    count_type <- function(type_key) {
      tryCatch(
        sum(str_to_lower(data$type_classified) == type_key, na.rm = TRUE),
        error = function(e) 0L
      )
    }

    n_articles      <- count_type("article")
    n_books         <- count_type("book")
    n_book_chapters <- count_type("book_chapter")
    n_seminars      <- count_type("seminar")
    n_conferences   <- count_type("conference")
    n_reports       <- count_type("report")
    n_theses        <- count_type("thesis_supervised")
    n_patents       <- count_type("patent")
    n_media         <- count_type("media")
    n_projects      <- count_type("project")
    n_awards        <- count_type("award")
    n_expertise     <- count_type("expertise")
    total_productions <- nrow(data)

    # ── Career years ─────────────────────────────────────────────────────────
    career_years <- tryCatch({
      if ("year" %in% names(data)) {
        years_valid <- as.numeric(data$year)
        years_valid <- years_valid[!is.na(years_valid)]
        if (length(years_valid) == 0L) {
          0L
        } else {
          as.integer(max(years_valid) - min(years_valid) + 1L)
        }
      } else {
        0L
      }
    }, error = function(e) 0L)

    # ── Most productive year ─────────────────────────────────────────────────
    most_productive_year <- tryCatch({
      if ("year" %in% names(data)) {
        year_counts <- data |>
          filter(!is.na(.data$year)) |>
          mutate(year_num = as.numeric(.data$year)) |>
          count(.data$year_num, name = "n") |>
          arrange(dplyr::desc(.data$n))
        if (nrow(year_counts) > 0L) {
          year_counts$year_num[1L]
        } else {
          NA_real_
        }
      } else {
        NA_real_
      }
    }, error = function(e) NA_real_)

    # ── Average per year ─────────────────────────────────────────────────────
    avg_per_year <- tryCatch({
      if (career_years > 0L) {
        round(total_productions / career_years, 1)
      } else {
        0
      }
    }, error = function(e) 0)

    # ── Top 3 keywords by global TF-IDF ──────────────────────────────────────
    top_3_keywords <- tryCatch({

      # Extract keywords: handle both list column and character column
      if ("keywords" %in% names(data)) {
        if (is.list(data$keywords)) {
          kw_df <- data |>
            mutate(doc_id = row_number()) |>
            select("doc_id", "keywords") |>
            tidyr::unnest(cols = "keywords") |>
            rename(word = "keywords")
        } else {
          # Character column: split on semicolons or commas
          kw_df <- data |>
            mutate(doc_id = row_number()) |>
            select("doc_id", "keywords") |>
            filter(!is.na(.data$keywords)) |>
            mutate(
              keywords = str_replace_all(.data$keywords, "\\s*;\\s*", ",")
            ) |>
            tidyr::separate_rows("keywords", sep = "\\s*,\\s*") |>
            rename(word = "keywords")
        }
      } else {
        # Fallback: tokenise titles
        kw_df <- data |>
          mutate(doc_id = row_number()) |>
          select("doc_id", "title") |>
          filter(!is.na(.data$title)) |>
          tidytext::unnest_tokens(output = "word", input = "title")
      }

      if (nrow(kw_df) == 0L) stop("empty_kw", call. = FALSE)

      # Clean
      kw_df <- kw_df |>
        mutate(word = str_trim(str_to_lower(.data$word))) |>
        filter(
          !is.na(.data$word),
          nchar(.data$word) >= 3L,
          !str_detect(.data$word, "^[0-9]+$")
        )

      # Remove stopwords (FR + EN)
      stopwords_combined <- tryCatch({
        sw <- tibble(word = character(0L))
        sw_en <- tidytext::get_stopwords(language = "en")
        sw_fr <- tidytext::get_stopwords(language = "fr", source = "snowball")
        sw <- bind_rows(sw, sw_en |> select("word"), sw_fr |> select("word")) |>
          distinct()
        sw
      }, error = function(e) tibble(word = character(0L)))

      kw_df <- kw_df |>
        filter(!(.data$word %in% stopwords_combined$word))

      if (nrow(kw_df) == 0L) stop("empty_kw", call. = FALSE)

      # Compute TF-IDF
      word_counts <- kw_df |>
        count(.data$doc_id, .data$word, name = "n")

      tfidf <- tryCatch({
        word_counts |>
          tidytext::bind_tf_idf(term = "word", document = "doc_id", n = "n")
      }, error = function(e) NULL)

      if (is.null(tfidf)) stop("empty_kw", call. = FALSE)

      # Mean TF-IDF per keyword across all documents
      top_kw <- tfidf |>
        group_by(.data$word) |>
        summarise(
          mean_tfidf = mean(.data$tf_idf, na.rm = TRUE),
          .groups    = "drop"
        ) |>
        arrange(dplyr::desc(.data$mean_tfidf)) |>
        slice_head(n = 3L) |>
        pull(.data$word)

      top_kw

    }, error = function(e) {
      pg_msg("warn",
             glue("Erreur lors du calcul des mots-cl\u00e9s TF-IDF : {conditionMessage(e)}"),
             glue("Error computing TF-IDF keywords: {conditionMessage(e)}"))
      character(0L)
    })

    # ── Number of unique co-authors ──────────────────────────────────────────
    n_unique_coauthors <- tryCatch({
      if ("authors" %in% names(data)) {
        if (is.list(data$authors)) {
          all_authors <- data$authors |>
            purrr::map(function(a) {
              if (is.null(a) || all(is.na(a))) return(character(0L))
              as.character(a)
            }) |>
            unlist() |>
            str_trim() |>
            str_to_lower()
          all_authors <- all_authors[!is.na(all_authors) & nchar(all_authors) > 0L]
          length(unique(all_authors))
        } else {
          # Character column: split using pg_clean_authors logic
          all_authors <- data$authors |>
            purrr::map(pg_clean_authors) |>
            unlist() |>
            str_trim() |>
            str_to_lower()
          all_authors <- all_authors[!is.na(all_authors) & nchar(all_authors) > 0L]
          length(unique(all_authors))
        }
      } else {
        0L
      }
    }, error = function(e) {
      pg_msg("warn",
             glue("Erreur lors du comptage des coauteurs : {conditionMessage(e)}"),
             glue("Error counting co-authors: {conditionMessage(e)}"))
      0L
    })

    # ── Number of distinct countries ─────────────────────────────────────────
    n_countries_interventions <- tryCatch({
      if ("country" %in% names(data)) {
        countries <- data$country |>
          str_trim() |>
          str_to_lower()
        countries <- countries[!is.na(countries) & nchar(countries) > 0L]
        length(unique(countries))
      } else {
        0L
      }
    }, error = function(e) {
      pg_msg("warn",
             glue("Erreur lors du comptage des pays : {conditionMessage(e)}"),
             glue("Error counting countries: {conditionMessage(e)}"))
      0L
    })

    # ── Assemble result list ─────────────────────────────────────────────────
    banner <- list(
      n_articles                = n_articles,
      n_books                   = n_books,
      n_book_chapters           = n_book_chapters,
      n_seminars                = n_seminars,
      n_conferences             = n_conferences,
      n_reports                 = n_reports,
      n_theses                  = n_theses,
      n_patents                 = n_patents,
      n_media                   = n_media,
      n_projects                = n_projects,
      n_awards                  = n_awards,
      n_expertise               = n_expertise,
      total_productions         = total_productions,
      career_years              = career_years,
      most_productive_year      = most_productive_year,
      avg_per_year              = avg_per_year,
      top_3_keywords            = top_3_keywords,
      n_unique_coauthors        = n_unique_coauthors,
      n_countries_interventions = n_countries_interventions
    )

    pg_msg("success",
           glue("Bandeau statistique calcul\u00e9 : {total_productions} productions, ",
                "{career_years} ann\u00e9es de carri\u00e8re."),
           glue("Stats banner computed: {total_productions} productions, ",
                "{career_years} career years."))

    banner

  }, error = function(e) {
    pg_msg("error",
           glue("Erreur dans pg_stats_banner : {conditionMessage(e)}"),
           glue("Error in pg_stats_banner: {conditionMessage(e)}"))

    # Return a safe empty banner on failure
    list(
      n_articles                = 0L,
      n_books                   = 0L,
      n_book_chapters           = 0L,
      n_seminars                = 0L,
      n_conferences             = 0L,
      n_reports                 = 0L,
      n_theses                  = 0L,
      n_patents                 = 0L,
      n_media                   = 0L,
      n_projects                = 0L,
      n_awards                  = 0L,
      n_expertise               = 0L,
      total_productions         = 0L,
      career_years              = 0L,
      most_productive_year      = NA_real_,
      avg_per_year              = 0,
      top_3_keywords            = character(0L),
      n_unique_coauthors        = 0L,
      n_countries_interventions = 0L
    )
  })
}
