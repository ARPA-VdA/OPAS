package Bobo::Controller::Diagnostici;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;

sub diagnostici {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Diagnostici");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # Render template "dati/diagnostici.html.ep" with message
    $self->render('dati/diagnostici');
}

sub get_diags_data {
    my $self = shift;
    $self->app->log->debug("Bobo::Controller::Diagnostici sub get_diags_data");

    my $user_id = $self->session('it.ecometer.bobo');

    my $date_from = $self->param('from'); # post
    my $date_to = $self->param('to'); # post
    my $stid = $self->param('stid'); # post

    $self->app->log->debug("Stazione: $stid");

    # get stations from province
    my $station = $self->dbcommon->get_station_by_id($stid);
    my $diags = $self->dbdiagnostici->get_active_diags_by_stid($station->{'main_station_fulltable'}, $date_from, $date_to);

    my $data = [];
    if (scalar @{$diags} > 0) {
        $data = $self->dbdiagnostici->get_data_diags_by_station($station->{'main_station_fulltable'}, $date_from, $date_to, $diags);
    }

    my $json = {
        res => "OK",
        diags => $diags,
        data => $data
    };

    # render
    $self->render(json => $json);
}

1;

=head1 diagnostici

Render della pagina di visualizzazione dei diagnostici.

Argomenti:  /

Return:     /

=cut

=head1 get_diags_data

Funzione per recuperare i diagnostici di una determinata stazione
e in un determinato periodo temporale.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

Return:     json contenente la risposta "OK", i diagnostici e i dati di quest'ultimi.

=cut