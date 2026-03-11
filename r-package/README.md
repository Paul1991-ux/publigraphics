# publigraphics <img src="man/figures/logo.png" align="right" height="139" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/Paul1991-ux/publigraphics/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Paul1991-ux/publigraphics/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/publigraphics)](https://CRAN.R-project.org/package=publigraphics)
[![codecov](https://codecov.io/gh/Paul1991-ux/publigraphics/branch/main/graph/badge.svg)](https://codecov.io/gh/Paul1991-ux/publigraphics)
<!-- badges: end -->

An R package for social researchers to create publication-ready academic
portfolio notebooks from bibliographic data (BibTeX/RIS/CSV). Features
automatic classification into 12 production types, thematic word clouds,
co-authorship networks, geographic mapping, Gantt charts, AI narratives
via the Claude API, and premium HTML/PDF output. Bilingual FR/EN.

## Installation

```r
# Install from GitHub
# install.packages("remotes")
remotes::install_github("Paul1991-ux/publigraphics", subdir = "r-package")
```

## Quick example

```r
library(publigraphics)

bib <- pg_read_bib(pg_example("duflo_demo.bib"))
classified <- pg_classify(bib)

generate_publigraphics(
  data     = classified,
  author   = "Esther Duflo",
  output   = "portfolio.html",
  language = "en"
)
```

## Main functions

| Category | Functions |
|----------|-----------|
| Data import | `pg_read_bib()`, `pg_read_extra()`, `pg_merge_inputs()` |
| Classification | `pg_classify()`, `pg_summary_table()` |
| Articles | `pg_wordcloud_articles()`, `pg_timeline_articles()`, `pg_card_article()` |
| Seminars | `pg_map_seminars()`, `pg_network_seminars()` |
| Books | `pg_gallery_books()`, `pg_network_coauthors()`, `pg_wordcloud_books()` |
| Other | `pg_gantt_projects()`, `pg_timeline_theses()`, `pg_infographic_awards()`, `pg_map_expertise()`, `pg_media_summary()` |
| Overview | `pg_radar_productions()`, `pg_curve_timeline()`, `pg_stats_banner()` |
| AI narratives | `pg_run_all_narratives()`, `pg_check_api_key()` |
| Notebook | `generate_publigraphics()`, `pg_build_cover()` |
| Theming | `pg_theme()`, `pg_palette()` |

## Documentation

- [Getting started](https://paul1991-ux.github.io/publigraphics/articles/introduction.html)
- [Advanced customization](https://paul1991-ux.github.io/publigraphics/articles/advanced-customization.html)
- [Full reference](https://paul1991-ux.github.io/publigraphics/reference/index.html)

## License

MIT (c) 2025 Paul Wambo
