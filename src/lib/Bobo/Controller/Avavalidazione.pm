package Bobo::Controller::Avavalidazione;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

sub ava_validazione {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub ava_validazione");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    my $portal_groups_list = $self->dbcommon->get_portal_groups_by_user($user_id);
    $self->stash(portal_groups_list => $portal_groups_list);

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces( $user_id );
    $self->stash(provinces => $provinces);

    # get stations
    # my $stations = $self->dbcommon->get_stations( $user_id );
    # $self->stash(stations => $stations);

    # get panels
    my $panels = $self->dbvalidazione->get_panels_list($user_id);
    $self->stash(panels => $panels);

    my $params = $self->dbvalidazione->get_all_parameters();
    $self->stash(params => $params);

    # Render template "avanzate/validazione.html.ep" with message
    $self->render('avanzate/validazione');
}

# -----------------------------------------------------------------------------
# Ajax GET
# -----------------------------------------------------------------------------
sub get_validation_groups {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub get_validation_groups");

    my $user_id = $self->session('it.ecometer.bobo');

    # get groups for the construction of the jstree
    my $groups = $self->dbvalidazione->get_validation_groups($user_id, 0);

    if (defined $groups) {
        $self->helperDumper(decode_json(encode_utf8($groups)));
        $self->render(json => decode_json(encode_utf8($groups)));
    }
    else {
        $self->render(json => {
            'icon'=> 'ti-package' ,
            'text'=> 'Nessun sottogruppo'
        });
    }
}

sub get_group_stations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub get_group_stations");

    # dump
    $self->helperDumper($self->req->query_params->to_hash);

    my $user_id = $self->session('it.ecometer.bobo');

    # get group id
    my $grid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};

    $self->app->log->debug("Got grid: $grid");

    # get stations by group id for the construction of the jstree
    my $stations = $self->dbvalidazione->get_group_stations_no_options($nodeid, $grid, $user_id);

    if (defined $stations) {
        $self->helperDumper(decode_json(encode_utf8($stations)));
        $self->render(json => decode_json(encode_utf8($stations)));
    }
    else {
        $self->render(json => {
            'icon'=> 'ti-home' ,
            'text'=> 'Nessuna stazione presente'
        });
    }
}

sub get_subgroup_by_id {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub get_subgroup_by_id");

    my $id = $self->param('id'); # post
    my $subgroup = $self->dbvalidazione->get_subgroup_by_id($id);

    # check result
    my $json;
    if (defined $subgroup) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            subgroup => $subgroup
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero del sottogruppo'
        };
    }

    # render
    $self->render(json => $json)
}

sub get_abnormals_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub get_abnormals_data");

    my $user_id = $self->session('it.ecometer.bobo');

    my $limits;

    # get abnormal data limit
    $limits = $self->dbvalidazione->get_abndata_limits($user_id);

    my $json;
    if (defined $limits) {
        $json = {
            res => "OK",
            limits => $limits
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

sub get_abnormals_data_by_id {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub get_abnormals_data_by_id");

    my $limit;
    my $plid = $self->param('plid'); # post

    # get abnormal data limit
    $limit = $self->dbvalidazione->get_abndata_limit_by_id($plid);

    my $json;
    if (defined $limit) {
        $json = {
            res => "OK",
            limit => $limit
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

sub get_stat_abnormals_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub get_stat_abnormals_data");

    my $limits;
    my $userid = $self->session('it.ecometer.bobo');

    # get abnormal data limit
    $limits = $self->dbvalidazione->get_stat_abndata_limits($userid);

    my $json;
    if (defined $limits) {
        $json = {
            res => "OK",
            limits => $limits
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

sub get_stat_abnormals_data_by_id {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub get_stat_abnormals_data_by_id");

    my $limit;
    my $plid = $self->param('plid'); # post

    # get abnormal data limit
    $limit = $self->dbvalidazione->get_stat_abndata_limit_by_id($plid);

    my $json;
    if (defined $limit) {
        $json = {
            res => "OK",
            limit => $limit
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

# -----------------------------------------------------------------------------
# Ajax PUT
# -----------------------------------------------------------------------------
sub put_subgroup {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub put_subgroup");
    $self->helperDumperPostData('Avavalidazione', 'put_subgroup', $self->req->body_params);

    my $user_id = $self->session('it.ecometer.bobo');
    my $table = 'validation'; # audit

    my $params = decode_json(encode_utf8($self->req->body_params->to_hash->{'params'}));
    $self->app->log->debug(Dumper($params));
    # my $table = $params->{'table'};

    my $subgroup_id = $params->{'subgroup-id'};
    my $res = 1;

    # if subgroup_id defined -> edit
    if (defined $subgroup_id && $subgroup_id ne "") {
        # log
        $self->app->log->debug("Bobo::Controller::Avavalidazione edit of subgroup");

        # store action to audit table
        $self->helperInsertUserLog('UPDATE TREE', $table, encode_json($params));

        $res = $self->dbvalidazione->update_subgroup( $params );
    }
    else { # else -> insert
        # log
        $self->app->log->debug("Bobo::Controller::Admin insert of new user");

        # store action to audit table
        $self->helperInsertUserLog('INSERT TREE', $table, encode_json($params));

        $subgroup_id = $self->dbvalidazione->insert_new_subgroup( $user_id, $params );
    }

    # check result
    if (defined $subgroup_id && $res == 1) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1)
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0)
    }
}

sub put_abnormals_limit {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub put_abnormals_limit");
    $self->helperDumperPostData('Avavalidazione', 'put_abnormals_limit', $self->req->body_params);

    my $table = 'validation'; # audit

    my $params  = $self->req->body_params->to_hash;
    $self->app->log->debug(Dumper($params));
    # my $table = $params->{'table'};

    my $plid = $params->{'abn-plid'};
    my $res = 1;

    # if plid defined -> edit
    if (defined $plid && $plid ne "") {
        # log
        $self->app->log->debug("Bobo::Controller::Avavalidazione edit of limit");

        # store action to audit table
        $self->helperInsertUserLog('UPDATE LIMIT', $table, encode_json($params));

        $res = $self->dbvalidazione->update_limit( $params );
    }
    else { # else -> insert
        # log
        $self->app->log->debug("Bobo::Controller::Avavalidazione insert of limit");

        # store action to audit table
        $self->helperInsertUserLog('INSERT LIMIT', $table, encode_json($params));

        $res = $self->dbvalidazione->insert_new_limit( $params );
    }

    # check result
    if ($res) {
        $self->app->log->debug('Result: '.$res);
        $self->render(json => $res)
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0)
    }
}

sub put_stat_abnormals_limit {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub put_stat_abnormals_limit");
    $self->helperDumperPostData('Avavalidazione', 'put_stat_abnormals_limit', $self->req->body_params);

    my $table = 'validation'; # audit

    my $params  = $self->req->body_params->to_hash;
    $self->app->log->debug(Dumper($params));
    # my $table = $params->{'table'};

    my $splid = $params->{'abn-plid'};
    my $res = 1;

    # if splid defined -> edit
    if (defined $splid && $splid ne "") {
        # log
        $self->app->log->debug("Bobo::Controller::Avavalidazione edit of limit");

        # store action to audit table
        $self->helperInsertUserLog('UPDATE STAT LIMIT', $table, encode_json($params));

        $res = $self->dbvalidazione->update_station_limit( $params );
    }
    else { # else -> insert
        # log
        $self->app->log->debug("Bobo::Controller::Avavalidazione insert of limit");

        # store action to audit table
        $self->helperInsertUserLog('INSERT STAT LIMIT', $table, encode_json($params));

        $res = $self->dbvalidazione->insert_new_station_limit( $params );
    }

    # check result
    if ($res) {
        $self->app->log->debug('Result: '.$res);
        $self->render(json => $res)
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0)
    }
}

# -----------------------------------------------------------------------------
# Ajax DEL
# -----------------------------------------------------------------------------
sub del_subgroup {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub del_subgroup");

    my $params = $self->req->body_params->to_hash;
    my $subgroup_id = $self->param('id'); # post

    $self->app->log->debug("Subgroup id: $subgroup_id");

    # store action to audit table
    my $table = 'validation'; # audit
    $self->helperInsertUserLog('DELETE TREE', $table, encode_json($params));

    my $json;
    my $res = $self->dbvalidazione->delete_subgroup($subgroup_id);

    if ($res) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

sub del_abnormals_limit {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub del_abnormals_limit");

    my $params = $self->req->body_params->to_hash;
    my $plid = $self->param('id'); # post

    $self->app->log->debug("Limit id: $plid");

    # store action to audit table
    my $table = 'validation'; # audit
    $self->helperInsertUserLog('DELETE LIMIT', $table, encode_json($params));

    my $json;
    my $res = $self->dbvalidazione->delete_limit($plid);

    if ($res) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

sub del_stat_abnormals_limit {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavalidazione sub del_stat_abnormals_limit");

    my $params = $self->req->body_params->to_hash;
    my $splid = $self->param('id'); # post

    $self->app->log->debug("Limit id: $splid");

    # store action to audit table
    my $table = 'validation'; # audit
    $self->helperInsertUserLog('DELETE STAT LIMIT', $table, encode_json($params));

    my $json;
    my $res = $self->dbvalidazione->delete_station_limit($splid);

    if ($res) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

1;

=head1 ava_validazione

Render della pagina 'Avanzate > Validazione'.

Argomenti:  /

Return:     /

=cut

=head1 get_validation_groups

Funzione per recuperare i gruppi di stazioni, visibili dall'utente loggato, disponibili
per la validazione dati.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente i gruppi, oppure un oggetto indicante 'Nessun sottogruppo'.

=cut

=head1 get_group_stations

Funzione per recuperare le stazioni appartenenti ad un determinato gruppo
visibile dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

           * id del gruppo ('grid');

           * id del nodo ('nodeid');

Return:     json contenente le stazioni, oppure un oggetto indicante 'Nessuna stazione presente'.

=cut

=head1 get_subgroup_by_id

Funzione per recuperare le informazioni relative ad un determinato sottogruppo.

Argomenti:  * id del sottogruppo ('id');

Return:     json contenente le informazioni del sottogruppo richiesto, oppure un oggetto indicante 'Errore nel recupero del sottogruppo'.

=cut

=head1 get_abnormals_data

Funzione per recuperare le informazioni relative ai limiti impostati
per i parametri presenti all'interno del sistema.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente i limiti, oppure un oggetto contenente il messaggio "ERR".

=cut

=head1 get_abnormals_data_by_id

Funzione per recuperare le informazioni relative ad un determinato limite
impostato all'interno del sistema.

Argomenti:  * id del limite ('plid');

Return:     json contenente il limite, oppure un oggetto contenente il messaggio "ERR".

=cut

=head1 get_stat_abnormals_data

Funzione per recuperare le informazioni relative ai limiti impostati
per i parametri associati ad una determinata stazione presente all'interno del sistema.

Argomenti:  * id dell'utente ('userid');

Return:     json contenente i limiti, oppure un oggetto contenente il messaggio "ERR".

=cut

=head1 get_stat_abnormals_data_by_id

Funzione per recuperare le informazioni relative ad un determinato limite
impostato per i parametri associati ad una determinata stazione
presente all'interno del sistema.

Argomenti:  * id del limite ('plid');

Return:     json contenente il limite, oppure un oggetto contenente il messaggio "ERR".

=cut

=head1 put_subgroup

Funzione per inserire/modificare un sottogruppo di stazioni da visualizzare
all'interno dell'applicativo 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * eventuale id del sottogruppo ('subgroup_id');

           * oggetto contenente le informazioni relative al sottogruppo da inserire/modificare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_abnormals_limit

Funzione per inserire/modificare un limite relativo ad un parametro di una stazione.

Argomenti:  * eventuale id del limite ('plid');

           * oggetto contenente le informazioni relative al limite da inserire/modificare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_stat_abnormals_limit

Funzione per inserire/modificare un limite relativo ad un determinato parametro
di una determinata una stazione.

Argomenti:  * eventuale id del limite ('splid');

           * oggetto contenente le informazioni relative al limite da inserire/modificare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_subgroup

Funzione per eliminare un sottogruppo di stazioni visibile
all'interno dell'applicativo 'Validazione'.

Argomenti:  * id del sottogruppo ('subgroup_id');

           * oggetto contenente le informazioni relative al sottogruppo da eliminare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_abnormals_limit

Funzione per eliminare un limite relativo ad un parametro di una stazione.

Argomenti:  * id del limite ('plid');

           * oggetto contenente le informazioni relative al limite da eliminare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_stat_abnormals_limit

Funzione per eliminare un limite relativo ad un determinato parametro
di una determinata una stazione.

Argomenti:  * id del limite ('splid');

           * oggetto contenente le informazioni relative al limite da eliminare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut