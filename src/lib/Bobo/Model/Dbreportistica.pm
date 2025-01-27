package Bobo::Model::Dbreportistica;

use Data::Dumper;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use utf8;

has 'pg';
has 'app';

# Getters
# -----------------------------------------------------------------------------
sub get_zones {
    my ($self, $user_id) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbreportistica sub get_zones");

    # query
    my $sql = qq{
        SELECT
            sz_id,
            sz_name
        FROM
            clients_stats.stations_zones
        WHERE
            -- portal_id = 4 -- FVG
            portal_id = (
                SELECT portal_id FROM bobo.users_metadata WHERE us_id = ?
            )
            AND sz_active IS TRUE
        ORDER BY
            sz_order ASC;
    };

    # return
    $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_stations_by_zone {
    my ( $self, $zone ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbreportistica sub get_stations_by_zone");

    # query
    my $sql = qq{
        WITH s AS (
            SELECT
                UNNEST(station_ids) AS station_id
            FROM
                clients_stats.stations_zones
            WHERE
                sz_id = ?
        )
        SELECT
            station_id,
            station_name
        FROM
            s
            LEFT JOIN metadata.stations st USING (station_id)
        ORDER BY
            station_name;
    };

    # return
    return $self->pg->db->query($sql, $zone)->hashes;
}

sub get_parameters_by_zone {
    my ( $self, $zone ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbreportistica sub get_parameters_by_zone");

    # query
    my $sql = qq{
        WITH s AS (
            SELECT
                UNNEST(station_ids) AS station_id
            FROM
                clients_stats.stations_zones
            WHERE
                sz_id = ?
        )
        SELECT
            param_id,
            param_name
        FROM
            s
            LEFT JOIN metadata.stations st USING (station_id)
            LEFT JOIN metadata.stations_parameters sp USING (station_id)
            LEFT JOIN metadata.parameters p USING (param_id)
        WHERE
            param_id IN (
                50, -- PM10
                48, -- PM2.5
                30, -- NOx
                31, -- NO
                32, -- NO2
                34, -- O3
                38, -- Benzene
                39, -- Toluene
                41, -- Ethylbenzene
                29, -- SO2
                45, -- M&P-xylene
                42, -- O-xylene
                35, -- IPA
                33, -- CO
                37  -- H2S
            )
        GROUP BY
            param_id, param_name
        ORDER BY
            param_name;
    };

    # return
    return $self->pg->db->query($sql, $zone)->hashes;
}

sub get_reports {
    my ( $self, $user_id, $from, $to, $type, $zone ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbreportistica sub get_reports");

    $type = ($type != -1 ? "^$type\$": ".*");
    $zone = ($zone != -1 ? "^$zone\$": ".*");

    # query
    my $sql = qq{
        SELECT
            r.rep_id       ,
            r.rt_id        ,
            rt.rt_name     ,
            rt.rt_icon     ,
            rt.rt_color    ,
            r.sz_id        ,
            sz.sz_id       ,
            sz.sz_name     ,
            sz.sz_code     ,
            r.param_id     ,
            p.param_name   ,
            r.rep_date     ,
            CASE
                WHEN r.rt_id = 1 THEN TO_CHAR(r.rep_date, 'DD/MM/YYYY')
                WHEN r.rt_id = 2 THEN TO_CHAR(r.rep_date, 'MM/YYYY')
                WHEN r.rt_id = 3 THEN TO_CHAR(r.rep_date, 'YYYY')
                ELSE TO_CHAR(r.rep_date, 'DD/MM/YYYY')
            END AS rep_date_formatted,
            r.rep_signer   ,
            CONCAT_WS(' ', u1.us_name, u1.us_2nd_name, u1.us_surname) AS signer_fullname,
            u1.us_avatar_thumb AS signer_avatar_thumb,

            r.rep_note     ,
            r.rep_file_name,
            r.rep_insert_ts AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome' AS rep_insert_ts,
            r.us_id,
            CONCAT_WS(' ', u2.us_name, u2.us_2nd_name, u2.us_surname) AS user_fullname,
            u2.us_avatar_thumb AS user_avatar_thumb
        FROM
            clients_stats.reports r
            LEFT JOIN clients_stats.report_types rt USING (rt_id)
            LEFT JOIN clients_stats.stations_zones sz USING (sz_id)
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN bobo.users u1 ON (u1.us_id = r.rep_signer)
            LEFT JOIN bobo.users u2 ON (u2.us_id = r.us_id)
        WHERE
            sz.portal_id = (
                SELECT portal_id FROM bobo.users_metadata WHERE us_id = ?
            )
            AND tsrange(?::timestamp, ?::timestamp, '[]') && (
                CASE
                    WHEN r.rt_id = 1 THEN tsrange(r.rep_date, r.rep_date + interval '1 day' - interval '1 minute', '[]')
                    WHEN r.rt_id = 2 THEN tsrange(r.rep_date, r.rep_date + interval '1 month' - interval '1 minute', '[]')
                    WHEN r.rt_id = 3 THEN tsrange(r.rep_date, r.rep_date + interval '1 year' - interval '1 minute', '[]')
                    ELSE tsrange(r.rep_date, r.rep_date + interval '1 day' - interval '1 minute', '[]')
                END
            )

            AND r.rt_id::text ~ ?
            AND r.sz_id::text ~ ?
        ORDER BY
            r.rep_insert_ts DESC;
    };

    # return
    return $self->pg->db->query(
        $sql,
        $user_id,
        $from, $to,
        $type,
        $zone
    )->hashes;
}

sub get_header_by_station {
    my ( $self, $from, $to, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbreportistica sub get_header_by_station");

    # query
    my $sql = qq{
        WITH t AS(
            SELECT
                l.pollutant_id,
                l.stat_id,
                MAX(l.limit_unit) AS limit_unit,
                CASE l.stat_id
                    WHEN 1 THEN 'media oraria'
                    WHEN 2 THEN 'media 24 ore'
                    WHEN 3 THEN 'max media di 8 ore'

                    ELSE NULL
                END AS stat_label,
                ARRAY_REMOVE(ARRAY_AGG( DISTINCT reporting_metric_id), NULL) AS metrics,
                ARRAY_AGG(
                    DISTINCT 'conc ('||limit_unit||')'
                ) AS metrics_desc
            FROM
                clients_stats.results r
                LEFT JOIN clients_stats.limits l USING (limit_id)
                LEFT JOIN clients_stats.statistics s USING (stat_id)
                LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
            WHERE
                sp.station_id = ?
                AND l.stat_id IN (1,2,3)
                AND r.res_date BETWEEN ?::date AND ?::date

            GROUP BY pollutant_id, stat_id
            ORDER BY pollutant_id, stat_id
        ),
        h AS (
            SELECT
                pollutant_id,

                json_agg(json_build_object(
                    'statistic', stat_label,
                    'metrics'  , CASE
                                    WHEN stat_id = 1 THEN ARRAY['conc max ('||limit_unit||')']
                                    WHEN stat_id IN (2, 3) AND array_length(metrics,1) != 0 THEN metrics_desc
                                    ELSE metrics_desc
                                END
                )) AS labels_obj
            FROM
                t
            WHERE
                stat_label NOTNULL
            GROUP BY pollutant_id
        )
        SELECT
            p.pollutant_id,
            pa.param_name,
            labels_obj
        FROM
            h
            LEFT JOIN infoaria.params_pollutant pp USING (pollutant_id)
            LEFT JOIN metadata.parameters pa USING (param_id)
            LEFT JOIN infoaria.pollutants p USING (pollutant_id)
            LEFT JOIN ( VALUES
                            (   5,  1), -- PM10
                            (6001,  2), -- PM2.5
                            (   9,  3), -- NOx
                            (  38,  4), -- NO
                            (   8,  5), -- NO2
                            (   7,  6), -- O3
                            (  20,  7), -- Benzene
                            (  21,  8), -- Toluene
                            ( 431,  9), -- Ethylbenzene
                            (   1, 10), -- SO2
                            ( 464, 11), -- M&P-xylene
                            ( 482, 12), -- O-xylene
                            (  30, 13), -- IPA
                            (  10, 14), -- CO
                            (  11, 15)  -- H2S
                        ) s(pollutant_id, pos) USING (pollutant_id)
        ORDER BY pos, pollutant_id;
    };

    # return
    return $self->pg->db->query($sql, $stid, $from, $to)->hashes;
}

sub get_data_by_station {
    my ( $self, $from, $to, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbindicatori sub get_data_by_station");

    # query
    my $sql = qq{
        WITH h AS(
            SELECT
                MIN(limit_id) AS limit_id,
                MAX(station_id) AS station_id
            FROM
                clients_stats.results r
                LEFT JOIN clients_stats.limits l  USING (limit_id)
                LEFT JOIN metadata.stations_parameters sp           USING (stpr_id)
            WHERE
                sp.station_id = ?
                AND r.res_date BETWEEN ?::date AND ?::date
            GROUP BY
                l.pollutant_id, l.stat_id
        ),
        c AS (
            SELECT
                limit_id,
                res_date
            FROM
                h
                CROSS JOIN (
                    SELECT
                        res_date
                    FROM generate_series
                    ( ?::timestamp
                    , ?::timestamp
                    , '1 day'::interval) s(res_date)
                ) AS s
        ),
        r AS (
            SELECT
                res_date,
                sp.station_id,
                stpr_id,
                limit_id,
                res_value,
                res_exceed_value,
                res_num_sup,
                res_exceed_num_sup,
                res_perc_valid,
                res_aggrules
            FROM clients_stats.results r
            LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
            WHERE
                sp.station_id = ?
                AND r.res_date BETWEEN ?::date AND ?::date
        )
        SELECT
            *,
            l.lt_id,
            l.stat_id,
            FALSE AS type_num_sup
        FROM
            c
            LEFT JOIN r USING (limit_id, res_date)
            LEFT JOIN clients_stats.limits l USING (limit_id)
            LEFT JOIN ( VALUES
                        (   5,  1), -- PM10
                        (6001,  2), -- PM2.5
                        (   9,  3), -- NOx
                        (  38,  4), -- NO
                        (   8,  5), -- NO2
                        (   7,  6), -- O3
                        (  20,  7), -- Benzene
                        (  21,  8), -- Toluene
                        ( 431,  9), -- Ethylbenzene
                        (   1, 10), -- SO2
                        ( 464, 11), -- M&P-xylene
                        ( 482, 12), -- O-xylene
                        (  30, 13), -- IPA
                        (  10, 14), -- CO
                        (  11, 15)  -- H2S
                    ) t(pollutant_id, pos) USING (pollutant_id)
        WHERE
            l.stat_id IN (1,2,3)
        ORDER BY res_date DESC, pos, stat_id;
    };

    # return
    return $self->pg->db->query($sql, $stid, $from, $to, $from, $to, $stid, $from, $to)->hashes;
}

sub get_header_by_type {
    my ( $self, $type, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbreportistica sub get_header_by_type");

    # query
    my $sql = qq{
        SELECT
            rts.rts_id,
            rts.rt_id,
            rts.rs_id,
            rs.rs_name,
            rs.rs_label,
            rts.rts_threshold

        FROM
            clients_stats.report_type_stats rts
            LEFT JOIN clients_stats.report_stats rs USING (rs_id)
        WHERE
            portal_id = (
                SELECT portal_id FROM bobo.users_metadata WHERE us_id = ?
            )
            AND rts.rt_id = ? -- Mensile / Annuale
            AND rts_active IS TRUE
        ORDER BY
            rts_order;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $type)->hashes;
}

sub get_data_by_type {
    my ( $self, $type, $params, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbindicatori sub get_data_by_type");

    # query
    my $sql = qq{
        SELECT
            s.station_id,
            s.station_name,
            ARRAY_AGG(rr.rr_result ORDER BY rts_order) AS results,
            ARRAY_AGG(rr.rr_overcoming ORDER BY rts_order) AS overcomings

        FROM
            clients_stats.report_type_stats rts
            LEFT JOIN clients_stats.report_stats rs USING (rs_id)
            LEFT JOIN clients_stats.report_results rr USING (rt_id, rs_id)
            LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
            LEFT JOIN metadata.stations s USING (station_id)
        WHERE
            portal_id = (
                SELECT portal_id FROM bobo.users_metadata WHERE us_id = ?
            )
            AND rts.rt_id = ? -- Mensile / Annuale
            AND rts.rts_active IS TRUE
            AND sp.station_id IN (
                SELECT UNNEST(station_ids)
                FROM clients_stats.stations_zones
                WHERE sz_id = ?
            )
            AND sp.param_id = ?
            AND rr.rr_date = ?::date
        GROUP BY
            s.station_id, s.station_name, sp.stpr_group_id
        ORDER BY
            s.station_name, sp.stpr_group_id;
    };

    # return
    return $self->pg->db->query(
        $sql,
        $user_id,
        $type,
        $params->{'zone'},
        $params->{'prid'},
        $params->{'date'}
    )->hashes;
}

sub check_data {
    my ( $self, $user_id, $zone, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbreportistica sub check_data");

    # query
    my $sql = qq{
        SELECT clients_stats.f_check_data( ?::integer , ?::integer , ?::timestamp, ?::timestamp) AS res
    };

    # return
    return $self->pg->db->query($sql, $user_id, $zone, $from, $to)->hash->{'res'};
}

sub insert_report {
    my ( $self, $user_id, $dt, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbreportistica sub insert_report");

    # query
    my $sql = qq{
        INSERT INTO clients_stats.reports
            (
                rt_id, sz_id, param_id, rep_date,
                rep_signer, rep_note, us_id
            )
        VALUES
            (
                ?, ?, ?, ?,
                ?, ?, ?
            )
        ON CONFLICT ON CONSTRAINT clients_stats_reports_ukey
        DO UPDATE SET
            rep_signer    = EXCLUDED.rep_signer,
            rep_note      = EXCLUDED.rep_note,
            us_id         = EXCLUDED.us_id,
            rep_insert_ts = CURRENT_TIMESTAMP
        RETURNING
            rep_id;
    };

    # return
    return $self->pg->db->query(
        $sql,
        $params->{'stats-type'},
        $params->{'stats-zone'},
        $params->{'stats-param'} == -1 ? undef : $params->{'stats-param'},
        $self->app->helperGetFormattedFulldate($dt),
        $params->{'stats-signature'} == -1 ? undef : $params->{'stats-signature'},
        $self->app->helperEscapeParam($params->{'stats-note'}),
        $user_id
    )->hash->{'rep_id'};
}

sub delete_report_by_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbreportistica sub delete_report_by_id");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;
        # ##################################################################
        # 1- eliminazione del report
        # ##################################################################

        # query
        my $sql = qq{
            DELETE FROM clients_stats.reports
            WHERE rep_id = ?;
        };

        $self->pg->db->query($sql, $rpid);
    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return 0;
    }
    else {
       $tx->commit;
       return 1;
    }
}

1;

=head1 get_zones

Funzione che recupera le zone visibili dall'utente loggato dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_stations_by_zone

Funzione che recupera, dato l'id di una zona, le informazioni delle stazioni associate dal database.

Argomenti:  * id della zona ('zone');

Return:     Risultato della query;

=cut

=head1 get_parameters_by_zone

Funzione che recupera, dato l'id di una zona, le informazioni dei parametri analizzati
dalle relative stazioni associate dal database.

Argomenti:  * id della zona ('zone');

Return:     Risultato della query;

=cut

=head1 get_reports

Funzione che recupera, dato un certo periodo temporale, tutti i relativi report,
eventualmente filtrati per tipologia e zona, dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della tipologia, se presente ('type');

           * id della zona, se presente ('zone');

Return:     Risultato della query.

=cut

=head1 get_header_by_station

Funzione che recupera l'header della tabella che contiene le statistiche
di una determinata stazione in un certo periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

Return:     Risultato della query.

=cut

=head1 get_data_by_station

Funzione che recupera dal database le statistiche di una determinata stazione
e in un certo periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

Return:     Risultato della query.

=cut

=head1 get_header_by_type

Funzione che recupera l'header della tabella che contiene le statistiche
di una determinata tipologia dal database.

Argomenti:  * id della tipologia ('type');

           * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_data_by_type

Funzione che recupera i dati relative alle statistiche, di una determinata tipologia,
richieste dall'utente loggato dal database.

Argomenti:  * id della tipologia ('type');

           * oggetto contenente le informazioni necessarie all'estrapolazione dei dati ('params');

           * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 check_data

Funzione che gestisce il controllo dei dati al fine di produrre il report statistiche richiesto.

Argomenti:  * id dell'utente ('user_id');

           * id della zona ('zone');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     Risultato della verifica dei dati;

=cut

=head1 insert_report

Funzione che inserisce un nuovo report nel database.

Argomenti:  * id dell'utente ('user_id');

           * data/ora ('dt');

           * oggetto contenente le informazioni del report da inserire ('params');

Return:     Se tutto OK, restituisce l'id del report appena inserito;

        Se KO, restituisce undef.

=cut


=head1 delete_report_by_id

Funzione che elimina, dato l'id, un determinato report dal database.

Argomenti:  * id del report ('rpid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut