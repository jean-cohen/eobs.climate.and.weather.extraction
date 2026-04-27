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

Les données bioclimatiques sont des données moyennées sur une période de référence. Elles sont calculées à partir du package `dismo`. La définition de chauqe variable est disponible ici : https://worldclim.org/data/bioclim.html.

