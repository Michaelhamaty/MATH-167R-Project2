#!/bin/bash
# download.sh
# Downloads the Yelp business and review files from Kaggle
# (needs the kaggle CLI and a ~/.kaggle/kaggle.json API key).
# Run from the Project2 folder:  bash R/download.sh

mkdir -p data/raw/dl

# The kaggle CLI saves each file as a zip, even though the name ends in .json,
# so download into a temp folder and rename to .zip
for f in business review; do
  kaggle datasets download yelp-dataset/yelp-dataset \
    -f yelp_academic_dataset_$f.json -p data/raw/dl
  mv data/raw/dl/yelp_academic_dataset_$f.json data/raw/$f.zip
done

rmdir data/raw/dl
