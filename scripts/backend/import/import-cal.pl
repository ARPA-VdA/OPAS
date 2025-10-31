#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : import-cal.pl
#        Author : Ecometer s.n.c.
#          Date : 2025-03-31
#
#   Download files from remote stations and insert into main database
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

use strict;
use warnings;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
use File::Copy;
use File::Path qw( make_path );
use Fcntl qw(:flock);
use Log::Log4perl::Level;
use Scalar::Util qw(looks_like_number);

#--------------------------------------------------------
# non-blocking flock
#--------------------------------------------------------
open our $file, '<', $0 or die $!;
flock $file, LOCK_EX|LOCK_NB or die "Unable to lock file $!";

#--------------------------------------------------------
# arguments
#--------------------------------------------------------
my $num_args = $#ARGV + 1;
if ($num_args == 1) { $DEBUG = $ARGV[0]; }

#--------------------------------------------------------
# script settings
#--------------------------------------------------------
my $title    = 'BUILDER.CAL';
my $location = 'LD';
my $logfile  = 'builder-cal.log';
my $version  = '3.0';
my $script   = basename($0);
# absolute path
my $abs_path = dirname(rel2abs($0));

#--------------------------------------------------------
# log handler
#--------------------------------------------------------
our $log;

#--------------------------------------------------------
# date time variables
#--------------------------------------------------------
our ($year,$month,$day,$hour,$min,$sec);

#--------------------------------------------------------
# load libraries
#--------------------------------------------------------
require "$abs_path/library-utils.pl";
require "$abs_path/library-dbh.pl";
require "$abs_path/settings.pl";

#--------------------------------------------------------
# network
#--------------------------------------------------------
my $download_path = "$abs_path/import/cal"; # sub dir from which getting files
my $network_path  = "$abs_path/backup"; # sub dir for storing data

#--------------------------------------------------------
# start up
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
# create paths
#--------------------------------------------------------
createpath($download_path);
createpath($network_path);

#--------------------------------------------------------
# connect to database
#--------------------------------------------------------
dbh_connect(our $db_settings) or bail_out("Cannot connect to database !");

#--------------------------------------------------------
# build query
#--------------------------------------------------------
my $q_stations = qq{
    SELECT
        s.station_name as station,
        s.station_active as enabled,
        s.station_file_header as localpath,
        s.station_file_header || '*.dat' AS fileglob,
        s.station_file_header || '-[0-9A-F]{8}-[0-9A-F]{4}-[4][0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}(.*)?\.dat' AS regexpress,
        s.station_id as stationid
        --,*
    FROM
        metadata.stations s
        LEFT JOIN metadata.stations_info   si USING(station_id)
        LEFT JOIN metadata.stations_status ss USING(station_id)
    WHERE
        s.station_active IS TRUE  -- stazione attiva
        AND ss_suspended IS false -- non sospesa
        AND si.st_info_network_type_fk = ?   -- tipo rete
        AND st_info_roaming_type_fk = ANY (?) -- tipo stazione
    ORDER BY
        s.station_id ASC
};

#------------------------------------------------------------------------------
# retrieve station array
#------------------------------------------------------------------------------
$log->info("Get station list");
my $stations = dbh_get_rows_arrayref_by_parameters(
    $q_stations, our $network_type, our $station_types
);

#--------------------------------------------------------
# loop through all the stations
#--------------------------------------------------------
foreach my $station ( @$stations )
{

    #--------------------------------------------------------
    # check if station is enabled
    #--------------------------------------------------------
    next unless $station->{enabled} eq '1';

    #--------------------------------------------------------
    # process it
    #--------------------------------------------------------
    $log->info("");
    $log->info("Processing station: $station->{station} ...");

    #--------------------------------------------------------
    # local path
    #--------------------------------------------------------
    my $backup_path = "$network_path/".$station->{localpath}."/$year/$month";
    createpath($backup_path);

    #--------------------------------------------------------
    # get file list anyway to allow manual import
    #--------------------------------------------------------
    $log->info("Globbing $download_path/".$station->{fileglob});
    my @data_files = glob $download_path."/".$station->{fileglob};
    my $filecount = scalar @data_files;

    #--------------------------------------------------------
    # skip if no files found
    #--------------------------------------------------------
    next unless $filecount;

    #--------------------------------------------------------
    # parse all data files
    #--------------------------------------------------------
    foreach my $data_file ( @data_files )
    {
        $log->info("Processing $data_file ...");

        #--------------------------------------------------------
        # skip if no file
        #--------------------------------------------------------
        next unless -e $data_file;

        #--------------------------------------------------------
        # get details
        #--------------------------------------------------------
        my($filename, $directory, $suffix) = fileparse($data_file);

        #--------------------------------------------------------
        # file reg expression
        #
        #
        #--------------------------------------------------------
        if ($filename =~ /$station->{regexpress}/i )
        {
            # all ok
        } else {
            $log->info("Filename $filename does not match reg express");
            next;
        }

        #--------------------------------------------------------
        # get next val calib_id
        #--------------------------------------------------------
        my $sql = "SELECT nextval('clients.calibrations_id_seq'::regclass);";

        my $calib_id = dbh_get_single_value( $sql );

        #--------------------------------------------------------
        # open the selected file
        #--------------------------------------------------------
        open F, $data_file;

        #--------------------------------------------------------
        # read the file content
        #--------------------------------------------------------
        while (<F>)
        {
            # chomp
            chomp($_);

            $log->info("Record: $_");

            #--------------------------------------------------------
            # reg express data - D,2019-03-14 15:00:10,17,AUTO,ZERO,6.4
            #--------------------------------------------------------
            if (m/(D),(\d{4}-\d{2}-\d{2}\s\d{2}\:\d{2}\:\d{2}),(\d+),(AUTO|USER),(ZERO|SPAN|PURGE|UNKNOWN),((-|\+)?\d*(\.\d+)?)/) {

                # Full match  0-38    D,2019-03-14 15:00:10,17,AUTO,ZERO,6.4
                # Group 1.    0-1 D
                # Group 2.    2-21    2019-03-14 15:00:10
                # Group 3.    22-24   17
                # Group 4.    25-29   AUTO
                # Group 5.    30-34   ZERO
                # Group 6.    35-38   6.4
                # Group 8.    36-38   .4

                #--------------------------------------------------------
                # insert data
                #--------------------------------------------------------
                if (!looks_like_number($3)){
                    $log->warn("Data field is empty {$_}");
                    next;
                }

                # sql
                $sql = "
                    INSERT INTO clients.calibrations_data
                        (calibration_id, station_id, calibration_date_time, measure_id, calibration_type, calibration_step, measure_value)
                    VALUES
                        ($calib_id, $station->{stationid}, '$2', $3, '$4', '$5', $6);
                ";

                # insert
                dbh_execute_query( $sql );

                # next row
                next;
            }

            #--------------------------------------------------------
            # reg express result - R,2019-03-14 15:22:08,18,AUTO,ZERO,0,5,8,0.18
            #--------------------------------------------------------
            if (m/(R),(\d{4}-\d{2}-\d{2}\s\d{2}\:\d{2}\:\d{2}),(\d+),(AUTO|USER),(ZERO|SPAN|PURGE|UNKNOWN),((-|\+)?\d*(\.\d+)?),((-|\+)?\d*(\.\d+)?),(\d+),((-|\+)?\d*(\.\d+)?)/) {

                # Full match  0-45    R,2019-03-14 15:22:08,18,AUTO,ZERO,0,5,8,0.18
                # Group 1.    0-1 R
                # Group 2.    2-21    2019-03-14 15:22:08
                # Group 3.    22-24   18
                # Group 4.    25-29   AUTO
                # Group 5.    30-34   ZERO
                # Group 6.    35-36   0
                # Group 9.    37-38   5
                # Group 12.   39-40   8
                # Group 13.   41-45   0.18
                # Group 15.   42-45   .18

                #--------------------------------------------------------
                # insert data
                #--------------------------------------------------------
                if (!looks_like_number($3)){
                    $log->warn("Data field is empty {$_}");
                    next;
                }

                # sql
                $sql = "
                    INSERT INTO clients.calibrations_result
                        (calibration_id, station_id, calibration_date_time, measure_id, calibration_type, calibration_step, reference_value, defect_value, result_code, result_value)
                    VALUES
                        ($calib_id, $station->{stationid}, '$2', $3, '$4', '$5', $6, $9, $12, $13);
                ";

                # insert
                dbh_execute_query( $sql );

                # next row
                next;
            }

            $log->warn("Record does not match regular expression {$_}");

            } # while (<F>)

        # close the file
        close F;

        #--------------------------------------------------------
        # move processed files
        #--------------------------------------------------------
        $log->info("Moving processed file $data_file ...");
        my $dest_file = "$backup_path/$filename";
        move($data_file, $dest_file) or die $log->info("Move $data_file -> $dest_file failed: $!");

    } # foreach my $data_file ( @data_files )

} # loop through all the stations

#--------------------------------------------------------
# disconnect from db
#--------------------------------------------------------
dbh_disconnect();

#--------------------------------------------------------
# the end
#--------------------------------------------------------
end();
exit(0);
