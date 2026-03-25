#' @export
get_extent <- function(filename) {
  filename %>%
    sf::st_read(agr = "constant", quiet = TRUE) %>%
    sf::st_bbox() %>%
    terra::ext()
}

#' @export
get_france_extent <- function() {
  filename <- system.file("extdata/metropole.geojson",
                          package = "eobs.climate.and.weather.extraction")
  get_extent(filename)
}

#' @export
crop_years <- function(raster, start_year, end_year) {
  start_date <- as.Date(paste0(start_year, "-01-01"))
  end_date <- as.Date(paste0(end_year, "-12-31"))
  cropped_raster <- raster %>%
    terra::subset(terra::time(.) >= start_date & terra::time(.) <= end_date)
  return(cropped_raster)
}
