#install all the required packages if not already installed
#install.packages(c("httr", "jsonlite", "dotenv", "dplyr"), repos = "https://cloud.r-project.org")library(httr)
# !! Important:
# Do not put API keys directly in this script. I put mine in a .env file that is not shared on GitHub.
# Store GUARDIAN_API_KEY in .env.

library(httr)
library(jsonlite)
library(dotenv)
library(dplyr)

# 1. Project setup


dotenv::load_dot_env(".env")

guardian_key <- Sys.getenv("GUARDIAN_API_KEY")

if (guardian_key == "") {
  stop("GUARDIAN_API_KEY is missing. Please check your .env file.")
}

dir.create("data", showWarnings = FALSE)
dir.create("data/raw", showWarnings = FALSE)
dir.create("data/processed", showWarnings = FALSE)

base_url <- "https://content.guardianapis.com/search"

from_date <- "2025-10-27"
to_date   <- "2025-11-24"

# Event date:
# 10 November 2025: Bank of England systemic stablecoin consultation.
event_date <- as.Date("2025-11-10")


# 2. Search queries

# Avoid using "Bank of England" alone.
# It brings back sports articles because of "England".
# These queries are broader than one exact event,
# but the filtering step below keeps only crypto/stablecoin/regulation texts.

queries <- c(
  "stablecoin",
  "stablecoins",
  "cryptocurrency regulation",
  "crypto regulation",
  "cryptoasset regulation",
  "crypto fraud",
  "crypto money laundering",
  "cryptocurrency fraud",
  "Bank of England cryptocurrency",
  "Bank of England digital currency",
  "FCA crypto",
  "Financial Conduct Authority crypto",
  "crypto crash",
  "crypto market"
)

# 3. Function to collect one page


collect_guardian_page <- function(query_term, page_number = 1) {
  
  resp <- GET(
    base_url,
    query = list(
      q = query_term,
      `from-date` = from_date,
      `to-date` = to_date,
      `page-size` = 50,
      page = page_number,
      `show-fields` = "trailText,bodyText",
      `order-by` = "newest",
      `api-key` = guardian_key
    )
  )
  
  status <- status_code(resp)
  
  if (status != 200) {
    warning(paste("Query failed:", query_term, "Page:", page_number, "Status:", status))
    return(data.frame())
  }
  
  guardian_json <- content(resp, as = "text", encoding = "UTF-8") |>
    jsonlite::fromJSON(flatten = TRUE)
  
  results <- guardian_json$response$results
  
  if (length(results) == 0 || nrow(results) == 0) {
    return(data.frame())
  }
  
  out <- results |>
    transmute(
      source = "guardian",
      query = query_term,
      title = webTitle,
      date = webPublicationDate,
      section = sectionName,
      url = webUrl,
      trail_text = ifelse(is.na(fields.trailText), "", fields.trailText),
      body_text = ifelse(is.na(fields.bodyText), "", fields.bodyText)
    )
  
  return(out)
}

# 4. Function to collect all pages for one query


get_total_pages <- function(query_term) {
  
  resp <- GET(
    base_url,
    query = list(
      q = query_term,
      `from-date` = from_date,
      `to-date` = to_date,
      `page-size` = 50,
      page = 1,
      `show-fields` = "trailText",
      `order-by` = "newest",
      `api-key` = guardian_key
    )
  )
  
  if (status_code(resp) != 200) {
    return(0)
  }
  
  guardian_json <- content(resp, as = "text", encoding = "UTF-8") |>
    jsonlite::fromJSON(flatten = TRUE)
  
  pages <- guardian_json$response$pages
  
  return(pages)
}

collect_guardian_query <- function(query_term, max_pages = 3) {
  
  total_pages <- get_total_pages(query_term)
  
  if (total_pages == 0) {
    cat("Query:", query_term, "| No pages found\n")
    return(data.frame())
  }
  
  pages_to_collect <- min(total_pages, max_pages)
  
  cat("Query:", query_term, "| Pages available:", total_pages,
      "| Pages collected:", pages_to_collect, "\n")
  
  query_results <- data.frame()
  
  for (p in 1:pages_to_collect) {
    page_data <- collect_guardian_page(query_term, p)
    query_results <- bind_rows(query_results, page_data)
    Sys.sleep(0.2)
  }
  
  return(query_results)
}

# 5. Collect raw Guardian data


guardian_raw <- data.frame()

for (q in queries) {
  q_data <- collect_guardian_query(q, max_pages = 3)
  guardian_raw <- bind_rows(guardian_raw, q_data)
}

guardian_raw <- guardian_raw |>
  distinct(url, .keep_all = TRUE) |>
  mutate(
    date_parsed = as.Date(substr(date, 1, 10)),
    event_period = case_when(
      date_parsed < event_date ~ "pre_event",
      date_parsed == event_date ~ "event_day",
      date_parsed > event_date ~ "post_event",
      TRUE ~ NA_character_
    ),
    combined_text = paste(title, trail_text, body_text, sep = " ")
  )


# 6. Filter for relevance

# Rule:
# Keep articles that contain at least one crypto/stablecoin-related term
# AND at least one regulation/security/market-stress-related term.

crypto_terms <- paste(
  c(
    "stablecoin",
    "stablecoins",
    "crypto",
    "cryptocurrency",
    "cryptoasset",
    "cryptoassets",
    "blockchain",
    "bitcoin",
    "ethereum",
    "usdc",
    "usdt",
    "tether",
    "digital currency",
    "digital currencies",
    "cbdc"
  ),
  collapse = "|"
)

security_regulation_terms <- paste(
  c(
    "regulation",
    "regulatory",
    "regulator",
    "regulated",
    "law",
    "legal",
    "fca",
    "financial conduct authority",
    "bank of england",
    "fraud",
    "scam",
    "money laundering",
    "aml",
    "sanction",
    "sanctions",
    "illicit",
    "crime",
    "criminal",
    "risk",
    "financial stability",
    "collapse",
    "crash",
    "market",
    "exchange"
  ),
  collapse = "|"
)

guardian_filtered <- guardian_raw |>
  mutate(
    combined_text_lower = tolower(combined_text),
    has_crypto_term = grepl(crypto_terms, combined_text_lower),
    has_security_regulation_term = grepl(security_regulation_terms, combined_text_lower),
    relevance_score =
      as.integer(grepl("stablecoin|stablecoins", combined_text_lower)) * 3 +
      as.integer(grepl("bank of england|fca|financial conduct authority", combined_text_lower)) * 2 +
      as.integer(grepl("regulation|regulatory|regulated", combined_text_lower)) * 2 +
      as.integer(grepl("fraud|scam|money laundering|aml|sanction|illicit|crime", combined_text_lower)) * 2 +
      as.integer(grepl("crypto|cryptocurrency|cryptoasset|blockchain", combined_text_lower)) * 1
  ) |>
  filter(
    has_crypto_term == TRUE,
    has_security_regulation_term == TRUE
  ) |>
  arrange(desc(relevance_score), date_parsed) |>
  select(
    source,
    query,
    title,
    date,
    date_parsed,
    event_period,
    section,
    url,
    trail_text,
    body_text,
    relevance_score
  )


# 7. Save outputs


write.csv(
  guardian_raw,
  "data/raw/guardian_raw.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  guardian_filtered,
  "data/processed/guardian_filtered.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# 8. Print summary


cat("\nGuardian collection complete.\n")
cat("Raw Guardian articles:", nrow(guardian_raw), "\n")
cat("Filtered Guardian articles:", nrow(guardian_filtered), "\n\n")

cat("Filtered article counts by event period:\n")
print(table(guardian_filtered$event_period))

cat("\nTop filtered articles:\n")
print(
  guardian_filtered |>
    select(query, title, date_parsed, section, relevance_score) |>
    head(30)
)