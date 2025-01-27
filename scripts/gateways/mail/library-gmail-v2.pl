#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : library-gmail-v2.pl
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#   Description : Library for sending mail with gmail smtp
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# -- Enables 5.24 features ----------------------------------------------------
# enables the strict and warnings pragmas
use Modern::Perl '2016';
# for mails
use Encode qw( encode decode encode_utf8 decode_utf8 );
use Email::Send::SMTP::Gmail;
# log
our $log;
# config
my $MAICNF = {
   mail_from => 'xxx@xxxx.xx',
   smtp_user => 'xxx@xxxx.xx',
   smtp_pass => 'xxxxxxxxxxx',
};
return(1);

# send_gmail_html(contenttype, disposition, attachments, subject, body, recipients) - send an email via gmail
sub send_gmail_html {

    my ($contenttype, $disposition, $attachments, $subject, $body, @recipients) = @_;

    # encoding
    $subject = encode_utf8( $subject );
    $body    = encode_utf8( $body );

    # log
    $log->info("Sending html to:" .join(",", @recipients).", subject: $subject...");

    my $err = 0;
    eval{

        # log
        $log->info("Sending from: $MAICNF->{mail_from} => to:" .
            join(",", @recipients).", subject: $subject, body: $body ...");

        # log
        $log->info("Connecting to mail server ...");

        # mail object
        my $mail=Email::Send::SMTP::Gmail->new(
            -smtp  => 'xxxxxxxxxxx',
            -login => $MAICNF->{smtp_user},
            -pass  => $MAICNF->{smtp_pass},
            -layer => 'ssl',
            -port  => 465
        );

        # log
        $log->info("Sending mail->send...");

        # mail send
        $mail->send(
            -from        => $MAICNF->{mail_from},
            -to          => join(",", @recipients),
            -subject     => $subject,
            -verbose     => 0,
            -body        => $body,
            -contenttype => $contenttype, # text/plain (default), text/html
            -disposition => $disposition, # set "inline" in sending embeeded attachments
            -attachments => $attachments
        );

        # log
        $log->info("Done mail->bye");
        $mail->bye;

    }; # eval

    # log
    if($@){
        $log->warn("Mail warning: $@");
        return 0;
    } else {
        if ( $err > 0 ) {
            $log->error("Mail sent with errors");
            return 0;
        } else {
            $log->info("Email sent");
            return 1;
        }
    }
}
