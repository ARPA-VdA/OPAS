package Bobo::Controller::Angparametri;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;

sub parametri {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Angparametri");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $units = $self->dbangparametri->get_parameters_units();
    $self->stash(units => $units);

    my $types = $self->dbangparametri->get_parameters_types();
    $self->stash(types => $types);

    # Render template "utilities/faq.html.ep" with message
    $self->render('anagrafica/parametri');
}

sub get_parameters {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Angparametri sub get_parameters");

    # get points from station
    my $params = $self->dbangparametri->get_all_parameters();

    my $json;
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

sub get_parameter_by_id {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Angparametri sub get_parameter_by_id");

    # get parameter id from ajax
    my $prid = $self->param('id'); # post
    $self->app->log->debug("Parametro $prid");
    my $param = $self->dbcommon->get_parameter_by_id($prid);
    my $instr = $self->dbangparametri->get_parameter_instr_by_id($prid);

    my $json;
    if (defined $param) {
        $json = {
            res => "OK",
            param => $param,
            instr => $instr
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

sub get_parameters_by_types {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Angparametri sub get_parameters_by_types");

    # get parameter types from ajax
    my $types = $self->param('pr_ty_id'); # post

    $types = decode_json($types);

    my $param = $self->dbangparametri->get_parameters_by_types($types);

    my $json;
    if (defined $param) {
        $json = {
            res => "OK",
            params => $param
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

sub put_parameter {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Angparametri  sub put_parameter");
    $self->helperDumperPostData('Parametri', 'put_parameter', $self->req->body_params);

    my $res = 0;
    my $params = $self->req->body_params->to_hash;

    # get params from ajax
    my $prid = $params->{'param-id'};

    # if arg_id defined -> edit report
    if (defined $prid && $prid ne "") {
        $self->app->log->debug("Bobo::Controller::Angparametri edit parameter");

        # 1- parameter update on main table
        # 2- parameter update on info table
        $res = $self->dbangparametri->update_parameter($params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Angparametri insert new parameter");

        # 1- new parameter creation and returning id
        # 2- additional information's insert by returned id
        $res = $self->dbangparametri->insert_new_parameter($params);
    }

    # check result
    if ($res > 0) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => $res);
    }
}

sub del_selected_coefficient {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Angparametri sub del_selected_coefficient");

    $self->helperDumperPostData('Parametri', 'del_selected_coefficient', $self->req->body_params);

    my $params = $self->req->body_params->to_hash; # for audit
    my $id = $params->{'id'};

    my $res = $self->dbangparametri->delete_coefficient($id);

    # check result
    if ($res) {
        # return true
        $self->app->log->debug('Result: OK');
        $self->render(json => $res);
    }
    else {
        # return false
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

1;

=head1 parametri

Render della pagina di visualizzazione dei parametri.

Argomenti:  /

Return:     /

=cut

=head1 get_parameters

Funzione per recuperare tutti i parametri disponibili sul portale.

Argomenti:  /

Return:     json contenente la risposta "OK" e i parametri, se presenti,
oppure solamente la risposta "ERR".

=cut

=head1 get_parameter_by_id

Funzione per recuperare, dato l'id, le informazioni di un determinato parametro.

Argomenti:  * id del parametro ('param_id');

Return:     json contenente la risposta "OK" e i parametri, se presenti,
oppure solamente la risposta "ERR".

=cut

=head1 get_parameters_by_types

Funzione per recuperare, dati uno o piu' id di tipologie di parametro, le informazioni di una serie di parametri.

Argomenti:  * id tipologie di parametro ('pr_ty_id');

Return:     json contenente la risposta "OK" e i parametri, se presenti,
oppure solamente la risposta "ERR".

=cut

=head1 put_parameter

Funzione per inserire/modificare un determinato parametro.

Argomenti:  * id del parametro, se gia' presente ('prid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_selected_coefficient

Funzione per eliminare, dato l'id, le informazioni relative ad un determinato coefficiente
di conversione i un determinato parametro.

Argomenti:  * id del fattore di conversione ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut