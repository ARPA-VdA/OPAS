package Bobo::Model::DbcnfDotazioni;
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

sub get_miscellanies {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfDotazioni sub get_miscellanies");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                m.mi_id,
                COALESCE(m.mi_arpa_id, '--')    AS miscellany_arpa_id,
                m.mi_name                       AS miscellany_name,
                m.mi_dismiss_date               AS miscellany_dismiss_date,
                m.mi_active                     AS miscellany_active ,
                vsm.stmi_id                     AS location_id,
                CASE
                    WHEN vsm.station_name NOTNULL THEN vsm.station_name
                    ELSE '<i class="icon-close text-danger"></i>'
                END AS location,
                CASE
                    WHEN station_mi_startup_date NOTNULL THEN TO_CHAR(station_mi_startup_date, 'DD/MM/YYYY HH24:MI')
                    ELSE '--'
                END AS location_start,
                CASE
                    WHEN station_mi_dismiss_date = 'infinity' THEN 'infinito'
                    WHEN station_mi_dismiss_date IS NULL THEN '--'
                    ELSE TO_CHAR(station_mi_dismiss_date, 'DD/MM/YYYY HH24:MI')
                END AS location_end

            FROM equipments.miscellanies m
            LEFT JOIN metadata.view_stations_miscellanies vsm ON ( m.mi_id = vsm.mi_id AND tsrange(vsm.station_mi_startup_date, vsm.station_mi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
            WHERE m.network_types && ARRAY(
                    SELECT st_network_id
                    FROM bobo.view_user_networks
                    WHERE user_id = ?
                )
        )
        SELECT *
        FROM t
        ORDER BY miscellany_name DESC;
    };

    # $self->app->log->debug($sql, $user_id, $from, $to);

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_miscellanies_by_date_station {
    my ( $self, $user_id, $from, $to, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfDotazioni sub get_miscellanies_by_date_station");

    # query
    my $sql = qq{
        SELECT
            mi_id,
            COALESCE(miscellany_arpa_id, '--') AS miscellany_arpa_id,
            miscellany_name,
            miscellany_dismiss_date,
            miscellany_active,
            stmi_id                     AS location_id,
            CASE
                WHEN station_name NOTNULL THEN station_name
                ELSE '<i class="icon-close text-danger"></i>'
            END AS location,
            CASE
                WHEN station_mi_startup_date NOTNULL THEN TO_CHAR(station_mi_startup_date, 'DD/MM/YYYY HH24:MI')
                ELSE '--'
            END AS location_start,
            CASE
                WHEN station_mi_dismiss_date = 'infinity' THEN 'infinito'
                WHEN station_mi_dismiss_date IS NULL THEN '--'
                ELSE TO_CHAR(station_mi_dismiss_date, 'DD/MM/YYYY HH24:MI')
            END AS location_end,
            station_mi_note

        FROM metadata.view_stations_miscellanies
        WHERE station_id IN (
            SELECT station_id
            FROM bobo.view_user_stations
            WHERE user_id = ?
        )
        AND tsrange(?::timestamp, ?::timestamp, '[]') && tsrange(station_mi_startup_date, station_mi_dismiss_date, '[]')
    };

    if ($stid != -1) {
        $sql .= qq{ AND station_id = $stid };
    }

    $sql .= qq{
        ORDER BY station_mi_startup_date DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_miscellanies_for_location {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfDotazioni sub get_miscellanies_for_location");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                m.mi_id,
                m.mi_name ||
                COALESCE(' ['||m.mi_arpa_id||']', '') AS miscellany_name,
                m.network_types,
                CASE
                    WHEN
                        (
                            SELECT TRUE
                            FROM metadata.stations_miscellanies sm
                            WHERE m.mi_id = sm.mi_id
                            AND tsrange(sm.stmi_startup_date, sm.stmi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                        ) THEN 'hidden'
                    ELSE ''
                END AS miscellany_class

            FROM equipments.miscellanies m
            WHERE m.network_types && ARRAY(
                SELECT st_network_id
                FROM bobo.view_user_networks
                WHERE user_id = ?
            )
            AND m.mi_active IS TRUE
        )
        SELECT *
        FROM t
        ORDER BY 2;
    };

    # $self->app->log->debug($sql, $user_id, $from, $to);

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_miscellany_by_id {
    my ( $self, $miid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfDotazioni sub get_miscellany_by_id");

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
                        '/uploads/impostazioni/dotazioni/'||LPAD(mi_id::text, 9, '0')||'/'||file_archive AS file_path,
                        file_image
                    FROM
                        equipments.miscellany_attachments ma
                    WHERE ma.mi_id = vm.mi_id
                ) j
            ) AS miscellany_attachments,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(l)))
                FROM (
                    SELECT
                        stmi_id                     AS id,
                        station_id                  AS location_id,
                        vsi.station_name            AS location_name,
                        vsm.province_name           AS location_prov,
                        vsi.station_lat_wgs84       AS location_lat,
                        vsi.station_lon_wgs84       AS location_lon,
                        stmi_startup_date           AS location_start,
                        CASE
                            WHEN stmi_dismiss_date = 'infinity' THEN 'infinito'
                            ELSE TO_CHAR(stmi_dismiss_date, 'DD/MM/YYYY HH24:MI')
                        END                         AS location_end,
                        stmi_dismiss_date,
                        COALESCE(stmi_note, '--')   AS location_note
                    FROM
                        metadata.stations_miscellanies sm
                        LEFT JOIN metadata.view_stations_info vsi USING (station_id)
                        LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
                    WHERE sm.mi_id = vm.mi_id
                    ORDER BY stmi_startup_date DESC
                ) l
            ) AS miscellany_locations
        FROM equipments.view_miscellanies vm
        WHERE mi_id = ?
    };

    # return
    return $self->pg->db->query($sql, $miid)->hash();
}

sub get_location_by_id {
    my ( $self, $stmiid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfDotazioni sub get_location_by_id");

    # query
    my $sql = qq{
        SELECT *
        FROM metadata.stations_miscellanies
        WHERE stmi_id = ?
    };

    # return
    return $self->pg->db->query($sql, $stmiid)->hash();
}

sub insert_new_miscellany {
    my( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfDotazioni insert_new_miscellany");

    my $tx;
    my $id;

    eval {
        $tx =  $self->pg->db->begin;

        # {
        #   "add-location" => "on",
        #   "equipment-arpa-id" => "test arpa",
        #   "equipment-owner" => "test proprietario",
        #   "equipment-date-dismiss" => "",
        #   "equipment-active" => "on",
        #   "equipment-id" => "",
        #   "equipment-name" => "Test 001",
        #   "equipment-networks" => [
        #                             3,
        #                             1
        #                           ],
        #   "equipment-note" => "Test note"
        #   "loc-end-date" => "31/12/2022 09:53",
        #   "loc-notes" => "test note location",
        #   "loc-prov" => -1,
        #   "loc-start-date" => "01/12/2021 09:53",
        #   "loc-stat" => 1004,
        # }

        # ARRAY networks
        my @networks;
        if (ref($params->{'equipment-networks'}) eq 'ARRAY') {
            @networks = @{$params->{'equipment-networks'}};
        }
        else {
            push @networks, $params->{'equipment-networks'};
        }

        $id = $self->pg->db->insert('equipments.miscellanies', {
            # id              => # id progressivo
            mi_arpa_id      => $self->app->helperEscapeParam($params->{'equipment-arpa-id'}),
            mi_owner        => $self->app->helperEscapeParam($params->{'equipment-owner'}),
            mi_name         => $self->app->helperEscapeParam($params->{'equipment-name'}),
            mi_dismiss_date => $self->app->helperGetFormattedFulldate($params->{'equipment-date-dismiss'}),
            mi_active       => $self->app->helperGetBoolean($params, 'equipment-active'),
            mi_note         => $self->app->helperEscapeParam($params->{'equipment-note'}),

            network_types   => \@networks,
            insert_user     => $userid
        }, {returning => 'mi_id'})->hash->{'mi_id'};

        if (defined $params->{'add-location'} && $params->{'add-location'} ne '') {
            $self->pg->db->insert('metadata.stations_miscellanies', {
                # id                => # id progressivo
                station_id        => $params->{'loc-stat'},
                mi_id             => $id,
                stmi_startup_date => $self->app->helperGetFormattedFulldate($params->{'loc-start-date'}),
                stmi_dismiss_date => $params->{'loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'loc-end-date'}) : 'infinity',
                stmi_note         => $self->app->helperEscapeParam($params->{'loc-notes'})

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
       return $id;
    }
}

sub insert_new_attachment {
    my( $self, $id, $original_name, $new_name, $is_image ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfDotazioni insert_new_attachment");
    $self->app->log->debug("File: $original_name to $new_name");

    my $res = $self->pg->db->insert('equipments.miscellany_attachments', {
        mi_id         => $id,
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
    $self->app->log->debug("sub Bobo::Model::DbcnfDotazioni insert_new_location");

    # {
    #   "place-loc-end-date" => "16/09/2021 10:59",
    #   "place-loc-id" => 1,
    #   "place-loc-notes" => "prova location Modifica",
    #   "place-loc-prov" => -1,
    #   "place-loc-start-date" => "01/09/2021 09:11",
    #   "place-loc-stat" => 1004,
    #   "place-networks" => "[1]",
    #   "place-loc-equipment" => 2
    # }

    my $id;
    eval{
        $id = $self->pg->db->insert('metadata.stations_miscellanies', {
            # id                => # id progressivo
            station_id        => $params->{'place-loc-stat'},
            mi_id             => $params->{'place-loc-equipment'},
            stmi_startup_date => $self->app->helperGetFormattedFulldate($params->{'place-loc-start-date'}),
            stmi_dismiss_date => $params->{'place-loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'place-loc-end-date'}) : 'infinity',
            stmi_note         => $self->app->helperEscapeParam($params->{'place-loc-notes'})
        }, {returning => 'stmi_id'})->hash->{'stmi_id'};
    };

    if (defined $id) {
        return 1;
    }
    else {
        if (index($@->{'message'}, 'metadata_stations_miscellanies_check') != -1) {
            return -1;
        }
        else {
            return undef;
        }
    }
}

sub update_miscellany_by_id {
    my( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfDotazioni update_miscellany_by_id");

    # {
    #   "add-location" => "on",
    #   "equipment-arpa-id" => "test arpa",
    #   "equipment-owner" => "test proprietario",
    #   "equipment-date-dismiss" => "",
    #   "equipment-active" => "on",
    #   "equipment-id" => "",
    #   "equipment-name" => "Test 001",
    #   "equipment-networks" => [
    #                             3,
    #                             1
    #                           ],
    #   "equipments-note" => "Test note"
    #   "loc-end-date" => "31/12/2022 09:53",
    #   "loc-notes" => "test note location",
    #   "loc-prov" => -1,
    #   "loc-start-date" => "01/12/2021 09:53",
    #   "loc-stat" => 1004,
    # }

    # ARRAY networks
    my @networks;
    if (ref($params->{'equipment-networks'}) eq 'ARRAY') {
        @networks = @{$params->{'equipment-networks'}};
    }
    else {
        push @networks, $params->{'equipment-networks'};
    }

    my $res = $self->pg->db->update('equipments.miscellanies', {
        # id              => # id progressivo
        mi_arpa_id      => $self->app->helperEscapeParam($params->{'equipment-arpa-id'}),
        mi_owner        => $self->app->helperEscapeParam($params->{'equipment-owner'}),
        mi_name         => $self->app->helperEscapeParam($params->{'equipment-name'}),
        mi_dismiss_date => $self->app->helperGetFormattedFulldate($params->{'equipment-date-dismiss'}),
        mi_active       => $self->app->helperGetBoolean($params, 'equipment-active'),
        mi_note         => $self->app->helperEscapeParam($params->{'equipment-note'}),

        network_types   => \@networks
    }, {mi_id => $params->{'equipment-id'}});

    # error check
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub update_location_by_id {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfDotazioni update_location_by_id");

    # {
    #   "place-loc-end-date" => "16/09/2021 10:59",
    #   "place-loc-id" => 1,
    #   "place-loc-notes" => "prova location Modifica",
    #   "place-loc-prov" => -1,
    #   "place-loc-start-date" => "01/09/2021 09:11",
    #   "place-loc-stat" => 1004,
    #   "place-networks" => "[1]",
    #   "place-loc-equipment" => 2
    # }

    my $res;

    eval {
        if (defined $params->{'place-loc-stat'}) {
            $res = $self->pg->db->update('metadata.stations_miscellanies', {
                station_id        => $params->{'place-loc-stat'},
                stmi_startup_date => $self->app->helperGetFormattedFulldate($params->{'place-loc-start-date'}),
                stmi_dismiss_date => $params->{'place-loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'place-loc-end-date'}) : 'infinity',
                stmi_note         => $self->app->helperEscapeParam($params->{'place-loc-notes'})
            }, {stmi_id => $params->{'place-loc-id'}});
        }
        else {
            $res = $self->pg->db->update('metadata.stations_miscellanies', {
                stmi_dismiss_date => $params->{'place-loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'place-loc-end-date'}) : 'infinity',
                stmi_note         => $self->app->helperEscapeParam($params->{'place-loc-notes'})
            }, {stmi_id => $params->{'place-loc-id'}});
        }
    };

    # check result and return
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'metadata_stations_miscellanies_check') != -1) {
            return -1;
        }
        else {
            return 0;
        }
    }
}

sub delete_miscellany_by_id {
    my ( $self, $miid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfDotazioni delete_miscellany_by_id");
    $self->app->log->debug("miid: $miid");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # query
        my $sql = qq{
            DELETE FROM metadata.stations_miscellanies
            WHERE mi_id = ?;
        };

        $self->pg->db->query($sql, $miid);

        $sql = qq{
            DELETE FROM equipments.miscellany_attachments
            WHERE mi_id = ?;
        };

        $self->pg->db->query($sql, $miid);

        $sql = qq{
            DELETE FROM equipments.miscellanies
            WHERE mi_id = ?;
        };

        $self->pg->db->query($sql, $miid);
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

sub delete_attachment_by_id {
    my ( $self, $att_id ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfDotazioni delete_attachment_by_id");
    $self->app->log->debug("att_id: $att_id");

    # query
    my $sql = qq{
        DELETE FROM equipments.miscellany_attachments
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

sub close_location_by_id {
    my( $self, $stmiid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfDotazioni close_location_by_id");

    # query
    my $res = $self->pg->db->update('metadata.stations_miscellanies', {
        stmi_dismiss_date => $self->app->helperGetLocaleFullDate()
    }, { stmi_id => $stmiid });

    # error check
    # my $res = $self->pg->db->query($sql, $self->app->helperGetLocaleFullDate(), $stcyid);
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub check_miscellany {
    my ( $self, $miid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfDotazioni check_miscellany");
    $self->app->log->debug("miid: $miid");

    # per controllo associazione con planning query:
    my $sql = qq{
        WITH t1 AS (
            SELECT COUNT(*) AS s
            FROM reports.tickets
            WHERE mi_id::integer = ?
        )
        SELECT
            CASE WHEN t1.s > 0 THEN TRUE
            ELSE FALSE
            END AS result
        FROM t1;
    };

    my $flag = $self->pg->db->query($sql, $miid)->hash->{'result'};

    # return
    return $flag;
}

sub check_location {
    my ( $self, $stmiid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfDotazioni check_location");
    $self->app->log->debug("stmiid: $stmiid");

    # per controllo associazione con report tarature e planning query:
    # station_id
    # cy_id
    # stcy_startup_date
    # stcy_dismiss_date

    # query
    my $sql = qq{
        WITH t1 AS (
            SELECT *
            FROM metadata.stations_miscellanies
            WHERE stmi_id = ?
        ),
        t2 AS (
            SELECT COUNT(*) AS s
            FROM t1
            LEFT JOIN reports.tickets t ON (t1.station_id = t.station_id AND tsrange(t1.stmi_startup_date, t1.stmi_dismiss_date, '[)') @> t.tk_opening_date )
            WHERE t.mi_id::integer = t1.mi_id
        )
        SELECT
            CASE
                WHEN t2.s > 0 THEN TRUE
                ELSE FALSE
            END AS result
        FROM t2;
    };

    my $flag = $self->pg->db->query($sql, $stmiid)->hash->{'result'};

    # return
    return $flag;
}

1;

=head1 get_miscellanies

Funzione che recupera dal database le dotazioni associate alle varie location di cui l'utente ha la visibilità.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_miscellanies_by_date_station

Funzione che recupera, dato un certo periodo temporale e l'id di una stazione, tutte le dotazioni dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione, se presente ('stid');

Return:     Risultato della query.

=cut

=head1 get_miscellanies_for_location

Funzione che recupera dal database le dotazioni non ancora stanziate.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_miscellany_by_id

Funzione che, dato l'id, recupera dal database le informazioni di una determinata dotazione.

Argomenti:  * id della dotazione ('miid');

Return:     Risultato della query.

=cut

=head1 get_location_by_id

Funzione che, dato l'id, recupera dal database le informazioni di una determinata location.

Argomenti:  * id della location ('stmiid');

Return:     Risultato della query.

=cut

=head1 insert_new_miscellany

Funzione che inserisce una nuova dotazione nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni della dotazione da inserire ('params');

Return:     Se tutto OK, restituisce l'id della dotazione appena inserita;

        Se KO, restituisce 'undef'.

=cut

=head1 insert_new_attachment

Funzione che inserisce gli allegati di una determinata dotazione nel database.

Argomenti:  * id della dotazione ('id');

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

=head1 update_miscellany_by_id

Funzione che, dato l'id, modifica una determinata dotazione nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni della dotazione da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_location_by_id

Funzione che, dato l'id, modifica una determinata location nel database.

Argomenti:  * oggetto contenente le informazioni della location da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0, oppure -1 qualora sia presente un messaggio d'errore.

=cut

=head1 delete_miscellany_by_id

Funzione che, dato l'id, elimina una determinata dotazione dal database.

Argomenti:  * id della dotazione ('miid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_attachment_by_id

Funzione che, dato l'id, elimina un determinato allegato dal database.

Argomenti:  * id dell'allegato ('att_id');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 close_location_by_id

Funzione che, dato l'id, effettua la chiusura di una determinata location nel database.

Argomenti:  * id della location ('stmiid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.


=cut

=head1 check_miscellany

Funzione che verifica se una determinata dotazione e' associata a qualche ticket.

Argomenti:  * id della dotazione ('miid');

Return:     Valore booleano TRUE/FALSE.

=cut

=head1 check_location

Funzione che verifica se la dotazione durante una determinata location e' associata a qualche ticket.

Argomenti:  * id della location ('stmiid');

Return:     Valore booleano TRUE/FALSE.

=cut