# =========================================================================
# PubliGraphics — Theme Helper for Notebook Templates
# Wrapper around pg_theme() with notebook-specific defaults
# =========================================================================

#' Initialise the PubliGraphics ggplot2 theme for notebook rendering
#'
#' This script is sourced automatically inside the RMarkdown template.
#' It configures \code{pg_theme()} with appropriate defaults for the
#' notebook context (HTML or paged output) and exposes a settings list
#' that other chunks can use.
#'
#' @param theme_color Primary colour (hex string) forwarded to pg_theme().
#' @param base_size   Base font size in points (default 12).
#' @param font_family Font family (default "Lato").
#' @return Invisibly, a list of resolved theme settings.

pg_notebook_theme <- function(theme_color = "#1B4F72",
                              base_size   = 12,
                              font_family = "Lato") {

  # --- Attempt to load the package theme function ---------------------------
  if (requireNamespace("publigraphics", quietly = TRUE)) {
    theme_fn <- publigraphics::pg_theme
  } else {
    # Fallback: look for the function in the current search path
    if (exists("pg_theme", mode = "function")) {
      theme_fn <- get("pg_theme", mode = "function")
    } else {
      # Minimal fallback theme if pg_theme is unavailable
      theme_fn <- function(base_size = 12,
                           base_family = "Lato",
                           theme_color = "#1B4F72",
                           ...) {
        ggplot2::theme_minimal(
          base_size   = base_size,
          base_family = base_family
        ) +
          ggplot2::theme(
            plot.title      = ggplot2::element_text(
              face = "bold", size = base_size * 1.3, colour = theme_color
            ),
            plot.subtitle   = ggplot2::element_text(
              size = base_size * 0.95, colour = "#5d6d7e"
            ),
            panel.grid.minor = ggplot2::element_blank(),
            legend.position  = "bottom",
            ...
          )
      }
    }
  }

  # --- Set as default ggplot2 theme -----------------------------------------
  default_theme <- theme_fn(
    base_size    = base_size,
    base_family  = font_family,
    theme_color  = theme_color
  )
  ggplot2::theme_set(default_theme)

  # --- Configure default ggplot2 colour / fill scales -----------------------
  pg_palette <- c(
    theme_color,
    "#2ecc71", "#e74c3c", "#f39c12", "#9b59b6",
    "#1abc9c", "#e67e22", "#3498db", "#c0392b"
  )

  options(
    ggplot2.discrete.colour = pg_palette,
    ggplot2.discrete.fill   = pg_palette,
    ggplot2.continuous.colour = function(...) {
      ggplot2::scale_colour_gradient(
        low = "#d4e6f1", high = theme_color, ...
      )
    },
    ggplot2.continuous.fill = function(...) {
      ggplot2::scale_fill_gradient(
        low = "#d4e6f1", high = theme_color, ...
      )
    }
  )

  # --- Build and return settings list ---------------------------------------
  settings <- list(
    theme_color  = theme_color,
    base_size    = base_size,
    font_family  = font_family,
    palette      = pg_palette,
    theme_object = default_theme,
    fig_width    = 9,
    fig_height   = 6,
    dpi          = 150
  )

  invisible(settings)
}

# --- Auto-initialise when sourced inside the notebook -----------------------
# The template passes params$theme_color via a setup chunk.
if (exists("params", envir = parent.frame(), inherits = FALSE)) {
  pg_env <- parent.frame()
  tc <- tryCatch(
    get("params", envir = pg_env)$theme_color,
    error = function(e) "#1B4F72"
  )
  pg_settings <- pg_notebook_theme(theme_color = tc)
} else {
  # Interactive / standalone usage — use default colour
  pg_settings <- pg_notebook_theme()
}
