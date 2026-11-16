# reviewers.R
# Step 7: adjust each review for the reviewer's usual score.
# Reads the saved files. It does not import the raw JSON again.
#
# Run from the Project2 folder:  Rscript R/reviewers.R

library(dplyr)
library(ggplot2)
library(sf)
library(stringr)

# Change these to loosen or tighten the rules.
min_reviews_per_reviewer <- 5   # reviews inside the 108 to count as eligible
min_eligible_reviews <- 5       # eligible reviews a place needs for a score
min_places <- 5                 # places a neighborhood needs to be ranked

selected <- readRDS("data/new_orleans/selected_with_reviews.rds")
reviews <- readRDS("data/new_orleans/reviews_new_orleans.rds")

# Only reviews of the 108 count. Reviewer activity is counted inside them.
reviews_108 <- reviews |>
  semi_join(selected, by = "business_id") |>
  select(business_id, user_id, stars)

# Build every score for one reviewer bar. Used for 5 and again for 10.
score_places <- function(bar) {
  # Reviewers with at least `bar` reviews of the 108.
  eligible <- reviews_108 |>
    count(user_id, name = "reviews_of_108") |>
    filter(reviews_of_108 >= bar)

  # The median is the reviewer's usual score. The gap is stars minus the median.
  adjusted <- reviews_108 |>
    semi_join(eligible, by = "user_id") |>
    group_by(user_id) |>
    mutate(usual_score = median(stars), gap = stars - usual_score) |>
    ungroup()

  # A place needs at least min_eligible_reviews of these reviews to get a score.
  places <- adjusted |>
    group_by(business_id) |>
    summarise(
      eligible_reviews = n(),
      adjusted_score = mean(gap),
      median_gap = median(gap),
      .groups = "drop"
    ) |>
    filter(eligible_reviews >= min_eligible_reviews)

  list(eligible = eligible, places = places)
}

result_5 <- score_places(min_reviews_per_reviewer)
result_10 <- score_places(10)

# ---- Reviewers kept ---------------------------------------------------------

reviewer_counts <- function(result) {
  data.frame(
    reviewers_kept = nrow(result$eligible),
    reviews_by_them = sum(result$eligible$reviews_of_108),
    share_of_reviews = sum(result$eligible$reviews_of_108) / nrow(reviews_108)
  )
}

reviewers_kept <- bind_rows(
  bind_cols(data.frame(bar = 5), reviewer_counts(result_5)),
  bind_cols(data.frame(bar = 10), reviewer_counts(result_10))
) |>
  mutate(
    all_reviewers = n_distinct(reviews_108$user_id),
    all_reviews = nrow(reviews_108)
  )

# ---- Neighborhood for each place -------------------------------------------

neighborhoods <- st_read("data/geo/neighborhoods.geojson", quiet = TRUE)
if (is.na(st_crs(neighborhoods))) {
  st_crs(neighborhoods) <- 4326
}
neighborhoods <- neighborhoods |>
  st_transform(4326) |>
  transmute(area_name = str_to_title(gnocdc_lab))

selected_points <- selected |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)

place_area <- selected_points |>
  st_join(neighborhoods, join = st_within, left = TRUE) |>
  st_drop_geometry() |>
  select(business_id, area_name)

# ---- One row per place ------------------------------------------------------

all_reviewer_mean <- reviews_108 |>
  group_by(business_id) |>
  summarise(mean_stars_all = mean(stars), .groups = "drop")

place_scores <- selected |>
  select(business_id, business_name, stars, latitude, longitude, n_reviews) |>
  left_join(place_area, by = "business_id") |>
  left_join(all_reviewer_mean, by = "business_id") |>
  left_join(result_5$places, by = "business_id") |>
  left_join(
    result_10$places |>
      transmute(business_id, score_at_10 = adjusted_score, eligible_at_10 = eligible_reviews),
    by = "business_id"
  )

scored <- place_scores |>
  filter(!is.na(adjusted_score))

# Stars list: Yelp stars, then more eligible reviews, then higher adjusted score.
top10_stars <- scored |>
  arrange(desc(stars), desc(eligible_reviews), desc(adjusted_score)) |>
  mutate(rank = row_number()) |>
  slice_head(n = 10)

# Adjusted list: adjusted score, then more eligible reviews, then higher stars.
top10_adjusted <- scored |>
  arrange(desc(adjusted_score), desc(eligible_reviews), desc(stars)) |>
  mutate(rank = row_number()) |>
  slice_head(n = 10)

# Rank of every scored place under each ordering, for the "who moved" text.
ranks <- scored |>
  arrange(desc(stars), desc(eligible_reviews), desc(adjusted_score)) |>
  mutate(rank_stars = row_number()) |>
  arrange(desc(adjusted_score), desc(eligible_reviews), desc(stars)) |>
  mutate(rank_adjusted = row_number(), move = rank_stars - rank_adjusted)

# ---- Neighborhoods under both rules ----------------------------------------

# Stars rule (already published): at least 5 of the 108, average Yelp stars.
neighborhood_stars <- place_scores |>
  filter(!is.na(area_name)) |>
  group_by(area_name) |>
  summarise(places = n(), score = round(mean(stars), 2), .groups = "drop") |>
  filter(places >= min_places) |>
  arrange(desc(score), desc(places))

# Adjusted rule: at least 5 places with an adjusted score, unweighted average.
neighborhood_adjusted <- scored |>
  filter(!is.na(area_name)) |>
  group_by(area_name) |>
  summarise(places = n(), score = mean(adjusted_score), .groups = "drop") |>
  filter(places >= min_places) |>
  arrange(desc(score), desc(places))

# Same rule with the reviewer bar at 10.
neighborhood_adjusted_10 <- place_scores |>
  filter(!is.na(adjusted_score), !is.na(score_at_10), !is.na(area_name)) |>
  group_by(area_name) |>
  summarise(places = n(), score = mean(score_at_10), .groups = "drop") |>
  filter(places >= min_places) |>
  arrange(desc(score), desc(places))

# ---- Print the numbers the report quotes -----------------------------------

cat("\nReviewers kept\n")
print(reviewers_kept)
cat("\nPlaces with an adjusted score:", nrow(scored), "of", nrow(selected), "\n")
cat("No adjusted score:", nrow(selected) - nrow(scored), "\n")
cat("\nTop 10 by stars\n")
print(as_tibble(top10_stars |> select(rank, business_name, area_name, stars, eligible_reviews, adjusted_score, median_gap)), n = 10, width = Inf)
cat("\nTop 10 adjusted\n")
print(as_tibble(top10_adjusted |> select(rank, business_name, area_name, stars, eligible_reviews, adjusted_score, median_gap)), n = 10, width = Inf)
cat("\nOn stars list only:", setdiff(top10_stars$business_name, top10_adjusted$business_name), "\n")
cat("On adjusted list only:", setdiff(top10_adjusted$business_name, top10_stars$business_name), "\n")
cat("\nNeighborhoods, stars rule\n")
print(as_tibble(neighborhood_stars), n = 20)
cat("\nNeighborhoods, adjusted rule\n")
print(as_tibble(neighborhood_adjusted), n = 20)
cat("\nNeighborhoods, adjusted rule, reviewer bar 10\n")
print(as_tibble(neighborhood_adjusted_10), n = 20)

# ---- Save tables ------------------------------------------------------------

write.csv(reviewers_kept, "data/new_orleans/reviewers_kept.csv", row.names = FALSE)
write.csv(place_scores, "data/new_orleans/place_scores.csv", row.names = FALSE)
write.csv(ranks, "data/new_orleans/place_ranks.csv", row.names = FALSE)
write.csv(top10_stars, "data/new_orleans/top10_stars.csv", row.names = FALSE)
write.csv(top10_adjusted, "data/new_orleans/top10_adjusted.csv", row.names = FALSE)
write.csv(neighborhood_stars, "data/new_orleans/neighborhood_stars.csv", row.names = FALSE)
write.csv(neighborhood_adjusted, "data/new_orleans/neighborhood_adjusted.csv", row.names = FALSE)
write.csv(neighborhood_adjusted_10, "data/new_orleans/neighborhood_adjusted_10.csv", row.names = FALSE)

# ---- Figures ----------------------------------------------------------------
# Same colors as the other maps: copper, gray, sand.

library(ggrepel)

sand <- "#EFE6D2"
border <- "#B9AE9A"
ink <- "#2F3B4A"
muted <- "#5B6675"
copper <- "#C97E47"

dir.create("figures", showWarnings = FALSE)

# Scatter: Yelp stars against the adjusted score. The adjusted top 10 is named.
scatter_data <- scored |>
  mutate(top10 = business_id %in% top10_adjusted$business_id)

p_scatter <- ggplot(scatter_data, aes(stars, adjusted_score)) +
  geom_hline(yintercept = 0, color = muted, linewidth = 0.4) +
  geom_point(
    aes(size = eligible_reviews, fill = top10),
    shape = 21,
    color = "white",
    alpha = 0.85,
    position = position_jitter(width = 0.04, height = 0, seed = 7)
  ) +
  # Names sit to the left of their points so the 4.5 cluster stays readable.
  geom_text_repel(
    data = filter(scatter_data, top10),
    aes(label = business_name),
    size = 3,
    color = ink,
    nudge_x = ifelse(filter(scatter_data, top10)$stars >= 4.5, -0.3, -0.28),
    direction = "y",
    ylim = c(0.1, 1.15),
    hjust = 1,
    min.segment.length = 0,
    segment.color = border,
    box.padding = 0.45,
    seed = 7
  ) +
  scale_fill_manual(values = c("TRUE" = copper, "FALSE" = "#B8BEC6"), guide = "none") +
  scale_size_area(max_size = 9, name = "Eligible-reviewer\nreviews") +
  guides(size = guide_legend(override.aes = list(fill = "#B8BEC6", color = "white"))) +
  scale_x_continuous(breaks = seq(2.5, 5, by = 0.5), expand = expansion(add = c(0.2, 0.15))) +
  scale_y_continuous(expand = expansion(add = c(0.1, 0.55))) +
  labs(
    title = "Yelp stars against the adjusted score",
    subtitle = "Copper points are the adjusted top 10. The line at zero is a reviewer's usual score.",
    x = "Yelp business stars",
    y = "Adjusted score"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", color = ink, size = 15),
    plot.subtitle = element_text(color = muted, size = 10, margin = margin(b = 8)),
    axis.text = element_text(color = muted),
    axis.title = element_text(color = ink),
    legend.title = element_text(size = 9, color = ink),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "#E4DCCB"),
    plot.margin = margin(12, 12, 12, 12)
  )

ggsave("figures/adjusted_scatter.png", p_scatter, width = 9, height = 6.2, dpi = 200, bg = "white")

# Map: the adjusted top 10 inside the neighborhood boundaries.
# Four of the ten sit about 100 meters apart in the French Quarter, so they
# get a zoom box where their labels are nudged apart.
library(patchwork)

top10_points <- top10_adjusted |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)

quarter_names <- top10_adjusted |>
  filter(area_name == "French Quarter") |>
  pull(business_name)
quarter_points <- filter(top10_points, business_name %in% quarter_names)
other_points <- filter(top10_points, !business_name %in% quarter_names)

# Name the neighborhoods that hold at least one of the ten.
named_areas <- neighborhoods |>
  filter(area_name %in% top10_adjusted$area_name)
area_labels <- st_transform(named_areas, 32615)
st_geometry(area_labels) <- st_point_on_surface(st_geometry(area_labels))
area_labels <- st_transform(area_labels, 4326) |>
  filter(area_name != "French Quarter")

# Numbered copper dot for every place in the layer it is given.
numbered_dots <- function(points, size) {
  list(
    geom_sf(data = points, color = "white", fill = copper, shape = 21, size = size, stroke = 0.7),
    geom_sf_text(data = points, aes(label = rank), color = "white", size = size * 0.55, fontface = "bold")
  )
}

map_theme <- theme_void() +
  theme(plot.margin = margin(6, 6, 6, 6))

# Main map: the whole set. Six names are on it; the Quarter four are in the box.
box <- st_bbox(top10_points)
pad_x <- (box[["xmax"]] - box[["xmin"]]) * 0.18
pad_y <- (box[["ymax"]] - box[["ymin"]]) * 0.14
quarter_box <- st_bbox(quarter_points)
zoom_pad_x <- (quarter_box[["xmax"]] - quarter_box[["xmin"]]) * 0.9
zoom_pad_y <- (quarter_box[["ymax"]] - quarter_box[["ymin"]]) * 1.4
zoom_xlim <- c(quarter_box[["xmin"]] - zoom_pad_x, quarter_box[["xmax"]] + zoom_pad_x)
zoom_ylim <- c(quarter_box[["ymin"]] - zoom_pad_y, quarter_box[["ymax"]] + zoom_pad_y)

p_main <- ggplot() +
  geom_sf(data = neighborhoods, fill = sand, color = border, linewidth = 0.25) +
  geom_sf(data = named_areas, fill = "#EBCBA5", color = border, linewidth = 0.3, alpha = 0.55) +
  geom_sf_text(data = area_labels, aes(label = area_name), size = 2.8, color = muted, fontface = "italic") +
  annotate(
    "rect",
    xmin = zoom_xlim[1], xmax = zoom_xlim[2], ymin = zoom_ylim[1], ymax = zoom_ylim[2],
    fill = NA, color = ink, linewidth = 0.5
  ) +
  numbered_dots(top10_points, 5) +
  geom_text_repel(
    data = other_points,
    aes(longitude, latitude, label = business_name),
    size = 3.2,
    color = ink,
    fontface = "bold",
    nudge_y = -0.008,
    min.segment.length = 0.002,
    segment.color = muted,
    box.padding = 0.3,
    seed = 11
  ) +
  coord_sf(
    xlim = c(box[["xmin"]] - pad_x, box[["xmax"]] + pad_x),
    ylim = c(box[["ymin"]] - pad_y, box[["ymax"]] + pad_y),
    expand = FALSE
  ) +
  map_theme

# Zoom box: the four French Quarter places, labels set apart by hand.
quarter_labels <- top10_adjusted |>
  filter(business_name %in% quarter_names) |>
  mutate(
    nudge_x = case_when(
      business_name == "Longway Tavern" ~ -0.004,
      business_name == "Café Cour" ~ 0.002,
      business_name == "Broussard's" ~ -0.003,
      TRUE ~ 0.002
    ),
    nudge_y = case_when(
      business_name == "Longway Tavern" ~ 0.0012,
      business_name == "Café Cour" ~ -0.0016,
      business_name == "Broussard's" ~ -0.0014,
      TRUE ~ 0.0012
    )
  )

p_zoom <- ggplot() +
  geom_sf(data = neighborhoods, fill = "#EBCBA5", color = border, linewidth = 0.3) +
  numbered_dots(quarter_points, 8) +
  geom_text_repel(
    data = quarter_labels,
    aes(longitude, latitude, label = business_name),
    nudge_x = quarter_labels$nudge_x,
    nudge_y = quarter_labels$nudge_y,
    size = 3.2,
    color = ink,
    fontface = "bold",
    min.segment.length = 0,
    segment.color = muted,
    box.padding = 0.2,
    seed = 11
  ) +
  coord_sf(xlim = zoom_xlim, ylim = zoom_ylim, expand = FALSE) +
  labs(title = "French Quarter") +
  map_theme +
  theme(
    plot.title = element_text(size = 10, face = "italic", color = muted),
    panel.border = element_rect(color = ink, fill = NA, linewidth = 0.5)
  )

p_map <- (p_main | p_zoom) +
  plot_layout(widths = c(1.35, 1)) +
  plot_annotation(
    title = "The adjusted top 10, by neighborhood",
    subtitle = "Numbers are the adjusted rank. Shaded neighborhoods hold at least one of the ten.",
    caption = "The four French Quarter places are named in the zoom box, with their labels nudged apart so they do not stack.",
    theme = theme(
      plot.title = element_text(face = "bold", size = 16, color = ink),
      plot.subtitle = element_text(size = 11, color = ink, margin = margin(b = 8)),
      plot.caption = element_text(size = 9, color = muted, hjust = 0),
      plot.margin = margin(12, 12, 12, 12)
    )
  )

ggsave("figures/top10_map.png", p_map, width = 12, height = 7.2, dpi = 200, bg = "white")

cat("\nSaved figures/adjusted_scatter.png and figures/top10_map.png\n")
