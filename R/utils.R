#' Extract the `SpatExtent` of a geojson file.
#'
#' `get_extent` loads a raster and extracts its extent.
#'
#' @param filename String. Path to the geojson file from which to extract the 
#' extent.
#'
#' @returns A `SpatExtent` object.
#' @export
get_extent <- function(filename) {
  filename %>%
    sf::st_read(agr = "constant", quiet = TRUE) %>%
    sf::st_bbox() %>%
    terra::ext()
}

#' Extract the `SpatExtent` of mainland France geojson file.
#'
#' `get_france_extent` loads a raster of mainland France and extracts its 
#' extent.
#'
#' @returns A `SpatExtent` object.
#' @export
get_france_extent <- function() {
  filename <- system.file("extdata/metropole.geojson",
                          package = "eobs.climate.and.weather.extraction")
  get_extent(filename)
}

#' Keep the layers of a raster within a specified year span.
#'
#' `crop_years` selects raster layers in a specified time period.
#'
#' @param raster A `SpatRaster` object with a time attribute. 
#' @param start_year String or integer. Lower bound year (included).
#' @param end_year String or integer. Upper bound year (included).
#'
#' @returns A `SpatRaster` with the selected layers.
#' @export
crop_years <- function(raster, start_year, end_year) {
  start_date <- as.Date(paste0(start_year, "-01-01"))
  end_date <- as.Date(paste0(end_year, "-12-31"))
  cropped_raster <- raster %>%
    terra::subset(terra::time(.) >= start_date & terra::time(.) <= end_date)
  return(cropped_raster)
}

#' Rename the layers of a raster according to its time.
#'
#' `rename_time_layers` renames raster layers.
#'
#' @param raster A `SpatRaster` object with a time attribute.
#' @param period String. Period corresponding to the time attribute.
#'
#' @returns A `SpatRaster` with renamed layers.
#' @export
rename_time_layers <- function(raster, period) {
  if (period == "yearmonths") {
    time_names <- format(zoo::as.yearmon(terra::time(raster)), "%Y-%m")
  } else {
    time_names <- terra::time(raster)
  }
  names(raster) <- time_names
  return(raster)
}

#' Transform years, months and days into the correct date format.
#'
#' `make_dates` renames raster layers.
#'
#' @param years Numeric or character vector of length 1 or N ; or `NULL`.
#' @param months Numeric or character vector of length 1 or N ; or `NULL`.
#' @param days Numeric or character vector of length 1 or N ; or `NULL`.
#'
#' @returns A character vector.
#' @export
make_dates <- function(years = NULL, months = NULL, days = NULL) {
  args <- list()
  if (!is.null(years)) {
    args <- c(args, list(as.character(years)))
  }
  if (!is.null(months)) {
    args <- c(args, list(sprintf("%02d", months)))
  }
  if (!is.null(days)) {
    args <- c(args, list(sprintf("%02d", days)))
  }
  return(do.call(paste, c(args, list(sep = "-"))))
}