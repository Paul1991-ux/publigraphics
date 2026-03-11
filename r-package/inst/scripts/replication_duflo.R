#!/usr/bin/env Rscript
# =============================================================================
# replication_duflo.R — PubliGraphics v0.2.0 Replication Script
# =============================================================================
#
# Replicates the full PubliGraphics pipeline using Esther Duflo's public data
# (bundled in the package as demo data).
#
# Author: Paul Wambo <paulwambo2@gmail.com>
# ORCID:  0009-0005-6062-9227
# License: MIT
#
# Usage:
#   Rscript replication_duflo.R           # default output in tempdir()
#   Rscript replication_duflo.R ./output  # custom output directory
#
# Expected runtime: < 2 minutes on a modern machine.
# =============================================================================

set.seed(2024L)
suppressPackageStartupMessages({
  library(publigraphics)
  library(dplyr)
  library(cli)
})

# --- Parse output directory from command line ---------------------------------
args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args) >= 1) args[1] else file.path(tempdir(), "publigraphics_duflo")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

cli_h1("PubliGraphics v{packageVersion('publigraphics')} \u2014 Replication Script")
cli_alert_info("Researcher: Esther Duflo (MIT, Nobel 2019)")
cli_alert_info("Output directory: {output_dir}")

# =============================================================================
# STEP 1: Load bundled demo data
# =============================================================================
cli_h2("Step 1: Data Import")

bib_path   <- system.file("extdata", "duflo_articles.bib", package = "publigraphics")
extra_path <- system.file("extdata", "duflo_extra.csv",    package = "publigraphics")

stopifnot(
  "Demo BibTeX not found" = file.exists(bib_path),
  "Demo CSV not found"    = file.exists(extra_path)
)

bib_data   <- pg_read_bib(bib_path)
extra_data <- pg_read_extra(extra_path)
data       <- pg_merge_inputs(bib_data, extra_data)
cli_alert_success("Imported {nrow(data)} productions from BibTeX + CSV")

# =============================================================================
# STEP 2: Classify productions
# =============================================================================
cli_h2("Step 2: Classification")

classified <- pg_classify(data)
cli_alert_success("Classified {nrow(classified)} productions into {length(unique(classified$type_classified))} types")

# Print type distribution
type_counts <- classified |>
  count(type_classified, sort = TRUE)
for (i in seq_len(nrow(type_counts))) {
  cli_bullets(c("*" = "{type_counts$type_classified[i]}: {type_counts$n[i]}"))
}

# =============================================================================
# STEP 3: Summary table
# =============================================================================
cli_h2("Step 3: Summary Table")

summary_tbl <- pg_summary_table(classified)
print(summary_tbl)

# Save as CSV
summary_csv <- file.path(output_dir, "summary_table.csv")
utils::write.csv(summary_tbl, summary_csv, row.names = FALSE)
cli_alert_success("Summary table saved to {summary_csv}")

# =============================================================================
# STEP 4: Statistics banner
# =============================================================================
cli_h2("Step 4: Statistics Banner")

stats <- pg_stats_banner(classified)
cli_alert_info("Total productions: {stats$Total}")
cli_alert_info("Articles: {stats$Articles} | Books: {stats$Books}")
cli_alert_info("Seminars: {stats$Seminars} | Projects: {stats$Projects}")
cli_alert_info("Theses: {stats$Theses} | Awards: {stats$Awards}")
cli_alert_info("Career span: {stats$Career_span} years ({stats$First_year}\u2013{stats$Last_year})")

# =============================================================================
# STEP 5: Scientific Influence Index (SII)
# =============================================================================
cli_h2("Step 5: Scientific Influence Index")

sii_result <- pg_compute_sii(classified)

cli_alert_success("SII = {round(sii_result$sii, 1)}/100")

# Display dimension scores
dims <- sii_result$dimensions
for (i in seq_len(nrow(dims))) {
  d <- dims[i, ]
  bar <- paste(rep("\u2588", round(d$score / 5)), collapse = "")
  cli_alert_info("{d$dimension} ({d$label_en}): {round(d$score, 1)} {bar}")
}

# SII Card (HTML)
sii_card <- pg_sii_card(sii_result, lang = "en")
card_path <- file.path(output_dir, "sii_card.html")
writeLines(sii_card, card_path)
cli_alert_success("SII card saved to {card_path}")

# =============================================================================
# STEP 6: Visualizations
# =============================================================================
cli_h2("Step 6: Visualizations")

viz_dir <- file.path(output_dir, "figures")
dir.create(viz_dir, showWarnings = FALSE)

save_plot <- function(p, filename, width = 10, height = 7) {
  path <- file.path(viz_dir, filename)
  tryCatch({
    ggplot2::ggsave(path, p, width = width, height = height, dpi = 150, bg = "white")
    cli_alert_success("Saved {filename}")
  }, error = function(e) {
    cli_alert_warning("Failed to save {filename}: {conditionMessage(e)}")
  })
}

# 6a. Word cloud
tryCatch({
  wc <- pg_wordcloud_articles(classified)
  save_plot(wc, "wordcloud_articles.png", width = 8, height = 8)
}, error = function(e) cli_alert_warning("Word cloud: {conditionMessage(e)}"))

# 6b. Timeline
tryCatch({
  tl <- pg_timeline_articles(classified)
  save_plot(tl, "timeline_articles.png")
}, error = function(e) cli_alert_warning("Timeline: {conditionMessage(e)}"))

# 6c. Production radar
tryCatch({
  radar <- pg_radar_productions(classified)
  save_plot(radar, "radar_productions.png", width = 8, height = 8)
}, error = function(e) cli_alert_warning("Production radar: {conditionMessage(e)}"))

# 6d. Production curve
tryCatch({
  curve <- pg_curve_timeline(classified)
  save_plot(curve, "curve_productions.png")
}, error = function(e) cli_alert_warning("Production curve: {conditionMessage(e)}"))

# 6e. SII radar
tryCatch({
  sii_radar <- pg_sii_radar(sii_result, lang = "en")
  save_plot(sii_radar, "sii_radar.png", width = 8, height = 8)
}, error = function(e) cli_alert_warning("SII radar: {conditionMessage(e)}"))

# 6f. SII evolution
tryCatch({
  sii_evo <- pg_sii_evolution(sii_result, lang = "en")
  save_plot(sii_evo, "sii_evolution.png")
}, error = function(e) cli_alert_warning("SII evolution: {conditionMessage(e)}"))

# 6g. Article cards (HTML)
tryCatch({
  articles <- classified |> filter(type_classified == "article")
  if (nrow(articles) > 0) {
    top_articles <- articles |>
      arrange(desc(cited_by)) |>
      head(5)
    cards <- purrr::map_chr(seq_len(nrow(top_articles)), function(i) {
      pg_card_article(top_articles[i, ])
    })
    cards_html <- paste(
      "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Top Articles</title></head><body>",
      paste(cards, collapse = "\n"),
      "</body></html>"
    )
    writeLines(cards_html, file.path(output_dir, "top_articles.html"))
    cli_alert_success("Saved top_articles.html ({nrow(top_articles)} cards)")
  }
}, error = function(e) cli_alert_warning("Article cards: {conditionMessage(e)}"))

# =============================================================================
# STEP 7: Summary report
# =============================================================================
cli_h2("Step 7: Results Summary")

report <- list(
  package_version = as.character(packageVersion("publigraphics")),
  researcher      = "Esther Duflo",
  affiliation     = "Massachusetts Institute of Technology",
  total_items     = nrow(classified),
  types_found     = length(unique(classified$type_classified)),
  year_range      = paste(range(classified$year, na.rm = TRUE), collapse = "\u2013"),
  sii_score       = round(sii_result$sii, 1),
  sii_level       = dplyr::case_when(
    sii_result$sii >= 80 ~ "Exceptional",
    sii_result$sii >= 60 ~ "Very High",
    sii_result$sii >= 40 ~ "High",
    sii_result$sii >= 20 ~ "Moderate",
    TRUE                 ~ "Emerging"
  ),
  output_dir      = output_dir,
  timestamp       = Sys.time()
)

# Save report as JSON
report_json <- file.path(output_dir, "replication_report.json")
jsonlite::write_json(report, report_json, pretty = TRUE, auto_unbox = TRUE)
cli_alert_success("Report saved to {report_json}")

# =============================================================================
# Final summary
# =============================================================================
cli_h1("Replication Complete")
cli_alert_success("SII = {report$sii_score}/100 ({report$sii_level})")
cli_alert_success("{report$total_items} productions, {report$types_found} types, {report$year_range}")
cli_alert_info("All outputs in: {output_dir}")

# List generated files
files <- list.files(output_dir, recursive = TRUE)
cli_alert_info("{length(files)} files generated:")
for (f in files) {
  cli_bullets(c(" " = f))
}
