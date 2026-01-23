package Bobo::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin';
use Unicode::UTF8 qw[decode_utf8 encode_utf8];


use strict;
use warnings;
use feature qw{ switch };
use Date::Calc qw(Now Today Today_and_Now Day_of_Year Add_Delta_DHMS Delta_Days Delta_DHMS Add_Delta_Days This_Year);
use DateTime;
use DateTime::TimeZone;
use DateTime::Format::Strptime;
use Data::Dumper;
use Email::Send::SMTP::Gmail;
use File::Temp ();
use File::Path qw(make_path);
use File::Basename;
use GD::Thumbnail;
use WWW::Mechanize;

use Net::Address::IP::Local;
use LWP::UserAgent;
use JSON;

#use Image::Magick::Thumbnail::Fixed;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
#
# subs
#

# helperDumper
# helperDumperPostData
# helperGetBoolean
# helperGetBulletinId
# helperGetFullDate
# helperGetLocaleFullDate
# helperGetFormattedFulldate
# helperGetMonthName
# helperEscapeParam
# helperGetFileVersion
# helperSendEmailHTML
# helperSendEmailPEC
# helperSendDirectEmailAttachment
# helperCreatePath
# helperFileUploadGetFileId
# helperImageCreateThumbanail
# helperInsertLog
# helperInsertUserLog
# helperGetRemoteFileStatus
# helperGetFileStatus
# helperGetFormattedFileDate
# helperGetFileIsLate

# helperGetCSVHeader
# helperGetCSVData

sub register {
    my ($self, $app, $config) = @_;

    # log debug message
    $app->log->debug('Bobo::Plugin::Helpers :: register()');

    # -----------------------------------------------------------------------------
    # -- db version
    # -----------------------------------------------------------------------------
    # dump structure
    # $app->helper(helperDbVersion =>sub
    # {
    #     my $self = shift;

    #     # SELECT version();
    #     # SHOW server_version;
    #     # SHOW server_version_num;
    #     my $sql = "SHOW server_version_num";
    #     return $self->app->database->database_query_value($sql);
    # });

    # -----------------------------------------------------------------------------
    # -- dumper
    # -----------------------------------------------------------------------------
    # dump structure
    $app->helper(helperDumper =>sub
    {
        my $self = shift;
        my $var  = shift;
        # http://perldoc.perl.org/Data/Dumper.html
        local $Data::Dumper::Terse    = 1; # no '$VAR1 = '
        local $Data::Dumper::Useqq    = 1; # double quoted strings
        local $Data::Dumper::Sortkeys = 1; # sort
        $self->app->log->debug(Dumper($var));
        #return Dumper($var);
    });

    # post file dumper
    $app->helper(helperDumperPostData =>sub
    {
        my $self   = shift;
        my $dir    = shift;
        my $header = shift;
        my $params = shift;
        $self->app->log->debug("helperDumperPostData");

        my ($year,$month,$day, $hour,$min,$sec) = Today_and_Now( 1 );
        # correct the date format
        $month = sprintf "%02d", $month;
        $day   = sprintf "%02d", $day;
        $hour  = sprintf "%02d", $hour;
        $min   = sprintf "%02d", $min;
        $sec   = sprintf "%02d", $sec;
        my $head_time = "{$year-$month-$day-$hour-$min-$sec}";

        # http://mojolicio.us/perldoc/Mojo/Home
        my $path = $self->app->home->rel_file('public/log/'.$year.'/'.$month.'/'.$dir);
        # if dir doesn't exist, create it
        if (!(-d $path)) {
            $path->make_path;
        }

        # my $file = $self->app->home->rel_file('dumps/Dumper.txt');
        my $file = File::Temp->new( TEMPLATE => $header.'.'.$head_time.'.XXXXXXXXXX',
            UNLINK => 0, DIR => $path, SUFFIX => '.dat');

        $self->app->log->debug("file : $file");

        open my $fh, '>', $file or $self->app->log->warn("Can't write '$file': $!");
        # http://perldoc.perl.org/Data/Dumper.html
        local $Data::Dumper::Terse    = 1; # no '$VAR1 = '
        local $Data::Dumper::Useqq    = 1; # double quoted strings
        local $Data::Dumper::Sortkeys = 1; # sort
        print $fh Dumper $params->to_hash;
        close $fh or $self->app->log->warn("Can't close '$file': $!");

        # chmod for linux
        if ( $^O eq 'linux' ) {
            $self->app->log->debug("helperDumperPostData - chmod 0744 : $file");
            chmod 0744, $file or die "Couldn't chmod $file: $!";
        }

        # return the filename
        return $file;
    });

    # post alims file
    $app->helper(helperDumperPostDataAlims =>sub
    {
        my $self   = shift;
        my $header = shift;
        my $params = shift;
        $self->app->log->debug("helperDumperPostDataAlims");

        my ($year,$month,$day, $hour,$min,$sec) = Today_and_Now( 1 );
        # correct the date format
        $month = sprintf "%02d", $month;
        $day   = sprintf "%02d", $day;
        $hour  = sprintf "%02d", $hour;
        $min   = sprintf "%02d", $min;
        $sec   = sprintf "%02d", $sec;
        my $head_time = "{$year-$month-$day-$hour-$min-$sec}";

        # http://mojolicio.us/perldoc/Mojo/Home
        my $path = $self->app->home->rel_file("public/uploads/alims/$year/$month");
        $self->helperCreatePath( $path );

        #my $file = $self->app->home->rel_file('dumps/Dumper.txt');
        my $file = File::Temp->new( TEMPLATE => $header.'.'.$head_time.'.XXXXXXXXXX',
            UNLINK => 0, DIR => $path, SUFFIX => '.json');

        $self->app->log->debug("file : $file");

        open my $fh, '>', $file or $self->app->log->warn("Can't write '$file': $!");
        # http://perldoc.perl.org/Data/Dumper.html
        local $Data::Dumper::Terse    = 1; # no '$VAR1 = '
        local $Data::Dumper::Useqq    = 1; # double quoted strings
        local $Data::Dumper::Sortkeys = 1; # sort
        print $fh Dumper $params;
        close $fh or $self->app->log->warn("Can't close '$file': $!");

        # chmod for linux
        if ( $^O eq 'linux' ) {
            $self->app->log->debug("helperDumperPostDataAlims - chmod 0744 : $file");
            chmod 0744, $file or die "Couldn't chmod $file: $!";
        }

        # return the filename
        return $file;
    });

    # check if a field exist, if defined return true also false
    $app->helper(helperGetBoolean =>
    sub
    {
        my $self   = shift;
        my $params = shift;
        my $field  = shift;

        # $self->app->log->debug("helperGetBoolean");

        if (defined $params->{$field}) {
            return 1;
        }
        else {
            return 0;
        }
    });

    $app->helper(helperGetBulletinId =>
    sub
    {
        my $self = shift;
        my ($year,$month,$day) = Today( );
        my $doy = Day_of_Year($year,$month,$day);

        return ( 1000 * $year ) + $doy;
    });

    $app->helper(helperGetFullDate =>
    sub
    {
        my $self   = shift;
        my ($year,$month,$day,$hour,$min,$sec) = Today_and_Now();
        # correct the date format
        $month = sprintf "%02d", $month;
        $day   = sprintf "%02d", $day;
        $hour  = sprintf "%02d", $hour;
        $min   = sprintf "%02d", $min;
        $sec   = sprintf "%02d", $sec;
        return "$year/$month/$day $hour:$min:$sec";
    });

    $app->helper(helperGetLocaleFullDate =>
    sub
    {
        my $self     = shift;

        my $local_tz = DateTime::TimeZone->new( name=> 'Europe/Rome' );
        my $now = DateTime->now( time_zone => $local_tz );

        $now =~ tr/-/\//;
        $now =~ tr/T/ /;

        return $now;
    });

    $app->helper(helperGetFormattedFulldate =>
    sub
    {
        my $self     = shift;
        my $fulldate = shift;
        # correct the date format
        if (!defined $fulldate || $fulldate eq "") {
            return undef;
        }
        else {
            # DD/MM/YYYY
            if ( $fulldate =~ /^(\d\d)\/(\d\d)\/(\d\d\d\d)$/) {
                $fulldate = "$3/$2/$1";
            } # DD/MM/YYYY HH:mm
            elsif ($fulldate =~ /^(\d\d)\/(\d\d)\/(\d\d\d\d)\s(\d\d):(\d\d)$/) {
                $fulldate = "$3/$2/$1 $4:$5";
            }

            return $fulldate;
        }
    });

    $app->helper(helperGetMonthName =>
    sub
    {
        my $self  = shift;
        my $month = shift;

        my $month_name;
        # correct the date format
        if ($month eq "01") { $month_name = "gennaio"  ; }
        elsif ($month eq "02") { $month_name = "febbraio" ; }
        elsif ($month eq "03") { $month_name = "marzo"    ; }
        elsif ($month eq "04") { $month_name = "aprile"   ; }
        elsif ($month eq "05") { $month_name = "maggio"   ; }
        elsif ($month eq "06") { $month_name = "giugno"   ; }
        elsif ($month eq "07") { $month_name = "luglio"   ; }
        elsif ($month eq "08") { $month_name = "agosto"   ; }
        elsif ($month eq "09") { $month_name = "settembre"; }
        elsif ($month eq "10") { $month_name = "ottobre"  ; }
        elsif ($month eq "11") { $month_name = "novembre" ; }
        elsif ($month eq "12") { $month_name = "dicembre" ; }
        else {$month_name = undef;}

        return $month_name;
    });

    $app->helper(helperEscapeParam =>
    sub
    {
        my $self  = shift;
        my $param = shift;

        # $self->app->log->debug("helperEscapeParam");

        if (defined ($param)) { # defined
            if ($param eq "") { # != from ""
                return undef;
            }
            else {
                $param =~ s/^\s+|\s+$//g;
                return $param; # ok
            }
        }
        else {
            return undef; # not defined
        }
    });

    # # -----------------------------------------------------------------------------
    # # -- versioning
    # # -----------------------------------------------------------------------------
    $app->helper(helperGetFileVersion =>
    sub
    {
        my $self = shift;
        my $file = shift;

        my $path = $self->app->home->rel_file('public/'.$file);
        my $epoch_timestamp = (stat($path))[9];
        # /js/app.js?v=number
        unless ( $epoch_timestamp ) {
            $app->log->debug('helperGetFileVersion: '.$path);
            return;
        }
        return $file."?v=".($epoch_timestamp || '');
    });


    # -----------------------------------------------------------------------------
    # -- send email via mail - gateway
    # -----------------------------------------------------------------------------
    $app->helper(helperSendEmailHTML =>
    sub {
        my $self       = shift;
        my $sender_app = shift;
        my $subject    = shift;
        my $body       = shift;
        my $logo       = shift;
        my @recipients = @_;

        $self->app->log->debug("helperSendEmailHTML");
        $self->app->log->debug("title: BOBO ".$sender_app);
        $self->app->log->debug("subject: $subject");
        # $self->app->log->debug("body: $body");
        $self->app->log->debug("recipients: @recipients");

        $sender_app = 'BOBO '. $sender_app;

        # my @recipients_list;
        # foreach my $recipient ( @recipients ) {
        #     $self->app->log->debug("Sending Mail to : $recipient");
        #     push( @recipients_list, $recipient );
        # }

        # sql
        my $sql = "INSERT INTO gateways.html_mails(app, recipients, subject, body, logo) VALUES (?,?,?,?,?);";

        # execute
        eval {
            $self->pg->db->query($sql, $sender_app, join(";", @recipients ), $subject, encode_utf8($body), $logo);
        };

         # error check
        if ($@) {
           $self->app->log->warn("Error: ".$@);
           return 0;
        }
        else {
           return 1;
        }
    });

    $app->helper(helperNewUserEmailHTML =>
    sub {
        my $self       = shift;
        my $sender_app = shift;
        my $subject    = shift;
        my $body       = shift;
        my $logo       = shift;
        my $send       = shift;
        my @recipients = @_;

        $self->app->log->debug("helperNewUserEmailHTML");
        $self->app->log->debug("title: BOBO ".$sender_app);
        $self->app->log->debug("subject: $subject");
        $self->app->log->debug("body: $body");
        $self->app->log->debug("recipients: @recipients");
        
        $self->app->log->debug("send: $send");

        $sender_app = 'OPAS '. $sender_app;

        # sql
        my $sql = "INSERT INTO gateways.html_mails(app, recipients, subject, body, logo, status) VALUES (?,?,?,?,?,?);";

        # execute
        eval {
            $self->pg->db->query($sql, $sender_app, join(";", @recipients ), $subject, encode_utf8($body), $logo, ($send ? undef : 1));
        };

         # error check
        if ($@) {
           $self->app->log->warn("Error: ".$@);
           return 0;
        }
        else {
           return 1;
        }
    });

    # -----------------------------------------------------------------------------
    # -- send flat email with attachment
    # -- http://mojolicio.us/perldoc/Mojolicious/Guides/FAQ#What_does_Worker_31842_has_no_heartbeat_restarting_mean
    # -----------------------------------------------------------------------------
    $app->helper( helperSendDirectEmailAttachment => sub
    {
        my $self            = shift;
        my $recipients      = shift;
        my $cc_recipients   = shift;
        my $subject         = shift;
        my $body            = shift;
        my $attachments     = shift;

        # log
        $self->app->log->debug("helperSendDirectEmailAttachment - subject: $subject");

        # encoding
        $subject = encode_utf8( $subject );
        $body    = encode_utf8( $body );

        # config
        my $mailcnf = $self->config->{sender_mail};
        my $mail_from = $mailcnf->{mail_from};
        my $smtp_user = $mailcnf->{smtp_user};
        my $smtp_pass = $mailcnf->{smtp_pass};
        # $mailcnf->{mail_from_header}

        $self->app->log->debug("mail_from: $mail_from");
        $self->app->log->debug("smtp_user: $smtp_user");
        $self->app->log->debug("smtp_pass: $smtp_pass");

        # try
        eval{

            # log
            $self->app->log->debug("Sending from: $mail_from => to:" .
                join(",", @{$recipients}).", subject: $subject, body: $body ...");

            # log
            $self->app->log->debug("Connecting to mail server...");
            # new mail object
            my $mail = Email::Send::SMTP::Gmail->new(
                -smtp   =>  'smtp.gmail.com',
                -login  =>  $smtp_user,
                -pass   =>  $smtp_pass,
                -layer  =>  'ssl',
                -port   =>  465,
                -timeout => 240,
                -debug  =>  0
            );

            # log
            # if (defined $fullfilename)
            $self->app->log->debug("Sending mail with attachment ". join(",", @{$attachments}));

            # send mail
            $mail->send(
                -from        =>  $mail_from,
                -to          =>  join(",", @$recipients),
                -cc          =>  join(",", @$cc_recipients),
                -subject     =>  $subject,
                -body        =>  $body,
                -attachments =>  join(",", @$attachments),
                -verbose     =>  0,
                -contenttype => 'text/html', # text/plain (default), text/html
                -disposition => 'inline'     # set "inline" in sending embeeded attachments
            );

            # end
            $mail->bye;

        }; # eval

        # log
        if ($@) {
            $self->app->log->warn("Mail warning: $@");
            return 0;
        }
        else {
            $self->app->log->debug("Mail sent ok");
            return 1;
        }
    });

    # -----------------------------------------------------------------------------
    # -- path
    # -----------------------------------------------------------------------------
    $app->helper(helperCreatePath =>
    sub {
        my $self = shift;
        my $dir  = shift;

        $self->app->log->debug("helperCreatePath - dir: $dir");

        $dir =~ s/ /\\ /g;
        unless (-e $dir)
        {
            my $dir_test = make_path($dir);
            if ($dir_test) {
                # chmod for linux
                if ($^O eq 'linux') {
                    $self->app->log->debug("helperCreatePath - chmod 0755 : $dir");
                    chmod 0755, $dir or die "Couldn't chmod $dir: $!";
                }
                return 1;
            }
            else {
                return 0;
            }
        }
        return 1;
    });

    # -----------------------------------------------------------------------------
    # -- get a new unique file id
    # -----------------------------------------------------------------------------
    $app->helper(helperFileUploadGetFileId =>
    sub {
        # Date and time
        my ($sec, $min, $hour, $mday, $month, $year) = localtime;
        $month = $month + 1;
        $year = $year + 1900;
        # Random number(0 ~ 99999)
        my $rand_num = int(rand 100000);
        # Create file name form datatime and random number
        # (like file-20091014051023-78973)
        return sprintf("file-%04s%02s%02s%02s%02s%02s-%05s",
            $year, $month, $mday, $hour, $min, $sec, $rand_num);
    });


    $app->helper(helperImageCreateThumbanail =>
    sub {
        my $self      = shift;
        my $image     = shift;
        my $image_dir = shift;

        $self->app->log->debug("helperImageCreateThumbanail - image: $image");

        #file names
        my $source    = $image_dir.'/'.$image;
        my $thumbnail = $image_dir.'/'.$image;

        # http://search.cpan.org/~burak/GD-Thumbnail-1.41/lib/GD/Thumbnail.pm
        my $thumb = GD::Thumbnail->new(
            square => 1,
        );
        my $raw   = $thumb->create($source, 350, 0);
        #warn sprintf "Dimension: %sx%s\n", $thumb->width, $thumb->height;
        open    IMG, ">$thumbnail" or die "Error: $!";
        binmode IMG;
        print   IMG $raw;
        close   IMG;
        return 1;
    });

    $app->helper(helperInsertAccessLog =>
    sub {
        my $self       = shift;
        my $headers    = shift;
        my $email      = shift;
        my $result     = shift;

        $self->app->log->debug("helperInsertAccessLog");

        # execute
        eval {
            my $res = $self->pg->db->insert('audit.access_log' , {
                log_headers => $headers,
                log_email   => $email,
                log_result  => $result
            }, { returning => 'log_id' })->hash->{'log_id'};
        };

        # error check
        if ($@) {
           $self->app->log->warn("Error: ".$@);
           return 0;
        }
        else {
           return 1;
        }
    });

    $app->helper(helperInsertLog =>
    sub {
        my $self       = shift;
        my $table      = shift;
        my $data_json  = shift;

        $self->app->log->debug("helperInsertLog");
        $self->app->log->debug("Action on table ".$table);

        # execute
        eval {
            my $res = $self->pg->db->insert('audit.'.$table , {
                log_data => $data_json
            }, { returning => 'log_id' })->hash->{'log_id'};
        };

        # error check
        if ($@) {
           $self->app->log->warn("Error: ".$@);
           return 0;
        }
        else {
           return 1;
        }
    });

    $app->helper(helperInsertPageLog =>
    sub {
        my $self    = shift;
        my $page    = shift;
        my $headers = shift;
        my $log     = shift;

        $self->app->log->debug("helperInsertPageLog");

        my $userid = $self->session('it.ecometer.bobo');

        # execute
        eval {
            my $res = $self->pg->db->insert('audit.pages_log' , {
                log_user    => $userid,
                log_headers => $headers,
                log_page    => $page,
                log_obj     => $log
            }, { returning => 'log_id' })->hash->{'log_id'};
        };

        # error check
        if ($@) {
           $self->app->log->warn("Error: ".$@);
           return 0;
        }
        else {
           return 1;
        }
    });


    $app->helper(helperInsertUserLog =>
    sub {
        my $self      = shift;
        my $action    = shift;
        my $table     = shift;
        my $data_json = shift;

        $self->app->log->debug("helperInsertUserLog");
        $self->app->log->debug("Action: ".$action." on table ".$table);

        my $userid = $self->session('it.ecometer.bobo');

        # execute
        eval {
            my $res = $self->pg->db->insert('audit.'.$table , {
                log_user   => $userid,
                log_action => $action,
                log_data   => $data_json
            }, { returning => 'log_id' })->hash->{'log_id'};
        };

        # error check
        if ($@) {
           $self->app->log->warn("Error: ".$@);
           return 0;
        }
        else {
           return 1;
        }
    });

    $app->helper(helperGetRemoteFileStatus=>
    sub {
        my $self = shift;
        my $fileurl = shift;
        my $gap = shift;
        my $local = shift; #time in local or gmt time zone

        $self->app->log->debug("helperGetRemoteFileStatus");
        $self->app->log->debug("$fileurl");

        if (!defined $local) {
            $local = 0;
        }

        my $status;

        # https://stackoverflow.com/a/17311304
        # for autocheck -> https://stackoverflow.com/a/39564004
        my $mech = WWW::Mechanize->new( autocheck => 0 );
        $mech->get( $fileurl);

        if ( $mech->success() ) {
            my $parser = DateTime::Format::Strptime->new(
                pattern => '%a, %d %b %Y %H:%M:%S',
                time_zone => 'UTC'
            );
            my $dt = $parser->parse_datetime($mech->response->header("Last-Modified"));
            $dt->strftime("%d-%m-%Y %H:%M:%S");

            my $now = Time::Moment->now;
            my $epoch_time = $now->epoch();
            my $epoch_file = $dt->epoch();

            # my $zone = DateTime::TimeZone->new(name => 'Europe/Rome');

            if ($local == 1) {
                $dt->set_time_zone('Europe/Rome');
            }


            my $is_late = (($epoch_time - $epoch_file) > ($gap*3600)) ? 1 : 0;

            $self->app->log->debug("$epoch_file");
           $status = {
                date    => $local == 1 ? $dt->strftime("%d-%m-%Y %H:%M:%S") : $dt->strftime("%d-%m-%Y %H:%M:%S GMT"),
                islate  => $is_late,
                url     => $fileurl."?v=".($epoch_file || '')
            };

            return $status;
        }
        else {
            $status = {
                date    => undef,
                islate  => 1,
                url     => $fileurl
            };
        }

        return $status;
    });

    $app->helper(helperGetFileStatus=>
    sub {
        my $self = shift;
        my $filename = shift;
        my $gap = shift;
        my $local = shift; #time in local or gmt time zone

        $self->app->log->debug("helperGetFileStatus");
        $self->app->log->debug("$filename");

        # get filename
        my $path = $self->app->home->rel_file('/public'.$filename);

        my $status;
        if (-e $path) {

            $status = {
                date    => $local == 1 ? $self->helperGetFormattedFileDate($filename) : $self->helperGetFormattedFileDateGMT($filename),
                islate  => $self->helperGetFileIsLate($filename, $gap),
                url     => $self->helperGetFileVersion($filename)
            };

        }
        else {
            $status = {
                date    => undef,
                islate  => 1,
                url     => $self->helperGetFileVersion($filename)
            };
        }

        return $status;
    });

    # -----------------------------------------------------------------------------
    # -- get file creation date
    # -----------------------------------------------------------------------------
    $app->helper(helperGetFormattedFileDateGMT=>
    sub {
        my $self = shift;
        my $filename = shift;

        # get filename
        $filename = $self->app->home->rel_file('/public'.$filename);

        if (-e $filename) {

            $self->app->log->debug("File exists");
            my $epoch_file = (stat($filename))[9];
            my $tm = Time::Moment->from_epoch($epoch_file);
            $self->app->log->debug($tm->strftime("%d-%m-%Y %H:%M:%S GMT"));

            return $tm->strftime("%d-%m-%Y %H:%M:%S GMT");
        }

        #$self->app->log->debug("islate : $islate");
        return undef;
    });

    $app->helper(helperGetFormattedFileDate=>
    sub {
        my $self = shift;
        my $filename = shift;

        my $zone = DateTime::TimeZone->new(name => 'Europe/Rome');

        # get filename
        $filename = $self->app->home->rel_file('/public'.$filename);

        if (-e $filename) {

            $self->app->log->debug("File exists");
            my $epoch_file = (stat($filename))[9];
            my $tm = Time::Moment->from_epoch($epoch_file);
            $self->app->log->debug($tm->strftime("%d-%m-%Y %H:%M:%S"));

            my $offset = $zone->offset_for_datetime($tm) / 60;

            return $tm->with_offset_same_instant($offset)->strftime("%d-%m-%Y %H:%M:%S");
        }

        #$self->app->log->debug("islate : $islate");
        return undef;
    });

    # -----------------------------------------------------------------------------
    # -- check if file is late
    # -----------------------------------------------------------------------------
    $app->helper(helperGetFileIsLate=>
    sub {
        my $self = shift;
        my $filename = shift;
        my $gap = shift;

        # log
        #$self->app->log->debug("Eagle::Apprespsala sub get_image_islate");

        # get filename
        $filename = $self->app->home->rel_file('/public'.$filename);

        my $islate = 1;
        if (-e $filename) {

            my $now = Time::Moment->now;
            my $epoch_time = $now->epoch;
            my $epoch_file = (stat($filename))[9];

            $islate = ( ($epoch_time - $epoch_file) > ($gap*3600) );
        }

        #$self->app->log->debug("islate : $islate");
        return $islate;
    });


    $app->helper(helperGetCSVHeader=>
    sub {
        my $self = shift;
        my $viewname = shift;

        # sql
        my $sql = "SELECT * FROM $viewname LIMIT 1";

        my $columns = $self->pg->db->query($sql)->columns;

        return $columns;
    });

    $app->helper(helperGetCSVData=>
    sub {
        my $self = shift;
        my $viewname = shift;
        my $from    = shift;
        my $to      = shift;
        my $stid    = shift;

        my $userid = $self->session('it.ecometer.bobo');

        my $sql = qq{
            SELECT *
            FROM $viewname v
                LEFT JOIN bobo.view_user_stations us ON (us.station_id = v."ID stazione")
            WHERE
                us.user_id = ?
                AND v."Data report" BETWEEN ?::timestamp AND ?::timestamp
        };

        if ($stid != -1) {
            $sql .= qq{
                    AND v."ID stazione" = $stid
                };
        }

        $sql .= qq{ORDER BY v."Data report" DESC;};

        my $data = $self->pg->db->query($sql, $userid, $from, $to)->hashes;

        #$self->app->log->debug("islate : $islate");
        return $data;
    });
}

1;

=head1 helperDumper

Funzione che stampa una determinata variabile nella console.

Argomenti:  * variabile da stampare ('var')

Return:     /

=cut

=head1 helperDumperPostData

Funzione che scrive un determinato contenuto in un file di log.

Argomenti:  * nome della directory (stesso nome della pagina) ('dir');

           * header del nome del file ('header');

           * contenuto da scrivere ('params');

Return:     Nome del file di log generato.

=cut

=head1 helperGetBoolean

Funzione che verifica se un determinato campo esiste.

Argomenti:  * variabile contenente i vari campi ('params');

           * nome del campo da verificare ('field');

Return:     valore 1/0:

                - 1: il campo esiste

                - 0: il campo non esiste

=cut

=head1 helperGetFullDate

Funzione che recupera la data e ora corrente.

Argomenti:  /

Return:     Data e ora corrente in formato 'YYYY-MM-DD HH:MI:SS'.

=cut

=head1 helperGetLocaleFullDate

Funzione che recupera la data e ora corrente tenendo conto
della timezone locale ('Europe/Rome').

Argomenti:  /

Return:     Data e ora corrente.

=cut

=head1 helperGetFormattedFulldate

Funzione che formatta una determinata data.

Argomenti:  * data da formattare ('fulldate')

Return:     - se $fulldate non e' definita o e' vuota: undef

        - oppure: data formattata in base alla presenza o

          meno dell'ora ('DD/MM/YYYY' o 'DD/MM/YYYY HH:MI:SS')

=cut

=head1 helperGetMonthName

Funzione che, dato un mese in formato numerico, restituisce il
corrispettivo mese in formato testuale.

Argomenti:  * mese da elaborare ('month')

Return:     Mese in formato testuale.

=cut

=head1 helperEscapeParam

Funzione che elimina eventuali spazi da una deterimanata stringa.

Argomenti:  * stringa da elaborare ('param')

Return:     - se $param non e' definita o e' vuota: undef

        - oppure: stringa ripulita dagli spazi

=cut

=head1 helperGetFileVersion

Funzione che recupera la versione di un determinato file.

Argomenti:  * path del file ('file')

Return:     path del file con accodata la versione.

=cut

=head1 helperSendEmailHTML

Funzione che inserisce una mail, contenente codice HTML, nella
coda di invio presente sul database.

Argomenti:  * nome dell'applicativo ('sender_app');

           * oggetto della mail ('subject');

           * corpo della mail ('body');

           * path del logo ('logo');

           * destinatari della mail, seperati da ';' ('recipients');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut

=head1 helperNewUserEmailHTML

Funzione che inserisce una mail con contenuto HTML nella coda di invio del database,
utilizzata specificamente per le email di registrazione/nuovo utente.

Argomenti:
* sender_app: nome dell'app mittente ('sender_app')
* subject: oggetto della mail ('subject')
* body: corpo HTML della mail ('body')
* logo: path del logo ('logo')
* send: flag (true/false) che indica se inviare subito o lasciare in coda (status)
* recipients: lista dei destinatari (uno o più indirizzi)

Return:
Valore 1 in caso di successo, 0 in caso di errore.

=cut

=head1 helperCreatePath

Funzione che crea, se non esiste, una determinata directory,
tenendo conto dell'intero path.

Argomenti:  * nome della directory ('dir')

Return:     valore 1/0:

                - 1: directory creata correttamente

                - 0: directory NON creata

=cut

=head1 helperFileUploadGetFileId

Funzione che genera un identificativo casuale
per il nome di un file.

Argomenti:  /

Return:     Identificativo generato randomicamente.

=cut

=head1 helperImageCreateThumbanail

Funzione che crea la thumbnail di una determinata immagine.

Argomenti:  * nome dell'immagine ('image');

           * nome della directory dell'immagine ('image_dir');

Return:     1 (tutto OK) oppure messaggio di errore.

=cut

=head1 helperInsertPageLog

Funzione che inserisce i log di una determinata pagina nel database.

Argomenti:  * url della pagina('page');

           * header del log da inserire ('headers');

           * contenuto del log da inserire ('log');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut