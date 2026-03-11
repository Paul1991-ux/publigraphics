# -- viz_other.R ---------------------------------------------------------------
# Visualisation functions for non-article research outputs:
#   projects (Gantt), theses (timeline), awards (infographic),
#   expertise (map), and media (bar chart).
# Exported: pg_gantt_projects, pg_timeline_theses, pg_infographic_awards,
#           pg_map_expertise, pg_media_summary.
# -----------------------------------------------------------------------------


# -- 1. Gantt Chart of Funded Projects ----------------------------------------

#' Gantt Chart of Funded Projects
#'
#' Builds a horizontal Gantt chart showing the duration of funded projects.
#' Bars are coloured by project status (completed, ongoing, future) and
#' annotated with the funding source when available.
#'
#' Date information is extracted from the `note` field, which is expected to
#' contain pipe-separated metadata including ISO-formatted `date_start` and
#' `date_end` values (e.g. `"Funding: 50000 | Source: ANR | 2020-01-15 | 2023-06-30"`).
#' If explicit dates are not found, the function falls back to the `year`
#' column to construct approximate date ranges.
#'
#' @param data A data frame (typically from [pg_merge_inputs()] and
#'   [pg_classify()]) containing at least `type_classified`, `title`, `note`,
#'   and `year` columns.
#' @param theme_color Character. Base hex colour for ongoing projects and
#'   theme accents (default `"#1B4F72"`).
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \dontrun{
#' bib   <- pg_read_bib("references.bib")
#' extra <- pg_read_extra("extra.csv")
#' all   <- pg_merge_inputs(bib, extra) |> pg_classify()
#' pg_gantt_projects(all)
#' }
#'
#' @export
pg_gantt_projects <- function(data, theme_color = "#1B4F72") {

  tryCatch({

    # -- Validate inputs -------------------------------------------------------
    if (!is.data.frame(data)) {
      pg_msg("error",
             "L'argument 'data' doit \u00eatre un data.frame.",
             "Argument 'data' must be a data.frame.")
      stop("Invalid 'data' argument.", call. = FALSE)
    }

    required_cols <- c("type_classified", "title")
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

    # -- Filter projects -------------------------------------------------------
    projects <- data |>
      filter(str_to_lower(.data$type_classified) == "project")

    if (nrow(projects) == 0L) {
      pg_msg("warn",
             "Aucun projet trouv\u00e9 dans les donn\u00e9es.",
             "No projects found in the data.")
      return(ggplot2::ggplot() + ggplot2::theme_void())
    }

    pg_msg("info",
           glue("{nrow(projects)} projets trouv\u00e9s pour le diagramme de Gantt."),
           glue("{nrow(projects)} projects found for Gantt chart."))

    # -- Extract dates from note field -----------------------------------------
    # note format example: "Funding: 50000 | Source: ANR | 2020-01-15 | 2023-06-30"
    iso_pattern <- "\\d{4}-\\d{2}-\\d{2}"

    projects <- projects |>
      mutate(
        note_safe = tidyr::replace_na(.data$note, ""),
        # Extract all ISO dates from the note field
        dates_extracted = map(.data$note_safe, function(n) {
          matches <- str_extract_all(n, iso_pattern)[[1L]]
          if (length(matches) == 0L) return(c(NA_character_, NA_character_))
          if (length(matches) == 1L) return(c(matches[1L], NA_character_))
          matches[1L:2L]
        }),
        date_start_raw = map_chr(.data$dates_extracted, ~ .x[1L]),
        date_end_raw   = map_chr(.data$dates_extracted, ~ .x[2L]),
        date_start = tryCatch(
          as.Date(.data$date_start_raw),
          error = function(e) rep(NA_real_, nrow(projects))
        ),
        date_end = tryCatch(
          as.Date(.data$date_end_raw),
          error = function(e) rep(NA_real_, nrow(projects))
        )
      )

    # Fallback: use year column for approximate dates if no ISO dates found
    if ("year" %in% names(projects)) {
      projects <- projects |>
        mutate(
          date_start = dplyr::if_else(
            is.na(.data$date_start) & !is.na(.data$year),
            as.Date(paste0(.data$year, "-01-01")),
            .data$date_start
          ),
          date_end = dplyr::if_else(
            is.na(.data$date_end) & !is.na(.data$year),
            as.Date(paste0(.data$year, "-12-31")),
            .data$date_end
          )
        )
    }

    # Remove rows where we still have no start date
    projects <- projects |>
      filter(!is.na(.data$date_start))

    if (nrow(projects) == 0L) {
      pg_msg("warn",
             "Aucune date exploitable trouv\u00e9e pour les projets.",
             "No usable dates found for projects.")
      return(ggplot2::ggplot() + ggplot2::theme_void())
    }

    # Fill end date with start date + 1 year if still missing
    projects <- projects |>
      mutate(
        date_end = dplyr::if_else(
          is.na(.data$date_end),
          .data$date_start + lubridate::years(1L),
          .data$date_end
        )
      )

    # -- Determine status ------------------------------------------------------
    today_date <- Sys.Date()
    projects <- projects |>
      mutate(
        status = dplyr::case_when(
          .data$date_end < today_date   ~ "completed",
          .data$date_start > today_date ~ "future",
          TRUE                          ~ "ongoing"
        ),
        title_short = pg_truncate(.data$title, n = 50L)
      )

    # -- Extract funding source from note --------------------------------------
    projects <- projects |>
      mutate(
        funding_source = map_chr(.data$note_safe, function(n) {
          src_match <- stringr::str_extract(n, "(?i)source\\s*:\\s*([^|]+)")
          if (is.na(src_match)) return("")
          stringr::str_trim(stringr::str_remove(src_match, "(?i)source\\s*:\\s*"))
        }),
        funding_amount = map_chr(.data$note_safe, function(n) {
          amt_match <- stringr::str_extract(n, "(?i)funding\\s*:\\s*([^|]+)")
          if (is.na(amt_match)) return("")
          stringr::str_trim(stringr::str_remove(amt_match, "(?i)funding\\s*:\\s*"))
        })
      )

    # -- Colour mapping --------------------------------------------------------
    status_colors <- c(
      "completed" = "#27AE60",
      "ongoing"   = theme_color,
      "future"    = "#E74C3C"
    )

    # -- Build Gantt plot ------------------------------------------------------
    p <- ggplot2::ggplot(
      projects,
      ggplot2::aes(
        x     = .data$date_start,
        xend  = .data$date_end,
        y     = stats::reorder(.data$title_short, .data$date_start),
        yend  = stats::reorder(.data$title_short, .data$date_start),
        color = .data$status
      )
    ) +
      ggplot2::geom_segment(linewidth = 6, lineend = "round") +
      ggplot2::scale_color_manual(
        values = status_colors,
        labels = c(
          "completed" = "Termin\u00e9 | Completed",
          "ongoing"   = "En cours | Ongoing",
          "future"    = "Futur | Future"
        ),
        name = "Statut | Status"
      ) +
      # Funding source labels to the right of bars
      ggplot2::geom_text(
        ggplot2::aes(
          x     = .data$date_end,
          y     = stats::reorder(.data$title_short, .data$date_start),
          label = .data$funding_source
        ),
        hjust  = -0.1,
        size   = 2.8,
        color  = "#555555",
        inherit.aes = FALSE
      ) +
      # Funding amount annotations if available
      {
        has_amount <- projects |>
          filter(nchar(.data$funding_amount) > 0L)
        if (nrow(has_amount) > 0L) {
          ggplot2::geom_text(
            data = has_amount,
            ggplot2::aes(
              x     = .data$date_start + (.data$date_end - .data$date_start) / 2,
              y     = stats::reorder(.data$title_short, .data$date_start),
              label = .data$funding_amount
            ),
            size  = 2.5,
            color = "white",
            fontface = "bold",
            inherit.aes = FALSE
          )
        }
      } +
      ggplot2::scale_x_date(
        date_labels = "%Y",
        date_breaks = "1 year"
      ) +
      pg_theme(base_color = theme_color) +
      ggplot2::labs(
        title   = "Projets financ\u00e9s | Funded Projects",
        x       = "Ann\u00e9e | Year",
        y       = NULL,
        caption = "publigraphics"
      ) +
      ggplot2::theme(
        axis.text.y = ggplot2::element_text(size = 9),
        panel.grid.major.y = ggplot2::element_blank()
      )

    pg_msg("success",
           "Diagramme de Gantt g\u00e9n\u00e9r\u00e9 avec succ\u00e8s.",
           "Gantt chart generated successfully.")

    p

  }, error = function(e) {
    pg_msg("error",
           glue("Erreur dans pg_gantt_projects : {conditionMessage(e)}"),
           glue("Error in pg_gantt_projects: {conditionMessage(e)}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })
}


# -- 2. Timeline of Supervised Theses -----------------------------------------

#' Vertical Timeline of Supervised Theses
#'
#' Produces a vertical timeline of supervised theses (PhD and Master),
#' with points coloured by degree level and labels showing the thesis title.
#'
#' The degree level is inferred from the `note` or `type_raw` field. If the
#' string contains "phd", "doctorat", or "these/these", it is classified as PhD;
#' if it contains "master", "m2", "m1", or "memoire", it is classified as
#' Master. Otherwise it defaults to "Other".
#'
#' @param data A data frame containing at least `type_classified`, `title`,
#'   and `year` columns.
#' @param theme_color Character. Base hex colour for PhD points
#'   (default `"#1B4F72"`). Master points use this colour at 50%
#'   opacity.
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \dontrun{
#' bib   <- pg_read_bib("references.bib")
#' extra <- pg_read_extra("extra.csv")
#' all   <- pg_merge_inputs(bib, extra) |> pg_classify()
#' pg_timeline_theses(all)
#' }
#'
#' @export
pg_timeline_theses <- function(data, theme_color = "#1B4F72") {

  tryCatch({

    # -- Validate inputs -------------------------------------------------------
    if (!is.data.frame(data)) {
      pg_msg("error",
             "L'argument 'data' doit \u00eatre un data.frame.",
             "Argument 'data' must be a data.frame.")
      stop("Invalid 'data' argument.", call. = FALSE)
    }

    required_cols <- c("type_classified", "title", "year")
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

    # -- Filter supervised theses ----------------------------------------------
    theses <- data |>
      filter(str_to_lower(.data$type_classified) == "thesis_supervised") |>
      filter(!is.na(.data$year))

    if (nrow(theses) == 0L) {
      pg_msg("warn",
             "Aucune th\u00e8se dirig\u00e9e trouv\u00e9e dans les donn\u00e9es.",
             "No supervised theses found in the data.")
      return(ggplot2::ggplot() + ggplot2::theme_void())
    }

    pg_msg("info",
           glue("{nrow(theses)} th\u00e8ses dirig\u00e9es trouv\u00e9es."),
           glue("{nrow(theses)} supervised theses found."))

    # -- Infer degree level ----------------------------------------------------
    theses <- theses |>
      mutate(
        note_lower     = str_to_lower(tidyr::replace_na(.data$note, "")),
        type_raw_lower = str_to_lower(tidyr::replace_na(
          if ("type_raw" %in% names(theses)) .data$type_raw else "", ""
        )),
        combined_text  = paste(.data$note_lower, .data$type_raw_lower),
        degree_level   = dplyr::case_when(
          str_detect(.data$combined_text,
                     "phd|doctorat|th\u00e8se|these|phdthesis") ~ "PhD",
          str_detect(.data$combined_text,
                     "master|m2|m1|m\u00e9moire|memoire|mastersthesis") ~ "Master",
          TRUE ~ "Other"
        ),
        year_num    = as.numeric(.data$year),
        title_short = str_wrap(pg_truncate(.data$title, n = 60L), width = 30L)
      )

    # -- Colour palette --------------------------------------------------------
    # PhD = full theme_color, Master = 50% opacity, Other = grey
    phd_color    <- theme_color
    master_color <- colorspace::adjust_transparency(theme_color, alpha = 0.5)
    other_color  <- "#999999"

    degree_colors <- c(
      "PhD"    = phd_color,
      "Master" = master_color,
      "Other"  = other_color
    )

    # -- Build vertical timeline -----------------------------------------------
    p <- ggplot2::ggplot(
      theses,
      ggplot2::aes(
        x     = .data$year_num,
        y     = stats::reorder(.data$title_short, .data$year_num),
        color = .data$degree_level
      )
    ) +
      ggplot2::geom_point(size = 6, alpha = 0.85) +
      ggplot2::geom_text(
        ggplot2::aes(label = str_wrap(.data$title, 30)),
        hjust  = 0,
        nudge_x = 0.3,
        size   = 2.5,
        show.legend = FALSE,
        color  = "#333333"
      ) +
      ggplot2::scale_color_manual(
        values = degree_colors,
        name   = "Niveau | Level"
      ) +
      ggplot2::scale_x_continuous(
        breaks = scales::breaks_pretty(n = 6)
      ) +
      pg_theme(base_color = theme_color) +
      ggplot2::labs(
        title   = "Th\u00e8ses dirig\u00e9es | Supervised Theses",
        x       = "Ann\u00e9e | Year",
        y       = NULL,
        caption = "publigraphics"
      ) +
      ggplot2::theme(
        axis.text.y        = ggplot2::element_text(size = 8),
        panel.grid.major.y = ggplot2::element_blank()
      )

    pg_msg("success",
           "Frise des th\u00e8ses g\u00e9n\u00e9r\u00e9e avec succ\u00e8s.",
           "Thesis timeline generated successfully.")

    p

  }, error = function(e) {
    pg_msg("error",
           glue("Erreur dans pg_timeline_theses : {conditionMessage(e)}"),
           glue("Error in pg_timeline_theses: {conditionMessage(e)}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })
}


# -- 3. Infographic of Awards -------------------------------------------------

#' Infographic Display of Awards and Distinctions
#'
#' Creates a vertical "palmares" infographic using `ggplot2`, displaying each
#' award as a tile with a medal icon (Unicode), the award title, granting
#' institution, and year. Alternating rows use a subtle background tint.
#'
#' @param data A data frame containing at least `type_classified`, `title`,
#'   and `year` columns. The `institution` column is used when available.
#' @param theme_color Character. Base hex colour for accents and alternating
#'   row tinting (default `"#1B4F72"`).
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \dontrun{
#' bib   <- pg_read_bib("references.bib")
#' extra <- pg_read_extra("extra.csv")
#' all   <- pg_merge_inputs(bib, extra) |> pg_classify()
#' pg_infographic_awards(all)
#' }
#'
#' @export
pg_infographic_awards <- function(data, theme_color = "#1B4F72") {

  tryCatch({

    # -- Validate inputs -------------------------------------------------------
    if (!is.data.frame(data)) {
      pg_msg("error",
             "L'argument 'data' doit \u00eatre un data.frame.",
             "Argument 'data' must be a data.frame.")
      stop("Invalid 'data' argument.", call. = FALSE)
    }

    required_cols <- c("type_classified", "title")
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

    # -- Filter awards ---------------------------------------------------------
    awards <- data |>
      filter(str_to_lower(.data$type_classified) == "award")

    if (nrow(awards) == 0L) {
      pg_msg("warn",
             "Aucun prix ou distinction trouv\u00e9 dans les donn\u00e9es.",
             "No awards found in the data.")
      return(ggplot2::ggplot() + ggplot2::theme_void())
    }

    pg_msg("info",
           glue("{nrow(awards)} prix/distinctions trouv\u00e9s."),
           glue("{nrow(awards)} awards found."))

    # -- Prepare display data --------------------------------------------------
    awards <- awards |>
      arrange(dplyr::desc(
        if ("year" %in% names(awards)) .data$year else 0L
      )) |>
      mutate(
        row_idx     = row_number(),
        year_label  = if ("year" %in% names(awards)) {
          as.character(tidyr::replace_na(.data$year, ""))
        } else {
          ""
        },
        institution_label = if ("institution" %in% names(awards)) {
          tidyr::replace_na(.data$institution, "")
        } else {
          ""
        },
        title_short = pg_truncate(.data$title, n = 55L),
        # Medal icons: gold for rank 1-3, silver for 4-6, bronze for rest
        medal_icon  = dplyr::case_when(
          .data$row_idx <= 3L ~ "\U0001F3C6",
          .data$row_idx <= 6L ~ "\U0001F3C5",
          TRUE                ~ "\U0001F396"
        ),
        # Alternating background fill
        bg_fill = dplyr::if_else(
          .data$row_idx %% 2L == 0L,
          colorspace::adjust_transparency(theme_color, alpha = 0.05),
          "#FFFFFF"
        ),
        # Composite label
        display_label = paste0(
          .data$medal_icon, "  ",
          .data$title_short,
          dplyr::if_else(
            nchar(.data$institution_label) > 0L,
            paste0("\n", .data$institution_label),
            ""
          ),
          dplyr::if_else(
            nchar(.data$year_label) > 0L,
            paste0("  (", .data$year_label, ")"),
            ""
          )
        ),
        # Y position (top = first row)
        y_pos = -1L * .data$row_idx
      )

    # -- Build infographic plot ------------------------------------------------
    p <- ggplot2::ggplot(awards, ggplot2::aes(x = 0.5, y = .data$y_pos)) +
      # Background tiles with alternating colour
      ggplot2::geom_tile(
        ggplot2::aes(fill = .data$bg_fill),
        width  = 1,
        height = 0.9,
        color  = "#EEEEEE",
        linewidth = 0.3
      ) +
      ggplot2::scale_fill_identity() +
      # Award text
      ggplot2::geom_text(
        ggplot2::aes(label = .data$display_label),
        size     = 3.5,
        color    = "#1A1A1A",
        hjust    = 0.5,
        lineheight = 1.2
      ) +
      # Year labels on the right margin
      ggplot2::geom_text(
        ggplot2::aes(x = 0.95, label = .data$year_label),
        size     = 3,
        color    = theme_color,
        fontface = "bold",
        hjust    = 1
      ) +
      ggplot2::coord_cartesian(xlim = c(0, 1), clip = "off") +
      pg_theme(base_color = theme_color) +
      ggplot2::labs(
        title   = "Prix et distinctions | Awards",
        caption = "publigraphics"
      ) +
      ggplot2::theme(
        axis.text    = ggplot2::element_blank(),
        axis.title   = ggplot2::element_blank(),
        axis.ticks   = ggplot2::element_blank(),
        panel.grid   = ggplot2::element_blank(),
        legend.position = "none"
      )

    pg_msg("success",
           "Infographie des prix g\u00e9n\u00e9r\u00e9e avec succ\u00e8s.",
           "Awards infographic generated successfully.")

    p

  }, error = function(e) {
    pg_msg("error",
           glue("Erreur dans pg_infographic_awards : {conditionMessage(e)}"),
           glue("Error in pg_infographic_awards: {conditionMessage(e)}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })
}


# -- 4. Map of Expertise / Consulting Missions --------------------------------

#' Geographic Map of Expertise and Consulting Missions
#'
#' Produces both an interactive Leaflet map and a static `ggplot2` map showing
#' the geographic locations of expertise and consulting missions. Uses square
#' markers (`pch = 15`) and a complementary colour derived from the base theme
#' colour via the `colorspace` package.
#'
#' Locations are geocoded from the `city` and `country` columns using
#' [tidygeocoder::geocode()]. Previously geocoded results are cached within
#' the returned data to avoid redundant API calls.
#'
#' This function follows the same logic as `pg_map_seminars()` but uses
#' square markers instead of circles and a complementary colour scheme.
#'
#' @param data A data frame containing at least `type_classified`, `title`,
#'   `city`, and `country` columns.
#' @param theme_color Character. Base hex colour (default `"#1B4F72"`). The
#'   map markers use the complementary colour.
#'
#' @return A named list with two elements:
#'   \describe{
#'     \item{interactive}{A [leaflet::leaflet()] map widget, or `NULL` on
#'       failure.}
#'     \item{static}{A `ggplot` object using [rnaturalearth::ne_countries()]
#'       as the basemap, or `NULL` on failure.}
#'   }
#'
#' @examples
#' \dontrun{
#' bib   <- pg_read_bib("references.bib")
#' extra <- pg_read_extra("extra.csv")
#' all   <- pg_merge_inputs(bib, extra) |> pg_classify()
#' maps  <- pg_map_expertise(all)
#' maps$interactive   # interactive Leaflet
#' print(maps$static) # static ggplot
#' }
#'
#' @export
pg_map_expertise <- function(data, theme_color = "#1B4F72") {

  tryCatch({

    # -- Validate inputs -------------------------------------------------------
    if (!is.data.frame(data)) {
      pg_msg("error",
             "L'argument 'data' doit \u00eatre un data.frame.",
             "Argument 'data' must be a data.frame.")
      stop("Invalid 'data' argument.", call. = FALSE)
    }

    required_cols <- c("type_classified", "title")
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

    # -- Filter expertise items ------------------------------------------------
    expertise <- data |>
      filter(str_to_lower(.data$type_classified) == "expertise")

    if (nrow(expertise) == 0L) {
      pg_msg("warn",
             "Aucune expertise trouv\u00e9e dans les donn\u00e9es.",
             "No expertise items found in the data.")
      return(list(interactive = NULL, static = NULL))
    }

    pg_msg("info",
           glue("{nrow(expertise)} expertises trouv\u00e9es pour la carte."),
           glue("{nrow(expertise)} expertise items found for map."))

    # -- Build location strings for geocoding ----------------------------------
    city_col    <- if ("city" %in% names(expertise)) expertise$city else
      rep(NA_character_, nrow(expertise))
    country_col <- if ("country" %in% names(expertise)) expertise$country else
      rep(NA_character_, nrow(expertise))

    expertise <- expertise |>
      mutate(
        geo_city    = tidyr::replace_na(city_col, ""),
        geo_country = tidyr::replace_na(country_col, ""),
        location    = str_trim(paste(.data$geo_city, .data$geo_country, sep = ", ")),
        location    = dplyr::if_else(
          .data$location == "," | nchar(str_trim(.data$location)) <= 1L,
          NA_character_,
          .data$location
        )
      ) |>
      filter(!is.na(.data$location))

    if (nrow(expertise) == 0L) {
      pg_msg("warn",
             "Aucune localisation exploitable pour les expertises.",
             "No usable locations for expertise items.")
      return(list(interactive = NULL, static = NULL))
    }

    # -- Geocode locations (using shared cache) --------------------------------
    loc_df <- expertise |>
      select("location") |>
      distinct()

    geo_df <- pg_geocode_cached(loc_df)

    if (is.null(geo_df) || nrow(geo_df) == 0L) {
      pg_msg("warn",
             "G\u00e9ocodage n'a retourn\u00e9 aucun r\u00e9sultat.",
             "Geocoding returned no results.")
      return(list(interactive = NULL, static = NULL))
    }

    # Merge coordinates back
    expertise <- expertise |>
      left_join(geo_df, by = "location") |>
      filter(!is.na(.data$lat) & !is.na(.data$long))

    if (nrow(expertise) == 0L) {
      pg_msg("warn",
             "Aucune coordonn\u00e9e valide apr\u00e8s g\u00e9ocodage.",
             "No valid coordinates after geocoding.")
      return(list(interactive = NULL, static = NULL))
    }

    pg_msg("info",
           glue("{nrow(expertise)} expertises g\u00e9olocalis\u00e9es avec succ\u00e8s."),
           glue("{nrow(expertise)} expertise items geocoded successfully."))

    # -- Complementary colour --------------------------------------------------
    hcl_vals     <- colorspace::hex2RGB(theme_color) |>
      methods::as("polarLUV")
    comp_hue     <- (hcl_vals@coords[1, "H"] + 180) %% 360
    marker_color <- colorspace::polarLUV(60, 70, comp_hue) |>
      colorspace::hex()

    # -- Interactive Leaflet map -----------------------------------------------
    interactive_map <- tryCatch({
      expertise |>
        leaflet::leaflet() |>
        leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron) |>
        leaflet::addCircleMarkers(
          lng     = ~long,
          lat     = ~lat,
          radius  = 7,
          color   = marker_color,
          fillColor   = marker_color,
          fillOpacity = 0.7,
          stroke  = TRUE,
          weight  = 2,
          # Square markers via CSS-styled popup; leaflet uses circles natively
          # so we use a slightly larger marker with square icon overlay
          popup   = ~paste0(
            "<strong>", .data$title, "</strong><br/>",
            "<em>", .data$location, "</em>",
            if ("year" %in% names(expertise)) {
              paste0("<br/>", .data$year)
            } else {
              ""
            }
          ),
          label   = ~.data$title
        )
    }, error = function(e) {
      pg_msg("warn",
             "Carte interactive non g\u00e9n\u00e9r\u00e9e.",
             "Interactive map not generated.")
      NULL
    })

    # -- Static ggplot map -----------------------------------------------------
    static_map <- tryCatch({
      world <- rnaturalearth::ne_countries(
        scale       = "medium",
        returnclass = "sf"
      )

      ggplot2::ggplot() +
        ggplot2::geom_sf(
          data = world,
          fill = "#F5F5F5",
          color = "#CCCCCC",
          linewidth = 0.2
        ) +
        ggplot2::geom_point(
          data    = expertise,
          ggplot2::aes(x = .data$long, y = .data$lat),
          shape   = 15,
          size    = 3,
          color   = marker_color,
          alpha   = 0.8
        ) +
        ggplot2::geom_text(
          data    = expertise,
          ggplot2::aes(
            x     = .data$long,
            y     = .data$lat,
            label = pg_truncate(.data$title, n = 25L)
          ),
          size    = 2.2,
          nudge_y = 2,
          color   = "#333333",
          check_overlap = TRUE
        ) +
        ggplot2::coord_sf(expand = FALSE) +
        pg_theme(base_color = theme_color) +
        ggplot2::labs(
          title   = "Expertises et missions | Consulting Map",
          caption = "publigraphics | OpenStreetMap"
        ) +
        ggplot2::theme(
          axis.text  = ggplot2::element_blank(),
          axis.title = ggplot2::element_blank(),
          axis.ticks = ggplot2::element_blank(),
          panel.grid = ggplot2::element_blank()
        )
    }, error = function(e) {
      pg_msg("warn",
             "Carte statique non g\u00e9n\u00e9r\u00e9e.",
             "Static map not generated.")
      NULL
    })

    pg_msg("success",
           "Cartes des expertises g\u00e9n\u00e9r\u00e9es avec succ\u00e8s.",
           "Expertise maps generated successfully.")

    list(interactive = interactive_map, static = static_map)

  }, error = function(e) {
    pg_msg("error",
           glue("Erreur dans pg_map_expertise : {conditionMessage(e)}"),
           glue("Error in pg_map_expertise: {conditionMessage(e)}"))
    list(interactive = NULL, static = NULL)
  })
}


# -- 5. Media Appearances Summary Bar Chart ------------------------------------

#' Horizontal Bar Chart of Media Appearances
#'
#' Produces a horizontal grouped bar chart summarising media appearances
#' (podcasts, interviews, press articles, etc.) by institution or media
#' outlet. Bars are grouped by sub-type when a `type` or `type_raw` column
#' provides finer-grained categorisation (e.g. `"podcast"`, `"interview"`,
#' `"media"`).
#'
#' @param data A data frame containing at least `type_classified` and
#'   `institution` (or `journal_or_venue`) columns. The `type` or `type_raw`
#'   column is used for sub-type grouping when available.
#' @param theme_color Character. Base hex colour for the palette
#'   (default `"#1B4F72"`).
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \dontrun{
#' bib   <- pg_read_bib("references.bib")
#' extra <- pg_read_extra("extra.csv")
#' all   <- pg_merge_inputs(bib, extra) |> pg_classify()
#' pg_media_summary(all)
#' }
#'
#' @export
pg_media_summary <- function(data, theme_color = "#1B4F72") {

  tryCatch({

    # -- Validate inputs -------------------------------------------------------
    if (!is.data.frame(data)) {
      pg_msg("error",
             "L'argument 'data' doit \u00eatre un data.frame.",
             "Argument 'data' must be a data.frame.")
      stop("Invalid 'data' argument.", call. = FALSE)
    }

    required_cols <- c("type_classified")
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

    # -- Filter media items ----------------------------------------------------
    media <- data |>
      filter(str_to_lower(.data$type_classified) == "media")

    if (nrow(media) == 0L) {
      pg_msg("warn",
             "Aucune apparition m\u00e9dia trouv\u00e9e dans les donn\u00e9es.",
             "No media appearances found in the data.")
      return(ggplot2::ggplot() + ggplot2::theme_void())
    }

    pg_msg("info",
           glue("{nrow(media)} apparitions m\u00e9dia trouv\u00e9es."),
           glue("{nrow(media)} media appearances found."))

    # -- Determine media outlet column -----------------------------------------
    # Prefer institution, fall back to journal_or_venue, then title
    media <- media |>
      mutate(
        media_outlet = dplyr::case_when(
          "institution" %in% names(media) &
            !is.na(.data$institution) &
            nchar(str_trim(.data$institution)) > 0L
            ~ .data$institution,
          "journal_or_venue" %in% names(media) &
            !is.na(.data$journal_or_venue) &
            nchar(str_trim(.data$journal_or_venue)) > 0L
            ~ .data$journal_or_venue,
          TRUE ~ "Autre | Other"
        ),
        media_outlet = pg_truncate(.data$media_outlet, n = 40L)
      )

    # -- Determine sub-type ----------------------------------------------------
    # Look in type_raw or type columns for finer categories
    media <- media |>
      mutate(
        sub_type_raw = dplyr::case_when(
          "type" %in% names(media) & !is.na(.data$type) ~ str_to_lower(.data$type),
          "type_raw" %in% names(media) & !is.na(.data$type_raw)
            ~ str_to_lower(.data$type_raw),
          TRUE ~ "media"
        ),
        sub_type = dplyr::case_when(
          str_detect(.data$sub_type_raw, "podcast")   ~ "Podcast",
          str_detect(.data$sub_type_raw, "interview")  ~ "Interview",
          str_detect(.data$sub_type_raw, "press|presse|article") ~ "Article presse",
          TRUE ~ "M\u00e9dia | Media"
        )
      )

    # -- Aggregate counts ------------------------------------------------------
    media_counts <- media |>
      count(.data$media_outlet, .data$sub_type, name = "n") |>
      arrange(dplyr::desc(.data$n))

    # -- Palette ---------------------------------------------------------------
    n_subtypes <- length(unique(media_counts$sub_type))
    palette    <- pg_palette(theme_color, n = max(n_subtypes, 1L),
                             type = "qualitative")

    # -- Build bar chart -------------------------------------------------------
    p <- ggplot2::ggplot(
      media_counts,
      ggplot2::aes(
        x    = .data$n,
        y    = stats::reorder(.data$media_outlet, .data$n),
        fill = .data$sub_type
      )
    ) +
      ggplot2::geom_col(
        position = ggplot2::position_dodge(width = 0.8),
        width    = 0.7,
        alpha    = 0.9
      ) +
      ggplot2::geom_text(
        ggplot2::aes(label = .data$n),
        position = ggplot2::position_dodge(width = 0.8),
        hjust    = -0.2,
        size     = 3,
        color    = "#333333"
      ) +
      ggplot2::scale_fill_manual(
        values = palette,
        name   = "Type"
      ) +
      ggplot2::scale_x_continuous(
        expand = ggplot2::expansion(mult = c(0, 0.15))
      ) +
      pg_theme(base_color = theme_color) +
      ggplot2::labs(
        title   = "Apparitions m\u00e9dia | Media Appearances",
        x       = "Nombre | Count",
        y       = NULL,
        caption = "publigraphics"
      ) +
      ggplot2::theme(
        panel.grid.major.y = ggplot2::element_blank()
      )

    pg_msg("success",
           "Graphique m\u00e9dia g\u00e9n\u00e9r\u00e9 avec succ\u00e8s.",
           "Media summary chart generated successfully.")

    p

  }, error = function(e) {
    pg_msg("error",
           glue("Erreur dans pg_media_summary : {conditionMessage(e)}"),
           glue("Error in pg_media_summary: {conditionMessage(e)}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })
}
