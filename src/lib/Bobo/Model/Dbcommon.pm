package Bobo::Model::Dbcommon;
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

# -----------------------------------------------------------------------------
# USER AND COMPANY
# -----------------------------------------------------------------------------
sub get_user_byid {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_user_byid");

    # query
    my $sql = qq{
        SELECT
            user_id,
            user_active,
            user_name,
            user_second_name,
            user_surname,
            user_email,
            user_phone,
            user_mobile,
            user_role,
            user_avatar,
            user_avatar_thumb,
            user_expiration_time,
            CASE user_expiration_time
                WHEN 86400 THEN '1 Giorno'
                WHEN 259200 THEN '3 Giorni'
                WHEN 604800 THEN '1 Settimana'
                WHEN 2419200 THEN '1 Mese'
                WHEN 14515200 THEN '6 Mesi'
                WHEN 2147483647 THEN 'Mai'
            END AS user_expiration_time_text,
            user_name || ' ' || COALESCE(user_second_name, '') || ' ' || user_surname AS user_fullname,
            CASE
                WHEN user_active IS TRUE THEN 'Si'
                ELSE 'No'
            END AS user_active,
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
            groups_name,
            company_id,
            company_name,
            company_desc,
            (
                SELECT
                    CASE WHEN company_id = (
                        SELECT admin_comp_id
                        FROM bobo.portal_properties
                        WHERE portal_id = vu.portal_id
                    ) THEN TRUE
                    ELSE FALSE
                    END
            ) AS company_admin,
            portal_id
        FROM
            bobo.view_users vu
        WHERE
            user_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hash;
}

sub get_portal_groups_by_user {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_portal_groups_by_user");

    # query
    my $sql = qq{
        SELECT gr_id, gr_name
        FROM bobo.groups
        WHERE gr_id IN (
            SELECT UNNEST(linked_gr_id)
            FROM bobo.portal_properties
            WHERE portal_id = (
                SELECT portal_id
                FROM bobo.view_users
                WHERE user_id = ?
            )
        )
        AND gr_id != 1
        ORDER BY gr_name
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_portal_users_by_user {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_portal_users_by_user");

    # query
    my $sql = qq{
        SELECT
            u.us_id,
            u.us_name,
            u.us_surname,
            CONCAT_WS(' ', u.us_name, u.us_2nd_name, u.us_surname) AS us_fullname,
            u.us_email
        FROM
            bobo.users u
            LEFT JOIN bobo.users_metadata um USING (us_id)
        WHERE
            um.portal_id = (
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
            AND us_active IS TRUE
        ORDER BY
            us_name||' '||us_surname;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_companies_by_portal {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_companies_by_portal");

    # if user company is admin, get all portal companies
    # otherwise get only user company info
    # query
    my $sql = qq{
        WITH t AS(
            SELECT
                CASE
                    WHEN um.comp_id = pp.admin_comp_id THEN linked_comp_id
                    ELSE ARRAY[um.comp_id]
                END AS comps
            FROM bobo.users_metadata um
            LEFT JOIN bobo.portal_properties pp USING (portal_id)
            WHERE us_id = ?
        )
        SELECT *
        FROM bobo.companies
        WHERE comp_id IN (
            SELECT UNNEST(comps) FROM t
        )
        ORDER BY comp_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_comp_detail_byid {
    my ( $self, $compid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_comp_detail_byid");

    # query
    my $sql = qq{
        SELECT
            comp_id  ,
            comp_name,
            COALESCE(comp_desc       , '') AS comp_desc,
            COALESCE(comp_title      , '') AS comp_title,
            COALESCE(comp_logo       , 'no_logo.png'        ) AS comp_logo,
            COALESCE(comp_thumb_logo , 'no_thumblogo.png'   ) AS comp_thumb_logo,
            COALESCE(comp_address    , '') AS comp_address,
            COALESCE(comp_phone      , '') AS comp_phone,
            COALESCE(comp_web        , '') AS comp_web,
            COALESCE(comp_email      , '') AS comp_email
        FROM bobo.companies
        WHERE
            comp_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $compid)->hash;
}

sub get_user_station_grants {
    my ($self, $user_id, $station_id) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_user_station_grants");
    $self->app->log->debug($station_id);

    # query
    my $sql = qq{
        WITH t AS (
            SELECT DISTINCT ON (u.us_id, s.station_id)
                u.us_id AS user_id,
                s.station_id,
                ( SELECT bit_or(tbit.gs_iud_grants) AS bit_or
                       FROM ( SELECT group_stations.gs_iud_grants
                               FROM bobo.group_stations
                              WHERE ((group_stations.station_id = s.station_id) AND (group_stations.gr_id IN ( SELECT user_groups.gr_id
                                       FROM bobo.user_groups
                                      WHERE (user_groups.us_id = u.us_id))))) tbit) AS total_user_grants
                FROM bobo.users u
                LEFT JOIN bobo.user_groups ug USING (us_id)
                LEFT JOIN bobo.groups g USING (gr_id)
                LEFT JOIN bobo.group_stations gs USING (gr_id)
                LEFT JOIN metadata.stations s USING (station_id)
            ORDER BY u.us_id, s.station_id
        )
        SELECT
            (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'100')) AS t (bit)) AS temp)::boolean AS station_insert,
            (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'010')) AS t (bit)) AS temp)::boolean AS station_update,
            (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'001')) AS t (bit)) AS temp)::boolean AS station_delete
        FROM
            t
        WHERE
            user_id = ?
            AND station_id = ?;
    };

    # return
    $self->pg->db->query($sql, $user_id, $station_id)->hash;
}

sub check_permission_station {
    my ( $self, $stid, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub check_permission_station");

    # query
    my $sql = qq{
        SELECT EXISTS(
            SELECT 1
            FROM bobo.view_user_stations
            WHERE  user_id = ?
            AND station_id = ?

        ) AS flag;
    };

    # return
    return $self->pg->db->query($sql, $userid, $stid)->hash->{'flag'};
}

# -----------------------------------------------------------------------------
# UTILITIES
# -----------------------------------------------------------------------------
sub get_aggregations {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_aggregations");

    # query
    my $sql = qq{
        SELECT DISTINCT ON(app_aggregation_label)
            app_aggregation_label,
            initcap(app_aggregation_desc) AS app_aggregation_desc,
            app_aggregation_default
        FROM metadata.view_app_aggregations
        WHERE app_aggregation_cadence_id >= (
            SELECT
                MIN(COALESCE((vsi.station_cadence_type_id)::text, '0')::integer)
            FROM
                bobo.view_user_stations vus
                LEFT JOIN metadata.view_stations_info vsi USING (station_id)
            WHERE vus.user_id = ?
            AND vsi.station_measure_type_id != 3
        )
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_min_aggregation {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_min_aggregation");

    # query
    my $sql = qq{
        SELECT DISTINCT ON(app_aggregation_cadence_id)
            app_aggregation_label,
            initcap(app_aggregation_desc) AS app_aggregation_desc
        FROM metadata.view_app_aggregations
        ORDER BY app_aggregation_cadence_id
        LIMIT 1;
    };

    # return
    return $self->pg->db->query($sql)->hash;
}

sub get_treatments {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_treatments");

    # query
    my $sql = qq{
        SELECT
            treatment_id,
            treatment_name
        FROM metadata.view_params_treatments
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

# -----------------------------------------------------------------------------
# REGIONS, PROVINCES AND MUNICIPALITIES
# -----------------------------------------------------------------------------
sub get_all_regions {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_all_regions");

    # query
    my $sql = qq{
        SELECT
            region_id,
            region_name
        FROM main.regions
        ORDER BY region_name
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_province_by_id {
    my ( $self, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_province_by_id");

    # query
    my $sql = qq{
        SELECT
            province_id,
            province_name,
            province_istat_code,
            province_code,
            province_note
        FROM
            main.provinces p
        WHERE
            province_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $prov)->hash;
}

sub get_provinces {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_provinces");

    # query
    my $sql = qq{
        SELECT DISTINCT ON (smu.region_name, smu.province_name)
            smu.province_id,
            smu.province_name,
            smu.province_istat_code,
            smu.province_code,
            smu.region_id,
            smu.region_name
        FROM
            metadata.view_stations_municipality smu
            LEFT JOIN bobo.view_user_stations us USING (station_id)
        WHERE
            us.user_id = ?
            AND us.station_active IS TRUE
            AND smu.province_id IS NOT NULL
        ORDER BY
            smu.region_name, smu.province_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_all_provinces {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_all_provinces");

    # query
    my $sql = qq{
        SELECT DISTINCT ON (smu.region_name, smu.province_name)
            smu.province_id,
            smu.province_name,
            smu.province_istat_code,
            smu.province_code,
            smu.region_id,
            smu.region_name
        FROM
            metadata.view_stations_municipality smu
            LEFT JOIN bobo.view_user_stations us USING (station_id)
        WHERE
            us.user_id = ?
            AND smu.province_id IS NOT NULL
        ORDER BY
            smu.region_name, smu.province_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_italy_provinces {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_italy_provinces");

    # query
    my $sql = qq{
        SELECT DISTINCT ON (vm.region_name, vm.province_name)
            vm.province_id,
            vm.province_name,
            vm.province_istat_code,
            vm.province_code,
            vm.region_id,
            vm.region_name
        FROM
            main.view_municipalities vm
        WHERE
            vm.province_id IS NOT NULL
        ORDER BY
            vm.region_name, vm.province_name;
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_all_provinces_by_region {
    my ( $self, $region_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_all_provinces_by_region");

    # query
    my $sql = qq{
        SELECT
            p.province_id,
            p.province_name,
            p.province_code
        FROM main.provinces p
        LEFT JOIN main.region_provinces rp USING (province_id)
        WHERE region_id = ?
        ORDER BY province_name;
    };

    # return
    return $self->pg->db->query($sql, $region_id)->hashes;
}

sub get_all_municipalities_by_province {
    my ( $self, $province_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_all_provinces_by_region");

    # query
    my $sql = qq{
        SELECT
            m.mu_id,
            m.mu_name,
            COALESCE(m.mu_cap, '') AS mu_cap
        FROM main.municipalities m
        LEFT JOIN main.province_municipalities pm USING (mu_id)
        WHERE province_id = ?
        OR mu_id = 0
        ORDER BY (
            CASE
                WHEN mu_id = 0 THEN 1
                ELSE 999
            END
        ) ASC, mu_name;
    };

    # return
    return $self->pg->db->query($sql, $province_id)->hashes;
}

sub get_municipality_by_coordinates {
    my ( $self, $lon, $lat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_municipality_by_coordinates");

    # query
    my $sql = qq{
        SELECT
            m.mu_id,
            m.mu_name,
            m.mu_istat_code,
            m.mu_catasto_code,
            m.mu_cap,
            m.mu_note,
            p.province_id,
            p.province_name,
            p.province_istat_code,
            p.province_code,
            p.province_note,
            r.region_id,
            r.region_name,
            r.region_istat_code,
            r.region_note
        FROM
            main.municipalities m
            LEFT JOIN main.province_municipalities pm USING (mu_id)
            LEFT JOIN main.provinces p USING (province_id)
            LEFT JOIN main.region_provinces rp USING (province_id)
            LEFT JOIN main.regions r USING (region_id)
        WHERE
            province_istat_code||mu_istat_code = (SELECT clients.f_get_comune_lonlat(?::float, ?::float));
    };

    # return
    return $self->pg->db->query($sql, $lon, $lat)->hash;
}

sub get_all_networks {
    my ( $self, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_all_networks");

    # query
    my $sql = qq{
        SELECT
            st_network_id,
            st_network_name,
            st_network_desc,
            st_network_logo
        FROM bobo.view_user_networks
        WHERE user_id = ?
        ORDER BY st_network_desc
    };

    # return
    return $self->pg->db->query($sql, $userid)->hashes;
}

# -----------------------------------------------------------------------------
# STATIONS AND PARAMETERS
# -----------------------------------------------------------------------------
sub get_stations {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_stations");

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
            LEFT JOIN bobo.view_user_stations us USING(station_id)
        WHERE
            us.user_id = ?
            AND station_network_type_id IS NOT NULL
        ORDER BY
            sm.station_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

# NOT USED YET
sub get_all_stations_by_province {
    my ( $self, $user_id, $prov) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_all_stations_by_province");

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
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
            LEFT JOIN bobo.view_user_stations vus USING (station_id)

        WHERE vus.us_id = ?
        AND sm.station_id >= 1000
        AND smu.province_id::text ~ ?
        ORDER BY
            sm.station_network_type_id, sm.station_active DESC, sm.station_name;
    };

    # $self->app->log->debug($sql);
    # return
    return $self->pg->db->query($sql, $user_id, $prov)->hashes;
}

sub get_stations_by_province {
    my ( $self, $user_id, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_stations_by_province");

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
            AND sm.station_network_type_id IS NOT NULL
        ORDER BY
            sm.station_network_type_id, sm.station_name;
    };

    # $self->app->log->debug($sql);
    # return
    return $self->pg->db->query($sql, $user_id, $prov)->hashes;
}

sub get_stations_by_net {
    my ( $self, $user_id, $network ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_stations_by_net");

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
            LEFT JOIN bobo.view_user_stations us USING(station_id)
        WHERE
            us.user_id = ?
            AND sm.station_network_type_desc = ?
            AND sm.station_active IS TRUE
        ORDER BY
            sm.station_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $network)->hashes;
}

sub get_stations_by_net_province {
    my ( $self, $user_id, $net, $prov) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_stations_by_net_province");

    $net = ($net != -1 ? "^$net\$" : ".*");
    $prov = ($prov != -1 ? "^$prov\$": ".*");

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
            sm.station_metadata_note,
            -- FOR PROVINCE FILTER
            smu.province_id,
            smu.province_name,
            smu.region_id,
            smu.region_name
        FROM
            metadata.view_stations_info sm
            LEFT JOIN bobo.view_user_stations us USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
            AND ( station_typology_desc NOT LIKE 'Limiti' OR station_typology_id IS NULL ) -- get ALL stations except limits
            AND smu.province_id::text ~ ?
            AND sm.station_network_type_id::text ~ ?
            AND sm.station_active IS TRUE
        ORDER BY
            sm.station_network_type_id, sm.station_name;
    };

    # $self->app->log->debug($sql);
    # return
    return $self->pg->db->query($sql, $user_id, $prov, $net)->hashes;
}

sub get_stations_by_nets {
    my ( $self, $user_id, $prov, $nets ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_stations_by_nets");

    $prov = ($prov != -1 ? "^$prov\$": ".*");

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
            -- not used
            -- AND station_id >= 100
            AND smu.province_id::text ~ ?
    };

    if (scalar(@{$nets}) > 0) {
        my $nets_string = join ',' , @{$nets};
        $sql .= qq{
            AND sm.station_network_type_id IN ( $nets_string )
        };
    }

    $sql .= qq{
            AND sm.station_active IS TRUE
        ORDER BY
            sm.station_network_type_id, sm.station_name;
    };

    # $self->app->log->debug($sql);
    # return
    return $self->pg->db->query($sql, $user_id, $prov)->hashes;
}

sub get_map_stations {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_map_stations");

    # query
    # | <a href="javascript:void(0)" class="show_rt" data-id="'|| sm.station_id ||'">real time</a>
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
            sm.station_network_type_name    AS marker_layer,
            t.main_station_id               AS marker_id,
            sm.station_name                 AS marker_name,
            sm.station_lat_wgs84            AS marker_lat,
            sm.station_lon_wgs84            AS marker_lon,
            ss.ss_suspended                 AS marker_suspended,
            CASE
                WHEN ss_suspended IS TRUE THEN
                    '<div>
                        <h4>'|| sm.station_name ||'</h4>
                        <strong class="text-danger">SOSPESA</strong><br>
                        <strong>Comune : </strong>'|| COALESCE(m.mu_name, '-') ||'<br>
                        <strong>Località : </strong>'|| COALESCE(sm.station_locality, '-') ||'<br>
                        <strong>Quota : </strong>'|| COALESCE(sm.station_altitude::text, '-') ||'<br>
                        <strong>Rete : </strong>'|| sm.station_network_type_desc||'
                        <p style="margin: 0;">
                            <strong>Links : </strong><a href="javascript:void(0)" class="show_ana" data-id="'|| t.main_station_id ||'">anagrafica</a> | <a href="javascript:void(0)" class="show_syn" data-id="'|| t.main_station_id ||'">sinottico</a>
                        </p>
                    </div>'
                ELSE
                    '<div>
                        <h4>'|| sm.station_name ||'</h4>
                        <strong>Comune : </strong>'|| COALESCE(m.mu_name, '-') ||'<br>
                        <strong>Località : </strong>'|| COALESCE(sm.station_locality, '-') ||'<br>
                        <strong>Quota : </strong>'|| COALESCE(sm.station_altitude::text, '-') ||'<br>
                        <strong>Rete : </strong>'|| sm.station_network_type_desc||'
                        <p style="margin: 0;">
                            <strong>Links : </strong><a href="javascript:void(0)" class="show_ana" data-id="'|| t.main_station_id ||'">anagrafica</a> | <a href="javascript:void(0)" class="show_syn" data-id="'|| t.main_station_id ||'">sinottico</a>'||
                            (
                                CASE
                                    WHEN ss_real_time IS TRUE THEN ' | <a href="javascript:void(0)" class="show_rt" data-id="'|| t.main_station_id ||'">real time</a>'
                                    ELSE ''
                                END
                            )
                        ||'</p>
                    </div>'
            END AS marker_desc,
            metadata.f_get_icon_by_station_id( t.station_id ) AS marker_icon
        FROM
            t
            LEFT JOIN metadata.view_stations_info sm USING (station_id)
            LEFT JOIN metadata.stations_status ss ON (ss.station_id = t.main_station_id)
            LEFT JOIN main.municipalities m USING (mu_id)
            LEFT JOIN bobo.view_user_stations us ON (us.station_id = t.main_station_id)
        WHERE
            us.user_id = ?
            AND sm.station_active IS TRUE
            AND sm.station_network_type_id IS NOT NULL
            AND sm.station_lat_wgs84 IS NOT NULL
            AND sm.station_lon_wgs84 IS NOT NULL
        ORDER BY
            sm.station_network_type_desc, sm.station_id;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_station_by_id {
    my ( $self, $station_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_station_by_id");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                s.station_id AS main_station_id,
                COALESCE(  ss.station_override_id, s.station_id ) AS station_id,
                s.station_schema || '.' || COALESCE(s.station_prefix, '') || s.station_table AS main_station_fulltable,
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
            t.main_station_id AS station_id,
            sm.station_name,
            sm.station_schema,
            sm.station_table,
            sm.station_prefix,
            sm.station_fulltable,
            t.main_station_fulltable,
            CASE
                WHEN sm.station_active IS TRUE THEN 'Si'
                ELSE 'No'
            END AS station_active,
            sm.station_active                           AS station_active_bool,
            sm.station_base_path,
            sm.station_base_path || '/' || t.main_station_id AS station_media_path,
            COALESCE (sm.station_external_id, '--')     AS station_external_id,
            COALESCE (sm.station_note, '--')            AS station_note,
            COALESCE (sm.station_shortname, '--')       AS station_shortname,
            COALESCE (sm.station_longname, '--')        AS station_longname,
            COALESCE (to_char(sm.station_startup_date, 'DD-MM-YYYY HH24:MI'), '--') AS station_startup_date,
            COALESCE (to_char(sm.station_dismiss_date, 'DD-MM-YYYY HH24:MI'), '--') AS station_dismiss_date,
            COALESCE (sm.station_locality, '--')        AS station_locality,
            COALESCE (sm.station_zone, '--')            AS station_zone,
            COALESCE (sm.station_basin, '--')           AS station_basin,
            COALESCE (sm.station_community, '--')       AS station_community,
            COALESCE ((sm.station_north_utm::integer)::text, '--') AS station_north_utm,
            COALESCE ((sm.station_east_utm::integer)::text, '--')  AS station_east_utm,
            COALESCE (sm.station_altitude::text, '--')  AS station_altitude,
            COALESCE (sm.station_lat_wgs84::text, '--') AS station_lat_wgs84,
            COALESCE (sm.station_lon_wgs84::text, '--') AS station_lon_wgs84,
            COALESCE (sm.station_national_code, '--')   AS station_national_code,
            COALESCE (sm.station_export_id, '--')       AS station_export_id,
            sm.station_network_type_id,
            sm.station_network_type_desc,
            sm.station_network_type_logo,
            sm.station_roaming_type_id,
            sm.station_roaming_type_desc,
            sm.station_typology_id,
            sm.station_typology_desc,
            sm.station_measure_type_id,
            COALESCE (sm.station_measure_type_desc, '--') AS station_measure_type_desc,
            sm.station_cadence_type_id,
            COALESCE (sm.station_cadence_type_desc, '--') AS station_cadence_type_desc,
            COALESCE ( sm.station_metadata_note, '--')  AS station_metadata_note,
            smu.mu_id,
            COALESCE(smu.mu_name, '--')                 AS mu_name,
            smu.mu_istat_code,
            smu.mu_catasto_code,
            smu.mu_cap,
            smu.mu_note,
            smu.province_id,
            COALESCE(smu.province_name, '--')           AS province_name,
            smu.province_istat_code,
            smu.province_code,
            smu.province_note,
            smu.region_id,
            COALESCE(smu.region_name, '--')             AS region_name,
            smu.region_istat_code,
            smu.region_note,
	        ss.ss_custom_export_publish					AS station_export_active,
            ss.ss_suspended         					AS station_suspended,
            ss.ss_dataview_publish                      AS station_published,
            ss.ss_real_time                             AS station_real_time
        FROM
            t
            LEFT JOIN metadata.view_stations_info sm USING (station_id)
            LEFT JOIN main.view_municipalities smu USING (mu_id)
            LEFT JOIN metadata.view_stations_parameters sp ON (sp.station_id = t.main_station_id)
            LEFT JOIN metadata.stations_status ss ON (ss.station_id = t.main_station_id)
        WHERE
            t.main_station_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $station_id)->hash;
}

sub get_parameter_by_id {
    my ( $self, $param_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_parameter_by_id");

    # query
    my $sql = qq{
        SELECT
            p.param_id          AS parameter_id,
            p.param_name        AS parameter_name,
            p.param_unit        AS parameter_unit,
            p.param_conv        AS parameter_conv,
            p.param_unit_conv   AS parameter_unit_conv,
            p.param_offset      AS parameter_offset,
            p.param_decimals    AS parameter_decimals,
            p.param_active      AS parameter_active,
            CASE
                WHEN param_active IS TRUE THEN 'Si'
                ELSE 'No'
            END                                     AS parameter_active_formatted,
            COALESCE(p.param_note, '' )             AS parameter_note,
            COALESCE(p.param_ext_id, '' )           AS parameter_external_id,
            COALESCE(pi.pm_info_shortname, '--' )   AS parameter_shortname,
            COALESCE(pi.pm_info_extra_shortname, '--' )  AS parameter_extra_shortname,
            pi.pm_info_type_fk                      AS parameter_type_id,
            COALESCE(pt.pm_type_desc, '--' )        AS parameter_type_desc,
            COALESCE(pi.pm_info_obj, '{}'  )        AS parameter_object,
            COALESCE(pi.pm_info_note, '--' )        AS parameter_info_note,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(c)))
                FROM (
                    SELECT
                        pc.pc_id,
                        pc.pc_conv,
                        CASE
                            WHEN ISFINITE(pc.pc_from_fulldate) THEN TO_CHAR(pc.pc_from_fulldate, 'DD/MM/YYYY')
                            ELSE NULL
                        END AS pc_from_fulldate,
                        CASE
                            WHEN ISFINITE(pc.pc_to_fulldate) THEN TO_CHAR(pc.pc_to_fulldate, 'DD/MM/YYYY')
                            ELSE NULL
                        END AS pc_to_fulldate,
                        CASE
                            WHEN tsrange(pc.pc_from_fulldate, pc.pc_to_fulldate, '[]') @> CURRENT_DATE::timestamp THEN TRUE
                            ELSE FALSE
                        END AS pc_current,
                        pc.pc_note,
                        pc.pc_insert_ts

                    FROM
                        metadata.parameters_conversions pc
                    WHERE
                        pc.param_id = p.param_id
                    ORDER BY
                        pc.pc_from_fulldate DESC
                ) c
            ) AS parameter_convs
        FROM
            metadata.parameters p
            LEFT JOIN metadata.parameters_info pi USING (param_id)
            LEFT JOIN metadata.parameters_type pt ON pi.pm_info_type_fk = pt.pm_type_id
        WHERE
            param_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $param_id)->hash;
}

sub get_all_parameters_by_station {
    my ( $self, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_all_parameters_by_station");

    # query
    my $sql = qq{
        SELECT
            sp.stpr_id,
            sp.stpr_table_id,
            sp.param_id,
            p.param_name || COALESCE(' - '||sp.stpr_note, '')         AS parameter_name,
            p.param_unit AS parameter_unit,
            sp.stpr_active AS station_param_active

        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.parameters_info pm USING (param_id)
        WHERE
            sp.stpr_active IS TRUE
            AND sp.station_id = ?

            --AND pm_info_type_fk NOT IN (12,13,14,18)
            AND pm_info_type_fk IN (1,2,3,11,15,16,17)

        ORDER BY
            p.param_name;
    };

    # return
    return $self->pg->db->query($sql, $stid)->hashes;
}

sub get_all_metadata_by_stprid {
    my ( $self, $user_id, $stprid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_all_metadata_by_stprid");

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT
                station_id,
                total_user_grants AS bit
            FROM bobo.view_user_stations
            WHERE user_id = ? AND station_id >= 1000
            UNION
            SELECT
                station_id,
                (b'010') AS bit
            FROM bobo.view_user_stations
            WHERE user_id = ? AND station_id >= 1000
        )
        SELECT
            stpr_id,
            stpr_table_id,
            station_id,
            station_name,
            station_fulltable,
            param_id AS parameter_id,
            parameter_name,
            parameter_unit,
            parameter_conv,
            parameter_unit_conv,
            parameter_decimals,
            parameter_active,
            COALESCE(parameter_object->'general'->>'treatment', 'avg') AS parameter_treatment,
            (SELECT bit_and(temp.bit)::integer FROM temp WHERE temp.station_id = vsp.station_id)::boolean AS station_update
        FROM
            metadata.view_stations_parameters vsp
        WHERE stpr_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $stprid)->hash;
}

# -----------------------------------------------------------------------------
# INSTRUMENTS AND CYLINDERS
# -----------------------------------------------------------------------------
sub get_equipments_categories {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_equipments_categories");

    # query
    my $sql = qq{
        SELECT
            category_id,
            category_name
        FROM equipments.categories
        WHERE category_id > 0
        AND category_visible IS TRUE
        ORDER BY category_name;
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_cylinders_categories {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_cylinders_categories");

    # query
    my $sql = qq{
        SELECT
            category_id,
            category_name
        FROM equipments.categories
        WHERE category_id IN (1,2,3,5,7,16,18)
        ORDER BY category_name;
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_instruments_by_station_date {
    my ( $self, $stid, $dt ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_instruments_by_station_date");

    # query
    my $sql = qq{
        SELECT
            stin_id,
            instr_id,
            instrument_type_fullname||' - '||category_name AS instrument_type_fullname,
            COALESCE(instrument_arpa_id, '') AS instrument_arpa_id,
            COALESCE(instrument_name, '') AS instrument_name,
            COALESCE(instrument_serial_num, '') AS instrument_serial_num,
            category_id,
            category_name
        FROM metadata.view_stations_instruments
        WHERE station_id = ?
        -- AND ?::timestamp BETWEEN station_instr_startup_date AND station_instr_dismiss_date
        AND tsrange(station_instr_startup_date, station_instr_dismiss_date, '[]') @> ?::timestamp
        ORDER BY instrument_name;
    };

    # return
    return $self->pg->db->query($sql, $stid, $dt)->hashes;
}

sub get_cylinders_by_station_date {
    my ( $self, $stid, $dt ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_cylinders_by_station_date");

    # query
    my $sql = qq{
        SELECT
            cy_id,
            cylinder_arpa_id     ,
            cylinder_name        ,
            cylinder_mixture     ,
            cylinder_mixture
            || COALESCE(' - '||cylinder_name, '')
            || COALESCE(' ['||cylinder_arpa_id||']', '') AS cylinder_fullname,
            cylinder_is_zero     ,
            cylinder_expiry_date ,
            TO_CHAR( cylinder_expiry_date, 'DD/MM/YYYY' ) AS cylinder_expiry_date_format,
            cylinder_ch_values   ,
            cylinder_all_stations,
            cylinder_active      ,
            category_id
        FROM
            metadata.view_stations_cylinders
        WHERE station_id = ? -- station_id
        AND tsrange(station_cy_startup_date, station_cy_dismiss_date, '[]') @> ?::timestamp
        AND cylinder_active IS TRUE
        ORDER BY 5;
    };

    # return
    return $self->pg->db->query($sql, $stid, $dt)->hashes;
}

sub get_miscellanies_by_station_date {
    my ( $self, $stid, $dt ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_miscellanies_by_station_date");

    # query
    my $sql = qq{
        SELECT
            mi_id,
            miscellany_arpa_id     ,
            miscellany_name        ,
            miscellany_name
            || COALESCE(' ['||miscellany_arpa_id||']', '') AS miscellany_fullname,
            miscellany_dismiss_date ,
            TO_CHAR( miscellany_dismiss_date, 'DD/MM/YYYY' ) AS miscellany_dismiss_date_format,
            miscellany_active
        FROM
            metadata.view_stations_miscellanies
        WHERE station_id = ? -- station_id
        AND tsrange(station_mi_startup_date, station_mi_dismiss_date, '[]') @> ?::timestamp
        AND miscellany_active IS TRUE
        ORDER BY 5;
    };

    # return
    return $self->pg->db->query($sql, $stid, $dt)->hashes;
}

# -----------------------------------------------------------------------------
# VALIDITY CODES
# -----------------------------------------------------------------------------
sub get_periphery {
    my ( $self) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_periphery");

    # query
    my $sql = qq{
        SELECT
            pvc_id, pvc_code_id, pvc_code_desc, pvc_code_default, pvc_code_valid
        FROM
            metadata.periphery_validation_codes;
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_autoval {
    my ( $self) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_autoval");

    # query
    my $sql = qq{
        SELECT
            avc_id, avc_code_id, avc_code_desc, avc_code_default, avc_code_valid
	    FROM
            metadata.auto_validation_codes;
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_validation_codes {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_validation_codes");

    # query
    my $sql = qq{
        SELECT
            uvc_id,
            uvc_code_id,
            uvc_code_desc,
            '[ '||uvc_code_id||' ] '||uvc_code_desc AS uvc_code_formatted,
            uvc_code_default,
            uvc_code_valid
        FROM
            metadata.user_validation_codes
        ORDER BY uvc_code_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_final_validation_codes {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_final_validation_codes");

    # query
    my $sql = qq{
        SELECT
            t1.fvc_id,
            t2.value AS fvc_code_id,
            t2.label AS fvc_code_desc,
            '[ '||t2.value||' ] '||t2.label AS fvc_code_formatted,
            t1.fvc_code_default,
            t1.fvc_code_valid
        FROM
            jsonb_to_recordset(
                bobo.f_get_user_portal_options( ?, '/dat_validazione' )-> 'codes'
            ) AS t2(value integer, label text)
            LEFT JOIN metadata.final_validation_codes t1 ON (t1.fvc_code_id = t2.value)

        ORDER BY
            t2.value;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_userval {
    my ( $self) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_userval");

    # query
    my $sql = qq{
        SELECT
            uvc_id, uvc_code_id, uvc_code_desc, uvc_code_default, uvc_code_valid
	    FROM
            metadata.user_validation_codes;
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_finalval {
    my ( $self) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_finalval");

    # query
    my $sql = qq{
        SELECT
            fvc_id, fvc_code_id, fvc_code_desc, fvc_code_default, fvc_code_valid
        FROM
            metadata.final_validation_codes
        ORDER BY
            fvc_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

1;

=head1 get_user_byid

Funzione che recupera, dato l'id, un determinato utente.

Argomenti:  * id dell'utente ($user_id);

Return:     Risultato della query;

=cut

=head1 get_portal_groups_by_user

Funzione che recupera, dato l'id dell'utente, i gruppi associati al/ai portale/i di appartenenza.

Argomenti:  * id dell'utente ($user_id);

Return:     Risultato della query;

=cut

=head1 get_portal_users_by_user

Funzione che recupera, dato l'id dell'utente, gli altri associati al/ai portale/i di appartenenza.

Argomenti:  * id dell'utente ($user_id);

Return:     Risultato della query;

=cut

=head1 get_companies_by_portal

Funzione che recupera, dato l'id dell'utente, le aziende di cui esso fa parte,
in funzione del portale di appartenenza.

Argomenti:  * id dell'utente ($user_id);

Return:     Risultato della query;

=cut

=head1 get_comp_detail_byid

Funzione che recupera, dato l'id, le informazioni di una
determinata azienda.

Argomenti:  * id dell'azienda ('compid');

Return:     Risultato della query;

=cut

=head1 get_user_station_grants

Funzione che recupera, dato l'id dell'utente e quello di una stazione, i permessi impostati.

Argomenti:  * id dell'utente ('user_id');

           * id della stazione ('station_id');

Return:     Risultato della query;

=cut

=head1 check_permission_station

Funzione che verifica i permessi di un determinato utente su di
una determinata stazione.

Argomenti:  * id della stazione ('stid');

           * id dell'utente ('userid');

Return:     Risultato della query (valore booleano).

=cut

=head1 get_validation_codes

Funzione che recupera i codici di validazione dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_final_validation_codes

Funzione che recupera i codici di validazione finale dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_aggregations

Funzione che recupera le varie aggregazioni dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_min_aggregation

Funzione che recupera dal database la minima aggregazione temporale dei dati.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_treatments

Funzione che recupera i vari trattamenti di dati dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_all_regions

Funzione che recupera tutte le regioni dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_province_by_id

Funzione che recupera, dato l'id, le informazioni di una
determinata provincia.

Argomenti:  * id dell'azienda ('prov');

Return:     Risultato della query;

=cut

=head1 get_provinces

Funzione che recupera le province delle stazioni di cui un determinato utente ha il permesso
di visualizzazione.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_all_provinces

Funzione che recupera le tutte le province che un determinato utente puo' visualizzare dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_italy_provinces

Funzione che recupera le tutte le province d'Italia dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_all_provinces_by_region

Funzione che recupera le province di una determinata regione dal database.

Argomenti:  * id della regione ('region_id');

Return:     Risultato della query;

=cut

=head1 get_all_municipalities_by_province

Funzione che recupera i comuni di una determinata provincia dal database.

Argomenti:  * id della provincia ('province_id');

Return:     Risultato della query;

=cut

=head1 get_municipality_by_coordinates

Funzione che recupera le informazioni di un comune attraverso delle determinate
coordinate geografiche dal database.

Argomenti:  * longitudine ('lon');

           * latitudine ('lat');

Return:     Risultato della query;

=cut

=head1 get_all_networks

Funzione che recupera le tutte le reti che un determinato utente puo' visualizzare dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_all_stations_by_province

Funzione che recupera, dati gli id dell'utente e di una provincia (non obbligatorio), le informazioni di determinate stazioni dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia, se presente ('prov');

Return:     Risultato della query;

=cut

=head1 get_stations

Funzione che recupera le stazioni dal database.

Argomenti:  * id dell'utente ($user_id);

Return:     Risultato della query;

=cut

=head1 get_stations_by_province

Funzione che recupera, dato l'id di una provincia (non obbligatorio), le informazioni di determinate stazioni dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia, se presente ('prov');

Return:     Risultato della query;

=cut

=head1 get_stations_by_net

Funzione che recupera, dato l'id di una rete (non obbligatorio), le informazioni di determinate stazioni dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della rete, se presente ('network');

Return:     Risultato della query;

=cut

=head1 get_stations_by_net_province

Funzione che recupera, dati gli id di una provincia e di una rete (non obbligatori), le informazioni di determinate stazioni dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia, se presente ('prov');

           * id della rete, se presente ('net');

Return:     Risultato della query;

=cut

=head1 get_stations_by_nets

Funzione che recupera, dati uno o piu' id di alcune reti, le informazioni di determinate stazioni dal database.

Argomenti:  * id della provincia, se presente ('prov');

           * id della/e rete/i ('nets');

Return:     Risultato della query;

=cut

=head1 get_map_stations

Funzione che recupera dal database le informazioni necessarie al
posizionamento del marker delle stazioni su una mappa.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_station_by_id

Funzione che recupera, dato l'id, le informazioni di una
determinata stazione.

Argomenti:  * id della stazione ('station_id');

Return:     Risultato della query;

=cut

=head1 get_parameter_by_id

Funzione che recupera, dato l'id, le informazioni di un
determinato parametro.

Argomenti:  * id del parametro ('param_id');

Return:     Risultato della query;

=cut

=head1 get_all_parameters_by_station

Funzione che recupera, dato l'id una stazione, le informazioni dei
parametri associati ad essa.

Argomenti:  * id della stazione ('stid');

Return:     Risultato della query;

=cut

=head1 get_all_metadata_by_stprid

Funzione che recupera, dati gli id dell'utente e di un'associazione stazione-parametro,
i relativi metadati.

Argomenti:  * id dell'utente ('user_id');

           * id dell'associazione stazione-parametro ('stprid')

Return:     Risultato della query;

=cut

=head1 get_equipments_categories

Funzione che recupera le categorie di strumento dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_cylinders_categories

Funzione che recupera le categorie di bombole dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_instruments_by_station_date

Funzione che recupera, dati l'id e una data, gli strumenti associati ad una
determinata stazione dal database.

Argomenti:  * id della stazione ('stid');

           * data e ora ('dt');

Return:     Risultato della query;

=cut

=head1 get_cylinders_by_station_date

Funzione che recupera, dati l'id e una data, le bombole associate ad una
determinata stazione dal database.

Argomenti:  * id della stazione ('stid');

           * data e ora ('dt');

Return:     Risultato della query;

=cut

=head1 get_miscellanies_by_station_date

Funzione che recupera, dati l'id e una data, le dotazioni associate ad una
determinata stazione dal database.

Argomenti:  * id della stazione ('stid');

           * data e ora ('dt');

Return:     Risultato della query;

=cut

=head1 get_periphery

Funzione che recupera i codici di periferia dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_autoval

Funzione che recupera i codici di autovalidazione dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_userval

Funzione che recupera i codici di validazione utente dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_finalval

Funzione che recupera i codici di validazione finale dal database.

Argomenti:  /

Return:     Risultato della query.

=cut