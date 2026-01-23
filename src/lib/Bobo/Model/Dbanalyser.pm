package Bobo::Model::Dbanalyser;

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
# ANALYSER functions
# -----------------------------------------------------------------------------

# Getters
# -----------------------------------------------------------------------------
sub get_wind_scales {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_wind_scales");

    # query
    my $sql = qq{
        SELECT
            ws_id,
            ws_name,
            ws_obj
        FROM
            bobo_tools.wind_scales
        ORDER BY
            ws_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_wind_scale_byid {
    my ( $self, $scaleid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_wind_scale_byid");

    # query
    my $sql = qq{
        SELECT
            ws_id,
            ws_name,
            ws_obj
        FROM
            bobo_tools.wind_scales
        WHERE
            ws_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $scaleid)->hash();
}

# Ajax calls
sub get_analyser_general_options {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_analyser_general_options");

    # query
    my $sql = qq{
        SELECT
            go_obj AS option_object
        FROM
            bobo_tools.general_options
        WHERE go_tool = 'analyser'
    };

    # return
    return $self->pg->db->query($sql)->hash();
}

sub get_analyser_user_options {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_analyser_user_options");

    # query
    my $sql = qq{
        SELECT
            option_object
        FROM bobo_tools.analyser_options
        WHERE option_user = ?;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hash();
}

sub get_analyser_groups {
    my ( $self, $user_id, $options ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_analyser_groups");

    # query
    my $sql = qq{
        WITH u AS(
            SELECT
                *
            FROM
                bobo.view_user_stations
            WHERE
                user_id = ?
        )
        SELECT array_to_json(array_agg(row_to_json(t))) AS json_tree
        FROM (
            (
                SELECT
                    tree_id::text AS id,
                    '#' AS parent,
                    tree_name||'  <span class="num">'||
                        (
                            SELECT COUNT(*)
                            FROM u
                            WHERE station_id IN (
                                SELECT
                                    (s.stations->>'st_id')::integer
                                FROM
                                    ( SELECT jsonb_array_elements( tree_object->'stations' ) AS stations ) s
                            )
                        )
                    ||'</span>' AS text,
                    'ti-package' AS icon,
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
                                tree_id       AS id
                        ) AS li
                    ) AS li_attr
                FROM bobo_tools.view_analyser_trees at
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
                ORDER BY tree_order, tree_name
            )
    };

    if (!defined $options || !defined $options->{general}{allocationsEnabled} || $options->{general}{allocationsEnabled}) {
        $sql .= qq{
            UNION ALL
                SELECT
                    '-9999'      AS id,
                    '#'         AS parent,
                    'Stanziamenti mezzi mobili <span class="btn btn-circle-mini" data-toggle="tooltip" data-html="true" data-placement="top" data-custom-class="custom-tooltip" data-title="<i class=''fa-solid fa-bell fa-shake''></i> Novità (Beta testing)" style="margin-left: 2px; font-size: 0.65rem;"><i class="fa-solid fa-sparkle"></i></span>'  AS text,
                    'fa-light fa-truck'  AS icon,
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
                                'sites'   AS type,
                                -9999       AS id
                        ) li
                    ) AS li_attr
        };
    }

    $sql .= qq{
            UNION ALL
                SELECT
                    '1-'||s.station_id AS id,
                    '#' AS parent,
                    s.station_name  AS text,
                    'ti-ruler-pencil' AS icon,
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
                            'station'    AS type,
                             s.station_id  AS id,
                             '--'        AS table
                    ) li
                ) AS li_attr
                FROM u s
                LEFT JOIN metadata.stations_info vsi USING (station_id)
                WHERE
                    vsi.st_info_typology_fk = 4
        ) t
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $user_id, $user_id, $user_id, $user_id)->hash()->{'json_tree'};
}

sub get_analyser_groups_no_options {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_analyser_groups_no_options");

    # query
    my $sql = qq{
        SELECT array_to_json(array_agg(row_to_json(t))) AS json_tree
        FROM (
            (
                SELECT
                    tree_id::text AS id,
                    '#' AS parent,
                    tree_name AS text,
                    'ti-package' AS icon,
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
                                tree_id       AS id
                        ) AS li
                    ) AS li_attr
                FROM bobo_tools.view_analyser_trees at
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
                ORDER BY tree_order, tree_name
            )
        ) t
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $user_id, $user_id, $user_id)->hash()->{'json_tree'};
}

sub get_group_stations {
    my ( $self, $nodeid, $grid, $options, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_group_stations");

    # recupero id param per windrose
    my $sql_id = qq{
        SELECT param_id
        FROM metadata.parameters_info
        WHERE (pm_info_obj->'general'->>'windroseV')::boolean IS TRUE
    };

    my $prid = $self->pg->db->query($sql_id)->hash; # velocità vento

    if (!defined $prid) {
        $prid = 0;
    }
    else {
        $prid= $prid->{'param_id'};
    }

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT jsonb_array_elements(tree_object->'stations')::jsonb AS stations
            FROM bobo_tools.analyser_trees at
            WHERE tree_id = ?
        ),
        stations AS (
            SELECT DISTINCT ON (u.us_id, s.station_id)
                u.us_id AS user_id,
                s.station_id,
                s.station_name,
                ((s.station_schema || '.'::text) || COALESCE(s.station_prefix, ''::text)) || s.station_table AS station_fulltable,
                s.station_active
            FROM bobo.users u
                LEFT JOIN bobo.user_groups ug USING (us_id)
                LEFT JOIN bobo.groups g USING (gr_id)
                LEFT JOIN bobo.group_stations gs USING (gr_id)
                LEFT JOIN metadata.stations s USING (station_id)
            WHERE u.us_active IS TRUE
            AND station_id NOTNULL
            AND u.us_id = ?
        )
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT
                ? ||'-'||s.station_id AS id,
                s.station_name
    };

    # stidEnabled
    # altitudeEnabled
    if ($options->{general}{stidEnabled}) {
        $sql .= qq{ ||' {'||s.station_id||'}' };
    }
    if ($options->{general}{altitudeEnabled}) {
        $sql .= qq{ ||' [ '||(SELECT COALESCE(station_altitude::text, '--') FROM metadata.view_stations_info WHERE station_id = s.station_id )||' slm ]' };
    }

    $sql .= qq{ || COALESCE((SELECT ' <span class="mdi mdi-camera-iris windrose" data-toggle="tooltip" data-placement="top" data-original-title="Visualizza grafico: rosa dei venti" data-stid='||s.station_id||'></span>' FROM metadata.stations_parameters sp WHERE sp.station_id = s.station_id AND sp.param_id = $prid LIMIT 1), '')
                AS text,
                'ti-home' AS icon,
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
            LEFT JOIN stations s ON (t.stations->>'st_id')::integer = s.station_id
            WHERE s.station_id NOTNULL
            ORDER BY (t.stations->>'st_pos')::integer
        ) d;
    };

    # return
    return $self->pg->db->query($sql, $grid, $user_id, $nodeid)->hash()->{'json_tree'};
}

sub get_group_stations_no_options {
    my ( $self, $nodeid, $grid, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_group_stations_no_options");

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT jsonb_array_elements(tree_object->'stations')::jsonb AS stations
            FROM bobo_tools.analyser_trees at
            WHERE tree_id = ?
        ),
        stations AS (
            SELECT DISTINCT ON (u.us_id, s.station_id)
                u.us_id AS user_id,
                s.station_id,
                s.station_name,
                ((s.station_schema || '.'::text) || COALESCE(s.station_prefix, ''::text)) || s.station_table AS station_fulltable,
                s.station_active
            FROM bobo.users u
                LEFT JOIN bobo.user_groups ug USING (us_id)
                LEFT JOIN bobo.groups g USING (gr_id)
                LEFT JOIN bobo.group_stations gs USING (gr_id)
                LEFT JOIN metadata.stations s USING (station_id)
            WHERE u.us_active IS TRUE
            AND station_id NOTNULL
            AND u.us_id = ?
        )
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT
                ? ||'-'||s.station_id AS id,
                s.station_name AS text,
                'ti-home' AS icon,
                 (
                    SELECT row_to_json(s)
                    FROM (
                        SELECT
                            true AS opened,
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
            LEFT JOIN stations s ON (t.stations->>'st_id')::integer = s.station_id
            WHERE s.station_id NOTNULL
            ORDER BY (t.stations->>'st_pos')::integer
        ) d;
    };

    # return
    return $self->pg->db->query($sql, $grid, $user_id, $nodeid)->hash()->{'json_tree'};
}

sub get_subgroup_by_id {
    my ( $self, $subgroup_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_subgroup_by_id");

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT (jsonb_array_elements(tree_object->'stations')::jsonb)->>'st_id' AS station_id
            FROM bobo_tools.analyser_trees at
            WHERE tree_id = ?
        )
        SELECT
            tree_id,
            tree_name,
            tree_public,
            groups_id,
            ARRAY( SELECT * FROM temp) AS stations_id
        FROM bobo_tools.view_analyser_trees
        WHERE tree_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $subgroup_id, $subgroup_id)->hash();
}

sub get_stations_by_nets {
    my ( $self, $user_id, $prid, $nets ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_stations_by_nets");

    $prid = ($prid != -1 ? "^$prid\$": ".*");

    # query
    my $sql = qq{
        SELECT
            sm.station_id,
            sm.station_name,
            sm.station_schema,
            sm.station_table,
            sm.station_prefix,
            sm.station_fulltable,
            sm.station_active,
            sm.station_note,
            sm.station_shortname,
            sm.station_longname,
            sm.station_startup_date,
            sm.station_dismiss_date,
            sm.station_locality,
            sm.station_zone,
            sm.station_basin,
            sm.station_community,
            sm.station_north_utm,
            sm.station_east_utm,
            sm.station_altitude,
            sm.station_lat_wgs84,
            sm.station_lon_wgs84,
            sm.station_network_type_id,
            sm.station_network_type_desc,
            sm.station_roaming_type_id,
            sm.station_roaming_type_desc,
            sm.station_typology_id,
            sm.station_typology_desc,
            sm.station_metadata_note
        FROM
            metadata.view_stations_info sm
            LEFT JOIN bobo.view_user_stations us USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
            AND station_network_type_id IS NOT NULL
            AND smu.province_id::text ~ ?
    };

    # prepare binds (user_id, prid) and optionally nets array literal
    my @binds = ($user_id, $prid);

    if (scalar(@{$nets}) > 0) {
        my $nets_array = '{' . join(',', @{$nets}) . '}';
        $self->app->log->debug($nets_array);

        # use PostgreSQL ANY with a parameterized array literal to avoid interpolation
        $sql .= qq{
            AND sm.station_network_type_id = ANY((?)::int[])
        };
        push @binds, $nets_array;
    }

    $sql .= qq{
        ORDER BY
            sm.station_network_type_id, sm.station_name;
    };
    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, @binds)->hashes();
}

sub get_station_params {
    my ( $self, $nodeid, $stid, $options ) = @_;

    # log
    $self->app->log->debug("sub get_station_params");
    $self->app->log->debug($options->{general}{convEnabled});

    my $unit = 'parameter_unit_conv';
    if ($options->{general}{convEnabled} == 0) {
        $unit = 'parameter_unit';
    }

    # unique column id NEEDED for tree structure
    my $sql = qq{
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            (
            SELECT
            ?||'-'||stpr_id    AS id,
            CASE
                WHEN parameter_type_desc LIKE 'Limiti' THEN parameter_name||' ['
    };

    if ($options->{general}{limitsValueEnabled}){
        $sql .= qq{ ||parameter_offset||' ' };
    }

    # query
    $sql .= qq{ ||parameter_unit||']'
                ELSE parameter_name||' ['|| $unit ||']'
            END AS text,
            CASE
                WHEN parameter_type_desc LIKE 'Limiti' THEN 'ti-ruler-alt'
                ELSE 'ti-stats-up'
            END AS icon,
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
                        'param'                     AS type,
                        param_id                    AS prid,
                        stpr_id                     AS stprid,
                        stpr_table_id               AS tbid,
                        CASE
                            WHEN station_param_active IS FALSE THEN 'node-not-active'
                            ELSE 'drag'
                        END AS class

                ) li
            ) AS li_attr
            FROM metadata.view_stations_parameters vsp
            LEFT JOIN bobo_tools.parameters_options po USING (param_id)
            WHERE station_id = ?
            AND parameter_type_id IN (1, 2, 3, 11, 18)
            AND stpr_id IS NOT NULL
            ORDER BY
                (
                    CASE
                        WHEN parameter_type_id IN (2,3) THEN 1
                        WHEN parameter_type_id = 1 THEN 2
                        WHEN parameter_type_id IS NULL THEN 1000
                        ELSE parameter_type_id
                    END
                ) ASC, param_order ASC, parameter_name
            )
    };


    # if exist diagnostics
    my $sql2 = qq{ SELECT COUNT(*) AS num FROM metadata.view_stations_parameters WHERE station_id = ? AND parameter_type_id = 13 };
    my $num = $self->pg->db->query($sql2, $stid)->hash()->{'num'};
    if ($num > 0) {
        $sql .= qq{
            UNION ALL(
                SELECT
                    'diag-'||$stid AS id,
                    'Diagnostici'  AS text,
                    'ti-heart-broken'   AS icon,
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
                            'param' AS type,
                            'diag'  AS param_type,
                            $stid   AS id
                    ) li
                ) AS li_attr
            )
        };
    }

    $sql2 = qq{ SELECT COUNT(*) AS num FROM metadata.view_stations_parameters WHERE station_id = ? AND parameter_type_id = 12 };
    $num = $self->pg->db->query($sql2, $stid)->hash()->{'num'};
    if ($num > 0) {
        $sql .= qq{
            UNION ALL(
                SELECT
                    'cc-'||$stid AS id,
                    'Carte controllo'  AS text,
                    'icon-layers'   AS icon,
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
                            'param' AS type,
                            'cc'  AS param_type,
                            $stid   AS id
                    ) li
                ) AS li_attr
            )
        };
    }

    # if exist alarms
    $sql2 = qq{ SELECT COUNT(*) AS num FROM  metadata.view_stations_parameters WHERE station_id = ? AND parameter_type_id = 14 };
    $num = $self->pg->db->query($sql2, $stid)->hash()->{'num'};
    if ($num > 0) {
        $sql .= qq{
            UNION ALL(
                SELECT
                    'alarm-'||$stid AS id,
                    'Allarmi'       AS text,
                    'ti-announcement'    AS icon,
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
                            'param'         AS type,
                            'alarm'         AS param_type,
                            $stid           AS id
                    ) li
                ) AS li_attr
            )
        };
    }

    $sql2 = qq{
        SELECT COUNT(*) AS num
        FROM  metadata.view_stations_parameters
        WHERE station_id = ?
        AND ( parameter_type_id BETWEEN 4 AND 10 OR parameter_type_id IN (15, 16, 17, 19, 20) )
    };
    $num = $self->pg->db->query($sql2, $stid)->hash()->{'num'};
    if ($num > 0) {
        $sql .= qq{
            UNION ALL(
                SELECT
                    'others-'||$stid AS id,
                    'Altri'       AS text,
                    'ti-panel'    AS icon,
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
                            'param'         AS type,
                            'other'         AS param_type,
                            $stid           AS id
                    ) li
                ) AS li_attr
            )
        };
    }

    $sql .= qq{ ) d; };

    # return
    return $self->pg->db->query($sql, $nodeid, $stid)->hash()->{'json_tree'};
}

sub get_params_type {
    my ( $self, $nodeid, $stid, $type, $options ) = @_;

    # log
    $self->app->log->debug("sub get_params_type");
    $self->app->log->debug($options->{general}{convEnabled});

    my $unit = 'parameter_unit_conv';
    if ($options->{general}{convEnabled} == 0) {
        $unit = 'parameter_unit';
    }

    # unique column id NEEDED for tree structure
    my $sql = qq{
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT
            ?||'-'||stpr_id    AS id,
            CASE
                WHEN parameter_type_desc LIKE 'Limiti' THEN parameter_name||' ['
    };

    if ($options->{general}{limitsValueEnabled}){
        $sql .= qq{ ||parameter_offset||' ' };
    }

    $sql .= qq{ ||parameter_unit||']'
                ELSE parameter_name||' ['|| $unit ||']'
            END AS text,
            CASE
                WHEN parameter_type_desc LIKE 'Diagnostici' THEN 'ti-pulse'
                WHEN parameter_type_desc LIKE 'Allarmi' THEN 'ti-alarm-clock'
                ELSE 'ti-stats-up'
            END AS icon,
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
                        'param'                     AS type,
                        param_id                    AS prid,
                        stpr_id                     AS stprid,
                        stpr_table_id               AS tbid,
                        CASE
                            WHEN station_param_active IS FALSE THEN 'node-not-active'
                            ELSE 'drag'
                        END AS class

                ) li
            ) AS li_attr
            FROM metadata.view_stations_parameters vsp
            LEFT JOIN bobo_tools.parameters_options po USING (param_id)
            WHERE station_id = ?
    };

    if ($type eq 'cc') {
        $sql .= qq{ AND parameter_type_id = 12 };
    }
    elsif ($type eq 'diag') {
        $sql .= qq{ AND parameter_type_id = 13 };
    }
    elsif ($type eq 'other') {
        $sql .= qq{ AND ( parameter_type_id BETWEEN 4 AND 10 OR parameter_type_id IN (15, 16, 17, 19, 20) ) };
    }
    else {
        $sql .= qq{ AND parameter_type_id = 14 };
    }

    $sql .= qq{
            AND stpr_id IS NOT NULL
            ORDER BY parameter_name
        ) d;
    };

    # return
    return $self->pg->db->query($sql, $nodeid, $stid)->hash()->{'json_tree'};
}

sub get_allocations {
    my ( $self, $nodeid, $user_id, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_allocations");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                ss.station_id 							AS main_station_id,
                ss.station_override_id 					AS station_id,
                MAX(s.station_name) 					AS station_name,
                MAX(((s.station_schema || '.'::text) || COALESCE(s.station_prefix, ''::text)) || s.station_table) AS station_fulltable,
                BOOL_AND(s.station_active)                   AS station_active
            FROM 
                metadata.stations_sites ss
                LEFT JOIN metadata.stations s ON s.station_id = ss.station_override_id
            WHERE 
                ss.station_id IN (
                    SELECT station_id
                    FROM bobo.view_user_stations
                    WHERE user_id = ?
                )
                AND tsrange(?::timestamp, ?::timestamp, '[]') && tsrange(stsi_startup_date, stsi_dismiss_date, '[]')
            GROUP BY
                ss.station_id, ss.station_override_id
        )
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT DISTINCT ON (t.station_name)
                ? ||'-'||t.station_id AS id,
                t.station_name              AS text,
                'fa-light fa-location-crosshairs'  AS icon,
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
                            'site_params'     AS type,
                            t.main_station_id AS main_station_id,
                            t.station_id      AS id,
                            CASE
                                WHEN t.station_active IS FALSE THEN 'node-not-active'
                                ELSE ''
                            END         AS class,
                            t.station_fulltable      AS table
                    ) li
                ) AS li_attr
            FROM t
            ORDER BY t.station_name
        ) d;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to, $nodeid)->hash()->{'json_tree'};
}

sub get_allocation_params {
    my ( $self, $nodeid, $stid, $options ) = @_;

    # log
    $self->app->log->debug("sub get_allocation_params");
    $self->app->log->debug($options->{general}{convEnabled});

    my $unit = 'parameter_unit_conv';
    if ($options->{general}{convEnabled} == 0) {
        $unit = 'parameter_unit';
    }

    # unique column id NEEDED for tree structure
    my $sql = qq{
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            (
            SELECT
            ?||'-'||stpr_id    AS id,
            CASE
                WHEN parameter_type_desc LIKE 'Limiti' THEN parameter_name||' ['
    };

    if ($options->{general}{limitsValueEnabled}){
        $sql .= qq{ ||parameter_offset||' ' };
    }

    # query
    $sql .= qq{ ||parameter_unit||']'
                ELSE parameter_name||' ['|| $unit ||']'
            END AS text,
            CASE
                WHEN parameter_type_desc LIKE 'Limiti' THEN 'ti-ruler-alt'
                ELSE 'ti-stats-up'
            END AS icon,
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
                        'param'                     AS type,
                        param_id                    AS prid,
                        stpr_id                     AS stprid,
                        stpr_table_id               AS tbid,
                        CASE
                            WHEN station_param_active IS FALSE THEN 'node-not-active'
                            ELSE 'drag'
                        END AS class

                ) li
            ) AS li_attr
            FROM metadata.view_sites_parameters vsp
            LEFT JOIN bobo_tools.parameters_options po USING (param_id)
            WHERE station_id = ?
            AND parameter_type_id IN (1, 2, 3, 11, 18)
            AND stpr_id IS NOT NULL
            ORDER BY
                (
                    CASE
                        WHEN parameter_type_id IN (2,3) THEN 1
                        WHEN parameter_type_id = 1 THEN 2
                        WHEN parameter_type_id IS NULL THEN 1000
                        ELSE parameter_type_id
                    END
                ) ASC, param_order ASC, parameter_name
            )
    };

    # if exist diagnostics
    my $sql2 = qq{ SELECT COUNT(*) AS num FROM metadata.view_sites_parameters WHERE station_id = ? AND parameter_type_id = 13 };
    my $num = $self->pg->db->query($sql2, $stid)->hash()->{'num'};
    if ($num > 0) {
        $sql .= qq{
            UNION ALL(
                SELECT
                    'diag-'||$stid AS id,
                    'Diagnostici'  AS text,
                    'ti-heart-broken'   AS icon,
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
                            'site_params_type' AS type,
                            'diag'  AS param_type,
                            $stid   AS id
                    ) li
                ) AS li_attr
            )
        };
    }

    $sql2 = qq{ SELECT COUNT(*) AS num FROM metadata.view_sites_parameters WHERE station_id = ? AND parameter_type_id = 12 };
    $num = $self->pg->db->query($sql2, $stid)->hash()->{'num'};
    if ($num > 0) {
        $sql .= qq{
            UNION ALL(
                SELECT
                    'cc-'||$stid AS id,
                    'Carte controllo'  AS text,
                    'icon-layers'   AS icon,
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
                            'site_params_type' AS type,
                            'cc'  AS param_type,
                            $stid   AS id
                    ) li
                ) AS li_attr
            )
        };
    }

    # if exist alarms
    $sql2 = qq{ SELECT COUNT(*) AS num FROM  metadata.view_sites_parameters WHERE station_id = ? AND parameter_type_id = 14 };
    $num = $self->pg->db->query($sql2, $stid)->hash()->{'num'};
    if ($num > 0) {
        $sql .= qq{
            UNION ALL(
                SELECT
                    'alarm-'||$stid AS id,
                    'Allarmi'       AS text,
                    'ti-announcement'    AS icon,
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
                            'site_params_type'         AS type,
                            'alarm'         AS param_type,
                            $stid           AS id
                    ) li
                ) AS li_attr
            )
        };
    }

    $sql2 = qq{
        SELECT COUNT(*) AS num
        FROM  metadata.view_sites_parameters
        WHERE station_id = ?
        AND ( parameter_type_id BETWEEN 4 AND 10 OR parameter_type_id IN (15, 16, 17, 19, 20) )
    };
    $num = $self->pg->db->query($sql2, $stid)->hash()->{'num'};
    if ($num > 0) {
        $sql .= qq{
            UNION ALL(
                SELECT
                    'others-'||$stid AS id,
                    'Altri'       AS text,
                    'ti-panel'    AS icon,
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
                            'site_params_type'  AS type,
                            'other'             AS param_type,
                            $stid               AS id
                    ) li
                ) AS li_attr
            )
        };
    }

    $sql .= qq{ ) d; };

    # return
    return $self->pg->db->query($sql, $nodeid, $stid)->hash()->{'json_tree'};
}

sub get_allocation_params_type{
    my ( $self, $nodeid, $stid, $type, $options ) = @_;

    # log
    $self->app->log->debug("sub get_params_type");
    $self->app->log->debug($options->{general}{convEnabled});

    my $unit = 'parameter_unit_conv';
    if ($options->{general}{convEnabled} == 0) {
        $unit = 'parameter_unit';
    }

    # unique column id NEEDED for tree structure
    my $sql = qq{
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT
            ?||'-'||stpr_id    AS id,
            CASE
                WHEN parameter_type_desc LIKE 'Limiti' THEN parameter_name||' ['
    };

    if ($options->{general}{limitsValueEnabled}){
        $sql .= qq{ ||parameter_offset||' ' };
    }

    $sql .= qq{ ||parameter_unit||']'
                ELSE parameter_name||' ['|| $unit ||']'
            END AS text,
            CASE
                WHEN parameter_type_desc LIKE 'Diagnostici' THEN 'ti-pulse'
                WHEN parameter_type_desc LIKE 'Allarmi' THEN 'ti-alarm-clock'
                ELSE 'ti-stats-up'
            END AS icon,
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
                        'param'          AS type,
                        param_id         AS prid,
                        stpr_id          AS stprid,
                        stpr_table_id    AS tbid,
                        CASE
                            WHEN station_param_active IS FALSE THEN 'node-not-active'
                            ELSE 'drag'
                        END AS class

                ) li
            ) AS li_attr
            FROM metadata.view_sites_parameters vsp
            LEFT JOIN bobo_tools.parameters_options po USING (param_id)
            WHERE station_id = ?
    };

    if ($type eq 'cc') {
        $sql .= qq{ AND parameter_type_id = 12 };
    }
    elsif ($type eq 'diag') {
        $sql .= qq{ AND parameter_type_id = 13 };
    }
    elsif ($type eq 'other') {
        $sql .= qq{ AND ( parameter_type_id BETWEEN 4 AND 10 OR parameter_type_id IN (15, 16, 17, 19, 20) ) };
    }
    else {
        $sql .= qq{ AND parameter_type_id = 14 };
    }

    $sql .= qq{
            AND stpr_id IS NOT NULL
            ORDER BY parameter_name
        ) d;
    };

    # return
    return $self->pg->db->query($sql, $nodeid, $stid)->hash()->{'json_tree'};
}

sub get_categories_list {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("sub get_categories_list");

    # estraggo le categorie associate al gruppo dll'utente
    # oppure le categorie pubbliche il cui proprietario fa parte dello stesso portale dell'utente
    my $sql = qq{
        SELECT
            category_id,
            category_name,
            category_public,
            ARRAY(
                SELECT gr_name
                FROM bobo.groups
                WHERE gr_id  = ANY (groups_id)
            ) AS category_groups_name
        FROM bobo_tools.view_analyser_categories ac
        WHERE (
            ac.category_public IS TRUE
            AND ac.category_owner_portal = (
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
        )
        OR ac.groups_id && (
            SELECT groups_id
            FROM bobo.view_users
            WHERE user_id = ?
        )
        OR ac.category_owner = ?
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $user_id)->hashes();
}

sub get_category_byid {
    my ( $self, $cat_id ) = @_;

    # log
    $self->app->log->debug("sub get_category_byid");

    # estraggo le categorie associate al gruppo dll'utente
    # oppure le categorie pubbliche il cui proprietario fa parte dello stesso portale dell'utente
    my $sql = qq{
        SELECT
            category_id,
            category_name,
            category_public,
            groups_id AS category_groups,
            ARRAY(
                SELECT gr_name
                FROM bobo.groups
                WHERE gr_id  = ANY (groups_id)
            ) AS category_groups_name
        FROM bobo_tools.view_analyser_categories ac
        WHERE category_id = ?
    };

    # return
    return $self->pg->db->query($sql, $cat_id)->hash();
}

sub get_groups {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("sub get_groups");

    # query
    my $sql = qq{

        SELECT array_to_json(array_agg(row_to_json(t))) AS json_tree
        FROM (
            SELECT
                category_id AS id,
                '#' AS parent,
                category_name AS text,
                CASE
                    WHEN ac.category_public IS TRUE THEN 'fa-light fa-folder-open'
                    ELSE 'fa-light fa-folder'
                END AS icon,
                -- CASE
                --     WHEN ac.category_public IS TRUE THEN 'fa-light fa-envelope-open'
                --     ELSE 'fa-light fa-envelope'
                -- END AS icon,
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
                            category_id       AS id
                    ) AS li
                ) AS li_attr
            FROM bobo_tools.view_analyser_categories ac
            WHERE (
                ac.category_public IS TRUE
                AND ac.category_owner_portal = (
                    SELECT portal_id
                    FROM bobo.users_metadata
                    WHERE us_id = ?
                )
            )
            OR ac.groups_id && (
                SELECT groups_id
                FROM bobo.view_users
                WHERE user_id = ?
            )
            OR ac.category_owner = ?
        ) t
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $user_id)->hash()->{'json_tree'};
}

sub get_group_macros {
    my ( $self, $nodeid, $grid, $options ) = @_;

    # log
    $self->app->log->debug("sub get_group_macros");

    my $flag_loaded = 'true';
    if ($options->{general}{paramsEnabled}) {
        $flag_loaded = 'false';
    }

    # query
    my $sql = qq{
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT
            ?||'-'||macro_id AS id,
            macro_name AS text,
            'ti-widget' AS icon,
            (
                SELECT row_to_json(s)
                FROM (
                    SELECT
                        false AS opened,
                        $flag_loaded AS loaded
                ) s
            ) AS state,
            (
                SELECT row_to_json(li)
                FROM (
                    SELECT
                        'macro'     AS type,
                        macro_id    AS id,
                        'macro'     AS class

                ) li
            ) AS li_attr
            FROM bobo_tools.view_analyser_macros
            WHERE category_id = ?
            ORDER BY macro_name
        ) d;
    };

    # return
    return $self->pg->db->query($sql, $nodeid, $grid)->hash()->{'json_tree'};
}

sub get_macro_params {
    my ( $self, $nodeid, $macroid ) = @_;

    # log
    $self->app->log->debug("sub get_macro_params");

    # query
    my $sql = qq{
         WITH t AS(
            SELECT
                jsonb_array_elements(macro_object->'params')->>'name' AS name,
                jsonb_array_elements(macro_object->'params')->>'unit' AS unit,
                jsonb_array_elements(macro_object->'params')->>'station' AS station
            FROM bobo_tools.analyser_macros
            WHERE macro_id = ?
        )
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT
            name||' ['||unit||'] - '|| station AS text,
            'ti-stats-up' AS icon,
            (
                SELECT row_to_json(s)
                FROM (
                    SELECT
                        true AS opened,
                        true AS loaded
                ) s
            ) AS state
            FROM t
            ORDER BY 1
        ) d;
    };

    # return
    return $self->pg->db->query($sql, $macroid)->hash()->{'json_tree'};
}

sub get_macro_byid {
    my ( $self, $mcid ) = @_;

    # log
    $self->app->log->debug("sub get_macro");

    # query
    my $sql = qq{
        SELECT
            macro_category,
            macro_object
        FROM bobo_tools.analyser_macros
        WHERE macro_id = ?;
    };

    # return
    return $self->pg->db->query( $sql, $mcid )->hash();
}

sub get_info_param {
    my ( $self, $stprid, $conv ) = @_;

    # log
    $self->app->log->debug("sub get_info_param");
    $self->app->log->debug("$conv");

    my $unit = 'parameter_unit_conv';
    if ($conv eq 'false') {
        $unit = 'parameter_unit';
    }

    # query
    my $sql = qq{
        SELECT
            stpr_id             AS st_pr_id,
            parameter_name      AS name,
            param_id            AS param_id,
            station_name        AS station,
            station_name||' '||parameter_name||' ['|| $unit ||']'    AS legend,
            parameter_name||' ['|| $unit ||'] <br>'||station_name   AS column_name,
            $unit AS unit,
            COALESCE(parameter_object ->'general'->>'treatment', 'avg')        AS treatment,
            'line'              AS chartstyle,
            'FFFFFF'            AS color,
            2                   AS line_width,

            ?::boolean          AS converted,

            -- 24/07/2024 10:04 update for conversion coefficient history management
            -- CASE
            --     WHEN conv THEN
            --                 CASE
            --                     WHEN parameter_conv = 0 THEN 'y='||COALESCE(parameter_offset::text, '0')
            --                     WHEN parameter_conv = 1 THEN 'y=x'||COALESCE('+'||parameter_offset::text, '')
            --                     ELSE 'y='||parameter_conv||'*x'||COALESCE('+'||parameter_offset::text, '')
            --                 END
            --     ELSE
            --         CASE
            --             WHEN parameter_conv = 0 THEN 'y='||COALESCE(parameter_offset::text, '0')
            --             ELSE 'y=x'||COALESCE('+'||parameter_offset::text, '')
            --         END
            -- END AS formule,
            CASE
                WHEN parameter_conv = 0 THEN 'y='||COALESCE(parameter_offset::text, '0')
                ELSE 'y=x'||COALESCE('+'||parameter_offset::text, '')
            END AS formule,

            parameter_decimals  AS decimals,
            CASE
                WHEN parameter_type_desc LIKE 'Limiti' THEN TRUE
                ELSE FALSE
            END AS is_limit
    };

    if($stprid < 0){
        $sql .= qq{FROM metadata.view_sites_parameters };
    }
    else {    
        $sql .= qq{FROM metadata.view_stations_parameters };
    }

    $sql .= qq{
        WHERE stpr_id = ?;
    };

    # return
    return $self->pg->db->query( $sql, $conv, $stprid )->hash();
}

sub insert_options {
    my ( $self, $user_id, $option_obj ) = @_;

    # log
    $self->app->helperDumper($option_obj);

    # query and return
    return $self->pg->db->insert('bobo_tools.analyser_options', {
        option_user   => $user_id,
        option_object => $option_obj
    });
}

sub insert_category {
    my( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub insert_category");
    $self->app->log->debug($params->{'new-cat-name'});

    my $tx;
    my $new_cat_id;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuova categoria e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 1");

        $new_cat_id = $self->pg->db->insert('bobo_tools.analyser_categories', {
            cat_name   => $self->app->helperEscapeParam($params->{'new-cat-name'}),
            cat_public => $self->app->helperGetBoolean($params, 'new-cat-public'),
            cat_owner  => $user_id
        }, {returning => 'cat_id'})->hash->{'cat_id'};

        # ##################################################################
        # 2 - associazione nuova categoria con i gruppi selezionati nel form
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 2");

        my @groups_id;

        if (ref($params->{'new-cat-groups'}) eq 'ARRAY') {
            @groups_id = @{$params->{'new-cat-groups'}};
        }
        elsif ($params->{'new-cat-groups'} ne "") {
            push @groups_id, $params->{'new-cat-groups'};
        }

        for my $gr_id (@groups_id) {
            $self->pg->db->insert('bobo_tools.analyser_category_groups', {
                cat_id => $new_cat_id,
                gr_id  => $gr_id
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
       return $new_cat_id;
    }
}

sub insert_macro {
    my ( $self, $macro_cat, $macro_obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub insert_macro");

    # query and return
    return $self->pg->db->insert('bobo_tools.analyser_macros', {
        macro_category => $macro_cat == -1 ? 1 : $macro_cat,
        macro_object   => $macro_obj
    }, {returning => 'macro_id'})->hash->{'macro_id'};
}

sub insert_macro_duplication {
    my ( $self, $macro_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub insert_macro_duplication");

    my $tx;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1 - insert della nuova macro
        # ##################################################################

        # query
        my $sql = qq{
            INSERT INTO bobo_tools.analyser_macros (macro_category, macro_object)
            (
                SELECT
                    macro_category,
                    jsonb_set( macro_object, '{macro, name}',  ('"' || (macro_object->'macro'->>'name') || ' - Copia"')::jsonb ) AS macro_object
                FROM
                    bobo_tools.analyser_macros
                WHERE
                    macro_id = ?
            );
        };

        $self->pg->db->query($sql, $macro_id);
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

sub insert_new_subgroup {
    my( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub insert_new_subgroup");
    $self->app->log->debug($params->{'subgroup-name'});

    my $tx;
    my $new_soubgroup_id;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuova categoria e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 1");

        my @stations;

        if (ref($params->{'subgroup-stat[]'}) eq 'ARRAY') {
            @stations = @{$params->{'subgroup-stat[]'}};
        }
        elsif ($params->{'subgroup-stat[]'} ne "") {
            push @stations, $params->{'subgroup-stat[]'};
        }

        # prepare parallel arrays for station ids and positions
        my @positions = ();
        if (@stations) {
            @positions = (0 .. $#stations);
        }

        my $stations_array  = (@stations) ? '{' . join(',', @stations) . '}'  : '{}';
        my $positions_array = (@positions) ? '{' . join(',', @positions) . '}' : '{}';

        # query - use unnest on the two arrays to avoid interpolating VALUES
        my $sql = qq {
            INSERT INTO bobo_tools.analyser_trees (tree_name, tree_object, tree_public, tree_owner)
            (
                WITH temp AS (
                    SELECT
                        st.station_id   ,
                        st.station_name ,
                        t.station_pos
                    FROM  ( SELECT * FROM unnest((?)::int[], (?)::int[]) AS t(station_id, station_pos) ) t
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

        $new_soubgroup_id = $self->pg->db->query(
            $sql,
            $stations_array ,
            $positions_array,
            $params->{'subgroup-name'},
            $self->app->helperGetBoolean($params, 'subgroup-public'),
            $user_id
        )->hash->{'tree_id'};

        # ##################################################################
        # 2 - associazione nuovo sottogruppo con i gruppi selezionati nel form se non pubblico
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 2");

        if ($self->app->helperGetBoolean($params, 'subgroup-public') == 0) {
            my @groups_id;

            if (ref($params->{'subgroup-groups'}) eq 'ARRAY') {
                @groups_id = @{$params->{'subgroup-groups'}};
            }
            elsif ($params->{'subgroup-groups'} ne "") {
                push @groups_id, $params->{'subgroup-groups'};
            }

            for my $gr_id (@groups_id) {
                $self->pg->db->insert('bobo_tools.analyser_trees_groups', {
                    tree_id => $new_soubgroup_id,
                    gr_id   => $gr_id
                });
            }
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

sub update_options {
    my ( $self, $user_id, $option_obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub update_options");
    # $self->app->helperDumper($macro_obj);

    # return
    return $self->pg->db->update('bobo_tools.analyser_options' , {
        option_object => $option_obj
    }, {option_user => $user_id});
}

sub update_category {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub update_category");
    $self->app->log->debug($params->{'new-cat-name'});

    my $tx;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1- modifica utente
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 1");

        # $db->update('some_table', {foo => 'bar'}, {id => 23});
        $self->pg->db->update('bobo_tools.analyser_categories', {
            cat_name   => $self->app->helperEscapeParam($params->{'new-cat-name'}),
            cat_public => $self->app->helperGetBoolean($params, 'new-cat-public')
        }, {cat_id => $params->{'new-cat-id'}});

        # ##################################################################
        # 2- eliminazione associazioni categoria-gruppi e inserimento nuove associazioni
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 2");

        # query
        my $sql = qq{
            DELETE FROM bobo_tools.analyser_category_groups WHERE cat_id = ?
        };

        $self->pg->db->query($sql, $params->{'new-cat-id'});

        my @groups_id;

        if (ref($params->{'new-cat-groups'}) eq 'ARRAY') {
            @groups_id = @{$params->{'new-cat-groups'}};
        }
        elsif ($params->{'new-cat-groups'} ne "") {
            push @groups_id, $params->{'new-cat-groups'};
        }

        for my $gr_id (@groups_id) {
            $self->pg->db->insert('bobo_tools.analyser_category_groups', {
                cat_id => $params->{'new-cat-id'},
                gr_id  => $gr_id
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

sub update_macro {
    my ( $self, $macro_id, $macro_cat, $macro_obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub update_macro");
    # $self->app->helperDumper($macro_obj);

    # query and return
    return $self->pg->db->update('bobo_tools.analyser_macros', {
        macro_category => $macro_cat == -1 ? 1 : $macro_cat,
        macro_object   => $macro_obj
    }, {macro_id => $macro_id});
}

sub update_subgroup {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub update_subgroup");
    $self->app->log->debug($params->{'subgroup-name'});

    my $tx;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuova categoria e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 1");

        my @stations;

        if (ref($params->{'subgroup-stat[]'}) eq 'ARRAY') {
            @stations = @{$params->{'subgroup-stat[]'}};
        }
        elsif ($params->{'subgroup-stat[]'} ne "") {
            push @stations, $params->{'subgroup-stat[]'};
        }

        # prepare parallel arrays for station ids and positions
        my @positions = ();
        if (@stations) {
            @positions = (0 .. $#stations);
        }

        my $stations_array  = (@stations) ? '{' . join(',', @stations) . '}'  : '{}';
        my $positions_array = (@positions) ? '{' . join(',', @positions) . '}' : '{}';

        # query
        my $sql = qq {
            UPDATE bobo_tools.analyser_trees
            SET tree_object = (
                WITH temp AS (
                    SELECT
                        st.station_id   ,
                        st.station_name ,
                        t.station_pos
                    FROM  ( SELECT * FROM unnest((?)::int[], (?)::int[]) AS t(station_id, station_pos) ) t
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
            $stations_array,        # unnest 1
            $positions_array,       # unnest 2
            $params->{'subgroup-name'},
            $self->app->helperGetBoolean($params, 'subgroup-public'),
            $params->{'subgroup-id'}
        );

        # ##################################################################
        # 2 - associazione nuovo sottogruppo con i gruppi selezionati nel form se non pubblico
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 2");

        $sql = qq{
            DELETE FROM bobo_tools.analyser_trees_groups WHERE tree_id = ?
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
                $self->pg->db->insert('bobo_tools.analyser_trees_groups', {
                    tree_id => $params->{'subgroup-id'},
                    gr_id   => $gr_id
                });
            }
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

sub delete_category {
    my ( $self, $cat_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub delete_category");
    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- elimino macro associate alla categoria
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 1");
        my $sql = qq{
            DELETE FROM bobo_tools.analyser_macros WHERE macro_category = ?
        };

        $self->pg->db->query($sql, $cat_id);

        # ##################################################################
        # 2- eliminazione associazioni categoria-gruppi
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 2");

        $sql = qq{
            DELETE FROM bobo_tools.analyser_category_groups WHERE cat_id = ?
        };

        $self->pg->db->query($sql, $cat_id);

        # ##################################################################
        # 3- eliminazione categoria
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 3");
        $sql = qq{
            DELETE FROM bobo_tools.analyser_categories WHERE cat_id = ?
        };

        $self->pg->db->query($sql, $cat_id);
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

sub delete_macro_byid {
    my ( $self, $mcid ) = @_;

    # log
    $self->app->log->debug("sub delete_macro_byid");

    # query
    my $sql = qq{
        DELETE FROM bobo_tools.analyser_macros
        WHERE macro_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $mcid);
}

sub delete_subgroup {
    my( $self, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub delete_subgroup");

    my $tx;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1 - elimino associazioni alberi di validazione - gruppi di autenticazione
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 2");

        my $sql = qq{
            DELETE FROM bobo_tools.analyser_trees_groups WHERE tree_id = ?
        };

        $self->pg->db->query($sql, $id);

        # ##################################################################
        # 2 - elimino albero di validazione
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbanalyser STEP 3");

        $sql = qq {
            DELETE FROM bobo_tools.analyser_trees WHERE tree_id = ?
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

1;

=head1 get_wind_scales

Funzione che recupera le scale di vento dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_wind_scale_byid

Funzione che recupera le informazioni relative ad una determinata scala di vento dal database.

Argomenti:  * id della scala di vento ('scaleid');

Return:     Risultato della query.

=cut

=head1 get_analyser_general_options

Funzione che recupera le impostazioni generali, valide per tutti, dello
strumento 'Analyser' dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_analyser_user_options

Funzione che recupera le impostazioni, personalizzate da un determinato utente,
dello strumento 'Analyser' dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_analyser_groups

Funzione che recupera i gruppi di stazioni/parametri (l'albero di destra), visibili
dall'utente loggato, dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_analyser_groups_no_options

Funzione che recupera i gruppi di stazioni/parametri (l'albero di destra), visibili
dall'utente loggato, dal database, ad eccezione delle opzioni html nel nome del nodo.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_group_stations

Funzione che recupera le informazioni necessarie a generare l'albero delle stazioni
all'interno dello strumento 'Analyser' sulla destra.

Argomenti:  * id del nodo ('nodeid');

           * id del gruppo ('grid');

           * oggetto contenente informazioni aggiuntive per l'albero ('options');

           * id dell'utente ('user_id');

Return:     Oggetto json per la costruzione dell'albero.

=cut

=head1 get_group_stations_no_options

Funzione che recupera le informazioni necessarie a generare l'albero all'interno
dello strumento 'Analyser' sulla destra, senza informazioni aggiuntive.

Argomenti:  * id del nodo ('nodeid');

           * id del gruppo ('grid');

           * id dell'utente ('user_id');

Return:     Oggetto json per la costruzione dell'albero.

=cut

=head1 get_subgroup_by_id

Funzione che recupera, dato l'id, le informazioni del sottogruppo richiesto dal database.

Argomenti:  * id del sottogruppo ('subgroup_id');

Return:     Risultato della query.

=cut

=head1 get_stations_by_nets

Funzione che recupera le informazioni relative alle stazioni presenti in una determinata provincia
e di una o più reti selezionate dall'utente.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia ('province_id');

           * array degli id delle reti eventualmente selezionate dall'utente ('nets');

Return:     Risultato della query..

=cut

=head1 get_station_params

Funzione che recupera le informazioni relative ai parametri di una determinata stazione
necessarie a generare l'albero all'interno dello strumento 'Analyser' sulla destra.

Argomenti:  * id del nodo ('nodeid');

           * id della stazione ('stid');

           * oggetto contenente informazioni aggiuntive per l'albero ('options');

Return:     Oggetto json per la costruzione dell'albero.

=cut

=head1 get_params_type

Funzione che recupera le informazioni relative ai parametri di una determinata tipologia
necessarie a generare l'albero all'interno dello strumento 'Analyser' sulla destra.

Argomenti:  * id del nodo ('nodeid');

           * id della stazione ('stid');

           * tipologia di parametro ('type');

           * oggetto contenente informazioni aggiuntive per l'albero ('options');

Return:     Oggetto json per la costruzione dell'albero.

=cut

=head1 get_categories_list

Funzione che recupera la lista delle categorie di macro visibili dall'utente dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_category_byid

Funzione che recupera, dato l'id, le informazioni della categoria richiesta dal database.

Argomenti:  * id della categoria ('cat_id');

Return:     Risultato della query.

=cut

=head1 get_groups

Funzione che recupera le informazioni relative ai gruppi di macro necessarie a
generare l'albero all'interno dello strumento 'Analyser' sulla sinistra.

Argomenti:  * id dell'utente ('user_id');

Return:     Oggetto json per la costruzione dell'albero.

=cut

=head1 get_group_macros

Funzione che recupera le informazioni necessarie a generare l'albero delle macro
all'interno dello strumento 'Analyser' sulla sinistra.

Argomenti:  * id del nodo ('nodeid');

           * id del gruppo ('grid');

           * oggetto contenente informazioni aggiuntive per l'albero ('options');

Return:     Oggetto json per la costruzione dell'albero.

=cut

=head1 get_macro_params

Funzione che recupera le informazioni necessarie a generare l'albero dei parametri
associati ad una determinata macro all'interno dello strumento 'Analyser' sulla sinistra.

Argomenti:  * id del nodo ('nodeid');

           * id della macro ('macroid');

Return:     Oggetto json per la costruzione dell'albero.

=cut

=head1 get_macro_byid

Funzione che recupera, dato l'id, le informazioni della macro richiesta dal database.

Argomenti:  * id della macro ('mcid');

Return:     Risultato della query.

=cut

=head1 get_info_param

Funzione che recupera le informazioni relative ad un determinato parametro associato ad una
determinata stazione dal database.

Argomenti:  * id dell'associazione stazione-parametro ('stprid');

           * valore booleano che indica se visualizzare il parametro convertito o meno ('conv');

Return:     Risultato della query.

=cut

=head1 insert_options

Funzione che inserisce le impostazioni personalizzate dell'utente nel database.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relative alle impostazioni ('option_obj');

Return:     Risultato della query.

=cut

=head1 insert_category

Funzione che inserisce una nuova categoria nel database.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relative alla categoria
             da inserire ('params');

Return:     ID della nuova categoria inserita, oppure il valore 'undef'.

=cut

=head1 insert_macro

Funzione che inserisce una nuova pagina, associata ad una determinata categoria, nel database.

Argomenti:  * id della categoria alla quale verra' associata la nuova macro ('macro_cat');

           * oggetto relativo alla macro da inserire ('macro_obj');

Return:     ID della nuova macro inserita.

=cut

=head1 insert_macro_duplication

Funzione che inserisce una nuova macro, duplicata da una gia' esistente, nel database.

Argomenti:  * id della macro da duplicare ('pgid');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 insert_new_subgroup

Funzione che inserisce un nuovo sottogruppo di stazioni-parametri da visualizzare all'interno
dello strumento 'Analyser'.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relative al sottogruppo
             da inserire ('params');

Return:     ID del nuovo sottogruppo inserito, oppure il valore 'undef'.

=cut

=head1 update_options

Funzione che aggiorna le impostazioni personalizzate dell'utente nel database.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relative alle impostazioni ('option_obj');

Return:     Risultato della query.

=cut

=head1 update_category

Funzione che aggiorna una determinata categoria nel database.

Argomenti:  * oggetto contenente le informazioni relative alla categoria
             da aggiornare ('params');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 update_macro

Funzione che aggiorna una determinata macro nel database.

Argomenti:  * id della macro ('macro_id');

           * id della categoria a cui è associata la macro ('macro_cat');

           * oggetto contenente le informazioni relative alla macro da aggiornare ('macro_obj');

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

=head1 delete_category

Funzione che elimina una determinata categoria dal database.

Argomenti:  * id della categoria ('cat_id');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 delete_macro_byid

Funzione che elimina, dato l'id, una determinata macro dal database.

Argomenti:  * id della macro ('mcid');

Return:     Risultato della query.

=cut

=head1 delete_subgroup

Funzione che elimina un determinato sottogruppo dal database.

Argomenti:  * id del sottogruppo ('id');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut