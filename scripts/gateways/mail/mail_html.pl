#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : mail_html.pl
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#   Description : Manage an html email queue
#
#   RUN EXAMPLE :
#       $ perl /path/to/script/mail_html.pl
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

use strict;
use warnings;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
use Getopt::Std;
use Fcntl qw(:flock);
use Log::Log4perl::Level;
use Encode;

    #--------------------------------------------------------
    # NON-BLOCKING FLOCK
    #--------------------------------------------------------
    open our $file, '<', $0 or die $!;
    flock $file, LOCK_EX|LOCK_NB or die "Unable to lock file $!";

    #--------------------------------------------------------
    # ARGUMENTS
    #--------------------------------------------------------
    my $num_args = $#ARGV + 1;
    if ($num_args == 1) { $DEBUG = $ARGV[0]; }

    #--------------------------------------------------------
    # SCRIPT SETTINGS
    #--------------------------------------------------------
    my $title    = 'HTML-EMAIL.GATEWAY';
    my $location = 'OPAS';
    my $logfile  = 'html-email.gateway.log';
    my $version  = '1.0';
    my $script   = basename($0);
    # absolute path
    my $abs_path = dirname(rel2abs($0));

    #--------------------------------------------------------
    # LOG HANDLER
    #--------------------------------------------------------
    our $log;

    #--------------------------------------------------------
    # DATE TIME VARIABLES
    #--------------------------------------------------------
    our ($year,$month,$day,$hour,$min,$sec);

    #--------------------------------------------------------
    # LOAD LIBRARIES
    #--------------------------------------------------------
    require "$abs_path/library-v2.pl";
    require "$abs_path/library-dbh-v2.pl";
    require "$abs_path/library-gmail-v2.pl";

    #--------------------------------------------------------
    # START UP
    #--------------------------------------------------------
    $log = set_logfile("$abs_path/log", $logfile);
    $log->level($DEBUG); # one of TRACE, DEBUG, INFO, WARN, ERROR, FATAL
    # $log->trace("...");  # Log a trace message
    # $log->debug("...");  # Log a debug message
    # $log->info("...");   # Log a info message
    # $log->warn("...");   # Log a warn message
    # $log->error("...");  # Log a error message
    # $log->fatal("...");  # Log a fatal message
    startup($title, $location, $version);

    #--------------------------------------------------------
    # USER SETTINGS
    #--------------------------------------------------------

    #--------------------------------------------------------
    # ERROR MAIL RECIPIENTS
    #--------------------------------------------------------
    my @recipients_mail_errors = (
        'xxxxxxxx@xxxxxxxx.it',
    );

    #--------------------------------------------------------
    # DATABASE
    #--------------------------------------------------------
    my $db_settings = {
        host => 'xxxxxxxx',
        port => 'xxxx',
        name => 'xxxxxxxx',
        user => 'xxxxxxxx',
        pass => 'xxxxxxxx',
        app  => 'mail.opas.gateway'
    };

    #--------------------------------------------------------
    #  CONNECT TO DATABASE
    #--------------------------------------------------------
    dbh_connect($db_settings) or bail_out("Cannot connect to database !");

    #--------------------------------------------------------
    # LOCK CHECK
    #--------------------------------------------------------
    $log->info("Checking locks...");
    my $sql = qq{
        SELECT
            count(*) -- n.nspname, pg_class.relname, pg_locks.mode
        FROM
            pg_locks
            LEFT OUTER JOIN pg_class ON (pg_locks.relation = pg_class.oid)
            LEFT OUTER JOIN pg_catalog.pg_namespace n ON (n.oid = pg_class.relnamespace)
        WHERE
            nspname = 'gateways'
            AND mode='AccessExclusiveLock'
            AND relname = 'html_mails'
    };
    # fetch row
    my $lock = dbh_get_single_value($sql);
    # exit if locked
    if ( $lock == 1 ) {
        $log->info("Table already locked, exiting...");
        #--------------------------------------------------------
        # DB DISCONNECT
        #--------------------------------------------------------
        dbh_disconnect();
        #--------------------------------------------------------
        # THE END
        #--------------------------------------------------------
        end();
        exit(0);
    }

    #--------------------------------------------------------
    #  BEGIN TRANSACTION + ACCESS EXCLUSIVE MODE
    #--------------------------------------------------------
    $log->debug("Acquiring lock...");
    $sql = qq{ LOCK TABLE gateways.html_mails IN ACCESS EXCLUSIVE MODE };
    dbh_execute_query($sql);

    #--------------------------------------------------------
    # DATE
    #--------------------------------------------------------
    refresh_dates();
    my $mail_time = "$year.$month.$day $hour:$min";

    #--------------------------------------------------------
    #  SELECT MAILS
    #--------------------------------------------------------
    $sql = qq{
        SELECT
            id, recipients, subject, body, logo, sent_tries
        FROM
            gateways.html_mails
        WHERE
            status IS null OR status IS false
        ORDER BY id
    };
    my $mails = dbh_get_rows_arrayref($sql);

    #--------------------------------------------------------
    # IF mails
    #--------------------------------------------------------
    $log->debug("Found ".scalar(@$mails)." mails");
    if ( scalar(@$mails) ) {

        #--------------------------------------------------------
        # SEND mails
        #--------------------------------------------------------
        $log->debug('Looping through mails...');
        foreach my $mail ( @$mails )
        {
            $log->debug("Processing html email id => $mail->{id}...");

            #--------------------------------------------------------
            #  TRIES CHECK
            #--------------------------------------------------------
            if ( $mail->{sent_tries} >= 5 ) {
                $log->debug("Sending ERROR Emails ...");
                my $mailbody = "Html email ID $mail->{id} tries == 5 !";
                send_gmail_html('text/plain', undef, undef, "$title - $location", $mailbody, @recipients_mail_errors);
                # next message
                next;
            }

            #--------------------------------------------------------
            #  MAIL CHECK
            #--------------------------------------------------------
            if ( ! $mail->{sms_sent} ) {

                #--------------------------------------------------------
                # MAIL HEADER
                #--------------------------------------------------------
                my $body = q{
                    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
                    <html xmlns="http://www.w3.org/1999/xhtml">
                    <head>
                        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                        <title>RMQA Report</title>
                        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
                    </head>
                    <body style="margin: 0; padding: 0;">
                    <div>
                };

                #--------------------------------------------------------
                # MAIL BODY FROM DATABASE
                #--------------------------------------------------------
                #$body .= decode_utf8($mail->{body})."\n";
                $body .= $mail->{body}."\n";

                #--------------------------------------------------------
                # MAIL FOOTER
                #--------------------------------------------------------
                $body .= "<p style='margin-left:0px;font-size:9pt;line-height:16px;'>OPen Air System<br/>\n";
                $body .= "https://opas.isprambiente.it/<br/>\n";
                $body .= "email inviata automaticamente @ $mail_time</p>\n";
                #$body .= "<p><img src='cid:".$mail->{logo}.".png' width='114' height='50'></p>";
                $body .= "<p><img src='cid:".$mail->{logo}.".png'></p>";
                $body .= "</div></body></html>";

                #--------------------------------------------------------
                # SEND EMAIL
                #--------------------------------------------------------
                $log->debug("Sending mail $mail->{subject}...");
                my @mail_recipients = split(';', $mail->{recipients});

                # contenttype, disposition, attachments, subject, body, recipients
                my $att = "$abs_path/img/".$mail->{logo}.".png";
                if ( send_gmail_html('text/html', 'inline', $att, $mail->{subject}, $body, @mail_recipients) ) {

                    #--------------------------------------------------------
                    # MARK AS SENT
                    #--------------------------------------------------------
                    update_mail_status($mail->{id}, $mail->{sent_tries}, 1);

                } else {

                    $log->debug("Sending ERROR Emails...");
                    my $mailbody = "Errore invio MAIL.\n\nOggetto: " . $mail->{subject};
                    send_gmail_html('text/plain', undef, undef, "$title - $location", $mailbody, @recipients_mail_errors);

                    #--------------------------------------------------------
                    #  MARK AS NOT SENT
                    #--------------------------------------------------------
                    update_mail_status($mail->{id}, $mail->{sent_tries}, 0);

                }
            }

            # delay
            sleep(1);
        }

    } # if scalar( $mails ) {

    #--------------------------------------------------------
    #  COMMIT TRANSACTION
    #--------------------------------------------------------
    $sql= qq{ COMMIT };
    dbh_execute_query($sql);

    #--------------------------------------------------------
    # DISCONNECT FROM DB
    #--------------------------------------------------------
    dbh_disconnect();

    #--------------------------------------------------------
    # THE END
    #--------------------------------------------------------
    end();
    exit(0);


#--------------------------------------------------------
# SUBS
#--------------------------------------------------------
sub update_mail_status
{
    my $id     = shift; # get the mail id
    my $tries  = shift; # get the mail tries
    my $status = shift; # get the mail status

    # log
    $log->debug("Updating mail $id ...");
    $log->debug("Status [$status], tries [$tries]");

    # increment tries
    $tries ++;
    my $stat = ($status == 1) ? "true" : "false";

    # build update query
    $sql  = "UPDATE gateways.html_mails\n";
    $sql .= "SET status = $stat,\n";
    if ($status == 1) {
       $sql .= "sent_time = current_timestamp,\n";
    } else {
        $sql .= "sent_time = null,\n";
    }
    $sql .= "sent_tries = $tries\n";
    $sql .= "WHERE id = $id";

    # execute sql
    dbh_execute_query($sql);
}

__END__
