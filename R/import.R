# import.R
# Steps 1-4: unzip the Yelp files, load them into R, keep only
# New Orleans restaurants, and save the smaller results as RDS files.
# Run from the Project2 folder:  Rscript R/import.R

library(dplyr)
library(stringr)
library(jsonlite)

raw_dir <- "data/raw"
out_dir <- "data/new_orleans"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

business_json <- file.path(raw_dir, "yelp_academic_dataset_business.json")
review_json   <- file.path(raw_dir, "yelp_academic_dataset_review.json")

# ---- Unzip --------------------------------------------------------------
# The download comes as zip files, so unzip them if the json isn't there yet
if (!file.exists(business_json)) {
  unzip(file.path(raw_dir, "business.zip"), exdir = raw_dir)
}
if (!file.exists(review_json)) {
  unzip(file.path(raw_dir, "review.zip"), exdir = raw_dir)
}

# ---- Load the business file ---------------------------------------------
# This one is small enough (~120 MB) to read all at once
business_raw <- stream_in(file(business_json), verbose = FALSE)

# Only keep the columns we need
business <- business_raw |>
  select(business_id, name, address, city, state, postal_code,
         latitude, longitude, stars, review_count, categories)

cat("All businesses:", nrow(business), "\n")
rm(business_raw)

# ---- Filter to New Orleans restaurants ----------------------------------
# Use city + state, then look for "Restaurants" in the categories text
new_orleans_restaurants <- business |>
  filter(
    state == "LA",
    city == "New Orleans",
    !is.na(categories),
    str_detect(categories, regex("Restaurants", ignore_case = TRUE))
  ) |>
  mutate(
    postal_code   = na_if(postal_code, ""),
    categories    = str_squish(categories),
    business_name = str_squish(name)
  ) |>
  distinct(business_id, .keep_all = TRUE)

cat("New Orleans restaurants:", nrow(new_orleans_restaurants), "\n")

# ---- Load the review file in chunks -------------------------------------
# The review file is ~5 GB which is too much for my 8 GB of RAM.
# stream_in() reads it in pages, and for each page we only keep the
# reviews that belong to a New Orleans restaurant.
keep_ids <- new_orleans_restaurants$business_id
kept_pages <- list()

handle_page <- function(page) {
  page <- page |>
    filter(business_id %in% keep_ids) |>
    select(business_id, user_id, stars, date, text, useful, funny, cool)
  kept_pages[[length(kept_pages) + 1]] <<- page
}

stream_in(
  file(review_json),
  handler = handle_page,
  pagesize = 100000,
  verbose = FALSE
)

reviews_new_orleans <- bind_rows(kept_pages)
rm(kept_pages)

cat("New Orleans reviews:", nrow(reviews_new_orleans), "\n")

# ---- Save as compressed RDS ---------------------------------------------
saveRDS(new_orleans_restaurants,
        file.path(out_dir, "business_new_orleans.rds"),
        compress = "xz")

saveRDS(reviews_new_orleans,
        file.path(out_dir, "reviews_new_orleans.rds"),
        compress = "xz")

# ---- Quick check: read them back in --------------------------------------
check_business <- readRDS(file.path(out_dir, "business_new_orleans.rds"))
check_reviews  <- readRDS(file.path(out_dir, "reviews_new_orleans.rds"))
cat("Read back:", nrow(check_business), "businesses and",
    nrow(check_reviews), "reviews\n")

# Every review should match one of the saved businesses
stopifnot(all(check_reviews$business_id %in% check_business$business_id))
