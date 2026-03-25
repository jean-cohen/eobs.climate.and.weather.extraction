#' @export
compute_bioclimactic_variables <- function(seasonal_averages) {
  bioclimatic_variables <- dismo::biovars(seasonal_averages$rr[],
                                          seasonal_averages$tn[],
                                          seasonal_averages$tx[])
  ref <- seasonal_averages$tg
  dim(bioclimatic_variables) <- c(ncol(ref), nrow(ref), 19)
  raster <- terra::rast(
    nrows = nrow(ref), ncols = ncol(ref), nlyrs=19, crs = terra::crs(ref),
    extent = terra::ext(ref), resolution = terra::res(ref),
    names = paste0("BIO", 1:19)
  )
  raster[] <- bioclimatic_variables
  return(raster)
}

#' @export
compute_climate_extract <- function(points_df, seasonal_averages,
                                    points_crs = 4326,
                                    interpolation_method = "bilinear") {
  bioclim_raster <- compute_bioclimactic_variables(seasonal_averages)

  points_vect <- points_df %>%
    sf::st_as_sf(coords = c("longitude", "latitude"),
                 crs = sf::st_crs(points_crs), agr = "constant") %>%
    terra::vect()

  climate_extract <- cbind(
    point_id = points_vect$point_id,
    terra::extract(
      bioclim_raster, points_vect, method = interpolation_method, ID = FALSE)
  )
  return(climate_extract)
}
