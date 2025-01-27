#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : tool_telegram_delete-v4.pl
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#   Description : Delete telegram messages
#
#   RUN EXAMPLE :
#       $ perl /path/to/script/tool_telegram-v4.pl
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

use Modern::Perl '2016';
use File::Spec::Functions qw(rel2abs);
use File::Basename;
use Getopt::Std;
use Fcntl qw(:flock);
use Log::Log4perl::Level;
use WWW::Telegram::BotAPI;
use JSON;
no warnings 'experimental';

    #--------------------------------------------------------
    # NON-BLOCKING FLOCK
    #--------------------------------------------------------
    open our $file, '<', $0 or die $!;
    flock $file, LOCK_EX|LOCK_NB or die "Unable to lock file $!";

    #--------------------------------------------------------
    # ARGUMENTS - LOG LEVEL
    #--------------------------------------------------------
    my $num_args = $#ARGV + 1;
    my $LOGLEVEL = $DEBUG;
    if ($num_args == 1) { $LOGLEVEL = $WARN; }

    #--------------------------------------------------------
    #  SCRIPT SETTINGS
    #--------------------------------------------------------
    my $title    = 'TELEGRAM-GATEWAY-DELETE';
    my $location = 'OPAS';
    my $logfile  = 'telegram-gateway-delete.log';
    my $version  = '4.0';
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
    require "$abs_path/library-dbh-v3.pl";

    #--------------------------------------------------------
    #  START UP
    #--------------------------------------------------------
    $log = set_logfile("$abs_path/log", $logfile);
    $log->level($LOGLEVEL); # one of TRACE, DEBUG, INFO, WARN, ERROR, FATAL
    # $log->trace("...");  # Log a trace message
    # $log->debug("...");  # Log a debug message
    # $log->info("...");   # Log a info message
    # $log->warn("...");   # Log a warn message
    # $log->error("...");  # Log a error message
    # $log->fatal("...");  # Log a fatal message
    startup($title, $location, $version);

    #--------------------------------------------------------
    # TELEGRAM SETTINGS
    #--------------------------------------------------------
    my $telegram_settings = {
        apiurl => 'https://api.telegram.org/bot%s/%s',
        token  => 'TOKEN',
    };

    #--------------------------------------------------------
    # DATABASE SETTINGS
    #--------------------------------------------------------
    $log->info("Db settings");
    my $db_settings = {
        host => 'xxxxxxxx',
        port => xxxx,
        name => 'xxxxxxxx',
        user => 'xxxxxxxx',
        pass => 'xxxxxxxx',
        app  => 'telegram.gateway',
        autocommit => 0
    };

    #--------------------------------------------------------
    #  CONNECT TO DATABASE
    #--------------------------------------------------------
    dbh_connect($db_settings) or bail_out("Cannot connect to database !");

    #--------------------------------------------------------
    #  LLOK FOR NEW MESSAGES
    #--------------------------------------------------------
    my $sql;
    #--------------------------------------------------------
    #  BEGIN TRANSACTION
    #  EXCLUSIVE MODE        -> ExclusiveLock
    #  ACCESS EXCLUSIVE MODE -> AccessExclusiveLock
    #  ROW EXCLUSIVE MODE    -> RowExclusiveLock
    #  ROW SHARE             -> RowShareLock
    #--------------------------------------------------------
    $log->debug("Begin transaction...");
    # already started
    #my $sql = qq{BEGIN;};
    #dbh_execute_query($sql);

    #--------------------------------------------------------
    #  SELECT TELEGRAMS
    #--------------------------------------------------------
    $sql = qq {
        SELECT
            id,
            chat,
            response->'result'->'message_id' AS message_id
        FROM
            gateways.telegrams
        WHERE
            tobe_deleted IS true
        ORDER BY
            id
        FOR UPDATE SKIP LOCKED
    };
    my $messages = dbh_get_rows_arrayref( $sql );

    #--------------------------------------------------------
    # IF MESSAGES
    #--------------------------------------------------------
    my $msg_counter = scalar(@$messages);
    $log->debug("Found $msg_counter messages...");
    if ( $msg_counter > 0 ) {

        #--------------------------------------------------------
        #  CONNECT API
        #--------------------------------------------------------
        $log->info("Connecting Telegram...");
        my $api = WWW::Telegram::BotAPI->new (
            token => $telegram_settings->{token},
            api_url => $telegram_settings->{apiurl},
            force_lwp => 1
        );
        # The API methods die when an error occurs.

        #--------------------------------------------------------
        # SEND MESSAGES
        #--------------------------------------------------------
        $log->info('Looping through messages...');
        foreach my $message ( @$messages )
        {
            $log->info("");
            $log->info("Processing message id => $message->{'id'}...");

            # infos
            $log->info("Message chat => [$message->{'chat'}]");

            my $res = 0;

            #--------------------------------------------------------
            #  DELETE MESSAGE
            #--------------------------------------------------------
            # https://core.telegram.org/bots/api#deletemessage

            # check if the message has previously been sent
            if ($message->{'message_id'}) {

                $log->info("Deleting message...");
                $res = eval {
                    $api->deleteMessage({
                        chat_id    => $message->{'chat'},
                        message_id => $message->{'message_id'}
                    })
                } or $log->error('Got error message: ', $api->parse_error->{msg});

                # check api result
                $log->info(Dumper($res));
                if ( $res ) {

                    #--------------------------------------------------------
                    #  MARK AS DELETED
                    #--------------------------------------------------------
                    update_telegram_status($message->{id});
                    dbh_execute_query('COMMIT');

                    #--------------------------------------------------------
                    #  STORE RESPONSE
                    #--------------------------------------------------------
                    update_telegram_response($message->{id}, encode_json($res));
                    dbh_execute_query('COMMIT');

                }else{
                    $log->warn("Error sending telegram!");
                }

            }else{
                $log->warn("Message has not been sent, set as deleted anyway!");
                update_telegram_status($message->{id});
                dbh_execute_query('COMMIT');
            }

        } # foreach my $message ( @$messages )

    } else { # if scalar( $messages ) {
        #--------------------------------------------------------
        #  ROLLBACK TRANSACTION
        #--------------------------------------------------------
        $log->debug("No messages, rolling back...");
        $sql = qq{ROLLBACK};
        dbh_execute_query($sql);
    }

    #--------------------------------------------------------
    #  DISCONNECT FROM DB
    #--------------------------------------------------------
    dbh_disconnect();

    #--------------------------------------------------------
    #  THE END
    #--------------------------------------------------------
    end();
    exit(0);


#--------------------------------------------------------
# SUBS
#--------------------------------------------------------
sub update_telegram_status
{
    my $id = shift; # get the message id

    # log
    $log->info("Updating message deleted status for id [$id]");

    # update status
    $sql  = "UPDATE gateways.telegrams\n";
    $sql .= "SET deleted = true, tobe_deleted = false, deleted_time = current_timestamp\n";
    $sql .= "WHERE id = ?";

    # execute
    dbh_execute_query_parameters($sql, $id) or $log->info("Couldn't execute sql: $sql");
}

sub update_telegram_response
{
    my $id       = shift; # get the message id
    my $response = shift; # get the response from request api

    # log
    $log->info("Updating message response for id [$id], response: $response");

    # update status
    $sql  = "UPDATE gateways.telegrams\n";
    $sql .= "SET deleted_response = ?\n";
    $sql .= "WHERE id = ?";

    # execute
    dbh_execute_query_parameters($sql, $response, $id) or $log->info("Couldn't execute sql: $sql");
}
