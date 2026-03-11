# publigraphics

<!-- badges: start -->
[![R-CMD-check](https://github.com/Paul1991-ux/publigraphics/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Paul1991-ux/publigraphics/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/publigraphics)](https://CRAN.R-project.org/package=publigraphics)
[![codecov](https://codecov.io/gh/Paul1991-ux/publigraphics/branch/main/graph/badge.svg)](https://codecov.io/gh/Paul1991-ux/publigraphics)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**Publication-ready academic portfolio notebooks from bibliographic data.**

`publigraphics` is a three-component project for social researchers:

| Component | Description |
|-----------|-------------|
| **R package** | Parse BibTeX/RIS/CSV, classify into 12 production types, generate word clouds (TF-IDF + LDA), co-authorship networks, geographic maps, Gantt charts, AI narratives (Claude API), and premium HTML/PDF notebooks. Bilingual FR/EN. |
| **MCP Server** | Model Context Protocol server for integration with AI assistants. |
| **JSS Article** | Companion paper submitted to the *Journal of Statistical Software*. |

**Author:** Paul Wambo -- Universite de Dschang
([ORCID: 0009-0005-6062-9227](https://orcid.org/0009-0005-6062-9227))

## Installation

```r
# Install from GitHub
# install.packages("remotes")
remotes::install_github("Paul1991-ux/publigraphics", subdir = "r-package")
```

## Quick example

```r
library(publigraphics)

# Load demo data (Esther Duflo bibliography)
bib <- pg_read_bib(pg_example("duflo_demo.bib"))

# Classify productions into 12 types
classified <- pg_classify(bib)

# Generate the full portfolio notebook
generate_publigraphics(
  data      = classified,
  author    = "Esther Duflo",
  output    = "portfolio.html",
  language  = "en"
)
```

## Main features

- **Data import** -- BibTeX, RIS, and CSV parsing with automatic field mapping
- **Classification** -- 12 academic production types (articles, books, chapters, theses, seminars, projects, awards, expertise, media, etc.)
- **Thematic analysis** -- TF-IDF word clouds and LDA topic modelling
- **Co-authorship networks** -- Interactive network graphs
- **Geographic mapping** -- Conference and expertise locations on world maps
- **Timeline & Gantt** -- Publication timelines and project Gantt charts
- **AI narratives** -- Automatic section narratives via the Claude API
- **Premium notebooks** -- Styled HTML and PDF output with cover page
- **Bilingual** -- Full French/English interface

## Documentation

- [Getting started vignette](https://paul1991-ux.github.io/publigraphics/articles/introduction.html)
- [Advanced customization](https://paul1991-ux.github.io/publigraphics/articles/advanced-customization.html)
- [Function reference](https://paul1991-ux.github.io/publigraphics/reference/index.html)
- [pkgdown site](https://paul1991-ux.github.io/publigraphics/)

## Demo data

The package ships with a curated subset of Esther Duflo's bibliography for
demonstration and testing purposes.

## License

MIT (c) 2025 Paul Wambo
