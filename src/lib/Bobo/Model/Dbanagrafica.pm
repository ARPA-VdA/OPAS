package Bobo::Model::Dbanagrafica;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use Encode qw(encode_utf8);
use utf8;

has 'pg';
has 'app';

sub get_instruments_types_info {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanagrafica sub get_instruments_types");

    # query
    my $sql = qq{
        SELECT
            instr_type_id,
            instr_type_fullname,
            CASE
                WHEN category_id = 0 THEN 'N.d.'
                ELSE category_name
            END AS category_name,
            '--' AS measurement_type_notation,
            '--' AS method,
            '--' AS detection_limit,
            '--' AS detection_limit_unit_id
        FROM
            equipments.view_instruments_type vit
        WHERE
            instr_type_id > 0
        ORDER BY
            instr_type_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_instruments_by_types {
    my ( $self, $user_id, $from, $to, $net, $prov, $types ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanagrafica sub get_instruments_types");

    $net = ($net != -1 ? "^$net\$": ".*");
    $prov = ($prov != -1 ? "^$prov\$": ".*");

    # query
    my $sql = qq{
        SELECT
            vsi.station_id,
            vsi.station_name,
            vsi.instr_type_id,
            vsi.instrument_type_fullname,
            CONCAT_WS(
                ' - ',
                vsi.instrument_name,
                vsi.instrument_arpa_id,
                vsi.instrument_serial_num
            ) AS instrument_identifier,
            vsi.station_instr_startup_date AS location_start,
            CASE
                WHEN vsi.station_instr_dismiss_date = 'infinity' THEN 'infinito'
                WHEN vsi.station_instr_dismiss_date IS NULL THEN '--'
                ELSE TO_CHAR(vsi.station_instr_dismiss_date, 'DD/MM/YYYY HH24:MI')
            END AS location_end,
            vsi.station_instr_master,
            COALESCE(vsi.instrument_note, '--') AS instrument_note
        FROM
            metadata.view_stations_instruments vsi
            LEFT JOIN metadata.stations_info si USING (station_id)
            LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
        WHERE
            station_id IN (
                SELECT station_id
                FROM bobo.view_user_stations
                WHERE user_id = ?
            )
            AND tsrange(?::timestamp, ?::timestamp, '[]') && tsrange(station_instr_startup_date, station_instr_dismiss_date, '[]')
            AND si.st_info_network_type_fk::text ~ ?
            AND vsm.province_id::text ~ ?
            AND instr_type_id = ANY(?)

        ORDER BY
            station_id;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to, $net, $prov, \@{$types})->hashes();
}

sub get_parameters_by_id {
    my ( $self, $user_id, $net, $prov, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanagrafica sub get_parameters_by_id");

    $net = ($net != -1 ? "^$net\$": ".*");
    $prov = ($prov != -1 ? "^$prov\$": ".*");

    # query
    my $sql = qq{
        SELECT
            sp.stpr_id,
            sp.param_id,
            CONCAT_WS(' - ', p.param_name, sp.stpr_note) AS param_name,
            p.param_unit,
            p.param_unit_conv,
            sp.stpr_table_id,
            sp.stpr_group_id,
            sp.stpr_active,
            vsi.station_id,
            vsi.station_name,
            vsi.station_active,
            vsi.station_network_type_desc,
            vsi.station_network_type_name
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.view_stations_info vsi USING (station_id)
            LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
        WHERE
            station_id IN (
                SELECT station_id
                FROM bobo.view_user_stations
                WHERE user_id = ?
            )
            AND vsi.station_network_type_id::text ~ ?
            AND vsm.province_id::text ~ ?
            AND sp.param_id = ANY(?)
        ORDER BY
            station_id;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $net, $prov, \@{$params})->hashes();
}

sub get_operations_by_id {
    my ( $self, $instr ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanagrafica sub get_operations_by_id");

    # query
    my $sql = qq{
        SELECT
            in_op_id,
            vio.category_id,
            vio.category_name,
            instr_type_id,
            instr_type_fullname,
            op_id,
            operation_description,
            operation_category_desc,
            freq_id,
            frequency_desc,
            frequency_label,
            frequency_db
        FROM equipments.view_instruments_operations vio
        LEFT JOIN equipments.view_instruments_type vit USING (instr_type_id)
        WHERE (
            vio.category_id = (
                SELECT category_id
                FROM equipments.instruments_type
                WHERE instr_type_id = ?
            ) AND instr_type_id IS NULL
        )
        OR (instr_type_id = ?)
        ORDER BY operation_description;
    };

    # return
    return $self->pg->db->query($sql, $instr, $instr)->hashes();
}


1;

=head1 get_instruments_types_info

Funzione che recupera tutte le informazioni riguardo alle tipologie
di strumenti dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_instruments_by_types

Funzione che recupera, dati un periodo temporale e ,
tutti gli strumenti disponibili dal database, eventualmente filtrati per rete e provincia,
visibili dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete ('net');

           * id della provincia ('prov');

           * oggetto contenente le tipologie di strumento ('types');

Return:     Risultato della query.

=cut

=head1 get_parameters_by_id

Funzione per recuperare tutti i parametri disponibili sul portale, eventualmente
filtrati per tipologia, rete e provincia.

Argomenti:  * id dell'utente ('user_id');

           * id della rete ('net');

           * id della provincia ('prov');

           * oggetto contenente le tipologie di parametro ('params');

Return:     json contenente la risposta "OK" e i parametri, oppure la risposta "ERR".

=cut

=head1 get_operations_by_id

Funzione per recuperare le operazioni disponibili per una determinata
tipologia di strumento sul portale.

Argomenti:  * id della tipologia di strumento ('instr');

Return:     Risultato della query.

=cut