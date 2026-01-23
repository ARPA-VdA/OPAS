package Bobo::Model::DbangParametri;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text
use Mojo::JSON qw(decode_json encode_json);
use Encode qw(encode_utf8);
use utf8;

has 'pg';
has 'app';

# -----------------------------------------------------------------------------
# Getters
# -----------------------------------------------------------------------------
sub get_parameters_units {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbangParametri sub get_parameters_units");

    # query
    my $sql = qq{
        SELECT
            pm_unit_id, pm_unit_desc
        FROM
            metadata.parameters_unit
        ORDER BY
        (
            CASE
                WHEN pm_unit_id = 0 THEN 0
                ELSE 1
            END
        ), ascii( LOWER(pm_unit_desc));
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_parameters_types {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbangParametri sub get_parameters_types");

    # query
    my $sql = qq{
        SELECT
            pm_type_id, pm_type_desc, pm_type_icon, pm_type_colour
        FROM
            metadata.parameters_type
        ORDER
            BY pm_type_desc;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_all_parameters {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbangParametri sub get_all_parameters");

    # query
    my $sql = qq{
        SELECT
            parameter_id,
            parameter_name,
            parameter_unit,
            parameter_conv,
            parameter_unit_conv,
            parameter_offset,
            parameter_decimals,
            parameter_active,
            COALESCE(parameter_note, '--') AS parameter_note,
            parameter_shortname,
            parameter_extra_shortname,
            parameter_type_id,
            COALESCE(parameter_type_desc, '--') AS parameter_type_desc
        FROM
            metadata.view_parameters_info
        ORDER BY parameter_id;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_parameters_by_types {
    my ( $self, $types ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbangParametri sub get_parameters_by_types");

    # concatenate types ids for the query
    my $types_string = '{' . join(',', @{$types}) . '}';
    $self->app->log->debug("parameter type ids: $types_string");

    # query
    my $sql = qq{
        SELECT
            parameter_id,
            parameter_name,
            parameter_unit,
            parameter_conv,
            parameter_unit_conv,
            parameter_offset,
            parameter_decimals,
            parameter_active,
            COALESCE(parameter_note, '--') AS parameter_note,
            parameter_shortname,
            parameter_extra_shortname,
            parameter_type_id,
            COALESCE(parameter_type_desc, '--') AS parameter_type_desc
        FROM
            metadata.view_parameters_info
        WHERE parameter_type_id = ANY((?)::int[])
        ORDER BY parameter_id;
    };

    # return
    return $self->pg->db->query($sql, $types_string)->hashes();
}

sub get_parameter_instr_by_id {
    my ( $self, $param_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbangParametri sub get_parameter_instr_by_id");

    # query
    my $sql = qq{
        SELECT
            it.instr_type_id,
            CASE
                WHEN it.instr_type_id = 0 THEN 'Stazione'::text
                ELSE btrim((((c.constr_name || ' '::text) || b.brand_name) || ' '::text) || m.model_name)
            END AS instr_fullname,
            ca.category_name
        FROM
            equipments.instruments_type it
            LEFT JOIN equipments.constructors c USING (constr_id)
            LEFT JOIN equipments.brands b USING (brand_id)
            LEFT JOIN equipments.models m USING (model_id)
            LEFT JOIN equipments.categories ca USING (category_id)
        WHERE
            it.instr_type_id IN (
                SELECT UNNEST(instr_type_ids)
                FROM metadata.parameters_info
                WHERE param_id = ?
            )
        ORDER BY instr_fullname;
    };

    # return
    return $self->pg->db->query($sql, $param_id)->hashes;
}

sub insert_new_parameter {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbangParametri sub insert_new_parameter");
    $self->app->log->debug($params->{'param-name'});

    my $tx;
    my $new_prid;

    eval {
        $tx =  $self->pg->db->begin;

        # ##################################################################
        # 1- new parameter creation and returning id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbangParametri STEP 1");

        $new_prid = $self->pg->db->insert('metadata.parameters', {
            param_name      => $self->app->helperEscapeParam($params->{'param-name'}),
            param_unit      => $params->{'param-unit'},
            # gestito dal trigger metadata.f_update_param_current_conversion
            # param_conv      => $params->{'param-coef'}, DEFAULT 1
            param_unit_conv => $params->{'param-unit-conv'},
            param_decimals  => $params->{'param-dec'},
            param_active    => $self->app->helperGetBoolean($params, 'param-active'),
            param_note      => $self->app->helperEscapeParam($params->{'param-note'}),
            param_ext_id    => $self->app->helperEscapeParam($params->{'param-extra-id'})

        }, {returning => 'param_id'})->hash->{'param_id'};

        # ##################################################################
        # 2- additional information's insert by returned id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbangParametri STEP 2");


        $self->pg->db->insert('metadata.parameters_info', {
            param_id                => $new_prid,
            pm_info_shortname       => $self->app->helperEscapeParam($params->{'param-shortname'}),
            pm_info_extra_shortname => $self->app->helperEscapeParam($params->{'param-extra-shortname'}),
            pm_info_type_fk         => $params->{'param-type'},
            pm_info_obj             => $params->{'param-obj'}
        });

        # ##################################################################
        # 3- insert conversion
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbangParametri STEP 3");
        my $conv = decode_json(encode_utf8($params->{'new-coef'}));

        $self->pg->db->insert('metadata.parameters_conversions', {
            param_id         => $new_prid,
            pc_conv          => $conv->{'coef'},
            pc_from_fulldate => '-infinity',
            pc_to_fulldate   => 'infinity',
            pc_note          => $self->app->helperEscapeParam($conv->{'desc'})
        });

    };

    # error check
    if ($@) {
        $self->app->log->warn("Error: ".$@);
        if (index($@->{'message'}, 'metadata_parameters_conversions_check') != -1) {
            $self->app->log->debug("RETURN -1");
            return -1;
        }
        else {
            return 0;
        }
    }
    else {
       $tx->commit;
       return $new_prid;
    }
}

sub update_parameter {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbangParametri sub update_parameter");
    $self->app->log->debug($params->{'param-name'});

    my $tx;
    my $new_prid;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- parameter update on main table
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbangParametri STEP 1");

        $self->pg->db->update('metadata.parameters', {
            param_name      => $self->app->helperEscapeParam($params->{'param-name'}),
            param_unit      => $params->{'param-unit'},
            # gestito dal trigger metadata.f_update_param_current_conversion
            # param_conv      => $params->{'param-coef'}, DEFAULT 1
            param_unit_conv => $params->{'param-unit-conv'},
            param_decimals  => $params->{'param-dec'},
            param_active    => $self->app->helperGetBoolean($params, 'param-active'),
            param_note      => $self->app->helperEscapeParam($params->{'param-note'}),
            param_ext_id    => $self->app->helperEscapeParam($params->{'param-extra-id'})
        }, {param_id => $params->{'param-id'}});

        # ##################################################################
        # 2- parameter update on info table
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbangParametri STEP 2");

        $self->pg->db->update('metadata.parameters_info', {
            pm_info_shortname       => $self->app->helperEscapeParam($params->{'param-shortname'}),
            pm_info_extra_shortname => $self->app->helperEscapeParam($params->{'param-extra-shortname'}),
            pm_info_type_fk         => $params->{'param-type'},
            pm_info_obj             => $params->{'param-obj'}
        }, {param_id => $params->{'param-id'}});

        # ##################################################################
        # 3- delete conversions and insert new ones
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbangParametri STEP 3");

        my $conv = decode_json(encode_utf8($params->{'edit-coef'}));
        $self->pg->db->update('metadata.parameters_conversions', {
            pc_to_fulldate => $conv->{'to'} ne '' ? $self->app->helperGetFormattedFulldate($conv->{'to'}) : 'infinity',
            pc_note        => $self->app->helperEscapeParam($conv->{'desc'})
        }, {pc_id => $conv->{'id'}});

        if (defined $params->{'new-coef'}) {
            $conv = decode_json(encode_utf8($params->{'new-coef'}));
            $self->pg->db->insert('metadata.parameters_conversions', {
                param_id         => $params->{'param-id'},
                pc_conv          => $conv->{'coef'},
                pc_from_fulldate => $self->app->helperGetFormattedFulldate($conv->{'from'}),
                pc_to_fulldate   => 'infinity',
                pc_note          => $self->app->helperEscapeParam($conv->{'desc'})
            });
        }
    };

    # error check
    if ($@) {
        $self->app->log->warn("Error: ".$@);
        if (index($@->{'message'}, 'metadata_parameters_conversions_check') != -1) {
            $self->app->log->debug("RETURN -1");
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

sub delete_coefficient {
    my( $self, $id ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbangParametri delete_coefficient");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # query
        my $sql = qq{ DELETE FROM metadata.parameters_conversions WHERE pc_id = ? };

        $self->pg->db->query($sql, $id);
    };

    # error check
    if ($@) {
        # rollback
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
    else {
       $tx->commit;
       return 1;
    }
}

1;

=head1 get_parameters_units

Funzione che effettua il recupero delle unita' di misura di tutti i parametri dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_parameters_types

Funzione che effettua il recupero delle tipologie di parametri dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_all_parameters

Funzione che effettua il recupero delle informazioni di tutti i parametri dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_parameters_by_types

Funzione che effettua il recupero, dati uno o piu' id di tipologie di parametro, delle informazioni di una serie di parametri dal database.

Argomenti:  * array degli id delle tipologie di parametro ('types');

Return:     Risultato della query;

=cut

=head1 get_parameter_instr_by_id

Funzione che effettua il recupero, dato l'id, delle informazioni relative agli strumenti associabili ad un determinato parametro.

Argomenti:  * id del parametro ('param_id');

Return:     Risultato della query;

=cut

=head1 insert_new_parameter

Funzione che effettua l'inserimento di un nuovo parametro nel database.

Argomenti:  * oggetto contenente le informazioni del parametro ('params');

Return:     Se tutto OK, restituisce l'id del nuovo parametro;

        Se KO, restituisce 'undef'.

=cut

=head1 update_parameter

Funzione che effettua la modifica di un parametro nel database.

Argomenti:  * oggetto contenente le informazioni del parametro ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_coefficient

Funzione che effettua l'eliminazione di un fattore di conversione impostato per un determinato parametro dal database.

Argomenti:  * id del fattore di conversione ('id');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut