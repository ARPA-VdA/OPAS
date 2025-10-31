package Bobo::Plugin::FileSystem;
use Mojo::Base 'Mojolicious::Plugin';

use strict;
use warnings;
use Mojo::File qw(path);
use Mojolicious::Types;

use File::Basename;
use File::Copy;
use File::Find;
use File::Path qw(make_path remove_tree);
use File::Temp;
# use File::Type;

use Data::Dumper;
use Encode qw(decode_utf8);

# move_up
# move_down
# move_to
# create_dir
# rename_dir
# remove_dir
# create_file
# rename_file
# remove_file
# copy_file
# get_file_size
# get_file_last_mod
# get_file_type

sub register {
    my ( $self, $app ) = @_;

    $app->helper( 'get_parent' => sub {
        my $self       = shift;
        my $path       = shift;

            # log
        $self->app->log->debug("sub get_parent");

        $path = path($path);
        my @parts = @{$path->to_array};
        my $last_el = pop @parts;

        $self->app->log->debug("POP $last_el");
        if ($last_el eq 'public') {
            #it is not possible to navigate outside default url
            $self->app->log->debug("Last element PUBLIC");
            return $self->app->home->rel_file($self->config->{root}); 
        }

        my $parent = join '/', @parts;
        $self->app->log->debug("GET PARENT $parent");
        return $parent;
    });

    $app->helper( 'move_up' => sub {
        my $self       = shift;
        my $path       = shift;

            # log
        $self->app->log->debug("sub move_up");

        $path = $self->app->home->rel_file($path);

        unless (-e $path) {
            return -1;
        }

        my $types = Mojolicious::Types->new;

        my $parent = $self->get_parent($path);
        my @list;
        for my $item (path($parent)->list({dir => 1})->each) {

            my $is_file = 0;
            my $file_type;

            if( -f decode_utf8($item) ){
                $is_file = 1;
                $file_type = $types->file_type($item);
            }

            my $o = {
                rel_path => decode_utf8($item->to_rel($self->app->home->rel_file('/'))->to_string),
                basename => decode_utf8($item->to_rel($self->app->home->rel_file('/'))->basename),
                is_dir   => ! $is_file,
                is_file  => $is_file,
                is_image => ( $is_file && $file_type && ($file_type =~ /^image/) ? 1 : 0),
                ext      => ( $is_file ? $item->extname : undef)
            };

            push @list, $o;
        }

        my $res = {
            parent  => path($parent)->to_rel($self->app->home->rel_file('/'))->to_string,
            list    => \@list
        };

        return $res;
    });

    $app->helper( 'move_down' => sub {
        my $self       = shift;
        my $path       = shift;

            # log
        $self->app->log->debug("sub move_down");

        my $parent = $path;

        $path = path($path);
        my @parts = @{$path->to_array};
        my $last_el = pop @parts;

        if ($last_el eq 'public') {
            $self->app->log->debug("Last element PUBLIC");
            #it is not possible to navigate outside default url
            $parent = $self->config->{root};
            $path = $self->app->home->rel_file($self->config->{root}); 
        }
        else{
            $path = $self->app->home->rel_file($parent);
        }

        unless ( -e $path ){
            return -1;
        }

        my $types = Mojolicious::Types->new;

        my @list;
        
        for my $item (path($path)->list({dir => 1})->each) {

            my $is_file = 0;
            my $file_type;

            if( -f decode_utf8($item) ){
                $is_file = 1;
                $file_type = $types->file_type($item);
            };

            my $o = {
                rel_path => decode_utf8($item->to_rel($self->app->home->rel_file('/'))->to_string),
                basename => decode_utf8($item->to_rel($self->app->home->rel_file('/'))->basename),
                is_dir   => ! $is_file,
                is_file  => $is_file,
                is_image => ( $is_file && $file_type && ($file_type =~ /^image/) ? 1 : 0),
                ext      => ( $is_file ? $item->extname : undef)
            };

            push @list, $o;
        }

        my $res = {
            parent  => $parent,
            list    => \@list
        };

        return $res;
    });

    $app->helper( 'move_to' => sub {
        my $self       = shift;
        my $path_from  = shift;
        my $path_to    = shift;

            # log
        $self->app->log->debug("sub move_to");
        $self->app->log->debug("FROM $path_from");
        $self->app->log->debug("TO $path_to");

        unless ( -e $path_from ){
            return -1;
        }

        return move($path_from, $path_to);
    });

    $app->helper( 'create_dir' => sub {
        my $self       = shift;
        my $path       = shift;

        $self->app->log->debug("sub create_dir");

        my $rel_path = $self->app->home->rel_file($path);
        $self->app->log->debug("PATH $path");

        # log
        if ( -e $rel_path ){
            return -1;
        }
        else{

            eval{
                $path = make_path($rel_path, {chmod  => 0755});
            };

            # error check
            if ( $@ ) {
                $self->app->log->warn("Error: ".$@);
                return 0;
            }
            else {
                return 1;
            }
        }

    });

    $app->helper( 'rename_dir' => sub {
        my $self     = shift;
        my $path     = shift;
        my $new_name = shift;

        # log
        my $rel_path = $self->app->home->rel_file($path);
        unless (-e $rel_path || -d $rel_path){
            return 0;
        }

        my @parts = @{path($path)->to_array};

        my $last_el = pop @parts;
        if ($last_el eq 'public') {
            #it is not possible to rename public folder
            return 0; 
        }

        (push @parts, $new_name);
        my $new_path = join ('/', @parts);

        # check if path already exists
        # if true return conflict
        if( -e $self->app->home->rel_file($new_path) ){
            return -1;
        }

        eval{
            move($rel_path, $self->app->home->rel_file($new_path));
        };

        # error check
        if ( $@ ) {
            $self->app->log->warn("Error: ".$@);
            return 0;
        }
        else {
            return 1;
        }
    });

    $app->helper('remove_dir' => sub {
        my $self      = shift;
        my $path      = shift;
        my $recursive = shift;

        $self->app->log->debug("sub remove_dir");

        # log
        my $rel_path = $self->app->home->rel_file($path);
        # check if path exists and it is a directory
        unless (-e $rel_path || -d $rel_path){
            return 0;
        }

        my @parts = @{path($path)->to_array};
        my $last_el = pop @parts;
        if ($last_el eq 'public') {
            #it is not possible to remove public folder
            return 0; 
        }

        eval{
            if ($recursive == 1) {
                remove_tree($rel_path, {safe => 1});
            }
            else {
                rmdir($rel_path);
            }
        };

        # error check
        if ( $@ ) {
            $self->app->log->warn("Error: ".$@);
            return 0;
        }
        else {
            return 1;
        }
    });

    $app->helper('rename_file' => sub {
        my $self      = shift;
        my $path      = shift;
        my $new_name  = shift;

        $self->app->log->debug("sub rename_file");

        my $rel_path = $self->app->home->rel_file($path);
        unless (-e $rel_path || -f $rel_path){
            return 0;
        }

        $path = path($path);

        my $dir = $path->dirname;
        my $ext = $path->extname;

        my $new_file = $dir.'/'.$new_name.'.'.$ext;
        my $rel_new_file = $self->app->home->rel_file($new_file);
        
        if(-e $rel_new_file ){
            return -1;
        }

        eval{
            $rel_path->move_to($rel_new_file);
        };

        # error check
        if ( $@ ) {
            $self->app->log->warn("Error: ".$@);
            return 0;
        }
        else {
            return 1;
        }
    });

    $app->helper('remove_file' => sub {
        my $self      = shift;
        my $path      = shift;

        $self->app->log->debug("sub remove_file");

        my $rel_path = $self->app->home->rel_file($path);
        unless (-e $rel_path || -f $rel_path){
            return 0;
        }

        $path = path($path);

        my $dir = $path->dirname;
        my $name = $path->basename;

        # $self->app->log->debug("DIR $dir");
        # $self->app->log->debug("NAME $name");

        $self->create_dir($dir.'/.trash');
        my $rel_dir = $self->app->home->rel_file($dir.'/.trash');

        eval{
            $rel_path->move_to($rel_dir);
        };

        # error check
        if ( $@ ) {
            $self->app->log->warn("Error: ".$@);
            return 0;
        }
        else {
            return 1;
        }
    });
}

1;

=head1 get_parent

Restituisce il percorso padre di un file o directory

Argomenti:  * percorso del file o directory ('path')

Return:     * percorso padre    
=cut

=head1 move_up

Sposta la navigazione alla cartella superiore e restituisce la lista dei file/cartelle presenti.

Argomenti:  * percorso corrente

Return:     * hashref con percorso padre e lista degli elementi
=cut

=head1 move_down

Sposta la navigazione nella cartella selezionata e restituisce la lista dei file/cartelle presenti.

Argomenti:  * percorso della cartella

Return:     * hashref con percorso e lista degli elementi
=cut

=head1 move_to

Sposta un file o una cartella da un percorso a un altro.

Argomenti:  
* path_from: percorso di origine  
* path_to: percorso di destinazione

Return:     * risultato dell'operazione (1/0)
=cut

=head1 create_dir

Crea una nuova cartella nel percorso specificato.

Argomenti:  * percorso della nuova cartella

Return:     * 1 se creata, -1 se già esiste, 0 in caso di errore
=cut

=head1 rename_dir

Rinomina una cartella esistente.

Argomenti:  
* path: percorso della cartella da rinominare  
* new_name: nuovo nome della cartella

Return:     * 1 se rinominata, -1 se conflitto, 0 in caso di errore
=cut

=head1 remove_dir

Elimina una cartella (anche ricorsivamente se richiesto).

Argomenti:  
* path: percorso della cartella  
* recursive: 1 per eliminazione ricorsiva

Return:     * 1 se eliminata, 0 in caso di errore
=cut

=head1 rename_file

Rinomina un file esistente.

Argomenti:  
* path: percorso del file  
* new_name: nuovo nome del file (senza estensione)

Return:     * 1 se rinominato, -1 se conflitto, 0 in caso di errore
=cut

=head1 remove_file

Sposta un file nel cestino (cartella .trash).

Argomenti:  * percorso del file da eliminare

Return:     * 1 se spostato, 0 in caso di errore
=cut

