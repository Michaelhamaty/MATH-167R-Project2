# Where a foodie can stay for a meal in New Orleans

Michael Hamaty

**[Open the report](https://michaelhamaty.github.io/MATH-167R-Project2/yelp_new_orleans_project.html)**

The page has the maps, the charts, the tables, and the R code. Click "View R code" under a chart to see the code.

Leonidas comes out first: 7 places, average 4.43 stars. The French Quarter has 37 places and a lower average, 3.97.

## The foodie set

A restaurant stays in the set when three things are true. It has at least one of these Yelp categories: American (new), cocktail bars, cafes, or seafood. Its name appears at most twice among all New Orleans restaurants, so Ruby Slipper and Dat Dog come out along with Waffle House. At least 5% of its reviews use one of these words: fusion, handmade, courtyard, mural, seasonal, inventive, or omakase. That leaves 108 restaurants.

## Scripts

- [R/import.R](R/import.R) loads the Yelp files and keeps New Orleans restaurants
- [R/categories.R](R/categories.R) builds the 108 and joins their reviews
- [R/places.R](R/places.R) checks the points against the Census city boundary
- [R/areas.R](R/areas.R) compares neighborhoods with census tracts
- [yelp_new_orleans_project.qmd](yelp_new_orleans_project.qmd) is the page source

Reviewer-adjusted scores are not in this report.

## How I defined a "New Orleans restaurant"

A business counts if `state == "LA"`, `city == "New Orleans"`, and its `categories` text contains "Restaurants". That gives **2,259 restaurants** and **476,421 reviews**.

## Files

- `R/download.sh` downloads the two Yelp files from Kaggle
- `data/new_orleans/business_new_orleans.rds` is the filtered businesses
- `data/new_orleans/reviews_new_orleans.rds` is the reviews for those businesses
- `data/new_orleans/selected_restaurants.rds` is the 108
- `docs/yelp_new_orleans_project.html` is the report, with the graphs inside the file

The reviews file is about 74 MB, so it is stored with Git LFS (run `git lfs install` before cloning). Read the saved files with:

```r
business <- readRDS("data/new_orleans/business_new_orleans.rds")
reviews  <- readRDS("data/new_orleans/reviews_new_orleans.rds")
```

## Getting the raw data

The raw JSON files are not in the repo (the review file is about 5 GB). To recreate the data:

```bash
bash R/download.sh        # needs the kaggle CLI + API key
Rscript R/import.R
Rscript R/categories.R
Rscript R/places.R        # downloads a Census place file the first time
Rscript R/areas.R         # downloads census tracts the first time
```

The Yelp Open Dataset is also available from https://www.yelp.com/dataset. Put the unzipped files in `data/raw/`.

## Handling the large files

- My laptop has 8 GB of RAM, so I could not load the 5 GB review file all at once. `stream_in()` reads it in pages of 100,000 reviews and only keeps the ones for New Orleans restaurants.
- Only the needed columns are kept.
- Disk space was tight (about 12 GB free), so I only downloaded the business and review files, and deleted the raw files after saving the RDS files.
- The import takes about 7 minutes.
