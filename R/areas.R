# areas.R
# Compare two ways to divide the city for the foodie set:
#   Neighborhood Statistical Areas (the names a person would say)
#   Census tracts (smaller boxes from the U.S. Census)
#
# An area can compete for "best" only when it has at least min_restaurants
# of the selected places. Average stars decides the order. The number of
# places is the tie-breaker.
#
# Run from the Project2 folder:  Rscript R/areas.R

# Set before library(tigris). Caching is on. This installed copy of tigris
# still prints the "set the cache option" tip when the package attaches.
options(tigris_use_cache = TRUE)

library(dplyr)
library(ggplot2)
library(sf)
library(stringr)
library(tigris)

# Change this one number to loosen or tighten the ranking.
min_restaurants <- 5

# Neighborhoods are the geography for the rest of the project.
# Census tracts stay in the script as the comparison, not the main cut.
chosen_system <- "Neighborhood"

selected <- readRDS("data/new_orleans/selected_restaurants.rds")

restaurant_points <- selected |>
  filter(!is.na(longitude), !is.na(latitude)) |>
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
  )

# ---- Boundaries -------------------------------------------------------------

neighborhoods <- st_read("data/geo/neighborhoods.geojson", quiet = TRUE)
if (is.na(st_crs(neighborhoods))) {
  st_crs(neighborhoods) <- 4326
}
neighborhoods <- neighborhoods |>
  st_transform(4326) |>
  transmute(area_name = stringr::str_to_title(gnocdc_lab))

tracts <- tracts(
  state = "LA",
  county = "Orleans",
  cb = TRUE,
  year = 2023
) |>
  st_transform(4326) |>
  transmute(area_name = NAMELSAD)

# ---- The same summary for either set of boundaries -------------------------

assign_areas <- function(points, boundaries) {
  assigned <- points |>
    st_join(boundaries, join = st_within, left = TRUE) |>
    st_drop_geometry()

  by_area <- assigned |>
    filter(!is.na(area_name)) |>
    group_by(area_name) |>
    summarise(
      restaurants = n(),
      average_stars = round(mean(stars, na.rm = TRUE), 2),
      # Median of the Yelp review counts. Context for the average.
      median_review_count = median(review_count, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(desc(average_stars), desc(restaurants))

  list(
    assigned = assigned,
    by_area = by_area,
    unmatched = sum(is.na(assigned$area_name))
  )
}

neighborhood_result <- assign_areas(restaurant_points, neighborhoods)
tract_result <- assign_areas(restaurant_points, tracts)

# One row of the comparison table the report needs.
comparison_row <- function(system_name, boundaries, result) {
  counts <- result$by_area$restaurants
  data.frame(
    geographic_system = system_name,
    areas_in_the_layer = nrow(boundaries),
    areas_with_a_restaurant = nrow(result$by_area),
    areas_with_enough = sum(counts >= min_restaurants),
    restaurants_assigned = nrow(result$assigned) - result$unmatched,
    unmatched_restaurants = result$unmatched,
    smallest_area_count = min(counts),
    largest_area_count = max(counts)
  )
}

comparison <- bind_rows(
  comparison_row("Neighborhood", neighborhoods, neighborhood_result),
  comparison_row("Census tract", tracts, tract_result)
)

cat("\nComparison\n")
print(comparison, row.names = FALSE)

neighborhood_ranking <- neighborhood_result$by_area |>
  filter(restaurants >= min_restaurants)

cat("\nNeighborhoods with at least", min_restaurants, "places, best average first\n")
print(as_tibble(neighborhood_ranking), n = 20)

cat("\nTracts with at least", min_restaurants, "places, best average first\n")
tract_result$by_area |>
  filter(restaurants >= min_restaurants) |>
  print(n = 20)

# These stay in the 108. They are left out of both rankings because the
# point is not inside either polygon layer.
outside_neighborhoods <- neighborhood_result$assigned |>
  filter(is.na(area_name)) |>
  select(business_id, business_name, stars, postal_code, latitude, longitude)

outside_tracts <- tract_result$assigned |>
  filter(is.na(area_name)) |>
  select(business_id, business_name)

cat("\nSelected restaurants outside the neighborhood polygons\n")
print(as_tibble(outside_neighborhoods), n = 10)
cat(
  "Same places missing from the tract polygons:",
  setequal(outside_neighborhoods$business_id, outside_tracts$business_id),
  "\n"
)

# ---- Maps -------------------------------------------------------------------
# Sand = no selected restaurant. Gray = too few to rank. Copper = average stars.

sand <- "#EFE6D2"
gray_few <- "#D4D4D0"
border <- "#B9AE9A"
ink <- "#2F3B4A"
muted <- "#5B6675"
copper <- c("#F6EAD7", "#EBCBA5", "#DDA673", "#C97E47", "#A85A2A", "#6E3517")

prepare_map <- function(boundaries, by_area) {
  boundaries |>
    left_join(by_area, by = "area_name") |>
    mutate(
      rank_stars = if_else(restaurants >= min_restaurants, average_stars, NA_real_),
      too_few = !is.na(restaurants) & restaurants < min_restaurants
    )
}

draw_map <- function(boundaries, by_area, title, subtitle) {
  map_data <- prepare_map(boundaries, by_area)
  thin_areas <- map_data |>
    filter(too_few)
  named_areas <- map_data |>
    filter(!is.na(rank_stars))

  # Point-on-surface in degrees warns, and so does calling it on an
  # sf object that still has columns. Work in meters, on the geometry only.
  label_points <- st_transform(named_areas, 32615)
  st_geometry(label_points) <- st_point_on_surface(st_geometry(label_points))
  label_points <- st_transform(label_points, 4326)

  # Crop to neighborhoods or tracts that have at least one place.
  # New Orleans East has none of this set, and it was hiding the rest of the map.
  focus <- map_data |>
    filter(!is.na(restaurants))
  box <- st_bbox(focus)
  pad_x <- (box[["xmax"]] - box[["xmin"]]) * 0.16
  pad_y <- (box[["ymax"]] - box[["ymin"]]) * 0.12

  ggplot() +
    geom_sf(data = map_data, aes(fill = rank_stars), color = border, linewidth = 0.25) +
    geom_sf(data = thin_areas, fill = gray_few, color = border, linewidth = 0.25) +
    geom_sf(data = restaurant_points, color = ink, size = 1.15, alpha = 0.8) +
    geom_sf_text(
      data = label_points,
      aes(label = str_replace(area_name, "Census Tract ", "Tract ")),
      fun.geometry = function(x) x,
      size = 2.6,
      color = ink,
      fontface = "bold",
      check_overlap = FALSE
    ) +
    scale_fill_gradientn(
      colors = copper,
      na.value = sand,
      limits = c(3.5, 4.5),
      name = "Average\nstars"
    ) +
    coord_sf(
      xlim = c(box[["xmin"]] - pad_x * 1.8, box[["xmax"]] + pad_x),
      ylim = c(box[["ymin"]] - pad_y, box[["ymax"]] + pad_y),
      expand = FALSE
    ) +
    labs(
      title = title,
      subtitle = subtitle,
      caption = "Labels can overlap where small areas meet, especially in the French Quarter."
    ) +
    theme_void() +
    theme(
      plot.title = element_text(face = "bold", size = 16, color = ink),
      plot.subtitle = element_text(size = 11, color = ink, margin = margin(b = 8)),
      plot.caption = element_text(size = 9, color = muted, hjust = 0),
      legend.position = "bottom",
      legend.title = element_text(size = 10, face = "bold", color = ink),
      legend.text = element_text(size = 9, color = ink),
      plot.margin = margin(12, 12, 12, 12)
    )
}

dir.create("figures", showWarnings = FALSE)

ggsave(
  "figures/neighborhoods.png",
  draw_map(
    neighborhoods,
    neighborhood_result$by_area,
    "Where the foodie places sit, by neighborhood",
    "Copper areas have at least 5 places. Gray areas have some, but not enough to rank."
  ),
  width = 9,
  height = 8,
  dpi = 200,
  bg = "white"
)

ggsave(
  "figures/tracts.png",
  draw_map(
    tracts,
    tract_result$by_area,
    "The same places, by census tract",
    "Copper tracts have at least 5 places. A tract number is not a place a person would name."
  ),
  width = 9,
  height = 8,
  dpi = 200,
  bg = "white"
)

# ---- Ranking chart ----------------------------------------------------------
# Stars and depth, side by side. The stars axis starts at 3.5 so the gap
# is visible. The rule still picks the higher average, which is Leonidas.

rank_levels <- rev(neighborhood_ranking$area_name)
ranked_plot <- neighborhood_ranking |>
  mutate(area = factor(area_name, levels = rank_levels))

panel_theme <- function(show_names) {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", color = ink, size = 13),
      axis.text.y = if (show_names) {
        element_text(color = ink, face = "bold", size = 10)
      } else {
        element_blank()
      },
      axis.text.x = element_text(color = muted),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.grid.major.x = element_line(color = "#E4DCCB"),
      plot.margin = margin(4, 10, 4, 6)
    )
}

p_stars <- ggplot(ranked_plot, aes(average_stars, area)) +
  geom_col(fill = "#C97E47", width = 0.72) +
  geom_text(
    aes(label = sprintf("%.2f", average_stars)),
    nudge_x = 0.03,
    hjust = 0,
    size = 3.4,
    color = ink
  ) +
  coord_cartesian(xlim = c(3.5, 4.9)) +
  labs(title = "Average stars", x = NULL, y = NULL) +
  panel_theme(TRUE)

p_count <- ggplot(ranked_plot, aes(restaurants, area)) +
  geom_col(fill = ink, width = 0.72) +
  geom_text(
    aes(label = restaurants),
    nudge_x = 0.5,
    hjust = 0,
    size = 3.4,
    color = ink
  ) +
  scale_x_continuous(limits = c(0, 48), expand = c(0, 0)) +
  labs(title = "Number of places", x = NULL, y = NULL) +
  panel_theme(FALSE)

grDevices::png(
  "figures/neighborhood_ranking.png",
  width = 9.4,
  height = 5.4,
  units = "in",
  res = 200,
  bg = "white"
)
grid::grid.newpage()
grid::pushViewport(grid::viewport(layout = grid::grid.layout(
  nrow = 2,
  ncol = 2,
  heights = grid::unit(c(0.95, 1), c("in", "null")),
  widths = grid::unit(c(1.35, 1), c("null", "null"))
)))
grid::pushViewport(grid::viewport(layout.pos.row = 1, layout.pos.col = 1:2))
grid::grid.text(
  "Leonidas leads on stars. The French Quarter leads on depth.",
  y = 0.68,
  gp = grid::gpar(fontsize = 15, fontface = "bold", col = ink)
)
grid::grid.text(
  "Neighborhoods with at least 5 places. The stars axis starts at 3.5. The rule picks Leonidas.",
  y = 0.28,
  gp = grid::gpar(fontsize = 10, col = muted)
)
grid::popViewport()
print(p_stars, vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1))
print(p_count, vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 2))
grDevices::dev.off()

dir.create("data/new_orleans", recursive = TRUE, showWarnings = FALSE)
write.csv(comparison, "data/new_orleans/area_comparison.csv", row.names = FALSE)
write.csv(neighborhood_result$by_area, "data/new_orleans/by_neighborhood.csv", row.names = FALSE)
write.csv(tract_result$by_area, "data/new_orleans/by_tract.csv", row.names = FALSE)
write.csv(neighborhood_ranking, "data/new_orleans/neighborhood_ranking.csv", row.names = FALSE)

cat("\nSaved figures/neighborhoods.png, figures/tracts.png, and figures/neighborhood_ranking.png\n")
cat("Chosen geography:", chosen_system, "\n")
cat("Best area under the", min_restaurants, "place rule:", neighborhood_ranking$area_name[1], "\n")
