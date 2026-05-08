# SECU0057 Data Science Project
# Candidate Number: RWFP0
#
# File name:
# data_preprocessing_and_weak_labels.R
#
# File purpose:
# This script combines the processed Guardian and Ethereum Research datasets
# into one text dataset. It also creates weak rule-based stress narrative labels
# for later text mining and machine learning.
#
# Input:
# - data/processed/guardian_filtered.csv
# - data/processed/ethresearch_filtered.csv
#
# Output:
# - data/processed/combined_text_data.csv
# - data/processed/combined_labeled.csv

# Notes:
# - The weak labels are not manually checked ground truth.
# - They are transparent rule-based labels for exploratory text mining and ML.
# - All file paths are relative to the project root folder.


library(dplyr)
library(stringr)

# 1. Load processed datasets

guardian <- read.csv("data/processed/guardian_filtered.csv")
eth <- read.csv("data/processed/ethresearch_filtered.csv")

# 2. Convert both datasets into a common text format

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

# Combine and clean the text data
# str_squish() removes extra spaces.
# text_lower is created for keyword matching.
# Very short or missing texts are removed.

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

# 3. Create weak stress-narrative labels
# This function assigns one weak label to each text using keyword dictionaries.
# The labels are:
# - fraud_security
# - regulatory_stress
# - market_panic
# - technical_friction
# - neutral_other
#
# The priority order is:
# fraud_security > regulatory_stress > market_panic > technical_friction > neutral_other
#
# This means if a text contains both fraud and regulation words,
# it will be labelled as fraud_security.
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

#Print summary checks
# These checks help confirm that the script ran correctly.
cat("Label counts:\n")
print(table(combined_labeled$weak_label))

cat("\nLabel by source:\n")
print(table(combined_labeled$source, combined_labeled$weak_label))