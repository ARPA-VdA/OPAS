package Bobo::Controller::Avaanalyser;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

sub ava_analyser {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avaanalyser ava_analyser");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    my $portal_groups_list = $self->dbcommon->get_portal_groups_by_user($user_id);
    $self->stash(portal_groups_list => $portal_groups_list);

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    # Render template "dati/statistiche.html.ep" with message
    $self->render('avanzate/analyser');
}

# -----------------------------------------------------------------------------
# Ajax GET
# -----------------------------------------------------------------------------
sub get_analyser_groups {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avaanalyser sub get_analyser_groups");

    my $user_id = $self->session('it.ecometer.bobo');

    # get groups for the construction of the jstree
    my $groups = $self->dbanalyser->get_analyser_groups_no_options($user_id);

    if (defined $groups) {
        # $self->helperDumper( decode_json(encode_utf8($groups)) );
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
    $self->app->log->debug("Bobo::Controller::Avaanalyser sub get_group_stations");

    # dump
    $self->helperDumper( $self->req->query_params->to_hash);

    my $user_id = $self->session('it.ecometer.bobo');

    # get group id
    my $grid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};

    $self->app->log->debug("Got grid: $grid");

    # get stations by group id for the construction of the jstree
    my $stations = $self->dbanalyser->get_group_stations_no_options($nodeid, $grid, $user_id);

    if (defined $stations) {
        # $self->helperDumper( decode_json(encode_utf8($stations)));
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
    $self->app->log->debug("Bobo::Controller::Avaanalyser sub get_subgroup_by_id");

    my $id = $self->param('id'); # post

    my $subgroup = $self->dbanalyser->get_subgroup_by_id($id);

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

sub get_stations_by_nets {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avaanalyser sub get_stations_by_nets");

    my $user_id = $self->session('it.ecometer.bobo');

    my $prid = $self->param('prid'); # post
    my $nets = decode_json($self->param('nets'));

    $self->app->log->debug("ID provincia: $prid");
    $self->app->log->debug("Networks:". \@{$nets});

    # get stations from province/nets
    my $stations = $self->dbanalyser->get_stations_by_nets($user_id, $prid, $nets);

    my $json = {
        res => "OK",
        stations => $stations
    };

    # render
    $self->render(json => $json);
}

# -----------------------------------------------------------------------------
# Ajax PUT
# -----------------------------------------------------------------------------
sub put_subgroup {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avaanalyser sub put_subgroup");

    $self->helperDumperPostData('Avaanalyser', 'put_subgroup', $self->req->body_params);

    my $user_id = $self->session('it.ecometer.bobo');
    my $table = 'analyser'; # audit

    my $params = $self->req->body_params->to_hash;
    # $self->app->log->debug(Dumper($params));
    # {
    #   'subgroup-id' => '5',
    #   'subgroup-groups' => [
    #                          '8',
    #                          '3',
    #                          '12'
    #                        ],
    #   'subgroup-stat[]' => '1136',
    #   'subgroup-fill' => '1',
    #   'subgroup-name' => 'AppaTN'
    # };

    my $subgroup_id = $params->{'subgroup-id'};
    my $res = 1;

    # if arg_id defined -> edit report
    if (defined $subgroup_id && $subgroup_id ne "") {

        $self->app->log->debug("Bobo::Controller::Avaanalyser edit of subgroup");
        # store action to audit table
        $self->helperInsertUserLog( 'UPDATE TREE', $table, encode_json($params));

        $res = $self->dbanalyser->update_subgroup( $params );
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Avaanalyser insert of subgroup");
        # store action to audit table
        $self->helperInsertUserLog('INSERT TREE', $table, encode_json($params));

        $subgroup_id = $self->dbanalyser->insert_new_subgroup($user_id, $params);
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

# -----------------------------------------------------------------------------
# Ajax DEL
# -----------------------------------------------------------------------------
sub del_subgroup {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avaanalyser sub del_subgroup");

    my $params = $self->req->body_params->to_hash;
    my $subgroup_id = $self->param('id'); # post

    $self->app->log->debug("Subgroup id: $subgroup_id");

    # store action to audit table
    my $table = 'analyser'; # audit
    $self->helperInsertUserLog('DELETE TREE', $table, encode_json($params));

    my $json;
    my $res = $self->dbanalyser->delete_subgroup($subgroup_id);

    if ($res) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

1;

=head1 ava_analyser

Render della pagina delle impostazioni avanzate dello strumento Analyser.

Argomenti:  /

Return:     /

=cut

=head1 get_analyser_groups

Funzione per recuperare l'elenco dei sottogruppi di stazioni attualmente presenti sul portale
all'interno dello strumento Analyser.

Argomenti:  * id dell'utente ('user_id');

Return:     Render dell'oggetto json dei sottogruppi; se nessun gruppo è presente verrà visualizzato
"Nessun sottogruppo".

=cut

=head1 get_group_stations

Funzione per recuperare le stazioni appartenenti ad un determinato gruppo visibile dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

           * id del gruppo ('grid');

           * id del nodo ('nodeid');

Return:     json contenente le stazioni, oppure un oggetto indicante 'Nessuna stazione presente'.

=cut

=head1 get_subgroup_by_id

Funzione per recuperare le informazioni relative ad un determinato sottogruppo.

Argomenti:  * id del sottogruppo ('id');

Return:     json contenente il messaggio "OK" e le informazioni del sottogruppo richiesto, oppure un oggetto indicante 'Errore nel recupero del sottogruppo'.

=cut

=head1 get_stations_by_nets

Funzione per recuperare le stazioni di una determinata provincia in una o piu' reti.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia ('prid');

           * array delle reti ('nets');

Return:     json contenente le stazioni e il messaggio "OK";

=cut

=head1 put_subgroup

Funzione per inserire/modificare un sottogruppo di stazioni da visualizzare
all'interno dell'applicativo 'Analyser'.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relative al sottogruppo da inserire/modificare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_subgroup

Funzione per eliminare un sottogruppo di stazioni visibile
all'interno dell'applicativo 'Analyser'.

Argomenti:  * id del sottogruppo ('subgroup_id');

           * oggetto contenente le informazioni relative al sottogruppo da eliminare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut