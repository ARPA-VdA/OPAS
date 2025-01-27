package Bobo::Controller::Cnfcampagne;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use File::Basename;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

sub campagne {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get regions
    my $regions = $self->dbcommon->get_all_regions();
    $self->stash(regions => $regions);

    # get provinces
    my $provinces = $self->dbcommon->get_all_provinces($user_id);
    $self->stash(provinces => $provinces);

    # Render template "utilities/campagne.html.ep" with message
    $self->render('impostazioni/campagne');
}

sub get_roaming_stations_bynets {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub get_roaming_stations_bynets");

    my $user_id = $self->session('it.ecometer.bobo');

    my $nets = decode_json($self->param('nets'));

    $self->app->log->debug("Networks:". \@{$nets});

    # get stations from province
    my $stations = $self->dbcnfcampagne->get_roaming_stations_by_nets($user_id, $nets);

    my $json = {
        res => "OK",
        stations => $stations
    };

    # render
    $self->render(json => $json);
}

sub get_campaigns {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub get_campaigns");

    my $user_id = $self->session('it.ecometer.bobo');

    my $campaigns = $self->dbcnfcampagne->get_campaigns($user_id);

    my $json;
    if (defined $campaigns) {
        $json = {
            res => "OK",
            campaigns => $campaigns
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

sub get_sites {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub get_sites");

    my $type = $self->param('type'); # post
    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post
    my $stid = $self->param('stid'); # post
    my $camp = $self->param('camp'); # post

    $self->app->log->debug("Type: $type");
    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("ID station: $stid");

    my $user_id = $self->session('it.ecometer.bobo');
    my $sites;
    my $locations;

    if ($type eq 'false') { # ricerca per sito
        $sites = $self->dbcnfcampagne->get_sites($user_id, $net, $prov);
    }
    else {
        $sites = $self->dbcnfcampagne->get_sites_by_date_station($user_id, $from, $to, $net, $prov, $stid, $camp);
    }

    $locations = $self->dbcnfcampagne->get_sites($user_id, -1, -1);

    my $json;
    if (defined $sites) {
        $json = {
            res => "OK",
            sites => $sites,
            locations => $locations
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

sub get_site_by_id {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Bombole sub get_site_by_id");

    my $siid = $self->param('id');

    $self->app->log->debug("ID site: $siid");

    # get data from dateFrom to dateTo
    my $json;
    my $site = $self->dbcnfcampagne->get_site_by_id($siid);

    if (defined $site) {
        $json = {
            res => "OK",
            site => $site
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

sub get_location_by_id {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub get_location_by_id");

    my $stsiid = $self->param('id');

    $self->app->log->debug("ID location: $stsiid");

    # get data from dateFrom to dateTo
    my $json;
    my $location = $self->dbcnfcampagne->get_location_by_id($stsiid);

    if (defined $location) {
        $json = {
            res => "OK",
            location => $location
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

sub put_campaign {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub put_campaign");
    $self->helperDumperPostData('Campagne', 'put_campaign', $self->req->body_params);

    my $res = 1;

    # get params from ajax
    my $params = $self->req->body_params->to_hash;
    my $campid = $params->{'camp-id'};
    my $userid = $self->session('it.ecometer.bobo');
    # my $table = 'cnf_instrument'; # audit

    # if campid defined -> edit site
    if (defined $campid && $campid ne "") {
        $self->app->log->debug("Bobo::Controller::Cnfcampagne edit of campaign");

        # store action to audit table
        # $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbcnfcampagne->update_campaign_by_id($params);
    }
    else { # else -> insert new site
        $self->app->log->debug("Bobo::Controller::Cnfcampagne insert of new campaign");

        # store action to audit table
        # $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $campid = $self->dbcnfcampagne->insert_new_campaign($params);
    }

    # check result
    if (defined $campid && $res == 1) {
        # già stanziato in un altro sito
        $self->app->log->debug('Result: OK');
        $self->render(json => $res);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub put_campaign_status {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub put_campaign_status");
    $self->helperDumperPostData('Campagne', 'put_campaign_status', $self->req->body_params);

    my $campid = $self->param('id'); # post
    my $status = $self->param('status');

    my $res = $self->dbcnfcampagne->update_campaign_status($campid, $status);

    # check result
    if (defined $res == 1) {
        # già stanziato in un altro sito
        $self->app->log->debug('Result: OK');
        $self->render(json => $res);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub put_site {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub put_site");
    $self->helperDumperPostData('Campagne', 'put_site', $self->req->body_params);

    my $res = 1;

    # get params from ajax
    my $params = $self->req->body_params->to_hash;
    my $siid = $params->{'site-id'};
    my $userid = $self->session('it.ecometer.bobo');
    # my $table = 'cnf_instrument'; # audit

    # if siid defined -> edit site
    if (defined $siid && $siid ne "") {
        $self->app->log->debug("Bobo::Controller::Strumenti edit of instrument");

        # store action to audit table
        # $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbcnfcampagne->update_site_by_id($params);
    }
    else { # else -> insert new site
        $self->app->log->debug("Bobo::Controller::Strumenti insert of new instrument");

        # store action to audit table
        # $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $siid = $self->dbcnfcampagne->insert_new_site($userid, $params);
        if (defined $siid && $siid <= -1) {
            $res = $siid;
        }
    }

    # Caricamento FILES sia per INSERT che per UPDATE
    my $files = $self->req->uploads('files');

    if ($res >= 0) {
        if (defined $siid && $res == 1) {
            if (scalar @{$files} > 0) {
                my $siid_file = sprintf("%09d", $siid);
                $self->app->log->debug("inid_file: $siid_file");
                my $file_base_dir = 'uploads/impostazioni/campagne/'.$siid_file;
                my $file_dir = $self->app->static->paths->[0].'/'.$file_base_dir;
                $self->helperCreatePath($file_dir);

                for my $file (@{$files}) {
                    # $self->helperDumper($file);
                    $self->app->log->debug($file->headers->content_type);
                    my $content_type = $file->headers->content_type;
                    my $is_image = 0;
                    if ($content_type =~ m/image\//) {
                        $self->app->log->debug("Is image");
                        $is_image = 1;
                    }

                    my $original_name = $file->filename;
                    my ($fp_name,$p_path,$p_ext) = fileparse($original_name, qr"\..[^.]*$");

                    my $file_name = $self->helperFileUploadGetFileId() . $p_ext;
                    my $full_file_name = $file_dir."/".$file_name;

                    $file->move_to($full_file_name);

                    $res = $self->dbcnfcampagne->insert_new_attachment($siid, $original_name, $file_name, $is_image);
                }
            } # END array files > 0
        } # END defined inid & res = TRUE
        else {
            $self->app->log->debug("Bobo::Controller::Cnfcampagne ERROR in insert or update site");
            $res = 0;
        }
    }

    # check result
    if ($res) {
        # $res == -1 può capitare solo in fase di insert e solo perché si è provato ad associare un laboratorio
        # già stanziato in un altro sito
        $self->app->log->debug('Result: OK');
        $self->render(json => $res);
    }
    else {

        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }

}

sub put_location {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub put_location");
    $self->helperDumperPostData('Campagne', 'put_location', $self->req->body_params);

    my $res = 1;

    # get params from ajax
    my $params = $self->req->body_params->to_hash;
    my $stsiid = $params->{'loc-id'};

    if (defined $stsiid && $stsiid ne "") {
        $self->app->log->debug("Bobo::Controller::Cnfcampagne edit of location");

        # store action to audit table
        # $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbcnfcampagne->update_location_by_id($params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Cnfcampagne insert of new location");

        # store action to audit table
        # $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $stsiid = $self->dbcnfcampagne->insert_new_location($params);
        if (defined $stsiid && $stsiid == -1) {
            $res = $stsiid;
        }
    }

    # check result
    if (defined $stsiid && $res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => $res);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub put_location_closure {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub put_location_closure");
    $self->helperDumperPostData('Campagne', 'put_location_closure', $self->req->body_params);

    # get params from ajax
    my $stsiid = $self->param('id');

    # check result
    if ($self->dbcnfcampagne->close_location_by_id($stsiid)) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_campaign {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub del_campaign");

    my $campid = $self->param('id'); # post

    my $res = $self->dbcnfcampagne->delete_campaign($campid);

    # check result
    if ($res == 1) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_attachment {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub del_attachment");
    $self->helperDumperPostData('Campagne', 'del_attachment', $self->req->body_params);

    # my $params = $self->req->body_params->to_hash; # for audit
    my $att_id = $self->param('id'); # post

    $self->app->log->debug("Attachment id: $att_id");

    # store action to audit table
    # my $table = 'rep_maintenance';
    # $self->helperInsertUserLog('DELETE ATT.', $table, encode_json($params));

    if ($self->dbcnfcampagne->delete_attachment_by_id($att_id)) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

sub del_site {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfcampagne sub del_site");
    $self->helperDumperPostData('Campagne', 'del_site', $self->req->body_params);

    # my $params = $self->req->body_params->to_hash; # for audit
    my $siid = $self->param('id'); # post

    $self->app->log->debug("Site: $siid");

    # store action to audit table
    # my $table = 'rep_maintenance';
    # $self->helperInsertUserLog( 'DELETE', $table, encode_json($params));

    # per controllo associazione con report tarature e planning query:
    my $flag = $self->dbcnfcampagne->check_site($siid);
    if ($flag == 0) {
        if ($self->dbcnfcampagne->delete_site_by_id($siid)) {
            $self->render(json => 1);
        }
        else {
            $self->render(json => 0);
        }
    }
    else {
        $self->render(json => -1);
    }
}

1;

=head1 campagne

Render della pagina di visualizzazione delle campagne.

Argomenti:  /

Return:     /

=cut

=head1 get_roaming_stations_bynets

Funzione per recuperare le informazioni delle stazioni mobili di determinate reti.

Argomenti:  * id dell'utente ('user_id');

           * json contenente le informazioni delle reti ('nets');

Return:     json contenente la risposta "OK" e le stazioni.

=cut

=head1 get_campaigns

Funzione per recuperare tutte le campagne visibili all'utente.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le campagne, oppure la risposta "ERR".

=cut

=head1 get_sites

Funzione per recuperare tutti i siti visibili all'utente.

Argomenti:  * tipo di ricerca ('type');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

           * id della stazione, se presente ('stid');

           * id della campagna, se presente ('camp');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK", i siti e le locations, oppure la risposta "ERR".

=cut

=head1 get_site_by_id

Funzione per recuperare le informazioni di un determinato sito.

Argomenti:  * id del sito ('id');

Return:     json contenente la risposta "OK" e il sito, oppure la risposta "ERR".

=cut

=head1 get_location_by_id

Funzione per recuperare le informazioni di una determinata location.

Argomenti:  * id della location ('id');

Return:     json contenente la risposta "OK" e la location, oppure la risposta "ERR".

=cut

=head1 put_campaign

Funzione per inserire/modificare una campagna.

Argomenti:  * oggetto contenente le informazioni della campagna da inserire/modificare ('params');

           * id della campagna; se presente: UPDATE ('camp-id');

           * id dell'utente ('userid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_campaign_status

Funzione per modificare lo stato di una determinata campagna.

Argomenti:  * id della campagna ('id');

           * stato da modificare ('status');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_site

Funzione per inserire/modificare un sito, compresi gli eventuali allegati.

Argomenti:  * oggetto contenente le informazioni del sito da inserire/modificare ('params');

           * id del sito; se presente: UPDATE ('site-id');

           * id dell'utente ('userid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;
=cut

=head1 put_location

Funzione per inserire/modificare una location.

Argomenti:  *  oggetto contenente le informazioni della location da inserire/modificare ('params');

           * id della location; se presente: UPDATE' ('loc-id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_location_closure

Funzione per effettuare la chiusura di una determinata location.

Argomenti:  * id della location ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_campaign

Funzione per eliminare una determinata campagna.

Argomenti:  * id della campagna ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_attachment

Funzione per eliminare un determinato allegato.

Argomenti:  * id dell'allegato ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_site

Funzione per eliminare un determinato sito.

Argomenti:  * id del sito ('id');

Return:     json contenente 1 o 0 o -1:

            - 1: OK;

            - 0: ERROR;

            - -1: non è possibile eliminare il sito perche' associato ad altri elementi;

=cut