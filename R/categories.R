# categories.R
# Build the foodie set used for the rest of the project.
#
# A restaurant is in the set when all three of these are true:
#   1. It has at least one of the categories listed below.
#   2. Its name appears at most twice among New Orleans restaurants.
#   3. At least 5% of its reviews use one of the creative words.
#
# A review word counts only if it is specific. Common words such as
# chef, tasting, homemade, patio, and creative were dropped because
# they showed up almost everywhere.
#
# Run from the Project2 folder:  Rscript R/categories.R

library(dplyr)
library(ggplot2)
library(stringr)
library(tidyr)

business <- readRDS("data/new_orleans/business_new_orleans.rds")
reviews  <- readRDS("data/new_orleans/reviews_new_orleans.rds")

dir.create("data/new_orleans", recursive = TRUE, showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)

# Four related categories: a meal, a drink, a long sit, and seafood.
selected_categories <- c(
  "american (new)",
  "cocktail bars",
  "cafes",
  "seafood"
)

# Same name in 3 or more places is treated as a chain, including local chains.
max_locations <- 2

# Edit this list. A review hits when any of these words appears.
creative_words <- c(
  "fusion",
  "handmade",
  "courtyard",
  "mural",
  "seasonal",
  "inventive",
  "omakase"
)

# At least this share of a restaurant's reviews must use a list word.
min_word_share <- 0.05

ink <- "#2F3B4A"
muted <- "#5B6675"
copper_bar <- "#C97E47"

# ---- One row per business and category --------------------------------------

restaurant_categories <- business |>
  mutate(category = str_split(str_to_lower(categories), ",\\s*")) |>
  unnest(category) |>
  mutate(category = str_squish(category))

category_counts <- restaurant_categories |>
  filter(category %in% selected_categories) |>
  count(category, name = "restaurants") |>
  arrange(desc(restaurants))

cat("\nRestaurants in each chosen category\n")
print(as_tibble(category_counts))
write.csv(category_counts, "data/new_orleans/category_counts.csv", row.names = FALSE)

category_labels <- c(
  "seafood" = "Seafood",
  "american (new)" = "American (new)",
  "cafes" = "Cafes",
  "cocktail bars" = "Cocktail bars"
)

category_plot_data <- category_counts |>
  mutate(
    category_label = category_labels[category],
    category_label = factor(category_label, levels = rev(category_label))
  )

ggsave(
  "figures/category_counts.png",
  ggplot(category_plot_data, aes(restaurants, category_label)) +
    geom_col(fill = copper_bar, width = 0.7) +
    geom_text(
      aes(label = restaurants),
      hjust = -0.15,
      color = ink,
      fontface = "bold",
      size = 4
    ) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.14))) +
    labs(
      title = "New Orleans restaurants in the four categories",
      subtitle = "A place is counted once for each label it carries.",
      x = "Restaurants",
      y = NULL
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold", color = ink),
      plot.subtitle = element_text(color = ink),
      axis.text = element_text(color = ink),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      plot.margin = margin(12, 16, 12, 12)
    ),
  width = 7.5,
  height = 4.2,
  dpi = 200,
  bg = "white"
)

# How often the chosen categories appear on the same restaurant.
cat("\nRestaurants that have both categories\n")
theme_rows <- restaurant_categories |>
  filter(category %in% selected_categories) |>
  distinct(business_id, category)

category_pairs <- theme_rows |>
  inner_join(theme_rows, by = "business_id", relationship = "many-to-many") |>
  filter(category.x < category.y) |>
  count(category.x, category.y, name = "restaurants") |>
  arrange(desc(restaurants)) |>
  rename(category_a = category.x, category_b = category.y)

print(as_tibble(category_pairs))
write.csv(category_pairs, "data/new_orleans/category_pairs.csv", row.names = FALSE)

# ---- Drop chains ------------------------------------------------------------
# Count locations on the full restaurant list, then apply that to the theme.
# A name with three shops is a chain even if only one shop has these categories.

location_counts <- business |>
  mutate(name_key = str_to_lower(str_squish(business_name))) |>
  count(name_key, name = "locations_in_city")

theme_ids <- theme_rows |>
  distinct(business_id)

theme <- business |>
  filter(business_id %in% theme_ids$business_id) |>
  mutate(name_key = str_to_lower(str_squish(business_name))) |>
  left_join(location_counts, by = "name_key")

n_theme <- nrow(theme)
cat("\nTheme restaurants before the chain rule:", n_theme, "\n")

chains_in_theme <- theme |>
  filter(locations_in_city > max_locations)

# Same name_key can be printed two ways (WOW Cafe and Wow Cafe). Collapse those.
chain_names <- chains_in_theme |>
  group_by(name_key) |>
  summarise(
    business_name = paste(sort(unique(business_name)), collapse = " / "),
    locations_in_city = first(locations_in_city),
    removed_from_theme = n(),
    .groups = "drop"
  ) |>
  select(business_name, locations_in_city, removed_from_theme) |>
  arrange(desc(locations_in_city), desc(removed_from_theme), business_name)

cat("\nNames removed because that name appears more than twice in the city\n")
cat("Restaurants removed:", nrow(chains_in_theme), "\n")
print(as_tibble(chain_names), n = 40)
write.csv(chain_names, "data/new_orleans/chains_removed.csv", row.names = FALSE)

selected <- theme |>
  filter(locations_in_city <= max_locations)

n_after_chain <- nrow(selected)
cat("\nTheme restaurants after the chain rule:", n_after_chain, "\n")

# ---- Count creative words, then apply the cutoff ---------------------------
# reviews_with_word = how many of its reviews use at least one list word
# share_with_word   = that count divided by all of its reviews
# The share is rounded to 3 decimals, then compared with the cutoff.

selected_reviews <- reviews |>
  filter(business_id %in% selected$business_id) |>
  mutate(text_lower = str_to_lower(text))

word_pattern <- paste(creative_words, collapse = "|")

word_summary <- selected_reviews |>
  mutate(hit = str_detect(text_lower, word_pattern)) |>
  group_by(business_id) |>
  summarise(
    reviews_read = n(),
    reviews_with_word = sum(hit, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(share_with_word = round(reviews_with_word / reviews_read, 3))

selected <- selected |>
  left_join(word_summary, by = "business_id") |>
  mutate(
    reviews_read = coalesce(reviews_read, 0L),
    reviews_with_word = coalesce(reviews_with_word, 0L),
    share_with_word = coalesce(share_with_word, 0)
  )

cat("\nHow many restaurants still in the set use each word at least once\n")
for (word in creative_words) {
  places <- selected_reviews |>
    filter(str_detect(text_lower, word)) |>
    distinct(business_id) |>
    nrow()
  cat(sprintf("  %-12s %4d restaurants\n", word, places))
}

cat("\nShare of reviews that use at least one list word, before the cutoff\n")
print(summary(selected$share_with_word))

selected <- selected |>
  filter(share_with_word >= min_word_share)

cat("\nRestaurants after the", min_word_share, "word-share cutoff:", nrow(selected), "\n")
cat("Postal codes in the final set:", n_distinct(selected$postal_code), "\n")
selected |>
  count(postal_code, sort = TRUE) |>
  as_tibble() |>
  print(n = 20)

filter_counts <- data.frame(
  step = c(
    "At least one chosen category",
    "Name appears at most twice in the city",
    "At least 5 percent of reviews use a list word"
  ),
  restaurants = c(n_theme, n_after_chain, nrow(selected))
)

cat("\nCount after each filter\n")
print(filter_counts, row.names = FALSE)
write.csv(filter_counts, "data/new_orleans/filter_counts.csv", row.names = FALSE)

star_counts <- selected |>
  count(stars) |>
  mutate(stars_label = factor(stars))

n_mid <- sum(selected$stars %in% c(4, 4.5))
n_five <- sum(selected$stars == 5)
n_low <- sum(selected$stars <= 3)

ggsave(
  "figures/stars_distribution.png",
  ggplot(star_counts, aes(stars_label, n)) +
    geom_col(fill = copper_bar, width = 0.72) +
    geom_text(aes(label = n), vjust = -0.35, color = ink, size = 3.6) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(
      title = "Business stars for the 108 places",
      subtitle = paste0(
        "Most sit at 4 or 4.5 (", n_mid, " places). ",
        n_five, " have a perfect 5, and ",
        n_low, " sit at 3 or below."
      ),
      x = "Yelp business stars",
      y = "Restaurants"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold", color = ink),
      plot.subtitle = element_text(color = ink),
      axis.text = element_text(color = ink),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      plot.margin = margin(12, 16, 12, 12)
    ),
  width = 7.5,
  height = 4.4,
  dpi = 200,
  bg = "white"
)

# ---- Join reviews for the final set -----------------------------------------
# One row per restaurant: how many reviews, and the mean and median stars
# on those reviews. Yelp's business stars can differ slightly from that mean.

review_summary <- reviews |>
  filter(business_id %in% selected$business_id) |>
  group_by(business_id) |>
  summarise(
    n_reviews = n(),
    mean_review_stars = mean(stars, na.rm = TRUE),
    median_review_stars = median(stars, na.rm = TRUE),
    .groups = "drop"
  )

selected_with_reviews <- selected |>
  left_join(review_summary, by = "business_id")

star_gap <- abs(selected_with_reviews$stars - selected_with_reviews$mean_review_stars)
cat("\nBusiness stars differ from the mean of review stars for",
    sum(star_gap > 0.001, na.rm = TRUE), "of", nrow(selected_with_reviews), "places\n")
cat("Median absolute gap:", round(median(star_gap, na.rm = TRUE), 3), "\n")
cat("Places where review_count differs from the number of review rows:",
    sum(selected_with_reviews$review_count != selected_with_reviews$n_reviews, na.rm = TRUE),
    "\n")

selected_with_reviews <- selected_with_reviews |>
  mutate(mean_review_stars = round(mean_review_stars, 2))

# ---- Save -------------------------------------------------------------------

saveRDS(
  selected,
  "data/new_orleans/selected_restaurants.rds",
  compress = "xz"
)

saveRDS(
  selected_with_reviews,
  "data/new_orleans/selected_with_reviews.rds",
  compress = "xz"
)

cat("\nSaved", nrow(selected), "restaurants to data/new_orleans/selected_restaurants.rds\n")
cat("Saved the review join to data/new_orleans/selected_with_reviews.rds\n")
