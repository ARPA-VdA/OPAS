#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : library-dbh-v2.pl
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#   Description : Library for managing dbh common routines
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# -- Enables 5.24 features ----------------------------------------------------
# enables the strict and warnings pragmas
use Modern::Perl '2014';
use DBI;
use Data::Dumper;

# dbh
our $dbh;
# log
our $log;
# test
my $TEST = 0;
return(1);

# dbh_connect() subroutine  -  connect to db server
sub dbh_connect {
    my $db_settings = shift; # get the database settings
    #$log->info( Dumper($db_settings) );

    $log->info("Connecting to PostgreSQL server ".$db_settings->{name}." ...");
    my ($dsn)  = "DBI:Pg:".
        "dbname=".$db_settings->{name}.
        ";host=".$db_settings->{host}.
        ";port=".$db_settings->{port}.
        ";application_name=".$db_settings->{app}."";

    # options
    # {AutoCommit => 0, RaiseError => 1, PrintError => 0}
    my (%attr) = ( AutoCommit => 0, PrintError => 1, RaiseError => 0 );

    # connection
    $dbh = DBI->connect($dsn, $db_settings->{user}, $db_settings->{pass}, \%attr) or
        bail_out("Cannot connect to database !");

    # Trace to a file
    #$dbh -> trace(1, 'tracelog.txt');

    return 1;
}

# dbh_disconnect() subroutine  -  disconnect from db server
sub dbh_disconnect {
    $log->info("Disconnecting from db ...");
    #$sth->finish();
    $dbh->disconnect();
}

# dbh_execute_query($sql) subroutine  -  execute the sql statement and check for errors
sub dbh_execute_query {
    my ($sql) = @_;

    # test only
    if ( $TEST  ) {
        # log log log
        $log->debug("TEST : $sql");
        # fake query
        $sql = 'SELECT 1'
    } else {
        # log log log
        $log->debug("Executing query : $sql");
    }

    # execute insert query
    my $sth = $dbh->prepare($sql) or $log->warn("Error : $DBI::errstr");
    return $sth->execute();# or $log->warn("Error : $DBI::errstr");
}

# dbh_execute_query_parameters(@params) subroutine  -  execute the sql statement with parameters and check for errors
sub dbh_execute_query_parameters {
    my ($sql, @params) = @_;

    # test only
    if ( $TEST  ) {
        # log log log
        $log->debug("TEST : $sql");
        # fake query
        $sql = 'SELECT 1'
    } else {
        # log log log
        $log->debug("Executing query : $sql, @params");
    }

    # execute insert query
    my $sth = $dbh->prepare($sql) or $log->warn("Error : $DBI::errstr");
    return $sth->execute( @params ); # or $log->warn("Error : $DBI::errstr");
}

# dbh_get_rows_arrayref($sql) subroutine  -  execute the sql statement and return the seleted rows
sub dbh_get_rows_arrayref {
    my $sql = shift; # get the query to execute

    # test only
    if ( $TEST  ) {
        # log log log
        $log->debug("TEST : $sql");
        # fake query
        $sql = 'SELECT 1'
    } else {
        # log log log
        $log->debug("Executing query : $sql");
    }

    # Prepare a SQL statement for execution
    my $sth = $dbh->prepare( $sql );

    # Execute the statement in the database
    $sth->execute(  );

    # get the stations id array
    my $rows = $sth->fetchall_arrayref({}) and $sth->finish;

    # return
    return $rows;
}

# dbh_get_rows_arrayref_by_parameters($sql, @params) subroutine  -  execute the sql statement and return the seleted rows
sub dbh_get_rows_arrayref_by_parameters {
    my ($sql, @params) = @_;

    # test only
    if ( $TEST  ) {
        # log log log
        $log->debug("TEST : $sql");
        # fake query
        $sql = 'SELECT 1'
    } else {
        # log log log
        $log->debug("Executing query : $sql, @params");
    }

    # Prepare a SQL statement for execution
    my $sth = $dbh->prepare( $sql );

    # Execute the statement in the database
    $sth->execute( @params ) or $log->info("Error : $DBI::errstr");

    # get the stations id array
    my $rows = $sth->fetchall_arrayref({}) and $sth->finish;

    # return
    return $rows;
}

# dbh_get_row_hashref($sql) subroutine  -  execute the sql statement and return the seleted row
sub dbh_get_row_hashref {
    my $sql = shift; # get the query to execute

    # test only
    if ( $TEST  ) {
        # log log log
        $log->debug("TEST : $sql");
        # fake query
        $sql = 'SELECT 1'
    } else {
        # log log log
        $log->debug("Executing query : $sql");
    }

    # log log log
    $log->debug("Getting row hashref: $sql ...");

    # Prepare a SQL statement for execution
    my $sth = $dbh->prepare( $sql );

    # Execute the statement in the database
    $sth->execute(  );

    # get the stations id array
    my $row = $sth->fetchrow_hashref() and $sth->finish;

    # return
    return $row;
}

# dbh_get_single_value($sql) subroutine  -  execute the sql statement and return seleted value
sub dbh_get_single_value {
    my $sql = shift; # get the query to execute

    # test only
    if ( $TEST  ) {
        # log log log
        $log->debug("TEST : $sql");
        # fake query
        $sql = 'SELECT 1'
    } else {
        # log log log
        $log->debug("Executing query : $sql");
    }

    # execute insert query
    my $sth = $dbh->prepare( $sql );
    $sth->execute( ) or $log->info("Error : $DBI::errstr");
    my $value = $sth->fetchrow_array();
    $sth->finish();

    # return
    return $value;
}
# dbh_get_single_value_parameters($sql, @params) subroutine  -  execute the sql statement with parameters and check for errors
sub dbh_get_single_value_parameters {
    my ($sql, @params) = @_;

    # test only
    if ( $TEST  ) {
        # log log log
        $log->debug("TEST : $sql");
        # fake query
        $sql = 'SELECT 1'
    } else {
        # log log log
        $log->debug("Executing query : $sql, @params");
    }

    # execute insert query
    my $sth = $dbh->prepare( $sql );
    $sth->execute( @params ) or $log->info("Error : $DBI::errstr");
    my $value = $sth->fetchrow_array();
    $sth->finish();

    # return
    return $value;
}


#
# common
# database dbh_escape_field($field) subroutine  -  escape text fields
#
sub dbh_escape_field {
    # log log log
    # $log->debug("Escaping field: $field", 3);

    my $field = shift;
    return 'null' unless defined $field;
    $field =~ s/^\s+|\s+$//g;
    $field =~ s/'/''/g;
    $field =~ s/\\/\\\\/g;
    return $field;
}

# database dbh_escape_quote_field($field) subroutine  -  escape text fields and quote it
sub dbh_escape_quote_field {
    # log log log
    # $log->debug("Escaping field: $field", 3);

    my $field = shift;
    return 'null' unless defined $field;
    $field =~ s/^\s+|\s+$//g;
    $field =~ s/'/''/g;
    $field =~ s/\\/\\\\/g;
    return "'$field'";
}

# database dbh_escape_boolean($field) subroutine  -  escape text fields
sub dbh_escape_boolean {
    # log log log
    # $log->debug("Escaping field: $field", 3);

    my $field = shift;
    return 'null' unless defined $field;
    return 'false' if ($field == 0);
    return 'true'  if ($field == 1);
}
