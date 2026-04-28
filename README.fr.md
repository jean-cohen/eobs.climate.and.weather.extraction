# Extraction de données bioclimatiques et météorologiques depuis E-OBS
[![en](https://img.shields.io/badge/lang-en-red.svg)](https://github.com/jean-cohen/eobs.climate.and.weather.extraction/blob/main/README.md)
[![fr](https://img.shields.io/badge/lang-fr-blue.svg)](https://github.com/jean-cohen/eobs.climate.and.weather.extraction/blob/main/README.fr.md)

## Installation
```
install.packages("devtools") # si nécessaire
devtools::install_github("jean-cohen/eobs.climate.and.weather.extraction")
library(eobs.climate.and.weather.extraction)
```
Ce package est basé sur les fonctions de `terra`. Pour lire les fichiers E-OBS, le driver `netCDF` doit être installé.
```
# Vérifier l'installation de netCDF
> terra::gdal(drivers = TRUE)

      name raster vector        can  vsi                  long.name
    netCDF   TRUE   TRUE read/write TRUE Network Common Data Format
```

## Données

Pour télécharger les données E-OBS : https://surfobs.climate.copernicus.eu/dataaccess/access_eobs.php#datafiles. Les données sont disponibles pour différentes résolutions (0.1° ou 0.25°), différentes métriques météo (TG, TN, TX, RR, HU, FG, QQ), en valeurs moyennes ('mean') ou en valeurs de dispersion ('spread'). Elles peuvent aussi être téléchargées sur la période complète (depuis 1950) ou par périodes de 15 ans : https://surfobs.climate.copernicus.eu/dataaccess/access_eobs_chunks.php

Les données doivent être téléchargées dans un seul dossier qui contient : 
- les fichiers `.nc` non renommés, éventuellement dans des sous dossiers (optionnels)
- plusieurs métriques éventuellement
- une seule version
- une seule résolution
- soit les données 'mean', soit les données 'spread'
- soit la période complète soit l'ensemble des fichiers par période de 15 ans

Exemple :
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

__Note :__ Pour le calculs des données bioclimatiques, il faut avoir téléchargé les données `mean`: `tx` (température maximale quotidienne), `tn` (température minimale quoitidienne) et `rr` (précipitations quotidiennes).

## Chargement des données

Les données E-OBS sont des rasters sur la région européenne, il est donc utile de les réduire à la zone d'intérêt dès le chargement.
```
# Utilisation d'un fichier .geojson pour la définition de la région d'intérêt
extent <- get_extent("reference_file.geojson")
# Si la région de référence est la France hexagonale
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

## Chargement des points d'extraction

Les points à extraire doivent être au format `SpatVector` et identifiés par une colonne `point_id`. Des colonnes de date d'échantillonnage au format `year`, `month`, `day` peuvent aussi être utiles pour l'extraction des données météo.
Le système de coordonnées (crs) doit être WSG84/ESPG4326.

```
points_vect <- data.frame(point_id = ..., longitude = ..., latitude = ..., year = ..., month = ..., day = ...) %>%
  sf::st_as_sf(coords = c("longitude", "latitude"), crs = sf::st_crs(4326), agr = "constant") %>%
  terra::vect()
```

## Extraction des données bioclimatiques

Les 19 variables bioclimatiques sont calculées sur des données moyennées sur une période de référence. Elles sont calculées à partir de la fonction `dismo::biovars`. La définition de chaque variable est disponible ici : https://worldclim.org/data/bioclim.html.
```
climate_extract <- compute_climate_extract(points_vect, daily_rasters, start_year = 1981, end_year = 2010, interpolation_method = "bilinear")
```
L'extraction de données peut se faire avec interpolation bilinéaire (moyenne pondérée des valeurs de la grille les plus proches) avec`interpolation_method = "bilinear"` ou simple (valeur au centre du pixel de la grille) avec `interpolation_method = "simple"`.

## Extraction des données météorologiques du jour d'échantillonnage
```
# Renommage du raster selon la bonne date :
mean_temp_raster <- rename_time_layers(daily_rasters$tg, "days")
# Dates d'extracttion au bon format :
sampling_dates <- make_dates(points_vect$year, points_vect$month, points_vect$day)

# Data.frame des résultats :
extract_values(points_vect, mean_temp_raster, sampling_dates, name = "temp_current_day", interpolation_method = "bilinear", mode = "by_year")
```
`name` est le nom de la colonne contenant les valeurs extraites, `mode = "by_year"` permet de filtrer successivement selon les années pour travailler sur des données plus petites et réduire le temps de calcul mais nécessite une colonne `year` dans `points_vect`.

## Extraction des anomalies météo du jour d'échantillonnage
```
# Calcul des anomalies météo
reference_temp <- get_climate_normal(daily_rasters$tg, mean, ref_first_year = 1981, ref_last_year = 2010)
daily_ano_temp <- compute_daily_anomalies(daily_temp, reference_temp)
# Retirer les années inutiles à l'extraction
daily_ano_temp <- crop_years(daily_ano_temp, 2008, 2024)

# Data.frame des résultats :
extract_values(points_vect, daily_ano_temp, sampling_dates, name = "ano_temp_current_day", interpolation_method = "bilinear", mode = "by_year")
```

## Extraction des anomalies météo à une date antérieure

### Exemple : un an avant l'échantillonnage
```
# Nouvelles dates d'extraction
one_year_before_sampling <- make_dates(points_vect$year - 1, points_vect$month, points_vect$day)

# Data.frame des résultats :
extract_values(points_vect, daily_ano_temp, one_year_before_sampling, name = "ano_temp_last_year", interpolation_method = "bilinear", mode = "by_year")
```

### Exemple : le mois d'avril précédant l'échantillonnage
```
# Calcul des anomalies mensuelles
monthly_ano_temp <- compute_monthly_anomalies(daily_ano_temp, mean)
# Nouvelles dates d'extraction
last_april <- make_dates(ifelse(points_vect$month > 4, points_vect$year, points_vect$year - 1), 4, NULL)

# Data.frame des résultats :
extract_values(points_vect, monthly_ano_temp, last_april, name = "ano_temp_last_april", interpolation_method = "bilinear")
```

### Exemple : l'hiver avant l'échantillonnage
```
# Calcul des anomalies de l'hiver (de Novembre jusqu'à Mars)
winter_ano_temp <- compute_winter_anomalies(monthly_ano_temp, mean, start_year = 2010, end_year = 2024)
# Nouvelles dates d'extraction
last_winter <- make_dates(ifelse(points_vect$month > 4, points_vect$year, points_vect$year - 1), NULL, NULL)

# Data.frame des résultats :
extract_values(points_vect, winter_ano_temp, last_winter, name = "ano_temp_last_winter", interpolation_method = "bilinear")
```
