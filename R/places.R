# places.R
# Step 5: check Yelp's city label against the Census place polygon.
# Mismatches stay in the data. The map is the "are the points even
# in the city" check for the 108 foodie places.
#
# Run from the Project2 folder:  Rscript R/places.R

# Set before library(tigris). Caching is on. This installed copy of tigris
# still prints the "set the cache option" tip when the package attaches.
options(tigris_use_cache = TRUE)

library(dplyr)
library(ggplot2)
library(sf)
library(tigris)

business <- readRDS("data/new_orleans/business_new_orleans.rds")
selected <- readRDS("data/new_orleans/selected_restaurants.rds")

dir.create("data/new_orleans", recursive = TRUE, showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)

# 2023 matches the tract year. If that file is gone, use 2024.
louisiana_places <- NULL
place_year <- NA_integer_
for (year in c(2023, 2024)) {
  louisiana_places <- tryCatch(
    places(
      state = "LA",
      cb = TRUE,
      year = year,
      class = "sf",
      progress_bar = FALSE
    ),
    error = function(e) NULL
  )
  if (!is.null(louisiana_places)) {
    place_year <- year
    break
  }
}
if (is.null(louisiana_places)) {
  stop("Could not download Louisiana place boundaries for 2023 or 2024.")
}

cat("Census place year:", place_year, "\n")
stopifnot("NAME" %in% names(louisiana_places))

if (is.na(st_crs(louisiana_places))) {
  st_crs(louisiana_places) <- 4326
}

place_layer <- louisiana_places |>
  st_transform(4326) |>
  select(GEOID, place_name = NAME)

new_orleans_boundary <- place_layer |>
  filter(place_name == "New Orleans")

if (nrow(new_orleans_boundary) != 1) {
  print(place_layer$place_name[grepl("New", place_layer$place_name)])
  stop("Could not find a single New Orleans place polygon.")
}

# ---- All New Orleans restaurants, as Yelp labeled them ---------------------

restaurant_points <- business |>
  filter(!is.na(longitude), !is.na(latitude)) |>
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
  )

cat("Restaurant points with coordinates:", nrow(restaurant_points), "\n")
cat("Dropped for missing coordinates:", nrow(business) - nrow(restaurant_points), "\n")

restaurants_with_place <- restaurant_points |>
  st_join(place_layer, join = st_within, left = TRUE)

city_vs_place <- restaurants_with_place |>
  st_drop_geometry() |>
  mutate(place_name = if_else(is.na(place_name), "(no Census place)", place_name)) |>
  count(city, place_name, name = "restaurants", sort = TRUE)

cat("\nYelp city compared with the Census place\n")
print(as_tibble(city_vs_place), n = 30)
write.csv(city_vs_place, "data/new_orleans/city_vs_place.csv", row.names = FALSE)

# One example from each place that is not the official city.
# These rows are for the write-up. They are not deleted.
mismatch_examples <- restaurants_with_place |>
  st_drop_geometry() |>
  filter(is.na(place_name) | place_name != "New Orleans") |>
  mutate(place_name = if_else(is.na(place_name), "(no Census place)", place_name)) |>
  group_by(place_name) |>
  arrange(address == "" | is.na(address), .by_group = TRUE) |>
  slice_head(n = 1) |>
  ungroup() |>
  select(business_name, address, postal_code, place_name) |>
  arrange(desc(place_name == "(no Census place)"), place_name)

cat("\nOne example from each mismatched place\n")
print(as_tibble(mismatch_examples), n = 30)
write.csv(
  mismatch_examples,
  "data/new_orleans/place_mismatch_examples.csv",
  row.names = FALSE
)

inside_city <- sum(city_vs_place$restaurants[city_vs_place$place_name == "New Orleans"])
cat(
  "\nPoints inside the New Orleans polygon:",
  inside_city, "of", sum(city_vs_place$restaurants), "\n"
)

# ---- The 108, drawn on the official city polygon ---------------------------

selected_points <- selected |>
  filter(!is.na(longitude), !is.na(latitude)) |>
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
  )

selected_in_city <- selected_points |>
  st_join(
    place_layer |> select(census_place = place_name),
    join = st_within,
    left = TRUE
  )

outside_points <- selected_in_city |>
  filter(is.na(census_place) | census_place != "New Orleans")

cat(
  "\nSelected places inside the official polygon:",
  nrow(selected_in_city) - nrow(outside_points),
  "of", nrow(selected_in_city), "\n"
)
cat("Selected places outside it:\n")
outside_points |>
  st_drop_geometry() |>
  select(business_name, address, postal_code, stars, census_place, latitude, longitude) |>
  as_tibble() |>
  print(n = 10)

sand <- "#EFE6D2"
border <- "#B9AE9A"
ink <- "#2F3B4A"
muted <- "#5B6675"
copper <- c("#F6EAD7", "#EBCBA5", "#DDA673", "#C97E47", "#A85A2A", "#6E3517")

# Include the city and any selected point that falls just outside it.
# Labels sit to the right of those points, so the pad is only a sliver.
west <- min(st_bbox(new_orleans_boundary)[["xmin"]], selected_points$longitude)
east <- st_bbox(new_orleans_boundary)[["xmax"]]
south <- min(st_bbox(new_orleans_boundary)[["ymin"]], selected_points$latitude)
north <- st_bbox(new_orleans_boundary)[["ymax"]]
span_x <- east - west
span_y <- north - south

ggsave(
  "figures/city_boundary.png",
  ggplot() +
    geom_sf(
      data = new_orleans_boundary,
      fill = "grey95",
      color = border,
      linewidth = 0.35
    ) +
    geom_sf(
      data = selected_points,
      aes(color = stars),
      size = 1.7,
      alpha = 0.9
    ) +
    geom_sf_text(
      data = outside_points,
      aes(label = business_name),
      fun.geometry = function(x) x,
      size = 2.7,
      color = ink,
      fontface = "bold",
      hjust = 0,
      nudge_x = 0.01,
      nudge_y = 0.012,
      check_overlap = FALSE
    ) +
    scale_color_gradientn(
      colors = copper,
      limits = c(3.5, 4.5),
      na.value = sand,
      oob = scales::squish,
      name = "Business\nstars"
    ) +
    coord_sf(
      xlim = c(west - span_x * 0.03, east + span_x * 0.03),
      ylim = c(south - span_y * 0.05, north + span_y * 0.04),
      expand = FALSE
    ) +
    labs(
      title = "The 108 places against the official city boundary",
      subtitle = "Grey is the Census place called New Orleans. Copper is the restaurant's Yelp stars.",
      caption = "Labeled points sit outside the grey shape. They stay in the set and out of the area ranking."
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
    ),
  width = 9,
  height = 8,
  dpi = 200,
  bg = "white"
)

cat("\nSaved figures/city_boundary.png\n")
cat("Saved data/new_orleans/city_vs_place.csv\n")
