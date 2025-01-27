package Bobo::Controller::Customized;
use Mojo::Base 'Mojolicious::Controller';

use JSON;
use Data::Dumper;

use File::Spec::Functions qw(rel2abs);
use File::Basename;
use Unicode::UTF8 qw(decode_utf8 encode_utf8);

# CUSTOM
sub get_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Customized sub get_report");

    my $params = $self->req->query_params->to_hash;
    $self->helperDumper($params);

    my $portal = $params->{'portal'};
    my $type = $params->{'type'};

    my $user_id = $self->session('it.ecometer.bobo');

    # get users associated with the portal
    my $user = $self->dbcommon->get_user_byid($user_id);

    # sanity check
    # return $self->render(json => { res => 'ERROR action not allowed', status => 403} ) if ($user->{'portal_id'} != $portal);
    return $self->render(template => 'forbidden') if ($user->{'portal_id'} != $portal);

    if ($portal == 3 && $type eq 'rp-rrqa') { # arpae
        $self->get_arpae_rp_rrqa();
    }
    else {
        return $self->reply->not_found;
    }
}

# ARPAE
sub get_arpae_rp_rrqa {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Customized sub get_arpae_rp_rrqa");

    my $body = $self->dbcustomized->get_arpae_validators();
    # $self->app->log->debug(Dumper($body));
    # $self->app->log->debug("$body");
    if (defined $body) {
        my $body_head = ''."\n";
        $body_head .= '<html>'."\n";
        $body_head .= '    <head>'."\n";
        $body_head .= '        <link rel="icon" id="icon16" type="image/png" sizes="16x16" href="/bobo-img/arpae/favicon/favicon-16x16.png">';
        $body_head .= '        <link rel="icon" id="icon32" type="image/png" sizes="32x32" href="/bobo-img/arpae/favicon/favicon-32x32.png">';
        $body_head .= '        <style>body {margin: 0px 0 0 0; padding: 0; min-width: 100% !important; font-family: Tahoma, Verdana, Trebuchet MS, sans-serif; font-size: 12px; color: #525252;}'."\n";
        $body_head .= '            #main-table tr:nth-child(even){background-color: #f2f2f2}'."\n";
        $body_head .= '            #main-table th {'."\n";
        $body_head .= '                background-color: #4f727b;'."\n";
        $body_head .= '                color: white;'."\n";
        $body_head .= '                text-align: left;'."\n";
        $body_head .= '            }'."\n";
        $body_head .= '        </style>'."\n";
        $body_head .= '    </head>'."\n";
        $body_head .= '    <body bgcolor="#e3edfa" style="min-width: 100% !important; font-family: Tahoma, Verdana, Trebuchet MS, sans-serif; font-size: 12px; color: #525252; margin: 0px 0 0; padding: 0;">'."\n";
        $body_head .= '        <table width="100%" bgcolor="#e3edfa" border="0" cellpadding="0" cellspacing="0" style="margin-top: 20px;">'."\n";
        $body_head .= '            <tr>'."\n";
        $body_head .= '                <td>'."\n";
        $body_head .= '                    <table  align="center" cellpadding="0" cellspacing="10px" border="0" bgcolor="#FFFFFF" style="width: 80%; box-shadow: 3px 3px #c4d0d4; border: 1px solid #bfd0db;">'."\n";
        $body_head .= '                        <tr>'."\n";
        $body_head .= '                            <td bgcolor="#f5ffff" style="padding: 10px; border: 1px dashed #c4d0d3;">'."\n";
        $body_head .= '                                <table width="100%" cellpadding="2px" cellspacing="0" border="0">'."\n";
        $body_head .= '                                    <tr>'."\n";
        $body_head .= '                                        <td width="145"><img src="https://opas.isprambiente.it/bobo-img/arpae/loghi/arpae.png" alt="logo Arpae" width="200" style="margin-right: 20px;" /></td>'."\n";
        $body_head .= '                                        <td>'."\n";
        $body_head .= '                                            <h1 style="font-size: 1.7em; color: #125465; font-weight: 500; margin: 5px 0px 0px; align="justify"">Elenco RP-RRQA e operatori abilitati alla validazione</h1>'."\n";
        $body_head .= '                                        </td>'."\n";
        $body_head .= '                                    </tr>'."\n";
        $body_head .= '                                </table>'."\n";
        $body_head .= '                            </td>'."\n";
        $body_head .= '                        </tr>'."\n";
        $body_head .= '                        <tr>'."\n";
        $body_head .= '                            <td>'."\n";
        # $body_head .= '                                <h3 style="font-size: 1.3em; font-weight: normal; color: #5f7984; font-style: italic; margin: 8px 0px 5px;">Tabella operatori</h3>'."\n";
        $body_head .= '                                <table id="main-table" width="100%" cellpadding="5px" cellspacing="0" border="0" style="margin-bottom: 15px; font-size: 0.92rem;">'."\n";
        $body_head .= '                                     <thead>'."\n";
        $body_head .= '                                         <tr>'."\n";
        $body_head .= '                                             <th>#</th>'."\n";
        $body_head .= '                                             <th>Sede operativa</th>'."\n";
        $body_head .= '                                             <th>Nome</th>'."\n";
        $body_head .= '                                             <th>Ruolo</th>'."\n";
        $body_head .= '                                             <th>Abilitazione</th>'."\n";
        $body_head .= '                                         </tr>'."\n";
        $body_head .= '                                     </thead>'."\n";
        $body_head .= '                                     <tbody>'."\n";

        my $body_footer = '';
        $body_footer .= '                                   </tbody>'."\n";
        $body_footer .= '                                   <tfoot>'."\n";
        $body_footer .= '                                       <tr>'."\n";
        $body_footer .= '                                           <th>#</th>'."\n";
        $body_footer .= '                                           <th>Sede operativa</th>'."\n";
        $body_footer .= '                                           <th>Nome</th>'."\n";
        $body_footer .= '                                           <th>Ruolo</th>'."\n";
        $body_footer .= '                                           <th>Abilitazione</th>'."\n";
        $body_footer .= '                                       </tr>'."\n";
        $body_footer .= '                                   </tfoot>'."\n";
        $body_footer .= '                               </table>'."\n";
        $body_footer .= '                            </td>'."\n";
        $body_footer .= '                        </tr>'."\n";
        $body_footer .= '                    </table>'."\n";
        $body_footer .= '                </td>'."\n";
        $body_footer .= '            </tr>'."\n";
        $body_footer .= '            <tr>'."\n";
        $body_footer .= '                <td>'."\n";
        $body_footer .= '                    <table align="center" cellpadding="0" cellspacing="10" border="0" style="width: 100%; max-width: 650px; font-size: 0.8em;">'."\n";
        $body_footer .= '                        <tr>'."\n";
        $body_footer .= '                            <td>'."\n";
        $body_footer .= '                                <p style="font-size: 1.15em; margin: 0px 0px 10px;" align="left">Mod1-I72001/SA rev1</p>'."\n";
        $body_footer .= '                            </td>'."\n";
        $body_footer .= '                            <td>'."\n";

        my $local_tz = DateTime::TimeZone->new(name => 'Europe/Rome');
        my $now = DateTime->now(time_zone => $local_tz);

        $body_footer .= '                                <p style="font-size: 1.15em; margin: 0px 0px 10px;" align="right">aggiornato il: '. $now->strftime("%d/%m/%Y %H:%M:%S") .'</p>'."\n";
        $body_footer .= '                            </td>'."\n";
        $body_footer .= '                        </tr>'."\n";
        $body_footer .= '                    </table>'."\n";
        $body_footer .= '                </td>'."\n";
        $body_footer .= '            </tr>'."\n";
        $body_footer .= '        </table>'."\n";
        $body_footer .= '    </body>'."\n";
        $body_footer .= '</html>'."\n";

        # get application path .../public/ path
        my $app_path = $self->app->home->rel_file('public/downloads/arpae');
        $self->app->log->debug("Application path: $app_path");

        # build filename
        my $filename = 'QAReports.html';
        $filename = encode_utf8($filename);

        my $full_filename = "$app_path/$filename";
        open(FH, '>:encoding(utf-8)', $full_filename) or die $!;
        print FH $body_head;
        print FH $body;
        print FH $body_footer;
        close(FH);

        # copy file to remote server
        if ($^O eq 'linux') {
            eval {
                $self->app->log->debug("[SCP] Copy html file to reverse server (dmz)");
                my $dest_path = 'PATH';
                my $proxy = 'Proxy';
                # -T Disable strict filename checking
                system("ls") or $self->app->log->warn("Scp failed: $!");
            };

            if ($@) {
                $self->app->log->warning("[SCP] Command failed: $@");
                # reply to 404 page
                $self->reply->exception;
            }
            else { # all went file
                $self->app->log->debug("[SCP] File copied");
            }
        }

        # redirect if file exists
        if (-e $full_filename) {
            $self->reply->static("/downloads/arpae/$filename");
        }
        else {
            $self->reply->exception;
        }
    }
    else {
        $self->reply->exception;
    }
}

# arpa vda horiba panel START
sub horiba {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Customized sub horiba");

    my $user_id = $self->session('it.ecometer.bobo');

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # get channels
    my $stations = $self->dbcommon->get_stations($user_id);
    $self->stash(stations => $stations);

    # Render template "customized/horiba.html.ep" with message
    $self->render('customized/horiba');
}

sub get_horiba_images {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Customized sub get_horiba_images");

    # my $stid  = $self->param('stid'); # post
    my $stid = 1004; # Primo maggio
    my $date = $self->param('date'); # post
    $self->app->log->debug("Station: $stid");

    # c:\Dev\bobo_cloud\webapp\bobo\public\downloads\arpavda\horiba_1maggio\Image_2023-08-20-00-00-00.jpg
    # c:\Dev\bobo_cloud\webapp\bobo\public\downloads\arpavda\horiba_1maggio\Image_2023-08-20-06-00-00.jpg
    # c:\Dev\bobo_cloud\webapp\bobo\public\downloads\arpavda\horiba_1maggio\Image_2023-08-20-12-00-00.jpg
    # c:\Dev\bobo_cloud\webapp\bobo\public\downloads\arpavda\horiba_1maggio\Image_2023-08-21-00-00-00.jpg

    my $path = $self->app->home->rel_file("/public/downloads/horiba-px-375/".$stid."/");

    my @img_files = File::Find::Rule->file()
                    ->name( '*.png', '*.jpeg', '*.jpg' )
                    ->in( $path );

    my @matches = grep { /.*(downloads.*\/Image_${date}-.*\.(jpg|png|jpeg))/ } @img_files;

    my @matches_formatted = map { (my $s = $_) =~ m/.*(downloads.*\/Image_${date}-.*\.(jpg|png|jpeg))/; '/'.$1 } @matches;
    my @matches_indexes = map { (my $c = $_) =~ m/.*downloads.*\/Image_${date}-(\d\d).*\.(jpg|png|jpeg)/; int($1)/6 } @matches;

    my $data = $self->dbcustomized->get_horiba_data_by_date($date, $stid);

    my $json;
    if (defined $data) {
        $json = {
            res => 'OK',
            images => \@matches_formatted,
            images_idx => \@matches_indexes,
            data => $data
        };
    }
    else {
        $json = {
            res => 'ERR'
        };
    }

    $self->render(json => $json);
}
# arpa vda horiba panel END

1;

=head1 get_report

Funzione per recuperare il report relativo agli utenti di Arpa Emilia Romagna con i relativi permessi.

Argomenti:  * id del portale ('portal');

           * tipologia di utente ('type');

Return:     Render del report online.

=cut

=head1 get_arpae_rp_rrqa

Funzione che genera la pagina html relativa al report validatori di Arpa Emilia Romagna.

Argomenti:  /

Return:     Render del report online.

=cut

=head1 horiba

Render della pagina relativa allo strumento Horiba PX-375.

Argomenti:  * id dell'utente ('user_id');

Return:     /

=cut

=head1 get_horiba_images

Funzione che recupera i dati e le relative immagini dello strumento Horiba PX-375.

Argomenti:  * data per il recupero dei dati ('date');

Return:     json contenente il messaggio "OK", i dati e le immagini, oppure il messaggio "ERR".

=cut