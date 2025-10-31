package Bobo::Model::Dbsysadmin;
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


sub get_system_emails {
    my ( $self, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbsysadmin sub get_system_emails");

    # query
    my $sql = qq{
        SELECT 
            id, app, recipients, subject, body,
            status, 
            CASE 
                WHEN status IS NULL THEN '<span class="badge badge-info"><i class="fa-light fa-sparkles"></i> Nuovo</span>'
                WHEN status IS TRUE THEN '<span class="badge badge-success"><i class="fa-light fa-envelope-circle-check"></i> Inviato</span>'
                ELSE '<span class="badge badge-danger"><i class="fa-light fa-triangle-exclamation"></i> Errore</span>'
            END AS formatted_status,
            insert_time, COALESCE(TO_CHAR(insert_time AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome', 'DD/MM/YYYY HH24:MI'), '--') AS formatted_insert_time,
            sent_time, COALESCE(TO_CHAR(sent_time AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome', 'DD/MM/YYYY HH24:MI'), '--') AS formatted_sent_time,
            sent_tries,
            CASE
                WHEN sent_tries = 0 THEN ''
                WHEN sent_tries IN (1,2) THEN 'text-gray'
                ELSE 'text-purple'
            END AS formatted_sent_tries 
        FROM 
            gateways.html_mails
        WHERE
            insert_time BETWEEN ?::timestamp AND ?::timestamp
        ORDER BY id DESC; 
    };

    # return
    $self->pg->db->query($sql, $from, $to)->hashes;
}

sub get_system_stations_by_net {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbsysadmin sub get_system_emails");

    # query
    my $sql = qq{
        SELECT 
            MAX(st_network_name) AS network, 
            COUNT(*) FILTER (WHERE station_active IS TRUE)  AS active,
            COUNT(*) FILTER (WHERE ss_suspended IS TRUE)  AS suspended,
            COUNT(*) FILTER (WHERE station_active IS FALSE) AS not_active,
            COUNT(*) FILTER (WHERE st_info_roaming_type_fk = 1) AS fixed,
            COUNT(*) FILTER (WHERE st_info_roaming_type_fk = 2) AS mobile,
            COUNT(*) AS total
        FROM 
            metadata.stations st
            LEFT JOIN metadata.stations_info sm USING (station_id)
            LEFT JOIN metadata.stations_status ss USING (station_id)
            LEFT JOIN metadata.stations_network_type snt ON snt.st_network_id = sm.st_info_network_type_fk
            LEFT JOIN metadata.stations_roaming_type srt ON srt.st_roaming_id = sm.st_info_roaming_type_fk
        WHERE 
            st_info_network_type_fk NOTNULL
            AND st_info_roaming_type_fk <= 2
            AND station_schema NOTNULL
        GROUP BY st_info_network_type_fk
        ORDER BY 1; 
    };

    # return
    $self->pg->db->query($sql)->hashes;
}

1;

=head1 get_system_emails

Funzione che recupera le email di sistema inviate dal portale in un intervallo di tempo specificato.

Argomenti:  
* from: data/ora di inizio intervallo ('from')
* to: data/ora di fine intervallo ('to')

Return:     
Risultato della query (lista di email di sistema).

=cut

=head1 get_system_stations_by_net

Funzione che recupera il riepilogo delle stazioni per rete, riportandone le statistiche per stato e tipologia.

Argomenti:  
Nessuno.

Return:     
Risultato della query (riepilogo stazioni per rete).

=cut