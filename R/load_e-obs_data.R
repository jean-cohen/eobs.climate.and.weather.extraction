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
