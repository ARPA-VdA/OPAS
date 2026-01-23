package Bobo::Model::Dbdataview;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use Scalar::Util qw(looks_like_number);
use Mojo::JSON qw(encode_json);
use Encode qw/decode_utf8/;
use utf8;

has 'pg';
has 'app';

sub get_dataview_options {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_dataview_options");

    # query
    my $sql = qq{
        SELECT
            go_obj AS option_object
        FROM
            bobo_tools.general_options
        WHERE go_tool = 'dataview'
    };

    # return
    return $self->pg->db->query($sql)->hash();
}

sub get_dataview_descriptions {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_dataview_descriptions");

    # query
    my $sql = qq{
        SELECT
            desc_id             AS id         ,
            desc_live           AS live       ,
            desc_indicator      AS indicator  ,
            desc_last_values    AS last_values,
            desc_infos          AS infos
        FROM bobo_tools.dataview_descriptions
        LIMIT 1;
    };

    # return
    return $self->pg->db->query($sql)->hash();
}

sub get_dataview_provinces {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_dataview_provinces");

    # Filtri QUERY sincronizzati con get_map_stations
    my $sql = qq{
        SELECT DISTINCT (province_id),
            province_name,
            province_code,
            region_id,
            region_name
        FROM
            metadata.stations_status ss
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.stations_info si USING (station_id)
            LEFT JOIN metadata.view_stations_municipality sm USING (station_id)
        WHERE
            s.station_active           IS TRUE
            AND ss.ss_suspended         IS FALSE
            AND ss.ss_dataview_publish  IS TRUE
            AND si.st_info_lat_wgs84 IS NOT NULL
            AND si.st_info_lon_wgs84 IS NOT NULL
        ORDER BY
            region_name, province_name;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_dataview_all_provinces {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_dataview_all_provinces");

    # Filtri QUERY sincronizzati con get_map_stations
    my $sql = qq{
        SELECT DISTINCT (province_id),
            province_name,
            province_code,
            region_id,
            region_name
        FROM
            metadata.view_stations_info si
            LEFT JOIN metadata.view_stations_municipality sm USING (station_id)
        WHERE
            station_id IN (
                    SELECT
                        station_id
                    FROM
                        metadata.stations_status ss
                    WHERE
                        ss_suspended         IS FALSE
                        AND ss_dataview_publish  IS TRUE
                UNION
                    SELECT
                        station_id
                    FROM
                        bobo.view_user_stations vus
                    LEFT JOIN metadata.stations_status ss2 USING (station_id)
                    WHERE
                        user_id = ?
                        AND ss2.ss_suspended IS FALSE
            )
            AND si.station_active       IS TRUE
            AND si.station_lat_wgs84 IS NOT NULL
            AND si.station_lon_wgs84 IS NOT NULL
        ORDER BY
            region_name, province_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_dataview_stations {
    my ( $self, $regid, $provid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_dataview_stations");

    # Filtri QUERY sincronizzati con get_map_stations
    my $sql = qq{
        SELECT
            *,
            DENSE_RANK() OVER (ORDER BY si.station_network_type_desc)-1 AS layer_order
        FROM
            metadata.stations_status ss
            LEFT JOIN metadata.view_stations_info si USING (station_id)
            LEFT JOIN metadata.view_stations_municipality sm USING (station_id)
        WHERE
            si.station_active           IS TRUE
            AND ss.ss_suspended         IS FALSE
            AND ss.ss_dataview_publish  IS TRUE
            AND si.station_lat_wgs84 IS NOT NULL
            AND si.station_lon_wgs84 IS NOT NULL
    };

    my @binds;
    if ($regid != -1) {
        $sql .= qq{ AND sm.region_id = ? };
        push @binds, $regid;
    }

    if ($provid != -1) {
        $sql .= qq{ AND sm.province_id = ? };
        push @binds, $provid;
    }

    $sql .= qq{
        ORDER BY
            region_name, province_code, si.station_name;
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes();
}

sub get_dataview_all_stations {
    my ( $self, $user_id, $regid, $provid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_dataview_all_stations");

    # Filtri QUERY sincronizzati con get_map_all_stations
    my $sql = qq{
        SELECT *,
            DENSE_RANK() OVER (ORDER BY station_network_type_desc)-1 AS layer_order
        FROM
            metadata.view_stations_info si
            LEFT JOIN metadata.view_stations_municipality sm USING (station_id)
        WHERE
            station_id IN (
                    SELECT
                        station_id
                    FROM
                        metadata.stations_status ss
                    WHERE
                        ss_suspended         IS FALSE
                        AND ss_dataview_publish  IS TRUE
                UNION
                    SELECT
                        station_id
                    FROM
                        bobo.view_user_stations vus
                    LEFT JOIN metadata.stations_status ss2 USING (station_id)
                    WHERE
                        user_id = ?
                        AND ss2.ss_suspended IS FALSE
            )
            AND si.station_active       IS TRUE
            AND si.station_lat_wgs84 IS NOT NULL
            AND si.station_lon_wgs84 IS NOT NULL
    };

    my @binds = ($user_id);
    if ($regid != -1) {
        $sql .= qq{ AND sm.region_id = ? };
        push @binds, $regid;
    }

    if ($provid != -1) {
        $sql .= qq{ AND sm.province_id = ? };
        push @binds, $provid;
    }

    $sql .= qq{
        ORDER BY
            region_name, province_code, si.station_name;
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes();
}

sub check_permission_station {
    my ( $self, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub check_permission_station");

    # query
    my $sql = qq{
        SELECT EXISTS(
            SELECT 1
            FROM metadata.stations_status ss
            LEFT JOIN metadata.view_stations_info sm USING (station_id)
            WHERE sm.station_active     IS TRUE
            AND ss.ss_suspended         IS FALSE
            AND ss.ss_dataview_publish  IS TRUE
            AND station_id = ?
        ) AS flag;
    };

    # return
    return $self->pg->db->query($sql, $stid)->hash()->{'flag'};
}

sub get_dataview_params {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_dataview_params");

    # query
    my $sql = qq{
        SELECT *
        FROM metadata.view_parameters_info vpi
        LEFT JOIN bobo_tools.parameters_options po ON (po.param_id = vpi.parameter_id)
        WHERE parameter_dataview_flag IS TRUE
        ORDER BY
            param_order, parameter_name;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_dataview_params_live {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_dataview_params_live");

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT
                parameter_id,
                jsonb_array_elements(parameter_dataview_labels)->>'big' AS label_big,
                jsonb_array_elements(parameter_dataview_labels)->>'little' AS label_little,
                jsonb_array_elements(parameter_dataview_labels)->>'aggregation' AS label_aggr,
                jsonb_array_elements(parameter_dataview_labels)->>'target' AS label_target,
                jsonb_array_elements(parameter_dataview_labels)->>'order' AS label_order
            FROM metadata.view_parameters_info vpi
            WHERE parameter_dataview_live IS TRUE
        )
        SELECT parameter_id, label_big, label_little, label_aggr
        FROM temp
        WHERE label_target LIKE 'live'
        ORDER BY label_order, parameter_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_dataview_params_indicator {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_dataview_params_indicator");

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT
                parameter_id,
                jsonb_array_elements(parameter_dataview_labels)->>'big' AS label_big,
                jsonb_array_elements(parameter_dataview_labels)->>'little' AS label_little,
                jsonb_array_elements(parameter_dataview_labels)->>'aggregation' AS label_aggr,
                jsonb_array_elements(parameter_dataview_labels)->>'stat_id' AS label_stat,
                jsonb_array_elements(parameter_dataview_labels)->>'target' AS label_target,
                jsonb_array_elements(parameter_dataview_labels)->>'order' AS label_order
            FROM metadata.view_parameters_info vpi
            WHERE parameter_dataview_indicator IS TRUE
        )
        SELECT parameter_id, label_big, label_little, label_aggr, label_stat
        FROM temp
        WHERE label_target LIKE 'indicator'
        ORDER BY label_order;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_map_stations {
    my ( $self, $params_array ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_map_stations");
    my $filter_sql = '';

    my @binds;
    if (defined $params_array && scalar @{$params_array} > 0) {
        my $flag = 0;
        $filter_sql = qq{ AND station_id IN ( };

        for my $param (@{$params_array}) {
            $self->app->log->debug($param);

            return undef
                unless looks_like_number($param);

            if ($flag) {
                $filter_sql .= qq{   INTERSECT};
            }

            $filter_sql .= qq{
                SELECT DISTINCT(station_id)
                FROM metadata.stations_parameters
                WHERE param_id = ?
                AND stpr_active IS TRUE
            };

            $flag = 1;
            push @binds, $param;
        }

        $filter_sql .= qq{ ) };

    }

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                s.station_id AS main_station_id,
                COALESCE(  ss.station_override_id, s.station_id ) AS station_id,
                CASE
                    WHEN ss.station_override_id NOTNULL THEN (
                        SELECT mu_id
                        FROM metadata.sites
                        WHERE site_id = ss.site_id
                    )
                    ELSE (
                        SELECT mu_id
                        FROM metadata.stations_municipality
                        WHERE station_id = s.station_id
                    )
                END     AS mu_id
            FROM
                metadata.stations s
                LEFT JOIN metadata.stations_sites ss ON (s.station_id = ss.station_id AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
        )
        SELECT
            'station'                       AS marker_type,
            TRUE                            AS marker_flag_popup,
            sm.station_network_type_id      AS marker_layer_id,
            sm.station_network_type_desc    AS marker_layer,
            DENSE_RANK() OVER (ORDER BY sm.station_network_type_desc)-1 AS marker_layer_order,
            sm.station_network_type_logo    AS marker_logo,
            t.main_station_id               AS marker_id,
            sm.station_name                 AS marker_name,
            sm.station_lat_wgs84            AS marker_lat,
            sm.station_lon_wgs84            AS marker_lon,
            '<div>
                <h4>'|| sm.station_name ||'</h4>
                <strong>Comune : </strong>'|| COALESCE(m.mu_name, '-') ||'<br>
                <strong>Località : </strong>'|| COALESCE(sm.station_locality, '-') ||'<br>
                <strong>Quota : </strong>'|| COALESCE(sm.station_altitude::text, '-') ||'<br>
                <strong>Rete : </strong>'|| sm.station_network_type_desc||'
                <p style="margin: 0;">
                    <strong>Links : </strong><a href="/str_dataview_station/'||t.main_station_id||'">dati e anagrafica</a>
                </p>
            </div>'                         AS marker_desc,
            metadata.f_get_icon_by_station_id( t.station_id ) AS marker_icon
        FROM
            t
            LEFT JOIN metadata.view_stations_info sm USING (station_id)
            LEFT JOIN main.municipalities m USING (mu_id)
        WHERE
            t.main_station_id IN (
                    SELECT
                        station_id
                    FROM
                        metadata.stations_status
                    WHERE
                        ss_dataview_publish      IS TRUE
                        AND ss_suspended         IS FALSE
            )
            AND sm.station_active IS TRUE
            AND sm.station_lat_wgs84 IS NOT NULL
            AND sm.station_lon_wgs84 IS NOT NULL
            AND station_roaming_type_id IN (1,2,4) -- stazioni fisse, mobili, siti con stanziamento
            $filter_sql
        ORDER BY
            sm.station_network_type_desc, sm.station_id;
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes();
}

sub get_map_all_stations {
    my ( $self, $userid, $params_array ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_map_all_stations");

    my $filter_sql = '';

    my @binds;
    if (defined $params_array && scalar @{$params_array} > 0) {
        my $flag = 0;
        $filter_sql = qq{ AND station_id IN ( };

        for my $param (@{$params_array}) {
            $self->app->log->debug($param);

            return undef
                unless looks_like_number($param);

            if ($flag) {
                $filter_sql .= qq{   INTERSECT};
            }

            $filter_sql .= qq{
                SELECT DISTINCT(station_id)
                FROM metadata.stations_parameters
                WHERE param_id = ?
                AND stpr_active IS TRUE
            };

            $flag = 1;
            push @binds, $param;
        }

        $filter_sql .= qq{ ) };
    }

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                s.station_id AS main_station_id,
                COALESCE(  ss.station_override_id, s.station_id ) AS station_id,
                CASE
                    WHEN ss.station_override_id NOTNULL THEN (
                        SELECT mu_id
                        FROM metadata.sites
                        WHERE site_id = ss.site_id
                    )
                    ELSE (
                        SELECT mu_id
                        FROM metadata.stations_municipality
                        WHERE station_id = s.station_id
                    )
                END     AS mu_id
            FROM
                metadata.stations s
                LEFT JOIN metadata.stations_sites ss ON (s.station_id = ss.station_id AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
        )
        SELECT
            'station'                       AS marker_type,
            TRUE                            AS marker_flag_popup,
            sm.station_network_type_id      AS marker_layer_id,
            sm.station_network_type_desc    AS marker_layer,
            DENSE_RANK() OVER (ORDER BY sm.station_network_type_desc)-1 AS marker_layer_order,
            sm.station_network_type_logo    AS marker_logo,
            t.main_station_id               AS marker_id,
            sm.station_name                 AS marker_name,
            sm.station_lat_wgs84            AS marker_lat,
            sm.station_lon_wgs84            AS marker_lon,
            '<div>
                <h4>'|| sm.station_name ||'</h4>
                <strong>Comune : </strong>'|| COALESCE(m.mu_name, '-') ||'<br>
                <strong>Località : </strong>'|| COALESCE(sm.station_locality, '-') ||'<br>
                <strong>Quota : </strong>'|| COALESCE(sm.station_altitude::text, '-') ||'<br>
                <strong>Rete : </strong>'|| sm.station_network_type_desc||'
                <p style="margin: 0;">
                    <strong>Links : </strong><a href="/str_dataview_station/'||t.main_station_id||'">dati e anagrafica</a>
                </p>
            </div>'                         AS marker_desc,
            metadata.f_get_icon_by_station_id( t.station_id ) AS marker_icon
        FROM
            t
            LEFT JOIN metadata.view_stations_info sm USING (station_id)
            LEFT JOIN main.municipalities m USING (mu_id)
        WHERE
            t.main_station_id IN (
                    SELECT
                        station_id
                    FROM
                        metadata.stations_status ss
                    WHERE
                        ss_suspended         IS FALSE
                        AND ss_dataview_publish  IS TRUE
                UNION
                    SELECT
                        station_id
                    FROM
                        bobo.view_user_stations vus
                    LEFT JOIN metadata.stations_status ss2 USING (station_id)
                    WHERE
                        user_id = ?
                        AND ss2.ss_suspended IS FALSE
            )
            AND sm.station_active    IS TRUE
            AND sm.station_lat_wgs84 IS NOT NULL
            AND sm.station_lon_wgs84 IS NOT NULL
            AND station_roaming_type_id IN (1,2,4) -- stazioni fisse, mobili, siti con stanziamento
            $filter_sql
        ORDER BY
            sm.station_network_type_desc, sm.station_id;
    };

    # return
    return $self->pg->db->query($sql, $userid, @binds)->hashes();
}

sub get_near_stations {
    my ( $self, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_near_stations");

    # query
    my $sql = qq{
        WITH o AS (
            SELECT
                s.station_id AS main_station_id,
                COALESCE(  ss.station_override_id, s.station_id ) AS station_id,
                CASE
                    WHEN ss.station_override_id NOTNULL THEN (
                        SELECT mu_id
                        FROM metadata.sites
                        WHERE site_id = ss.site_id
                    )
                    ELSE (
                        SELECT mu_id
                        FROM metadata.stations_municipality
                        WHERE station_id = s.station_id
                    )
                END     AS mu_id
            FROM
                metadata.stations s
                LEFT JOIN metadata.stations_sites ss ON (s.station_id = ss.station_id AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
        ),
        t AS (
            SELECT
                o.main_station_id,
                s.station_id,
                s.station_name,
                s.station_network_type_desc,
                s.station_lat_wgs84,
                s.station_lon_wgs84,
                ST_SetSRID(ST_MakePoint(s.station_lat_wgs84, s.station_lon_wgs84), 4326) AS geom
            FROM
                o
                LEFT JOIN metadata.view_stations_info s USING (station_id)
            WHERE
                o.main_station_id IN (
                    SELECT
                        station_id
                    FROM
                        metadata.stations_status
                    WHERE
                        ss_dataview_publish      IS TRUE
                        AND ss_suspended         IS FALSE
                )
                AND s.station_active IS TRUE
                AND s.station_lat_wgs84 IS NOT NULL
                AND s.station_lon_wgs84 IS NOT NULL
            ORDER BY
                station_id
        ),
        s AS (
            SELECT
                ST_SetSRID(ST_MakePoint(station_lat_wgs84, station_lon_wgs84), 4326) AS geom
            FROM
                o
                LEFT JOIN metadata.view_stations_info s USING (station_id)
            WHERE main_station_id = ?
        )
        SELECT
            main_station_id,
            station_id,
            station_name,
            station_network_type_desc AS st_network_name,
            station_lat_wgs84 AS station_lat,
            station_lon_wgs84 AS station_lon,
            round((ST_Distance(
                ST_Transform(t.geom , 2100),
                ST_Transform((SELECT s.geom FROM s) , 2100)
            ) / 1000.0)::numeric, 2) AS station_distance
        FROM
            t
        ORDER BY
            ST_Distance(t.geom, (SELECT s.geom FROM s)) ASC
        LIMIT 16;
    };

    # return
    return $self->pg->db->query($sql, $stid )->hashes();
}

sub get_all_near_stations {
    my ( $self, $userid, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_all_near_stations");

    # query
    my $sql = qq{
        WITH o AS (
            SELECT
                s.station_id AS main_station_id,
                COALESCE(  ss.station_override_id, s.station_id ) AS station_id,
                CASE
                    WHEN ss.station_override_id NOTNULL THEN (
                        SELECT mu_id
                        FROM metadata.sites
                        WHERE site_id = ss.site_id
                    )
                    ELSE (
                        SELECT mu_id
                        FROM metadata.stations_municipality
                        WHERE station_id = s.station_id
                    )
                END     AS mu_id
            FROM
                metadata.stations s
                LEFT JOIN metadata.stations_sites ss ON (s.station_id = ss.station_id AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
        ),
        t AS (
            SELECT
                o.main_station_id,
                s.station_id,
                s.station_name,
                s.station_network_type_desc,
                s.station_lat_wgs84,
                s.station_lon_wgs84,
                ST_SetSRID(ST_MakePoint(s.station_lat_wgs84, s.station_lon_wgs84), 4326) AS geom
            FROM
                o
                LEFT JOIN metadata.view_stations_info s USING (station_id)
            WHERE
                o.main_station_id IN (
                    SELECT
                        station_id
                    FROM
                        metadata.stations_status ss
                    WHERE
                        ss_suspended         IS FALSE
                        AND ss_dataview_publish  IS TRUE
                UNION
                    SELECT
                        station_id
                    FROM
                        bobo.view_user_stations vus
                    LEFT JOIN metadata.stations_status ss2 USING (station_id)
                    WHERE
                        user_id = ?
                        AND ss2.ss_suspended IS FALSE
                )
                AND s.station_active IS TRUE
                AND s.station_lat_wgs84 IS NOT NULL
                AND s.station_lon_wgs84 IS NOT NULL
            ORDER BY
                station_id
        ),
        s AS (
            SELECT
                ST_SetSRID(ST_MakePoint(station_lat_wgs84, station_lon_wgs84), 4326) AS geom
            FROM
                o
                LEFT JOIN metadata.view_stations_info s USING (station_id)
            WHERE main_station_id = ?
        )
        SELECT
            main_station_id,
            station_id,
            station_name,
            station_network_type_desc AS st_network_name,
            station_lat_wgs84 AS station_lat,
            station_lon_wgs84 AS station_lon,
            round((ST_Distance(
                ST_Transform(t.geom , 2100),
                ST_Transform((SELECT s.geom FROM s) , 2100)
            ) / 1000.0)::numeric, 2) AS station_distance
        FROM
            t
        ORDER BY
            ST_Distance(t.geom, (SELECT s.geom FROM s)) ASC
        LIMIT 16;
    };

    # return
    return $self->pg->db->query($sql, $userid, $stid )->hashes();
}

sub get_dataview_files {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_dataview_files");

    # query
    my $sql = qq{
        SELECT *
        FROM bobo_tools.dataview_files;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_stations_by_dates_params {
    my ( $self, $date_from, $date_to, $params_array ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_stations_by_dates_params");

    my $sql;
    my @binds;
    if (!defined $params_array || scalar @{$params_array} == 0) {
        # query
        $sql = qq{
            SELECT *
            FROM metadata.stations_status ss
            LEFT JOIN metadata.view_stations_info sm USING (station_id)
            WHERE sm.station_active     IS TRUE
            AND ss.ss_suspended         IS FALSE
            AND ss.ss_dataview_publish  IS TRUE
            AND station_roaming_type_id = 1 -- solo fisse
            AND (?::timestamp, ?::timestamp)
                OVERLAPS
                (station_startup_date, CASE WHEN station_dismiss_date IS NULL THEN CURRENT_TIMESTAMP ELSE station_dismiss_date END )
            ORDER BY station_name;
        };

        push @binds, $date_from, $date_to;
    }
    else {
        my $inner_sql;
        my $flag = 0;

        push @binds, $date_from, $date_to;

        for my $param (@{$params_array}){
            $self->app->log->debug($param);

            return undef
                unless looks_like_number($param);

            if ($flag) {
                $inner_sql .= qq{   INTERSECT};
            }

            $inner_sql .= qq{
                SELECT DISTINCT(station_id)
                FROM metadata.view_stations_parameters
                WHERE param_id = ?
            };

            $flag = 1;
            push @binds, $param;
        }

        # query
        $sql = qq{
            SELECT *
            FROM metadata.stations_status ss
            LEFT JOIN metadata.view_stations_info sm USING (station_id)
            WHERE sm.station_active     IS TRUE
            AND ss.ss_suspended         IS FALSE
            AND ss.ss_dataview_publish  IS TRUE
            AND station_roaming_type_id = 1 -- solo fisse
            AND (?::timestamp, ?::timestamp)
                OVERLAPS
                (station_startup_date, CASE WHEN station_dismiss_date IS NULL THEN CURRENT_TIMESTAMP ELSE station_dismiss_date END )
            AND station_id IN (
                $inner_sql
            )
            ORDER BY station_name;
        }
    }

    # return
    return $self->pg->db->query($sql, @binds )->hashes();
}

sub get_params_by_dates_stations {
    my ( $self, $date_from, $date_to, $aggr, $stations_array ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_params_by_dates_stations");

    my $sql;
    my $filter_aggr;

    if ($aggr == -1) {
        $filter_aggr = 'TRUE';
    }
    elsif ($aggr == 1) {
        $filter_aggr = 'vpi.parameter_aggr_hh_enabled';
    }
    elsif ($aggr == 2) {
        $filter_aggr = 'vpi.parameter_aggr_dd_enabled';
    }
    elsif ($aggr == 3) {
        $filter_aggr = 'vpi.parameter_aggr_mm_enabled';
    }
    else {
        $filter_aggr = 'vpi.parameter_aggr_yy_enabled';
    }

    my @binds;
    if (!defined $stations_array || scalar @{$stations_array} == 0) {
        $sql = qq{
            SELECT *
            FROM metadata.view_parameters_info vpi
            WHERE $filter_aggr IS TRUE
            AND parameter_dataview_flag IS TRUE
            ORDER BY vpi.parameter_name;
        };
    }
    else {
        my $inner_sql;
        my $flag = 0;

        
        for my $station (@{$stations_array}) {
            return undef
                unless looks_like_number($station);

            if ($flag) {
                $inner_sql .= qq{INTERSECT};
            }

            $inner_sql .= qq{
                SELECT DISTINCT(parameter_id)
                FROM metadata.view_stations_parameters
                RIGHT JOIN metadata.view_parameters_info USING (parameter_id)
                WHERE station_id = ?
                AND parameter_dataview_flag IS TRUE
            };

            $flag = 1;
            push @binds, $station;
        }

        $sql = qq{
            SELECT *
            FROM metadata.view_parameters_info vpi
            WHERE parameter_id IN (
                $inner_sql
            )
            AND $filter_aggr IS TRUE
            ORDER BY vpi.parameter_name;
        }
    }

    # return
    return $self->pg->db->query($sql, @binds)->hashes();
}

sub get_params_by_station {
    my ( $self, $station_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_params_by_station");

    # query
    my $sql = qq{
        SELECT
            vsi.station_name,
            vsp.parameter_name,
            CASE
                WHEN vsp.station_param_startup_date IS NULL THEN COALESCE(TO_CHAR(vsi.station_startup_date, 'DD/MM/YYYY HH24:MI'), '')
                ELSE TO_CHAR(vsp.station_param_startup_date, 'DD/MM/YYYY HH24:MI')
            END AS station_param_startup_date,
            CASE
                WHEN vsp.station_param_dismiss_date IS NULL THEN COALESCE(TO_CHAR(vsi.station_dismiss_date, 'DD/MM/YYYY HH24:MI'), '')
                ELSE TO_CHAR(vsp.station_param_dismiss_date, 'DD/MM/YYYY HH24:MI')
            END AS station_param_dismiss_date,
            TO_CHAR(vsi.station_startup_date, 'DD/MM/YYYY HH24:MI'),
            vsi.station_dismiss_date
        FROM metadata.view_stations_parameters vsp
        RIGHT JOIN metadata.view_parameters_info vfpd USING (parameter_id)
        LEFT JOIN metadata.view_stations_info vsi USING (station_id)
        WHERE station_id = ?
        AND vfpd.parameter_dataview_flag IS TRUE
        ORDER BY vsp.parameter_name;
    };

    # return
    return $self->pg->db->query($sql, $station_id)->hashes();
}

# -----------------------------------------------------------------------------
# JOBS
# -----------------------------------------------------------------------------
sub get_pending_jobs {
    my ( $self, $uuid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_pending_jobs");

    # query
    my $sql = qq{
        SELECT COUNT(*) AS num
        FROM
            bobo_tools.dataview_jobs_queue
        WHERE
            djq_uuid = ?
            AND ( djq_end_ts IS NULL OR djq_ack IS FALSE );
    };

    # return
    return $self->pg->db->query($sql, $uuid)->hash->{'num'};
};

sub get_pending_jobs_by_params {
    my ( $self, $uuid, $args ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_pending_jobs_by_params");

    $args = decode_utf8(encode_json($args));

    # query
    my $sql = qq{
        SELECT COUNT(*) AS num
        FROM
            bobo_tools.dataview_jobs_queue
        WHERE
            djq_uuid = ?
            -- A @> B AND A <@ B
            AND ( djq_args_obj @> ?::jsonb AND djq_args_obj <@ ?::jsonb )
            AND djq_end_ts IS NULL;
    };

    # return
    return $self->pg->db->query($sql, $uuid, $args, $args)->hash->{'num'};
};

sub get_finished_jobs {
    my ( $self, $uuid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_finished_jobs");

    # query
    my $sql = qq{
        SELECT
            djq_id        ,
            djq_uuid      ,
            djq_args_obj  ,
            djq_start_ts  ,
            djq_end_ts    ,
            djq_result_obj,
            djq_ack
        FROM
            bobo_tools.dataview_jobs_queue
        WHERE
            djq_uuid = ?
            AND djq_end_ts IS NOT NULL
            AND djq_ack IS FALSE;
    };

    # return
    return $self->pg->db->query($sql, $uuid)->hashes;
};

sub get_all_jobs {
    my ( $self, $uuid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_all_jobs");

    # query
    my $sql = qq{
        SELECT
            djq_id        ,
            TO_CHAR((djq_args_obj->>'start_d' )::timestamp, 'DD/MM/YYYY') AS start_date,
            TO_CHAR((djq_args_obj->>'end_d' )::timestamp, 'DD/MM/YYYY') AS end_date,
            CASE (djq_args_obj->>'aggr')::smallint
                WHEN 1 THEN 'Orario (GMT)'
                WHEN 2 THEN 'Giornaliero'
                ELSE 'Unknown'
            END AS aggregation,
            (
                SELECT
                    STRING_AGG(station_name, ', ')
                FROM
                    metadata.stations
                WHERE station_id::text = ANY( ARRAY( SELECT jsonb_array_elements_text(djq_args_obj->'st_ids')))
            ) AS stations,
            (
                SELECT
                    STRING_AGG(param_name, ', ')
                FROM
                    metadata.parameters
                WHERE param_id::text = ANY( ARRAY( SELECT jsonb_array_elements_text(djq_args_obj->'pr_ids')))
            ) AS parameters,
            djq_start_ts,
            djq_end_ts,
            djq_result_obj->>'link' AS download_link
        FROM
            bobo_tools.dataview_jobs_queue
        WHERE
            djq_uuid = ?
            AND djq_start_ts::date = CURRENT_DATE
        ORDER BY
            djq_start_ts DESC;
    };

    # return
    return $self->pg->db->query($sql, $uuid)->hashes;
};

sub insert_new_job {
    my ( $self, $uuid, $args ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub insert_new_job");

    # query and return
    return $self->pg->db->insert('bobo_tools.dataview_jobs_queue', {
        djq_uuid     => $uuid,
        djq_args_obj => decode_utf8(encode_json($args))
    }, { returning => 'djq_id' })->hash->{'djq_id'};
};

sub update_job_ack {
    my ( $self, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub update_notification_ack");

    # query and return
    return $self->pg->db->update('bobo_tools.dataview_jobs_queue', {
        djq_ack => 1
    }, { djq_id  => $id });
};

1;

=head1 get_dataview_options

Funzione che recupera le opzioni generali dell'applicativo Dataview.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_dataview_descriptions

Funzione che recupera le informazioni generali dell'applicativo Dataview.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_dataview_provinces

Funzione che recupera le province relative alle stazioni attive dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_dataview_all_provinces

Funzione che recupera tutte le province visibili dall'utente loggato dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_dataview_stations

Funzione che recupera le stazioni attive dal database, eventualmente filtrate per regione e/o provincia.

Argomenti:  * eventuale id della regione ('regid');

           * eventuale id della provincia ('provid');

Return:     Risultato della query.

=cut

=head1 get_dataview_all_stations

Funzione che recupera tutte le stazioni visibili dall'utente loggato dal database, eventualmente filtrate
per regione e/o provincia.

Argomenti:  * id dell'utente ('user_id');

           * eventuale id della regione ('regid');

           * eventuale id della provincia ('provid');

Return:     Risultato della query.

=cut

=head1 check_permission_station

Funzione che verifica i permessi di una determinata stazione.

Argomenti:  * id della stazione ('stid');

Return:     Risultato della query (valore booleano).

=cut

=head1 get_dataview_params

Funzione che recupera le informazioni relative ai parametri presenti
all'interno dell'applicativo Dataview.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_dataview_params_live

Funzione che recupera le informazioni relative ai dati live presenti
all'interno dell'applicativo Dataview.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_dataview_params_indicator

Funzione che recupera le informazioni relative agli indicatori presenti
all'interno dell'applicativo Dataview.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_map_stations

Funzione che recupera dal database le informazioni necessarie al
posizionamento del marker delle stazioni sulla mappa presente all'interno
dell'applicativo Dataview.

Argomenti:  * array di parametri ('params_array');

Return:     Risultato della query.

=cut

=head1 get_map_all_stations

Funzione che recupera dal database le informazioni necessarie al
posizionamento del marker delle stazioni, visibili dall'utente loggato,
sulla mappa presente all'interno dell'applicativo Dataview.

Argomenti:  * id dell'utente ('user_id');

           * array di parametri ('params_array');

Return:     Risultato della query.

=cut

=head1 get_near_stations

Funzione che recupera, dato l'id, le informazioni relative alle stazioni
poste nelle vicinanze di una determinata stazione.

Argomenti:  * id della stazione ('stid');

Return:     Risultato della query.

=cut

=head1 get_all_near_stations

Funzione che recupera, dato l'id, le informazioni relative alle stazioni, visibili
dall'utente loggato, poste nelle vicinanze di una determinata stazione.

Argomenti:  * id dell'utente ('userid');

           * id della stazione ('stid');

Return:     Risultato della query.

=cut

=head1 get_dataview_files

Funzione che recupera i files dell'applicativo Dataview.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_stations_by_dates_params

Funzione che recupera le stazioni pubbliche attive in un determinato periodo temporale e che acquisiscono i parametri selezionati dall'utente.

Argomenti:  * data d'inizio ('date_from');

           * data di fine ('date_to');

           * id del/dei parametro/i, se presente/i ('params_array');

Return:     Risultato della query.

=cut

=head1 get_params_by_dates_stations

Funzione che recupera i parametri acquisiti nelle stazioni pubbliche selezionate dall'utente.

Argomenti:  * data d'inizio ('date_from');

           * data di fine ('date_to');

           * aggregazione temporale ('aggr');

           * id della/e stazione/e, se presente/i ('stations_array');

Return:     Risultato della query.

=cut

=head1 get_params_by_station

Funzione che recupera tutte le informazioni relative ai parametri acquisiti da una determinata stazione pubblica.

Argomenti:  * id della stazione ('station_id');

Return:     Risultato della query.

=cut

=head1 get_pending_jobs

Funzione che recupera dal database il numero di richieste dell'utente nella coda di job ancora in attesa di essere eseguite.

Argomenti:  * id univoco dell'utente che ha richiesto i dati ('uuid');

Return:     Risultato della query.

=cut

=head1 get_pending_jobs_by_params

Funzione che recupera dal database il numero di richieste dell'utente nella coda di job di Dataview con determinati parametri e ancora in attesa di essere eseguite.

Argomenti:  * id univoco dell'utente che ha richiesto i dati ('uuid');

           * oggetto contenente i parametri della richiesta inseriti dall'utente ('args');

Return:     Risultato della query.

=cut

=head1 get_finished_jobs

Funzione che recupera dal database il numero di richieste completate.

Argomenti:  * id univoco dell'utente che ha richiesto i dati ('uuid');

Return:     Risultato della query.

=cut

=head1 get_all_jobs

Funzione che recupera tutte le richieste di download lanciate da un determinato utente nel giorno corrente.

Argomenti:  * id univoco dell'utente che ha richiesto i dati ('uuid');

Return:     Risultato della query.

=cut

=head1 insert_new_job

Funzione che inserisce una nuova richiesta nella coda di job di Dataview.

Argomenti:  * id univoco dell'utente che ha richiesto i dati ('uuid');

           * oggetto contenente i parametri della richiesta inseriti dall'utente ('args');

Return:     Risultato della query.

=cut

=head1 update_job_ack

Funzione che aggiorna il campo di acknowledge di una determinata richiesta nella coda di job di Dataview.

Argomenti:  * id della richiesta ('id');

Return:     Risultato della query.

=cut