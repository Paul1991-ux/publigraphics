# ── viz_seminars.R ────────────────────────────────────────────────────────────
# Visualisation and narrative functions for seminars and conferences.
# Exported: pg_map_seminars, pg_network_seminars, pg_narrative_seminar.
# ──────────────────────────────────────────────────────────────────────────────

# ── Geocoding cache (module-level environment) ───────────────────────────────

.geocode_env <- new.env(parent = emptyenv())
.geocode_env$cache_path <- NULL

#' Retrieve or initialise the geocoding cache file path
#'
#' @return Character. Path to the temporary RDS cache file.
#' @noRd
pg_geocode_cache_path <- function() {
  if (is.null(.geocode_env$cache_path) ||
      !file.exists(.geocode_env$cache_path)) {
    .geocode_env$cache_path <- tempfile(
      pattern = "pg_geocode_", fileext = ".rds"
    )
  }
  .geocode_env$cache_path
}

#' Geocode locations with caching
#'
#' Geocodes a tibble of unique city+country pairs using
#' `tidygeocoder::geo(method = "osm")`. Results are cached in
#' a temporary RDS file to avoid repeated API calls within the
#' same session.
#'
#' @param locations_df A tibble with columns `city` and `country`.
#'
#' @return A tibble with columns `city`, `country`, `lat`, `long`.
#' @noRd
pg_geocode_cached <- function(locations_df) {

  cache_file <- pg_geocode_cache_path()

  # Load existing cache if available

  cached <- tryCatch({
    if (file.exists(cache_file)) {
      readRDS(cache_file)
    } else {
      tibble(city = character(0L), country = character(0L),
             lat = numeric(0L), long = numeric(0L))
    }
  }, error = function(e) {
    tibble(city = character(0L), country = character(0L),
           lat = numeric(0L), long = numeric(0L))
  })

  # Identify locations not yet cached
  locations_df <- locations_df |>
    distinct(.data$city, .data$country)

  already_cached <- locations_df |>
    dplyr::semi_join(cached, by = c("city", "country"))

  to_geocode <- locations_df |>
    dplyr::anti_join(cached, by = c("city", "country"))

  if (nrow(to_geocode) > 0L) {
    pg_msg("info",
           glue("{nrow(to_geocode)} lieu(x) \u00e0 g\u00e9ocoder via OpenStreetMap."),
           glue("{nrow(to_geocode)} location(s) to geocode via OpenStreetMap."))

    # Build a combined address string for geocoding
    new_geocoded <- tryCatch({
      to_geocode |>
        mutate(
          address = paste(
            tidyr::replace_na(.data$city, ""),
            tidyr::replace_na(.data$country, ""),
            sep = ", "
          )
        ) |>
        tidygeocoder::geocode(
          address = "address",
          method  = "osm",
          quiet   = TRUE
        ) |>
        select("city", "country", "lat", "long")
    }, error = function(e) {
      pg_msg("warn",
             glue("Erreur de g\u00e9ocodage : {conditionMessage(e)}"),
             glue("Geocoding error: {conditionMessage(e)}"))
      to_geocode |>
        mutate(lat = NA_real_, long = NA_real_)
    })

    # Update cache
    cached <- bind_rows(cached, new_geocoded)
    tryCatch(
      saveRDS(cached, cache_file),
      error = function(e) {
        pg_msg("warn",
               "Impossible de sauvegarder le cache de g\u00e9ocodage.",
               "Unable to save geocoding cache.")
      }
    )
  }

  # Return geocoded results for the requested locations
  locations_df |>
    left_join(cached, by = c("city", "country"))
}


# ── 1. Geographic Map of Seminars ────────────────────────────────────────────

#' Geographic Map of Seminar and Conference Interventions
#'
#' Creates an interactive Leaflet map and/or a static ggplot2 map showing
#' the geographic distribution of seminars and conferences. Each location
#' is represented by a proportional circle whose radius encodes the number
#' of interventions.
#'
#' @param data A data frame (typically from [pg_classify()]) containing at
#'   least `type_classified`, `title`, `city`, and `country` columns.
#' @param output_type Character. Type of output to generate: `"both"`
#'   (default), `"interactive"`, or `"static"`.
#' @param theme_color Character. Base hex colour for markers and points
#'   (default `"#1B4F72"`).
#'
#' @return A named list with two elements:
#'   \describe{
#'     \item{interactive}{A `leaflet` htmlwidget (or `NULL` if
#'       `output_type = "static"`).}
#'     \item{static}{A `ggplot` object (or `NULL` if
#'       `output_type = "interactive"`).}
#'   }
#'
#' @details
#' Locations are geocoded using [tidygeocoder::geo()] with the
#' OpenStreetMap (`"osm"`) method. Results are cached in a temporary file
#' for the duration of the R session to avoid repeated API calls.
#'
#' The **interactive** version uses [leaflet::leaflet()] with
#' `CartoDB.Positron` tiles and circle markers with HTML popups listing
#' intervention titles.
#'
#' The **static** version uses [rnaturalearth::ne_countries()] for the
#' basemap and [ggplot2::geom_point()] for proportional symbols, styled
#' with [pg_theme()].
#'
#' @examples
#' \dontrun{
#' bib   <- pg_read_bib("references.bib")
#' extra <- pg_read_extra("extra.csv")
#' data  <- pg_merge_inputs(bib, extra) |> pg_classify()
#' maps  <- pg_map_seminars(data)
#' maps$interactive         # open in viewer
#' print(maps$static)       # static PDF-ready
#' }
#'
#' @export
pg_map_seminars <- function(data,
                            output_type = "both",
                            theme_color = "#1B4F72") {

  set.seed(2024L)

  # ── Validate inputs ──────────────────────────────────────────────────────
  if (!is.data.frame(data)) {
    pg_msg("error",
           "L'argument 'data' doit \u00eatre un data.frame.",
           "Argument 'data' must be a data.frame.")
    stop("Invalid 'data' argument.", call. = FALSE)
  }

  output_type <- match.arg(output_type, c("both", "interactive", "static"))

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

  # ── Filter seminars and conferences ──────────────────────────────────────
  seminars <- data |>
    filter(.data$type_classified %in% c("seminar", "conference"))

  if (nrow(seminars) == 0L) {
    pg_msg("warn",
           "Aucun s\u00e9minaire ou conf\u00e9rence trouv\u00e9 dans les donn\u00e9es.",
           "No seminars or conferences found in the data.")
    return(list(interactive = NULL, static = NULL))
  }

  pg_msg("info",
         glue("{nrow(seminars)} s\u00e9minaires/conf\u00e9rences trouv\u00e9(e)s."),
         glue("{nrow(seminars)} seminars/conferences found."))

  # ── Extract and clean city + country ─────────────────────────────────────
  seminars <- seminars |>
    mutate(
      city_clean    = tidyr::replace_na(
        if ("city" %in% names(seminars)) .data$city else NA_character_,
        ""
      ),
      country_clean = tidyr::replace_na(
        if ("country" %in% names(seminars)) .data$country else NA_character_,
        ""
      )
    ) |>
    filter(
      nchar(str_trim(.data$city_clean)) > 0L |
        nchar(str_trim(.data$country_clean)) > 0L
    )

  if (nrow(seminars) == 0L) {
    pg_msg("warn",
           "Aucune localisation (ville/pays) disponible pour la carte.",
           "No location (city/country) available for the map.")
    return(list(interactive = NULL, static = NULL))
  }

  # ── Geocode locations ───────────────────────────────────────────────────
  locations <- seminars |>
    select(city = "city_clean", country = "country_clean") |>
    distinct()

  geocoded <- tryCatch(
    pg_geocode_cached(locations),
    error = function(e) {
      pg_msg("error",
             glue("Erreur lors du g\u00e9ocodage : {conditionMessage(e)}"),
             glue("Geocoding error: {conditionMessage(e)}"))
      locations |>
        mutate(lat = NA_real_, long = NA_real_)
    }
  )

  # Merge geocoded coordinates back
  seminars <- seminars |>
    left_join(
      geocoded,
      by = c("city_clean" = "city", "country_clean" = "country")
    ) |>
    filter(!is.na(.data$lat), !is.na(.data$long))

  if (nrow(seminars) == 0L) {
    pg_msg("warn",
           "Aucune coordonn\u00e9e valide apr\u00e8s g\u00e9ocodage.",
           "No valid coordinates after geocoding.")
    return(list(interactive = NULL, static = NULL))
  }

  pg_msg("info",
         glue("{nrow(seminars)} intervention(s) g\u00e9olocalis\u00e9e(s)."),
         glue("{nrow(seminars)} intervention(s) geolocated."))

  # ── Aggregate by coordinates ─────────────────────────────────────────────
  map_data <- seminars |>
    group_by(.data$lat, .data$long, .data$city_clean, .data$country_clean) |>
    summarise(
      n      = n(),
      titles = list(.data$title),
      .groups = "drop"
    )

  # ── INTERACTIVE version (leaflet) ─────────────────────────────────────────
  leaflet_obj <- NULL
  if (output_type %in% c("both", "interactive")) {
    leaflet_obj <- tryCatch({
      # Build HTML popups
      popups <- purrr::map_chr(seq_len(nrow(map_data)), function(i) {
        row     <- map_data[i, ]
        loc_lbl <- paste0(row$city_clean, ", ", row$country_clean)
        ttls    <- unlist(row$titles)
        ttls    <- purrr::map_chr(ttls, ~ pg_truncate(.x, n = 60L))
        titles_html <- paste0("<li>", htmltools::htmlEscape(ttls), "</li>",
                              collapse = "")
        paste0(
          '<div style="font-family:Lato,Helvetica,sans-serif;',
          'max-width:280px;">',
          '<strong style="color:', theme_color, ';font-size:13px;">',
          htmltools::htmlEscape(loc_lbl), '</strong>',
          '<br><span style="font-size:11px;color:#666;">',
          row$n, ' intervention(s)</span>',
          '<ul style="margin:4px 0;padding-left:16px;font-size:11px;">',
          titles_html,
          '</ul></div>'
        )
      })

      leaflet::leaflet(data = map_data) |>
        leaflet::addProviderTiles("CartoDB.Positron") |>
        leaflet::addCircleMarkers(
          lng         = ~long,
          lat         = ~lat,
          radius      = ~sqrt(n) * 5,
          color       = theme_color,
          fillColor   = theme_color,
          fillOpacity = 0.65,
          weight      = 1.5,
          popup       = popups
        )
    }, error = function(e) {
      pg_msg("warn",
             glue("Carte interactive non g\u00e9n\u00e9r\u00e9e : {conditionMessage(e)}"),
             glue("Interactive map not generated: {conditionMessage(e)}"))
      NULL
    })
  }

  # ── STATIC version (ggplot2 + sf) ────────────────────────────────────────
  ggplot_obj <- NULL
  if (output_type %in% c("both", "static")) {
    ggplot_obj <- tryCatch({
      # Load world basemap
      world <- rnaturalearth::ne_countries(
        scale       = "medium",
        returnclass = "sf"
      )

      ggplot2::ggplot() +
        ggplot2::geom_sf(
          data     = world,
          fill     = "#F5F5F5",
          color    = "white",
          linewidth = 0.2
        ) +
        ggplot2::geom_point(
          data = map_data,
          ggplot2::aes(
            x    = .data$long,
            y    = .data$lat,
            size = .data$n
          ),
          color = theme_color,
          alpha = 0.8
        ) +
        ggplot2::scale_size_continuous(
          range = c(3, 12),
          name  = "Interventions"
        ) +
        ggplot2::coord_sf(expand = FALSE) +
        pg_theme(base_color = theme_color) +
        ggplot2::labs(
          title   = "Carte des s\u00e9minaires et conf\u00e9rences | Seminar & Conference Map",
          caption = "publigraphics | OpenStreetMap geocoding"
        ) +
        ggplot2::theme(
          axis.text  = ggplot2::element_blank(),
          axis.title = ggplot2::element_blank(),
          axis.ticks = ggplot2::element_blank()
        )
    }, error = function(e) {
      pg_msg("warn",
             glue("Carte statique non g\u00e9n\u00e9r\u00e9e : {conditionMessage(e)}"),
             glue("Static map not generated: {conditionMessage(e)}"))
      NULL
    })
  }

  pg_msg("success",
         "Carte des s\u00e9minaires g\u00e9n\u00e9r\u00e9e avec succ\u00e8s.",
         "Seminar map generated successfully.")

  list(interactive = leaflet_obj, static = ggplot_obj)
}


# ── 2. Keyword Network for Seminars ────────────────────────────────────────

#' Keyword Network of Seminar Interventions
#'
#' Builds a bipartite keyword network centred on the researcher, with
#' peripheral nodes representing the top keywords extracted from seminar
#' titles and keyword fields. The central node represents the author and
#' theme nodes are sized by frequency.
#'
#' @param data A data frame (typically from [pg_classify()]) containing at
#'   least `type_classified`, `title`, and optionally `keywords` columns.
#' @param author_name Character. Name of the researcher displayed as
#'   the central node.
#' @param theme_color Character. Base hex colour for the central node and
#'   palette generation (default `"#1B4F72"`).
#'
#' @return A `ggplot` object (from [ggraph]).
#'
#' @details
#' Keywords are extracted from the `title` and `keywords` columns of
#' seminars and conferences. After tokenisation and stopword removal
#' (French + English), the top 20 most frequent keywords become
#' peripheral nodes in the network.
#'
#' The network is built with [tidygraph::tbl_graph()] and laid out
#' with the `"stress"` algorithm (seed 2024). Edges connect the central
#' author node to each keyword; node sizes reflect frequency.
#'
#' @examples
#' \dontrun{
#' bib   <- pg_read_bib("references.bib")
#' extra <- pg_read_extra("extra.csv")
#' data  <- pg_merge_inputs(bib, extra) |> pg_classify()
#' net   <- pg_network_seminars(data, author_name = "Paul Wambo")
#' print(net)
#' }
#'
#' @export
pg_network_seminars <- function(data,
                                author_name,
                                theme_color = "#1B4F72") {

  set.seed(2024L)

  # ── Validate inputs ──────────────────────────────────────────────────────
  if (!is.data.frame(data)) {
    pg_msg("error",
           "L'argument 'data' doit \u00eatre un data.frame.",
           "Argument 'data' must be a data.frame.")
    stop("Invalid 'data' argument.", call. = FALSE)
  }

  if (missing(author_name) || is.null(author_name) ||
      nchar(str_trim(author_name)) == 0L) {
    pg_msg("error",
           "Le nom de l'auteur (author_name) est requis.",
           "Author name (author_name) is required.")
    stop("Missing 'author_name' argument.", call. = FALSE)
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

  # ── Filter seminars and conferences ──────────────────────────────────────
  seminars <- data |>
    filter(.data$type_classified %in% c("seminar", "conference"))

  if (nrow(seminars) == 0L) {
    pg_msg("warn",
           "Aucun s\u00e9minaire ou conf\u00e9rence trouv\u00e9.",
           "No seminars or conferences found.")
    return(ggplot2::ggplot() + ggplot2::theme_void())
  }

  pg_msg("info",
         glue("{nrow(seminars)} s\u00e9minaires/conf\u00e9rences pour le r\u00e9seau."),
         glue("{nrow(seminars)} seminars/conferences for the network."))

  # ── Build corpus from titles + keywords ─────────────────────────────────
  corpus_df <- seminars |>
    mutate(
      doc_id = row_number(),
      text   = paste(
        tidyr::replace_na(.data$title, ""),
        tidyr::replace_na(
          if ("keywords" %in% names(seminars)) {
            purrr::map_chr(.data$keywords, function(kw) {
              if (is.null(kw) || all(is.na(kw))) return("")
              paste(kw, collapse = " ")
            })
          } else {
            ""
          },
          ""
        )
      )
    ) |>
    select("doc_id", "text")

  # ── Tokenise ────────────────────────────────────────────────────────────
  tokens <- tryCatch({
    corpus_df |>
      tidytext::unnest_tokens(output = "word", input = "text")
  }, error = function(e) {
    pg_msg("error",
           "Erreur lors de la tokenisation.",
           "Error during tokenisation.")
    return(NULL)
  })

  if (is.null(tokens) || nrow(tokens) == 0L) {
    pg_msg("warn",
           "Aucun token extrait.",
           "No tokens extracted.")
    return(ggplot2::ggplot() + ggplot2::theme_void())
  }

  # ── Remove stopwords (French + English) ────────────────────────────────
  stopwords_combined <- tryCatch({
    sw <- tibble(word = character(0L))
    sw_en <- tidytext::get_stopwords(language = "en")
    sw    <- bind_rows(sw, sw_en |> select("word"))
    sw_fr <- tidytext::get_stopwords(language = "fr", source = "snowball")
    sw    <- bind_rows(sw, sw_fr |> select("word"))
    sw |> distinct()
  }, error = function(e) {
    pg_msg("warn",
           "Impossible de charger les mots vides.",
           "Unable to load stopwords.")
    tibble(word = character(0L))
  })

  tokens_clean <- tokens |>
    filter(
      !(.data$word %in% stopwords_combined$word),
      !str_detect(.data$word, "^[0-9]+$"),
      nchar(.data$word) >= 3L
    )

  if (nrow(tokens_clean) == 0L) {
    pg_msg("warn",
           "Aucun mot restant apr\u00e8s filtrage.",
           "No words remaining after filtering.")
    return(ggplot2::ggplot() + ggplot2::theme_void())
  }

  # ── Top 20 keywords by frequency ────────────────────────────────────────
  top_keywords <- tokens_clean |>
    count(.data$word, name = "freq") |>
    arrange(dplyr::desc(.data$freq)) |>
    slice_head(n = 20L)

  if (nrow(top_keywords) == 0L) {
    pg_msg("warn",
           "Pas assez de mots-cl\u00e9s pour construire le r\u00e9seau.",
           "Not enough keywords to build the network.")
    return(ggplot2::ggplot() + ggplot2::theme_void())
  }

  pg_msg("info",
         glue("{nrow(top_keywords)} mots-cl\u00e9s retenus pour le r\u00e9seau."),
         glue("{nrow(top_keywords)} keywords retained for the network."))

  # ── Build bipartite graph ──────────────────────────────────────────────
  graph <- tryCatch({
    # Nodes: central author + keyword nodes
    nodes <- tibble(
      name = c(author_name, top_keywords$word),
      type = c("author", rep("keyword", nrow(top_keywords))),
      size = c(15, scales::rescale(top_keywords$freq, to = c(4, 12)))
    )

    # Edges: author -> each keyword
    edges <- tibble(
      from = rep(author_name, nrow(top_keywords)),
      to   = top_keywords$word,
      weight = top_keywords$freq
    )

    tidygraph::tbl_graph(
      nodes = nodes,
      edges = edges,
      directed = FALSE
    )
  }, error = function(e) {
    pg_msg("error",
           glue("Erreur lors de la construction du graphe : {conditionMessage(e)}"),
           glue("Error building graph: {conditionMessage(e)}"))
    return(NULL)
  })

  if (is.null(graph)) {
    return(ggplot2::ggplot() + ggplot2::theme_void())
  }

  # ── Generate palette ───────────────────────────────────────────────────
  # Lighter shade for keyword nodes
  keyword_color <- pg_palette(theme_color, n = 3L, type = "sequential")[2L]

  # ── Plot with ggraph ───────────────────────────────────────────────────
  p <- tryCatch({
    ggraph::ggraph(graph, layout = "stress") +
      ggraph::geom_edge_link(
        ggplot2::aes(width = .data$weight),
        alpha    = 0.3,
        color    = "#AAAAAA",
        show.legend = FALSE
      ) +
      ggraph::scale_edge_width_continuous(range = c(0.5, 2.5)) +
      ggraph::geom_node_point(
        ggplot2::aes(
          size  = .data$size,
          color = .data$type
        ),
        show.legend = FALSE
      ) +
      ggplot2::scale_color_manual(
        values = c("author" = theme_color, "keyword" = keyword_color)
      ) +
      ggplot2::scale_size_identity() +
      ggraph::geom_node_text(
        ggplot2::aes(label = .data$name),
        repel      = TRUE,
        size       = 3.2,
        color      = "#333333",
        max.overlaps = 20L
      ) +
      pg_theme(base_color = theme_color) +
      ggplot2::labs(
        title   = glue("R\u00e9seau th\u00e9matique des s\u00e9minaires | Seminar Keyword Network"),
        subtitle = author_name,
        caption  = "publigraphics | Layout: stress"
      ) +
      ggplot2::theme(
        axis.text   = ggplot2::element_blank(),
        axis.title  = ggplot2::element_blank(),
        axis.ticks  = ggplot2::element_blank(),
        panel.grid  = ggplot2::element_blank()
      )
  }, error = function(e) {
    pg_msg("error",
           glue("Erreur lors de la cr\u00e9ation du graphique r\u00e9seau : {conditionMessage(e)}"),
           glue("Error creating network plot: {conditionMessage(e)}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })

  pg_msg("success",
         "R\u00e9seau th\u00e9matique des s\u00e9minaires g\u00e9n\u00e9r\u00e9.",
         "Seminar keyword network generated.")

  p
}


# ── 3. AI Narrative Summary for One Seminar ──────────────────────────────────

#' AI Narrative Summary for One Seminar or Conference
#'
#' Calls the Anthropic Claude API to generate a structured narrative summary
#' for a single seminar or conference row. The response is a JSON object
#' with four keys: `question_centrale`, `audience_ciblee`,
#' `positionnement_debat`, `apport_original`.
#'
#' @param seminar_row A one-row data frame (or list) with at least a `title`
#'   field. The fields `keywords`, `journal_or_venue`, `city`, `country`,
#'   and `year` are used if available.
#' @param api_key Character. Anthropic API key.
#' @param lang Character. Language for the narrative: `"fr"` (default) or
#'   `"en"`.
#'
#' @return A one-row [tibble::tibble()] with columns `question_centrale`,
#'   `audience_ciblee`, `positionnement_debat`, and `apport_original`.
#'   On failure all values are `NA_character_` and a warning is emitted.
#'
#' @examples
#' \dontrun{
#' seminar <- data[data$type_classified == "seminar", ][1, ]
#' narr    <- pg_narrative_seminar(
#'   seminar,
#'   api_key = Sys.getenv("ANTHROPIC_API_KEY")
#' )
#' narr$question_centrale
#' }
#'
#' @export
pg_narrative_seminar <- function(seminar_row,
                                 api_key,
                                 lang = "fr") {

  # ── Empty fallback tibble ───────────────────────────────────────────────
  na_result <- tibble(
    question_centrale    = NA_character_,
    audience_ciblee      = NA_character_,
    positionnement_debat = NA_character_,
    apport_original      = NA_character_
  )

  # ── Validate inputs ────────────────────────────────────────────────────
  if (missing(api_key) || is.null(api_key) || nchar(api_key) == 0L) {
    pg_msg("error",
           "Cl\u00e9 API Anthropic manquante.",
           "Anthropic API key is missing.")
    return(na_result)
  }

  # ── Extract fields safely ──────────────────────────────────────────────
  safe_field <- function(row, field) {
    tryCatch({
      val <- row[[field]]
      if (is.null(val)) return(NA_character_)
      # Handle list-columns (e.g., keywords stored as list)
      if (is.list(val)) {
        val <- unlist(val)
        if (length(val) == 0L || all(is.na(val))) return(NA_character_)
        return(paste(val, collapse = ", "))
      }
      val <- as.character(val)
      if (is.na(val) || nchar(str_trim(val)) == 0L) NA_character_ else val
    }, error = function(e) NA_character_)
  }

  title_val <- safe_field(seminar_row, "title")
  keywords_val <- safe_field(seminar_row, "keywords")
  venue_val <- safe_field(seminar_row, "journal_or_venue")
  city_val <- safe_field(seminar_row, "city")
  country_val <- safe_field(seminar_row, "country")
  year_val <- safe_field(seminar_row, "year")

  if (is.na(title_val)) {
    pg_msg("warn",
           "Titre de s\u00e9minaire manquant, narration ignor\u00e9e.",
           "Seminar title missing, skipping narrative.")
    return(na_result)
  }

  # ── Build prompt ───────────────────────────────────────────────────────
  if (lang == "fr") {
    system_prompt <- paste0(
      "Tu es un assistant acad\u00e9mique expert en sciences sociales, ",
      "sp\u00e9cialis\u00e9 dans l\u2019analyse des interventions en s\u00e9minaires ",
      "et conf\u00e9rences. Pour l\u2019intervention suivante, g\u00e9n\u00e8re un ",
      "r\u00e9sum\u00e9 narratif structur\u00e9 sous forme de JSON avec exactement ",
      "4 cl\u00e9s : ",
      "\"question_centrale\" (la question ou th\u00e9matique centrale ",
      "de l\u2019intervention, 1-2 phrases), ",
      "\"audience_ciblee\" (le public vis\u00e9 et le contexte ",
      "de l\u2019\u00e9v\u00e9nement, 1-2 phrases), ",
      "\"positionnement_debat\" (comment cette intervention se ",
      "positionne dans le d\u00e9bat scientifique, 1-2 phrases), ",
      "\"apport_original\" (la contribution originale ou la valeur ",
      "ajout\u00e9e de cette intervention, 1-2 phrases). ",
      "R\u00e9ponds UNIQUEMENT avec le JSON valide, sans texte suppl\u00e9mentaire."
    )
  } else {
    system_prompt <- paste0(
      "You are an expert academic assistant in social sciences, ",
      "specialising in the analysis of seminar and conference ",
      "presentations. For the following intervention, generate a ",
      "structured narrative summary as JSON with exactly 4 keys: ",
      "\"question_centrale\" (the central question or theme of the ",
      "presentation, 1-2 sentences), ",
      "\"audience_ciblee\" (the target audience and event context, ",
      "1-2 sentences), ",
      "\"positionnement_debat\" (how this intervention is positioned ",
      "in the scientific debate, 1-2 sentences), ",
      "\"apport_original\" (the original contribution or added value ",
      "of this intervention, 1-2 sentences). ",
      "Reply ONLY with valid JSON, no additional text."
    )
  }

  # Compose context string with available metadata
  context_parts <- c(
    paste0("Titre : ", title_val)
  )
  if (!is.na(keywords_val)) {
    context_parts <- c(context_parts, paste0("Mots-cl\u00e9s : ", keywords_val))
  }
  if (!is.na(venue_val)) {
    context_parts <- c(context_parts, paste0("\u00c9v\u00e9nement : ", venue_val))
  }
  location_parts <- c()
  if (!is.na(city_val)) location_parts <- c(location_parts, city_val)
  if (!is.na(country_val)) location_parts <- c(location_parts, country_val)
  if (length(location_parts) > 0L) {
    context_parts <- c(context_parts,
                       paste0("Lieu : ", paste(location_parts, collapse = ", ")))
  }
  if (!is.na(year_val)) {
    context_parts <- c(context_parts, paste0("Ann\u00e9e : ", year_val))
  }

  user_content <- paste(context_parts, collapse = "\n")

  # ── Call Anthropic API ─────────────────────────────────────────────────
  result <- tryCatch({

    body_list <- list(
      model      = "claude-sonnet-4-20250514",
      max_tokens = 500L,
      system     = system_prompt,
      messages   = list(
        list(role = "user", content = user_content)
      )
    )

    resp <- httr2::request("https://api.anthropic.com/v1/messages") |>
      httr2::req_headers(
        `x-api-key`         = api_key,
        `anthropic-version`  = "2023-06-01",
        `content-type`       = "application/json"
      ) |>
      httr2::req_body_json(body_list) |>
      httr2::req_timeout(60) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()

    status <- httr2::resp_status(resp)
    if (status != 200L) {
      pg_msg("warn",
             glue("API Anthropic : statut HTTP {status}."),
             glue("Anthropic API: HTTP status {status}."))
      return(na_result)
    }

    resp_body <- httr2::resp_body_json(resp)

    # Extract text content from the response
    raw_text <- resp_body$content[[1L]]$text

    # Parse JSON from the response
    parsed <- jsonlite::fromJSON(raw_text, simplifyVector = TRUE)

    expected_keys <- c("question_centrale", "audience_ciblee",
                       "positionnement_debat", "apport_original")
    missing_keys  <- setdiff(expected_keys, names(parsed))
    if (length(missing_keys) > 0L) {
      pg_msg("warn",
             paste0("Cl\u00e9s JSON manquantes : ",
                    paste(missing_keys, collapse = ", ")),
             paste0("Missing JSON keys: ",
                    paste(missing_keys, collapse = ", ")))
    }

    tibble(
      question_centrale    = as.character(
        parsed$question_centrale    %||% NA_character_
      ),
      audience_ciblee      = as.character(
        parsed$audience_ciblee      %||% NA_character_
      ),
      positionnement_debat = as.character(
        parsed$positionnement_debat %||% NA_character_
      ),
      apport_original      = as.character(
        parsed$apport_original      %||% NA_character_
      )
    )

  }, error = function(e) {
    pg_msg("warn",
           glue("Erreur API narrative s\u00e9minaire : {conditionMessage(e)}"),
           glue("Seminar narrative API error: {conditionMessage(e)}"))
    na_result
  })

  pg_msg("success",
         glue("Narration g\u00e9n\u00e9r\u00e9e pour : {pg_truncate(title_val, 50L)}"),
         glue("Narrative generated for: {pg_truncate(title_val, 50L)}"))

  result
}
