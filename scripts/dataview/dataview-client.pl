#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : dataview-client.pl
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#
#   DATAVIEW CLIENT
#       Perl script to extract data from database
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# enables the strict and warnings pragmas
use Modern::Perl '2019';
use File::Spec::Functions qw(rel2abs);
use File::Basename;
use Log::Log4perl::Level;
use Scalar::Util qw(looks_like_number);
use Unicode::UTF8 qw[encode_utf8 decode_utf8];
use Time::Moment;
use File::Path qw(rmtree);
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use JSON;
use utf8;

#--------------------------------------------------------
#  ARGUMENTS
#--------------------------------------------------------
my $num_args = $#ARGV + 1;

#--------------------------------------------------------
#  SCRIPT SETTINGS
#--------------------------------------------------------
my $title    = 'Dataview';
my $location = 'OPAS';
my $logfile  = 'dataview_client.log';
my $version  = '1.0';
my $script   = basename($0);
# absolute path
my $abs_path = dirname(rel2abs($0));

#--------------------------------------------------------
#  LOG HANDLER + DB
#--------------------------------------------------------
our $log;
our $db_settings;
our $export_path;
our $root_web_link;

#--------------------------------------------------------
#  DATE TIME VARIABLES
#--------------------------------------------------------
our ($year,$month,$day,$hour,$min,$sec);

#--------------------------------------------------------
#  LOAD LIBRARIES
#--------------------------------------------------------
require "$abs_path/library-v2.pl";
require "$abs_path/library-dbh-v3.pl";
require "$abs_path/settings.pl";

#--------------------------------------------------------
#  USER SETTINGS
#--------------------------------------------------------
my $zip_path = "$abs_path/zip";
createpath($zip_path);

#--------------------------------------------------------
#  START UP
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
#  GET JOB ID
#--------------------------------------------------------
my $jobid;
if ($num_args == 1) {
    $jobid = $ARGV[0];
} else {
    $log->warn("No Job Id provided");
    end();
    exit(0);
}

#--------------------------------------------------------
#  CONNECT TO DATABASE
#--------------------------------------------------------
dbh_connect($db_settings) or bail_out("Cannot connect to database !");

#--------------------------------------------------------
#  JOB QUERY
#--------------------------------------------------------
my $sql = qq{
    SELECT aggr, start_d, end_d, translate(st_ids, '[]', '{}')::integer[] AS st_ids, translate(pr_ids, '[]', '{}')::integer[] AS pr_ids
    FROM jsonb_to_record(
        (
            SELECT
                djq_args_obj
            FROM
                bobo_tools.dataview_jobs_queue
            WHERE
                djq_id = ?
        )::jsonb
    ) AS x (
        aggr    smallint,
        start_d timestamp,
        end_d   timestamp,
        st_ids  text,
        pr_ids  text
    )
};


#--------------------------------------------------------
#  GET JOB TO EXECUTE
#--------------------------------------------------------
my $job = dbh_get_row_hashref_by_parameters($sql, $jobid);
$log->info(Dumper($job));
# {
#   "aggr": "1",
#   "end_d": "2023-03-06 23:59:59",
#   "pr_ids": [
#     "7",
#     "1"
#   ],
#   "st_ids": [
#     "4000",
#     "1000"
#   ],
#   "start_d": "2023-01-06"
# }
#$log->info($job->{start_d});
#$log->info($job->{pr_ids});

#--------------------------------------------------------
#  VARIABLES
#--------------------------------------------------------
my $web_link;

#--------------------------------------------------------
#  PROCESS JOB
#--------------------------------------------------------
eval {

    # create a temp dir to store data files
    my $temp_path = tempdir('temp_XXXXX', DIR => $zip_path);
    $log->info("Temp path: $temp_path");

    # create file name headers
    $log->info("Formattazione date per creazione nome zip");
    my $tm = Time::Moment->now;
    my $head_time = $tm->strftime("{%Y%m%d_%H%M%S}");
    my $date_from_ISO = $job->{start_d};
    $date_from_ISO =~ s/ /T/;
    $date_from_ISO .= 'Z';
    $tm = Time::Moment->from_string($date_from_ISO);
    $head_time .= '-' . $tm->strftime("[%Y%m%d");
    my $date_to_ISO = $job->{end_d};
    $date_to_ISO =~ s/ /T/;
    $date_to_ISO .= 'Z';
    $tm = Time::Moment->from_string($date_to_ISO);
    $head_time .= '-' . $tm->strftime("%Y%m%d]");

    # loop through stations
    $log->info("Loop through stations...");
    for my $stid (@{$job->{st_ids}}) {

        # log
        $log->debug("stid: $stid");

        # get station info
        $sql = qq{
            SELECT station_name, station_active FROM metadata.stations WHERE station_id = ?;
        };
        my $station = dbh_get_row_hashref_by_parameters($sql, $stid);
        my $station_name = $station->{'station_name'};
        $log->debug("Stazione: $station_name");

        # loop through parameters
        $log->info("Loop through parameters");
        for my $prid (@{$job->{pr_ids}}) {

            # log
            $log->debug("prid: $prid");

            # take care of aggregation
            # 1 -> Orario (GMT)
            # 2 -> Giornaliero
            # 3 -> Mensile NOT POSSIBLE FROM CLIENT SIDE
            # 4 -> Annuale NOT POSSIBLE FROM CLIENT SIDE
            my $formatted_aggr;
            if($job->{aggr} == 1){
                $formatted_aggr = 'hh';
            }
            else{
                $formatted_aggr = 'dd';
            }

            # data extraction query
            $log->info("Extraction query");
            $sql = qq{
                SELECT * FROM clients.f_get_csv_data(?::timestamp, ?::timestamp, ?::metadata.e_aggregations, ?::integer, ?::integer);
            };

            # get data from db
            my $data = dbh_get_rows_arrayref_by_parameters($sql, $job->{start_d}, $job->{end_d}, $formatted_aggr, $stid, $prid);
            $log->info("Dump to file");
            if (!$data) {
                $log->debug("Nessun dato trovato!");
                next;
            }

            # get parameter info
            $sql = qq{
                SELECT param_name, param_unit_conv FROM metadata.parameters WHERE param_id = ?;
            };
            my $parameter = dbh_get_row_hashref_by_parameters($sql, $prid);
            my $parameter_name = $parameter->{'param_name'};
            my $parameter_unit = $parameter->{'param_unit_conv'};
            $log->debug("Parametro: $parameter_name");

            # build filename
            my $csv_filename = 'Dati_'.$stid.'-'.$parameter_name.'.csv';
            $csv_filename = encode_utf8( $csv_filename );
            my $full_csv_filename = $temp_path.'/'.$csv_filename;
            $log->info("File csv : $full_csv_filename");

            # header
            my $eco_file_header = '';
            $eco_file_header .= "Stazione: $station_name\n";
            $eco_file_header .= "Parametro: $parameter_name\n";
            $eco_file_header .= "Unità misura: $parameter_unit\n";
            $eco_file_header .= "Data inizio: ". $job->{start_d} ."\n";
            $eco_file_header .= "Data fine: ". $job->{end_d} ."\n\n";

            # open single data file
            $log->info("Open CSV data file");
            open(FH, '>', $full_csv_filename);
            # print header & pubs
            print FH $eco_file_header;
            foreach my $r (@$data) {
                # get values
                my $datetime = $r->[0];
                my $measure = looks_like_number($r->[1]) ? $r->[1] : undef;
                $measure =~ s/\./,/g if $measure;
                $measure = '' unless $measure;
                my $code = 0;

                # save to data file
                print FH $datetime .";" . $measure ."\n";
            }
            # close data file
            $log->info("Close CSV data file");
            close(FH);

        } # foreach my $prid (@{$pridArr}) {

    } # foreach my $stid (@{$stidArr}) {

    # zip all files into one
    $log->info("Zip all files into one");
    # create zip file to be downloaded
    my $zip_filename = "Dati_".$head_time.".zip";

    # get full zip filename
    my $full_zip_filename = $zip_path.'/'.$zip_filename;
    $log->info("Zip file: $full_zip_filename");

    # get new zip file object
    my $zip = Archive::Zip->new();

    # read temp dir
    opendir(DIR, $temp_path);
    #my @zipfiles = readdir(DIR);
    my @zipfiles = grep( !/^\./, readdir(DIR) );
    closedir(DIR);

    # add files to zip object
    foreach (@zipfiles) {
        $log->info("Adding file [$_] ...");
        $zip->addFile( "$temp_path/$_", $_ ); # add files
    }

    # save zip object to file
    $log->info("Save zip file to disk");
    if ($zip->writeToFileNamed($full_zip_filename) != AZ_OK) {
        $log->info("Error in archive creation!");
    }
    else {
       $log->info("Archive created successfully");
    }

    # delete temporary directory
    $log->debug("Delete temporary directory: $temp_path");
    rmtree($temp_path, {error => \my $err});
    if ($err && @$err) {
        for my $diag (@$err) {
            my ($file, $message) = %$diag;
            if ($file eq '') {
              $log->warning("General error: $message");
            }
            else {
              $log->warning("Problem unlinking $file: $message");
            }
        }
    }
    else {
        $log->debug("No error encountered");
    }

    # copy zip to web server to make it available for download
    $log->info("copy zip to web server to make it available for download");
    copy ($full_zip_filename, $export_path.'/'.$zip_filename);
    $web_link = $root_web_link.'/'.$zip_filename;
};

#--------------------------------------------------------
#  EVAL ERROR
#--------------------------------------------------------
$log->debug("Parse result");
my $json;
if ($@) {
    # log error
    $log->error($@);

    # get response
    my %rec_hash = (
        'head' => 'File dati non creato. Errori durante il recupero dei dati',
        'text' => 'Operazione non eseguita',
        'type' => 'warn'
    );
    $json = encode_json \%rec_hash;

} else {
    # get response
    my %rec_hash = (
        'head' => 'File dati creato',
        'text' => 'Accedi alla pagina di scarico dati per effettuare il download',
        'link' => $web_link,
        'type' => 'succ'
    );
    $json = encode_json \%rec_hash;
}

#--------------------------------------------------------
#  UPDATE QUERY
#--------------------------------------------------------
$sql = qq{
    UPDATE
        bobo_tools.dataview_jobs_queue
    SET
        djq_result_obj = ?,
        djq_end_ts = CURRENT_TIMESTAMP
    WHERE
        djq_id = ?
};

#--------------------------------------------------------
#  UPDATE JOB STATUS
#--------------------------------------------------------
dbh_execute_query_parameters($sql, $json, $jobid);

#--------------------------------------------------------
#  DISCONNECT FROM DB
#--------------------------------------------------------
dbh_disconnect();

#--------------------------------------------------------
#  THE END
#--------------------------------------------------------
end();
exit(0);
