#!/usr/bin/env /usr/local/share/jupyterhub/env/R/lib/R/bin/Rscript
args = commandArgs(trailingOnly=TRUE)

print (args)

current_dir <- getwd()
data_dir <- 'data'

if (!file.exists(data_dir)){
    dir.create(file.path(current_dir, data_dir))
} else {
    print ("Directory already exists")
}

institutions <- file.path(current_dir, data_dir, args[1])
institutions_url <- 'https://raw.githubusercontent.com/clemsonciti/data-mining-r-workshop/master/institutions.txt'

download.file(institutions_url, institutions)

df_institutions <- read.csv(institutions)

# names including data sources: lengthy but meaningful and maintainable
ncses_institution_profiles_dir <- 'ncses_institution_profiles'

if (!file.exists(file.path(data_dir, ncses_institution_profiles_dir))){
    dir.create(file.path(data_dir, ncses_institution_profiles_dir))
    print ('Create directory ncses_institution_profiles under data')
} else {
    print ("Directory already exists")
}

url_prefix <- 'https://ncsesdata.nsf.gov/profiles/site?method=download&fice='

for (i in 1:nrow(df_institutions)){
    full_url <- paste(url_prefix, df_institutions$FICE[i],sep='')
    institution <- paste(df_institutions$FICE[i],df_institutions$Institutions[i],sep='_')
    institution <- gsub(" ", "_", institution, fixed = TRUE)
    institution <- paste(institution,'.zip',sep='')
    institution_path <- file.path(current_dir,data_dir, ncses_institution_profiles_dir, institution)
    print(full_url)
    print(institution_path)
    download.file(full_url, institution_path, mode = "wb")
    # be courteous to your source:
    sleep_time <- sample(2:6,1)
    print (sleep_time)
    Sys.sleep(sleep_time)
}