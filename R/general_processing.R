#' Transform rasters of daily values to raster of monthly aggregated values.
#'
#' `get_climate_normal` aggregates data on a given period with a given
#' aggregating function.
#'
#' @param daily_raster A `SpatRaster` object. It contains the daily data for
#' a metric of interest (temperature or precipitation).
#' @param agg_fun Function. Function used to aggregate data over a month. Common
#' choices are `mean` (for temperature data) or `sum` (for precipitation data).
#' @param start_year String or integer. Lower bound year (included).
#' @param end_year String or integer. Upper bound year (included).
#'
#' @returns A `SpatRaster` containing the climate normal for each month (12
#' layers).
#' @export
get_climate_normal <- function(
  daily_raster,
  agg_fun,
  start_year,
  end_year
) {
  seasonal_average <- daily_raster %>%
    crop_years(start_year, end_year) %>%
    ## Aggregate data by year*month
    terra::tapp("yearmonths", agg_fun) %>%
    ## Average over all months
    terra::tapp("months", mean) %>%
    terra::subset(., order(terra::time(., "months")))
  return(seasonal_average)
}

#' Extract values for a series of points from certain layers of a given raster.
#'
#' `extract_values` uses terra::extract to return values at given locations.
#'
#' @param points_vect A `SpatVector` object. Points where to extract the values.
#' Each row must be identified by a `point_id` column. A `year` column is needed
#' if `mode == 'by_year'`.
#' @param raster A `SpatRaster` object to extract data from.
#' @param layers A character vector. List of `raster` layer names to extract
#' data from for each geometry.
#' @param mode String. 'direct' (default) of 'by_year'. With 'direct' all data
#' is extracted from the entire `raster`. With 'by_year', data is extracted year
#' by year in order to reduce the size of the raster and to ease calculation.
#' @param name String. Name of the column to be created containing the extracted
#' value for each point.
#' @param interpolation_method String. Name of the terra::extract method to use:
#' Method for extracting values with points ('simple' or 'bilinear'). With
#' "simple" values for the cell a point falls in are returned. With 'bilinear'
#' the returned values are interpolated from the values of the four nearest
#' raster cells. Default is 'bilinear'.
#'
#' @returns A dataframe containing the extracted values in a column named by
#' `name` and identified with `point_id`.
#' @export
extract_values <- function(
  points_vect,
  raster,
  layers,
  mode = "direct",
  name = "value",
  interpolation_method = "bilinear"
) {
  if (mode == "by_year") {
    return(extract_values_by_year(
      points_vect,
      raster,
      layers,
      name = name,
      interpolation_method = interpolation_method
    ))
  } else {
    extract <- data.frame(point_id = points_vect$point_id)
    extract[[name]] = terra::extract(
      raster,
      points_vect,
      method = interpolation_method,
      layer = layers
    )$value
    return(extract)
  }
}

#' Extract values for a series of points from certain layers of a given raster.
#'
#' `extract_values_by_year` selects data year by year and calls `extract_values`
#' successively to work with smaller rasters.
#'
#' @param points_vect A `SpatVector` object. Points where to extract the values.
#' Each row must be identified by a `point_id` column. A `year` column is needed
#' if `mode == 'by_year'`.
#' @param raster A `SpatRaster` object to extract data from.
#' @param layers A character vector. List of `raster` layers names to extract
#' data from for each geometry.
#' @param name String. Name of the column to be created containing the extracted
#' value for each point.
#' @param interpolation_method String. Name of the terra::extract method to use:
#' Method for extracting values with points ('simple' or 'bilinear'). With
#' "simple" values for the cell a point falls in are returned. With 'bilinear'
#' the returned values are interpolated from the values of the four nearest
#' raster cells. Default is 'bilinear'.
#'
#' @returns A dataframe containing the extracted values in a column named by
#' `name` and identified with `point_id`.
#' @export
extract_values_by_year <- function(points_vect, raster, layers, ...) {
  full_extract <- unique(points_vect$year) %>%
    lapply(function(year_value) {
      filtered_points <- tidyterra::filter(points_vect, year == year_value)
      filtered_raster <- terra::subset(
        raster,
        terra::time(raster, "years") == year_value
      )
      filtered_layers <- layers[points_vect$year == year_value]
      extract_values(filtered_points, filtered_raster, filtered_layers, ...)
    }) %>%
    dplyr::bind_rows()
  return(full_extract)
}