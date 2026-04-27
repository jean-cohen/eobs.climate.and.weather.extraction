#' Load E-OBS data as a SpatRaster
#'
#' `load_nc_as_raster` loads ans combines NetCDF files for a given metric.
#'
#' @param code String. Metric identifier, must correspond to data available in 
#' the E-OBS folder. 'tg' for temperature mean, 'rr' for precipitations, other 
#' metrics are available on the E-OBS website 
#' (https://www.ecad.eu/download/ensembles/download.php).
#' @param eobs_path String. Path to the folder containing the E-OBS data. No 
#' specific structure is needeed. Make sure that only one version and one grid 
#' size is in the folder and that filenames were not renamed.
#' @param extent A `SpatExtent` object. Extent of the desired crop. Optional. 
#' If `NULL` (default) is provided, the default extent will be used. The 
#' specified extent must be within the E-OBS data full extent.
#'
#' @returns A `SpatRaster` containing the daily data for the given metric. Data 
#' from different period is stacked in chronological order.
#' @export
load_nc_as_raster <- function(code, eobs_path, extent = NULL) {
  if (is.null(extent)) {
    load_func <- terra::rast
  } else {
    load_func <- function(x) terra::crop(terra::rast(x), extent)
  }
  raster <- sprintf("%s_ens_mean_.*\\.nc", code) %>%
    list.files(eobs_path, pattern = ., recursive = TRUE, full.names = TRUE) %>%
    sort() %>%
    lapply(load_func) %>%
    terra::rast()
  return(raster)
}
