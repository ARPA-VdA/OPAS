#!/usr/bin/python3
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : exporter_e2a.py
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#   Description : Ispra E2a data export
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
"""
    main script
    --include
    sudo apt-get install python3-pip
    pip install psycopg2-binary
    -- validation
    pylint --max-line-length=240 exporter_e2a.py
"""
import sys
import os
import logging
from datetime import datetime
import ftplib
import psycopg2
import psycopg2.extras
# custom files
import config
from log import logger, set_log

def clear_screen():
    """Clear screen"""
    if os.name == "posix":
        # Unix/Linux/MacOS/BSD/etc
        os.system('clear')
    elif os.name in ("nt", "dos", "ce"):
        # DOS/Windows
        os.system('CLS')

def pg_connect(pg_cnf):
    """Database connection"""
    logger.info("Database connection")
    try:
        con = psycopg2.connect(
            host=pg_cnf['host'],
            port=pg_cnf['port'],
            user=pg_cnf['user'],
            password=pg_cnf['password'],
            database=pg_cnf['database'],
            application_name=pg_cnf['appname']
        )
    except psycopg2.OperationalError as ex:
        logger.critical("An database exception was encountered: %s", str(ex))
        return None
    else:
        return con

def pg_disconnect(con):
    """Database disconnection"""
    logger.verbose("Database disconnection")
    try:
        con.close()
    except psycopg2.OperationalError as ex:
        logger.critical("An database exception was encountered: %s", str(ex))

def pg_get_data(con, id_rete):
    """Get records to be processed"""
    logger.verbose("Get records to be processed")
    try:
        sql = """
            WITH deleted AS (
                DELETE FROM
                    infoaria.data_export_e2a
                WHERE
                    counter IN (
                        SELECT
                            counter
                        FROM
                            infoaria.data_export_e2a t
                            LEFT JOIN infoaria.view_e2a_metadata v ON (t.station_id = v.station_id AND t.measure_id = v.stpr_table_id)
                        WHERE
                            t.station_id IN (
                                SELECT station_id FROM metadata.stations
                                LEFT JOIN metadata.stations_info USING(station_id)
                                WHERE st_info_network_type_fk = %s
                            )
                            AND v.e2a_active IS TRUE
                        ORDER BY
                            counter LIMIT 1000
                    )
                RETURNING
                    counter,
                    station_id,
                    measure_date_time,
                    measure_id,
                    measure_value,
                    post_validity_code
            )
            SELECT
                -- header metadata
                v.station_name,
                v.assessment_type_id,
                v.spo_name,
                v.pollutant_id,
                v.observation_unit_id,
                v.param_decimals,
                v.stpr_cadence,
                CASE v.stpr_cadence
                    WHEN 5 THEN 'hour'
                    WHEN 8 THEN 'day'
                    ELSE ''
                END AS cadence_txt,
                -- data
                measure_date_time,
                CASE v.stpr_cadence
                    WHEN 5 THEN
                        to_char(measure_date_time at time zone 'utc-2', 'YYYY-MM-DD"T"HH24:MI:SSOF":00"')

                    WHEN 8 THEN
                        to_char(measure_date_time at time zone 'utc-1', 'YYYY-MM-DD"T"HH24:MI:SSOF":00"')
                    ELSE ''
                END AS start_measure_time,
                CASE v.stpr_cadence
                    WHEN 5 THEN
                        to_char(measure_date_time at time zone 'utc-2', 'YYYY-MM-DD') || 'T'
                            || to_char( ( (extract('hour' from measure_date_time at time zone 'utc-2') + 1) * interval '1 hours')::interval, 'HH24:MI:SS')
                            || to_char(current_timestamp, 'OF') || ':00'

                    WHEN 8 THEN
                        to_char((measure_date_time + interval '24 hours') at time zone 'utc-1', 'YYYY-MM-DD') || 'T'
                            || to_char( ( (extract('hour' from (measure_date_time + interval '24 hours') at time zone 'utc-1') + 1) * interval '1 hours')::interval, 'HH24:MI:SS')
                            || to_char(current_timestamp, 'OF') || ':00'
                    ELSE ''
                END AS end_measure_time,
                -- OLD -> 2022-06-09T00:00:00+01:00  2022-06-09T24:00:00+01:00
                -- NEW -> 2022-06-09T23:00:00+01:00  2022-06-10T23:00:00+01:00
                CASE
                    WHEN -64 = ANY( main.signed_bitmask_toarray(t.post_validity_code, 10 ) )   THEN -99 -- non valido per manutenzione
                    WHEN post_validity_code < -1                                               THEN  -1 -- non valido (<-DL, malfunzionamento, altro)
                    WHEN ROUND(cast(measure_value * v.param_conv AS numeric), v.param_decimals)
                        BETWEEN -(detection_limit) AND detection_limit                         THEN   2 -- valido (-DL <= valore < DL) -> valore come misurato (WE USE THIS ONE)
                    --WN measure_value < det_limit                                             THEN   3 -- valido (-DL <= valore < DL) -> valore sostituito da DL/2
                    ELSE 1                                                                            -- valido (>=DL)
                END
                                                                                         AS validity_flag,      -- pg 10
                -- 1->verified, 2->preliminary verified, 3->not verified
                3::integer                                                               AS verification_flag,  -- pg 10 -- (OK FOR 2013)
                ROUND(cast(measure_value * v.param_conv AS numeric), v.param_decimals)   AS measure_value,      -- pg 11

                CASE
                    WHEN -4 = ANY( main.signed_bitmask_toarray(t.post_validity_code, 10 ) ) THEN 'false'
                    ELSE 'true'
                END                                                             AS coverage_flag,
                96::real                                                        AS data_capture,                -- pg 11 [] -- NOT USED
                post_validity_code                                              AS measure_code
            FROM
                deleted t
                LEFT JOIN infoaria.view_e2a_metadata v
                    ON (t.station_id = v.station_id AND t.measure_id = v.stpr_table_id)
            WHERE
                e2a_active IS TRUE
            ORDER BY
                t.counter; -- make sure keep incoming data order !!
        """

        logger.verbose("Sql: %s" % str(sql))

        # execute the query
        logger.debug("Execute the query")
        #cur = con.cursor()
        cur = con.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # timezone + sql
        cur.execute("SET timezone = 'UTC-1'")
        cur.execute(sql, (id_rete,))

        # retrieve the whole result set
        logger.verbose("Retrieve the whole result set")
        records = cur.fetchall()

        # close cursor and connection
        logger.verbose("Close cursor and connection")
        cur.close()

        # return data
        return records

    except psycopg2.OperationalError as ex:
        logger.critical("An database exception was encountered: %s", str(ex))
        return None

def pg_commit(con):
    """Commit current transaction"""
    logger.info("Commit transaction")
    con.commit()

def pg_roll_back(con):
    """Rollback current transaction"""
    logger.info("Rollback transaction")
    con.rollback()

def save_data_file(full_file_name, buffer):
    """Save data to export file"""
    try:
        # dump data to file
        file_name = os.path.splitext(full_file_name)[0]
        logger.debug("Saving data to file %s", file_name)
        with open(full_file_name, "w") as file:
            file.write(buffer)

    except IOError as ex:
        logger.critical("An exception was encountered: %s", str(ex))

def append_data_file(full_file_name, buffer):
    """Append data to export file"""
    try:
        # dump data to file
        file_name = os.path.splitext(full_file_name)[0]
        logger.debug("Appending data to file %s", file_name)
        with open(full_file_name, "a") as file:
            file.write(buffer)

    except IOError as ex:
        logger.critical("An exception was encountered: %s", str(ex))

def ftp_send_file(ftp_cnf, full_file_name, ftpfilename):
    """Send ftp file"""
    logger.info("Send ftp file")

    # ftp object
    ftp = None
    try:
        logger.info("Sending ftp file %s", full_file_name)

        # ftp login
        logger.info("Logging ftp in")
        ftp = ftplib.FTP()
        ftp.connect(host=ftp_cnf['host'], port=ftp_cnf['port'], timeout=15)
        ftp.login(ftp_cnf['user'], ftp_cnf['pass'])
        ftp.set_pasv(ftp_cnf['pasv'])
        ftp.cwd(ftp_cnf['path'])

        # send the file
        logger.info("Sending file content")
        filehandle = open(full_file_name, 'rb')
        ftp.storlines('STOR '+ ftpfilename, filehandle)
        filehandle.close()
        return True

    except Exception as ex:
        logger.error("Exception : %s", str(ex))
        return False
    finally:
        # close file and FTP
        logger.info("Closing ftp connection")
        if ftp:
            ftp.quit()
        logger.info("Done.")

def main():
    """Main function"""
    try:
        # Clear
        clear_screen()

        # Logging VERBOSE | DEBUG | INFO
        logging.VERBOSE = 5
        set_log(logging.VERBOSE)

        # Start
        now = datetime.now()
        logger.info("Program start @ {}".format(now.strftime("%Y-%m-%d %H:%M:%S")))

        # application path
        logger.verbose("Paths check")
        app_path = os.path.dirname(os.path.realpath(__file__))

        # Data export path
        export_path = os.path.join(app_path, 'export')
        if not os.path.exists(export_path):
            os.mkdir(export_path)

        # Application path
        data_path = os.path.join(export_path, now.strftime('%Y/%m/%d'))
        if not os.path.exists(data_path):
            os.makedirs(data_path)

        # Get the connection handler
        con = pg_connect(config.PGCNF)

        # Check connection
        if con is None:
            sys.exit(1)

        # Build data file name
        logger.verbose("Build data filename")
        now = datetime.now()

        # custom filename - E2a_02_2018032713.csv
        #my $data_file = "$data_path/E2a_02_".$fyear.$fmonth.$fday.$fhour.".csv"; #E2a_02_2018020108.csv (E2a_05_2018011903.csv)
        data_file_name = "E2a_{0}_{1}.csv".format(config.IPR['idregione'], now.strftime('%Y%m%d%H'))
        data_full_file_name = os.path.join(data_path, data_file_name)

        # Get data
        logger.verbose("Get available data")
        data_records = pg_get_data(con, config.IPR['idrete'])
        if data_records:
            # loop through all the records and build data files
            for rec in data_records:
                logger.verbose(f"Processing station: {rec['station_name']}")
                logger.verbose(f"Processing spo: {rec['spo_name']}")

                # build data file name
                logger.verbose("Build datafile")
                now = datetime.now()

                # # from april
                # ($fyear,$fmonth,$fday, $fhour,$fmin,$fsec) = Add_Delta_DHMS($fyear,$fmonth,$fday, $fhour,$fmin,$fsec,0,0,0,0);
                # $fmonth = sprintf "%02d", $fmonth;
                # $fday   = sprintf "%02d", $fday;
                # $fhour  = sprintf "%02d", $fhour;
                # $fmin   = sprintf "%02d", $fmin;
                # $fsec   = sprintf "%02d", $fsec;
                # my $data_file = "$data_path/E2a_02_".$fyear.$fmonth.$fday.$fhour.".csv"; #E2a_02_2018020108.csv (E2a_05_2018011903.csv)
                # # Tipodataset_codiceISTATregione_PeriodoRiferimento_TipoSottomissione.csv(/.xml)
                # # E1A_01_2013_IC.csv(/.xml)
                # # Legenda tipo sottomissione:
                # #   IC : invio completo (cancellazione preventiva di tutti i dati E1A per il periodo di riferimento)
                # #   IN: integrazione (non potranno contenere serie temporali parzialmente sovrapposte a quelle già presenti nel sistema)
                # #   SO: sostituzione (cancellazione dei dati relativi al periodo di riferimento di punti di campionamento che vengono risottomessi).
                # # 02 - Valle d'Aosta

                # fixed;SPO.IT0988A_8_chemi_2001-11-15_00:00:00;2018-03-27T12:00:00+02:00;2018-03-27T13:00:00+02:00;8;hour;ug.m-3;true;true;15;1;0
                # assessment_type
                # fixed

                # SPO.IT0988A_8_chemi_hour
                # SPO + st_info_eu_code + pollutant_id + method

                # ug.m-3  true  true  15  1  0
                # observation_unit_id + coverage_flag (>75%) + data_capture_flag (>90%) + uncertanty_exstimation + rec_count (1) + observation_decimals_place

                # !! Build header
                # fixed;SPO.IT0983A_8_chemi_2005-01-01_00:00:00;2022-01-05T16:00:00+01:00;2022-01-05T17:00:00+01:00;8;hour;ug.m-3;true;true;15;1;0

                #--------------------------------------------------------
                # Data Capture = 100* Nvalid/Ntotal
                #--------------------------------------------------------
                # Nvalid = n° misure orarie / giornaliere valide
                # Ntotal= n° di campioni orari/giornalieri pianificati nel Time coverage e coincide numericamente con Nplanned del Time coverage.
                # Nello specifico vanno conteggiati i dati con flag di validità 1, 2, e 3 e quelli con flag -99.

                # 8->day, 5->hour
                if rec['stpr_cadence'] == 5:

                    data_capture_flag = 'false'
                    if rec['validity_flag'] in [-99, 1, 2, 3]:
                        data_capture_flag = 'true'

                else:
                    # da implementare
                    v1 = 24
                    # v2 =
                    # if ( rec['validity_flag'] ):
                    #     v2 = 1

                    # datacapt = ( 100 * ( v2 / v1) )

                    # data_capture_flag = 'false';
                    # if ( datacapt > 90 ):
                    data_capture_flag = 'true' # 90% - ozone winter time 75%

                # build header
                buffer = '{};SPO.{};{};{};{};{};{};{};{};15;1;{}{}'.format(
                    rec['assessment_type_id'],
                    rec['spo_name'],
                    rec['start_measure_time'],
                    rec['end_measure_time'],
                    rec['pollutant_id'],
                    rec['cadence_txt'],
                    rec['observation_unit_id'],
                    rec['coverage_flag'],
                    data_capture_flag,
                    rec['param_decimals'],
                    "\n"
                )

                # Append buffer to file
                append_data_file(data_full_file_name, buffer)

                # !! Build data line
                # 2022-01-05T16:00:00+01:00;2022-01-05T17:00:00+01:00;3;1;7

                if rec['measure_value']:
                    measure_value = rec['measure_value']
                else:
                    measure_value = -9999

                buffer = '{};{};{};{};{}{}'.format(
                    rec['start_measure_time'],
                    rec['end_measure_time'],
                    rec['verification_flag'],
                    rec['validity_flag'],
                    measure_value,
                    "\n"
                )

                # Append buffer to file
                append_data_file(data_full_file_name, buffer)

            # Send file via ftp
            if ftp_send_file(config.FTPCNF, data_full_file_name, data_file_name):
                # Commit transaction as no errors
                pg_commit(con)

            else:
                logger.info("Error sending file to FTP server")
                # Rollback transaction
                pg_roll_back(con)
        else:
            logger.info("No data found")
            # Rollback transaction
            pg_roll_back(con)

    except (psycopg2.OperationalError, IOError, Exception) as ex:
        logger.critical("Exception: %s", str(ex))
        # Rollback transaction
        pg_roll_back(con)
    finally:
        # Disconnect from database
        pg_disconnect(con)

if __name__ == '__main__':
    main()
