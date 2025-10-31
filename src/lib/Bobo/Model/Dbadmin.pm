package Bobo::Model::Dbadmin;
use Mojo::Base -base;

use Data::Dumper;
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

# PERMISSIONS GETTER
sub get_users {
    my ( $self, $userid, $grid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_users");

    my $sql;
    my $filter = '';

    # check group id
    if ($grid != -1) {
        $filter = qq{AND groups_id @> ARRAY[ $grid ]};
    };

    # select
    $sql = qq{
        SELECT
            user_id,
            user_email,
            user_name,
            user_second_name,
            user_surname,
            user_name || ' ' || COALESCE(user_second_name, '') || ' ' || user_surname AS user_fullname,
            user_active,
            (
                SELECT
                    CASE WHEN groups_id && (
                        SELECT ARRAY_AGG(admin_gr_id)
                        FROM bobo.portal_properties
                    ) THEN TRUE
                    ELSE FALSE
                    END
            ) AS user_admin,
            groups_id,
            --groups_name,
            company_id,
            company_name,
            company_desc,
            portal_name
        FROM
            bobo.view_users vu
        WHERE
            (
                ( 	ARRAY_LENGTH(groups_id, 1) > 1
                    AND groups_id != ARRAY[1,2]
                    AND groups_id <@ (
                        SELECT
                            linked_gr_id
                        FROM bobo.portal_properties
                        WHERE admin_gr_id IN (
                            SELECT gr_id
                            FROM bobo.user_groups
                            WHERE us_id = ?
                        )
                    )
                )
                OR (
                    (groups_id = ARRAY[1] OR groups_id = ARRAY[1,2])
                    AND portal_id = (
                        SELECT
                            portal_id
                        FROM bobo.users_metadata
                        WHERE us_id = ?
                    )
                )
            )
        $filter
        ORDER BY user_active, user_fullname;
    };

    # return
    return $self->pg->db->query($sql, $userid, $userid)->hashes;
}

sub get_groups_menu {
    my ($self, $groups_id) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_groups_menu");

    # concatenate group ids for the query
    my $grid_string = join ',' , @{$groups_id};
    $self->app->log->debug($grid_string);

    # query
    my $sql = qq{
        SELECT *,
        (
            SELECT bit_or(tbit.gp_iud_grants) FROM
            (
                SELECT gp_iud_grants
                FROM bobo.group_pages
                WHERE page_id = vmp.page_id
                AND gr_id IN ( $grid_string )
            ) AS tbit
        ) AS total_user_grants,
        (
            SELECT
                CASE WHEN '{$grid_string}'::int[] && (
                    SELECT ARRAY_AGG(admin_gr_id)
                    FROM bobo.portal_properties
                ) THEN TRUE
                ELSE FALSE
                END
        ) AS user_admin
        FROM bobo.view_menu_pages vmp
        WHERE (
            SELECT COUNT(*) AS children
            FROM bobo.view_menu_pages
            WHERE vmp.page_path @> page_path
            AND page_href IS NOT NULL
            AND page_id IN (
                SELECT DISTINCT(page_id)
                FROM bobo.group_pages
                WHERE gr_id IN ( $grid_string )
            )
        ) > 0
        AND menu_id = 1
        AND menu_page_level > 1
        ORDER BY menu_page_order;
    };

    # return
    $self->pg->db->query($sql)->hashes;
}

sub get_groups_stations {
    my ($self, $groups_id) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_groups_stations");

    # concatenate group ids for the query
    my $grid_string = join ',' , @{$groups_id};
    $self->app->log->debug($grid_string);

    # query
    my $sql = qq{
        SELECT DISTINCT ON (station_id)
            gr_id,
            vs.station_id,
            vs.station_name,
            vs.station_active,
            vs.station_network_type_desc,
            (
                SELECT bit_or(tbit.gs_iud_grants) FROM
                    (
                        SELECT gs_iud_grants
                        FROM bobo.group_stations
                        WHERE station_id = vs.station_id
                        AND gr_id IN ($grid_string)
                    ) AS tbit
            ) AS total_user_grants,
            COALESCE(vsm.mu_name, '--') AS mu_name,
            vsm.mu_cap,
            COALESCE(vsm.province_name, '--') AS province_name,
            COALESCE(vsm.province_code, '--') AS province_code,
            COALESCE(vsm.region_name, '--') AS region_name,
            vsm.region_istat_code
        FROM bobo.group_stations gs
        LEFT JOIN metadata.view_stations_info vs USING (station_id)
        LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
        WHERE gr_id IN ($grid_string)
        ORDER BY station_id;
    };

    # return
    $self->pg->db->query($sql)->hashes;
}

sub get_portals {
    my ($self) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_portals");

    # query
    my $sql = qq{
        SELECT *
        FROM bobo.portals
        ORDER BY portal_name;
    };

    # return
    $self->pg->db->query($sql)->hashes;
}

sub get_linked_groups_byadmin {
    my ($self, $userid) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_linked_groups_byadmin");

    # query
    my $sql = qq{
        SELECT
            gr_id,
            gr_name,
            gr_desc,
            (
                SELECT
                    CASE WHEN gr_id IN (
                        SELECT admin_gr_id
                        FROM bobo.portal_properties
                    ) THEN TRUE
                    ELSE FALSE
                    END
            ) AS gr_admin,
            ARRAY(
                SELECT portal_id
                FROM bobo.portal_properties
                WHERE gr_id = ANY(linked_gr_id)
            ) AS gr_portals,
            ARRAY(
                SELECT
                    p.portal_name
                FROM bobo.portal_properties pp
                LEFT JOIN bobo.portals p USING (portal_id)
                WHERE gr_id = ANY(linked_gr_id)
            ) AS gr_portals_names
        FROM bobo.groups
        WHERE gr_id IN (
            SELECT UNNEST(linked_gr_id)
            FROM bobo.portal_properties
            WHERE admin_gr_id IN (
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = ?
            )
        )
        AND gr_id != 1
        ORDER BY gr_name;
    };

    # return
    $self->pg->db->query($sql, $userid)->hashes;
}

sub get_linked_comps_byadmin {
    my ($self, $userid) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_linked_comps_byadmin");

    # query
    my $sql = qq{
        SELECT
            comp_id,
            comp_name
        FROM bobo.companies
        WHERE comp_id IN (
            SELECT UNNEST(linked_comp_id)
            FROM bobo.portal_properties
            WHERE admin_gr_id IN (
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = ?
            )
        )
        ORDER BY comp_name;
    };

    # return
    $self->pg->db->query($sql, $userid)->hashes;
}

sub get_admin_pages_grants {
    my ($self, $userid) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_admin_pages_grants");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT *
            FROM bobo.view_menu_pages vmp
            WHERE (
                SELECT COUNT(*) AS children
                FROM bobo.view_menu_pages
                WHERE vmp.page_path @> page_path
                AND page_href IS NOT NULL
                AND page_id IN (
                    SELECT DISTINCT(page_id)
                    FROM bobo.group_pages
                    WHERE gr_id IN (
                        SELECT gr_id
                        FROM bobo.user_groups
                        WHERE us_id = ?
                    )
                )
            ) > 0
            AND menu_id = 1
            AND menu_page_level > 1
        ),
        u AS (
            SELECT
                page_id,
                (
                    SELECT bit_or(tbit.gp_iud_grants) FROM
                    (
                        SELECT gp_iud_grants
                        FROM bobo.group_pages
                        WHERE page_id = vmp.page_id
                        AND gr_id IN (
                            SELECT gr_id
                            FROM bobo.user_groups
                            WHERE us_id = ?
                        ) -- shared + gruppo selezionato
                    ) AS tbit
                ) AS total_user_grants
            FROM bobo.view_menu_pages vmp
            WHERE (
                SELECT COUNT(*) AS children
                FROM bobo.view_menu_pages
                WHERE vmp.page_path @> page_path
                AND page_href IS NOT NULL
                AND page_id IN (
                    SELECT DISTINCT(page_id)
                    FROM bobo.group_pages
                    WHERE gr_id IN (
                        SELECT gr_id
                        FROM bobo.user_groups
                        WHERE us_id = ?
                    )
                )
            ) > 0
            AND menu_id = 1
            AND menu_page_level > 1
        )
        SELECT
            t.page_id,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'100')) AS t (bit)) AS temp)::boolean IS TRUE THEN ''
                ELSE 'disabled'
            END AS class_insert,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'010')) AS t (bit)) AS temp)::boolean IS TRUE THEN ''
                ELSE 'disabled'
            END AS class_update,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'001')) AS t (bit)) AS temp)::boolean IS TRUE THEN ''
                ELSE 'disabled'
            END AS class_delete
        FROM t
        LEFT JOIN u USING (page_id)
        ORDER BY t.menu_page_order;
    };

    # return
    $self->pg->db->query( $sql, $userid, $userid, $userid )->hashes;
}

sub get_group_pages_grants {
    my ($self, $userid, $grid) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_group_pages_grants");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT *
            FROM bobo.view_menu_pages vmp
            WHERE (
                SELECT COUNT(*) AS children
                FROM bobo.view_menu_pages
                WHERE vmp.page_path @> page_path
                AND page_href IS NOT NULL
                AND page_id IN (
                    SELECT DISTINCT(page_id)
                    FROM bobo.group_pages
                    WHERE gr_id IN (
                        SELECT gr_id
                        FROM bobo.user_groups
                        WHERE us_id = ?
                    )
                )
            ) > 0
            AND menu_id = 1
            AND menu_page_level > 1
        ),
        u AS (
            SELECT
                page_id,
                (
                    SELECT bit_or(tbit.gp_iud_grants) FROM
                    (
                        SELECT gp_iud_grants
                        FROM bobo.group_pages
                        WHERE page_id = vmp.page_id
                        AND gr_id IN (1, ?) -- shared + gruppo selezionato
                    ) AS tbit
                ) AS total_user_grants
            FROM bobo.view_menu_pages vmp
            WHERE (
                SELECT COUNT(*) AS children
                FROM bobo.view_menu_pages
                WHERE vmp.page_path @> page_path
                AND page_href IS NOT NULL
                AND page_id IN (
                    SELECT DISTINCT(page_id)
                    FROM bobo.group_pages
                    WHERE gr_id IN (1, ?)
                )
            ) > 0
            AND menu_id = 1
            AND menu_page_level > 1
        )
        SELECT
            t.page_id,
            t.page_name,
            t.menu_page_level,
            t.menu_page_expanded,
            t.menu_page_icon,
            CASE
                WHEN u.total_user_grants NOTNULL THEN 'checked'
                ELSE ''
            END AS page_visibility,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'100')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS page_insert,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'010')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS page_update,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'001')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS page_delete
        FROM t
        LEFT JOIN u USING (page_id)
        ORDER BY t.menu_page_order;
    };

    # return
    $self->pg->db->query($sql, $userid, $grid, $grid)->hashes;
}

sub get_page_groups_grants {
    my ($self, $userid, $page) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_page_groups_grants");

    # query
    my $sql = qq{
        SELECT 
            page_id, 
            page_name, 
            g.gr_id, 
            g.gr_name, 
            gp.gp_iud_grants,
            CASE
                WHEN gp_iud_grants NOTNULL THEN 'checked'
                ELSE ''
            END AS page_visibility,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(gp_iud_grants, '000')), (b'100')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS page_insert,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(gp_iud_grants, '000')), (b'010')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS page_update,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(gp_iud_grants, '000')), (b'001')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS page_delete
        FROM 
            bobo.groups g
            LEFT JOIN bobo.group_pages gp ON (g.gr_id = gp.gr_id AND page_id = ?)
            LEFT JOIN bobo.pages p USING (page_id)
        WHERE 
            g.gr_id IN (
                SELECT UNNEST(linked_gr_id) AS gr_id
                FROM bobo.portal_properties
                WHERE admin_gr_id IN (
                    SELECT gr_id
                    FROM bobo.user_groups
                    WHERE us_id = ?
                )
            )
        ORDER BY gr_name
    };

    # return
    $self->pg->db->query($sql, $page, $userid)->hashes;    
}

sub get_group_stations_grants {
    my ($self, $userid, $grid, $prid, $netid) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_group_stations_grants");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT DISTINCT ON (station_id)
                s.station_id,
                s.station_name,
                s.station_active,
                vs.st_info_network_type_fk AS station_network_type_id,
                snt.st_network_desc AS station_network_type_desc,
                vsm.province_id
            FROM bobo.group_stations gs
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.stations_info vs USING (station_id)
            LEFT JOIN metadata.stations_network_type snt ON snt.st_network_id = vs.st_info_network_type_fk
            LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
            WHERE gr_id IN (
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = ?
            )
            AND vs.st_info_roaming_type_fk != 4 -- No siti con stanziamento
            AND station_id >= 1
    };

    # check province id
    if ($prid != -1) {
        $sql .= qq{
            AND vsm.province_id = $prid
        };
    }

    # check network id
    if ($netid != -1) {
        $sql .= qq{
            AND vs.st_info_network_type_fk = $netid
        };
    }

    $sql .= qq{
        ),
        u AS (
            SELECT
                gs.station_id,
                gs.gs_iud_grants AS total_user_grants
            FROM bobo.group_stations gs
            WHERE gr_id = ?
        )
        SELECT
            t.station_id,
            t.station_name,
            t.station_active,
            t.station_network_type_id,
            t.station_network_type_desc,
            CASE
                WHEN u.total_user_grants NOTNULL THEN 'checked'
                ELSE ''
            END AS station_visibility,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'100')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS station_insert,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'010')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS station_update,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'001')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS station_delete
        FROM t
        LEFT JOIN u USING (station_id)
    };

    $sql .= qq{
        ORDER BY t.station_network_type_desc, t.station_name;
    };

    # return
    $self->pg->db->query($sql, $userid, $grid)->hashes;
}

sub get_group_networks_grants {
    my ($self, $userid, $grid) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_group_networks_grants");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                st_network_id,
                st_network_name,
                st_network_desc,
                st_network_logo
            FROM bobo.view_user_networks
            WHERE user_id = ?
        )
        SELECT
            t.st_network_id  ,
            t.st_network_name,
            t.st_network_desc,
            t.st_network_logo,
            CASE
                WHEN gn.st_network_id NOTNULL THEN 'checked'
                ELSE ''
            END AS network_visibility
        FROM t
        LEFT JOIN bobo.group_networks gn ON (gn.st_network_id = t.st_network_id AND gn.gr_id = ?)
        ORDER BY t.st_network_name;
    };

    # return
    $self->pg->db->query($sql, $userid, $grid)->hashes;
}

sub get_group_widgets_grants {
    my ($self, $userid, $grid) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_group_widgets_grants");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                wdg_id,
                wdg_name,
                wdg_description,
                wdg_image_url,
                wdg_page_html
            FROM bobo.view_user_widgets
            WHERE user_id = ?
        )
        SELECT
            t.wdg_id,
            t.wdg_name,
            t.wdg_description,
            t.wdg_image_url,
            t.wdg_page_html,
            CASE
                WHEN gw.wdg_id NOTNULL THEN 'checked'
                ELSE ''
            END AS wdg_visibility,
            gw_dest
        FROM t
        LEFT JOIN bobo.group_widgets gw ON (gw.wdg_id = t.wdg_id AND gw.gr_id = ?)
        ORDER BY t.wdg_name;
    };

    # return
    $self->pg->db->query($sql, $userid, $grid)->hashes;
}

sub get_group_channels_grants {
    my ($self, $userid, $grid) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_group_channels_grants");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                channel_id,
                chat,
                channel_name,
                channel_desc
            FROM
                bobo.view_user_channels
            WHERE user_id = ?
        ),
        u AS (
            SELECT
                gc.tc_id AS channel_id,
                gc.gc_iud_grants AS total_user_grants
            FROM bobo.group_channels gc
            WHERE gr_id = ?
        )
        SELECT
            t.channel_id,
            t.chat,
            t.channel_name,
            t.channel_desc,
            CASE
                WHEN u.total_user_grants NOTNULL THEN 'checked'
                ELSE ''
            END AS channel_visibility,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'100')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS channel_insert,
            CASE
                WHEN (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (COALESCE(u.total_user_grants, '000')), (b'001')) AS t (bit)) AS temp)::boolean IS TRUE THEN 'checked'
                ELSE ''
            END AS channel_delete
        FROM t
        LEFT JOIN u USING (channel_id)
        ORDER BY t.channel_name;
    };

    # return
    $self->pg->db->query($sql, $userid, $grid)->hashes;
}

sub get_group_codes_grants {
    my ($self, $userid, $grid) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_group_networks_grants");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                value AS fvc_code_id,
                label AS fvc_code_desc
            FROM
                jsonb_to_recordset(
                    bobo.f_get_user_portal_options( ?, '/dat_validaz_finale' )-> 'codes'
                ) AS x(value integer, label text)
            ORDER BY
                value
        )
        SELECT
            t.fvc_code_id  ,
            t.fvc_code_desc,
            CASE
                WHEN gfc.fvc_code_id NOTNULL THEN 'checked'
                ELSE ''
            END AS code_visibility
        FROM t
        LEFT JOIN bobo.group_final_codes gfc ON (t.fvc_code_id = gfc.fvc_code_id AND gfc.gr_id = ?)
        ORDER BY t.fvc_code_id;
    };

    # return
    $self->pg->db->query($sql, $userid, $grid)->hashes;
}
# END PERMISSIONS GETTER

# PORTAL OPTIONS
sub get_all_parameters {
    my ($self) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_all_parameters");

    # query
    my $sql = qq{
        SELECT
            parameter_id,
            parameter_name,
            parameter_unit,
            parameter_type_id,
            COALESCE(parameter_type_desc, '--') AS parameter_type_desc
        FROM
            metadata.view_parameters_info
        ORDER BY
            parameter_type_id, parameter_name;
    };

    # return
    $self->pg->db->query($sql)->hashes;
}

sub get_final_validation_options {
    my ($self, $portal) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub get_final_validation_options");

    # query
    my $sql = qq{
        SELECT
            po_obj
        FROM
            bobo_tools.portal_options
        WHERE
            portal_id = ?
            AND page_id = (
                SELECT page_id
                FROM bobo.pages
                WHERE page_href = '/dat_validaz_finale'
            )
    };

    # return
    $self->pg->db->query($sql, $portal)->hash->{po_obj};
}
# END PORTAL OPTIONS

sub insert_new_group {
    my( $self, $us_admin, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub insert_new_group");
    $self->app->log->debug($params->{'new-group-name'});

    my $tx;
    my $new_gr_id;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuovo gruppo e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbadmin STEP 1");

        $new_gr_id = $self->pg->db->insert('bobo.groups', {
            gr_name => $params->{'new-group-name'},
            gr_desc => $self->app->helperEscapeParam($params->{'new-group-desc'}),

        }, {returning => 'gr_id'})->hash->{'gr_id'};

        # ##################################################################
        # 2- associazione nuovo gruppo con portal_id dell'admin
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbadmin STEP 2");

        my $sql;
        if (defined $params->{'new-group-portals'}) {
            my @portals_id;
            if (ref($params->{'new-group-portals'}) eq 'ARRAY') {
                @portals_id = @{$params->{'new-group-portals'}};
            }
            else {
                push @portals_id, $params->{'new-group-portals'};
            }

            for my $portal_id (@portals_id) {
                $sql = qq{ UPDATE bobo.portal_properties SET linked_gr_id = array_append(linked_gr_id, ?) WHERE portal_id IN (0, ?) };
                $self->pg->db->query($sql, $new_gr_id, $portal_id);
            }
        }
        else {
            $sql = qq{
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            };

            my $us_portal = $self->pg->db->query($sql, $us_admin)->hash->{'portal_id'};

            # link to Ecometer and to admin portal
            $sql = qq{ UPDATE bobo.portal_properties SET linked_gr_id = array_append(linked_gr_id, ?) WHERE portal_id IN (0, ?) };
            $self->pg->db->query($sql, $new_gr_id, $us_portal);
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
       return $new_gr_id;
    }
}

sub insert_new_user {
    my( $self, $us_admin, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub insert_new_user");
    $self->app->log->debug($params->{'new-user-name'});

    my $tx;
    my $new_us_id;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuovo utente e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbadmin STEP 1");

        $new_us_id = $self->pg->db->insert('bobo.users', {
            us_name     => $self->app->helperEscapeParam($params->{'new-user-name'}),
            us_2nd_name => $self->app->helperEscapeParam($params->{'new-user-secondname'}),
            us_surname  => $self->app->helperEscapeParam($params->{'new-user-surname'}),
            us_role     => $self->app->helperEscapeParam($params->{'new-user-role'}),
            us_email    => $self->app->helperEscapeParam($params->{'new-user-email'}),
            us_phone    => $self->app->helperEscapeParam($params->{'new-user-phone'}),
            us_mobile   => $self->app->helperEscapeParam($params->{'new-user-mobile'}),
            us_exp_time => $self->app->helperEscapeParam($params->{'new-user-session'}),
            us_pwd      => $params->{'new-user-surname'}
        }, {returning => 'us_id'})->hash->{'us_id'};

        # ##################################################################
        # 2- associazione nuovo utente con portal_id dell'admin e azienda selezionata nel form
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbadmin STEP 2");

        my $sql;
        my $new_us_portal;
        if (defined $params->{'new-user-portal'}) {
            $new_us_portal = $params->{'new-user-portal'};
        }
        else {
            $sql = qq{
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            };

            $new_us_portal = $self->pg->db->query($sql, $us_admin)->hash->{'portal_id'};
        }

        my $new_us_comp = $params->{'new-user-comp'};

        $self->pg->db->insert('bobo.users_metadata', {
            us_id     => $new_us_id,
            comp_id   => $new_us_comp,
            portal_id => $new_us_portal
        });

        # ##################################################################
        # 3- associazione nuovo utente con i gruppi selezionati nel form e user update avatar
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbadmin STEP 3");
        my @groups_id;
        if (ref($params->{'new-user-groups'}) eq 'ARRAY') {
            @groups_id = @{$params->{'new-user-groups'}};
        }
        else {
            push @groups_id, $params->{'new-user-groups'};
        }

        my $shared = 0;
        for my $gr_id (@groups_id) {
            if ($gr_id == 1) {
                $shared = 1;
            }

            $self->pg->db->insert('bobo.user_groups', {
                us_id => $new_us_id,
                gr_id => $gr_id
            });
        }

        if ($shared == 0) {
            $self->pg->db->insert('bobo.user_groups', {
                us_id => $new_us_id,
                gr_id => 1
            });
        }

        $sql = qq{
            WITH tmp AS(
                SELECT
                    CASE WHEN groups_id && (
                        SELECT ARRAY_AGG(admin_gr_id)
                        FROM bobo.portal_properties
                    ) THEN '/bobo-img/default/avatar/ava-admin.png'
                    ELSE '/bobo-img/default/avatar/ava01.png'
                    END AS us_avatar
                FROM
                    bobo.view_users vu
                WHERE
                    user_id = ?
            )
            UPDATE bobo.users SET us_avatar_thumb = ( SELECT us_avatar FROM tmp) WHERE us_id = ?;
        };

        $self->pg->db->query($sql, $new_us_id, $new_us_id);

    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return undef;
    }
    else {
       $tx->commit;
       return $new_us_id;
    }
}

sub insert_page_grants {
    my( $self, $grid, $pgid, $grants ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub insert_page_grants");

    my $grants_bit = '';

    $grants_bit .= $grants->{'insert'} ? 1 : 0;
    $grants_bit .= $grants->{'update'} ? 1 : 0;
    $grants_bit .= $grants->{'delete'} ? 1 : 0;

    $self->app->log->debug("$grants_bit");

    # query
    my $sql = qq{
        INSERT INTO bobo.group_pages
            (gr_id, page_id, gp_iud_grants)
        VALUES
            (?, ?, ?)

        ON CONFLICT ON CONSTRAINT bobo_group_pages_ukey
        DO UPDATE
            SET gp_iud_grants = ?;
    };

    # check result and return
    if ($self->pg->db->query($sql, $grid, $pgid, $grants_bit, $grants_bit)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub insert_network_grants {
    my( $self, $grid, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub insert_network_grants");

    # query
    my $sql = qq{
        INSERT INTO bobo.group_networks
            (gr_id, st_network_id)
        VALUES
            (?, ?);
    };

    # check result and return
    if ($self->pg->db->query($sql, $grid, $id)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub insert_final_code_grants {
    my( $self, $grid, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub insert_final_code_grants");

    # query
    my $sql = qq{
        INSERT INTO bobo.group_final_codes
            (gr_id, fvc_code_id)
        VALUES
            (?, ?);
    };

    # check result and return
    if ($self->pg->db->query($sql, $grid, $id)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub insert_widget_grants {
    my( $self, $grid, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub insert_widget_grants");

    # query
    my $sql = qq{
        INSERT INTO bobo.group_widgets
            (gr_id, wdg_id)
        VALUES
            (?, ?);
    };

    # check result and return
    if ($self->pg->db->query($sql, $grid, $id)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub insert_channel_grants {
    my( $self, $grid, $chid, $grants ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub insert_channel_grants");

    my $grants_bit = '';

    $grants_bit .= $grants->{'insert'} ? 1 : 0;
    $grants_bit .= $grants->{'update'} ? 1 : 0;
    $grants_bit .= $grants->{'delete'} ? 1 : 0;

    $self->app->log->debug("$grants_bit");

    # query
    my $sql = qq{
        INSERT INTO bobo.group_channels
            (gr_id, tc_id, gc_iud_grants)
        VALUES
            (?, ?, ?)

        ON CONFLICT ON CONSTRAINT bobo_group_channels_ukey
        DO UPDATE
            SET gc_iud_grants = ?;
    };

    # check result and return
    if ($self->pg->db->query($sql, $grid, $chid, $grants_bit, $grants_bit)) {
        return 1;
    }
    else {
        return 0;
    }
}

# PORTAL OPTIONS
sub insert_validation_options {
    my( $self, $portal, $obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub insert_validation_options");

    # query
    my $sql = qq{
        INSERT INTO bobo_tools.portal_options (portal_id, page_id, po_obj)
        (
            SELECT
                ?::integer,
                page_id,
                ?::jsonb
            FROM
                bobo.pages
            WHERE
                page_href IN ('/dat_validazione', '/dat_validaz_finale')
        )
        ON CONFLICT ON CONSTRAINT bobo_tools_portal_options_ukey
        DO UPDATE
            SET po_obj = EXCLUDED.po_obj;
    };

    # check result and return
    if ($self->pg->db->query($sql, $portal, $obj))
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub update_user {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub update_user");
    $self->app->log->debug($params->{'new-user-name'});

    my $tx;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1- modifica utente
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbadmin STEP 1");

        # $db->update('some_table', {foo => 'bar'}, {id => 23});
        $self->pg->db->update('bobo.users', {
            us_name     => $params->{'new-user-name'},
            us_2nd_name => $self->app->helperEscapeParam($params->{'new-user-secondname'}),
            us_surname  => $params->{'new-user-surname'},
            us_role     => $self->app->helperEscapeParam($params->{'new-user-role'}),
            us_email    => $params->{'new-user-email'},
            us_phone    => $self->app->helperEscapeParam($params->{'new-user-phone'}),
            us_mobile   => $self->app->helperEscapeParam($params->{'new-user-mobile'}),
            us_active   => $self->app->helperGetBoolean($params, 'user-active'),
            us_exp_time => $self->app->helperEscapeParam($params->{'new-user-session'})
        }, {us_id => $params->{'new-user-id'}});

        # ##################################################################
        # 2- modifica metadata (comp_id) dell'utente
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbadmin STEP 2");
        # $self->app->log->debug($params->{'new-user-comp'});
        if (defined $params->{'new-user-portal'}) {
            $self->pg->db->update('bobo.users_metadata', {
                portal_id => $params->{'new-user-portal'}
            }, {us_id => $params->{'new-user-id'}});
        }

        $self->pg->db->update('bobo.users_metadata', {
            comp_id => $params->{'new-user-comp'}
        }, {us_id => $params->{'new-user-id'}});

        # ##################################################################
        # 3- eliminazione associazioni utente-gruppi e inserimento nuove associazioni
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbadmin STEP 3");
        my $sql = qq{
            DELETE FROM bobo.user_groups WHERE us_id = ?
        };

        $self->pg->db->query($sql, $params->{'new-user-id'});

        my @groups_id;

        if (ref($params->{'new-user-groups'}) eq 'ARRAY') {
            @groups_id = @{$params->{'new-user-groups'}};
        }
        else {
            push @groups_id, $params->{'new-user-groups'};
        }

        my $shared = 0;
        for my $gr_id (@groups_id) {
            if ($gr_id == 1) {
                $shared = 1;
            }

            $self->pg->db->insert('bobo.user_groups', {
                us_id => $params->{'new-user-id'},
                gr_id => $gr_id
            });
        }

        if ($shared == 0) {
            $self->pg->db->insert('bobo.user_groups', {
                us_id => $params->{'new-user-id'},
                gr_id => 1
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

sub update_group {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub update_group");
    $self->app->log->debug($params->{'new-group-name'});

    my $tx;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1- modifica gruppo
        # ##################################################################

        $self->pg->db->update('bobo.groups', {
            gr_name => $params->{'new-group-name'},
            gr_desc => $self->app->helperEscapeParam($params->{'new-group-desc'}),

        }, {gr_id => $params->{'new-group-id'}});

        if (defined $params->{'new-group-portals'}) {
            # ##################################################################
            # 2- eliminazione associazioni gruppo
            # ##################################################################
            $self->app->log->debug("Bobo::Model::Dbadmin STEP 2");

            my $sql = qq{
                UPDATE bobo.portal_properties SET linked_gr_id = array_remove(linked_gr_id, ?);
            };

            $self->pg->db->query($sql, $params->{'new-group-id'});

            # ##################################################################
            # 2- inserimento nuove associazioni gruppo
            # ##################################################################
            $self->app->log->debug("Bobo::Model::Dbadmin STEP 3");

            my @portals_id;
            if (ref($params->{'new-group-portals'}) eq 'ARRAY') {
                @portals_id = @{$params->{'new-group-portals'}};
            }
            else {
                push @portals_id, $params->{'new-group-portals'};
            }

            for my $portal_id (@portals_id) {
                $sql = qq{ UPDATE bobo.portal_properties SET linked_gr_id = array_append(linked_gr_id, ?) WHERE portal_id = ? };
                $self->pg->db->query($sql, $params->{'new-group-id'}, $portal_id);
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

sub update_avatar {
    my( $self, $user_id, $avatar ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub update_avatar");
    $self->app->log->debug($user_id);

    # query
    my $sql = qq{
        UPDATE bobo.users SET us_avatar_thumb = ? WHERE us_id = ?;
    };

    # error check
    if ($self->pg->db->query($sql, $avatar, $user_id)) {
        return 1;
    }
    else {
       $self->app->log->warn("Error: ".$@);
       return 0;
    }
}

sub update_stations_grants {
    my( $self, $grid, $stations_grants ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub edit_stations_grants");

    my $tx;
    my $sql;

    eval {
        $tx =  $self->pg->db->begin;

        my $sql;
        my $grants_bit;

        for my $station (@{$stations_grants}) {
            my $stid = $station->{'stid'};

            if ($station->{'visible'}) { # visibile quindi inserisco / modifico grants per stazione
                $grants_bit = '';

                $grants_bit .= $station->{'insert'} ? 1 : 0;
                $grants_bit .= $station->{'update'} ? 1 : 0;
                $grants_bit .= $station->{'delete'} ? 1 : 0;

                # $self->app->log->debug("$grants_bit");

                $sql = qq{
                    INSERT INTO bobo.group_stations
                        (gr_id, station_id, gs_iud_grants)
                    VALUES
                        (?, ?, ?)
                    ON CONFLICT ON CONSTRAINT bobo_group_stations_ukey
                    DO UPDATE
                        SET gs_iud_grants = ?;
                };

                $self->pg->db->query($sql, $grid, $stid, $grants_bit, $grants_bit);
            }
            else { # elimino la stazione dal gruppo
                $sql = qq{DELETE FROM bobo.group_stations WHERE gr_id = ? AND station_id = ?; };

                $self->pg->db->query($sql, $grid, $stid);
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

sub update_widget_destination {
    my( $self, $grid, $wdgid, $dest ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub update_widget_destination");

    # query
    my $sql = qq{
        UPDATE bobo.group_widgets
        SET gw_dest = ?
        WHERE gr_id = ?
        AND  wdg_id = ?;
    };

    # check result and return
    if ($self->pg->db->query($sql, $dest, $grid, $wdgid)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub delete_group {
    my( $self, $grid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub delete_group");

    my $tx;

    eval {
        $tx =  $self->pg->db->begin;

        # DA IMPLEMENTARE
        # check link ad altre tabelle
        # https://stackoverflow.com/questions/5347050/postgresql-sql-script-to-get-a-list-of-all-tables-that-have-a-particular-column

        # ##################################################################
        # 1- eliminazione gruppo
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbadmin STEP 1");

        my $sql = qq{
            DELETE FROM bobo.groups WHERE gr_id = ?;
        };

        $self->pg->db->query($sql, $grid);

        # ##################################################################
        # 2- eliminazione associazioni gruppo
        # ##################################################################
        $sql = qq{
            UPDATE bobo.portal_properties SET linked_gr_id = array_remove(linked_gr_id, ?)
        };

        $self->pg->db->query($sql, $grid);
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

sub delete_page_grants {
    my( $self, $grid, $pgid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub delete_page_grants");

    # query
    my $sql = qq{ DELETE FROM bobo.group_pages WHERE gr_id = ? AND page_id = ?; };

    # check result and return
    if ($self->pg->db->query($sql, $grid, $pgid)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub delete_network_grants {
    my( $self, $grid, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub delete_network_grants");

    # query
    my $sql = qq{ DELETE FROM bobo.group_networks WHERE gr_id = ? AND st_network_id = ?; };

    # check result and return
    if ($self->pg->db->query($sql, $grid, $id)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub delete_final_code_grants {
    my( $self, $grid, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub delete_final_code_grants");

    # query
    my $sql = qq{ DELETE FROM bobo.group_final_codes WHERE gr_id = ? AND fvc_code_id = ?; };

    # check result and return
    if ($self->pg->db->query($sql, $grid, $id)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub delete_widget_grants {
    my( $self, $grid, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub delete_widget_grants");

    # query
    my $sql = qq{ DELETE FROM bobo.group_widgets WHERE gr_id = ? AND wdg_id = ?; };

    # check result and return
    if ($self->pg->db->query($sql, $grid, $id)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub delete_channel_grants {
    my( $self, $grid, $chid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbadmin sub delete_channel_grants");

    # query
    my $sql = qq{ DELETE FROM bobo.group_channels WHERE gr_id = ? AND tc_id = ?; };

    # check result and return
    if ($self->pg->db->query($sql, $grid, $chid)) {
        return 1;
    }
    else {
        return 0;
    }
}

1;

=head1 get_users

Funzione che recupera tutti gli utenti (se presente l'id, di un determinato gruppo) dal database.

Argomenti:  * id dell'utente ('userid');

           * id del gruppo, se presente ('grid');

Return:     Risultato della query.

=cut

=head1 get_groups_menu

Funzione che recupera, dati gli id, le informazioni dei menu visibili di uno o piu' gruppi dal database.

Argomenti:  * array dei gruppi ('groups_id');

Return:     Risultato della query.

=cut

=head1 get_groups_stations

Funzione che recupera, dati gli id, le informazioni delle stazioni visibili di uno o piu' gruppi dal database.

Argomenti:  * array dei gruppi ('groups_id');

Return:     Risultato della query.

=cut

=head1 get_portals

Funzione che recupera le informazioni di tutti i portali dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_linked_groups_byadmin

Funzione che recupera le informazioni dei gruppi co-linkati al gruppo
di un determinato utente dal database.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query.

=cut

=head1 get_linked_comps_byadmin

Funzione che recupera le informazioni delle aziende co-linkate al gruppo
di un determinato utente dal database.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query.

=cut

=head1 get_admin_pages_grants

Funzione che recupera i permessi sulle pagine dal database.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query.

=cut

=head1 get_group_pages_grants

Funzione che recupera i permessi che un determinato gruppo possiede sulle pagine del portale dal database.

Argomenti:  * id dell'utente ('userid');

           * id del gruppo ('grid');

Return:     Risultato della query.

=cut

=head1 get_group_stations_grants

Funzione che recupera i permessi che un determinato gruppo possiede sulle stazioni dal database.

Argomenti:  * id dell'utente ('userid');

           * id del gruppo ('grid');

           * id della provincia, se presente ('prid');

           * id della rete, se presente ('netid');

Return:     Risultato della query.

=cut

=head1 get_group_networks_grants

Funzione che recupera i permessi che un determinato gruppo possiede sulle reti del portale dal database.

Argomenti:  * id dell'utente ('userid');

           * id del gruppo ('grid');

Return:     Risultato della query.

=cut

=head1 get_group_widgets_grants

Funzione che recupera i permessi che un determinato gruppo possiede sui widget del portale dal database.

Argomenti:  * id dell'utente ('userid');

           * id del gruppo ('grid');

Return:     Risultato della query.

=cut

=head1 get_group_channels_grants

Funzione che recupera i permessi che un determinato gruppo possiede sui canali del portale dal database.

Argomenti:  * id dell'utente ('userid');

           * id del gruppo ('grid');

Return:     Risultato della query.

=cut

=head1 get_group_codes_grants

Funzione che recupera i permessi che un determinato gruppo possiede sui codici di validazione dal database.

Argomenti:  * id dell'utente ('userid');

           * id del gruppo ('grid');

Return:     Risultato della query.

=cut

=head1 get_all_parameters

Funzione che effettua il recupero delle informazioni di tutti i parametri dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_final_validation_options

Funzione che recupera, dato l'id di un portale, le relative impostazioni di validazione multilivello dal database.

Argomenti:  * id del portale ('portal');

Return:     Risultato della query.

=cut

=head1 insert_new_group

Funzione che inserisce un nuovo gruppo nel database.

Argomenti:  * id dell'utente ('us_admin');

           * oggetto contenente le informazioni del gruppo da inserire ('params');

Return:     Se tutto OK, restituisce l'id del gruppo appena inserita;

        Se KO, restituisce 'undef'.

=cut

=head1 insert_new_user

Funzione che inserisce un nuovo utente nel database.

Argomenti:  * id dell'utente ('us_admin');

           * oggetto contenente le informazioni del utente da inserire ('params');

Return:     Se tutto OK, restituisce l'id del utente appena inserita;

        Se KO, restituisce 'undef'.

=cut

=head1 insert_page_grants

Funzione che inserisce i permessi su una determinata pagina ad un determinato gruppo nel database.

Argomenti:  * id del gruppo ('grid');

           * id della pagina ('pgid');

           * permessi da associare ('grants');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut

=head1 insert_network_grants

Funzione che inserisce i permessi su una determinata rete ad un determinato gruppo nel database.

Argomenti:  * id del gruppo ('grid');

           * id della rete ('id');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut

=head1 insert_final_code_grants

Funzione che inserisce i permessi su un determinato codice di validazione finale ad un determinato gruppo nel database.

Argomenti:  * id del gruppo ('grid');

           * id del codice di validazione finale ('id');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut

=head1 insert_widget_grants

Funzione che inserisce i permessi su un determinato widget ad un determinato gruppo nel database.

Argomenti:  * id del gruppo ('grid');

           * id del widget ('id');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut

=head1 insert_channel_grants

Funzione che inserisce i permessi su un determinato canale ad un determinato gruppo nel database.

Argomenti:  * id del gruppo ('grid');

           * id del canale ('chid');

           * permessi da associare ('grants');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut

=head1 insert_validation_options

Funzione che inserisce, per un determinato portale, le impostazioni di validazione dal database.

Argomenti:  * id del portale ('portal');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut

=head1 update_user

Funzione che modifica, dato l'id, un determinato utente nel database.

Argomenti:  * oggetto contenente le informazioni dell'utente da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_group

Funzione che modifica, dato l'id, un determinato gruppo nel database.

Argomenti:  * oggetto contenente le informazioni del gruppo da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_avatar

Funzione che effettua l'update dell'immagine profilo dell'utente.

Argomenti:  * id dell'utente ('user_id');

           * path dell'immagine ('avatar');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut

=head1 update_stations_grants

Funzione che effettua l'update dei permessi di un determinato gruppo su una determinata stazione.

Argomenti:  * id del gruppo ('grid');

           * oggetto contenente le informazioni della stazione e i relativi permessi da modificare ('stations_grants');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_widget_destination

Funzione che effettua l'update della destinazione di un determinato widget di un determinato gruppo.

Argomenti:  * id del gruppo ('grid');

           * id del widget ('wdgid');

           * id della destinazione del widget  ('dest');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_group

Funzione che effettua l'eliminazione di un gruppo dal database.

Argomenti:  * id del gruppo ('grid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_page_grants

Funzione che effettua l'eliminazione dei permessi di un determinato gruppo
su una determinata pagina dal database.

Argomenti:  * id del gruppo ('grid');

           * id della pagina ('pgid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_network_grants

Funzione che effettua l'eliminazione dei permessi di un determinato gruppo
su una determinata rete dal database.

Argomenti:  * id del gruppo ('grid');

           * id della rete ('id');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 insert_final_code_grants

Funzione che effettua l'eliminazione dei permessi di un determinato gruppo
su un determinato codice di validazione finale dal database.

Argomenti:  * id del gruppo ('grid');

           * id del codice di validazione finale ('id');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut

=head1 delete_widget_grants

Funzione che effettua l'eliminazione dei permessi di un determinato gruppo
su un determinato widget dal database.

Argomenti:  * id del gruppo ('grid');

           * id del widget ('id');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_channel_grants

Funzione che effettua l'eliminazione dei permessi di un determinato gruppo
su un determinato canale dal database.

Argomenti:  * id del gruppo ('grid');

           * id del canale ('chid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut