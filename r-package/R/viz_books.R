# -- viz_books.R ---------------------------------------------------------------
# Visualisation functions for books and book chapters.
# Exported: pg_gallery_books, pg_network_coauthors, pg_wordcloud_books.
# ------------------------------------------------------------------------------


# -- 1. Book Cover Gallery -----------------------------------------------------

#' Gallery of Book Covers from Open Library
#'
#' Fetches book cover images from the Open Library Covers API using ISBNs found
#' in the data. When a cover cannot be retrieved (HTTP error or missing ISBN), a
#' placeholder is generated with [ggplot2]. The individual panels are assembled
#' into a grid via [patchwork::wrap_plots()].
#'
#' @param data A data frame (typically from [pg_read_bib()] followed by
#'   [pg_classify()]) containing at least `type_classified`, `title`, and
#'   `isbn` columns.
#' @param theme_color Character. Base hex colour for placeholder backgrounds
#'   and theme accents (default `"#1B4F72"`).
#'
#' @return A `patchwork` ggplot object assembling book cover panels.
#'   Returns an empty `ggplot() + theme_void()` when no books are found.
#'
#' @examples
#' \dontrun{
#' bib  <- pg_read_bib("references.bib") |> pg_classify()
#' gallery <- pg_gallery_books(bib)
#' print(gallery)
#' }
#'
#' @export
pg_gallery_books <- function(data, theme_color = "#1B4F72") {

  set.seed(2024L)

  # -- Validate inputs ---------------------------------------------------------
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

  # -- Filter books and book chapters ------------------------------------------
  books <- data |>
    filter(.data$type_classified %in% c("book", "book_chapter"))

  if (nrow(books) == 0L) {
    pg_msg("warn",
           "Aucun ouvrage ou chapitre trouv\u00e9 dans les donn\u00e9es.",
           "No books or book chapters found in the data.")
    return(ggplot2::ggplot() + ggplot2::theme_void())
  }

  pg_msg("info",
         glue("{nrow(books)} ouvrages/chapitres trouv\u00e9s pour la galerie."),
         glue("{nrow(books)} books/chapters found for the gallery."))

  # -- Ensure isbn column exists -----------------------------------------------
  if (!"isbn" %in% names(books)) {
    books$isbn <- NA_character_
  }

  # -- Helper: generate a placeholder cover ------------------------------------
  make_placeholder <- function(book_title, fill_color) {
    title_wrapped <- str_wrap(pg_truncate(book_title, n = 60L), width = 18)
    ggplot2::ggplot() +
      ggplot2::geom_rect(
        ggplot2::aes(xmin = 0, xmax = 1, ymin = 0, ymax = 1.4),
        fill = fill_color, colour = NA
      ) +
      ggplot2::geom_text(
        ggplot2::aes(x = 0.5, y = 0.7, label = title_wrapped),
        colour = "white", size = 3.2, fontface = "bold",
        lineheight = 1.1
      ) +
      ggplot2::coord_fixed(ratio = 1 / 1.4) +
      ggplot2::theme_void() +
      ggplot2::theme(plot.margin = ggplot2::margin(2, 2, 2, 2))
  }

  # -- Helper: try to fetch cover from Open Library ----------------------------
  fetch_cover <- function(isbn_val) {
    tryCatch({
      url <- glue("https://covers.openlibrary.org/b/isbn/{isbn_val}-M.jpg")
      resp <- httr2::request(url) |>
        httr2::req_timeout(10) |>
        httr2::req_error(is_error = function(resp) FALSE) |>
        httr2::req_perform()

      status <- httr2::resp_status(resp)
      if (status != 200L) return(NULL)

      # Check content length to detect 1x1 pixel placeholder (< 1 KB)
      body_raw <- httr2::resp_body_raw(resp)
      if (length(body_raw) < 1000L) return(NULL)

      # Write to temp file
      tmp_path <- file.path(tempdir(), paste0(isbn_val, ".jpg"))
      writeBin(body_raw, tmp_path)
      tmp_path
    }, error = function(e) {
      NULL
    })
  }

  # -- Helper: build a single panel from cover image or placeholder ------------
  build_panel <- function(cover_path, book_title) {
    title_label <- pg_truncate(book_title, n = 40L)

    if (!is.null(cover_path) && file.exists(cover_path)) {
      # Read JPEG and create raster panel
      img <- tryCatch({
        jpeg::readJPEG(cover_path)
      }, error = function(e) {
        NULL
      })

      if (!is.null(img)) {
        g <- ggplot2::ggplot() +
          ggplot2::annotation_raster(
            img, xmin = 0, xmax = 1, ymin = 0, ymax = 1.4
          ) +
          ggplot2::coord_fixed(ratio = 1 / 1.4) +
          ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
          ggplot2::scale_y_continuous(limits = c(0, 1.4), expand = c(0, 0)) +
          ggplot2::labs(subtitle = title_label) +
          ggplot2::theme_void() +
          ggplot2::theme(
            plot.subtitle = ggplot2::element_text(
              size = 7, hjust = 0.5, colour = "#333333",
              margin = ggplot2::margin(t = 4)
            ),
            plot.margin = ggplot2::margin(4, 4, 4, 4)
          )
        return(g)
      }
    }

    # Fallback: use placeholder
    make_placeholder(book_title, theme_color) +
      ggplot2::labs(subtitle = title_label) +
      ggplot2::theme(
        plot.subtitle = ggplot2::element_text(
          size = 7, hjust = 0.5, colour = "#333333",
          margin = ggplot2::margin(t = 4)
        )
      )
  }

  # -- Build all panels --------------------------------------------------------
  panels <- tryCatch({
    purrr::map(seq_len(nrow(books)), function(i) {
      isbn_val   <- as.character(books$isbn[i])
      title_val  <- as.character(books$title[i])

      cover_path <- NULL
      if (!is.na(isbn_val) && nchar(str_trim(isbn_val)) > 0L) {
        # Clean ISBN: remove hyphens and spaces
        isbn_clean <- str_replace_all(isbn_val, "[-\\s]", "")
        cover_path <- fetch_cover(isbn_clean)
      }

      build_panel(cover_path, title_val)
    })
  }, error = function(e) {
    pg_msg("error",
           glue("Erreur lors de la construction des panneaux : {conditionMessage(e)}"),
           glue("Error building panels: {conditionMessage(e)}"))
    list(ggplot2::ggplot() + ggplot2::theme_void())
  })

  # -- Assemble grid -----------------------------------------------------------
  n_books <- length(panels)
  n_cols  <- min(4L, n_books)

  gallery <- tryCatch({
    patchwork::wrap_plots(panels, ncol = n_cols) +
      patchwork::plot_annotation(
        title   = "Galerie des ouvrages | Book Gallery",
        caption = "publigraphics",
        theme   = pg_theme(base_color = theme_color)
      )
  }, error = function(e) {
    pg_msg("error",
           glue("Erreur lors de l'assemblage de la galerie : {conditionMessage(e)}"),
           glue("Error assembling gallery: {conditionMessage(e)}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })

  pg_msg("success",
         glue("Galerie g\u00e9n\u00e9r\u00e9e avec {n_books} ouvrage(s)."),
         glue("Gallery generated with {n_books} book(s)."))

  gallery
}


# -- 2. Co-authorship Network --------------------------------------------------

#' Co-authorship Network Graph
#'
#' Builds an interactive-style co-authorship network centred on a focal author.
#' Edges connect the focal author to each co-author; edge width encodes the
#' number of co-publications and edge colour encodes the production type.
#' Layout uses the Fruchterman--Reingold algorithm (seed 2024).
#'
#' @param data A data frame (typically from [pg_read_bib()] followed by
#'   [pg_classify()]) containing at least `type_classified`, `title`, and
#'   `authors` columns. The `authors` column should be a list-column of
#'   character vectors (one vector per row).
#' @param author_name Character. The full name of the focal author as it
#'   appears in the `authors` field (e.g., `"Dupont, Jean"`).
#' @param theme_color Character. Base hex colour for the theme
#'   (default `"#1B4F72"`).
#'
#' @return A `ggplot` object (from [ggraph]).
#'
#' @examples
#' \dontrun{
#' bib <- pg_read_bib("references.bib") |> pg_classify()
#' pg_network_coauthors(bib, author_name = "Dupont, Jean")
#' }
#'
#' @export
pg_network_coauthors <- function(data,
                                  author_name,
                                  theme_color = "#1B4F72") {

  set.seed(2024L)


  # -- Validate inputs ---------------------------------------------------------
  if (!is.data.frame(data)) {
    pg_msg("error",
           "L'argument 'data' doit \u00eatre un data.frame.",
           "Argument 'data' must be a data.frame.")
    stop("Invalid 'data' argument.", call. = FALSE)
  }

  if (missing(author_name) || is.null(author_name) ||
      nchar(str_trim(author_name)) == 0L) {
    pg_msg("error",
           "Le nom de l'auteur principal est requis.",
           "The main author name is required.")
    stop("Argument 'author_name' is required.", call. = FALSE)
  }

  required_cols <- c("type_classified", "title", "authors")
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

  # -- Extract edges from the authors list-column ------------------------------
  edges_df <- tryCatch({
    # Expand authors list-column into long format
    data |>
      mutate(.row_id = row_number()) |>
      select(".row_id", "authors", "type_classified", "title") |>
      mutate(
        authors_vec = purrr::map(.data$authors, function(a) {
          if (is.null(a) || all(is.na(a))) return(character(0L))
          a_clean <- str_trim(as.character(a))
          a_clean[nchar(a_clean) > 0L & !is.na(a_clean)]
        })
      ) |>
      filter(purrr::map_lgl(.data$authors_vec, ~ length(.x) >= 2L)) |>
      filter(purrr::map_lgl(
        .data$authors_vec,
        ~ any(str_to_lower(.x) == str_to_lower(author_name))
      )) |>
      mutate(
        coauthors = purrr::map(.data$authors_vec, function(a) {
          a[str_to_lower(a) != str_to_lower(author_name)]
        })
      ) |>
      tidyr::unnest(cols = "coauthors") |>
      select(
        coauthor        = "coauthors",
        type_classified = "type_classified"
      )
  }, error = function(e) {
    pg_msg("error",
           glue("Erreur lors de l'extraction des co-auteurs : {conditionMessage(e)}"),
           glue("Error extracting co-authors: {conditionMessage(e)}"))
    return(NULL)
  })

  if (is.null(edges_df) || nrow(edges_df) == 0L) {
    pg_msg("warn",
           glue("Aucun co-auteur trouv\u00e9 pour '{author_name}'."),
           glue("No co-authors found for '{author_name}'."))
    return(ggplot2::ggplot() + ggplot2::theme_void())
  }

  pg_msg("info",
         glue("{nrow(edges_df)} liens de co-autorat extraits."),
         glue("{nrow(edges_df)} co-authorship links extracted."))

  # -- Count co-publications per co-author (all types) -------------------------
  coauthor_counts <- edges_df |>
    count(.data$coauthor, name = "n_collab") |>
    arrange(dplyr::desc(.data$n_collab))

  # Filter: keep co-authors with >= 2 co-publications, or top 20
  if (sum(coauthor_counts$n_collab >= 2L) >= 3L) {
    coauthor_keep <- coauthor_counts |>
      filter(.data$n_collab >= 2L) |>
      pull("coauthor")
  } else {
    coauthor_keep <- coauthor_counts |>
      slice_head(n = 20L) |>
      pull("coauthor")
  }

  edges_filtered <- edges_df |>
    filter(.data$coauthor %in% coauthor_keep)

  # -- Aggregate edges: one row per (co-author, type) with count ---------------
  edge_summary <- edges_filtered |>
    count(.data$coauthor, .data$type_classified, name = "n") |>
    mutate(
      from = author_name,
      to   = .data$coauthor
    )

  # -- Build tidygraph ---------------------------------------------------------
  nodes_df <- tibble(
    name = c(author_name, unique(edge_summary$to))
  ) |>
    distinct() |>
    left_join(
      coauthor_counts |> rename(name = "coauthor"),
      by = "name"
    ) |>
    mutate(
      n_collab = tidyr::replace_na(.data$n_collab, 0L),
      is_focal = (.data$name == author_name)
    )

  graph <- tryCatch({
    tidygraph::tbl_graph(
      nodes = nodes_df,
      edges = edge_summary |> select("from", "to", "n", "type_classified"),
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

  # -- Colour palette per production type --------------------------------------
  type_levels <- unique(edge_summary$type_classified)
  n_types     <- max(length(type_levels), 1L)
  type_palette <- pg_palette(theme_color, n = n_types, type = "qualitative")
  names(type_palette) <- type_levels

  # -- Build ggraph plot -------------------------------------------------------
  p <- tryCatch({
    ggraph::ggraph(graph, layout = "fr") +
      ggraph::geom_edge_link(
        ggplot2::aes(
          width = .data$n,
          colour = .data$type_classified
        ),
        alpha = 0.6,
        show.legend = TRUE
      ) +
      ggraph::geom_node_point(
        ggplot2::aes(
          size = ifelse(.data$is_focal, 12, .data$n_collab + 2)
        ),
        colour = theme_color,
        alpha  = 0.85
      ) +
      ggraph::geom_node_text(
        ggplot2::aes(label = .data$name),
        repel      = TRUE,
        size       = 2.8,
        colour     = "#333333",
        max.overlaps = 20L
      ) +
      ggraph::scale_edge_width(
        range = c(0.4, 3),
        name  = "Co-publications"
      ) +
      ggraph::scale_edge_colour_manual(
        values = type_palette,
        name   = "Type"
      ) +
      ggplot2::scale_size_identity() +
      pg_theme(base_color = theme_color) +
      ggplot2::labs(
        title   = glue("R\u00e9seau de co-autorat | Co-authorship Network"),
        subtitle = glue("Auteur principal | Focal author: {author_name}"),
        caption = "publigraphics | Fruchterman-Reingold layout"
      ) +
      ggplot2::theme(
        axis.text    = ggplot2::element_blank(),
        axis.title   = ggplot2::element_blank(),
        panel.grid   = ggplot2::element_blank()
      )
  }, error = function(e) {
    pg_msg("error",
           glue("Erreur lors de la cr\u00e9ation du graphique r\u00e9seau : {conditionMessage(e)}"),
           glue("Error creating network plot: {conditionMessage(e)}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })

  pg_msg("success",
         glue("R\u00e9seau de co-autorat g\u00e9n\u00e9r\u00e9 ({length(coauthor_keep)} co-auteurs)."),
         glue("Co-authorship network generated ({length(coauthor_keep)} co-authors)."))

  p
}


# -- 3. Word Cloud for Books --------------------------------------------------

#' TF-IDF Weighted Word Cloud for Books and Book Chapters
#'
#' Builds a word cloud from the titles and subtitles of books and book chapters.
#' Words are sized by mean TF-IDF weight. Unlike [pg_wordcloud_articles()],
#' no LDA topic modelling is performed because the document count is typically
#' too small; instead, words are coloured by a sequential palette derived from
#' `theme_color`.
#'
#' @param data A data frame (typically from [pg_read_bib()] followed by
#'   [pg_classify()]) containing at least `type_classified` and `title`
#'   columns. Optionally includes a `subtitle` column.
#' @param theme_color Character. Base hex colour for the palette
#'   (default `"#1B4F72"`).
#' @param lang Character. Stopword languages to remove. One of `"both"`
#'   (French + English, default), `"fr"`, or `"en"`.
#' @param max_words Integer. Maximum number of words in the cloud
#'   (default `60L`).
#'
#' @return A named list with two elements:
#'   \describe{
#'     \item{widget}{An interactive `htmlwidget` from [wordcloud2::wordcloud2()].}
#'     \item{plot}{A static `ggplot` object from [ggwordcloud::geom_text_wordcloud()].}
#'   }
#'
#' @examples
#' \dontrun{
#' bib <- pg_read_bib("references.bib") |> pg_classify()
#' wc  <- pg_wordcloud_books(bib)
#' wc$widget          # interactive
#' print(wc$plot)     # static PDF-ready
#' }
#'
#' @export
pg_wordcloud_books <- function(data,
                                theme_color = "#1B4F72",
                                lang        = "both",
                                max_words   = 60L) {

  set.seed(2024L)

  # -- Validate inputs ---------------------------------------------------------
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

  # -- Filter books and book chapters ------------------------------------------
  books <- data |>
    filter(.data$type_classified %in% c("book", "book_chapter"))

  if (nrow(books) == 0L) {
    pg_msg("warn",
           "Aucun ouvrage trouv\u00e9 dans les donn\u00e9es.",
           "No books found in the data.")
    return(list(widget = NULL, plot = NULL))
  }

  pg_msg("info",
         glue("{nrow(books)} ouvrages/chapitres trouv\u00e9s pour le nuage de mots."),
         glue("{nrow(books)} books/chapters found for word cloud."))

  # -- Build corpus from titles (+ subtitle if present) ------------------------
  corpus_df <- books |>
    mutate(
      doc_id = row_number(),
      text   = paste(
        tidyr::replace_na(.data$title, ""),
        tidyr::replace_na(
          if ("subtitle" %in% names(books)) .data$subtitle else "",
          ""
        )
      )
    ) |>
    select("doc_id", "text")

  # -- Tokenise ----------------------------------------------------------------
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
    return(list(widget = NULL, plot = NULL))
  }

  # -- Remove stopwords --------------------------------------------------------
  stopwords_combined <- tryCatch({
    sw <- tibble(word = character(0L))
    if (lang %in% c("both", "en")) {
      sw_en <- tidytext::get_stopwords(language = "en")
      sw    <- bind_rows(sw, sw_en |> select("word"))
    }
    if (lang %in% c("both", "fr")) {
      sw_fr <- tidytext::get_stopwords(language = "fr", source = "snowball")
      sw    <- bind_rows(sw, sw_fr |> select("word"))
    }
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
    return(list(widget = NULL, plot = NULL))
  }

  # -- TF-IDF (simplified, no LDA) --------------------------------------------
  word_counts <- tokens_clean |>
    count(.data$doc_id, .data$word, name = "n")

  tfidf <- tryCatch({
    word_counts |>
      tidytext::bind_tf_idf(term = "word", document = "doc_id", n = "n")
  }, error = function(e) {
    pg_msg("error",
           "Erreur lors du calcul TF-IDF.",
           "Error computing TF-IDF.")
    return(NULL)
  })

  if (is.null(tfidf)) return(list(widget = NULL, plot = NULL))

  # Aggregate: mean TF-IDF per word across corpus
  word_scores <- tfidf |>
    group_by(.data$word) |>
    summarise(
      mean_tfidf = mean(.data$tf_idf, na.rm = TRUE),
      total_n    = sum(.data$n, na.rm = TRUE),
      .groups    = "drop"
    ) |>
    arrange(dplyr::desc(.data$mean_tfidf)) |>
    slice_head(n = max_words)

  if (nrow(word_scores) == 0L) {
    pg_msg("warn",
           "Aucun mot retenu apr\u00e8s le calcul TF-IDF.",
           "No words retained after TF-IDF computation.")
    return(list(widget = NULL, plot = NULL))
  }

  # -- Sequential palette (no LDA topics) --------------------------------------
  n_colors <- nrow(word_scores)
  palette  <- pg_palette(theme_color, n = max(n_colors, 2L),
                         type = "sequential")

  # Assign colours based on TF-IDF rank (higher TF-IDF = darker)
  word_scores <- word_scores |>
    mutate(
      rank  = row_number(),
      color = palette[ceiling(.data$rank / max(.data$rank, 1L) *
                                length(palette))]
    )

  # -- Interactive widget (wordcloud2) -----------------------------------------
  widget <- tryCatch({
    wc_df <- word_scores |>
      select(word = "word", freq = "mean_tfidf") |>
      mutate(freq = round(.data$freq * 1e4))

    wordcloud2::wordcloud2(
      data       = as.data.frame(wc_df),
      color      = word_scores$color,
      size       = 0.8,
      fontFamily = "sans",
      shape      = "circle",
      minSize    = 5
    )
  }, error = function(e) {
    pg_msg("warn",
           "Widget interactif non g\u00e9n\u00e9r\u00e9.",
           "Interactive widget not generated.")
    NULL
  })

  # -- Static plot (ggwordcloud) -----------------------------------------------
  static_plot <- tryCatch({
    ggplot2::ggplot(
      word_scores,
      ggplot2::aes(
        label  = .data$word,
        size   = .data$mean_tfidf,
        colour = .data$mean_tfidf
      )
    ) +
      ggwordcloud::geom_text_wordcloud(
        area_corr  = TRUE,
        seed       = 2024L,
        rm_outside = TRUE,
        shape      = "circle"
      ) +
      ggplot2::scale_size_area(max_size = 20) +
      ggplot2::scale_colour_gradientn(
        colours = palette,
        name    = "TF-IDF"
      ) +
      pg_theme(base_color = theme_color) +
      ggplot2::labs(
        title   = "Nuage de mots (ouvrages) | Word Cloud (Books)",
        caption = "TF-IDF | publigraphics"
      ) +
      ggplot2::theme(
        legend.position = "bottom",
        axis.text       = ggplot2::element_blank(),
        axis.title      = ggplot2::element_blank(),
        panel.grid      = ggplot2::element_blank()
      )
  }, error = function(e) {
    pg_msg("warn",
           "Graphique statique non g\u00e9n\u00e9r\u00e9.",
           "Static plot not generated.")
    NULL
  })

  pg_msg("success",
         "Nuage de mots (ouvrages) g\u00e9n\u00e9r\u00e9 avec succ\u00e8s.",
         "Book word cloud generated successfully.")

  list(widget = widget, plot = static_plot)
}
