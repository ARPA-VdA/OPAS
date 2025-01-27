#!/usr/bin/python3
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : planning_mailer.py
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#   Description : Parse planning tickets and send custom mails. (tt_id = 1 -> Ticket non programmati)
#                 Mail attività correttive e manutentive
#
#    "CRON" row :
#       # planning tickets
#       * * * * * /usr/bin/python3 /path/to/script/mail_planning/planning_mailer.py
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

"""
    main script
    --include
    sudo apt-get install python3-pip
    pip install psycopg2
    -- validation
    pylint --max-line-length=240 planning_mailer.py
"""
import sys
import os
import logging
import logging.handlers
from datetime import datetime
import platform
import psycopg2
import psycopg2.extras

def create_log(logging_level):
    """Create log manager"""
    # path
    logpath = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'log')
    if not os.path.exists(logpath):
        os.makedirs(logpath)
    # script name
    file_name = os.path.basename(sys.argv[0])
    # log name
    logname = os.path.join(logpath, file_name + '.log')

    # formatter
    formatter = logging.Formatter('%(asctime)s-%(levelname)s: %(message)s')

    # rotation -  max 100 MB
    #handler = logging.handlers.RotatingFileHandler(logname, maxBytes=10*1024*1024, backupCount=100)
    #handler.setFormatter(formatter)
    #logging.getLogger('').addHandler(handler)

    handler = logging.handlers.TimedRotatingFileHandler(logname, when="w0", interval=1)
    handler.setFormatter(formatter)
    handler.suffix = "%Y%m%d"
    logging.getLogger('').addHandler(handler)

    # console
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    # formatter
    formatter_console = logging.Formatter('%(asctime)s-%(levelname)s: %(message)s')
    #formatter_console = logging.Formatter('%(message)s')
    console.setFormatter(formatter_console)
    logging.getLogger('').addHandler(console)

    # set custom level
    logging.getLogger('').setLevel(logging_level)
    console.setLevel(logging_level)

    # https://docs.python.org/3.4/library/logging.handlers.html?highlight=backupcount
    # CRITICAL 50
    # ERROR    40
    # WARNING  30
    # INFO     20
    # DEBUG    10
    # NOTSET    0

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
    """Database disconnection"""
    logging.info("Database disconnection")
    try:
        if con:
            con.close()
    except psycopg2.OperationalError as ex:
        logging.critical("An database exception was encountered: %s", str(ex))

def pg_get_records(con):
    """Get records to be processed"""
    logging.info("Get records to be processed")
    try:
        # Build query

        # Ticket type
        # 1   Correttivo     <<---
        # 2   Programmato
        # 3   Evolutivo
        # 4   Generale

        sql = """
            SELECT
                t.tk_id                                   AS ticket_id,
                --t.tk_parent_id_fk,
                t.tk_opening_date                         AS ticket_opening_date,
                t.tk_expiry_date                          AS ticket_expiry_date,
                --t.tk_opening_user_fk,
                (date_part('epoch'::text,
                 age(t.tk_expiry_date::timestamp, now()))
                 / 86400::double precision)::integer      AS ticket_days_to_expiration,
                ((us1.us_name || ' '::text) ||
                 COALESCE(us1.us_2nd_name, ''::text))
                 || us1.us_surname                        AS ticket_opening_user_name,
                --t.tk_recipient_comp_fk,
                --c.comp_name,
                t.station_id                              AS ticket_station_id,
                s.station_name                            AS ticket_station_name,
                --t.instr_id,
                --t.cy_id,
                --t.mi_id,
                --t.tt_id,
                --tt.tt_desc,
                --t.tc_id,
                tc.tc_desc                                AS ticket_category_desc,
                --t.tu_id,
                --tu.tu_desc,
                --t.tf_id,
                --tf.tf_desc,
                t.tk_title                                AS ticket_title,
                t.tk_opening_note                         AS ticket_opening_note,
                --t.tk_mail_date,
                CASE
                    WHEN t.instr_id IS NOT NULL THEN
                        (SELECT instr_type_fullname
                        || COALESCE(' - '||instrument_name, '')
                        || COALESCE(' ['||instrument_arpa_id||'] ', '')
                        FROM equipments.view_instruments vi
                        WHERE vi.instr_id = t.instr_id )
                    WHEN t.cy_id IS NOT NULL THEN
                        (SELECT cy_mixture
                        || COALESCE(' - '||cy_name, '')
                        || COALESCE(' ['||cy_arpa_id||']', '')
                        FROM equipments.cylinders c
                        WHERE cy_id = t.cy_id )
                    WHEN t.mi_id IS NOT NULL THEN
                        (SELECT mi_name
                        || COALESCE(' ['||mi_arpa_id||']', '')
                        FROM equipments.miscellanies m
                        WHERE mi_id = t.mi_id )
                    ELSE ''
                END                                       AS ticket_object_name,
                ml.ml_name                                AS ticket_recipient_group_name,
                array_to_string(vtml.user_mails, ',')     AS ticket_recipient_group_mail,
                array_to_string(vtml.external_mails, ',') AS ticket_recipient_exter_mail
                --tml.*,
                --ml.*,
                --vtml.*
            FROM
                reports.tickets t
                LEFT JOIN bobo.companies c ON c.comp_id = t.tk_recipient_comp_fk
                LEFT JOIN metadata.stations s USING (station_id)
                LEFT JOIN bobo.users us1 ON t.tk_opening_user_fk = us1.us_id
                LEFT JOIN reports.ticket_types tt USING (tt_id)
                LEFT JOIN reports.ticket_categories tc USING (tc_id)
                LEFT JOIN reports.ticket_urgencies tu USING (tu_id)
                LEFT JOIN reports.ticket_frequencies tf USING (tf_id)
                --LEFT JOIN reports.tickets_mlists tml USING (tk_id)
                --LEFT JOIN gateways.mailing_list ml USING(ml_id)
                LEFT JOIN reports.view_tickets_mlists vtml USING(tk_id)
                LEFT JOIN gateways.mailing_list ml USING(ml_id)
            WHERE
                t.tt_id = 1 -- to be sent asap tickets - Ticket type Correttivo
                AND ml_id IS NOT NULL
                AND tk_mail_date IS NULL
            ORDER BY
                t.tk_opening_date, s.station_name
            LIMIT 1
            FOR UPDATE OF t
        """
        #logging.debug('Sql: {0}, grid: {1}'.format(sql, mlist_id))

        # execute the query
        logging.debug("Execute the query")
        cur = con.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cur.execute(sql)

        # retrieve the whole result set
        logging.debug("Retrieve the whole result set")
        records = cur.fetchall()

        # close cursor and connection
        logging.debug("Close cursor and connection")
        cur.close()

        # return data
        return records

    except psycopg2.OperationalError as ex:
        logging.critical("An database exception was encountered: %s", str(ex))
        return None

def send_mail(con, records):
    """Send email to maintainers"""

    logging.info("Checking records")
    # sanity check
    if not records:
        logging.info("No data found")
        return

    # default mail recipients
    recipients = []

    # mail header
    logging.info("Building mail header")
    message_email = '<p style="font-size:12pt;">Riepilogo attivit&agrave; correttive e manutentive in programma.</p>\n'

    # open table
    message_email += '<table width=\"90%\" cellpadding=\"2\" style="border: solid gray 1px; border-collapse: collapse;">\n'
    message_email += '<thead>\n'
    message_email += '  <tr>\n'
    message_email += '    <th colspan=\"8\" style="border: solid gray 1px; padding: 4px; font-size: 14px;">Tabella tickets</th>'
    message_email += '  </tr>\n'
    message_email += '  <tr>\n'
    message_email += '    <th style="border: solid gray 1px; padding: 4px; text-align: left; min-width:100px">Scadenza</th>'
    message_email += '    <th style="border: solid gray 1px; padding: 4px; text-align: left;">Titolo</th>'
    message_email += '    <th style="border: solid gray 1px; padding: 4px; text-align: left;">Note</th>'
    message_email += '    <th style="border: solid gray 1px; padding: 4px; text-align: left;">Stazione</th>'
    message_email += '    <th style="border: solid gray 1px; padding: 4px; text-align: left;">Strumento/Altro</th>'
    message_email += '    <th style="border: solid gray 1px; padding: 4px; text-align: left;">Categoria</th>'
    message_email += '    <th style="border: solid gray 1px; padding: 4px; text-align: left;">Da</th>\n'
    message_email += '    <th style="border: solid gray 1px; padding: 4px; text-align: left;">A</th>\n'
    message_email += '  </tr>\n'
    message_email += '</thead>\n'

    # open a cursor
    cur = con.cursor(cursor_factory=psycopg2.extras.DictCursor)

    # loop through records
    try:
        for record in records:
            logging.debug("Station: {}, description: {}".format(record['ticket_station_name'], record['ticket_object_name']))

            # append mailing lists mail
            if record['ticket_recipient_group_mail']:
                #logging.debug("ticket_recipient_group_mail: {}".format(record['ticket_recipient_group_mail']))
                ticket_recipients = record['ticket_recipient_group_mail'].split(',')
                for recipient in ticket_recipients:
                    #logging.debug("recipient: {}".format(recipient))
                    if recipient not in recipients:
                        recipients.append(recipient)

            # append external mail
            if record['ticket_recipient_exter_mail']:
                ticket_recipients = record['ticket_recipient_exter_mail'].split(',')
                for recipient in ticket_recipients:
                    if recipient not in recipients:
                        recipients.append(recipient)

            # log full mail list
            logging.debug("recipients: {}".format(recipients))

            # message body
            message_email += '<tr>\n'
            css = ''
            if record['ticket_days_to_expiration'] < 0:
                css = 'background-color: #FFA500;'
            message_email += '  <td style="border: solid gray 1px; padding: 4px; text-align: left;'+css+'">'+str(record['ticket_expiry_date'])+'</td>\n'
            message_email += '  <td style="border: solid gray 1px; padding: 4px; text-align: left;">'+str(record['ticket_title'])+'</td>\n'
            message_email += '  <td style="border: solid gray 1px; padding: 4px; text-align: left;">'+str(record['ticket_opening_note'])+'</td>\n'
            message_email += '  <td style="border: solid gray 1px; padding: 4px; text-align: left;">'+str(record['ticket_station_name'])+'</td>\n'
            message_email += '  <td style="border: solid gray 1px; padding: 4px; text-align: left;">'+str(record['ticket_object_name'])+'</td>\n'
            message_email += '  <td style="border: solid gray 1px; padding: 4px; text-align: left;">'+str(record['ticket_category_desc'])+'</td>\n'
            message_email += '  <td style="border: solid gray 1px; padding: 4px; text-align: left;">'+str(record['ticket_opening_user_name'])+'</td>\n'
            message_email += '  <td style="border: solid gray 1px; padding: 4px; text-align: left;">'+str(record['ticket_recipient_group_name'])+'</td>\n'
            message_email += '</tr>\n'

            # update ticket sent time
            query = '''UPDATE reports.tickets SET tk_mail_date = current_timestamp WHERE tk_id = %s'''
            logging.debug("Executing query: {}, {}".format(query, record['ticket_id']))
            # execute
            cur.execute(query, (record['ticket_id'],))
            # commit
            con.commit()

    except (psycopg2.OperationalError, IOError, Exception) as ex:
        logging.error("An exception was encountered: %s", str(ex))
        # rollback if errors
        con.rollback()
    finally:
        # close cursor
        cur.close()

    # Close table
    message_email += '</table>\n'
    message_email += '<p style="margin-top:25px;font-size:9pt;line-height:22px;">\n'
    # escape message
    # $message =~ s//'''/g;
    # $message =~ s/\\/\\\\/g;
    logging.debug('mail body')
    logging.debug(message_email)
    logging.debug('recipients')
    logging.debug(recipients)

    # open a cursor
    cur = con.cursor(cursor_factory=psycopg2.extras.DictCursor)
    # send mail
    try:
        # build query
        query = '''
            INSERT INTO gateways.html_mails(app, recipients, subject, body, logo)
            VALUES (%s, %s, %s, %s, 'opas')
        '''
        logging.debug("Executing query: %s", query)

        # execute
        separator = ','
        cur.execute(query, ('planning.mailer.daily', separator.join(recipients), 'ISPRA.PLANNING', message_email))
        # commit
        con.commit()

    except (psycopg2.OperationalError, IOError, Exception) as ex:
        logging.error("An exception was encountered: %s", str(ex))
        # rollback if errors
        con.rollback()
        raise
    finally:
        # close cursor
        cur.close()

def main():
    """Main function"""
    con = None
    try:
        # Clear
        clear_screen()

        # Logging DEBUG | INFO
        create_log(logging.DEBUG)

        # Start
        now = datetime.now()
        logging.info("Program start @ %s on %s", now.strftime("%Y-%m-%d %H:%M:%S"), platform.system())

        # Get the connection handler
        pg_cnf = {
            'host': 'xxxxxxxx',
            'port': xxxx,
            'user': 'xxxxxxxx',
            'pass': 'xxxxxxxx',
            'database': 'xxxxxxxx',
            'appname': 'planning.mailer.daily'
        }

        # Connect to db and check result
        con = pg_connect(pg_cnf)
        if con is None:
            logging.warning("No db connection")
            sys.exit(1)

        # Get tickets to be sent by mail
        records = pg_get_records(con)
        # send mail to mainatiners
        send_mail(con, records)

    except (psycopg2.OperationalError, IOError, Exception) as ex:
        logging.critical("An exception was encountered: %s", str(ex))
    finally:
        # Disconnect from database
        pg_disconnect(con)
        # End
        logging.info("Program end.")

if __name__ == '__main__':
    main()
