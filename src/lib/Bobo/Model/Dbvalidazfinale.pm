package Bobo::Model::Dbvalidazfinale;

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
sub get_validation_codes {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazfinale sub get_validation_codes");

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
            v.fvc_code_id  ,
            t.fvc_code_desc
        FROM
            bobo.view_user_final_codes v
            LEFT JOIN t USING (fvc_code_id)
        WHERE
            user_id = ?
            AND t.fvc_code_desc NOTNULL
        ORDER BY
            fvc_code_id;
    };

    # return
    $self->pg->db->query($sql, $user_id, $user_id)->hashes;
}

sub get_portal_codes {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazfinale sub get_portal_codes");

    # query
    my $sql = qq{
        SELECT
            value AS fvc_code_id,
            label AS fvc_code_desc
        FROM
            jsonb_to_recordset(
                bobo.f_get_user_portal_options( ?, '/dat_validaz_finale' )-> 'codes'
            ) AS x(value integer, label text)
        ORDER BY
            value;
    };

    # return
    $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_validation_per_year {
    my ( $self, $user_id, $year, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazfinale sub get_validation_per_year");

    # query
    my $sql = qq{
        WITH t AS(
            SELECT
                d::date AS start_date,
                ((d + '1 month'::interval - '1 day'::interval )::date || ' 23:00:00')::timestamp end_date,
                ROW_NUMBER() OVER() AS month_idx
            FROM
                generate_series((?||'-01-01')::date, (?||'-12-31')::date, '1 month'::interval) d
        )
        SELECT
            sp.stpr_id,
            s.station_name,
            p.param_name || COALESCE(' - ' || sp.stpr_note, '') AS param_name,
            (
                SELECT
                    json_agg(json_build_object(
                        'month', t.month_idx,
                        'obj'  , (SELECT row_to_json(s) FROM clients.f_data_validity_statistics( sp.stpr_id , t.start_date::timestamp, t.end_date::timestamp, FALSE::boolean ) AS s)
                    ))
                FROM
                    t

            ) AS stats_obj
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.parameters p USING (param_id)

        WHERE
            station_id = ?
            AND param_id IN (
                SELECT
                    value AS param_id
                FROM
                    jsonb_to_recordset(
                        bobo.f_get_user_portal_options( ?, '/dat_validaz_finale' )-> 'params'
                    ) AS x(value integer, label text)
             )
        ORDER BY
            station_name, param_name;
    };

    # return
    return $self->pg->db->query($sql, $year, $year, $stid, $user_id)->hashes;
}

sub get_validation_table {
    my ( $self, $user_id, $from, $to, $stations, $params, $conv ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazfinale sub get_validation_table");

    my $stations_string = join ', ', @{$stations};
    my $params_string = join ', ', @{$params};

    # query
    my $sql = qq{
        WITH g AS (
            SELECT
                station_id,
                (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'010')) AS t (bit)) AS temp)::boolean AS station_update
            FROM
                bobo.view_user_stations vus
            WHERE
                user_id = ?
        )
        SELECT
            sp.stpr_id,
            sp.station_id,
            s.station_name,
            g.station_update,
            p.param_name || COALESCE(' - ' || sp.stpr_note, '') AS param_name,
            (
                SELECT
                    row_to_json(s)
                FROM
                    clients.f_data_validity_statistics( sp.stpr_id , ?::timestamp, ?::timestamp, ?::boolean ) AS s
            ) AS stats_obj
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN g USING (station_id)

        WHERE
            station_id IN ( $stations_string )
            AND param_id IN ( $params_string )
        ORDER BY
            station_name, param_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to, $conv)->hashes;
}

sub get_activities_log {
    my ( $self, $user_id, $from, $to, $lvl, $prid, $stid, $usid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazfinale sub get_activities_log");

    $lvl = ($lvl != -1 ? "^$lvl\$": ".*");
    $prid = ($prid != -1 ? "^$prid\$": ".*");
    $stid = ($stid != -1 ? "^$stid\$": ".*");
    $usid = ($usid != -1 ? "^$usid\$": ".*");

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
            fvl.us_id,
            CONCAT_WS(' ', u.us_name, u.us_2nd_name, u.us_surname) AS user_fullname,
            u.us_avatar_thumb,
            fvl.stpr_id,
            vus.station_id,
            vus.station_name,
            p.param_id,
            p.param_name || COALESCE(' - ' || sp.stpr_note, '') AS param_name,
            fvl.fvc_code_id,
            t.fvc_code_desc,
            fvl.fvl_date_start,
            fvl.fvl_date_end,
            CONCAT_WS(' - ', TO_CHAR(fvl.fvl_date_start, 'DD/MM/YYYY'), TO_CHAR(fvl.fvl_date_end, 'DD/MM/YYYY') ) AS fvl_date_range,
            fvl.fvl_insert_ts AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome' AS fvl_insert_ts,
            TO_CHAR(fvl.fvl_insert_ts AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome', 'DD/MM/YYYY HH24:MI') AS fvl_insert_format,
            ( EXTRACT('epoch' FROM fvl.fvl_date_end::timestamp - fvl.fvl_date_start::timestamp) / 3600 )::integer + 1 AS diff_hours,
            fvl.fvl_rows

        FROM
            clients.final_validation_log fvl
            LEFT JOIN bobo.users u                              USING (us_id)
            LEFT JOIN metadata.stations_parameters sp           USING (stpr_id)
            LEFT JOIN metadata.parameters p                     USING (param_id)
            LEFT JOIN t                                         USING (fvc_code_id)
            LEFT JOIN metadata.view_stations_municipality vsm   USING (station_id)
            LEFT JOIN bobo.view_user_stations vus               USING (station_id)
        WHERE
            fvl.fvl_insert_ts BETWEEN ?::timestamp AND ?::timestamp
            AND vus.user_id = ?
            AND fvl.fvc_code_id::text ~ ?
            AND vsm.province_id::text ~ ?
            AND vus.station_id::text ~ ?
            AND fvl.us_id::text ~ ?
        ORDER BY
            fvl_insert_ts DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to, $user_id, $lvl, $prid, $stid, $usid)->hashes;
}

sub update_final_validity_code {
    my ( $self, $user_id, $stprid, $from, $to, $code ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbvalidazfinale sub update_final_validity_code");

    my $tx;
    my $sql;
    my $res;

    eval {
        $tx = $self->pg->db->begin;

        # inserimento nota se presente @TODO
        my $ann_id = undef;

        # inserimento metadata da recuperare nel trigger f_save_history che scatta before update
        # !attenzione! riga visibile solo dai trigger che scattano durante questa transazione
        # INSERT INTO clients.trigger_history (us_id, ann_id) VALUES (4, NULL);
        $self->pg->db->insert('clients.trigger_history' , {
            us_id  => $user_id,
            ann_id => $ann_id
        });

        my $sql = qq{
            SELECT clients.f_update_final_validity_code( ?::integer , ?::timestamp, ?::timestamp, ?::smallint ) AS num_rows;
        };

        $res = $self->pg->db->query($sql, $stprid, $from, $to, $code)->hash->{'num_rows'};

        # ELIMINA RISULTATI VALIDAZIONE AUTOMATICA
        $sql = qq{
            DELETE FROM clients.auto_validation_results
            WHERE measure_date_time BETWEEN ?::timestamp AND ?::timestamp
            AND stpr_id = ?;
        };

        $self->pg->db->query($sql, $from, $to, $stprid);

        # elimino metadata salvati precedentemente
        # !attenzione! elimina unicamente la riga inserita in questa transazione
        $sql = qq{
            DELETE FROM clients.trigger_history;
        };

        $self->pg->db->query($sql);

        # check result
        if (!defined $res) {
            die "Something went wrong during function clients.f_update_final_validity_code execution!";
        }
        elsif ($res > 0) {
            # 1 or more rows affected by the update => save action in a specific table
            $self->pg->db->insert('clients.final_validation_log' , {
                us_id          => $user_id,
                stpr_id        => $stprid,
                fvc_code_id    => $code,
                fvl_date_start => $from,
                fvl_date_end   => $to,
                fvl_rows       => $res
            });
        }
    }; # end eval

    $self->app->log->debug("RESULT $res");

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return -1;
    }
    else {
       $tx->commit;
       return $res;
    }
}

1;

=head1 get_validation_codes

Funzione che recupera i codici di validazione dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_portal_codes

Funzione che recupera i codici di validazione dal database, in base al portale dell'utente loggato.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_validation_per_year

Funzione che recupera i dati di validazione per un determinato anno di una determinata
stazione dal database.

Argomenti:  * id dell'utente ('user_id');

           * anno ('year');

           * id della stazione ('stid');

Return:     Risultato della query.

=cut

=head1 get_validation_table

Funzione che recupera dal database il registro delle attivita' eseguite dagli utenti
relative alla validazione multilivello.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * array degli id delle stazioni richieste dall'utente ('stations');

           * array degli id dei parametri richiesti dall'utente ('params');

           * valore booleano relativo alla conversione dei parametri ('conv');

Return:     Risultato della query.

=cut

=head1 get_activities_log

Funzione che recupera dal database il registro delle attivita' eseguite dagli utenti
relative alla validazione multilivello.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * tipo di validazione ('lvl');

           * id della provincia, se presente ('prid');

           * id della stazione, se presente ('stid');

           * id dell'utente che ha effettuato le operazioni validazione ('usid');

Return:     Risultato della query.

=cut

=head1 update_final_validity_code

Funzione che effettua la modifica del codice di validazione finale per un determinato parametro
di una determinata stazione in un determinato periodo temporale..

Argomenti:  * id dell'utente ('user_id');

           * id dell'associazione stazione-parametro ('stprid');

           * data d'inizio ('from');

           * data di fine ('to');

           * valore del codice di validazione ('code');

Return:     Risultato della query.

=cut