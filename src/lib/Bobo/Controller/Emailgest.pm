package Bobo::Controller::Emailgest;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;

# This action will render a template
sub emailgest {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Emailgest sub emailgest");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get companies
    my $companies = $self->dbcommon->get_companies_by_portal($user_id);
    $self->stash(companies => $companies);

    # get users
    my $users = $self->dbcommon->get_portal_users_by_user($user_id);
    $self->stash(users => $users);

    # render
    $self->render('divulgazione/emailgest');
}

sub get_mailing_lists {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Emailgest sub get_mailing_lists");

    my $user_id = $self->session('it.ecometer.bobo');

    my $lists = $self->dbemailgest->get_mailing_lists($user_id);

    my $json = {
        res => "OK",
        lists => $lists
    };

    # render
    $self->render(json => $json);
}

sub get_selected_mailing_list {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Emailgest sub get_selected_mailing_list");

    my $id = $self->param('id');

    my $list = $self->dbemailgest->get_mailing_list_byid($id);

    my $json = {
        res => "OK",
        list => $list
    };

    # render
    $self->render(json => $json);
}

sub get_external_mails {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Emailgest sub get_external_mails");

    my $user_id = $self->session('it.ecometer.bobo');

    my $mails = $self->dbemailgest->get_external_mails($user_id);

    my $json = {
        res => "OK",
        mails => $mails
    };

    # render
    $self->render(json => $json);
}

sub put_mailing_list {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Emailgest sub put_mailing_list");
    $self->helperDumperPostData('Emailgest', 'put_mailing_list', $self->req->body_params);

    my $res = 1;
    my $params = $self->req->body_params->to_hash;
    my $user_id = $self->session('it.ecometer.bobo');

    # get params from ajax
    my $mlid =  $params->{'mlist-id'};

    # if mlid defined -> edit mailing list
    if (defined $mlid && $mlid ne "") {
        $self->app->log->debug("Bobo::Controller::Emailgest edit the mailing list");

        $res = $self->dbemailgest->update_mailing_list($params);
    }
    else { # else -> insert new mailing list
        $self->app->log->debug("Bobo::Controller::Emailgest insert new mailing list");

        $mlid = $self->dbemailgest->insert_new_mailing_list($user_id, $params);
    }

    # check result
    if (defined $mlid && $res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => $res);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub put_external_mail {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Emailgest sub put_external_mail");
    $self->helperDumperPostData('Emailgest', 'put_external_mail', $self->req->body_params);

    my $res = 1;
    my $params = $self->req->body_params->to_hash;
    my $user_id = $self->session('it.ecometer.bobo');

    # get params from ajax
    my $eeid = $params->{'email-id'};

    # if eeid defined -> edit external mail
    if (defined $eeid && $eeid ne "") {
        $self->app->log->debug("Bobo::Controller::Emailgest edit the external mail");

        $res = $self->dbemailgest->update_external_mail($params);
    }
    else { # else -> insert new external mail
        $self->app->log->debug("Bobo::Controller::Emailgest insert new external mail");

        $eeid = $self->dbemailgest->insert_new_external_mail($user_id, $params);
        if ($eeid < 0) {
            $res = $eeid;
        }
    }

    # check result
    if (defined $eeid && $res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => $res);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_mailing_list {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Emailgest sub del_mailing_list");
    $self->helperDumperPostData('Emailgest', 'del_mailing_list', $self->req->body_params);

    my $mlid = $self->param('id'); # post

    $self->app->log->debug("Mailing list: $mlid");

    if ($self->dbemailgest->delete_mailing_list_by_id($mlid)) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

sub del_external_mail {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Emailgest sub del_external_mail");
    $self->helperDumperPostData('Emailgest', 'del_external_mail', $self->req->body_params);

    # my $params  = $self->req->body_params->to_hash; # for audit
    my $eeid = $self->param('id'); # post
    my $user_id = $self->session('it.ecometer.bobo');

    $self->app->log->debug("External mail: $eeid");

    if ($self->dbemailgest->delete_email_by_id($user_id, $eeid)) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

1;

=head1 emailgest

Render della pagina di visualizzazione del gestionale delle mailing list con recupero di tutti i
metadati necessari al popolamento delle select.

Argomenti:  /

Return:     /

=cut

=head1 get_mailing_lists

Funzione per recuperare le mailing list visibili all'utente.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e , se presenti, le mailing lists.

=cut

=head1 get_selected_mailing_list

Funzione per recuperare il dettaglio di una determinata mailing.

Argomenti:  * id della mailing list ('id');

Return:     json contenente la risposta "OK" e le informazioni del dettaglio.

=cut

=head1 get_external_mails

Funzione per recuperare gli indirizzi mail esterni al portale visibili all'utente.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e , se presenti, gl indirizzi esterni.

=cut

=head1 put_mailing_list

Funzione per inserire/modificare una mailing list.

Argomenti:  * id dell'utente ('user_id');

           * oggetto (serialize del form lato client) contenente le informazioni della mailing list ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_external_mail

Funzione per inserire/modificare un indirizzo mail esterno al portale.

Argomenti:  * id dell'utente ('user_id');

           * oggetto (serialize del form lato client) contenente le informazioni della mail esterna ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_mailing_list

Funzione per eliminare una determinata mailing list.

Argomenti:  * id della mailing list ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_external_mail

Funzione per eliminare una determinata mail esterna al portale.

Argomenti:  * id della mail esterna ('id');

           * id dell'utente ('user_id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut
