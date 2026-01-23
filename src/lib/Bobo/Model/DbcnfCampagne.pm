package Bobo::Model::DbcnfCampagne;
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

# Setters/Getters webcam
# -----------------------------------------------------------------------------

# get roaming stations
sub get_roaming_stations_by_nets {
    my ( $self, $userid, $nets ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfCampagne sub get_roaming_stations_by_nets");

    # query
    my $sql = qq{
        WITH t AS(
            SELECT
                station_id,
                stsi_startup_date,
                stsi_dismiss_date
            FROM (
                -- prendo tutti gli stanziamenti in corso o futuri
                -- li ordino da quelli più vecchi a quelli più nel futuro
                SELECT
                    station_id,
                    stsi_startup_date,
                    stsi_dismiss_date,
                    row_number() OVER (PARTITION BY station_id ORDER BY stsi_startup_date ASC) AS rownum
                FROM metadata.stations_sites
                WHERE
                    tsrange(stsi_startup_date, stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    OR stsi_startup_date > CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'
            ) AS x
            -- seleziono uno stanziamento in atto o il primo nel futuro
            WHERE x.rownum = 1
        )
        SELECT
            sm.station_id,
            COALESCE(t.stsi_dismiss_date::text, '2000-01-01 00:00')::timestamp AS last_dismiss_date,
            CASE
                --WHEN t.stsi_dismiss_date > CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome' THEN 'disabled'
                WHEN t.stsi_startup_date ISNULL THEN ''
                WHEN tsrange(t.stsi_startup_date, t.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome') THEN 'disabled'
                ELSE ''
            END AS station_class,
            sm.station_name,
            sm.station_active,
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
            LEFT JOIN t USING (station_id)
        WHERE
            us.user_id = ?
            AND sm.station_roaming_type_id = 2 -- roaming
    };

    # prepare binds (userid + optional filters)
    my @binds = ($userid);

    if (scalar(@{$nets}) > 1) {
        my $nets_array = '{' . join(',', @{$nets}) . '}';
        $self->app->log->debug($nets_array);

        # use placeholder and PostgreSQL ANY with array literal
        $sql .= qq{
            AND sm.station_network_type_id = ANY((?)::int[])
        };
        push @binds, $nets_array;
    }
    else {
        if ($nets->[0] != -1) {
            $sql .= qq{
                AND sm.station_network_type_id = ?
            };
            push @binds, $nets->[0];
        }
    }

    $sql .= qq{
            AND sm.station_active IS TRUE
        ORDER BY
            sm.station_network_type_desc, sm.station_name;
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes;
}

sub get_campaigns {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfCampagne sub get_campaigns");

    # query
    my $sql = qq{
        SELECT
            camp_id,
            camp_name,
            network_types,
            ARRAY(
                SELECT
                    st_network_name
                FROM  metadata.stations_network_type
                WHERE st_network_id = ANY(network_types)
            ) AS network_names,
            camp_active,
            CASE
                WHEN camp_active IS FALSE THEN 'hidden'
                ELSE ''
            END AS camp_class,
            EXISTS(
                SELECT 1
                FROM
                    metadata.stations_sites ss
                WHERE ss.camp_id = c.camp_id
            ) AS camp_linked
        FROM metadata.campaigns c
        WHERE network_types && ARRAY(
            SELECT st_network_id
            FROM bobo.view_user_networks
            WHERE user_id = ?
        )
        ORDER BY camp_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_sites {
    my ( $self, $user_id, $net, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfCampagne sub get_sites");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                site_id,
                site_name,
                network_types,
                ARRAY(
                    SELECT
                        st_network_name
                    FROM  metadata.stations_network_type
                    WHERE st_network_id = ANY(network_types)
                ) AS network_names,
                mu_id,
                province_code,
                site_locality,
                null::integer AS stsi_id,
                ARRAY(
                    SELECT
                        station_name
                    FROM
                        metadata.stations_sites ss
                        LEFT JOIN metadata.stations st USING (station_id)
                    WHERE
                        s.site_id = ss.site_id
                        AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                ) AS lab,
                null::text AS lab_start,
                null::text AS lab_end,
                null::text AS lab_campaign,
                site_note,
                EXISTS(
                    SELECT 1
                    FROM
                        metadata.stations_sites ss
                    WHERE ss.site_id = s.site_id
                ) AS site_linked

            FROM metadata.sites s
            LEFT JOIN main.province_municipalities pm USING (mu_id)
            LEFT JOIN main.provinces p USING (province_id)
            WHERE network_types && ARRAY(
                    SELECT st_network_id
                    FROM bobo.view_user_networks
                    WHERE user_id = ?
                )
    };

    my @binds = ($user_id);

    if ($net != -1) {
        # bind net instead of interpolating
        $sql .= qq{
            AND ? = ANY(network_types)
        };
        push @binds, $net;
    }

    if ($prov != -1) {
        $sql .= qq{
            AND province_id = ?
        };
        push @binds, $prov;
    }

    $sql .= qq{
        )
        SELECT *
        FROM t
        ORDER BY site_name;
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes;
}

sub get_sites_by_date_station {
    my ( $self, $user_id, $from, $to, $net, $prov, $stid, $camp ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfCampagne sub get_sites_by_date_station");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                site_id,
                site_name,
                s.network_types,
                ARRAY(
                    SELECT
                        st_network_name
                    FROM  metadata.stations_network_type
                    WHERE st_network_id = ANY(s.network_types)
                ) AS network_names,
                mu_id,
                province_code,
                site_locality,
                stsi_id,
                ARRAY[station_name] AS lab,
                stsi_startup_date AS lab_start,
                CASE
                    WHEN stsi_dismiss_date = 'infinity' THEN 'infinito'
                    WHEN stsi_dismiss_date IS NULL THEN '--'
                    ELSE TO_CHAR(stsi_dismiss_date, 'DD/MM/YYYY HH24:MI')
                END AS lab_end,
                c.camp_name AS lab_campaign,
                site_note,
                TRUE as site_linked

            FROM metadata.stations_sites ss
            LEFT JOIN metadata.campaigns c USING (camp_id)
            LEFT JOIN metadata.stations st USING (station_id)
            LEFT JOIN metadata.sites s USING (site_id)
            LEFT JOIN main.province_municipalities pm USING (mu_id)
            LEFT JOIN main.provinces p USING (province_id)
            WHERE station_id IN (
                SELECT station_id
                FROM bobo.view_user_stations
                WHERE user_id = ?
            )
            AND tsrange(?::timestamp, ?::timestamp, '[]') && tsrange(stsi_startup_date, stsi_dismiss_date, '[]')
    };

    my @binds = ($user_id, $from, $to);

    if ($net != -1) {
        $sql .= qq{ AND ? = ANY(s.network_types) };
        push @binds, $net;
    }

    if ($prov != -1) {
        $sql .= qq{
            AND province_id = ?
        };
        push @binds, $prov;
    }

    if ($stid != -1) {
        $sql .= qq{
            AND station_id = ?
        };
        push @binds, $stid;
    }

    if ($camp != -1) {
        $sql .= qq{
            AND camp_id = ?
        };
        push @binds, $camp;
    }

    $sql .= qq{
        )
        SELECT *
        FROM t
        ORDER BY lab_start DESC;
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes();
}

sub get_site_by_id {
    my ( $self, $siid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfCampagne sub get_site_by_id");

    # query
    my $sql = qq{
        SELECT
            *,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(j)))
                FROM (
                    SELECT
                        att_id          AS file_id,
                        file_original   AS file_name,
                        '/uploads/impostazioni/campagne/'||LPAD(site_id::text, 9, '0')||'/'||file_archive AS file_path,
                        file_image
                    FROM
                        metadata.site_attachments sa
                    WHERE sa.site_id = vs.site_id
                ) j
            ) AS site_attachments,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(l)))
                FROM (
                    SELECT
                        ss.stsi_id                      AS id,
                        ss.station_id                   AS location_id,
                        s.station_name                  AS location_name,
                        ss.stsi_startup_date            AS location_start,
                        CASE
                            WHEN ss.stsi_dismiss_date = 'infinity' THEN 'infinito'
                            ELSE TO_CHAR(ss.stsi_dismiss_date, 'DD/MM/YYYY HH24:MI')
                        END                         AS location_end,
                        ss.stsi_dismiss_date,
                        COALESCE(ss.stsi_note, '--')            AS location_note,
                        ss.camp_id,
                        c.camp_name,
                        COALESCE(s2.station_ext_id, '--')       AS location_ext_id
                    FROM
                        metadata.stations_sites ss
                        LEFT JOIN metadata.stations s USING (station_id)
                        LEFT JOIN metadata.campaigns c USING (camp_id)
                        LEFT JOIN metadata.stations s2 ON (ss.station_override_id = s2.station_id)
                    WHERE ss.site_id = vs.site_id
                    ORDER BY stsi_startup_date DESC
                ) l
            ) AS site_locations
        FROM metadata.view_sites vs
        WHERE site_id = ?
    };

    # return
    return $self->pg->db->query($sql, $siid)->hash;
}

sub get_location_by_id {
    my ( $self, $stsiid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfCampagne sub get_location_by_id");

    # query
    my $sql = qq{
        SELECT
            ss.stsi_id,
            ss.station_id,
            ss.station_override_id,
            ss.site_id,
            ss.stsi_startup_date,
            ss.stsi_dismiss_date,
            ss.stsi_note,
            ss.camp_id,
            s.station_ext_id
        FROM
            metadata.stations_sites ss
            LEFT JOIN metadata.stations s ON (ss.station_override_id = s.station_id)
        WHERE stsi_id = ?
    };

    # return
    return $self->pg->db->query($sql, $stsiid)->hash();
}

sub get_mm_history{
    my ( $self, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfCampagne sub get_mm_history");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                row_number() OVER (PARTITION BY station_id ORDER BY stsi_startup_date ASC) AS rownum,
                stsi_id,
                station_id,
                site_id,
                stsi_startup_date,
                CASE
                    WHEN stsi_dismiss_date = 'infinity' THEN CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'
                    ELSE stsi_dismiss_date
                END AS stin_dismiss_date,
                stsi_note
            FROM
                metadata.stations_sites
            WHERE
                station_id = ?
            ORDER BY 
                stsi_startup_date ASC
        )
        SELECT 
            s.station_name,
            (
            SELECT 
                to_json(ARRAY_AGG(json_strip_nulls(row_to_json(l))))
                FROM (
                    SELECT 
                        t.rownum::text AS id,
                        vs.site_name||' - '||vs.site_locality||' ('|| vs.province_name ||')'  AS name,
                        t.stsi_startup_date AS start,
                        t.stin_dismiss_date AS end,
                        vs.site_wgs84_lat,
                        vs.site_wgs84_lon,
                        COALESCE(t.stsi_note, '--') AS note,
                        CASE
                            WHEN t.rownum = 1 THEN NULL
                            ELSE (t.rownum-1)::text 
                        END 				AS dependency
                    FROM
                        t
                        LEFT JOIN metadata.view_sites vs USING (site_id)
                    ORDER BY
                        rownum
                ) l 
            ) AS mm_locations	
        FROM metadata.stations s
        WHERE station_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $stid, $stid)->hash();
}

sub insert_new_campaign {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne insert_new_campaign");

    my $tx;
    my $id;

    eval {
        $tx = $self->pg->db->begin;

        my @networks;
        if (ref($params->{'camp-networks'}) eq 'ARRAY') {
            @networks = @{$params->{'camp-networks'}};
        }
        else {
            push @networks, $params->{'camp-networks'};
        }

        $id = $self->pg->db->insert('metadata.campaigns', {
            camp_name     => $params->{'camp-name'}, # NOT NULL
            network_types => \@networks # NOT NULL
        }, {returning => 'camp_id'})->hash->{'camp_id'};

    };

    # error check
    if ($@) {
        $self->app->log->warn("Error: ".$@);
       # rollback
       return undef;
    }
    else {
        $tx->commit;
        return $id;
    }
}

sub insert_new_site {
    my( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne insert_new_site");

    my $tx;
    my $id;

    eval {
        $tx = $self->pg->db->begin;

        $self->app->log->debug("STEP 1 insert sito");

        # ARRAY networks
        my @networks;
        if (ref($params->{'site-networks'}) eq 'ARRAY') {
            @networks = @{$params->{'site-networks'}};
        }
        else {
            push @networks, $params->{'site-networks'};
        }

        $id = $self->pg->db->insert('metadata.sites', {
            site_name      => $params->{'site-name'}, # NOT NULL
            mu_id          => $params->{'site-district'}, # NOT NULL
            site_locality  => $params->{'site-locality'}, # NOT NULL
            site_altitude  => $self->app->helperEscapeParam($params->{'site-altitude'}),
            site_wgs84_lat => $params->{'site-latitude'}, # NOT NULL
            site_wgs84_lon => $params->{'site-longitude'}, # NOT NULL
            site_note      => $self->app->helperEscapeParam($params->{'site-note'}),
            network_types  => \@networks # NOT NULL
        }, {returning => 'site_id'})->hash->{'site_id'};

        if (defined $params->{'add-location'} && $params->{'add-location'} ne '') {
            my $sql = qq{ SELECT st_info_shortname, st_info_network_type_fk FROM metadata.stations_info WHERE station_id = ? };
            my $res = $self->pg->db->query($sql, $params->{'main-loc-lab'})->hash;

            # insert di una nuova stazione fittizia per la relazione sito-lab
            # essendo nuovo il sito sicuramente non esiste già la stessa stazione fittizia

            # INSERT INTO metadata.stations
            #     (station_id, station_name, station_schema, station_table, station_prefix, station_active, station_note, station_ext_id)
            # VALUES
            #     (DEFAULT, 'TEST - Lab02'         , 'site', 'f_mm_1'          , NULL, true, NULL, NULL ),

            $self->app->log->debug("STEP 2 insert stazione virtuale: ".$res->{'st_info_shortname'}." - ".$params->{'site-name'});
            my $id_override = $self->pg->db->insert('metadata.stations', {
                station_name   => $res->{'st_info_shortname'}.' - '.$params->{'site-name'}, # NOT NULL
                station_schema => 'site', # NOT NULL
                station_table  => 'mm_'.$params->{'main-loc-lab'}.'_'.$id,  # NOT NULL
                station_active => 1,
                # ID esterno diverso dal mezzo mobile originale
                station_ext_id => $self->app->helperEscapeParam($params->{'main-ext-id'})
            }, {returning => 'station_id'})->hash->{'station_id'};

            $self->pg->db->insert('metadata.stations_info', {
                station_id        => $id_override,
                st_info_shortname => $res->{'st_info_shortname'}.' - '.$params->{'site-name'},

                # Da non aggiungere -> Acquisiti da sito tramite view_stations_info
                # st_info_locality  => $params->{'site-locality'},
                # st_info_altitude  => $self->app->helperEscapeParam($params->{'site-altitude'}),
                # st_info_lat_wgs84 => $params->{'site-latitude'},
                # st_info_lon_wgs84 => $params->{'site-longitude'},

                st_info_network_type_fk => $res->{'st_info_network_type_fk'},
                st_info_roaming_type_fk => 4 # sito con stanziamento
            });

            $self->app->log->debug("STEP 3 insert relazione stazione-sito. ID OVERRIDE: ".$id_override);
            $self->pg->db->insert('metadata.stations_sites', {
                station_id          => $params->{'main-loc-lab'}, # NOT NULL
                station_override_id => $id_override, # NOT NULL
                site_id             => $id, # NOT NULL
                stsi_startup_date   => $self->app->helperGetFormattedFulldate($params->{'main-loc-start-date'}), # NOT NULL
                stsi_dismiss_date   => $params->{'main-loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'main-loc-end-date'}) : 'infinity',
                stsi_note           => $self->app->helperEscapeParam($params->{'main-loc-notes'}),

                camp_id             => ($params->{'main-loc-campaign'} == -1 ? undef : $params->{'main-loc-campaign'})
            });
        }
    };

    # error check
    if ($@) {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'metadata_stations_sites_check') != -1) {
            $self->app->log->debug("RETURN -1");
            return -1;
        }
        elsif (index($@->{'message'}, 'metadata_sites_ukey') != -1) {
            $self->app->log->debug("RETURN -2");
            return -2;
        }
        else {
            return undef;
        }
    }
    else {
        $tx->commit;
        return $id;
    }
}

sub insert_new_attachment {
    my( $self, $id, $original_name, $new_name, $is_image ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne insert_new_attachment");
    $self->app->log->debug("File: $original_name to $new_name");

    my $res = $self->pg->db->insert('metadata.site_attachments', {
        site_id       => $id,
        file_original => $original_name,
        file_archive  => $new_name,
        file_image    => $is_image
    });

    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub insert_new_location {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne insert_new_location");

    my $tx;
    my $id;

    eval {
        $tx = $self->pg->db->begin;

        # query
        my $sql = qq{
            SELECT st_info_shortname, st_info_network_type_fk
            FROM metadata.stations_info
            WHERE station_id = ?;
        };

        my $station = $self->pg->db->query($sql, $params->{'loc-lab'})->hash;

        $sql = qq{
            SELECT *
            FROM metadata.sites
            WHERE site_id = ?;
        };

        my $site = $self->pg->db->query($sql, $params->{'loc-site'})->hash;
        # $self->app->helperDumper($site);

        $self->app->log->debug("STEP 1 controllo se esiste già stazione virtuale: ".$station->{'st_info_shortname'}." - ".$site->{'site_name'});

        $sql = qq{
            SELECT station_override_id
            FROM metadata.stations_sites
            WHERE site_id = ?
            AND station_id = ?
            LIMIT 1;
        };

        my $id_override = $self->pg->db->query($sql, $params->{'loc-site'}, $params->{'loc-lab'})->hash;

        if (!defined $id_override) {
            # non esiste un'associazione precedente sito - lab
            # insert di una nuova stazione fittizia per la relazione sito-lab

            # INSERT INTO metadata.stations
            #     (station_id, station_name, station_schema, station_table, station_prefix, station_active, station_note, station_ext_id)
            # VALUES
            #     (DEFAULT, 'TEST - Lab02'         , 'site', 'f_mm_1'          , NULL, true, NULL, NULL ),

            $self->app->log->debug("STEP 2 insert stazione virtuale: ".$station->{'st_info_shortname'}." - ".$site->{'site_name'});
            $id_override = $self->pg->db->insert('metadata.stations', {
                station_name   => $station->{'st_info_shortname'}.' - '.$site->{'site_name'}, # NOT NULL
                station_schema => 'site', # NOT NULL
                station_table  => 'mm_'.$params->{'loc-lab'}.'_'.$params->{'loc-site'},  # NOT NULL
                station_active => 1,
                # ID esterno diverso dal mezzo mobile originale
                station_ext_id => $self->app->helperEscapeParam($params->{'loc-ext-id'})
            }, {returning => 'station_id'})->hash->{'station_id'};

            $self->pg->db->insert('metadata.stations_info', {
                station_id        => $id_override,
                st_info_shortname => $station->{'st_info_shortname'}.' - '.$site->{'site_name'},

                # da non aggiungere -> acquisiti da sito tramite 'view_stations_info'
                # st_info_locality  => $site->{'site_locality'},
                # st_info_altitude  => $site->{'site_altitude'},
                # st_info_lat_wgs84 => $site->{'site_wgs84_lat'},
                # st_info_lon_wgs84 => $site->{'site_wgs84_lon'},

                st_info_network_type_fk => $station->{'st_info_network_type_fk'},
                st_info_roaming_type_fk => 4 # sito con stanziamento
            });
        }
        else {
            $id_override = $id_override->{'station_override_id'};
        }

        $self->app->log->debug("STEP 3 insert relazione stazione-sito. ID OVERRIDE: ".$id_override);

        $id = $self->pg->db->insert('metadata.stations_sites', {
            station_id          => $params->{'loc-lab'}, # NOT NULL
            station_override_id => $id_override, # NOT NULL
            site_id             => $params->{'loc-site'}, # NOT NULL
            stsi_startup_date   => $self->app->helperGetFormattedFulldate($params->{'loc-start-date'}), # NOT NULL
            stsi_dismiss_date   => $params->{'loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'loc-end-date'}) : 'infinity',
            stsi_note           => $self->app->helperEscapeParam($params->{'loc-notes'}),

            camp_id             => ( $params->{'loc-campaign'} == -1 ? undef : $params->{'loc-campaign'} )
        }, {returning => 'stsi_id'})->hash->{'stsi_id'};
    };

    if (defined $id) {
        $tx->commit;
        return 1;
    }
    else {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'metadata_stations_sites_check') != -1) {
            return -1;
        }
        else {
            return undef;
        }
    }
}

sub update_campaign_by_id {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne update_campaign_by_id");

    my @networks;

    if (ref($params->{'camp-networks'}) eq 'ARRAY') {
        @networks = @{$params->{'camp-networks'}};
    }
    else {
        push @networks, $params->{'camp-networks'};
    }

    my $res = $self->pg->db->update('metadata.campaigns', {
        camp_name     => $params->{'camp-name'}, # NOT NULL
        network_types => \@networks # NOT NULL
    }, {camp_id => $params->{'camp-id'}});

    # error check
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub update_campaign_status {
    my ( $self, $campid, $status ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfCampagne sub update_campaign_status");

    my $res = $self->pg->db->update('metadata.campaigns', {
        camp_active => $status
    }, {camp_id => $campid} );

     # error check
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub update_site_by_id {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne update_site_by_id");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ARRAY networks
        my @networks;
        if (ref($params->{'site-networks'}) eq 'ARRAY') {
            @networks = @{$params->{'site-networks'}};
        }
        else {
            push @networks, $params->{'site-networks'};
        }

        $self->pg->db->update('metadata.sites', {
            site_name      => $params->{'site-name'}, # NOT NULL
            mu_id          => $params->{'site-district'}, # NOT NULL
            site_locality  => $params->{'site-locality'}, # NOT NULL
            site_altitude  => $self->app->helperEscapeParam($params->{'site-altitude'}),
            site_wgs84_lat => $params->{'site-latitude'}, # NOT NULL
            site_wgs84_lon => $params->{'site-longitude'}, # NOT NULL
            site_note      => $self->app->helperEscapeParam($params->{'site-note'}),
            network_types  => \@networks # NOT NULL
        }, {site_id => $params->{'site-id'}});
    };

    # error check
    if ($@) {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'metadata_sites_ukey') != -1) {
            $self->app->log->debug("RETURN -2");
            # come per l'insert per avere lo stesso tipo di messaggio lato JS
            return -2;
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

sub update_location_by_id {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne update_location_by_id");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        $self->app->log->debug("STEP 1 Aggiorno stanziamento");

        $self->pg->db->update('metadata.stations_sites', {
            stsi_startup_date => $self->app->helperGetFormattedFulldate($params->{'loc-start-date'}), # NOT NULL
            stsi_dismiss_date => $params->{'loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'loc-end-date'}) : 'infinity',
            stsi_note         => $self->app->helperEscapeParam($params->{'loc-notes'}),

            camp_id           => ($params->{'loc-campaign'} == -1 ? undef : $params->{'loc-campaign'})
        }, { stsi_id => $params->{'loc-id'} });

        $self->app->log->debug("STEP 2 recupero l'id della stazione e aggiorno l'id esterno");

        my $sql = qq{
            SELECT station_override_id
            FROM metadata.stations_sites
            WHERE stsi_id = ?;
        };

        my $id_override = $self->pg->db->query($sql, $params->{'loc-id'})->hash->{station_override_id};

        $self->pg->db->update('metadata.stations', {
            # ID esterno diverso dal mezzo mobile originale
            station_ext_id => $self->app->helperEscapeParam($params->{'loc-ext-id'})
        }, { station_id => $id_override });
    };

    # error check
    if ($@) {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'metadata_stations_sites_check') != -1) {
            $self->app->log->debug("RETURN -2");
            # come per l'insert per avere lo stesso tipo di messaggio lato JS
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

sub delete_campaign {
    my ( $self, $campid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfCampagne sub delete_campaign");

    # query
    my $sql = qq{ DELETE FROM metadata.campaigns WHERE camp_id = ? };

    my $res = $self->pg->db->query($sql, $campid);

    # error check
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub delete_attachment_by_id {
    my ( $self, $att_id ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne delete_attachment_by_id");
    $self->app->log->debug("att_id: $att_id");

    # query
    my $sql = qq{
        DELETE FROM metadata.site_attachments
        WHERE att_id = ?;
    };

    # return
    my $res = $self->pg->db->query($sql, $att_id);
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub delete_site_by_id {
    my ( $self, $siid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne delete_site_by_id");
    $self->app->log->debug("site_id: $siid");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        my $sql = qq{
            DELETE FROM metadata.site_attachments
            WHERE site_id = ?;
        };

        $self->pg->db->query($sql, $siid);

        $sql = qq{
            DELETE FROM metadata.sites
            WHERE site_id = ?;
        };

        $self->pg->db->query($sql, $siid);
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

sub close_location_by_id {
    my( $self, $stsiid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne close_location_by_id");

    my $res = $self->pg->db->update('metadata.stations_sites', {
        stsi_dismiss_date => $self->app->helperGetLocaleFullDate()
    }, {stsi_id => $stsiid });

    # error check
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub check_site {
    my ( $self, $siid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfCampagne check_site");
    $self->app->log->debug("site_id: $siid");

    # per controllo associazione
    my $sql = qq{
        WITH t1 AS (
            SELECT COUNT(*) AS s
            FROM metadata.stations_sites ss
            WHERE site_id = ?
        )
        SELECT
            CASE WHEN t1.s > 0 THEN TRUE
            ELSE FALSE
            END AS result
        FROM t1;
    };

    my $flag = $self->pg->db->query($sql, $siid)->hash->{'result'};

    # return
    return $flag;
}

1;

=head1 get_roaming_stations_by_nets

Funzione che recupera dal database le informazioni delle stazioni mobili.

Argomenti:  * id dell'utente ('user_id');

           * json contenente le informazioni delle reti, se presenti ('nets');

Return:     Risultato della query.

=cut

=head1 get_campaigns

Funzione che recupera dal database tutte le campagne visibili all'utente.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_sites

Funzione che recupera dal database tutti i siti visibili all'utente.

Argomenti:  * id dell'utente ('user_id');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

Return:     Risultato della query.

=cut

=head1 get_sites_by_date_station

Funzione che recupera, dati un certo periodo temporale e l'id di una stazione,
tutti i siti visibili all'utente.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

           * id della stazione, se presente ('stid');

           * id della campagna, se presente ('camp');

Return:     Risultato della query.

=cut

=head1 get_site_by_id

Funzione che recupera dal database le informazioni di un determinato sito.

Argomenti:  * id del sito ('siid');

Return:     Risultato della query.

=cut

=head1 get_location_by_id

Funzione che recupera dal database le informazioni di una determinata location.

Argomenti:  * id della location ('stsiid');

Return:     Risultato della query.

=cut

=head1 get_mm_history

Funzione che dato l'id del mezzo mobile ne recupera lo storico degli stanziamenti, organizzandoli in un unico jsonb.
L'oggetto viene utilizzato per la costruzione di un GANTT

Argomenti:  * id del mezzo mobile ('stid');

Return:     Risultato della query.

=cut

=head1 insert_new_campaign

Funzione che inserisce una nuova campagna nel database.

Argomenti:  * oggetto contenente le informazioni della campagna da inserire ('params');

Return:     Se tutto OK, restituisce l'id della campagna appena inserita;

        Se KO, restituisce 'undef'.

=cut

=head1 insert_new_site

Funzione che inserisce un nuovo sito nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni del sito da inserire ('params');

Return:     Se tutto OK, restituisce l'id del sito appena inserito;

        Se KO, restituisce 'undef'.

=cut

=head1 insert_new_attachment

Funzione che inserisce gli allegati di un determinato sito nel database.

Argomenti:  * id del sito ('id');

           * nome originale dell'allegato ('original_name');

           * nuovo nome dell'allegato per l'archiviazione ('new_name');

           * valore booleano che indica se l'allegato e' un'immagine ('is_image');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 insert_new_location

Funzione che inserisce una nuova location nel database.

Argomenti:  * oggetto contenente le informazioni della location da inserire ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 'undef', oppure -1 qualora sia presente un messaggio d'errore.

=cut

=head1 update_campaign_by_id

Funzione che modifica una determinata campagna nel database.

Argomenti:  * oggetto contenente le informazioni della campagna da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_campaign_status

Funzione che modifica lo stato di una determinata campagna nel database.

Argomenti:  * id della campagna ('campid');

           * stato della campagna da modificare ('status');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_site_by_id

Funzione che modifica un determinato sito nel database.

Argomenti:  * oggetto contenente le informazioni del sito da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_location_by_id

Funzione che modifica una determinata location nel database.

Argomenti:  * oggetto contenente le informazioni della location da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0, oppure -1 qualora sia presente un messaggio d'errore.

=cut

=head1 delete_campaign

Funzione che elimina una determinata campagna dal database.

Argomenti:  * id della campagna ('campid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_attachment_by_id

Funzione che elimina un determinato allegato dal database.

Argomenti:  * id dell'allegato ('att_id');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_site_by_id

Funzione che elimina un determinato sito dal database.

Argomenti:  * id del sito ('siid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 close_location_by_id

Funzione che effettua la chiusura di una determinata location nel database.

Argomenti:  * id della location ('stinid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.


=cut

=head1 check_site

Funzione che verifica se un determinato sito e' già stato associato a qualche mezzo mobile.

Argomenti:  * id del sito ('siid');

Return:     Valore booleano TRUE/FALSE.

=cut