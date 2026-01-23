package Bobo::Model::Dbcustomized;
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

#
# ARPAE
#
sub get_arpae_validators {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcustomized sub get_arpae_validators");

    # query
    my $sql = qq{
        SELECT
             STRING_AGG(
                '<tr>'||E'\n'
                ||'    <td>'||us_num||'</td>'||E'\n'
                ||'    <td>'||us_office||'</td>'||E'\n'
                ||'    <td>'||us_fullname||'</td>'||E'\n'
                ||'    <td>'||COALESCE(us_role, '')||'</td>'||E'\n'
                ||'    <td>'||us_function||'</td>'||E'\n'
                ||'</tr>'||E'\n'
            , '') AS body
        FROM
            bobo.view_custom_arpae_validators;
    };

    # return
    return $self->pg->db->query($sql)->hash->{'body'};
}

sub get_arpae_stations {
    my ( $self, $type ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcustomized sub get_arpae_stations");
    
    # query
    my $sql = qq{
        SELECT
            STRING_AGG(
                '<tr>'||E'\n'
                ||'    <td>'||st_num||'</td>'||E'\n'
                ||'    <td>'||st_arpa_id||'</td>'||E'\n'
                ||'    <td>'||st_eu_id||'</td>'||E'\n'
                ||'    <td>'||st_name||'</td>'||E'\n'
                ||'    <td>'||st_address||'</td>'||E'\n'
                ||'    <td>'||st_lat_wgs84||'</td>'||E'\n'
                ||'    <td>'||st_lon_wgs84||'</td>'||E'\n'
                ||'    <td align="center">'||( CASE WHEN st_pm10 IS TRUE THEN '✔' ELSE '-' END )||'</td>'||E'\n'
                ||'    <td align="center">'||( CASE WHEN st_pm25 IS TRUE THEN '✔' ELSE '-' END )||'</td>'||E'\n'
                ||'    <td align="center">'||( CASE WHEN st_nox  IS TRUE THEN '✔' ELSE '-' END )||'</td>'||E'\n'
                ||'    <td align="center">'||( CASE WHEN st_co   IS TRUE THEN '✔' ELSE '-' END )||'</td>'||E'\n'
                ||'    <td align="center">'||( CASE WHEN st_btx  IS TRUE THEN '✔' ELSE '-' END )||'</td>'||E'\n'
                ||'    <td align="center">'||( CASE WHEN st_so2  IS TRUE THEN '✔' ELSE '-' END )||'</td>'||E'\n'
                ||'    <td align="center">'||( CASE WHEN st_o3   IS TRUE THEN '✔' ELSE '-' END )||'</td>'||E'\n'
                ||'    <td>'||st_type||'</td>'||E'\n'
                ||'    <td>'||st_zone||'</td>'||E'\n'
                ||'</tr>'||E'\n'
            , '') AS body,

            '<tr style="font-weight: 600;font-size:1.1rem;color: #4f727b;">'||E'\n'
            ||'    <td colspan="3"></td>'||E'\n'
            ||'    <td colspan="4">N° totale stazioni: '||MAX(tot_stations)||'</td>'||E'\n'
            ||'    <td align="center">'||MAX(tot_pm10)||'</td>'||E'\n'
            ||'    <td align="center">'||MAX(tot_pm25)||'</td>'||E'\n'
            ||'    <td align="center">'||MAX(tot_nox)||'</td>'||E'\n'
            ||'    <td align="center">'||MAX(tot_co)||'</td>'||E'\n'
            ||'    <td align="center">'||MAX(tot_btx)||'</td>'||E'\n'
            ||'    <td align="center">'||MAX(tot_so2)||'</td>'||E'\n'
            ||'    <td align="center">'||MAX(tot_o3)||'</td>'||E'\n'
            ||'    <td colspan="2"></td>'||E'\n'
            ||'</tr>'||E'\n' AS totals
            
        FROM
            metadata.view_custom_arpae_stations
        WHERE 
            st_group = ?
    };

    # return
    return $self->pg->db->query($sql, $type)->hash;
}

sub get_arpae_active_equipments{
    my ( $self, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcustomized sub get_arpae_active_equipments");

    $prov = ($prov ne 'ALL' ? "^$prov\$": ".*");

    my $sql = qq{
        SELECT 
            --equip_id,
            row_number() OVER (PARTITION BY vsm.province_name ORDER BY t.station_name, t.row_type, t.equip_name)::text AS row_num,
            t.station_id,
            t.station_name,
            vsm.province_name,
            t.equip_name,
            t.equip_brand_model,
            t.equip_serial_num,
            t.equip_arpa_id,
            t.equip_delivery_date,
            t.equip_owner,
            t.row_icon,
            t.row_type
        FROM 
            metadata.view_custom_arpae_active_equipments t
            LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)

        WHERE vsm.province_code ~* ?
        ORDER BY
            vsm.province_name, t.station_name, t.row_type, t.equip_name;
    };

    # return
    return $self->pg->db->query($sql, $prov)->hashes;
}

sub get_arpae_not_active_equipments{
    my ( $self, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcustomized sub get_arpae_not_active_equipments");

    $prov = ($prov ne 'ALL' ? "$prov": ".*");

    my $sql = qq{
        SELECT 
            --equip_id,
            row_number() OVER (PARTITION BY p.province_name ORDER BY t.row_type, t.equip_name)::text AS row_num,
            CASE 
                WHEN SPLIT_PART(t.equip_name, '-', 2 ) = 'RR' THEN 'Rete Ricerca'
                ELSE p.province_name
            END AS province_name,
            t.equip_name,
            t.equip_brand_model,
            t.equip_serial_num,
            t.equip_arpa_id,
            t.equip_delivery_date,
            t.equip_owner,
            t.row_icon,
            t.row_type
        FROM 
            metadata.view_custom_arpae_not_active_equipments t
            LEFT JOIN main.provinces p ON ( SPLIT_PART(t.equip_name, '-', 2 ) = p.province_code  )
        WHERE
            SPLIT_PART(t.equip_name, '-', 2 ) ~* ? -- Codice provincia
        ORDER BY
            p.province_name, t.row_type, t.equip_name;
    };

    # return
    return $self->pg->db->query($sql, $prov)->hashes;
}

#
# IMMAGINI HORIBA
#
sub get_horiba_data_by_date {
    my ( $self, $date, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcustomized sub get_horiba_data_by_date");

    # prepare date bounds (start and end of day) and bind them instead of interpolating
    my $start = $date;
    my $end   = $date . ' 23:59:59';

    # query
    my $sql = qq{
        WITH p AS (
            SELECT
                stpr_id,
                param_name,
                param_unit,
                param_decimals
            FROM
                metadata.view_horiba_parameters p
                LEFT JOIN metadata.stations_parameters sp1 USING (param_id)
            WHERE
                sp1.station_id = ?
                AND sp1.stpr_group_id = (
                    SELECT
                        stpr_group_id
                    FROM
                        metadata.view_horiba_parameters p2
                        LEFT JOIN metadata.stations_parameters sp2 USING (param_id)
                    WHERE
                        station_id = sp1.station_id
                    GROUP BY
                        stpr_group_id
                    HAVING
                        COUNT(*) > 1
                )
        )
        SELECT
            param_name,
            param_unit,
            (SELECT ROUND(measure_value, param_decimals) FROM clients.f_data_extraction(stpr_id, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '< 2147483647'::text) tbl WHERE EXTRACT('hour' FROM measure_date_time) = 00) AS fld1,
            (SELECT ROUND(measure_value, param_decimals) FROM clients.f_data_extraction(stpr_id, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '< 2147483647'::text) tbl WHERE EXTRACT('hour' FROM measure_date_time) = 06) AS fld2,
            (SELECT ROUND(measure_value, param_decimals) FROM clients.f_data_extraction(stpr_id, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '< 2147483647'::text) tbl WHERE EXTRACT('hour' FROM measure_date_time) = 12) AS fld3,
            (SELECT ROUND(measure_value, param_decimals) FROM clients.f_data_extraction(stpr_id, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '< 2147483647'::text) tbl WHERE EXTRACT('hour' FROM measure_date_time) = 18) AS fld4
        FROM
            p
    };

    # return
    return $self->pg->db->query(
        $sql, $stid,
        $start, $end,
        $start, $end,
        $start, $end,
        $start, $end
    )->hashes;
}

1;

=head1 get_arpae_validators

Funzione che recupera le informazioni relative ai validatori di Arpa Emilia Romagna.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_arpae_stations

Funzione che recupera la lista delle stazioni ARPAE per il gruppo specificato (st_group).
La query restituisce una rappresentazione HTML aggregata (body) delle righe e una riga totals
con i conteggi aggregati.

Argomenti:  * type: codice del gruppo di stazioni ('st_group')

Return:     Risultato della query (hashref contenente 'body' e 'totals').

=cut

=head1 get_arpae_active_equipments

Funzione che recupera gli equipaggiamenti attivi per provincia (o tutte le province).
La funzione accetta un filtro provincia (codice) o 'ALL' per non filtrare, e restituisce
una lista ordinata di equipaggiamenti attivi con alcune colonne utili per la UI.

Argomenti:  * prov: codice della provincia (es. 'IM','SV') oppure 'ALL'

Return:     Risultato della query (array di hashrefs con gli equipaggiamenti attivi).

=cut

=head1 get_arpae_not_active_equipments

Funzione che recupera gli equipaggiamenti non attivi filtrabili per provincia.
Restituisce righe con informazioni sull'equipaggiamento non attivo, incluse alcune logiche
di presentazione (es. mappatura del nome in province).

Argomenti:  * prov: codice della provincia (es. 'IM','SV') oppure 'ALL'

Return:     Risultato della query (array di hashrefs con gli equipaggiamenti non attivi).

=cut

=head1 get_horiba_data_by_date

Funzione che recupera i dati dello strumento Horiba PX-375 acquisiti in una determinata data.

Argomenti:  * data per il recupero dei dati ('date');

           * id della stazione ('stid');

Return:     Risultato della query.

=cut