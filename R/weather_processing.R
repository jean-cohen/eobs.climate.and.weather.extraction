#' Transform a daily raster into a daily anomaly raster.
#'
#' `compute_daily_anomalies` takes a daily anomaly raster and agregates the
#' values for each year x month.
#'
#' @param daily_raster A `SpatRaster` object. It contains the daily data for
#' a metric of interest (temperature or precipitation).
#' @param climate_normal A `SpatRaster` containing the climate normal for each
#' month (12 layers).
#'
#' @returns A `SpatRaster` object containing anomalies for each year x month.
#' @export
compute_daily_anomalies <- function(daily_raster, climate_normal) {
  refs <- terra::subset(climate_normal, terra::time(daily_raster, "months"))
  daily_anomalies <- daily_raster - refs
  daily_anomalies <- rename_time_layers(daily_anomalies, "days")
  return(daily_anomalies)
}

#' Aggregate daily anomalies to get monthly anomalies.
#'
#' `compute_monthly_anomalies` takes a daily anomaly raster and agregates the
#' values for each year x month.
#'
#' @param monthly_anomalies A `SpatRaster` object. Each layer is the anomaly
#' value for a 'days' period.
#' @param agg_fun Function. Function used to aggregate data over a month. Common
#' choices are `mean` (for temperature data) or `sum` (for precipitation data).
#'
#' @returns A `SpatRaster` object containing anomalies for each year x month.
#' @export
compute_monthly_anomalies <- function(daily_anomalies, agg_fun) {
  monthly_anomalies <- daily_anomalies %>%
    terra::tapp("yearmonths", agg_fun) %>%
    rename_time_layers("yearmonths")
  return(monthly_anomalies)
}

#' Aggregate monthly anomalies to get winter anomalies.
#'
#' `compute_winter_anomalies` takes a monthly anomaly raster and agregates the
#' values from November to March.
#'
#' @param monthly_anomalies A `SpatRaster` object. Each layer is the anomaly
#' value for a 'yearmonths' period.
#' @param agg_fun Function. Function used to aggregate data over a month. Common
#' choices are `mean` (for temperature data) or `sum` (for precipitation data).
#' @param start_year String or integer. Lower bound year (included).
#' @param end_year String or integer. Upper bound year (included).
#'
#'
#' @returns A `SpatRaster` object containing anomalies for each winter.
#' @export
compute_winter_anomalies <- function(
  monthly_anomalies,
  agg_fun,
  start_year,
  end_year
) {
  year_span <- start_year:end_year

  raster <- monthly_anomalies %>%
    terra::subset(terra::time(., 'months') %in% c(11, 12, 1, 2, 3))
  month_modifier <- c("11" = 1, "12" = 1, "1" = 0, "2" = 0, "3" = 0)
  month_char <- as.character(terra::time(raster, 'months'))
  index <- terra::time(raster, 'years') + month_modifier[month_char]
  filtered <- index %in% year_span

  winter_anomalies <- raster %>%
    terra::subset(filtered) %>%
    terra::tapp(index[filtered], agg_fun)
  terra::time(winter_anomalies, 'years') <- year_span
  winter_anomalies <- rename_time_layers(winter_anomalies, "years")
  return(winter_anomalies)
}