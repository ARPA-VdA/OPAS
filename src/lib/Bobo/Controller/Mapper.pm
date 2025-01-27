package Bobo::Controller::Mapper;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;

# -----------------------------------------------------------------------------
# Main page
# -----------------------------------------------------------------------------
sub mapper {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Mapper sub mapper");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    my $station_id = $self->stash->{'stid'};

    if (defined $station_id) {
        $self->app->log->debug("Station: $station_id");
        return $self->redirect_to('/str_mapper')
            unless $self->dbcommon->check_permission_station($station_id, $user_id);
    }

    # Render template
    $self->render('strumenti/mapper');
}

# -----------------------------------------------------------------------------
# Ajax get
# -----------------------------------------------------------------------------
sub get_map_stations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Mapper sub get_map_stations");

    my $user_id = $self->session('it.ecometer.bobo');

    # get stations
    my $stations = $self->dbcommon->get_map_stations($user_id);

    # check result
    my $json;
    if ($stations) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            # message => '',
            stations => $stations
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero delle stazioni'
        };
    }

    # render
    $self->render(json => $json)
}

sub get_data_station {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Mapper sub get_data_station");

    my $stid = $self->param('id'); # post
    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $conv = $self->param('conv'); # post
    my $all = $self->param('all'); # post

    my $data = $self->dbdatamanager->get_data_station($stid, $from, $to, $conv, $all);

    # check result
    my $json;
    if ($data) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            # message => '',
            data => $data
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero delle stazioni'
        };
    }

    # render
    $self->render(json => $json)
}

sub get_inst_data_station {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Mapper sub get_inst_data_station");

    my $station_id = $self->param('id'); # post
    my $to = $self->param('to'); # post

    my $data = $self->dbdatamanager->get_inst_data_station($station_id, $to);

    # check result
    my $json;
    if ($data) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            # message => '',
            data => $data
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero delle stazioni'
        };
    }

    # render
    $self->render(json => $json);
}

sub get_windrose_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Mapper sub get_windrose_data");

    my $params = $self->req->body_params->to_hash;
    my $station_id = $params->{'id'}; # post
    my $dateFrom = $params->{'from'}; # post
    my $dateTo = $params->{'to'}; # post

    my $aggr = $self->dbcommon->get_min_aggregation();
    my $rs = $self->dbdatamanager->get_station_wind_rose_data($station_id, $dateFrom, $dateTo, $aggr->{'app_aggregation_label'});

    my @json_calma;
    my @json_debole;
    my @json_moderata;
    my @json_forte;
    my @json_molto_forte;
    my @json_totale;
    my $tot = 0;
    my $tot_calma = 0;

    foreach my $rec (@{$rs}) {
        $tot = $tot + $rec->{'totale'};
        $tot_calma = $tot_calma + $rec->{'calma'};
    }

    foreach my $rec (@{$rs}) {
        if (!defined $tot || $tot == 0) {
            $tot = 1;
        }

        # if (defined $rec->{'calma'}) {
        #     my $value = $rec->{'calma'} + 0;
        #     my $result = ($value / $tot) * 100;
        #     $self->app->log->debug("Risultato: $result");
        #     push @json_calma, sprintf("%.3f", $result) + 0; # force to number
        # }
        # else {
        #     push @json_calma, undef;
        # }
        if (defined $rec->{'debole'}) {
            my $value = $rec->{'debole'} + 0;
            my $result = ($value / $tot) * 100;
            push @json_debole, sprintf("%.3f", $result) + 0; # force to number
        }
        else {
            push @json_debole, undef;
        }

        if (defined $rec->{'moderata'}) {
            my $value = $rec->{'moderata'} + 0;
            my $result = ($value / $tot) * 100;
            push @json_moderata, sprintf("%.3f", $result) + 0; # force to number
        }
        else {
            push @json_moderata, undef;
        }

        if (defined $rec->{'forte'}) {
            my $value = $rec->{'forte'} + 0;
            my $result = ($value / $tot) * 100;
            push @json_forte, sprintf("%.3f", $result) + 0; # force to number
        }
        else {
            push @json_forte, undef;
        }

        if (defined $rec->{'molto_forte'}) {
            my $value = $rec->{'molto_forte'} + 0;
            my $result = ($value / $tot) * 100;
            push @json_molto_forte, sprintf("%.3f", $result) + 0; # force to number
        }
        else {
            push @json_molto_forte, undef;
        }

        if (defined $rec->{'totale'}) {
            push @json_totale, $rec->{'totale'} + 0; # force to number
        }
        else {
            push @json_totale, undef;
        }
    }

    # calma
    # debole
    # moderata
    # forte
    # molto_forte
    # totale

    # -------------------------------------------------------
    # RETURN
    # -------------------------------------------------------
    my $perc_calma = ($tot_calma / $tot) * 100;
    $perc_calma = sprintf("%.3f", $perc_calma) + 0;

    # json back
    $self->render(json => {
        perc_calma => $perc_calma,
        json_debole => \@json_debole,
        json_moderata => \@json_moderata,
        json_forte => \@json_forte,
        json_molto_forte => \@json_molto_forte,
        json_totale => \@json_totale
    });
}

sub get_info_station {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Mapper sub get_info_station");

    my $station_id = $self->param('id'); # post

    # get stations
    my $station = $self->dbcommon->get_station_by_id($station_id);
    my $files = undef;
    my $image = undef;

    if (defined $station->{'station_media_path'}) {
        $files = $self->helperGetStationFiles($station->{'station_media_path'});
        $image = @{$files->{'img_files'}}[0];
    }
    # $self->app->log->debug("$image");
    if (defined $image && $image =~ /.*(media.*\.(jpg|png|jpeg))/) {
        $image = "/$1";
    }
    else {
        $image= "/media/no-photo.png";
    }

    # check result
    my $json;
    if ($station) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            station => $station,
            image => $image
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero dell\'anagrafica della stazione'
        };
    }

    # render
    $self->render(json => $json)
}

1;

=head1 mapper

Render della pagina dell'applicativo Mapper.

Argomenti:  /

Return:     /

=cut

=head1 get_map_stations

Funzione per recuperare le stazioni visibili ad un determinato utente e le loro relative
informazioni utili a posizionare il marker sulla mappa presente all'interno della pagina.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e i metadati delle stazioni (se presenti), oppure la risposta "Error" e un messaggio di errore.

=cut

=head1 get_data_station

Funzione per recuperare i dati di una determinata stazione di un determinato periodo temporale.

Argomenti:  * id della stazione ('stid');

           * data d'inizio ('from');

           * data di fine ('to');

           * valore booleano che indica la conversione dei dati della stazione ('conv');

Return:     json contenente la risposta "OK" e i dati della stazione, oppure la risposta "Error" e un messaggio di errore.

=cut

=head1 get_inst_data_station

Funzione per recuperare i dati istantanei di una determinata stazione.

Argomenti:  * id della stazione ('id');

           * data di fine ('to');

Return:     json contenente la risposta "OK" e i dati della stazione, oppure la risposta "Error" e un messaggio di errore.

=cut

=head1 get_windrose_data

Funzione per recuperare i dati dei parametri del vento da un determinata stazione
in un determinato periodo temporale.

Argomenti:  * id della stazione ('id');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente i valori dei parametri.

=cut

=head1 get_info_station

Funzione per recuperare, dato l'id, le informazioni, compresa la relativa foto, di una determinata stazione.

Argomenti:  * id della stazione ('id');

Return:     json contenente, se presenti, la risposta "OK", le informazioni e il percorso dell'immagine,
oppure la risposta "Error" e un messaggio di errore.

=cut