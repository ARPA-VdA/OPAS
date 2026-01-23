package Bobo::Model::Dbindicatori;
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

#
# GETTERS
#
sub get_runs{
    my ( $self, $user_id, $from, $to, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbindicatori sub get_runs");
    
    # query
    my $sql = qq{
        SELECT 
            run_id,
            r.us_id,
            CONCAT_WS(' ', u.us_name, u.us_2nd_name, u.us_surname)      AS us_fullname,
            TO_CHAR( COALESCE(run_update_ts, run_insert_ts) AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome', 'DD/MM/YYYY HH24:MI') AS run_insert_format,
            run_date,
            TO_CHAR(run_date, 'DD/MM/YYYY') AS run_date_format,
            r.province_id,
            p.province_code,
            run_result,
            CASE
                WHEN run_result IS TRUE THEN '<i class="fa-solid fa-check text-success"></i> Si'
                WHEN run_result IS FALSE THEN '<i class="fa-solid fa-xmark text-danger"></i> No'
                ELSE '--'
            END AS run_result_format,
            run_pdf,
            CASE
                WHEN run_pdf THEN 'report_giornaliero_'||p.province_code||'-'||run_date||'.pdf'
                ELSE '--'
            END AS run_pdf_name,
            CASE
                WHEN run_pdf THEN '/downloads/statistiche/indicatori/'||TO_CHAR(run_date, 'YYYY/MM')||'/report_giornaliero_'||p.province_code||'-'||run_date||'.pdf' 
                ELSE ''
            END AS run_pdf_path,
            run_pdf_creator,
            CONCAT_WS(' ', u2.us_name, u2.us_2nd_name, u2.us_surname)      AS run_pdf_creator_fullname,
            run_pdf_last_mod,
            COALESCE(TO_CHAR(run_pdf_last_mod AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome', 'DD/MM/YYYY HH24:MI'), '--') AS run_pdf_last_modified
            
        FROM clients_stats.runs r
        LEFT JOIN main.provinces p USING (province_id)
        LEFT JOIN bobo.users u USING (us_id)
        LEFT JOIN bobo.users u2 ON ( u2.us_id = r.run_pdf_creator )
        WHERE
            run_date BETWEEN ?::date AND ?::date
    };
    my @binds;
    push @binds, $from, $to;

    if ($prov != -1) {
        $sql .= qq{ AND province_id = ? };
        push @binds, $prov;
    }
    else{
        $sql .= qq{ AND province_id IN (
                SELECT 
                    DISTINCT smu.province_id
                FROM
                    metadata.view_stations_municipality smu
                    LEFT JOIN bobo.view_user_stations us USING (station_id)
                WHERE
                    us.user_id = ?
                    AND us.station_active IS TRUE
                    AND smu.province_id IS NOT NULL
            )
        };

        push @binds, $user_id;
    }

    $sql .= qq{
        ORDER BY 1 DESC
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes;
}


sub get_header_by_date {
    my ( $self, $user_id, $dt, $net, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbindicatori sub get_header_by_date");
    
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
                    WHEN 4 THEN 'media annuale'
                    WHEN 5 THEN 'media invernale'
                    WHEN 6 THEN 'aot40'
                    WHEN 7 THEN 'media mobile annuale'
                    ELSE NULL
                END AS stat_label,
                ARRAY_REMOVE(ARRAY_AGG( DISTINCT reporting_metric_id), NULL) AS metrics,
                ARRAY_AGG(
                    DISTINCT CASE
                        WHEN reporting_metric_id IN ('hrsAbove', '3hAbove') AND l.objective_type_id = 'INT' THEN 'n° sup info'
                        WHEN reporting_metric_id IN ('hrsAbove', '3hAbove') AND l.objective_type_id = 'ALT' THEN 'n° sup allarme'
                        WHEN reporting_metric_id IN ('hrsAbove', '3hAbove', 'daysAbove') THEN 'n° sup da inizio anno'
                        WHEN reporting_metric_id = 'daysAbove-3yr' THEN 'n° sup su 3 anni'
                        ELSE 'conc ('||limit_unit||')'
                    END
                ) AS metrics_desc
            FROM
                clients_stats.results r
                LEFT JOIN clients_stats.limits l USING (limit_id)
                LEFT JOIN clients_stats.statistics s USING (stat_id)
                LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
                LEFT JOIN metadata.stations_info sm                 USING (station_id)
                LEFT JOIN metadata.view_stations_municipality vsm   USING (station_id)
                LEFT JOIN bobo.view_user_stations vus               USING (station_id)
            WHERE
                vus.user_id = ?
                AND r.res_date = ?::date
    };

    my @binds;
    push @binds, $user_id, $dt;

    if ($net != -1) {
        $sql .= qq{ AND sm.st_info_network_type_fk = ? };
        push @binds, $net;
    }

    if ($prov != -1) {
        $sql .= qq{ AND vsm.province_id = ? };
        push @binds, $prov;
    }

    $sql .= qq{
            GROUP BY pollutant_id, stat_id
            ORDER BY pollutant_id, stat_id
        ),
        h AS (
            SELECT
                pollutant_id,

                json_agg(json_build_object(
                    'statistic', stat_label,
                    'metrics'  , CASE
                                    WHEN stat_id = 1 THEN 'conc max ('||limit_unit||')'||metrics_desc
                                    WHEN stat_id IN (2, 3) AND array_length(metrics,1) != 0 THEN 'conc ('||limit_unit||')'||metrics_desc
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
            pollutant_id,
            pollutant_notation,
            labels_obj
        FROM
            h
            LEFT JOIN infoaria.params_pollutant pp USING (pollutant_id)
            LEFT JOIN infoaria.pollutants p USING (pollutant_id)
            LEFT JOIN ( VALUES (1, 1), (10, 2), (7, 3), (8, 4), (20, 5), (5, 6), (6001, 7)) s(pollutant_id, pos) USING (pollutant_id)
        ORDER BY pos, pollutant_id;
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes;
}

sub get_data_by_date {
    my ( $self, $user_id, $dt, $net, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbindicatori sub get_data_by_date");

    # query
    my $sql = qq{
        WITH h AS(
            SELECT
                limit_id
            FROM
                clients_stats.results r
                LEFT JOIN metadata.stations_parameters sp           USING (stpr_id)
                LEFT JOIN metadata.stations_info sm                 USING (station_id)
                LEFT JOIN metadata.view_stations_municipality vsm   USING (station_id)
                LEFT JOIN bobo.view_user_stations vus               USING (station_id)
            WHERE
                vus.user_id = ?
                AND r.res_date = ?::date
    };

    my @binds;
    push @binds, $user_id, $dt;

    if ($net != -1) {
        $sql .= qq{ AND sm.st_info_network_type_fk = ? };
        push @binds, $net;
    }

    if ($prov != -1) {
        $sql .= qq{ AND vsm.province_id = ? };
        push @binds, $prov;
    }

    $sql .= qq{
            GROUP BY limit_id
        ),
        c AS (
            SELECT
                limit_id,
                station_id,
                vsm.station_name
            FROM
                h
                CROSS JOIN (
                    SELECT
                        station_id
                    FROM
                        clients_stats.results r
                        LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
                    WHERE r.res_date = ?::date
                    GROUP BY station_id
                ) AS s
                LEFT JOIN metadata.stations_info sm                 USING (station_id)
                LEFT JOIN metadata.view_stations_municipality vsm   USING (station_id)
                LEFT JOIN bobo.view_user_stations vus               USING (station_id)
            WHERE
                vus.user_id = ?
    };

    push @binds, $dt, $user_id;

    if ($net != -1) {
        $sql .= qq{ AND sm.st_info_network_type_fk = ? };
        push @binds, $net;
    }

    if ($prov != -1) {
        $sql .= qq{ AND vsm.province_id = ? };
        push @binds, $prov;
    }

    $sql .= qq{
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
            WHERE r.res_date = ?::date
        )
        SELECT
            *,
            l.lt_id,
            l.stat_id,
            CASE
                WHEN reporting_metric_id IN ('hrsAbove', '3hAbove', 'daysAbove', 'daysAbove-3yr') THEN TRUE
                ELSE FALSE
            END AS type_num_sup
        FROM
            c
            LEFT JOIN r USING (limit_id, station_id)
            LEFT JOIN clients_stats.limits l USING (limit_id)
            LEFT JOIN ( VALUES (1, 1), (10, 2), (7, 3), (8, 4), (20, 5), (5, 6), (6001, 7)) t(pollutant_id, pos) USING (pollutant_id)

        ORDER BY station_name, pos, stat_id;
    };

    push @binds, $dt;


    # return
    return $self->pg->db->query($sql, @binds)->hashes;
}

sub get_header_by_station {
    my ( $self, $from, $to, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbindicatori sub get_header_by_station");

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
                    WHEN 4 THEN 'media annuale'
                    WHEN 5 THEN 'media invernale'
                    WHEN 6 THEN 'aot40'
                    WHEN 7 THEN 'media mobile annuale'
                    ELSE NULL
                END AS stat_label,
                ARRAY_REMOVE(ARRAY_AGG( DISTINCT reporting_metric_id), NULL) AS metrics,
                ARRAY_AGG(
                    DISTINCT CASE
                        WHEN reporting_metric_id IN ('hrsAbove', '3hAbove') AND l.objective_type_id = 'INT' THEN 'n° sup info'
                        WHEN reporting_metric_id IN ('hrsAbove', '3hAbove') AND l.objective_type_id = 'ALT' THEN 'n° sup allarme'
                        WHEN reporting_metric_id IN ('hrsAbove', '3hAbove', 'daysAbove') THEN 'n° sup da inizio anno'
                        WHEN reporting_metric_id = 'daysAbove-3yr' THEN 'n° sup su 3 anni'
                        ELSE 'conc ('||limit_unit||')'
                    END
                ) AS metrics_desc
            FROM
                clients_stats.results r
                LEFT JOIN clients_stats.limits l USING (limit_id)
                LEFT JOIN clients_stats.statistics s USING (stat_id)
                LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
            WHERE
                sp.station_id = ?
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
                                    WHEN stat_id = 1 THEN 'conc max ('||limit_unit||')'||metrics_desc
                                    WHEN stat_id IN (2, 3) AND array_length(metrics,1) != 0 THEN 'conc ('||limit_unit||')'||metrics_desc
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
            pollutant_id,
            pollutant_notation,
            labels_obj
        FROM
            h
            LEFT JOIN infoaria.params_pollutant pp USING (pollutant_id)
            LEFT JOIN infoaria.pollutants p USING (pollutant_id)
            LEFT JOIN ( VALUES (1, 1), (10, 2), (7, 3), (8, 4), (20, 5), (5, 6), (6001, 7)) s(pollutant_id, pos) USING (pollutant_id)
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
                limit_id,
                MAX(station_id) AS station_id
            FROM
                clients_stats.results r
                LEFT JOIN metadata.stations_parameters sp           USING (stpr_id)
            WHERE
                sp.station_id = ?
                AND r.res_date BETWEEN ?::date AND ?::date
            GROUP BY limit_id
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
            CASE
                WHEN reporting_metric_id IN ('hrsAbove', '3hAbove', 'daysAbove', 'daysAbove-3yr') THEN TRUE
                ELSE FALSE
            END AS type_num_sup
        FROM
            c
            LEFT JOIN r USING (limit_id, res_date)
            LEFT JOIN clients_stats.limits l USING (limit_id)
            LEFT JOIN ( VALUES (1, 1), (10, 2), (7, 3), (8, 4), (20, 5), (5, 6), (6001, 7)) t(pollutant_id, pos) USING (pollutant_id)

        ORDER BY res_date DESC, pos, stat_id;
    };

    # return
    return $self->pg->db->query($sql, $stid, $from, $to, $from, $to, $stid, $from, $to)->hashes;
}

sub insert_run{
    my ( $self, $user_id, $dt, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbindicatori sub insert_run");

    # query
    my $sql = qq{
        INSERT INTO clients_stats.runs (run_date, province_id, us_id) VALUES (?, ?, ?) 
            ON CONFLICT (run_date, province_id)
            DO UPDATE SET 
                run_update_ts = CURRENT_TIMESTAMP,
                us_id = EXCLUDED.us_id;
    };

    # return
    return $self->pg->db->query($sql, $dt, $prov, $user_id);
}


sub update_run{
    my ( $self, $user_id, $dt, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbindicatori sub update_run");

    # query
    my $sql = qq{
        UPDATE clients_stats.runs 
        SET 
            run_pdf = TRUE,
            run_pdf_creator = ?,
            run_pdf_last_mod = CURRENT_TIMESTAMP 
        WHERE run_date = ?
        AND province_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $dt, $prov);
}

1;

=head1 get_runs

Funzione che recupera le esecuzioni disponibili degli indicatori per un determinato periodo temporale,
con la possibilità di filtrare i dati estratti per provincia e utente.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della provincia, se presente ('prov');

Return:     Risultato della query.

=cut

=head1 get_header_by_date

Funzione che recupera l'header della tabella che contiene le statistiche di una determinata data.

Argomenti:  * id dell'utente ('user_id');

           * data e ora ('dt');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

Return:     Risultato della query.

=cut

=head1 get_data_by_date

Funzione che recupera dal database le statistiche calcolate per una determinata data.

Argomenti:  * id dell'utente ('user_id');

           * data e ora ('dt');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

Return:     Risultato della query.

=cut

=head1 get_header_by_station

Funzione che recupera l'header della tabella che contiene le statistiche di una determinata stazione in un certo periodo temporale.


Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

Return:     Risultato della query.

=cut

=head1 get_data_by_station

Funzione che recupera dal database le statistiche di una determinata stazione e in un certo periodo temporale

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

Return:     Risultato della query.

=cut