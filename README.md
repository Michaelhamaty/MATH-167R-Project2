# Yelp New Orleans Restaurant Project

Project 2 for MATH 167R. The goal is to find the best restaurants in a chosen category in New Orleans and which area is best for finding them. This repo currently covers Steps 1-4 (getting and filtering the data).

## What's done so far

1. Created this GitHub repo.
2. Downloaded the Yelp business and review files, unzipped them and loaded them into R.
3. Filtered to New Orleans restaurants.
4. Saved the results as compressed RDS files.

## How I defined a "New Orleans restaurant"

A business counts if `state == "LA"`, `city == "New Orleans"`, and its `categories` text contains "Restaurants". That gives **2,259 restaurants** and **476,421 reviews** (all reviews for those restaurants).

## Files

- `R/download.sh` - downloads the two Yelp files from Kaggle
- `R/import.R` - unzips, loads, filters and saves the data
- `data/new_orleans/business_new_orleans.rds` - filtered businesses
- `data/new_orleans/reviews_new_orleans.rds` - reviews for those businesses

Read them back with:

```r
business <- readRDS("data/new_orleans/business_new_orleans.rds")
reviews  <- readRDS("data/new_orleans/reviews_new_orleans.rds")
```

## Getting the raw data

The raw JSON files are not in the repo (the review file is about 5 GB). To recreate the data:

```bash
bash R/download.sh        # needs the kaggle CLI + API key
Rscript R/import.R
```

The Yelp Open Dataset is also available from https://www.yelp.com/dataset. Put the unzipped files in `data/raw/`.

## Handling the large files

- My laptop has 8 GB of RAM, so I couldn't load the 5 GB review file all at once. `stream_in()` reads it in pages of 100,000 reviews and only keeps the ones for New Orleans restaurants.
- Only the needed columns are kept.
- Disk space was tight (about 12 GB free), so I only downloaded the business and review files (not user, tip or checkin), and deleted the raw files after saving the RDS files.
- The import takes about 7 minutes.
