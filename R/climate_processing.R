#' Computes bioclimatic variables from seasonal averages.
#'
#' `compute_bioclimactic_variables` computes bioclimatic variables from seasonal 
#' averages. 
#'
#' @param seasonal_averages A list of `SpatRaster` objects. Each `SpatRaster` 
#' must have 12 layers, one for each month. The list must contain named objects 
#' for 'tn', 'tx' and 'rr' metrics.
#' 
#' @returns A `SpatRaster` object with 19 layers. Each one corresponds to a 
#' bioclimatic variable as defined on the WorldClim website
#' (https://www.worldclim.org/data/bioclim.html).
#' @export
compute_bioclimactic_variables <- function(seasonal_averages) {
  bioclimatic_variables <- dismo::biovars(seasonal_averages$rr[],
                                          seasonal_averages$tn[],
                                          seasonal_averages$tx[])
  ref <- seasonal_averages$rr
  dim(bioclimatic_variables) <- c(ncol(ref), nrow(ref), 19)
  raster <- terra::rast(
    nrows = nrow(ref), ncols = ncol(ref), nlyrs=19, crs = terra::crs(ref),
    extent = terra::ext(ref), resolution = terra::res(ref),
    names = paste0("BIO", 1:19)
  )
  raster[] <- bioclimatic_variables
  return(raster)
}

#' Get bioclimatic variable values for a series of point locations.
#'
#' `compute_climate_extract` computes bioclimatic variables from seasonal
#' averages and extracts interpolated values at different point locations.
#'
#' @param points_vect A `SpatVector` object. Points where to extract the values.
#' Each row must be identified by a `point_id` column.
#' @param daily_rasters A list of `SpatRaster` objects. Each named `SpatRaster`
#' must contain the daily data for the metrics of interest : 'tn', 'tx' and
#' 'rr'.
#' @param start_year String or integer. Lower bound year (included) to the
#' period on which to evaluate climatic variables.
#' @param end_year String or integer. Upper bound year (included) to the period
#' on which to evaluate climatic variables.
#' @param interpolation_method String. Name of the terra::extract method to use:
#' Method for extracting values with points ('simple' or 'bilinear'). With
#' "simple" values for the cell a point falls in are returned. With 'bilinear'
#' the returned values are interpolated from the values of the four nearest
#' raster cells. Default is 'bilinear'.
#'
#' @returns A data frame containing the extracted value of each bioclimatic
#' variable for each one of the given data points.
#' @export
compute_climate_extract <- function(
  points_vect,
  daily_rasters,
  start_year,
  end_year,
  interpolation_method = "bilinear"
) {
  ## Compute seasonal averages
  aggregation_functions <- list(
    "tn" = mean, # minimal daily temperature
    "tx" = mean, # maximal daily temperature
    "rr" = sum # daily precipitation
  )
  climate_metrics <- names(aggregation_functions)
  climate_normals <- climate_metrics %>%
    stats::setNames(., .) %>%
    lapply(function(code) {
      get_climate_normal(
        daily_rasters[[code]],
        aggregation_functions[[code]],
        start_year,
        end_year
      )
    })

  ## Compute bioclimatic variables
  bioclim_raster <- compute_bioclimactic_variables(climate_normals)

  ## Extract point values
  climate_extract <- cbind(
    point_id = points_vect$point_id,
    terra::extract(
      bioclim_raster,
      points_vect,
      method = interpolation_method,
      ID = FALSE
    )
  )
  return(climate_extract)
}
