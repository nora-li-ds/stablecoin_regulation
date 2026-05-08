# SECU0057 Crypto Stress Narrative Project

## Project Aim

This project uses text data to examine how different communities describe stress around cryptoassets, stablecoins, regulation, fraud, and technical friction. It compares mainstream media narratives from The Guardian with crypto-native technical discussions from Ethereum Research.

The aim is not to detect money laundering directly. Instead, this project tests whether text mining and machine learning can help identify market, regulatory, fraud/security, and technical stress narratives that may later support more transparent and auditable crypto-AML analysis.

本项目使用文本数据分析不同群体如何描述加密资产、稳定币、监管、诈骗风险和技术摩擦相关的压力叙事。项目对比了 The Guardian 的主流媒体叙事，以及 Ethereum Research 的加密技术社区讨论。

本项目不直接识别洗钱行为，而是测试文本挖掘和机器学习是否能够帮助识别市场压力、监管压力、欺诈/安全风险和技术摩擦等叙事类型。未来这些文本压力指标可以作为更透明、可审计的 crypto-AML 分析中的 regime filter。

## Data Sources

- Guardian Open Platform API  
  - Mainstream media / public-security narrative
- Ethereum Research public JSON endpoints  
  - Crypto-native technical discussion

## Methods

- API / JSON-based web data collection
- Keyword-based relevance filtering
- Weak rule-based stress narrative labelling
- TF-IDF text mining
- Linear SVM classification
- Evaluation using accuracy, macro-F1, and confusion matrix

## Current Outputs

- Filtered Guardian articles
- Filtered Ethereum Research posts
- Combined labelled text dataset
- Weak stress-narrative label distribution
- TF-IDF and bigram term summaries
- SVM classification metrics

## Notes

Reddit and Stocktwits were considered as potential sources of retail-investor sentiment. However, Reddit currently requires explicit API approval, and Stocktwits API access returned a Cloudflare 403 challenge. To avoid bypassing access controls or violating platform rules, they were not used in the main dataset.

This repository is used as a learning and project log for the SECU0057 Applied Data Science project.