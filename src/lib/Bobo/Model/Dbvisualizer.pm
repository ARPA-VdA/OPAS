package Bobo::Model::Dbvisualizer;

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
# VISUALIZER functions
# -----------------------------------------------------------------------------

# Getters
# -----------------------------------------------------------------------------
sub get_categories_list {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("sub get_categories_list");

    # cat_id
    # cat_name
    # cat_public
    # cat_owner

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
        FROM bobo_tools.view_visualizer_categories vvc
        WHERE (
            vvc.category_public IS TRUE
            AND vvc.category_owner_portal = (
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
        )
        OR (
            ARRAY( SELECT gr_id FROM bobo.user_groups WHERE us_id = ? ) && ARRAY( SELECT admin_gr_id FROM bobo.portal_properties )
            AND vvc.category_owner_portal = (
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
        )
        OR vvc.groups_id && (
            SELECT groups_id
            FROM bobo.view_users
            WHERE user_id = ?
        )
        OR vvc.category_owner = ?
        ORDER BY
            category_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $user_id, $user_id, $user_id)->hashes;
}

sub get_category_byid {
    my ( $self, $cat_id ) = @_;

    # log
    $self->app->log->debug("sub get_category_byid");

    # cat_id
    # cat_name
    # cat_public
    # cat_owner

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
        FROM bobo_tools.view_visualizer_categories ac
        WHERE category_id = ?
    };

    # return
    return $self->pg->db->query($sql, $cat_id)->hash();
}

sub get_visualizer_general_options {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbanalyser sub get_visualizer_general_options");

    # query
    my $sql = qq{
        SELECT
            go_obj AS option_object
        FROM
            bobo_tools.general_options
        WHERE go_tool = 'visualizer'
    };

    # return
    return $self->pg->db->query($sql)->hash;
}

sub get_visualizer_user_options {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_visualizer_user_options");

    # query
    my $sql = qq{
        SELECT
            option_object
        FROM bobo_tools.visualizer_options
        WHERE option_user = ?;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hash;
}

sub get_pages {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_pages");

    # query
    my $sql = qq{
        SELECT
            vc.category_id,
            vc.category_name,
            vp.page_id,
            vp.page_name
        FROM bobo_tools.view_visualizer_categories vc
        LEFT JOIN bobo_tools.view_visualizer_pages vp USING (category_id)
        WHERE (
            vc.category_public IS TRUE
            AND vc.category_owner_portal = (
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
        )
        OR (
            ARRAY( SELECT gr_id FROM bobo.user_groups WHERE us_id = ? ) && ARRAY( SELECT admin_gr_id FROM bobo.portal_properties )
            AND vc.category_owner_portal = (
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
        )
        OR vc.groups_id && ARRAY(
            SELECT gr_id
            FROM bobo.user_groups
            WHERE us_id = ?
        )
        OR vc.category_owner = ?
        ORDER BY category_name, page_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $user_id, $user_id, $user_id)->hashes;
}

sub get_pages_by_category {
    my ( $self, $user_id, $cat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_pages_by_category");

    # query
    my $sql = qq{
        SELECT
            vc.category_id,
            vc.category_name,
            vp.page_id,
            vp.page_name
        FROM bobo_tools.view_visualizer_categories vc
        LEFT JOIN bobo_tools.view_visualizer_pages vp USING (category_id)
    };

    # check if the category is not provided
    if ($cat == -1) {
        $sql .= qq{
            WHERE (
                vc.category_public IS TRUE
                AND vc.category_owner_portal = (
                    SELECT portal_id
                    FROM bobo.users_metadata
                    WHERE us_id = $user_id
                )
            )
            OR (
                ARRAY( SELECT gr_id FROM bobo.user_groups WHERE us_id = $user_id ) && ARRAY( SELECT admin_gr_id FROM bobo.portal_properties )
                AND vc.category_owner_portal = (
                    SELECT portal_id
                    FROM bobo.users_metadata
                    WHERE us_id = $user_id
                )
            )
            OR vc.groups_id && ARRAY(
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = $user_id
            )
            OR vc.category_owner = $user_id
        };
    }
    else {
        $sql .= qq{
            WHERE
                vc.category_id = $cat
        };
    }

    $sql .= qq{ORDER BY category_name, page_name;};

    # return
    return $self->pg->db->query($sql)->hashes();
}

# JS TREE
sub get_groups {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_groups");

    # cat_id
    # cat_name
    # cat_public
    # cat_owner

    # query
    my $sql = qq{
        SELECT array_to_json(array_agg(row_to_json(t))) AS json_tree
        FROM (
            SELECT
                category_id AS id,
                '#' AS parent,
                category_name AS text,
                --'ti-package' AS icon,
                CASE
                    WHEN vc.category_public IS TRUE THEN 'fa-light fa-folder-open'
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
                            category_id       AS id
                    ) AS li
                ) AS li_attr
            FROM bobo_tools.view_visualizer_categories vc
            WHERE (
                vc.category_public IS TRUE
                AND vc.category_owner_portal = (
                    SELECT portal_id
                    FROM bobo.users_metadata
                    WHERE us_id = ?
                )
            )
            OR (
                ARRAY( SELECT gr_id FROM bobo.user_groups WHERE us_id = ? ) && ARRAY( SELECT admin_gr_id FROM bobo.portal_properties )
                AND vc.category_owner_portal = (
                    SELECT portal_id
                    FROM bobo.users_metadata
                    WHERE us_id = ?
                )
            )
            OR vc.groups_id && ARRAY(
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = ?
            )
            OR vc.category_owner = ?
        ) t
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $user_id, $user_id, $user_id)->hash()->{'json_tree'};
}

sub get_group_pages {
    my ( $self, $nodeid, $grid, $loaded ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_group_macros");

    # macro_id
    # macro_category
    # macro_object

    # check boolean value
    if (!defined $loaded) {
        $loaded = 'true';
    }

    # query
    my $sql = qq{
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT
            ?||'-'||page_id AS id,
            page_name AS text,
            'icon-frame' AS icon,
            (
                SELECT row_to_json(s)
                FROM (
                    SELECT
                        false AS opened,
                        ?::boolean AS loaded
                ) s
            ) AS state,
            (
                SELECT row_to_json(li)
                FROM (
                    SELECT
                        'page'     AS type,
                        page_id    AS id,
                        'page'     AS class

                ) li
            ) AS li_attr
            FROM bobo_tools.view_visualizer_pages
            WHERE category_id = ?
            ORDER BY page_id
        ) d;
    };

    # return
    return $self->pg->db->query($sql, $nodeid, $loaded, $grid)->hash()->{'json_tree'};
}

sub get_page_boxes {
    my ( $self, $nodeid, $pageid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_page_boxes");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                jsonb_array_elements(macro_object)->'macro'->>'name' AS tabname,
                jsonb_array_elements(macro_object)->'macro'->>'type' AS tabtype,
                jsonb_array_elements(macro_object)->'params' AS tabparams
            FROM bobo_tools.visualizer_macros
            WHERE macro_page = ?
        )
        SELECT array_to_json(array_agg(row_to_json(d))) AS json_tree
        FROM (
            SELECT
            ?||'-'||ROW_NUMBER() OVER() AS id,
            tabname||' ['||tabtype||']' AS text,
            'icon-folder' AS icon,
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
                        'tab'       AS type,
                        ROW_NUMBER() OVER(ORDER BY tabname || tabtype)      AS id,
                        'tab'       AS class

                ) li
            ) AS li_attr,
            (array_to_json(ARRAY(
                SELECT row_to_json(p)
                FROM(
                    SELECT jsonb_array_elements(tabparams)->>'name' AS text,
                    'ti-stats-up' AS icon
                ) p
            ))) AS children
            FROM t
        ) d;
    };

    # return
    return $self->pg->db->query($sql, $pageid, $nodeid )->hash()->{'json_tree'};
}
# END JS TREE

sub get_pages_list {
    my ( $self, $cat_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_pages_list");

    # cat_id
    # cat_name
    # cat_public
    # cat_owner

    # query
    my $sql = qq{
        SELECT
            category_id,
            category_name,
            page_id,
            page_name
        FROM bobo_tools.view_visualizer_pages vp
        WHERE
            category_id = ?
    };

    # return
    return $self->pg->db->query($sql, $cat_id)->hashes();
}

sub get_page_byid {
    my ( $self, $page_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_page_byid");

    # query
    my $sql = qq{
        SELECT
            category_id,
            category_name,
            page_id,
            page_name
        FROM bobo_tools.view_visualizer_pages vp
        WHERE page_id = ?
    };

    # return
    return $self->pg->db->query($sql, $page_id)->hash();
}

sub get_macros_by_page {
    my ( $self, $pgid, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_macros_by_page");

    # query
    my $sql = qq{
        SELECT
            vp.page_id,
            vp.page_name,
            vp.page_category,
            vm.macro_id,
            vm.macro_object
        FROM bobo_tools.visualizer_macros vm
        LEFT JOIN bobo_tools.visualizer_pages vp ON (vm.macro_page = vp.page_id)
        LEFT JOIN bobo_tools.view_visualizer_categories vvc ON (vp.page_category = vvc.category_id)
        WHERE macro_page = ?
        AND (
                (
                    vvc.category_public IS TRUE
                    AND vvc.category_owner_portal = (
                        SELECT portal_id
                        FROM bobo.users_metadata
                        WHERE us_id = ?
                    )
                )
                OR (
                    ARRAY( SELECT gr_id FROM bobo.user_groups WHERE us_id = ? ) && ARRAY( SELECT admin_gr_id FROM bobo.portal_properties )
                    AND vvc.category_owner_portal = (
                        SELECT portal_id
                        FROM bobo.users_metadata
                        WHERE us_id = ?
                    )
                )
                OR vvc.groups_id && ARRAY(
                    SELECT gr_id
                    FROM bobo.user_groups
                    WHERE us_id = ?
                )
                OR vvc.category_owner = ?
            )
        ORDER BY macro_id;
    };

    # return
    return $self->pg->db->query( $sql, $pgid, $user_id, $user_id, $user_id, $user_id, $user_id )->hash;
}

sub get_macro_byid {
    my ( $self, $mcid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_macro_byid");

    # query
    my $sql = qq{
        SELECT
            macro_id,
            macro_page,
            macro_object
        FROM bobo_tools.visualizer_macros
        WHERE macro_id = ?;
    };

    # return
    return $self->pg->db->query( $sql, $mcid )->hash();
}

sub get_info_params {
    my ( $self, $conv, $stprid_array ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_info_params");
    $self->app->log->debug("$conv");

    my $sql;
    my @data;

    my $unit = 'param_unit_conv';
    if ($conv eq 'false') {
        $unit = 'param_unit';
    }

    # loop through parameters
    for my $stprid (@{$stprid_array}) {
        $sql = qq{
            SELECT
                stpr_id                                             AS st_pr_id,
                p.param_name || COALESCE(' - '|| sp.stpr_note, '')  AS name,
                param_id                                            AS param_id,
                station_name                                        AS station,
                station_name||' '||p.param_name
                    ||COALESCE(' - '|| sp.stpr_note, '')
                    ||' ['|| $unit ||']'                            AS legend,
                p.param_name || COALESCE(' - '|| sp.stpr_note, '')
                    ||' ['|| $unit ||'] <br>'
                    ||station_name                                  AS column_name,
                $unit AS unit,
                COALESCE(pi.pm_info_obj ->'general'->>'treatment', 'avg')        AS treatment,
                'line'                                              AS chartstyle,
                'FFFFFF'                                            AS color,
                2                                                   AS line_width,

                $conv               AS converted,
                -- 24/07/2024 10:04 update for conversion coefficient history management
                -- CASE
                --     WHEN $conv THEN
                --                 CASE
                --                     WHEN param_conv = 0 THEN 'y='||COALESCE(param_offset::text, '0')
                --                     WHEN param_conv = 1 THEN 'y=x'||COALESCE('+'||param_offset::text, '')
                --                     ELSE 'y='||param_conv||'*x'||COALESCE('+'||param_offset::text, '')
                --                 END
                --     ELSE
                --         CASE
                --             WHEN param_conv = 0 THEN 'y='||COALESCE(param_offset::text, '0')
                --             ELSE 'y=x'||COALESCE('+'||param_offset::text, '')
                --         END
                -- END AS formule,
                CASE
                    WHEN param_conv = 0 THEN 'y='||COALESCE(param_offset::text, '0')
                    ELSE 'y=x'||COALESCE('+'||param_offset::text, '')
                END AS formule,

                param_decimals                                      AS decimals,
                CASE
                    WHEN pt.pm_type_desc LIKE 'Limiti' THEN TRUE
                    ELSE FALSE
                END                                                 AS is_limit
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
                LEFT JOIN metadata.parameters_type pt ON pi.pm_info_type_fk = pt.pm_type_id
                LEFT JOIN metadata.stations s USING (station_id)
            WHERE
                stpr_id = ?;
        };

        my $res = $self->pg->db->query($sql, $stprid)->hash();
        # my $res = $self->pg->db->query($sql, $dateFrom, $dateTo, $percent, $param->{'st_pr_id'})->hash();

        # check result
        if (defined $res) {
            push @data, $res;
        }
    }

    # return
    return \@data;
}

sub get_all_stations_params_by_types {
    my ( $self, $stid, $types, $cat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_all_stations_params_by_types");

    my $stid_string = join ', ', @{$stid};

    # query
    my $sql = qq{
        SELECT
            p.param_id,
            p.param_name
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.parameters_info pm USING (param_id)
        WHERE
            sp.station_id IN ( $stid_string )
    };

    if (scalar @{$types} > 0) {
        my $types_string = join ',', @{$types};

        $sql .= qq{ AND pm.pm_info_type_fk IN ( $types_string ) };
    }

    if ($cat != -1) {
        $sql .= qq{
            AND instr_type_ids && ARRAY(
                SELECT instr_type_id
                FROM equipments.instruments_type
                WHERE category_id = $cat
            )
        };
    }

    $sql .= qq{
        GROUP BY 1,2
        ORDER BY 1,2;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_all_params_by_types {
    my ( $self, $types, $cat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_all_params_by_types");

    my $types_string = join ',', @{$types};

    # query
    my $sql = qq{
        SELECT
            p.param_id,
            p.param_name
        FROM
            metadata.parameters p
            LEFT JOIN metadata.parameters_info pm USING (param_id)
        WHERE
            pm.pm_info_type_fk IN ( $types_string )
    };

    if ($cat != -1) {
        $sql .= qq{
            AND instr_type_ids && ARRAY(
                SELECT instr_type_id
                FROM equipments.instruments_type
                WHERE category_id = $cat
            )
        };
    }

    $sql .= qq{
        ORDER BY 1,2;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_all_stations_params_by_province {
    my ( $self, $user_id, $net, $province_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_all_stations_params_by_province");

    # query
    my $sql = qq{
        SELECT
            sp.stpr_id         AS station_param_id,
            sp.stpr_table_id   AS station_param_table_id,
            sp.param_id        AS parameter_id,
            p.param_name || COALESCE(' - '|| sp.stpr_note, '') AS parameter_name,
            s.station_name||' - '||p.param_name || COALESCE(' - '|| sp.stpr_note, '') AS parameter_fullname,
            p.param_unit AS parameter_unit,
            p.param_unit_conv AS parameter_unit_conv,
            sp.stpr_active AS station_param_active,
            s.station_name
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.stations_info sm USING (station_id)
            LEFT JOIN bobo.view_user_stations us USING(station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
    };

    if ($net != -1) {
        $sql .= qq{
            AND sm.st_info_network_type_fk = $net
        };
    }

    if ($province_id != -1) {
        $sql .= qq{
            AND smu.province_id = $province_id
        };
    }

    $sql .= qq {
            AND stpr_id IS NOT NULL
            AND s.station_active IS TRUE
        ORDER BY
            s.station_name, p.param_name
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_all_stations_params {
    my ( $self, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_all_stations_params");

    my $stid_string = join ', ', @{$stid};

    # query
    my $sql = qq{
        SELECT
            sp.stpr_id         AS station_param_id,
            sp.stpr_table_id   AS station_param_table_id,
            sp.param_id        AS parameter_id,
            p.param_name || COALESCE(' - '|| sp.stpr_note, '') AS parameter_name,
            s.station_name||' - '||p.param_name || COALESCE(' - '|| sp.stpr_note, '') AS parameter_fullname,
            p.param_unit AS parameter_unit,
            p.param_unit_conv AS parameter_unit_conv,
            sp.stpr_active AS station_param_active,
            s.station_name
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.stations s USING (station_id)
        WHERE
            sp.station_id IN ( $stid_string )
            AND stpr_id IS NOT NULL
            AND s.station_active IS TRUE
        ORDER BY
            s.station_name, p.param_name
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_automatic_macros {
    my ( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub get_automatic_macros");

    my @stations;
    if (ref($params->{'auto-stations'}) eq 'ARRAY') {
        @stations = @{$params->{'auto-stations'}};
    }
    else {
        push @stations, $params->{'auto-stations'};
    }

    my @types;
    if (ref($params->{'auto-params-type'}) eq 'ARRAY') {
        @types = @{$params->{'auto-params-type'}};
    }
    else {
        push @types, $params->{'auto-params-type'};
    }

    my $sql;
    if (!defined $params->{'auto-params'}) {
        $self->app->log->debug("WithOUT PARAMETERS");

        # query
        $sql = qq{
            SELECT bobo_tools.f_visualizer_auto_generate_macro( ?::integer[], ?::integer[], NULL, ?, ?) AS macros;
        };

        # return
        return $self->pg->db->query($sql, \@stations, \@types, $params->{'auto-instruments'}, $self->app->helperGetBoolean($params, 'auto-conv'))->hash->{'macros'};
    }
    else {
        $self->app->log->debug("With PARAMETERS");

        my @parameters;
        if (ref($params->{'auto-params'}) eq 'ARRAY') {
            @parameters = @{$params->{'auto-params'}};
        }
        else {
            push @parameters, $params->{'auto-params'};
        }

        # query
        $sql = qq{
            SELECT bobo_tools.f_visualizer_auto_generate_macro( ?::integer[], ?::integer[], ?::integer[], ?, ?) AS macros;
        };

        # $self->app->log->debug($sql);

        # return
        return $self->pg->db->query($sql, \@stations, \@types, \@parameters, $params->{'auto-instruments'}, $self->app->helperGetBoolean($params, 'auto-conv'))->hash->{'macros'};
    }
}

sub insert_options {
    my ( $self, $user_id, $option_obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub insert_options");
    $self->app->helperDumper($option_obj);

    # return
    return $self->pg->db->insert('bobo_tools.visualizer_options', {
        option_user   => $user_id,
        option_object => $option_obj
    });
}

sub insert_category {
    my( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub insert_category");
    $self->app->log->debug($params->{'new-cat-name'});

    my $tx;
    my $new_cat_id;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuova categoria e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 1");

        $new_cat_id = $self->pg->db->insert('bobo_tools.visualizer_categories', {
            cat_name   => $self->app->helperEscapeParam($params->{'new-cat-name'}),
            cat_public => $self->app->helperGetBoolean($params, 'new-cat-public'),
            cat_owner  => $user_id
        }, { returning => 'cat_id' })->hash->{'cat_id'};

        # ##################################################################
        # 2 - associazione nuova categoria con i gruppi selezionati nel form
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 2");
        my @groups_id;
        if (ref($params->{'new-cat-groups'}) eq 'ARRAY') {
            @groups_id = @{$params->{'new-cat-groups'}};
        }
        elsif ($params->{'new-cat-groups'} ne "") {
            push @groups_id, $params->{'new-cat-groups'};
        }

        for my $gr_id (@groups_id) {
            $self->pg->db->insert('bobo_tools.visualizer_category_groups', {
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

sub insert_page {
    my ( $self, $name, $cat_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub insert_page");

    # query and return
    return $self->pg->db->insert('bobo_tools.visualizer_pages' , {
        page_category => $cat_id,
        page_name     => $name
    }, { returning => 'page_id' })->hash->{'page_id'};
}

sub insert_page_duplication {
    my ( $self, $pgid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub insert_page_duplication");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1 - insert della nuova pagina
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 1");

        # query
        my $sql = qq{
            INSERT INTO bobo_tools.visualizer_pages (page_category, page_name)
            (
                SELECT
                    page_category,
                    page_name||' - Copia'
                FROM
                    bobo_tools.visualizer_pages
                WHERE
                    page_id = ?
            )
            RETURNING page_id;
        };

        my $new_pgid = $self->pg->db->query($sql, $pgid)->hash->{'page_id'};

        # ##################################################################
        # 2 - insert dei nuovi box
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 2");

        $sql = qq{
            INSERT INTO bobo_tools.visualizer_macros (macro_page, macro_object)
            (
                SELECT
                    ?::integer,
                    macro_object
                FROM
                    bobo_tools.visualizer_macros
                WHERE
                    macro_page = ?
            )
        };

        $self->pg->db->query($sql, $new_pgid, $pgid);
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

sub insert_boxes {
    my ( $self, $page_id, $page_boxes ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub insert_boxes");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1 - eliminazione di tutte le macro associate alla pagina
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 1");

        # query
        my $sql = qq{
            DELETE FROM bobo_tools.visualizer_macros WHERE macro_page = ?
        };

        $self->pg->db->query($sql, $page_id);

        # ##################################################################
        # 2 - insert dei nuovi box
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 2");

        $sql = qq{INSERT INTO bobo_tools.visualizer_macros (macro_page, macro_object) VALUES ( ?, ?::jsonb)};
        $self->pg->db->query($sql, $page_id, $page_boxes);
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

sub update_options {
    my ( $self, $user_id, $option_obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub update_options");

    # $self->app->helperDumper($macro_obj);

    # query and return
    return $self->pg->db->update('bobo_tools.visualizer_options', {
        option_object => $option_obj
    }, { option_user => $user_id });
}

sub update_category {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub update_category");
    $self->app->log->debug($params->{'new-cat-name'});

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- modifica utente
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 1");

        # $db->update('some_table', {foo => 'bar'}, {id => 23});
        $self->pg->db->update('bobo_tools.visualizer_categories', {
            cat_name   => $self->app->helperEscapeParam($params->{'new-cat-name'}),
            cat_public => $self->app->helperGetBoolean($params, 'new-cat-public')
        }, { cat_id => $params->{'new-cat-id'} });

        # ##################################################################
        # 2- eliminazione associazioni categoria-gruppi e inserimento nuove associazioni
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 2");
        my $sql = qq{
            DELETE FROM bobo_tools.visualizer_category_groups WHERE cat_id = ?
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
            $self->pg->db->insert('bobo_tools.visualizer_category_groups', {
                cat_id    => $params->{'new-cat-id'},
                gr_id     => $gr_id
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

sub update_page {
    my ( $self, $page_id, $page_name, $page_cat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub update_page");

    # query and return
    return $self->pg->db->update('bobo_tools.visualizer_pages', {
        page_name     => $page_name,
        page_category => $page_cat
    }, { page_id => $page_id });
}

sub update_macro {
    my ( $self, $macro_id, $macro_index, $macro_obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub update_macro");

    # query
    my $sql = qq{
        UPDATE bobo_tools.visualizer_macros
        SET macro_object = jsonb_set(macro_object, ?, ?::jsonb, false)
        WHERE macro_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $macro_index, $macro_obj, $macro_id);
}

sub delete_category {
    my ( $self, $cat_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub delete_category");
    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- elimino macro associate alle pagine associate alla categoria
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 1");
        my $sql = qq{
            DELETE FROM bobo_tools.visualizer_macros
            WHERE macro_page IN (
                SELECT page_id
                FROM bobo_tools.visualizer_pages
                WHERE page_category = ?
            );
        };

        $self->pg->db->query($sql, $cat_id);

        # ##################################################################
        # 2- elimino pagine associate alla categoria
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 2");
        # $db->update('some_table', {foo => 'bar'}, {id => 23});
        $sql = qq{
            DELETE FROM bobo_tools.visualizer_pages WHERE page_category = ?
        };

        $self->pg->db->query($sql, $cat_id);

        # ##################################################################
        # 3- eliminazione associazioni categoria-gruppi
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 3");
        # $db->update('some_table', {foo => 'bar'}, {id => 23});
        $sql = qq{
            DELETE FROM bobo_tools.visualizer_category_groups WHERE cat_id = ?
        };

        $self->pg->db->query($sql, $cat_id);

        # ##################################################################
        # 4- eliminazione categoria
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 4");
        # $db->update('some_table', {foo => 'bar'}, {id => 23});
        $sql = qq{
            DELETE FROM bobo_tools.visualizer_categories WHERE cat_id = ?
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

sub delete_page {
    my ( $self, $page_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvisualizer sub delete_page");
    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- elimino macro associate al pannello
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 1");
        my $sql = qq{
            DELETE FROM bobo_tools.visualizer_macros WHERE macro_page = ?
        };

        $self->pg->db->query($sql, $page_id);

        # ##################################################################
        # 2- eliminazione pannello
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbvisualizer STEP 2");
        # $db->update('some_table', {foo => 'bar'}, {id => 23});
        $sql = qq{
            DELETE FROM bobo_tools.visualizer_pages WHERE page_id = ?
        };

        $self->pg->db->query($sql, $page_id);
    };

    # error check
    if ($@) {
        $self->app->log->warn("Error: ".$@);
        if (index($@->{'message'}, 'bobo_tools_validation_trees_pages_fk2') != -1) {
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

1;

=head1 get_categories_list

Funzione che recupera la lista delle categorie associate al gruppo
dell'utente loggato dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_category_byid

Funzione che recupera, dato l'id, le informazioni relative
ad una determinata categoria dal database.

Argomenti:  * id della categoria ('cat_id');

Return:     Risultato della query.

=cut

=head1 get_visualizer_general_options

Funzione che recupera le impostazioni generali, valide per tutti, dello
strumento 'Visualizer' dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_visualizer_user_options

Funzione che recupera le impostazioni, personalizzate da un determinato utente,
dello strumento 'Visualizer' dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_pages

Funzione che recupera le pagine, visibili dall'utente loggato, dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_pages_by_category

Funzione che recupera, dato l'id di una categoria, le relative pagine,
visibili dall'utente loggato, dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della categoria ('cat');

Return:     Risultato della query.

=cut

=head1 get_groups

Funzione che recupera i gruppi di macro, visibili dall'utente loggato, dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_group_pages

Funzione che recupera le informazioni necessarie a generare l'albero presente nella
pagina 'Avanzate > Visualizer' sulla sinistra.

Argomenti:  * id del nodo ('nodeid');

           * id del gruppo ('grid');

           * valore booleano ('loaded');

Return:     Oggetto json per la costruzione dell'albero.

=cut

=head1 get_page_boxes

Funzione che recupera le informazioni relative alle finestre presenti all'interno di una
determinata pagina, dal database.

Argomenti:  * id del nodo ('nodeid');

           * id della pagina ('pageid');

Return:     Oggetto json per la costruzione delle finestre.

=cut

=head1 get_pages_list

Funzione che recupera, dato l'id di una categoria, tutte le relative pagine dal database.

Argomenti:  * id della categoria ('cat_id');

Return:     Risultato della query.

=cut

=head1 get_page_byid

Funzione che recupera, dato l'id, le informazioni della pagina richiesta dal database.

Argomenti:  * id della pagina ('page_id');

Return:     Risultato della query.

=cut

=head1 get_macros_by_page

Funzione che recupera, dato l'id di una pagina, le relative macro, visibili
dall'utente loggato, dal database.

Argomenti:  * id della pagina ('page_id');

           * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_macro_byid

Funzione che recupera, dato l'id, le informazioni di una determinata macro dal database.

Argomenti:  * id della macro ('mcid');

Return:     Risultato della query.

=cut

=head1 get_info_params

Funzione che recupera, dati gli id, le informazioni relative a dei determinati parametri
dal database.

Argomenti:  * valore booleano relativo alla conversione dei parametri ('conv');

           * array contenente gli id delle associazioni stazione-parametro ('stprid_array');

Return:     Array contenente gli oggetti delle informazioni relative ai parametri richiesti.

=cut

=head1 get_all_stations_params_by_types

Funzione che recupera le informazioni relative ai parametri di determinate stazioni dal database,
filtrati eventualmente per tipologia e categoria di strumento che li acquisisce.

Argomenti:  * array degli id delle stazioni ('stid');

           * array degli id delle tipologie di parametro ('types');

           * categoria di strumento ('cat');

Return:     Risultato della query.

=cut

=head1 get_all_params_by_types

Funzione che recupera i parametri di determinate tipologie dal database,
filtrati eventualmente per categoria di strumento che li acquisisce.

Argomenti:  * array degli id delle tipologie di parametro ('types');

           * categoria di strumento ('cat');

Return:     Risultato della query.

=cut

=head1 get_all_stations_params_by_province

Funzione che recupera le informazioni relative ai parametri di determinate stazioni,
filtrati eventualmente per rete e provincia, dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della rete ('net');

           * id della provincia ('province_id');

Return:     Risultato della query.

=cut

=head1 get_all_stations_params

Funzione che recupera le informazioni relative ai parametri di determinate stazioni dal database.

Argomenti:  * array degli id delle stazioni ('stid');

Return:     Risultato della query.

=cut

=head1 get_automatic_macros

Funzione che recupera i metadati necessari alla generazione automatica delle macro
dal database.

Argomenti:  * oggetto contenente i metadati ('params');

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

=head1 insert_page

Funzione che inserisce una nuova pagina, associata ad una determinata categoria, nel database.

Argomenti:  * nome della nuova pagina ('name');

           * id della categoria alla quale verra' associata la nuova pagina ('cat_id');

Return:     Risultato della query.

=cut

=head1 insert_page_duplication

Funzione che inserisce una nuova pagina, duplicata da una gia' esistente, nel database.

Argomenti:  * id della pagina da duplicare ('pgid');

Return:     Risultato della query.

=cut

=head1 insert_boxes

Funzione che inserisce, associate ad una determinata pagina, le finestre/macro nel database.

Argomenti:  * id della pagina ('page_id');

           * oggetto contenente le informazioni alle finestre/macro da inserire ('page_boxes');

Return:     Risultato della query.

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

=head1 update_page

Funzione che aggiorna una determinata pagina nel database.

Argomenti:  * id della pagina ('page_id');

           * nome della pagina ('page_name');

           * categoria della pagina ('page_cat');

Return:     Risultato della query.

=cut

=head1 update_macro

Funzione che aggiorna una determinata macro nel database.

Argomenti:  * id della macro ('macro_id');

           * indice di posizionamento della macro ('macro_index');

           * oggetto contenente le informazioni relative alla macro da aggiornare ('macro_obj');

Return:     Risultato della query.

=cut

=head1 delete_category

Funzione che elimina una determinata categoria dal database.

Argomenti:  * id della categoria ('cat_id');

Return:     Risultato della query.

=cut

=head1 delete_page

Funzione che elimina una determinata pagina dal database.

Argomenti:  * id della pagina ('page_id');

Return:     Risultato della query.

=cut