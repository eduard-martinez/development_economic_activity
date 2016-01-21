library(raster)
library(rgdal)
library(rasterVis)
library(sp)
library(ggplot2)
library(rgdal)
library(maptools)
library(lattice)
library(plyr)
library(grid)
library(dplyr)
library(stringr)


#SpatialPolgon processing: Get administrative shape files and more geographical info. 

#Get administrative GIS data
setwd("/Volumes/LaCie/Datos")
colombia_municipios <- readOGR(dsn = "Geografia", layer="Municipios")
black_territories <- readOGR(dsn = "Comunidades", layer="Tierras de Comunidades Negras (2015) ")
indigenous_territories <- readOGR(dsn = "Resguardos", layer="Resguardos Indigenas (2015) ") 

#Get political GIS data
landmines <- readOGR(dsn = "MAP&MUSE_GIS", layer = "eventos_shape")

#Project CRS of black and indigenous territories (1: blak territories, 2: indigenous territories) and municipalities
reproject_layers <- list(black_territories, indigenous_territories)
layers_reprojected <- lapply(reproject_layers, spTransform, CRS=CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"))
colombia_municipios <- spTransform(colombia_municipios, CRS=CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"))

#Aggregate municipalities to get departments (states)
colombia_municipios_df <- data.frame(colombia_municipios)
colombia_departamentos <- unionSpatialPolygons(colombia_municipios, colombia_municipios$COD_DEPTO)
colombia_municipios_agg <- aggregate(colombia_municipios_df[,2], list(colombia_municipios$COD_DEPTO), sum)
row.names(colombia_municipios_agg) <- as.character(colombia_municipios_agg$Group.1)
colombia_departamentos <- SpatialPolygonsDataFrame(colombia_departamentos, colombia_municipios_agg) #Shape file for departments (made with the join of municipalities. "Group.1" is the depatment code)

#Select only departments and municipalities over the pacific littoral (Chocó, Valle del Cauca, Cauca and Nariño)
pacific_littoral <- c("CAUCA", "CHOCÓ", "VALLE DEL CAUCA", "NARIÑO")
pacific_littoral_map <- colombia_municipios[colombia_municipios@data$NOM_DEPART %in% pacific_littoral, ]

#Filter only communities in the pacific littoral
communities_littoral <- lapply(layers_reprojected, crop, pacific_littoral_map)

#Elevation data
setwd("/Volumes/LaCie/Datos")
download.file(     
url = "http://edcintl.cr.usgs.gov/downloads/sciweb1/shared/topo/downloads/GMTED/Global_tiles_GMTED/300darcsec/mea/W090/10S090W_20101117_gmted_mea300.tif" ,
destfile = "altura_mean_30arc.tif", mode="wb")
elevation <- raster("altura_mean_30arc.tif")

#Open .tif files as a raster (the raster package allow to read these files in the disk and not in the memory, this improves the efficiency of functions in R)
rasterOptions(tmpdir="Volumes/LaCie/tmpraster")
setwd("~")
setwd("/Volumes/LaCie/NOAA2/TIFF/")

#Read rasters and group them into a stack (I used the crop function to cut the rasters to the same extent)
list_raster <- list.files()
rasters <- lapply(list_raster, raster)
rasters_extent <- extent(rasters[[1]]) #We need to put all rasters into the same extent (all have the same resolution)
rasters <- lapply(rasters, setExtent, rasters_extent)
rasters_pacifico <- lapply(rasters, crop, pacific_littoral_map)
stack_pacifico <- stack(rasters_pacifico) #Stack them!

#Once cropped, you can mask the rasters to include all the pixels within the Pacific littoral (if the centroid of the pixel is outside the litroral, its value is set to NA)
stack_pacifico_mask <- mask(stack_pacifico, pacific_littoral_map)

#The same for elevation raster
rasters_extent_pacifico <- extent(stack_pacifico)
elevation_pacifico <- crop(elevation, rasters_extent_pacifico)
elevation_pacifico <- setExtent(elevation_pacifico, rasters_extent_pacifico)#The same for elevation raster

#Extract elevation and light data for each pixel (1*1 km  grid approximately)
stack_pacifico_dataframe <- extract(stack_pacifico, seq_len(ncell(stack_pacifico)), df=TRUE)
elevation_dataframe <- extract(elevation_pacifico, seq_len(ncell(elevation_pacifico)), df=TRUE)
merge_rasters_dataframes <- merge(elevation_dataframe, stack_pacifico_dataframe, by="ID")

#Get black communities by year
communities_littoral[[1]]@data$year <- str_extract(communities_littoral[[1]]@data$RESOLUCION, "[1-2][0, 9][0, 1, 9][0-9]")

#Join black communities territories (create a frontier)
communities_littoral[[1]]$ID <- 1
black_territories_union <- unionSpatialPolygons(communities_littoral[[1]], communities_littoral[[1]]$ID)

#Create a border line from polygons
border_black_territories <- as(black_territories_union, "SpatialLines")
border_black_territories <- as(border_black_territories, "SpatialPoints")


