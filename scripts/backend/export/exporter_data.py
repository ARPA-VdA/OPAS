#!/usr/bin/python3
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : export_data.py
#        Author : Ecometer s.n.c.
#          Date : 2025-03-28
#   Description : Export custom data to SFTP server
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
"""
    main script

    --include
    sudo apt-get install python3-pip
    pip install psycopg2-binary
    python -m pip install -U pip
    pip install cryptography
    pip install pynacl
    pip install bcrypt
    pip install paramiko
"""
import sys
import os
import logging
import logging.handlers
from datetime import datetime
import ftplib
import paramiko
import platform
import psycopg2
import psycopg2.extras

def create_log(logging_level):
    """Create log manager

    @param: logging_level: The level of logging from VERBOSE to ERROR
    """
    # Path
    logpath = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'log')
    if not os.path.exists(logpath):
        os.makedirs(logpath)
    # Script name
    file_name = os.path.basename(sys.argv[0])
    # Log name
    logdatafile = os.path.join(logpath, file_name + '.log')

    # Logging custom level
    logging.addLevelName(logging.VERBOSE, 'VERBOSE')
    logging.getLogger('').setLevel(logging.INFO)
    logging.Logger.verbose = lambda inst, msg, *args, **kwargs: inst.log(logging.VERBOSE, msg, *args, **kwargs)
    logging.verbose = lambda msg, *args, **kwargs: logging.log(logging.VERBOSE, msg, *args, **kwargs)

    # Formatter
    formatter = logging.Formatter('%(asctime)s-%(levelname)s: %(message)s')

    # Rotation -  max 100 MB
    handler = logging.handlers.RotatingFileHandler(logdatafile, maxBytes=10*1024*1024, backupCount=100)
    handler.setFormatter(formatter)
    logging.getLogger('').addHandler(handler)

    # Console
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    # Formatter
    formatter_console = logging.Formatter('%(asctime)s-%(levelname)s: %(message)s')
    console.setFormatter(formatter_console)
    logging.getLogger('').addHandler(console)

    # Set custom level
    logging.getLogger('').setLevel(logging_level)
    console.setLevel(logging_level)

def clear_screen():
    """Clear screen"""
    if os.name == "posix":
        # Unix/Linux/MacOS/BSD/etc
        os.system('clear')
    elif os.name in ("nt", "dos", "ce"):
        # DOS/Windows
        os.system('CLS')

def pg_connect(pg_cnf):
    """Database connection

    @param: pg_cnf: The Postgres configuration object
    """
    logging.info("Database connection")
    try:
        con = psycopg2.connect(
            host=pg_cnf['host'],
            port=pg_cnf['port'],
            user=pg_cnf['user'],
            password=pg_cnf['pass'],
            database=pg_cnf['database'],
            application_name=pg_cnf['appname']
        )
    except psycopg2.OperationalError as ex:
        logging.critical("An database exception was encountered: %s", str(ex))
        return None
    else:
        return con

def pg_disconnect(con):
    """Database disconnection

    @param: con: The db handler
    """
    logging.verbose("Database disconnection")
    try:
        con.close()
    except psycopg2.OperationalError as ex:
        logging.critical("An database exception was encountered: %s", str(ex))

def pg_get_records(con):
    """Get records to be processed

    @param: con: The db handler
    """
    logging.verbose("Get records to be processed")
    try:
        sql = """
        WITH deleted AS (
            DELETE FROM
                client_xxx.data_export
            WHERE
                counter IN (
                    SELECT counter FROM client_xxx.data_export ORDER BY counter LIMIT 10000
                )
            RETURNING
                counter,
                station_id,
                measure_date_time,
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
                final_validity_code
        )
        SELECT
            s.station_id         AS station_id,
            s.station_name       AS station_name,
            measure_date_time    AS measure_date_time,
            measure_id           AS measure_id,
            measure_value        AS measure_value,
            measure_perc         AS measure_perc,
            measure_min          AS measure_min,
            measure_min_time     AS measure_min_time,
            measure_max          AS measure_max,
            measure_max_time     AS measure_max_time,
            measure_std_dev      AS measure_std_dev,
            measure_code         AS measure_code,
            station_code         AS station_code,
            auto_validity_code   AS auto_validity_code,
            post_validity_code   AS post_validity_code,
            final_validity_code  AS final_validity_code,
            si.st_info_export_id AS station_export_id,
            spi.stpr_export_id1  AS stpr_export_id1,
            spi.stpr_export_id2  AS stpr_export_id2,
            pl.param_unit        AS measure_unit,
            pl.param_unit_conv   AS measure_unit_conv
        FROM
            deleted t
            LEFT JOIN metadata.stations s USING(station_id)
            LEFT JOIN metadata.stations_info si USING (station_id)
            LEFT JOIN metadata.stations_parameters sp ON t.station_id = sp.station_id AND t.measure_id = sp.stpr_table_id
            LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
            LEFT JOIN metadata.parameters pl ON sp.param_id = pl.param_id
        ORDER BY
            t.counter;
        """
        logging.verbose("Sql: %s" % str(sql))

        # Execute the query
        logging.debug("Execute the query")
        cur = con.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cur.execute(sql)

        # Retrieve the whole result set
        logging.verbose("Retrieve the whole result set")
        records = cur.fetchall()

        # Close cursor and connection
        logging.verbose("Close cursor and connection")
        cur.close()

        # Return data
        return records

    except psycopg2.OperationalError as ex:
        logging.critical("An database exception was encountered: %s", str(ex))
        return None

def save_data_file(full_file_name, file_name, buffer):
    """Save data to export file

    @param: full_file_name: The file name with path
    @param: file_name: The file name only
    @param: buffer: The file content
    """
    try:
        # Dump data to file
        logging.debug("Saving data to file %s", file_name)
        with open(full_file_name, "w") as file:
            file.write(buffer)

    except IOError as ex:
        logging.critical("An exception was encountered: %s", str(ex))

def append_data_file(full_file_name, file_name, buffer):
    """Append data to export file

    @param: full_file_name: The file name with path
    @param: file_name: The file name only
    @param: buffer: The file content
    """
    try:
        # Dump data to file
        logging.debug("Appending data to file %s", file_name)
        with open(full_file_name, "a") as file:
            file.write(buffer)

    except IOError as ex:
        logging.critical("An exception was encountered: %s", str(ex))

def ftp_send_file(ftp_cnf, file_name, ftp_file_name):
    """Upload file to FTP server

    @param: ftp_cnf: The config object
    @param: file_name: The file name
    @param: ftp_file_name: The ftp file name
    """
    logging.info("Send ftp file")
    ftp = None
    try:
        logging.info("Sending ftp file %s", file_name)

        # Ftp login
        logging.info("Logging ftp in")
        ftp = ftplib.FTP()
        ftp.connect(host=ftp_cnf['host'], port=ftp_cnf['port'], timeout=15)
        ftp.login(ftp_cnf['user'], ftp_cnf['pass'])
        ftp.set_pasv(ftp_cnf['pasv'])
        ftp.cwd(ftp_cnf['path'])

        # Send the file
        logging.info("Sending file content")
        filehandle = open(file_name, 'rb')
        ftp.storlines('STOR '+ ftp_file_name, filehandle)
        filehandle.close()

    except Exception as ex:
        logging.error("An exception was encountered in ftp_send_file() : %s", str(ex))
        raise
    finally:
        # Close file and FTP
        logging.info("Closing ftp connection")
        if ftp:
            ftp.quit()
        logging.info("Done.")

def sftp_upload_files(sftp_cnf, file_name, sftp_file_name):
    """Upload sftp files in the remote directory

    @param: sftp_cnf: The config object
    @param: file_name: The file name
    @param: sftp_file_name: The ftp file name
    """
    logging.info("Upload sftp files")
    ssh_client = None
    sftp = None
    try:

        # Login
        logging.debug("Connecting to: {}".format(sftp_cnf['host']))
        ssh_client = paramiko.SSHClient()
        ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh_client.load_system_host_keys()

        # Connection
        logging.debug("Login with: {}".format(sftp_cnf['user']))
        ssh_client.connect(
            hostname=sftp_cnf['host'],
            port=sftp_cnf['port'],
            username=sftp_cnf['user'],
            password=sftp_cnf['pass']
        )

        # Create an SFTP client object
        sftp = ssh_client.open_sftp()

        # Set path
        logging.debug("Change path to: {}".format(sftp_cnf['path']))
        sftp.chdir(sftp_cnf['path'])

        # Send the file
        logging.info("Sending file")
        sftp.put(file_name, sftp_file_name + ".part")

        # Rename remote file
        logging.debug("Rename file, remove [.part]")
        sftp.rename(sftp_file_name + ".part", sftp_file_name)

    except Exception as ex:
        logging.error("An exception was encountered in sftp_upload_files() : %s", str(ex))
        raise
    finally:
        logging.debug("Closing sftp connection")
        # close the connection
        if sftp:
            sftp.close()
        if ssh_client:
            ssh_client.close()
        logging.info("Done.")


def main():
    """Main function"""
    try:
        # Clear
        clear_screen()

        # Logging VERBOSE | DEBUG | INFO
        logging.VERBOSE = 5
        create_log(logging.DEBUG)

        # Start
        now = datetime.now()
        logging.info("Program start @ %s on %s", now.strftime("%Y-%m-%d %H:%M:%S"), platform.system())

        # application path
        logging.verbose("Paths")
        app_path = os.path.dirname(os.path.realpath(__file__))

        # Data export path
        export_path = os.path.join(app_path, 'export')
        if not os.path.exists(export_path):
            os.mkdir(export_path)

        # Ftp config
        ftp_cnf = {
            'host': 'xxxxxxxx',
            'port': 21,
            'user': 'xxxxxxxx',
            'pass': 'xxxxxxxx',
            'path': 'xxxxxxxx',
            'pasv': True
        }

        # Sftp config
        sftp_cnf = {
            'host': 'xxxxxxxx',
            'port': 22,
            'user': 'xxxxxxxx',
            'pass': 'xxxxxxxx',
            'path': 'xxxxxxxx'
        }

        # Postgres config
        pg_cnf = {
            'host': 'xxxxxxxx',
            'port': 5432,
            'user': 'xxxxxxxx',
            'pass': 'xxxxxxxx',
            'database': 'xxxxxxxx',
            'appname': 'xxxxxxxx'
        }

        # Get the connection handler
        con = pg_connect(pg_cnf)

        # Check connection
        if con is None:
            sys.exit(1)

        # Get data
        records = pg_get_records(con)

        # Check for valid data
        logging.debug("Check data")
        if records:

            # Build data file name
            logging.verbose("Build datafile")
            now = datetime.now()

            # Application path
            data_path = os.path.join(export_path, now.strftime('%Y%m%d'))
            if not os.path.exists(data_path):
                os.mkdir(data_path)

            # Custom filename - DATI.YYYYMMDDHHMMSS.csv
            data_file_name = "DATI.{0}.csv".format(now.strftime('%Y%m%d%H%M%S'))
            data_full_file_name = os.path.join(data_path, data_file_name)

            # Append header
            buffer = "station_id,measure_date_time,measure_id,measure_value,measure_perc,measure_min,measure_min_time,measure_max,measure_max_time,measure_std_dev,measure_code,measure_unit,station_code,auto_validity_code,post_validity_code,final_validity_code,station_export_id,stpr_export_id1,stpr_export_id2\n"

            # Loop through all the records and build data files
            for record in records:
                logging.verbose("station: %s, data: %s" % (
                    record['station_name'], record['measure_date_time'])
                )
                # Create buffer
                # infos
                buffer += '{},'.format(record['station_id'])
                # data
                buffer += '{},'.format(record['measure_date_time'])
                buffer += '{},'.format(record['measure_id'])
                buffer += '{},'.format(record['measure_value'])
                buffer += '{},'.format(record['measure_perc'])
                buffer += '{},'.format(record['measure_min'])
                buffer += '{},'.format(record['measure_min_time'])
                buffer += '{},'.format(record['measure_max'])
                buffer += '{},'.format(record['measure_max_time'])
                buffer += '{},'.format(record['measure_std_dev'])
                buffer += '{},'.format(record['measure_code'])
                buffer += '"{}",'.format(record['measure_unit'])
                buffer += '{},'.format(record['station_code'])
                # codes
                buffer += '{},'.format(record['auto_validity_code'])
                buffer += '{},'.format(record['post_validity_code'])
                buffer += '{},'.format(record['final_validity_code'])
                # ids
                buffer += '{},'.format(record['station_export_id'])
                buffer += '{},'.format(record['stpr_export_id1'])
                buffer += '{}'.format(record['stpr_export_id2'])
                # end
                buffer += '{}'.format("\n")

            # Append buffer to file
            save_data_file(data_full_file_name, data_file_name, buffer)

            # Send file via ftp
            ftp_send_file(ftp_cnf, data_full_file_name, data_file_name)

            # Send file via ftp
            sftp_upload_files(sftp_cnf, data_full_file_name, data_file_name)

            # Commit transaction as no errors
            logging.info("Commit transaction")
            con.commit()

        else:
            logging.info("No data found")
            # Rollback transaction
            logging.info("Rollback transaction")
            con.rollback()

    except (psycopg2.OperationalError, IOError, Exception) as ex:
        logging.critical("Exception: %s", str(ex))
        # Rollback transaction
        logging.warning("Rollback transaction")
        con.rollback()
    finally:
        # Disconnect from database
        pg_disconnect(con)

if __name__ == '__main__':
    main()
