#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : library-utils.pl
#        Author : Ecometer s.n.c.
#          Date : 2025-03-31
#
#   Library containg most frequently used code
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

use Modern::Perl;
use Date::Calc qw(Today_and_Now Add_Delta_DHMS Delta_Days);
use Time::HiRes qw( usleep gettimeofday tv_interval );
use File::Spec::Functions qw(rel2abs);
use File::Basename;
use File::Path qw(make_path);
use Log::Log4perl qw(:easy);
# log
our $log;
# date time variables
our ($year,$month,$day,$hour,$min,$sec);
# time execution
my $t0;
# debug - if not set skip header and footer
my $PRINT_HEAD_FOOT = 1;
return(1);

# set_logfile($path, $file) - set the local log filename
sub set_logfile
{
    my $path = shift;
    my $file = shift;

    # create path if does not exists
    createpath($path);

    # http://search.cpan.org/~mschilli/Log-Log4perl-1.46/lib/Log/Log4perl.pm
    # http://ddiguru.com/blog/126-eight-loglog4perl-recipes

    # %c Category of the logging event.
    # %C Fully qualified package (or class) name of the caller
    # %d Current date in yyyy/MM/dd hh:mm:ss format
    # %F File where the logging event occurred
    # %H Hostname (if Sys::Hostname is available)
    # %l Fully qualified name of the calling method followed by the
    #    callers source the file name and line number between
    #    parentheses.
    # %L Line number within the file where the log statement was issued
    # %m The message to be logged
    # %m{chomp} The message to be logged, stripped off a trailing newline
    # %M Method or function where the logging request was issued
    # %n Newline (OS-independent)
    # %p Priority of the logging event
    # %P pid of the current process
    # %r Number of milliseconds elapsed from program start to logging
    #    event
    # %R Number of milliseconds elapsed from last logging event to
    #    current logging event
    # %T A stack trace of functions called
    # %x The topmost NDC (see below)
    # %X{key} The entry 'key' of the MDC (see below)
    # %% A literal percent (%) sign

    # Initialize Logger - 10485760 10MB
    my $log_conf = qq(
        log4perl.rootLogger              = DEBUG, LOG1, SCREEN
        log4perl.appender.LOG1           = Log::Dispatch::FileRotate
        log4perl.appender.LOG1.filename  = $path/$file
        log4perl.appender.LOG1.mode      = append
        log4perl.appender.LOG1.autoflush = 1
        log4perl.appender.LOG1.max       = 15
        log4perl.appender.LOG1.DatePattern = yyyy-MM-dd
        log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.LOG1.layout.ConversionPattern = %d %m %n
        log4perl.appender.SCREEN         = Log::Log4perl::Appender::Screen
        log4perl.appender.SCREEN.stderr  = 0
        log4perl.appender.Screen.utf8    = 1
        log4perl.appender.SCREEN.layout  = Log::Log4perl::Layout::PatternLayout::Multiline
        log4perl.appender.SCREEN.layout.ConversionPattern = %d{HH:mm} %p %m %n
    );
    #log4perl.appender.LOG1.size      = 10485760
    #log4perl.appender.LOG1.layout.ConversionPattern = %d %R %F{1} %L> %m %n
    #log4perl.appender.LOG1.layout.ConversionPattern = %d %R %F{1} %L> %m %n
    #log4perl.appender.LOG1.layout.ConversionPattern = %d %p %m %n
    #log4perl.appender.SCREEN.layout  = Log::Log4perl::Layout::SimpleLayout
    Log::Log4perl::init(\$log_conf);
    return Log::Log4perl->get_logger();
}

# startup($title, $location, $version) - start of main program
sub startup
{
    my $title    = shift;
    my $location = shift;
    my $version  = shift;

    #--------------------------------------------------------
    #  START UP
    #--------------------------------------------------------
    $t0 = [gettimeofday];
    refresh_dates();
    system(($^O eq 'MSWin32') ? 'cls' : 'clear');

    #For debug
    if ( $PRINT_HEAD_FOOT == 0 ) {
        $log->info("-- Running ...");
        return;
    }
    $log->info("--------------------------------------------------------");
    $log->info("-- xxxxxxxx |  Author: xxxxxxxx  |  xxxx-$year ");
    $log->info("--");
    $log->info("-- TITLE    : $title");
    $log->info("-- LOCATION : $location");
    $log->info("-- VERSION  : $version");
    $log->info("--------------------------------------------------------");
}

# end() - end of main program
sub end
{
    #For debug
    if ( $PRINT_HEAD_FOOT == 0 ) { return; }
    #--------------------------------------------------------
    #  THE END
    #--------------------------------------------------------
    my $t1 = [gettimeofday];
    my $t0_t1 = tv_interval $t0, $t1;
    my $elapsed = tv_interval ($t0, [gettimeofday]);
    #$elapsed = tv_interval ($t0); # equivalent code
    $log->info("");
    $log->info("--------------------------------------------------------");
    $log->info("-- End of program.");
    $log->info("-- Done in $elapsed secs.");
    $log->info("--------------------------------------------------------\n\n");
    # sleep a while..
    #usleep(100_000);
}

# getpath() - get the path of a file
sub getpath
{
    my $file = shift;
    return dirname(rel2abs($file));
}

# createpath() - create the path if does not exists
sub createpath
{
    my $path = shift;

    unless (-e $path) {
        make_path $path or die "Failed to create path: $path";
    }
}

# get_dir_listing( root_path ) -  return array of directories
sub get_dir_listing {
    my $path = shift;
    #$log->info("Opening dir $path ...", 2);
    opendir(DIR, $path) or die "cant find $path: $!";
    my @folders;
    while (defined(my $file = readdir(DIR))) {
        next if $file =~ /^\.\.?$/;
        if (-d "$path/$file"){
            #push @folders,"$path/$file";
            push @folders, $file;
        }
    }
    closedir(DIR);
    return @folders;
}

# lpad() subroutine left pad routine
sub lpad {
    return($_[1] x ($_[2] - length($_[0])) . $_[0]);
}

# lpad2() subroutine support for $log->info()
sub lpad2 {
   #return($_[1] x ($_[2] - length($_[0])) . $_[0]);
   return(($_[1] x $_[2]) . $_[0]);
}

# dotize() subroutine a longer string - dotize(16, $mystring)
sub dotize {
    my($width, $string) = @_;

    if (length($string) > $width) {
        return(substr($string, 0, $width - 3) . "...");
    }
    else {
        return($string);
    }
}

# refresh_dates( $gmt = 0) subroutine  -  refresh the date and time
sub refresh_dates
{
    my $gmt = shift || 0;
    # get the date and time
    ($year,$month,$day, $hour,$min,$sec) = Today_and_Now( $gmt );
    # correct the date format
    $month = sprintf "%02d", $month;
    $day   = sprintf "%02d", $day;
    $hour  = sprintf "%02d", $hour;
    $min   = sprintf "%02d", $min;
    $sec   = sprintf "%02d", $sec;
}

# get_hours() - GET THE TIME
sub get_hours
{
    refresh_dates();
    return "$hour:$min:$sec";
}

# get_time() - GET THE TIME
sub get_time
{
    refresh_dates();
    return "$year-$month-$day $hour:$min:$sec";
}

# get_time_formatted() - GET THE TIME IN FORAMATTED WAY
sub get_time_formatted
{
    refresh_dates();
    if ( $min < 30 ) { $min = "00"; } else { $min = "30"; }
    return "$year-$month-$day $hour:$min:00";
}

# get_gmt_time_formatted() - GET THE TIME IN gmt FORMAT
sub get_gmt_time_formatted
{
    my $gmt = 1;
    my ($year,$month,$day, $hour,$min,$sec) = Today_and_Now( $gmt );
    # correct the date format
    $month = sprintf "%02d", $month;
    $day   = sprintf "%02d", $day;
    $hour  = sprintf "%02d", $hour;
    $min   = sprintf "%02d", $min;
    $sec   = sprintf "%02d", $sec;
    #my $theGMTime = "$year-$month-$day $hour:$min:$sec";
    if ( $min < 30 ) { $min = "00"; } else { $min = "30"; }
    #print "time = $year-$month-$day $hour:$min:$sec\n";
    return "$year-$month-$day $hour:$min:00";
}

# time_add_days() subroutine
sub time_add_days
{
    my $time = shift;
    my $days = shift;
    #print "time = $time, days = $days\n";
    $time  =~m/^(\d+)-(\d+)-(\d+)\s(\d+):(\d+):(\d+)/;
    $year  = $1;
    $month = $2;
    $day   = $3;
    $hour  = $4;
    $min   = $5;
    $sec   = $6;
    # add - remove
    ($year,$month,$day, $hour,$min,$sec) =
    Add_Delta_DHMS($year,$month,$day, $hour,$min,$sec,$days,0,0,0);
    # format
    $month = sprintf "%02d", $month;
    $day   = sprintf "%02d", $day;
    $hour  = sprintf "%02d", $hour;
    $min   = sprintf "%02d", $min;
    $sec   = sprintf "%02d", $sec;
    #print "time = $year-$month-$day $hour:$min:$sec\n";
    return "$year-$month-$day $hour:$min:$sec";
}

# time_add_hours() subroutine
sub time_add_hours
{
    my $time  = shift;
    my $hours = shift;
    #print "time = $time, hours = $hours\n";
    $time  =~m/^(\d+)-(\d+)-(\d+)\s(\d+):(\d+):(\d+)/;
    $year  = $1;
    $month = $2;
    $day   = $3;
    $hour  = $4;
    $min   = $5;
    $sec   = $6;
    # add - remove
    ($year,$month,$day, $hour,$min,$sec) =
    Add_Delta_DHMS($year,$month,$day, $hour,$min,$sec,0,$hours,0,0);
    # format
    $month = sprintf "%02d", $month;
    $day   = sprintf "%02d", $day;
    $hour  = sprintf "%02d", $hour;
    $min   = sprintf "%02d", $min;
    $sec   = sprintf "%02d", $sec;
    #print "time = $year-$month-$day $hour:$min:$sec\n";
    return "$year-$month-$day $hour:$min:$sec";
}

# time_add_minutes() subroutine
sub time_add_minutes
{
    my $time    = shift;
    my $minutes = shift;
    #print "time = $time, hours = $hours\n";
    $time  =~m/^(\d+)-(\d+)-(\d+)\s(\d+):(\d+):(\d+)/;
    $year  = $1;
    $month = $2;
    $day   = $3;
    $hour  = $4;
    $min   = $5;
    $sec   = $6;
    # add - remove
    ($year,$month,$day, $hour,$min,$sec) =
    Add_Delta_DHMS($year,$month,$day, $hour,$min,$sec,0,0,$minutes,0);
    # format
    $month = sprintf "%02d", $month;
    $day   = sprintf "%02d", $day;
    $hour  = sprintf "%02d", $hour;
    $min   = sprintf "%02d", $min;
    $sec   = sprintf "%02d", $sec;
    #print "time = $year-$month-$day $hour:$min:$sec\n";
    return "$year-$month-$day $hour:$min:$sec";
}

# date_add_days() subroutine
sub date_add_days
{
    my $date = shift;
    my $days = shift;
    #print "date = $date, days = $days\n";
    $date  =~m/^(\d+)-(\d+)-(\d+)/;
    $year  = $1;
    $month = $2;
    $day   = $3;
    $hour  = 0;
    $min   = 0;
    $sec   = 0;
    # add - remove
    ($year,$month,$day, $hour,$min,$sec) =
    Add_Delta_DHMS($year,$month,$day, $hour,$min,$sec,$days,0,0,0);
    # format
    $month = sprintf "%02d", $month;
    $day   = sprintf "%02d", $day;
    #print "time = $year-$month-$day\n";
    return "$year-$month-$day";
}

# date_diff() subroutine
sub date_diff
{
    my $date1 = shift;
    my $date2 = shift;

    $date1  =~m/^(\d+)-(\d+)-(\d+)/;
    my $year1  = $1;
    my $month1 = $2;
    my $day1   = $3;

    $date2  =~m/^(\d+)-(\d+)-(\d+)/;
    my $year2  = $1;
    my $month2 = $2;
    my $day2   = $3;

    return Delta_Days($year1,$month1,$day1,
        $year2,$month2,$day2);
}

# date_truncate() subroutine
# truncates a full date and returns only the date
sub date_truncate {
    my $datetime = shift;
    #print "datetime = [$datetime]\n";
    my ($year,$month,$day,$hour,$min,$sec);
    $datetime  =~m/^(\d+)-(\d+)-(\d+)\s\d+:\d+:\d+/;
    $year  = $1;
    $month = $2;
    $day   = $3;
    return "$year-$month-$day";
}

# is_valid_date() subroutine
sub is_valid_date {
    my $input = shift;
    if ($input =~ m!^((?:19|20)\d\d)[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])$!) {
        # At this point, $1 holds the year, $2 the month and $3 the day of the date entered
        if ($3 == 31 and ($2 == 4 or $2 == 6 or $2 == 9 or $2 == 11)) {
            return 0; # 31st of a month with 30 days
        } elsif ($3 >= 30 and $2 == 2) {
            return 0; # February 30th or 31st
        } elsif ($2 == 2 and $3 == 29 and not ($1 % 4 == 0 and ($1 % 100 != 0 or $1 % 400 == 0))) {
            return 0; # February 29th outside a leap year
        } else {
            return 1; # Valid date
        }
    } else {
        return 0; # Not a date
    }
}

# is_numeric() subroutine
sub is_numeric
{
    # http://rosettacode.org/wiki/Determine_if_a_string_is_numeric
    my $number = shift;
    if ( $number =~ m/^\d+\z/)                                              { return 1; } # is a whole number
    if ( $number =~ m/^-?\d+\z/)                                            { return 1; } # is an integer
    if ( $number =~ m/^[+-]?\d+\z/)                                         { return 1; } # is a +/- integer
    if ( $number =~ m/^-?\d+\.?\d*\z/)                                      { return 1; } # is a real number
    if ( $number =~ m/^-?(?:\d+(?:\.\d*)?&\.\d+)\z/)                        { return 1; } # is a decimal number
    if ( $number =~ m/^([+-]?)(?=\d&\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?\z/)   { return 1; } # a C float

    # not a number
    return 0;
}


# bail_out() subroutine  -  print error code and string, then exit
sub bail_out
{
    my ($message) = shift;
    $log->error("$message");
    die;
}
