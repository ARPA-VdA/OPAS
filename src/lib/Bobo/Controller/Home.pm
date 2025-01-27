package Bobo::Controller::Home;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];
use Data::Dumper;

# This action will render a template
sub home {
    my $self = shift;

    # get the menu with active element based on the current route
    $self->helperGetMenusStash('/');

    # Get the operating mode for application
    my $mode = $self->app->mode();
    $self->stash(mode => $mode);

    my $current_timestamp = $self->dbhome->welcome();
    $self->stash(current_timestamp => $current_timestamp);

    # the redirect to "/" use first "login_redirect_path" setted in the authorization plugin
    my $login_redirect_path = $self->flash('login_redirect_path');

    # if defined, we must redefine the login_redirect_path for redirect after login
    if (defined $login_redirect_path) {
        $self->flash(login_redirect_path => $login_redirect_path);
    }

    my $user_id = $self->session('it.ecometer.bobo');

    my @options;

    # retrive the user options
    my $user_options = $self->dboptions->get_user_options($user_id);
    if (defined $user_options) {
        $user_options = decode_json($user_options->{option_object});
        my $widgets = $user_options->{widgets};

        my $counter = 0;

        # build the homepage widgets table
        foreach my $row (@{$widgets}) {
            my @user_widgets;
            foreach my $col (@{$row}) {
                my $widget = $self->dbhome->get_widget_by_id($user_id, $col);

                my $html_name;
                if (defined $widget) {
                    # $html_name = $widget->{'wdg_page_html'};
                    $widget->{'gw_dest'} = decode_json($widget->{'gw_dest'});
                    push @user_widgets, $widget;
                }
                else {
                    # $html_name = undef;
                    push @user_widgets, undef;
                }

                # $self->app->log->debug($html_name);
                # push @htmls, $html_name;
            }

            $options[$counter] = \@user_widgets;
            $counter++;
        }
    }

    $self->helperDumper(\@options);
    $self->stash(options => \@options);

    $self->helperGetPortalPageOptions();

    # render
    $self->render('home/home');
}

sub get_open_doors {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home sub get_open_doors");

    my $user_id = $self->session('it.ecometer.bobo');

    my $dateFrom = $self->param('from'); # post
    my $dateTo = $self->param('to'); # post

    $self->app->log->debug("From: $dateFrom");
    $self->app->log->debug("To: $dateTo");

    # get alarms by dates sent by an ajax call
    my $doors = $self->dbhome->get_open_doors_bydates($user_id, $dateFrom, $dateTo);

    my $json = {
        res => "OK",
        doors => $doors
    };

    # render
    $self->render(json => $json);
}

sub get_last_reports {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home sub get_last_reports");

    my $user_id = $self->session('it.ecometer.bobo');

    # get last reports by an ajax call
    my $reports = $self->dbhome->get_last_reports($user_id);

    my $json = {
        res => "OK",
        reports => $reports
    };

    # render
    $self->render(json => $json);
}

sub get_delays {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home sub get_delays");

    my $user_id = $self->session('it.ecometer.bobo');

    my $range = $self->param('range'); # post

    # get delays by an ajax call
    my $delays = $self->dbhome->get_delays($user_id, $range);

    my $json = {
        res => "OK",
        delays => $delays
    };

    # render
    $self->render(json => $json);
}

sub get_instr_delays {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home sub get_instr_delays");

    my $user_id = $self->session('it.ecometer.bobo');

    # get delays by an ajax call
    my $delays = $self->dbhome->get_instr_delays($user_id);

    my $json = {
        res => "OK",
        delays => $delays
    };

    # render
    $self->render(json => $json);
}

sub get_station_params_delays{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home sub get_instr_delays");

    my $stid = $self->param('stid'); # post

    # get delays by an ajax call
    my $delays = $self->dbhome->get_station_params_delays($stid);
    if(defined $delays){
        $delays = decode_json(encode_utf8($delays));
    }

    my $json = {
        res => "OK",
        delays => $delays
    };

    # render
    $self->render(json => $json);
}

sub get_last_alarms {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home sub get_last_alarms");

    my $user_id = $self->session('it.ecometer.bobo');

    # get last alarms by an ajax call
    my $alarms = $self->dbhome->get_last_alarms($user_id);

    my $json = {
        res => "OK",
        alarms => $alarms
    };

    # render
    $self->render(json => $json);
}

sub get_last_warnings {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home sub get_last_warnings");

    my $type = $self->param('type'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    my $warnings;
    if ($type == 1) { # SWAM
        $warnings = $self->dbhome->get_last_swam_messages($user_id);
    }
    elsif ($type == 2) { # TECORA
        $warnings = $self->dbhome->get_last_tecora_messages($user_id);
    }
    elsif ($type == 3) { # DERENDA
        $warnings = $self->dbhome->get_last_derenda_messages($user_id);
    }
    elsif ($type == 4) { # ENVEA
        $warnings = $self->dbhome->get_last_envea_messages($user_id);
    }
    elsif ($type == 5) { # METONE
        $warnings = $self->dbhome->get_last_metone_messages($user_id);
    }
    elsif ($type == 6) { # FIDAS
        $warnings = $self->dbhome->get_last_fidas_messages($user_id);
    }
    elsif ($type == 7) { # Teledyne
        $warnings = $self->dbhome->get_last_teledyne_messages($user_id);
    }
    else {
        # nothing to do
    }

    my $json = {
        res => "OK",
        warns => $warnings
    };

    # render
    $self->render(json => $json);
}

sub get_user_links {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home sub get_user_links");

    my $user_id = $self->session('it.ecometer.bobo');

    # get user links by an ajax call
    my $user_links = $self->dbhome->get_user_links($user_id);

    my $json = {
        res => "OK",
        user_links => $user_links
    };

    # render
    $self->render(json => $json);
}

sub get_links {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home sub get_links");

    my $user_id = $self->session('it.ecometer.bobo');

    # get links sent by an ajax call
    my $links = $self->dbhome->get_links($user_id);

    my $json = {
        res => "OK",
        links => $links
    };

    # render
    $self->render(json => $json);
}

sub put_link {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home  sub put_link");
    $self->helperDumperPostData('Home', 'put_link', $self->req->body_params);

    # my $res = 1;
    my $params = $self->req->body_params->to_hash;
    my $user_id = $self->session('it.ecometer.bobo');
    # get params from ajax
    # my $id =  $params->{'link-id'};

    # # if arg_id defined -> edit report
    # if (defined $bulletin) {
    #     $self->app->log->debug("Bobo::Controller::Bolrai edit of bulletin");

    #     $res = $self->dbbolrai->update_bulletin( $params );
    # }
    # else { # else -> insert new link

    $self->app->log->debug("Bobo::Controller::Home insert of new link");

    my $id = $self->dboptions->insert_new_link($user_id, $params);
    # }

    my $json;

    # check result
    if (defined $id) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            id => $id
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'ERR'
        };
    }

    # render
    $self->render(json => $json)
}

sub put_user_links {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Home  sub put_user_links");
    $self->helperDumperPostData('Home', 'put_user_links', $self->req->body_params);

    # my $res = 1;
    my $params = $self->req->body_params->to_hash;
    my $user_id = $self->session('it.ecometer.bobo');
    # get params from ajax
    # my $id = $params->{'link-id'};

    # # if arg_id defined -> edit report
    # if (defined $bulletin) {
    #     $self->app->log->debug("Bobo::Controller::Bolrai edit of bulletin");

    #     $res = $self->dbbolrai->update_bulletin($params);
    # }
    # else { # else -> insert new link

    my $res = $self->dboptions->update_links($user_id, $params->{'links'});
    # }

    # check result
    if ($res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

1;

=head1 home

Redirect alla homepage del portale.

Argomenti:  /

Return:     /

=cut

=head1 get_open_doors

Funzione che recupera gli allarmi scattati di tipo 'Porta aperta' in un determinato periodo
temporale per il widget presente in homepage.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente la risposta "OK" e gli allarmi.

=cut

=head1 get_last_reports

Funzione che recupera gli ultimi report tarature/manutenzioni per il widget presente in homepage.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e i report.

=cut

=head1 get_delays

Funzione che recupera lo stato delle stazioni per il widget presente in homepage.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e gli stati.

=cut

=head1 get_instr_delays

Funzione che recupera lo stato degli strumenti presenti nelle stazioni della rete per il widget
presente in homepage.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e gli stati.

=cut

=head1 get_last_alarms

Funzione che recupera gli allarmi scattati nelle stazioni negli ultimi 10 minuti
per il widget presente in homepage.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e gli allarmi.

=cut

=head1 get_last_warnings

Funzione che recupera gli ultimi warnings strumentali scattati nelle stazioni
per il widget presente in homepage.

Argomenti:  * id della tipologia di warning strumentale ('type');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e i warnings.

=cut

=head1 get_user_links

Funzione che recupera i links utili impostati dall'utente per il widget presente in homepage.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e i links.

=cut

=head1 get_links

Funzione che recupera i links per il widget presente in homepage.

Argomenti:  /

Return:     json contenente la risposta "OK" e i links.

=cut

=head1 put_link

Funzione che inserisce un nuovo link tra quelli utili all'interno del widget per la homepage.

Argomenti:  * oggetto contenente le informazioni del link da inserire ('params');

           * id dell'utente ('user_id');

Return:     json contenente:

            - il messaggio "OK" e l'id restituito dalla query effettuata nel database;

            - il messaggio "ERR" se non è stato inserito il link;

=cut

=head1 put_user_links

Funzione che aggiorna le informazioni dei links utili all'utente all'interno del widget per la homepage.

Argomenti:  * oggetto contenente le informazioni dei links da aggiornare ('params');

           * id dell'utente ('user_id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut