package Bobo::Controller::Avavisualizer;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

sub ava_visualizer {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    my $portal_groups_list = $self->dbcommon->get_portal_groups_by_user($user_id);
    $self->stash(portal_groups_list => $portal_groups_list);

    my $categories = $self->dbvisualizer->get_categories_list($user_id);
    $self->stash(categories => $categories);

    # parameters types
    my $types = $self->dbangparametri->get_parameters_types();
    $self->stash(types => $types);

    my $instr_categories = $self->dbcommon->get_equipments_categories();
    $self->stash(instr_categories => $instr_categories);

    # Render template "avanzate/visualizer.html.ep" with message
    $self->render('avanzate/visualizer');
}

# -----------------------------------------------------------------------------
# Ajax GET
# -----------------------------------------------------------------------------
sub get_form_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub get_form_options");

    my $json;

    my $user_id = $self->session('it.ecometer.bobo');

    # get provinces
    my $val_codes = $self->dbcommon->get_validation_codes();
    my $aggregations = $self->dbcommon->get_aggregations($user_id);
    my $treatments = $self->dbcommon->get_treatments();
    my $parameters = $self->dbvisualizer->get_all_stations_params_by_province($user_id, -1, -1);

    $json = {
        res => "OK",
        val_codes    => $val_codes,
        aggregations => $aggregations,
        treatments   => $treatments,
        parameters   => $parameters
    };

    # render
    $self->render(json => $json);
}

sub get_categories {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub get_categories");

    my $user_id = $self->session('it.ecometer.bobo');

    my $categories_list = $self->dbvisualizer->get_categories_list($user_id);
    my $json;

    # check result
    if (defined $categories_list) {
        $json = {
            res => "OK",
            categories_list => $categories_list
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

sub get_category_byid {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub get_category_byid");

    my $cat_id = $self->param('id'); # post

    $self->app->log->debug("cat_id: $cat_id");

    my $category =  $self->dbvisualizer->get_category_byid($cat_id);
    my $json;

    # check result
    if (defined $category) {
        $json = {
            res => "OK",
            category => $category
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

sub get_parameters_by_stations_types {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub get_parameters_by_stations_types");

    my $stid = $self->param('stid'); # post
    my $types = $self->param('types'); # post
    my $cat = $self->param('cat'); # post

    $stid = decode_json(encode_utf8($stid));
    $types = decode_json(encode_utf8($types));

    my $params;

    # get stations from province
    if (scalar @{$stid} > 0) {
        $params = $self->dbvisualizer->get_all_stations_params_by_types($stid, $types, $cat);
    }
    else {
        $params = $self->dbvisualizer->get_all_params_by_types($types, $cat);
    }

    my $json = {
        res => "OK",
        params => $params
    };

    # render
    $self->render(json => $json);
}

sub get_parameters {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub get_parameters");

    my $user_id = $self->session('it.ecometer.bobo');

    my $net = $self->param('net'); # post
    my $prid = $self->param('prid'); # post
    my $stid = $self->param('stid'); # post

    $stid = decode_json(encode_utf8($stid));

    $self->app->log->debug("ID network: $net");
    $self->app->log->debug("ID provincia: $prid");

    my $params;

    # get stations from province
    if (scalar @{$stid} > 0) {
        $params = $self->dbvisualizer->get_all_stations_params($stid);
    }
    else {
        # get params from network and province
        $params = $self->dbvisualizer->get_all_stations_params_by_province($user_id, $net, $prid);
    }

    my $json = {
        res => "OK",
        params => $params
    };

    # render
    $self->render(json => $json);
}

sub get_params_info {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub get_params_info");

    my $stprid = $self->param('stprid'); # post
    my $conv = $self->param('conv'); # post
    $stprid = decode_json(encode_utf8($stprid));

    $self->app->log->debug("St_pr_id: $stprid");

    my $json;

    my $params = $self->dbvisualizer->get_info_params($conv, $stprid);

    $json = {
        res => "OK",
        params => $params
    };

    # render
    $self->render(json => $json);
}

sub get_macros_by_page {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub get_macros_by_page");

    my $pgid = $self->param('id'); # post
    my $user_id = $self->session('it.ecometer.bobo');

    $self->app->log->debug("Page id: $pgid");

    my $json;
    my $macros = $self->dbvisualizer->get_macros_by_page($pgid, $user_id);

    # $self->app->helperDumper($macros);

    # check result
    if (defined $macros) {
        $json = {
            res => "OK",
            macros => $macros
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

sub get_automatic_macros {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub get_automatic_macros");

    $self->helperDumperPostData('Avavisualizer', 'get_automatic_macros', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper( $params );

    my $macros = $self->dbvisualizer->get_automatic_macros($params);

    my $json;

    # check result
    if (defined $macros) {
        $json = {
            res => "OK",
            macros => $macros
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
sub put_category {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub put_categories");

    $self->helperDumperPostData('Avavisualizer', 'put_category', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper( $params );

    my $cat_id = $params->{'new-cat-id'};
    my $user_id = $self->session('it.ecometer.bobo');

    my $res = 1;

    # store action to audit table
    my $table = 'visualizer';

    # check 'cat_id' to either update or insert the category
    if (defined $cat_id && $cat_id ne "") {
        $self->helperInsertUserLog( 'UPDATE CAT', $table, encode_json($params));
        $res = $self->dbvisualizer->update_category($params);
    }
    else {
        $self->helperInsertUserLog('INSERT CAT', $table, encode_json($params));
        $cat_id = $self->dbvisualizer->insert_category($user_id, $params);
    }

    # $self->helperDumper( $data );

    my $json;

    $self->app->log->debug("$res");
    # $self->app->log->debug("$cat_id");

    # check result
    if (defined $res && defined $cat_id) {
        $json = {
            res => "OK",
            cat_id => $cat_id
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

sub put_page_macros {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub put_page_macros");

    $self->helperDumperPostData('Avavisualizer', 'put_page_macros', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    my $table = 'visualizer';

    my $page_id = $params->{'id'};
    my $page_name = $params->{'name'};
    my $page_cat = $params->{'cat'};
    my $page_boxes = $params->{'boxes'};

    my $res = 1;

    # FIRST STEP: INSERT OR UPDATE OF THE PAGE
    if (defined $page_id && $page_id ne "") {
        # store action to audit table
        $self->helperInsertUserLog('UPDATE PAGE', $table, encode_json($params));

        $res = $self->dbvisualizer->update_page($page_id, $page_name, $page_cat);
    }
    else {
        # store action to audit table
        $self->helperInsertUserLog('INSERT PAGE', $table, encode_json($params));

        $page_id = $self->dbvisualizer->insert_page($page_name, $page_cat);
    }

    # SECOND STEP: INSERT OF BOXES
    if (defined $res && defined $page_id) {
        $res = $self->dbvisualizer->insert_boxes($page_id, $page_boxes);
    }

    my $json;

    # check result
    if ($res) {
        $json = {
            res => 'OK',
            id  => $page_id
        };

        $self->render(json => $json);
    }
    else {
        $json = {
            res => 'ERR'
        };

        $self->render(json => $json);
    }
}

sub put_page_duplication {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub put_page_duplication");

    my $pgid = $self->param('id'); # post

    $self->app->log->debug("Page id: $pgid");

    my $res = $self->dbvisualizer->insert_page_duplication($pgid);

    # render
    $self->render(json => $res);
}

# -----------------------------------------------------------------------------
# Ajax DEL
# -----------------------------------------------------------------------------
sub del_category {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub del_category");
    $self->helperDumperPostData('Avavisualizer', 'del_category', $self->req->body_params);

    my $params  = $self->req->body_params->to_hash;

    my $cat_id = $self->param('id');
    my $res = 1;

    # store action to audit table
    my $table = 'visualizer';
    $self->helperInsertUserLog('DELETE CAT', $table, encode_json($params));

    # delete macro
    $res = $self->dbvisualizer->delete_category($cat_id);

    my $json;
    $self->app->log->debug("$res");

    # check result
    if ($res == 1) {
        $self->render(json => 1 );
    }
    else {
        $self->render(json => 0);
    }
}

sub del_page {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Avavisualizer sub del_page");

    my $params = $self->req->body_params->to_hash;
    my $pgid = $self->param('id'); # post

    $self->app->log->debug("Page id: $pgid");

    # store action to audit table
    my $table = 'visualizer';
    $self->helperInsertUserLog('DELETE PAGE', $table, encode_json($params));

    my $json;
    my $res = $self->dbvisualizer->delete_page($pgid);

    $self->app->log->debug("RISULTATO: $res");
    $self->render(json => $res);
}

1;

=head1 ava_visualizer

Render della pagina 'Avanzate > Visualizer'.

Argomenti:  /

Return:     /

=cut

=head1 get_form_options

Funzione per recuperare le opzioni principali di personalizzazione delle finestre di Visualizer,
in base ai permessi di visibilita' dell'utente loggato.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le impostazioni.

=cut

=head1 get_categories

Funzione per recuperare le categorie, in base ai permessi di visibilita' dell'utente loggato.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e la lista delle categorie, oppure la risposta "ERR".

=cut

=head1 get_category_byid

Funzione per recuperare, dato l'id, le informazioni relative ad una determinata categoria.

Argomenti:  * id della categoria ('cat_id');

Return:     json contenente la risposta "OK" e la lista delle categorie, oppure la risposta "ERR".

=cut

=head1 get_parameters_by_stations_types

Funzione per recuperare le informazioni relative ai parametri di determinate stazioni,
filtrati eventualmente per tipologia e categoria di strumento che li acquisisce.

Argomenti:  * array degli id delle stazioni ('stid');

           * array degli id delle tipologie di parametro ('types');

           * categoria di strumento ('cat');

Return:     json contenente la risposta "OK" e le informazioni relative ai parametri.

=cut

=head1 get_parameters

Funzione per recuperare le informazioni relative ai parametri di determinate stazioni,
filtrati eventualmente per rete e provincia.

Argomenti:  * id dell'utente ('user_id');

           * id della rete ('net');

           * id della provincia ('prid');

           * array degli id delle stazioni ('stid');

Return:     json contenente la risposta "OK" e le informazioni relative ai parametri.

=cut

=head1 get_params_info

Funzione per recuperare, dati gli id, le informazioni relative a dei determinati parametri
di determinate stazioni.

Argomenti:  * oggetto contenente gli id delle associazioni stazione-parametro ('stprid');

           * valore booleano relativo alla conversione dei parametri ('conv');

Return:     json contenente la risposta "OK" e le informazioni relative ai parametri.

=cut

=head1 get_macros_by_page

Funzione per recuperare, dato l'id di una pagina, le relative macro, visibili
dall'utente loggato.

Argomenti:  * id della pagina ('pg_id');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le macro, oppure la risposta "ERR".

=cut

=head1 get_automatic_macros

Funzione che recupera i metadati necessari alla generazione automatica delle macro.

Argomenti:  * oggetto contenente i metadati ('params');

Return:     json contenente la risposta "OK" e le macro, oppure la risposta "ERR".

=cut

=head1 put_category

Funzione per modificare/inserire una categoria.

Argomenti:  * oggetto contenente le informazioni relative alla categoria
              da modificare/inserire ('params');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e l'id della categoria modificata/inserita,
            oppure la risposta "ERR".

=cut

=head1 put_page_macros

Funzione per modificare/inserire una pagina e le sue relative finestre.

Argomenti:  * oggetto contenente le informazioni relative alla pagina
              da modificare/inserire ('params');

Return:     json contenente la risposta "OK" e l'id della pagina modificata/inserita,
            oppure la risposta "ERR".

=cut

=head1 put_page_duplication

Funzione per inserire una nuova pagina, duplicata da una gia' esistente.

Argomenti:  * id della pagina da duplicare ('pgid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_category

Funzione per eliminare una categoria.

Argomenti:  * oggetto contenente le informazioni relative alla categoria
              da eliminare ('params');

           * id della categoria ('cat_id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_page

Funzione per eliminare una pagina.

Argomenti:  * oggetto contenente le informazioni relative alla pagina
              da eliminare ('params');

           * id della pagina ('pgid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut