package Bobo::Model::Dbalims;
use Mojo::Base -base;

# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text
use utf8;

use Data::Dumper;
use Mojo::JSON qw (decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

has 'pg';
has 'app';

sub get_stations_by_province {
    my ( $self, $user_id, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_stations_by_province");

    $prov = ($prov != -1 ? "^$prov\$": ".*");

    # query
    my $sql = qq{
        SELECT
            sm.station_id,
            sm.station_name,
            sm.station_active,
            sm.station_shortname,
            sm.station_longname,
            sm.station_north_utm,
            sm.station_east_utm,
            sm.station_altitude,
            sm.station_lat_wgs84,
            sm.station_lon_wgs84,
            sm.station_network_type_id,
            sm.station_network_type_desc
        FROM
            metadata.view_stations_info sm
            LEFT JOIN bobo.view_user_stations us USING(station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
            AND smu.province_id::text ~ ?
            AND sm.station_active IS TRUE
            AND sm.station_network_type_id NOTNULL
            AND sm.station_export_id NOTNULL
        ORDER BY
            sm.station_network_type_id, sm.station_name;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $user_id, $prov)->hashes;
}

sub get_arguments {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_arguments");

    # query
    my $sql = qq{
        SELECT
            arg_id,
            arg_desc
        FROM client_lig_alims.arguments
        ORDER BY arg_desc;
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_analytics {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_analytics");

    # query
    my $sql = qq{
        SELECT
            ana_id,
            ana_desc
        FROM client_lig_alims.analytics
        WHERE ana_active IS TRUE
        ORDER BY ana_desc;
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_reports_by_date_province {
    my ( $self, $user_id, $from, $to, $prid, $pack ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_reports_by_date_province");

    # query
    my $sql = qq{
        SELECT
            r.rep_id                               AS report_id  ,
            r.rep_seq                              AS report_seq,
            r.rep_fulldate                         AS report_fulldate,
            TO_CHAR(r.rep_fulldate, 'DD/MM/YYYY HH24:MI') AS report_fulldate_formatted,
            r.rep_number                           AS report_number,
            r.rep_pdf                              AS report_pdf,
            r.rep_sent                             AS report_sent,
            COALESCE(TO_CHAR(r.rep_sent_ts at time zone 'UTC' at time zone 'Europe/Rome', 'DD/MM/YYYY HH24:MI'), '--')
                                                   AS report_sent_ts,
            CASE
                WHEN r.analisys_receive_ts NOTNULL THEN TRUE
                ELSE FALSE
            END                                    AS report_received,
            r.rep_multi_filters                    AS report_multi_filters,
            -- analytic
            r.ana_ids                              AS analytics_id,
            array_to_string( ARRAY(
                SELECT ana_desc
                FROM client_lig_alims.analytics
                WHERE ana_id = ANY(r.ana_ids)
            ), ', ')                               AS analytics_desc,
            -- (
            --     SELECT COUNT(*)
            --     FROM client_lig_alims.filters f
            --     WHERE f.rep_id = r.rep_id
            -- )                                       AS report_filter_number,
            (
                SELECT COUNT(*)
                FROM client_lig_alims.filters f
                WHERE f.rep_id = r.rep_id
                AND f.filter_cancelled IS FALSE
            )                                       AS report_num_valid,
            (
                SELECT COUNT(*)
                FROM client_lig_alims.filters f
                WHERE f.rep_id = r.rep_id
                AND f.filter_cancelled IS TRUE
            )                                       AS report_num_cancelled,
            -- station
            vsm.province_name                       AS province_name,
            r.station_id                            AS station_id,
            s.station_name                          AS station_name,
            -- user
            r.us_id                                 AS user_id,
            u.us_name || ' '
            || COALESCE(u.us_2nd_name, ''::text)
            || u.us_surname                         AS user_fullname,
            u.us_avatar                             AS user_avatar,
            u.us_avatar_thumb                       AS user_avatar_thumb,
            -- instrument
            r.instr_id                              AS instr_id        ,
            i.instr_type_id                         AS instr_type_id   ,
            CASE
                WHEN it.instr_type_id = 0 THEN 'Stazione'
                ELSE c.constr_name||' '
                    ||b.brand_name||' '
                    ||m.model_name
            END                                     AS instr_type_fullname  ,
            i.instr_arpa_id    ,
            i.instr_serial_num ,
            i.instr_name
        FROM
            client_lig_alims.reports r
            LEFT JOIN metadata.stations s                       USING (station_id)
            LEFT JOIN bobo.users u                              USING (us_id)
            LEFT JOIN equipments.instruments i                  USING (instr_id)
            LEFT JOIN equipments.instruments_type it            USING (instr_type_id)
            LEFT JOIN equipments.constructors c                 USING (constr_id)
            LEFT JOIN equipments.brands b                       USING (brand_id)
            LEFT JOIN equipments.models m                       USING (model_id)
            LEFT JOIN metadata.view_stations_municipality vsm   USING (station_id)
            LEFT JOIN bobo.view_user_stations vus               USING (station_id)
        WHERE
            vus.user_id = ?

        AND r.rep_fulldate BETWEEN ?::timestamp AND ?::timestamp
    };

    # check province id
    if ($prid != -1) {
        $sql .= qq{ AND vsm.province_id = $prid }
    }

    # check analytic pack id
    if ($pack != -1) {
        $sql .= qq{ AND $pack = ANY(r.ana_ids) }
    }

    $sql .= qq{
        ORDER BY r.rep_fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes;
}

sub get_reports_by_date_station {
    my ( $self, $from, $to, $stid, $pack ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_reports_by_date_station");

    # query
    my $sql = qq{
        SELECT
            r.rep_id                               AS report_id  ,
            r.rep_seq                              AS report_seq,
            r.rep_fulldate                         AS report_fulldate,
            TO_CHAR(r.rep_fulldate, 'DD/MM/YYYY HH24:MI') AS report_fulldate_formatted,
            r.rep_number                           AS report_number,
            r.rep_pdf                              AS report_pdf,
            r.rep_sent                             AS report_sent,
            COALESCE(TO_CHAR(r.rep_sent_ts at time zone 'UTC' at time zone 'Europe/Rome', 'DD/MM/YYYY HH24:MI'), '--')
                                                   AS report_sent_ts,
            CASE
                WHEN r.analisys_receive_ts NOTNULL THEN TRUE
                ELSE FALSE
            END                                    AS report_received,
            r.rep_multi_filters                    AS report_multi_filters,
            -- analytic
            r.ana_ids                              AS analytics_id,
            array_to_string( ARRAY(
                SELECT ana_desc
                FROM client_lig_alims.analytics
                WHERE ana_id = ANY(r.ana_ids)
            ), ', ')                               AS analytics_desc,
            -- (
            --     SELECT COUNT(*)
            --     FROM client_lig_alims.filters f
            --     WHERE f.rep_id = r.rep_id
            -- )                                       AS report_filter_number,
            (
                SELECT COUNT(*)
                FROM client_lig_alims.filters f
                WHERE f.rep_id = r.rep_id
                AND f.filter_cancelled IS FALSE
            )                                       AS report_num_valid,
            (
                SELECT COUNT(*)
                FROM client_lig_alims.filters f
                WHERE f.rep_id = r.rep_id
                AND f.filter_cancelled IS TRUE
            )                                       AS report_num_cancelled,
            -- station
            vsm.province_name                       AS province_name,
            r.station_id                            AS station_id,
            s.station_name                          AS station_name,
            -- user
            r.us_id                                 AS user_id,
            u.us_name || ' '
            || COALESCE(u.us_2nd_name, ''::text)
            || u.us_surname                         AS user_fullname,
            u.us_avatar                             AS user_avatar,
            u.us_avatar_thumb                       AS user_avatar_thumb,
            -- instrument
            r.instr_id                              AS instr_id        ,
            i.instr_type_id                         AS instr_type_id   ,
            CASE
                WHEN it.instr_type_id = 0 THEN 'Stazione'
                ELSE c.constr_name||' '
                    ||b.brand_name||' '
                    ||m.model_name
            END                                     AS instr_type_fullname  ,
            i.instr_arpa_id    ,
            i.instr_serial_num ,
            i.instr_name
        FROM
            client_lig_alims.reports r
            LEFT JOIN metadata.stations s                       USING (station_id)
            LEFT JOIN metadata.view_stations_municipality vsm   USING (station_id)
            LEFT JOIN bobo.users u                              USING (us_id)
            LEFT JOIN equipments.instruments i                  USING (instr_id)
            LEFT JOIN equipments.instruments_type it            USING (instr_type_id)
            LEFT JOIN equipments.constructors c                 USING (constr_id)
            LEFT JOIN equipments.brands b                       USING (brand_id)
            LEFT JOIN equipments.models m                       USING (model_id)
        WHERE
            r.rep_fulldate BETWEEN ?::timestamp AND ?::timestamp
            AND r.station_id = ?
    };

    if ($pack != -1) {
        $sql .= qq{ AND $pack = ANY(r.ana_ids) }
    }

    $sql .= qq{
        ORDER BY r.rep_fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $from, $to, $stid)->hashes;
}

sub get_report_by_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_report_by_id");

    # query
    my $sql = qq{
        SELECT
            r.rep_id           ,
            r.rep_seq          ,
            r.rep_fulldate     ,
            r.rep_number       ,
            TO_CHAR(r.rep_insert_ts at time zone 'UTC' at time zone 'Europe/Rome', 'DD/MM/YYYY HH24:MI') AS rep_insert_ts,
            r.rep_pdf          ,
            r.rep_sent         ,
            COALESCE(TO_CHAR(r.rep_sent_ts at time zone 'UTC' at time zone 'Europe/Rome', 'DD/MM/YYYY HH24:MI'), '--') AS rep_sent_ts,
            CASE
                WHEN r.analisys_receive_ts NOTNULL THEN TRUE
                ELSE FALSE
            END                                     AS rep_received,
            COALESCE(TO_CHAR(r.analisys_receive_ts at time zone 'UTC' at time zone 'Europe/Rome', 'DD/MM/YYYY HH24:MI'), '--') AS analisys_receive_ts,
            r.rep_multi_filters,
            -- argument
            r.arg_id                                AS argument_id,
            a.arg_desc                              AS argument_desc,
            -- analytic
            r.ana_ids                               AS analytics_id,
            ARRAY(
                SELECT ana_desc
                FROM client_lig_alims.analytics
                WHERE ana_id = ANY(r.ana_ids)
            )                                       AS analytics_desc,
            array_to_string(ARRAY
                (
                    SELECT ana_desc
                    FROM client_lig_alims.analytics
                    WHERE ana_id = ANY(r.ana_ids)
                ), ', '::text
            )                                       AS analytics_desc_str,
            -- station
            r.station_id                            AS station_id,
            s.station_name                          AS station_name,
            vsm.province_id,
            vsm.province_name,
            -- user
            r.us_id                                 AS user_id,
            u.us_name || ' '
            || COALESCE(u.us_2nd_name, ''::text)
            || u.us_surname                         AS user_fullname,
            u.us_avatar                             AS user_avatar,
            u.us_avatar_thumb                       AS user_avatar_thumb,
            -- instrument
            r.instr_id                              AS instr_id        ,
            i.instr_type_id                         AS instr_type_id   ,
            CASE
                WHEN it.instr_type_id = 0 THEN 'Stazione'
                ELSE c.constr_name||' '
                    ||b.brand_name||' '
                    ||m.model_name
            END                                     AS instr_type_fullname  ,
            i.instr_arpa_id                         AS instr_arpa_id   ,
            i.instr_serial_num                      AS instr_serial_num,
            i.instr_name                            AS instr_name
        FROM
            client_lig_alims.reports r
            LEFT JOIN client_lig_alims.arguments a   USING (arg_id)
            LEFT JOIN metadata.stations s            USING (station_id)
            LEFT JOIN bobo.users u                   USING (us_id)
            LEFT JOIN equipments.instruments i       USING (instr_id)
            LEFT JOIN equipments.instruments_type it USING (instr_type_id)
            LEFT JOIN equipments.constructors c      USING (constr_id)
            LEFT JOIN equipments.brands b            USING (brand_id)
            LEFT JOIN equipments.models m            USING (model_id)
            LEFT JOIN metadata.view_stations_municipality vsm   USING (station_id)
        WHERE r.rep_id = ?
    };

    # return
    return $self->pg->db->query($sql, $rpid)->hash;
}

sub get_report_by_number {
    my ( $self, $num ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_report_by_number");

    # query
    my $sql = qq{
        SELECT
            r.rep_id           ,
            r.rep_seq          ,
            r.rep_fulldate     ,
            r.rep_number       ,
            TO_CHAR(r.rep_insert_ts at time zone 'UTC' at time zone 'Europe/Rome', 'DD/MM/YYYY HH24:MI') AS rep_insert_ts,
            r.rep_pdf          ,
            r.rep_sent         ,
            COALESCE(TO_CHAR(r.rep_sent_ts at time zone 'UTC' at time zone 'Europe/Rome', 'DD/MM/YYYY HH24:MI'), '--') AS rep_sent_ts,
            CASE
                WHEN r.analisys_receive_ts NOTNULL THEN TRUE
                ELSE FALSE
            END                                     AS rep_received,
            COALESCE(TO_CHAR(r.analisys_receive_ts at time zone 'UTC' at time zone 'Europe/Rome', 'DD/MM/YYYY HH24:MI'), '--') AS analisys_receive_ts,
            r.rep_multi_filters,
            -- argument
            r.arg_id                                AS argument_id,
            a.arg_desc                              AS argument_desc,
            -- analytic
            r.ana_ids                               AS analytics_id,
            -- station
            r.station_id                            AS station_id,
            s.station_name                          AS station_name,
            -- user
            r.us_id                                 AS user_id,
            u.us_name || ' '
            || COALESCE(u.us_2nd_name, ''::text)
            || u.us_surname                         AS user_fullname,
            -- instrument
            r.instr_id                              AS instr_id        ,
            i.instr_type_id                         AS instr_type_id   ,
            i.instr_arpa_id                         AS instr_arpa_id   ,
            i.instr_serial_num                      AS instr_serial_num,
            i.instr_name                            AS instr_name
        FROM
            client_lig_alims.reports r
            LEFT JOIN client_lig_alims.arguments a   USING (arg_id)
            LEFT JOIN metadata.stations s            USING (station_id)
            LEFT JOIN bobo.users u                   USING (us_id)
            LEFT JOIN equipments.instruments i       USING (instr_id)
            LEFT JOIN equipments.instruments_type it USING (instr_type_id)
        WHERE r.rep_number = ?
    };

    # return
    return $self->pg->db->query($sql, $num)->hash;
}

sub get_filters_by_report {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_filters_by_report");

    # query
    my $sql = qq{
        WITH f AS(
            SELECT *
            FROM client_lig_alims.filters
            WHERE rep_id = ?
            AND filter_cancelled IS FALSE
            AND filter_white IS FALSE
        ),
        t AS(
            SELECT
                SUM(filter_volume) AS filter_tot_volume,
                STRING_AGG(filter_name, '_' ORDER BY filter_id) AS filter_tot_name
            FROM
                f
            GROUP BY rep_id
            UNION ALL
            SELECT
                null,
                null
            WHERE NOT EXISTS (SELECT 1 FROM f)
        )
        SELECT
            filter_id             ,
            filter_name           ,
            filter_start_fulldate ,
            TO_CHAR(filter_start_fulldate, 'DD/MM/YYYY HH24:MI')  AS filter_start_fulldate_formated,
            filter_end_fulldate,
            TO_CHAR(filter_end_fulldate, 'DD/MM/YYYY HH24:MI')    AS filter_end_fulldate_formated,
            filter_volume    ,
            filter_cancelled ,
            filter_white     ,
            -- truncate e cast a date per ovviare al problema dei minuti != da 0 (es. 00:05 - 23:55)
            (
                EXTRACT(
                    EPOCH FROM (date_trunc('hour', filter_end_fulldate) - filter_start_fulldate::date )
                ) / (3600) +1
            ) / 24              AS filter_ndays,
            filter_results_obj,
            t.filter_tot_volume,
            t.filter_tot_name
        FROM
            client_lig_alims.filters, t
        WHERE rep_id = ?
        ORDER BY filter_id ASC;
    };

    # return
    return $self->pg->db->query($sql, $rpid, $rpid)->hashes;
}

sub get_multiple_filter_by_report_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_multiple_filter_by_report_id");

    # query
    my $sql = qq{
        SELECT
            r.rep_id,
            MIN(r.station_id)   AS station_id,
            MAX(s.station_name) AS station_name,

            MIN(f.filter_id)                AS filter_id,
            MIN(f.filter_start_fulldate)    AS filter_start_fulldate,
            MAX(f.filter_end_fulldate)      AS filter_end_fulldate,
            -- truncate e cast a date per ovviare al problema dei minuti != da 0 (es. 00:05 - 23:55)
            (
                EXTRACT(
                    EPOCH FROM (date_trunc('hour', MAX(f.filter_end_fulldate)) - MIN(f.filter_start_fulldate)::date )
                ) / (3600) +1
            ) / 24                          AS filter_ndays,
            SUM(f.filter_volume)            AS filter_volume,
            FALSE::boolean                  AS filter_white

        FROM
            client_lig_alims.reports r
            LEFT JOIN client_lig_alims.filters f USING (rep_id)
            LEFT JOIN metadata.stations s USING (station_id)
        WHERE
            r.rep_id = ?
            AND f.filter_cancelled IS FALSE
            AND f.filter_white IS FALSE
        GROUP BY
            r.rep_id;
    };

    # return
    return $self->pg->db->query($sql, $rpid)->hash;
}

sub get_filter_by_report_id {
    my ( $self, $rpid, $filter_name ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_filter_by_report_id");

    # query
    my $sql = qq{
        SELECT
            r.rep_id,
            r.station_id  ,
            s.station_name,

            f.filter_id            ,
            f.filter_start_fulldate,
            f.filter_end_fulldate  ,
            -- truncate e cast a date per ovviare al problema dei minuti != da 0 (es. 00:05 - 23:55)
            (
                EXTRACT(
                    EPOCH FROM (date_trunc('hour', f.filter_end_fulldate) - f.filter_start_fulldate::date )
                ) / (3600) +1
            ) / 24              AS filter_ndays,
            f.filter_volume        ,
            f.filter_white
        FROM
            client_lig_alims.reports r
            LEFT JOIN client_lig_alims.filters f USING (rep_id)
            LEFT JOIN metadata.stations s USING (station_id)
        WHERE
            r.rep_id = ?
            AND f.filter_name = ?;
    };

    # return
    return $self->pg->db->query($sql, $rpid, $filter_name)->hash;
}

sub get_volume {
    my ( $self, $stid, $inid, $dt ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_volume");

    # query
    my $sql = qq{
        SELECT
            st.station_schema || '.' || COALESCE(st.station_prefix, '') || st.station_table AS station_fulltable
        FROM
            metadata.stations st
        WHERE
            station_id = ?;
    };

    my $table = $self->pg->db->query($sql, $stid)->hash->{'station_fulltable'};

    $sql = qq{
        WITH t AS(
            SELECT
                stpr_table_id,
                p.param_name || COALESCE(' - '::text || sp.stpr_note, ''::text) AS param_name,
                param_unit
            FROM metadata.stations_parameters sp
            LEFT JOIN metadata.parameters p USING (param_id)
            WHERE
                stpr_group_id = (
                    SELECT
                        stpr_group_id
                    FROM
                        metadata.stations_instruments
                    WHERE
                        station_id = ?
                        AND instr_id = ?
                        AND tsrange(stin_startup_date, stin_dismiss_date, '[]') @> ?::timestamp
                )
                AND param_id IN (
                    188, -- [TC] Volume standard
                    373, -- [SWAM] Inlet volume [m³]
                    670  -- [HYDRA] Inlet volume [m³]
                )
                -- 539 [SWAM] Volume standard [m³]
                -- 671 [HYDRA] Volume standard [Nm³]
        )
        SELECT
            stpr_table_id,
            param_name,
            measure_value,
            param_unit
        FROM
            t
            LEFT JOIN $table d ON (t.stpr_table_id = d.measure_id AND measure_date_time = ?::date)
        WHERE
            measure_value NOTNULL;
    };

    # return
    return $self->pg->db->query($sql, $stid, $inid, $dt, $dt)->hashes;
}

sub get_stpr_by_alims_code {
    my ( $self, $stid, $code ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub get_stpr_by_alims_code");

    # query
    my $sql;

    # active,
    # id,
    # pr_id,
    # name,
    # shortname,
    # unit,
    # unitconv,
    # decimals,
    # st_id,
    # stationname,
    # schema||'.data_'||tableid AS fulltable
    $sql = qq{
        SELECT
            param_id,
            param_name,
            param_unit,
            param_unit_conv,
            param_decimals,
            station_id,
            station_name,
            station_schema||'.'||COALESCE(station_prefix, ''::text)||station_table AS station_fulltable,
            stpr_table_id
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.parameters_info pi USING (param_id)
        WHERE
            station_id = ?
            AND pm_info_obj->'general'->>'alims_code' = ?
    };

    # return
    return $self->pg->db->query($sql, $stid, $code)->hash;
}

sub insert_report {
    my ( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub insert_report");

    my $tx;
    my $new_rpid;

    # "analytics-alims" => [
    #                      19,
    #                      17
    #                    ],
    # "argument-alims" => 1,
    # "datetime-alims" => "20/04/2022 16:08",
    # "filter-volume-tot-alims" => "",
    # "filters-alims" => "",
    # "id-alims" => "",
    # "instrument-alims" => 704,
    # "number-alims" => "OPAS2022_xxxx",
    # "prov-alims" => 4,
    # "station-alims" => 1188

    eval {
        $tx =  $self->pg->db->begin;

        # ARRAY analytics
        my @analytics;
        if (ref($params->{'analytics-alims'}) eq 'ARRAY') {
            @analytics = @{$params->{'analytics-alims'}};
        }
        else {
            push @analytics, $params->{'analytics-alims'};
        }

        # lock table
        $self->pg->db->query("LOCK TABLE client_lig_alims.reports IN ACCESS EXCLUSIVE MODE");

        # get the report number
        my $sql = qq{
            SELECT
                'OPAS'||EXTRACT(year FROM CURRENT_TIMESTAMP)::text||'_'||lpad(COALESCE((MAX(rep_seq)+1)::text, '1'), 4, '0') AS report_seq_string,
                COALESCE((MAX(rep_seq)+1)::text, '1')::integer AS report_seq_number
            FROM
                client_lig_alims.reports
            WHERE
                EXTRACT(year FROM rep_fulldate) = EXTRACT(year FROM CURRENT_TIMESTAMP);
        };

        my $row = $self->pg->db->query($sql)->hash();

        # ##################################################################
        # 1- creazione nuovo report alims e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbalims STEP 1");

        $new_rpid = $self->pg->db->insert('client_lig_alims.reports', {
            rep_number        => $row->{'report_seq_string'}, # calcolato
            rep_seq           => $row->{'report_seq_number'}, # calcolato
            us_id             => $user_id,
            rep_fulldate      => $self->app->helperGetFormattedFulldate($params->{'datetime-alims'}),
            arg_id            => $params->{'argument-alims'},
            ana_ids           => \@analytics,
            station_id        => $params->{'station-alims'},
            instr_id          => $params->{'instrument-alims'},
            rep_multi_filters => $self->app->helperGetBoolean($params, 'multi-alims')

        }, {returning => 'rep_id'})->hash->{'rep_id'};

        # ##################################################################
        # 2- aggiunta dei filtri associati al report
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbalims STEP 2");

        my @filters = decode_json(encode_utf8($params->{'filters-alims'}));

        $self->app->log->debug("Print ARRAY");
        $self->app->helperDumper($filters[0]);

        for my $filter (@{$filters[0]}){

            # $self->app->helperDumper( $filter );
            # filterObj = {
            #     name:
            #     start:
            #     end:
            #     volume:
            #     cancelled:
            #     white:
            # };

            $self->pg->db->insert('client_lig_alims.filters', {
                rep_id                => $new_rpid,
                filter_name           => $filter->{'name'},
                filter_start_fulldate => $self->app->helperGetFormattedFulldate($filter->{'start'}),
                filter_end_fulldate   => $self->app->helperGetFormattedFulldate($filter->{'end'}),
                filter_volume         => $filter->{'volume'},
                filter_cancelled      => $filter->{'cancelled'},
                filter_white          => $filter->{'white'}
            });
        };
    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return undef;
    }
    else {
       $tx->commit;
       return $new_rpid;
    }
}

sub insert_filter_value {
    my ( $self, $iswhite, $volume, $start, $ndays, $stpr, $value, $ldq ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub insert_filter_value");

    # build sql
    my $tx;
    my $sql;
    my $res;

    # verifica filtro
    my $code = 0;
    # ' dl
    # CALIBRATION = 16
    # DETECTION_LIMIT = 512
    # MIN_DETECTION_LIMIT = 1024
    if ($iswhite) {
        # filtro di bianco
        $self->app->log->debug("filtro di bianco, valore non cambia");
        #$value = $value;

        # set code as for calibration
        $code = 16;

        # i filtri più vecchi non hanno il campo ResultLDQ => lo imposto a 0
        if (!defined $ldq) {
            $ldq = 0;
        }

        eval {
            $tx =  $self->pg->db->begin;

            # processo giorni sequenziali dello stesso filtro
            for (my $i = 0; $i < $ndays; $i++) {
                # query
                $sql = qq{
                    SELECT nextval('clients.calibrations_id_seq'::regclass) AS cal_id;
                };

                my $id = $self->pg->db->query($sql)->hash->{'cal_id'};

                # calibration_id        -> get next val - SELECT nextval('clients.calibrations_id_seq'::regclass);
                # calibration_date_time -> calib_fulldate
                # station_id            -> station_id
                # measure_id            -> par_zero | par_span
                # calibration_type      -> USER (USER | AUTO)
                # calibration_step      -> ZERO,SPAN (par_zero | par_span) (ZERO | SPAN | PURGE | UNKNOWN)
                # reference_value       -> theory_xxx
                # defect_value          -> 10%
                # result_code           -> calculated (16  CALIBRATION || {1 SPAN_LOW - 2 SPAN_HIGH - 4 ZERO_LOW - 8 ZERO_HIGH})
                # result_value          -> read_xxx

                $sql = qq{
                    INSERT INTO clients.calibrations_result
                        ( calibration_id, calibration_date_time, station_id, measure_id, calibration_type, calibration_step, reference_value, defect_value, result_code, result_value )
                    VALUES
                        (?, ( (? ::date)::timestamp + interval '$i days' ), ?, ?, 'USER', 'ZERO', 0, ?, 16, ?)
                    ON CONFLICT ON CONSTRAINT calibrations_result_pkey
                    DO UPDATE SET
                        result_value = EXCLUDED.result_value;
                };

                $self->pg->db->query($sql, $id, $start, $stpr->{'station_id'}, $stpr->{'stpr_table_id'}, $ldq, $value);
            }
        };

        # error check
        if ($@) {
           $self->app->log->warn("Error: ".$@);
           # rollback
           $res = undef;
        }
        else {
           $tx->commit;
           $res = 1;
        }
    }
    else {
        if ($value < 0) {
            # valore è negativo e quindi minore del DL
            $self->app->log->debug("il valore è negativo e quindi minore del DL -> dato = DLc/2");

            $volume = 55.2;
            $value = $value * -1;
            $value = ($value / ($ndays * $volume));
            $value = $value / 2;
            # set code dl
            $code = 512;
        }
        else {
            # dato normale
            $self->app->log->debug("valore normale calcolato con giorni e volume");
            # valore = (valore / (numero_giorni * volume_filtro))
            $value = ($value / ($ndays * $volume));
        }

        # get tablename
        my $table = $stpr->{'station_fulltable'};

        eval {
            $tx = $self->pg->db->begin;
            # processo giorni sequenziali dello stesso filtro
            for (my $i = 0; $i < $ndays; $i++) {
                $sql = qq{
                    INSERT INTO $table
                        (measure_date_time, measure_id, measure_value, measure_code, extract_code)
                    VALUES
                        ( ( ( ?::date)::timestamp + interval '$i days' ), ?, ?, ?, 24::smallint)
                    ON CONFLICT (measure_date_time, measure_id)
                    DO UPDATE SET
                        measure_value = EXCLUDED.measure_value,
                        measure_code = EXCLUDED.measure_code;
                };

                $self->pg->db->query($sql, $start, $stpr->{'stpr_table_id'}, $value, $code);
            }
        };

        # error check
        if ($@) {
           $self->app->log->warn("Error: ".$@);
           # rollback
           $res = undef;
        }
        else {
           $tx->commit;
           $res = 1;
        }
    }

    # return
    return $res;
}

sub update_report {
    my ( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub update_report");

    my $tx;

    # "analytics-alims" => [
    #                      19,
    #                      17
    #                    ],
    # "argument-alims" => 1,
    # "datetime-alims" => "20/04/2022 16:08",
    # "filter-volume-tot-alims" => "",
    # "filters-alims" => "",
    # "id-alims" => "",
    # "instrument-alims" => 704,
    # "number-alims" => "OPAS2022_xxxx",
    # "prov-alims" => 4,
    # "station-alims" => 1188

    eval {
        $tx =  $self->pg->db->begin;

        # ARRAY analytics
        my @analytics;
        if (ref($params->{'analytics-alims'}) eq 'ARRAY') {
            @analytics = @{$params->{'analytics-alims'}};
        }
        else {
            push @analytics, $params->{'analytics-alims'};
        }

        # ##################################################################
        # 1- modifica report alims
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbalims STEP 1");

        $self->pg->db->update('client_lig_alims.reports', {
            rep_fulldate      => $self->app->helperGetFormattedFulldate($params->{'datetime-alims'}),
            arg_id            => $params->{'argument-alims'},
            ana_ids           => \@analytics,
            station_id        => $params->{'station-alims'},
            instr_id          => $params->{'instrument-alims'},
            rep_multi_filters => $self->app->helperGetBoolean($params, 'multi-alims')

        }, {rep_id => $params->{'id-alims'}});

        # ##################################################################
        # 2- eliminazione dei filtri associati al report
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbalims STEP 2");
        my $sql = qq{
            DELETE FROM client_lig_alims.filters
            WHERE rep_id = ?;
        };

        $self->pg->db->query($sql, $params->{'id-alims'});

        # ##################################################################
        # 3- aggiunta dei filtri associati al report
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbalims STEP 3");

        my @filters = decode_json(encode_utf8($params->{'filters-alims'}));

        $self->app->log->debug("Print ARRAY");
        $self->app->helperDumper($filters[0]);

        for my $filter (@{$filters[0]}){

            # $self->app->helperDumper( $filter );
            # filterObj = {
            #     name:
            #     start:
            #     end:
            #     volume:
            #     cancelled:
            #     white:
            # };

            $self->pg->db->insert('client_lig_alims.filters', {
                rep_id                => $params->{'id-alims'},
                filter_name           => $filter->{'name'},
                filter_start_fulldate => $self->app->helperGetFormattedFulldate($filter->{'start'}),
                filter_end_fulldate   => $self->app->helperGetFormattedFulldate($filter->{'end'}),
                filter_volume         => $filter->{'volume'},
                filter_cancelled      => $filter->{'cancelled'},
                filter_white          => $filter->{'white'}
            });
        };
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

sub update_pdf_flag {
    my ( $self, $rpid, $flag ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub update_pdf_flag");

    # update and return
    return $self->pg->db->update('client_lig_alims.reports', {
        rep_pdf => $flag,

    }, { rep_id => $rpid });
}

sub update_sent_flag {
    my ( $self, $rpid, $flag ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub update_sent_flag");

    # update and return
    return $self->pg->db->update('client_lig_alims.reports', {
        rep_sent    => $flag,
        rep_sent_ts => $self->app->helperGetFullDate()

    }, { rep_id => $rpid } );

}

sub update_received_obj {
    my ( $self, $rpid, $obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub update_received_obj");

    # update and return
    return $self->pg->db->update('client_lig_alims.reports', {
        analisys_obj        => $self->app->helperEscapeParam(decode_utf8(encode_json($obj))),
        analisys_receive_ts => $self->app->helperGetFullDate()

    }, { rep_id =>  $rpid });
}

sub update_received_filter_obj {
    my ( $self, $filter_id, $obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub update_received_filter_obj");

     # update and return
    return $self->pg->db->update('client_lig_alims.filters', {
        filter_results_obj => $self->app->helperEscapeParam(decode_utf8(encode_json($obj)))
    }, { filter_id =>  $filter_id });
}

sub delete_report_by_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbalims sub delete_report_by_id");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- eliminazione dei filtri associati al report
        # ##################################################################
        my $sql = qq{
            DELETE FROM client_lig_alims.filters
            WHERE rep_id = ?;
        };

        $self->pg->db->query($sql, $rpid);

        # ##################################################################
        # 2- eliminazione del report
        # ##################################################################
        $sql = qq{
            DELETE FROM client_lig_alims.reports
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

=head1 get_stations_by_province

Funzione che recupera, dato l'id di una provincia (non obbligatorio), le informazioni di determinate stazioni dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia, se presente ('prov');

Return:     Risultato della query;

=cut

=head1 get_arguments

Funzione che recupera gli argomenti disponibili per i verbali ALIMS dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_analytics

Funzione che recupera i pacchetti analitici disponibili per i verbali ALIMS dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_reports_by_date_province

Funzione che recupera, dato un certo periodo temporale e l'id di una provincia,
tutti i relativi report con le relative informazioni riguardanti
i pacchetti analitici associati al verbale dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della provincia, se presente ('prid');

           * id del pacchetto analitico, se presente ('pack');

Return:     Risultato della query.

=cut

=head1 get_reports_by_date_station

Funzione che recupera, dato un certo periodo temporale e l'id di una stazione,
tutti i relativi report con le relative informazioni riguardanti
i pacchetti analitici associati al verbale dal database.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

           * id del pacchetto analitico, se presente ('pack');

Return:     Risultato della query.

=cut

=head1 get_report_by_id

Funzione che recupera, dato l'id, le informazioni di un determinato verbale dal database.

Argomenti:  * id del report ('rpid');

Return:     Risultato della query.

=cut

=head1 get_report_by_number

Funzione che recupera, dato il numero, le informazioni di un determinato verbale dal database.

Argomenti:  * numero del verbale ('num');

Return:     Risultato della query.

=cut

=head1 get_filters_by_report

Funzione che recupera, dato l'id di un report, i relativi filtri associati dal database.

Argomenti:  * id del report ('rpid');

Return:     Risultato della query.

=cut

=head1 get_multiple_filter_by_report_id

Funzione che recupera, dato l'id di un report, i relativi filtri multipli associati dal database.

Argomenti:  * id del report ('rpid');

Return:     Risultato della query.

=cut

=head1 get_filter_by_report_id

Funzione che recupera, dato l'id di un report, le informazioni relative ad un determinato
filtro dal database.

Argomenti:  * id del report ('rpid');

           * nome del filtro ('filter_name');

Return:     Risultato della query.

=cut

=head1 get_volume

Funzione che recupera il valore di volume dei filtri inseriti per un determinato strumento
in una determinata stazione ed in una determinata data dal database.

Argomenti:  * id della stazione ('stid');

           * is dello strumento ('inid');

           * data/ora ('dt');

Return:     Risultato della query.

=cut

=head1 get_stpr_by_alims_code

Funzione che recupera, dato l'id della stazione ed un determinato codice ALIMS, le relative
informazioni dell'associazione stazione-parametro dal database.

Argomenti:  * id della stazione ('stid');

           * codice ALIMS ('code');

Return:     Risultato della query.

=cut

=head1 insert_report

Funzione che inserisce un nuovo verbale nel database.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni del report da inserire ('params');

Return:     Se tutto OK, restituisce l'id del verbale appena inserito;

        Se KO, restituisce undef.

=cut

=head1 insert_filter_value

Funzione che inserisce un nuovo filtro nel database.

Argomenti:  * valore booleano che indica se il filtro da inserire e' bianco ('iswhite');

           * valore di volume ('volume');

           * data d'inizio ('start');

           * numero di giorni ('ndays');

           * oggetto contenente le informazioni relative ai parametri della stazione ('stpr');

           * valore del filtro ('value');

           * valore di difetto ('ldq');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce undef.

=cut

=head1 update_report

Funzione che modifica, dato l'id, un determinato report nel database.

Argomenti:  * oggetto contenente le informazioni del report da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_pdf_flag

Funzione che aggiorna, dato l'id, il flag di generazione del PDF di un determinato report nel database.

Argomenti:  * id del report ('rpid');

           * flag 1/0 relativo alla generazione del PDF ('flag');

Return:     Risultato della query.

=cut

=head1 update_sent_flag

Funzione che aggiorna, dato l'id, il flag di invio del verbale di un determinato report nel database.

Argomenti:  * id del report ('rpid');

           * flag 1/0 relativo alla generazione del PDF ('flag');

Return:     Risultato della query.

=cut

=head1 update_received_obj

Funzione che aggiorna, dato l'id, le informazioni di ricezione di un determinato report nel database.

Argomenti:  * id del report ('rpid');

           * oggetto relativo alla ricezione del verbale ('obj');

Return:     Risultato della query.

=cut

=head1 update_received_filter_obj

Funzione che aggiorna, dato l'id, le informazioni di ricezione di un determinato filtro nel database.

Argomenti:  * id del filtro ('filter_id');

           * oggetto relativo alla ricezione del filtro ('obj');

Return:     Risultato della query.

=cut

=head1 delete_report_by_id

Funzione che elimina, dato l'id, un determinato report dal database.

Argomenti:  * id del report ('rpid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut