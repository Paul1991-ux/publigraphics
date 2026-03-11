# -- generate_notebook.R --------------------------------------------------------
# Main pipeline function that orchestrates the entire publigraphics workflow:
# parse inputs, classify, compute stats, generate visualisations, build cover,
# render Rmd template, and export to PDF / HTML.
# Exported: generate_publigraphics.
# ------------------------------------------------------------------------------


#' Generate a Complete PubliGraphics Notebook
#'
#' End-to-end pipeline that reads bibliographic and supplementary data, classifies
#' research outputs, computes summary statistics, generates AI narrative summaries
#' (when an Anthropic API key is available), produces all visualisations, builds an
#' HTML cover page, renders an R Markdown template to HTML, and optionally converts
#' to PDF via [pagedown::chrome_print()]. The final output files are named with
#' the author name and current date, and can be opened automatically in a browser.
#'
#' @param author_name Character(1). Full name of the researcher (e.g.
#'   `"Dupont, Marie"`). Used in the cover page, co-authorship network, and
#'   output file names.
#' @param bib_file Character(1). Path to the bibliography file (`.bib`, `.csv`,
#'   or `.xlsx`). Parsed by [pg_read_bib()].
#' @param extra_data Character(1) or `NULL`. Path to a supplementary CSV file
#'   containing non-bibliographic outputs (seminars, projects, theses, awards).
#'   Parsed by [pg_read_extra()]. Default `NULL`.
#' @param photo Character(1) or `NULL`. Path to a local photo file (JPEG/PNG)
#'   for the cover page. Default `NULL` (initials placeholder used).
#' @param affiliation Character(1). Institutional affiliation for the cover page.
#'   Default `""`.
#' @param orcid Character(1) or `NULL`. ORCID identifier. Default `NULL`.
#' @param linkedin Character(1) or `NULL`. LinkedIn profile URL. Default `NULL`.
#' @param website Character(1) or `NULL`. Personal website URL (also used to
#'   generate a QR code on the cover). Default `NULL`.
#' @param api_key_claude Character(1). Anthropic API key for narrative generation.
#'   Defaults to `Sys.getenv("ANTHROPIC_API_KEY")`. When empty or invalid,
#'   narrative summaries are silently skipped.
#' @param theme_color Character(1). Hex colour code for the visual theme
#'   (default `"#1B4F72"`). Must be a valid `#RRGGBB` or `#RGB` string.
#' @param output_formats Character vector. One or both of `"pdf"` and `"html"`.
#'   Default `c("pdf", "html")`.
#' @param output_dir Character(1). Directory where output files and
#'   visualisations are saved. A `viz/` sub-directory is created automatically.
#'   Default `file.path(getwd(), "publigraphics_output")`.
#' @param language Character(1). Language for bilingual labels and narrative
#'   prompts: `"fr"` (default) or `"en"`.
#' @param use_cache Logical(1). If `TRUE` (default), geocoding results and
#'   API responses are cached to avoid redundant calls on re-runs.
#' @param open_after Logical(1). If `TRUE` (default), the HTML output is
#'   opened in the default browser after generation.
#' @param n_narrative_max Integer(1). Maximum number of items to generate
#'   narrative summaries for (default `20L`). Limits API usage.
#'
#' @return Invisible named list with elements:
#'   \describe{
#'     \item{pdf_path}{Character or `NULL`. Path to the generated PDF file.}
#'     \item{html_path}{Character or `NULL`. Path to the generated HTML file.}
#'     \item{data}{The merged and classified tibble used for all outputs.}
#'     \item{duration_seconds}{Numeric. Wall-clock duration of the pipeline.}
#'   }
#'
#' @details
#' ## Pipeline Steps
#'
#' 1. **Validate inputs**: file existence, hex colour format, output formats,
#'    language code.
#' 2. **Create directories**: `output_dir` and `output_dir/viz`.
#' 3. **Parse data**: [pg_read_bib()], optionally [pg_read_extra()], then
#'    [pg_merge_inputs()] and [pg_classify()].
#' 4. **Compute stats**: [pg_stats_banner()] for the cover page and summary.
#' 5. **Narrative summaries** (if API key valid): [pg_run_all_narratives()]
#'    generates structured AI summaries for up to `n_narrative_max` items.
#' 6. **Visualisations**: all `pg_wordcloud_*`, `pg_timeline_*`,
#'    `pg_network_*`, `pg_map_*`, `pg_gallery_*`, `pg_gantt_*`,
#'    `pg_infographic_*`, and `pg_media_*` functions are called. Each plot is
#'    saved as a 300 dpi PNG via [ggplot2::ggsave()].
#' 7. **Cover page**: [pg_build_cover()] generates the HTML cover.
#' 8. **Template**: the Rmd template is copied from
#'    `system.file("templates", package = "publigraphics")` to `output_dir`.
#' 9. **Render**: [rmarkdown::render()] produces the HTML notebook, passing
#'    all params.
#' 10. **PDF** (if requested): [pagedown::chrome_print()] converts the HTML
#'     to PDF.
#' 11. **Rename**: output files are renamed to
#'     `publigraphics_<AuthorName>_<YYYYMMDD>.<ext>`.
#' 12. **Summary**: a [cli] summary is printed with file paths and counts.
#' 13. **Open**: if `open_after = TRUE`, the HTML file is opened in the
#'     browser via [utils::browseURL()].
#'
#' @examples
#' \dontrun{
#' generate_publigraphics(
#'   author_name = "Wambo, Paul",
#'   bib_file    = "references.bib",
#'   extra_data  = "extra_outputs.csv",
#'   photo       = "photo.jpg",
#'   affiliation = "Universite de Yaounde II",
#'   orcid       = "0009-0005-6062-9227",
#'   website     = "https://paulwambo.com",
#'   theme_color = "#1B4F72",
#'   output_formats = c("pdf", "html"),
#'   language    = "fr"
#' )
#' }
#'
#' @export
generate_publigraphics <- function(author_name,
                                   bib_file,
                                   extra_data       = NULL,
                                   photo            = NULL,
                                   affiliation      = "",
                                   orcid            = NULL,
                                   linkedin         = NULL,
                                   website          = NULL,
                                   api_key_claude   = Sys.getenv("ANTHROPIC_API_KEY"),
                                   theme_color      = "#1B4F72",
                                   output_formats   = c("pdf", "html"),
                                   output_dir       = file.path(getwd(),
                                                                "publigraphics_output"),
                                   language         = "fr",
                                   use_cache        = TRUE,
                                   open_after       = TRUE,
                                   n_narrative_max  = 20L) {

  start_time <- proc.time()

  tryCatch({

    # =========================================================================
    # STEP 1: Validate inputs
    # =========================================================================
    pg_msg("info",
           "Demarrage du pipeline PubliGraphics...",
           "Starting PubliGraphics pipeline...")
    cli::cli_h1("PubliGraphics")

    # -- author_name -----------------------------------------------------------
    if (missing(author_name) || is.null(author_name) ||
        nchar(stringr::str_trim(author_name)) == 0L) {
      pg_msg("error",
             "Le nom de l'auteur (author_name) est requis.",
             "Author name (author_name) is required.")
      stop("generate_publigraphics: missing 'author_name'.", call. = FALSE)
    }

    # -- bib_file --------------------------------------------------------------
    if (missing(bib_file) || is.null(bib_file) ||
        nchar(stringr::str_trim(bib_file)) == 0L) {
      pg_msg("error",
             "Le fichier bibliographique (bib_file) est requis.",
             "Bibliography file (bib_file) is required.")
      stop("generate_publigraphics: missing 'bib_file'.", call. = FALSE)
    }

    if (!fs::file_exists(bib_file)) {
      pg_msg("error",
             glue::glue("Fichier bibliographique introuvable : {bib_file}"),
             glue::glue("Bibliography file not found: {bib_file}"))
      stop(glue::glue("File not found: {bib_file}"), call. = FALSE)
    }

    # -- extra_data (optional) -------------------------------------------------
    if (!is.null(extra_data) && !fs::file_exists(extra_data)) {
      pg_msg("warn",
             glue::glue("Fichier supplementaire introuvable : {extra_data} ; ignore."),
             glue::glue("Supplementary file not found: {extra_data}; skipping."))
      extra_data <- NULL
    }

    # -- photo (optional) ------------------------------------------------------
    if (!is.null(photo) && !fs::file_exists(photo)) {
      pg_msg("warn",
             glue::glue("Photo introuvable : {photo} ; initiales utilisees."),
             glue::glue("Photo not found: {photo}; using initials."))
      photo <- NULL
    }

    # -- theme_color -----------------------------------------------------------
    if (!pg_hex_valid(theme_color)) {
      pg_msg("warn",
             "Couleur de theme invalide ; utilisation de #1B4F72.",
             "Invalid theme colour; falling back to #1B4F72.")
      theme_color <- "#1B4F72"
    }

    # -- output_formats --------------------------------------------------------
    valid_formats <- c("pdf", "html")
    output_formats <- tolower(output_formats)
    output_formats <- intersect(output_formats, valid_formats)
    if (length(output_formats) == 0L) {
      pg_msg("warn",
             "Aucun format de sortie valide ; utilisation de 'html'.",
             "No valid output format; falling back to 'html'.")
      output_formats <- "html"
    }

    # -- language --------------------------------------------------------------
    language <- match.arg(language, c("fr", "en"))

    # -- n_narrative_max -------------------------------------------------------
    n_narrative_max <- as.integer(n_narrative_max)
    if (is.na(n_narrative_max) || n_narrative_max < 0L) {
      n_narrative_max <- 20L
    }

    pg_msg("success",
           "Validation des parametres terminee.",
           "Input validation complete.")

    # =========================================================================
    # STEP 2: Create output directories
    # =========================================================================
    cli::cli_h2("Repertoires | Directories")

    fs::dir_create(output_dir)
    viz_dir <- fs::path(output_dir, "viz")
    fs::dir_create(viz_dir)

    pg_msg("success",
           glue::glue("Repertoire de sortie cree : {output_dir}"),
           glue::glue("Output directory created: {output_dir}"))

    # =========================================================================
    # STEP 3: Parse and merge inputs
    # =========================================================================
    cli::cli_h2("Import des donnees | Data Import")

    bib_data <- pg_read_bib(bib_file)

    extra_tbl <- NULL
    if (!is.null(extra_data)) {
      extra_tbl <- pg_read_extra(extra_data)
    }

    merged_data <- pg_merge_inputs(bib_data, extra_tbl)
    classified_data <- pg_classify(merged_data)

    pg_msg("success",
           glue::glue("{nrow(classified_data)} productions classifiees."),
           glue::glue("{nrow(classified_data)} productions classified."))

    # =========================================================================
    # STEP 4: Compute summary statistics
    # =========================================================================
    cli::cli_h2("Statistiques | Statistics")

    summary_tbl <- pg_summary_table(classified_data)

    # Build the stats list for the cover page
    stats_list <- pg_build_stats_list(summary_tbl)

    pg_msg("success",
           "Statistiques calculees.",
           "Statistics computed.")

    # =========================================================================
    # STEP 5: AI Narrative summaries (optional)
    # =========================================================================
    cli::cli_h2("Narrations IA | AI Narratives")

    has_api_key <- !is.null(api_key_claude) &&
      nchar(stringr::str_trim(api_key_claude)) > 10L

    narratives <- NULL
    if (has_api_key && n_narrative_max > 0L) {
      pg_msg("info",
             glue::glue("Generation des narrations IA (max {n_narrative_max})..."),
             glue::glue("Generating AI narratives (max {n_narrative_max})..."))

      narratives <- tryCatch(
        pg_run_all_narratives(
          data      = classified_data,
          api_key   = api_key_claude,
          lang      = language,
          max_items = n_narrative_max
        ),
        error = function(e) {
          pg_msg("warn",
                 glue::glue("Narrations IA echouees : {conditionMessage(e)}"),
                 glue::glue("AI narratives failed: {conditionMessage(e)}"))
          NULL
        }
      )

      if (!is.null(narratives)) {
        pg_msg("success",
               "Narrations IA generees avec succes.",
               "AI narratives generated successfully.")
      }
    } else {
      pg_msg("info",
             "Pas de cle API valide ou n_narrative_max = 0 ; narrations ignorees.",
             "No valid API key or n_narrative_max = 0; narratives skipped.")
    }

    # =========================================================================
    # STEP 6: Generate all visualisations
    # =========================================================================
    cli::cli_h2("Visualisations")

    viz_paths <- pg_generate_all_viz(
      data        = classified_data,
      author_name = author_name,
      theme_color = theme_color,
      language    = language,
      viz_dir     = viz_dir
    )

    pg_msg("success",
           glue::glue("{length(viz_paths)} visualisation(s) sauvegardee(s)."),
           glue::glue("{length(viz_paths)} visualisation(s) saved."))

    # =========================================================================
    # STEP 7: Build cover page
    # =========================================================================
    cli::cli_h2("Page de couverture | Cover Page")

    cover_html <- pg_build_cover(
      author_name = author_name,
      affiliation = affiliation,
      photo_path  = photo,
      orcid       = orcid,
      linkedin    = linkedin,
      website     = website,
      stats       = stats_list,
      theme_color = theme_color,
      lang        = language
    )

    # Save cover HTML to output directory
    cover_path <- fs::path(output_dir, "cover.html")
    writeLines(cover_html, cover_path, useBytes = TRUE)

    pg_msg("success",
           "Page de couverture generee.",
           "Cover page generated.")

    # =========================================================================
    # STEP 8: Copy and prepare Rmd template
    # =========================================================================
    cli::cli_h2("Template R Markdown")

    template_src <- system.file(
      "templates", "publigraphics_notebook.Rmd",
      package = "publigraphics"
    )

    if (!nzchar(template_src) || !file.exists(template_src)) {
      pg_msg("error",
             "Template Rmd introuvable dans le package.",
             "Rmd template not found in the package.")
      stop("generate_publigraphics: Rmd template not found.", call. = FALSE)
    }

    template_dest <- fs::path(output_dir, "publigraphics_notebook.Rmd")
    fs::file_copy(template_src, template_dest, overwrite = TRUE)

    pg_msg("success",
           "Template Rmd copiee dans le repertoire de sortie.",
           "Rmd template copied to output directory.")

    # =========================================================================
    # STEP 9: Render with rmarkdown
    # =========================================================================
    cli::cli_h2("Rendu HTML | HTML Rendering")

    render_params <- list(
      author_name    = author_name,
      affiliation    = affiliation,
      theme_color    = theme_color,
      language       = language,
      cover_html     = cover_html,
      data           = classified_data,
      summary_table  = summary_tbl,
      narratives     = narratives,
      viz_dir        = as.character(viz_dir),
      viz_paths      = viz_paths
    )

    html_output <- tryCatch({
      rmarkdown::render(
        input       = as.character(template_dest),
        output_dir  = as.character(output_dir),
        params      = render_params,
        quiet       = TRUE,
        envir       = new.env(parent = globalenv())
      )
    }, error = function(e) {
      pg_msg("error",
             glue::glue("Erreur de rendu Rmd : {conditionMessage(e)}"),
             glue::glue("Rmd rendering error: {conditionMessage(e)}"))
      NULL
    })

    if (is.null(html_output)) {
      pg_msg("warn",
             "Le rendu HTML a echoue ; impossible de continuer.",
             "HTML rendering failed; unable to continue.")
      elapsed <- (proc.time() - start_time)["elapsed"]
      return(invisible(list(
        pdf_path         = NULL,
        html_path        = NULL,
        data             = classified_data,
        duration_seconds = as.numeric(elapsed)
      )))
    }

    pg_msg("success",
           "Rendu HTML termine.",
           "HTML rendering complete.")

    # =========================================================================
    # STEP 10: PDF via pagedown::chrome_print() (if requested)
    # =========================================================================
    pdf_output <- NULL

    if ("pdf" %in% output_formats) {
      cli::cli_h2("Conversion PDF")

      pdf_output <- tryCatch({
        pdf_path <- sub("\\.html$", ".pdf", html_output)
        pagedown::chrome_print(
          input  = html_output,
          output = pdf_path,
          wait   = 10,
          extra_args = c("--no-sandbox", "--disable-gpu")
        )
        pdf_path
      }, error = function(e) {
        pg_msg("warn",
               glue::glue("Conversion PDF echouee : {conditionMessage(e)}"),
               glue::glue("PDF conversion failed: {conditionMessage(e)}"))
        NULL
      })

      if (!is.null(pdf_output)) {
        pg_msg("success",
               "Conversion PDF terminee.",
               "PDF conversion complete.")
      }
    }

    # =========================================================================
    # STEP 11: Rename output files with author name + date
    # =========================================================================
    cli::cli_h2("Renommage | Renaming")

    date_stamp  <- format(Sys.Date(), "%Y%m%d")
    author_slug <- pg_slugify(author_name)
    base_name   <- glue::glue("publigraphics_{author_slug}_{date_stamp}")

    # Rename HTML
    final_html <- NULL
    if (!is.null(html_output) && file.exists(html_output)) {
      final_html <- fs::path(output_dir, paste0(base_name, ".html"))
      tryCatch(
        fs::file_move(html_output, final_html),
        error = function(e) {
          pg_msg("warn",
                 "Impossible de renommer le fichier HTML.",
                 "Unable to rename the HTML file.")
          final_html <<- html_output
        }
      )
    }

    # Rename PDF
    final_pdf <- NULL
    if (!is.null(pdf_output) && file.exists(pdf_output)) {
      final_pdf <- fs::path(output_dir, paste0(base_name, ".pdf"))
      tryCatch(
        fs::file_move(pdf_output, final_pdf),
        error = function(e) {
          pg_msg("warn",
                 "Impossible de renommer le fichier PDF.",
                 "Unable to rename the PDF file.")
          final_pdf <<- pdf_output
        }
      )
    }

    pg_msg("success",
           "Fichiers de sortie renommes.",
           "Output files renamed.")

    # =========================================================================
    # STEP 12: Final summary via cli
    # =========================================================================
    elapsed <- (proc.time() - start_time)["elapsed"]
    elapsed_fmt <- sprintf("%.1f", as.numeric(elapsed))

    cli::cli_h1("Terminee | Complete")

    cli::cli_bullets(c(
      "i" = glue::glue("Auteur | Author: {author_name}"),
      "i" = glue::glue("Productions | Productions: {nrow(classified_data)}"),
      "i" = glue::glue("Types: {nrow(summary_tbl)}"),
      "i" = glue::glue("Visualisations: {length(viz_paths)}"),
      "i" = glue::glue("Narrations IA | AI Narratives: {if (is.null(narratives)) 0L else nrow(narratives)}"),
      "v" = if (!is.null(final_html)) {
        glue::glue("HTML: {final_html}")
      } else {
        "HTML: non genere | not generated"
      },
      "v" = if (!is.null(final_pdf)) {
        glue::glue("PDF: {final_pdf}")
      } else {
        "PDF: non genere | not generated"
      },
      "i" = glue::glue("Duree | Duration: {elapsed_fmt}s")
    ))

    # =========================================================================
    # STEP 13: Open in browser (if requested)
    # =========================================================================
    if (open_after && !is.null(final_html) && file.exists(final_html)) {
      tryCatch(
        utils::browseURL(as.character(final_html)),
        error = function(e) {
          pg_msg("warn",
                 "Impossible d'ouvrir le fichier dans le navigateur.",
                 "Unable to open file in browser.")
        }
      )
    }

    # =========================================================================
    # STEP 14: Return invisible results
    # =========================================================================
    invisible(list(
      pdf_path         = if (!is.null(final_pdf)) as.character(final_pdf) else NULL,
      html_path        = if (!is.null(final_html)) as.character(final_html) else NULL,
      data             = classified_data,
      duration_seconds = as.numeric(elapsed)
    ))

  }, error = function(e) {
    elapsed <- (proc.time() - start_time)["elapsed"]
    if (!grepl("^generate_publigraphics:", e$message)) {
      pg_msg("error",
             glue::glue("Erreur fatale dans le pipeline : {e$message}"),
             glue::glue("Fatal pipeline error: {e$message}"))
    }
    stop(e)
  })
}


# ===========================================================================
# Internal helper functions for generate_publigraphics
# ===========================================================================


#' Build the stats list for the cover page from a summary table
#'
#' Maps the canonical type counts from [pg_summary_table()] to the six
#' categories expected by [pg_build_cover()].
#'
#' @param summary_tbl A tibble as returned by [pg_summary_table()].
#'
#' @return A named list with keys `Articles`, `Books`, `Seminars`, `Theses`,
#'   `Awards`, `Projects`. Each value is an integer count.
#' @noRd
pg_build_stats_list <- function(summary_tbl) {

  get_count <- function(types) {
    summary_tbl |>
      dplyr::filter(.data$type_classified %in% types) |>
      dplyr::pull(.data$n) |>
      sum(na.rm = TRUE) |>
      as.integer()
  }

  list(
    Articles = get_count(c("article")),
    Books    = get_count(c("book", "book_chapter")),
    Seminars = get_count(c("seminar", "conference")),
    Theses   = get_count(c("thesis_supervised")),
    Awards   = get_count(c("award")),
    Projects = get_count(c("project"))
  )
}


#' Generate a URL-safe slug from an author name
#'
#' Converts a name like `"Dupont, Marie"` into `"dupont_marie"` for use
#' in output file names.
#'
#' @param name Character(1). Author name.
#'
#' @return Character(1). Lowercased slug with non-alphanumeric characters
#'   replaced by underscores.
#' @noRd
pg_slugify <- function(name) {
  name |>
    stringr::str_to_lower() |>
    stringr::str_replace_all("[^a-z0-9]+", "_") |>
    stringr::str_remove_all("^_|_$")
}


#' Compute the banner stats for quick display
#'
#' Returns a one-row tibble with total counts, year range, and type summary
#' suitable for embedding in an Rmd header or CLI output.
#'
#' @param data A classified tibble from [pg_classify()].
#'
#' @return A one-row tibble with summary statistics.
#' @noRd
pg_stats_banner <- function(data) {

  tryCatch({
    tibble::tibble(
      total_productions = nrow(data),
      n_types           = length(unique(data$type_classified)),
      year_min          = min(data$year, na.rm = TRUE),
      year_max          = max(data$year, na.rm = TRUE),
      career_span       = max(data$year, na.rm = TRUE) -
        min(data$year, na.rm = TRUE) + 1L
    )
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Erreur dans pg_stats_banner : {conditionMessage(e)}"),
           glue::glue("Error in pg_stats_banner: {conditionMessage(e)}"))
    tibble::tibble(
      total_productions = 0L, n_types = 0L,
      year_min = NA_integer_, year_max = NA_integer_,
      career_span = 0L
    )
  })
}


#' Generate all visualisations and save them as PNG files
#'
#' Calls each `pg_*` visualisation function, catches errors gracefully, and
#' saves static plots as 300 dpi PNG files to the `viz_dir`. Returns a named
#' character vector of saved file paths.
#'
#' @param data A classified tibble.
#' @param author_name Character. Focal author name.
#' @param theme_color Character. Hex colour for the theme.
#' @param language Character. `"fr"` or `"en"`.
#' @param viz_dir Character. Path to the viz sub-directory.
#'
#' @return Named character vector of file paths for saved visualisations.
#' @noRd
pg_generate_all_viz <- function(data, author_name, theme_color,
                                language, viz_dir) {

  saved_paths <- character(0L)

  # Helper: save a ggplot object and record its path
  save_plot <- function(plot_obj, filename, width = 10, height = 7) {
    if (is.null(plot_obj)) return(invisible(NULL))
    if (!inherits(plot_obj, "gg") && !inherits(plot_obj, "patchwork")) {
      return(invisible(NULL))
    }
    out_path <- fs::path(viz_dir, filename)
    tryCatch({
      ggplot2::ggsave(
        filename = as.character(out_path),
        plot     = plot_obj,
        width    = width,
        height   = height,
        dpi      = 300,
        bg       = "white"
      )
      saved_paths[[filename]] <<- as.character(out_path)
      pg_msg("info",
             glue::glue("Sauvegarde : {filename}"),
             glue::glue("Saved: {filename}"))
    }, error = function(e) {
      pg_msg("warn",
             glue::glue("Impossible de sauvegarder {filename} : {conditionMessage(e)}"),
             glue::glue("Unable to save {filename}: {conditionMessage(e)}"))
    })
    invisible(NULL)
  }

  # Helper: save a leaflet widget as PNG via webshot2
  save_widget <- function(widget_obj, filename, width = 900, height = 600) {
    if (is.null(widget_obj)) return(invisible(NULL))
    out_path <- fs::path(viz_dir, filename)
    tryCatch({
      tmp_html <- tempfile(fileext = ".html")
      htmlwidgets::saveWidget(widget_obj, tmp_html, selfcontained = TRUE)
      webshot2::webshot(
        url      = tmp_html,
        file     = as.character(out_path),
        vwidth   = width,
        vheight  = height,
        delay    = 2
      )
      tryCatch(unlink(tmp_html), error = function(e) NULL)
      saved_paths[[filename]] <<- as.character(out_path)
      pg_msg("info",
             glue::glue("Sauvegarde widget : {filename}"),
             glue::glue("Saved widget: {filename}"))
    }, error = function(e) {
      pg_msg("warn",
             glue::glue("Impossible de sauvegarder le widget {filename} : {conditionMessage(e)}"),
             glue::glue("Unable to save widget {filename}: {conditionMessage(e)}"))
    })
    invisible(NULL)
  }

  # 1. Word cloud (articles)
  tryCatch({
    wc_articles <- pg_wordcloud_articles(
      data, theme_color = theme_color, lang = if (language == "fr") "both" else "en"
    )
    save_plot(wc_articles$plot, "wordcloud_articles.png", width = 10, height = 8)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Nuage de mots articles echoue : {conditionMessage(e)}"),
           glue::glue("Article word cloud failed: {conditionMessage(e)}"))
  })

  # 2. Timeline (articles)
  tryCatch({
    tl <- pg_timeline_articles(data, theme_color = theme_color)
    save_plot(tl, "timeline_articles.png", width = 12, height = 6)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Frise articles echouee : {conditionMessage(e)}"),
           glue::glue("Article timeline failed: {conditionMessage(e)}"))
  })

  # 3. Book gallery
  tryCatch({
    gallery <- pg_gallery_books(data, theme_color = theme_color)
    save_plot(gallery, "gallery_books.png", width = 12, height = 8)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Galerie ouvrages echouee : {conditionMessage(e)}"),
           glue::glue("Book gallery failed: {conditionMessage(e)}"))
  })

  # 4. Co-authorship network
  tryCatch({
    net <- pg_network_coauthors(data, author_name = author_name,
                                theme_color = theme_color)
    save_plot(net, "network_coauthors.png", width = 10, height = 10)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Reseau co-auteurs echoue : {conditionMessage(e)}"),
           glue::glue("Co-authorship network failed: {conditionMessage(e)}"))
  })

  # 5. Book word cloud
  tryCatch({
    wc_books <- pg_wordcloud_books(data, theme_color = theme_color,
                                    lang = if (language == "fr") "both" else "en")
    save_plot(wc_books$plot, "wordcloud_books.png", width = 10, height = 8)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Nuage de mots ouvrages echoue : {conditionMessage(e)}"),
           glue::glue("Book word cloud failed: {conditionMessage(e)}"))
  })

  # 6. Seminar map (static)
  tryCatch({
    maps <- pg_map_seminars(data, output_type = "both",
                            theme_color = theme_color)
    save_plot(maps$static, "map_seminars_static.png", width = 12, height = 7)
    save_widget(maps$interactive, "map_seminars_interactive.png")
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Carte seminaires echouee : {conditionMessage(e)}"),
           glue::glue("Seminar map failed: {conditionMessage(e)}"))
  })

  # 7. Seminar keyword network
  tryCatch({
    sem_net <- pg_network_seminars(data, author_name = author_name,
                                   theme_color = theme_color)
    save_plot(sem_net, "network_seminars.png", width = 10, height = 10)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Reseau seminaires echoue : {conditionMessage(e)}"),
           glue::glue("Seminar network failed: {conditionMessage(e)}"))
  })

  # 8. Gantt chart (projects)
  tryCatch({
    gantt <- pg_gantt_projects(data, theme_color = theme_color)
    save_plot(gantt, "gantt_projects.png", width = 12, height = 6)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Gantt projets echoue : {conditionMessage(e)}"),
           glue::glue("Gantt chart failed: {conditionMessage(e)}"))
  })

  # 9. Thesis timeline
  tryCatch({
    tl_theses <- pg_timeline_theses(data, theme_color = theme_color)
    save_plot(tl_theses, "timeline_theses.png", width = 10, height = 6)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Frise theses echouee : {conditionMessage(e)}"),
           glue::glue("Thesis timeline failed: {conditionMessage(e)}"))
  })

  # 10. Awards infographic
  tryCatch({
    awards <- pg_infographic_awards(data, theme_color = theme_color)
    save_plot(awards, "infographic_awards.png", width = 8, height = 10)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Infographie prix echouee : {conditionMessage(e)}"),
           glue::glue("Awards infographic failed: {conditionMessage(e)}"))
  })

  # 11. Expertise map
  tryCatch({
    exp_maps <- pg_map_expertise(data, theme_color = theme_color)
    save_plot(exp_maps$static, "map_expertise_static.png", width = 12, height = 7)
    save_widget(exp_maps$interactive, "map_expertise_interactive.png")
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Carte expertises echouee : {conditionMessage(e)}"),
           glue::glue("Expertise map failed: {conditionMessage(e)}"))
  })

  # 12. Media summary
  tryCatch({
    media <- pg_media_summary(data, theme_color = theme_color)
    save_plot(media, "media_summary.png", width = 10, height = 6)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("Graphique media echoue : {conditionMessage(e)}"),
           glue::glue("Media chart failed: {conditionMessage(e)}"))
  })

  saved_paths
}
