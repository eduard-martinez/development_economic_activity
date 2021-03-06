library(dismo)
library(rasterVis)
library(animation)
library(GISTools)
library(SDMTools)
library(ggplot2)



#Mapa 1. OpenStreetMap
pacifico_osm <- openmap(c(8.700, -79.420),c(0.648, -74.928), type="osm", minNumTiles = 15) %>%
  openproj(projection = "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")
plot(pacifico_osm)
plot(black_communities_union, add = T)
raster::scalebar(100, type = "bar", below = "km", divs = 4, xy = click()) #scalebar


#Mapa 2. Raster lignhts
rasters_suma <- stackApply(rasters_lights, indices = rep(1, 35), fun = mean)
plot(rasters_suma, axes = F)
plot(capital_cities_centroids, cex = 0.5, pch = 16, add = T)
plot(colombia, add = T)
plot(black_communities_union, add = T, lty = 3, lwd = 0.5)
plot(pacific_littoral_map_dpto, add = T, lwd = 0.5)
raster::scalebar(200, type = "bar", below = "km", divs = 4, xy = click())



##Extremos
tratados <- merge_rasters_dataframes[merge_rasters_dataframes$treatment == "1", c(42:43)] %>%
tratados <-  SpatialPointsDataFrame(coords = tratados[, c(1,2)], data = tratados, proj4string = crs(rasters_lights))

low <- extremos[extremos[,3] == stack_pacifico_mask[[35]]@data@min,1:2] # min value
plot(stack_pacifico_mask[[35]])
points(tratados, pch=15, col="red")
points(low, pch=15, col="blue")

##ggplot maps

# 1. Prepare data
communities_littoral[[1]]@data$OBJECTID_1 <- rownames(communities_littoral[[1]]@data)
black_communities_points <- tidy(communities_littoral[[1]], region = "OBJECTID_1")
black_communities_polygon <- tidy(black_communities_union)
black_communities_df <- join(black_communities_points, communities_littoral[[1]]@data, by = "OBJECTID_1")


ggplot(black_communities_polygon, aes(x = long, y = lat, group = id)) +
  geom_polygon(colour = "black", fill = "grey80", size = 1) +
  coord_equal() +
  theme()


comunidades_mapa <- ggplot() + geom_polygon(data = communities_littoral[[1]], aes(x = long, y = lat, group =  ID), 
                                            fill = "cadetblue", color="grey")
comunidades_mapa <- comunidades_mapa + coord_equal()+xlim(c(-5000000, 5000000))+ylim(c(1000000, 8000000))



#Maps
setwd("~/Dropbox/BANREP/Pacifico/Primer_DTSER/Mapas_Graficos")

#Map of communities in the Pacific littoral
opar <- par()
par(mar = c(1, 1, 1, 1))
png("comunidades_littoral.png", width = 8.5, height = 9, units = 'in', res = 900)
plot(pacific_littoral_map_dpto, axes = T, main = "Territorios de comunidades negras (1996 - 2015)")
plot(communities_littoral[[1]], add= T, col = heat.colors(22)[communities_littoral[[1]]@data$year], border = NA)
legend("bottomleft", legend = communities_littoral[[1]]@data$year)
dev.off()

#Levelplot distance
png("distancia_littoral.png", width = 8.5, height = 9, units = 'in', res = 900)
levelplot(distance_raster_mask, main = "Distancia por pixel a comunidad negra")
dev.off()

#Histograma
hist(merge_rasters_dataframes$dist_p, main = "Distancia por pixel a comunidades negras", xlab = "Distancia", ylab = "Frecuencia")

#Map of lights over the Pacific littoral (rasters is a list of the rasters for the all the years)
png("litoral_distancias.jpeg", width = 8.5, height = 11, units = 'in', res = 500)
plot(distance_raster_mask)
plot(black_communities_union, border="red", lwd=1, add=T)
dev.off()

#Plot elevation, aspect and hill 
png("aspecto.png", width = 8.5, height =9, units = 'in', res = 900)
plot(hills_pacifico, col = grey(0:100/100), legend = F, main = "Elevación litoral pacífico")
plot(elevation_pacifico, col = rainbow(25, alpha = 0.35), add = T)
plot(pacific_littoral_map_dpto, add = T)
plot(black_communities_union, add= T, border= "grey")
dev.off()

#Export to KML files
lapply(rasters_pacifico, KML)

#Plot distance raster
png("litoral_distancias.jpeg", width = 8.5, height = 11, units = 'in', res = 1000)
plot(distance_raster_mask, main="Distancias a los territorios comunitarios")
plot(black_communities_union, border="red", lwd=1, add=T)
plot(pacific_littoral_map_dpto, add=T)
dev.off()

#Nighlights raster animation
saveGIF({
  ani.options(interval = 1, nmax = 35)
  for(i in c(1:35)){
    plot(stack_pacifico_mask[[i]], col=grey.colors(100))
    plot(pacific_littoral_map_dpto, add = T, main = "Luminosidad por año")
  }
}, movie.name = "light.gif", ani.width = 800, ani.height = 1000)

saveLatex({
  ani.options(interval = 1, nmax = 35)
  for(i in c(1:35)){
    plot(stack_pacifico_mask[[i]], col=grey.colors(100))
    plot(pacific_littoral_map_dpto, add = T, main = "Luminosidad por año")
    map.scale()
  }
}, nmax = 35, interval = 0.5, img.name = "dm_plot",
latex.filename = ifelse(interactive(), "dm_plot_year.tex"))


#Map of lights over the Pacific littoral (rasters is a list of the rasters for the all the years)
png("litoral_comunidades_2013_municipios.png", width = 8.5, height = 9, units = 'in', res = 900)
plot(stack_pacifico_mask[[35]], col=grey.colors(100), main = "Densidad de luz y comunidades negras e indígenas")
plot(communities_littoral[[1]], add=T,  boder= 10, lwd = 1.5)
plot(communities_littoral[[2]], add = T, border = "yellow", lwd = 1.5)
plot(pacific_littoral_map_dpto, lwd=2, border= "red", lwd=1, add=T)
dev.off()


#Timeline economic activity by lights (treatment vs. no-treatment)
rasters_year <- group_by(merge_rasters_dataframes_long, year, treatment) %>%
  summarise(total_dm=sum(dm),
            mean_dm = mean(dm)
)

g3 <- ggplot(rasters_year, aes(x=year, y=total_dm, colour=as.factor(treatment))) + geom_line(size=1)
g3 <- g3 + scale_x_continuous(breaks=c(1992:2013))
g3 <- g3 + theme(axis.text.x = element_text(angle=90, hjust=1, vjust=.5, size = 10),
                 axis.text.y = element_text(size = 10))
g3 <- g3 + labs(x = "Año", y = "Actividad económica (densidad luz)") 
g3 <- g3 + theme(
                 axis.title.x = element_text(face="bold", size=10),
                 axis.title.y = element_text(face = "bold", size = 10))
g3

png("actividad_economica.png", width = 13, height = 9, units = 'in', res = 800)
g3
dev.off()

#Timeline of communitites by year
communities_littoral[[1]]@data$AREA_POLY <- areaPolygon(communities_littoral[[1]])
black_communities_year <- group_by(communities_littoral[[1]]@data, year)
black_communities_year <- summarise(black_communities_year,
                                    total_area = sum(AREA_POLY))
black_communities_year$total_area_km2 <- black_communities_year$total_area/1000000
black_communities_year$year <- as.numeric(levels(black_communities_year$year))

theme_set(theme_gray(base_size = 13))
g4 <- ggplot(black_communities_year, aes(as.numeric(year))) + geom_line(aes(y = total_area_km2), colour = "red", size = 1)
g4 <- g4 + scale_x_continuous(breaks=c(1996:2015))
g4 <- g4 + theme(axis.title.x = element_text(size = 10, face = "bold"),
                 axis.title.y = element_text(size = 13, face = "bold"))
g4 <- g4 + labs(x="Año", y=expression(paste("Área (Km2)")), title="Área asignada a comunidades negras \n(1996 - 2015)") 
g4 <- g4 + theme(plot.title = element_text(size=20, face="bold", margin = margin(10, 10, 10, 10)),
                 axis.title = element_text(face="bold"))
g4

png("area_comunidades.png", width = 13, height = 9, units = 'in', res = 800)
g4
dev.off()


#Histogram of distances
g5 <- ggplot(merge_rasters_dataframes, aes(dist_p)) +
  geom_density(kernel = "triangular", color = "blue")
g5 <- g5 + theme(axis.title.x = element_text(size = 10, face = "bold"),
                 axis.title.y = element_text(size = 13, face = "bold"))
g5 <- g5 + labs(x="Distancia", y=expression(paste("Frecuencia")), title="Densidad de la distancias a las comunidades") 
g5 <- g5 + theme(plot.title = element_text(size=20, face="bold", margin = margin(10, 10, 10, 10)),
                 axis.title = element_text(face="bold"))

png("hist_dist1.png", width = 13, height = 9, units = 'in', res = 800)
g5
dev.off()

#Example to illustrate discontinuity (beamer presentation)
x<-runif(10000,-10,10)
y<-(5+3*x+2*(x>=0)+rnorm(1000))^5
png("ejemplo2.png", width = 13, height = 9, units = 'in', res = 800)
rdplot(y,x, title = "Ejemplo discontinuidad - Datos simulados", x.label = "Tratamiento", 
       y.lab = "Variable dependiente", p = 1)
dev.off()




