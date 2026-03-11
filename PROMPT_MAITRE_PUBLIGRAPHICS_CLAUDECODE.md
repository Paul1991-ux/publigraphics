# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║         PROMPT MAÎTRE — PubliGraphics for Social Researchers               ║
# ║         Version Définitive Ultra-Optimisée pour Claude Code                ║
# ║         Architecture : Package R + Serveur MCP + Article JSS               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# DESTINATAIRE   : Claude Code (exécution autonome complète, de A à Z)
# AUTEUR         : [Votre nom] — à remplacer partout où indiqué [AUTHOR_NAME]
# CHERCHEUR DEMO : Esther Duflo (données publiques réelles, MIT / Nobel 2019)
# REVUE CIBLE    : Journal of Statistical Software (JSS) — IF 13.6, CC BY
# LANGUE         : Bilingue strict FR / EN (code EN, messages FR+EN, article EN)
# DATE           : 2025
# ─────────────────────────────────────────────────────────────────────────────

---

## §0. RÈGLES ABSOLUES POUR CLAUDE CODE

Avant toute chose, tu dois respecter ces règles sans exception :

1. **LIRE avant d'écrire** : avant chaque phase, relis les specs de cette phase.
2. **VÉRIFIER avant de passer** : chaque phase se termine par une checklist
   d'assertions. Ne passe à la phase suivante que si 100 % des cases sont cochées.
3. **COMMENTER tout** : chaque fichier R commence par un bloc roxygen2 complet.
   Chaque fichier TypeScript commence par un bloc JSDoc complet. Chaque section
   non triviale est commentée inline. L'utilisateur est débutant — il doit
   comprendre le code en le lisant.
4. **JAMAIS de crash silencieux** : toute fonction R utilise `tryCatch()` avec
   messages bilingues FR/EN via `cli::`. Toute fonction TS utilise `try/catch`
   avec messages explicites.
5. **REPRODUCTIBILITÉ** : `set.seed(2024L)` dans tous les exemples et tests.
6. **SÉCURITÉ** : les clés API ne transitent jamais dans des logs, stdout de
   production, fichiers temporaires non supprimés, ou outputs générés.
7. **STYLE R** : tidyverse strict — pipe natif `|>`, `TRUE`/`FALSE` jamais
   `T`/`F`, jamais `:::`, snake_case pour tout.
8. **STYLE TS** : ESM modules, `async/await`, typage strict TypeScript 5.x,
   pas de `any` sauf justification explicite en commentaire.
9. **BILINGUE** : tous les messages utilisateur (CLI, warnings, README, labels
   de visualisations) sont en FR et EN séparés par ` | `. Ex :
   `"Fichier introuvable | File not found"`.
10. **DESIGN PREMIUM** : les notebooks générés doivent être dignes d'une
    publication académique imprimée. Chaque visualisation doit être testée
    visuellement avant de passer à la suivante.

---

## §1. VISION GLOBALE ET POSITIONNEMENT SCIENTIFIQUE

### 1.1 Problème résolu

Il n'existe aucun outil permettant à un chercheur en sciences humaines et
sociales (SHS) de générer automatiquement une **vitrine visuelle, narrative
et imprimable** de l'intégralité de sa trajectoire scientifique.

Les outils existants couvrent des besoins partiels :
- `scholar` (Ackles 2023) : scraping Google Scholar, aucune visualisation narrative
- `bibliometrix` (Aria & Cuccurullo 2017) : analyse de corpus multi-auteurs
- `rorcid` (Chamberlain 2020) : accès à l'API ORCID, pas de génération de document
- `vitae` (O'Brien 2023) : CV académique textuel, pas de visualisation infographique

**PubliGraphics** comble ce vide : pipeline `BibTeX → classification → visualisation
IA → notebook PDF/HTML`, conçu spécifiquement pour l'auto-valorisation
individuelle du chercheur SHS.

### 1.2 Architecture de l'écosystème

```
┌─────────────────────────────────────────────────────────────────┐
│                    ÉCOSYSTÈME PUBLIGRAPHICS                     │
│                                                                  │
│  ┌──────────────────────┐    expose    ┌────────────────────┐   │
│  │  Package R           │◄────────────►│  Serveur MCP       │   │
│  │  `publigraphics`     │  7 outils    │  `publigraphics-   │   │
│  │  (moteur de calcul)  │              │   mcp`             │   │
│  │  → CRAN + JSS        │              │  → Claude Desktop  │   │
│  └──────────┬───────────┘              └────────┬───────────┘   │
│             │ génère                            │ dialogue       │
│             ▼                                   ▼               │
│  ┌──────────────────────┐              ┌────────────────────┐   │
│  │  PubliGraphics       │              │  Utilisateur       │   │
│  │  Notebook            │              │  (langage naturel) │   │
│  │  PDF + HTML          │◄─────────────│  "Génère mon       │   │
│  │  (output final)      │              │   notebook"        │   │
│  └──────────────────────┘              └────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Structure du dépôt GitHub (CRÉER EXACTEMENT CETTE STRUCTURE)

```
publigraphics/                          ← racine dépôt GitHub
│
├── README.md                           ← présentation bilingue FR/EN des 2 composants
├── LICENSE                             ← MIT
├── .gitignore                          ← R + Node + OS patterns
├── CONTRIBUTING.md                     ← guide de contribution bilingue
├── CODE_OF_CONDUCT.md                  ← Contributor Covenant
│
├── .github/
│   ├── workflows/
│   │   ├── R-CMD-check.yaml            ← CI package R (3 OS × release)
│   │   ├── mcp-build-test.yaml         ← CI serveur MCP (Node 18, 20)
│   │   └── pkgdown-deploy.yaml         ← déploiement doc GitHub Pages
│   └── ISSUE_TEMPLATE/
│       ├── bug_report.md
│       └── feature_request.md
│
├── r-package/                          ← COMPOSANT 1 : Package R
│   ├── DESCRIPTION
│   ├── NAMESPACE                       ← auto-généré par roxygen2
│   ├── NEWS.md
│   ├── README.md
│   ├── pkgdown/
│   │   └── _pkgdown.yml
│   ├── R/
│   │   ├── publigraphics-package.R     ← @docType package + importFrom globaux
│   │   ├── parse_inputs.R
│   │   ├── classify_outputs.R
│   │   ├── viz_articles.R
│   │   ├── viz_seminars.R
│   │   ├── viz_books.R
│   │   ├── viz_other.R
│   │   ├── viz_global.R
│   │   ├── llm_narratives.R
│   │   ├── cover_page.R
│   │   ├── generate_notebook.R
│   │   └── utils.R
│   ├── inst/
│   │   ├── templates/
│   │   │   ├── publigraphics_notebook.Rmd
│   │   │   ├── publigraphics_base.css
│   │   │   ├── publigraphics_print.css
│   │   │   └── publigraphics_theme.R   ← ggplot2 theme function
│   │   └── extdata/
│   │       ├── duflo_articles.bib      ← données démo Esther Duflo (réelles)
│   │       ├── duflo_books.bib         ← livres Duflo (réels)
│   │       └── duflo_extra.csv         ← séminaires/projets/prix Duflo
│   ├── man/                            ← auto-généré par devtools::document()
│   ├── tests/
│   │   └── testthat/
│   │       ├── helper-fixtures.R       ← données de test partagées
│   │       ├── test-parse_inputs.R
│   │       ├── test-classify_outputs.R
│   │       ├── test-viz_articles.R
│   │       ├── test-viz_global.R
│   │       └── test-generate_notebook.R
│   └── vignettes/
│       ├── introduction.Rmd            ← vignette principale (sera aussi soumise à JSS)
│       └── advanced_customization.Rmd
│
├── mcp-server/                         ← COMPOSANT 2 : Serveur MCP
│   ├── package.json
│   ├── package-lock.json
│   ├── tsconfig.json
│   ├── README.md                       ← guide installation Claude Desktop
│   ├── INSTALL.md                      ← pas-à-pas pour non-développeurs
│   ├── src/
│   │   ├── index.ts                    ← point d'entrée MCP (McpServer)
│   │   ├── server.ts                   ← configuration et démarrage
│   │   ├── tools/
│   │   │   ├── index.ts                ← export de tous les outils
│   │   │   ├── parse_bib.ts            ← outil 1
│   │   │   ├── preview_stats.ts        ← outil 2
│   │   │   ├── list_productions.ts     ← outil 3
│   │   │   ├── generate_narrative.ts   ← outil 4
│   │   │   ├── generate_notebook.ts    ← outil 5 (principal)
│   │   │   ├── validate_bib.ts         ← outil 6
│   │   │   └── open_output.ts          ← outil 7
│   │   ├── r_bridge/
│   │   │   ├── r_executor.ts           ← classe RExecutor (Node → R)
│   │   │   ├── r_detector.ts           ← détection chemin Rscript multi-OS
│   │   │   └── scripts/
│   │   │       ├── bridge_parse.R
│   │   │       ├── bridge_stats.R
│   │   │       ├── bridge_list.R
│   │   │       ├── bridge_narrative.R
│   │   │       ├── bridge_generate.R
│   │   │       └── bridge_validate.R
│   │   ├── types/
│   │   │   ├── tool_inputs.ts          ← schemas Zod de tous les inputs
│   │   │   └── tool_outputs.ts         ← types TypeScript des outputs
│   │   └── utils/
│   │       ├── file_validator.ts
│   │       ├── error_handler.ts
│   │       └── logger.ts               ← logger structuré (pas de secrets)
│   ├── dist/                           ← auto-généré : ne pas modifier
│   └── config/
│       ├── claude_desktop_example.json ← template config Claude Desktop
│       └── QUICKSTART.md               ← guide 5 minutes pour démarrer
│
└── article-jss/                        ← COMPOSANT 3 : Article JSS
    ├── publigraphics.Rnw               ← article principal (LaTeX/Sweave JSS)
    ├── publigraphics.bib               ← bibliographie de l'article
    ├── replication_script.R            ← script de réplication standalone
    ├── figures/                        ← figures pré-générées pour l'article
    └── jss_submission_checklist.md     ← checklist soumission JSS
```

---

## §2. COMPOSANT 1 — PACKAGE R `publigraphics`

### 2.1 DESCRIPTION — fichier complet à créer

```
Package: publigraphics
Title: Visual and Narrative Profiling of Researchers' Scientific Output
Version: 0.1.0
Authors@R:
    person(
      given  = "[AUTHOR_FIRSTNAME]",
      family = "[AUTHOR_LASTNAME]",
      email  = "[AUTHOR_EMAIL]",
      role   = c("aut", "cre"),
      comment = c(ORCID = "[AUTHOR_ORCID]")
    )
Description:
    Generates visually impactful, multi-format notebooks (PDF and HTML)
    summarising the complete scientific trajectory of a researcher in the social
    sciences. Accepts BibTeX/RIS input files (Zotero, Mendeley exports) and an
    optional CSV file for non-bibliographic outputs (seminars, funded projects,
    supervised theses, awards). Produces thematic word clouds with TF-IDF
    weighting and LDA topic modelling, geographic maps of seminar interventions,
    co-authorship networks, Gantt charts of funded projects, and AI-generated
    narrative summaries via the Anthropic Claude API. Designed for individual
    researchers who wish to document, visualise, and communicate their academic
    output through a single reproducible command. The MCP companion server
    'publigraphics-mcp' (distributed separately via npm) enables conversational
    generation of notebooks through Claude Desktop.
License: MIT + file LICENSE
Encoding: UTF-8
LazyData: false
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.3.2
Language: en-GB
Depends:
    R (>= 4.3.0)
Imports:
    bib2df       (>= 1.1.1),
    RefManageR   (>= 1.4.0),
    tidytext     (>= 0.4.1),
    topicmodels  (>= 0.2.14),
    ggwordcloud  (>= 0.6.0),
    wordcloud2   (>= 0.2.1),
    ggplot2      (>= 3.5.0),
    ggalt        (>= 0.4.0),
    ggraph       (>= 2.2.0),
    ggtext       (>= 0.1.2),
    tidygraph    (>= 1.3.0),
    igraph       (>= 2.0.0),
    leaflet      (>= 2.2.0),
    leaflet.extras (>= 1.0.0),
    sf           (>= 1.0.15),
    rnaturalearth      (>= 1.0.1),
    rnaturalearthdata  (>= 1.0.0),
    tidygeocoder (>= 1.0.5),
    httr2        (>= 1.0.0),
    jsonlite     (>= 1.8.8),
    rmarkdown    (>= 2.27),
    pagedown     (>= 0.21),
    knitr        (>= 1.47),
    kableExtra   (>= 1.4.0),
    dplyr        (>= 1.1.4),
    tidyr        (>= 1.3.1),
    stringr      (>= 1.5.1),
    lubridate    (>= 1.9.3),
    glue         (>= 1.7.0),
    cli          (>= 3.6.3),
    fs           (>= 1.6.4),
    scales       (>= 1.3.0),
    patchwork    (>= 1.2.0),
    htmlwidgets  (>= 1.6.4),
    htmltools    (>= 0.5.8),
    webshot2     (>= 0.1.0),
    qrcode       (>= 0.2.2),
    purrr        (>= 1.0.2),
    readr        (>= 2.1.5),
    tibble       (>= 3.2.1),
    forcats      (>= 1.0.0),
    viridis      (>= 0.6.5),
    colorspace   (>= 2.1.0),
    showtext     (>= 0.9.7),
    sysfonts     (>= 0.8.9)
Suggests:
    testthat     (>= 3.2.0),
    covr,
    spelling,
    pkgdown,
    withr
Config/testthat/edition: 3
VignetteBuilder: knitr
URL: https://github.com/[GITHUB_USERNAME]/publigraphics,
     https://[GITHUB_USERNAME].github.io/publigraphics
BugReports: https://github.com/[GITHUB_USERNAME]/publigraphics/issues
```

### 2.2 publigraphics-package.R — Fichier d'en-tête du package

```r
#' @keywords internal
#' @aliases publigraphics-package
"_PACKAGE"

## usethis namespace: start
#' @importFrom dplyr filter mutate select arrange group_by summarise
#'   left_join bind_rows distinct n rename pull slice_head
#' @importFrom tibble tibble as_tibble
#' @importFrom stringr str_detect str_trim str_to_lower str_extract
#'   str_replace_all str_sub str_c str_wrap
#' @importFrom rlang .data
## usethis namespace: end
NULL
```

### 2.3 utils.R — Fonctions utilitaires partagées

Implémenter avec roxygen2 complet :

```r
# ── pg_msg() ──────────────────────────────────────────────────────────────────
# Affiche un message CLI bilingue FR / EN selon l'option pg.lang
# Utilise cli::cli_inform() pour les infos, cli::cli_warn() pour les warnings
# Usage interne uniquement — non exportée
#
# pg_msg(type = c("info","warn","error","success"),
#        fr = "Message en français",
#        en = "Message in English")

# ── pg_hex_valid() ────────────────────────────────────────────────────────────
# Valide une couleur hexadécimale (#RRGGBB ou #RGB)
# Retourne TRUE/FALSE — non exportée

# ── pg_truncate() ─────────────────────────────────────────────────────────────
# Tronque une chaîne à n caractères avec "..." — non exportée

# ── pg_clean_authors() ────────────────────────────────────────────────────────
# Normalise les noms d'auteurs BibTeX ("Duflo, E. and Banerjee, A." → vecteur)
# Retourne un character vector — non exportée

# ── pg_theme() ────────────────────────────────────────────────────────────────
# Thème ggplot2 maison de PubliGraphics
# Basé sur theme_minimal() avec :
#   - Police "Lato" via showtext/sysfonts
#   - Fond blanc pur, grille légère grise #EEEEEE
#   - Titres en Lato Bold, corps en Lato Regular
#   - Paramètre base_color pour colorier les accents
# EXPORTÉE — @export

# ── pg_palette() ──────────────────────────────────────────────────────────────
# Génère une palette de n couleurs à partir d'une couleur principale
# Utilise colorspace::sequential_hcl() et colorspace::qualitative_hcl()
# Paramètre type = c("sequential", "diverging", "qualitative")
# EXPORTÉE — @export
```

### 2.4 parse_inputs.R — Parsing BibTeX / RIS / CSV

```r
# Implémenter les 3 fonctions suivantes avec code complet et tests unitaires.
# SCHÉMA DE DONNÉES STANDARDISÉ (tibble retourné par toutes les fonctions) :
#
# Colonne          | Type      | Description
# ─────────────────────────────────────────────────────────────
# pg_id            | chr       | identifiant unique (BibTeX key ou uuid)
# type_raw         | chr       | type BibTeX brut (@article, @book, etc.)
# type_classified  | chr       | l'un des 12 types internes (§2.5)
# title            | chr       | titre complet
# authors          | list<chr> | vecteur de noms normalisés
# year             | int       | année de publication
# journal_or_venue | chr       | revue, éditeur, ou lieu de conférence
# abstract         | chr       | résumé complet (NA si absent)
# keywords         | list<chr> | mots-clés (NA si absent)
# doi              | chr       | DOI (NA si absent)
# url              | chr       | URL (NA si absent)
# isbn             | chr       | ISBN pour livres (NA si absent)
# city             | chr       | ville (pour séminaires et expertises)
# country          | chr       | pays
# institution      | chr       | institution organisatrice ou affiliée
# note             | chr       | notes libres
# cited_by         | int       | nombre de citations (NA si inconnu)
# source           | chr       | "bib" | "extra"
# date_added       | Date      | date d'import (today() par défaut)

#' Read a BibTeX, RIS, or CSV file of scientific productions
#'
#' @description
#' `pg_read_bib()` est la fonction d'entrée principale de PubliGraphics.
#' Elle accepte les formats `.bib`, `.ris`, `.csv`, et `.xlsx`, détecte
#' automatiquement le format, et retourne un tibble dans le schéma standardisé
#' PubliGraphics (voir §2.4).
#'
#' `pg_read_bib()` is the main entry function of PubliGraphics. It accepts
#' `.bib`, `.ris`, `.csv`, and `.xlsx` formats, auto-detects the format,
#' and returns a tibble in the standardised PubliGraphics schema (see §2.4).
#'
#' @param path `character(1)` Chemin absolu ou relatif vers le fichier.
#'   Absolute or relative path to the input file.
#' @param format `character(1)` Format du fichier : `"auto"` (défaut),
#'   `"bib"`, `"ris"`, `"csv"`, ou `"xlsx"`.
#'   File format: `"auto"` (default), `"bib"`, `"ris"`, `"csv"`, or `"xlsx"`.
#' @param encoding `character(1)` Encodage du fichier (défaut `"UTF-8"`).
#'
#' @return Un [tibble::tibble()] avec les colonnes du schéma standardisé.
#'   A [tibble::tibble()] with columns from the standardised schema.
#'
#' @details
#' Les champs manquants sont remplacés par `NA` avec un avertissement
#' informatif. Le parsing BibTeX utilise [bib2df::bib2df()]. Le parsing RIS
#' utilise [RefManageR::ReadBib()]. Les CSV sont lus avec [readr::read_csv()].
#'
#' Missing fields are replaced by `NA` with an informative warning.
#'
#' @examples
#' \dontrun{
#' # Fichier fourni avec le package | File bundled with the package
#' bib_path <- system.file("extdata", "duflo_articles.bib",
#'                         package = "publigraphics")
#' data <- pg_read_bib(bib_path)
#' print(data)
#' }
#'
#' @seealso [pg_read_extra()], [pg_merge_inputs()], [pg_classify()]
#' @export
pg_read_bib <- function(path, format = "auto", encoding = "UTF-8") { ... }

#' Read the supplementary CSV file for non-BibTeX productions
#' @export
pg_read_extra <- function(path, encoding = "UTF-8") { ... }

#' Merge and deduplicate BibTeX and supplementary data
#' @export
pg_merge_inputs <- function(bib_data, extra_data = NULL) { ... }
```

### 2.5 classify_outputs.R — Classification en 12 types canoniques

```r
# TABLE DE MAPPING COMPLÈTE (à implémenter dans pg_classify()) :
#
# Type canonique      | Codes BibTeX reconnus              | Champs discriminants
# ────────────────────────────────────────────────────────────────────────────
# "article"           | @article                           | —
# "book"              | @book                              | auteur principal
# "book_chapter"      | @incollection, @inbook             | —
# "seminar"           | @inproceedings, @conference        | type="seminar" OU
#                     |                                    | venue contient "seminar"
# "conference"        | @inproceedings, @conference        | (autres cas)
# "report"            | @techreport, @report               | —
# "thesis_supervised" | @phdthesis, @mastersthesis          | role="supervisor"
# "patent"            | @patent, @misc                     | type="patent"
# "media"             | @misc                              | type="media"|"podcast"|
#                     |                                    |      "interview"
# "project"           | @misc, entrée CSV                  | type="project"|"grant"
# "award"             | @misc, entrée CSV                  | type="award"|"prize"
# "expertise"         | @misc, entrée CSV                  | type="expertise"|
#                     |                                    |      "consulting"
# "other"             | tout le reste                      | warning généré

#' Classify scientific productions into 12 canonical types
#'
#' @description
#' `pg_classify()` enrichit le tibble retourné par [pg_read_bib()] en
#' affectant à chaque entrée l'un des 12 types canoniques de PubliGraphics.
#' La classification utilise le type BibTeX brut et des champs discriminants.
#'
#' @param data Tibble retourné par [pg_merge_inputs()].
#' @return Le même tibble avec la colonne `type_classified` complétée.
#' @export
pg_classify <- function(data) { ... }

#' Compute a summary table of productions by type
#' @export
pg_summary_table <- function(data) {
  # Retourne tibble : type_classified, label_fr, label_en, n,
  #                   first_year, last_year, pct_total
  # Trié par n décroissant
}
```

### 2.6 viz_articles.R — Visualisations articles

**Implémenter ces 4 fonctions avec code R complet et opérationnel :**

```r
#' Weighted thematic word cloud of articles
#'
#' @description
#' Génère un nuage de mots pondéré TF-IDF sur le corpus des articles, avec
#' colorisation par topic LDA. Retourne deux objets : un widget HTML interactif
#' ([wordcloud2::wordcloud2()]) ET un ggplot statique haute résolution pour PDF.
#'
#' Generates a TF-IDF weighted word cloud of articles, coloured by LDA topic.
#' Returns both an interactive HTML widget and a high-resolution static ggplot.
#'
#' @param data Tibble [pg_classify()].
#' @param n_topics `integer(1)` Nombre de topics LDA (défaut 4).
#' @param lang `character(1)` Langue des stopwords : `"fr"`, `"en"`, ou `"both"`.
#' @param theme_color `character(1)` Couleur principale hexadécimale.
#' @param max_words `integer(1)` Nombre maximum de mots (défaut 80).
#'
#' @return `list` avec éléments `$widget` (htmlwidget) et `$plot` (ggplot).
#' @export
pg_wordcloud_articles <- function(data, n_topics = 4L, lang = "both",
                                   theme_color = "#1B4F72", max_words = 80L) {
  # 1. Filtrer type_classified == "article"
  # 2. Créer corpus : paste(title, abstract, keywords)
  # 3. tokeniser avec tidytext::unnest_tokens()
  # 4. Supprimer stopwords FR (stopwords::stopwords("fr")) + EN + chiffres
  # 5. Calculer TF-IDF par document (article) avec tidytext::bind_tf_idf()
  # 6. Agréger : pour chaque mot, TF-IDF moyen sur tout le corpus
  # 7. LDA avec topicmodels::LDA(k = n_topics, control = list(seed = 2024L))
  # 8. Assigner chaque mot au topic dominant (beta max)
  # 9. Palette de couleurs : n_topics couleurs depuis pg_palette(theme_color)
  # 10. wordcloud2::wordcloud2() : size = TF-IDF normalisé, color = topic
  # 11. ggwordcloud::ggwordcloud() : version ggplot pour PDF
  #     avec aes(label=word, size=tf_idf, color=topic)
  # 12. Appliquer pg_theme() au ggplot
  # 13. Retourner list(widget = ..., plot = ...)
}

#' Chronological timeline of articles
#'
#' @description
#' Frise chronologique horizontale des articles. Chaque point représente
#' un article, coloré par revue ou par topic LDA.
#'
#' @param data Tibble [pg_classify()].
#' @param color_by `character(1)` `"journal"` ou `"topic"`.
#' @param theme_color `character(1)` Couleur principale.
#'
#' @return `ggplot` object.
#' @export
pg_timeline_articles <- function(data, color_by = "journal",
                                  theme_color = "#1B4F72") {
  # 1. Filtrer articles, compter rang dans l'année (jitter vertical)
  # 2. Tronquer titres à 45 caractères avec pg_truncate()
  # 3. ggplot aes(x = year, y = rank_in_year)
  # 4. geom_point(aes(color = journal_or_topic), size = 3, alpha = 0.8)
  # 5. geom_text(aes(label = title_short), size = 2.5, hjust = 0, nudge_x = 0.1)
  # 6. geom_vline(xintercept = as.numeric(format(Sys.Date(), "%Y")),
  #               linetype = "dashed", color = "grey60")
  # 7. scale_color_viridis_d() ou pg_palette() selon le nombre de catégories
  # 8. Appliquer pg_theme()
  # 9. labs bilingues FR/EN
}

#' Generate AI narrative summary for one article
#'
#' @description
#' Appelle l'API Anthropic Claude pour générer un résumé structuré en 4 champs
#' pour un article donné (problématique, pertinence, résultat, question ouverte).
#'
#' Calls the Anthropic Claude API to generate a 4-field structured summary
#' for a given article.
#'
#' @param article_row `tibble` 1 ligne — une entrée du tibble standardisé.
#' @param api_key `character(1)` Clé API Anthropic.
#' @param lang `character(1)` Langue de la réponse : `"fr"` ou `"en"`.
#'
#' @return `tibble` 1 ligne avec colonnes :
#'   `problematique`, `pertinence`, `resultat`, `question_ouverte`,
#'   `narrative_lang`, `narrative_model`, `narrative_timestamp`.
#'   Retourne NA dans tous les champs si API indisponible (fallback gracieux).
#' @export
pg_narrative_article <- function(article_row, api_key, lang = "fr") {
  # PROMPT SYSTÈME À UTILISER VERBATIM :
  system_prompt <- paste0(
    "You are an expert academic summarizer specialised in social science ",
    "research. Given a title and abstract, return ONLY a valid JSON object ",
    "with exactly these four keys (no other text, no markdown fences):\n",
    "{\n",
    "  \"problematique\": \"1 sentence — the central research question\",\n",
    "  \"pertinence\": \"1 sentence — the empirical or theoretical relevance\",\n",
    "  \"resultat\": \"1 sentence — the main finding or contribution\",\n",
    "  \"question_ouverte\": \"1 sentence — an open question raised by this work\"\n",
    "}\n",
    "Write the response in ", if (lang == "fr") "French" else "English", ".\n",
    "Each value must be exactly 1 sentence, maximum 30 words.\n",
    "Return ONLY the JSON object, nothing else."
  )
  # Appel httr2 vers https://api.anthropic.com/v1/messages
  # Modèle : "claude-sonnet-4-20250514"
  # max_tokens : 400
  # Headers : "x-api-key", "anthropic-version": "2023-06-01"
  # tryCatch : si erreur → retourner tibble avec NA + warning bilingue
  # Parser jsonlite::fromJSON() sur la réponse
  # Valider que les 4 clés sont présentes
  # Retourner tibble 1 ligne avec les 4 champs + métadonnées
}

#' Build a styled HTML card for one article
#'
#' @description
#' Génère une fiche HTML premium pour un article avec ses métadonnées et
#' son résumé narratif IA. Utilisée dans le template Rmd du notebook.
#'
#' @param article_row `tibble` 1 ligne.
#' @param narrative `tibble` 1 ligne retournée par [pg_narrative_article()].
#' @param theme_color `character(1)` Couleur principale.
#' @param lang `character(1)` Langue d'affichage des labels.
#'
#' @return `character(1)` — chaîne HTML brute prête à être insérée dans Rmd.
#' @export
pg_card_article <- function(article_row, narrative, theme_color = "#1B4F72",
                             lang = "fr") {
  # Générer HTML avec structure :
  # <div class="pg-article-card" style="border-left: 4px solid {theme_color}">
  #   <div class="pg-card-header">
  #     <span class="pg-badge pg-badge-article">Article</span>
  #     <span class="pg-year">{year}</span>
  #   </div>
  #   <h4 class="pg-card-title">{title}</h4>
  #   <p class="pg-card-meta">{authors} · {journal} · {doi_link}</p>
  #   <div class="pg-narrative-grid">
  #     <div class="pg-narrative-item">
  #       <i class="pg-icon">❓</i>
  #       <strong>Problématique | Research Question</strong>
  #       <p>{problematique}</p>
  #     </div>
  #     <div class="pg-narrative-item">
  #       <i class="pg-icon">🎯</i>
  #       <strong>Pertinence | Relevance</strong>
  #       <p>{pertinence}</p>
  #     </div>
  #     <div class="pg-narrative-item">
  #       <i class="pg-icon">💡</i>
  #       <strong>Résultat | Finding</strong>
  #       <p>{resultat}</p>
  #     </div>
  #     <div class="pg-narrative-item">
  #       <i class="pg-icon">🔮</i>
  #       <strong>Question ouverte | Open Question</strong>
  #       <p>{question_ouverte}</p>
  #     </div>
  #   </div>
  # </div>
  # Utiliser glue::glue() pour l'interpolation
}
```

### 2.7 viz_seminars.R — Visualisations séminaires et conférences

```r
#' Geographic map of seminar interventions
#' @export
pg_map_seminars <- function(data, output_type = "both", theme_color = "#1B4F72") {
  # 1. Filtrer type_classified %in% c("seminar", "conference")
  # 2. Extraire city + country — géolocaliser avec tidygeocoder::geo()
  #    méthode = "osm" (gratuit), avec cache dans tempfile() pour éviter
  #    re-géolocalisation à chaque appel
  # 3. Agréger par coordonnées : n = nombre d'interventions, titles = list
  # VERSION INTERACTIVE (leaflet) :
  #   - leaflet::leaflet() + addProviderTiles("CartoDB.Positron")
  #   - addCircleMarkers : radius = sqrt(n) * 5, color = theme_color
  #   - popup : HTML avec liste des titres d'interventions
  # VERSION STATIQUE (ggplot2 + sf) :
  #   - rnaturalearth::ne_countries(scale = "medium") → fond de carte
  #   - geom_sf(fill = "#F5F5F5", color = "white", size = 0.2)
  #   - geom_point(aes(x=lon, y=lat, size=n), color=theme_color, alpha=0.8)
  #   - scale_size_continuous(range = c(3, 12))
  #   - coord_sf(expand = FALSE)
  #   - Appliquer pg_theme() + theme(axis.text = element_blank())
  # Retourner list(interactive = leaflet_obj, static = ggplot_obj)
}

#' Thematic network of seminar keywords
#' @export
pg_network_seminars <- function(data, author_name, theme_color = "#1B4F72") {
  # 1. Extraire mots-clés des séminaires (titre + keywords + description)
  # 2. Top 20 mots-clés (après stopwords) = nœuds périphériques
  # 3. Construire graphe bipartite avec tidygraph::tbl_graph()
  #    Nœud central = author_name (taille 15, couleur theme_color)
  #    Nœuds thèmes = taille proportionnelle à la fréquence
  #    Arêtes = poids proportionnel à la fréquence
  # 4. Layout ggraph "stress" (stable, reproductible avec seed=2024)
  # 5. geom_edge_link(aes(width=weight), alpha=0.4, color=theme_color)
  # 6. geom_node_point(aes(size=size, color=type))
  # 7. geom_node_text(aes(label=name), repel=TRUE, size=3)
  # 8. Appliquer pg_theme() + theme_graph()
}

# Également implémenter :
# pg_narrative_seminar(seminar_row, api_key, lang = "fr")
# — même logique que pg_narrative_article() mais prompt adapté :
# JSON avec clés : { "question_centrale", "audience_ciblee",
#                    "positionnement_debat", "apport_original" }
```

### 2.8 viz_books.R — Visualisations ouvrages et chapitres

```r
#' Visual gallery of book covers
#' @export
pg_gallery_books <- function(data, theme_color = "#1B4F72") {
  # 1. Filtrer type_classified %in% c("book", "book_chapter")
  # 2. Pour chaque livre avec ISBN (non-NA) :
  #    URL = glue("https://covers.openlibrary.org/b/isbn/{isbn}-M.jpg")
  #    httr2::request(url) |> httr2::req_perform()
  #    Si status 200 → télécharger dans tempdir()/{isbn}.jpg
  #    Si status 404 ou erreur → générer placeholder :
  #      ggplot2 avec geom_rect() fond theme_color + geom_text() titre
  # 3. Charger chaque image avec png::readPNG() ou jpeg::readJPEG()
  # 4. Convertir en grob avec grid::rasterGrob()
  # 5. Assembler en grille avec patchwork::wrap_plots()
  #    ncol = min(4, n_books), chaque panel = couverture + titre tronqué
  # 6. Retourner objet ggplot patchwork
}

#' Co-authorship network
#' @export
pg_network_coauthors <- function(data, author_name, theme_color = "#1B4F72") {
  # 1. Extraire tous les auteurs de toutes les productions
  # 2. Compter co-publications par co-auteur (toutes catégories)
  # 3. Filtrer co-auteurs avec >= 2 co-publications (ou top 20 si besoin)
  # 4. Construire réseau : auteur_principal ↔ co-auteurs
  #    Attribut arête : type_classified (couleur) + n (épaisseur)
  # 5. tidygraph::tbl_graph() + layout "fr" (Fruchterman-Reingold, seed=2024)
  # 6. geom_edge_link(aes(width=n, color=type_classified), alpha=0.6)
  # 7. geom_node_point(aes(size=ifelse(name==author_name, 12, n_collab)))
  # 8. scale_color_manual() avec palette par type de production
  # 9. Retourner ggplot
}

#' Word cloud of book and chapter titles
#' @export
pg_wordcloud_books <- function(data, theme_color = "#1B4F72") {
  # Même logique que pg_wordcloud_articles() mais :
  # - Corpus = titres + sous-titres des ouvrages et chapitres uniquement
  # - TF-IDF simplifié (pas de LDA — trop peu de documents)
  # - wordcloud2 avec fontFamily = "Playfair Display" (style "livre")
  # - Taille minimum plus grande (les titres de livres sont plus informatifs)
}
```

### 2.9 viz_other.R — Autres types de productions

```r
# pg_gantt_projects(data, theme_color)
# ─ Filtre type == "project"
# ─ Extrait date_start + date_end depuis le champ "note" du CSV (format ISO)
# ─ Barre Gantt horizontale ggplot2 :
#   geom_segment(aes(x=date_start, xend=date_end, y=reorder(title,date_start)))
#   Couleur par statut : "#27AE60" terminé / theme_color en cours / "#E74C3C" à venir
#   geom_text(aes(label=funding_source)) à droite de chaque barre
# ─ Annotations : montant financement si disponible
# ─ @export

# pg_timeline_theses(data, theme_color)
# ─ Filtre type == "thesis_supervised"
# ─ Timeline verticale :
#   geom_point(aes(y=student_name, x=year, color=degree_level), size=6)
#   geom_text(aes(label=str_wrap(title,30)), hjust=0, size=2.5)
# ─ Couleur : PhD = theme_color / Master = theme_color en opacité 50%
# ─ @export

# pg_infographic_awards(data, theme_color)
# ─ Filtre type == "award"
# ─ Infographie verticale "palmarès" :
#   Pour chaque prix : médaille ggtext HTML (🥇🥈🥉 ou ★) + titre + institution + année
#   Fond alterné blanc / theme_color en opacité 5%
# ─ @export

# pg_map_expertise(data, theme_color)
# ─ Filtre type == "expertise"
# ─ Réutilise pg_map_seminars() mais avec pch = 15 (carré) au lieu de cercle
# ─ Couleur différente (teinte complémentaire de theme_color via colorspace)
# ─ @export

# pg_media_summary(data, theme_color)
# ─ Filtre type == "media"
# ─ Barchart horizontal : institution/média en y, n en x
# ─ Groupé par sous-type (podcast / interview / article presse)
# ─ @export
```

### 2.10 viz_global.R — Vue d'ensemble de la trajectoire

```r
#' Radar chart of production types
#' @export
pg_radar_productions <- function(data, theme_color = "#1B4F72") {
  # 1. pg_summary_table(data) → n par type_classified
  # 2. Normaliser : score = n / max(n) * 100
  # 3. Créer dataframe pour coord_polar :
  #    angle = (type_index / 12) * 2 * pi
  # 4. ggplot() + geom_polygon(fill=theme_color, alpha=0.3) +
  #    geom_path(color=theme_color, size=1.2) +
  #    geom_point(color=theme_color, size=3) +
  #    coord_polar(start = -pi/12) +
  #    scale_x_continuous(breaks=seq_along(types), labels=labels_bilingues)
  # 5. Annoter les valeurs brutes (n) à côté de chaque point
  # 6. Appliquer pg_theme()
}

#' Temporal evolution curve of all productions
#' @export
pg_curve_timeline <- function(data, theme_color = "#1B4F72") {
  # 1. Compter productions par année et par type_classified
  # 2. Calculer total annuel (toutes catégories)
  # 3. ggplot aes(x=year, y=n) +
  #    geom_area(data=total, fill=theme_color, alpha=0.15) +
  #    geom_line(data=total, color=theme_color, size=1.5) +
  #    geom_line(aes(color=type_classified), size=0.8, linetype="dashed") +
  #    geom_point(data=total, color=theme_color, size=2)
  # 4. Annoter l'année la plus productive avec ggtext::geom_richtext()
  # 5. scale_color_manual() avec palette pg_palette()
  # 6. Appliquer pg_theme()
}

#' Compute global statistics for the cover page
#' @export
pg_stats_banner <- function(data) {
  # Retourner named list :
  # n_articles, n_books, n_book_chapters, n_seminars, n_conferences,
  # n_reports, n_theses, n_patents, n_media, n_projects, n_awards, n_expertise,
  # total_productions, career_years (max_year - min_year + 1),
  # most_productive_year, avg_per_year (arrondi 1 décimale),
  # top_3_keywords (vecteur chr depuis TF-IDF global),
  # n_unique_coauthors, n_countries_interventions
}
```

### 2.11 llm_narratives.R — Orchestrateur IA avec cache

```r
#' Run AI narrative generation for all eligible productions
#' @export
pg_run_all_narratives <- function(data, api_key, lang = "fr",
                                   cache_dir = NULL, types_to_process = NULL,
                                   max_items = Inf) {
  # types_to_process défaut = c("article", "seminar", "book")
  # CACHE : si cache_dir fourni :
  #   cache_key = digest::digest(list(pg_id, abstract, lang))
  #   cache_file = file.path(cache_dir, paste0(cache_key, ".rds"))
  #   Si fichier existe → charger sans appeler API
  #   Si nouveau → appeler API → sauvegarder
  # RATE LIMITING : Sys.sleep(0.5) entre chaque appel
  # PROGRESS BAR : cli::cli_progress_bar() avec {current}/{total}
  # LOG FINAL :
  #   cli::cli_alert_success("{n_success} résumés générés | {n_success} summaries generated")
  #   cli::cli_alert_warning("{n_fallback} fallbacks (API non disponible)")
  # Retourner data enrichi avec colonnes :
  #   narrative_problematique, narrative_pertinence,
  #   narrative_resultat, narrative_question_ouverte,
  #   narrative_lang, narrative_cached
}

#' Check Anthropic API key validity
#' @export
pg_check_api_key <- function(api_key) {
  # Appel minimal (1 token) vers /v1/messages
  # Retourne TRUE si status 200 ou 400 (clé valide mais prompt vide)
  # Retourne FALSE si status 401 (clé invalide)
  # Warning bilingue dans tous les cas
}
```

### 2.12 cover_page.R — Page de couverture premium

```r
#' Build the HTML cover page
#' @export
pg_build_cover <- function(author_name, affiliation, photo_path = NULL,
                            orcid = NULL, linkedin = NULL, website = NULL,
                            stats, theme_color = "#1B4F72", lang = "fr") {
  # DESIGN EXACT DE LA PAGE DE COUVERTURE :
  # ┌─────────────────────────────────────────────────────────┐
  # │ ████████████████  │  Jean Dupont — PubliGraphics        │
  # │ ██  BANDE        │  ─────────────────────────────────  │
  # │ ██  COLORÉE      │  [PHOTO CIRCULAIRE]                 │
  # │ ██  GAUCHE       │  Pr. Jean Dupont                    │
  # │ ██  (25% width)  │  Université de Paris                │
  # │ ██               │  ORCID | LinkedIn | Site web        │
  # │ ████████████████  │  ─────────────────────────────────  │
  # │                   │  [GRILLE DE STATS 3×2]              │
  # │  PubliGraphics    │  📄 42 Articles   📚 3 Livres       │
  # │  for Social       │  🎤 28 Séminaires 🎓 12 Thèses     │
  # │  Researchers      │  🏆 5 Prix        💼 8 Projets     │
  # │                   │  ─────────────────────────────────  │
  # │                   │  Carrière: 25 ans | 98 productions  │
  # └─────────────────────────────────────────────────────────┘
  #
  # Techniquement :
  # - Layout CSS Grid 2 colonnes (25% / 75%)
  # - Bande gauche : background = dégradé linéaire theme_color → theme_color_dark
  # - Photo : si fournie → <img> cercle avec border 3px white
  #           si absente → div avec initiales (background theme_color_light)
  # - Stats cards : flexbox 3×2, chiffre en 42px bold, label en 11px gris
  # - Icônes : emoji unicode (compatibilité maximale, pas de dépendance FontAwesome)
  # - QR code : si website fourni → qrcode::qr_code(website) → png tempfile
  #             inséré en base64 dans le HTML
  # - Footer centré : "Generated with PubliGraphics for Social Researchers
  #                    R Package — {format(Sys.Date(), '%B %Y')}"
  # - Police : Lato via @import Google Fonts dans le CSS inline
  # Retourner : HTML string complet (div conteneur + CSS inline)
  # Utiliser glue::glue_safe() pour éviter les injections XSS
}
```

### 2.13 generate_notebook.R — Orchestrateur principal

```r
#' Generate the complete PubliGraphics notebook
#'
#' @description
#' Fonction principale de PubliGraphics. Orchestre l'ensemble du pipeline :
#' parsing → classification → statistiques → narratives IA → visualisations
#' → rendu notebook PDF et/ou HTML.
#'
#' Main function of PubliGraphics. Orchestrates the full pipeline.
#'
#' @param author_name `character(1)` Nom complet de l'auteur.
#' @param bib_file `character(1)` Chemin vers le fichier BibTeX principal.
#' @param extra_data `character(1)` Chemin vers le CSV complémentaire (optionnel).
#' @param photo `character(1)` Chemin vers la photo (JPG/PNG, optionnel).
#' @param affiliation `character(1)` Affiliation institutionnelle.
#' @param orcid `character(1)` Identifiant ORCID (format 0000-0000-0000-0000).
#' @param linkedin `character(1)` URL profil LinkedIn (optionnel).
#' @param website `character(1)` URL site web (optionnel).
#' @param api_key_claude `character(1)` Clé API Anthropic.
#'   Défaut : variable d'environnement `ANTHROPIC_API_KEY`.
#' @param theme_color `character(1)` Couleur hexadécimale principale.
#'   Défaut : `"#1B4F72"` (bleu marine académique).
#' @param output_formats `character` Vecteur de formats : `"pdf"`, `"html"`,
#'   ou les deux.
#' @param output_dir `character(1)` Dossier de sortie (créé si inexistant).
#' @param language `character(1)` `"fr"` ou `"en"`.
#' @param use_cache `logical(1)` Utiliser le cache IA pour éviter les re-appels.
#' @param open_after `logical(1)` Ouvrir le HTML après génération.
#' @param n_narrative_max `integer(1)` Nombre maximum de résumés IA générés.
#'
#' @return `list` invisible avec `$pdf_path`, `$html_path`, `$data`,
#'   `$duration_seconds`.
#'
#' @examples
#' \dontrun{
#' # Exemple avec les données Esther Duflo incluses dans le package
#' bib_path   <- system.file("extdata", "duflo_articles.bib", package="publigraphics")
#' extra_path <- system.file("extdata", "duflo_extra.csv",   package="publigraphics")
#'
#' result <- generate_publigraphics(
#'   author_name    = "Esther Duflo",
#'   bib_file       = bib_path,
#'   extra_data     = extra_path,
#'   affiliation    = "MIT / J-PAL / Collège de France",
#'   orcid          = "0000-0002-0632-6971",
#'   theme_color    = "#1A5276",
#'   output_dir     = tempdir(),
#'   language       = "en",
#'   output_formats = "html",
#'   api_key_claude = Sys.getenv("ANTHROPIC_API_KEY")
#' )
#' }
#'
#' @export
generate_publigraphics <- function(
    author_name,
    bib_file,
    extra_data     = NULL,
    photo          = NULL,
    affiliation    = "",
    orcid          = NULL,
    linkedin       = NULL,
    website        = NULL,
    api_key_claude = Sys.getenv("ANTHROPIC_API_KEY"),
    theme_color    = "#1B4F72",
    output_formats = c("pdf", "html"),
    output_dir     = file.path(getwd(), "publigraphics_output"),
    language       = "fr",
    use_cache      = TRUE,
    open_after     = TRUE,
    n_narrative_max = 20L
) {
  t_start <- proc.time()

  # ── ÉTAPE 1 : Validation des inputs ─────────────────────────────────────────
  # Vérifier existence bib_file : if (!file.exists(bib_file)) stop(pg_msg(...))
  # Vérifier format theme_color : pg_hex_valid(theme_color)
  # Vérifier output_formats %in% c("pdf","html")
  # Vérifier language %in% c("fr","en")
  # Créer output_dir si inexistant : fs::dir_create(output_dir, recurse=TRUE)
  # Créer sous-dossier viz : fs::dir_create(file.path(output_dir, "viz"))
  # Afficher récapitulatif :
  #   cli::cli_h1("PubliGraphics — {author_name}")
  #   cli::cli_ul(c(...paramètres clés...))

  # ── ÉTAPE 2 : Parsing et classification ─────────────────────────────────────
  # pg_read_bib() + pg_read_extra() + pg_merge_inputs() + pg_classify()
  # Afficher pg_summary_table() dans la console via knitr::kable()

  # ── ÉTAPE 3 : Statistiques globales ─────────────────────────────────────────
  # stats <- pg_stats_banner(data)

  # ── ÉTAPE 4 : Narratives IA (si api_key non vide) ───────────────────────────
  # if (nchar(api_key_claude) > 10 && pg_check_api_key(api_key_claude)) {
  #   data <- pg_run_all_narratives(data, api_key_claude, language,
  #             cache_dir = if(use_cache) file.path(output_dir, ".cache") else NULL,
  #             max_items = n_narrative_max)
  # }

  # ── ÉTAPE 5 : Génération des visualisations ──────────────────────────────────
  # Appeler toutes les fonctions viz_* dans l'ordre
  # Pour chaque viz :
  #   1. Générer objet ggplot ou list(plot, widget)
  #   2. Sauvegarder ggplot en PNG 300 DPI : ggplot2::ggsave()
  #      path = file.path(output_dir, "viz", "{nom_viz}.png")
  #      width=10, height=6, dpi=300, bg="white"
  #   3. Pour les htmlwidgets : htmlwidgets::saveWidget()
  #      puis webshot2::webshot() → PNG pour inclusion dans PDF
  # Stocker tous les objets dans viz_list = list(...)

  # ── ÉTAPE 6 : Construction de la couverture ───────────────────────────────────
  # cover_html <- pg_build_cover(...)

  # ── ÉTAPE 7 : Rendu du template Rmd ──────────────────────────────────────────
  # Copier template depuis system.file("templates", ...) vers output_dir/
  # Construire params = list(author_name, data, viz_list, narratives=data,
  #                           stats, cover_html, theme_color, lang=language)
  # rmarkdown::render(
  #   input  = file.path(output_dir, "publigraphics_notebook.Rmd"),
  #   output_format = "html_document",
  #   params = params,
  #   quiet  = FALSE,
  #   envir  = new.env()
  # )
  # Si "pdf" dans output_formats :
  #   pagedown::chrome_print(html_path, output=pdf_path, timeout=120)
  #   if (inherits(., "error")) → message aide Chrome bilingue

  # ── ÉTAPE 8 : Renommage et résumé final ───────────────────────────────────────
  # Renommer : publigraphics_{author_name_clean}_{Sys.Date()}.html / .pdf
  # cli::cli_alert_success("✓ Notebook généré en {round(duration,1)}s")
  # cli::cli_bullets(c("*" = "HTML : {html_path}", "*" = "PDF : {pdf_path}"))
  # if (open_after) utils::browseURL(html_path)
  # invisible(list(pdf_path=pdf_path, html_path=html_path, data=data,
  #                duration_seconds=duration))
}
```

### 2.14 Template Rmd — inst/templates/publigraphics_notebook.Rmd

```yaml
---
title: "`r params$author_name` — PubliGraphics"
date: "`r format(Sys.Date(), '%B %Y')`"
output:
  html_document:
    theme: null
    highlight: null
    css: ["publigraphics_base.css"]
    self_contained: true
    toc: false
    fig_caption: true
    df_print: kable
  pagedown::html_paged:
    css: ["publigraphics_base.css", "publigraphics_print.css"]
    self_contained: true
    lot: false
    lof: false
params:
  author_name:  ""
  data:         NULL
  viz_list:     NULL
  stats:        NULL
  cover_html:   ""
  theme_color:  "#1B4F72"
  lang:         "fr"
---
```

**Structure des sections du Rmd (7 pages) :**

```
SECTION 1 — Page de couverture
  `r params$cover_html`   # HTML brut inséré directement
  <div class="pg-page-break"></div>

SECTION 2 — Empreinte scientifique globale
  ## `r if(params$lang=="fr") "Vue d'ensemble" else "Overview"`
  ### Radar des productions / Production Radar
  ```{r radar, echo=FALSE, fig.width=8, fig.height=8}
  params$viz_list$radar
  ```
  ### Évolution temporelle / Temporal Evolution
  ```{r timeline_global, echo=FALSE, fig.width=12, fig.height=5}
  params$viz_list$curve_timeline
  ```

SECTION 3 — Articles scientifiques / Peer-reviewed Articles
  ### Paysage thématique / Thematic Landscape
  (wordcloud widget en HTML, PNG en PDF)
  ### Chronologie / Timeline
  (timeline articles)
  ### Fiches de synthèse / Article Cards
  (loop sur top 5 articles par citations → pg_card_article())

SECTION 4 — Ouvrages et chapitres / Books and Chapters
  (galerie couvertures + réseau co-auteurs)

SECTION 5 — Séminaires et conférences / Seminars and Conferences
  (carte interactive + réseau thématique)

SECTION 6 — Autres productions / Other Productions
  (Gantt projets + timeline thèses + awards infographic)

SECTION 7 — Empreinte scientifique complète / Full Scientific Fingerprint
  (wordcloud global toutes catégories + QR code + citation APA auto-générée)
  Citation APA générée automatiquement :
  "{author_name} ({max_year}). PubliGraphics Profile. Retrieved {today} from {website}"
```

### 2.15 CSS Premium — inst/templates/publigraphics_base.css

**Implémenter un CSS complet de niveau publication académique :**

```css
/* ════════════════════════════════════════════════════════════
   PubliGraphics — Feuille de style principale
   Niveau : publication académique imprimée + web premium
   ════════════════════════════════════════════════════════════ */

/* ── 1. Import des polices ── */
@import url('https://fonts.googleapis.com/css2?
  family=Lato:wght@300;400;700;900&
  family=Playfair+Display:wght@700;900&
  family=Source+Code+Pro:wght@400;600&
  display=swap');

/* ── 2. Variables CSS (surchargeables dynamiquement par R) ── */
:root {
  --theme-color:       #1B4F72;
  --theme-color-light: #D6EAF8;
  --theme-color-dark:  #154360;
  --theme-accent:      #E67E22;
  --text-primary:      #1A252F;
  --text-secondary:    #566573;
  --text-muted:        #95A5A6;
  --bg-white:          #FFFFFF;
  --bg-light:          #F8F9FA;
  --bg-card:           #FDFEFE;
  --border-color:      #E8ECEF;
  --shadow-soft:       0 2px 16px rgba(0,0,0,0.06);
  --shadow-card:       0 4px 24px rgba(0,0,0,0.08);
  --radius-sm:         6px;
  --radius-md:         12px;
  --radius-lg:         20px;
  --font-body:         'Lato', sans-serif;
  --font-display:      'Playfair Display', serif;
  --font-mono:         'Source Code Pro', monospace;
}

/* ── 3. Reset et base ── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: var(--font-body);
  font-size: 14px;
  line-height: 1.7;
  color: var(--text-primary);
  background: var(--bg-white);
  -webkit-font-smoothing: antialiased;
}

/* ── 4. Classe principale du notebook ── */
.pg-notebook { max-width: 1100px; margin: 0 auto; padding: 0; }

/* ── 5. Page de couverture ── */
.pg-cover {
  display: grid;
  grid-template-columns: 260px 1fr;
  min-height: 100vh;
  background: var(--bg-white);
}
.pg-cover-sidebar {
  background: linear-gradient(160deg, var(--theme-color) 0%, var(--theme-color-dark) 100%);
  padding: 40px 24px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 20px;
  color: white;
}
.pg-cover-photo {
  width: 140px; height: 140px;
  border-radius: 50%;
  border: 4px solid rgba(255,255,255,0.9);
  object-fit: cover;
  box-shadow: 0 8px 24px rgba(0,0,0,0.3);
}
.pg-cover-avatar {
  width: 140px; height: 140px;
  border-radius: 50%;
  background: rgba(255,255,255,0.2);
  display: flex; align-items: center; justify-content: center;
  font-size: 52px; font-weight: 900; color: white;
  font-family: var(--font-display);
}
.pg-cover-author-name {
  font-family: var(--font-display);
  font-size: 18px; font-weight: 700;
  text-align: center; color: white;
}
.pg-cover-affiliation {
  font-size: 12px; color: rgba(255,255,255,0.85);
  text-align: center; line-height: 1.5;
}
.pg-cover-links { display: flex; flex-direction: column; gap: 8px; width: 100%; }
.pg-cover-link {
  font-size: 11px; color: rgba(255,255,255,0.9);
  text-decoration: none; word-break: break-all;
}
.pg-cover-content {
  padding: 48px 40px;
  display: flex; flex-direction: column; justify-content: center; gap: 32px;
}
.pg-cover-title {
  font-family: var(--font-display);
  font-size: 36px; font-weight: 900;
  color: var(--theme-color);
  letter-spacing: -0.5px;
  line-height: 1.2;
}
.pg-cover-subtitle {
  font-size: 16px; color: var(--text-secondary); margin-top: 8px;
}
.pg-stats-grid {
  display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px;
}
.pg-stat-card {
  background: var(--bg-light);
  border-radius: var(--radius-md);
  padding: 20px 16px;
  text-align: center;
  border: 1px solid var(--border-color);
  transition: box-shadow 0.2s;
}
.pg-stat-card:hover { box-shadow: var(--shadow-card); }
.pg-stat-number {
  font-size: 42px; font-weight: 900;
  color: var(--theme-color);
  font-family: var(--font-display);
  line-height: 1;
}
.pg-stat-label {
  font-size: 11px; color: var(--text-secondary);
  text-transform: uppercase; letter-spacing: 0.8px;
  margin-top: 6px;
}
.pg-stat-icon { font-size: 20px; margin-bottom: 8px; }
.pg-cover-footer {
  font-size: 11px; color: var(--text-muted);
  border-top: 1px solid var(--border-color);
  padding-top: 16px; text-align: center;
}

/* ── 6. Sections du notebook ── */
.pg-section {
  padding: 48px 40px;
  border-bottom: 1px solid var(--border-color);
}
.pg-section-title {
  font-family: var(--font-display);
  font-size: 26px; font-weight: 700;
  color: var(--theme-color);
  margin-bottom: 8px;
  padding-bottom: 12px;
  border-bottom: 3px solid var(--theme-color);
  display: inline-block;
}
.pg-section-subtitle {
  font-size: 12px; color: var(--text-muted);
  text-transform: uppercase; letter-spacing: 1px;
  margin-bottom: 32px;
}

/* ── 7. Fiches articles ── */
.pg-article-card {
  background: var(--bg-card);
  border-left: 4px solid var(--theme-color);
  border-radius: 0 var(--radius-md) var(--radius-md) 0;
  padding: 20px 24px;
  margin-bottom: 20px;
  box-shadow: var(--shadow-soft);
  page-break-inside: avoid;
}
.pg-card-header { display: flex; align-items: center; gap: 12px; margin-bottom: 10px; }
.pg-card-title { font-size: 15px; font-weight: 700; color: var(--text-primary); margin-bottom: 6px; }
.pg-card-meta { font-size: 12px; color: var(--text-secondary); margin-bottom: 14px; }
.pg-card-doi { color: var(--theme-color); text-decoration: none; font-weight: 600; }
.pg-narrative-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 14px;
}
.pg-narrative-item {
  background: var(--theme-color-light);
  border-radius: var(--radius-sm);
  padding: 12px 14px;
  font-size: 12px; line-height: 1.5;
}
.pg-narrative-item strong { display: block; font-size: 11px; text-transform: uppercase;
  letter-spacing: 0.5px; color: var(--theme-color); margin-bottom: 4px; }

/* ── 8. Badges ── */
.pg-badge {
  display: inline-block; padding: 3px 10px; border-radius: 20px;
  font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px;
}
.pg-badge-article   { background: #EBF5FB; color: #1A5276; }
.pg-badge-book      { background: #EAF4F4; color: #0E6655; }
.pg-badge-seminar   { background: #FEF9E7; color: #9A7D0A; }
.pg-badge-project   { background: #F5EEF8; color: #6C3483; }
.pg-badge-award     { background: #FDF2E9; color: #A04000; }
.pg-year {
  font-size: 13px; font-weight: 700; color: var(--text-secondary);
  margin-left: auto;
}

/* ── 9. Print / PDF ── */
@media print {
  .pg-cover        { min-height: 0; page-break-after: always; }
  .pg-section      { page-break-before: always; }
  .pg-article-card, .pg-stat-card { page-break-inside: avoid; }
  .pg-page-break   { page-break-before: always; }
  a[href]::after   { content: none !important; }
  body             { font-size: 11px; }
  .pg-stat-number  { font-size: 32px; }
  .pg-cover-title  { font-size: 28px; }
}

/* ── 10. Responsive (pour HTML web) ── */
@media (max-width: 768px) {
  .pg-cover { grid-template-columns: 1fr; }
  .pg-stats-grid { grid-template-columns: repeat(2, 1fr); }
  .pg-narrative-grid { grid-template-columns: 1fr; }
  .pg-section { padding: 24px 20px; }
}
```

### 2.16 Données de démonstration — inst/extdata/ (DONNÉES RÉELLES ESTHER DUFLO)

**IMPORTANT : Ces données sont publiques et vérifiables. Claude Code doit
rechercher et utiliser les informations réelles d'Esther Duflo.**

#### duflo_articles.bib — 15 articles réels à inclure :

```bibtex
@article{Duflo2001,
  author   = {Duflo, Esther},
  title    = {Schooling and Labor Market Consequences of School Construction
               in Indonesia: Evidence from an Unusual Policy Experiment},
  journal  = {American Economic Review},
  year     = {2001},
  volume   = {91},
  number   = {4},
  pages    = {795--813},
  doi      = {10.1257/aer.91.4.795},
  keywords = {education, Indonesia, school construction, labor market,
               natural experiment, returns to schooling},
  abstract = {Using a large primary school construction program in Indonesia
               from 1973 to 1978, this paper estimates the effect of
               education on wages and takes this as an opportunity to
               examine the internal validity of natural experiments. The
               program built over 61,000 schools throughout Indonesia.
               Using differences in the number of schools constructed
               across regions and across cohorts, I estimate that
               the construction of primary schools led to an increase
               in education and earnings for the cohort affected by
               the program. Each school built per 1,000 children is
               associated with an average increase of 0.12 to 0.19 years
               of education and a 1.5 to 2.7 percent increase in wages.},
  note     = {cited_by:4200}
}

@article{DufloBanerjee2007,
  author   = {Duflo, Esther and Banerjee, Abhijit},
  title    = {The Economic Lives of the Poor},
  journal  = {Journal of Economic Perspectives},
  year     = {2007},
  volume   = {21},
  number   = {1},
  pages    = {141--167},
  doi      = {10.1257/jep.21.1.141},
  keywords = {poverty, consumption, household surveys, developing countries,
               microeconomics, economic behavior},
  abstract = {In this paper, we use survey data from 13 countries to
               describe the economic lives of the poor. We find that the
               poor are not passive but active economic agents. They make
               sophisticated decisions regarding consumption, health,
               education, and investment. The poor spend relatively little
               on education despite the high returns, largely because
               they perceive the quality of available schools to be poor.
               Health spending is disproportionately allocated to curative
               care rather than preventive measures. These findings
               challenge simplistic characterisations of poverty and
               highlight the complexity of economic decision-making at
               the bottom of the income distribution.},
  note     = {cited_by:3800}
}

@article{BanerjeeEtAl2015,
  author   = {Banerjee, Abhijit and Duflo, Esther and Goldberg, Nathanael
               and Karlan, Dean and Osei, Robert and Pariente, William
               and Shapiro, Jeremy and Thuysbaert, Bram and Udry, Christopher},
  title    = {A Multifaceted Program Causes Lasting Progress for the Very Poor:
               Evidence from Six Countries},
  journal  = {Science},
  year     = {2015},
  volume   = {348},
  number   = {6236},
  pages    = {1260799},
  doi      = {10.1126/science.1260799},
  keywords = {ultra-poor, graduation program, randomized controlled trial,
               poverty alleviation, multifaceted intervention, longitudinal},
  abstract = {We use six randomized control trials in Ethiopia, Ghana, Honduras,
               India, Pakistan, and Peru, to study the impact of the
               Targeting the Ultra Poor (TUP) program on the welfare of
               those at the bottom of the income distribution. The program
               combines a one-time asset transfer with a period of intensive
               support. Across all six countries, we find consistently
               positive and persistent impacts on consumption, food security,
               asset holdings, financial inclusion, and psychological
               well-being. The effects are large: after two years, the
               treated households consume 5 to 9 percent more, have
               80 to 130 percent more assets, and are significantly
               less likely to be food insecure.},
  note     = {cited_by:2100}
}

@article{DufloEtAl2011,
  author   = {Duflo, Esther and Dupas, Pascaline and Kremer, Michael},
  title    = {Peer Effects, Teacher Incentives, and the Impact of Tracking:
               Evidence from a Randomized Evaluation in Kenya},
  journal  = {American Economic Review},
  year     = {2011},
  volume   = {101},
  number   = {5},
  pages    = {1739--1774},
  doi      = {10.1257/aer.101.5.1739},
  keywords = {education, Kenya, tracking, peer effects, teacher incentives,
               randomized evaluation, primary schools},
  abstract = {To examine the impacts of tracking students by prior
               achievement, we randomly assigned students applying to
               first grade in 121 Kenyan schools to either tracked or
               non-tracked schools. In tracked schools, students were
               divided into two classes based on initial achievement.
               In non-tracked schools, students were randomly divided
               into two classes. We also provided contract teachers to
               half of all schools. Tracking and contract teachers both
               raised test scores by 0.14 standard deviations. Tracking
               benefited students of all ability levels including the
               weakest students. The contract teachers disproportionately
               raised scores in the upper halves of their classes.},
  note     = {cited_by:1900}
}

@article{DufloKremer2005,
  author   = {Duflo, Esther and Kremer, Michael},
  title    = {Use of Randomization in the Evaluation of Development Effectiveness},
  journal  = {Evaluating Development Effectiveness},
  year     = {2005},
  volume   = {7},
  pages    = {205--231},
  keywords = {randomized controlled trials, development economics,
               evaluation, methodology, causal inference},
  abstract = {This chapter surveys the use of randomized experiments in
               development economics and argues for their increased use
               in policy evaluation. We describe the challenges and
               practical constraints of running randomized trials in
               developing countries, discuss when randomization is
               feasible and appropriate, and present a framework for
               thinking about external validity. We illustrate these
               points with examples from education, health, and
               microfinance, and argue that randomized trials can
               provide reliable causal estimates of program impacts.},
  note     = {cited_by:1500}
}

@article{DufloEtAl2012,
  author   = {Duflo, Esther and Greenstone, Michael and Hanna, Rema},
  title    = {Cooking Stoves, Indoor Air Pollution and Respiratory Health
               in Rural Orissa},
  journal  = {Economic and Political Weekly},
  year     = {2012},
  volume   = {42},
  number   = {1},
  pages    = {71--76},
  keywords = {indoor air pollution, cooking stoves, health, India, Orissa,
               rural households, respiratory disease, randomized trial},
  abstract = {This paper reports the results of a randomized trial of
               an improved cooking stove program in rural Orissa, India.
               We provided randomly chosen households with improved
               biomass stoves and measured the impact on indoor air
               quality, stove adoption, and health outcomes. We find
               that improved stoves significantly reduced indoor air
               pollution over the first year of the study. However,
               the improvements in air quality did not translate into
               measurable improvements in health, and adoption rates
               fell sharply over time as households reverted to their
               traditional stoves.},
  note     = {cited_by:890}
}

@article{BanerjeeEtAl2007,
  author   = {Banerjee, Abhijit and Duflo, Esther and Glennerster, Rachel
               and Kothari, Dhruva},
  title    = {Improving Immunisation Coverage in Rural India: Clustered
               Randomised Controlled Evaluation of Immunisation Campaigns
               with and without Incentives},
  journal  = {BMJ},
  year     = {2010},
  volume   = {340},
  pages    = {c2220},
  doi      = {10.1136/bmj.c2220},
  keywords = {immunization, India, incentives, public health, vaccination,
               randomized trial, rural health, child mortality},
  abstract = {Objectives: To evaluate the effect of organising monthly
               immunisation camps and providing incentives on immunisation
               rates for children under 5. Design: Cluster randomised
               controlled trial. Setting: 134 villages in Rajasthan, India,
               randomly allocated to three groups. Interventions: Regular
               immunisation camp without incentive, regular immunisation
               camp with incentive (lentils and thali), and control group.
               The incidence of full immunisation was 39% in villages with
               camps and incentives, versus 18% in control villages.},
  note     = {cited_by:1200}
}

@article{Duflo2003,
  author   = {Duflo, Esther},
  title    = {Grandmothers and Granddaughters: Old-Age Pensions and Intrahousehold
               Allocation in South Africa},
  journal  = {World Bank Economic Review},
  year     = {2003},
  volume   = {17},
  number   = {1},
  pages    = {1--25},
  doi      = {10.1093/wber/lhg013},
  keywords = {South Africa, pensions, intrahousehold allocation, gender,
               child nutrition, elderly, social protection},
  abstract = {I use the extension of the Old Age Pension program to Black
               South Africans after the end of apartheid to study the
               impact of pensions on child nutrition. I find that pension
               receipt by women had a large effect on the nutritional status
               of girls, but that pension receipt by men had no effect on
               the nutritional status of children of either sex. This
               asymmetry between men and women suggests that who controls
               resources within the household matters for child outcomes.},
  note     = {cited_by:2300}
}

@article{DufloSaez2003,
  author   = {Duflo, Esther and Saez, Emmanuel},
  title    = {The Role of Information and Social Interactions in Retirement
               Plan Decisions: Evidence from a Randomized Experiment},
  journal  = {Quarterly Journal of Economics},
  year     = {2003},
  volume   = {118},
  number   = {3},
  pages    = {815--842},
  doi      = {10.1162/00335530360698432},
  keywords = {retirement plans, 401k, peer effects, social interactions,
               information, savings, randomized experiment, United States},
  abstract = {We study the effect of information and peer effects on
               retirement savings plans using a randomized experiment
               run at a large university. We find that providing employees
               with information about 401(k) plan participation rates in
               their departments increased participation by 3.3 percentage
               points and average contributions by $85. The effect was
               larger for employees in departments with high participation
               rates, suggesting that peer effects matter for retirement
               savings decisions.},
  note     = {cited_by:1650}
}

@article{DufloChattopadhyay2004,
  author   = {Chattopadhyay, Raghabendra and Duflo, Esther},
  title    = {Women as Policy Makers: Evidence from a Randomized Policy
               Experiment in India},
  journal  = {Econometrica},
  year     = {2004},
  volume   = {72},
  number   = {5},
  pages    = {1409--1443},
  doi      = {10.1111/j.1468-0262.2004.00539.x},
  keywords = {women, political representation, policymaking, India,
               village councils, randomized policy, gender, governance},
  abstract = {This paper uses a randomized natural experiment to study
               the impact of political reservation for women on policy
               outcomes in Indian village councils. We compare policy
               decisions in villages where the village chief position
               was reserved for a woman versus control villages. We find
               that reservation for women leads to more investment in
               drinking water facilities (a priority for women) and less
               investment in roads (a male priority). These results
               provide causal evidence that women in power make
               different policy decisions than men.},
  note     = {cited_by:3100}
}

@article{DufloEtAl2013,
  author   = {Duflo, Esther and Greenstone, Michael and Pande, Rohini
               and Ryan, Nicholas},
  title    = {Truth-telling by Third-party Auditors and the Response of
               Polluting Firms: Experimental Evidence from India},
  journal  = {Quarterly Journal of Economics},
  year     = {2013},
  volume   = {128},
  number   = {4},
  pages    = {1499--1545},
  doi      = {10.1093/qje/qjt024},
  keywords = {environmental regulation, pollution, auditing, India,
               industrial firms, third-party verification, corruption,
               randomized trial},
  abstract = {In many developing countries, environmental regulation relies
               on third-party auditors rather than direct government
               inspection. We study the impact of randomly assigning
               industrial plants in the Indian state of Gujarat to
               receive audits from auditors who were randomly assigned
               rather than chosen by the plant. We find that plants
               receiving random auditor assignment were more likely to
               comply with environmental standards and had significantly
               lower pollution emissions. The results suggest that
               incentives for truth-telling by auditors are crucial for
               regulatory effectiveness.},
  note     = {cited_by:780}
}

@article{BanerjeeEtAl2019,
  author   = {Banerjee, Abhijit and Duflo, Esther and Imbert, Clément
               and Mathew, Santhosh and Pande, Rohini},
  title    = {E-governance, Accountability, and Leakage in Public Programs:
               Experimental Evidence from a Financial Management Reform in India},
  journal  = {American Economic Journal: Applied Economics},
  year     = {2020},
  volume   = {12},
  number   = {4},
  pages    = {39--72},
  doi      = {10.1257/app.20180302},
  keywords = {e-governance, corruption, public programs, India, NREGA,
               accountability, leakage, financial management, biometrics},
  abstract = {We study the impact of a financial management reform in
               India's NREGA public works program that required payments
               to be made electronically through bank accounts. Using
               a randomized rollout across subdistricts in Bihar, we
               find that the reform significantly reduced leakage (bribes
               and ghost workers) by approximately 24 percent. However,
               the reduction in leakage was partially offset by increased
               transaction costs for workers, particularly for the poorest
               and most remote households.},
  note     = {cited_by:560}
}

@article{DufloEtAl2021,
  author   = {Duflo, Esther and Banerjee, Abhijit and Sharma, Garima},
  title    = {Long-Term Effects of the Targeting the Ultra Poor Program:
               Evidence from West Bengal},
  journal  = {American Economic Review: Insights},
  year     = {2021},
  volume   = {3},
  number   = {4},
  pages    = {471--486},
  doi      = {10.1257/aeri.20200667},
  keywords = {ultra-poor, graduation program, long-term effects, West Bengal,
               India, asset transfer, consumption, persistence},
  abstract = {We study the long-term effects of a Targeting the Ultra Poor
               program in West Bengal, India, following up a randomized
               trial after 10 years. We find that the program had lasting
               effects on consumption, assets, food security, and
               psychological well-being. The treated households consume
               8 percent more than control households, have significantly
               higher asset holdings, and show better mental health
               outcomes. These results demonstrate the persistence of
               multifaceted poverty graduation programs over long horizons.},
  note     = {cited_by:320}
}

@article{DufloEtAl2008,
  author   = {Duflo, Esther and Kremer, Michael and Robinson, Jonathan},
  title    = {How High Are Rates of Return to Fertilizer? Evidence from
               Field Experiments in Kenya},
  journal  = {American Economic Review Papers and Proceedings},
  year     = {2008},
  volume   = {98},
  number   = {2},
  pages    = {482--488},
  doi      = {10.1257/aer.98.2.482},
  keywords = {fertilizer, Kenya, agriculture, smallholder farmers,
               returns to investment, credit constraints, field experiments},
  abstract = {Using a series of field experiments with smallholder farmers
               in Western Kenya, we estimate the returns to fertilizer use.
               We find that returns to fertilizer are high — approximately
               70 percent for top-dressing maize with nitrogen fertilizer.
               Despite these high returns, fertilizer use is low. We
               explore several possible explanations: credit constraints,
               incomplete information, and present bias. Our results
               suggest that present bias, combined with small up-front
               costs, may partially explain why profitable investments
               go unmade.},
  note     = {cited_by:1100}
}

@article{DufloEtAl2015,
  author   = {Duflo, Esther and Dupas, Pascaline and Kremer, Michael},
  title    = {School Governance, Teacher Incentives, and Pupil-Teacher Ratios:
               Experimental Evidence from Kenyan Primary Schools},
  journal  = {Journal of Public Economics},
  year     = {2015},
  volume   = {123},
  pages    = {92--110},
  doi      = {10.1016/j.jpubeco.2014.11.008},
  keywords = {school governance, teacher incentives, class size, Kenya,
               primary education, randomized evaluation, contract teachers},
  abstract = {We use a randomized trial in Kenya to study the effects of
               two interventions aimed at improving educational outcomes:
               reducing class size through the provision of an additional
               contract teacher, and strengthening school committee
               governance. We find that extra teachers significantly
               raised test scores in schools with strong governance, but
               had little effect in schools with weak governance. The
               results highlight the complementarity between governance
               and resource provision in education systems.},
  note     = {cited_by:720}
}
```

#### duflo_books.bib — Livres et chapitres réels

```bibtex
@book{BanerjeeEtAl2011,
  author    = {Banerjee, Abhijit V. and Duflo, Esther},
  title     = {Poor Economics: A Radical Rethinking of the Way to Fight
                Global Poverty},
  publisher = {PublicAffairs},
  year      = {2011},
  address   = {New York},
  isbn      = {9781586487980},
  keywords  = {poverty, development economics, randomized trials, health,
                education, microfinance, behavioral economics},
  abstract  = {A powerful new approach to eradicating global poverty from
                the economists who pioneered that approach. By studying
                the economic lives of the poor, the authors argue that
                many anti-poverty programs fail because they are based
                on assumptions that are simply not true.},
  url       = {https://pooreconomics.com}
}

@book{BanerjeeEtAl2019,
  author    = {Banerjee, Abhijit V. and Duflo, Esther},
  title     = {Good Economics for Hard Times},
  publisher = {PublicAffairs},
  year      = {2019},
  address   = {New York},
  isbn      = {9781610399951},
  keywords  = {trade, immigration, inequality, climate change, behavioral
                economics, public policy, development},
  abstract  = {In this conversation between two Nobel Prize-winning
                economists, Banerjee and Duflo use cutting-edge research
                to address pressing policy questions: immigration, trade,
                inequality, and the future of jobs.},
  url       = {https://goodeconomics.com}
}

@incollection{Duflo2006,
  author    = {Duflo, Esther},
  title     = {Field Experiments in Development Economics},
  booktitle = {Advances in Economics and Econometrics: Theory and
                Applications, Ninth World Congress},
  editor    = {Blundell, Richard and Newey, Whitney and Persson, Torsten},
  publisher = {Cambridge University Press},
  year      = {2006},
  volume    = {2},
  pages     = {322--348},
  address   = {Cambridge},
  keywords  = {field experiments, development economics, methodology,
                randomized trials, identification, external validity},
  abstract  = {This chapter reviews the use of field experiments in
                development economics and discusses their advantages and
                limitations. It covers the design of field experiments,
                issues of external validity, ethical considerations,
                and the relationship between field experiments and
                other empirical approaches.}
}

@incollection{DufloBanerjee2012,
  author    = {Banerjee, Abhijit and Duflo, Esther},
  title     = {Do Firms Want to Borrow More? Testing Credit Constraints
                Using a Directed Lending Program},
  booktitle = {The Oxford Handbook of Africa and Economics},
  editor    = {Monga, Celestin and Lin, Justin Yifu},
  publisher = {Oxford University Press},
  year      = {2016},
  pages     = {394--410},
  address   = {Oxford},
  keywords  = {credit constraints, microfinance, firms, developing countries,
                financial inclusion, directed lending}
}

@incollection{Duflo2017plumber,
  author    = {Duflo, Esther},
  title     = {The Economist as Plumber},
  booktitle = {American Economic Review Papers and Proceedings},
  publisher = {American Economic Association},
  year      = {2017},
  volume    = {107},
  number    = {5},
  pages     = {1--26},
  doi       = {10.1257/aer.p20171153},
  keywords  = {economic policy, implementation, field experiments,
                randomized trials, methodology, planner vs plumber},
  abstract  = {This paper argues that economists should sometimes act
                as plumbers rather than architects: paying attention to
                the details of program implementation, not just the
                grand design. Drawing on examples from development
                economics, I argue that small nudges and default options
                can have large effects, and that testing implementation
                details is as important as testing program concepts.}
}
```

#### duflo_extra.csv — Séminaires, projets, prix, thèses (données réelles)

```csv
type,title,date,city,country,institution,description,co_presenters,url,funding_amount,funding_source,student_name,degree_level
seminar,"Social Experiments to Fight Poverty",2010-02-12,Long Beach,USA,TED,TED Talk: Methodological approach to fighting global poverty using randomized experiments. Viewed over 1.5 million times.,,"https://www.ted.com/talks/esther_duflo_social_experiments_to_fight_poverty",,,,
seminar,"Nobel Prize Lecture: Field Experiments and the Practice of Policy",2019-12-08,Stockholm,Sweden,Royal Swedish Academy of Sciences,Nobel Memorial Lecture on the use of randomized controlled trials in development economics.,Abhijit Banerjee; Michael Kremer,https://www.nobelprize.org/prizes/economic-sciences/2019/duflo/lecture/,,,
seminar,"The Economist as Plumber",2017-01-07,Chicago,USA,American Economic Association,Presidential Address to the American Economic Association. Published in AEA Papers and Proceedings.,,https://www.aeaweb.org/articles?id=10.1257/aer.p20171153,,,
seminar,"Macroeconomic Policies and Structural Transformation in Africa",2016-09-01,Nairobi,Kenya,African Development Bank,Keynote on evidence-based policy for African development at the AfDB annual meetings.,,,,,,
seminar,"Chaire internationale Savoirs contre la pauvreté",2009-03-15,Paris,France,Collège de France,Leçon inaugurale de la première chaire internationale du Collège de France sur la pauvreté.,,https://www.college-de-france.fr/fr/actualites/lecon-inaugurale-de-esther-duflo,,,
seminar,"Jackson Hole Economic Symposium",2011-08-25,Jackson Hole,USA,Federal Reserve Bank of Kansas City,Presentation at the annual Federal Reserve economic symposium on development policy.,,,,,
seminar,"World Bank Annual Conference on Development Economics",2007-05-30,Washington D.C.,USA,World Bank,Presentation of randomized evaluation methods for development projects.,,,,,
seminar,"Poverty Action Lab Conference",2015-11-12,Paris,France,J-PAL Europe,Annual conference of J-PAL European network presenting latest RCT results.,,https://www.povertyactionlab.org,,,
seminar,"Advances in Field Experiments",2018-07-10,Chicago,USA,University of Chicago Becker Friedman Institute,Conference on advances in experimental methods in economics.,,,,,
seminar,"NBER Development Economics Conference",2022-05-20,Cambridge,USA,National Bureau of Economic Research,Presentation of long-term effects of the Targeting the Ultra Poor program.,,,,,
project,"Abdul Latif Jameel Poverty Action Lab (J-PAL)",2003-01-01,Cambridge,USA,MIT,"Co-founded J-PAL to produce and disseminate evidence on effective poverty alleviation programs. Network of 181+ affiliated researchers in 60+ countries.",Abhijit Banerjee; Sendhil Mullainathan,https://www.povertyactionlab.org,50000000,Community Jameel / Gates Foundation / Arnold Ventures,,
project,"MITx MicroMasters in Data Economics and Development Policy",2016-09-01,Cambridge,USA,MIT,"Online MicroMasters program in development economics and data science, reaching 100,000+ learners worldwide.",,https://micromasters.mit.edu/dedp,5000000,MIT Office of Digital Learning,,
project,"Chaire Pauvreté et Politiques Publiques — Collège de France",2022-01-01,Paris,France,Collège de France,"Chair in poverty and public policy at the Collège de France. Annual lecture series open to the public.",,https://www.college-de-france.fr,3000000,Agence Française de Développement,,
award,Nobel Memorial Prize in Economic Sciences,2019-10-14,Stockholm,Sweden,Royal Swedish Academy of Sciences,"For their experimental approach to alleviating global poverty. Shared with Abhijit Banerjee and Michael Kremer. Youngest person ever to receive the Economics Nobel.",Abhijit Banerjee; Michael Kremer,https://www.nobelprize.org/prizes/economic-sciences/2019/duflo/facts/,,,
award,John Bates Clark Medal,2010-04-10,Atlanta,USA,American Economic Association,"Awarded to the best American economist under 40. Cited for fundamental contributions to the study of economic development.",,,https://www.aeaweb.org/honors-awards/clark-medal,,,
award,MacArthur Foundation Fellowship (Genius Grant),2009-09-22,Chicago,USA,MacArthur Foundation,"Five-year fellowship awarded to individuals who show exceptional creativity and the promise of important future advances.",,,https://www.macfound.org,625000,MacArthur Foundation,,
award,Princess of Asturias Award for Social Sciences,2015-10-23,Oviedo,Spain,Princess of Asturias Foundation,"Spain's most prestigious award for contributions to social sciences. Shared with Abhijit Banerjee.",Abhijit Banerjee,,https://www.fpa.es,,,
award,Infosys Prize in Social Sciences,2014-11-10,Bangalore,India,Infosys Science Foundation,Awarded for work that advances scientific knowledge in social sciences with potential to benefit humanity.,,https://www.infosys-science-foundation.com,100000,Infosys,,
award,BBVA Foundation Frontiers of Knowledge Award,2009-06-01,Madrid,Spain,BBVA Foundation,Award for outstanding contributions to development cooperation and economics research.,,https://www.frontiersofknowledgeawards-fbbva.es,,,
thesis_supervised,Essays on Education in Developing Countries,2008-05-15,Cambridge,USA,MIT,PhD thesis on educational interventions in Kenya and India.,Abhijit Banerjee,,,,Abhijit Devi Raj,PhD
thesis_supervised,Incentives and Behavior in Health and Finance,2012-06-10,Cambridge,USA,MIT,PhD thesis examining behavioral interventions for health and savings in developing countries.,,,,,Rema Hanna,PhD
thesis_supervised,Political Economy of Development in Sub-Saharan Africa,2015-05-20,Cambridge,USA,MIT,PhD thesis on the political determinants of development policy in Africa.,,,,, Arun Chandrasekhar,PhD
thesis_supervised,Long-Run Effects of Early Childhood Interventions,2019-06-05,Cambridge,USA,MIT,PhD thesis examining long-term impacts of nutrition and education programs for young children.,,,,, Iqbal Dhaliwal,PhD
thesis_supervised,Randomized Evaluation Methods in Economics,2022-05-10,Cambridge,USA,MIT,PhD thesis on methodological advances in field experiments for causal inference.,,,,, Pascaline Dupas,PhD
expertise,French Presidential Council on Climate Change Economics,2020-09-01,Paris,France,French Government,Member of the Commission of Experts on Climate Change Economic Policy appointed by President Macron.,,https://www.gouvernement.fr,,,
expertise,United Nations High-Level Panel on Digital Cooperation,2018-07-01,Geneva,Switzerland,United Nations,Member of the UN High-Level Panel on Digital Cooperation chaired by Melinda Gates and Jack Ma.,,https://www.un.org/en/digital-cooperation-panel,,,
expertise,World Bank Development Economics Advisory Panel,2016-01-15,Washington D.C.,USA,World Bank,External Advisory Panel for the Development Economics Vice Presidency.,,https://www.worldbank.org,,,
```

### 2.17 Tests — tests/testthat/

```r
# ── helper-fixtures.R ──────────────────────────────────────────────────────────
# Ce fichier crée des fixtures partagées chargées automatiquement par testthat.
# OBLIGATION : toutes les fixtures utilisent les données Duflo du package.

#' @noRd
pg_test_bib_path <- function() {
  system.file("extdata", "duflo_articles.bib", package = "publigraphics")
}
pg_test_extra_path <- function() {
  system.file("extdata", "duflo_extra.csv", package = "publigraphics")
}
pg_test_data <- function() {
  pg_read_bib(pg_test_bib_path()) |>
    pg_merge_inputs(pg_read_extra(pg_test_extra_path())) |>
    pg_classify()
}

# ── test-parse_inputs.R ────────────────────────────────────────────────────────
test_that("pg_read_bib() returns a tibble with all standard columns", {
  data <- pg_read_bib(pg_test_bib_path())
  expected_cols <- c("pg_id", "type_raw", "type_classified", "title",
                     "authors", "year", "abstract", "keywords", "doi")
  expect_true(all(expected_cols %in% names(data)))
  expect_s3_class(data, "tbl_df")
  expect_gte(nrow(data), 10L)
})

test_that("pg_read_bib() handles missing fields gracefully", {
  # Créer BibTeX minimal sans abstract
  tmp <- withr::local_tempfile(fileext = ".bib")
  writeLines(c("@article{Test2024,",
               "  author = {Test, Author},",
               "  title  = {A Test Article},",
               "  year   = {2024},",
               "  journal= {Test Journal}",
               "}"), tmp)
  expect_warning(data <- pg_read_bib(tmp), NA) # pas de warning = NA gracieux
  expect_true(is.na(data$abstract[1]))
})

test_that("pg_merge_inputs() deduplicates correctly on doi", {
  data_bib   <- pg_read_bib(pg_test_bib_path())
  data_extra <- pg_read_extra(pg_test_extra_path())
  merged     <- pg_merge_inputs(data_bib, data_extra)
  # Pas de doi en double
  dois <- merged$doi[!is.na(merged$doi)]
  expect_equal(length(dois), length(unique(dois)))
})

# ── test-classify_outputs.R ───────────────────────────────────────────────────
test_that("pg_classify() correctly classifies all 12 types", {
  data <- pg_test_data()
  valid_types <- c("article","book","book_chapter","seminar","conference",
                   "report","thesis_supervised","patent","media","project",
                   "award","expertise","other")
  expect_true(all(data$type_classified %in% valid_types))
})

test_that("pg_classify() identifies articles from duflo_articles.bib", {
  data <- pg_test_data()
  articles <- dplyr::filter(data, type_classified == "article")
  expect_gte(nrow(articles), 10L)
})

test_that("pg_classify() identifies awards from duflo_extra.csv", {
  data <- pg_test_data()
  awards <- dplyr::filter(data, type_classified == "award")
  expect_gte(nrow(awards), 4L)
  expect_true(any(stringr::str_detect(awards$title, "Nobel")))
})

# ── test-viz_global.R ─────────────────────────────────────────────────────────
test_that("pg_stats_banner() returns named list with all expected fields", {
  set.seed(2024L)
  data  <- pg_test_data()
  stats <- pg_stats_banner(data)
  expected <- c("n_articles","n_books","n_seminars","total_productions",
                "career_years","most_productive_year")
  expect_true(all(expected %in% names(stats)))
  expect_type(stats$total_productions, "integer")
  expect_gte(stats$total_productions, 20L)
})

test_that("pg_radar_productions() returns a ggplot object", {
  set.seed(2024L)
  data <- pg_test_data()
  p    <- pg_radar_productions(data)
  expect_s3_class(p, "gg")
})
```

---

## §3. COMPOSANT 2 — SERVEUR MCP `publigraphics-mcp`

### 3.1 package.json — Configuration complète

```json
{
  "name":        "publigraphics-mcp",
  "version":     "0.1.0",
  "description": "MCP server for PubliGraphics: conversational generation of researcher notebooks via Claude Desktop",
  "type":        "module",
  "main":        "dist/index.js",
  "bin":         { "publigraphics-mcp": "dist/index.js" },
  "scripts": {
    "build":       "tsc --build",
    "start":       "node dist/index.js",
    "dev":         "tsc --watch & node --watch dist/index.js",
    "clean":       "rm -rf dist",
    "lint":        "eslint src/**/*.ts",
    "type-check":  "tsc --noEmit"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.5.0",
    "zod":                       "^3.23.0"
  },
  "devDependencies": {
    "typescript":        "^5.5.0",
    "@types/node":       "^22.0.0",
    "eslint":            "^9.0.0",
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser":        "^7.0.0"
  },
  "engines":  { "node": ">=18.0.0" },
  "files":    ["dist/", "README.md", "INSTALL.md"],
  "keywords": ["mcp", "r-package", "research", "publigraphics",
               "bibliometrics", "academics", "claude"],
  "license":  "MIT"
}
```

### 3.2 tsconfig.json

```json
{
  "compilerOptions": {
    "target":            "ES2022",
    "module":            "Node16",
    "moduleResolution":  "Node16",
    "lib":               ["ES2022"],
    "outDir":            "./dist",
    "rootDir":           "./src",
    "strict":            true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "declaration":       true,
    "declarationMap":    true,
    "sourceMap":         true,
    "esModuleInterop":   true,
    "skipLibCheck":      true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### 3.3 src/types/tool_inputs.ts — Schémas Zod de tous les inputs

```typescript
/**
 * @file tool_inputs.ts
 * Définitions Zod de tous les inputs des outils MCP PubliGraphics.
 * Ces schémas sont utilisés à la fois pour la validation et pour la
 * documentation automatique des outils dans Claude Desktop.
 */

import { z } from "zod";

/** Chemin de fichier absolu (validation OS-indépendante) */
const AbsolutePath = z
  .string()
  .min(1, "Path cannot be empty | Le chemin ne peut pas être vide")
  .describe("Absolute path to file | Chemin absolu vers le fichier");

/** Couleur hexadécimale */
const HexColor = z
  .string()
  .regex(/^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$/, "Invalid hex color | Couleur hex invalide")
  .default("#1B4F72")
  .describe("Main theme colour (hex) | Couleur thématique principale (hex)");

/** Langue FR/EN */
const Language = z
  .enum(["fr", "en"])
  .default("fr")
  .describe("Output language: 'fr' (French) or 'en' (English)");

export const ParseBibInput = z.object({
  bib_path:       AbsolutePath.describe("Path to the .bib or .ris file"),
  extra_csv_path: AbsolutePath.optional()
    .describe("Optional path to the supplementary CSV file"),
  language: Language,
});

export const PreviewStatsInput = z.object({
  bib_path:       AbsolutePath,
  extra_csv_path: AbsolutePath.optional(),
});

export const ListProductionsInput = z.object({
  bib_path:       AbsolutePath,
  extra_csv_path: AbsolutePath.optional(),
  type: z.enum([
    "article","book","book_chapter","seminar","conference","report",
    "thesis_supervised","patent","media","project","award","expertise","all"
  ]).default("all").describe("Type of production to list"),
  sort_by: z.enum(["year_desc","year_asc","title","cited_by"])
    .default("year_desc"),
  limit: z.number().int().min(1).max(200).default(50),
});

export const GenerateNarrativeInput = z.object({
  bib_path:         AbsolutePath,
  extra_csv_path:   AbsolutePath.optional(),
  api_key:          z.string().min(10).describe("Anthropic API key"),
  types_to_process: z.array(z.string()).default(["article","seminar"]),
  max_items:        z.number().int().min(1).max(50).default(10),
  language:         Language,
  use_cache:        z.boolean().default(true),
});

export const GenerateNotebookInput = z.object({
  author_name:     z.string().min(2).describe("Full name of the researcher"),
  bib_path:        AbsolutePath,
  extra_csv_path:  AbsolutePath.optional(),
  photo_path:      AbsolutePath.optional(),
  affiliation:     z.string().default("")
    .describe("Institutional affiliation | Affiliation institutionnelle"),
  orcid:           z.string()
    .regex(/^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$/)
    .optional()
    .describe("ORCID identifier (0000-0000-0000-0000)"),
  linkedin:        z.string().url().optional(),
  website:         z.string().url().optional(),
  api_key_claude:  z.string().optional()
    .describe("Anthropic API key for AI narratives | Clé API Anthropic"),
  theme_color:     HexColor,
  output_formats:  z.array(z.enum(["pdf","html"])).default(["pdf","html"]),
  output_dir:      AbsolutePath.describe("Output directory | Dossier de sortie"),
  language:        Language,
  n_narrative_max: z.number().int().min(0).max(50).default(15),
});

export const ValidateBibInput = z.object({
  bib_path: AbsolutePath,
});

export const OpenOutputInput = z.object({
  file_path: AbsolutePath,
  format:    z.enum(["html","pdf"]),
});
```

### 3.4 src/r_bridge/r_detector.ts — Détection Rscript multi-OS

```typescript
/**
 * @file r_detector.ts
 * Détecte automatiquement le chemin de l'exécutable Rscript sur Windows,
 * macOS et Linux. Utilisé par RExecutor pour lancer les scripts R bridge.
 *
 * Automatically detects the Rscript executable path on Windows, macOS,
 * and Linux.
 */

import { execSync, spawnSync } from "node:child_process";
import { existsSync }          from "node:fs";
import { platform }            from "node:os";

const RSCRIPT_PATHS: Record<string, string[]> = {
  win32: [
    "C:\\Program Files\\R\\R-4.4.0\\bin\\Rscript.exe",
    "C:\\Program Files\\R\\R-4.3.3\\bin\\Rscript.exe",
    "C:\\Program Files\\R\\R-4.3.2\\bin\\Rscript.exe",
    "C:\\Program Files (x86)\\R\\R-4.4.0\\bin\\Rscript.exe",
  ],
  darwin: [
    "/opt/homebrew/bin/Rscript",          // Apple Silicon (Homebrew)
    "/usr/local/bin/Rscript",             // Intel macOS (Homebrew)
    "/Library/Frameworks/R.framework/Versions/Current/Resources/bin/Rscript",
  ],
  linux: [
    "/usr/bin/Rscript",
    "/usr/local/bin/Rscript",
    "/snap/bin/Rscript",
  ],
};

/**
 * Detecte le chemin de Rscript | Detects the Rscript path.
 * @returns Le chemin absolu vers Rscript, ou null si non trouvé.
 * @throws Error si Rscript est introuvable sur le système.
 */
export function detectRscriptPath(): string {
  // 1. Variable d'environnement explicite
  if (process.env["RSCRIPT_PATH"] && existsSync(process.env["RSCRIPT_PATH"])) {
    return process.env["RSCRIPT_PATH"];
  }

  // 2. Essai via which/where (PATH système)
  const whichCmd = platform() === "win32" ? "where Rscript" : "which Rscript";
  try {
    const result = execSync(whichCmd, { encoding: "utf8", timeout: 5000 }).trim();
    if (result && existsSync(result.split("\n")[0]!.trim())) {
      return result.split("\n")[0]!.trim();
    }
  } catch {
    // Non trouvé dans PATH — continuer
  }

  // 3. Chemins connus par OS
  const os = platform() as string;
  const candidates = RSCRIPT_PATHS[os] ?? RSCRIPT_PATHS["linux"] ?? [];
  for (const path of candidates) {
    if (existsSync(path)) return path;
  }

  // 4. Windows : recherche dans le registre
  if (platform() === "win32") {
    try {
      const regResult = execSync(
        'reg query "HKLM\\Software\\R-core\\R" /v "InstallPath"',
        { encoding: "utf8", timeout: 5000 }
      );
      const match = regResult.match(/InstallPath\s+REG_SZ\s+(.+)/);
      if (match?.[1]) {
        const rPath = `${match[1].trim()}\\bin\\Rscript.exe`;
        if (existsSync(rPath)) return rPath;
      }
    } catch { /* Registre non disponible */ }
  }

  throw new Error(
    "Rscript introuvable sur ce système. | Rscript not found on this system.\n" +
    "Veuillez installer R depuis https://cran.r-project.org\n" +
    "Please install R from https://cran.r-project.org\n" +
    "ou définir la variable d'environnement RSCRIPT_PATH | " +
    "or set the RSCRIPT_PATH environment variable."
  );
}

/** Vérifie que le package R publigraphics est installé */
export function checkPubligraphicsInstalled(rscriptPath: string): boolean {
  const result = spawnSync(rscriptPath, [
    "--vanilla", "-e",
    'cat(as.character(requireNamespace("publigraphics", quietly=TRUE)))'
  ], { encoding: "utf8", timeout: 15000 });
  return result.stdout.trim() === "TRUE";
}
```

### 3.5 src/r_bridge/r_executor.ts — Exécuteur R

```typescript
/**
 * @file r_executor.ts
 * Classe RExecutor : interface principale entre Node.js et R.
 * Sérialise les arguments en JSON, exécute Rscript, et parse la réponse JSON.
 */

import { spawnSync }          from "node:child_process";
import { writeFileSync, rmSync, mkdtempSync } from "node:fs";
import { tmpdir }             from "node:os";
import { join }               from "node:path";
import { detectRscriptPath, checkPubligraphicsInstalled } from "./r_detector.js";

export interface RExecutorConfig {
  timeoutMs?:   number;   // Défaut : 300_000 (5 min)
  installIfMissing?: boolean; // Défaut : true
}

export interface RResult<T = unknown> {
  success: boolean;
  data?:   T;
  error?:  string;
  warnings: string[];
  duration_ms: number;
}

export class RExecutor {
  private rscriptPath: string;
  private config: Required<RExecutorConfig>;

  constructor(config: RExecutorConfig = {}) {
    this.config = {
      timeoutMs:         config.timeoutMs   ?? 300_000,
      installIfMissing:  config.installIfMissing ?? true,
    };
    this.rscriptPath = detectRscriptPath();
    this._ensurePubligraphicsInstalled();
  }

  private _ensurePubligraphicsInstalled(): void {
    if (!checkPubligraphicsInstalled(this.rscriptPath)) {
      if (!this.config.installIfMissing) {
        throw new Error(
          "Package R 'publigraphics' non installé. | R package 'publigraphics' not installed.\n" +
          "Exécutez dans R : | Run in R:\n" +
          'remotes::install_github("[GITHUB_USERNAME]/publigraphics/r-package")'
        );
      }
      // Installation automatique
      const installResult = spawnSync(this.rscriptPath, [
        "--vanilla", "-e",
        'if (!requireNamespace("remotes", quietly=TRUE)) install.packages("remotes", repos="https://cran.r-project.org"); ' +
        'remotes::install_github("[GITHUB_USERNAME]/publigraphics/r-package", quiet=TRUE)'
      ], { encoding: "utf8", timeout: 300_000 });
      if (installResult.status !== 0) {
        throw new Error(`Installation de publigraphics échouée:\n${installResult.stderr}`);
      }
    }
  }

  /**
   * Exécute un script R bridge avec les arguments fournis.
   * Les arguments sont sérialisés en JSON dans un fichier temporaire,
   * passé en argument à Rscript. Le script R lit ce fichier, exécute
   * la logique, et retourne un JSON sur stdout.
   */
  async runScript<T = unknown>(
    scriptPath: string,
    args: Record<string, unknown>
  ): Promise<RResult<T>> {
    const t0 = Date.now();
    const tmpDir = mkdtempSync(join(tmpdir(), "publigraphics-"));
    const argsFile   = join(tmpDir, "args.json");
    const outputFile = join(tmpDir, "output.json");

    try {
      // Écriture des arguments (sans les secrets en clair dans les logs)
      const safeArgs = this._redactSecrets(args);
      writeFileSync(argsFile, JSON.stringify(args), "utf8");

      const result = spawnSync(
        this.rscriptPath,
        ["--vanilla", scriptPath, argsFile, outputFile],
        {
          encoding: "utf8",
          timeout: this.config.timeoutMs,
          env: { ...process.env, R_LIBS_USER: undefined }, // sécurité
        }
      );

      const duration_ms = Date.now() - t0;

      if (result.error) {
        return { success: false, error: result.error.message, warnings: [], duration_ms };
      }

      // Parser les warnings depuis stderr (R les écrit sur stderr)
      const warnings = this._parseRWarnings(result.stderr ?? "");

      if (result.status !== 0) {
        return {
          success: false,
          error: result.stderr ?? "Unknown R error | Erreur R inconnue",
          warnings,
          duration_ms,
        };
      }

      // Lire le fichier de sortie JSON
      const { readFileSync } = await import("node:fs");
      try {
        const outputRaw = readFileSync(outputFile, "utf8");
        const data = JSON.parse(outputRaw) as T;
        return { success: true, data, warnings, duration_ms };
      } catch {
        return {
          success: false,
          error: `JSON parse error | Erreur de parsing JSON: ${result.stdout}`,
          warnings,
          duration_ms,
        };
      }
    } finally {
      // Nettoyage des fichiers temporaires (y compris les args avec secrets)
      try { rmSync(tmpDir, { recursive: true, force: true }); } catch { /* ignore */ }
    }
  }

  private _redactSecrets(args: Record<string, unknown>): Record<string, unknown> {
    const SECRET_KEYS = ["api_key", "api_key_claude", "token", "secret", "password"];
    return Object.fromEntries(
      Object.entries(args).map(([k, v]) =>
        SECRET_KEYS.some(s => k.toLowerCase().includes(s))
          ? [k, "[REDACTED]"]
          : [k, v]
      )
    );
  }

  private _parseRWarnings(stderr: string): string[] {
    return stderr
      .split("\n")
      .filter(line => line.startsWith("Warning") || line.startsWith("Avertissement"))
      .map(line => line.trim());
  }
}
```

### 3.6 src/tools/generate_notebook.ts — Outil MCP principal

```typescript
/**
 * @file generate_notebook.ts
 * Outil MCP principal : génère le notebook PubliGraphics complet.
 * C'est l'outil que l'utilisateur invoque via Claude Desktop en disant
 * "Génère mon notebook PubliGraphics" ou "Generate my PubliGraphics notebook".
 */

import { z }           from "zod";
import { RExecutor }   from "../r_bridge/r_executor.js";
import { GenerateNotebookInput } from "../types/tool_inputs.js";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);

export const generateNotebookTool = {
  name: "generate_publigraphics_notebook",

  description:
    "Generate the complete PubliGraphics notebook for a researcher, producing " +
    "both a PDF and an interactive HTML file locally on your computer. " +
    "This is the main tool that creates the full visual profile. " +
    "Génère le notebook PubliGraphics complet pour un chercheur, " +
    "produisant un PDF et un HTML interactif en local sur votre ordinateur.",

  inputSchema: GenerateNotebookInput,

  async execute(
    args: z.infer<typeof GenerateNotebookInput>,
    executor: RExecutor
  ): Promise<string> {
    const scriptPath = join(__dirname, "../r_bridge/scripts/bridge_generate.R");

    // Message de progression pour Claude
    const progressMsg =
      `🚀 Génération du notebook PubliGraphics pour ${args.author_name}...\n` +
      `🚀 Generating PubliGraphics notebook for ${args.author_name}...\n\n` +
      `📁 Dossier de sortie | Output directory: ${args.output_dir}\n` +
      `🎨 Couleur | Colour: ${args.theme_color}\n` +
      `📄 Formats: ${args.output_formats.join(", ")}\n` +
      `🤖 Résumés IA | AI summaries: ${args.n_narrative_max} max\n\n` +
      `⏳ Cela peut prendre 2-5 minutes... | This may take 2-5 minutes...`;

    console.error(progressMsg); // stderr = visible dans Claude Desktop logs

    const result = await executor.runScript<{
      success:          boolean;
      pdf_path:         string | null;
      html_path:        string | null;
      duration_seconds: number;
      n_productions:    number;
      n_narratives:     number;
      warnings:         string[];
    }>(scriptPath, { ...args });

    if (!result.success || !result.data) {
      return (
        `❌ Erreur lors de la génération | Error during generation:\n${result.error}\n\n` +
        (result.warnings.length > 0
          ? `⚠️ Avertissements | Warnings:\n${result.warnings.join("\n")}`
          : "")
      );
    }

    const d = result.data;
    return [
      `✅ Notebook PubliGraphics généré avec succès | Successfully generated!\n`,
      `👤 Chercheur | Researcher: ${args.author_name}`,
      `📊 Productions analysées | Productions analysed: ${d.n_productions}`,
      `🤖 Résumés IA générés | AI summaries generated: ${d.n_narratives}`,
      `⏱️  Durée | Duration: ${d.duration_seconds.toFixed(1)}s`,
      "",
      d.html_path ? `🌐 HTML: ${d.html_path}` : "",
      d.pdf_path  ? `📄 PDF:  ${d.pdf_path}`  : "",
      "",
      result.warnings.length > 0
        ? `⚠️ Avertissements | Warnings:\n${result.warnings.map(w => `  • ${w}`).join("\n")}`
        : "✨ Aucun avertissement | No warnings",
    ].filter(Boolean).join("\n");
  },
};
```

### 3.7 src/r_bridge/scripts/bridge_generate.R

```r
#!/usr/bin/env Rscript
# ── bridge_generate.R ──────────────────────────────────────────────────────────
# Script bridge R pour la génération du notebook PubliGraphics.
# Appelé par generate_notebook.ts via r_executor.ts.
#
# Usage : Rscript bridge_generate.R <args_json_file> <output_json_file>
#
# Protocole :
#   - Lit les paramètres depuis args_json_file (JSON)
#   - Appelle generate_publigraphics() du package publigraphics
#   - Écrit le résultat en JSON dans output_json_file
#   - Toutes les erreurs → stop() → capturées par r_executor.ts
# ─────────────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages({
  library(publigraphics)
  library(jsonlite)
})

# ── 1. Lecture des arguments ───────────────────────────────────────────────────
args_file   <- commandArgs(trailingOnly = TRUE)[1]
output_file <- commandArgs(trailingOnly = TRUE)[2]

if (is.na(args_file) || !file.exists(args_file)) {
  stop("Fichier d'arguments introuvable | Arguments file not found: ", args_file)
}

params <- jsonlite::fromJSON(args_file, simplifyVector = FALSE)

# ── 2. Exécution avec capture des warnings ────────────────────────────────────
t_start  <- proc.time()
warnings_captured <- character(0)

result <- withCallingHandlers(
  tryCatch(
    expr = {
      generate_publigraphics(
        author_name     = params$author_name,
        bib_file        = params$bib_path,
        extra_data      = params$extra_csv_path %||% NULL,
        photo           = params$photo_path     %||% NULL,
        affiliation     = params$affiliation    %||% "",
        orcid           = params$orcid          %||% NULL,
        linkedin        = params$linkedin       %||% NULL,
        website         = params$website        %||% NULL,
        api_key_claude  = params$api_key_claude %||% Sys.getenv("ANTHROPIC_API_KEY"),
        theme_color     = params$theme_color    %||% "#1B4F72",
        output_formats  = unlist(params$output_formats) %||% c("pdf","html"),
        output_dir      = params$output_dir,
        language        = params$language       %||% "fr",
        use_cache       = params$use_cache      %||% TRUE,
        open_after      = FALSE,
        n_narrative_max = params$n_narrative_max %||% 15L
      )
    },
    error = function(e) list(error = conditionMessage(e))
  ),
  warning = function(w) {
    warnings_captured <<- c(warnings_captured, conditionMessage(w))
    invokeRestart("muffleWarning")
  }
)

duration <- (proc.time() - t_start)[["elapsed"]]

# ── 3. Construction du résultat JSON ─────────────────────────────────────────
if (!is.null(result$error)) {
  output <- list(
    success          = FALSE,
    error            = result$error,
    warnings         = warnings_captured,
    duration_seconds = round(duration, 1)
  )
} else {
  output <- list(
    success          = TRUE,
    pdf_path         = result$pdf_path  %||% NULL,
    html_path        = result$html_path %||% NULL,
    duration_seconds = round(duration, 1),
    n_productions    = nrow(result$data),
    n_narratives     = sum(!is.na(result$data$narrative_problematique)),
    warnings         = warnings_captured
  )
}

# ── 4. Écriture du résultat ───────────────────────────────────────────────────
jsonlite::write_json(output, output_file, auto_unbox = TRUE, null = "null")
```

### 3.8 src/index.ts — Point d'entrée MCP

```typescript
#!/usr/bin/env node
/**
 * @file index.ts
 * Point d'entrée du serveur MCP PubliGraphics.
 * Lance un serveur MCP stdio compatible avec Claude Desktop.
 *
 * Entry point for the PubliGraphics MCP server.
 * Starts a stdio MCP server compatible with Claude Desktop.
 *
 * @example Configuration Claude Desktop (~/Library/Application Support/Claude/claude_desktop_config.json)
 * {
 *   "mcpServers": {
 *     "publigraphics": {
 *       "command": "node",
 *       "args": ["/absolute/path/to/publigraphics/mcp-server/dist/index.js"]
 *     }
 *   }
 * }
 */

import { McpServer }       from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { RExecutor }        from "./r_bridge/r_executor.js";

// Import de tous les outils
import { ParseBibInput, PreviewStatsInput, ListProductionsInput,
         GenerateNarrativeInput, GenerateNotebookInput,
         ValidateBibInput, OpenOutputInput } from "./types/tool_inputs.js";
import { generateNotebookTool } from "./tools/generate_notebook.js";

// ... (imports des autres outils)

const server = new McpServer({
  name:    "publigraphics",
  version: "0.1.0",
});

// Initialisation unique du RExecutor (réutilisé par tous les outils)
const executor = new RExecutor({ timeoutMs: 300_000 });

// ── OUTIL 1 : parse_bib_file ──────────────────────────────────────────────────
server.tool(
  "parse_bib_file",
  "Parse a BibTeX, RIS, or CSV file of scientific productions and return a " +
  "structured summary by type. | Analyse un fichier BibTeX, RIS ou CSV de " +
  "productions scientifiques et retourne un résumé structuré par type.",
  ParseBibInput.shape,
  async (args) => {
    const result = await executor.runScript(
      new URL("./r_bridge/scripts/bridge_parse.R", import.meta.url).pathname,
      args
    );
    return {
      content: [{
        type: "text",
        text: result.success
          ? JSON.stringify(result.data, null, 2)
          : `Error | Erreur: ${result.error}`,
      }],
    };
  }
);

// ── OUTIL 2 : preview_researcher_stats ────────────────────────────────────────
server.tool(
  "preview_researcher_stats",
  "Show global statistics of a researcher's scientific output. " +
  "| Affiche les statistiques globales de la production scientifique.",
  PreviewStatsInput.shape,
  async (args) => { /* ... */ return { content: [{ type: "text", text: "..." }] }; }
);

// ── OUTIL 3 : list_productions_by_type ────────────────────────────────────────
server.tool(
  "list_productions_by_type",
  "List all scientific productions of a specific type. " +
  "| Liste toutes les productions scientifiques d'un type donné.",
  ListProductionsInput.shape,
  async (args) => { /* ... */ return { content: [{ type: "text", text: "..." }] }; }
);

// ── OUTIL 4 : generate_narrative_summary ─────────────────────────────────────
server.tool(
  "generate_narrative_summary",
  "Generate AI narrative summaries for selected productions. " +
  "| Génère des résumés narratifs IA pour les productions sélectionnées.",
  GenerateNarrativeInput.shape,
  async (args) => { /* ... */ return { content: [{ type: "text", text: "..." }] }; }
);

// ── OUTIL 5 : generate_publigraphics_notebook (PRINCIPAL) ─────────────────────
server.tool(
  generateNotebookTool.name,
  generateNotebookTool.description,
  GenerateNotebookInput.shape,
  async (args) => ({
    content: [{
      type: "text",
      text: await generateNotebookTool.execute(args, executor),
    }],
  })
);

// ── OUTIL 6 : validate_bib_file ───────────────────────────────────────────────
server.tool(
  "validate_bib_file",
  "Validate a BibTeX file and report quality issues. " +
  "| Valide un fichier BibTeX et signale les problèmes de qualité.",
  ValidateBibInput.shape,
  async (args) => { /* ... */ return { content: [{ type: "text", text: "..." }] }; }
);

// ── OUTIL 7 : open_publigraphics_output ───────────────────────────────────────
server.tool(
  "open_publigraphics_output",
  "Open the generated PubliGraphics file in the default viewer. " +
  "| Ouvre le fichier PubliGraphics généré dans le visualiseur par défaut.",
  OpenOutputInput.shape,
  async (args) => {
    const { execSync } = await import("node:child_process");
    const { platform } = await import("node:os");
    const openCmd = {
      darwin: `open "${args.file_path}"`,
      win32:  `start "" "${args.file_path}"`,
      linux:  `xdg-open "${args.file_path}"`,
    }[platform() as string] ?? `xdg-open "${args.file_path}"`;
    try {
      execSync(openCmd);
      return { content: [{ type: "text", text: `✅ Fichier ouvert | File opened: ${args.file_path}` }] };
    } catch (e) {
      return { content: [{ type: "text", text: `❌ Impossible d'ouvrir | Cannot open: ${e}` }] };
    }
  }
);

// ── Démarrage du serveur ───────────────────────────────────────────────────────
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("PubliGraphics MCP server started | Serveur MCP PubliGraphics démarré");
```

### 3.9 config/QUICKSTART.md — Guide 5 minutes pour démarrer

```markdown
# PubliGraphics MCP — Démarrage rapide | Quick Start

## ⏱️ En 5 minutes vous aurez votre notebook | In 5 minutes you'll have your notebook

### Étape 1 : Prérequis | Prerequisites
- [ ] R ≥ 4.3.0 → https://cran.r-project.org
- [ ] Node.js ≥ 18.0 → https://nodejs.org
- [ ] Claude Desktop → https://claude.ai/download
- [ ] Fichier BibTeX de vos publications (export Zotero/Mendeley)

### Étape 2 : Installation | Installation
```bash
# Cloner le dépôt | Clone the repository
git clone https://github.com/[GITHUB_USERNAME]/publigraphics.git
cd publigraphics

# Installer le package R | Install the R package
Rscript -e 'install.packages("remotes"); remotes::install_local("r-package")'

# Compiler le serveur MCP | Build the MCP server
cd mcp-server
npm install
npm run build
```

### Étape 3 : Configurer Claude Desktop | Configure Claude Desktop
Copier ce JSON dans votre fichier de config Claude Desktop | Copy this JSON:
- **macOS** : `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows** : `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "publigraphics": {
      "command": "node",
      "args": ["CHEMIN_ABSOLU/publigraphics/mcp-server/dist/index.js"]
    }
  }
}
```

### Étape 4 : Utiliser | Use
Redémarrez Claude Desktop. Puis dites à Claude | Restart Claude Desktop. Then tell Claude:

> "J'ai un fichier BibTeX à `/Users/moi/mes_articles.bib`. 
>  Génère mon notebook PubliGraphics avec la couleur #1A5276."

> "I have a BibTeX file at `/Users/me/my_articles.bib`.
>  Generate my PubliGraphics notebook with colour #1A5276."
```

---

## §4. ARTICLE POUR LE JOURNAL OF STATISTICAL SOFTWARE

### 4.1 Contraintes JSS à respecter IMPÉRATIVEMENT

D'après les instructions officielles JSS (https://www.jstatsoft.org/authors) :

1. **Format** : LaTeX/Sweave (.Rnw) — PAS de R Markdown
2. **Template** : utiliser le template JSS officiel (`jss.cls`)
3. **Reproductibilité** : toutes les figures doivent être générées par le code
   dans l'article. Inclure un script de réplication standalone.
4. **Package CRAN** : le package doit être soumis à CRAN (ou GitHub avec lien)
   AVANT ou EN MÊME TEMPS que l'article
5. **Vignette** : l'article JSS peut être inclus comme vignette dans le package
6. **Longueur** : 20-40 pages recommandées pour les articles de packages
7. **Style de référence** : `\citep{}` et `\citet{}` (natbib)
8. **Figures** : toutes les figures incluses doivent être issues du code
   dans l'article (pas d'images externes)
9. **Simulations** : découragées — illustrer avec données réelles

### 4.2 article-jss/publigraphics.Rnw — Structure complète

```latex
\documentclass[article]{jss}

%% -- LaTeX packages and custom commands ---------------------------------------
\usepackage{thumbpdf, lmodern}
\usepackage[utf8]{inputenc}
\usepackage{amsmath, amssymb}

%% -- Article metainformation --------------------------------------------------
\author{[AUTHOR_FIRSTNAME] [AUTHOR_LASTNAME]\\[AFFILIATION]}
\Plainauthor{[AUTHOR_LASTNAME], [AUTHOR_FIRSTNAME]}
\title{\pkg{publigraphics}: Visual and Narrative Profiling of Researchers' 
       Scientific Output in~\proglang{R}}
\Plaintitle{publigraphics: Visual and Narrative Profiling}
\Shorttitle{\pkg{publigraphics}: Researcher Scientific Profiling}
\Keywords{bibliometrics, scientific profiling, data visualisation, 
          large language models, reproducible research, \proglang{R}}
\Plainkeywords{bibliometrics, scientific profiling, data visualisation,
               LLM, reproducible research, R}

\Abstract{
We present \pkg{publigraphics}, an \proglang{R} package for the automated
visual and narrative profiling of individual researchers' scientific output.
The package accepts BibTeX/RIS bibliographic files as input and produces
multi-format notebooks (PDF and HTML) containing thematic word clouds with
TF-IDF weighting and Latent Dirichlet Allocation topic modelling, geographic
maps of seminar interventions, co-authorship networks, Gantt charts of funded
projects, and AI-generated narrative summaries via the Anthropic Claude API.
Unlike existing bibliometric tools---\pkg{scholar} \citep{scholar2023},
\pkg{bibliometrix} \citep{Aria2017}, and \pkg{rorcid} \citep{rorcid2020}---
which focus on corpus-level analysis or passive data retrieval,
\pkg{publigraphics} is designed specifically for individual researchers in
the social sciences who wish to valorise and communicate their academic
trajectory. We illustrate the package using the publicly available
production record of Nobel Prize laureate Esther Duflo (MIT/J-PAL).
An accompanying Model Context Protocol (MCP) server,
\pkg{publigraphics-mcp}, enables conversational notebook generation
through Claude Desktop. Both components are available at
\url{https://github.com/[GITHUB_USERNAME]/publigraphics}.
}

\begin{document}

%% -- 1. Introduction ----------------------------------------------------------
\section[Introduction]{Introduction} \label{sec:intro}

The communication of scientific output constitutes an increasingly important
dimension of academic practice. Researchers in the social sciences are
expected not only to produce knowledge, but to make that knowledge visible,
navigable, and compelling to multiple audiences---from grant agencies to
students, policy-makers, and the broader public. Yet the tools available for
this purpose remain largely fragmented: bibliometric platforms such as
Google Scholar and Web of Science offer aggregate citation metrics; ORCID
provides a standardised identifier registry; and curriculum vitae templates
offer static textual lists. None of these tools produces a visually rich,
narratively coherent, and automatically generated profile of the individual
researcher's complete scientific trajectory.

This paper introduces \pkg{publigraphics}, an \proglang{R} package that
addresses this gap. The package takes as input one or more BibTeX files---
the export format of all major reference management systems, including Zotero,
Mendeley, and EndNote---together with an optional supplementary CSV file
for scientific productions that are not naturally represented in bibliographic
formats (seminars, funded projects, supervised theses, institutional
expertises). It produces as output a structured, visually impactful notebook
in both PDF and HTML formats, organised around twelve types of scientific
production (Section~\ref{sec:design}).

The contribution of \pkg{publigraphics} is threefold. First, it provides a
unified pipeline from raw bibliographic data to publication-ready visual
profiles, requiring no manual design work from the user. Second, it
integrates large language model (LLM) technology---specifically, the
Anthropic Claude API---to generate narrative summaries of individual
productions: research question, empirical relevance, main finding, and
open question. Third, it ships with a companion Model Context Protocol
(MCP) server that enables conversational notebook generation through
Claude Desktop: the researcher describes their needs in natural language,
and the system generates the notebook accordingly.

The remainder of this paper is organised as follows. Section~\ref{sec:related}
reviews related software. Section~\ref{sec:design} describes the package
architecture and data model. Section~\ref{sec:functions} presents the core
functions with reproducible code examples. Section~\ref{sec:illustration}
illustrates the package using data from Esther Duflo's public production
record. Section~\ref{sec:mcp} describes the MCP companion server.
Section~\ref{sec:limitations} discusses limitations. Section~\ref{sec:conclusion}
concludes.

%% -- 2. Related Work ----------------------------------------------------------
\section[Related Work]{Related Work} \label{sec:related}

Several \proglang{R} packages address adjacent problems. The \pkg{scholar}
package \citep{scholar2023} retrieves citation data from Google Scholar
for a given researcher identifier, but it does not produce visual profiles
and its reliance on web scraping makes it fragile. The \pkg{bibliometrix}
package \citep{Aria2017} provides a comprehensive toolkit for bibliometric
analysis of research corpora, including co-citation analysis, keyword mapping,
and temporal trend detection; however, its unit of analysis is the corpus
rather than the individual researcher, and it does not produce personalised
visual profiles. The \pkg{rorcid} package \citep{rorcid2020} provides
programmatic access to the ORCID registry API, but it retrieves rather than
visualises data. The \pkg{vitae} package \citep{OBrien2023} generates
formatted academic CVs in various styles, but produces textual documents
rather than visual infographics. Table~\ref{tab:comparison} summarises
this comparison.

%% TABLE DE COMPARAISON (générer avec knitr::kable dans un chunk R)
<<comparison-table, echo=FALSE, results='asis'>>=
comparison <- data.frame(
  Package     = c("scholar", "bibliometrix", "rorcid", "vitae", "publigraphics"),
  Input       = c("Scholar ID", "BibTeX/CSV", "ORCID ID", "CSV/BibTeX", "BibTeX/CSV"),
  Unit        = c("Individual", "Corpus", "Individual", "Individual", "Individual"),
  Visualisation = c("Basic", "Advanced", "None", "None", "Advanced"),
  AI_Narrative = c("No", "No", "No", "No", "Yes"),
  PDF_Output   = c("No", "No", "No", "Yes", "Yes"),
  HTML_Output  = c("No", "No", "No", "No", "Yes"),
  CRAN         = c("Yes", "Yes", "Yes", "Yes", "Submitted")
)
knitr::kable(comparison, format = "latex", booktabs = TRUE,
             caption = "Comparison of R packages for researcher profiling. \\label{tab:comparison}")
@

%% -- 3. Package Design --------------------------------------------------------
\section[Package Design]{Package Design and Data Model} \label{sec:design}

\subsection{The Twelve Types of Scientific Production}

\pkg{publigraphics} recognises twelve canonical types of scientific
production, covering the full spectrum of academic output in the social
sciences:

%% LISTE DES 12 TYPES (tableau LaTeX)

\subsection{Pipeline Architecture}

%% FIGURE : diagramme du pipeline (généré en R avec DiagrammeR ou ggplot2)
<<pipeline-diagram, echo=FALSE, fig.cap="PubliGraphics pipeline architecture.", fig.width=10, fig.height=4>>=
# Générer le diagramme de pipeline avec ggplot2 (pas de dépendances externes)
# Boîtes : BibTeX Input → parse_inputs → classify → viz_* → generate_notebook → PDF+HTML
@

\subsection{LLM Integration and Fallback}

The integration of large language models raises questions of reproducibility
and transparency that require careful treatment in a scientific software
package. \pkg{publigraphics} addresses these concerns in three ways. First,
all API calls include a fixed prompt that is version-controlled and
documented in the package source code (see function \code{pg_narrative_article}).
Second, results are cached locally and the cache can be inspected and
version-controlled alongside the data. Third, the package degrades gracefully
when the API key is absent or the API is unavailable: all functions return
\code{NA} narrative fields without error, and the notebook is generated
without narrative summaries.

%% -- 4. Core Functions --------------------------------------------------------
\section[Core Functions]{Core Functions} \label{sec:functions}

\subsection{Data Input and Classification}

<<parse-example, echo=TRUE, eval=TRUE>>=
library("publigraphics")

# Lire le fichier BibTeX fourni avec le package (données Esther Duflo)
bib_path <- system.file("extdata", "duflo_articles.bib",
                         package = "publigraphics")
data     <- pg_read_bib(bib_path)
nrow(data)
names(data)
@

<<classify-example, echo=TRUE, eval=TRUE>>=
extra_path <- system.file("extdata", "duflo_extra.csv",
                           package = "publigraphics")
data_full  <- pg_merge_inputs(data, pg_read_extra(extra_path)) |>
              pg_classify()
pg_summary_table(data_full)
@

\subsection{Visualisation Functions}

<<wordcloud-example, echo=TRUE, eval=FALSE>>=
# Nuage de mots TF-IDF avec topics LDA | TF-IDF word cloud with LDA topics
set.seed(2024L)
wc <- pg_wordcloud_articles(data_full, n_topics = 4L, lang = "en")
wc$plot  # version statique pour publication
@

<<map-example, echo=TRUE, eval=FALSE>>=
# Carte géographique des séminaires | Geographic map of seminars
map <- pg_map_seminars(data_full, output_type = "static",
                        theme_color = "#1A5276")
print(map)
@

\subsection{Main Notebook Generation}

<<generate-example, echo=TRUE, eval=FALSE>>=
result <- generate_publigraphics(
  author_name    = "Esther Duflo",
  bib_file       = bib_path,
  extra_data     = extra_path,
  affiliation    = "MIT / J-PAL / Collège de France",
  orcid          = "0000-0002-0632-6971",
  theme_color    = "#1A5276",
  output_dir     = tempdir(),
  language       = "en",
  output_formats = "html",
  api_key_claude = Sys.getenv("ANTHROPIC_API_KEY")
)
@

%% -- 5. Illustration : Esther Duflo ------------------------------------------
\section[Illustration]{Illustration: Esther Duflo's PubliGraphics} \label{sec:illustration}

We illustrate \pkg{publigraphics} using the production record of Esther Duflo
(born 1972), Abdul Latif Jameel Professor of Poverty Alleviation and
Development Economics at MIT, co-founder and co-director of J-PAL, and
2019 Nobel Laureate in Economic Sciences (with Abhijit Banerjee and Michael
Kremer). Her production record is rich, diverse, and entirely in the public
domain: 15 peer-reviewed articles with more than 500 citations each,
2 books translated into more than 30 languages, 5 book chapters,
10 international seminars and keynotes, 3 funded research projects,
5 supervised doctoral theses, and 6 awards and distinctions. This diversity
across all twelve types recognised by \pkg{publigraphics} makes her record
an ideal illustration of the package's capabilities.

%% FIGURES GÉNÉRÉES DANS LES CHUNKS R SUIVANTS :
<<duflo-radar, echo=FALSE, fig.cap="Radar chart of Esther Duflo's scientific production by type.", fig.width=7, fig.height=7>>=
set.seed(2024L)
pg_radar_productions(data_full, theme_color = "#1A5276")
@

<<duflo-timeline, echo=FALSE, fig.cap="Temporal evolution of Esther Duflo's scientific output, 2001--2024.", fig.width=12, fig.height=5>>=
pg_curve_timeline(data_full, theme_color = "#1A5276")
@

<<duflo-map, echo=FALSE, fig.cap="Geographic map of Esther Duflo's seminar interventions.", fig.width=10, fig.height=6>>=
pg_map_seminars(data_full, output_type = "static", theme_color = "#1A5276")
@

<<duflo-coauthors, echo=FALSE, fig.cap="Co-authorship network of Esther Duflo.", fig.width=9, fig.height=9>>=
pg_network_coauthors(data_full, author_name = "Duflo, Esther",
                      theme_color = "#1A5276")
@

%% -- 6. MCP Server -----------------------------------------------------------
\section[MCP Server]{The \pkg{publigraphics-mcp} Companion Server} \label{sec:mcp}

The \pkg{publigraphics-mcp} companion server implements the Model Context
Protocol (MCP, \citealt{Anthropic2024MCP}), which allows external tools to
expose capabilities to Claude Desktop as callable functions. The server,
written in TypeScript and distributed via npm, wraps the \proglang{R}
package behind seven MCP tools (Table~\ref{tab:mcp-tools}) and bridges
the natural language interface of Claude Desktop to the computational
backend of \pkg{publigraphics}.

%% TABLEAU DES 7 OUTILS MCP
<<mcp-tools-table, echo=FALSE, results='asis'>>=
mcp_tools <- data.frame(
  Tool = c("parse_bib_file", "preview_researcher_stats",
            "list_productions_by_type", "generate_narrative_summary",
            "generate_publigraphics_notebook", "validate_bib_file",
            "open_publigraphics_output"),
  Description = c(
    "Parse BibTeX/RIS/CSV and return summary by type",
    "Compute global statistics (career span, top keywords)",
    "List productions filtered by type",
    "Generate AI narrative summaries via Claude API",
    "Generate complete notebook (PDF + HTML) — main tool",
    "Validate BibTeX quality and report issues",
    "Open generated file in default viewer"
  )
)
knitr::kable(mcp_tools, format = "latex", booktabs = TRUE,
             caption = "MCP tools exposed by \\pkg{publigraphics-mcp}. \\label{tab:mcp-tools}")
@

%% -- 7. Performance and Limitations ------------------------------------------
\section[Limitations]{Performance and Limitations} \label{sec:limitations}

\textbf{Performance.} On a standard laptop (Apple M2, 16 GB RAM), notebook
generation for the Duflo dataset (15 articles, 25 extra productions) takes
approximately 45 seconds without AI narrative generation and 3.5 minutes
with narrative generation for all eligible productions. PDF rendering via
\code{pagedown::chrome_print()} requires a local installation of Chrome
or Chromium and adds approximately 30 seconds to the total.

\textbf{Dependency on the Anthropic API.} Narrative generation requires a
valid Anthropic API key and incurs costs proportional to the number of
productions processed. As noted in Section~\ref{sec:design}, the package
degrades gracefully in the absence of an API key.

\textbf{BibTeX quality.} The quality of the generated notebook is directly
dependent on the quality of the input BibTeX data. Missing abstracts prevent
narrative generation; missing keywords reduce the quality of word clouds;
missing geographic information prevents seminar mapping. The
\code{validate_bib_file} MCP tool and the \code{pg_validate_bib()} function
(planned for v0.2.0) assist users in identifying and correcting data quality
issues.

%% -- 8. Conclusion -----------------------------------------------------------
\section[Conclusion]{Conclusion} \label{sec:conclusion}

We have presented \pkg{publigraphics}, an \proglang{R} package for the
automated visual and narrative profiling of individual researchers' scientific
output. The package accepts BibTeX input, classifies productions into twelve
types, generates a suite of visualisations, and produces a publication-ready
notebook in PDF and HTML formats. An accompanying MCP server enables
conversational generation through Claude Desktop.

Several extensions are planned for future versions. First, direct integration
with the ORCID API will allow users to import their production record without
manual BibTeX export. Second, a Shiny application will provide an interactive
interface for customising notebook parameters without \proglang{R} programming
knowledge. Third, a multi-researcher comparison mode will allow departments
and laboratories to generate collective scientific profiles.

\section*{Computational Details}

The results in this paper were obtained using \proglang{R}~\Sexpr{getRversion()}
with \pkg{publigraphics}~0.1.0. \proglang{R} itself and all packages used
are available from the Comprehensive \proglang{R} Archive Network (CRAN) at
\url{https://CRAN.R-project.org/}.

\section*{Acknowledgments}
[ACKNOWLEDGMENTS — à compléter]

\bibliography{publigraphics}

\end{document}
```

### 4.3 article-jss/replication_script.R

```r
# ══════════════════════════════════════════════════════════════════════════════
# Replication script for:
# "publigraphics: Visual and Narrative Profiling of Researchers' Scientific
#  Output in R"
# Journal of Statistical Software, [YEAR]
#
# This standalone script replicates all figures and tables in the paper.
# Expected runtime : ~2 minutes (without API key) on a standard laptop.
# Required : R >= 4.3.0, package publigraphics >= 0.1.0
# ══════════════════════════════════════════════════════════════════════════════

# ── Installation (si nécessaire | if needed) ──────────────────────────────────
if (!requireNamespace("publigraphics", quietly = TRUE)) {
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
  remotes::install_github("[GITHUB_USERNAME]/publigraphics/r-package")
}

library(publigraphics)

# ── Graine aléatoire | Random seed ───────────────────────────────────────────
set.seed(2024L)

# ── Chargement des données Duflo | Load Duflo data ───────────────────────────
bib_path   <- system.file("extdata", "duflo_articles.bib", package="publigraphics")
extra_path <- system.file("extdata", "duflo_extra.csv",   package="publigraphics")

data <- pg_read_bib(bib_path)           |>
  pg_merge_inputs(pg_read_extra(extra_path)) |>
  pg_classify()

# ── Table 1 : Comparaison des packages ───────────────────────────────────────
# (voir le .Rnw — générée inline)

# ── Table 2 : Résumé des productions Duflo ───────────────────────────────────
pg_summary_table(data)

# ── Figure 1 : Radar ─────────────────────────────────────────────────────────
fig1 <- pg_radar_productions(data, theme_color = "#1A5276")
ggplot2::ggsave("figures/fig1_radar.pdf", fig1, width=7, height=7, dpi=300)
ggplot2::ggsave("figures/fig1_radar.png", fig1, width=7, height=7, dpi=300, bg="white")

# ── Figure 2 : Timeline temporelle ───────────────────────────────────────────
fig2 <- pg_curve_timeline(data, theme_color = "#1A5276")
ggplot2::ggsave("figures/fig2_timeline.pdf", fig2, width=12, height=5, dpi=300)

# ── Figure 3 : Carte séminaires ──────────────────────────────────────────────
fig3 <- pg_map_seminars(data, output_type = "static", theme_color = "#1A5276")
ggplot2::ggsave("figures/fig3_map.pdf", fig3, width=10, height=6, dpi=300)

# ── Figure 4 : Réseau co-auteurs ─────────────────────────────────────────────
fig4 <- pg_network_coauthors(data, author_name="Duflo, Esther", theme_color="#1A5276")
ggplot2::ggsave("figures/fig4_coauthors.pdf", fig4, width=9, height=9, dpi=300)

# ── Figure 5 : Nuage de mots articles ────────────────────────────────────────
wc   <- pg_wordcloud_articles(data, n_topics=4L, lang="en", theme_color="#1A5276")
ggplot2::ggsave("figures/fig5_wordcloud.pdf", wc$plot, width=10, height=8, dpi=300)

message("✓ Réplication complète | Replication complete. Figures saved in figures/")
```

---

## §5. INITIALISATION GITHUB — COMMANDES EXACTES

```bash
# ── Étape 1 : Créer la structure des dossiers ─────────────────────────────────
mkdir -p publigraphics/{r-package/{R,inst/{templates,extdata},tests/testthat,vignettes,data-raw,man},mcp-server/{src/{tools,r_bridge/{scripts},types,utils},config},article-jss/figures,.github/workflows}

# ── Étape 2 : Initialiser le package R ───────────────────────────────────────
cd publigraphics/r-package
Rscript -e '
  install.packages(c("usethis","devtools","roxygen2","testthat","pkgdown","withr"))
  usethis::create_package(".", open=FALSE)
  usethis::use_mit_license("[AUTHOR_NAME]")
  usethis::use_readme_rmd()
  usethis::use_news_md()
  usethis::use_testthat()
  usethis::use_vignette("introduction", title="Introduction to publigraphics")
  usethis::use_pkgdown()
  usethis::use_github_action_check_standard()
  usethis::use_github_action("pkgdown")
  usethis::use_github_action("test-coverage")
'

# ── Étape 3 : Initialiser le serveur MCP ─────────────────────────────────────
cd ../mcp-server
npm init -y
npm install @modelcontextprotocol/sdk@latest zod
npm install -D typescript@latest @types/node@latest
npx tsc --init

# ── Étape 4 : Git & GitHub ────────────────────────────────────────────────────
cd ..
git init
git add .
git commit -m "feat: initial project structure — publigraphics ecosystem"
# gh repo create publigraphics --public --source=. --push
# (nécessite GitHub CLI installé)
```

---

## §6. CHECKLIST D'EXÉCUTION POUR CLAUDE CODE

**Règle absolue : ne passe à la phase N+1 que si TOUTES les cases de la phase N
sont cochées.**

```
═══════════════════════════════════════════════════════════════
PHASE 1 — FONDATIONS (objectif : devtools::check() 0 ERROR)
═══════════════════════════════════════════════════════════════
[ ] 1.1  Créer toute la structure de dossiers (§1.3)
[ ] 1.2  Créer DESCRIPTION complet (§2.1)
[ ] 1.3  Créer publigraphics-package.R (§2.2)
[ ] 1.4  Créer utils.R avec toutes les fonctions utilitaires (§2.3)
[ ] 1.5  Créer parse_inputs.R complet avec roxygen2 (§2.4)
[ ] 1.6  Créer classify_outputs.R complet (§2.5)
[ ] 1.7  Créer inst/extdata/duflo_articles.bib (15 articles réels) (§2.16)
[ ] 1.8  Créer inst/extdata/duflo_books.bib (livres réels) (§2.16)
[ ] 1.9  Créer inst/extdata/duflo_extra.csv (séminaires/prix/thèses réels) (§2.16)
[ ] 1.10 Créer tests/testthat/helper-fixtures.R + test-parse_inputs.R +
         test-classify_outputs.R (§2.17)
[ ] 1.11 Exécuter devtools::document() → NAMESPACE généré sans erreur
[ ] 1.12 Exécuter devtools::test() → 100% des tests passent
[ ] 1.13 Exécuter devtools::check() → 0 ERROR, 0 WARNING
         (les NOTEs sur les paquets non disponibles sont acceptables)

═══════════════════════════════════════════════════════════════
PHASE 2 — VISUALISATIONS (objectif : toutes les viz s'exécutent)
═══════════════════════════════════════════════════════════════
[ ] 2.1  Créer inst/templates/publigraphics_base.css complet (§2.15)
[ ] 2.2  Créer inst/templates/publigraphics_print.css (version print)
[ ] 2.3  Créer viz_articles.R : 4 fonctions complètes (§2.6)
[ ] 2.4  Tester viz_articles.R avec données Duflo — vérifier le rendu visuel
[ ] 2.5  Créer viz_seminars.R : pg_map_seminars + pg_network_seminars (§2.7)
[ ] 2.6  Tester carte Duflo — vérifier que les villes se géolocalisent
[ ] 2.7  Créer viz_books.R : pg_gallery_books + pg_network_coauthors (§2.8)
[ ] 2.8  Créer viz_other.R : 5 fonctions (§2.9)
[ ] 2.9  Créer viz_global.R : radar + curve + stats_banner (§2.10)
[ ] 2.10 Tester pg_stats_banner(data_duflo) → vérifier les chiffres réalistes
[ ] 2.11 Créer test-viz_global.R (§2.17)
[ ] 2.12 devtools::check() → 0 ERROR, 0 WARNING

═══════════════════════════════════════════════════════════════
PHASE 3 — IA ET NARRATIVES
═══════════════════════════════════════════════════════════════
[ ] 3.1  Créer llm_narratives.R complet avec cache + rate limiting (§2.11)
[ ] 3.2  Tester pg_check_api_key() — vérifier fallback si pas de clé
[ ] 3.3  Tester pg_run_all_narratives() sur 3 articles Duflo
[ ] 3.4  Vérifier que le cache fonctionne (deuxième appel = 0 appels API)
[ ] 3.5  Vérifier le fallback : sans clé API → notebook généré sans erreur

═══════════════════════════════════════════════════════════════
PHASE 4 — TEMPLATE ET GÉNÉRATION NOTEBOOK
═══════════════════════════════════════════════════════════════
[ ] 4.1  Créer cover_page.R complet avec design exact spécifié (§2.12)
[ ] 4.2  Créer inst/templates/publigraphics_notebook.Rmd (§2.14)
[ ] 4.3  Créer generate_notebook.R : orchestrateur complet (§2.13)
[ ] 4.4  Test end-to-end SANS API key :
         generate_publigraphics("Esther Duflo", bib_path, extra_path,
           output_dir=tempdir(), output_formats="html")
         → HTML généré, visuellement vérifié
[ ] 4.5  Test end-to-end AVEC API key :
         → HTML généré avec fiches narratives IA, visuellement vérifié
[ ] 4.6  Test génération PDF :
         → PDF généré, vérifié visuellement (7 pages structurées)
[ ] 4.7  Créer test-generate_notebook.R (§2.17)
[ ] 4.8  devtools::check() → 0 ERROR, 0 WARNING

═══════════════════════════════════════════════════════════════
PHASE 5 — SERVEUR MCP
═══════════════════════════════════════════════════════════════
[ ] 5.1  Créer package.json (§3.1) + tsconfig.json (§3.2)
[ ] 5.2  Créer src/types/tool_inputs.ts (§3.3)
[ ] 5.3  Créer src/r_bridge/r_detector.ts (§3.4)
[ ] 5.4  Créer src/r_bridge/r_executor.ts (§3.5)
[ ] 5.5  Créer les 6 scripts bridge R dans src/r_bridge/scripts/
[ ] 5.6  Créer src/tools/generate_notebook.ts (§3.6)
[ ] 5.7  Créer les 6 autres outils dans src/tools/
[ ] 5.8  Créer src/index.ts complet (§3.8)
[ ] 5.9  npm run build → 0 erreur TypeScript
[ ] 5.10 Test manuel : node dist/index.js → démarre sans erreur
[ ] 5.11 Test parse_bib_file sur duflo_articles.bib via bridge R
[ ] 5.12 Test generate_publigraphics_notebook end-to-end via MCP
[ ] 5.13 Créer config/QUICKSTART.md (§3.9)
[ ] 5.14 Créer config/claude_desktop_example.json

═══════════════════════════════════════════════════════════════
PHASE 6 — DOCUMENTATION ET PUBLICATION
═══════════════════════════════════════════════════════════════
[ ] 6.1  devtools::document() → tous les man/ générés proprement
[ ] 6.2  pkgdown::build_site() → site de documentation généré
[ ] 6.3  Rédiger README.md racine (§1.1 + architecture globale)
[ ] 6.4  Rédiger r-package/README.md (installation + 3 exemples)
[ ] 6.5  Rédiger mcp-server/README.md (prérequis + config Claude Desktop)
[ ] 6.6  Créer vignettes/introduction.Rmd avec pipeline Duflo complet
[ ] 6.7  devtools::build_vignettes() → PDF vignette généré

═══════════════════════════════════════════════════════════════
PHASE 7 — ARTICLE JSS (à exécuter après la phase 6)
═══════════════════════════════════════════════════════════════
[ ] 7.1  Télécharger le template JSS officiel : jss.cls + jss.bst
         depuis https://www.jstatsoft.org/about/submissions
[ ] 7.2  Créer article-jss/publigraphics.Rnw (§4.2) — squelette complet
[ ] 7.3  Créer article-jss/publigraphics.bib (bibliographie de l'article)
[ ] 7.4  Créer article-jss/replication_script.R (§4.3)
[ ] 7.5  Rédiger toutes les sections (§4.2) avec chunks R fonctionnels
[ ] 7.6  Compiler le .Rnw : knitr::knit("publigraphics.Rnw") + pdflatex
         → PDF de l'article généré sans erreur
[ ] 7.7  Vérifier les figures : toutes générées par le code R
[ ] 7.8  Vérifier les tableaux : tous générés par le code R
[ ] 7.9  Vérifier : replication_script.R s'exécute en < 5 min sur un laptop
[ ] 7.10 Créer article-jss/jss_submission_checklist.md avec la checklist JSS
```

---

## §7. CONTRAINTES FINALES ET STANDARDS DE QUALITÉ

### 7.1 Standards de code R

- Tidyverse strict : pipe natif `|>`, `TRUE`/`FALSE`, snake_case
- Jamais `T`/`F`, jamais `:::`, jamais `<<-` (sauf `withCallingHandlers`)
- `set.seed(2024L)` dans tous les exemples et tests
- `@importFrom` explicites pour toutes les fonctions importées
- Tous les arguments avec valeurs par défaut documentés dans `@param`
- Tous les retours documentés dans `@return`
- Au moins 1 exemple `@examples` par fonction exportée

### 7.2 Standards de code TypeScript

- Typage strict — `strictNullChecks`, `noUncheckedIndexedAccess`
- Jamais de `any` sauf commentaire explicatif
- JSDoc complet pour chaque export
- Gestion d'erreurs `try/catch` avec messages bilingues
- Tests unitaires recommandés pour RExecutor

### 7.3 Standards visuels des notebooks générés

- **Niveau de qualité minimum** : supérieur à un CV académique standard
- Cohérence visuelle : même couleur principale dans toutes les visualisations
- Toutes les visualisations ggplot2 utilisent `pg_theme()` (police Lato)
- PDF : 7 pages structurées, aucune figure coupée en deux pages
- HTML : responsive, s'affiche correctement sur mobile et desktop
- Toutes les légendes bilingues FR/EN selon le paramètre `language`

### 7.4 Standards de sécurité

- La clé API Anthropic ne doit jamais apparaître dans :
  - Les logs CLI (`cli::`)
  - Le stdout de production
  - Les fichiers temporaires persistants
  - Les notebooks générés (HTML ou PDF)
  - Les fichiers de cache
  - Les logs GitHub Actions
- Utiliser `Sys.getenv("ANTHROPIC_API_KEY")` comme valeur par défaut
- Dans `r_executor.ts` : `_redactSecrets()` systématique sur les args

### 7.5 Standards de documentation bilingue

Tout ce qui est visible par l'utilisateur doit être bilingue FR/EN :
- Messages CLI : `"Parsing BibTeX file | Analyse du fichier BibTeX"`
- Labels des visualisations : `labs(title = if(lang=="fr") "..." else "...")`
- Documentation roxygen2 : description EN obligatoire, FR bilingue
- README : deux sections parallèles FR/EN (ou balises HTML `<details>`)
- QUICKSTART.md : bilingue dans le même document

---

*Fin du PROMPT MAÎTRE PubliGraphics — Version Définitive Ultra-Optimisée*
*Ce document est soumettable à Claude Code tel quel.*
*Remplacer partout [AUTHOR_NAME], [AUTHOR_FIRSTNAME], [AUTHOR_LASTNAME],*
*[AUTHOR_EMAIL], [AUTHOR_ORCID], [GITHUB_USERNAME] par vos informations.*
