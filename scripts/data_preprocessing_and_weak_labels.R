library(dplyr)
library(stringr)

guardian <- read.csv("data/processed/guardian_filtered.csv")
eth <- read.csv("data/processed/ethresearch_filtered.csv")

guardian_text <- guardian |>
  transmute(
    source = "guardian",
    date = date_parsed,
    original_title = title,
    text = paste(title, trail_text, body_text, sep = " ")
  )

eth_text <- eth |>
  transmute(
    source = "ethresearch",
    date = date_parsed,
    original_title = title,
    text = paste(title, text_plain, sep = " ")
  )

combined <- bind_rows(guardian_text, eth_text) |>
  mutate(
    text = str_squish(text),
    text_lower = tolower(text),
    text_length = nchar(text)
  ) |>
  filter(!is.na(text), text_length > 50)

write.csv(
  combined,
  "data/processed/combined_text_data.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("Combined rows:", nrow(combined), "\n")
print(table(combined$source))


## This script combines the processed Guardian and EthResearch datasets into a single dataset for analysis. It also performs some basic text cleaning and filtering to ensure the data is suitable for further processing.

#weak lables for training data:

library(dplyr)
library(stringr)

combined <- read.csv("data/processed/combined_text_data.csv")

label_text <- function(text) {
  text <- tolower(text)
  
  regulatory <- str_detect(
    text,
    "regulation|regulatory|regulator|fca|financial conduct authority|bank of england|law|legal|compliance|policy|consultation"
  )
  
  fraud_security <- str_detect(
    text,
    "fraud|scam|money laundering|aml|sanction|sanctions|illicit|crime|criminal|hack|exploit|terrorist|laundering"
  )
  
  market_panic <- str_detect(
    text,
    "crash|collapse|panic|fear|sell-off|bubble|volatility|depeg|liquidity|withdrawal|bank run|contagion"
  )
  
  technical_friction <- str_detect(
    text,
    "gas|fee|fees|eip-1559|congestion|mev|transaction cost|friction|mempool|base fee|priority fee"
  )
  
  if (fraud_security) {
    return("fraud_security")
  } else if (regulatory) {
    return("regulatory_stress")
  } else if (market_panic) {
    return("market_panic")
  } else if (technical_friction) {
    return("technical_friction")
  } else {
    return("neutral_other")
  }
}

combined_labeled <- combined |>
  mutate(
    weak_label = sapply(text_lower, label_text)
  )

write.csv(
  combined_labeled,
  "data/processed/combined_labeled.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("Label counts:\n")
print(table(combined_labeled$weak_label))

cat("\nLabel by source:\n")
print(table(combined_labeled$source, combined_labeled$weak_label))