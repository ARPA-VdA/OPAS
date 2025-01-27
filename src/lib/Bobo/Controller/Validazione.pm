package Bobo::Controller::Validazione;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

sub validazione {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    my $codes = $self->dbcommon->get_final_validation_codes($user_id);
    $self->stash(codes => $codes);

    $self->helperGetPortalPageOptions();

    # Render template "dati/validazione.html.ep" with message
    $self->render('dati/validazione');
}

sub get_validation_user_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_validation_user_options");

    my $user_id = $self->session('it.ecometer.bobo');

    # get groups for the construction of the jstree
    my $options = $self->dbvalidazione->get_validation_user_options($user_id);
    my $json;

    if (defined $options) {
        $json = {
            res => "OK",
            options => decode_json(encode_utf8($options->{'option_object'}))
        };
    }
    else {
        $json = {
            res => "OK",
            options => undef
        };
    }

    # return
    $self->render(json => $json);
}

sub get_stations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_stations");

    my $user_id = $self->session('it.ecometer.bobo');

    my $prid = $self->param('prid'); # post
    $self->app->log->debug("ID provincia: $prid");

    # get stations from province
    my $stations = $self->dbvalidazione->get_stations_by_province($user_id, $prid);

    my $json = {
        res => "OK",
        stations => $stations
    };

    # render
    $self->render(json => $json);
}

sub get_validation_codes {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_validation_codes");

    # get validation codes
    my $codes = $self->dbcommon->get_validation_codes();
    my $json;

    if (defined $codes) {
        $json = {
            res => "OK",
            codes => $codes
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

sub get_validation_groups {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_validation_groups");

    my $user_id = $self->session('it.ecometer.bobo');

    # get groups for the construction of the jstree
    my $groups = $self->dbvalidazione->get_validation_groups($user_id, 1);

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
    $self->app->log->debug("Bobo::Controller::Validazione sub get_group_stations");

    # dump
    $self->helperDumper($self->req->query_params->to_hash);

    my $user_id = $self->session('it.ecometer.bobo');

    # get group id
    my $grid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    my $options = decode_json(encode_utf8($self->req->query_params->to_hash->{options}));

    $self->helperDumper($options);
    $self->app->log->debug("Got grid: $grid");

    # get stations by group id for the construction of the jstree
    my $stations = $self->dbvalidazione->get_group_stations($nodeid, $grid, $options, $user_id);

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

sub get_group_params {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_group_params");

    # dump
    $self->helperDumper($self->req->query_params->to_hash);

    my $user_id = $self->session('it.ecometer.bobo');

    # get group id
    my $grid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    my $options = decode_json(encode_utf8($self->req->query_params->to_hash->{options}));

    $self->app->log->debug("Got grid: $grid");

    # get stations by group id for the construction of the jstree
    my $params = $self->dbvalidazione->get_group_params($nodeid, $grid, $options, $user_id);

    if (defined $params) {
        $self->helperDumper(decode_json(encode_utf8($params)));
        $self->render(json => decode_json(encode_utf8($params)));
    }
    else {
        $self->render(json => {
            'icon'=> 'ti-stats-up' ,
            'text'=> 'Nessun parametro presente'
        });
    }
}

sub get_group_suspects {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_group_suspects");

    # dump
    $self->helperDumper($self->req->query_params->to_hash);

    my $user_id = $self->session('it.ecometer.bobo');

    # get group id
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    my $from = $self->req->query_params->to_hash->{from};
    my $to = $self->req->query_params->to_hash->{to};

    # get stations by group id for the construction of the jstree
    my $suspects = $self->dbvalidazione->get_group_suspects($nodeid, $user_id, $from, $to);

    if (defined $suspects) {
        # $self->helperDumper(decode_json(encode_utf8($suspects)));
        $self->render(json => decode_json(encode_utf8($suspects)));
    }
    else {
        $self->render(json => {
            'icon'=> 'ti-pin' ,
            'text'=> 'Nessun dato sospetto presente'
        });
    }
}

sub get_group_suspect_params {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_group_suspect_params");

    # dump
    $self->helperDumper($self->req->query_params->to_hash);

    my $user_id = $self->session('it.ecometer.bobo');

    # get id
    my $stid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    my $from = $self->req->query_params->to_hash->{from};
    my $to = $self->req->query_params->to_hash->{to};

    # get stations by group id for the construction of the jstree
    my $params = $self->dbvalidazione->get_group_suspect_params($stid, $nodeid, $user_id, $from, $to);

    $self->helperDumper(decode_json(encode_utf8($params)));
    $self->render(json => decode_json(encode_utf8($params)));
}

# recupero i dati di tutti i parametri associati alla stazione
sub get_all_params_data_table {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_all_params_data_table");

    my $station_id = $self->param('id'); # post
    my $date_from = $self->param('dateFrom'); # post
    my $date_to = $self->param('dateTo'); # post
    my $conv = $self->param('converted'); # post
    # my $hide_nulls = $self->param('hideNulls'); # post
    my $hide_nulls = 'false';

    $self->app->log->debug($conv);
    $conv = $conv eq 'true' ? 1 : 0;

    my $user_id = $self->session('it.ecometer.bobo');

    my $min_agg = $self->dbcommon->get_min_aggregation();
    my $grants = $self->dbcommon->get_user_station_grants($user_id, $station_id);
    my $params = $self->dbvalidazione->get_ordered_stpr_by_station($user_id, $station_id, $conv);


    my $json;
    if (@{$params}) {
        my $title = uc @{$params}[0]->{'station_name'};
        my $data = $self->dbdatamanager->get_data_station_table($min_agg->{'app_aggregation_label'}, $date_from, $date_to, $conv, $hide_nulls, $params);
        my $alarms = $self->dbdatamanager->get_station_alarms($station_id, $date_from, $date_to);

        # check result
        if ($data) {
            $self->app->log->debug('Result: OK');
            $json = {
                res => 'OK',
                title => $title,
                grants => $grants,
                params => $params,
                data => $data,
                alarms => $alarms
            };
        }
        else {
            $self->app->log->debug('Result: ERROR');
            $json = {
                res => 'ERR',
                message => 'Errore nel recupero dei dati'
            };
        }
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'ERR',
            message => 'Nessun parametro associato alla stazione'
        };
    }

    # render
    $self->render(json => $json)
}

# recupero i dati di tutte le stazioni associate al parametro
sub get_all_stations_data_table {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_all_stations_data_table");

    my $param_id = $self->param('id'); # post
    my $group_id = $self->param('grid'); # post
    my $date_from = $self->param('dateFrom'); # post
    my $date_to = $self->param('dateTo'); # post
    my $conv = $self->param('converted'); # post

    # my $hide_nulls = $self->param('hideNulls'); # post
    my $hide_nulls = 'false';

    $self->app->log->debug($conv);
    $conv = $conv eq 'true' ? 1 : 0;

    my $user_id = $self->session('it.ecometer.bobo');

    my $min_agg = $self->dbcommon->get_min_aggregation();
    my $param = $self->dbcommon->get_parameter_by_id($param_id);
    my $title = uc $param->{'parameter_name'};

    if ($conv == 1) {
        $title .= ' ['.$param->{'parameter_unit_conv'}.']';
    }
    else {
        $title .= ' ['.$param->{'parameter_unit'}.']';
    }

    my $params = $self->dbvalidazione->get_ordered_stpr_by_param($user_id, $param_id, $group_id, $conv);
    my $data = $self->dbdatamanager->get_data_station_table($min_agg->{'app_aggregation_label'}, $date_from, $date_to, $conv, $hide_nulls, $params);

    # check result
    my $json;
    if ($params && $data) {
    # if (1){
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            title => $title,
            params => $params,
            data => $data
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero dei dati'
        };
    }

    # render
    $self->render(json => $json)
}

sub get_validation_codes_bycell {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_validation_codes_bycell");

    my $fulltable = $self->param('table'); # post
    my $date = $self->param('date'); # post
    my $id = $self->param('id'); # post

    my $stprid = $self->param('stprid'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    my $codes = $self->dbdatamanager->get_val_codes_by_date_id($user_id, $fulltable, $date, $id);
    my $history = $self->dbdatamanager->get_history_by_date_id($fulltable, $date, $id, $stprid);

    # check result
    my $json;
    if (defined $codes) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            codes => $codes,
            history => $history
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero dei dati'
        };
    }

    # render
    $self->render(json => $json)
}

sub get_point_neighborhood(){
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub get_point_neighborhood");

    my $stprid = $self->param('stprid'); # post
    my $date = $self->param('date'); # post
    my $conv = $self->param('converted'); # post

    $self->app->log->debug("Converted $conv");

    my $user_id = $self->session('it.ecometer.bobo');

    my $min_agg = $self->dbcommon->get_min_aggregation();
    my $metadata = $self->dbcommon->get_all_metadata_by_stprid($user_id, $stprid);

    my $chart_data = $self->dbdatamanager->get_chart_data_neighborhood($min_agg->{'app_aggregation_label'}, $stprid, $date, $conv);
    my $table_data = $self->dbdatamanager->get_table_data_neighborhood($min_agg->{'app_aggregation_label'}, $stprid, $date, $conv, $metadata);

    # check result
    my $json;
    if (defined $chart_data && defined $table_data) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            metadata => $metadata,
            chart_data => $chart_data,
            table_data => $table_data
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero dei dati'
        };
    }

    # render
    $self->render(json => $json);
}

sub put_validation_user_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validation sub put_validation_user_options");
    $self->helperDumperPostData('Validazione', 'put_validation_user_options', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    my $options = $params->{'options'};
    my $user_id = $self->session('it.ecometer.bobo');

    my $res = 1;

    if (defined $self->dbvalidazione->get_validation_user_options($user_id)) {
        $res = $self->dbvalidazione->update_options($user_id, $options);
    }
    else {
        $res = $self->dbvalidazione->insert_options($user_id, $options);
    }

    # $self->helperDumper($data);
    my $json;

    if (defined $res) {
        $json = 1;
    }
    else {
        $json = 0;
    }

    # render
    $self->render(json => $json);
}

sub put_action_by_calendar {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub put_action_by_calendar");
    $self->helperDumperPostData('Validazione', 'put_action_by_calendar', $self->req->body_params);

    my $user_id = $self->session('it.ecometer.bobo');
    my $params = $self->req->body_params->to_hash;
    # my $table = $params->{'table'};

    my $table = 'validation'; # audit

    # store action to audit table
    $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

    my $res;

    # true validation, false operation
    if ($params->{'action_val'} eq 'true') {
        $res = $self->dbdatamanager->update_data_validation_by_calendar($user_id, $params);
    }
    else {
        $res = $self->dbdatamanager->update_data_value_by_calendar($user_id, $params);
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

sub put_cells(){
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub put_cells");
    $self->helperDumperPostData('Validazione', 'put_cells', $self->req->body_params);

    my $user_id = $self->session('it.ecometer.bobo');

    my $params = $self->req->body_params->to_hash;
    my $cells = decode_json(encode_utf8($params->{'cells'}));
    # my $table = $params->{'table'};

    $self->app->log->debug(Dumper($cells));

    my $conv = $params->{'converted'}; # post
    $conv = $conv eq 'true' ? 1 : 0;

    my $table = 'validation'; # audit

    # store action to audit table
    $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

    my $res = $self->dbdatamanager->update_data($user_id, $conv, $cells);

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

sub put_check_cells(){
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub put_check_cells");
    $self->helperDumperPostData('Validazione', 'put_cells', $self->req->body_params);

    my $user_id = $self->session('it.ecometer.bobo');

    my $params = $self->req->body_params->to_hash;

    my $from = $params->{'from'};
    my $to = $params->{'to'};
    my $cells = decode_json(encode_utf8($params->{'cells'}));

    my $table = 'validation'; # audit

    # store action to audit table
    $self->helperInsertUserLog('UPDATE CHECK', $table, encode_json($params));

    my $res = $self->dbdatamanager->update_check_data($user_id, $from, $to, $cells);

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

sub put_reset_cells(){
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazione sub put_reset_cells");
    $self->helperDumperPostData('Validazione', 'put_reset_cells', $self->req->body_params);

    my $user_id = $self->session('it.ecometer.bobo');

    my $params = $self->req->body_params->to_hash;
    my $cells = decode_json(encode_utf8($params->{'cells'}));

    my $table = 'validation'; # audit

    # store action to audit table
    $self->helperInsertUserLog('UPDATE RESET', $table, encode_json($params));

    my $res = $self->dbdatamanager->reset_cells_code($user_id, $cells);

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


1;

=head1 validazione

Render della pagina dell'applicativo Validazione.

Argomenti:  /

Return:     /

=cut

=head1 get_validation_user_options

Funzione per recuperare le impostazioni dell'utente
dello strumento Validazione.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e l'oggetto delle impostazioni relative all'utente loggato, oppure 'undef'.

=cut

=head1 get_stations

Funzione per recuperare tutte le stazioni disponibili sul portale,
eventualmente filtrate per provincia.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia, se presente ('prid');

Return:     json contenente la risposta "OK" e le stazioni.

=cut

=head1 get_validation_codes

Funzione per recuperare i codici di validazione.

Argomenti:  /

Return:     json contenente la risposta "OK" e i codici, oppure la risposta 'ERR'.

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

           * oggetto contenente le impostazioni per l'applicativo validazione ('options');

Return:     json contenente le stazioni, oppure un oggetto indicante 'Nessuna stazione presente'.

=cut

=head1 get_group_params

Funzione per recuperare i parametri appartenenti ad un determinato gruppo
visibile dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

           * id del gruppo ('grid');

           * id del nodo ('nodeid');

           * oggetto contenente le impostazioni per l'applicativo validazione ('options');

Return:     json contenente i parametri, oppure un oggetto indicante 'Nessuna parametro presente'.

=cut

=head1 get_group_suspects

Funzione per recuperare i dati sospetti visibili dall'utente loggato all'interno dello
strumento 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * id del nodo ('nodeid');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente i dati sospetti, oppure un oggetto indicante 'Nessuna dato sospetto presente'.

=cut

=head1 get_group_suspect_params

Funzione per recuperare i dati sospetti di una determinata stazione visibili dall'utente
loggato all'interno dello strumento 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * id della stazione ('stid');

           * id del nodo ('nodeid');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente i parametri, oppure un oggetto json vuoto.

=cut

=head1 get_all_params_data_table

Funzione per recuperare i dati di tutti i parametri associati ad una determinata stazione
per un determinato periodo temporale.

Argomenti:  * id della stazione ('station_id');

           * data d'inizio ('date_from');

           * data di fine ('date_to');

           * valore booleano per la conversione del parametro ('conv');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le informazioni relative ai parametri, oppure la risposta "ERR".

=cut

=head1 get_all_stations_data_table

Funzione per recuperare i dati di tutti le stazioni associate ad un determinato parametro
per un determinato periodo temporale.

Argomenti:  * id del parametro ('param_id');

           * id del gruppo ('grid');

           * data d'inizio ('date_from');

           * data di fine ('date_to');

           * valore booleano per la conversione del parametro ('conv');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le informazioni relative alle stazioni, oppure la risposta "ERR".

=cut

=head1 get_validation_codes_bycell

Funzione per recuperare i codici di validita' e lo storico delle modifiche di un determinato parametro
di una determinata stazione per una determinata data.

Argomenti:  * tabella dei dati ('fulltable');

           * data ('date');

           * id del parametro ('id');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le informazioni relative ai dati, oppure la risposta "ERR".

=cut

=head1 put_validation_user_options

Funzione per salvare le impostazioni utente personalizzate all'interno del database.

Argomenti:  * oggetto contenente le impostazioni utente ('params');

           * id dell'utente ('user_id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_action_by_calendar

Funzione per inserire un'azione di modifica/validazione, effettuata da calendario, all'interno
del database.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relativa all'azione effettuata dall'utente ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_cells

Funzione per modificare il valore di una o piu' celle presenti all'interno
dell'applicativo 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relativa alle celle modificate ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_check_cells

Funzione che gestisce la validazione finale dei dati all'interno
dell'applicativo 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relativa alle validazione ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_reset_cells

Funzione che gestisce il reset dei codici di validazione applicati ad una o piu' celle
selezionate dall'utente loggato all'interno dell'applicativo 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relativa al reset ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut
