#!/usr/bin/env Rscript
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : openair-charts.R
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#
#   GRAFICI INQUINANTI OPENAIR
#
#   ONLINE RESOURCE:
#       https://davidcarslaw.github.io/openair/
#
#   EXTERNAL SCRIPT:
#       /data/bin/.../openair/inquinanti.R
#
#   PACKAGES:
#       install.packages("RPostgreSQL")
#       install.packages("futile.logger")
#       install.packages("openair")
#       install.packages("stringi")
#
#   "OPENAIR" PACKAGE'S USED FUNCTIONS:
#       "windRose" & "pollutionRose": The traditional wind rose plot that plots
#                                     wind speed and wind direction by
#                                     different intervals.
#                                     The pollution rose applies the same plot
#                                     structure, but substitutes other
#                                     measurements, most commonly a pollutant
#                                     time series, for wind speed.
#       https://davidcarslaw.github.io/openair/reference/windRose.html
#
#       "polarPlot": Function for plotting pollutant concentration in polar
#                    coordinates showing concentration by wind speed (or
#                    another numeric variable) and direction.
#       https://davidcarslaw.github.io/openair/reference/polarPlot.html
#
#       "polarAnnulus": Typically plots the concentration of a pollutant
#                       by wind direction and as a function of time
#                       as an annulus.
#       https://davidcarslaw.github.io/openair/reference/polarAnnulus.html
#
#   RUN EXAMPLE:
#       (jq_id)   $ Rscript openair-charts.R 1
#
#        # server ecometer-mngt
#        /usr/bin/Rscript /data/bin/.../openair/openair-charts.R 101
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# clean workspace
rm(list = ls(all = TRUE))

#------------------------------------------------------------------------------

# set timezone
Sys.setenv(TZ = "UTC")

#------------------------------------------------------------------------------

# load libraries
library(lubridate, warn.conflicts = FALSE)
library(stringi)
library(openair)

#------------------------------------------------------------------------------

# set application working directory
setwd("/path/to/script/openair")

#------------------------------------------------------------------------------

# load common function library
source("./common/lib_functions.R")
source("./common/lib_pgsql.R")
source("config.R")

#------------------------------------------------------------------------------

# command line arguments
args <- commandArgs(trailingOnly = TRUE)

# check arguments
if (length(args) != 1) {
    stop("Argument missing. Sample: Rscript openair-charts.R 101")
} else {
    jobid <- args[1]
}

#------------------------------------------------------------------------------

# custom functions

#' Get station name and fulltable name (schema + table)
#'
#' @param station_id Station ID.
#'
#' @return Station name and fulltable name.
#'
#' @examples
#' metadata <- get_station_metadata(stid_p)
#' metadata <- get_station_metadata(1000)
q_metadata <- function(station_id) {
    flog.info("metadata query...")
    query <- paste0("
        SELECT
            station_name,
            station_schema || '.' || station_table AS station_fulltable
        FROM metadata.stations
        WHERE station_id = ", station_id, ";
    ")
    return(PG.ExecuteQuery(dbh, query))
}

#' Get wind/pollutant data of a given station.
#'
#' @param label Parameter label.
#' @param date_start Period start date.
#' @param date_end Period end date.
#' @param station_fulltable Station fulltable name.
#' @param stpr_table_id Parameter table ID.
#'
#' @return Station wind/pollutant data.
#'
#' @examples
#' data <- q_station_data(
#'     "ws",
#'     start_d,
#'     end_d,
#'     w_station_fulltable,
#'     ws_table_id
#' )
#' data <- q_station_data(
#'     "ws",
#'     "2022-01-01",
#'     "2022-12-31",
#'     "client_xxxx.prov_nome_staz",
#'     19
#' )
q_data <- function(label,
                param_conv,
                date_start,
                date_end,
                station_fulltable,
                stpr_table_id) {
    flog.info("data query...")
    query <- paste0("
        WITH t AS (
            SELECT fulldate_series AS measure_date_time
            FROM generate_series
            ( '", date_start, "'::timestamp
            , '", date_end, " 23:59:59'::timestamp
            , '1 hour'::interval) s(fulldate_series)
        )
        SELECT
            t.measure_date_time AS \"date\",
            ROUND(CAST(d.measure_value * ", param_conv, " AS numeric), 1) AS ", label, "
        FROM t
        LEFT JOIN ", station_fulltable, " d ON t.measure_date_time = d.measure_date_time
         AND d.measure_id = ", stpr_table_id, "
         AND d.post_validity_code >= 0
        ORDER BY \"date\";
    ")

    return(PG.ExecuteQuery(dbh, query))
}

#------------------------------------------------------------------------------

# init logging - TRACE, DEBUG, INFO, WARN, ERROR, FATAL
# function(LOG.path, LOG.name)
# NOTSET FINEST FINER FINE DEBUG INFO WARNING
#      0      1     4    7    10   20      30
log_path <- file.path(getwd(), "log")

LOG.Init(10, log_path, "openair-charts")

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# start up
flog.debug(" ################### - START UP - ################### ")
#flog.info(Sys.getlocale())
Sys.setlocale("LC_CTYPE", "it_IT.utf8")
#options(encoding = "it_IT.utf8")
flog.info(Sys.getlocale())

#------------------------------------------------------------------------------

# disconnect all connection from db
PG.DisconnectAll()

#------------------------------------------------------------------------------

# connect to database server
flog.info("connection to db")
dbh <- PG.Connect(db_conf)

#------------------------------------------------------------------------------
# get job info
flog.info("job job info...")
query <- paste0("
    SELECT * FROM
    jsonb_to_record(
        ( SELECT jq_args_obj FROM clients.jobs_queue j2 WHERE jq_id = ", jobid, " )
    ) AS x(
        start_d     text,
        end_d       text,
        stid_p      text,
        stid_w      text,
        w_calm      text,
        inst_cat    text,
        l_lim       text,
        u_lim       text,
        scale_type  text,
        scale_opt   text
    )"
)
job <- PG.ExecuteQuery(dbh, query)

# check job
if (is.na(job$start_d)) {
    stop("Job does not exist!")
}

# "end_d": "2023-04-07",
# "l_lim": "5.5",
# "u_lim": "180.55",
# "stid_p": "1000",
# "stid_w": "1000",
# "w_calm": "0.5",
# "start_d": "2022-04-07",
# "inst_cat": "-1",
# "scale_opt": "",
# "scale_type": 0

# get data
start_d    <- job$start_d
end_d      <- job$end_d
stid_p     <- job$stid_p
stid_w     <- job$stid_w
inst_cat   <- job$inst_cat
w_calm     <- job$w_calm
l_lim      <- job$l_lim
u_lim      <- job$u_lim
scale_type <- job$scale_type
scale_opt  <- job$scale_opt
flog.info(paste0("job start_d: ", start_d, ", end_d: ", end_d))
flog.info(paste0("job stid_p: ", stid_p, ", stid_w: ", stid_w))
flog.info(paste0("job inst_cat: ", inst_cat, ", wind-calm: ", w_calm))
flog.info(paste0("job limit-low: ", l_lim, ", limit-high: ", u_lim))
flog.info(paste0("job scale_type: ", scale_type, ", scale_opt: ", scale_opt))

# convert string list to numeric list
scale_opt <- strsplit(scale_opt, ",")
scale_opt <- as.numeric(unlist(scale_opt))

#------------------------------------------------------------------------------

# temp dir
flog.info("> Create temp dir ")
current_timestamp <- round(as.numeric(Sys.time()) * 1000)
flog.info(paste0("current timestamp: ", current_timestamp))
tmp_path <- paste0(current_timestamp, "_", stri_rand_strings(1, 8, pattern = "[a-z]")) # [a-z0-9]
#flog.info(paste0("temp dir: ", tmp_path))
tmp_path_full <- file.path("./charts", tmp_path)
flog.info(paste0("Create dir: ", tmp_path_full))
dir.create(tmp_path_full, showWarnings = FALSE)

# external program path
external_program <- file.path(getwd(), "inquinanti.R")

#------------------------------------------------------------------------------

# check if instrument category is not provided
if (inst_cat == -1) {
    flog.info("> get ALL data")

    pollutants <- data.frame(
        poll_param_id = c(
            29, # SO2
            30, # NOx
            32, # NO2
            31, # NO
            33, # CO
            34, # O3
            38, # Benzene
            39, # Toluene
            41, # Ethylbenzene
            50, # PM10
            48  # PM2.5
        ),
        poll_name = c(
            "so2",
            "nox",
            "no2",
            "no",
            "co",
            "o3",
            "ben",
            "tol",
            "etil",
            "pm10",
            "pm25"
        ),
        stringsAsFactors = FALSE
    )

    n_params <- nrow(pollutants)

    limiti <- list(
        so2 = c(0, 60),
        nox = c(0, 150),
        no2 = c(0, 80),
        no = c(0, 40),
        co = c(0, 2),
        o3 = c(0, 120),
        ben = c(0, 50),
        tol = c(0, 50),
        etil = c(0, 50),
        pm10 = c(0, 50),
        pm01 = c(0, 50),
        pm4 = c(0, 50),
        pm25 = c(0, 50),
        pmtot = c(0, 50)
    )
} else {
    flog.info("> get data per instrument category")

    # for PM10, PM2.5 ((hack) per lo switch)
    if (dust_poll <- inst_cat %in% c("10", "14", "16")) {
        inst_cat <- "pm"
    }

    # switch case to set only the requested parameter/s
    switch(inst_cat,
        "1" = { # Analizzatore SO2
            flog.info("Analizzatore SO2")

            pollutants <- data.frame(
                poll_param_id = c(
                    29 # SO2
                ),
                poll_name = c(
                    "so2"
                ),
                stringsAsFactors = FALSE
            )

            n_params <- nrow(pollutants)

            limiti <- list(
                so2 = c(0, 60)
            )
        },
        "2" = { # Analizzatore NOx
            flog.info("Analizzatore NOx")

            pollutants <- data.frame(
                poll_param_id = c(
                    30, # NOx
                    32, # NO2
                    31  # NO
                ),
                poll_name = c(
                    "nox",
                    "no2",
                    "no"
                ),
                stringsAsFactors = FALSE
            )

            n_params <- nrow(pollutants)

            limiti <- list(
                nox = c(0, 150),
                no2 = c(0, 80),
                no = c(0, 40)
            )
        },
        "3" = { # Analizzatore CO
            flog.info("Analizzatore CO")

            pollutants <- data.frame(
                poll_param_id = c(
                    33 # CO
                ),
                poll_name = c(
                    "co"
                ),
                stringsAsFactors = FALSE
            )

            n_params <- nrow(pollutants)

            limiti <- list(
                co = c(0, 2)
            )
        },
        "4" = { # Analizzatore O3
            flog.info("Analizzatore O3")

            pollutants <- data.frame(
                poll_param_id = c(
                    34 # O3
                ),
                poll_name = c(
                    "o3"
                ),
                stringsAsFactors = FALSE
            )

            n_params <- nrow(pollutants)

            limiti <- list(
                o3 = c(0, 120)
            )
        },
        "5" = { # Analizzatore BTX
            flog.info("Analizzatore BTX")

            pollutants <- data.frame(
                poll_param_id = c(
                    38, # Benzene
                    39, # Toluene
                    41  # Ethylbenzene
                ),
                poll_name = c(
                    "ben",
                    "tol",
                    "etil"
                ),
                stringsAsFactors = FALSE
            )

            n_params <- nrow(pollutants)

            limiti <- list(
                ben = c(0, 50),
                tol = c(0, 50),
                etil = c(0, 50)
            )
        },
        "pm" = { # Polveri
            flog.info("Polveri")

            pollutants <- data.frame(
                poll_param_id = c(
                    50, # PM10
                    48  # PM2.5
                ),
                poll_name = c(
                    "pm10",
                    "pm25"
                ),
                stringsAsFactors = FALSE
            )

            n_params <- nrow(pollutants)

            limiti <- list(
                pm10 = c(0, 50),
                pm01 = c(0, 50),
                pm4 = c(0, 50),
                pm25 = c(0, 50),
                pmtot = c(0, 50)
            )
        }
    )
}

# valid data percentage for graphs creation
lim_dati <- 0.2

# wind data
flog.info(paste("Query dati stazione meteo ", stid_w))

dbdata <- q_metadata(stid_w)
w_station_fulltable <- dbdata$station_fulltable
w_station_name <- dbdata$station_name

# wind speed = 19
query <- paste0("
    SELECT
        stpr_table_id,
        param_conv
    FROM metadata.stations_parameters
    LEFT JOIN metadata.parameters USING (param_id)
    WHERE station_id = ", stid_w, "
    AND param_id = 19
")
res <- PG.ExecuteQuery(dbh, query)
ws_param_conv <- res$param_conv
ws_table_id <- res$stpr_table_id

# wind direction = 22
query <- paste0("
    SELECT
        stpr_table_id,
        param_conv
    FROM metadata.stations_parameters
    LEFT JOIN metadata.parameters USING (param_id)
    WHERE station_id = ", stid_w, "
    AND param_id = 22
")
res <- PG.ExecuteQuery(dbh, query)
wd_param_conv <- res$param_conv
wd_table_id <- res$stpr_table_id

# wind data query
ws_data <- q_data(
    "ws",
    ws_param_conv,
    start_d,
    end_d,
    w_station_fulltable,
    ws_table_id
)
wd_data <- q_data(
    "wd",
    wd_param_conv,
    start_d,
    end_d,
    w_station_fulltable,
    wd_table_id
)

wind_data <- merge(ws_data, wd_data)

# pollutants data
flog.info(paste("Query dati stazione chimici ", stid_p))

dbdata <- q_metadata(stid_p)
p_station_fulltable <- dbdata$station_fulltable
p_station_name <- dbdata$station_name

# loop per parameter
# initialize the dataframe with the dates extracted earlier for the wind
pollutants_data <- data.frame(date = wind_data$date)

for (row in 1:n_params) {
    param_id <- pollutants[row, "poll_param_id"]
    param_name <- pollutants[row, "poll_name"]

    # parameters query (++ check if linked instrument is the master)
    query <- paste0("
        SELECT
            stpr_table_id,
            p.param_name,
            p.param_unit,
            p.param_conv,
            p.param_unit_conv,
            CASE
                WHEN it.instr_type_id = 0 THEN 'Stazione'::text
                ELSE btrim((((c.constr_name || ' '::text) || b.brand_name) || ' '::text) || m.model_name)
            END AS instr_type_fullname
        FROM metadata.stations_parameters sp
        -- parameters
        LEFT JOIN metadata.parameters p USING (param_id)
        -- instruments
        LEFT JOIN metadata.stations_instruments si USING (stpr_group_id)
        LEFT JOIN equipments.instruments i USING (instr_id)
        -- instr metadata
        LEFT JOIN equipments.instruments_type it USING (instr_type_id)
        LEFT JOIN equipments.brands b USING (brand_id)
        LEFT JOIN equipments.models m USING (model_id)
        LEFT JOIN equipments.constructors c USING (constr_id)
        WHERE sp.station_id = ", stid_p, "
        AND param_id = ", param_id, "
        AND stin_master IS TRUE"
    )
    dbdata <- PG.ExecuteQuery(dbh, query)

    if (nrow(dbdata) != 0) {
        flog.info(paste("dati inquinante ", param_id, " (", param_name, ")"))
        stpr_table_id <- dbdata$stpr_table_id
        param_conv <- dbdata$param_conv

        # query dati
        data <- q_data(
            param_name,
            param_conv,
            start_d,
            end_d,
            p_station_fulltable,
            stpr_table_id
        )

        pollutants_data <- merge(pollutants_data, data)
    }
}

# merge wind and pollutants data
pollutants_data <- merge(pollutants_data, wind_data)

# check wind data presence
flog.info(paste("Controllo presenza dati direzione e velocita del vento"))
# pollutant data's total number
n_dati <- nrow(pollutants_data)
# MISSING wind speed data's total number
check_ws <- sum(is.na(pollutants_data$ws))
# MISSING wind speed data's total number
check_wd <- sum(is.na(pollutants_data$wd))
# sum of wind speed and wind direction's EXISTING data
check <- sum(!is.na(pollutants_data$ws) & !is.na(pollutants_data$wd))
flog.info(paste("dati totali = ", n_dati, " mancanti ws =", check_ws, " - wd = ", check_wd, " - check = ", check))

# data elaboration and plots
# check if total number of wind's (speed + direction) EXISTING data is higher then the 20% of the total data
if (check > n_dati * lim_dati) {
    # higher then the 20%: generate images
    flog.info(paste("> higher then the 20%: OK"))
    flog.info(paste("> call external_program (", external_program, ")"))
    source(external_program)

    #------------------------------------------------------------------------------

    # syncro data to server app
    flog.info("> Syncro files to app server")

    # today date
    tmp_path_date <- format(Sys.Date(), format = "%Y%m%d")

    flog.info(paste0("system(\"scp -r ", tmp_path_full, " ", tmp_path_date, "\")"))
    s <- system(paste0("scp -r ", tmp_path_full, " ", tmp_path_date))
    flog.info(s)

    #------------------------------------------------------------------------------

    # update jobs table
    flog.info("update jobs table")
    json <- paste0("{
        \"head\": \"Grafici terminati\",
        \"text\": \"Operazione eseguita con successo\",
        \"type\": \"succ\",
        \"dir\": \"",tmp_path,"\"
    }")
    query <- paste0("
        UPDATE clients.jobs_queue
        SET jq_result_obj = '", json, "', jq_end_ts = CURRENT_TIMESTAMP
        WHERE jq_id = ", jobid, ""
    )
    PG.ExecuteQuery(dbh, query)

} else {
    # less then the 20%: DO NOT generate images
    flog.info(paste("> less then the 20%: ERROR"))

    # update jobs table
    flog.info("update jobs table")
    json <- paste0("{
        \"head\": \"Grafici non creati, dati non trovati\",
        \"text\": \"Operazione non eseguita\",
        \"type\": \"warn\",
        \"dir\": \"",NA,"\"
    }")
    query <- paste0("
        UPDATE clients.jobs_queue
        SET jq_result_obj = '", json, "', jq_end_ts = CURRENT_TIMESTAMP
        WHERE jq_id = ", jobid, ""
    )
    PG.ExecuteQuery(dbh, query)
}


#------------------------------------------------------------------------------

# disconnect from database server
PG.Disconnect(dbh)

#------------------------------------------------------------------------------

# end
flog.debug(" ################### - END - ################### ")

#------------------------------------------------------------------------------

# quit script
quit(status = 0)
