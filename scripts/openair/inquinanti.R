#!/usr/bin/env Rscript
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : inquinanti.R
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#
#   GRAFICI INQUINANTI OPENAIR
#
#   Grafici del vento (annuale stagionale) + pollution-rose e polar-plot degli
#   inquinanti tramite pacchetto "openair".
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# custom functions

#' Get graph's metadata
#'
#' @param param Parameter (wind/pollutant) name.
#'
#' @examples
#' g_metadata(inquinante)
#' g_metadata("so2")
g_metadata <- function(param) {
    # debug:
    flog.info(paste(" > creazione grafici stazione:", p_station_name, " - parametro: ", param))

    # check if "co" OR "nox" (different measure unit)
    switch(param,
        "co" = {
            misura <<- stri_enc_toutf8("mg/m³")
        },
        "nox" = {
            misura <<- "ppb"
        },
        {
            # (hack) encoding problems...
            misura <<- "µg/m³"
            Encoding(misura) <- "UTF-8"
        }
    )

    legenda <<- list(
        header = param,
        footer = misura,
        plot.style = c("paddle"),
        fit = "all",
        height = 1,
        space = "right"
    )
    column <<- as.name(paste0("y$", param))
    perc <<- 100 * sum(!is.na(eval(parse(text = column))) & !is.na(y$ws) & !is.na(y$wd)) / n_dati # percentuale dati validi

    # check if there are graphs limits setted by user
    if (l_lim == "" && u_lim == "") { # no lower + no upper
        graph_limits <<- NA
    } else if (l_lim != "" && u_lim == "") { # only upper
        graph_limits <<- c(as.numeric(l_lim), max(eval(parse(text = column)), na.rm = TRUE))
    } else if (l_lim == "" && u_lim != "") { # only lower
        graph_limits <<- c(0, as.numeric(u_lim))
    } else { # lower + upper
        graph_limits <<- c(as.numeric(l_lim), as.numeric(u_lim))
    }
}

#' Function that generates ALL graphs (every pollutant)
#'
#' @param inquinante Pollutant name (string).
#' @param limiti Limits array.
#'
#' @examples
#' all_graphs(
#'     inquinante,
#'     eval(parse(text = (paste0("limiti$", inquinante))))
#' )
all_graphs <- function(inquinante, limiti) {
    # graph metadata
    g_metadata(inquinante)

    # pollutionrose graph
    flog.info(" > pollutionrose")
    tryCatch({
        # nomefile = file.path(percorso_output, paste0(stazione, "_pollutionrose_", inquinante, ".png"))
        nomefile <- file.path(tmp_path_full, paste0("pollutionrose_", inquinante, ".png"))
        png(
            nomefile,
            width = larghezza,
            height = altezza,
            res = 150
        )
        titolo <- paste(p_station_name, "\npollutionRose", inquinante, "\nda ", start_d, " a ", end_d)
        subtitolo <- paste("Frequenza di osservazioni rispetto alla direzione del vento (dati ", round(perc), "%)\nStazione meteo: ", w_station_name)
        my.statistic <- list(
            "fun" = length,
            "unit" = "%",
            "scale" = "all",
            "lab" = list(
                subtitolo,
                cex = 0.65
            ),
            "fun2" = function(x) signif(mean(x, na.rm = TRUE), 3),
            "lab2" = "mean",
            "labcalm" = function(x) round(x, 1)
        )
        tipo <- c("season")

        # set graph scale
        switch(scale_type,
            "0" = { # default
                flog.info("Default")

                y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = 9))
            },
            "1" = { # numero di fasce
                flog.info("Numero di fasce")

                y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = scale_opt))
            },
            "2" = { # scala da utente
                flog.info("Scala da utente")

                y_lim <- scale_opt
            }
        )

        # "openair" graph function
        pollutionRose(
            y,
            pollutant = inquinante,
            type = tipo,
            limits = graph_limits,
            breaks = y_lim,
            main = titolo,
            sub = subtitolo,
            statistic = my.statistic,
            key = legenda,
            annotate = TRUE,
            bias.corr = FALSE,
            auto.text = FALSE,
            paddle = F,
            angle = 45
        )

        dev.off()

        flog.info(" > grafico POLLUTIONROSE creato correttamente")
    },
    error = function(e) {
        flog.info(" > errore nella creazione del grafico")
    })

    # polarplot weekend graph
    flog.info(" > polarplot weekend")
    tryCatch({
        if(sum(!is.na(variabile)) > n_dati * 0.3) { # aggiunto controllo su percentuale dati mancanti per inizio anno
            # nomefile = file.path(percorso_output, paste0(stazione, "_polarplot_", inquinante, ".png"))
            nomefile <- file.path(tmp_path_full, paste0("polarplot_", inquinante, ".png"))
            png(
                nomefile,
                width = larghezza,
                height = altezza,
                res = 150
            )
            titolo <- paste(p_station_name, "\nbivariate polar plot of concentrations", inquinante, "\nda ", start_d, " a ", end_d)
            subtitolo <- paste("Date di riferimento: ", start_d, " a ", end_d, "\nStazione meteo di referimento: ", w_station_name, "\nConcentrazione rispetto alla direzione e velocità del vento (dati ", round(perc), "%)")

            # (hack) encoding problems...
            Encoding(subtitolo) <- "UTF-8"

            tipo <- "weekend"

            # set graph scale
            switch(scale_type,
                "0" = { # default
                    flog.info("Default")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = 9))
                },
                "1" = { # numero di fasce
                    flog.info("Numero di fasce")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = scale_opt))
                },
                "2" = { # scala da utente
                    flog.info("Scala da utente")

                    y_lim <- scale_opt
                }
            )

            # "openair" graph function
            polarPlot(
                y,
                pollutant = inquinante,
                type = tipo,
                limits = graph_limits,
                breaks = y_lim,
                key = legenda,
                main = titolo,
                sub = subtitolo,
                auto.text = FALSE,
                paddle = F,
                angle = 45
            )

            dev.off()

            flog.info(" > grafico POLARPLOT WEEKEND creato correttamente")
        } else {
            flog.info(" > !! dati inquinante mancanti SUPERIORI al 30% del totale")
        }
    },
    error = function(e) {
        flog.info(" > errore nella creazione del grafico")
    })

    # polarplot season graph
    flog.info(" > polarplot season")
    tryCatch({
        if(sum(!is.na(variabile)) > n_dati * 0.3) { # aggiunto controllo su percentuale dati mancanti per inizio anno
            # nomefile = file.path(percorso_output, paste0(stazione, "_polarplot_season_", inquinante, ".png"))
            nomefile <- file.path(tmp_path_full, paste0("polarplot_season_", inquinante, ".png"))
            png(
                nomefile,
                width = larghezza,
                height = altezza,
                res = 150
            )
            # titolo = paste(stazione, "bivariate polar plot of concentrations ", inquinante, " - da ", data_start, " a ", data_end)
            # subtitolo = paste("Concentrazione rispetto alla direzione e velocità del vento (dati ", round(perc), "%) - Stazione meteo: ", stazione_vento)
            titolo <- paste(p_station_name, "\nbivariate polar plot of concentrations " , inquinante, "\nda ", start_d, " a ", end_d)
            subtitolo <- paste("Date di riferimento: ", start_d, " a ", end_d, "\nStazione meteo di referimento: ", w_station_name, "\nConcentrazione rispetto alla direzione e velocità del vento (dati ", round(perc), "%)")

            # (hack) encoding problems...
            Encoding(subtitolo) <- "UTF-8"

            tipo <- "season"

            # set graph scale
            switch(scale_type,
                "0" = { # default
                    flog.info("Default")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = 9))
                },
                "1" = { # numero di fasce
                    flog.info("Numero di fasce")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = scale_opt))
                },
                "2" = { # scala da utente
                    flog.info("Scala da utente")

                    y_lim <- scale_opt
                }
            )

            # "openair" graph function
            polarPlot(
                y,
                pollutant = inquinante,
                type = tipo,
                limits = graph_limits,
                breaks = y_lim,
                key = legenda,
                main = titolo,
                sub = subtitolo,
                auto.text = FALSE,
                paddle = F,
                angle = 45
            )

            dev.off()

            flog.info(" > grafico POLARPLOT SEASON creato correttamente")
        } else {
            flog.info(" > !! dati inquinante mancanti SUPERIORI al 30% del totale")
        }
    },
    error = function(e) {
        flog.info(" > errore nella creazione del grafico")
    })

    # polarannulus hour graph
    flog.info(" > polarannulus hour")
    # nota: i valori di calma di vento sono stati esclusi dal grafico
    y_nocalma <- subset(y, ws >= w_calm) # nota: calma = 1m/s
    n_dati_nocalma <- nrow(y_nocalma)
    if(sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * 0.3 && n_dati_nocalma > n_dati * 0.2) {
        tryCatch({
            # nomefile = file.path(percorso_output, paste0(stazione, "_polarannulus_", inquinante, ".png"))
            nomefile <- file.path(tmp_path_full, paste0("polarannulus_", inquinante, ".png"))
            png(
                nomefile,
                width = larghezza,
                height = altezza,
                res = 150
            )
            titolo <- paste(p_station_name, "\nbivariate polar annulus plot ", inquinante, "\nda ", start_d, " a ", end_d)
            subtitolo <- paste("Concentrazione in funzione del tempo (ore) e della direzione del vento (dati ", round(perc), "%)\nStazione meteo: ", w_station_name)
            periodo <- "hour"
            # tipo <- "default"

            # set graph scale
            switch(scale_type,
                "0" = { # default
                    flog.info("Default")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = 9))
                },
                "1" = { # numero di fasce
                    flog.info("Numero di fasce")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = scale_opt))
                },
                "2" = { # scala da utente
                    flog.info("Scala da utente")

                    y_lim <- scale_opt
                }
            )

            # "openair" graph function
            polarAnnulus(
                subset(y, ws >= w_calm),
                pollutant = inquinante,
                limits = graph_limits,
                breaks = y_lim,
                resolution = "fine",
                period = periodo,
                key = legenda,
                main = titolo,
                sub = subtitolo,
                auto.text = FALSE,
                paddle = FALSE,
                angle = 45,
                k = 10
            )

            dev.off()

            flog.info(" > grafico POLARANNULUS HOUR creato correttamente")
        },
        error = function(e) {
            flog.info(" > errore nella creazione del grafico")
        })
    } else {
        flog.info(" > !! dati inquinante mancanti SUPERIORI al 30% del totale o dati vento mancanti SUPERIORI al 20% del totale")
    }

    # polarannulus season graph
    flog.info(" > polarannulus season")
    # solo se presente almeno 80% dei dati (se il numero di dati è di molto inferiore a 1 anno, da errore)
    # nota: i valori di calma di vento sono stati esclusi dal grafico
    if(sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * 0.8 && n_dati_nocalma > n_dati * 0.2) {
        tryCatch({
            # nomefile = file.path(percorso_output, paste0(stazione, "_polarannulus_season_", inquinante, ".png"))
            nomefile <- file.path(tmp_path_full, paste0("polarannulus_season_", inquinante, ".png"))
            png(
                nomefile,
                width = larghezza+50,
                height = altezza,
                res = 150
            )
            titolo <- paste(p_station_name, "\nbivariate polar annulus plot stagionale ", inquinante, "\nda ", start_d, " a ", end_d)
            subtitolo <- paste("Concentrazione in funzione del tempo (stagioni) e della direzione del vento (dati ", round(perc), "%)\nStazione meteo: ", w_station_name)
            periodo <- "season"
            tipo <- "default"

            # set graph scale
            switch(scale_type,
                "0" = { # default
                    flog.info("Default")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = 9))
                },
                "1" = { # numero di fasce
                    flog.info("Numero di fasce")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = scale_opt))
                },
                "2" = { # scala da utente
                    flog.info("Scala da utente")

                    y_lim <- scale_opt
                }
            )

            # "openair" graph function
            polarAnnulus(
                subset(y, ws >= w_calm),
                pollutant = inquinante,
                limits = graph_limits,
                breaks = y_lim,
                resolution = "fine",
                period = periodo,
                type = tipo,
                key = legenda,
                main = titolo,
                sub = subtitolo,
                auto.text = FALSE,
                paddle = FALSE,
                angle = 45,
                k = 10
            )

            dev.off()

            flog.info(" > grafico POLARANNULUS SEASON creato correttamente")
        },
        error = function(e) {
            flog.info(" > errore nella creazione del grafico")
        })
    } else {
        flog.info(" > !! dati inquinante mancanti SUPERIORI al 80% del totale o dati vento mancanti SUPERIORI al 20% del totale")
    }
}

#' Function that generates POLLUTIONROSE "openair" graph
#'
#' @param inquinante Pollutant name (string).
#' @param limiti Limits array.
#'
#' @examples
#' g_pollutionrose(
#'     inquinante,
#'     eval(parse(text = (paste0("limiti$", inquinante))))
#' )
g_pollutionrose <- function(inquinante, limiti) {
    flog.info(" > pollutionrose")
    tryCatch({
        # nomefile = file.path(percorso_output, paste0(stazione, "_pollutionrose_", inquinante, ".png"))
        nomefile <- file.path(tmp_path_full, paste0("pollutionrose_", inquinante, ".png"))
        png(
            nomefile,
            width = larghezza,
            height = altezza,
            res = 150
        )
        titolo <- paste(p_station_name, "\npollutionRose", inquinante, "\nda ", start_d, " a ", end_d)
        subtitolo <- paste("Frequenza di osservazioni rispetto alla direzione del vento (dati ", round(perc), "%)\nStazione meteo: ", w_station_name)
        my.statistic <- list(
            "fun" = length,
            "unit" = "%",
            "scale" = "all",
            "lab" = list(
                subtitolo,
                cex = 0.65
            ),
            "fun2" = function(x) signif(mean(x, na.rm = TRUE), 3),
            "lab2" = "mean",
            "labcalm" = function(x) round(x, 1)
        )
        tipo <- c("season")

        # set graph scale
        switch(scale_type,
            "0" = { # default
                flog.info("Default")

                y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = 9))
            },
            "1" = { # numero di fasce
                flog.info("Numero di fasce")

                y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = scale_opt))
            },
            "2" = { # scala da utente
                flog.info("Scala da utente")

                y_lim <- scale_opt
            }
        )

        # "openair" graph function
        pollutionRose(
            y,
            pollutant = inquinante,
            type = tipo,
            limits = graph_limits,
            breaks = y_lim,
            main = titolo,
            sub = subtitolo,
            statistic = my.statistic,
            key = legenda,
            annotate = TRUE,
            bias.corr = FALSE,
            auto.text = FALSE,
            paddle = F,
            angle = 45
        )

        dev.off()

        flog.info(" > grafico POLLUTIONROSE creato correttamente")
    },
    error = function(e) {
        flog.info(" > errore nella creazione del grafico")
    })
}

#' Function that generates POLARPLOT (weekend) "openair" graph
#'
#' @param inquinante Pollutant name (string).
#' @param limiti Limits array.
#'
#' @examples
#' g_polarplot_weekend(
#'     inquinante,
#'     eval(parse(text = (paste0("limiti$", inquinante))))
#' )
g_polarplot_weekend <- function(inquinante, limiti) {
    flog.info(" > polarplot weekend")
    tryCatch({
        if (sum(!is.na(variabile)) > n_dati * 0.3) { # aggiunto controllo su percentuale dati mancanti per inizio anno
            # nomefile = file.path(percorso_output, paste0(stazione, "_polarplot_", inquinante, ".png"))
            nomefile <- file.path(tmp_path_full, paste0("polarplot_", inquinante, ".png"))
            png(
                nomefile,
                width = larghezza,
                height = altezza,
                res = 150
            )
            titolo <- paste(p_station_name, "\nbivariate polar plot of concentrations", inquinante, "\nda ", start_d, " a ", end_d)
            subtitolo <- paste("Date di riferimento: ", start_d, " a ", end_d, "\nStazione meteo di referimento: ", w_station_name, "\nConcentrazione rispetto alla direzione e velocità del vento (dati ", round(perc), "%)")

            # (hack) encoding problems...
            Encoding(subtitolo) <- "UTF-8"

            tipo <- "weekend"

            # set graph scale
            switch(scale_type,
                "0" = { # default
                    flog.info("Default")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = 9))
                },
                "1" = { # numero di fasce
                    flog.info("Numero di fasce")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = scale_opt))
                },
                "2" = { # scala da utente
                    flog.info("Scala da utente")

                    y_lim <- scale_opt
                }
            )

            # "openair" graph function
            polarPlot(
                y,
                pollutant = inquinante,
                type = tipo,
                limits = graph_limits,
                breaks = y_lim,
                key = legenda,
                main = titolo,
                sub = subtitolo,
                auto.text = FALSE,
                paddle = F,
                angle = 45
            )

            dev.off()

            flog.info(" > grafico POLARPLOT WEEKEND creato correttamente")
        } else {
            flog.info(" > !! dati inquinante mancanti SUPERIORI al 30% del totale")
        }
    },
    error = function(e) {
        flog.info(" > errore nella creazione del grafico")
    })
}

#' Function that generates POLARPLOT (season) "openair" graph
#'
#' @param inquinante Pollutant name (string).
#' @param limiti Limits array.
#'
#' @examples
#' g_polarplot_season(
#'     inquinante,
#'     eval(parse(text = (paste0("limiti$", inquinante))))
#' )
g_polarplot_season <- function(inquinante, limiti) {
    flog.info(" > polarplot season")
    tryCatch({
        if (sum(!is.na(variabile)) > n_dati * 0.3) { # aggiunto controllo su percentuale dati mancanti per inizio anno
            # nomefile = file.path(percorso_output, paste0(stazione, "_polarplot_season_", inquinante, ".png"))
            nomefile <- file.path(tmp_path_full, paste0("polarplot_season_", inquinante, ".png"))
            png(
                nomefile,
                width = larghezza,
                height = altezza,
                res = 150
            )
            # titolo = paste(stazione, "bivariate polar plot of concentrations ", inquinante, " - da ", data_start, " a ", data_end)
            # subtitolo = paste("Concentrazione rispetto alla direzione e velocità del vento (dati ", round(perc), "%) - Stazione meteo: ", stazione_vento)
            titolo <- paste(p_station_name, "\nbivariate polar plot of concentrations ", inquinante, "\nda ", start_d, " a ", end_d)
            subtitolo <- paste("Date di riferimento: ", start_d, " a ", end_d, "\nStazione meteo di referimento: ", w_station_name, "\nConcentrazione rispetto alla direzione e velocità del vento (dati ", round(perc), "%)")

            # (hack) encoding problems...
            Encoding(subtitolo) <- "UTF-8"

            tipo <- "season"

            # set graph scale
            switch(scale_type,
                "0" = { # default
                    flog.info("Default")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = 9))
                },
                "1" = { # numero di fasce
                    flog.info("Numero di fasce")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = scale_opt))
                },
                "2" = { # scala da utente
                    flog.info("Scala da utente")

                    y_lim <- scale_opt
                }
            )

            # "openair" graph function
            polarPlot(
                y,
                pollutant = inquinante,
                type = tipo,
                limits = graph_limits,
                breaks = y_lim,
                key = legenda,
                main = titolo,
                sub = subtitolo,
                auto.text = FALSE,
                paddle = F,
                angle = 45
            )

            dev.off()

            flog.info(" > grafico POLARPLOT SEASON creato correttamente")
        } else {
            flog.info(" > !! dati inquinante mancanti SUPERIORI al 30% del totale")
        }
    },
    error = function(e) {
        flog.info(" > errore nella creazione del grafico")
    })
}

#' Function that generates POLARANNULUS (hour) "openair" graph
#'
#' @param inquinante Pollutant name (string).
#' @param limiti Limits array.
#'
#' @examples
#' g_polarannulus_hour(
#'     inquinante,
#'     eval(parse(text = (paste0("limiti$", inquinante))))
#' )
g_polarannulus_hour <- function(inquinante, limiti) {
    flog.info(" > polarannulus hour")
    # nota: i valori di calma di vento sono stati esclusi dal grafico
    y_nocalma <- subset(y, ws >= w_calm) # nota: calma=1m/s
    n_dati_nocalma <- nrow(y_nocalma)
    if (sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * 0.3 && n_dati_nocalma > n_dati * 0.2) {
        tryCatch({
            # nomefile = file.path(percorso_output, paste0(stazione, "_polarannulus_", inquinante, ".png"))
            nomefile <- file.path(tmp_path_full, paste0("polarannulus_", inquinante, ".png"))
            png(
                nomefile,
                width = larghezza,
                height = altezza,
                res = 150
            )
            titolo <- paste(p_station_name, "\nbivariate polar annulus plot ", inquinante, "\nda ", start_d, " a ", end_d)
            subtitolo <- paste("Concentrazione in funzione del tempo (ore) e della direzione del vento (dati ", round(perc), "%)\nStazione meteo: ", w_station_name)
            periodo <- "hour"
            # tipo <- "default"

            # set graph scale
            switch(scale_type,
                "0" = { # default
                    flog.info("Default")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = 9))
                },
                "1" = { # numero di fasce
                    flog.info("Numero di fasce")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = scale_opt))
                },
                "2" = { # scala da utente
                    flog.info("Scala da utente")

                    y_lim <- scale_opt
                }
            )

            # "openair" graph function
            polarAnnulus(
                subset(y, ws >= w_calm),
                pollutant = inquinante,
                limits = graph_limits,
                breaks = y_lim,
                resolution = "fine",
                period = periodo,
                key = legenda,
                main = titolo,
                sub = subtitolo,
                auto.text = FALSE,
                paddle = FALSE,
                angle = 45,
                k = 10
            )

            dev.off()

            flog.info(" > grafico POLARANNULUS HOUR creato correttamente")
        },
        error = function(e) {
            flog.info(" > errore nella creazione del grafico")
        })
    } else {
        flog.info(" > !! dati inquinante mancanti SUPERIORI al 30% del totale o dati vento mancanti SUPERIORI al 20% del totale")
    }
}

#' Function that generates POLARANNULUS (season) "openair" graph
#'
#' @param inquinante Pollutant name (string).
#' @param limiti Limits array.
#'
#' @examples
#' g_polarannulus_season(
#'     inquinante,
#'     eval(parse(text = (paste0("limiti$", inquinante))))
#' )
g_polarannulus_season <- function(inquinante, limiti) {
    flog.info(" > polarannulus season")
    # solo se presente almeno 80% dei dati (se il numero di dati è di molto inferiore a 1 anno, da errore)
    # nota: i valori di calma di vento sono stati esclusi dal grafico
    y_nocalma <- subset(y, ws >= w_calm) # nota: calma=1m/s
    n_dati_nocalma <- nrow(y_nocalma)
    if (sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * 0.8 && n_dati_nocalma > n_dati * 0.2) {
        tryCatch({
            # nomefile = file.path(percorso_output, paste0(stazione, "_polarannulus_season_", inquinante, ".png"))
            nomefile <- file.path(tmp_path_full, paste0("polarannulus_season_", inquinante, ".png"))
            png(
                nomefile,
                width = larghezza + 50,
                height = altezza,
                res = 150
            )
            titolo <- paste(p_station_name, "\nbivariate polar annulus plot stagionale ", inquinante, "\nda ", start_d, " a ", end_d)
            subtitolo <- paste("Concentrazione in funzione del tempo (stagioni) e della direzione del vento (dati ", round(perc), "%)\nStazione meteo: ", w_station_name)
            periodo <- "season"
            tipo <- "default"

            # set graph scale
            switch(scale_type,
                "0" = { # default
                    flog.info("Default")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = 9))
                },
                "1" = { # numero di fasce
                    flog.info("Numero di fasce")

                    y_lim <- round(seq(0, max(eval(parse(text = column)), na.rm = TRUE), length.out = scale_opt))
                },
                "2" = { # scala da utente
                    flog.info("Scala da utente")

                    y_lim <- scale_opt
                }
            )

            # "openair" graph function
            polarAnnulus(
                subset(y, ws >= w_calm),
                pollutant = inquinante,
                limits = graph_limits,
                breaks = y_lim,
                resolution = "fine",
                period = periodo,
                type = tipo,
                key = legenda,
                main = titolo,
                sub = subtitolo,
                auto.text = FALSE,
                paddle = FALSE,
                angle = 45,
                k = 10
            )

            dev.off()

            flog.info(" > grafico POLARANNULUS SEASON creato correttamente")
        },
        error = function(e) {
            flog.info(" > errore nella creazione del grafico")
        })
    } else {
        flog.info(" > !! dati inquinante mancanti SUPERIORI al 80% del totale o dati vento mancanti SUPERIORI al 20% del totale")
    }
}

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# start up
flog.info(" >>>>>>> start external_program (inquinanti.R)")

# trasforma in km/h le velocità del vento:
# inquinanti$ws = inquinanti$ws * 3.6

# graph parameters
y <- pollutants_data

# check data: elimina dati velocità del vento negativa
for(h in which(y$ws < 0)){ y$ws[h] <- NA }

# # porto a zero tutti i valori < 1 m/s per conteggiarli nella calma di vento
# y$ws[which(y$ws < calma)] <- 0

# scala di vento debole/medio/forte
ws_lim <- c(w_calm, 5, 10, 15, 25) # in m/s
ws_labels <- c("calma", "debole", "moderato", "forte", "molto forte")
ws_labels2 <- c("debole", "moderato", "forte", "molto forte", "tempestoso")
ws_legend <- paste(" calma:< ", w_calm, " m/s, debole:1-5 m/s, moderato: 5-10 m/s, forte:10-15 m/s, molto forte: 15-25 m/s ")
n_lim <- length(ws_lim)

# GRAPHS
# graph features
data_sistema <- format(Sys.Date(), "%d/%m/%Y")
larghezza <- 1000
altezza <- 768
unita <- "px"
sfondo <- "white"
risoluzione <- NA # in dpi

# colour definitions (http://www.stat.columbia.edu/~tzheng/files/Rcolor.pdf)
colori <- c("olivedrab", "olivedrab3", "gold", "darkorange", "orangered")

#------------------------------------------------------------------------------

# DIREZIONE E VELOCITA' DEL VENTO IN FUNZIONE DEL TEMPO
flog.info(paste(" > grafico velocita e direzione del vento ", w_station_name))

# colours
colws <- "#CD5B45"
colwd <- "#458B74"

# nomefile = file.path(percorso_output, paste0(stazione, "_wind.png"))
nomefile <- file.path(tmp_path_full, paste0("wind.png"))
png(
    filename = nomefile,
    width = larghezza,
    height = altezza,
    unit = unita,
    bg = sfondo,
    res = risoluzione
)
titolo <- paste("Direzione e velocità del vento\n", w_station_name, "\nda ", start_d, " a ", end_d)

# (hack) encoding problems...
Encoding(titolo) <- "UTF-8"

# indicizza dati mancanti
nodata <- y$date
nodataws <- replace(nodata, which(!is.na(y$ws)), NA)
nodatawd <- replace(nodata, which(!is.na(y$wd)), NA)

# 2 figures arranged in 2 rows and 1 column
par(mfrow = c(2, 1))

# (hack) encoding problems...
y_label <- "velocità (m/s)"
Encoding(y_label) <- "UTF-8"

# wind speed graph
plot(
    y$date,
    y$ws,
    type = "p",
    ylim = c(-1, max(y$ws, na.rm = TRUE) + 2),
    col = colws,
    main = titolo,
    xlab = "data",
    ylab = y_label
)
abline(
    h = 0,
    lty = 2,
    lwd = 2,
    col = "grey"
)
segments(
    y$date,
    rep(-1, n_dati),
    y$date,
    rep(-0.5, n_dati),
    col = "grey"
)
segments(
    nodataws,
    rep(-1, n_dati),
    nodataws,
    rep(-0.5, n_dati),
    col = colws
)

# (hack) encoding problems...
string_legend <- "velocità del vento"
Encoding(string_legend) <- "UTF-8"

legend(
    "topleft",
    c(string_legend, "dati mancanti"),
    lty = c(NA, NA),
    pch = c(1, 15),
    lwd = c(1, 3),
    col = c(colws, colws),
    ncol = 2,
    cex = 1
)

# wind direction graph
plot(
    y$date,
    y$wd,
    type = "p",
    ylim = c(-40, 420),
    col = colwd,
    xlab = "data",
    ylab = "direzione (gradi)",
    yaxt = "n"
)
abline(
    h = c(0, 180, 360),
    lty = 2,
    lwd = 2,
    col = "grey"
)
segments(
    y$date,
    rep(-40, n_dati),
    y$date,
    rep(-15, n_dati),
    col = "grey"
)
segments(
    nodatawd,
    rep(-40, n_dati),
    nodatawd,
    rep(-15, n_dati),
    col = colwd
)
axis(
    2,
    at = c(0, 90, 180, 270, 360),
    labels = c(0, 90, 180, 270, 360)
)
legend(
    "topleft",
    c("direzione del vento", "dati mancanti"),
    lty = c(NA, NA),
    pch = c(1, 15),
    lwd = c(1, 3),
    col = c(colwd, colwd),
    ncol = 2,
    cex = 1
)

dev.off()
flog.info(" > grafico DIREZIONE E VELOCITA' DEL VENTO IN FUNZIONE DEL TEMPO creato correttamente")

#------------------------------------------------------------------------------

# porto a zero tutti i valori < 1 m/s per conteggiarli nella calma di vento:
y$ws[which(y$ws < w_calm)] <- 0

#------------------------------------------------------------------------------

# ROSA DEI VENTI

flog.info(paste(" > rosa dei venti ", w_station_name))

# nomefile = file.path(percorso_output, paste0(stazione, "_windrose.png"))
nomefile <- file.path(tmp_path_full, paste0("windrose.png"))
png(
    filename = nomefile,
    width = larghezza,
    height = altezza,
    unit = unita,
    bg = sfondo,
    res = risoluzione
)
titolo <- paste("Rosa dei venti\n", w_station_name, "\nda ", start_d, " a ", end_d)
subtitolo <- paste("Frequenza di osservazioni rispetto alla direzione del vento (dati ", round(100*check/n_dati), "%)\nStazione meteo: ", w_station_name)
max_freq <- 50 # massimo per assi x e y

# (hack) encoding problems...
s_header <- "velocità del vento"
Encoding(s_header) <- "UTF-8"

legenda <- list(
    header = s_header,
    footer = "m/s",
    plot.style = c("paddle"),
    fit = "all",
    height = 1,
    space = "right",
    col = colori
)
my.statistic <- list(
    "fun" = length,
    "unit" = "%",
    "scale" = "all",
    "lab" = list(
        subtitolo,
        cex = 0.65),
    "fun2" = function(x) signif(mean(x, na.rm = TRUE), 3),
    "lab2" = "mean",
    "labcalm" = function(x) round(x, 1)
)
# statistic$lab <- "My title"

# "openair" graph function
windRose(
    y,
    breaks = c(ws_lim),
    cols = colori,
    key = legenda,
    max.freq = max_freq,
    main = titolo,
    sub = subtitolo,
    par.settings = list(fontsize = list(text = 18)),
    statistic = my.statistic,
    annotate = TRUE,
    auto.text = FALSE,
    paddle = F,
    angle = 45
)

dev.off()

flog.info(" > grafico ROSA DEI VENTI creato correttamente")

#------------------------------------------------------------------------------

# ROSA DEI VENTI STAGIONALE

flog.info(paste(" > rosa dei venti stagionale ", w_station_name))

# nomefile = file.path(percorso_output, paste0(stazione, "_windrose_season.png"))
nomefile <- file.path(tmp_path_full, paste0("windrose_season.png"))
png(
    filename = nomefile,
    width = larghezza,
    height = altezza,
    unit = unita,
    bg = sfondo,
    res = risoluzione
)
titolo <- paste("Rosa dei venti stagionale\n", w_station_name, '\nda ', start_d, ' a ', end_d)
subtitolo <- paste("Frequenza di osservazioni rispetto alla direzione del vento (dati ", round(100*check/n_dati), "%)\nStazione meteo: ", w_station_name)
max_freq <- 50 # massimo per assi x e y

# (hack) encoding problems...
s_header <- "velocità del vento"
Encoding(s_header) <- "UTF-8"

# legenda velocità del vento
legenda <- list(
    header = s_header,
    footer = "m/s",
    plot.style = c("paddle"),
    fit = "all",
    height = 1,
    space = "right",
    col = colori
)

# modifica la scritta sotto il grafico
my.statistic <- list(
    "fun" = length,
    "unit" = "%",
    "scale" = "all",
    "lab" = list(
        subtitolo,
        cex = 0.65),
    "fun2" = function(x) signif(mean(x, na.rm = TRUE), 3),
    "lab2" = "mean",
    "labcalm" = function(x) round(x, 1)
)

# "openair" graph function
windRose(
    y,
    type = c("season", "daylight"),
    breaks = c(ws_lim),
    cols = colori, # xlab = x_labels,
    par.settings = list(fontsize = list(text = 18)),
    statistic = my.statistic,
    key = legenda,
    max.freq = max_freq,
    annotate = TRUE,
    main = quickText(titolo, auto.text = FALSE),
    auto.text = FALSE,
    paddle = F,
    angle = 45,
    bias.corr = FALSE
)

dev.off()

flog.info(" > grafico ROSA DEI VENTI STAGIONALE creato correttamente")

#------------------------------------------------------------------------------

# chimici: limiti di legge
# no2 = 205
# o3 = 240.5

#------------------------------------------------------------------------------

# GRAFICI PER INQUINANTE / CATEGORIA DI STRUMENTO

# check if instrument category is not provided
if (inst_cat == -1) {
    flog.info(" > generate ALL graphs")

    for (inquinante in pollutants[, "poll_name"]) {
        if (sum(colnames(y) == inquinante) > 0) { # controlla l'esistenza della colonna corrispondente all'inquinante (parse confonde pm10 e pm1)
            variabile <- eval(parse(text = as.name(paste0("y$", inquinante))))
            if (!is.null(variabile) && sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * lim_dati) {
                all_graphs(
                    inquinante,
                    eval(parse(text = (paste0("limiti$", inquinante))))
                )
            }
        }
    }
} else {
    flog.info(" > generate graphs per instrument category")

    # for PM10, PM2.5 ((hack) per lo switch)
    if (dust_poll <- inst_cat %in% c("10", "14", "16")) {
        inst_cat <- "pm"
    }

    # switch per instrument category
    switch(inst_cat,
        "1" = { # Analizzatore SO2
            flog.info("Analizzatore SO2")

            # set pollutant
            inquinante <- "so2"

            # graphs metadata
            g_metadata(inquinante)

            # graphs
            if (sum(colnames(y) == inquinante) > 0) { # controlla l'esistenza della colonna corrispondente all'inquinante (parse confonde pm10 e pm1)
                variabile <- eval(parse(text = as.name(paste0("y$", inquinante))))
                if (!is.null(variabile) && sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * lim_dati) {
                    g_pollutionrose(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarplot_weekend(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarplot_season(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarannulus_hour(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarannulus_season(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                } else {
                    flog.info("> !! check data limits")
                }
            } else {
                flog.info("> !! check pollutant data column")
            }
        },
        "2" = { # Analizzatore NOx
            flog.info("Analizzatore NOx")

            # set pollutants
            inquinanti <- c("nox", "no2", "no")

            # graphs per pollutant
            for (inquinante in inquinanti) {
                # graphs metadata
                g_metadata(inquinante)

                if (sum(colnames(y) == inquinante) > 0) { # controlla l'esistenza della colonna corrispondente all'inquinante (parse confonde pm10 e pm1)
                    variabile <- eval(parse(text = as.name(paste0("y$", inquinante))))
                    if (!is.null(variabile) && sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * lim_dati) {
                        g_pollutionrose(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarplot_weekend(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarplot_season(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarannulus_hour(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarannulus_season(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                    } else {
                        flog.info("> !! check data limits")
                    }
                } else {
                    flog.info("> !! check pollutant data column")
                }
            }
        },
        "3" = { # Analizzatore CO
            flog.info("Analizzatore CO")

            # set pollutant
            inquinante <- "co"

            # graphs metadata
            g_metadata(inquinante)

            # graphs
            if (sum(colnames(y) == inquinante) > 0) { # controlla l'esistenza della colonna corrispondente all'inquinante (parse confonde pm10 e pm1)
                variabile <- eval(parse(text = as.name(paste0("y$", inquinante))))
                if (!is.null(variabile) && sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * lim_dati) {
                    g_pollutionrose(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarplot_weekend(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarplot_season(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarannulus_hour(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarannulus_season(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                } else {
                    flog.info("> !! check data limits")
                }
            } else {
                flog.info("> !! check pollutant data column")
            }
        },
        "4" = { # Analizzatore O3
            flog.info("Analizzatore O3")

            # set pollutant
            inquinante <- "o3"

            # graphs metadata
            g_metadata(inquinante)

            # graphs
            if (sum(colnames(y) == inquinante) > 0) { # controlla l'esistenza della colonna corrispondente all'inquinante (parse confonde pm10 e pm1)
                variabile <- eval(parse(text = as.name(paste0("y$", inquinante))))
                if (!is.null(variabile) && sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * lim_dati) {
                    g_pollutionrose(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarplot_weekend(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarplot_season(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarannulus_hour(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                    g_polarannulus_season(
                        inquinante,
                        eval(parse(text = (paste0("limiti$", inquinante))))
                    )
                } else {
                    flog.info("> !! check data limits")
                }
            } else {
                flog.info("> !! check pollutant data column")
            }
        },
        "5" = { # Analizzatore BTX
            flog.info("Analizzatore BTX")

            # set pollutants
            inquinanti <- c("ben", "tol", "etil")

            # graphs per pollutant
            for (inquinante in inquinanti) {
                # graphs metadata
                g_metadata(inquinante)

                if (sum(colnames(y) == inquinante) > 0) { # controlla l'esistenza della colonna corrispondente all'inquinante (parse confonde pm10 e pm1)
                    variabile <- eval(parse(text = as.name(paste0("y$", inquinante))))
                    if (!is.null(variabile) && sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * lim_dati) {
                        g_pollutionrose(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarplot_weekend(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarplot_season(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarannulus_hour(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarannulus_season(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                    } else {
                        flog.info("> !! check data limits")
                    }
                } else {
                    flog.info("> !! check pollutant data column")
                }
            }
        },
        "pm" <- { # Polveri
            flog.info("Polveri")
            # 10    Campionatore polveri basso volume
            # 14    Campionatore polveri ottico
            # 16    Misuratore polveri

            # set pollutants
            inquinanti <- c("pm10", "pm25")

            # graphs per pollutant
            for (inquinante in inquinanti) {
                # graphs metadata
                g_metadata(inquinante)

                if (sum(colnames(y) == inquinante) > 0) { # controlla l'esistenza della colonna corrispondente all'inquinante (parse confonde pm10 e pm1)
                    variabile <- eval(parse(text = as.name(paste0("y$", inquinante))))
                    if (!is.null(variabile) && sum(!is.na(variabile) & !is.na(y$ws) & !is.na(y$wd)) > n_dati * lim_dati) {
                        g_pollutionrose(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarplot_weekend(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarplot_season(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarannulus_hour(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                        g_polarannulus_season(
                            inquinante,
                            eval(parse(text = (paste0("limiti$", inquinante))))
                        )
                    } else {
                        flog.info("> !! check data limits")
                    }
                } else {
                    flog.info("> !! check pollutant data column")
                }
            }
        }
    )
}

#------------------------------------------------------------------------------

# end
flog.info(" >>>>>>> end external_program (inquinanti.R)")

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------