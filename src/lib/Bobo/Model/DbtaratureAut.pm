package Bobo::Model::DbtaratureAut;
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

# http://mojolicious.org/perldoc/Mojo/Pg
# http://mojolicious.org/perldoc/Mojo/Pg/Results
# http://mojolicious.org/perldoc/Mojo/Collection

# Getters
# -----------------------------------------------------------------------------

sub get_parameters {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbtaratureAut sub get_parameters");

    # query
    my $sql = qq{
        SELECT *
        FROM clients.view_calibration_parameters;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_all_data_by_dates {
    my ( $self, $user_id, $from, $to, $netid, $provid, $prid, $flag ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbtaratureAut sub get_all_data_by_dates");

    $netid  = ($netid != -1 ? "^$netid\$": ".*");
    $provid = ($provid != -1 ? "^$provid\$": ".*");
    $prid   = ($prid != -1 ? "^$prid\$": ".*");

    # query
    my $sql = qq{
        WITH gp AS (
            SELECT
                stpr_group_id, TRUE AS exception_flag
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.parameters p USING (param_id)
            WHERE
                stpr_group_id NOTNULL
            GROUP BY
                stpr_group_id
            HAVING
                ARRAY_AGG(param_name) && '{"NH3", "TNx", "Toluene", "Ethylbenzene"}'::text[]
        ),
        t AS (
            SELECT
                cr.calibration_id,
                cr.calibration_date_time,
                cr.station_id,
                st.station_name,
                si.st_info_network_type_fk,
                pm.province_id,
                cr.measure_id,
                p.param_id,
                p.param_name || COALESCE(' - '::text || sp.stpr_note, ''::text) AS param_name,
                p.param_unit,
                p.param_conv,
                p.param_unit_conv,
                p.param_decimals,
                cr.calibration_type,
                cr.calibration_step,
                cr.reference_value,
                cr.defect_value,
                    CASE
                        WHEN cr.calibration_step = 'ZERO'::text THEN cr.defect_value::text ||' '||p.param_unit
                        ELSE cr.defect_value::text || ' %'::text
                    END AS calibration_defect,
                cr.result_code,
                CASE
                    WHEN gp.exception_flag IS TRUE AND p.param_name = ANY (ARRAY['NO'::text, 'Benzene'::text]) THEN clients.f_calibration_result_tostring(cr.result_code::integer, cr.calibration_step)
                    WHEN gp.exception_flag IS NOT TRUE AND p.param_name NOT IN ('NO', 'NO2') THEN  clients.f_calibration_result_tostring(cr.result_code::integer, cr.calibration_step)
                    ELSE ''::text
                END AS result_code_string,
                cr.result_value
            FROM
                clients.calibrations_result cr
                LEFT JOIN metadata.stations_parameters sp ON (cr.station_id = sp.station_id AND cr.measure_id = sp.stpr_table_id )
                LEFT JOIN gp ON (gp.stpr_group_id = sp.stpr_group_id )
                LEFT JOIN metadata.stations st ON ( cr.station_id = st.station_id )
                LEFT JOIN metadata.stations_info si ON ( cr.station_id = si.station_id )
                LEFT JOIN metadata.stations_municipality sm ON ( cr.station_id = sm.station_id )
                LEFT JOIN main.province_municipalities pm USING (mu_id)
                LEFT JOIN metadata.parameters p USING (param_id)

            WHERE
                cr.station_id IN (SELECT station_id FROM bobo.view_user_stations WHERE user_id = ?)
                AND calibration_date_time BETWEEN ?::timestamp AND ?::timestamp
                
        )
        SELECT *
        FROM t
        WHERE 
            st_info_network_type_fk::text ~ ?
            AND province_id::text ~ ?
            AND param_id::text ~ ?
    };

    if ($flag eq 'true') {
        $sql .= qq{
            AND result_code_string != ''
        }
    }

    $sql .= qq{ ORDER BY calibration_date_time DESC; };

    # return
    return $self->pg->db->query($sql, 
        $user_id,
        $from, $to, 
        $netid, $provid, $prid,  
    )->hashes();
}

sub get_data_by_station_dates {
    my ( $self, $stid, $from, $to, $prid, $flag ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbtaratureAut sub get_data_by_station_dates");

    $prid = ($prid != -1 ? "^$prid\$": ".*");

    # query
    my $sql = qq{
        WITH gp AS (
            SELECT
                stpr_group_id, 
                TRUE AS exception_flag
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.parameters p USING (param_id)
            WHERE
                stpr_group_id NOTNULL
                AND station_id = ?
            GROUP BY
                stpr_group_id
            HAVING
                ARRAY_AGG(param_name) && '{"NH3", "TNx", "Toluene", "Ethylbenzene"}'::text[]
        ),
        t AS (
            SELECT
                cr.calibration_id,
                cr.calibration_date_time,
                cr.station_id,
                st.station_name,
                cr.measure_id,
                p.param_id,
                p.param_name || COALESCE(' - '::text || sp.stpr_note, ''::text) AS param_name,
                p.param_unit,
                p.param_conv,
                p.param_unit_conv,
                p.param_decimals,
                cr.calibration_type,
                cr.calibration_step,
                cr.reference_value,
                cr.defect_value,
                    CASE
                        WHEN cr.calibration_step = 'ZERO'::text THEN cr.defect_value::text ||' '||p.param_unit
                        ELSE cr.defect_value::text || ' %'::text
                    END AS calibration_defect,
                cr.result_code,
                CASE
                    WHEN gp.exception_flag IS TRUE AND p.param_name = ANY (ARRAY['NO'::text, 'Benzene'::text]) THEN clients.f_calibration_result_tostring(cr.result_code::integer, cr.calibration_step)
                    WHEN gp.exception_flag IS NOT TRUE AND p.param_name NOT IN ('NO', 'NO2') THEN  clients.f_calibration_result_tostring(cr.result_code::integer, cr.calibration_step)
                    ELSE ''::text
                END AS result_code_string,
                cr.result_value
            FROM
                clients.calibrations_result cr 
                LEFT JOIN metadata.stations_parameters sp ON (cr.station_id = sp.station_id AND cr.measure_id = sp.stpr_table_id )
                LEFT JOIN gp ON (gp.stpr_group_id = sp.stpr_group_id )
                LEFT JOIN metadata.stations st ON ( st.station_id = sp.station_id )
                LEFT JOIN metadata.parameters p USING (param_id)
            WHERE
                cr.station_id = ?
                AND cr.calibration_date_time BETWEEN ?::timestamp AND ?::timestamp
        )
        SELECT *
        FROM t
        WHERE param_id::text ~ ?
    };

    if ($flag eq 'true') {
        $sql .= qq{
            AND result_code_string != ''
        }
    }

    $sql .= qq{ ORDER BY calibration_date_time DESC; };

    # return
    return $self->pg->db->query($sql, $stid, $stid, $from, $to, $prid )->hashes();
}

sub get_all_events_by_dates {
    my ( $self, $user_id, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbtaratureAut sub get_all_events_by_dates");

    # query
    my $sql = qq{
        SELECT
            calibration_date_time::date     AS events_date,
            COUNT(DISTINCT(calibration_id)) AS events_num
        FROM
            clients.calibrations_result cr
            LEFT JOIN bobo.view_user_stations us USING (station_id)
        WHERE
            calibration_date_time::date BETWEEN ?::date AND ?::date
            AND us.user_id = ?
        GROUP BY calibration_date_time::date;
    };

    # return
    return $self->pg->db->query($sql, $from, $to, $user_id)->hashes();
}

sub get_events_list_by_date {
    my ( $self, $user_id, $date ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbtaratureAut sub get_events_list_by_date");

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT DISTINCT ON (cr.calibration_id, cr.station_id)
                cr.calibration_id,
                cr.station_id,
                TO_CHAR(MIN(cr.calibration_date_time), 'HH24:MI') AS calibration_time,
                MIN(p.param_id) AS param_id
            FROM
                clients.calibrations_result cr
                LEFT JOIN metadata.stations_parameters sp ON cr.station_id = sp.station_id AND cr.measure_id = sp.stpr_table_id
                LEFT JOIN metadata.parameters p USING (param_id)
            WHERE calibration_date_time::date = ?
            GROUP BY cr.calibration_id, cr.station_id
        )
        SELECT *
        FROM
            temp
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN bobo.view_user_stations us USING (station_id)
        WHERE
            us.user_id = ?
        ORDER BY calibration_time;
    };

    # return
    return $self->pg->db->query($sql, $date, $user_id)->hashes();
}

sub get_calibration_metadata {
    my ( $self, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbtaratureAut sub get_calibration_metadata");

    # query
    my $sql = qq{
        SELECT DISTINCT ON (measure_id)
            station_name,
            COALESCE(param_name, 'sconosciuto') AS param_name,
            COALESCE(param_unit, '--')          AS param_unit
        FROM clients.view_calibrations_data
        WHERE calibration_id = ?
        ORDER BY measure_id;
    };

    # return
    return $self->pg->db->query($sql, $id)->hashes();
}

sub get_calibration_data {
    my ( $self, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbtaratureAut sub get_calibration_data");

    # query
    my $sql = qq{
        SELECT
            measure_id, calibration_date_time, measure_value, calibration_step
        FROM
            clients.view_calibrations_data
        WHERE calibration_id = ?
        ORDER BY measure_id, calibration_date_time;
    };

    # return
    return $self->pg->db->query($sql, $id)->hashes();
}

1;

=head1 get_parameters

Funzione che recupera dal database i parametri per cui è possibile effettuare una taratura automatica.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_all_data_by_dates

Funzione che recupera dal database i dati relativi alle tarature automatiche, visibili dall'utente loggato,
per un determinato periodo temporale ed eventualmente filtrati per rete, provincia e parametro.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete ('netid');

           * id della provincia ('provid');

           * id del parametro ('prid');

           * valore booleano che indica il filtro per le sole tarature che presentano un risultato ('flag');

Return:     Risultato della query.

=cut

=head1 get_data_by_station_dates

Funzione che recupera dal database i dati relativi alle tarature automatiche effettuate in una determinata stazione,
per un determinato periodo temporale ed eventualmente filtrati per parametro.

Argomenti:  * id della stazione ('stid');

           * data d'inizio ('from');

           * data di fine ('to');

           * id del parametro ('prid');

           * valore booleano che indica il filtro per le sole tarature che presentano un risultato ('flag');

Return:     Risultato della query.

=cut

=head1 get_all_events_by_dates

Funzione che recupera dal database i dati relativi agli eventi, visibili dall'utente loggato,
per un determinato periodo temporale.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     Risultato della query.

=cut

=head1 get_events_list_by_date

Funzione che recupera dal database la lista degli eventi, visibili dall'utente loggato,
per una determinata data.

Argomenti:  * id dell'utente ('user_id');

           * data ('date');

Return:     Risultato della query.

=cut

=head1 get_calibration_metadata

Funzione che recupera dal database i metadati di una determinata taratura automatica,
necessari alla creazione del relativo grafico.

Argomenti:  * id della taratura automatica ('id');

Return:     Risultato della query.

=cut

=head1 get_calibration_data

Funzione che recupera dal database i dati effettivi di una determinata taratura automatica,
necessari alla creazione del relativo grafico.

Argomenti:  * id della taratura automatica ('id');

Return:     Risultato della query.

=cut