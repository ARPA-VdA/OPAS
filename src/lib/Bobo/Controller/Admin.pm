package Bobo::Controller::Admin;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw(decode_utf8 encode_utf8);
use Data::Dumper;

use Mojo::File 'path';

# This action will render a template
sub admin {
    my $self = shift;

    my $userid = $self->session('it.ecometer.bobo');
    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $portals  = $self->dbadmin->get_portals();
    $self->stash(portals => $portals);

    my $groups = $self->dbadmin->get_linked_groups_byadmin($userid);
    $self->stash(groups => $groups);

    my $comps  = $self->dbadmin->get_linked_comps_byadmin($userid);
    $self->stash(comps => $comps);

    my $networks  = $self->dbcommon->get_all_networks($userid);
    $self->stash(networks => $networks);

    my $pages = $self->dboptions->get_pages_icon($userid);
    $self->stash(pages => $pages);

    # get provinces
    my $provinces = $self->dbcommon->get_all_provinces($userid );
    $self->stash(provinces => $provinces);

    my $params = $self->dbadmin->get_all_parameters();
    $self->stash(params => $params);

    my $codes = $self->dbcommon->get_finalval();
    $self->stash(codes => $codes);

    $self->render('utente/admin');
}

sub get_groups {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub get_groups");

    my $userid = $self->session('it.ecometer.bobo');

    # get groups associated with the portal
    my $groups = $self->dbadmin->get_linked_groups_byadmin($userid);

    my $json = {
        res => "OK",
        groups => $groups
    };

    $self->render(json => $json);
}

sub get_users {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub get_users");

    my $userid = $self->session('it.ecometer.bobo');
    my $grid = $self->param('grid'); # post

    # get users associated with the portal
    my $users = $self->dbadmin->get_users($userid, $grid);

    my $json = {
        res => "OK",
        users => $users
    };

    $self->render(json => $json);
}

sub get_user_byid {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub get_user_byid");

    my $userid = $self->param('id'); # post
    $self->app->log->debug("User id: $userid");;

    # get users associated with the portal
    my $user = $self->dbcommon->get_user_byid($userid);

    my $json = {
        res => "OK",
        user => $user
    };

    $self->render(json => $json);
}

sub get_comp_detail {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub get_comp_detail");

    my $compid = $self->param('compid'); # post
    $self->app->log->debug("Company id: $compid");;

    # get company by id sent by an ajax call
    my $comp = $self->dbcommon->get_comp_detail_byid($compid);

    my $json = {
        res => "OK",
        comp => $comp
    };

    $self->render(json => $json);
}

sub get_groups_detail {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub get_groups_detail");

    my @groups_id = decode_json($self->param('groups_id')); # post
    $self->app->log->debug("Groups id:");
    $self->helperDumper( @groups_id );

    # get company by id sent by an ajax call
    my $menu = $self->dbadmin->get_groups_menu(@groups_id);
    my $stations = $self->dbadmin->get_groups_stations(@groups_id);

    my $json = {
        res => "OK",
        menu => $menu,
        stations => $stations
    };

    $self->render(json => $json);
}

sub get_group_pages_grants {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub get_group_pages_grants");

    my $userid = $self->session('it.ecometer.bobo');

    my $grid = $self->param('grid'); # post
    $self->app->log->debug("Group id: $grid");

    # get group pages grants by an ajax call
    my $pages = $self->dbadmin->get_group_pages_grants($userid, $grid);
    my $admin = $self->dbadmin->get_admin_pages_grants($userid);

    my $json;
    if (defined $pages) {
        $json = {
            res => "OK",
            pages => $pages,
            admin => $admin
        };
    }
    else {
       $json = {
            res => "ERR"
        };
    }

    $self->render(json => $json);
}

sub get_group_stations_grants {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub get_group_stations_grants");

    my $userid = $self->session('it.ecometer.bobo');

    my $grid = $self->param('grid'); # post
    my $prid = $self->param('prid'); # post
    my $netid = $self->param('netid'); # post
    $self->app->log->debug("Group id: $grid");
    $self->app->log->debug("Province id: $prid");
    $self->app->log->debug("Network id: $netid");

    # get group stations grants by an ajax call
    my $stations = $self->dbadmin->get_group_stations_grants($userid, $grid, $prid, $netid);

    my $json;

    if (defined $stations) {
        $json = {
            res => "OK",
            stations => $stations
        };
    }
    else {
       $json = {
            res => "ERR"
        };
    }

    $self->render(json => $json);
}

sub get_group_others_grants {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub get_group_others_grants");

    my $userid = $self->session('it.ecometer.bobo');

    my $grid = $self->param('grid'); # post
    $self->app->log->debug("Group id: $grid");

    # get group pages grants by an ajax call
    my $nets = $self->dbadmin->get_group_networks_grants($userid, $grid);
    my $widgets = $self->dbadmin->get_group_widgets_grants($userid, $grid);
    my $channels = $self->dbadmin->get_group_channels_grants($userid, $grid);
    my $codes = $self->dbadmin->get_group_codes_grants($userid, $grid);

    my $json = {
        res     => "OK",
        nets    => $nets,
        widgets => $widgets,
        channels => $channels,
        codes    => $codes
    };

    $self->render(json => $json);
}

sub recover_user_password {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub recover_user_password");

    my $id = $self->param('id');
    my $user = $self->dbcommon->get_user_byid($id);

    # update returning new password
    my $new_pwd = $self->dbmain->recover_password( $user->{'user_email'} );
    my $res;

    # insert into db to sending email with new password
    if (defined $new_pwd) {
        $self->app->log->debug("Password changed: insert into db to sending email");

        my @email_recipients;
        push @email_recipients, $user->{'user_email'};

        my $email_title = $user->{'portal_footer_text'};
        my $email_subject = '[NO REPLY] Nuove credenziali di accesso';
        my $email_body ='<p>Gentile Utente,<br>';
        $email_body .= 'A seguito della richiesta inoltrata dall\'amministratore del portale, Le abbiamo inviato le nuove credenziali di accesso.</p>';
        $email_body .= '<p>Al primo login Le verr&agrave; richiesto di modificare la password.</p>';
        $email_body .= '<p>Nuova password: <strong>'.$new_pwd. '</strong></p>';
        $email_body .= '<p>Cordiali saluti</p>';

        my $email_logo = $self->config->{logo_mail};

        if ($self->helperSendEmailHTML($email_title, $email_subject , decode_utf8($email_body), $email_logo, @email_recipients)) {
            $res = 1;
        }
    }
    else {
        $res = 0;
    }

    $self->render(json => $res);
}

# !! IMPOSTAZIONI PORTALE
sub get_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Admin sub get_options");

    my $userid = $self->session('it.ecometer.bobo');
    $self->app->log->debug("User id: $userid");

    # get users associated with the portal
    my $user = $self->dbcommon->get_user_byid($userid);

    my $validation_options = $self->dbadmin->get_final_validation_options( $user->{'portal_id'} );

    my $json = {
        res => "OK",
        validation => $validation_options
    };

    # render
    $self->render(json => $json);
}


sub put_group {
    my $self = shift;
    $self->app->log->debug("Bobo::Controller::Admin  sub put_group");
    $self->helperDumperPostData('Admin', 'put_group', $self->req->body_params);

    my $res = 1;
    my $params = $self->req->body_params->to_hash;
    my $us_admin = $self->session('it.ecometer.bobo');
    # get params from ajax
    my $gr_id =  $params->{'new-group-id'};

    # if arg_id defined -> edit report
    if (defined $gr_id && $gr_id ne "") {

        $self->app->log->debug("Bobo::Controller::Admin edit of group");

        $res = $self->dbadmin->update_group( $params );
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Admin insert of new group");

        $gr_id = $self->dbadmin->insert_new_group( $us_admin, $params );
    }

    # check result
    if (defined $gr_id && $res == 1) {
        $self->app->log->debug('Result: OK');
        $self->render(json => $res);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub put_user {
    my $self = shift;
    $self->app->log->debug("Bobo::Controller::Admin  sub put_user");
    $self->helperDumperPostData('Admin', 'put_user', $self->req->body_params);

    my $res = 1;
    my $params = $self->req->body_params->to_hash;
    my $us_admin = $self->session('it.ecometer.bobo');
    # get params from ajax
    my $user_id =  $params->{'new-user-id'};

    # if arg_id defined -> edit report
    if (defined $user_id && $user_id ne "") {
        $self->app->log->debug("Bobo::Controller::Admin edit of user");

        # 1- modifica utente
        # 2- modifica metadata (comp_id) dell'utente
        # 3- eliminazione associazioni utente-gruppi e inserimento nuove associazioni
        $res = $self->dbadmin->update_user($params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Admin insert of new user");

        # check se esiste già un utente con quella mail
        my $user = $self->dbmain->get_user_bymail($params->{'new-user-email'});
        if (defined $user) {
            $self->app->log->debug("Bobo::Controller::Admin this email already exists");
            $res = -1;
        }
        else {
            $user_id = $self->dbadmin->insert_new_user($us_admin, $params);

            if (defined $user_id) {
                # 4- se tutto a buon fine, invio mail con la password temporanea
                # update returning new password
                my $user = $self->dbmain->get_user_byid($user_id);
                my $new_pwd = $self->dbmain->recover_password($params->{"new-user-email"});

                # insert into db to sending email with new password
                if (defined $new_pwd) {
                    $self->app->log->debug("Created a new password for the new user: insert into db to sending email");
                    # my $config = $self->app->plugin('Config');

                    my @email_recipients;
                    push @email_recipients, $params->{"new-user-email"};

                    $self->app->log->debug($self->config->{url});

                    my $email_title = $user->{'portal_footer_text'};
                    my $email_subject = '[NO REPLY] Benvenuto nel portale '.$user->{'portal_name'};
                    my $email_body ='<p>Gentile Utente,<br>';
                    $email_body .= 'A seguito della richiesta di creazione di un nuovo account, Le abbiamo inviato le credenziali di accesso.</p>';
                    $email_body .= '<p>Al primo login Le verrà richiesto di modificare la password.</p>';
                    $email_body .= '<p>Username: <strong>'.$params->{"new-user-email"}. '</strong></p>';
                    $email_body .= '<p>Password: <strong>'.$new_pwd.'</strong></p>';

                    if (defined $user->{'portal_link'}) {
                        $email_body .= '<p>Per effettuare l\'accesso cliccare sul seguente link: <a href="'.$user->{'portal_link'}.'" target ="_blank">'.$user->{'portal_link'}.'</a></p>';
                    }
                    else {
                        $email_body .= '<p>Per effettuare l\'accesso collegarsi al link fornito dal vostro amministratore.</p>';
                    }
                    $email_body .= '<p>Cordiali saluti</p>';

                    my $email_logo = $self->config->{logo_mail};

                    $res = $self->helperSendEmailHTML($email_title, $email_subject , $email_body, $email_logo, @email_recipients);
                }
            }
            else {
                $res = 0;
            }
        }
        # 1- creazione nuovo utente e recupero id
        # 2- associazione nuovo utente con portal_id dell'admin e azienda selezionata nel form
        # 3- associazione nuovo utente con i gruppi selezionati nel from

    }

    # se andato tutto a buon fine mi occupo dei file
    if (defined $user_id && $res == 1) {
        # Caricamento FILES sia per INSERT che per UPDATE
        my $file = $self->req->upload('file');

        if (defined $file) {
            my $basepath;
            my $admin = $self->dbmain->get_user_byid($us_admin);

            if (defined $admin->{'portal_basepath'}) {
                $basepath = $admin->{'portal_basepath'};
            }
            else {
                $basepath = '/bobo-img/default';
            }

            my $user_file = sprintf("%06d", $user_id);
            $self->app->log->debug("user_file: $user_file");
            my $file_base_dir = $basepath .'/avatar/'.$user_file;
            my $file_dir = $self->app->static->paths->[0] . $file_base_dir;
            $self->helperCreatePath($file_dir);

            my $file_name = $self->helperFileUploadGetFileId() . ".jpg";
            my $full_file_name = $file_dir."/".$file_name;

            $file->move_to($full_file_name);
            $self->helperImageCreateThumbanail($file_name, $file_dir);

            $res = $self->dbadmin->update_avatar($user_id, $file_base_dir.'/'.$file_name);

        } # END defined file
    } # END defined rpid & res = TRUE

    $self->render(json => $res);
}

sub put_group_pages_grants {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub put_group_pages_grants");

    my $grants = $self->param('grants');
    $grants = decode_json(encode_utf8($grants));

    my $grid = $self->param('grid'); # post
    my $pgid = $self->param('pgid'); # post

    my $res = 1;

    if ($grants->{'visible'}) { # eseguo l'insert o se gia presente l'update dei permessi
        $self->app->log->debug("Page visible");

        $res = $self->dbadmin->insert_page_grants($grid, $pgid, $grants);
    }
    else { # elimino la pagina dal gruppo
        $self->app->log->debug("Page not visible");

        $res = $self->dbadmin->delete_page_grants($grid, $pgid);
    }

    $self->render(json => $res);
}

sub put_group_stations_grants {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub put_group_stations_grants");
    $self->helperDumperPostData('Admin', 'put_group_stations_grants', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;

    my $grid = $params->{'grid'}; # post
    my $grants = decode_json(encode_utf8($params->{'grants'}));

    my $res = 1;

    if ($self->dbadmin->update_stations_grants($grid, $grants)) { #
        $self->app->log->debug("Success");
    }
    else { # elimino la pagina dal gruppo
        $self->app->log->debug("Error");
        $res = 0;
    }

    $self->render(json => $res);
}

sub put_group_others_grants {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub put_group_others_grants");

    my $grant = $self->param('grant');
    $self->app->log->debug("$grant");

    my $grid = $self->param('grid'); # post
    my $id = $self->param('id'); # post
    my $type = $self->param('type'); # post

    my $res = 1;

    if ($type eq 'net') {
        if ($grant eq 'true') { # eseguo l'insert o se gia presente l'update dei permessi
            $self->app->log->debug("Network visible");

            $res = $self->dbadmin->insert_network_grants($grid, $id);
        }
        else { # elimino la rete dal gruppo
            $self->app->log->debug("Network not visible");

            $res = $self->dbadmin->delete_network_grants($grid, $id);
        }

    }
    if ($type eq 'code') {
        if ($grant eq 'true') { # eseguo l'insert o se gia presente l'update dei permessi
            $self->app->log->debug("Code visible");

            $res = $self->dbadmin->insert_final_code_grants($grid, $id);
        }
        else { # elimino il codice dal gruppo
            $self->app->log->debug("Code not visible");

            $res = $self->dbadmin->delete_final_code_grants($grid, $id);
        }

    }
    elsif ($type eq 'widget') {

        if ($grant eq 'true') { # eseguo l'insert o se gia presente l'update dei permessi
            $self->app->log->debug("Widget visible");

            $res = $self->dbadmin->insert_widget_grants($grid, $id);
        }
        else { # elimino il widget dal gruppo
            $self->app->log->debug("Widget not visible");

            $res = $self->dbadmin->delete_widget_grants($grid, $id);
        }
    }
    else {
        # parametro
    }

    $self->render(json => $res);
}

sub put_group_channels_grants {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub put_group_channels_grants");

    my $grants = $self->param('grants');
    $grants = decode_json(encode_utf8($grants));

    my $grid = $self->param('grid'); # post
    my $chid = $self->param('chid'); # post

    my $res = 1;

    if ($grants->{'visible'}) { # eseguo l'insert o se gia presente l'update dei permessi
        $self->app->log->debug("Channel visible");

        $res = $self->dbadmin->insert_channel_grants($grid, $chid, $grants);
    }
    else { # elimino la pagina dal gruppo
        $self->app->log->debug("Channel not visible");

        $res = $self->dbadmin->delete_channel_grants($grid, $chid);
    }

    $self->render(json => $res);
}

sub put_widget_destination {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub put_widget_destination");

    my $params  = $self->req->body_params->to_hash;

    my $grid = $params->{'grid'}; # post
    my $wdgid = $params->{'id'}; # post
    my $dest = $params->{'obj'}; # post

    my $res = $self->dbadmin->update_widget_destination($grid, $wdgid, $dest);

    $self->render(json => $res);
}

# !! IMPOSTAZIONI PORTALE
sub put_validation_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Admin sub put_validation_options");

    my $params  = $self->req->body_params->to_hash;

    my $userid = $self->session('it.ecometer.bobo');
    $self->app->log->debug("User id: $userid");

    # get users associated with the portal
    my $user = $self->dbcommon->get_user_byid($userid);
    my $obj  = $params->{'obj'}; # post

    my $res = $self->dbadmin->insert_validation_options($user->{'portal_id'}, $obj);

    # render
    $self->render(json => $res);
}

sub del_group {
    my $self = shift;

    $self->app->log->debug("Bobo::Controller::Admin sub del_group");

    my $grid = $self->param('id');

    my $res = $self->dbadmin->delete_group($grid);

    $self->render(json => $res);
}

1;

=head1 admin

Render della pagina di amministrazione.

Argomenti:  /

Return:     /

=cut

=head1 get_groups

Funzione per recuperare i gruppi disponibili sul portale.

Argomenti:  * id dell'utente ('userid');

Return:     json contenente la risposta "OK" e i gruppi.

=cut

=head1 get_users

Funzione per recuperare gli utenti disponibili sul portale.

Argomenti:  * id dell'utente ('userid');

           * id del gruppo, se presente ('grid');

Return:     json contenente la risposta "OK" e gli utenti.

=cut

=head1 get_user_byid

Funzione per recuperare, dato l'id, le informazioni di un determinato utente presente sul portale.

Argomenti:  * id dell'utente ('id');

Return:     json contenente la risposta "OK" e l'utente.

=cut

=head1 get_comp_detail

Funzione per recuperare, dato l'id, le informazioni di una determinata azienda.

Argomenti:  * id dell'azienda ('compid');

Return:     json contenente la risposta "OK" e l'azienda.

=cut

=head1 get_groups_detail

Funzione per recuperare, dati gli id, le informazioni (menu e stazioni visibili) di uno o piu' gruppi.

Argomenti:  * array degli id dei gruppi ('groups_id');

Return:     json contenente, se presenti, la risposta "OK", il menu e le stazioni visibili
dal/dai gruppo/gruppi.

=cut

=head1 get_group_pages_grants

Funzione per recuperare, dato l'id, i permessi alle pagine di un determinato gruppo.

Argomenti:  * id del gruppo ('grid');

Return:     json contenente la risposta "OK" e i permessi, oppure solamente la risposta "ERR".

=cut

=head1 get_group_stations_grants

Funzione per recuperare, dato l'id, i permessi sulle stazioni di un determinato gruppo.

Argomenti:  * id dell'utente ('userid');

           * id del gruppo ('grid');

           * id della provincia, se presente ('prid');

           * id della rete, se presente ('netid');

Return:     json contenente la risposta "OK" e i permessi, oppure solamente la risposta "ERR".

=cut

=head1 get_group_others_grants

Funzione per recuperare, dato l'id, i permessi sugli altri applicativi di un determinato gruppo.

Argomenti:  * id dell'utente ('userid');

           * id del gruppo ('grid');

Return:     json contenente la risposta "OK" e i permessi.

=cut

=head1 recover_user_password

Funzione per recuperare, dato l'id, la password di un determinato utente.

Argomenti:  * id dell'utente ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 get_options

Funzione per recuperare le impostazioni di validazione multilivello.

Argomenti:  * id dell'utente ('userid');

Return:     json contenente la risposta "OK" e le impostazioni.

=cut

=head1 put_group

Funzione per inserire/modificare un gruppo.

Argomenti:  * oggetto contenente le informazioni del gruppo da inserire/modificare ('params');

           * id dell'utente amministratore ('us_admin');

           * id del gruppo, se presente: UPDATE ('new-group-id');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut

=head1 put_user

Funzione per inserire/modificare un utente, con i relativi allegati.

Argomenti:  * oggetto contenente le informazioni dell'utente da inserire/modificare ('params');

           * id dell'utente amministratore ('us_admin');

           * id dell'utente, se presente: UPDATE ('new-user-id');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut

=head1 put_group_pages_grants

Funzione per inserire/modificare, oppure eliminare, i permessi sulle pagine di un determinato gruppo.

Argomenti:  * oggetto contenente le pagine con i relativi permessi ('grants');

           * id del gruppo ('grid');

           * id della pagina ('pgid');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut

=head1 put_group_stations_grants

Funzione per modificare i permessi sulle stazioni di un determinato gruppo.

Argomenti:  * id del gruppo ('grid');

           * oggetto contenente le stazioni con i relativi permessi ('grants');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut

=head1 put_group_others_grants

Funzione per inserire/modificare, oppure eliminare, i permessi sugli altri applicativi di un determinato gruppo.

Argomenti:  * oggetto contenente i permessi ('grant');

           * id del gruppo ('grid');

           * id della rete/widget ('id');

           * id tipologia applicativo ('type');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut

=head1 put_group_channels_grants

Funzione per inserire/modificare, oppure eliminare, i permessi sui canali Telegram di un determinato gruppo.

Argomenti:  * oggetto contenente i canali con i relativi permessi ('grants');

           * id del gruppo ('grid');

           * id del canale ('chid');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut

=head1 put_widget_destination

Funzione per modificare la destinazione di un determinato widget di un determinato gruppo.

Argomenti:  * id del gruppo ('grid');

           * id del widget ('id');

           * id della destinazione del widget ('obj');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut

=head1 put_validation_options

Funzione per modificare le impostazioni di validazione multilivello.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le modifiche relative alle impostazioni ('params');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut

=head1 del_group

Funzione per eliminare un determinato gruppo.

Argomenti:  * id del gruppo ('id');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut