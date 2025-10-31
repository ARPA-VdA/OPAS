#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : import-data.pl
#        Author : Ecometer s.n.c.
#          Date : 2025-03-31
#
#   Import remote data files into postgres database
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

use strict;
use warnings;
use Modern::Perl;
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
# script settings
#--------------------------------------------------------
my $title    = 'BUILDER.DATA';
my $location = 'OPAS-LD';
my $logfile  = 'builder-data.log';
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
# user settings
#--------------------------------------------------------
my $download_path = "$abs_path/import/data"; # sub dir from which getting files
my $network_path  = "$abs_path/backup"; # sub dir for storing data

#--------------------------------------------------------
# start up
#--------------------------------------------------------
$log = set_logfile("$abs_path/log", $logfile);
$log->level($TRACE); # one of TRACE, DEBUG, INFO, WARN, ERROR, FATAL
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
# Cargar la configuración desde db_settings.pl
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
        s.station_file_header || '-\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2}\\.dat' AS regexpress1,
        s.station_file_header || '-\\d{4}-\\d{2}-\\d{2}\\.dat' AS regexpress2,
        s.station_schema || '.' || s.station_table as tablename
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
    # process it
    #--------------------------------------------------------
    $log->info("");
    $log->info("Processing station: ", $station->{'station'});

    #--------------------------------------------------------
    # local path
    #--------------------------------------------------------
    my $backup_path = "$network_path/".$station->{'localpath'}."/$year/$month";
    createpath($backup_path);

    #--------------------------------------------------------
    # get file list anyway to allow manual import
    #--------------------------------------------------------
    $log->info("Globbing $download_path/".$station->{'fileglob'});
    my @data_files = glob $download_path."/".$station->{'fileglob'};
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
        $log->info("Processing $data_file");

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
        #--------------------------------------------------------
        if ($filename =~ /$station->{regexpress1}/ ||
            $filename =~ /$station->{regexpress2}/)
        {
            # all ok, keep going
        } else {
            $log->warn("Filename $filename does not match reg expression");
            next;
        }

        #--------------------------------------------------------
        # open the selected file
        #--------------------------------------------------------
        open F, $data_file;

        #--------------------------------------------------------
        # read the file content
        #--------------------------------------------------------
        while (my $rec = <F>)
        {
            # chomp
            chomp($rec);
            $log->trace("Record: $rec");

            #--------------------------------------------------------
            # record reg expression check
            #--------------------------------------------------------
            if ($rec !~ m/'\d{4}-\d{2}-\d{2}\s\d{2}\:\d{2}\:\d{2}',\d+,(((-|\+)?\d*(.\d+)?)|NULL),\d+,\d+,\d+,(((-|\+)?\d*(.\d+)?)|NULL),'\d{2}\:\d{2}\:\d{2}\',(((-|\+)?\d*(.\d+)?)|NULL),'\d{2}\:\d{2}\:\d{2}\',((-|\+)?\d*(.\d+)?)/) {
                $log->warn("Record does not match regular expression {$_}");
                # continue next record
                next;
            }

            #--------------------------------------------------------
            # insert all data
            #--------------------------------------------------------
            my $value = $1;
            # null sanity check
            if ($value eq 'NULL'){
                $log->warn("Data field is NULL, replacing value with 0");
                $rec =~ s/,NULL,/,0,/; # replace only first occurency
                $value = 0;
            }
            # validity sanity check
            if (!looks_like_number($value)){
                $log->warn("Data field is empty {$rec}");
                next;
            }
            # build sql
            my $sql = "
                INSERT INTO $station->{tablename} (
                    measure_date_time,
                    measure_id,
                    measure_value,
                    measure_code,
                    station_code,
                    measure_perc,
                    measure_min,
                    measure_min_time,
                    measure_max,
                    measure_max_time,
                    measure_std_dev
                ) VALUES (
                    $rec
                ) ON CONFLICT DO NOTHING
            ";
            # execute it
            dbh_execute_query( $sql );

          } # while (<F>)

        # close the file
        close F;

        #--------------------------------------------------------
        # move processed files
        #--------------------------------------------------------
        $log->info("Moving processed file $data_file");
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
