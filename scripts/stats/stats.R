#!/usr/bin/env Rscript
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : stats.R
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#
#   STATISTICHE
#
#   ONLINE RESOURCE:
#       https://davidcarslaw.github.io/openair/
#
#   PACKAGES:
#       install.packages("RPostgreSQL")
#       install.packages("futile.logger")
#       install.packages("openair")
#       install.packages("roxygen2")
#
#   "OPENAIR" PACKAGE'S USED FUNCTIONS:
#       "selectByDate": select periods before sending to a function.
#       https://davidcarslaw.github.io/openair/reference/selectByDate.html
#       parameters:
#           - data dataframe;
#           - period start date;
#           - period end date.
#       "aqStats": calculate air pollution statistics.
#       https://davidcarslaw.github.io/openair/reference/aqStats.html
#       parameters:
#           - data dataframe;
#           - name of the pollutant (same name of the data column in the data dataframe);
#           - specifyies how the moving window should be aligned.
#             ("right" means that the previous hours, including the current, are averaged)
#       "rollingMean": calculate rolling mean values taking account of data capture thresholds.
#       https://davidcarslaw.github.io/openair/reference/rollingMean.html
#       parameters:
#           - data dataframe;
#           - name of the pollutant (same name of the data column in the data dataframe);
#           - the averaging period (rolling window width) to use;
#             ("8" will generate 8-hour rolling mean values when hourly data are analysed)
#           - minimum percentage of data;
#             (with "width = 8" and "data.thresh = 75": at least 6 hours are required to calculate the mean, else NA is returned)
#           - specifyies how the moving window should be aligned.
#             ("right" means that the previous hours, including the current, are averaged)
#
#   RUN EXAMPLE:
#       (jq_id)   $ Rscript stats.R 1
#
#             # server ecometer-mngt
#             /usr/bin/Rscript /data/bin/.../stats/stats.R 101
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
library(lattice)
library(openair)
library(lubridate)
library(dplyr)
library(plyr)
library(roxygen2)

#------------------------------------------------------------------------------
# set application working directory
setwd("/path/to/script/stats")

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
    stop("Argument missing. Sample: Rscript stats.R 101")
} else {
    jobid <- args[1]
}

#------------------------------------------------------------------------------
# custom functions

#' Function to remove spaces, using a regular expression
#'
#' @param x Value/string.
#'
#' @return Value/string without any space.
#'
#' @examples
#' trim(n)
#' trim(16)
trim <- function(x) {
    gsub("(^[[:space:]]+|[[:space:]]+$)", "", x)
}

#' Function to manage NULL/NA values
#'
#' @param n Value.
#'
#' @return Checked value.
#'
#' @examples
#' escape("")
#' escape("NA")
#' escape(mean_24h)
escape <- function(n) {
    n <- trim(n)
    if (is.na(n)) {
        return("NULL")
    } else if (n == "NA") {
        return("NULL")
    } else {
        return(n)
    }
}

#' Function to rounding up value
#'
#' @param x Value.
#' @param n Number of decimals.
#'
#' @return Rounded value.
#'
#' @examples
#' rounding(123,456, 1)
#' rounding(stats$max, 0)
rounding <- function(x, n) {
    z <- x * 10^n
    z <- z + 0.5
    z <- trunc(z)
    z <- z / 10^n
}

#' PostegreSQL query to retrive data (hourly)
#'
#' This function executes a SQL query to retrive the pollutant data of a
#' determinate time period.
#'
#' @param date_start Period start time.
#' @param date_end Period end time.
#' @param param_conv Pollutant's convertion factor.
#' @param pollutant_name Pollutant's name.
#' @param station_fulltable Station's data table fullname.
#' @param stpr_table_id Parameter's table ID.
#'
#' @return A dataframe of hourly data.
#'
#' @examples
#' data <- q_data_select_hh(
#'     date_start,
#'     date_end,
#'     param_conv,
#'     "so2",
#'     station_fulltable,
#'     stpr_table_id
#' )
#' data <- q_data_select_hh(
#'     "2022-01-01 00:00:00",
#'     "2022-12-31 23:00:00",
#'     2.6609,
#'     "so2",
#'     "client_xxxx.prov_nome_staz",
#'     1
#' )
q_data_select_hh <- function(date_start,
                          date_end,
                          param_conv,
                          pollutant_name,
                          station_fulltable,
                          stpr_table_id) {
    flog.info("data query...")
    query <- paste0("
        WITH t AS (
            SELECT fulldate_series AS measure_date_time
            FROM generate_series
            ( '", date_start, "'::timestamp
            , '", date_end, "'::timestamp
            , '1 hour'::interval) s(fulldate_series)
        )
        SELECT
            t.measure_date_time AS \"date\",
            d.measure_value * ", param_conv, " AS ", pollutant_name, "
        FROM
            t
            LEFT JOIN ", station_fulltable, " d ON (
                t.measure_date_time = d.measure_date_time
                AND d.measure_id = ", stpr_table_id, "
                AND d.post_validity_code >= 0
                AND d.final_validity_code > 0
            )
        ORDER BY 1;"
    )

    return(PG.ExecuteQuery(dbh, query))
}

#' PostegreSQL query to retrive data (daily)
#'
#' This function executes a SQL query to retrive the pollutant data of a
#' determinate time period.
#'
#' @param date_start Period start time.
#' @param date_end Period end time.
#' @param param_conv Pollutant's convertion factor.
#' @param pollutant_name Pollutant's name.
#' @param station_fulltable Station's data table fullname.
#' @param stpr_table_id Parameter's table ID.
#'
#' @return A dataframe of hourly data.
#'
#' @examples
#' data <- q_data_select_dd(
#'     date_start,
#'     date_end,
#'     param_conv,
#'     "so2",
#'     station_fulltable,
#'     stpr_table_id
#' )
#' data <- q_data_select_dd(
#'     "2021-04-02 00:00:00",
#'     "2022-04-01 23:00:00",
#'     2.6609,
#'     "so2",
#'     "client_xxxx.prov_nome_staz",
#'     1
#' )
q_data_select_dd <- function(date_start,
                          date_end,
                          param_conv,
                          pollutant_name,
                          station_fulltable,
                          stpr_table_id) {
    flog.info("data query...")
    query <- paste0("
        WITH t AS (
            SELECT fulldate_series AS measure_date_time
            FROM generate_series
            ( '", date_start, "'::timestamp
            , '", date_end, "'::timestamp
            , '1 hour'::interval) s(fulldate_series)
        ),
        f AS (
            SELECT
                t.measure_date_time,
                d.measure_value * ", param_conv, " AS measure_value,
                ROUND((SUM(d.extract_code) OVER (PARTITION BY t.measure_date_time::date)::numeric / 24 ), 2) * 100 AS perc_per_day
            FROM
                t
                LEFT JOIN ", station_fulltable, " d ON (
                    t.measure_date_time = d.measure_date_time
                    AND d.measure_id = ", stpr_table_id, "
                    AND d.post_validity_code >= 0
                    AND d.final_validity_code > 0
                )
            ORDER BY 1
        )
        SELECT
            f.measure_date_time AS \"date\",
            CASE
                WHEN perc_per_day >= 75 THEN measure_value
                ELSE NULL::numeric
            END AS ", pollutant_name, "
        FROM f
        ORDER BY 1;")

    return(PG.ExecuteQuery(dbh, query))
}

#' PostegreSQL query to insert the statistics's data
#'
#' This function executes a SQL query to insert the statistics pollutant's data
#' of a determinate time period.
#'
#' @param res_date Statistic's date.
#' @param stpr_id Parameter's table ID.
#' @param limit_id Limit's ID.
#' @param res_value Statistic's value.
#' @param res_exceed_value Boolean value for exceeding the statistic's limit.
#' @param res_num_sup Statistic's number of exceedances.
#' @param res_exceed_num_sup Boolean value for exceeding the statistic's limit
#'                           number of exceedances.
#' @param res_perc_valid Percentage of valid data.
#' @param res_aggrules BOOLEAN
#'
#' @examples
#' q_data_insert(
#'     as.Date(date_end),
#'     stpr_id,
#'     1,
#'     escape(max_h_mean),
#'     if (!is.na(max_h_mean) & max_h_mean >= so2_limits[so2_limits$limit_id == 1, "limit_value"]) TRUE else FALSE,
#'     escape(exc_max_h_mean),
#'     if (exc_max_h_mean >= so2_limits[so2_limits$limit_id == 1, "limit_sup"]) TRUE else FALSE,
#'     75,
#'     TRUE,
#' )
#' q_data_insert(
#'     as.Date("2022-04-01 23:00:00"),
#'     8701,
#'     1,
#'     escape(60),
#'     if (!is.na(60) & 60 >= so2_limits[so2_limits$limit_id == 1, "limit_value"]) TRUE else FALSE,
#'     escape(0),
#'     if (0 >= so2_limits[so2_limits$limit_id == 1, "limit_sup"]) TRUE else FALSE,
#'     75,
#'     TRUE,
#' )
q_data_insert <- function(res_date,
                          stpr_id,
                          limit_id,
                          res_value,
                          res_exceed_value,
                          res_num_sup,
                          res_exceed_num_sup,
                          res_perc_valid,
                          res_aggrules) {
    query <- paste0("
        INSERT INTO clients_stats.results
            (
                res_date,
                stpr_id,
                limit_id,
                res_value,
                res_exceed_value,
                res_num_sup,
                res_exceed_num_sup,
                res_perc_valid,
                res_aggrules
            )
        VALUES
            (
                '", res_date, "'::timestamp,
                ", stpr_id, ",
                ", limit_id, ",
                ", res_value, ",
                ", res_exceed_value, ",
                ", res_num_sup, ",
                ", res_exceed_num_sup, ",
                ", res_perc_valid, ",
                ", res_aggrules, "
            );")
    # execute the query
    flog.info("data insert query...")
    PG.ExecuteQuery(dbh, query)
}

#------------------------------------------------------------------------------
# init logging - TRACE, DEBUG, INFO, WARN, ERROR, FATAL
# function(LOG.path, LOG.name)
# NOTSET FINEST FINER FINE DEBUG INFO WARNING
#      0      1     4    7    10   20      30
log_path <- file.path(getwd(), "log")

LOG.Init(10, log_path, "stats")

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# start up
flog.debug(" ################### - START UP - ################### ")

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
    SELECT *
    FROM jsonb_to_record(
        ( SELECT jq_args_obj FROM clients.jobs_queue WHERE jq_id = ", jobid, ")::jsonb
    ) AS x(
        dt text,
        prov text
    )"
)
job <- PG.ExecuteQuery(dbh, query)
# get data
date_ref <- job$dt
province <- job$prov
flog.info(paste0("job date_ref: ", date_ref, ", province: ", province))

#------------------------------------------------------------------------------
# days settings
days <- 365
n_data <- 365 * 24 # data total number (hourly)

# add hour to "date_end"
date_end <- paste0(date_ref, " 23:59:59")

# date start
date_start <- paste0(
    as.Date(
        date_end,
        format = "%Y-%m-%d"
    ) - days + 1,
    " 00:00:00"
) # (data extraction start date = data_end - 366 days)

year_day1 <- paste0(
    floor_date(
        as.Date(date_end),
        unit = "years"
    ),
    " 00:00:00"
) # (first day of current year)

#------------------------------------------------------------------------------
# checking for existing statistics in the provided date/province and delete them
flog.info("deletion...")
query <- paste0("
    DELETE FROM clients_stats.results
    WHERE res_date = '", as.Date(date_end, format = "%Y-%m-%d"), "'
    AND stpr_id IN (
        SELECT stpr_id
        FROM clients_stats.results r
        LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
        LEFT JOIN metadata.stations_municipality sm USING (station_id)
        LEFT JOIN main.province_municipalities pm USING (mu_id)
        LEFT JOIN main.provinces p USING (province_id)
        WHERE p.province_id = ", province, "
        ORDER BY station_id, limit_id
    )"
)
PG.ExecuteQuery(dbh, query)

# limits
flog.info("limits...")
query <- paste0("
    SELECT
        limit_id,
        pollutant_id,
        limit_value,
        limit_sup,
        limit_note
    FROM clients_stats.limits
    ORDER BY 1 ASC;"
)
limits <- PG.ExecuteQuery(dbh, query)

# set pollutant's limits
so2_limits  <- limits[limits$limit_id %in% c(1, 2), ]
no2_limits  <- limits[limits$limit_id %in% c(6, 8, 9, 10), ]
co_limits   <- limits[limits$limit_id == 15, ]
o3_limits   <- limits[limits$limit_id %in% c(27, 28, 30, 31), ]
c6h6_limits <- limits[limits$limit_id %in% c(12, 13, 14), ]
pm25_limits <- limits[limits$limit_id %in% c(19, 20), ]
pm10_limits <- limits[limits$limit_id %in% c(17, 18), ]

# stations
flog.info("stations...")
query <- paste0("
    SELECT station_id
    FROM metadata.stations s
    LEFT JOIN metadata.stations_municipality sm USING (station_id)
    LEFT JOIN metadata.stations_status ss USING (station_id)
    LEFT JOIN main.province_municipalities pm USING (mu_id)
    LEFT JOIN main.provinces p USING (province_id)
    WHERE s.station_active = TRUE
    AND ss.ss_suspended = FALSE
    -- AND station_id = 1030 -- (test)
    AND p.province_id = '", province, "'
    ORDER BY 1 ASC;"
)
stations <- PG.ExecuteQuery(dbh, query)

# loop each station...
for (station in stations[, 1]) {
    flog.info(station)
    flog.info("station fulltable...")
    query <- paste0("
        SELECT station_schema || '.' || station_table AS station_fulltable
        FROM metadata.stations
        WHERE station_id = ", station, ";"
    )
    station_fulltable <- PG.ExecuteQuery(dbh, query)

    flog.info("pollutant's stpr ids...")
    # date_end refer to date requested by web app, not now
    # AND tsrange(stin_startup_date, stin_dismiss_date, '[]') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome') NO
    query <- paste0("
        SELECT stpr_id, stpr_table_id, param_id, param_conv
        FROM metadata.stations_parameters sp
        LEFT JOIN metadata.parameters p USING (param_id)
        LEFT JOIN metadata.stations_instruments si USING (stpr_group_id)
        WHERE sp.station_id = ", station, "
        AND param_id IN (
            29, -- SO2
            32, -- NO2
            33, -- CO
            34, -- O3
            38, -- C6H6
            48, -- PM2.5
            50  -- PM10
        )
        AND tsrange(stin_startup_date, stin_dismiss_date, '[]') @> ('", date_end, "'::timestamp)
        AND stin_master IS TRUE
        ORDER BY param_id, stpr_table_id ASC;"
    )
    poll_ids <- PG.ExecuteQuery(dbh, query)

    # skip station if "poll_ids" is empty (no pollutants)
    if (nrow(poll_ids) == 0) {
        flog.info("no pollutant in this station. Skip to next... ")
        next
    }

    # loop each station parameter...
    for (row in 1:nrow(poll_ids)) {
        stpr_id       <- poll_ids[row, "stpr_id"]
        stpr_table_id <- poll_ids[row, "stpr_table_id"]
        param_id      <- as.character(poll_ids[row, "param_id"])
        param_conv    <- poll_ids[row, "param_conv"]

        # switch case for pollutant...
        x <- switch(param_id,
            "29" = { # SO2
                flog.info("SO2")

                # DD data query
                data_dd <- q_data_select_dd(
                    date_start,
                    date_end,
                    param_conv,
                    "so2",
                    station_fulltable,
                    stpr_table_id
                )

                # HH data query
                data_hh <- q_data_select_hh(
                    date_start,
                    date_end,
                    param_conv,
                    "so2",
                    station_fulltable,
                    stpr_table_id
                )

                # check if "data" array is empty
                if (nrow(data_dd) != 0 && nrow(data_hh) != 0) {
                    # "openair" statistics for "SO2"
                    stats_dd <- as.data.frame(
                        aqStats(
                            selectByDate(
                                data_dd,
                                start = as.Date(date_end),
                                end = as.Date(date_end)
                            ),
                            pollutant = "so2",
                            align = "right"
                        )
                    )
                    stats_hh <- as.data.frame(
                        aqStats(
                            selectByDate(
                                data_hh,
                                start = as.Date(date_end),
                                end = as.Date(date_end)
                            ),
                            pollutant = "so2",
                            align = "right"
                        )
                    )

                    # check limits (so2_limits)
                    # max_h_mean  -> 1
                    # mean_24h    -> 2
                    so2_limit_1_val <- so2_limits[so2_limits$limit_id == 1, "limit_value"]
                    so2_limit_1_sup <- so2_limits[so2_limits$limit_id == 1, "limit_sup"]
                    so2_limit_2_val <- so2_limits[so2_limits$limit_id == 2, "limit_value"]
                    so2_limit_2_sup <- so2_limits[so2_limits$limit_id == 2, "limit_sup"]

                    # hourly mean
                    max_h_mean <- rounding(stats_dd$max, 0)

                    # 24h mean
                    mean_24h <- rounding(stats_dd$max_daily, 0)

                    # number of exceedances
                    exc_max_h_mean <- 0
                    exc_mean_24h <- 0

                    # get exceeded values from first day of the year (exc_max_h_mean)
                    exc_val <- data_dd[!is.na(data_dd$so2) & data_dd$date >= year_day1 & data_dd$so2 > so2_limit_1_val, ]
                    # count rows
                    exc_max_h_mean <- nrow(exc_val)

                    # get exceeded values from first day of the year (exc_mean_24h)
                    exc_val <- data_dd[!is.na(data_dd$so2) & data_dd$date >= year_day1 & data_dd$so2 > so2_limit_2_val, ]
                    # count rows
                    exc_mean_24h <- nrow(exc_val)

                    # insert data: 24h mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        2,
                        escape(mean_24h),
                        if (!is.na(mean_24h) & mean_24h > so2_limit_2_val) TRUE else FALSE,
                        escape(exc_mean_24h),
                        if (exc_mean_24h > so2_limit_2_sup) TRUE else FALSE,
                        75,
                        TRUE
                    )

                    # insert data: hourly mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        1,
                        escape(max_h_mean),
                        if (!is.na(max_h_mean) & max_h_mean > so2_limit_1_val) TRUE else FALSE,
                        escape(exc_max_h_mean),
                        if (exc_max_h_mean > so2_limit_1_sup) TRUE else FALSE,
                        75,
                        TRUE
                    )
                } else {
                    flog.debug("NO DATA")
                }
            },
            "32" = { # NO2
                flog.info("NO2")

                # DD data query
                data_dd <- q_data_select_dd(
                    date_start,
                    date_end,
                    param_conv,
                    "no2",
                    station_fulltable,
                    stpr_table_id
                )

                # HH data query
                data_hh <- q_data_select_hh(
                    date_start,
                    date_end,
                    param_conv,
                    "no2",
                    station_fulltable,
                    stpr_table_id
                )

                # check if "data" array is empty
                if (nrow(data_dd) != 0 && nrow(data_hh) != 0) {
                    # "openair" statistics for "NO2"
                    stats_dd <- as.data.frame(
                        aqStats(
                            selectByDate(
                                data_dd,
                                start = as.Date(date_end),
                                end = as.Date(date_end)
                            ),
                            pollutant = "no2",
                            align = "right"
                        )
                    )
                    stats_hh <- as.data.frame(
                        aqStats(
                            selectByDate(
                                data_hh,
                                start = as.Date(date_end),
                                end = as.Date(date_end)
                            ),
                            pollutant = "no2",
                            align = "right"
                        )
                    )

                    # check limits (no2_limits)
                    # max_h_mean  -> 6
                    # roll_y_mean -> 10
                    # mean_24h    -> 9
                    no2_limit_6_val <- no2_limits[no2_limits$limit_id == 6, "limit_value"]
                    no2_limit_6_sup <- no2_limits[no2_limits$limit_id == 6, "limit_sup"]
                    no2_limit_8_val <- no2_limits[no2_limits$limit_id == 10, "limit_value"]

                    # remove NA values
                    cleared_data_hh <- data_hh[rowSums(is.na(data_hh)) == 0, ]

                    # counting rows of cleared data
                    count_rows <- nrow(cleared_data_hh)

                    # data percentage out of 365 days
                    perc_roll_y_mean <- (count_rows / n_data) * 100

                    # (hack)
                    # if 75% calculate stats, else NA
                    # if (perc_roll_y_mean >= 75) {
                        roll_y_mean <- rounding(mean(data_hh$no2, na.rm = TRUE), 0)
                    # } else {
                        # roll_y_mean <- NA
                    # }

                    # max hourly mean
                    max_h_mean <- rounding(stats_dd$max, 0)

                    # 24h mean
                    mean_24h <- rounding(stats_dd$max_daily, 0)

                    # take exceeds
                    # get exceeded values from first day of the year (exc_mean_24h)
                    exc_val <- data_dd[!is.na(data_dd$no2) & data_dd$date >= year_day1 & data_dd$no2 > no2_limit_6_val, ]
                    # count rows
                    exc_mean_24h <- nrow(exc_val)

                    # (hack)
                    if (is.na(mean_24h)) {
                        roll_y_mean <- NA
                    }

                    # insert data: hourly mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        6,
                        escape(max_h_mean),
                        if (!is.na(max_h_mean) & max_h_mean > no2_limit_6_val) TRUE else FALSE,
                        escape(exc_mean_24h),
                        if (exc_mean_24h > no2_limit_6_sup) TRUE else FALSE,
                        75,
                        TRUE
                    )

                    # insert data: 24h mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        9,
                        escape(mean_24h),
                        "NULL",
                        "NULL",
                        "NULL",
                        75,
                        TRUE
                    )

                    # insert data: yearly rolling mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        10,
                        escape(roll_y_mean),
                        if (!is.na(roll_y_mean) & roll_y_mean > no2_limit_8_val) TRUE else FALSE,
                        "NULL",
                        "NULL",
                        75,
                        TRUE
                    )
                } else {
                    flog.debug("NO DATA")
                }
            },
            "33" = { # CO
                flog.info("CO")

                # HH data query
                data_hh <- q_data_select_hh(
                    date_start,
                    date_end,
                    param_conv,
                    "co",
                    station_fulltable,
                    stpr_table_id
                )

                # check if "data" array is empty
                if (nrow(data_hh) != 0) {
                    # "openair" statistics for "CO"
                    stats_hh <- as.data.frame(
                        aqStats(
                            selectByDate(
                                data_hh,
                                start = as.Date(date_end),
                                end = as.Date(date_end)
                            ),
                            pollutant = "co",
                            align = "right"
                        )
                    )

                    # check limits (co_limits)
                    # max_8h_mean -> 15
                    co_limit_15_val <- co_limits[co_limits$limit_id == 15, "limit_value"]

                    # calculate the max mean 8h
                    # "openair" rolling mean
                    exc_max_8h_mean <- as.data.frame(
                        rollingMean(
                            data_hh,
                            pollutant = "co",
                            width = 8,
                            data.thresh = 75, # 6h on 8
                            align = "right",
                        )
                    )

                    # remove NA rows
                    cleared_max_8h_mean <- exc_max_8h_mean[rowSums(is.na(exc_max_8h_mean)) == 0, ]

                    # get the max conc per day
                    max_conc_per_day <- as.data.frame(
                        cleared_max_8h_mean %>%
                            group_by(as.Date(cleared_max_8h_mean$date)) %>%
                            dplyr::filter(rolling8co == max(rolling8co)) %>%
                            distinct(rolling8co, .keep_all = T) %>%
                            ungroup()
                    )

                    # get dates
                    dates_max_8h_mean <- as.data.frame(as.Date(cleared_max_8h_mean$date))

                    # counting number of values per date
                    freq_max_8h_mean <- count(dates_max_8h_mean[, 1])

                    # add column to the new data frame
                    df <- cbind(freq_max_8h_mean, rounding(max_conc_per_day$rolling8co, 1))

                    # change column names
                    colnames(df) <- c("date", "freq", "meanco")

                    # get rows with the same date as the provided date
                    max_8h_mean_row <- as.data.frame(df %>% filter(date == as.Date(date_end)))

                    # set default value as NA
                    max_8h_mean <- NA

                    # check number of rows
                    if (nrow(max_8h_mean_row) != 0) {
                        # check if present at least 18 values
                        if (max_8h_mean_row$freq >= 18) {
                            # save the value
                            max_8h_mean <- max_8h_mean_row$meanco
                        }
                    }

                    # get number of exceedences
                    rows_sup <- df %>% filter(date >= as.Date(year_day1), freq >= 18, meanco > co_limit_15_val)

                    # count exceedences
                    count_sup <- nrow(rows_sup)

                    # insert data: max 8h mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        15,
                        escape(max_8h_mean),
                        if (!is.na(max_8h_mean) & max_8h_mean > co_limit_15_val) TRUE else FALSE,
                        escape(count_sup),
                        "NULL",
                        75,
                        TRUE
                    )
                } else {
                    flog.debug("NO DATA")
                }
            },
            "34" = { # O3
                flog.info("O3")

                # DD data query
                data_dd <- q_data_select_dd(
                    date_start,
                    date_end,
                    param_conv,
                    "o3",
                    station_fulltable,
                    stpr_table_id
                )

                # HH data query
                data_hh <- q_data_select_hh(
                    date_start,
                    date_end,
                    param_conv,
                    "o3",
                    station_fulltable,
                    stpr_table_id
                )

                # check if "data" array is empty
                if (nrow(data_dd) != 0 && nrow(data_hh) != 0) {
                    # "openair" statistics for "O3"
                    stats_hh <- as.data.frame(
                        aqStats(
                            selectByDate(
                                data_hh,
                                start = as.Date(date_end),
                                end = as.Date(date_end)
                            ),
                            pollutant = "o3",
                            align = "right"
                        )
                    )
                    stats_dd <- as.data.frame(
                        aqStats(
                            selectByDate(
                                data_dd,
                                start = as.Date(date_end),
                                end = as.Date(date_end)
                            ),
                            pollutant = "o3",
                            align = "right"
                        )
                    )

                    # check limits (o3_limits)
                    # max_h_mean   -> 27
                    # max_8h_mean  -> 31
                    # alert_h_mean -> 28
                    o3_limit_27_val <- o3_limits[o3_limits$limit_id == 27, "limit_value"]
                    o3_limit_28_val <- o3_limits[o3_limits$limit_id == 28, "limit_value"]
                    o3_limit_30_sup <- o3_limits[o3_limits$limit_id == 30, "limit_sup"]
                    o3_limit_31_val <- o3_limits[o3_limits$limit_id == 31, "limit_value"]

                    # calculate the max mean 8h
                    # "openair" rolling mean
                    exc_max_8h_mean <- as.data.frame(
                        rollingMean(
                            data_hh,
                            pollutant = "o3",
                            width = 8,
                            data.thresh = 75, # 6 ore su 8
                            align = "right",
                        )
                    )

                    # remove NA rows
                    cleared_max_8h_mean <- exc_max_8h_mean[rowSums(is.na(exc_max_8h_mean)) == 0, ]

                    # get the max conc per day
                    max_conc_per_day <- as.data.frame(
                        cleared_max_8h_mean %>%
                            group_by(as.Date(cleared_max_8h_mean$date)) %>%
                            dplyr::filter(rolling8o3 == max(rolling8o3)) %>%
                            distinct(rolling8o3, .keep_all = T) %>%
                            ungroup()
                    )

                    # get dates
                    dates_max_8h_mean <- as.data.frame(as.Date(cleared_max_8h_mean$date))

                    # counting number of values per date
                    freq_max_8h_mean <- count(dates_max_8h_mean[, 1])

                    # add column to the new data frame
                    df <- cbind(freq_max_8h_mean, rounding(max_conc_per_day$rolling8o3, 0))

                    # change column names
                    colnames(df) <- c('date', 'freq', 'meano3')

                    # get rows with the same date as the provided date
                    max_8h_mean_row <- as.data.frame(df %>% filter(date == as.Date(date_end)))

                    # set default value as NA
                    max_8h_mean <- NA

                    # check number of rows
                    if (nrow(max_8h_mean_row) != 0) {
                        # check if present at least 18 values
                        if (max_8h_mean_row$freq >= 18) {
                            # save the value
                            max_8h_mean <- max_8h_mean_row$meano3
                        }
                    }

                    # get number of exceedences
                    rows_sup <- df %>% filter(date >= as.Date(year_day1), freq >= 18, meano3 > o3_limit_31_val)

                    # count exceedences
                    count_sup <- nrow(rows_sup)

                    # max hourly mean
                    max_h_mean <- rounding(stats_dd$max, 0)

                    # number of exceedances (max_h_mean + alarm)
                    exc_max_h_mean <- 0
                    exc_alert_h_mean <- 0

                    # get exceeded values from first day of the year (exc_max_h_mean)
                    exc_val <- data_dd[!is.na(data_dd$o3) & data_dd$date >= year_day1 & data_dd$o3 > o3_limit_27_val, ]
                    # remove NA values and count rows
                    exc_max_h_mean <- nrow(exc_val)
                    # get exceeded values from first day of the year (exc_alert_h_mean)
                    exc_val <- data_dd[!is.na(data_dd$o3) & data_dd$date >= year_day1 & data_dd$o3 > o3_limit_28_val, ]
                    # remove NA values and count rows
                    exc_alert_h_mean <- nrow(exc_val)

                    # insert data: hourly mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        27,
                        escape(max_h_mean),
                        if (!is.na(max_h_mean) & max_h_mean > o3_limit_27_val) TRUE else FALSE,
                        escape(exc_max_h_mean),
                        if (exc_max_h_mean > o3_limit_27_val) TRUE else FALSE,
                        75,
                        TRUE
                    )

                    # insert data: max 8h mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        31,
                        escape(max_8h_mean),
                        if (!is.na(max_8h_mean) & max_8h_mean > o3_limit_31_val) TRUE else FALSE,
                        escape(count_sup),
                        if (!is.na(count_sup) & count_sup > o3_limit_30_sup) TRUE else FALSE,
                        # "NULL",
                        75,
                        TRUE
                    )

                    # insert data: alert h mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        28,
                        escape(max_h_mean),
                        if (!is.na(max_h_mean) & max_h_mean > o3_limit_27_val) TRUE else FALSE,
                        escape(exc_alert_h_mean),
                        if (exc_alert_h_mean > o3_limit_28_val) TRUE else FALSE,
                        75,
                        TRUE
                    )
                } else {
                    flog.debug("NO DATA")
                }
            },
            "38" = { # C6H6
                flog.info("C6H6")

                # DD data query
                data_dd <- q_data_select_dd(
                    date_start,
                    date_end,
                    param_conv,
                    "c6h6",
                    station_fulltable,
                    stpr_table_id
                )

                # HH data query
                data_hh <- q_data_select_hh(
                    date_start,
                    date_end,
                    param_conv,
                    "c6h6",
                    station_fulltable,
                    stpr_table_id
                )

                # check if "data" array is empty
                if (nrow(data_dd) != 0 && nrow(data_hh) != 0) {
                    # "openair" statistics for "C6H6"
                    stats_dd <- as.data.frame(
                        aqStats(
                            selectByDate(
                                data_dd,
                                start = as.Date(date_end),
                                end = as.Date(date_end)
                            ),
                            pollutant = "c6h6",
                            align = "right"
                        )
                    )

                    # check limits (c6h6_limits)
                    # mean_24h    -> 13
                    # roll_y_mean -> 14
                    c6h6_limit_12_val <- c6h6_limits[c6h6_limits$limit_id == 14, "limit_value"]

                    # remove NA values
                    cleared_data_hh <- data_hh[rowSums(is.na(data_hh)) == 0, ]

                    # counting rows of cleared data
                    count_rows <- nrow(cleared_data_hh)

                    # data percentage out of 365 days
                    perc_roll_y_mean <- (count_rows / n_data) * 100

                    # (hack)
                    # if 75% calculate stats, else NA
                    # if (perc_roll_y_mean >= 75) {
                        roll_y_mean <- rounding(mean(data_hh$c6h6, na.rm = TRUE), 1)
                    # } else {
                        # roll_y_mean <- NA
                    # }

                    # 24h mean
                    mean_24h <- rounding(stats_dd$max_daily, 1)

                    # (HACK)
                    if (is.na(mean_24h)) {
                        roll_y_mean <- NA
                    }

                    # insert data: 24h mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        13,
                        escape(mean_24h),
                        "NULL",
                        "NULL",
                        "NULL",
                        75,
                        TRUE
                    )

                    # insert data: yearly rolling mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        14,
                        escape(roll_y_mean),
                        if (!is.na(roll_y_mean) & roll_y_mean > c6h6_limit_12_val) TRUE else FALSE,
                        "NULL",
                        "NULL",
                        75,
                        TRUE
                    )
                } else {
                    flog.debug("NO DATA")
                }
            },
            "48" = { # PM2.5
                flog.info("PM2.5")

                # DD data query
                data_dd <- q_data_select_dd(
                    date_start,
                    date_end,
                    param_conv,
                    "pm25",
                    station_fulltable,
                    stpr_table_id
                )

                # check if "data" array is empty
                if (nrow(data_dd) != 0) {
                    # "openair" statistics for "PM2.5"
                    stats_dd <- as.data.frame(
                        aqStats(
                            selectByDate(
                                data_dd,
                                start = as.Date(date_end),
                                end = as.Date(date_end)
                            ),
                            pollutant = "pm25",
                            align = "right"
                        )
                    )

                    # check limits (pm25_limits)
                    # y_mean -> 19
                    # mean_24h -> 20
                    pm25_limit_20_val <- pm25_limits[pm25_limits$limit_id == 20, "limit_value"]

                    # 24h mean
                    mean_24h <- rounding(stats_dd$max_daily, 0)

                    # insert data: 24h mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        20,
                        escape(mean_24h),
                        if (!is.na(mean_24h) & mean_24h > pm25_limit_20_val) TRUE else FALSE,
                        "NULL",
                        "NULL",
                        75,
                        TRUE
                    )
                } else {
                    flog.debug("NO DATA")
                }
            },
            "50" = { # PM10
                flog.info("PM10")

                # data query
                data_dd <- q_data_select_dd(
                    date_start,
                    date_end,
                    param_conv,
                    "pm10",
                    station_fulltable,
                    stpr_table_id
                )

                # check if "data" array is empty
                if (nrow(data_dd) != 0) {
                    # "openair" statistics for "PM10"
                    stats_dd <- as.data.frame(
                        aqStats(
                            selectByDate(
                                data_dd,
                                start = as.Date(date_end),
                                end = as.Date(date_end)
                            ),
                            pollutant = "pm10",
                            align = "right"
                        )
                    )

                    # check limits (pm10_limits)
                    # mean_24h -> 17
                    # y_mean   -> 18
                    pm10_limit_17_val <- pm10_limits[pm10_limits$limit_id == 17, "limit_value"]
                    pm10_limit_17_sup <- pm10_limits[pm10_limits$limit_id == 17, "limit_sup"]

                    # exceeds since year day 1
                    # get the daily means
                    media_gg <- aggregate(data_dd$pm10, by = list(d = as.POSIXct(trunc(data_dd$date, "day"))), mean, na.rm = TRUE)
                    media_gg$x <- rounding(media_gg$x, 0)

                    # january 1st index
                    jan1 <- min(which(format(media_gg$d, "%m") == "01" & format(media_gg$d, "%d") == "01"))
                    exc_mean_24h <- length(which(media_gg[jan1:n_data, 2] > pm10_limit_17_val))

                    # 24h mean
                    mean_24h <- rounding(stats_dd$max_daily, 0)

                    # insert data: 24h mean
                    q_data_insert(
                        as.Date(date_end),
                        stpr_id,
                        17,
                        escape(mean_24h),
                        if (!is.na(mean_24h) & mean_24h > pm10_limit_17_val) TRUE else FALSE,
                        escape(exc_mean_24h),
                        if (exc_mean_24h > pm10_limit_17_sup) TRUE else FALSE,
                        75,
                        TRUE
                    )
                } else {
                    flog.debug("NO DATA")
                }
            }
        )
    }
}

#------------------------------------------------------------------------------
# update jobs table
flog.info("update jobs table")
json <- paste0("{
    \"head\": \"Calcolo terminato\",
    \"text\": \"Operazione eseguita con successo\",
    \"type\": \"succ\"
}")
query <- paste0("
    UPDATE clients.jobs_queue
    SET jq_result_obj = '", json, "', jq_end_ts = CURRENT_TIMESTAMP
    WHERE jq_id = ", jobid, ""
)
PG.ExecuteQuery(dbh, query)

#------------------------------------------------------------------------------
# disconnect from database server
PG.Disconnect(dbh)

#------------------------------------------------------------------------------
# end
flog.debug(" ################### - END - ################### ")

#------------------------------------------------------------------------------
# quit script
quit(status = 0)
