package Bobo::Controller::Cnfbombole;
use Mojo::Base 'Mojolicious::Controller';

use File::Basename;
use Data::Dumper;

sub bombole {
    my $self = shift;
    $self->app->log->debug("Bobo::Controller::Cnfbombole");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    # get provinces
    my $provinces = $self->dbcommon->get_provinces( $userid );
    $self->stash(provinces => $provinces);

    # get networks
    my $networks = $self->dbcommon->get_all_networks($userid);
    $self->stash(networks => $networks);

    # get categories
    my $categories = $self->dbcommon->get_cylinders_categories();
    $self->stash(categories => $categories);

    # Render template "utilities/bombole.html.ep" with message
    $self->render('impostazioni/bombole');
}

sub get_cylinders {
    my $self = shift;
    $self->app->log->debug("Bobo::Controller::Cnfbombole sub get_cylinders");

    my $type = $self->param('type'); # post
    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $net = $self->param('net'); # post
    my $stid = $self->param('stid'); # post

    $self->app->log->debug("Type: $type");
    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("ID station: $stid");

    my $user_id = $self->session('it.ecometer.bobo');
    my $cylinders;

    if ($type eq 'false') { # search by cylinder
        $cylinders = $self->dbcnfbombole->get_cylinders_by_date($user_id, $from, $to, $net);
    }
    else {
        $cylinders = $self->dbcnfbombole->get_cylinders_by_date_station($user_id, $from, $to, $net, $stid);
    }

    my $json;
    if (defined $cylinders) {
        $json = {
            res => "OK",
            cylinders => $cylinders
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

sub get_cylinders_for_location {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfbombole sub get_cylinders_for_location");

    my $user_id = $self->session('it.ecometer.bobo');

    my $cylinders = $self->dbcnfbombole->get_cylinders_for_location($user_id);

    my $json;
    if (defined $cylinders) {
        $json = {
            res => "OK",
            cylinders => $cylinders
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

sub get_cylinder_by_id {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfbombole sub get_cylinder_by_id");

    my $cyid = $self->param('id');

    $self->app->log->debug("ID cylinder: $cyid");

    # get data from dateFrom to dateTo
    my $json;
    my $cylinder = $self->dbcnfbombole->get_cylinder_by_id($cyid);
    my $locations = $self->dbcnfbombole->get_cylinder_locations_history($cyid);

    if (defined $cylinder) {
        $json = {
            res => "OK",
            cylinder => $cylinder,
            gantt_locations => $locations
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
    $self->app->log->debug("Bobo::Controller::Cnfbombole sub get_location_by_id");

    my $stcyid = $self->param('id');

    $self->app->log->debug("ID location: $stcyid");

    # get data from dateFrom to dateTo
    my $json;
    my $location = $self->dbcnfbombole->get_location_by_id($stcyid);
    my $edit_check = $self->dbcnfbombole->check_location($stcyid);

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

sub put_cylinder {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfbombole sub put_cylinder");
    $self->helperDumperPostData('Bombole', 'put_cylinder', $self->req->body_params);

    my $res = 1;

    # get params from ajax
    my $params = $self->req->body_params->to_hash;
    my $cyid = $params->{'tank-cy-id'};
    my $userid = $self->session('it.ecometer.bobo');
    # my $table = 'cnf_cylinder'; # audit

    # if cyid defined -> edit report
    if (defined $cyid && $cyid ne "") {
        $self->app->log->debug("Bobo::Controller::Cnfbombole edit of cylinder");

        # store action to audit table
        # $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbcnfbombole->update_cylinder_by_id($userid, $params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Cnfbombole insert of new cylinder");

        # store action to audit table
        # $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $cyid = $self->dbcnfbombole->insert_new_cylinder($userid, $params);
    }

    # Caricamento FILES sia per INSERT che per UPDATE
    my $files = $self->req->uploads('files');

    if (defined $cyid && $res == 1) {
        if (scalar @{$files} > 0) {
            my $cyid_file = sprintf("%09d", $cyid);
            $self->app->log->debug("cyid_file: $cyid_file");
            my $file_base_dir = 'uploads/impostazioni/bombole/'.$cyid_file;
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

                $res = $self->dbcnfbombole->insert_new_attachment($cyid, $original_name, $file_name, $is_image);
            }
        } # END array files > 0
    }
    else { # END defined cyid & res = TRUE
        $self->app->log->debug("Bobo::Controller::Cnfbombole ERROR in insert or update cylinder");
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
    $self->app->log->debug("Bobo::Controller::Cnfbombole sub put_location");
    $self->helperDumperPostData('Bombole', 'put_location', $self->req->body_params);

    my $res = 1;

    # get params from ajax
    my $params = $self->req->body_params->to_hash;
    my $stcyid = $params->{'modal-loc-id'};

    if (defined $stcyid && $stcyid ne "") {
        $self->app->log->debug("Bobo::Controller::Cnfbombole edit of location");

        # store action to audit table
        # $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbcnfbombole->update_location_by_id($params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Cnfbombole insert of new location");

        # store action to audit table
        # $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $stcyid = $self->dbcnfbombole->insert_new_location($params);

        if ($stcyid == -1) {
            $res = $stcyid;
        }
    }

    # check result
    if (defined $stcyid && $res) {
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
    $self->app->log->debug("Bobo::Controller::Cnfbombole sub put_location_closure");
    $self->helperDumperPostData('Bombole', 'put_location_closure', $self->req->body_params);

    # get params from ajax
    my $stcyid = $self->param('id');

    # check result
    if ($self->dbcnfbombole->close_location_by_id($stcyid)) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_cylinder {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfbombole sub del_cylinder");
    $self->helperDumperPostData('Bombole', 'del_cylinder', $self->req->body_params);

    # my $params  = $self->req->body_params->to_hash; # for audit
    my $cyid = $self->param('id');  # post

    $self->app->log->debug("Cylinder: $cyid");

    # store action to audit table
    # my $table = 'rep_maintenance';
    # $self->helperInsertUserLog( 'DELETE', $table, encode_json($params));

    # per controllo associazione con report tarature e planning query:
    my $flag = $self->dbcnfbombole->check_cylinder($cyid);
    if ($flag == 0) {
        if ($self->dbcnfbombole->delete_cylinder_by_id($cyid)) {
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
    $self->app->log->debug("Bobo::Controller::Cnfbombole sub del_attachment");
    $self->helperDumperPostData('Bombole', 'del_attachment', $self->req->body_params);

    # my $params = $self->req->body_params->to_hash; # for audit
    my $att_id = $self->param('id'); # post

    $self->app->log->debug("Attachment id: $att_id");

    # store action to audit table
    # my $table = 'rep_maintenance';
    # $self->helperInsertUserLog( 'DELETE ATT.', $table, encode_json($params));

    if ($self->dbcnfbombole->delete_attachment_by_id($att_id)) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

1;

=head1 bombole

Render della pagina di visualizzazione delle bombole.

Argomenti:  /

Return:     /

=cut

=head1 get_cylinders

Funzione per recuperare tutte le bombole disponibili sul portale.

Argomenti:  * tipo di ricerca ('type');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della stazione, se presente ('stid');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le bombole, oppure la risposta "ERR".

=cut

=head1 get_cylinders_for_location

Funzione per recuperare le informazioni delle bombole non ancora stanziate.

Argomenti:  /

Return:     json contenente la risposta "OK" e le bombole, oppure la risposta "ERR".

=cut

=head1 get_cylinder_by_id

Funzione per recuperare, dato l'id, le informazioni di una determinata bombola.

Argomenti:  * id della bombola ('id');

Return:     json contenente la risposta "OK" e la bombola, oppure la risposta "ERR".

=cut


=head1 get_location_by_id

Funzione per recuperare, dato l'id, le informazioni di una determinata location.

Argomenti:  * id della location ('id');

Return:     json contenente la risposta "OK", la location e valore booleano per associazione
con report tarature o planning, oppure la risposta "ERR".

=cut

=head1 put_cylinder

Funzione per inserire/modificare una bombola, compresi gli eventuali allegati.

Argomenti:  * oggetto contenente le informazioni della bombola da inserire/modificare ('params');

           * id della bombola; se presente: UPDATE ('cyid');

           * id dell'utente ('user_id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_location

Funzione per inserire/modificare una location.

Argomenti:  *  oggetto contenente le informazioni della location da inserire/modificare ('params');

           * id della location; se presente: UPDATE' ('modal-loc-id');

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

=head1 del_cylinder

Funzione per eliminare, dato l'id, una determinata bombola.

Argomenti:  * id della bombola ('id');

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