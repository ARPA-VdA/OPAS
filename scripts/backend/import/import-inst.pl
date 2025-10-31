#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : import-inst.pl
#        Author : Ecometer s.n.c.
#          Date : 2025-03-31
#
#   Import istantaneous data from local path into postgres server
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
# arguments
#--------------------------------------------------------
my $num_args = $#ARGV + 1;
if ($num_args == 1) { $DEBUG = $ARGV[0]; }

#--------------------------------------------------------
# script settings
#--------------------------------------------------------
my $title    = 'BUILDER.INST';
my $location = 'OPAS-LD';
my $logfile  = 'builder-inst.log';
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
my $download_path = "$abs_path/import/inst"; # sub dir from which getting files

#--------------------------------------------------------
# start up
#--------------------------------------------------------
$log = set_logfile("$abs_path/log", $logfile);
$log->level($INFO); # one of TRACE, DEBUG, INFO, WARN, ERROR, FATAL
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
        s.station_file_header || '*.dat' AS fileglob,
        s.station_schema || '.' || s.station_table || '_inst' as tablename
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
    # get file list anyway to allow manual import
    #--------------------------------------------------------
    $log->info("Globbing $download_path/".$station->{fileglob});
    my @data_files = glob $download_path."/".$station->{fileglob};
    my $filecount = scalar @data_files;
    $log->info(@data_files);

    #--------------------------------------------------------
    # skip if no files found
    #--------------------------------------------------------
    $log->info("File count $filecount");
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
        # open the selected file
        #--------------------------------------------------------
        open F, $data_file;

        #--------------------------------------------------------
        # read the file content
        #--------------------------------------------------------
        $log->info("Get file content ...");
        my ($date_time, $station_alarm);
        while (<F>)
        {
            # chomp
            chomp($_);
            my $row = $_;

            #$log->info("Record: $row");
            # replace comma with dot
            $row =~ tr/,/./;

            #--------------------------------------------------------
            # reg express date time & station alarm
            #--------------------------------------------------------
            # Data ora          2022-01-26 16:33:01
            # Allarme stazione  0
            if ($row =~ m/Data ora\t(\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d)/) {
                $date_time = "'$1'";
                $log->debug("Datetime found {$date_time}");
            }

            if ($row =~ m/Allarme stazione\t((-|\+)?\d*(\.\d+)?)/) {
                $station_alarm = $1;
                $log->debug("Alarm found {$station_alarm}");
            }

            #--------------------------------------------------------
            # reg express data
            #--------------------------------------------------------
            if ($row !~ m/(P|D|A)\t(\d+)\t(\d+)\t((-|\+)?\d*(\.\d+)?)/) {
                $log->warn("Record does not match regular expression {$row}");
                next;
            }
            # P 51      0   58,7
            # D 1051    0   529
            # A 3100    0   0

            #--------------------------------------------------------
            # insert all data
            #--------------------------------------------------------
            if (!looks_like_number($2) or !looks_like_number($3) or !looks_like_number($4)){
                $log->warn("Data field is empty {$row}");
                next;
            }
            my $sql = "
                INSERT INTO $station->{tablename} (
                    measure_date_time,
                    measure_id,
                    measure_value,
                    measure_code,
                    station_code
                ) VALUES (
                    date_trunc('minute', CAST($date_time AS timestamp)), $2, $4, $3, $station_alarm
                ) ON CONFLICT DO NOTHING
            ";
            # execute it
            dbh_execute_query( $sql );

        } # while (<F>)

        # close the file
        close F;

        #--------------------------------------------------------
        # delete processed files
        #--------------------------------------------------------
        $log->debug("Deleting processed file $filename ...");
        unlink($data_file) or die "Can't unlink $data_file: $!";

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
