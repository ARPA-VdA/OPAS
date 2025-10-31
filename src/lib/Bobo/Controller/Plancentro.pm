package Bobo::Controller::Plancentro;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use File::Basename;
use Mojo::File 'path';
use Mojo::JSON qw(decode_json encode_json);
use Encode qw/encode_utf8 decode_utf8/;

# use Mojo::AsyncAwait;
# use Mojo::Promise;
# use Mojo::IOLoop;

# !! centro
sub centro {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Tickets notifcentroiche");

    my $user_id = $self->session('it.ecometer.bobo');

    # get all passible tickets status
    my $status = $self->dbplancentro->get_status();
    $self->stash(status_list => $status);

    # get types
    my $types = $self->dbplancentro->get_types();
    $self->stash(types => $types);

    # get urgencies
    my $urgencies = $self->dbplancentro->get_urgencies();
    $self->stash(urgencies => $urgencies);

    # get groups
    my $groups = $self->dbplancentro->get_groups();
    $self->stash(groups => $groups);

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # Render template "planning/calendario.html.ep" with message
    $self->render('planning/centro');
}

sub get_metadata{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia sub get_metadata");

    my $user_id = $self->session('it.ecometer.bobo');

    my $user = $self->dbplancentro->get_user_role($user_id);
    my $status = $self->dbplancentro->get_status();
    my $types = $self->dbplancentro->get_types();
    my $urgencies = $self->dbplancentro->get_urgencies();
    my $groups = $self->dbplancentro->get_groups();

    my $json;
    if (defined $user) {
        $json = {
            res => "OK",
            user => $user,
            status => $status,
            types => $types,
            urgencies => $urgencies,
            groups => $groups
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

sub get_tickets {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Plancentro sub get_tickets");

    my $from   = $self->param('from'); # post
    my $to     = $self->param('to'); # post
    my $status = $self->param('status'); # post
    my $urgency = $self->param('urgency'); # post
    my $type    = $self->param('type'); # post
    my $useful = $self->param('useful'); # post

    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("Status: $status");
    $self->app->log->debug("Urgency: $urgency");
    $self->app->log->debug("Type: $type");
    $self->app->log->debug("useful: $useful");

    my $tickets;

    # get tickets
    $tickets = $self->dbplancentro->get_tickets($from, $to, $status, $urgency, $type, $useful);

    my $json;
    if (defined $tickets) {
        $json = {
            res => "OK",
            tickets => $tickets
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

sub get_selected_ticket {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Plancentro sub get_selected_ticket");

    my $id = $self->param('id'); # post
    $self->app->log->debug("ID ticket: $id");

    # get tickets
    my $ticket = $self->dbplancentro->get_ticket_by_id($id);
    my $status_list = $self->dbplancentro->get_ticket_status_list($id);

    my $json;
    if (defined $ticket) {
        $json = {
            res => "OK",
            ticket => $ticket,
            status_list => $status_list
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

sub put_ticket {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Plancentro sub put_ticket");

    # dump post data (with user infos)
    $self->helperDumperPostData('Plancentro', 'put_ticket', $self->req->body_params);

    my $params  = $self->req->body_params->to_hash;
    # $self->helperDumper($params);

    my $user_id = $self->session('it.ecometer.bobo');

    # get params from ajax
    my $res = 1;
    my $tkid = $params->{'newtic-id'};

    # if tkid defined -> edit ticket
    if (defined $tkid && $tkid ne "") {
        $self->app->log->debug("Bobo::Controller::Plancentro edit of ticket");

        $res = $self->dbplancentro->update_ticket($params);
    }
    else { # else -> insert new ticket
        $self->app->log->debug("Bobo::Controller::Plancentro insert of new ticket");

        $tkid = $self->dbplancentro->insert_ticket($user_id, $params);
    }

    # Caricamento FILES sia per INSERT che per UPDATE
    my $files = $self->req->uploads('files');

    if (defined $tkid && $res) {
        if (scalar @{$files} > 0) {

            my $status = $self->dbplancentro->get_ticket_last_status($tkid);
            my $status_id = $status->{cts_id};

            my $status_file = sprintf("%09d", $status_id);
            $self->app->log->debug("status_file: $status_file");
            my $file_base_dir = 'uploads/planning/centro/'.$status_file;
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
                $self->app->log->debug("original_name: $original_name");
                my ($fp_name,$p_path,$p_ext) = fileparse($original_name, qr"\..[^.]*$");

                my $file_name = $self->helperFileUploadGetFileId() . $p_ext;
                my $full_file_name = $file_dir."/".$file_name;

                $file->move_to($full_file_name);

                $res = $self->dbplancentro->insert_new_attachment($status_id, $original_name, $file_name, $is_image);
            }
        } # END array files > 0
    } # END defined rpid & res = TRUE
    else {
        $self->app->log->debug("Bobo::Controller::Qasopralluoghi ERROR in insert or update report");
        $res = 0;
    }

    if ($res == 1) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub put_ticket_status {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia sub put_ticket_status");

    # dump post data (with user infos)
    $self->helperDumperPostData('Plancentro', 'put_ticket_status', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;

    my $user_id = $self->session('it.ecometer.bobo');
    my $status_id = $self->dbplancentro->insert_ticket_status($user_id, $params);

    my $res = 1;
    # Caricamento FILES sia per INSERT che per UPDATE
    my $files = $self->req->uploads('files');

    if (defined $status_id ) {
        if (scalar @{$files} > 0) {

            my $status_file = sprintf("%09d", $status_id);
            $self->app->log->debug("status_file: $status_file");
            my $file_base_dir = 'uploads/planning/centro/'.$status_file;
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
                $self->app->log->debug("original_name: $original_name");
                my ($fp_name,$p_path,$p_ext) = fileparse($original_name, qr"\..[^.]*$");

                my $file_name = $self->helperFileUploadGetFileId() . $p_ext;
                my $full_file_name = $file_dir."/".$file_name;

                $file->move_to($full_file_name);

                $res = $self->dbplancentro->insert_new_attachment($status_id, $original_name, $file_name, $is_image);
            }
        } # END array files > 0
    } # END defined status_id & res = TRUE
    else {
        $self->app->log->debug("Bobo::Controller::Plancentro ERROR in insert status");
        $res = 0;
    }

    if ($res == 1) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub put_ticket_usefulness{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia sub put_ticket_usefulness");

    my $id = $self->param('id'); # post
    my $useful = $self->param('useful'); # post

    $self->app->log->debug("ID ticket: $id");
    $self->app->log->debug("Useful ticket: $useful");
    
    if ( $self->dbplancentro->update_ticket_usefulness($id, $useful) ) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_selected_ticket {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Plancentro sub del_selected_ticket");

    # dump post data (with user infos)
    $self->helperDumperPostData('Plancentro', 'del_selected_ticket', $self->req->body_params);

    my $id = $self->param('id'); # post

    my $res = $self->dbplancentro->delete_ticket($id);

    if (defined $res && $res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_selected_attachment {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Plancentro sub del_selected_attachment");
    $self->helperDumperPostData('Plancentro', 'del_selected_attachment', $self->req->body_params);

    my $params = $self->req->body_params->to_hash; # for audit
    my $attach_id = $self->param('id'); # post

    $self->app->log->debug("Attachment id: $attach_id");

    # store action to audit table
    # my $table = 'inspections';
    # $self->helperInsertUserLog('DELETE ATT.', $table, encode_json($params));

    if ($self->dbplancentro->delete_attachment_by_id($attach_id)) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

1;

=head1 centro

Render della pagina principale del ticket centro, con caricamento di status, tipi, urgenze e gruppi dei ticket.

Argomenti:  /
Return:     /

=cut

=head1 get_metadata

Restituisce i metadati necessari per la gestione dei ticket (ruolo utente, status, tipi, urgenze, gruppi).

Argomenti:  /
Return:     JSON con i metadati

=cut

=head1 get_tickets

Restituisce la lista dei ticket filtrati per data, stato, urgenza, tipo e utilità.

Argomenti:  
* from: data inizio
* to: data fine
* status: stato
* urgency: urgenza
* type: tipo
* useful: utilità

Return:    
* JSON con la lista dei ticket

=cut

=head1 get_selected_ticket

Restituisce i dettagli di un ticket selezionato e la lista degli stati associati.

Argomenti:  
* id: identificativo del ticket

Return:    
* JSON con i dettagli del ticket e la lista degli stati

=cut

=head1 put_ticket

Crea un nuovo ticket o aggiorna un ticket esistente, gestendo anche il caricamento di eventuali allegati.

Argomenti:  
* Parametri del ticket (via POST)
* files: lista dei file allegati

Return:    
* JSON con esito dell'operazione

=cut

=head1 put_ticket_status

Aggiunge un nuovo stato a un ticket, gestendo anche il caricamento di eventuali allegati.

Argomenti:  
* Parametri dello stato (via POST)
* files: lista dei file allegati

Return:    
* JSON con esito dell'operazione

=cut

=head1 put_ticket_usefulness

Aggiorna il campo "utilità" di un ticket.

Argomenti:  
* id: identificativo del ticket
* useful: valore di utilità

Return:    
* JSON con esito dell'operazione

=cut

=head1 del_selected_ticket

Elimina un ticket selezionato.

Argomenti:  
* id: identificativo del ticket

Return:    
* JSON con esito dell'operazione

=cut

=head1 del_selected_attachment

Elimina un allegato selezionato da un ticket.

Argomenti:  
* id: identificativo dell'allegato

Return:    
* JSON con esito dell'operazione

=cut

#