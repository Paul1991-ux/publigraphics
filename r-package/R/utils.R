# ── utils.R ─────────────────────────────────────────────────────────────────────
# Internal utility functions for the publigraphics package.
# All helper functions are non-exported unless marked @export.
# ────────────────────────────────────────────────────────────────────────────────

#' Display a bilingual CLI message
#'
#' @param type Character. One of `"info"`, `"warn"`, `"error"`, `"success"`.
#' @param fr Character. Message in French.
#' @param en Character. Message in English.
#'
#' @return Invisible `NULL`. Called for its side effect.
#' @noRd
pg_msg <- function(type = c("info", "warn", "error", "success"), fr, en) {
  type <- match.arg(type)
  msg <- paste0(fr, " | ", en)
  switch(type,
    info    = cli::cli_alert_info(msg),
    warn    = cli::cli_alert_warning(msg),
    error   = cli::cli_alert_danger(msg),
    success = cli::cli_alert_success(msg)
  )
  invisible(NULL)
}

#' Validate a hexadecimal colour string
#'
#' @param hex Character. Colour string to validate.
#'
#' @return Logical. `TRUE` if valid `#RRGGBB` or `#RGB` format.
#' @noRd
pg_hex_valid <- function(hex) {
  grepl("^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$", hex)
}

#' Truncate a character string
#'
#' @param x Character vector.
#' @param n Integer. Maximum number of characters.
#' @param suffix Character. Suffix appended when truncated.
#'
#' @return Character vector.
#' @noRd
pg_truncate <- function(x, n = 45L, suffix = "...") {
  ifelse(
    nchar(x) > n,
    paste0(str_sub(x, 1L, n - nchar(suffix)), suffix),
    x
  )
}

#' Normalise BibTeX author strings into a character vector
#'
#' Splits combined author fields like `"Duflo, E. and Banerjee, A."` into
#' individual name strings.
#'
#' @param authors_raw Character(1). Raw author string from BibTeX.
#'
#' @return Character vector of individual author names.
#' @noRd
pg_clean_authors <- function(authors_raw) {
  if (is.na(authors_raw) || nchar(str_trim(authors_raw)) == 0L) {
    return(NA_character_)
  }
  authors_raw |>
    str_replace_all("\\s+and\\s+", " ; ") |>
    strsplit(" ; ", fixed = TRUE) |>
    unlist() |>
    str_trim()
}

#' PubliGraphics ggplot2 theme
#'
#' A publication-ready ggplot2 theme based on `theme_minimal()`. Uses the
#' Lato font family (loaded via `showtext` / `sysfonts`) with a clean white
#' background and light grey gridlines.
#'
#' @param base_size Numeric. Base font size in points (default 12).
#' @param base_color Character. Accent colour for titles (default `"#1B4F72"`).
#'
#' @return A `ggplot2::theme` object.
#'
#' @examples
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point() +
#'   pg_theme()
#'
#' @export
pg_theme <- function(base_size = 12, base_color = "#1B4F72") {
  # Register Lato font if available
  tryCatch({
    if (!"Lato" %in% sysfonts::font_families()) {
      sysfonts::font_add_google("Lato", "Lato")
    }
    showtext::showtext_auto()
    font_family <- "Lato"
  }, error = function(e) {
    font_family <- "sans"
  })

  font_family <- if ("Lato" %in% sysfonts::font_families()) "Lato" else "sans"


  ggplot2::theme_minimal(base_size = base_size, base_family = font_family) +
    ggplot2::theme(
      plot.title       = ggplot2::element_text(
        face = "bold", colour = base_color, size = base_size * 1.4,
        margin = ggplot2::margin(b = 8)
      ),
      plot.subtitle    = ggplot2::element_text(
        colour = "#555555", size = base_size * 1.05,
        margin = ggplot2::margin(b = 12)
      ),
      plot.caption     = ggplot2::element_text(
        colour = "#999999", size = base_size * 0.8, hjust = 1
      ),
      panel.grid.major = ggplot2::element_line(colour = "#EEEEEE", linewidth = 0.4),
      panel.grid.minor = ggplot2::element_blank(),
      axis.title       = ggplot2::element_text(colour = "#333333", face = "bold"),
      axis.text        = ggplot2::element_text(colour = "#555555"),
      legend.position  = "bottom",
      legend.title     = ggplot2::element_text(face = "bold", size = base_size * 0.9),
      plot.background  = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.margin      = ggplot2::margin(15, 15, 15, 15)
    )
}

#' Generate a colour palette from a base colour
#'
#' Produces `n` colours derived from a base colour using the `colorspace`
#' package. Supports sequential, diverging, and qualitative palettes.
#'
#' @param base_color Character. Base hex colour (default `"#1B4F72"`).
#' @param n Integer. Number of colours to generate (default 5).
#' @param type Character. Palette type: `"sequential"`, `"diverging"`,
#'   or `"qualitative"`.
#'
#' @return Character vector of `n` hex colour codes.
#'
#' @examples
#' pg_palette("#1B4F72", n = 4)
#' pg_palette("#E74C3C", n = 6, type = "qualitative")
#'
#' @export
pg_palette <- function(base_color = "#1B4F72", n = 5L,
                       type = c("sequential", "diverging", "qualitative")) {
  type <- match.arg(type)

  # Extract HCL components from base colour
  hcl_vals <- colorspace::hex2RGB(base_color) |>
    methods::as("polarLUV")
  base_hue <- hcl_vals@coords[1, "H"]

  switch(type,
    sequential = colorspace::sequential_hcl(
      n, h = base_hue, c = c(60, 20), l = c(30, 90), power = 1.2
    ),
    diverging = colorspace::diverging_hcl(
      n, h = c(base_hue, (base_hue + 180) %% 360), c = 80, l = c(40, 95)
    ),
    qualitative = colorspace::qualitative_hcl(
      n, h = base_hue + seq(0, 300, length.out = n), c = 70, l = 60
    )
  )
}
