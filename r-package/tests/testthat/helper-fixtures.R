# ── helper-fixtures.R ──────────────────────────────────────────────────────────
# Shared test fixtures for publigraphics testthat tests.
# Loaded automatically by testthat before any test file is sourced.
# ──────────────────────────────────────────────────────────────────────────────

# ── 1. Mock BibTeX tibble (5 rows) ──────────────────────────────────────────

fixture_bib <- tibble::tibble(
  pg_id            = paste0("bib_", 1:5),
  type_raw         = c("article", "article", "book", "incollection", "inproceedings"),
  type_classified  = NA_character_,
  title            = c(
    "Randomized Experiments in Development Economics",
    "Women as Policy Makers in Village Councils",
    "Poor Economics: A Radical Rethinking of Poverty",
    "Field Experiments in Development",
    "Seminar on Microfinance and Poverty Reduction"
  ),
  authors          = list(
    c("Duflo, Esther", "Banerjee, Abhijit"),
    c("Chattopadhyay, Raghabendra", "Duflo, Esther"),
    c("Banerjee, Abhijit", "Duflo, Esther"),
    c("Duflo, Esther"),
    c("Duflo, Esther", "Morduch, Jonathan")
  ),
  year             = c(2006L, 2004L, 2011L, 2014L, 2019L),
  journal_or_venue = c(
    "American Economic Review",
    "Econometrica",
    "PublicAffairs",
    "Handbook of Field Experiments",
    "NBER Summer Institute"
  ),
  abstract         = c(
    "A survey of randomized experiments used in development economics.",
    "Examines women leaders and public goods investment in India.",
    "A rethinking of the economics of poverty and development.",
    "Overview of field experiments in development research.",
    "Discussion of microfinance impacts on poverty."
  ),
  keywords         = list(
    c("randomization", "development", "economics"),
    c("gender", "policy", "India"),
    c("poverty", "economics", "book"),
    c("field experiments", "development"),
    c("microfinance", "poverty", "seminar")
  ),
  doi              = c("10.1257/aer.96.5.1", "10.1111/j.1468-0262.2004.00539.x",
                        NA_character_, NA_character_, NA_character_),
  url              = rep(NA_character_, 5L),
  isbn             = c(NA_character_, NA_character_, "978-1-58648-798-0",
                        NA_character_, NA_character_),
  city             = c(NA_character_, NA_character_, "New York",
                        NA_character_, "Cambridge"),
  country          = c("USA", "India", "USA", "USA", "USA"),
  institution      = rep(NA_character_, 5L),
  note             = rep(NA_character_, 5L),
  cited_by         = c(1500L, 2200L, 3000L, 800L, NA_integer_),
  source           = rep("bib", 5L),
  date_added       = rep(as.Date("2024-01-15"), 5L)
)


# ── 2. Mock extra CSV tibble (3 rows) ───────────────────────────────────────

fixture_extra <- tibble::tibble(
  pg_id            = paste0("extra_", 1:3),
  type_raw         = c("project", "award", "expertise"),
  type_classified  = NA_character_,
  title            = c(
    "J-PAL Governance Initiative Grant",
    "John Bates Clark Medal",
    "World Bank Advisory Panel on Poverty"
  ),
  authors          = list(NA_character_, NA_character_, NA_character_),
  year             = c(2018L, 2010L, 2020L),
  journal_or_venue = rep(NA_character_, 3L),
  abstract         = rep(NA_character_, 3L),
  keywords         = list(NA_character_, NA_character_, NA_character_),
  doi              = rep(NA_character_, 3L),
  url              = rep(NA_character_, 3L),
  isbn             = rep(NA_character_, 3L),
  city             = c("Cambridge", NA_character_, "Washington"),
  country          = c("USA", "USA", "USA"),
  institution      = c("MIT", "AEA", "World Bank"),
  note             = c("Funding: $500,000 | Source: USAID",
                        NA_character_,
                        "Consulting engagement 2020-2022"),
  cited_by         = rep(NA_integer_, 3L),
  source           = rep("extra", 3L),
  date_added       = rep(as.Date("2024-01-15"), 3L)
)


# ── 3. Merged + classified tibble ───────────────────────────────────────────

fixture_merged <- dplyr::bind_rows(fixture_bib, fixture_extra) |>
  dplyr::arrange(dplyr::desc(.data$year), .data$title)

# Apply classification manually (matches pg_classify logic)
fixture_classified <- fixture_merged
fixture_classified$type_classified <- dplyr::case_when(
  fixture_classified$type_raw == "article"        ~ "article",
  fixture_classified$type_raw == "book"            ~ "book",
  fixture_classified$type_raw == "incollection"    ~ "book_chapter",
  fixture_classified$type_raw == "inproceedings"   ~ "conference",
  fixture_classified$type_raw == "project"         ~ "project",
  fixture_classified$type_raw == "award"           ~ "award",
  fixture_classified$type_raw == "expertise"        ~ "expertise",
  TRUE                                              ~ "other"
)
