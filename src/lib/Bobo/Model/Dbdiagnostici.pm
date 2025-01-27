package Bobo::Model::Dbdiagnostici;
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

sub get_active_diags_by_stid {
    my ( $self, $table, $date_from, $date_to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdiagnostici sub get_active_diags_by_stid");

    # query
    my $sql = qq{
        SELECT DISTINCT ON (diag_id)
            diag_id,
            diag_instr_id,
            diag_name
        FROM
            $table t
        LEFT JOIN metadata.diagnostics d ON (t.measure_id = d.diag_id)
        WHERE measure_date_time BETWEEN ?::timestamp AND ?::timestamp
        AND diag_id > 1000
        ORDER BY 1;
    };

    # return
    $self->app->log->debug($sql);
    return $self->pg->db->query($sql, $date_from, $date_to)->hashes();
}

sub get_data_diags_by_station {
    my ( $self, $table, $date_from, $date_to, $diags ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdiagnostici sub get_data_diags_by_station");

    my $ext_fields = 'fulldate::timestamp';
    my $ext_conditions = '';
    my $inner_fields = 'fulldate text';
    my $inner_query = '';
    my @ids;
    my @ids_table;

    # query
    for my $diag (@{$diags}){
        my $diag_id = $diag->{'diag_id'};

        push @ids, $diag_id;
        push @ids_table, '('.$diag_id.')';

        $ext_fields .= ", field".$diag_id."[1] AS value_".$diag_id.", field".$diag_id."[2] AS class_".$diag_id;
        $inner_fields .= qq{, field$diag_id text[]};
    }

    my $string_ids = join(',',@ids);
    my $string_ids_table = join(',',@ids_table);
    my $final_query = qq{
        SELECT
            $ext_fields
        FROM crosstab('
            WITH p AS(
                SELECT
                    measure_id,
                    (''$date_from''::timestamp + interval ''60 minute'' * s.a)::timestamp AS measure_date_time
                FROM
                    ( VALUES  $string_ids_table ) p (measure_id)
                    CROSS JOIN generate_series(0,(EXTRACT(EPOCH FROM ''$date_to''::timestamp - ''$date_from''::timestamp)/3600)::integer) AS s(a)
                ORDER BY 1,2
            )
            SELECT
                p.measure_date_time::text ,
                ''field''||p.measure_id,
                ARRAY[
                    COALESCE(t.measure_value::text, ''nd''),
                    CASE
                        WHEN d.diag_min NOTNULL AND t.measure_value < d.diag_min THEN ''few-data''
                        WHEN d.diag_max NOTNULL AND t.measure_value > d.diag_max THEN ''no-data''
                        ELSE ''all-data''
                    END
                ]
            FROM
                p
            LEFT JOIN $table t USING (measure_id, measure_date_time)
            LEFT JOIN metadata.diagnostics d ON (t.measure_id = d.diag_id)
            WHERE measure_date_time BETWEEN ''$date_from''::timestamp AND ''$date_to''::timestamp
            AND measure_id IN ($string_ids)
            ORDER BY 1, 2
        ') AS horiz_table( $inner_fields );
    };

    # return data
    $self->app->log->debug($final_query);
    return $self->pg->db->query($final_query)->hashes();
}

1;

=head1 get_active_diags_by_stid

Funzione che recupera i diagnostici attivi associati ad una determinata stazione dal database.

Argomenti:  * nome della tabella dei dati della stazione ('table');

           * data d'inizio ('date_from');

           * data di fine ('date_to');

Return:     Risultato della query.

=cut

=head1 get_data_diags_by_station

Funzione che recupera, dato un certo periodo temporale, i dati diagnostici di una determinata stazione dal database.

Argomenti:  * nome della tabella dei dati della stazione ('table');

           * data d'inizio ('date_from');

           * data di fine ('date_to');

           * array dei diagnostici ('diags');

Return:     Risultato della query.

=cut