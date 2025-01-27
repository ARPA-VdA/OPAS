package Bobo::Model::Dbvalidazione;

use Data::Dumper;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];
use utf8;

has 'pg';
has 'app';

# -----------------------------------------------------------------------------
# VALIDATION functions
# -----------------------------------------------------------------------------

# Getters
# -----------------------------------------------------------------------------

sub get_validation_user_options {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_validation_user_options");

    # query
    my $sql = qq{
        SELECT
            option_object
        FROM bobo_tools.validation_options
        WHERE option_user = ?;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hash();
}

sub get_validation_groups {
    my ( $self, $user_id, $flag_suspect ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_validation_groups");

    # query
    my $sql = qq{
        SELECT array_to_json(array_agg(row_to_json(t))) AS json_tree
        FROM (
            (
                SELECT
                    tree_id::text AS id,
                    '#' AS parent,
                    tree_name AS text,
                    -- 'ti-package' AS icon,
                    CASE
                        WHEN at.tree_public IS TRUE THEN 'fa-light fa-folder-open'
                        ELSE 'fa-light fa-folder'
                    END AS icon,
                    (
                        SELECT row_to_json(s)
                        FROM (
                            SELECT
                                false AS opened,
                                false AS loaded
                        ) AS s
                    ) AS state,
                    (
                        SELECT row_to_json(li)
                        FROM (
                            SELECT
                                'group'     AS type,
                                tree_id     AS id
                        ) AS li
                    ) AS li_attr
                FROM bobo_tools.view_validation_trees at
                WHERE (
                    at.tree_public IS TRUE
                    AND at.tree_owner_portal = (
                        SELECT portal_id
                        FROM bobo.users_metadata
                        WHERE us_id = ?
                    )
                )
                OR (
                    ARRAY( SELECT gr_id FROM bobo.user_groups WHERE us_id = ? ) && ARRAY( SELECT admin_gr_id FROM bobo.portal_properties )
                    AND at.tree_owner_portal = (
                        SELECT portal_id
                        FROM bobo.users_metadata
                        WHERE us_id = ?
                    )
                )
                OR at.groups_id && ARRAY(
                    SELECT gr_id
                    FROM bobo.user_groups
                    WHERE us_id = ?
                )
                OR at.tree_owner = ?
                ORDER BY tree_order
            )
    };

    if ($flag_suspect) {
        $sql .= qq{
            UNION ALL
                SELECT
                    '9999'      AS id,
                    '#'         AS parent,
                    'Sospetti'  AS text,
                    'ti-alert'  AS icon,
                    (
                        SELECT row_to_json(s)
                        FROM (
                            SELECT
                                false AS opened,
                                false AS loaded
                        ) s
                    ) AS state,
                    (
                        SELECT row_to_json(li)
                        FROM (
                            SELECT
                                'suspect'   AS type,
                                9999        AS id
                        ) li
                    ) AS li_attr
        };
    }

    $sql .= qq{    ) t  };

    # @TODO da cambiare

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $user_id, $user_id, $user_id)->hash()->{'json_tree'};
}

sub get_group_stations {
    my ( $self, $nodeid, $grid, $options, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_station_groups");
    $self->app->log->debug("stidEnabled: ".$options->{general}{stidEnabled});
    $self->app->log->debug("altitudeEnabled: ".$options->{general}{altitudeEnabled});

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT jsonb_array_elements(tree_object->'stations')::jsonb AS stations
            FROM bobo_tools.validation_trees at
            WHERE tree_id = ?
        )
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            (
                SELECT
                    ? ||'-'||s.station_id AS id,
                    s.station_name
    };
    # stidEnabled
    # altitudeEnabled
    # $options->{general}{stidEnabled} ||
    # $options->{general}{altitudeEnabled} ||
    if ($options->{general}{stidEnabled}){
        $sql .= qq{||' {'||s.station_id||'}' };
    }
    if ($options->{general}{altitudeEnabled}){
        $sql .= qq{||' [ '||(SELECT COALESCE(station_altitude::text, '--') FROM metadata.view_stations_info WHERE station_id = s.station_id )||' slm ]' };
    }

    $sql .= qq{
                AS text,
                    'ti-home' AS icon,
                     (
                        SELECT row_to_json(s)
                        FROM (
                            SELECT
                                false AS opened,
                                true AS loaded
                        ) s
                    ) AS state,
                    (
                        SELECT row_to_json(li)
                        FROM (
                            SELECT
                                'station'          AS type,
                                s.station_id       AS id,
                                CASE
                                    WHEN s.station_active IS FALSE THEN 'node-not-active'
                                    ELSE ''
                                END         AS class,
                                s.station_fulltable      AS table
                        ) li
                    ) AS li_attr
                FROM temp t
                LEFT JOIN bobo.view_user_stations s ON (t.stations->>'st_id')::integer = s.station_id
                WHERE
                    s.user_id = ?
                ORDER BY (t.stations->>'st_pos')::integer
            )
            UNION ALL
            (
                SELECT
                    ? ||'-vis-'||page_id AS id,
                    page_name   AS text,
                    'ti-new-window'  AS icon,
                    (
                        SELECT row_to_json(s)
                        FROM (
                            SELECT
                                false AS opened,
                                true AS loaded
                        ) s
                    ) AS state,
                    (
                        SELECT row_to_json(li)
                        FROM (
                            SELECT
                                'link'              AS type,
                                page_id        AS id,
                                '/str_visualizer/'||page_id AS url
                        ) li
                    ) AS li_attr
                FROM bobo_tools.view_validation_trees_pages
                WHERE tree_id = ?
                AND page_id IS NOT NULL
                ORDER BY page_name
            )
        ) d;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $grid, $nodeid, $user_id, $nodeid, $grid)->hash()->{'json_tree'};
}

sub get_group_stations_no_options {
    my ( $self, $nodeid, $grid, $user_id ) = @_;

    # logcontextmenu
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_group_stations_no_options");

    my $sql = qq{
        WITH temp AS (
            SELECT jsonb_array_elements(tree_object->'stations')::jsonb AS stations
            FROM bobo_tools.validation_trees at
            WHERE tree_id = ?
        )
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            (
                SELECT
                    ? ||'-'||s.station_id AS id,
                    s.station_name ||' [ '||(SELECT COALESCE(station_altitude::text, '--') FROM metadata.view_stations_info WHERE station_id = s.station_id )||' slm ]' AS text,
                    'ti-home' AS icon,
                     (
                        SELECT row_to_json(s)
                        FROM (
                            SELECT
                                false AS opened,
                                true AS loaded
                        ) s
                    ) AS state,
                    (
                        SELECT row_to_json(li)
                        FROM (
                            SELECT
                                'station'          AS type,
                                s.station_id       AS id,
                                CASE
                                    WHEN s.station_active IS FALSE THEN 'node-not-active'
                                    ELSE ''
                                END         AS class,
                                s.station_fulltable      AS table
                        ) li
                    ) AS li_attr
                FROM temp t
                LEFT JOIN bobo.view_user_stations s ON (t.stations->>'st_id')::integer = s.station_id
                WHERE
                    s.user_id = ?
                ORDER BY (t.stations->>'st_pos')::integer
            )
            UNION ALL
            (
                SELECT
                    ? ||'-vis-'||page_id AS id,
                    page_name   AS text,
                    'ti-new-window'  AS icon,
                    (
                        SELECT row_to_json(s)
                        FROM (
                            SELECT
                                false AS opened,
                                true AS loaded
                        ) s
                    ) AS state,
                    (
                        SELECT row_to_json(li)
                        FROM (
                            SELECT
                                'link'              AS type,
                                page_id        AS id,
                                '/str_visualizer/'||page_id AS url
                        ) li
                    ) AS li_attr
                FROM bobo_tools.view_validation_trees_pages
                WHERE tree_id = ?
                AND page_id IS NOT NULL
                ORDER BY page_name
            )
        ) d;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $grid, $nodeid, $user_id, $nodeid, $grid)->hash()->{'json_tree'};
}

sub get_group_params {
    my ( $self, $nodeid, $grid, $options, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_group_params");

    my $fullname;

    if ($options->{general}{convEnabled}) {
        $fullname = "param_name||' ['|| param_unit_conv ||']'";
    }
    else {
        $fullname = "param_name||' ['|| param_unit ||']'";
    }

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT (jsonb_array_elements(tree_object->'stations')::jsonb)->>'st_id' AS station_id
            FROM bobo_tools.validation_trees at
            WHERE tree_id = ?
        ),
        params AS (
            SELECT DISTINCT ON(param_id)
                param_id,
                param_order,
                $fullname AS param_name
            FROM temp t
            LEFT JOIN bobo.view_user_stations s ON (t.station_id)::integer = s.station_id
            LEFT JOIN metadata.stations_parameters sp ON (t.station_id)::integer = sp.station_id
            LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.parameters_info pm USING (param_id)
            LEFT JOIN bobo_tools.parameters_options po USING (param_id)
            WHERE
                s.user_id = ?
            --AND pm_info_type_fk NOT IN (12,13,14,18)
            AND pm_info_type_fk IN (1,2,3,11,15,16,17,20)
        )
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            (
                SELECT
                    ? ||'-'||param_id AS id,
                    param_name AS text,
                    'ti-stats-up' AS icon,
                    (
                        SELECT row_to_json(s)
                        FROM (
                            SELECT
                                false AS opened,
                                true AS loaded
                        ) s
                    ) AS state,
                    (
                        SELECT row_to_json(li)
                        FROM (
                            SELECT
                                'param'     AS type,
                                param_id    AS id
                        ) li
                    ) AS li_attr
                FROM params p
                ORDER BY
                    param_order, param_name
            )
            UNION ALL
            (
                SELECT
                    ? ||'-vis-'||page_id AS id,
                    page_name   AS text,
                    'ti-new-window'  AS icon,
                    (
                        SELECT row_to_json(s)
                        FROM (
                            SELECT
                                false AS opened,
                                true AS loaded
                        ) s
                    ) AS state,
                    (
                        SELECT row_to_json(li)
                        FROM (
                            SELECT
                                'link'              AS type,
                                page_id        AS id,
                                '/str_visualizer/'||page_id AS url
                        ) li
                    ) AS li_attr
                FROM bobo_tools.view_validation_trees_pages
                WHERE tree_id = ?
                AND page_id IS NOT NULL
                ORDER BY page_name
            )

        ) d;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $grid, $user_id, $nodeid, $nodeid, $grid)->hash()->{'json_tree'};
}

sub get_group_suspects {
    my ( $self, $nodeid, $user_id, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_group_suspects");

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT
                stpr_id,
                MIN(measure_date_time) AS measure_date_time
            FROM clients.auto_validation_results
            WHERE measure_date_time BETWEEN ? AND ?
            GROUP BY (stpr_id)
        ),
        temp2 AS (
            SELECT
                stpr_id,
                vsp.station_id,
                vsp.station_name,
                vsp.station_fulltable,
                vsp.parameter_id,
                vsp.parameter_name,
                measure_date_time
            FROM temp t
            LEFT JOIN metadata.view_stations_parameters vsp USING (stpr_id)
            LEFT JOIN bobo.view_user_stations s USING (station_id)
            WHERE
                s.user_id = ?
        )
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT DISTINCT ON (t.station_name)
                ? ||'-'||t.station_id       AS id,
                t.station_name              AS text,
                'ti-home'                   AS icon,
                (
                    SELECT row_to_json(s)
                    FROM (
                        SELECT
                            false           AS opened,
                            false           AS loaded
                    ) s
                ) AS state,
                (
                    SELECT row_to_json(li)
                    FROM (
                        SELECT
                            'suspect_station' AS type,
                            t.station_id   AS id,
                            t.station_fulltable      AS table
                    ) li
                ) AS li_attr
            FROM temp2 t
            ORDER BY t.station_name
        ) d;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $from, $to, $user_id, $nodeid)->hash()->{'json_tree'};
}

sub get_group_suspect_params {
    my ( $self, $stid, $nodeid, $user_id, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_group_suspect_params");

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT
                stpr_id,
                MIN(measure_date_time) AS measure_date_time
            FROM clients.auto_validation_results
            WHERE measure_date_time BETWEEN ? AND ?
            GROUP BY (stpr_id)
        ),
        temp2 AS (
            SELECT
                stpr_id,
                vsp.station_id,
                vsp.station_name,
                vsp.parameter_id,
                vsp.parameter_name,
                measure_date_time
            FROM temp t
            LEFT JOIN metadata.view_stations_parameters vsp USING (stpr_id)
            LEFT JOIN bobo.view_user_stations s USING (station_id)
            WHERE
                s.user_id = ?
        )
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT
                ? ||'-'||t2.stpr_id       AS id,
                t2.parameter_name || ' ['|| TO_CHAR(t2.measure_date_time, 'DD.MM.YYYY HH24:MI') || ']'       AS text,
                'ti-stats-up'             AS icon,
                (
                    SELECT row_to_json(s)
                    FROM (
                        SELECT
                            true AS opened,
                            true AS loaded
                    ) s
                )                   AS state,
                (
                    SELECT row_to_json(li)
                    FROM (
                        SELECT
                            'station_param'      AS type,
                            t2.stpr_id           AS id,
                            t2.measure_date_time AS date
                    ) li
                )                   AS li_attr
            FROM temp2 t2
            WHERE t2.station_id = ?
            ORDER BY t2.parameter_name
        ) d;
    };

    # return
    return $self->pg->db->query($sql, $from, $to, $user_id, $nodeid, $stid)->hash()->{'json_tree'};
}

sub get_stations_by_province {
    my ( $self, $user_id, $province_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_all_stations_by_province");

    # query
    my $sql = qq{
        WITH g AS (
            SELECT
                station_id,
                (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'100')) AS t (bit)) AS temp)::boolean AS station_insert,
                (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'010')) AS t (bit)) AS temp)::boolean AS station_update,
                (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'001')) AS t (bit)) AS temp)::boolean AS station_delete
            FROM
                bobo.view_user_stations vus
            WHERE
                user_id = ?
        )
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
            g
            LEFT JOIN metadata.view_stations_info sm USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            sm.station_active IS TRUE
            -- AND station_insert IS TRUE
            AND station_update IS TRUE
            -- not used
            -- AND sm.station_id >= 1000
    };

    if ($province_id != -1) {
        $sql .= qq{AND smu.province_id = $province_id};
    }

    $sql .= qq {
        ORDER BY
            sm.station_network_type_id, sm.station_active DESC, sm.station_name;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_ordered_stpr_by_station {
    my ( $self, $user_id, $station_id, $converted ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_ordered_stpr_by_station");

    my $fullname;
    my $unit;

    if ($converted) {
        $fullname = "parameter_name||' ['|| parameter_unit_conv ||']'";
        $unit = 'parameter_unit_conv';
    }
    else {
        $fullname = "parameter_name||' ['|| parameter_unit ||']'";
        $unit = 'parameter_unit';
    }

    # query
    my $sql = qq{
        WITH s AS (
            SELECT total_user_grants AS bit
            FROM bobo.view_user_stations
            WHERE user_id = ? AND station_id = ?
        ),
        si AS (
            SELECT bit FROM s
            UNION
            SELECT (b'100') AS bit
        ),
        su AS (
            SELECT bit FROM s
            UNION
            SELECT (b'010') AS bit
        )
        SELECT
            station_fulltable,
            station_name,
            station_param_id,
            parameter_id,
            station_param_table_id,
            $fullname AS column_name,
            parameter_decimals,
            parameter_active,
            parameter_conv,
            $unit AS unit,
            COALESCE(parameter_object->'general'->>'treatment', 'avg') AS parameter_treatment,
            (SELECT bit_and(si.bit)::integer FROM si)::boolean AS station_insert,
            (SELECT bit_and(su.bit)::integer FROM su)::boolean AS station_update
        FROM
            metadata.view_stations_parameters vsp
            LEFT JOIN bobo_tools.parameters_options po ON (po.param_id = vsp.parameter_id)
        WHERE station_id = ?
        AND station_param_active IS TRUE
        -- AND parameter_type_id NOT IN (4,5,6,12,13,14,18)
        AND parameter_type_id IN (1,2,3,11,15,16,17,20)
        ORDER BY po.param_order, station_param_table_id;
    };

    # log
    $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $user_id, $station_id, $station_id)->hashes();
}

sub get_ordered_stpr_by_param {
    my ( $self, $user_id, $param_id, $group_id, $converted ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_ordered_stpr_by_param");

    my $unit;

    if ($converted) {
        $unit = 'parameter_unit_conv';
    }
    else {
        $unit = 'parameter_unit';
    }

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT (jsonb_array_elements(tree_object->'stations')::jsonb)->>'st_id' AS station_id
            FROM bobo_tools.validation_trees at
            WHERE tree_id = ?
        )
        SELECT
            vsp.station_fulltable,
            vsp.station_param_id,
            vsp.parameter_id,
            vsp.station_param_table_id,
            vsp.station_name AS column_name,
            vsp.parameter_decimals,
            vsp.parameter_active,
            vsp.parameter_conv,
            $unit AS unit,
            COALESCE(parameter_object->'general'->>'treatment', 'avg') AS parameter_treatment,
            (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (s.total_user_grants), (b'100')) AS t (bit)) AS temp)::boolean AS station_insert,
            (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (s.total_user_grants), (b'010')) AS t (bit)) AS temp)::boolean AS station_update
        FROM temp t
        LEFT JOIN metadata.view_stations_parameters vsp ON (t.station_id)::integer = vsp.station_id
        LEFT JOIN bobo.view_user_stations s ON (t.station_id)::integer = s.station_id
        LEFT JOIN metadata.view_stations_municipality vsm ON (t.station_id)::integer = vsm.station_id
        WHERE
            s.user_id = ?
        AND parameter_id = ?
        --AND parameter_type_id NOT IN (12,13,14,18)
        AND parameter_type_id IN (1,2,3,11,15,16,17,20)
        AND station_param_active IS TRUE
        ORDER BY vsm.province_code, vsp.station_name;
    };

    # log
    $self->app->log->debug("$sql { $group_id, $user_id, $param_id }");

    # return
    return $self->pg->db->query($sql, $group_id, $user_id, $param_id)->hashes();
}

sub get_panels_list {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_panels_list");

    # query
    # estraggo le categorie associate al gruppo dell'utente
    # oppure le categorie pubbliche il cui proprietario fa parte dello stesso portale dell'utente
    my $sql = qq{
        SELECT
            page_id,
            page_name,
            category_name
        FROM bobo_tools.view_visualizer_pages vp
        WHERE category_id IN (
            SELECT
                category_id
            FROM bobo_tools.view_visualizer_categories vc
            WHERE (
                vc.category_public IS TRUE
                AND vc.category_owner_portal = (
                    SELECT portal_id
                    FROM bobo.users_metadata
                    WHERE us_id = ?
                )
            )
            OR vc.groups_id && (
                SELECT groups_id
                FROM bobo.view_users
                WHERE user_id = ?
            )
            OR vc.category_owner = ?
        )
        ORDER BY category_name, page_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $user_id)->hashes();
}

sub get_subgroup_by_id {
    my ( $self, $subgroup_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_subgroup_by_id");

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT (jsonb_array_elements(tree_object->'stations')::jsonb)->>'st_id' AS station_id
            FROM bobo_tools.validation_trees at
            WHERE tree_id = ?
        )
        SELECT
            tree_id,
            tree_name,
            tree_public,
            groups_id,
            ARRAY( SELECT * FROM temp) AS stations_id,
            panels_id::text[]
        FROM bobo_tools.view_validation_trees
        WHERE tree_id = ?;
    };

    # log
    $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $subgroup_id, $subgroup_id)->hash();
}

sub get_all_parameters {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_all_parameters");

    # query
    my $sql = qq{
        SELECT
            parameter_id,
            parameter_name,
            parameter_unit,
            parameter_conv,
            parameter_unit_conv,
            parameter_offset,
            parameter_decimals,
            parameter_active,
            COALESCE(parameter_note, '--') AS parameter_note,
            parameter_shortname,
            parameter_extra_shortname,
            parameter_type_id,
            COALESCE(parameter_type_desc, '--') AS parameter_type_desc
        FROM
            metadata.view_parameters_info vpi
            LEFT JOIN bobo_tools.parameters_options po ON (po.param_id = vpi.parameter_id)
        WHERE
            -- parameter_type_id NOT IN (12, 13, 14, 18)
            parameter_type_id IN (1,2,3,11,15,16,17,20)
        ORDER BY po.param_order, parameter_name;
    };

    # log
    $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_abndata_limits {
    my ( $self, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_abndata_limits");

    # query
    my $sql = qq{
        SELECT
            pl_id,
            param_id,
            param_name,
            pl_jd_from,
            pl_jd_to,
            COALESCE( pl_suspect_min::text, '-')         AS pl_suspect_min,
            COALESCE( pl_suspect_max::text, '-')         AS pl_suspect_max,
            COALESCE( pl_error_min::text, '-')           AS pl_error_min,
            COALESCE( pl_error_max::text, '-')           AS pl_error_max,
            COALESCE( pl_suspect_gap::text, '-')         AS pl_suspect_gap,
            COALESCE( pl_error_gap::text, '-')           AS pl_error_gap,
            COALESCE( pl_suspect_persistence::text, '-') AS pl_suspect_persistence,
            COALESCE( pl_error_persistence::text, '-')   AS pl_error_persistence,
            ARRAY(
                SELECT st_network_desc
                FROM metadata.stations_network_type
                WHERE st_network_id = ANY(pl.network_types)
            ) AS networks
        FROM clients.param_limits pl
        LEFT JOIN metadata.parameters p USING (param_id)
        WHERE network_types && ARRAY(
            SELECT
                st_network_id
            FROM bobo.view_user_networks
            WHERE user_id = ?
        )
        ORDER BY param_name, pl_jd_from;
    };

    # return
    return $self->pg->db->query($sql, $userid)->hashes();
}

sub get_abndata_limit_by_id {
    my ( $self, $plid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_abndata_limit_by_id");

    # query
    my $sql = qq{
        SELECT
            pl_id,
            param_id,
            param_name,
            param_unit,
            pl_jd_from,
            pl_jd_to,
            pl_suspect_min         AS pl_suspect_min,
            pl_suspect_max         AS pl_suspect_max,
            pl_error_min           AS pl_error_min,
            pl_error_max           AS pl_error_max,
            pl_suspect_gap         AS pl_suspect_gap,
            pl_error_gap           AS pl_error_gap,
            pl_suspect_persistence AS pl_suspect_persistence,
            pl_error_persistence   AS pl_error_persistence,
            network_types          AS networks,
            ARRAY(
                SELECT st_network_desc
                FROM metadata.stations_network_type
                WHERE st_network_id = ANY(pl.network_types)
            )                      AS networks_name
        FROM clients.param_limits pl
        LEFT JOIN metadata.parameters p USING (param_id)
        WHERE
            pl_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $plid)->hash();
}

sub get_stat_abndata_limits {
    my ( $self, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_stat_abndata_limits");

    # query
    my $sql = qq{
        SELECT
            spl_id,
            s.station_id,
            s.station_name,
            p.param_id,
            CONCAT_WS(' ', p.param_name, '- '||sp.stpr_note) AS param_name,
            spl_jd_from,
            spl_jd_to,
            COALESCE( spl_suspect_min::text, '-')            AS spl_suspect_min,
            COALESCE( spl_suspect_max::text, '-')            AS spl_suspect_max,
            COALESCE( spl_error_min::text, '-')              AS spl_error_min,
            COALESCE( spl_error_max::text, '-')              AS spl_error_max,
            COALESCE( spl_suspect_gap::text, '-')            AS spl_suspect_gap,
            COALESCE( spl_error_gap::text, '-')              AS spl_error_gap,
            COALESCE( spl_suspect_persistence::text, '-')    AS spl_suspect_persistence,
            COALESCE( spl_error_persistence::text, '-')      AS spl_error_persistence
        FROM clients.stations_param_limits spl
        LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
        LEFT JOIN metadata.stations s USING (station_id)
        LEFT JOIN metadata.parameters p USING (param_id)
        LEFT JOIN bobo.view_user_stations us USING (station_id)
        WHERE us.user_id = ?
        ORDER BY param_name, spl_jd_from;
    };

    # return
    return $self->pg->db->query($sql, $userid)->hashes();
}

sub get_stat_abndata_limit_by_id {
    my ( $self, $splid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub get_stat_abndata_limit_by_id");

    # query
    my $sql = qq{
        SELECT
            spl_id,
            stpr_id,
            s.station_id,
            s.station_name,
            p.param_id,
            p.param_name,
            p.param_unit,
            spl_jd_from,
            spl_jd_to,
            spl_suspect_min         AS spl_suspect_min,
            spl_suspect_max         AS spl_suspect_max,
            spl_error_min           AS spl_error_min,
            spl_error_max           AS spl_error_max,
            spl_suspect_gap         AS spl_suspect_gap,
            spl_error_gap           AS spl_error_gap,
            spl_suspect_persistence AS spl_suspect_persistence,
            spl_error_persistence   AS spl_error_persistence
        FROM clients.stations_param_limits spl
        LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
        LEFT JOIN metadata.stations s             USING (station_id)
        LEFT JOIN metadata.parameters p           USING (param_id)
        WHERE
            spl_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $splid)->hash();
}

# Put
# -----------------------------------------------------------------------------

sub insert_options {
    my ( $self, $user_id, $option_obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub update_options");
    $self->app->helperDumper($option_obj);

    # query and return
    return $self->pg->db->insert('bobo_tools.validation_options', {
        option_user   => $user_id,
        option_object => $option_obj
    });
}

sub insert_new_subgroup {
    my( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub insert_new_subgroup");
    $self->app->log->debug($params->{'subgroup-name'});

    my $tx;
    my $new_soubgroup_id;

    # 'subgroup-id' => '',
    # 'subgroup-fill' => '1',
    # 'subgroup-group' => [
    #                     '5',
    #                     '6',
    #                     '4'
    #                   ],
    # 'subgroup-vis[]' => [
    #                     '1',
    #                     '2',
    #                     '3',
    #                     '5'
    #                   ],
    # 'subgroup-stat[]' => [
    #                      '13050',
    #                      '2960'
    #                    ],
    # 'subgroup-name' => 'Prova'

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuova categoria e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvalidazione STEP 1");
        my @stations;
        if (ref($params->{'subgroup-stat[]'}) eq 'ARRAY') {
            @stations = @{$params->{'subgroup-stat[]'}};
        }
        elsif ($params->{'subgroup-stat[]'} ne "") {
            push @stations, $params->{'subgroup-stat[]'};
        }

        # preparo stringa nel formato (1200,1), (3110,2), (1170,3), ...
        my $inner_sql;
        my $count = 0;
        for my $stid (@stations) {
            if ($count == 0) {
                $inner_sql .= qq{ ( $stid, $count )};
            }
            else {
                $inner_sql .= qq{, ( $stid, $count )};
            }

            $count++;
        };

        my $sql = qq {
            INSERT INTO bobo_tools.validation_trees (tree_name, tree_object, tree_public, tree_owner)
            (
                WITH temp AS (
                    SELECT
                        st.station_id   ,
                        st.station_name ,
                        t.station_pos
                    FROM  ( VALUES $inner_sql ) t(station_id, station_pos)
                        LEFT JOIN metadata.view_stations_info st USING (station_id)
                    ORDER BY t.station_pos
                )
                SELECT
                    ? AS tree_name,
                    json_build_object(

                        'stations',
                        (
                            SELECT
                                json_agg(json_build_object(
                                    'st_id'  ,   t.station_id   ,
                                    'st_name',   t.station_name ,
                                    'st_pos' ,   t.station_pos
                                ))
                            FROM temp t
                        )
                    ) AS tree_object,
                    ? AS tree_public,
                    ? AS tree_owner
            )
            RETURNING tree_id;
        };

        $new_soubgroup_id = $self->pg->db->query($sql,
            $params->{'subgroup-name'},
            $self->app->helperGetBoolean($params, 'subgroup-public'),
            $user_id
        )->hash->{'tree_id'};

        # ##################################################################
        # 2 - associazione nuovo sottogruppo con i gruppi selezionati nel form se non pubblico
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvalidazione STEP 2");
        if ($self->app->helperGetBoolean($params, 'subgroup-public') == 0) {
            my @groups_id;
            if (ref($params->{'subgroup-groups'}) eq 'ARRAY') {
                @groups_id = @{$params->{'subgroup-groups'}};
            }
            elsif ($params->{'subgroup-groups'} ne "") {
                push @groups_id, $params->{'subgroup-groups'};
            }

            for my $gr_id (@groups_id){
                $self->pg->db->insert('bobo_tools.validation_trees_groups', {
                    tree_id   => $new_soubgroup_id,
                    gr_id     => $gr_id
                });
            }
        }

        # ##################################################################
        # 2 - associazione nuovo sottogruppo con pagine visualizer
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvalidazione STEP 3");

        my @pages_id;
        if (ref($params->{'subgroup-vis[]'}) eq 'ARRAY') {
            @pages_id = @{$params->{'subgroup-vis[]'}};
        }
        elsif (defined $params->{'subgroup-vis[]'} && $params->{'subgroup-vis[]'} ne "") {
            push @pages_id, $params->{'subgroup-vis[]'};
        }

        for my $pg_id (@pages_id) {
            # query
            $self->pg->db->insert('bobo_tools.validation_trees_pages', {
                tree_id => $new_soubgroup_id,
                page_id => $pg_id
            });
        }
    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return undef;
    }
    else {
       $tx->commit;
       return $new_soubgroup_id;
    }
}

sub insert_new_limit {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub insert_new_limit");

    my $tx;
    my $id;

    eval {
        $tx = $self->pg->db->begin;
        #  0: {name: "abn-plid", value: ""}
        #  1: {name: "abn-param", value: "8"}
        #  2: {name: "abn-date-from", value: "10"}
        #  3: {name: "abn-date-to", value: "50"}
        #  4: {name: "abn-error-min", value: "-15"}
        #  5: {name: "abn-susp-min", value: "0"}
        #  6: {name: "abn-susp-max", value: "5"}
        #  7: {name: "abn-error-max", value: "15"}
        #  8: {name: "abn-gap-error", value: "20"}
        #  9: {name: "abn-gap-susp", value: "15"}
        # 10: {name: "abn-pers-susp", value: "15"}
        # 11: {name: "abn-pers-error", value: "20"}


        my @nets;
        if (ref($params->{'abn-net'}) eq 'ARRAY'){
            @nets = @{$params->{'abn-net'}};
        } elsif ($params->{'abn-net'} ne ""){
            push @nets, $params->{'abn-net'};
        }

        $id = $self->pg->db->insert('clients.param_limits', {
            param_id               => $params->{'abn-param'},
            pl_jd_from             => $params->{'abn-date-from'},
            pl_jd_to               => $params->{'abn-date-to'},
            pl_suspect_min         => $self->app->helperEscapeParam($params->{'abn-susp-min'}),
            pl_suspect_max         => $self->app->helperEscapeParam($params->{'abn-susp-max'}),

            pl_error_min           => $self->app->helperEscapeParam($params->{'abn-error-min'}),
            pl_error_max           => $self->app->helperEscapeParam($params->{'abn-error-max'}),
            pl_suspect_gap         => $self->app->helperEscapeParam($params->{'abn-gap-susp'}),
            pl_error_gap           => $self->app->helperEscapeParam($params->{'abn-gap-error'}),
            pl_suspect_persistence => $self->app->helperEscapeParam($params->{'abn-pers-susp'}),
            pl_error_persistence   => $self->app->helperEscapeParam($params->{'abn-pers-error'}),

            network_types          => \@nets

        }, {returning => 'pl_id'} )->hash->{'pl_id'};
    };

    # error check
    if ($@) {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'clients_param_limits_check') != -1) {
            $self->app->log->debug("RETURN -1");
            return -1;
        }
        else {
            return 0;
        }
    }
    else {
        $tx->commit;
        return 1;
    }
}

sub insert_new_station_limit {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub insert_new_station_limit");

    my $tx;
    my $id;

    eval {
        $tx = $self->pg->db->begin;
        #  0: {name: "abn-plid", value: ""}
        #  1: {name: "abn-param", value: "8"}
        #  2: {name: "abn-date-from", value: "10"}
        #  3: {name: "abn-date-to", value: "50"}
        #  4: {name: "abn-error-min", value: "-15"}
        #  5: {name: "abn-susp-min", value: "0"}
        #  6: {name: "abn-susp-max", value: "5"}
        #  7: {name: "abn-error-max", value: "15"}
        #  8: {name: "abn-gap-error", value: "20"}
        #  9: {name: "abn-gap-susp", value: "15"}
        # 10: {name: "abn-pers-susp", value: "15"}
        # 11: {name: "abn-pers-error", value: "20"}

        $id = $self->pg->db->insert('clients.stations_param_limits', {
            stpr_id                 => $params->{'abn-param'},
            spl_jd_from             => $params->{'abn-date-from'},
            spl_jd_to               => $params->{'abn-date-to'},
            spl_suspect_min         => $self->app->helperEscapeParam($params->{'abn-susp-min'}),
            spl_suspect_max         => $self->app->helperEscapeParam($params->{'abn-susp-max'}),

            spl_error_min           => $self->app->helperEscapeParam($params->{'abn-error-min'}),
            spl_error_max           => $self->app->helperEscapeParam($params->{'abn-error-max'}),
            spl_suspect_gap         => $self->app->helperEscapeParam($params->{'abn-gap-susp'}),
            spl_error_gap           => $self->app->helperEscapeParam($params->{'abn-gap-error'}),
            spl_suspect_persistence => $self->app->helperEscapeParam($params->{'abn-pers-susp'}),
            spl_error_persistence   => $self->app->helperEscapeParam($params->{'abn-pers-error'})

        }, {returning => 'spl_id'} )->hash->{'spl_id'};
    };

    # error check
    if ($@) {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'clients_stations_param_limits_check') != -1) {
            $self->app->log->debug("RETURN -1");
            return -1;
        }
        else {
            return 0;
        }
    }
    else {
        $tx->commit;
        return 1;
    }
}

sub update_options {
    my ( $self, $user_id, $option_obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub update_options");
    # $self->app->helperDumper($macro_obj);

    # update and return result
    return $self->pg->db->update('bobo_tools.validation_options', {
        option_object => $option_obj
    }, { option_user => $user_id });
}

sub update_subgroup {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub update_subgroup");
    $self->app->log->debug($params->{'subgroup-name'});

    my $tx;
    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuova categoria e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvalidazione STEP 1");
        my @stations;
        if (ref($params->{'subgroup-stat[]'}) eq 'ARRAY') {
            @stations = @{$params->{'subgroup-stat[]'}};
        }
        elsif ($params->{'subgroup-stat[]'} ne "") {
            push @stations, $params->{'subgroup-stat[]'};
        }

        # preparo stringa nel formato (1200,1), (3110,2), (1170,3), ...
        my $inner_sql;
        my $count = 0;
        for my $stid (@stations) {
            if ($count == 0) {
                $inner_sql .= qq{ ( $stid, $count )};
            }
            else {
                $inner_sql .= qq{, ( $stid, $count )};
            }

            $count++;
        };

        my $sql = qq{
            UPDATE bobo_tools.validation_trees
            SET tree_object = (
                            WITH temp AS (
                                SELECT
                                    st.station_id   ,
                                    st.station_name ,
                                    t.station_pos
                                FROM  ( VALUES $inner_sql ) t(station_id, station_pos)
                                    LEFT JOIN metadata.view_stations_info st USING (station_id)
                                ORDER BY t.station_pos
                            )
                            SELECT
                                json_build_object(

                                    'stations',
                                    (
                                        SELECT
                                            json_agg(json_build_object(
                                                'st_id'  ,   t.station_id   ,
                                                'st_name',   t.station_name ,
                                                'st_pos' ,   t.station_pos
                                            ))
                                        FROM temp t
                                    )
                                ) AS tree_object
                            ),

                tree_name = ?,
                tree_public = ?

            WHERE tree_id = ?;
        };

        $self->pg->db->query($sql,
            $params->{'subgroup-name'},
            $self->app->helperGetBoolean($params, 'subgroup-public'),
            $params->{'subgroup-id'}
        );

        # ##################################################################
        # 2 - associazione nuovo sottogruppo con i gruppi selezionati nel form se non pubblico
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvalidazione STEP 2");

        $sql = qq{
            DELETE FROM bobo_tools.validation_trees_groups WHERE tree_id = ?
        };

        $self->pg->db->query($sql, $params->{'subgroup-id'});

        if ($self->app->helperGetBoolean($params, 'subgroup-public') == 0) {
            my @groups_id;

            if (ref($params->{'subgroup-groups'}) eq 'ARRAY') {
                @groups_id = @{$params->{'subgroup-groups'}};
            }
            elsif ($params->{'subgroup-groups'} ne "") {
                push @groups_id, $params->{'subgroup-groups'};
            }

            for my $gr_id (@groups_id) {
                $self->pg->db->insert('bobo_tools.validation_trees_groups', {
                    tree_id => $params->{'subgroup-id'},
                    gr_id   => $gr_id
                });
            }
        }

        # ##################################################################
        # 3 - associazione nuovo sottogruppo con pagine visualizer
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvalidazione STEP 3");

        $sql = qq{
            DELETE FROM bobo_tools.validation_trees_pages WHERE tree_id = ?
        };

        $self->pg->db->query($sql, $params->{'subgroup-id'});

        my @pages_id;
        if (ref($params->{'subgroup-vis[]'}) eq 'ARRAY') {
            @pages_id = @{$params->{'subgroup-vis[]'}};
        }
        elsif ($params->{'subgroup-vis[]'} ne "") {
            push @pages_id, $params->{'subgroup-vis[]'};
        }

        for my $pg_id (@pages_id) {
            $self->pg->db->insert('bobo_tools.validation_trees_pages', {
                tree_id => $params->{'subgroup-id'},
                page_id => $pg_id
            });
        }
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

sub update_limit {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub update_limit");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;
        #  0: {name: "abn-plid", value: ""}
        #  1: {name: "abn-param", value: "8"}
        #  2: {name: "abn-date-from", value: "10"}
        #  3: {name: "abn-date-to", value: "50"}
        #  4: {name: "abn-error-min", value: "-15"}
        #  5: {name: "abn-susp-min", value: "0"}
        #  6: {name: "abn-susp-max", value: "5"}
        #  7: {name: "abn-error-max", value: "15"}
        #  8: {name: "abn-gap-error", value: "20"}
        #  9: {name: "abn-gap-susp", value: "15"}
        # 10: {name: "abn-pers-susp", value: "15"}
        # 11: {name: "abn-pers-error", value: "20"}

        my @nets;
        if (ref($params->{'abn-net'}) eq 'ARRAY') {
            @nets = @{$params->{'abn-net'}};
        }
        elsif ($params->{'abn-net'} ne "") {
            push @nets, $params->{'abn-net'};
        }

        # query
        $self->pg->db->update('clients.param_limits', {
            pl_jd_from             => $params->{'abn-date-from'},
            pl_jd_to               => $params->{'abn-date-to'},
            pl_suspect_min         => $self->app->helperEscapeParam($params->{'abn-susp-min'}),
            pl_suspect_max         => $self->app->helperEscapeParam($params->{'abn-susp-max'}),

            pl_error_min           => $self->app->helperEscapeParam($params->{'abn-error-min'}),
            pl_error_max           => $self->app->helperEscapeParam($params->{'abn-error-max'}),
            pl_suspect_gap         => $self->app->helperEscapeParam($params->{'abn-gap-susp'}),
            pl_error_gap           => $self->app->helperEscapeParam($params->{'abn-gap-error'}),
            pl_suspect_persistence => $self->app->helperEscapeParam($params->{'abn-pers-susp'}),
            pl_error_persistence   => $self->app->helperEscapeParam($params->{'abn-pers-error'}),

            network_types          => \@nets

        }, { pl_id => $params->{'abn-plid'} });
    };

    # error check
    if ($@) {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'clients_param_limits_check') != -1) {
            $self->app->log->debug("RETURN -1");
            return -1;
        }
        else {
            return 0;
        }
    }
    else {
        $tx->commit;
        return 1;
    }
}

sub update_station_limit {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub update_station_limit");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;
        #  0: {name: "abn-plid", value: ""}
        #  1: {name: "abn-param", value: "8"}
        #  2: {name: "abn-date-from", value: "10"}
        #  3: {name: "abn-date-to", value: "50"}
        #  4: {name: "abn-error-min", value: "-15"}
        #  5: {name: "abn-susp-min", value: "0"}
        #  6: {name: "abn-susp-max", value: "5"}
        #  7: {name: "abn-error-max", value: "15"}
        #  8: {name: "abn-gap-error", value: "20"}
        #  9: {name: "abn-gap-susp", value: "15"}
        # 10: {name: "abn-pers-susp", value: "15"}
        # 11: {name: "abn-pers-error", value: "20"}

        # query
        $self->pg->db->update('clients.stations_param_limits', {
            spl_jd_from             => $params->{'abn-date-from'},
            spl_jd_to               => $params->{'abn-date-to'},
            spl_suspect_min         => $self->app->helperEscapeParam($params->{'abn-susp-min'}),
            spl_suspect_max         => $self->app->helperEscapeParam($params->{'abn-susp-max'}),

            spl_error_min           => $self->app->helperEscapeParam($params->{'abn-error-min'}),
            spl_error_max           => $self->app->helperEscapeParam($params->{'abn-error-max'}),
            spl_suspect_gap         => $self->app->helperEscapeParam($params->{'abn-gap-susp'}),
            spl_error_gap           => $self->app->helperEscapeParam($params->{'abn-gap-error'}),
            spl_suspect_persistence => $self->app->helperEscapeParam($params->{'abn-pers-susp'}),
            spl_error_persistence   => $self->app->helperEscapeParam($params->{'abn-pers-error'})

        }, { spl_id => $params->{'abn-plid'} });
    };

    # error check
    if ($@) {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'clients_stations_param_limits_check') != -1) {
            $self->app->log->debug("RETURN -1");
            return -1;
        }
        else {
            return 0;
        }
    }
    else {
        $tx->commit;
        return 1;
    }
}

sub delete_subgroup {
    my( $self, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub delete_subgroup");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- elimino associazioni alberi di validazione - pagine visualizer
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvalidazione STEP 1");

        my $sql = qq{
            DELETE FROM bobo_tools.validation_trees_pages WHERE tree_id = ?
        };

        $self->pg->db->query($sql, $id);

        # ##################################################################
        # 2 - elimino associazioni alberi di validazione - gruppi di autenticazione
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvalidazione STEP 2");

        $sql = qq{
            DELETE FROM bobo_tools.validation_trees_groups WHERE tree_id = ?
        };

        $self->pg->db->query($sql, $id);

        # ##################################################################
        # 2 - elimino albero di validazione
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvalidazione STEP 3");

        $sql = qq{
            DELETE FROM bobo_tools.validation_trees WHERE tree_id = ?
        };

        $self->pg->db->query($sql, $id);
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

sub delete_limit {
    my( $self, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub delete_limit");

    # query
    my $sql = qq{
        DELETE FROM clients.param_limits WHERE pl_id = ?;
    };

    # check and return
    if ($self->pg->db->query($sql, $id)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub delete_station_limit {
    my( $self, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazione sub delete_station_limit");

    # query
    my $sql = qq{
        DELETE FROM clients.stations_param_limits WHERE spl_id = ?;
    };

    # check and return
    if ($self->pg->db->query($sql, $id)){
        return 1;
    }
    else {
        return 0;
    }
}

1;

=head1 get_validation_user_options

Funzione che recupera dal database le impostazioni dell'utente per l'applicativo validazione.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_validation_groups

Funzione che recupera dal database i gruppi di stazioni, visibili dall'utente loggato, disponibili
per la validazione dati.

Argomenti:  * id dell'utente ('user_id');

           * valore booleano per la visualizzazione del gruppo 'Sospetti' ('flag_suspect');

Return:     Risultato della query.

=cut

=head1 get_group_stations

Funzione che recupera dal database le stazioni appartenenti ad un determinato gruppo con specifiche impostazioni.

Argomenti:  * id del nodo ('nodeid');

           * id del gruppo ('grid');

           * oggetto contenente le impostazioni dell'utente ('options');

           * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_group_stations_no_options

Funzione che recupera dal database le stazioni appartenenti ad un determinato gruppo, senza impostazioni specifiche.

Argomenti:  * id del nodo ('nodeid');

           * id del gruppo ('grid');

           * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_group_params

Funzione che recupera dal database i parametri appartenenti ad un determinato gruppo con specifiche impostazioni.

Argomenti:  * id del nodo ('nodeid');

           * id del gruppo ('grid');

           * oggetto contenente le impostazioni dell'utente ('options');

           * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_group_suspects

Funzione che recupera dal database le stazioni con dati sospetti visibili dall'utente loggato all'interno dello
strumento 'Validazione'.

Argomenti:  * id del nodo ('nodeid');

           * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     Risultato della query.

=cut

=head1 get_group_suspect_params

Funzione che recupera dal database i dati sospetti di una determinata stazione visibili dall'utente
loggato all'interno dello strumento 'Validazione'.

Argomenti:  * id della stazione ('stid');

           * id del nodo ('nodeid');

           * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     Risultato della query.

=cut

=head1 get_stations_by_province

Funzione che recupera dal database le informazioni relative alle stazioni,
eventualmente filtrate per provincia.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia ('province_id');

Return:     Risultato della query.

=cut

=head1 get_stations_by_param

Funzione che recupera dal database le informazioni relative alle stazioni filtrate per parametro.

Argomenti:  * id dell'utente ('user_id');

           * id del parametro ('prid');

Return:     Risultato della query.

=cut

=head1 get_ordered_stpr_by_station

Funzione che recupera dal database le informazioni relative ai parametri associati
ad una determinata stazione e ordinati per id.

Argomenti:  * id dell'utente ('user_id');

           * id della stazione ('station_id');

           * valore booleano per la conversione dei parametri ('converted');

Return:     Risultato della query.

=cut

=head1 get_ordered_stpr_by_param

Funzione che recupera dal database le informazioni relative ai parametri ordinati per id e associati
alle stazioni che, a loro volta, hanno associato un determinato parametro.

Argomenti:  * id dell'utente ('user_id');

           * id del parametro ('param_id');

           * id gruppo per associazione strumento-parametro ('group_id');

           * valore booleano per la conversione dei parametri ('converted');

Return:     Risultato della query.

=cut

=head1 get_panels_list

Funzione che recupera dal database la lista dei pannelli di Visualizer
visibili dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_subgroup_by_id

Funzione che recupera dal database la lista di stazioni associate ad un determinato gruppo
all'interno dell'applicativo 'Validazione'.

Argomenti:  * id del gruppo ('subgroup_id');

Return:     Risultato della query.

=cut

=head1 get_all_parameters

Funzione che recupera le informazioni relative ai parametri principali dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_abndata_limits

Funzione che recupera dal database le informazioni relative ai limiti impostati
per i parametri presenti all'interno del sistema.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query.

=cut

=head1 get_abndata_limit_by_id

Funzione che recupera dal database le informazioni relative ad un determinato
limite impostato per un parametro presente all'interno del sistema.

Argomenti:  * id del limite ('plid');

Return:     Risultato della query.

=cut

=head1 get_stat_abndata_limits

Funzione che recupera dal database le informazioni relative ai limiti impostati
per i parametri associati alle stazioni presenti all'interno del sistema.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query.

=cut

=head1 get_stat_abndata_limit_by_id

Funzione che recupera dal database le informazioni relative ad un determinato
limite impostato per un parametro associato ad una determinata stazione presente
all'interno del sistema.

Argomenti:  * id del limite ('splid');

Return:     Risultato della query.

=cut

=head1 insert_options

Funzione che inserisce all'interno del database le impostazioni personalizzate dall'utente
relative all'applicativo 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le impostazioni personalizzate ('option_obj');

Return:     Risultato della query.

=cut

=head1 insert_new_subgroup

Funzione che inserisce un nuovo sottogruppo di stazioni-parametri da visualizzare all'interno
dello strumento 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relative al sottogruppo
             da inserire ('params');

Return:     ID del nuovo sottogruppo inserito, oppure il valore 'undef'.

=cut

=head1 insert_new_limit

Funzione che inserisce un nuovo limite relativo ad un determinato parametro all'interno del database.

Argomenti:  * oggetto contenente le informazioni relative al nuovo limite da inserire ('params');

Return:     ID del nuovo limite inserito, oppure il valore 'undef'.

=cut

=head1 insert_new_station_limit

Funzione che inserisce un nuovo limite relativo ad un determinato parametro associato ad una
determinata stazione all'interno del database.

Argomenti:  * oggetto contenente le informazioni relative al nuovo limite da inserire ('params');

Return:     ID del nuovo limite inserito, oppure il valore 'undef'.

=cut

=head1 update_options

Funzione che aggiorna le impostazioni personalizzate dall'utente
relative all'applicativo 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le impostazioni personalizzate ('option_obj');

Return:     Risultato della query.

=cut

=head1 update_subgroup

Funzione che aggiorna un determinato sottogruppo nel database.

Argomenti:  * oggetto contenente le informazioni relative al sottogruppo
             da aggiornare ('params');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 update_limit

Funzione che aggiorna un determinato limite impostato per un parametro.

Argomenti:  * oggetto contenente le informazioni relative al limite da aggiornare ('params');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 update_station_limit

Funzione che aggiorna un determinato limite impostato per un parametro associato ad una determinata stazione.

Argomenti:  * oggetto contenente le informazioni relative al limite da aggiornare ('params');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 delete_subgroup

Funzione che elimina un determinato sottogruppo dal database.

Argomenti:  * id del sottogruppo ('id');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 delete_limit

Funzione che elimina un determinato limite impostato per un parametro.

Argomenti:  * id del limite da eliminare ('id');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 delete_station_limit

Funzione che elimina un determinato limite impostato per un parametro associato ad una determinata stazione.

Argomenti:  * id del limite da eliminare ('id');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;
=cut