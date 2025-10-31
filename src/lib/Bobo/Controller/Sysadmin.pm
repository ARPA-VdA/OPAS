package Bobo::Controller::Sysadmin;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;

sub sysadmin {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Sysadmin");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # get system admin options
    my $opt = $self->helperGetSysAdminOptions();
    $self->stash( sys_options => $opt );

    # get system emails
    my $stations = $self->dbsysadmin->get_system_stations_by_net();
    $self->stash( stations => $stations );

    # Render template "dati/statistiche.html.ep" with message
    $self->render('utente/sysadmin');
}

sub get_options{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Sysadmin sub get_options");

    # get system admin options
    my $opt = $self->dbmain->get_sys_admin_options();

    my $json = {
        res => "OK",
        opt => $opt
    };

    # render
    $self->render(json => $json);
}

sub get_system_emails{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Sysadmin sub get_system_emails");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    $self->app->log->debug("Date range: $from - $to");
    # get system admin options
    my $emails = $self->dbsysadmin->get_system_emails($from, $to);

    my $json = {
        res => "OK",
        emails => $emails
    };

    # render
    $self->render(json => $json);
}

sub put_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Sysadmin sub put_options");

    my $params  = $self->req->body_params->to_hash;

    my $obj  = $params->{'obj'}; # post

    my $res = $self->dbmain->insert_sys_admin_options($obj);

    # render
    $self->render(json => $res);
}

1;

=head1 sysadmin

Render della pagina di System Admin.

Argomenti:  /

Return:     /

=cut

=head1 get_options

Funzione per recuperare le impostazioni del System Admin.

Argomenti:  /

Return:     json contenente la risposta "OK" e le impostazioni.

=cut

=head1 get_system_emails

Funzione che recupera le email di sistema inviate dal portale in un intervallo di tempo specificato.

Argomenti:  
* from: data/ora di inizio intervallo ('from')
* to: data/ora di fine intervallo ('to')

Return:     
json contenente la risposta "OK" e la lista delle email di sistema.

=cut

=head1 put_options

Funzione per modificare le impostazioni del System Admin.

Argomenti:  * oggetto contenente le modifiche relative alle impostazioni ('obj');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut