package Bobo::Controller::Cnfstazioni;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

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

=head1 del_station

Funzione per eliminare una determinata stazione.

Argomenti:  * id della stazione ('stid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut