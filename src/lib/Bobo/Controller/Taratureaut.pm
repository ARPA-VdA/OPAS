package Bobo::Controller::Taratureaut;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;

sub tarature_aut {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Taratureaut");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get parameters
    my $parameters = $self->dbtaratureaut->get_parameters( );
    $self->stash(parameters => $parameters);

    # Render template "dati/tarature_aut.html.ep" with message
    $self->render('dati/tarature_aut');
}

sub get_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Taratureaut sub get_data");

    my $user_id = $self->session('it.ecometer.bobo');

    my $from   = $self->param('from');   # post
    my $to     = $self->param('to');     # post
    my $netid  = $self->param('netid');  # post
    my $provid = $self->param('provid'); # post
    my $stid   = $self->param('stid');   # post
    my $prid   = $self->param('prid');   # post
    my $flag   = $self->param('flag');   # post
    my $data;

    if ($stid == -1) { # se nessuna selezione selezionata estraggo tutte le stazioni associate all'utente
        $data = $self->dbtaratureaut->get_all_data_by_dates($user_id, $from, $to, $netid, $provid, $prid, $flag);
    }
    else {
        $data = $self->dbtaratureaut->get_data_by_station_dates($stid, $from, $to, $prid, $flag);
    }

    my $json = {
        res => "OK",
        data => $data
    };

    # render
    $self->render(json => $json);
}

sub get_events {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Taratureaut sub get_events");

    my $user_id = $self->session('it.ecometer.bobo');

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post

    my $events = $self->dbtaratureaut->get_all_events_by_dates($user_id, $from, $to);

    my $json = {
        res => "OK",
        events => $events
    };

    # render
    $self->render(json => $json);
}

sub get_events_list {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Taratureaut sub get_events_list");

    my $user_id = $self->session('it.ecometer.bobo');

    my $date = $self->param('date'); # post

    my $events = $self->dbtaratureaut->get_events_list_by_date($user_id, $date);

    my $json = {
        res => "OK",
        events => $events
    };

    # render
    $self->render(json => $json);
}

sub get_chart {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Taratureaut sub get_chart");

    my $id = $self->param('id'); # post

    my $metadata = $self->dbtaratureaut->get_calibration_metadata($id);
    my $data = $self->dbtaratureaut->get_calibration_data($id);

    my $json = {
        res => "OK",
        metadata => $metadata,
        data => $data
    };

    # render
    $self->render(json => $json);
}

1;

=head1 tarature_aut

Render della pagina relativa alle tarature automatiche.

Argomenti:  /

Return:     /

=cut

=head1 get_data

Funzione per recuperare i dati relativi alle tarature automatiche, visibili dall'utente loggato,
per un determinato periodo temporale ed eventualmente filtrati per rete, provincia, stazione e parametro.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete ('netid');

           * id della provincia ('provid');

           * id della stazione ('stid');

           * id del parametro ('prid');

           * valore booleano che indica il filtro per le sole tarature che presentano un risultato ('flag');

Return:     json contenente la risposta "OK" e i dati delle tarature automatiche.

=cut

=head1 get_events

Funzione per recuperare i dati relativi agli eventi, visibili dall'utente loggato,
per un determinato periodo temporale.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente la risposta "OK" e gli eventi.

=cut

=head1 get_events_list

Funzione per recuperare la lista degli eventi, visibili dall'utente loggato,
per una determinata data.

Argomenti:  * id dell'utente ('user_id');

           * data ('date');

Return:     json contenente la risposta "OK" e la lista degli eventi.

=cut

=head1 get_chart

Funzione per recuperare il grafico relativo ad una determinata taratura automatica.

Argomenti:  * id della taratura automatica ('id');

Return:     json contenente la risposta "OK", i metadati e i dati del grafico della taratura richiesta.

=cut