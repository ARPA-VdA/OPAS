package Bobo::Controller::Cnfstrumenti;
use Mojo::Base 'Mojolicious::Controller';

use File::Basename;
use Data::Dumper;

sub strumenti {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($userid);
    $self->stash(provinces => $provinces);

    # get networks
    my $networks = $self->dbcommon->get_all_networks($userid);
    $self->stash(networks => $networks);

    my $categories = $self->dbcommon->get_equipments_categories();
    $self->stash(categories => $categories);

    my $types = $self->dbcnfstrumenti->get_instruments_types();
    $self->stash(types => $types);

    # Render template "utilities/faq.html.ep" with message
    $self->render('impostazioni/strumenti');
}

sub get_instruments {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti sub get_instruments");

    my $type = $self->param('type'); # post
    my $from = $self->param('from'); # post
    my $to   = $self->param('to');   # post
    my $net  = $self->param('net');  # post
    my $stid = $self->param('stid'); # post
    my $cat  = $self->param('cat');  # post

    $self->app->log->debug("Type: $type");
    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("ID station: $stid");

    my $user_id = $self->session('it.ecometer.bobo');
    my $instruments;

    if ($type eq 'false') { # ricerca per strumento
        $instruments = $self->dbcnfstrumenti->get_instruments_by_date($user_id, $from, $to, $net, $cat);
    }
    else {
        $instruments = $self->dbcnfstrumenti->get_instruments_by_date_station($user_id, $from, $to, $net, $stid, $cat);
    }

    my $json;
    if (defined $instruments) {
        $json = {
            res => "OK",
            instruments => $instruments
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

sub get_instrument_by_id {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti sub get_instrument_by_id");

    my $inid = $self->param('id');

    $self->app->log->debug("ID instrument: $inid");

    my $json;
    my $instrument = $self->dbcnfstrumenti->get_instrument_by_id($inid);

    if (defined $instrument) {
        $json = {
            res => "OK",
            instrument => $instrument
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

sub get_params_by_instr_type {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti sub get_params_by_instr_type");

    my $stid = $self->param('stid');
    my $intyid = $self->param('intyid');

    $self->app->log->debug("ID stazione: $stid");
    $self->app->log->debug("ID instrument type: $intyid");

    my $json;
    my $params = $self->dbcnfstrumenti->get_params_by_instr_type($stid, $intyid);

    if (defined $params) {
        $json = {
            res => "OK",
            params => $params
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

sub get_instruments_for_location {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti sub get_instruments_for_location");

    my $userid = $self->session('it.ecometer.bobo');

    my $instruments = $self->dbcnfstrumenti->get_instruments_for_location($userid);

    my $json;
    if (defined $instruments) {
        $json = {
            res => "OK",
            instruments => $instruments
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
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti sub get_location_by_id");

    my $stinid = $self->param('id');

    $self->app->log->debug("ID location: $stinid");

    my $json;
    my $location = $self->dbcnfstrumenti->get_location_by_id($stinid);
    my $edit_check = $self->dbcnfstrumenti->check_location($stinid);

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

sub put_instrument {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti sub put_instrument");
    $self->helperDumperPostData('Strumenti', 'put_instrument', $self->req->body_params);

    my $res = 1;

    # get params from ajax
    my $params = $self->req->body_params->to_hash;
    my $inid = $params->{'instr-id'};
    my $userid = $self->session('it.ecometer.bobo');
    # my $table = 'cnf_instrument'; # audit

    # check instrument
    if (defined $inid && $inid ne "") { # if inid defined -> edit report
        $self->app->log->debug("Bobo::Controller::Cnfstrumenti edit of instrument");

        # store action to audit table
        # $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbcnfstrumenti->update_instrument_by_id($userid, $params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Cnfstrumenti insert of new instrument");

        # store action to audit table
        # $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $inid = $self->dbcnfstrumenti->insert_new_instrument($userid, $params);
        if (defined $inid && $inid == -1) {
            $res = -1;
        }
    }

    # Caricamento FILES sia per INSERT che per UPDATE
    my $files = $self->req->uploads('files');

    if ($res != -1) {
        if (defined $inid && $res == 1) {
            if (scalar @{$files} > 0) {
                my $inid_file = sprintf("%09d", $inid);
                $self->app->log->debug("inid_file: $inid_file");
                my $file_base_dir = 'uploads/impostazioni/strumenti/'.$inid_file;
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

                    $res = $self->dbcnfstrumenti->insert_new_attachment($inid, $original_name, $file_name, $is_image);
                }
            } # END array files > 0
        } # END defined inid & res = TRUE
        else {
            $self->app->log->debug("Bobo::Controller::Cnfstrumenti ERROR in insert or update instrument");
            $res = 0;
        }
    }

    # check result
    if ($res) {
        # $res == -1 può capitare solo in fase di insert e solo perché si è provato ad associare lo strumento
        # ad un parametro già "occupato"
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
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti sub put_location");
    $self->helperDumperPostData('Strumenti', 'put_location', $self->req->body_params);

    my $res = 1;

    # get params from ajax
    my $params = $self->req->body_params->to_hash;
    my $stinid = $params->{'place-id'};

    if (defined $stinid && $stinid ne "") {
        $self->app->log->debug("Bobo::Controller::Cnfstrumenti edit of location");

        # store action to audit table
        # $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbcnfstrumenti->update_location_by_id($params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Cnfstrumenti insert of new location");

        # store action to audit table
        # $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $stinid = $self->dbcnfstrumenti->insert_new_location($params);
        if ($stinid < 0) {
            $res = $stinid;
        }
    }

    # check result
    if (defined $stinid && $res) {
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
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti sub put_location_closure");
    $self->helperDumperPostData('Strumenti', 'put_location_closure', $self->req->body_params);

    # get params from ajax
    my $stinid = $self->param('id');

    # check result
    if ($self->dbcnfstrumenti->close_location_by_id($stinid)) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_instrument {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti sub del_instrument");
    $self->helperDumperPostData('Strumenti', 'del_instrument', $self->req->body_params);

    # my $params = $self->req->body_params->to_hash; # for audit
    my $inid = $self->param('id'); # post

    $self->app->log->debug("instrument: $inid");

    # store action to audit table
    # my $table = 'rep_maintenance';
    # $self->helperInsertUserLog('DELETE', $table, encode_json($params));

    # per controllo associazione con report tarature e planning query:
    my $flag = $self->dbcnfstrumenti->check_instrument($inid);
    if ($flag == 0) {
        if ($self->dbcnfstrumenti->delete_instrument_by_id($inid)) {
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
    $self->app->log->debug("Bobo::Controller::Cnfstrumenti sub del_attachment");
    $self->helperDumperPostData('Strumenti', 'del_attachment', $self->req->body_params);

    # my $params = $self->req->body_params->to_hash; # for audit
    my $att_id = $self->param('id'); # post

    $self->app->log->debug("Attachment id: $att_id");

    # store action to audit table
    # my $table = 'rep_maintenance';
    # $self->helperInsertUserLog('DELETE ATT.', $table, encode_json($params));

    if ($self->dbcnfstrumenti->delete_attachment_by_id($att_id)) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

1;

=head1 strumenti

Render della pagina di visualizzazione degli strumenti.

Argomenti:  /

Return:     /

=cut

=head1 get_instruments

Funzione per recuperare tutti gli strumenti disponibili sul portale.

Argomenti:  * tipo di ricerca ('type');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della stazione, se presente ('stid');

           * id della categoria di strumento ('cat');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e gli strumenti, oppure la risposta "ERR".

=cut

=head1 get_instrument_by_id

Funzione per recuperare, dato l'id, le informazioni di un determinato strumento.

Argomenti:  * id dello strumento ('id');

Return:     json contenente la risposta "OK" e lo strumento, oppure la risposta "ERR".

=cut

=head1 get_params_by_instr_type

Funzione per recuperare i parametri associabili ad un determinato strumento
in base alla sua tipologia.

Argomenti:  * id dello strumento ('stid');

           * id della tipologia di strumento ('intyid');

Return:     json contenente la risposta "OK" e i parametri, oppure la risposta "ERR".

=cut

=head1 get_instruments_for_location

Funzione per recuperare le informazioni degli strumenti non ancora stanziati.

Argomenti:  /

Return:     json contenente la risposta "OK" e gli strumenti, oppure la risposta "ERR".

=cut

=head1 get_location_by_id

Funzione per recuperare, dato l'id, le informazioni di una determinata location.

Argomenti:  * id della location ('id');

Return:     json contenente la risposta "OK", la location e valore booleano per associazione
con report tarature o planning, oppure la risposta "ERR".

=cut

=head1 put_instrument

Funzione per inserire/modificare uno strumento, compresi gli eventuali allegati.

Argomenti:  * oggetto contenente le informazioni dello strumento da inserire/modificare ('params');

           * id dello strumento; se presente: UPDATE ('inid');

           * id dell'utente ('userid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_location

Funzione per inserire/modificare una location.

Argomenti:  *  oggetto contenente le informazioni della location da inserire/modificare ('params');

           * id della location; se presente: UPDATE' ('place-id');

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

=head1 del_instrument

Funzione per eliminare, dato l'id, un determinato strumento.

Argomenti:  * id dello strumento ('id');

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