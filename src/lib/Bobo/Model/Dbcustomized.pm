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

    # stpr_table_id  |  param_id  |  parameter
    # ---------------+------------+---------------------
    #            66  |        50  |  PM10 - PX-375
    #                |  IMMAGINE  |
    #            67  |       962  |  [cont] Alluminio - PX-375
    #            68  |       963  |  [cont] Silicio - PX-375
    #            69  |       965  |  [cont] Zolfo - PX-375
    #            70  |       967  |  [cont] Potassio - PX-375
    #            71  |       968  |  [cont] Calcio - PX-375
    #            72  |      1143  |  [cont] Titanio - PX-375
    #            73  |       970  |  [cont] Vanadio - PX-375
    #            74  |       971  |  [cont] Cromo - PX-375
    #            75  |       972  |  [cont] Manganese - PX-375
    #            76  |       973  |  [cont] Ferro - PX-375
    #            77  |       975  |  [cont] Nichel - PX-375
    #            78  |       976  |  [cont] Rame - PX-375
    #            79  |       977  |  [cont] Zinco - PX-375
    #            80  |       980  |  [cont] Arsenico - PX-375
    #            81  |      1003  |  [cont] Piombo - PX-375
    #            82  |       978  |  [cont] Gallio - PX-375
    #            83  |       979  |  [cont] Germanio - PX-375
    #            84  |      1144  |  [cont] Selenio - PX-375
    #            85  |       982  |  [cont] Rubidio - PX-375
    #            86  |       983  |  [cont] Stronzio - PX-375
    #            87  |       984  |  [cont] Yttrio - PX-375
    #            88  |       985  |  [cont] Zirconio - PX-375
    #            89  |       987  |  [cont] Molibdeno - PX-375
    #            90  |       988  |  [cont] Palladio - PX-375
    #            91  |       989  |  [cont] Argento - PX-375
    #            92  |       990  |  [cont] Cadmio - PX-375
    #            93  |       991  |  [cont] Indio - PX-375
    #            94  |       992  |  [cont] Stagno - PX-375
    #            95  |      1145  |  [cont] Antimonio - PX-375
    #            96  |       993  |  [cont] Tellurio - PX-375
    #            97  |       995  |  [cont] Cesio - PX-375
    #            98  |      1146  |  [cont] Bario - PX-375
    #            99  |       997  |  [cont] Cerio - PX-375
    #           100  |       648  |  [cont] Hg - PX-375
    #           101  |      1004  |  [cont] Bismuto - PX-375
    #           102  |       974  |  [cont] Cobalto - PX-375

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
            (SELECT ROUND(measure_value, param_decimals) FROM clients.f_data_extraction(stpr_id, '$date'::timestamp, '$date 23:59:59'::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '< 2147483647'::text) tbl WHERE EXTRACT('hour' FROM measure_date_time) = 00) AS fld1,
            (SELECT ROUND(measure_value, param_decimals) FROM clients.f_data_extraction(stpr_id, '$date'::timestamp, '$date 23:59:59'::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '< 2147483647'::text) tbl WHERE EXTRACT('hour' FROM measure_date_time) = 06) AS fld2,
            (SELECT ROUND(measure_value, param_decimals) FROM clients.f_data_extraction(stpr_id, '$date'::timestamp, '$date 23:59:59'::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '< 2147483647'::text) tbl WHERE EXTRACT('hour' FROM measure_date_time) = 12) AS fld3,
            (SELECT ROUND(measure_value, param_decimals) FROM clients.f_data_extraction(stpr_id, '$date'::timestamp, '$date 23:59:59'::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '< 2147483647'::text) tbl WHERE EXTRACT('hour' FROM measure_date_time) = 18) AS fld4
        FROM
            p
    };

    # return
    return $self->pg->db->query($sql, $stid)->hashes;
}

1;

=head1 get_arpae_validators

Funzione che recupera le informazioni relative ai validatori di Arpa Emilia Romagna.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_horiba_data_by_date

Funzione che recupera i dati dello strumento Horiba PX-375 acquisiti in una determinata data.

Argomenti:  * data per il recupero dei dati ('date');

           * id della stazione ('stid');

Return:     Risultato della query.

=cut