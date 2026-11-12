# =============================================================================
# Europe PMC publication counts for four diffusion MRI methods
#
# Run from RStudio with the working directory set to this script's folder:
#   source("Diffusion_search_europePMC.R", echo = TRUE)
#
# Files saved in out_dir (one set per search, plus combined files per run):
#
#   <name>_summary.csv              total to date, counts by publication type,
#                                   first year, earliest records, reconciliation
#   <name>_by_year.csv              publications per year (total and by type)
#   <name>_records_not_in_by_year.csv
#                                   every record counted in the total but not in
#                                   the per-year counts, with the reason
#   search_log_<run>.csv            exact query, total and completion time for
#                                   each search
#   supplementary_reconciliation_<run>.csv
#                                   one row per search explaining the difference
#                                   between the total and the figure
#   supplementary_note_<run>.txt    ready-to-edit wording for the paper
#   all_searches_summary_<run>.csv  the per-search summary files combined,
#                                   one row per search
#
# Queries go straight to the Europe PMC REST API (the same search as the
# website), so totals should match europepmc.org.

# Search date for publication 12/11/2026 - if using this code after this date,
# results may differ
#
# Packages: httr, jsonlite
# =============================================================================

# install.packages(c("httr", "jsonlite")) - Install if needed
library(httr)
library(jsonlite)

# ---- Settings ----------------------------------------------------------------

out_dir      <- "europepmc_counts"   # folder for output files
start_year   <- 1985                 # selected as main search terms did not 
                                     # exist prior to this year
end_year     <- as.integer(format(Sys.Date(), "%Y"))
plot_through <- end_year - 1         # last year you plan to show in the figure
                                     # (the current year is incomplete); used
                                     # only for the reconciliation table

run_stamp <- format(Sys.time(), "%Y%m%d_%H%M")
dir.create(out_dir, showWarnings = FALSE)

# ---- Searches ----------------------------------------------------------------
# Names become the start of each output file name.

searches <- list(
  fixel_based_analysis =
    '(BODY:"fixel based analysis" OR BODY:"fixel-based analysis"
      OR TITLE:"fixel based analysis" OR TITLE:"fixel-based analysis"
      OR ABSTRACT:"fixel based analysis" OR ABSTRACT:"fixel-based analysis")
      AND ("diffusion-weighted imaging" OR "diffusion weighted imaging"
      OR "diffusion MRI" OR "MRI" OR "magnetic resonance imaging" OR "tractography" OR "white matter")',

  constrained_spherical_deconvolution =
    '(BODY:"constrained spherical deconvolution"
      OR TITLE:"constrained spherical deconvolution"
      OR ABSTRACT:"constrained spherical deconvolution")
      AND ("diffusion-weighted imaging" OR "diffusion weighted imaging"
      OR "diffusion MRI" OR "MRI" OR "magnetic resonance imaging" OR "tractography" OR "white matter")',

  diffusion_tensor_imaging =
    '(BODY:"diffusion tensor imaging"
      OR TITLE:"diffusion tensor imaging"
      OR ABSTRACT:"diffusion tensor imaging") AND 
      ("diffusion-weighted imaging" OR "diffusion weighted imaging"
      OR "diffusion MRI" OR "DTI" OR "MRI" OR "magnetic resonance imaging" OR "tractography" OR "white matter")',

  fractional_anisotropy =
    '(BODY:"fractional anisotropy"
      OR TITLE:"fractional anisotropy"
      OR ABSTRACT:"fractional anisotropy")
      AND ("diffusion tensor imaging" OR "diffusion-weighted imaging" OR "diffusion weighted imaging"
      OR "diffusion MRI" OR "DTI" OR "MRI" OR "magnetic resonance imaging" OR "tractography" OR "white matter")'
)

# ---- Publication-type filters --------------------------------------------------
# Europe PMC uses both PubMed-style ("Journal Article", "Review") and
# publisher-style ("research-article", "review-article") type labels, so both
# are included. Types are assigned in order (preprint > review > research
# article) so each paper is counted once; the rest is "other" (editorials,
# letters, case reports, conference abstracts, books, etc.).

#Note - PPR used for pre-print

type_filters <- list(
  preprint = 'SRC:PPR', 
  review   = '(PUB_TYPE:"review" OR PUB_TYPE:"review-article" OR PUB_TYPE:"systematic review") NOT SRC:PPR',
  research_article = '(PUB_TYPE:"research-article" OR PUB_TYPE:"journal article")
                      NOT (PUB_TYPE:"review" OR PUB_TYPE:"review-article" OR PUB_TYPE:"systematic review")
                      NOT SRC:PPR'
)

# ---- Helpers -----------------------------------------------------------------

# Europe PMC Articles RESTful API - search endpoint.
# This is the programmatic version of the search box on europepmc.org: each
# query is sent here as a web request and the results come back as JSON.
# The script reads "hitCount" (number of matching records) from each reply,
# and downloads record details where needed.
# Documentation: https://europepmc.org/RestfulWebService

api_url <- "https://www.ebi.ac.uk/europepmc/webservices/rest/search"

# Collapse line breaks and repeated spaces so queries are sent cleanly
clean_query <- function(q) gsub("\\s+", " ", trimws(q))

# Run one search and return the parsed reply, retrying on temporary errors
epmc_search <- function(query, page_size = 1, result_type = "lite",
                        cursor = "*", tries = 4) {
  for (i in seq_len(tries)) {
    resp <- tryCatch(
      GET(api_url, timeout(60), query = list(
        query      = clean_query(query),
        format     = "json",
        pageSize   = page_size,
        resultType = result_type,
        cursorMark = cursor,
        synonym    = "false"
      )),
      error = function(e) NULL
    )
    if (!is.null(resp) && status_code(resp) == 200) {
      return(fromJSON(content(resp, as = "text", encoding = "UTF-8")))
    }
    Sys.sleep(2 * i)  # back off before retrying
  }
  stop("Europe PMC request failed after ", tries, " attempts:\n", query)
}

hit_count <- function(query) {
  Sys.sleep(0.15)  # be polite to the API
  as.integer(epmc_search(query)$hitCount)
}

# Combine a base search with an extra (positive) filter
and_filter <- function(base, filter) {
  paste0("(", clean_query(base), ") AND (", clean_query(filter), ")")
}

# Counts for one query: total plus each publication type
type_counts <- function(query) {
  total    <- hit_count(query)
  preprint <- hit_count(and_filter(query, type_filters$preprint))
  review   <- hit_count(and_filter(query, type_filters$review))
  research <- hit_count(and_filter(query, type_filters$research_article))
  data.frame(
    total            = total,
    research_article = research,
    review           = review,
    preprint         = preprint,
    other            = total - research - review - preprint
  )
}

# Columns kept when downloading record details. Records differ in which
# fields they carry, so missing ones are filled with NA.
record_cols <- c("id", "source", "pmid", "pmcid", "doi", "title",
                 "journalTitle", "pubYear", "firstPublicationDate", "pubType")

standardise_records <- function(recs) {
  if (is.null(recs) || length(recs) == 0 || nrow(recs) == 0) return(NULL)
  for (col in setdiff(record_cols, names(recs))) recs[[col]] <- NA
  out <- recs[, record_cols]
  out[] <- lapply(out, function(x) as.character(x))
  out
}

# Download every record matching a query (pages of 1000)
fetch_all <- function(query, max_records = 10000) {
  cursor <- "*"
  pages <- list()
  n <- 0
  repeat {
    res  <- epmc_search(query, page_size = 1000, cursor = cursor)
    recs <- standardise_records(res$resultList$result)
    if (is.null(recs)) break
    pages[[length(pages) + 1]] <- recs
    n <- n + nrow(recs)
    nxt <- res$nextCursorMark
    if (is.null(nxt) || nxt == cursor || n >= res$hitCount || n >= max_records) break
    cursor <- nxt
    Sys.sleep(0.15)
  }
  if (length(pages) == 0) {
    empty <- as.data.frame(setNames(replicate(length(record_cols), character(0),
                                              simplify = FALSE), record_cols))
    return(empty)
  }
  do.call(rbind, pages)
}

# ---- Run the searches --------------------------------------------------------

all_summaries <- list()
search_log    <- list()
reconciliation <- list()
note_lines    <- character(0)

for (name in names(searches)) {
  q <- clean_query(searches[[name]])
  message("\n=== ", name, " ===")

  # 1. Totals to date, by publication type
  totals <- type_counts(q)
  message("Total publications: ", totals$total)

  # 2. Counts per year, by publication type
  by_year <- do.call(rbind, lapply(start_year:end_year, function(yr) {
    cbind(year = yr, type_counts(and_filter(q, paste0("PUB_YEAR:", yr))))
  }))
  message("Per-year counts done")

  # 3. Year of first publication, plus the earliest records for checking
  first_year <- min(by_year$year[by_year$total > 0])
  earliest <- standardise_records(
    epmc_search(and_filter(q, paste0("PUB_YEAR:", first_year)),
                page_size = 5)$resultList$result)
  earliest_records <- if (is.null(earliest)) "" else {
    e <- earliest
    e[is.na(e)] <- ""
    paste(sprintf("%s [%s, %s]%s", e$title, e$journalTitle, e$pubYear,
                  ifelse(e$doi == "", "", paste0(" doi:", e$doi))),
          collapse = " | ")
  }

  # 4. Records in the total but not in the per-year counts
  #    (no publication year, or a year outside start_year-end_year).
  #    NOT is written directly - a bracketed NOT on its own returns nothing.
  outside_query <- paste0("(", q, ") NOT PUB_YEAR:[", start_year, " TO ", end_year, "]")
  n_outside_hits <- hit_count(outside_query)
  outside <- fetch_all(outside_query)

  py <- suppressWarnings(as.integer(outside$pubYear))
  outside$reason <- ifelse(is.na(py), "no publication year",
                    ifelse(py > end_year, paste0("dated after ", end_year),
                                          paste0("dated before ", start_year)))
  outside$year_from_first_publication_date <- substr(outside$firstPublicationDate, 1, 4)

  if (nrow(outside) > 0) {
    write.csv(cbind(search = name, outside),
              file.path(out_dir, paste0(name, "_records_not_in_by_year.csv")),
              row.names = FALSE)
  }

  n_no_year <- sum(is.na(py))
  n_after   <- sum(!is.na(py) & py > end_year)
  n_before  <- sum(!is.na(py) & py < start_year)

  # 5. Reconciliation: total vs per-year sum vs what the figure shows
  sum_per_year   <- sum(by_year$total)
  in_figure      <- sum(by_year$total[by_year$year <= plot_through])
  partial_year   <- sum(by_year$total[by_year$year > plot_through])
  unexplained    <- totals$total - sum_per_year - n_outside_hits

  recon <- data.frame(
    search                       = name,
    total_to_date                = totals$total,
    sum_of_per_year_counts       = sum_per_year,
    not_in_per_year_counts       = n_outside_hits,
    no_publication_year          = n_no_year,
    dated_after_end_year         = n_after,
    dated_before_start_year      = n_before,
    no_year_but_dated_by_first_publication = sum(is.na(py) &
                                    !is.na(outside$year_from_first_publication_date) &
                                    outside$year_from_first_publication_date != ""),
    unexplained_difference       = unexplained,
    shown_in_figure              = in_figure,
    figure_years                 = paste0(first_year, "-", plot_through),
    excluded_partial_year_count  = partial_year,
    pct_total_not_in_per_year    = round(100 * n_outside_hits / totals$total, 2),
    pct_total_not_in_figure      = round(100 * (totals$total - in_figure) / totals$total, 2)
  )
  reconciliation[[name]] <- recon

  message("Total: ", totals$total, " | per-year sum: ", sum_per_year,
          " | not in per-year counts: ", n_outside_hits,
          " (", n_no_year, " no year, ", n_after, " after ", end_year,
          ", ", n_before, " before ", start_year, ")",
          " | unexplained: ", unexplained)

  # 6. Per-search summary file
  summary_df <- cbind(
    data.frame(
      search           = name,
      date_searched    = as.character(Sys.Date()),
      database         = "Europe PMC",
      total_to_date    = totals$total,
      research_article = totals$research_article,
      review           = totals$review,
      preprint         = totals$preprint,
      other            = totals$other,
      first_year       = first_year,
      earliest_records = earliest_records
    ),
    recon[, c("sum_of_per_year_counts", "not_in_per_year_counts",
              "no_publication_year", "dated_after_end_year",
              "dated_before_start_year", "unexplained_difference")],
    query = q
  )
  write.csv(summary_df, file.path(out_dir, paste0(name, "_summary.csv")),
            row.names = FALSE)
  all_summaries[[name]] <- summary_df

  # 7. Per-year file, starting at the first publication year
  by_year <- by_year[by_year$year >= first_year, ]
  write.csv(by_year, file.path(out_dir, paste0(name, "_by_year.csv")),
            row.names = FALSE)

  # 8. Search log entry, timestamped when this search finished
  search_log[[name]] <- data.frame(
    search          = name,
    query           = q,
    total_to_date   = totals$total,
    sum_of_per_year = sum_per_year,
    first_year      = first_year,
    database        = "Europe PMC",
    completed_at    = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    timezone        = Sys.timezone()
  )

  # 9. Wording for the supplementary note
  note_lines <- c(note_lines, sprintf(
    "- %s: %d records in total; %d (%.2f%%) shown in the figure (%s). Not shown: %d from %d (incomplete year), %d with no publication year, %d dated after %d%s%s.",
    gsub("_", " ", name), totals$total, in_figure,
    100 * in_figure / totals$total, recon$figure_years,
    partial_year, end_year, n_no_year, n_after, end_year,
    if (n_before > 0) sprintf(", %d dated before %d", n_before, start_year) else "",
    if (unexplained != 0) sprintf(", %d unexplained (index updates during the run)", unexplained) else ""
  ))
}

# ---- Combined files for this run ----------------------------------------------

search_log_df <- do.call(rbind, search_log)
write.csv(search_log_df, file.path(out_dir, paste0("search_log_", run_stamp, ".csv")),
          row.names = FALSE)

recon_df <- do.call(rbind, reconciliation)
write.csv(recon_df,
          file.path(out_dir, paste0("supplementary_reconciliation_", run_stamp, ".csv")),
          row.names = FALSE)

note <- c(
  sprintf("Europe PMC searches completed %s (%s).",
          format(Sys.time(), "%d %B %Y"), Sys.timezone()),
  "",
  "Totals include every record returned by each search. Per-year counts use the",
  "Europe PMC publication year (PUB_YEAR), so they exclude records without a",
  "publication year (mostly full-text records with no PubMed entry) and records",
  "already assigned to a future year's issue. The figure also excludes the",
  sprintf("current, incomplete year (%d).", end_year),
  "",
  note_lines
)
writeLines(note, file.path(out_dir, paste0("supplementary_note_", run_stamp, ".txt")))

# Combined summary: the per-search _summary.csv files in one table
all_summaries_df <- do.call(rbind, all_summaries)
write.csv(all_summaries_df,
          file.path(out_dir, paste0("all_searches_summary_", run_stamp, ".csv")),
          row.names = FALSE)

message("\nDone. Files saved in: ", normalizePath(out_dir))
