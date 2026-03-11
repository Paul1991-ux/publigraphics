# -- cover_page.R ---------------------------------------------------------------
# HTML cover page generator for the publigraphics notebook.
# Exported: pg_build_cover.
# ------------------------------------------------------------------------------


#' Build an HTML Cover Page for a Researcher Profile
#'
#' Generates a self-contained HTML cover page featuring the researcher's photo
#' (or initials placeholder), affiliation, social links (ORCID, LinkedIn),
#' a QR code for their website, and a 3x2 statistics grid summarising their
#' scientific output. The design uses CSS Grid with a two-column layout
#' (25 % left accent band / 75 % content area) and the Lato font loaded via
#' Google Fonts inline CSS.
#'
#' @param author_name Character(1). Full name of the researcher.
#' @param affiliation Character(1). Institutional affiliation displayed below
#'   the author name.
#' @param photo_path Character(1) or `NULL`. Path to a local photo file
#'   (JPEG or PNG). When `NULL` (default), a circular initials placeholder is
#'   generated from the first letters of `author_name`.
#' @param orcid Character(1) or `NULL`. ORCID identifier (e.g.
#'   `"0000-0001-2345-6789"`). Displayed as a clickable link when provided.
#' @param linkedin Character(1) or `NULL`. LinkedIn profile URL.
#' @param website Character(1) or `NULL`. Personal or institutional website
#'   URL. When provided a QR code is generated using [qrcode::qr_code()] and
#'   embedded as a base64 PNG image.
#' @param stats A named list with exactly six numeric elements:
#'   `Articles`, `Books`, `Seminars`, `Theses`, `Awards`, `Projects`.
#'   Each value is displayed as a large bold number in the stats grid.
#' @param theme_color Character(1). Hex colour code used for the left accent
#'   band gradient, headings, and link colours (default `"#1B4F72"`).
#' @param lang Character(1). Display language: `"fr"` (default) or `"en"`.
#'   Controls the labels in the stats grid and footer text.
#'
#' @return A `character(1)` HTML string suitable for inclusion in R Markdown
#'   or Quarto documents via [htmltools::HTML()].
#'
#' @details
#' ## Design
#'
#' The cover uses a **CSS Grid** two-column layout:
#'
#' * **Left band (25 %)**: a vertical gradient from `theme_color` to a darker
#'   shade (computed via [colorspace::darken()]).
#' * **Right area (75 %)**: contains the author photo (clipped to a circle
#'   with a 4 px white border), name, affiliation, social-link icons, the
#'   stats grid (3 columns x 2 rows), an optional QR code, and a footer.
#'
#' ## Security
#'
#' All user-supplied text values are interpolated with [glue::glue_safe()] to
#' prevent XSS injection in the generated HTML. The photo is embedded as a
#' base64 data URI to keep the output self-contained.
#'
#' @examples
#' \dontrun{
#' cover_html <- pg_build_cover(
#'   author_name = "Marie Dupont",
#'   affiliation = "Universite de Paris",
#'   photo_path  = "photo.jpg",
#'   orcid       = "0000-0001-2345-6789",
#'   linkedin    = "https://linkedin.com/in/mariedupont",
#'   website     = "https://mariedupont.fr",
#'   stats       = list(
#'     Articles = 24, Books = 3, Seminars = 15,
#'     Theses = 8, Awards = 2, Projects = 5
#'   ),
#'   theme_color = "#1B4F72",
#'   lang        = "fr"
#' )
#' htmltools::browsable(htmltools::HTML(cover_html))
#' }
#'
#' @export
pg_build_cover <- function(author_name,
                           affiliation,
                           photo_path  = NULL,
                           orcid       = NULL,
                           linkedin    = NULL,
                           website     = NULL,
                           stats,
                           theme_color = "#1B4F72",
                           lang        = "fr") {

  tryCatch({

    # -- Validate inputs ---------------------------------------------------------
    if (missing(author_name) || is.null(author_name) ||
        nchar(stringr::str_trim(author_name)) == 0L) {
      pg_msg("error",
             "Le nom de l'auteur est requis pour la page de couverture.",
             "Author name is required for the cover page.")
      stop("pg_build_cover: missing 'author_name'.", call. = FALSE)
    }

    if (missing(affiliation) || is.null(affiliation)) {
      affiliation <- ""
    }

    if (!pg_hex_valid(theme_color)) {
      pg_msg("warn",
             "Couleur invalide, utilisation de #1B4F72.",
             "Invalid colour, falling back to #1B4F72.")
      theme_color <- "#1B4F72"
    }

    lang <- match.arg(lang, c("fr", "en"))

    # Validate stats list
    expected_stat_keys <- c("Articles", "Books", "Seminars",
                            "Theses", "Awards", "Projects")
    if (!is.list(stats) || !all(expected_stat_keys %in% names(stats))) {
      pg_msg("warn",
             "La liste 'stats' est incomplete ; valeurs manquantes mises a 0.",
             "The 'stats' list is incomplete; missing values set to 0.")
      for (k in expected_stat_keys) {
        if (is.null(stats[[k]])) stats[[k]] <- 0L
      }
    }

    pg_msg("info",
           glue::glue("Construction de la page de couverture pour {author_name}..."),
           glue::glue("Building cover page for {author_name}..."))

    # -- Compute darker shade for gradient -------------------------------------
    darker_color <- tryCatch({
      colorspace::darken(theme_color, amount = 0.35)
    }, error = function(e) {
      "#0D2B3E"
    })

    # -- Build photo HTML (base64 or initials placeholder) ---------------------
    photo_html <- pg_cover_photo_html(author_name, photo_path, theme_color)

    # -- Build social links HTML -----------------------------------------------
    social_html <- pg_cover_social_html(orcid, linkedin, website, theme_color)

    # -- Build QR code HTML (if website provided) ------------------------------
    qr_html <- pg_cover_qr_html(website)

    # -- Build stats grid HTML -------------------------------------------------
    stats_html <- pg_cover_stats_html(stats, theme_color, lang)

    # -- Labels ----------------------------------------------------------------
    if (lang == "fr") {
      footer_text <- "Genere avec PubliGraphics for Social Researchers"
      profile_lbl <- "Profil Scientifique"
    } else {
      footer_text <- "Generated with PubliGraphics for Social Researchers"
      profile_lbl <- "Scientific Profile"
    }

    # -- Sanitise text for safe interpolation ----------------------------------
    safe_author      <- glue::glue_safe("{author_name}")
    safe_affiliation <- glue::glue_safe("{affiliation}")
    safe_profile_lbl <- glue::glue_safe("{profile_lbl}")
    safe_footer      <- glue::glue_safe("{footer_text}")

    # -- Assemble full HTML cover ----------------------------------------------
    cover_html <- glue::glue_safe('
<!DOCTYPE html>
<html lang="{lang}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  @import url("https://fonts.googleapis.com/css2?family=Lato:wght@300;400;700;900&display=swap");

  .pg-cover-wrapper {{
    font-family: "Lato", "Helvetica Neue", Helvetica, Arial, sans-serif;
    display: grid;
    grid-template-columns: 25% 75%;
    min-height: 100vh;
    width: 100%;
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    background: #FFFFFF;
    color: #1A1A1A;
    overflow: hidden;
  }}

  .pg-cover-left {{
    background: linear-gradient(180deg, {theme_color} 0%, {darker_color} 100%);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px 20px;
  }}

  .pg-cover-left .pg-brand-text {{
    color: rgba(255, 255, 255, 0.85);
    font-size: 14px;
    font-weight: 700;
    letter-spacing: 2px;
    text-transform: uppercase;
    writing-mode: vertical-rl;
    text-orientation: mixed;
    transform: rotate(180deg);
  }}

  .pg-cover-right {{
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 50px 40px;
    gap: 24px;
  }}

  .pg-cover-photo {{
    width: 140px;
    height: 140px;
    border-radius: 50%;
    border: 4px solid #FFFFFF;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
    object-fit: cover;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }}

  .pg-cover-initials {{
    width: 140px;
    height: 140px;
    border-radius: 50%;
    border: 4px solid #FFFFFF;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
    background: {theme_color};
    color: #FFFFFF;
    font-size: 48px;
    font-weight: 900;
    display: flex;
    align-items: center;
    justify-content: center;
    letter-spacing: 2px;
  }}

  .pg-cover-name {{
    font-size: 32px;
    font-weight: 900;
    color: {theme_color};
    margin: 0;
    text-align: center;
    line-height: 1.2;
  }}

  .pg-cover-affiliation {{
    font-size: 16px;
    color: #555555;
    margin: 0;
    text-align: center;
    font-style: italic;
  }}

  .pg-cover-label {{
    font-size: 13px;
    color: #999999;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    font-weight: 700;
    margin: 0;
  }}

  .pg-cover-social {{
    display: flex;
    gap: 18px;
    align-items: center;
    justify-content: center;
    flex-wrap: wrap;
  }}

  .pg-cover-social a {{
    color: {theme_color};
    text-decoration: none;
    font-size: 13px;
    font-weight: 600;
    transition: opacity 0.2s;
  }}

  .pg-cover-social a:hover {{
    opacity: 0.7;
  }}

  .pg-stats-grid {{
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
    width: 100%;
    max-width: 520px;
    margin: 10px 0;
  }}

  .pg-stat-card {{
    background: #F8F9FA;
    border-radius: 8px;
    padding: 16px 12px;
    text-align: center;
    border-left: 3px solid {theme_color};
    transition: box-shadow 0.2s;
  }}

  .pg-stat-card:hover {{
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  }}

  .pg-stat-icon {{
    font-size: 22px;
    display: block;
    margin-bottom: 4px;
  }}

  .pg-stat-number {{
    font-size: 28px;
    font-weight: 900;
    color: {theme_color};
    display: block;
    line-height: 1.2;
  }}

  .pg-stat-label {{
    font-size: 11px;
    color: #777777;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    font-weight: 600;
  }}

  .pg-cover-qr {{
    margin-top: 8px;
    text-align: center;
  }}

  .pg-cover-qr img {{
    width: 80px;
    height: 80px;
    border: 1px solid #EEEEEE;
    border-radius: 4px;
  }}

  .pg-cover-qr-label {{
    font-size: 10px;
    color: #AAAAAA;
    margin-top: 4px;
  }}

  .pg-cover-footer {{
    font-size: 11px;
    color: #BBBBBB;
    text-align: center;
    padding-top: 12px;
    border-top: 1px solid #EEEEEE;
    width: 100%;
    max-width: 520px;
  }}
</style>
</head>
<body style="margin:0;padding:0;">
<div class="pg-cover-wrapper">

  <!-- Left accent band -->
  <div class="pg-cover-left">
    <span class="pg-brand-text">PUBLIGRAPHICS</span>
  </div>

  <!-- Right content area -->
  <div class="pg-cover-right">

    <!-- Photo or initials -->
    {photo_html}

    <!-- Author name -->
    <h1 class="pg-cover-name">{safe_author}</h1>

    <!-- Affiliation -->
    <p class="pg-cover-affiliation">{safe_affiliation}</p>

    <!-- Profile label -->
    <p class="pg-cover-label">{safe_profile_lbl}</p>

    <!-- Social links -->
    {social_html}

    <!-- Stats grid 3x2 -->
    {stats_html}

    <!-- QR code -->
    {qr_html}

    <!-- Footer -->
    <div class="pg-cover-footer">
      {safe_footer}
    </div>

  </div>

</div>
</body>
</html>
')

    pg_msg("success",
           glue::glue("Page de couverture generee pour {author_name}."),
           glue::glue("Cover page generated for {author_name}."))

    as.character(cover_html)

  }, error = function(e) {
    if (!grepl("^pg_build_cover:", e$message)) {
      pg_msg("error",
             glue::glue("Erreur inattendue dans pg_build_cover : {e$message}"),
             glue::glue("Unexpected error in pg_build_cover: {e$message}"))
    }
    stop(e)
  })
}


# -- Internal helpers for pg_build_cover --------------------------------------

#' Build the photo or initials placeholder HTML fragment
#'
#' @param author_name Character. Author name for initials extraction.
#' @param photo_path Character or NULL. Path to a local photo file.
#' @param theme_color Character. Hex colour for placeholder background.
#'
#' @return Character(1). HTML fragment.
#' @noRd
pg_cover_photo_html <- function(author_name, photo_path, theme_color) {

  # If photo_path is provided and file exists, embed as base64

  if (!is.null(photo_path) && nchar(photo_path) > 0L) {
    photo_exists <- tryCatch(
      fs::file_exists(photo_path),
      error = function(e) FALSE
    )

    if (photo_exists) {
      photo_b64 <- tryCatch({
        raw_bytes <- readBin(photo_path, what = "raw",
                             n = file.info(photo_path)$size)
        ext <- tolower(tools::file_ext(photo_path))
        mime_type <- switch(ext,
          jpg = "image/jpeg", jpeg = "image/jpeg",
          png = "image/png", gif = "image/gif",
          "image/jpeg"
        )
        b64 <- base64enc::base64encode(raw_bytes)
        paste0("data:", mime_type, ";base64,", b64)
      }, error = function(e) {
        pg_msg("warn",
               "Impossible de lire la photo ; utilisation des initiales.",
               "Unable to read photo; using initials placeholder.")
        NULL
      })

      if (!is.null(photo_b64)) {
        safe_b64 <- glue::glue_safe("{photo_b64}")
        return(glue::glue_safe(
          '<img class="pg-cover-photo" src="{safe_b64}" alt="Author photo">'
        ))
      }
    } else {
      pg_msg("warn",
             glue::glue("Photo introuvable : {photo_path} ; utilisation des initiales."),
             glue::glue("Photo not found: {photo_path}; using initials."))
    }
  }

  # Fallback: generate initials placeholder
  initials <- pg_extract_initials(author_name)
  safe_initials <- glue::glue_safe("{initials}")
  glue::glue_safe(
    '<div class="pg-cover-initials">{safe_initials}</div>'
  )
}


#' Extract initials from an author name
#'
#' Takes the first letter of each whitespace-separated word, up to 3 letters.
#'
#' @param name Character(1). Full name string.
#'
#' @return Character(1). Uppercase initials (1-3 characters).
#' @noRd
pg_extract_initials <- function(name) {
  parts <- unlist(strsplit(stringr::str_trim(name), "\\s+"))
  parts <- parts[nchar(parts) > 0L]
  if (length(parts) == 0L) return("?")
  initials <- toupper(substr(parts, 1L, 1L))
  paste0(head(initials, 3L), collapse = "")
}


#' Build social links HTML fragment
#'
#' @param orcid Character or NULL.
#' @param linkedin Character or NULL.
#' @param website Character or NULL.
#' @param theme_color Character. Hex colour for link styling.
#'
#' @return Character(1). HTML fragment with social links, or empty string.
#' @noRd
pg_cover_social_html <- function(orcid, linkedin, website, theme_color) {

  links <- character(0L)

  if (!is.null(orcid) && nchar(stringr::str_trim(orcid)) > 0L) {
    safe_orcid <- glue::glue_safe("{orcid}")
    orcid_url <- if (grepl("^https?://", orcid)) {
      safe_orcid
    } else {
      glue::glue_safe("https://orcid.org/{safe_orcid}")
    }
    links <- c(links, glue::glue_safe(
      '<a href="{orcid_url}" target="_blank">&#127891; ORCID</a>'
    ))
  }

  if (!is.null(linkedin) && nchar(stringr::str_trim(linkedin)) > 0L) {
    safe_linkedin <- glue::glue_safe("{linkedin}")
    links <- c(links, glue::glue_safe(
      '<a href="{safe_linkedin}" target="_blank">&#128101; LinkedIn</a>'
    ))
  }

  if (!is.null(website) && nchar(stringr::str_trim(website)) > 0L) {
    safe_website <- glue::glue_safe("{website}")
    links <- c(links, glue::glue_safe(
      '<a href="{safe_website}" target="_blank">&#127760; Web</a>'
    ))
  }

  if (length(links) == 0L) return("")

  links_joined <- paste(links, collapse = "\n    ")
  glue::glue_safe('<div class="pg-cover-social">\n    {links_joined}\n  </div>')
}


#' Build QR code HTML fragment from a website URL
#'
#' Uses [qrcode::qr_code()] to generate a QR code matrix, then renders it
#' to a temporary PNG file and embeds it as a base64 data URI.
#'
#' @param website Character or NULL. URL to encode.
#'
#' @return Character(1). HTML fragment with embedded QR code, or empty string.
#' @noRd
pg_cover_qr_html <- function(website) {

  if (is.null(website) || nchar(stringr::str_trim(website)) == 0L) {
    return("")
  }

  qr_b64 <- tryCatch({
    # Generate QR code matrix
    qr_mat <- qrcode::qr_code(website)

    # Render to temporary PNG
    tmp_png <- tempfile(fileext = ".png")
    grDevices::png(tmp_png, width = 200, height = 200, bg = "white")
    graphics::par(mar = c(0, 0, 0, 0))
    plot(qr_mat)
    grDevices::dev.off()

    # Read and encode as base64
    raw_bytes <- readBin(tmp_png, what = "raw", n = file.info(tmp_png)$size)
    b64 <- base64enc::base64encode(raw_bytes)

    # Clean up temp file
    tryCatch(unlink(tmp_png), error = function(e) NULL)

    paste0("data:image/png;base64,", b64)
  }, error = function(e) {
    pg_msg("warn",
           glue::glue("QR code non genere : {conditionMessage(e)}"),
           glue::glue("QR code not generated: {conditionMessage(e)}"))
    NULL
  })

  if (is.null(qr_b64)) return("")

  safe_b64 <- glue::glue_safe("{qr_b64}")
  glue::glue_safe('
  <div class="pg-cover-qr">
    <img src="{safe_b64}" alt="QR Code">
    <div class="pg-cover-qr-label">Scan to visit website</div>
  </div>')
}


#' Build the 3x2 stats grid HTML fragment
#'
#' @param stats Named list with numeric values for Articles, Books, Seminars,
#'   Theses, Awards, Projects.
#' @param theme_color Character. Hex colour for stat numbers.
#' @param lang Character. `"fr"` or `"en"`.
#'
#' @return Character(1). HTML fragment.
#' @noRd
pg_cover_stats_html <- function(stats, theme_color, lang) {

  # Define the stat cards with emoji icons and bilingual labels
  stat_defs <- if (lang == "fr") {
    list(
      list(key = "Articles",  icon = "&#128240;", label = "Articles"),
      list(key = "Books",     icon = "&#128218;", label = "Ouvrages"),
      list(key = "Seminars",  icon = "&#127891;", label = "Seminaires"),
      list(key = "Theses",    icon = "&#128221;", label = "Theses"),
      list(key = "Awards",    icon = "&#127942;", label = "Prix"),
      list(key = "Projects",  icon = "&#128188;", label = "Projets")
    )
  } else {
    list(
      list(key = "Articles",  icon = "&#128240;", label = "Articles"),
      list(key = "Books",     icon = "&#128218;", label = "Books"),
      list(key = "Seminars",  icon = "&#127891;", label = "Seminars"),
      list(key = "Theses",    icon = "&#128221;", label = "Theses"),
      list(key = "Awards",    icon = "&#127942;", label = "Awards"),
      list(key = "Projects",  icon = "&#128188;", label = "Projects")
    )
  }

  # Build individual stat card HTML fragments
  cards <- purrr::map_chr(stat_defs, function(s) {
    val <- as.integer(stats[[s$key]] %||% 0L)
    safe_icon  <- s$icon
    safe_val   <- as.character(val)
    safe_label <- glue::glue_safe("{s$label}")
    glue::glue_safe('
    <div class="pg-stat-card">
      <span class="pg-stat-icon">{safe_icon}</span>
      <span class="pg-stat-number">{safe_val}</span>
      <span class="pg-stat-label">{safe_label}</span>
    </div>')
  })

  cards_joined <- paste(cards, collapse = "\n")

  glue::glue_safe('
  <div class="pg-stats-grid">
    {cards_joined}
  </div>')
}
