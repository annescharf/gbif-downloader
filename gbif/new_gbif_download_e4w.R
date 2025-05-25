## this scrip downloads data from GBIF with the following criteria:
# - download critera:
# * scientific name: Aves
# * occurrence status: present
# * has geospatial issue: F
# * has coordinates: T
# * coordinate uncertainty in meters: 0-100
# * year: between beginning of year xx (eg. 2013) and end of year xx (eg. 2022) - always 10 years
# * restricted to a polygon drawn around Europe 

### for testing:
## use a smaller timerange, e.g. 2-3 years
## use the polygon corresponding to "metnau" that is commented out

library(rgbif)
library(readr)

########################
# set credentials gbif #    ADJUST!!!!
########################
usethis::edit_r_environ()
# GBIF_USER="xxx"
# GBIF_PWD="xxx"
# GBIF_EMAIL="xxx@xx"

########################
# Define download path #    ADJUST!!!!
########################
download_path <- "/home/ascharf/Documents/Projects/E4Warning/gbif_download/" 

#########################
# define the year range #    ADJUST!!!!
#########################
end_year <- 2025
timeSpan <- 10 # years


###################
# Geographic area #
###################
# region_polygon <- "POLYGON((-26.01051 33.20471,-25.27652 33.20471,47.9298 32.46067,48.89006 71.94297,-25.27652 71.22729,-26.01051 71.22729,-26.01051 33.20471))" ## Europe
region_polygon <- "POLYGON((8.96136 47.7155,9.02477 47.7155,9.02477 47.74642,8.96136 47.74642,8.96136 47.7155))" ## Metnau - for testing


###########################
# create download request #
###########################
todayDate <- gsub("-","_",Sys.Date())
output_path <- file.path(download_path, todayDate) ## top folder is named after the date of download
dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
start_year <- end_year-(timeSpan-1)
occ_d <- occ_download(
  pred("hasGeospatialIssue", FALSE),
  pred("hasCoordinate", TRUE),
  pred("occurrenceStatus", "PRESENT"),
  pred_and(pred_gte("year", start_year), pred_lte("year", end_year)),
  pred_within(region_polygon),
  pred("taxonKey", 212),  
  pred_lte("coordinateUncertaintyInMeters", "100"),
  format = "SIMPLE_CSV"
)

#str(occ_d)

download_key <- as.character(occ_d)
print(download_key)

zip_file <- file.path(output_path, paste0(download_key, ".zip"))

occ_download_wait(occ_d) # check now and again, as connection fails. Status can also be looked up on gbif webpage - https://www.gbif.org/user/download
dwn <- occ_download_get(occ_d, path = output_path)
# dta <- occ_download_import(dwn) # if dwn is loaded, else
# dta <- occ_download_import(as.download(zip_file))

## unzip the RDS to get access to the csv to extract species tables
unzip(dwn[[1]], exdir = output_path)

############################
# get citation and save it #
############################
# Occurrence data downloads (https://www.gbif.org/citation-guidelines#occDataDownload)
citation_text <- attr(occ_d, "citation")
citation_file <- file.path(output_path, paste0("GBIF_citation_", download_key, ".txt"))
writeLines(citation_text, citation_file)

###########################################
# get all species names included in table #
###########################################
csv_file <- file.path(output_path, paste0(download_key, ".csv"))  ##make sure we have correct file name

dir.create(file.path(output_path, "gbifData"), showWarnings = FALSE)
rds_path <- file.path(output_path, "gbifData", paste0("species_in_", download_key, ".rds"))

## the table is to large and cannot be read in (R crashes), therefore one column sps in read in
spsCol <- read_delim(csv_file, 
                     delim="\t",
                     col_select = "species")
#head(spsCol)

spsunique <- unique(spsCol$species)
length(spsunique)

saveRDS(spsunique, rds_path)

######################################
# extract and save table per species #
######################################
species_tables_folder <- file.path(output_path, "gbifData", paste0("spsTBof_", download_key))
dir.create(species_tables_folder, showWarnings = FALSE, recursive = TRUE)

spsL <- readRDS(rds_path)
## table is lo large to read in, so only relevant lines (species) are read in
lapply(spsL, function(x){
  print(x)
  subDF <- read_delim(pipe(paste0("cat ","'",csv_file,"'"," | grep ","'",x,"\\|species","'")),delim="\t")
  print(nrow(subDF))
  saveRDS(subDF, paste0(species_tables_folder,"/",gsub(" ","_",x),".rds"))
})


### checking if all tables are created, if not, run again those that are missing. ####

spsLasFn <- paste0(gsub(" ","_",spsL),".rds")
lf <- list.files(species_tables_folder, pattern = "\\.rds$", full.names = F)

missingSps <- setdiff(spsLasFn, lf)

#missingSps <- missingSps[-1]

misSpsNms <- gsub(".rds","",gsub("_"," ",missingSps))

lapply(misSpsNms, function(x){
  print(x)
  subDF <- read_delim(pipe(paste0("cat ","'",csv_file,"'"," | grep ","'",x,"\\|species","'")),delim="\t")
  print(nrow(subDF))
  saveRDS(subDF, paste0(species_tables_folder,gsub(" ","_",x),".rds"))
})
