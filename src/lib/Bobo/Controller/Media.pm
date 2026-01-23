package Bobo::Controller::Media;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;

use File::Basename;
use Mojo::File 'path';

# This action will render a template
sub media {
    my $self = shift;

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    my $root = $self->config->{root};
    $self->stash(root => $root);

    $self->render('utilities/media');
    #$self->reply->exception('Division by zero!')->rendered(400);
}

sub check_permissions{
    my $self    = shift;
    my $grants  = shift;
    my $path    = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Media sub check_permissions");

    # sanity check
    # the user can only operate in the ../public/media folder
    unless( $path =~ /^public\/media/ ){
        return 0;
    }

    my @levels = split '/', $path;

    # check networks level
    my %vals_to_find = map { $_ => 1 } @{$grants->{networks}};
    if( 
        scalar(@levels) > 2 &&          # check navigation depth
        !defined $vals_to_find{ $levels[2] }   # check if user has visibility grants for the selected network
    ){
        return 0;
    }

    # check stations level
    %vals_to_find = map { $_ => 1 } @{$grants->{station_ids}};
    if( 
        scalar(@levels) > 3 &&          # check navigation depth
        $levels[3] =~ /^[0-9]+$/ &&     # check if the requested directory is a station's folder
        !defined $vals_to_find{ $levels[3] }   # check if user has visibility grants for the selected station
    ){
        return 0;
    }

    return 1;
}

sub navigate_filesystem{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Media sub navigate_filesystem");

    my $userid = $self->session('it.ecometer.bobo');

    # my $user_id = $self->session('it.ecometer.bobo');
    my $path = $self->param('path'); # post
    my $dir = $self->param('dir'); # post

    $self->app->log->debug("PATH: $path");
    $self->app->log->debug("DIRECTION: $dir");

    my $json;

    # check permission for requested path
    my $grants = $self->dbcommon->get_user_station_media_grants($userid);
    unless( $self->check_permissions($grants, $path) ){
    
        $json = {
            res  => "ERR",
            msg => "Permesso negato"
        };

        # render
        $self->render(json => $json);
        return;
    }

    my $res;
    if($dir eq 'up'){
        $res = $self->move_up($path);
    }
    else{
        $res = $self->move_down($path);
    }

    # check visibility permission for elements inside the selected directory
    my @levels = split '/', $res->{parent};
    if( scalar(@levels) == 2){
        $self->app->log->debug("Livello 2");

        # crea un hash nella forma { "rete": 1, "rete2": 1, "rete3": 1, ... }
        my %vals_to_find = map { $_ => 1 } @{$grants->{networks}}; # qw( arpavda arpae )

        # genera un array temporaneo filtrando gli elementi dall'array originale
        # vengono mantenuti solo gli elementi su cui l'utente ha i permessi 
        # contenuti nell'hash %vals_to_find
        my @filtered_list = grep { $vals_to_find{ $_->{basename} } } @{ $res->{list} };

        # sostituisci l'array originale con quello filtrato
        $res->{list} = \@filtered_list;

    }
    elsif( scalar(@levels) == 3){
        $self->app->log->debug("Livello 3");

        my %names_map;
        @names_map{@{$grants->{station_ids}}} = @{$grants->{station_names}};

        # crea un hash nella forma { "1000": 1, "1002": 1, "9999": 1, ... }
        my %vals_to_find = map { $_ => 1 } @{$grants->{station_ids}}; # qw( 1000 1002 )

        # genera un array temporaneo filtrando gli elementi dall'array originale
        # vengono mantenuti solo gli elementi su cui l'utente ha i permessi (stazioni e nuove directory)
        # le stazioni sono contenute nell'hash %vals_to_find e il nome delle directory è costituito da soli numeri (station_id)
        my @filtered_list = grep { ( !($_->{basename} =~ /^[0-9]+$/) || $vals_to_find{ $_->{basename} }) } @{ $res->{list} };

        # aggiungi il campo "editable" a true per le directory create dagli utenti 
        # e che non sono riconducibili ad una stazione
        local *check = sub { 
            if( $_->{basename} =~ /^[0-9]+$/ ){
                $_->{editable} = 0;
                $_->{station} = @names_map{ $_->{basename} };
            }
            else{
                $_->{editable} = 1;
            }
            return $_;
        };

        my @formatted_list = map { check($_) } @filtered_list;

        # sostituisci l'array originale con quello filtrato
        $res->{list} = \@formatted_list;
    }

    if($res == -1){
        $json = {
            res => "ERR",
            msg => "Non è stato possibile aprire la cartella selezionata"
        };
    }
    else{
        $json = {
            res  => "OK",
            dir => $res
        };
    }

    # render
    $self->render(json => $json);
}

sub put_folder{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Media sub put_folder");

    my $userid = $self->session('it.ecometer.bobo');

    my $path = $self->param('path'); # post
    my $name = $self->param('name'); # post
    my $source = $self->param('source'); # post

    $self->app->log->debug($path);
    $self->app->log->debug($source);

    my $json;

    # check permission for requested path
    my $grants = $self->dbcommon->get_user_station_media_grants($userid);
    unless( $self->check_permissions($grants, $path) ){
    
        $json = {
            res  => "ERR",
            msg => "Permesso negato"
        };

        # render
        $self->render(json => $json);
        return;
    }

    $self->app->log->debug("PATH: $path");
    $self->app->log->debug("FOLDER: $name");
    my $res;
    # if not null then it's a rename action
    if($source eq ''){
        $self->app->log->debug("create_dir");
        $res = $self->create_dir($path.'/'.$name);
    }
    else{
        $self->app->log->debug("rename_dir");
        $res = $self->rename_dir($source, $name);
    }

    if($res == -1){
        $json = {
            res => "CONFLICT"
        };
    }
    elsif($res == 0){
        $json = {
            res => "ERR"
        }
    }
    else{
        $json = {
            res  => "OK"
        };
    }

    # render
    $self->render(json => $json);
}

sub put_files{
    my $self = shift;
    # log
    $self->app->log->debug("Bobo::Controller::Media sub put_files");
    # dump post data (with user infos)
    # $self->helperDumperPostData('Media', 'put_files', $self->req->body_params);

    # get params from ajax
    my $params  = $self->req->body_params->to_hash;

    # Uploading FILES
    my $files = $self->req->uploads('files');

    my $file_base_dir = $params->{'path'};
    $self->app->log->debug( "DIR path: $file_base_dir" );

    my $json;

    my $userid = $self->session('it.ecometer.bobo');
    # check permission for requested path
    my $grants = $self->dbcommon->get_user_station_media_grants($userid);
    unless( $self->check_permissions($grants, $file_base_dir) ){
    
        $json = {
            res => "ERR",
            msg => "Permesso negato"
        };

        # render
        $self->render(json => $json);
        return;
    }

    eval{
        my $file_dir = $self->app->home->rel_file($file_base_dir);
        # loop through files
        for my $file (@{$files}) {

            # check if the file is an image by recevoring the content type
            $self->app->log->debug($file->headers->content_type);
            my $content_type = $file->headers->content_type;

            # get filename
            my $original_name = $file->filename;
            # $self->app->log->debug( "Filename: $original_name" );
            # parse the file name and get name, path and extension
            my ($fp_name,$p_path,$p_ext) = fileparse($original_name, qr"\..[^.]*$");

            my $full_file_name = $file_dir."/".$original_name;
            $self->app->log->debug( "FULL filename: $full_file_name ");

            if(-e $full_file_name ){
                $self->app->log->debug( "file exists!");
                my $cnt = 0;
                # add a counter to the filename in order to prevent conflicts
                # foreach number check if file already exists
                do{
                    $cnt++;
                    $full_file_name = $file_dir."/".$fp_name.'('.$cnt.')'.$p_ext;
                }
                while( -e $full_file_name )
            }
            # copy file in the selected directory
            $file->move_to($full_file_name);
        }
    };

    # error check
    if ( $@ ) {
        $self->app->log->warn("Error: ".$@);
        # render
        $json = {
            res => "ERR"
        };

        # render
        $self->render(json => $json);
    }
    else {
        # render
        $json = {
            res => "OK"
        };

        # render
        $self->render(json => $json);
    }
}

sub put_file_name{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Media sub put_file_name");

    # my $user_id = $self->session('it.ecometer.bobo');
    my $path = $self->param('path'); # post
    my $name = $self->param('name'); # post

    $self->app->log->debug("PATH: $path");
    $self->app->log->debug("NAME: $name");

    my $userid = $self->session('it.ecometer.bobo');
    # check permission for requested path
    my $grants = $self->dbcommon->get_user_station_media_grants($userid);
    unless( $self->check_permissions($grants, $path) ){
    
        my $json = {
            res  => "ERR",
            msg => "Permesso negato"
        };

        # render
        $self->render(json => $json);
        return;
    }

    my $res = $self->rename_file($path, $name);
    my $json;
    if($res == -1){
        $json = {
            res => "CONFLICT"
        };
    }
    elsif($res == 0){
        $json = {
            res => "ERR"
        }
    }
    else{
        $json = {
            res  => "OK"
        };
    }

    # render
    $self->render(json => $json);
}

sub del_folder{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Media sub del_file");

    # my $user_id = $self->session('it.ecometer.bobo');
    my $path = $self->param('path'); # post

    $self->app->log->debug("PATH: $path");

    my $userid = $self->session('it.ecometer.bobo');
    # check permission for requested path
    my $grants = $self->dbcommon->get_user_station_media_grants($userid);
    unless( $self->check_permissions($grants, $path) ){
    
        my $json = {
            res  => "ERR",
            msg => "Permesso negato"
        };

        # render
        $self->render(json => $json);
        return;
    }

    my $res = $self->remove_dir($path, 1);

    # my $res = 1;
    my $json;
    if($res == 1){
        $json = {
            res => "OK"
        };
    }
    else{
        $json = {
            res  => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

sub del_file{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Media sub del_file");

    # my $user_id = $self->session('it.ecometer.bobo');
    my $path = $self->param('path'); # post

    $self->app->log->debug("PATH: $path");

    my $userid = $self->session('it.ecometer.bobo');
    # check permission for requested path
    my $grants = $self->dbcommon->get_user_station_media_grants($userid);
    unless( $self->check_permissions($grants, $path) ){
    
        my $json = {
            res  => "ERR",
            msg => "Permesso negato"
        };

        # render
        $self->render(json => $json);
        return;
    }

    my $res = $self->remove_file($path);
    my $json;
    if($res == 1){
        $json = {
            res => "OK"
        };
    }
    else{
        $json = {
            res  => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

1;

=head1 media

Render della pagina di visualizzazione dei file multimediali.  

Argomenti:  /

Return:     /

=cut

=head1 check_permissions

Verifica se l'utente ha i permessi necessari per accedere al percorso richiesto.

Argomenti:  
* grants: hashref dei permessi dell'utente
* path: percorso da verificare

Return:    
* 1 se permesso, 0 altrimenti

=cut

=head1 navigate_filesystem

Gestisce la navigazione tra le cartelle del filesystem multimediale, applicando i permessi utente.

Argomenti:  
* path: percorso corrente
* dir: direzione di navigazione (up/down)

Return:    
* JSON con la lista delle cartelle/file accessibili

=cut

=head1 put_folder

Crea una nuova cartella o rinomina una cartella esistente nel filesystem multimediale.

Argomenti:  
* path: percorso della cartella padre
* name: nome della nuova cartella o nuovo nome
* source: percorso della cartella da rinominare (opzionale)

Return:    
* JSON con esito dell'operazione

=cut

=head1 put_files

Carica uno o più file nella cartella specificata, gestendo eventuali conflitti di nome.

Argomenti:  
* path: percorso della cartella di destinazione
* files: lista dei file da caricare

Return:    
* JSON con esito dell'operazione

=cut

=head1 put_file_name

Rinomina un file esistente nel filesystem multimediale.

Argomenti:  
* path: percorso del file da rinominare
* name: nuovo nome del file

Return:    
* JSON con esito dell'operazione

=cut

=head1 del_folder

Elimina una cartella e tutto il suo contenuto dal filesystem multimediale.

Argomenti:  
* path: percorso della cartella da eliminare

Return:    
* JSON con esito dell'operazione

=cut

=head1 del_file

Elimina un file dal filesystem multimediale.

Argomenti:  
* path: percorso del file da eliminare

Return:    
* JSON con esito dell'operazione

=cut
