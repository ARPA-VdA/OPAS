package Bobo::Controller::Options;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];
use Mojo::File 'path';

# This action will render a template
sub options {
    my $self = shift;

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    my $pages = $self->dboptions->get_pages_icon($userid);
    $self->stash(pages => $pages);

    # render
    $self->render('utente/options');
}

sub get_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Options sub get_options");

    my $userid = $self->session('it.ecometer.bobo');
    my $options = $self->dboptions->get_user_options($userid);

    my $json;
    if (defined $options) {
        $json = {
            res => 'OK',
            options => $options
        };
    }
    else {
       $self->dboptions->insert_options($userid);
       $json = {
           res => 'OK'
       };
    }

    # render
    $self->render(json => $json);
}

sub get_widget_list {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Options sub get_widget_list");

    my $userid = $self->session('it.ecometer.bobo');
    my $widgets = $self->dboptions->get_widgets($userid);

    my $json;
    if (defined $widgets) {
        $json = {
            res => 'OK',
            widgets => $widgets
        };
    }
    else {
        $json = {
            res => 'ERR'
        };
    }

    # render
    $self->render(json => $json);
}

sub put_widgets {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Options sub put_widgets");
    $self->helperDumperPostData('Options', 'put_widgets', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    my $user_id = $self->session('it.ecometer.bobo');

    my $widgets = $params->{'widgets'};
    $self->helperDumper($params);

    my $res = $self->dboptions->update_widgets($user_id, $widgets);

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

sub put_links {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Options sub put_links");
    $self->helperDumperPostData('Options', 'put_links', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    my $user_id = $self->session('it.ecometer.bobo');

    my $links = $params->{'links'};
    $self->helperDumper($params);

    my $res = $self->dboptions->update_links($user_id, $links);

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

sub put_shortcuts {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Options sub put_shortcuts");
    $self->helperDumperPostData('Options', 'put_shortcuts', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    my $user_id = $self->session('it.ecometer.bobo');

    my $shortcuts = $params->{'shortcuts'};
    # $self->helperDumper($params);

    my $res = $self->dboptions->update_shortcuts($user_id, $shortcuts);

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

=head1 options

Render della pagina di impostazioni.

Argomenti:  /

Return:     /

=cut

=head1 get_options

Funzione per recuperare le impostazioni del portale di un determinato utente.

Argomenti:  * id dell'utente ('userid');

Return:     json contenente la risposta "OK" e le impostazioni, se presenti, oppure viene effettuato
l'inserimento di un oggetto vuoto relativo alle impostazioni dell'utente e restituita la risposta "OK".

=cut

=head1 get_widget_list

Funzione per recuperare la lista dei widget di un determinato utente.

Argomenti:  * id dell'utente ('userid');

Return:     json contenente la risposta "OK" e i widget, oppure solamente la risposta "ERR".

=cut

=head1 put_widgets

Funzione per associare/modificare uno o piu' widget/s ad un determinato utente.

Argomenti:  * oggetto contenente le informazioni del/dei widget/s da associare/modificare ('params');

           * id dell'utente ('user_id');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut

=head1 put_links

Funzione per inserire/modificare uno o piu' link/s da associare/associato ad un determinato utente.

Argomenti:  * oggetto contenente le informazioni del/dei link/s da inserire/modificare ('params');

           * id dell'utente ('user_id');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut

=head1 put_shortcuts

Funzione per associare/modificare le shortcuts ad un determinato utente.

Argomenti:  * oggetto contenente le informazioni delle shortcuts da associare/modificare ('params');

           * id dell'utente ('user_id');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut