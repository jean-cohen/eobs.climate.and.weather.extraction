#' @export
compute_seasonal_average <- function(full_rasters, start_year, end_year) {
  seasonal_average <- full_rasters %>%
    crop_years(start_year, end_year) %>%
    terra::tapp("months", mean) %>%
    terra::subset(., order(terra::time(., "months")))
  return(seasonal_average)
}

#' @export
extract_values <- function(points_vect, raster, layer, mode = "direct",
                           name = "value", method = "bilinear") {
  if (mode == "by_year") {
    return(extract_values_by_year(
      points_vect, raster, layer, name = name, method = method))
  } else {
    extract <- data.frame(point_id = points_vect$point_id)
    extract[[name]] = terra::extract(
      raster, points_vect, method = method, layer = layer)$value
    return(extract)
  }

}

#' @export
extract_values_by_year <- function(points_vect, raster, layer, ...) {
  full_extract <- unique(points_vect$year) %>%
    lapply(function(year_value) {
      filtered_points <- tidyterra::filter(points_vect, year == year_value)
      filtered_raster <- terra::subset(
        raster, terra::time(raster, "years") == year_value)
      extract_values(filtered_points, filtered_raster, layer, ...)
    }) %>%
    dplyr::bind_rows()
  return(full_extract)
}
