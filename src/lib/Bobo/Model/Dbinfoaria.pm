package Bobo::Model::Dbinfoaria;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use Date::Calc qw(Today);
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

sub get_pollutants {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbinfoaria sub get_pollutants");

    # query
    my $sql = qq{
        SELECT *
        FROM infoaria.pollutants ip
        LEFT JOIN infoaria.params_pollutant pp USING (pollutant_id)
        LEFT JOIN metadata.parameters mp USING (param_id)
        WHERE param_id NOTNULL
        ORDER BY param_id
    };

    # return
    return $self->pg->db->query($sql)->hashes;
}

sub get_all_stations_params_by_province {
    my ( $self, $user_id, $net, $prov, $prid, $year ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbinfoaria sub get_all_stations_params_by_province");

    $net = ($net  != -1 ? "^$net\$": ".*");
    $prov = ($prov != -1 ? "^$prov\$": ".*");
    $prid = ($prid != -1 ? "^$prid\$": ".*");

    # query
    my $sql = qq{
        SELECT
            sp.stpr_id       ,
            sp.stpr_table_id ,
            sp.param_id      ,
            p.param_name                                        AS parameter_name ,
            s.station_name||' / '|| p.param_name|| COALESCE(' - ' || sp.stpr_note, '')                 AS parameter_fullname,
            p.param_unit                                        AS parameter_unit,
            p.param_unit_conv                                   AS parameter_unit_conv,
            sp.stpr_active                                      AS station_param_active,
            s.station_name,
            COALESCE(spe.spe_active     , 'false')::boolean     AS e2a_active,
            COALESCE(sps.sps_dataset_e1a, 'false')::boolean     AS e1a_active
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.stations_info si USING (station_id)
            LEFT JOIN bobo.view_user_stations us USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
            LEFT JOIN infoaria.stations_params_e2a spe USING (stpr_id)
            LEFT JOIN infoaria.stations_params_status sps ON (sp.stpr_id = sps.stpr_id AND sps_year = ?::integer)
        WHERE
            us.user_id = ?
        AND sp.param_id IN (
            SELECT param_id
            FROM infoaria.params_pollutant
        )
        AND si.st_info_network_type_fk::text ~ ?
        AND smu.province_id::text ~ ?
        AND sp.param_id::text ~ ?
        ORDER BY
            station_name, param_name;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $year, $user_id, $net, $prov, $prid)->hashes;
}

sub get_all_station_params {
    my ( $self, $stid, $prid, $year ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbinfoaria sub get_all_station_params");

    $prid = ($prid != -1 ? "^$prid\$": ".*");

    # query
    my $sql = qq{
        SELECT
            sp.stpr_id       ,
            sp.stpr_table_id ,
            sp.param_id      ,
            p.param_name                                        AS parameter_name ,
            s.station_name||' / '|| p.param_name|| COALESCE(' - ' || sp.stpr_note, '')                 AS parameter_fullname,
            p.param_unit                                        AS parameter_unit,
            p.param_unit_conv                                   AS parameter_unit_conv,
            sp.stpr_active                                      AS station_param_active,
            s.station_name,
            COALESCE(spe.spe_active     , 'false')::boolean     AS e2a_active,
            COALESCE(sps.sps_dataset_e1a, 'false')::boolean     AS e1a_active
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN infoaria.stations_params_e2a spe USING (stpr_id)
            LEFT JOIN infoaria.stations_params_status sps ON (sp.stpr_id = sps.stpr_id AND sps_year = ?::integer)
        WHERE
            station_id = ?
        AND sp.param_id IN (
            SELECT param_id
            FROM infoaria.params_pollutant
        )
        AND param_id::text ~ ?
        ORDER BY
            station_name, param_name;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $year, $stid, $prid)->hashes;
}

sub get_stations_params_e2a_recap {
    my ( $self, $user_id, $net, $prov, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbinfoaria sub get_stations_params_e2a_recap");

    $net = ($net  != -1 ? "^$net\$" : ".*");
    $prov = ($prov != -1 ? "^$prov\$": ".*");
    $stid = ($stid != -1 ? "^$stid\$": ".*");

    # query
    my $sql = qq{
        SELECT
            vem.spo_name,
            vem.station_id,
            vem.st_info_eu_code,
            vem.st_info_name,
            vem.pollutant_id,
            vem.pollutant_notation,
            TO_CHAR(vem.stpr_startup_date, 'DD/MM/YYYY HH24:MI') AS stpr_startup_date,
            vem.instr_type_fullname,
            vem.method

        FROM
            infoaria.view_e2a_metadata vem
            LEFT JOIN metadata.stations_info si USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
            LEFT JOIN bobo.view_user_stations us USING (station_id)
        WHERE
            us.user_id = ?
            AND e2a_active IS TRUE
            AND si.st_info_network_type_fk::text ~ ?
            AND smu.province_id::text ~ ?
            AND station_id::text ~ ?

        ORDER BY
            (
                CASE
                    WHEN spo_name IS NULL THEN 0
                    ELSE 100
                END
            ) ASC, st_info_name, pollutant_id;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $user_id, $net, $prov, $stid)->hashes;
}

sub get_stations_params_e1a_recap {
    my ( $self, $user_id, $year, $net, $prov, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbinfoaria sub get_stations_params_e1a_recap");

    $net = ($net  != -1 ? "^$net\$" : ".*");
    $prov = ($prov != -1 ? "^$prov\$": ".*");
    $stid = ($stid != -1 ? "^$stid\$": ".*");

    # query
    my $sql = qq{
        SELECT
            vem.spo_name,
            vem.station_id,
            vem.st_info_eu_code,
            vem.st_info_name,
            vem.pollutant_id,
            vem.pollutant_notation,
            TO_CHAR(vem.stpr_startup_date, 'DD/MM/YYYY HH24:MI') AS stpr_startup_date,
            vem.instr_type_fullname,
            vem.method

        FROM
            infoaria.f_get_e1a_metadata(?::integer) vem
            LEFT JOIN metadata.stations_info si USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
            LEFT JOIN bobo.view_user_stations us USING (station_id)
        WHERE
            us.user_id = ?
            AND e1a_active IS TRUE
            AND si.st_info_network_type_fk::text ~ ?
            AND smu.province_id::text ~ ?
            AND station_id::text ~ ?

        ORDER BY
            (
                CASE
                    WHEN spo_name IS NULL THEN 0
                    ELSE 100
                END
            ) ASC, st_info_name, pollutant_id;
    };

    # return
    return $self->pg->db->query($sql, $year, $user_id, $net, $prov, $stid)->hashes;
}

sub get_active_station_params {
    my ( $self, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbinfoaria sub get_active_station_params");

    # query
    my $sql = qq{
        SELECT
            sp.stpr_id       ,
            sp.stpr_table_id ,
            sp.param_id      ,
            p.param_name                                        AS parameter_name ,
            s.station_name||' / '|| p.param_name|| COALESCE(' - ' || sp.stpr_note, '')                 AS parameter_fullname,
            p.param_unit                                        AS parameter_unit,
            p.param_unit_conv                                   AS parameter_unit_conv,
            sp.stpr_active                                      AS station_param_active,
            s.station_name,
            COALESCE(spe.spe_active     , 'false')::boolean     AS e2a_active,
            COALESCE(sps.sps_dataset_e1a, 'false')::boolean     AS e1a_active
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN infoaria.stations_params_e2a spe USING (stpr_id)
            LEFT JOIN infoaria.stations_params_status sps ON (sp.stpr_id = sps.stpr_id AND sps_year = TO_CHAR(CURRENT_TIMESTAMP, 'YYYY')::integer)
        WHERE
            station_id = ?
        AND sp.param_id IN (
            SELECT param_id
            FROM infoaria.params_pollutant
        )
        AND ( spe.spe_active IS TRUE OR sps.sps_dataset_e1a IS TRUE )
        ORDER BY
            station_name, param_name;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $stid)->hashes();
}

sub update_stations_params_status {
    my( $self, $stpr_status ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbinfoaria sub update_stations_params_status");

    my $tx;
    my $sql;

    eval {
        $tx = $self->pg->db->begin;

        my $sql;

        for my $status (@{$stpr_status}) {
            my $stprid = $status->{'stprid'};

            if (defined $status->{'e2a'}) {
                $sql = qq{
                    INSERT INTO infoaria.stations_params_e2a
                        ( stpr_id, spe_active )
                    VALUES
                        (?, ?)
                    ON CONFLICT ON CONSTRAINT infoaria_stations_params_e2a_pkey
                    DO UPDATE
                        SET spe_active = EXCLUDED.spe_active;
                };

                $self->pg->db->query($sql, $stprid, $status->{'e2a'});
            }
            elsif (defined $status->{'e1a'}) {
                my $year = $status->{'year'};

                $sql = qq{
                    INSERT INTO infoaria.stations_params_status
                        ( stpr_id, sps_year, sps_dataset_e1a )
                    VALUES
                        (?, ?, ?)
                    ON CONFLICT ON CONSTRAINT infoaria_stations_params_status_pkey
                    DO UPDATE
                        SET sps_dataset_e1a = EXCLUDED.sps_dataset_e1a;
                };

                $self->pg->db->query($sql, $stprid, $year, $status->{'e1a'});
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

1;

=head1 get_pollutants

Funzione che recupera gli inquinanti dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_all_stations_params_by_province

Funzione che recupera tutte le associazioni stazione/parametro dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

           * id del parametro, se presente ('prid');

           * anno, se presente ('year');

Return:     Risultato della query;

=cut

=head1 get_all_station_params

Funzione che recupera le associazioni stazione/parametro di una determinata stazione dal database.

Argomenti:  * id della stazione ('stid');

           * id del parametro, se presente ('prid');

           * anno, se presente ('year');

Return:     Risultato della query;

=cut

=head1 get_stations_params_e2a_recap

Funzione che recupera il riassunto dei parametri attivi nelle stazioni di una determinata
rete e/o di una determinata provincia che vengono inviati per il report E2A.

Argomenti:  * id dell'utente ('user_id');

           * eventuale id della rete ('net');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stid');

Return:     Risultato della query;

=cut

=head1 get_stations_params_e1a_recap

Funzione che recupera il riassunto dei parametri attivi nelle stazioni di una determinata
rete e/o di una determinata provincia che vengono inviati per il report E1A.

Argomenti:  * id dell'utente ('user_id');

           * eventuale id della rete ('net');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stid');

Return:     Risultato della query;

=cut

=head1 get_active_station_params

Funzione che recupera le associazioni stazione/parametro (SOLO quelle attive) di una determinata stazione dal database.

Argomenti:  * id della stazione ('stid');

Return:     Risultato della query;

=cut

=head1 update_stations_params_status

Funzione che effettua la modifica dello status dell'associazione stazione/parametro nel database.

Argomenti:  * status dell'associazione da modificare ('stpr_status');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut