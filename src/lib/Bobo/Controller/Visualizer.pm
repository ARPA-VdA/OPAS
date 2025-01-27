package Bobo::Controller::Visualizer;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

sub visualizer {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub visualizer");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    my $portal_groups_list = $self->dbcommon->get_portal_groups_by_user($user_id);
    $self->stash(portal_groups_list => $portal_groups_list);

    my $val_codes = $self->dbcommon->get_validation_codes();
    $self->stash(val_codes => $val_codes);

    my $aggregations = $self->dbcommon->get_aggregations($user_id);
    $self->stash(aggregations => $aggregations);

    my $treatments = $self->dbcommon->get_treatments();
    $self->stash(treatments => $treatments);

    my $categories = $self->dbvisualizer->get_categories_list($user_id);
    $self->stash(categories => $categories);

    # # -------------------------------------------------------------------------
    # # get stationid
    # # -------------------------------------------------------------------------
    # my $pgid = $self->stash->{'pgid'};

    # Render template "strumenti/analyser.html.ep" with message
    $self->render('strumenti/visualizer');
}

sub get_visualizer_user_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub get_visualizer_user_options");

    my $user_id = $self->session('it.ecometer.bobo');

    # get groups for the construction of the jstree
    my $gen_opt = $self->dbvisualizer->get_visualizer_general_options();
    my $user_opt = $self->dbvisualizer->get_visualizer_user_options($user_id);
    my $json;

    # check result
    if (defined $user_opt) {
        $json = {
            res => "OK",
            gen_opt => decode_json(encode_utf8($gen_opt->{'option_object'})),
            user_opt => decode_json(encode_utf8($user_opt->{'option_object'}))
        };
    }
    else {
        $json = {
            res => "OK",
            gen_opt => decode_json(encode_utf8($gen_opt->{'option_object'})),
            user_opt => undef
        };
    }

    # render
    $self->render(json => $json);
}

sub get_pages_by_cat {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub get_pages_by_cat");

    my $cat = $self->param('id');
    my $user_id = $self->session('it.ecometer.bobo');

    # get groups for the construction of the jstree
    my $pages = $self->dbvisualizer->get_pages_by_category($user_id, $cat);
    my $json;

    # check result
    if (defined $pages) {
        $json = {
            res => "OK",
            pages => $pages
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

sub get_groups {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub get_groups");

    my $user_id = $self->session('it.ecometer.bobo');

    # get macro groups for the construction of the jstree
    my $groups = $self->dbvisualizer->get_groups($user_id);
    $self->helperDumper($groups);

    # check result
    if (defined $groups) {
        $self->helperDumper(decode_json(encode_utf8($groups)));
        $self->render(json => decode_json(encode_utf8($groups)));
    }
    else {
        $self->render(json => {
            'icon'=> 'ti-package',
            'text'=> 'Nessuna categoria presente'
        });
    }
}

sub get_group_pages {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub get_group_pages");

    $self->helperDumper($self->req->query_params->to_hash);

    my $grid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    my $loaded = $self->req->query_params->to_hash->{loaded};
    $self->app->log->debug("Got grid: $grid");

    # get macros by category id for the construction of the jstree
    my $pages = $self->dbvisualizer->get_group_pages($nodeid, $grid, $loaded);

    # check result
    if (defined $pages) {
        $self->helperDumper(decode_json(encode_utf8($pages)));
        $self->render(json => decode_json(encode_utf8($pages)));
    }
    else {
        $self->render(json => []);
    }
}

# TODO da eliminare
# sub get_page_boxes{
#     my $self = shift;

#     $self->app->log->debug("Bobo::Controller::Visualizer sub get_page_boxes");

#     $self->helperDumper( $self->req->query_params->to_hash);

#     my $pageid = $self->req->query_params->to_hash->{id};
#     my $nodeid = $self->req->query_params->to_hash->{nodeid};
#     $self->app->log->debug("Got pageid: $pageid");

#     # get macros by category id for the construction of the jstree
#     my $box = $self->dbvisualizer->get_page_boxes($nodeid, $pageid);

#     if (defined $box) {
#         # $self->helperDumper(decode_json(encode_utf8($box)));
#         $self->render(json => decode_json(encode_utf8($box)));
#     }
#     else {
#         $self->render(json => []);
#     }
# }

sub get_page_boxes {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub get_page_boxes");

    $self->helperDumper( $self->req->query_params->to_hash);

    my $pageid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    $self->app->log->debug("Got pageid: $pageid");

    # get macros by category id for the construction of the jstree
    my $boxes = $self->dbvisualizer->get_page_boxes($nodeid, $pageid);

    # check result
    if (defined $boxes) {
        # $self->helperDumper(decode_json(encode_utf8($box)));
        $self->render(json => decode_json(encode_utf8($boxes)));
    }
    else {
        $self->render(json => []);
    }
}

sub get_macros_by_page {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub get_macros_by_page");

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

sub get_param_info {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub get_param_info");

    my $stprid = $self->param('stprid'); # post

    $self->app->log->debug("St_pr_id: $stprid");

    my $json;

    my $param = $self->dbvisualizer->get_info_param($stprid);

    # set result object
    $json = {
        res => "OK",
        param => $param
    };

    # render
    $self->render(json => $json);
}

sub get_highcharts_data_bydate {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub get_highcharts_data_bydate");

    my $macro = $self->param('macro');
    $macro = decode_json(encode_utf8($macro));
    # $self->helperDumper($macro);

    my $hide_nulls = 'false';
    my $dateFrom = $self->param('from'); # post
    my $dateTo = $self->param('to'); # post

    $self->app->log->debug("Data inizio: $dateFrom, data fine: $dateTo");

    # get data from dateFrom to dateTo
    my $json;
    my $data = $self->dbdatamanager->get_highcharts_data_by_dates($dateFrom, $dateTo, $hide_nulls, $macro);

    # check result
    if (defined $data) {
        $json = {
            res => "OK",
            data => $data
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

# TODO da eliminare
# sub get_tabulator_data{
#     my $self = shift;

#     $self->app->log->debug("Bobo::Controller::Visualizer sub get_tabulator_data");

#     my $macro = decode_json(encode_utf8($self->param('macro')));
#     my $hide_nulls = 'false';
#     my $dateFrom = $self->param('from');
#     my $dateTo = $self->param('to');
#     # my $page = $self->param('page');
#     # my $size = $self->param('size');

#     # $self->helperDumper( $page );

#     #get reports from dateFrom to dateTo
#     # my $last_page = $self->dbdatamanager->get_last_page($macro->{macro}{aggregation}, $dateFrom, $dateTo, $size);

#     # my $data = $self->dbdatamanager->get_datatable_progressive_data_by_dates_page($dateFrom, $dateTo, $hide_nulls, $macro, $page, $size);
#     my $data = $self->dbdatamanager->get_datatable_data_by_dates($dateFrom, $dateTo, $hide_nulls, $macro);

#     # $self->helperDumper( $data );
#     my $json = {
#         res => "OK",
#         data => $data,
#         # last_page => $last_page
#         # info =>
#     };

#     $self->render(json => $json);
# }

sub put_visualizer_user_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub put_visualizer_user_options");
    $self->helperDumperPostData('Visualizer', 'put_visualizer_user_options', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    my $options = $params->{'options'};
    my $user_id = $self->session('it.ecometer.bobo');

    my $res = 1;

    if (defined $self->dbvisualizer->get_visualizer_user_options($user_id)) {
        $res = $self->dbvisualizer->update_options($user_id, $options);
    }
    else {
        $res = $self->dbvisualizer->insert_options($user_id, $options);
    }

    # $self->helperDumper( $data );

    my $json;

    # check result
    if (defined $res) {
        $json = 1;
    }
    else {
        $json = 0;
    }

    # render
    $self->render(json => $json);
}

sub put_category {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub put_categories");
    $self->helperDumperPostData('Visualizer', 'put_category', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper($params);

    my $cat_id = $params->{'new-cat-id'};
    my $user_id = $self->session('it.ecometer.bobo');

    my $res = 1;

    # check 'cat_id' to either update or insert the category
    if (defined $cat_id && $cat_id ne "") {
        $res = $self->dbvisualizer->update_category($params);
    }
    else {
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

# TODO da eliminare
# sub put_macro{

#     my $self = shift;

#     $self->app->log->debug("Bobo::Controller::Visualizer sub put_macro");
#     $self->helperDumperPostData('Visualizer', 'put_macro', $self->req->body_params);

#     my $params  = $self->req->body_params->to_hash;

#     my $macro_id = $params->{'mcid'};
#     my $macro_index = $params->{'idx'};
#     my $macro = $params->{'macro'};
#     # my $macro_cat = $params->{'mccat'};
#     my $res = 1;

#     $macro_index = '{'. $macro_index .'}';

#     if (defined $macro_id && $macro_id ne "") {
#         $res = $self->dbvisualizer->update_macro($macro_id, $macro_index, $macro);
#     }
#     # else {
#     #     # associa la nuova macro alla categoria di default
#     #     $macro_id = $self->dbvisualizer->insert_macro($macro);
#     # }
#     # $self->helperDumper( $data );
#     my $json;
#     $self->app->log->debug("$res");
#     $self->app->log->debug("$macro_id");

#     if (defined $res && defined $macro_id) {
#         $json = {
#             res => "OK",
#             macro_id => $macro_id
#         };
#     }
#     else {
#         $json = {
#             res => "ERR"
#         };
#     }

#     $self->render(json => $json);
# }

sub del_category {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Visualizer sub del_category");
    $self->helperDumperPostData('Visualizer', 'del_category', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;

    my $cat_id = $self->param('id');
    my $res = 1;

    # delete category
    $res = $self->dbvisualizer->delete_category($cat_id);

    my $json;
    $self->app->log->debug("$res");

    # check result
    if ($res == 1) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

# TODO da eliminare
# sub del_macro{

#     my $self = shift;

#     $self->app->log->debug("Bobo::Controller::Visualizer sub del_macro");
#     $self->helperDumperPostData('Visualizer', 'del_macro', $self->req->body_params);

#     my $params  = $self->req->body_params->to_hash;

#     my $macro_id = $self->param('mcid');
#     my $res = 1;

#     # delete macro
#     $res = $self->dbvisualizer->delete_macro_byid($macro_id);

#     my $json;
#     $self->app->log->debug("$res");
#     $self->app->log->debug("$macro_id");

#     if (defined $res) {
#         $self->render(json => 1);
#     }
#     else {
#         $self->render(json => 0);
#     }
# }

1;

# NOT USED YET
# sub get_categories {
#     my $self = shift;
#     $self->app->log->debug("Bobo::Controller::Visualizer sub get_categories");

#     my $user_id = $self->session('it.ecometer.bobo');


#     my $categories_list =  $self->dbvisualizer->get_categories_list($user_id);
#     my $json;

#     if (defined $categories_list) {
#         $json = {
#             res => "OK",
#             categories_list => $categories_list
#         };
#     }
#     else {
#         $json = {
#             res => "ERR"
#         };
#     }

#     $self->render(json => $json);
# }

# sub get_category_byid{
#     my $self = shift;
#     $self->app->log->debug("Bobo::Controller::Visualizer sub get_category_byid");

#     my $cat_id = $self->param('id'); # post

#     $self->app->log->debug("cat_id: $cat_id");


#     my $category = $self->dbvisualizer->get_category_byid($cat_id);
#     my $json;

#     if (defined $category) {
#         $json = {
#             res => "OK",
#             category => $category
#         };
#     }
#     else {
#         $json = {
#             res => "ERR"
#         };
#     }

#     $self->render(json => $json);
# }

# sub get_pages {
#     my $self = shift;
#     $self->app->log->debug("Bobo::Controller::Visualizer sub get_pages");

#     my $user_id = $self->session('it.ecometer.bobo');

#     my $pages_list = $self->dbvisualizer->get_pages_list($user_id);
#     my $json;

#     if (defined $pages_list) {
#         $json = {
#             res => "OK",
#             pages_list => $pages_list
#         };
#     }
#     else {
#         $json = {
#             res => "ERR"
#         };
#     }

#     $self->render(json => $json);
# }

# sub get_page_byid{
#     my $self = shift;
#     $self->app->log->debug("Bobo::Controller::Visualizer sub get_page_byid");

#     my $page_id = $self->param('id'); # post

#     $self->app->log->debug("page_id: $page_id");

#     my $page = $self->dbvisualizer->get_page_byid($page_id);
#     my $json;

#     if (defined $page) {
#         $json = {
#             res => "OK",
#             page => $page
#         };
#     }
#     else {
#         $json = {
#             res => "ERR"
#         };
#     }

#     $self->render(json => $json);
# }

# TODO da eliminare
# sub get_macro_metadata{
#     my $self = shift;

#     $self->app->log->debug("Bobo::Controller::Visualizer sub get_macro_metadata");

#     my $mcid = $self->param('id'); # post

#     $self->app->log->debug("Macro id: $mcid");

#     my $json;
#     my $macro = $self->dbvisualizer->get_macro_byid($mcid);

#     # OLD
#     # $macro = $self->dbvisualizer->get_macro_info($mcid);
#     # my $params = $self->dbvisualizer->get_macro_params($mcid);
#     # $json = {
#     #     res => "OK",
#     #     macro => $macro,
#     #     params => $params
#     # };
#     $self->app->helperDumper($macro);

#     if (defined $macro) {
#         $json = {
#             res => "OK",
#             category => $macro->{'macro_page'},
#             macro => decode_json(encode_utf8($macro->{'macro_object'}))
#         };
#     }
#     else {
#         $json = {
#             res => "ERR"
#         }
#     }

#     $self->render(json => $json);
# }

=head1 visualizer

Render della pagina dell'applicativo Visualizer.

Argomenti:  /

Return:     /

=cut

=head1 get_visualizer_user_options

Funzione per recuperare le impostazioni personalizzate di un determinato utente loggato.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e gli oggetti delle impostazioni utente.

=cut

=head1 get_pages_by_cat

Funzione per recuperare le pagine visibili dall'utente loggato, eventualmente filtrate per
la categoria selezionata dall'utente sulla pagina dello strumento Visualizer.

Argomenti:  * id della categoria ('cat');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le pagine, oppure la risposta "ERR".

=cut

=head1 get_groups

Funzione per recuperare i gruppi di macro visibili dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente i gruppi, oppure un oggetto indicante 'Nessuna categoria presente'.

=cut

=head1 get_group_pages

Funzione per recuperare le informazioni necessarie a generare l'albero presente nella
pagina 'Avanzate > Visualizer' sulla sinistra.

Argomenti:  * id del gruppo ('grid');

           * id del nodo ('nodeid');

           * valore booleano ('loaded');

Return:     json contenente le macro, oppure un oggetto vuoto.

=cut

=head1 get_page_boxes

Funzione per recuperare le informazioni relative alle finestre presenti all'interno di una
determinata pagina.

Argomenti:  * id della pagina ('pageid');

           * id del nodo ('nodeid');

Return:     json contenente le finestre, oppure un oggetto vuoto.

=cut

=head1 get_macros_by_page

Funzione per recuperare le informazioni relative alle macro di una determinata finestra
visualizzabili dall'utente loggato.

Argomenti:  * id della finestra ('pgid');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le macro, oppure la risposta "ERR".

=cut

=head1 get_param_info

Funzione per recuperare le informazioni relative ad un determinato parametro di
una determinata stazione.

Argomenti:  * id dell'associazione stazione-parametro ('stprid');

Return:     json contenente la risposta "OK" e le informazioni relative al parametro.

=cut

=head1 get_highcharts_data_bydate

Funzione per recuperare i dati necessari alla creazione dei grafici Highcharts di un
determinato periodo temporale.

Argomenti:  * oggetto contenente le informazioni relative alla macro ('macro');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente la risposta "OK" e i dati Highcharts, oppure la risposta "ERR".

=cut

=head1 put_visualizer_user_options

Funzione per salvare le impostazioni utente personalizzate all'interno del database.

Argomenti:  * oggetto contenente le impostazioni utente ('params');

           * id dell'utente ('user_id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_category

Funzione per modificare/inserire una categoria.

Argomenti:  * oggetto contenente le informazioni relative alla categoria
              da modificare/inserire ('params');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e l'id della categoria modificata/inserita,
            oppure la risposta "ERR".

=cut

=head1 del_category

Funzione per eliminare una categoria.

Argomenti:  * oggetto contenente le informazioni relative alla categoria
              da eliminare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut
