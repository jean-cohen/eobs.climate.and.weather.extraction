# Extract bioclimatic and weather data from the E-OBS database
[![en](https://img.shields.io/badge/lang-en-red.svg)](https://github.com/jean-cohen/eobs.climate.and.weather.extraction/blob/main/README.md)
[![fr](https://img.shields.io/badge/lang-fr-blue.svg)](https://github.com/jean-cohen/eobs.climate.and.weather.extraction/blob/main/README.fr.md)

## Installation
```
install.packages("devtools") # if necessary
devtools::install_github("jean-cohen/eobs.climate.and.weather.extraction")
library(eobs.climate.and.weather.extraction)
```
This library is built upon `terra`. The `netCDF` driver must be installed to read the E-OBS datafiles.
```
# Check netCDF installation
> terra::gdal(drivers = TRUE)

      name raster vector        can  vsi                  long.name
    netCDF   TRUE   TRUE read/write TRUE Network Common Data Format
```

## Download data

Download the E-OBS datafiles: https://surfobs.climate.copernicus.eu/dataaccess/access_eobs.php#datafiles. Data is available for several gris sizes (0.1° or 0.25°), several weather metrics (TG, TN, TX, RR, HU, FG, QQ) for two statistics: 'mean' or 'spread'. It can be download for the entire time period (since 1950) or in 15-years chunks: https://surfobs.climate.copernicus.eu/dataaccess/access_eobs_chunks.php.

Data must be stored in a single folder containing:
- the `.nc` files, possibly located in subfolders (optional). They should not be renamed.
- at least one weather metric
- a single data version (ex. v31.0e)
- a single data grid resolution (ex. 0.1deg)
- a single statistic ('mean' or 'spread')
- either the complete period or several 15-years chunks

Example :
```
e_obs_v31.0e_0.1deg_mean/
  tg/
    tg_ens_mean_0.1deg_reg_1980-1994_v31.0e.nc
    tg_ens_mean_0.1deg_reg_1995-2010_v31.0e.nc
    tg_ens_mean_0.1deg_reg_2011-2024_v31.0e.nc
  tx/
    tx_ens_mean_0.1deg_reg_1980-1994_v31.0e.nc
    tx_ens_mean_0.1deg_reg_1995-2010_v31.0e.nc
    tx_ens_mean_0.1deg_reg_2011-2024_v31.0e.nc
  tn/
    tn_ens_mean_0.1deg_reg_1980-1994_v31.0e.nc
    tn_ens_mean_0.1deg_reg_1995-2010_v31.0e.nc
    tn_ens_mean_0.1deg_reg_2011-2024_v31.0e.nc
  rr/
    rr_ens_mean_0.1deg_reg_1980-1994_v31.0e.nc
    rr_ens_mean_0.1deg_reg_1995-2010_v31.0e.nc
    rr_ens_mean_0.1deg_reg_2011-2024_v31.0e.nc
```

__Note :__ In order to compute bioclimatic data, the folder must contain 'mean' data for: `tx` (daily maximal temperature), `tn` (daily minimal temperature) et `rr` (daily precipitation sum).

## Load data

E-OBS data consists of raster images covering the European region, so it is helpful to crop them to the area of interest as soon as they are loaded.
```
# Using a reference .geojson file to get the extent of the area of interest
extent <- get_extent("reference_file.geojson")
# If the area of interest is mainland France:
extent <- get_france_extent()
```
```
daily_rasters <- list(
  "tg" =  load_nc_as_raster("tg", "e_obs_v31.0e_0.1deg_mean", extent),
  "tx" =  load_nc_as_raster("tx", "e_obs_v31.0e_0.1deg_mean", extent),
  "tn" =  load_nc_as_raster("tn", "e_obs_v31.0e_0.1deg_mean", extent),
  "rr" =  load_nc_as_raster("rr", "e_obs_v31.0e_0.1deg_mean", extent)
)
```

## Load point locations of extraction

The point where to extract data from must be in the `SpatVector` terra format, each must have an identifier stored in the `point_id` column. Three columns containing sampling dates (`year`, `month` and `day`) can also be useful to extract weather data. The coordinate system (CRS) must be WSG84/ESPG4326.

```
points_vect <- data.frame(point_id = ..., longitude = ..., latitude = ..., year = ..., month = ..., day = ...) %>%
  sf::st_as_sf(coords = c("longitude", "latitude"), crs = sf::st_crs(4326), agr = "constant") %>%
  terra::vect()
```

## Extract bioclimatic variables

The 19 bioclimatic variables are calculated with data aggregated on a reference period. They are comuted with the `dismo::biovars` function. Definitions can be found here: https://worldclim.org/data/bioclim.html.
```
climate_extract <- compute_climate_extract(points_vect, daily_rasters, start_year = 1981, end_year = 2010, interpolation_method = "bilinear")
```
Data point extraction can be done with either a bilinear interpolation (values averaged accordind to theid distance with the four closest pixel centers) with `interpolation_method = "bilinear"` or a simple interpolation (closest pixel center) with `interpolation_method = "simple"`.

## Extract weather data at the sampling date
```
# Renamming the raster with the correct date:
mean_temp_raster <- rename_time_layers(daily_rasters$tg, "days")
# Put extraction dates in the correct format:
sampling_dates <- make_dates(points_vect$year, points_vect$month, points_vect$day)

# Data.frame of the results:
extract_values(points_vect, mean_temp_raster, sampling_dates, name = "temp_current_day", interpolation_method = "bilinear", mode = "by_year")
```
`name` is the name of the column containing extrated values. `mode = "by_year"` successively filters along the years to work with smaller rasters and reduce computation time. It requires a `year` column in `points_vect`.

## Extract weather anomalies at the sampling date
```
# Compute weather anomalies
reference_temp <- get_climate_normal(daily_rasters$tg, mean, ref_first_year = 1981, ref_last_year = 2010)
daily_ano_temp <- compute_daily_anomalies(daily_temp, reference_temp)
# Remove unnecessary layers
daily_ano_temp <- crop_years(daily_ano_temp, 2008, 2024)

# Data.frame of the results:
extract_values(points_vect, daily_ano_temp, sampling_dates, name = "ano_temp_current_day", interpolation_method = "bilinear", mode = "by_year")
```

## Extract weather anomalies at a previous date

### Example: one year before sampling
```
# New extraction dates
one_year_before_sampling <- make_dates(points_vect$year - 1, points_vect$month, points_vect$day)

# Data.frame of the results:
extract_values(points_vect, daily_ano_temp, one_year_before_sampling, name = "ano_temp_last_year", interpolation_method = "bilinear", mode = "by_year")
```

### Example: in April before sampling
```
# Compute monthly anomalies
monthly_ano_temp <- compute_monthly_anomalies(daily_ano_temp, mean)
# New extraction dates
last_april <- make_dates(ifelse(points_vect$month > 4, points_vect$year, points_vect$year - 1), 4, NULL)

# Data.frame of the results:
extract_values(points_vect, monthly_ano_temp, last_april, name = "ano_temp_last_april", interpolation_method = "bilinear")
```

### Example: during the winter before sampling
```
# Compute winter anomalies (from November to March)
winter_ano_temp <- compute_winter_anomalies(monthly_ano_temp, mean, start_year = 2010, end_year = 2024)
# New extraction dates
last_winter <- make_dates(ifelse(points_vect$month > 4, points_vect$year, points_vect$year - 1), NULL, NULL)

# Data.frame of the results:
extract_values(points_vect, winter_ano_temp, last_winter, name = "ano_temp_last_winter", interpolation_method = "bilinear")
```
