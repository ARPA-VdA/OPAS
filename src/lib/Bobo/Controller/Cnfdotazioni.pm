package Bobo::Controller::Cnfdotazioni;
use Mojo::Base 'Mojolicious::Controller';

use File::Basename;
use Data::Dumper;

sub dotazioni {
    my $self = shift;
    $self->app->log->debug("Bobo::Controller::Cnfdotazioni");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    # get provinces
    my $provinces = $self->dbcommon->get_provinces( $userid );
    $self->stash(provinces => $provinces);

    # get networks
    my $networks = $self->dbcommon->get_all_networks($userid);
    $self->stash(networks => $networks);

    # Render template "impostazioni/dotazioni.html.ep" with message
    $self->render('impostazioni/dotazioni');
}

sub get_miscellanies {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfdotazioni sub get_miscellanies");

    my $type = $self->param('type'); # post
    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $stid = $self->param('stid'); # post

    $self->app->log->debug("Type: $type");
    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("ID station: $stid");

    my $user_id = $self->session('it.ecometer.bobo');
    my $miscellanies;

    if ($type eq 'false') { # ricerca per bombola
        $miscellanies = $self->dbcnfdotazioni->get_miscellanies($user_id);
    }
    else {
        $miscellanies = $self->dbcnfdotazioni->get_miscellanies_by_date_station($user_id, $from, $to, $stid);
    }

    my $json;
    if (defined $miscellanies) {
        $json = {
            res => "OK",
            miscellanies => $miscellanies
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

sub get_miscellanies_for_location {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfdotazioni sub get_miscellanies_for_location");

    my $user_id = $self->session('it.ecometer.bobo');

    my $miscellanies = $self->dbcnfdotazioni->get_miscellanies_for_location($user_id);

    my $json;
    if (defined $miscellanies) {
        $json = {
            res => "OK",
            miscellanies => $miscellanies
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

sub get_miscellany_by_id {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfdotazioni sub get_miscellany_by_id");

    my $miid = $self->param('id');

    $self->app->log->debug("ID miscellany: $miid");

    # get data from dateFrom to dateTo
    my $json;
    my $miscellany = $self->dbcnfdotazioni->get_miscellany_by_id($miid);

    if (defined $miscellany) {
        $json = {
            res => "OK",
            miscellany => $miscellany
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
    $self->app->log->debug("Bobo::Controller::Cnfdotazioni sub get_location_by_id");

    my $stmiid = $self->param('id');

    $self->app->log->debug("ID location: $stmiid");

    # get data from dateFrom to dateTo
    my $json;
    my $location = $self->dbcnfdotazioni->get_location_by_id($stmiid);
    my $edit_check = $self->dbcnfdotazioni->check_location($stmiid);

    if (defined $location) {
        $json = {
            res => "OK",
            location => $location,
            check => $edit_check
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

sub put_miscellany {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfdotazioni sub put_miscellany");
    $self->helperDumperPostData('Dotazioni', 'put_miscellany', $self->req->body_params);

    my $res = 1;

    # get params from ajax
    my $params = $self->req->body_params->to_hash;
    my $miid =  $params->{'equipment-id'};
    my $userid = $self->session('it.ecometer.bobo');
    # my $table = 'cnf_cylinder'; # audit

    # if miid defined -> edit report
    if (defined $miid && $miid ne "") {
        $self->app->log->debug("Bobo::Controller::Cnfdotazioni edit of miscellany");

        # store action to audit table
        # $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbcnfdotazioni->update_miscellany_by_id($userid, $params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Cnfdotazioni insert of new miscellany");

        # store action to audit table
        # $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $miid = $self->dbcnfdotazioni->insert_new_miscellany($userid, $params);
    }

    # Caricamento FILES sia per INSERT che per UPDATE
    my $files = $self->req->uploads('files');

    if (defined $miid && $res == 1) {
        if (scalar @{$files} > 0) {
            my $miid_file = sprintf("%09d", $miid);
            $self->app->log->debug("miid_file: $miid_file");
            my $file_base_dir = 'uploads/impostazioni/dotazioni/'.$miid_file;
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

                $res = $self->dbcnfdotazioni->insert_new_attachment($miid, $original_name, $file_name, $is_image);
            }
        } # END array files > 0
    } # END defined miid & res = TRUE
    else {
        $self->app->log->debug("Bobo::Controller::Cnfdotazioni ERROR in insert or update miscellany");
        $res = 0;
    }

    # check result
    if ($res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub put_location {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfdotazioni sub put_location");
    $self->helperDumperPostData('Dotazioni', 'put_location', $self->req->body_params);

    my $res = 1;

    # get params from ajax
    my $params = $self->req->body_params->to_hash;
    my $stmiid = $params->{'place-loc-id'};

    if (defined $stmiid && $stmiid ne "") {
        $self->app->log->debug("Bobo::Controller::Cnfdotazioni edit of location");

        # store action to audit table
        # $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbcnfdotazioni->update_location_by_id($params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Cnfdotazioni insert of new location");

        # store action to audit table
        # $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $stmiid = $self->dbcnfdotazioni->insert_new_location($params);
        if ($stmiid == -1) {
            $res = $stmiid;
        }
    }

    # check result
    if (defined $stmiid && $res) {
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
    $self->app->log->debug("Bobo::Controller::Cnfdotazioni sub put_location_closure");
    $self->helperDumperPostData('Dotazioni', 'put_location_closure', $self->req->body_params);

    # get params from ajax
    my $stmiid = $self->param('id');

    # check result
    if ($self->dbcnfdotazioni->close_location_by_id($stmiid)) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_miscellany {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfdotazioni sub del_miscellany");
    $self->helperDumperPostData('Dotazioni', 'del_miscellany', $self->req->body_params);

    # my $params  = $self->req->body_params->to_hash; # for audit
    my $miid = $self->param('id'); # post

    $self->app->log->debug("Miscellany: $miid");

    # store action to audit table
    # my $table = 'rep_maintenance';
    # $self->helperInsertUserLog('DELETE', $table, encode_json($params));

    # per controllo associazione con report tarature e planning query:
    my $flag = $self->dbcnfdotazioni->check_miscellany($miid);
    if ($flag == 0) {
        if ($self->dbcnfdotazioni->delete_miscellany_by_id($miid)) {
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

sub del_attachment {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfdotazioni sub del_attachment");
    $self->helperDumperPostData('Dotazioni', 'del_attachment', $self->req->body_params);

    # my $params  = $self->req->body_params->to_hash; # for audit
    my $att_id = $self->param('id'); # post

    $self->app->log->debug("Attachment id: $att_id");

    # store action to audit table
    # my $table = 'rep_maintenance';
    # $self->helperInsertUserLog('DELETE ATT.', $table, encode_json($params));

    if ($self->dbcnfdotazioni->delete_attachment_by_id($att_id)) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

1;

=head1 dotazioni

Render della pagina di visualizzazione delle dotazioni.

Argomenti:  /

Return:     /

=cut

=head1 get_miscellanies

Funzione per recuperare tutte le dotazioni disponibili sul portale.

Argomenti:  * tipo di ricerca ('type');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione, se presente ('stid');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le dotazioni, oppure la risposta "ERR".

=cut

=head1 get_miscellanies_for_location

Funzione per recuperare le informazioni delle dotazioni non ancora stanziate.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le dotazioni, oppure la risposta "ERR".

=cut

=head1 get_miscellany_by_id

Funzione per recuperare, dato l'id, le informazioni di una determinata dotazione.

Argomenti:  * id della dotazione ('id');

Return:     json contenente la risposta "OK" e la dotazione, oppure la risposta "ERR".

=cut


=head1 get_location_by_id

Funzione per recuperare, dato l'id, le informazioni di una determinata location.

Argomenti:  * id della location ('id');

Return:     json contenente la risposta "OK", la location e valore booleano per associazione
con report tarature o planning, oppure la risposta "ERR".

=cut

=head1 put_miscellany

Funzione per inserire/modificare una dotazione, compresi gli eventuali allegati.

Argomenti:  * oggetto contenente le informazioni della bombola da inserire/modificare ('params');

           * id della dotazione; se presente: UPDATE ('equipment-id');

           * id dell'utente ('userid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_location

Funzione per inserire/modificare una location.

Argomenti:  *  oggetto contenente le informazioni della location da inserire/modificare ('params');

           * id della location; se presente: UPDATE' ('place-loc-id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_location_closure

Funzione per effettuare, dato l'id, la chiusura di una determinata location.

Argomenti:  * id della location ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_miscellany

Funzione per eliminare, dato l'id, una determinata dotazione.

Argomenti:  * id della dotazione ('id');

Return:     json contenente 1 o 0 o -1:

            - 1: OK;

            - 0: ERROR;

            - -1: NULL;

=cut

=head1 del_attachment

Funzione per eliminare, dato l'id, un determinato allegato.

Argomenti:  * id dell'allegato ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut