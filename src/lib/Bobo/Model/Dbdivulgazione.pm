package Bobo::Model::Dbdivulgazione;
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

sub get_notification_stations_grants {
    my ($self, $userid) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdivulgazione sub get_group_stations_grants");

    # query
    my $sql = qq{
        SELECT
            s.station_id,
            s.station_name,
            s.station_active,
            si.st_info_network_type_fk,
            snt.st_network_desc,
            vsm.province_id,
            vsm.province_code,
            CASE
                WHEN ss.ss_email IS TRUE THEN 'checked'
                ELSE ''
            END AS station_email,
            CASE
                WHEN ss.ss_telegram IS TRUE THEN 'checked'
                ELSE ''
            END AS station_telegram
        FROM
            metadata.stations s
            LEFT JOIN metadata.stations_status ss USING (station_id)
            LEFT JOIN metadata.stations_info si USING (station_id)
            LEFT JOIN metadata.stations_network_type snt ON snt.st_network_id = si.st_info_network_type_fk
            LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
            LEFT JOIN bobo.view_user_stations vus USING (station_id)
        WHERE
            vus.user_id = ?
            AND si.st_info_roaming_type_fk IN (1,2,3)
        ORDER BY
            si.st_info_network_type_fk, s.station_name;
    };

    # return
    $self->pg->db->query($sql, $userid)->hashes;
}

sub update_notification_stations_grants {
    my( $self, $grants ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdivulgazione sub update_notification_stations_grants");

    my $tx;
    my $sql;

    eval {
        $tx =  $self->pg->db->begin;

        my $sql;
        my $grants_bit;

        for my $grant (@{$grants}) {
            my $stid = $grant->{'stid'};

            $sql = qq{
                INSERT INTO metadata.stations_status
                    (station_id, ss_email, ss_telegram)
                VALUES
                    (?, ?, ?)
                ON CONFLICT ON CONSTRAINT metadata_stations_status_pkey
                DO UPDATE
                    SET ss_email = EXCLUDED.ss_email,
                        ss_telegram = EXCLUDED.ss_telegram;
            };

            $self->pg->db->query($sql, $stid, $grant->{'email'}, $grant->{'telegram'});
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

=head1 get_notification_stations_grants

Funzione che recupera le informazioni relative alle stazioni in base ai permessi dell'utente loggato dal database.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query.

=cut

=head1 update_notification_stations_grants

Funzione che inserisce/modifica, oppure elimina, i permessi sulle notifiche delle stazioni dal database.

Argomenti:  * oggetto contenente i relativi permessi ('params');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut