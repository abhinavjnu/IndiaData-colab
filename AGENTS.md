# AGENTS.md - Guidance for Coding Agents in IndiaData

This file is for autonomous/agentic coding tools working in this repository.
It documents the practical commands and coding conventions already used in the codebase.

## Scope

- Repository: `Data Analysis/IndiaData`
- Primary language: R (scripts + reusable modules under `R/`)
- Analysis style: `data.table` + `survey/srvyr` + `ggplot2`
- Test framework: `testthat` (directory-based tests, not an R package build)

## Environment Snapshot

- R scripts are intended to run from the project root.
- `config.yaml` is local and contains secrets; do not commit it.
- `config.yaml.example` is the committed template.
- Raw/processed/outputs are mostly generated artifacts and usually ignored by git.
- Necessary R packages may already be installed in your environment; if not, run setup.

## Setup Commands

Run from project root (`IndiaData/`):

```bash
Rscript R/00_setup.R
```

Create local config if needed:

```bash
cp config.yaml.example config.yaml
```

Then edit `config.yaml` with valid API values.

## Build / Run Commands

There is no compiled build step (this is an R analysis project). Use these runtime checks:

```bash
# Full analysis pipeline
Rscript run_analysis.R

# Chart/table generation
Rscript generate_charts.R

# Focused analyses
Rscript analyze_pg_unemployment.R
Rscript pg_prime_age_analysis.R
Rscript pg_industry_occupation.R
Rscript create_education_ur_charts.R
```

## Test Commands

Preferred (matches CI behavior):

```bash
Rscript -e 'testthat::test_dir("tests/testthat", reporter = "summary")'
```

Run a single test file:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-plfs-indicators.R")'
```

Run a single test block (by test name regex):

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-plfs-indicators.R", filter = "Age filtering works")'
```

Alternative local runner present in repo:

```bash
Rscript tests/testthat.R
```

Note: `tests/testthat.R` calls `test_check("IndiaData")`, which assumes package-style metadata.
For this repo, `testthat::test_dir()` is generally the safest default.

## Lint Commands

CI uses `lintr` with a customized profile (line length 120 and flexible object names).

```bash
Rscript -e 'lints <- lintr::lint_dir("R", linters = lintr::linters_with_defaults(line_length_linter = lintr::line_length_linter(120), object_name_linter = NULL)); if (length(lints) > 0) { print(lints); quit(status = 1) }'
```

Quick lint pass (less strict to CI profile details):

```bash
Rscript -e 'lintr::lint_dir("R")'
```

## Code Organization Conventions

- Core reusable logic lives in numbered modules under `R/` (`00_` to `07_`).
- Scripts in repository root orchestrate analyses and exports.
- Tests live in `tests/testthat/` and mirror module responsibilities.
- Keep new modules aligned with numeric ordering and existing naming style.

## Import and Dependency Style

- Use `suppressPackageStartupMessages({ library(...) })` at file top for module dependencies.
- Prefer explicit package calls where clarity matters (for example `yaml::read_yaml`).
- Avoid adding heavy new dependencies unless they provide clear value.
- If adding dependencies, update `R/00_setup.R`.

## Formatting and Naming Guidelines

- Use snake_case for function and variable names.
- Use UPPER_CASE for constants (for example `EMPLOYED_CODES`).
- Keep lines readable; CI target is max 120 chars.
- Use section dividers (`# ====...`) consistent with existing files.
- Prefer clear, descriptive names over abbreviations unless domain-standard (LFPR, WPR, UR).
- Keep function signatures stable; add optional params rather than breaking callers.

## Types and Data Handling

- Default working table type is `data.table`.
- For `survey::svydesign`, convert to `data.frame` where needed (existing pattern).
- Return `data.table` from analysis helpers unless there is a strong reason not to.
- Use `copy(data)` before mutating inputs inside helper functions.
- Use explicit coercion for coded variables (`as.integer`, `as.numeric`, `as.character`).

## Error Handling and Validation

- Validate early with `stopifnot()` and explicit `stop()` messages.
- Use `warning()` for recoverable quality issues (missing weights, singleton strata).
- Use `tryCatch()` around external I/O and API operations.
- Include actionable error messages that explain how to fix the issue.
- Do not silently swallow failures in core computations.

## Survey and Domain Rules (Important)

- Preserve weighted-estimation workflow (`create_plfs_design()` before indicators).
- Prefer CWS for unemployment analysis (`approach = "cws"`) when appropriate.
- Keep PLFS weight formulas and detection logic centralized; avoid duplicating variants.
- Reuse variable detection helpers (`detect_variable`, `detect_variables`) rather than ad-hoc matching.

## Paths, Files, and Secrets

- Use path helpers from `R/01_config.R` (`raw_path`, `processed_path`, etc.).
- Avoid hardcoded absolute paths in committed code.
- Never print or commit API keys.
- Keep generated artifacts out of commits unless explicitly requested.

## Documentation and Comments

- Follow existing roxygen-style function headers for exported/reusable functions.
- Add comments for non-obvious logic, not for trivial line-by-line narration.
- If behavior changes, update `README.md` (and templates/docs if relevant).

## Cursor / Copilot Rules Check

- `.cursor/rules/`: not found in this repository.
- `.cursorrules`: not found in this repository.
- `.github/copilot-instructions.md`: not found in this repository.
- If these files are added later, treat them as higher-priority local agent instructions.

## Safe Change Checklist for Agents

- Run relevant tests after edits (at least targeted `test_file` for touched module).
- Run lint on modified R modules.
- Keep changes minimal and scoped to requested task.
- Do not refactor unrelated code opportunistically.
- Preserve existing outputs/contracts unless task explicitly changes them.
