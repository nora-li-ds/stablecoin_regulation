# SECU0057 Data Science Project
# Candidate Number: RWFP0
#
# File purpose:
# This script collects crypto-native technical discussion from Ethereum Research.
# It uses public Discourse JSON endpoints to collect topics and posts related to
# stablecoins, gas fees, fee markets, EIP-1559, congestion, MEV, USDC, USDT, and depeg.
#
# Input:
# - Ethereum Research public JSON endpoints
# - Search query terms defined in this script
#
# Output:
# - Raw Ethereum Research topic/post data saved in data/raw/
# - Filtered Ethereum Research data saved in data/processed/
#
# Notes:
# - This script does not bypass access controls.
# - The collected data are used only at aggregate text level.
library(httr)
library(jsonlite)
library(dplyr)
library(stringr)

dir.create("data", showWarnings = FALSE)
dir.create("data/raw", showWarnings = FALSE)
dir.create("data/processed", showWarnings = FALSE)

base_search_url <- "https://ethresear.ch/search.json"

queries <- c(
  "stablecoin",
  "gas fee",
  "fee market",
  "EIP-1559",
  "congestion",
  "MEV",
  "USDC",
  "USDT",
  "depeg"
)

collect_search_results <- function(query_term) {
  
  resp <- GET(
    base_search_url,
    query = list(q = query_term),
    add_headers(
      `User-Agent` = "SECU0057 stablecoin regulation academic project"
    )
  )
  
  cat("Search query:", query_term, "| Status:", status_code(resp), "\n")
  
  if (status_code(resp) != 200) {
    return(data.frame())
  }
  
  data <- content(resp, as = "text", encoding = "UTF-8") |>
    fromJSON(flatten = TRUE)
  
  topics <- data$topics
  
  if (length(topics) == 0 || nrow(topics) == 0) {
    return(data.frame())
  }
  
  topics |>
    transmute(
      source = "ethresearch",
      query = query_term,
      topic_id = id,
      title = title,
      slug = slug,
      created_at = created_at,
      url = paste0("https://ethresear.ch/t/", slug, "/", id)
    )
}

topic_results <- data.frame()

for (q in queries) {
  q_data <- collect_search_results(q)
  topic_results <- bind_rows(topic_results, q_data)
  Sys.sleep(0.5)
}

topic_results <- topic_results |>
  distinct(topic_id, .keep_all = TRUE)

cat("Unique topics collected:", nrow(topic_results), "\n")

get_topic_posts <- function(topic_id, query_term, title, url) {
  
  topic_json_url <- paste0("https://ethresear.ch/t/", topic_id, ".json")
  
  resp <- GET(
    topic_json_url,
    add_headers(
      `User-Agent` = "SECU0057 stablecoin regulation academic project"
    )
  )
  
  cat("Topic:", topic_id, "| Status:", status_code(resp), "\n")
  
  if (status_code(resp) != 200) {
    return(data.frame())
  }
  
  data <- content(resp, as = "text", encoding = "UTF-8") |>
    fromJSON(flatten = TRUE)
  
  posts <- data$post_stream$posts
  
  if (length(posts) == 0 || nrow(posts) == 0) {
    return(data.frame())
  }
  
  posts |>
    transmute(
      source = "ethresearch",
      query = query_term,
      topic_id = topic_id,
      title = title,
      url = url,
      post_id = id,
      created_at = created_at,
      post_number = post_number,
      text_html = cooked,
      text_plain = cooked |>
        str_replace_all("<[^>]+>", " ") |>
        str_replace_all("&quot;", "\"") |>
        str_replace_all("&amp;", "&") |>
        str_replace_all("&lt;", "<") |>
        str_replace_all("&gt;", ">") |>
        str_squish()
    )
}

eth_raw <- data.frame()

# Limit for now so collection stays small and manageable.
# You can increase this later.
topics_to_fetch <- topic_results |> head(80)

for (i in seq_len(nrow(topics_to_fetch))) {
  row <- topics_to_fetch[i, ]
  
  post_data <- get_topic_posts(
    topic_id = row$topic_id,
    query_term = row$query,
    title = row$title,
    url = row$url
  )
  
  eth_raw <- bind_rows(eth_raw, post_data)
  Sys.sleep(0.5)
}

eth_raw <- eth_raw |>
  mutate(
    date_parsed = as.Date(substr(created_at, 1, 10)),
    combined_text = paste(title, text_plain, sep = " ")
  )

write.csv(
  eth_raw,
  "data/raw/ethresearch_raw.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# Filtering for texts relevant to your dissertation/pilot:
# stablecoins, fees, congestion, MEV, market stress, and technical friction.
relevance_terms <- paste(
  c(
    "stablecoin",
    "stablecoins",
    "USDC",
    "USDT",
    "Tether",
    "depeg",
    "gas",
    "fee",
    "fees",
    "congestion",
    "EIP-1559",
    "MEV",
    "liquidity",
    "friction",
    "transaction cost",
    "cost",
    "market",
    "risk"
  ),
  collapse = "|"
)

eth_filtered <- eth_raw |>
  mutate(
    combined_lower = tolower(combined_text),
    relevance_score =
      as.integer(grepl("stablecoin|stablecoins|usdc|usdt|tether|depeg", combined_lower)) * 3 +
      as.integer(grepl("gas|fee|fees|eip-1559|congestion", combined_lower)) * 3 +
      as.integer(grepl("mev|liquidity|friction|transaction cost|cost", combined_lower)) * 2 +
      as.integer(grepl("market|risk", combined_lower)) * 1
  ) |>
  filter(grepl(relevance_terms, combined_lower)) |>
  arrange(desc(relevance_score), date_parsed) |>
  select(
    source,
    query,
    topic_id,
    title,
    url,
    post_id,
    post_number,
    created_at,
    date_parsed,
    text_plain,
    relevance_score
  )

write.csv(
  eth_filtered,
  "data/processed/ethresearch_filtered.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("\nEthereum Research collection complete.\n")
cat("Search topics collected:", nrow(topic_results), "\n")
cat("Raw posts collected:", nrow(eth_raw), "\n")
cat("Filtered posts collected:", nrow(eth_filtered), "\n\n")

cat("Top filtered Ethereum Research posts:\n")
print(
  eth_filtered |>
    select(query, title, date_parsed, post_number, relevance_score) |>
    head(30)
)