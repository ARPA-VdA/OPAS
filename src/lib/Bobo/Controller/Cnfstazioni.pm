package Bobo::Controller::Cnfstazioni;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];
use Sys::Hostname;

sub stazioni {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstazioni");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    # get networks
    my $schemas = $self->dbcnfstazioni->get_schemas($userid);
    $self->stash(schemas => $schemas);

    # get networks
    my $networks = $self->dbcommon->get_all_networks($userid);
    $self->stash(networks => $networks);

    # get regions
    my $regions = $self->dbcommon->get_all_regions();
    $self->stash(regions => $regions);

    # get station typologies
    my $typologies = $self->dbcnfstazioni->get_typologies();
    $self->stash(typologies => $typologies);

    # get station roaming type
    my $roaming_types = $self->dbcnfstazioni->get_roaming_types();
    $self->stash(roaming_types => $roaming_types);

    # get station measure type
    my $measures_types = $self->dbcnfstazioni->get_measures_types();
    $self->stash(measures_types => $measures_types);

    # get station measures cadence
    my $measures_cadences = $self->dbcnfstazioni->get_measures_cadences();
    $self->stash(measures_cadences => $measures_cadences);

    # Render template "utilities/faq.html.ep" with message
    $self->render('impostazioni/stazioni_v2');
}

sub get_stations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstazioni sub get_stations");

    my $user_id = $self->session('it.ecometer.bobo');

    my $net = $self->param('netid'); # post
    my $prov = $self->param('prid'); # post
    my $status = $self->param('status'); # post
    $self->app->log->debug("ID network: $net");
    $self->app->log->debug("ID provincia: $prov");
    $self->app->log->debug("Stato della stazione: $status");

    # get stations from province
    my $stations = $self->dbcnfstazioni->get_stations_by_province_net($user_id, $net, $prov, $status);

    my $json = {
        res => "OK",
        stations => $stations
    };

    # render
    $self->render(json => $json);
}

sub get_station_by_id {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstazioni sub get_station_by_id");

    my $userid = $self->session('it.ecometer.bobo');

    my $stid = $self->param('stid'); # post
    $self->app->log->debug("ID stazione: $stid");

    # ATTENZIONE: non uso la dbcommon perché in questo caso non deve recuperare l'anagrafica del sito con stanziamento
    my $station = $self->dbcnfstazioni->get_station_by_id($stid);
    my $grants = $self->dbcommon->get_user_station_grants($userid, $stid);

    my $image; # = @{$files->{'img_files'}}[0]; (old) gets the first image randomly

    if (defined $station->{'station_media_path'}) {
        my $files = $self->helperGetStationFiles($station->{'station_media_path'});

        # loop all images
        for my $img (@{$files->{'img_files'}}) {
            $self->app->log->debug("File immagine: $img");
            # regular expression contain the 'station_id'
            # examples:
            # 1000.jpg        <-- get only this one
            # 1000_map.png
            # 1000_vdamap.png
            # 1000_graph.png
            # 1000_idro.png
            my $reg = ".*(media.*".$stid."\.(jpg|png|jpeg))";
            if ($img =~ /$reg/) {
                $image = "/$1";
            }
        }
    }

    # set the default image when '[STATION_ID].jpg|png|jpeg' not found
    if (!defined $image) {
        $image= "/media/no-photo-dataview.png";
    }

    $self->app->log->debug("$image");

    my $json;
    if (defined $station) {
        $json = {
            res => "OK",
            station => $station,
            grants => $grants,
            image => $image
        };
    }
    else {
        $json = {
            res => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

sub get_pdf{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qatarature sub get_pdf");

    my $user_id = $self->session('it.ecometer.bobo');
    # get user metadata
    my $user = $self->dbcommon->get_user_byid($user_id);

    my $params = $self->req->query_params->to_hash;
    $self->helperDumper($params);

    # get station id
    my $stid = $params->{'stid'}; # post

    $self->app->log->debug("PDF della stazione: $stid");

    if ($^O eq 'linux') {
        # choose by host
        my $host = hostname;
        if ($host eq 'opas-http') {
            # system
            eval{
                # create remote report
                $self->app->log->debug("[LOCALE] Lancio script creazione pdf");
                my $cmd = '~/perl5/perlbrew/perls/perl-5.38.0/bin/perl ~/bin/anagrafica/stazioni/report-anagrafica.pl '.$user->{portal_id}.' '.$stid;
                $self->app->log->debug($cmd);
                system($cmd) or $self->app->log->warn("CMD failed: $!");
                $self->app->log->debug("Fine script creazione pdf");
            };
        }
        else {
            $self->app->log->debug("Lancio script creazione pdf");
            # system('perl /var/www/bobo_latex/anagrafica/stazioni/report-anagrafica.pl '.$user->{portal_id}.' '.$stid);
            $self->app->log->debug("Fine script creazione pdf");
        }
    }

    my $json;

    $self->app->log->debug("check system result");
    $self->app->log->debug($?);
    if ($? == -1) { # errore if ($? == -1) {
        $self->app->log->debug("command failed: $!");

        $json = {
            res => 'ERROR',
            desc => 'Errore durante la creazione del pdf',
            id => 0
        };

        # final render
        $self->render(json => $json);
    }
    else { # comando andato a buon fine
        $self->app->log->debug('Pdf creato correttamente');
        $self->app->log->debug("Inizio recupero dati");

        # get application download path .../public/ path
        my $download_path = $self->app->static->paths->[0].'/downloads/anagrafica/stazioni';
        $self->app->log->debug("Download path: $download_path");

        # get PDF filename
        $self->app->log->debug("File PDF");
        my $pdf_filename = "report-anagrafica-".$stid.".pdf";

        # get full zip filename
        my $full_pdf_filename = $download_path.'/'.$pdf_filename;
        # log
        $self->app->log->debug("PDF filename: $full_pdf_filename");

        # last check
        if (-e $full_pdf_filename) {
            # encode filename to support "à"
            $pdf_filename = encode_utf8($pdf_filename);

            # downloadPdfFile | render_file
            $self->render_file(
                'filepath' => $full_pdf_filename,
                'filename' => $pdf_filename,
                'format' => 'pdf', # will change Content-Type "application/x-download" to "application/pdf"
                'content_disposition' => 'attachment', # will change Content-Disposition from "attachment" to "inline"
                'cleanup' => 0 # delete file after completed

                # inline               - is for showing file inline
                # attachment (default) - is for downloading
            );
        }
        else {
            $self->app->log->error("Error. PDF file DOES NOT exists!");

            $json = {
                res => 'ERROR',
                desc => "Errore durante lo scarico del bollettino."
            };

            # final render
            $self->render(json => $json);
        }
    }
}

sub put_station {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstazioni  sub put_station");
    $self->helperDumperPostData('Stazioni', 'put_station', $self->req->body_params);

    my $userid = $self->session('it.ecometer.bobo');

    my $res = 1;

    # get params from ajax
    my $params = $self->req->body_params->to_hash;
    $self->app->log->debug(Dumper($params));

    my $stid = $params->{'station-id'};

    my $table = 'stations'; # audit

    # check station
    if (defined $stid && $stid ne '') { # if stid defined -> edit station
        $self->app->log->debug("Bobo::Controller::Cnfstazioni edit of station");

        $res = $self->dbcnfstazioni->update_station($userid, $params);
        # store action to audit table
        $self->helperInsertUserLog('UPDATE', $table, encode_json($params));
    }
    else { # else -> insert new station
        $self->app->log->debug("Bobo::Controller::Cnfstazioni insert of new station");

        $stid = $self->dbcnfstazioni->insert_station($userid, $params);
        # store action to audit table
        $self->helperInsertUserLog('INSERT', $table, encode_json($params));
    }

    # check result
    if ($res && defined $stid) {
        # my $station = $self->dbcommon->get_station_by_id( $stid );
        # my $files = $self->helperGetStationFiles($station->{'station_media_path'});
        # my $image = @{$files->{'img_files'}}[0];

        # # $self->app->log->debug("$image");
        # if ($image && $image =~ /.*(media.*\.(jpg|png|jpeg))/) {
        #     $image = "/$1";
        # }
        # else {
        #     $image= "/media/no-photo-dataview.png";
        # }

        # my $json = {
        #     res  => 'OK',
        #     stid => $stid
        #     # image => $image
        # };

        $self->app->log->debug('Result: OK');
        $self->render(json => $stid);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_station {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstazioni sub del_station");
    $self->helperDumperPostData('Stazioni', 'del_station', $self->req->body_params);

    my $params = $self->req->body_params->to_hash; # for audit
    my $stid = $self->param('id'); # post

    $self->app->log->debug("Station ID: $stid");

    # store action to audit table
    # my $table = 'rep_qamaintenances';
    # $self->helperInsertUserLog( 'DELETE', $table, encode_json($params));

    my $res = $self->dbcnfstazioni->delete_station_by_id($stid);

    # check result
    if ($res > 0) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => $res);
    }
}


1;

=head1 stazioni

Render della pagina di visualizzazione delle stazioni.

Argomenti:  /

Return:     /

=cut

=head1 get_stations

Funzione per recuperare tutte le stazioni disponibili sul portale.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia, se presente ('prid');

           * id della rete, se presente ('netid');

Return:     json contenente la risposta "OK" e le stazioni.

=cut

=head1 get_station_by_id

Funzione per recuperare, dato l'id, le informazioni di una determinata stazione.

Argomenti:  * id dell'utente ('user_id');

           * id della stazione ('stid');

Return:     json contenente, se presenti, la risposta "OK", la stazione, i permessi e
il percorso per le immagini della stazione estratta oppure solamente la risposta "ERR".

=cut


=head1 put_station

Funzione per inserire/modificare una determinata stazione. (Attualmente SOLO modifica)

Argomenti:  * id della stazione, se gia' presente ('station-id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_pdf

Funzione per generare, dato l'id, il download del pdf di anagrafica di una determinata stazione.

Argomenti:  * id della stazione ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_station

Funzione per eliminare una determinata stazione.

Argomenti:  * id della stazione ('stid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut