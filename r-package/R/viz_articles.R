# ── viz_articles.R ─────────────────────────────────────────────────────────────
# Visualisation and narrative functions for scientific articles.
# Exported: pg_wordcloud_articles, pg_timeline_articles,
#           pg_narrative_article, pg_card_article.
# ──────────────────────────────────────────────────────────────────────────────

# ── 1. Word Cloud (TF-IDF + LDA) ─────────────────────────────────────────────

#' TF-IDF Weighted Word Cloud Coloured by LDA Topic
#'
#' Builds a word cloud from article titles, abstracts, and keywords. Words are
#' sized by mean TF-IDF weight across the corpus and coloured by their dominant
#' LDA topic.
#'
#' @param data A data frame (typically from `pg_read_bib()`) containing at least
#'   `type_classified`, `title`, `abstract`, and `keywords` columns.
#' @param n_topics Integer. Number of LDA topics (default `4L`).
#' @param lang Character. Stopword languages to remove. One of `"both"`
#'   (French + English, default), `"fr"`, or `"en"`.
#' @param theme_color Character. Base hex colour for the palette
#'   (default `"#1B4F72"`).
#' @param max_words Integer. Maximum number of words in the cloud
#'   (default `80L`).
#'
#' @return A named list with two elements:
#'   \describe{
#'     \item{widget}{An interactive `htmlwidget` from [wordcloud2::wordcloud2()].}
#'     \item{plot}{A static `ggplot` object from [ggwordcloud::geom_text_wordcloud()].}
#'   }
#'
#' @examples
#' \dontrun{
#' bib <- pg_read_bib("references.bib")
#' wc  <- pg_wordcloud_articles(bib, n_topics = 3L)
#' wc$widget          # interactive
#' print(wc$plot)     # static PDF-ready
#' }
#'
#' @export
pg_wordcloud_articles <- function(data,
                                  n_topics    = 4L,
                                  lang        = "both",
                                  theme_color = "#1B4F72",
                                  max_words   = 80L) {

  set.seed(2024L)


  # ── Validate inputs ──────────────────────────────────────────────────────────
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

  # ── Filter articles ──────────────────────────────────────────────────────────
  articles <- data |>
    filter(str_detect(str_to_lower(.data$type_classified), "article"))

  if (nrow(articles) == 0L) {
    pg_msg("warn",
           "Aucun article trouv\u00e9 dans les donn\u00e9es.",
           "No articles found in the data.")
    return(list(widget = NULL, plot = NULL))
  }

  pg_msg("info",
         glue("{nrow(articles)} articles trouv\u00e9s pour le nuage de mots."),
         glue("{nrow(articles)} articles found for word cloud."))

  # ── Build corpus ─────────────────────────────────────────────────────────────
  corpus_df <- articles |>
    mutate(
      doc_id = row_number(),
      text   = paste(
        tidyr::replace_na(.data$title, ""),
        tidyr::replace_na(
          if ("abstract" %in% names(articles)) .data$abstract else "",
          ""
        ),
        tidyr::replace_na(
          if ("keywords" %in% names(articles)) .data$keywords else "",
          ""
        )
      )
    ) |>
    select("doc_id", "text")

  # ── Tokenise ─────────────────────────────────────────────────────────────────
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

  # ── Remove stopwords ────────────────────────────────────────────────────────
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

  # ── TF-IDF ──────────────────────────────────────────────────────────────────
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

  # ── LDA topic modelling ────────────────────────────────────────────────────
  dtm <- tryCatch({
    word_counts |>
      filter(.data$word %in% word_scores$word) |>
      tidytext::cast_dtm(document = "doc_id", term = "word", value = "n")
  }, error = function(e) {
    pg_msg("warn",
           "Erreur lors de la cr\u00e9ation de la DTM.",
           "Error creating DTM.")
    return(NULL)
  })

  topic_assignments <- tryCatch({
    if (is.null(dtm) || nrow(dtm) < 2L) {
      pg_msg("warn",
             "Pas assez de documents pour LDA, topic unique attribu\u00e9.",
             "Not enough documents for LDA, assigning single topic.")
      word_scores |>
        mutate(topic = 1L) |>
        select("word", "topic")
    } else {
      k_use <- min(n_topics, nrow(dtm))
      lda_model <- topicmodels::LDA(
        dtm, k = k_use,
        control = list(seed = 2024L)
      )
      # Beta matrix: per-topic per-word probability
      beta_df <- tidytext::tidy(lda_model, matrix = "beta")
      # Assign each word to its dominant topic
      beta_df |>
        group_by(.data$term) |>
        slice_head(n = 1L, order_by = dplyr::desc(.data$beta)) |>
        ungroup() |>
        select(word = "term", topic = "topic") |>
        mutate(topic = as.integer(.data$topic))
    }
  }, error = function(e) {
    pg_msg("warn",
           glue("LDA \u00e9chou\u00e9 : {conditionMessage(e)}"),
           glue("LDA failed: {conditionMessage(e)}"))
    word_scores |>
      mutate(topic = 1L) |>
      select("word", "topic")
  })

  # ── Merge scores + topics ──────────────────────────────────────────────────
  cloud_data <- word_scores |>
    left_join(topic_assignments, by = "word") |>
    mutate(topic = tidyr::replace_na(.data$topic, 1L))

  # ── Palette ─────────────────────────────────────────────────────────────────
  n_pal   <- max(length(unique(cloud_data$topic)), 1L)
  palette <- pg_palette(theme_color, n = n_pal, type = "qualitative")

  cloud_data <- cloud_data |>
    mutate(color = palette[.data$topic])

  # ── Interactive widget (wordcloud2) ─────────────────────────────────────────
  widget <- tryCatch({
    wc_df <- cloud_data |>
      select(word = "word", freq = "mean_tfidf") |>
      mutate(freq = round(.data$freq * 1e4))
    wordcloud2::wordcloud2(
      data       = as.data.frame(wc_df),
      color      = cloud_data$color,
      size       = 0.6,
      fontFamily = "Lato",
      shape      = "circle"
    )
  }, error = function(e) {
    pg_msg("warn",
           "Widget interactif non g\u00e9n\u00e9r\u00e9.",
           "Interactive widget not generated.")
    NULL
  })

  # ── Static plot (ggwordcloud) ───────────────────────────────────────────────
  static_plot <- tryCatch({
    ggplot2::ggplot(
      cloud_data,
      ggplot2::aes(
        label = .data$word,
        size  = .data$mean_tfidf,
        color = factor(.data$topic)
      )
    ) +
      ggwordcloud::geom_text_wordcloud(
        area_corr     = TRUE,
        seed          = 2024L,
        rm_outside    = TRUE,
        shape         = "circle"
      ) +
      ggplot2::scale_size_area(max_size = 18) +
      ggplot2::scale_color_manual(
        values = palette,
        name   = "Topic"
      ) +
      pg_theme() +
      ggplot2::labs(
        title   = "Nuage de mots | Word Cloud",
        caption = "TF-IDF + LDA | publigraphics"
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
         "Nuage de mots g\u00e9n\u00e9r\u00e9 avec succ\u00e8s.",
         "Word cloud generated successfully.")

  list(widget = widget, plot = static_plot)
}


# ── 2. Timeline of Articles ──────────────────────────────────────────────────

#' Chronological Timeline of Articles
#'
#' Plots a timeline of published articles along a horizontal time axis. Points
#' are coloured by a user-chosen variable (default: journal) and labelled with
#' truncated titles.
#'
#' @param data A data frame containing at least `type_classified`, `year`,
#'   `title`, and the column specified in `color_by`.
#' @param color_by Character. Column name used for point colour
#'   (default `"journal"`).
#' @param theme_color Character. Base hex colour for the theme
#'   (default `"#1B4F72"`).
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \dontrun{
#' bib <- pg_read_bib("references.bib")
#' pg_timeline_articles(bib, color_by = "journal")
#' }
#'
#' @export
pg_timeline_articles <- function(data,
                                 color_by    = "journal",
                                 theme_color = "#1B4F72") {

  set.seed(2024L)

  # ── Validate inputs ──────────────────────────────────────────────────────────
  if (!is.data.frame(data)) {
    pg_msg("error",
           "L'argument 'data' doit \u00eatre un data.frame.",
           "Argument 'data' must be a data.frame.")
    stop("Invalid 'data' argument.", call. = FALSE)
  }

  required_cols <- c("type_classified", "year", "title")
  missing_cols  <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0L) {
    pg_msg("error",
           paste0("Colonnes manquantes : ", paste(missing_cols, collapse = ", ")),
           paste0("Missing columns: ", paste(missing_cols, collapse = ", ")))
    stop("Missing required columns.", call. = FALSE)
  }

  if (!color_by %in% names(data)) {
    pg_msg("warn",
           glue("Colonne '{color_by}' introuvable, utilisation de 'year'."),
           glue("Column '{color_by}' not found, falling back to 'year'."))
    color_by <- "year"
  }

  if (!pg_hex_valid(theme_color)) {
    pg_msg("warn",
           "Couleur invalide, utilisation de #1B4F72.",
           "Invalid colour, falling back to #1B4F72.")
    theme_color <- "#1B4F72"
  }

  # ── Filter articles ──────────────────────────────────────────────────────────
  articles <- data |>
    filter(str_detect(str_to_lower(.data$type_classified), "article")) |>
    filter(!is.na(.data$year))

  if (nrow(articles) == 0L) {
    pg_msg("warn",
           "Aucun article avec ann\u00e9e valide trouv\u00e9.",
           "No articles with valid year found.")
    return(ggplot2::ggplot() + ggplot2::theme_void())
  }

  pg_msg("info",
         glue("{nrow(articles)} articles pour la frise chronologique."),
         glue("{nrow(articles)} articles for the timeline."))

  # ── Prepare data ─────────────────────────────────────────────────────────────
  timeline_df <- articles |>
    mutate(
      year_num    = as.numeric(.data$year),
      title_short = pg_truncate(.data$title, n = 45L)
    ) |>
    arrange(.data$year_num) |>
    group_by(.data$year_num) |>
    mutate(rank_in_year = row_number()) |>
    ungroup() |>
    mutate(
      y_jitter = .data$rank_in_year * 0.5,
      color_var = as.character(.data[[color_by]])
    )

  # ── Determine palette ───────────────────────────────────────────────────────
  n_groups <- length(unique(timeline_df$color_var))

  # ── Build plot ──────────────────────────────────────────────────────────────
  p <- tryCatch({
    ggplot2::ggplot(
      timeline_df,
      ggplot2::aes(
        x     = .data$year_num,
        y     = .data$y_jitter,
        color = .data$color_var,
        label = .data$title_short
      )
    ) +
      ggplot2::geom_hline(
        yintercept = 0, linewidth = 0.4, colour = "#CCCCCC"
      ) +
      ggplot2::geom_point(size = 3, alpha = 0.85) +
      ggplot2::geom_text(
        size   = 2.8,
        hjust  = 0,
        nudge_x = 0.15,
        nudge_y = 0.1,
        check_overlap = TRUE,
        show.legend   = FALSE
      ) +
      {
        if (n_groups <= 12L) {
          ggplot2::scale_color_manual(
            values = pg_palette(theme_color, n = max(n_groups, 1L),
                                type = "qualitative"),
            name   = str_to_lower(color_by)
          )
        } else {
          ggplot2::scale_color_viridis_d(
            name   = str_to_lower(color_by),
            option = "D"
          )
        }
      } +
      ggplot2::scale_x_continuous(
        breaks = scales::breaks_pretty(n = 8)
      ) +
      pg_theme(base_color = theme_color) +
      ggplot2::labs(
        title    = "Frise chronologique des articles | Article Timeline",
        x        = "Ann\u00e9e | Year",
        y        = NULL,
        caption  = "publigraphics"
      ) +
      ggplot2::theme(
        axis.text.y  = ggplot2::element_blank(),
        axis.ticks.y = ggplot2::element_blank(),
        panel.grid.major.y = ggplot2::element_blank()
      )
  }, error = function(e) {
    pg_msg("error",
           glue("Erreur lors de la cr\u00e9ation du graphique : {conditionMessage(e)}"),
           glue("Error creating plot: {conditionMessage(e)}"))
    ggplot2::ggplot() + ggplot2::theme_void()
  })

  pg_msg("success",
         "Frise chronologique g\u00e9n\u00e9r\u00e9e.",
         "Timeline generated.")

  p
}


# ── 3. AI Narrative Summary ──────────────────────────────────────────────────

#' AI Narrative Summary for One Article
#'
#' Calls the Anthropic Claude API to generate a structured narrative summary for
#' a single article row. The response is a JSON object with four keys:
#' `problematique`, `pertinence`, `resultat`, `question_ouverte`.
#'
#' @param article_row A one-row data frame (or list) with at least `title`,
#'   `abstract`, and `keywords` fields.
#' @param api_key Character. Anthropic API key.
#' @param lang Character. Language for the narrative: `"fr"` (default) or
#'   `"en"`.
#'
#' @return A one-row [tibble::tibble()] with columns `problematique`,
#'   `pertinence`, `resultat`, and `question_ouverte`. On failure all values
#'   are `NA_character_` and a warning is emitted.
#'
#' @examples
#' \dontrun{
#' article <- bib[1, ]
#' narr    <- pg_narrative_article(article, api_key = Sys.getenv("ANTHROPIC_API_KEY"))
#' narr$problematique
#' }
#'
#' @export
pg_narrative_article <- function(article_row,
                                 api_key,
                                 lang = "fr") {

  # ── Empty fallback tibble ───────────────────────────────────────────────────
  na_result <- tibble(
    problematique  = NA_character_,
    pertinence     = NA_character_,
    resultat       = NA_character_,
    question_ouverte = NA_character_
  )

  # ── Validate inputs ────────────────────────────────────────────────────────
  if (missing(api_key) || is.null(api_key) || nchar(api_key) == 0L) {
    pg_msg("error",
           "Cl\u00e9 API Anthropic manquante.",
           "Anthropic API key is missing.")
    return(na_result)
  }

  title_val    <- as.character(
    if ("title" %in% names(article_row)) article_row$title else NA_character_
  )
  abstract_val <- as.character(
    if ("abstract" %in% names(article_row)) article_row$abstract else ""
  )
  keywords_val <- as.character(
    if ("keywords" %in% names(article_row)) article_row$keywords else ""
  )

  if (is.na(title_val) || nchar(str_trim(title_val)) == 0L) {
    pg_msg("warn",
           "Titre d'article manquant, narration ignor\u00e9e.",
           "Article title missing, skipping narrative.")
    return(na_result)
  }

  # ── Build prompt ────────────────────────────────────────────────────────────
  if (lang == "fr") {
    system_prompt <- paste0(
      "Tu es un assistant acad\u00e9mique expert en sciences sociales. ",
      "Pour l\u2019article suivant, g\u00e9n\u00e8re un r\u00e9sum\u00e9 narratif structur\u00e9 ",
      "sous forme de JSON avec exactement 4 cl\u00e9s : ",
      "\"problematique\" (la question de recherche, 1-2 phrases), ",
      "\"pertinence\" (l\u2019importance et le contexte, 1-2 phrases), ",
      "\"resultat\" (les principaux r\u00e9sultats, 1-2 phrases), ",
      "\"question_ouverte\" (une question ouverte pour prolonger la r\u00e9flexion, 1 phrase). ",
      "R\u00e9ponds UNIQUEMENT avec le JSON valide, sans texte suppl\u00e9mentaire."
    )
  } else {
    system_prompt <- paste0(
      "You are an expert academic assistant in social sciences. ",
      "For the following article, generate a structured narrative summary ",
      "as JSON with exactly 4 keys: ",
      "\"problematique\" (the research question, 1-2 sentences), ",
      "\"pertinence\" (the importance and context, 1-2 sentences), ",
      "\"resultat\" (the main findings, 1-2 sentences), ",
      "\"question_ouverte\" (an open question to extend the reflection, 1 sentence). ",
      "Reply ONLY with valid JSON, no additional text."
    )
  }

  user_content <- glue_safe(
    "Titre : {title_val}\n",
    "R\u00e9sum\u00e9 : {abstract_val}\n",
    "Mots-cl\u00e9s : {keywords_val}"
  )

  # ── Call Anthropic API ─────────────────────────────────────────────────────
  result <- tryCatch({

    body_list <- list(
      model      = "claude-sonnet-4-20250514",
      max_tokens = 400L,
      system     = system_prompt,
      messages   = list(
        list(role = "user", content = as.character(user_content))
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

    expected_keys <- c("problematique", "pertinence", "resultat",
                       "question_ouverte")
    missing_keys  <- setdiff(expected_keys, names(parsed))
    if (length(missing_keys) > 0L) {
      pg_msg("warn",
             paste0("Cl\u00e9s JSON manquantes : ",
                    paste(missing_keys, collapse = ", ")),
             paste0("Missing JSON keys: ",
                    paste(missing_keys, collapse = ", ")))
    }

    tibble(
      problematique    = as.character(parsed$problematique    %||% NA_character_),
      pertinence       = as.character(parsed$pertinence       %||% NA_character_),
      resultat         = as.character(parsed$resultat         %||% NA_character_),
      question_ouverte = as.character(parsed$question_ouverte %||% NA_character_)
    )

  }, error = function(e) {
    pg_msg("warn",
           glue("Erreur API narrative : {conditionMessage(e)}"),
           glue("Narrative API error: {conditionMessage(e)}"))
    na_result
  })

  pg_msg("success",
         glue("Narration g\u00e9n\u00e9r\u00e9e pour : {pg_truncate(title_val, 50L)}"),
         glue("Narrative generated for: {pg_truncate(title_val, 50L)}"))

  result
}


# ── 4. HTML Card for One Article ─────────────────────────────────────────────

#' HTML Card for One Article with Narrative Summary
#'
#' Generates an HTML card for a single article that includes bibliographic
#' metadata (title, authors, journal, DOI) and the four narrative sections
#' produced by [pg_narrative_article()].
#'
#' @param article_row A one-row data frame with article metadata. Expected
#'   fields: `title`, `author`, `journal`, `year`, `doi`.
#' @param narrative A one-row [tibble::tibble()] as returned by
#'   [pg_narrative_article()], with columns `problematique`, `pertinence`,
#'   `resultat`, `question_ouverte`.
#' @param theme_color Character. Hex colour for the left border and header
#'   badge (default `"#1B4F72"`).
#' @param lang Character. Display language: `"fr"` (default) or `"en"`.
#'
#' @return A `character(1)` HTML string suitable for inclusion in R Markdown /
#'   Quarto documents via [htmltools::HTML()].
#'
#' @examples
#' \dontrun{
#' article   <- bib[1, ]
#' narrative <- pg_narrative_article(article, api_key = Sys.getenv("ANTHROPIC_API_KEY"))
#' html_card <- pg_card_article(article, narrative)
#' htmltools::browsable(htmltools::HTML(html_card))
#' }
#'
#' @export
pg_card_article <- function(article_row,
                            narrative,
                            theme_color = "#1B4F72",
                            lang        = "fr") {

  # ── Validate colour ────────────────────────────────────────────────────────
  if (!pg_hex_valid(theme_color)) {
    pg_msg("warn",
           "Couleur invalide, utilisation de #1B4F72.",
           "Invalid colour, falling back to #1B4F72.")
    theme_color <- "#1B4F72"
  }

  # ── Extract metadata safely ─────────────────────────────────────────────────
  safe_field <- function(row, field, fallback = "") {
    tryCatch({
      val <- as.character(row[[field]])
      if (is.na(val) || nchar(str_trim(val)) == 0L) fallback else val
    }, error = function(e) fallback)
  }

  title_val   <- safe_field(article_row, "title",   "Sans titre | Untitled")
  author_val  <- safe_field(article_row, "author",  "Auteur inconnu | Unknown author")
  journal_val <- safe_field(article_row, "journal", "Revue non renseign\u00e9e | N/A")
  year_val    <- safe_field(article_row, "year",    "")
  doi_val     <- safe_field(article_row, "doi",     "")

  # ── Labels ──────────────────────────────────────────────────────────────────
  if (lang == "fr") {
    labels <- list(
      badge             = "ARTICLE",
      authors_lbl       = "Auteurs",
      journal_lbl       = "Revue",
      problematique_lbl = "Probl\u00e9matique",
      pertinence_lbl    = "Pertinence",
      resultat_lbl      = "R\u00e9sultat cl\u00e9",
      question_lbl      = "Question ouverte",
      doi_lbl           = "Acc\u00e9der",
      na_text           = "Non disponible"
    )
  } else {
    labels <- list(
      badge             = "ARTICLE",
      authors_lbl       = "Authors",
      journal_lbl       = "Journal",
      problematique_lbl = "Research Question",
      pertinence_lbl    = "Relevance",
      resultat_lbl      = "Key Finding",
      question_lbl      = "Open Question",
      doi_lbl           = "Access",
      na_text           = "Not available"
    )
  }

  # ── Narrative values ────────────────────────────────────────────────────────
  na_text <- labels$na_text
  safe_narr <- function(field) {
    tryCatch({
      val <- as.character(narrative[[field]])
      if (is.na(val) || nchar(str_trim(val)) == 0L) na_text else val
    }, error = function(e) na_text)
  }

  problematique_val  <- safe_narr("problematique")
  pertinence_val     <- safe_narr("pertinence")
  resultat_val       <- safe_narr("resultat")
  question_val       <- safe_narr("question_ouverte")

  # ── DOI link ────────────────────────────────────────────────────────────────
  doi_lbl <- labels$doi_lbl

  doi_html <- if (nchar(doi_val) > 0L) {
    doi_url <- if (str_detect(doi_val, "^https?://")) {
      doi_val
    } else {
      paste0("https://doi.org/", doi_val)
    }
    glue_safe(
      '<a href="{doi_url}" target="_blank" ',
      'style="color:{theme_color};text-decoration:none;font-weight:600;">',
      '&#128279; {doi_lbl}</a>'
    )
  } else {
    ""
  }

  # ── Extract labels to local vars (glue_safe cannot resolve `$`) ───────────
  badge_lbl         <- labels$badge
  authors_lbl       <- labels$authors_lbl
  journal_lbl       <- labels$journal_lbl
  problematique_lbl <- labels$problematique_lbl
  pertinence_lbl    <- labels$pertinence_lbl
  resultat_lbl      <- labels$resultat_lbl
  question_lbl      <- labels$question_lbl

  # ── Assemble HTML card ─────────────────────────────────────────────────────
  card_html <- tryCatch({
    glue_safe('
<div style="border-left:5px solid {theme_color};background:#FAFAFA;
            border-radius:6px;padding:18px 22px;margin-bottom:20px;
            font-family:Lato,Helvetica,Arial,sans-serif;
            box-shadow:0 1px 4px rgba(0,0,0,0.08);">

  <!-- Badge -->
  <span style="display:inline-block;background:{theme_color};color:#FFFFFF;
               font-size:11px;font-weight:700;padding:3px 10px;
               border-radius:3px;letter-spacing:0.8px;margin-bottom:8px;">
    {badge_lbl} {year_val}
  </span>

  <!-- Title -->
  <h3 style="margin:8px 0 4px;color:#1A1A1A;font-size:16px;
             line-height:1.35;">{title_val}</h3>

  <!-- Authors -->
  <p style="margin:2px 0;color:#555555;font-size:13px;">
    <strong>{authors_lbl} :</strong> {author_val}
  </p>

  <!-- Journal -->
  <p style="margin:2px 0 10px;color:#555555;font-size:13px;">
    <em>{journal_lbl} : {journal_val}</em> &nbsp; {doi_html}
  </p>

  <hr style="border:none;border-top:1px solid #E0E0E0;margin:10px 0;">

  <!-- Narrative sections -->
  <div style="margin-top:8px;">
    <p style="margin:6px 0;font-size:13px;line-height:1.5;">
      <span style="color:{theme_color};font-weight:700;">&#127891; {problematique_lbl} &mdash;</span>
      {problematique_val}
    </p>
    <p style="margin:6px 0;font-size:13px;line-height:1.5;">
      <span style="color:{theme_color};font-weight:700;">&#127760; {pertinence_lbl} &mdash;</span>
      {pertinence_val}
    </p>
    <p style="margin:6px 0;font-size:13px;line-height:1.5;">
      <span style="color:{theme_color};font-weight:700;">&#128200; {resultat_lbl} &mdash;</span>
      {resultat_val}
    </p>
    <p style="margin:6px 0;font-size:13px;line-height:1.5;">
      <span style="color:{theme_color};font-weight:700;">&#10067; {question_lbl} &mdash;</span>
      {question_val}
    </p>
  </div>

</div>
')
  }, error = function(e) {
    pg_msg("error",
           glue("Erreur lors de la cr\u00e9ation de la carte HTML : {conditionMessage(e)}"),
           glue("Error creating HTML card: {conditionMessage(e)}"))
    paste0('<div style="color:red;">Error generating card for: ',
           title_val, '</div>')
  })

  pg_msg("success",
         glue("Carte HTML g\u00e9n\u00e9r\u00e9e pour : {pg_truncate(title_val, 40L)}"),
         glue("HTML card generated for: {pg_truncate(title_val, 40L)}"))

  as.character(card_html)
}
