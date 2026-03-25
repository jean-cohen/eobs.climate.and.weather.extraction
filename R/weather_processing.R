#' @export
compute_anomalies <- function(raster, seasonal_average) {
  means <- terra::subset(seasonal_average, terra::time(raster, "months"))
  anomalies <- raster - means
  return(anomalies)
}

#' @export
compute_winter_anomalies <- function(anomaly_raster, start_year, end_year) {
  year_span <- start_year:end_year

  raster <- anomaly_raster %>%
    terra::subset(terra::time(., 'months') %in% c(11, 12, 1, 2, 3))

  month_modifier <- c("11" = 1, "12" = 1, "1" = 0, "2" = 0, "3" = 0)
  month_char <- as.character(terra::time(raster, 'months'))
  index <- terra::time(raster, 'years') + month_modifier[month_char]
  filtered <- index %in% year_span

  raster <- raster %>%
    terra::subset(filtered) %>%
    terra::tapp(index[filtered], mean)
  terra::time(raster, 'years') <- year_span
  names(raster) <- year_span
  return(raster)
}


#' @export
compute_weather_extract <- function(points_df, seasonal_averages,
                                    weather_start_year,
                                    weather_end_year,
                                    points_crs = 4326,
                                    interpolation_method = "bilinear") {
  # Prepare rasters
  daily_weather_rasters <- full_rasters %>%
    lapply(function(x) {
      raster <- crop_years(x, weather_start_year - 1, weather_end_year)
      names(raster) <- terra::time(raster)
      return(raster)
    })

  daily_weather_anomalies <- list("tg" = "tg", "rr" = "rr") %>%
    lapply(function(code) {
      compute_anomalies(
        daily_weather_rasters[[code]], seasonal_averages[[code]])
    })

  monthly_weather_anomalies <- daily_weather_anomalies %>%
    lapply(function(x) {
      raster <- terra::tapp(x, "yearmonths", mean)
      names(raster) <- sprintf(
        "%d-%02d", terra::time(raster, "years"), terra::time(raster, "months"))
      return(raster)
    })

  winter_weather_anomalies <- monthly_weather_anomalies %>%
    lapply(compute_winter_anomalies, weather_start_year, weather_end_year)

  # Points transformation
  points_vect <- points_df %>%
    dplyr::mutate(
      current_day = sprintf("%d-%02d-%02d", year, month, day),
      april_current_year = paste0(year, "-04"),
      april_previous_year = paste0(year - 1, "-04"),
      month_previous_year = sprintf("%d-%02d", year - 1, month),
      winter_current_year = as.character(year)
    ) %>%
    sf::st_as_sf(coords = c("longitude", "latitude"),
                 crs = sf::st_crs(points_crs), agr = "constant") %>%
    terra::vect()

  # Extract data
  extract_rasters <- list(
    "temp_current_day" = list(mode = "by_year",
      raster = daily_weather_rasters$tg, layer = "current_day"),
    "prec_current_day" = list(mode = "by_year",
      raster = daily_weather_rasters$rr, layer = "current_day"),
    "ano_temp_current_day" = list(mode = "by_year",
      raster = daily_weather_anomalies$tg, layer = "current_day"),
    "ano_prec_current_day" = list(mode = "by_year",
      raster = daily_weather_anomalies$rr, layer = "current_day"),
    "ano_temp_april_current_year" = list(
      raster = monthly_weather_anomalies$tg, layer = "april_current_year"),
    "ano_prec_april_current_year" = list(
      raster = monthly_weather_anomalies$rr, layer = "april_current_year"),
    "ano_temp_april_previous_year" = list(
      raster = monthly_weather_anomalies$tg, layer = "april_previous_year"),
    "ano_prec_april_previous_year" = list(
      raster = monthly_weather_anomalies$rr, layer = "april_previous_year"),
    "ano_temp_month_previous_year" = list(
      raster = monthly_weather_anomalies$tg, layer = "month_previous_year"),
    "ano_prec_month_previous_year" = list(
      raster = monthly_weather_anomalies$rr, layer = "month_previous_year"),
    "ano_temp_winter_current_year" = list(
      raster = winter_weather_anomalies$tg, layer = "winter_current_year"),
    "ano_prec_winter_current_year" = list(
      raster = winter_weather_anomalies$rr, layer = "winter_current_year")
  )

  weather_extract <- extract_rasters %>%
    mapply(function(args, name) {
      do.call(extract_values, c(
        list(points_vect = points_vect, name = name,
             method = interpolation_method),
        args))}, ., names(.), SIMPLIFY = FALSE) %>%
    purrr::reduce(dplyr::full_join, by = "point_id")

  return(weather_extract)
}
