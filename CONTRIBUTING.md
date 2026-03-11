# Contributing to publigraphics

Thank you for your interest in contributing! This document outlines the
process for contributing to the project.

## How to contribute

1. **Fork** the repository on GitHub.
2. **Create a branch** from `main` for your changes:
   ```bash
   git checkout -b feature/my-feature
   ```
3. **Make your changes**, following the code style guidelines below.
4. **Write or update tests** as needed (using `testthat`).
5. **Run checks** locally:
   ```r
   devtools::check("r-package")
   ```
6. **Commit** with a clear message describing the change.
7. **Push** your branch and open a **Pull Request** against `main`.

## Code style

- Follow the [tidyverse style guide](https://style.tidyverse.org/).
- Use `styler::style_pkg()` to auto-format code.
- Use `lintr::lint_package()` to check for lint issues.
- Document all exported functions with roxygen2.

## Tests

- All new features must include tests in `tests/testthat/`.
- Aim for meaningful coverage of edge cases and expected outputs.
- Run `devtools::test("r-package")` before submitting.

## Pull request process

- Ensure `R CMD check` passes with no errors, warnings, or notes.
- Update documentation (`devtools::document()`) if you changed any roxygen.
- Reference any related issue in the PR description (e.g., "Closes #42").
- One approval is required before merging.

## Reporting bugs

Please use the [bug report template](https://github.com/Paul1991-ux/publigraphics/issues/new?template=bug_report.md)
when filing issues.

## Questions?

Open a discussion on the [GitHub Discussions](https://github.com/Paul1991-ux/publigraphics/discussions)
page or contact Paul Wambo at paulwambo2@gmail.com.
