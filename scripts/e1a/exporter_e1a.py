#!/usr/bin/python3
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : exporter_e1a.py
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#   Description : Ispra E1a data export
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
"""
    main script
    --include
    sudo apt-get install python3-pip
    pip install psycopg2-binary
    -- validation
    pylint --max-line-length=240 exporter_e1a.py
"""
import sys
import os
import logging
from datetime import datetime
import time
import ftplib
import subprocess
import json
import calendar
import psycopg2
import psycopg2.extras
from psycopg2.extensions import AsIs
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

def pg_get_spo(con, job, netid):
    """Get all available spo"""
    logger.verbose("Get all available spo")
    try:
        # Sql
        sql = """
            SELECT
                e1a.stpr_id,
                e1a.sps_year,
                e1a.e1a_active,
                e1a.station_id,
                e1a.stpr_table_id,
                e1a.station_name,
                e1a.param_id,
                e1a.param_name,
                e1a.param_conv,
                e1a.param_unit_conv,
                COALESCE(e1a.stpr_note, '') AS stpr_note,
                e1a.stpr_startup_date,
                e1a.stpr_dismiss_date,
                to_char(('%(year)s' || '-01-01')::TIMESTAMP WITH TIME ZONE, 'YYYY-MM-DD"T"HH24:MI:SS"+01:00"')  AS start_time,
                to_char(('%(year)s' || '-12-31 23:59:59')::TIMESTAMP WITH TIME ZONE, 'YYYY-MM-DD') || 'T'
                    || to_char( ( (extract('hour' FROM ('%(year)s' || '-12-31 23:59:59')::TIMESTAMP WITH TIME ZONE) + 1)
                    * interval '1 hours')::interval, 'HH24:MI:SS') || '+01:00'                       AS end_time,
                e1a.stpr_cadence,
                CASE
                    WHEN e1a.stpr_cadence = 5 THEN 'hour'
                    WHEN e1a.stpr_cadence = 8 THEN 'day'
                END AS stpr_cadence_desc,
                e1a.spo_name,
                e1a.st_info_name,
                e1a.st_info_eu_code,
                e1a.pollutant_id,
                e1a.pollutant_notation,
                e1a.observation_unit_id,
                coalesce(e1a.pp_uncertainty_estimation, 25) AS pp_uncertainty_estimation,
                coalesce(e1a.pp_time_coverage_perc, 90) AS pp_time_coverage_perc,
                coalesce(e1a.pp_decimals, 0) AS pp_decimals,
                e1a.assessment_type_id,
                e1a.analytical_technique_notation,
                e1a.instr_type_id,
                e1a.instr_type_fullname,
                e1a.measurement_type_notation,
                e1a.equipment,
                e1a.method,
                e1a.detection_limit,
                e1a.detection_limit_unit_id,
                ms.station_schema || '.' || ms.station_table AS table_name
            FROM
                infoaria.view_e1a_metadata e1a
                LEFT JOIN metadata.stations ms USING(station_id)
                LEFT JOIN metadata.stations_info msi USING(station_id)
            WHERE
                e1a_active IS true
                AND e1a.spo_name IS NOT NULL
                AND sps_year = %(year)s
                AND st_info_network_type_fk = %(netid)s
                --AND station_id = xxxx
            ORDER BY
                station_id, param_id
        """
        logger.verbose("Sql: %s" % str(sql))

        # Get cursor
        cur = con.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # Query parameters
        logger.debug("Execute the query with parameters")
        logger.verbose(f"> year {job['year']}")
        logger.verbose(f"> netid {netid}")

        # Execute query
        cur.execute(sql, {
            'year' : job['year'],
            'netid' : netid
        })
        # Retrieve the whole result set
        logger.verbose("Retrieve the whole result set")
        records = cur.fetchall()

        # Close cursor and connection
        logger.verbose("Close cursor and connection")
        cur.close()

        # Return data
        return records

    except psycopg2.OperationalError as ex:
        logger.critical("An database exception was encountered: %s", str(ex))
        return None

def pg_get_stat(con, job, spo):
    """Get stats for the requested spo"""
    logger.verbose("Get stats for the requested spo")
    try:
        # Take care of cadence
        # 1	    1 minuto
        # 2	    5 minuti
        # 3	    10 minuti
        # 4	    30 minuti
        # 5	    oraria
        # 6	    bi-oraria
        # 7	    tri-oraria
        # 8	    giornaliera
        # 9	    settimanale
        # 10	mensile
        # 11	annuale
        if (spo['stpr_cadence']) == 5:
            integration = '1 hour'
        else:
            integration = '1 day'

        # Sql
        sql = """
            WITH m AS(
                SELECT measure_date_time from generate_series(
                    ('%(year)s' || '-01-01')::timestamp,
                    ('%(year)s' || '-12-31 23:59:59')::timestamp, INTERVAL %(integration)s
                ) measure_date_time
            )
            SELECT
                count(m.measure_date_time) AS data_expected,
                count(
                    CASE
                        WHEN measure_value IS null     THEN null
                        WHEN post_validity_code = -128 THEN null  -- null or 1 ????
                        WHEN post_validity_code < 0    THEN null
                        ELSE 1
                    END
                ) AS data_collected,
                round(cast(avg(CASE WHEN post_validity_code >= 0
                    THEN measure_value * %(formule)s END) AS numeric), %(decimals)s) AS avg_expected
            FROM
                m
                LEFT JOIN %(table)s t ON m.measure_date_time = t.measure_date_time AND t.measure_id = %(id)s
            WHERE
                m.measure_date_time BETWEEN ('%(year)s' || '-01-01')::timestamp AND ('%(year)s' || '-12-31 23:59:59')::timestamp
        """
        logger.verbose("Sql: %s" % str(sql))

        # Execute the query
        logger.debug("Execute the query")
        cur = con.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # Query parameters
        logger.verbose(f"integration {integration}")
        logger.verbose(f"year {job['year']}")
        logger.verbose(f"table {AsIs(spo['table_name'])}")
        logger.verbose(f"id {spo['stpr_table_id']}")
        logger.verbose(f"formule {spo['param_conv']}")
        logger.verbose(f"decimals {spo['pp_decimals']}")

        # Execute query
        cur.execute(sql, {
            'integration' : integration,
            'year' : job['year'],
            'table' : AsIs(spo['table_name']),
            'id' : spo['stpr_table_id'],
            'formule' : spo['param_conv'],
            'decimals' : spo['pp_decimals']
        })

        # Retrieve the whole result set
        logger.verbose("Retrieve the whole result set")
        records = cur.fetchone()

        # Close cursor and connection
        logger.verbose("Close cursor and connection")
        cur.close()

        # Return data
        return records

    except psycopg2.OperationalError as ex:
        logger.critical("An database exception was encountered: %s", str(ex))
        return None

def pg_get_data(con, job, spo):
    """Get records to be processed for the requested spo"""
    logger.verbose("Get records to be processed for the requested spo")
    try:
        # Take care of cadence
        if (spo['stpr_cadence']) == 5:
            integration = '1 hour'
            time_offset = 1
        else:
            integration = '1 day'
            time_offset = 24

        # Sql
        sql = """
            WITH t AS(
                SELECT measure_date_time from generate_series(
                    ('%(year)s' || '-01-01')::timestamp,
                    ('%(year)s' || '-12-31 23:59:59')::timestamp, INTERVAL %(integration)s
                ) measure_date_time
            )
            SELECT
                t.measure_date_time,
                measure_id,
                measure_value,
                measure_perc,
                measure_min,
                measure_min_time,
                measure_max,
                measure_max_time,
                measure_std_dev,
                measure_code,
                station_code,
                auto_validity_code,
                post_validity_code,
                final_validity_code,
                measure_insert_ts,
                measure_update_obj,
                extract_code,
                calccode,
                to_char(t.measure_date_time, 'YYYY-MM-DD"T"HH24:MI:SS"+01:00"') AS start_measure_time, -- pg 10
                to_char(t.measure_date_time, 'YYYY-MM-DD') || 'T'
                    || to_char( ( (extract('hour' FROM t.measure_date_time) + %(time_offset)s) * interval '1 hours')::interval, 'HH24:MI:SS')
                    || '+01:00' AS end_measure_time,   -- pg 10
                CASE
                    WHEN post_validity_code <= -64 THEN -99 -- non valido per manutenzione
                    WHEN post_validity_code <   0  THEN  -1 -- non valido (<-DL, malfunzionamento, altro)
                    WHEN measure_value < %(ldl)s   THEN   2 -- valido (-DL <= valore < DL) -> valore come misurato (WE USE THIS ONE)
                    --WHEN measure_value < $ldl    THEN   3 -- valido (-DL <= valore < DL) -> valoro sostituito da DL/2
                    ELSE 1                                   -- valido (>=DL)
                END                                                                                             AS validity_flag,      -- pg 10
                -- 1->verified, 2->preliminary verified, 3->not verified
                1::smallint                                                                                     AS verification_flag,  -- pg 10 -- (OK FOR 2013)

                round(cast(measure_value * %(formule)s AS numeric), %(decimals)s)                               AS measure_value,      -- pg 11
                96::real                                                                                        AS data_capture        -- pg 11 []
	        FROM
                t LEFT JOIN %(table)s d ON t.measure_date_time = d.measure_date_time AND measure_id = %(id)s
            WHERE
                t.measure_date_time BETWEEN ('%(year)s' || '-01-01')::timestamp AND ('%(year)s' || '-12-31 23:59:59')::timestamp
            ORDER BY
                t.measure_date_time
            --LIMIT 1
        """
        logger.verbose("Sql: %s" % str(sql))

        # Get cursor
        cur = con.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # Query parameters
        logger.debug("Execute the query with parameters")
        logger.verbose(f"> integration {integration}")
        logger.verbose(f"> time_offset {time_offset}")
        logger.verbose(f"> year {job['year']}")
        logger.verbose(f"> table {AsIs(spo['table_name'])}")
        logger.verbose(f"> id {spo['stpr_table_id']}")
        logger.verbose(f"> ldl {spo['detection_limit']}")
        logger.verbose(f"> formule {spo['param_conv']}")
        logger.verbose(f"> decimals {spo['pp_decimals']}")

        # Execute query
        cur.execute(sql, {
            'integration' : integration,
            'time_offset' : time_offset,
            'year' : job['year'],
            'table' : AsIs(spo['table_name']),
            'id' : spo['stpr_table_id'],
            'ldl' : spo['detection_limit'],
            'formule' : spo['param_conv'],
            'decimals' : spo['pp_decimals'],
        })

        # Retrieve the whole result set
        logger.verbose("Retrieve the whole result set")
        records = cur.fetchall()

        # Close cursor and connection
        logger.verbose("Close cursor and connection")
        cur.close()

        # Return data
        return records

    except psycopg2.OperationalError as ex:
        logger.critical("An database exception was encountered: %s", str(ex))
        return None

def pg_job_get(con, jqid):
    """Get job to be executed"""
    logger.verbose("Get job to be executed")
    try:
        # Sql
        sql = """
            SELECT
                *
            FROM
            jsonb_to_record(
                (
                    SELECT
                        jq_args_obj
                    FROM
                        clients.jobs_queue
                    WHERE
                        jq_id = %(jqid)s
                )::jsonb
            ) AS x (
                year   smallint,
                region smallint,
                ftp    boolean
            )
        """
        logger.verbose("Sql: %s" % str(sql))

        # Get cursor
        cur = con.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # Query parameters
        logger.debug("Execute the query with parameters")
        logger.verbose(f"> jqid {jqid}")

        # Execute query
        cur.execute(sql, {
            'jqid' : jqid
        })

        # Retrieve the whole result set
        logger.verbose("Retrieve the whole result set")
        record = cur.fetchone()

        # Close cursor and connection
        logger.verbose("Close cursor and connection")
        cur.close()

        # Return data
        return record

    except psycopg2.OperationalError as ex:
        logger.critical("Exception in  pg_job_get: %s", str(ex))
        # Return
        return None

def pg_job_update(con, jqid, jqres):
    """Update job queue table"""
    logger.verbose("Update job queue table")
    try:
        # Sql
        sql = """
            UPDATE
                clients.jobs_queue
            SET
                jq_result_obj = %(jqres)s, jq_end_ts = CURRENT_TIMESTAMP
            WHERE
                jq_id = %(jqid)s
        """
        logger.verbose("Sql: %s" % str(sql))

        # Get cursor
        cur = con.cursor()

        # Query parameters
        logger.debug("Execute the query with parameters")
        logger.verbose(f"> jqres {jqres}")
        logger.verbose(f"> jqid {jqid}")

        # Execute query
        cur.execute(sql, {
            'jqres' : jqres,
            'jqid' : jqid
        })

        # Get result
        count = cur.rowcount
        logger.info("Record updated successfully: {}".format(count))

        # Make the changes to the database persistent
        con.commit()

        # Return ok
        return True

    except (psycopg2.OperationalError, IOError, Exception) as ex:
        logger.critical("Exception in pg_store_data: %s", str(ex))
        con.rollback()
        # Return
        return False

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
        # Dump data to file
        logger.debug("Saving data to file %s", full_file_name)
        with open(full_file_name, "w") as file:
            file.write(buffer)

    except IOError as ex:
        logger.critical("An exception was encountered: %s", str(ex))

def append_data_file(full_file_name, buffer):
    """Append data to export file"""
    try:
        # Dump data to file
        #logger.debug("Appending data to file %s", full_file_name)
        with open(full_file_name, "a") as file:
            file.write(buffer)

    except IOError as ex:
        logger.critical("An exception was encountered: %s", str(ex))

def read_file(full_file_name):
    """Read file content"""
    try:
        # Read file
        logger.debug("Reading data from file %s", full_file_name)
        with open(full_file_name) as s:
            content = s.read()

        return content

    except IOError as ex:
        logger.critical("An exception was encountered: %s", str(ex))

def ftp_send_file(ftp_cnf, full_file_name, ftpfilename):
    """Send ftp file"""
    logger.info("Send ftp file")

    # ftp object
    ftp = None
    try:
        logger.info("Sending ftp file %s", full_file_name)

        # Ftp login
        logger.info("Logging ftp in")
        ftp = ftplib.FTP()
        ftp.connect(host=ftp_cnf['host'], port=ftp_cnf['port'], timeout=15)
        ftp.login(ftp_cnf['user'], ftp_cnf['pass'])
        ftp.set_pasv(ftp_cnf['pasv'])
        ftp.cwd(ftp_cnf['path'])

        # Send the file
        logger.info("Sending file content")
        filehandle = open(full_file_name, 'rb')
        ftp.storlines('STOR '+ ftpfilename, filehandle)
        filehandle.close()
        return True

    except Exception as ex:
        logger.error("Exception : %s", str(ex))
        return False
    finally:
        # Close file and FTP
        logger.info("Closing ftp connection")
        if ftp:
            ftp.quit()
        logger.info("Done.")

def main():
    """Main function"""
    try:
        # Clear
        clear_screen()

        # Get connection
        con = None

        # Logging VERBOSE | DEBUG | INFO
        logging.VERBOSE = 5
        set_log(logging.VERBOSE)

        # Start
        now = datetime.now()
        logger.info("Program start @ {}".format(now.strftime("%Y-%m-%d %H:%M:%S")))

        # Argument list check
        args = len(sys.argv)
        if args != 2:
            logger.info("Usage, {} [job-id]".format(os.path.basename(__file__)))
            return

        # Get job id
        jqid = sys.argv[1]

        # Application path
        logger.verbose("Paths check")
        app_path = os.path.dirname(os.path.realpath(__file__))

        # Data export path
        export_path = os.path.join(app_path, 'export')
        data_path = os.path.join(export_path, now.strftime('%Y'))
        if not os.path.exists(data_path):
            os.makedirs(data_path)

        # Get the connection handler
        con = pg_connect(config.PGCNF)

        # Check connection
        if con is None:
            sys.exit(1)

        # Get Job to be processed
        logger.verbose("Retrieve job to be processed by id")
        job = pg_job_get(con, jqid)
        logger.verbose(f"Processing job: {job}")

        # Get spo list
        logger.verbose("Get available sampling point")
        data_spo = pg_get_spo(con, job, config.IPR['idrete'])
        # Sanity check
        if data_spo:

            # html_chunks table body
            html_chunks = []

            # Custom filename -> E1a_02_2021_20220606115723.csv
            logger.verbose("Build data filename")
            #my $data_file = "$data_path/E1a_02_".$fyear.$fmonth.$fday.$fhour.".csv"; #E1a_02_2021_20220606115723.csv
            # Take care of preview file
            if job['ftp']:
                logger.verbose("Official run")
                data_file_name = "E1a_{0}_{1}_{2}.csv".format(
                    config.IPR['idregione'],
                    job['year'],
                    now.strftime('%Y%m%d%H%M%S')
                )

            else:
                logger.verbose("Preview run")
                data_file_name = "E1a_{0}_{1}_{2}_preview.csv".format(
                    config.IPR['idregione'],
                    job['year'],
                    now.strftime('%Y%m%d%H%M%S')
                )

            # Build full file name
            data_full_file_name = os.path.join(data_path, data_file_name)

            # Loop through all the records and build data files
            logger.verbose("Loop through all the spo records")
            for spo in data_spo:
                # Log
                logger.verbose(f"Processing station: {spo['station_name']}")
                logger.verbose(f"> Table: {spo['table_name']}")
                logger.verbose(f"> Param: {spo['param_name']} {spo['stpr_note']}")
                logger.verbose(f"> Id: {spo['stpr_table_id']}")
                logger.verbose(f"> Spo: {spo['spo_name']}")
                logger.verbose(f"> Cadence: {spo['stpr_cadence']}")
                logger.verbose(f"> Eu code: {spo['st_info_eu_code']}")
                logger.verbose(f"> Time coverage perc: {spo['pp_time_coverage_perc']}")

                # Html table
                html_chunks.append("<tr>")
                html_chunks.append("<td>{}</td>".format(spo['station_name']))
                html_chunks.append("<td>{}</td>".format(spo['st_info_eu_code']))
                html_chunks.append("<td>{} {}</td>".format(spo['param_name'], spo['stpr_note']))

                # Get stats to build header
                logger.verbose("Get available stats to build header record")
                data_stat = pg_get_stat(con, job, spo)
                # Sanity check
                if data_stat:
                    logger.verbose("Calculate stats")

                    logger.verbose("Calculate time coverage")
                    # Time coverage = 100* Nplanned/Nyear
                    # Nplanned = n° giorni/ore di monitoraggio
                    # Nyear = n° giorni/ore contenuti in un anno
                    v1 = data_stat['data_expected']
                    v2 = data_stat['data_collected']
                    avg = data_stat['avg_expected']
                    v_timecov = round( 100 * (v2 / v1))
                    v_timecov_flag = False
                    cov_perc = spo['pp_time_coverage_perc'] # 90, 50 ,33
                    if (v_timecov > cov_perc ):
                        v_timecov_flag = True

                    # Log report
                    logger.verbose(f"Data expected: {v1}")
                    logger.verbose(f"Data collected: {v2}")
                    logger.verbose(f"Data coverage: {v_timecov}")
                    logger.verbose(f"Data avg expected: {avg}")

                    # Html table
                    html_chunks.append("<td>{}</td>".format(v1))
                    html_chunks.append("<td>{}</td>".format(v2))
                    if ( v_timecov >= 75 ):
                        html_chunks.append('<td style="color:#008000; font-weight:bold;">{}</td>'.format(v_timecov))
                    else:
                        html_chunks.append('<td style="color:#e60000; font-weight:bold;">{}</td>'.format(v_timecov))

                    logger.verbose("Calculate data capture")
                    # Data Capture = 100* Nvalid/Ntotal
                    # Nvalid = n° misure orarie / giornaliere valide
                    # Ntotal= n° di campioni orari/giornalieri pianificati nel Time coverage e coincide numericamente con Nplanned del Time coverage.
                    # Nello specifico vanno conteggiati i dati con flag di validità 1, 2, e 3 e quelli con flag -99.
                    #$v1 = $stats->[0]->{'data_expected'};
                    #$v2 = $stats->[0]->{'data_collected'};
                    v_datacapt = round( 100 * (v2 / v1))
                    #$log->info("\t-> v_datacapt: ".$v_datacapt);
                    v_datacapt_flag = False
                    if (v_datacapt > 90):
                        v_datacapt_flag = True # 90% - ozone winter time 75%

                    logger.verbose(f"Data expected: {v1}")
                    logger.verbose(f"Data collected: {v2}")
                    logger.verbose(f"Data Capture: {v_datacapt}")

                    logger.verbose("Calculate record count")
                    # Record_count: Numero Intero che rappresenta il numero di record presenti nel blocco record delle misure,
                    # con tutti i possibili valori del validity_flag.
                    #my $record_count = $row->{'record_count'};
                    record_count = data_stat['data_expected']
                    data_average = data_stat['avg_expected']
                    #$log->info("\t-> record_count: ".$record_count);
                    logger.verbose(f"Record count: {record_count}")
                    logger.verbose(f"Data average: {data_average}")

                    # Html table
                    html_chunks.append("<td>{}</td>".format(data_average))

                    # Take care of leap years
                    year_days  = 365
                    year_hours = 8760
                    ref_year = job['year']
                    if ( calendar.isleap( ref_year ) ):
                        year_days  = 366;
                        year_hours = 8784;

                    # Sanity check
                    if ( record_count == year_days or record_count == year_hours):
                        logger.verbose(f"All ok")
                    else:
                        #logger.verbose("\tdata: ".sqldata)
                        #logger.verbose("\tstats: ".sqlstats)
                        logger.verbose(f"Expected record count (365/66 or 8760), instead: {record_count}")
                        return

                    logger.verbose("Build file header")
                    # Build header
                    # fixed;SPO.IT0988A_7_UV-P_2001-11-15_00:00:00;2021-01-01T00:00:00+01:00;2021-12-31T24:00:00+01:00;7;hour;ug.m-3;true;true;15;8760;0  <-- ok
                    # Assessment_type; Sampling_point_id; start_time; end_time; pollutant_id;
                    # primary_observation; UoM; Time coverage; Data_capture; Uncertanty_estimation; Record_count, Decimal_places
                    header = []
                    header.append(str(spo['assessment_type_id']))
                    header.append("SPO.{}".format(str(spo['spo_name'])))
                    header.append(str(spo['start_time']))
                    header.append(str(spo['end_time']))
                    header.append(str(spo['pollutant_id']))
                    header.append(str(spo['stpr_cadence_desc']))
                    header.append(str(spo['observation_unit_id']))
                    header.append(str(v_timecov_flag).lower())
                    header.append(str(v_datacapt_flag).lower())
                    header.append(str(spo['pp_uncertainty_estimation']))
                    header.append(str(record_count))
                    header.append(str(spo['pp_decimals']))
                    row = ";".join(header)
                    logger.verbose(f"Header: {row}")

                    # Html table
                    html_chunks.append("<td>{}</td>".format(row))
                    html_chunks.append("</tr>")

                    # Append header to file
                    append_data_file(data_full_file_name, row+"\n")

                else:
                    logger.warning("No stats available")
                    return

                # Get data
                logger.verbose("Get available data")
                data_records = pg_get_data(con, job, spo)

                # Sanity check
                if data_records:
                    # Loop through all the records and build data files
                    for rec in data_records:
                        #logger.verbose(f"Date time: {rec['measure_date_time']}")
                        #logger.verbose(f"Value: {rec['measure_value']}")
                        #logger.verbose(f"Code: {rec['post_validity_code']}")

                        # Build data file name
                        #logger.verbose("Build datafile")
                        now = datetime.now()

                        # Caculations
                        validity_flag = rec['validity_flag']
                        if (validity_flag == -1):
                            logger.warning("Values not valid, validity_flag = -1")
                            # not valid
                            measure_value = -9999;

                        else:
                            # Data check
                            if (rec['post_validity_code'] or rec['post_validity_code'] == 0):
                                measure_code = rec['post_validity_code']
                            else:
                                logger.warning("Post validity code is null")
                                measure_code = -9999;

                            # Get measure value
                            if (rec['measure_value'] or rec['measure_value'] == 0):
                                measure_value = rec['measure_value']

                                # Parameter HACK
                                if (spo['pollutant_id'] == 5012):
                                    # Piombo su PM10 microgrammi
                                    logger.warning("Conversione Piombo in microgrammi")
                                    measure_value = measure_value / 1000
                                    measure_value = round(measure_value, spo['pp_decimals'])

                            else:
                                logger.warning("Measure_value code is null")
                                measure_value = -9999;
                                if (validity_flag > 0):
                                    validity_flag = -1

                            # Validity check
                            if (measure_code < 0):
                                logger.warning("Value not valid, measure_code < 0")
                                measure_value = -9999;
                                if ( validity_flag > 0 ):
                                    validity_flag = -1

                        # Build record
                        fields = []
                        fields.append(str(rec['start_measure_time']))
                        fields.append(str(rec['end_measure_time']))
                        fields.append(str(validity_flag))
                        fields.append(str(rec['verification_flag']))
                        fields.append(str(measure_value))
                        row = ";".join(fields)
                        #logger.verbose(f"Data: {row}")

                        # Append buffer to file
                        append_data_file(data_full_file_name, row+"\n")

                else:
                    logger.info("No data found")
                    # Update queue table
                    x = '{ "head": "File dati E1a non creato. Errori durante il recupero dei dati", "text": "Operazione non eseguita", "type": "warn" }'
                    pg_job_update(con, jqid, x)
                    return

            # Build html content
            logger.info("Build HTML content")
            table_header = read_file(os.path.join(app_path, 'templates/table-header.html'))
            table_footer = read_file(os.path.join(app_path, 'templates/table-footer.html'))
            html_content = "{}\n{}\n{}".format(table_header, "\n".join(html_chunks), table_footer)
            #logger.verbose(f"HTML: {html_content}")
            # Get filename
            logger.info("Export to file")
            table_file = "table_e1a_{}.html".format(job['year'])
            logger.verbose(f"table_file: {table_file}")
            table_full_file_name = os.path.join(data_path, table_file) # data_path - app_path
            # Save html data to file
            save_data_file(table_full_file_name, html_content)

            # Send file via scp
            logger.info("Send file via scp to HTTP server")
            #cmd = "scp {} user@host:/path".format(data_full_file_name)
            #call(cmd.split(" "))
            command = ";".join(['/usr/bin/scp', data_full_file_name, config.HTTP['url']])
            logger.verbose(f"Command: {command}")
            # Run command
            result = subprocess.run(['/usr/bin/scp', data_full_file_name, config.HTTP['url']])
            retcode = result.returncode
            logger.verbose(f"Return code: {retcode}")
            # Check result
            if retcode == 0:
                logger.info("File sent to HTTP server")

            else:
                logger.info("Error sending file to HTTP server")

                # Update queue table
                #logger.info("Update queue table")
                x = '{ "head": "Impossibile copiare il file CSV nella directory di scarico dati", "text": "Operazione non eseguita", "type": "warn" }'
                pg_job_update(con, jqid, x)
                return

            # Send file via ftp if requested
            if job['ftp']:
                if ftp_send_file(config.FTPCNF, data_full_file_name, data_file_name):
                    logger.info("File sent to FTP server")

                    # Update queue table
                    logger.info("All went fine")
                    x = '{ "head": "File dati E1a creato ed inviato in FTP.", "text": "Operazione eseguita con successo", "type": "succ" }'
                    pg_job_update(con, jqid, x)

                else:
                    logger.info("Error sending file to FTP server")
                    # Update queue table
                    x = '{ "head": "Impossibile inviare il file CSV nello spazio FTP dedicato", "text": "Operazione non eseguita", "type": "warn" }'
                    pg_job_update(con, jqid, x)
                    return

            else:
                # Update queue table
                logger.info("All went fine")
                x = '{ "head": "File dati E1a creato.", "text": "Operazione eseguita con successo", "type": "succ" }'
                pg_job_update(con, jqid, x)

        else:
            logger.warning("No sampling points found")

            # Update queue table
            x = '{ "head": "Nessun sample point trovato per la rete e l\'anno selezionato", "text": "Operazione non eseguita", "type": "warn" }'
            pg_job_update(con, jqid, x)

    except (psycopg2.OperationalError, IOError, Exception) as ex:
        # Log execption
        logger.critical("Exception: %s", str(ex))

    finally:
        # Disconnect from database
        if con:
            pg_disconnect(con)

if __name__ == '__main__':
    main()
