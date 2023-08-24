# Preprocessing
globalVariables(c("Year", "type"))

# Getting the coordinate sets
Divider = function (line.x, line.y, line.id, r, flag) {

  # Determining the starting point and also determining the center of the first circle
  centerx = line.x[1]
  centery = line.y[1]

  # Building a data container and saving the center of the circle
  line_x = vector()
  line_y = vector()
  line_x = append(line_x, centerx)
  line_y = append(line_y, centery)

  # Traversing the entire line
  for (i in line.id[-1]) {

    # Filtering to points with a distance from the center of the circle slightly greater than the radius
    distance = sqrt((line.x[i] - centerx)**2 + (line.y[i] - centery)**2)
    if (distance >= r) {

      # Recording the new coordinates of the center of the circle
      centerx = line.x[i]
      centery = line.y[i]

      # Saving the center of the circle
      line_x = append(line_x,centerx);
      line_y = append(line_y,centery);
    }
  }

  # Results
  if (length(line_x) == length(line_y)) {

    if (flag) {
      return(length(line_x))
    } else {
      return(data.frame("line_y" = line_y, "line_x" = line_x))
    }
  }
}

# Calculating the dividers fractal dimension
Dividers_Functoin = function (path, r, pearsonValue) {

  # Getting required data
  my_data_sp = readOGR(path, verbose = FALSE)
  my_data_sf = st_as_sf(my_data_sp)
  my_data_dataframe = fortify(my_data_sp)

  # Filtering required data
  line.x = my_data_dataframe$lat
  line.y = my_data_dataframe$long
  line.id = my_data_dataframe$order

  # Calculating the fractal dimension
  results = vector()
  for (i in r) {

    result = Divider(line.x, line.y, line.id, i, TRUE)
    results = append(results, result)
  }
  lgr = log10(r)
  lgnr = log10(results)
  my_data_content = data.frame("lgr" = lgr, "lgnr" = lgnr)

  # Pearson
  pearson = cor(lgr, lgnr, method = "pearson")
  if (abs(pearson) >= pearsonValue) {
    show_info = lm(lgnr ~ lgr, data = my_data_content)
  } else {
    return(NA)
  }

  return(0 - show_info[["coefficients"]][["lgr"]])
}

# Getting the number of boxes
Box = function (my_data_sf, Fishnet) {

  results = vector()
  for (i in Fishnet) {

    my_data_net = read_sf(i)
    result = length(st_intersection(my_data_sf, my_data_net)$Id)
    results = append(results, result)
  }

  return(results)
}

# Calculating the boxes fractal dimension
Boxes_Function = function (path, netPath, n, pearsonValue) {

  # Getting required data
  my_data_sf = read_sf(path)
  Fishnet = list.files(path = netPath,
                       pattern = "*.shp$",
                       all.files = FALSE,
                       full.names = TRUE)

  # Calculating the fractal dimension
  nr = Box(my_data_sf, Fishnet)
  lgn = log10(n)
  lgnr = log10(nr)
  my_data_content = data.frame("lgn" = lgn, "lgnr" = lgnr)

  # Pearson
  pearson = cor(lgnr, lgn, method = "pearson")
  if (abs(pearson) >= pearsonValue) {
    show_info = lm(lgnr ~ lgn, data = my_data_content)
  } else {
    return(NA)
  }

  return(0 - show_info[["coefficients"]][["lgn"]])
}

#'
#' @title CoastlineFD
#'
#' @description Calculate the Coastline Fractal Dimension
#'
#' @usage FD(DinputPath, BinputPath, netPath, outputPath, year, r, pearsonValue, showFlag)
#'
#' @param DinputPath    All density shoreline files path
#' @param BinputPath    All origin shoreline files path
#' @param netPath       All fishnet files path
#' @param outputPath    FD results will be exported here
#' @param year          R vector object, which represent your study time
#' @param r             R vector object, which represent your study scale
#' @param pearsonValue  The Pearson coefficient of your input data
#' @param showFlag      Drawing Function's result
#'
#' @returns An .xlsx file containing the results of the fractal dimension calculation, and a fractal dimension graph
#'
#' @export
#' @import sf
#' @import sp
#' @import rgdal
#' @import readxl
#' @import fields
#' @import writexl
#' @import ggplot2
#' @import progress
#' @import tidyr
#' @import utils
#'
#' @importFrom stats cor lm
#'
#' @examples
#' DinputPath = list.files(system.file('extdata', package = 'CoastlineFD'),full.names = TRUE)[2]
#' BinputPath = list.files(system.file('extdata', package = 'CoastlineFD'),full.names = TRUE)[1]
#' netPath = list.files(system.file('extdata', package = 'CoastlineFD'),full.names = TRUE)[3]
#' outputPath = paste0(system.file('extdata', package = 'CoastlineFD'), "/FD1985_1986.xlsx")
#'
#' FD(
#'   DinputPath,
#'   BinputPath,
#'   netPath,
#'   outputPath,
#'   c(1985:1986),
#'   c(300, 600, 900, 1000, 1050, 1100),
#'   0.00,
#'   TRUE
#' )
#'

# Calculating final results
FD = function (DinputPath, BinputPath, netPath, outputPath, year, r, pearsonValue, showFlag) {

  my_data_D = list.files(path = DinputPath,
                         pattern = "*.shp$",
                         all.files = FALSE,
                         full.names = TRUE)

  my_data_B = list.files(path = BinputPath,
                         pattern = "*.shp$",
                         all.files = FALSE,
                         full.names = TRUE)

  DividersResults = vector()
  BoxesResults = vector()
  N = length(year)
  pb = progress_bar$new(total = N)
  for (i in c(1:N)) {

    # Calculating Dividers_FD from timeline
    DividersResult = Dividers_Functoin(my_data_D[i], r, pearsonValue)
    DividersResults = append(DividersResults, DividersResult)

    # Calculating Boxes_FD from timeline
    BoxesResult = Boxes_Function(my_data_B[i], netPath, r, pearsonValue)
    BoxesResults = append(BoxesResults, BoxesResult)

    # print progress bar
    pb$tick()
    Sys.sleep(0.05)
  }

  FractalDimension = data.frame(
    "Year" = year,
    "DividersFD" = DividersResults,
    "BoxesFD" = BoxesResults
  )
  write_xlsx(FractalDimension, outputPath)

  if (showFlag) {

    tmp = FractalDimension %>% pivot_longer(cols = 2:3, names_to = "type", values_to = "FD")
    tmp %>% ggplot(aes(Year, FD, col = type, group = type)) +
      geom_line(color = "black") +
      geom_point(size = 2) +
      ylab("FractalDimension")
  }
}