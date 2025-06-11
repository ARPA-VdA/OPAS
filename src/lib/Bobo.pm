package Bobo;
use Mojo::Base 'Mojolicious';

use Mojolicious::Plugin::Authentication;
use Mojolicious::Plugin::Authorization;

use Mojo::Pg;

use Data::Dumper;

use Bobo::Plugin::Helpers;
use Bobo::Plugin::Menus;

# import models
use Bobo::Model::Dbadmin;
use Bobo::Model::Dbalims;
use Bobo::Model::Dbanagrafica;
use Bobo::Model::Dbanalyser;
use Bobo::Model::DbangParametri;
use Bobo::Model::DbcnfBombole;
use Bobo::Model::DbcnfCampagne;
use Bobo::Model::DbcnfDotazioni;
use Bobo::Model::DbcnfParametri;
use Bobo::Model::DbcnfStazioni;
use Bobo::Model::DbcnfStrumenti;
use Bobo::Model::Dbcommon;
use Bobo::Model::Dbcustomized;
use Bobo::Model::Dbdatamanager;
use Bobo::Model::Dbdataview;
use Bobo::Model::Dbdiagnostici;
use Bobo::Model::Dbdivulgazione;
use Bobo::Model::Dbemailgest;
use Bobo::Model::Dbfaq;
use Bobo::Model::Dbhome;
use Bobo::Model::Dbindicatori;
use Bobo::Model::Dbinfoaria;
use Bobo::Model::Dbmain;
use Bobo::Model::Dboptions;
use Bobo::Model::DbplanPeriferia;
use Bobo::Model::Dbprofile;
use Bobo::Model::Dbqamanutenzioni;
use Bobo::Model::Dbqasopralluoghi;
use Bobo::Model::Dbqatarature;
use Bobo::Model::Dbreportistica;
use Bobo::Model::Dbstatistiche;
use Bobo::Model::DbtaratureAut;
use Bobo::Model::Dbtelegram;
use Bobo::Model::Dbutilities;
use Bobo::Model::Dbvalidazione;
use Bobo::Model::Dbvalidazfinale;
use Bobo::Model::Dbverbali;
use Bobo::Model::Dbvisualizer;

# This method will run once at server start
sub startup {
    my $self = shift;

    # ----------------------------------------------------------------------------------------------
    # load configuration stuff
    # ----------------------------------------------------------------------------------------------
    # load configuration from hash returned by "my_app.conf"
    my $config = $self->plugin('Config');

    # set log level
    $self->app->log->path( $config->{logpath} );
    $self->app->log->level( $config->{loglevel} );

    # get config values
    my $public_routes = $config->{public_routes};

    # ----------------------------------------------------------------------------------------------
    # log infos
    # ----------------------------------------------------------------------------------------------
    $self->app->log->info( sprintf( "Application %s version %s starting up", $config->{title}, $config->{version} ) );
    $self->app->log->info( sprintf( "Log path : %s", $config->{logpath} || 'not set' ) );
    $self->app->log->info( sprintf( "Log level : %s", $config->{loglevel} ) );
    $self->app->log->info( sprintf( "Application mode : %s", $self->mode ) );

    # ----------------------------------------------------------------------------------------------
    # secret
    # ----------------------------------------------------------------------------------------------
    $self->sessions->cookie_name('it.ecometer.bobo');
    $self->sessions->cookie_name('sys_admin');
    $self->secrets( $config->{secrets} );

    # ----------------------------------------------------------------------------------------------
    # encoding
    # ----------------------------------------------------------------------------------------------
    $self->renderer->encoding('utf-8');

    # Documentation browser under "/perldoc"
    $self->plugin('DefaultHelpers');
    $self->plugin('TagHelpers');

    $self->app->log->debug();
    $self->plugin('PODRenderer') if $config->{perldoc};
    $self->plugin('Bobo::Plugin::Helpers'   , $config);
    $self->plugin('Bobo::Plugin::Menus'     , $config); #functions for the menu
    $self->plugin('Bobo::Plugin::RenderFile'); # custom plugin to support file download event

    # ----------------------------------------------------------------------------------------------
    # load database models
    # ----------------------------------------------------------------------------------------------
    $self->helper(pg => sub {
        state $pg = Mojo::Pg->new(shift->config->{database})
    });
    $self->helper(dbadmin => sub {
        state $dbadmin = Bobo::Model::Dbadmin->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbalims => sub {
        state $dbalims = Bobo::Model::Dbalims->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbanagrafica => sub {
        state $dbanagrafica = Bobo::Model::Dbanagrafica->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbanalyser => sub {
        state $dbanalyser = Bobo::Model::Dbanalyser->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbangparametri => sub {
        state $dbangparametri = Bobo::Model::DbangParametri->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbcnfbombole => sub {
        state $dbcnfbombole = Bobo::Model::DbcnfBombole->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbcnfcampagne => sub {
        state $dbcnfcampagne = Bobo::Model::DbcnfCampagne->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbcnfdotazioni => sub {
        state $dbcnfdotazioni = Bobo::Model::DbcnfDotazioni->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbcnfparametri => sub {
        state $dbcnfparametri = Bobo::Model::DbcnfParametri->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbcnfstazioni => sub {
        state $dbcnfstazioni = Bobo::Model::DbcnfStazioni->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbcnfstrumenti => sub {
        state $dbcnfstrumenti = Bobo::Model::DbcnfStrumenti->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbcommon => sub {
        state $dbcommon = Bobo::Model::Dbcommon->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbcustomized => sub {
        state $dbcustomized = Bobo::Model::Dbcustomized->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbdatamanager => sub {
        state $dbdatamanager = Bobo::Model::Dbdatamanager->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbdataview => sub {
        state $dbdataview = Bobo::Model::Dbdataview->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbdiagnostici => sub {
        state $dbdiagnostici = Bobo::Model::Dbdiagnostici->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbdivulgazione => sub {
        state $dbdivulgazione = Bobo::Model::Dbdivulgazione->new( pg  => shift->pg, app => $self->app )
    });
    $self->helper(dbemailgest => sub {
        state $dbemailgest = Bobo::Model::Dbemailgest->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbfaq => sub {
        state $dbfaq = Bobo::Model::Dbfaq->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbhome => sub {
        state $dbhome = Bobo::Model::Dbhome->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbindicatori => sub {
        state $dbindicatori = Bobo::Model::Dbindicatori->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbinfoaria => sub {
        state $dbinfoaria = Bobo::Model::Dbinfoaria->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbmain => sub {
        state $dbmain = Bobo::Model::Dbmain->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dboptions => sub {
        state $dboptions = Bobo::Model::Dboptions->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbplanperiferia => sub {
        state $dbplanperiferia = Bobo::Model::DbplanPeriferia->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbprofile => sub {
        state $dbprofile = Bobo::Model::Dbprofile->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbqamanutenzioni => sub {
        state $dbqamanutenzioni = Bobo::Model::Dbqamanutenzioni->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbqasopralluoghi => sub {
        state $dbqasopralluoghi = Bobo::Model::Dbqasopralluoghi->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbqatarature => sub {
        state $dbqatarature = Bobo::Model::Dbqatarature->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbreportistica => sub {
        state $dbreportistica = Bobo::Model::Dbreportistica->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbstatistiche => sub {
        state $dbstatistiche = Bobo::Model::Dbstatistiche->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbtaratureaut => sub {
        state $dbtaratureaut = Bobo::Model::DbtaratureAut->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbtelegram => sub {
        state $dbtelegram = Bobo::Model::Dbtelegram->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbutilities => sub {
        state $dbutilities = Bobo::Model::Dbutilities->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbvalidazione => sub {
        state $dbvalidazione = Bobo::Model::Dbvalidazione->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbvalidazfinale => sub {
        state $dbvalidazfinale = Bobo::Model::Dbvalidazfinale->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbverbali => sub {
        state $dbverbali = Bobo::Model::Dbverbali->new( pg => shift->pg, app => $self->app )
    });
    $self->helper(dbvisualizer => sub {
        state $dbvisualizer = Bobo::Model::Dbvisualizer->new( pg => shift->pg, app => $self->app )
    });

    # ----------------------------------------------------------------------------------------------
    # default expiration to 1 month
    # ----------------------------------------------------------------------------------------------
    $self->sessions->default_expiration(3600); # default Mojolicious

    $self->plugin('Authentication' => {
        'session_key' => 'it.ecometer.bobo',
        'load_user' => sub {
            my $self = shift;
            my $uid = shift;

            unless ($self->session('it.ecometer.bobo')){

                $self->app->log->debug('user NOT found');
                return undef;
            }

            $self->app->log->debug('return data session');
            return $self->session('it.ecometer.bobo');
        },
        'validate_user' => sub {
            my $self = shift;
            my $usermail = shift || '';
            my $password = shift || '';

            # the return parameter is saved in the session
            $self->app->log->debug('validate_user ' . '*' x 60);
            my $res = $self->dbmain->user_login( $usermail, $password );
            $self->app->log->debug( Dumper( $res ) );
            $self->session('sys_admin', $res->{user_sys_admin});

            if( $res->{user_id} ) {
                $self->app->log->debug('user_id found');
                return $res->{user_id};
            }

            return undef;
        },
    });

    # ----------------------------------------------------------------------------------------------
    # authorization
    # https://groups.google.com/forum/?fromgroups=#!topic/mojolicious/8nthwmmr1Lk
    # ----------------------------------------------------------------------------------------------
    $self->plugin('Authorization' => {
        # check if the current session has the given privilege
        'has_priv' => sub {
            my ($self, $priv) = @_;

            $self->app->log->debug('^' x 60);
            $self->app->log->debug('PRIV:'. $priv);

            my $active_path = $self->req->url->to_abs->path;
            $self->app->log->debug('ACTIVE_PATH:'. $active_path);

            $self->app->log->debug($self->session('it.ecometer.bobo'));

            # return to login if unlogged
            if ( ! $self->session('it.ecometer.bobo') ) {
                $self->app->log->info('AUTHORIZATION DENIED : self->session(it.ecometer.bobo) not set');

                # store coming path for redirect after login
                $self->flash(login_redirect_path => $active_path );

                # redirect to login form (see the route '/')
                $self->redirect_to('/login') and return 0;
            }

            my $result = $self->dbmain->user_authorization( $self->session('it.ecometer.bobo'), $priv );

            # return to root if logged, but without privileges
            if ( ! $result ) {
                $self->app->log->info('AUTHORIZATION DENIED : privilege not set for '.$priv.': redirect to home');

                if ($active_path eq '/') {
                    # no need to save path in login_redirect_path cause the user cannot access the page
                    $self->redirect_to('/logout') and return 0;
                }
                else {
                    # no need to save path in login_redirect_path cause the user cannot access the page
                    $self->redirect_to('/') and return 0;
                }
            }

            # first login, user must change password before access to website
            if ( $result->{'user_first_log'} and $active_path ne '/primo_login') {
                $self->app->log->info('AUTHORIZATION DENIED : first log, user must change password');

                # no need to save path in login_redirect_path cause the user cannot access the page
                $self->redirect_to('/primo_login') and return 0;
            }

            # in order to prevent that user return to /primo_login when user_first_login is FALSE
            if ( !$result->{'user_first_log'} and $active_path eq '/primo_login') {
                $self->app->log->info('AUTHORIZATION DENIED : user cannot return to /primo_login');

                # no need to save path in login_redirect_path cause the user cannot access the page
                $self->redirect_to('/') and return 0;
            }

            # password expired, user must change password before access to website
            if( $result->{'user_pwd_expired'} and $active_path ne '/password' ) {
                $self->app->log->info('AUTHORIZATION DENIED : user must change password');

                # no need to save path in login_redirect_path cause the user cannot access the page
                $self->redirect_to('/password') and return 0;
            }

            $self->stash(user_grants => $result);

            # authorized
            $self->app->log->info('AUTHORIZATION ACCEPTED!');
            return 1;
        },
        'is_role' => sub { return 1 if $_[1] eq 'rolemodel' }, # controllo ruolo dell'utente
        'user_privs' => sub { return [ qw( rolemodel rolemodel ) ] },
        'user_role' => sub { return 'rolemodel' },
    });

    $self->defaults( websockets => {} );


    # Router
    my $r = $self->routes;
    $r = $r->add_type(txt => qr/\w+/);

    # For serving static files from your public directories, defaults to a Mojolicious::Static object.
    my $static = $self->static;

    # At all requests check if portal is under maintenance
    $self->hook(before_dispatch => sub {
        my ( $self ) = @_;
        
        my $sys_admin = $self->session('sys_admin');
        
        my $static = $self->app->static->paths->[0];

        my $path = $self->req->url->to_abs->path;

        # check if the request is a static file under "public" directory
        # if TRUE do nothing
        # else do more controls
        if($path eq '/' || ! (-e $static . $path ) ){

            # get system admin options
            my $opt = $self->helperGetSysAdminOptions();

            if( defined $opt->{'maintenance'} && $opt->{'maintenance'} == 1){
                # format dates
                my $f = $opt->{'maintenance_start'} ne '' ? $opt->{'maintenance_start'} : '01/01/1970 00:00';
                my $t = $opt->{'maintenance_end'} ne '' ? $opt->{'maintenance_end'} : '01/01/2199 00:00';

                $f = $self->helperGetFormattedFulldate($f);
                $f =~ s/\//-/g;
                $f =~ s/ /T/;
                $f = $f.'Z';

                $t = $self->helperGetFormattedFulldate($t);
                $t =~ s/\//-/g;
                $t =~ s/ /T/;
                $t = $t.'Z';

                my $now = $self->helperGetLocaleFullDate();
                $now =~ s/\//-/g;
                $now =~ s/ /T/;
                $now = $now.'Z';

                # check if there is an active maintenance
                if(
                    Time::Moment->from_string($f)->is_before(Time::Moment->from_string($now)) &&
                    Time::Moment->from_string($t)->is_after(Time::Moment->from_string($now)) &&
                    ( !defined $sys_admin || $sys_admin == 0)
                ){
                    $self->app->log->debug('!! UNDER MAINTENANCE !! ');
                    $self->render(template => 'under_maintenance');
                }
            }
        }
    });

    # ----------------------------------------------------------------------------------------------
    #
    # GUIDELINES:
    # Visible URLs from DB in Italian
    # For AJAX routes, keywords:
    #   - GET for getting data from db
    #   - PUT for insert and update action
    #   - DEL for removing data from db
    #   - UPLOAD for file
    # ----------------------------------------------------------------------------------------------

    # ----------------------------------------------------------------------------------------------
    # routes authentication stuff
    # ----------------------------------------------------------------------------------------------
    $r->get('/login'        )->to( controller => 'auth', action => 'login'           );
    $r->post('/get_login'   )->to( controller => 'auth', action => 'get_login'       ); # login
    $r->get('/logout'       )->to( controller => 'auth', action => 'delete'          ); # logout
    $r->post('/get_password')->to( controller => 'auth', action => 'recover_password');

    # web services
    $r->post('/rep_alims_ws')->to( controller => 'alims',     action => 'alims_ws'        );

	# web socket
    $r->websocket('/bobo_ws')->to( controller => 'utilities', action => 'ws'              );

    # Public routes, callable via curl
    # https://mojolicious.org/perldoc/Mojolicious/Guides/Routing#Restrictive-placeholders
    # !!DATAVIEW
    if ($public_routes == 1) {
        $r->get('/str_dataview/:reg'                   )->to( controller => 'dataview', action => 'dataview', reg => undef                );
        $r->get('/str_dataview_station/:stid/:tab'     )->to( controller => 'dataview', action => 'station' , stid => undef, tab => undef );
        $r->get('/str_dataview_download'               )->to( controller => 'dataview', action => 'download'                              );

        # DATAVIEW - AJAX
        # dataview index
        $r->post('/str_dataview_get_stations_list'     )->to( controller => 'dataview', action => 'get_stations_list'         );
        $r->post('/str_dataview_get_map_last_data'     )->to( controller => 'dataview', action => 'get_map_last_data'         );
        $r->post('/str_dataview_get_map_indicators'    )->to( controller => 'dataview', action => 'get_map_indicators'        );
        $r->post('/str_dataview_get_map_stations'      )->to( controller => 'dataview', action => 'get_map_stations'          );
        # station
        $r->post('/str_dataview_get_near_stations'     )->to( controller => 'dataview', action => 'get_near_stations'         );
        $r->post('/str_dataview_get_allparams_data'    )->to( controller => 'dataview', action => 'get_all_params_data'       );
        $r->post('/str_dataview_get_allparams_data_tbl')->to( controller => 'dataview', action => 'get_all_params_data_table' );
        $r->post('/str_dataview_get_windrose_data'     )->to( controller => 'dataview', action => 'get_windrose_data'         );
        # download
        $r->post('/str_dataview_get_stations'          )->to( controller => 'dataview', action => 'get_stations'              );
        $r->post('/str_dataview_get_params'            )->to( controller => 'dataview', action => 'get_params'                );
        $r->post('/str_dataview_get_station_params'    )->to( controller => 'dataview', action => 'get_station_params'        );
        $r->post('/str_dataview_get_data'              )->to( controller => 'dataview', action => 'get_data'                  );
        $r->post('/str_dataview_get_downloads'         )->to( controller => 'dataview', action => 'get_downloads'             );
        # notifier
        $r->post('/str_dataview_get_notifications'     )->to( controller => 'dataview', action => 'get_notifications'         );
        $r->post('/str_dataview_put_notification_ack'  )->to( controller => 'dataview', action => 'put_notification_ack'      );
    }

    # check if user is authenticated via function "is_user_authenticated" (plugin Authentication declared in Bobo.pm)
    my $auth = $r->under(             )->to( controller => 'auth', action => 'check' ); # always done

    # ----------------------------------------------------------------------------------------------
    # private routes user must be authenticated and for certain routes user must have privileges
    # ----------------------------------------------------------------------------------------------
    $auth->get('/primo_login')->requires(has_priv => '/')->to( controller => 'auth', action => 'primo_login' );
    $auth->get('/password'   )->requires(has_priv => '/')->to( controller => 'auth', action => 'password'    );
    $auth->get('/'           )->requires(has_priv => '/')->to( controller => 'home', action => 'home'        );

    # notifier
    $auth->post('/get_notifications'   )->to( controller => 'utilities', action => 'get_notifications'    );
    $auth->post('/put_notification_ack')->to( controller => 'utilities', action => 'put_notification_ack' );

    # documentation
    $auth->get('/docs')->requires(has_priv => '/docs')->to( controller => 'utilities', action => 'docs' );

    # !!HOME AJAX
    $auth->post('/home_get_stations'             )->to( controller => 'common', action => 'get_stations_by_net_province' );
    $auth->post('/home_get_open_doors'           )->to( controller => 'home'  , action => 'get_open_doors'               );
    $auth->post('/home_get_last_reports'         )->to( controller => 'home'  , action => 'get_last_reports'             );
    $auth->post('/home_get_delays'               )->to( controller => 'home'  , action => 'get_delays'                   );
    $auth->post('/home_get_instr_delays'         )->to( controller => 'home'  , action => 'get_instr_delays'             );
    $auth->post('/home_get_station_params_delays')->to( controller => 'home'  , action => 'get_station_params_delays'    );
    $auth->post('/home_get_last_alarms'          )->to( controller => 'home'  , action => 'get_last_alarms'              );
    $auth->post('/home_get_last_warnings'        )->to( controller => 'home'  , action => 'get_last_warnings'            );
    $auth->post('/home_get_user_links'           )->to( controller => 'home'  , action => 'get_user_links'               );
    $auth->post('/home_get_links'                )->to( controller => 'home'  , action => 'get_links'                    );
    $auth->post('/home_put_link'                 )->to( controller => 'home'  , action => 'put_link'                     );
    $auth->post('/home_put_user_links'           )->to( controller => 'home'  , action => 'put_user_links'               );

    # MAIN - AJAX
    $auth->post('/put_password')->to( controller => 'auth', action => 'edit_password' );

    # !!MENU USER
    $auth->get('/usr_admin'   )->requires(has_priv => '/usr_admin'  )->to( controller => 'admin'    , action => 'admin'    );
    $auth->get('/usr_sysadmin')->requires(has_priv => '/usr_admin'  )->to( controller => 'sysadmin' , action => 'sysadmin' );
    $auth->get('/usr_profile' )->requires(has_priv => '/usr_profile')->to( controller => 'profile'  , action => 'profile'  );
    $auth->get('/usr_options' )->requires(has_priv => '/usr_options')->to( controller => 'options'  , action => 'options'  );

    # MENU USER ADMIN PERMISSIONS - AJAX
    $auth->post('/usr_admin_get_groups'               )->to( controller => 'admin', action => 'get_groups'                );
    $auth->post('/usr_admin_get_users'                )->to( controller => 'admin', action => 'get_users'                 );
    $auth->post('/usr_admin_get_user_byid'            )->to( controller => 'admin', action => 'get_user_byid'             );
    $auth->post('/usr_admin_get_comp_detail'          )->to( controller => 'admin', action => 'get_comp_detail'           );
    $auth->post('/usr_admin_get_groups_detail'        )->to( controller => 'admin', action => 'get_groups_detail'         );
    $auth->post('/usr_admin_get_group_pages_grants'   )->to( controller => 'admin', action => 'get_group_pages_grants'    );
    $auth->post('/usr_admin_get_group_stations_grants')->to( controller => 'admin', action => 'get_group_stations_grants' );
    $auth->post('/usr_admin_get_group_others_grants'  )->to( controller => 'admin', action => 'get_group_others_grants'   );
    $auth->post('/usr_admin_get_user_password'        )->to( controller => 'admin', action => 'recover_user_password'     );
    $auth->post('/usr_admin_put_group'                )->to( controller => 'admin', action => 'put_group'                 );
    $auth->post('/usr_admin_put_user'                 )->to( controller => 'admin', action => 'put_user'                  );
    $auth->post('/usr_admin_put_group_pages_grants'   )->to( controller => 'admin', action => 'put_group_pages_grants'    );
    $auth->post('/usr_admin_put_group_stations_grants')->to( controller => 'admin', action => 'put_group_stations_grants' );
    $auth->post('/usr_admin_put_group_others_grants'  )->to( controller => 'admin', action => 'put_group_others_grants'   );
    $auth->post('/usr_admin_put_group_channels_grants')->to( controller => 'admin', action => 'put_group_channels_grants' );
    $auth->post('/usr_admin_put_widget_destination'   )->to( controller => 'admin', action => 'put_widget_destination'    );
    $auth->post('/usr_admin_del_group'                )->to( controller => 'admin', action => 'del_group'                 );

    # MENU USER ADMIN SETTINGS - AJAX
    $auth->post('/usr_admin_get_portal_options'       )->to( controller => 'admin', action => 'get_options'               );
    $auth->post('/usr_admin_put_validation_options'   )->to( controller => 'admin', action => 'put_validation_options'    );
    # MENU USER SYSTEM ADMIN - AJAX
    $auth->post('/usr_sysadmin_get_options'              )->to(controller => 'sysadmin', action => 'get_options' );
    $auth->post('/usr_sysadmin_put_options'              )->to(controller => 'sysadmin', action => 'put_options' );

    # MENU USER PROFILE - AJAX
    $auth->post('/usr_profile_get_user_byid'          )->to( controller => 'profile', action => 'get_user_byid'           );
    $auth->post('/usr_profile_put_user'               )->to( controller => 'profile', action => 'put_user'                );
    $auth->post('/usr_profile_put_password'           )->to( controller => 'profile', action => 'put_password'            );

    # MENU USER OPTIONS - AJAX
    $auth->post('/usr_options_get_widget_list'        )->to( controller => 'options', action => 'get_widget_list'         );
    $auth->post('/usr_options_get_options'            )->to( controller => 'options', action => 'get_options'             );
    $auth->post('/usr_options_put_widgets'            )->to( controller => 'options', action => 'put_widgets'             );
    $auth->post('/usr_options_put_shortcuts'          )->to( controller => 'options', action => 'put_shortcuts'           );

    # !!CALENDARIO
    $auth->get('/calendario')->requires(has_priv => '/calendario')->to( controller => 'utilities', action => 'calendario' );

    # CALENDARIO - AJAX
    $auth->post('/calendario_get_events')->to( controller => 'utilities', action => 'get_calendar_events' );

    # !!STRUMENTI
    $auth->get('/str_analyser'                                 )->requires(has_priv => '/str_analyser'  )->to( controller => 'analyser'  , action => 'analyser'                                              );
    $auth->get('/str_visualizer/<pgid:num>/<from:num>/<to:num>')->requires(has_priv => '/str_visualizer')->to( controller => 'visualizer', action => 'visualizer', pgid => undef, from => undef, to => undef );
    $auth->get('/str_mapper/<stid:num>'                        )->requires(has_priv => '/str_mapper'    )->to( controller => 'mapper'    , action => 'mapper'    , stid => undef                             );
    $auth->get('/str_openair'                                  )->requires(has_priv => '/str_openair'   )->to( controller => 'openair'   , action => 'openair'                                               );

    # STRUMENTI - ANALYSER - AJAX
    $auth->post('/str_ana_get_analyser_options'          )->to(controller => 'analyser', action => 'get_analyser_options'        );
    $auth->post('/str_ana_get_categories'                )->to(controller => 'analyser', action => 'get_categories'              );
    $auth->post('/str_ana_get_category_byid'             )->to(controller => 'analyser', action => 'get_category_byid'           );
    $auth->get('/str_ana_get_analyser_groups'            )->requires(has_priv => '/str_analyser' )->to(controller => 'analyser', action => 'get_analyser_groups'         );
    $auth->get('/str_ana_get_group_stations'             )->requires(has_priv => '/str_analyser' )->to(controller => 'analyser', action => 'get_group_stations'          );
    $auth->get('/str_ana_get_station_params'             )->requires(has_priv => '/str_analyser' )->to(controller => 'analyser', action => 'get_station_params'          );
    $auth->get('/str_ana_get_params_type'                )->requires(has_priv => '/str_analyser' )->to(controller => 'analyser', action => 'get_params_type'             );
    $auth->get('/str_ana_get_allocations'              )->requires(has_priv => '/str_analyser' )->to(controller => 'analyser', action => 'get_allocations'             );
    $auth->get('/str_ana_get_allocation_params'        )->requires(has_priv => '/str_analyser' )->to(controller => 'analyser', action => 'get_allocation_params'       );
    $auth->get('/str_ana_get_allocation_params_type'   )->requires(has_priv => '/str_analyser' )->to(controller => 'analyser', action => 'get_allocation_params_type'  );


    $auth->get('/str_ana_get_groups'                     )->requires(has_priv => '/str_analyser' )->to(controller => 'analyser', action => 'get_groups'                  );
    $auth->get('/str_ana_get_group_macros'               )->requires(has_priv => '/str_analyser' )->to(controller => 'analyser', action => 'get_group_macros'            );
    $auth->get('/str_ana_get_macro_params'               )->requires(has_priv => '/str_analyser' )->to(controller => 'analyser', action => 'get_macro_params'            );
    $auth->post('/str_ana_get_macro_metadata'            )->to(controller => 'analyser', action => 'get_macro_metadata'          );
    $auth->post('/str_ana_get_param_info'                )->to(controller => 'analyser', action => 'get_param_info'              );
    $auth->post('/str_ana_get_wind_scale'                )->to(controller => 'analyser', action => 'get_wind_scale'              );

    $auth->post('/str_ana_get_highcharts_data_bydate'    )->to(controller => 'analyser', action => 'get_highcharts_data_bydate'  );
    $auth->post('/str_ana_get_highcharts_data_per_year'  )->to(controller => 'analyser', action => 'get_highcharts_data_per_year');
    $auth->post('/str_ana_get_windrose_data'             )->to(controller => 'analyser', action => 'get_windrose_data'           );
    $auth->post('/str_ana_get_tabulator_data'            )->to(controller => 'analyser', action => 'get_tabulator_data'          );
    $auth->post('/str_ana_get_csv_data'                   )->to(controller => 'analyser', action => 'get_csv_data'               );

    $auth->post('/str_ana_put_analyser_user_options'     )->to(controller => 'analyser', action => 'put_analyser_user_options'   );
    $auth->post('/str_ana_put_category'                  )->to(controller => 'analyser', action => 'put_category'                );
    $auth->post('/str_ana_put_macro'                     )->to(controller => 'analyser', action => 'put_macro'                   );
    $auth->post('/str_ana_put_macro_duplication'         )->to(controller => 'analyser', action => 'put_macro_duplication'       );
    $auth->post('/str_ana_del_category'                  )->to(controller => 'analyser', action => 'del_category'                );
    $auth->post('/str_ana_del_macro'                     )->to(controller => 'analyser', action => 'del_macro'                   );

    # STRUMENTI - VISUALIZER - AJAX
    $auth->post('/str_vis_get_visualizer_user_options'   )->to(controller => 'visualizer', action => 'get_visualizer_user_options' );
    $auth->post('/str_vis_get_pages_by_cat'              )->to(controller => 'visualizer', action => 'get_pages_by_cat' );
    $auth->get('/str_vis_get_groups'                     )->requires(has_priv => '/str_visualizer' )->to(controller => 'visualizer', action => 'get_groups'                  );
    $auth->get('/str_vis_get_group_pages'                )->requires(has_priv => '/str_visualizer' )->to(controller => 'visualizer', action => 'get_group_pages'             );
    $auth->get('/str_vis_get_page_boxes'                 )->requires(has_priv => '/str_visualizer' )->to(controller => 'visualizer', action => 'get_page_boxes'              );
    $auth->post('/str_vis_get_macros_by_page'            )->to(controller => 'visualizer', action => 'get_macros_by_page'          );

    $auth->post('/str_vis_get_highcharts_data_bydate'    )->to(controller => 'visualizer', action => 'get_highcharts_data_bydate'  );

    $auth->post('/str_vis_put_visualizer_user_options'   )->to(controller => 'visualizer', action => 'put_visualizer_user_options' );

    # STRUMENTI - MAPPER - AJAX
    $auth->post('/str_map_get_stations'         )->to( controller => 'common', action => 'get_stations'          );
    $auth->post('/str_map_get_map_stations'     )->to( controller => 'mapper', action => 'get_map_stations'      );
    $auth->post('/str_map_get_data_station'     )->to( controller => 'mapper', action => 'get_data_station'      );
    $auth->post('/str_map_get_inst_data_station')->to( controller => 'mapper', action => 'get_inst_data_station' );
    $auth->post('/str_map_get_windrose_data'    )->to( controller => 'mapper', action => 'get_windrose_data'     );
    $auth->post('/str_map_get_info_station'     )->to( controller => 'mapper', action => 'get_info_station'      );

    # STRUMENTI - OPENAIR - AJAX
    $auth->post('/str_openair_get_stations'       )->to( controller => 'common' , action => 'get_stations'        );
    $auth->post('/str_openair_get_runs'           )->to( controller => 'openair', action => 'get_runs'            );
    $auth->post('/str_openair_get_images'         )->to( controller => 'openair', action => 'get_images'          );
    $auth->post('/str_openair_put_images_creation')->to( controller => 'openair', action => 'put_images_creation' );

    # !!DATI

    # 2 CASES:
    # - case of /station_id/date_start/date_end
    #   load data between date_start and date_end for selected station
    # - case of /st_pr_id/date_start
    #   load data +24 and -24 hours around date_start for station-param-id

    $auth->get('/dat_validazione/<id:num>/<start:num>/<end:num>')->requires(has_priv => '/dat_validazione'   )->to( controller => 'validazione'  , action => 'validazione', id => undef, start => undef, end => undef );
    $auth->get('/dat_validaz_finale'                            )->requires(has_priv => '/dat_validaz_finale')->to( controller => 'validazfinale', action => 'validaz_finale' );
    $auth->get('/dat_istantanei/<stid:num>'                     )->requires(has_priv => '/dat_istantanei'    )->to( controller => 'utilities'    , action => 'istantanei', stid => undef );
    $auth->get('/dat_diagnostici/<stid:num>'                    )->requires(has_priv => '/dat_diagnostici'    )->to(controller => 'diagnostici'   ,  action => 'diagnostici', stid => undef );
    $auth->get('/dat_tarature_aut/<stid:num>/<start:num>'       )->requires(has_priv => '/dat_tarature_aut'  )->to( controller => 'taratureaut'  , action => 'tarature_aut', stid => undef, start => undef );
    $auth->get('/dat_allarmi'                                   )->requires(has_priv => '/dat_allarmi'       )->to( controller => 'utilities'    , action => 'allarmi'        );
    $auth->get('/dat_warning'                                   )->requires(has_priv => '/dat_warning'       )->to( controller => 'utilities'    , action => 'warning'        );

    # DATI - VALIDAZIONE - AJAX
    $auth->post('/dat_val_get_codes'                     )->to(controller => 'common'     , action => 'get_codes'                     );
    $auth->post('/dat_val_get_stations'                  )->to(controller => 'validazione', action => 'get_stations'                  );
    $auth->post('/dat_val_get_parameters'                )->to(controller => 'common'     , action => 'get_parameters'                );
    $auth->post('/dat_val_get_validation_codes'          )->to(controller => 'validazione', action => 'get_validation_codes'          );
    $auth->post('/dat_val_get_validation_user_options'   )->to(controller => 'validazione', action => 'get_validation_user_options'   );
    $auth->get('/dat_val_get_validation_groups'          )->requires(has_priv => '/dat_validazione' )->to(controller => 'validazione', action => 'get_validation_groups'         );
    $auth->get('/dat_val_get_group_stations'             )->requires(has_priv => '/dat_validazione' )->to(controller => 'validazione', action => 'get_group_stations'            );
    $auth->get('/dat_val_get_group_params'               )->requires(has_priv => '/dat_validazione' )->to(controller => 'validazione', action => 'get_group_params'              );
    $auth->get('/dat_val_get_group_suspects'             )->requires(has_priv => '/dat_validazione' )->to(controller => 'validazione', action => 'get_group_suspects'            );
    $auth->get('/dat_val_get_group_suspect_params'       )->requires(has_priv => '/dat_validazione' )->to(controller => 'validazione', action => 'get_group_suspect_params'      );

    $auth->post('/dat_val_get_all_params_data_table'     )->to(controller => 'validazione', action => 'get_all_params_data_table'     );
    $auth->post('/dat_val_get_all_stations_data_table'   )->to(controller => 'validazione', action => 'get_all_stations_data_table'   );
    $auth->post('/dat_val_get_validation_codes_bycell'   )->to(controller => 'validazione', action => 'get_validation_codes_bycell'   );
    $auth->post('/dat_val_get_point_neighborhood'        )->to(controller => 'validazione', action => 'get_point_neighborhood'        );

    $auth->post('/dat_val_put_validation_user_options'   )->to(controller => 'validazione', action => 'put_validation_user_options'   );
    $auth->post('/dat_val_put_action_by_calendar'        )->to(controller => 'validazione', action => 'put_action_by_calendar'        );
    $auth->post('/dat_val_put_cells'                     )->to(controller => 'validazione', action => 'put_cells'                     );
    $auth->post('/dat_val_put_check_cells'               )->to(controller => 'validazione', action => 'put_check_cells'               );
    $auth->post('/dat_val_put_reset_cells'               )->to(controller => 'validazione', action => 'put_reset_cells'               );

    # DATI - VALIDAZIONE FINALE - AJAX
    $auth->post('/dat_validaz_finale_get_stations_by_network')->to( controller => 'common'       , action => 'get_stations_by_net_province' );
    $auth->post('/dat_validaz_finale_get_stations'           )->to( controller => 'common'       , action => 'get_stations'                 );
    $auth->post('/dat_validaz_finale_get_validation_per_year')->to( controller => 'validazfinale', action => 'get_validation_per_year'      );
    $auth->post('/dat_validaz_finale_get_validation_table'   )->to( controller => 'validazfinale', action => 'get_validation_table'         );
    $auth->post('/dat_validaz_finale_get_station_param_data' )->to( controller => 'validazfinale', action => 'get_station_data_by_stprid'   );
    $auth->post('/dat_validaz_finale_get_activities_log'     )->to( controller => 'validazfinale', action => 'get_activities_log'           );
    $auth->post('/dat_validaz_finale_put_final_validation'   )->to( controller => 'validazfinale', action => 'put_final_validation'         );

    # DATI - ISTANTANEI - AJAX
    $auth->post('/dat_inst_get_stations')->to( controller => 'common'   , action => 'get_stations_by_net_province' );
    $auth->post('/dat_inst_get_data'    )->to( controller => 'utilities', action => 'get_inst_data_table'          );

    # DATI - DIAGNOSTICI - AJAX
    $auth->post('/dat_diagnostici_get_stations'  )->to( controller => 'common'     , action => 'get_stations_by_net_province' );
    $auth->post('/dat_diagnostici_get_diags_data')->to( controller => 'diagnostici', action => 'get_diags_data'               );

    # DATI - TARATURE AUTOMATICHE - AJAX
    $auth->post('/dat_tarature_aut_get_stations'   )->to( controller => 'common'     , action => 'get_stations_by_net_province' );
    $auth->post('/dat_tarature_aut_get_data'       )->to( controller => 'taratureaut', action => 'get_data'                     );
    $auth->post('/dat_tarature_aut_get_events'     )->to( controller => 'taratureaut', action => 'get_events'                   );
    $auth->post('/dat_tarature_aut_get_events_list')->to( controller => 'taratureaut', action => 'get_events_list'              );
    $auth->post('/dat_tarature_aut_get_chart'      )->to( controller => 'taratureaut', action => 'get_chart'                    );

    # DATI - ALLARMI - AJAX
    $auth->post('/dat_allarmi_get_stations'     )->to( controller => 'common'   , action => 'get_stations_by_net_province' );
    $auth->post('/dat_allarmi_get_alarms_bydate')->to( controller => 'utilities', action => 'get_alarms_bydate'            );

    # DATi - WARNING - AJAX
    $auth->post('/dat_warning_get_stations'            )->to( controller => 'common'   , action => 'get_stations'             );
    $auth->post('/dat_warning_get_instruments_messages')->to( controller => 'utilities', action => 'get_instruments_messages' );

    # !!AVANZATE
    $auth->get('/str_ava_analyser'   )->requires(has_priv => '/str_ava_analyser'   )->to( controller => 'avaanalyser'   , action => 'ava_analyser'    );
    $auth->get('/str_ava_visualizer' )->requires(has_priv => '/str_ava_visualizer' )->to( controller => 'avavisualizer' , action => 'ava_visualizer'  );
    $auth->get('/str_ava_validazione')->requires(has_priv => '/str_ava_validazione')->to( controller => 'avavalidazione', action => 'ava_validazione' );

    # AVANZATE - ANALYSER - AJAX
    $auth->post('/str_ava_ana_get_stations_bynets')->to( controller => 'avaanalyser', action => 'get_stations_by_nets' );
    $auth->get('/str_ava_ana_get_analyser_groups' )->requires(has_priv => '/str_ava_analyser')->to( controller => 'avaanalyser', action => 'get_analyser_groups' );
    $auth->get('/str_ava_ana_get_group_stations'  )->requires(has_priv => '/str_ava_analyser')->to( controller => 'avaanalyser', action => 'get_group_stations'  );
    $auth->post('/str_ava_ana_get_subgroup_by_id' )->to( controller => 'avaanalyser', action => 'get_subgroup_by_id'   );
    $auth->post('/str_ava_ana_put_subgroup'       )->to( controller => 'avaanalyser', action => 'put_subgroup'         );
    $auth->post('/str_ava_ana_del_subgroup'       )->to( controller => 'avaanalyser', action => 'del_subgroup'         );

    # AVANZATE - VISUALIZER - AJAX
    $auth->post('/str_ava_vis_get_stations'           )->to( controller => 'common'       , action => 'get_stations_by_net_province'     );
    $auth->post('/str_ava_vis_get_categories'         )->to( controller => 'avavisualizer', action => 'get_categories'                   );
    $auth->post('/str_ava_vis_get_category_byid'      )->to( controller => 'avavisualizer', action => 'get_category_byid'                );
    $auth->post('/str_ava_vis_get_params_bystid_types')->to( controller => 'avavisualizer', action => 'get_parameters_by_stations_types' );
    $auth->post('/str_ava_vis_get_parameters'         )->to( controller => 'avavisualizer', action => 'get_parameters'                   );
    $auth->post('/str_ava_vis_get_form_options'       )->to( controller => 'avavisualizer', action => 'get_form_options'                 );
    $auth->post('/str_ava_vis_get_params_info'        )->to( controller => 'avavisualizer', action => 'get_params_info'                  );
    $auth->post('/str_ava_vis_get_macros_by_page'     )->to( controller => 'avavisualizer', action => 'get_macros_by_page'               );
    $auth->post('/str_ava_vis_get_automatic_macros'   )->to( controller => 'avavisualizer', action => 'get_automatic_macros'             );
    $auth->post('/str_ava_vis_put_category'           )->to( controller => 'avavisualizer', action => 'put_category'                     );
    $auth->post('/str_ava_vis_put_page'               )->to( controller => 'avavisualizer', action => 'put_page_macros'                  );
    $auth->post('/str_ava_vis_put_page_duplication'   )->to( controller => 'avavisualizer', action => 'put_page_duplication'             );
    $auth->post('/str_ava_vis_del_category'           )->to( controller => 'avavisualizer', action => 'del_category'                     );
    $auth->post('/str_ava_vis_del_page'               )->to( controller => 'avavisualizer', action => 'del_page'                         );

    # AVANZATE - VALIDAZIONE - AJAX
    $auth->post('/str_ava_val_get_stations_bynets'          )->to( controller => 'common'        , action => 'get_stations_by_nets'          );
    $auth->get('/str_ava_val_get_validation_groups'         )->requires(has_priv => '/str_ava_validazione')->to( controller => 'avavalidazione', action => 'get_validation_groups' );
    $auth->get('/str_ava_val_get_group_stations'            )->requires(has_priv => '/str_ava_validazione')->to( controller => 'avavalidazione', action => 'get_group_stations'    );
    $auth->post('/str_ava_val_get_subgroup_by_id'           )->to( controller => 'avavalidazione', action => 'get_subgroup_by_id'            );
    $auth->post('/str_ava_val_put_subgroup'                 )->to( controller => 'avavalidazione', action => 'put_subgroup'                  );
    $auth->post('/str_ava_val_del_subgroup'                 )->to( controller => 'avavalidazione', action => 'del_subgroup'                  );
    $auth->post('/str_ava_val_get_abnormals_data'           )->to( controller => 'avavalidazione', action => 'get_abnormals_data'            );
    $auth->post('/str_ava_val_get_abnormals_data_by_id'     )->to( controller => 'avavalidazione', action => 'get_abnormals_data_by_id'      );
    $auth->post('/str_ava_val_put_abnormals_limit'          )->to( controller => 'avavalidazione', action => 'put_abnormals_limit'           );
    $auth->post('/str_ava_val_del_abnormals_limit'          )->to( controller => 'avavalidazione', action => 'del_abnormals_limit'           );
    $auth->post('/str_ava_val_get_stations'                 )->to( controller => 'common'        , action => 'get_stations'                  );
    $auth->post('/str_ava_val_get_parameters'               )->to( controller => 'common'        , action => 'get_parameters'                );
    $auth->post('/str_ava_val_get_stat_abnormals_data'      )->to( controller => 'avavalidazione', action => 'get_stat_abnormals_data'       );
    $auth->post('/str_ava_val_get_stat_abnormals_data_by_id')->to( controller => 'avavalidazione', action => 'get_stat_abnormals_data_by_id' );
    $auth->post('/str_ava_val_put_stat_abnormals_limit'     )->to( controller => 'avavalidazione', action => 'put_stat_abnormals_limit'      );
    $auth->post('/str_ava_val_del_stat_abnormals_limit'     )->to( controller => 'avavalidazione', action => 'del_stat_abnormals_limit'      );

    # !!STATISTICHE
    $auth->get('/stat_indicatori'     )->requires(has_priv => '/stat_indicatori'     )->to( controller => 'indicatori'  , action => 'indicatori'      );
    $auth->get('/stat_reportistica'   )->requires(has_priv => '/stat_reportistica'   )->to( controller => 'reportistica', action => 'reportistica'    );
    $auth->get('/stat_ana_validazione')->requires(has_priv => '/stat_ana_validazione')->to( controller => 'statistiche' , action => 'ana_validazione' );
    $auth->get('/stat_ana_copertura'  )->requires(has_priv => '/stat_ana_copertura'  )->to( controller => 'statistiche' , action => 'copertura'       );
    $auth->get('/stat_info'           )->requires(has_priv => '/stat_info'           )->to( controller => 'statistiche' , action => 'info'            );

    # STATISTICHE - AJAX
    $auth->post('/stat_indicatori_get_stations'         )->to( controller => 'common'     , action => 'get_stations_by_net_province' );
    $auth->post('/stat_indicatori_get_pdf_files'        )->to( controller => 'indicatori' , action => 'get_pdf_files'                );
    $auth->post('/stat_indicatori_get_table_by_date'    )->to( controller => 'indicatori' , action => 'get_table_by_date'            );
    $auth->post('/stat_indicatori_get_table_by_station' )->to( controller => 'indicatori' , action => 'get_table_by_station'         );
    $auth->post('/stat_indicatori_put_stats_calculation')->to( controller => 'indicatori' , action => 'put_stats_calculation'        );
    $auth->post('/stat_indicatori_put_pdf_by_date_net'  )->to( controller => 'indicatori' , action => 'put_pdf'                      );

    # REPORTISTICA - AJAX
    $auth->post('/stat_reportistica_get_stations_by_zone' )->to( controller => 'reportistica' , action => 'get_stations_by_zone'  );
    $auth->post('/stat_reportistica_get_params_by_zone'   )->to( controller => 'reportistica' , action => 'get_params_by_zone'    );
    $auth->post('/stat_reportistica_get_reports'          )->to( controller => 'reportistica' , action => 'get_reports'           );
    $auth->post('/stat_reportistica_get_check_data'       )->to( controller => 'reportistica' , action => 'get_check_data'        );
    $auth->post('/stat_reportistica_get_stats_by_station' )->to( controller => 'reportistica' , action => 'get_stats_by_station'  );
    $auth->post('/stat_reportistica_get_stats_by_type'    )->to( controller => 'reportistica' , action => 'get_stats_by_type'     );
    $auth->post('/stat_reportistica_put_stats_calculation')->to( controller => 'reportistica' , action => 'put_stats_calculation' );
    $auth->post('/stat_reportistica_put_pdf'              )->to( controller => 'reportistica' , action => 'put_pdf'               );
    $auth->post('/stat_reportistica_del_report'           )->to( controller => 'reportistica' , action => 'del_report'            );

    # STATISTICHE - COPERTURA - AJAX
    $auth->post('/stat_ana_validazione_get_stations'           )->to( controller => 'common'     , action => 'get_stations_by_net_province' );
    $auth->post('/stat_ana_validazione_get_validation_analysis')->to( controller => 'statistiche', action => 'get_user_validation_analysis' );
    $auth->post('/stat_ana_validazione_get_csv_data'           )->to( controller => 'statistiche', action => 'get_csv_data'                 );
    $auth->post('/stat_ana_validazione_get_network_csv_data'   )->to( controller => 'statistiche', action => 'get_network_csv_data'         );
    $auth->post('/stat_ana_validazione_get_downloads'          )->to( controller => 'statistiche', action => 'get_downloads'                );

    # STATISTICHE - COPERTURA - AJAX
    $auth->post('/stat_ana_copertura_get_stations'     )->to( controller => 'common'     , action => 'get_stations_by_net_province' );
    $auth->post('/stat_ana_copertura_get_data_coverage')->to( controller => 'statistiche', action => 'get_data_coverage'            );

    # !!REPORT
    $auth->get('/rep_qa_sopralluoghi'           )->requires(has_priv => '/rep_qa_sopralluoghi')->to( controller => 'qasopralluoghi', action => 'qa_sopralluoghi' );
    $auth->get('/rep_qa_tarature/<rpid:num>'    )->requires(has_priv => '/rep_qa_tarature'    )->to( controller => 'qatarature'    , action => 'qa_tarature'    , rpid => undef );
    $auth->get('/rep_qa_manutenzioni/<rpid:num>')->requires(has_priv => '/rep_qa_manutenzioni')->to( controller => 'qamanutenzioni', action => 'qa_manutenzioni', rpid => undef );
    $auth->get('/rep_verbali'                   )->requires(has_priv => '/rep_verbali'        )->to( controller => 'verbali'       , action => 'verbali'         );
    $auth->get('/rep_alims'                     )->requires(has_priv => '/rep_alims'          )->to( controller => 'alims'         , action => 'alims'           );
    $auth->get('/rep_automatici'                )->requires(has_priv => '/rep_automatici'     )->to( controller => 'utilities'     , action => 'automatici'      );

    # REPORT - QA SOPRALLUOGHI - AJAX
    $auth->post('/rep_qa_sopralluoghi_get_municipalities' )->to( controller => 'common'        , action => 'get_municipalities'      );
    $auth->post('/rep_qa_sopralluoghi_get_reports'        )->to( controller => 'qasopralluoghi', action => 'get_reports'             );
    $auth->post('/rep_qa_sopralluoghi_get_selected_report')->to( controller => 'qasopralluoghi', action => 'get_selected_report'     );
    $auth->get( '/rep_qa_sopralluoghi_get_pdf'            )->requires(has_priv => '/rep_qa_manutenzioni')->to( controller => 'qasopralluoghi', action => 'get_pdf' );
    $auth->post('/rep_qa_sopralluoghi_put_report'         )->to( controller => 'qasopralluoghi', action => 'put_report'              );
    $auth->post('/rep_qa_sopralluoghi_del_report'         )->to( controller => 'qasopralluoghi', action => 'del_selected_report'     );
    $auth->post('/rep_qa_sopralluoghi_selected_attachment')->to( controller => 'qasopralluoghi', action => 'del_selected_attachment' );

    # REPORT - QA TARATURE - AJAX
    $auth->post('/rep_qa_tarature_get_stations'       )->to( controller => 'common'    , action => 'get_stations_by_net_province' );
    $auth->post('/rep_qa_tarature_get_instruments'    )->to( controller => 'common'    , action => 'get_instruments'              );
    $auth->post('/rep_qa_tarature_get_metadata'       )->to( controller => 'qatarature', action => 'get_metadata'                 );
    $auth->post('/rep_qa_tarature_get_reports'        )->to( controller => 'qatarature', action => 'get_reports'                  );
    $auth->post('/rep_qa_tarature_get_selected_report')->to( controller => 'qatarature', action => 'get_selected_report'          );
    $auth->get( '/rep_qa_tarature_get_pdf'            )->requires(has_priv => '/rep_qa_tarature')->to( controller => 'qatarature', action => 'get_pdf'       );
    $auth->get( '/rep_qa_tarature_get_total_pdf'      )->requires(has_priv => '/rep_qa_tarature')->to( controller => 'qatarature', action => 'get_total_pdf' );
    $auth->post('/rep_qa_tarature_put_report'         )->to( controller => 'qatarature', action => 'put_report'                   );
    $auth->post('/rep_qa_tarature_del_report'         )->to( controller => 'qatarature', action => 'del_report'                   );
    $auth->post('/rep_qa_tarature_selected_attachment')->to( controller => 'qatarature', action => 'del_selected_attachment'      );

    # REPORT - QA MANUTENZIONI - AJAX
    $auth->post('/rep_qa_manutenzioni_get_stations'       )->to( controller => 'common'        , action => 'get_stations_by_net_province' );
    $auth->post('/rep_qa_manutenzioni_get_instruments'    )->to( controller => 'qamanutenzioni', action => 'get_instruments'              );
    $auth->post('/rep_qa_manutenzioni_get_miscellanies'   )->to( controller => 'qamanutenzioni', action => 'get_miscellanies'             );
    $auth->post('/rep_qa_manutenzioni_get_operations'     )->to( controller => 'qamanutenzioni', action => 'get_operations'               );
    $auth->post('/rep_qa_manutenzioni_get_calibrations'   )->to( controller => 'qamanutenzioni', action => 'get_calibrations'             );
    $auth->post('/rep_qa_manutenzioni_get_reports'        )->to( controller => 'qamanutenzioni', action => 'get_reports'                  );
    $auth->post('/rep_qa_manutenzioni_get_selected_report')->to( controller => 'qamanutenzioni', action => 'get_selected_report'          );
    $auth->get( '/rep_qa_manutenzioni_get_pdf'            )->requires(has_priv => '/rep_qa_manutenzioni')->to( controller => 'qamanutenzioni', action => 'get_pdf'       );
    $auth->get( '/rep_qa_manutenzioni_get_total_pdf'      )->requires(has_priv => '/rep_qa_manutenzioni')->to( controller => 'qamanutenzioni', action => 'get_total_pdf' );
    $auth->post('/rep_qa_manutenzioni_put_report'         )->to( controller => 'qamanutenzioni', action => 'put_report'                  );
    $auth->post('/rep_qa_manutenzioni_del_report'         )->to( controller => 'qamanutenzioni', action => 'del_report'                  );

    # REPORT - VERBALI - AJAX
    $auth->post('/rep_verbali_get_reports'        )->to( controller => 'verbali', action => 'get_reports'         );
    $auth->post('/rep_verbali_get_selected_report')->to( controller => 'verbali', action => 'get_selected_report' );
    $auth->get( '/rep_verbali_get_pdf'            )->requires(has_priv => '/rep_verbali')->to( controller => 'verbali', action => 'get_pdf' );
    $auth->post('/rep_verbali_put_report'         )->to( controller => 'verbali', action => 'put_report'          );
    $auth->post('/rep_verbali_del_selected_report')->to( controller => 'verbali', action => 'del_selected_report' );

    # REPORT - VERBALE ALIMS - AJAX
    $auth->post('/rep_alims_get_stations'       )->to( controller => 'alims' , action => 'get_stations'        );
    $auth->post('/rep_alims_get_instruments'    )->to( controller => 'common', action => 'get_instruments'     );
    $auth->post('/rep_alims_get_reports'        )->to( controller => 'alims' , action => 'get_reports'         );
    $auth->post('/rep_alims_get_selected_report')->to( controller => 'alims' , action => 'get_selected_report' );
    $auth->post('/rep_alims_get_volume'         )->to( controller => 'alims' , action => 'get_volume'          );
    $auth->get( '/rep_alims_get_pdf'            )->requires(has_priv => '/rep_alims')->to( controller => 'alims', action => 'get_pdf' );
    $auth->post('/rep_alims_put_report'         )->to( controller => 'alims' , action => 'put_report'          );
    $auth->post('/rep_alims_put_send'           )->to( controller => 'alims' , action => 'put_send'            );
    $auth->post('/rep_alims_del_report'         )->to( controller => 'alims' , action => 'del_report'          );

    $auth->post('/rep_automatici_get_ws_status'   )->to(controller => 'utilities' ,  action => 'get_ws_status_bydate'   );

    # !! TICKETS
    $auth->get('/plan_attivita'         )->requires(has_priv => '/plan_attivita')->to( controller => 'planperiferia', action => 'attivita'              );

    # TICKETS - ATTIVITÀ - AJAX
    $auth->post('/plan_attivita_get_stations'       )->to( controller => 'common'       , action => 'get_stations'        );
    $auth->post('/plan_attivita_get_equipments'     )->to( controller => 'planperiferia', action => 'get_equipments'      );
    $auth->post('/plan_attivita_get_maintenances'   )->to( controller => 'planperiferia', action => 'get_maintenances'    );
    $auth->post('/plan_attivita_get_tickets'        )->to( controller => 'planperiferia', action => 'get_tickets'         );
    $auth->post('/plan_attivita_get_selected_ticket')->to( controller => 'planperiferia', action => 'get_selected_ticket' );
    $auth->post('/plan_attivita_put_ticket'         )->to( controller => 'planperiferia', action => 'put_ticket'          );
    $auth->post('/plan_attivita_put_ticket_status'  )->to( controller => 'planperiferia', action => 'put_ticket_status'   );
    $auth->post('/plan_attivita_del_selected_ticket')->to( controller => 'planperiferia', action => 'del_selected_ticket' );

    # !! IMPOSTAZIONI
    $auth->get('/cnf_stazioni/<stid:num>' )->requires(has_priv => '/cnf_stazioni' )->to( controller => 'cnfstazioni' , action => 'stazioni' , stid => undef );
    $auth->get('/cnf_parametri/<stid:num>')->requires(has_priv => '/cnf_parametri')->to( controller => 'cnfparametri', action => 'parametri', stid => undef );
    $auth->get('/cnf_strumenti'           )->requires(has_priv => '/cnf_strumenti')->to( controller => 'cnfstrumenti', action => 'strumenti'                );
    $auth->get('/cnf_bombole'             )->requires(has_priv => '/cnf_bombole'  )->to( controller => 'cnfbombole'  , action => 'bombole'                  );
    $auth->get('/cnf_campagne'            )->requires(has_priv => '/cnf_campagne' )->to( controller => 'cnfcampagne' , action => 'campagne'                 );
    $auth->get('/cnf_dotazioni'           )->requires(has_priv => '/cnf_dotazioni')->to( controller => 'cnfdotazioni', action => 'dotazioni'                );

    # IMPOSTAZIONI RETE - STAZIONI - AJAX
    $auth->post('/cnf_stazioni_get_provinces'               )->to(controller => 'common'   , action => 'get_provinces'              );
    $auth->post('/cnf_stazioni_get_municipalities'          )->to(controller => 'common'   , action => 'get_municipalities'         );
    $auth->post('/cnf_stazioni_get_municipality_by_coords'  )->to(controller => 'common'   , action => 'get_municipality_by_coords' );
    $auth->post('/cnf_stazioni_get_stations'                )->to(controller => 'cnfstazioni',  action => 'get_stations'           );
    $auth->post('/cnf_stazioni_get_station_by_id'           )->to(controller => 'cnfstazioni',  action => 'get_station_by_id'      );
    $auth->get ('/cnf_stazioni_get_pdf'                     )->to(controller => 'cnfstazioni',  action => 'get_pdf' );
    $auth->post('/cnf_stazioni_put_station'                 )->to(controller => 'cnfstazioni',  action => 'put_station'            );
    $auth->post('/cnf_stazioni_put_pdf'                     )->to(controller => 'cnfstazioni',  action => 'put_pdf'                );
    $auth->post('/cnf_stazioni_del_station'                 )->to(controller => 'cnfstazioni',  action => 'del_station'            );
    # IMPOSTAZIONI RETE - PARAMETRI - AJAX
    $auth->post('/cnf_parametri_get_parameters_by_stid'      )->to(controller => 'cnfparametri',  action => 'get_parameters_by_stid'    );
    $auth->post('/cnf_parametri_get_parameter_by_stprid'     )->to(controller => 'cnfparametri',  action => 'get_parameter_by_stprid'   );
    $auth->post('/cnf_parametri_put_station_param'           )->to(controller => 'cnfparametri',  action => 'put_station_param'         );
    $auth->post('/cnf_parametri_put_config_file'             )->to(controller => 'cnfparametri',  action => 'put_config_file'           );
    $auth->post('/cnf_parametri_put_config_params'           )->to(controller => 'cnfparametri',  action => 'put_config_params'         );
    $auth->post('/cnf_parametri_del_station_param'           )->to(controller => 'cnfparametri',  action => 'del_station_param'         );

    # IMPOSTAZIONI RETE - STRUMENTI - AJAX
    $auth->post('/cnf_strumenti_get_stations'                )->to( controller => 'common'      , action => 'get_stations_by_net_province' );
    $auth->post('/cnf_strumenti_get_stations_bynets'         )->to( controller => 'common'      , action => 'get_stations_by_nets'         );
    $auth->post('/cnf_strumenti_get_instruments'             )->to( controller => 'cnfstrumenti', action => 'get_instruments'              );
    $auth->post('/cnf_strumenti_get_instruments_for_location')->to( controller => 'cnfstrumenti', action => 'get_instruments_for_location' );
    $auth->post('/cnf_strumenti_get_instrument_by_id'        )->to( controller => 'cnfstrumenti', action => 'get_instrument_by_id'         );
    $auth->post('/cnf_strumenti_get_params_by_instr_type'    )->to( controller => 'cnfstrumenti', action => 'get_params_by_instr_type'     );
    $auth->post('/cnf_strumenti_get_location_by_id'          )->to( controller => 'cnfstrumenti', action => 'get_location_by_id'           );
    $auth->post('/cnf_strumenti_put_instrument'              )->to( controller => 'cnfstrumenti', action => 'put_instrument'               );
    $auth->post('/cnf_strumenti_put_location'                )->to( controller => 'cnfstrumenti', action => 'put_location'                 );
    $auth->post('/cnf_strumenti_put_location_closure'        )->to( controller => 'cnfstrumenti', action => 'put_location_closure'         );
    $auth->post('/cnf_strumenti_del_instrument'              )->to( controller => 'cnfstrumenti', action => 'del_instrument'               );
    $auth->post('/cnf_strumenti_del_attachment'              )->to( controller => 'cnfstrumenti', action => 'del_attachment'               );

    # IMPOSTAZIONI RETE - BOMBOLE - AJAX
    $auth->post('/cnf_bombole_get_stations'              )->to( controller => 'common'    , action => 'get_stations_by_net_province' );
    $auth->post('/cnf_bombole_get_stations_bynets'       )->to( controller => 'common'    , action => 'get_stations_by_nets'         );
    $auth->post('/cnf_bombole_get_cylinders'             )->to( controller => 'cnfbombole', action => 'get_cylinders'                );
    $auth->post('/cnf_bombole_get_cylinders_for_location')->to( controller => 'cnfbombole', action => 'get_cylinders_for_location'   );
    $auth->post('/cnf_bombole_get_cylinder_by_id'        )->to( controller => 'cnfbombole', action => 'get_cylinder_by_id'           );
    $auth->post('/cnf_bombole_get_location_by_id'        )->to( controller => 'cnfbombole', action => 'get_location_by_id'           );
    $auth->post('/cnf_bombole_put_cylinder'              )->to( controller => 'cnfbombole', action => 'put_cylinder'                 );
    $auth->post('/cnf_bombole_put_location'              )->to( controller => 'cnfbombole', action => 'put_location'                 );
    $auth->post('/cnf_bombole_put_location_closure'      )->to( controller => 'cnfbombole', action => 'put_location_closure'         );
    $auth->post('/cnf_bombole_del_cylinder'              )->to( controller => 'cnfbombole', action => 'del_cylinder'                 );
    $auth->post('/cnf_bombole_del_attachment'            )->to( controller => 'cnfbombole', action => 'del_attachment'               );

    # IMPOSTAZIONI RETE - CAMPAGNE -AJAX
    $auth->post('/cnf_campagne_get_provinces'              )->to( controller => 'common'     , action => 'get_provinces'               );
    $auth->post('/cnf_campagne_get_municipalities'         )->to( controller => 'common'     , action => 'get_municipalities'          );
    $auth->post('/cnf_campagne_get_municipality_by_coords' )->to( controller => 'common'     , action => 'get_municipality_by_coords'  );
    $auth->post('/cnf_campagne_get_roaming_stations_bynets')->to( controller => 'cnfcampagne', action => 'get_roaming_stations_bynets' );
    $auth->post('/cnf_campagne_get_campaigns'              )->to( controller => 'cnfcampagne', action => 'get_campaigns'               );
    $auth->post('/cnf_campagne_get_sites'                  )->to( controller => 'cnfcampagne', action => 'get_sites'                   );
    $auth->post('/cnf_campagne_get_site_by_id'             )->to( controller => 'cnfcampagne', action => 'get_site_by_id'              );
    $auth->post('/cnf_campagne_get_location_by_id'         )->to( controller => 'cnfcampagne', action => 'get_location_by_id'          );
    $auth->post('/cnf_campagne_put_campaign'               )->to( controller => 'cnfcampagne', action => 'put_campaign'                );
    $auth->post('/cnf_campagne_put_campaign_status'        )->to( controller => 'cnfcampagne', action => 'put_campaign_status'         );
    $auth->post('/cnf_campagne_put_site'                   )->to( controller => 'cnfcampagne', action => 'put_site'                    );
    $auth->post('/cnf_campagne_put_location'               )->to( controller => 'cnfcampagne', action => 'put_location'                );
    $auth->post('/cnf_campagne_put_location_closure'       )->to( controller => 'cnfcampagne', action => 'put_location_closure'        );
    $auth->post('/cnf_campagne_del_campaign'               )->to( controller => 'cnfcampagne', action => 'del_campaign'                );
    $auth->post('/cnf_campagne_del_attachment'             )->to( controller => 'cnfcampagne', action => 'del_attachment'              );
    $auth->post('/cnf_campagne_del_site'                   )->to( controller => 'cnfcampagne', action => 'del_site'                    );

    # IMPOSTAZIONI RETE - DOTAZIONI - AJAX
    $auth->post('/cnf_dotazioni_get_stations'                 )->to( controller => 'common'      , action => 'get_stations'                  );
    $auth->post('/cnf_dotazioni_get_stations_bynets'          )->to( controller => 'common'      , action => 'get_stations_by_nets'          );
    $auth->post('/cnf_dotazioni_get_miscellanies'             )->to( controller => 'cnfdotazioni', action => 'get_miscellanies'              );
    $auth->post('/cnf_dotazioni_get_miscellanies_for_location')->to( controller => 'cnfdotazioni', action => 'get_miscellanies_for_location' );
    $auth->post('/cnf_dotazioni_get_miscellany_by_id'         )->to( controller => 'cnfdotazioni', action => 'get_miscellany_by_id'          );
    $auth->post('/cnf_dotazioni_get_location_by_id'           )->to( controller => 'cnfdotazioni', action => 'get_location_by_id'            );
    $auth->post('/cnf_dotazioni_put_miscellany'               )->to( controller => 'cnfdotazioni', action => 'put_miscellany'                );
    $auth->post('/cnf_dotazioni_put_location'                 )->to( controller => 'cnfdotazioni', action => 'put_location'                  );
    $auth->post('/cnf_dotazioni_put_location_closure'         )->to( controller => 'cnfdotazioni', action => 'put_location_closure'          );
    $auth->post('/cnf_dotazioni_del_miscellany'               )->to( controller => 'cnfdotazioni', action => 'del_miscellany'                );
    $auth->post('/cnf_dotazioni_del_attachment'               )->to( controller => 'cnfdotazioni', action => 'del_attachment'                );

    # !! ANAGRAFICA SISTEMA
    $auth->get('/ang_parametri')->requires(has_priv => '/ang_parametri')->to( controller => 'angparametri', action => 'parametri' );
    $auth->get('/ang_strumenti')->requires(has_priv => '/ang_strumenti')->to( controller => 'anagrafica'  , action => 'strumenti' );
    $auth->get('/ang_stazioni' )->requires(has_priv => '/ang_stazioni' )->to( controller => 'anagrafica'  , action => 'stazioni'  );

    # ANAGRAFICA - PARAMETRI - AJAX
    $auth->post('/ang_parametri_get_parameters'          )->to( controller => 'angparametri', action => 'get_parameters'           );
    $auth->post('/ang_parametri_get_parameters_by_types' )->to( controller => 'angparametri', action => 'get_parameters_by_types'  );
    $auth->post('/ang_parametri_get_parameter_by_id'     )->to( controller => 'angparametri', action => 'get_parameter_by_id'      );
    $auth->post('/ang_parametri_put_parameter'           )->to( controller => 'angparametri', action => 'put_parameter'            );
    $auth->post('/ang_parametri_del_selected_coefficient')->to( controller => 'angparametri', action => 'del_selected_coefficient' );

    # ANAGRAFICA - STAZIONI AJAX
    $auth->post('/ang_stazioni_get_parameters'        )->to( controller => 'anagrafica' , action => 'get_parameters'         );
    $auth->post('/ang_stazioni_get_instruments'       )->to( controller => 'anagrafica' , action => 'get_instruments'        );
    $auth->post('/ang_stazioni_get_stations'          )->to( controller => 'cnfstazioni', action => 'get_stations'           );
    $auth->post('/ang_stazioni_get_station_equipments')->to( controller => 'anagrafica' , action => 'get_station_equipments' );

    # ANAGRAFICA - STRUMENTI AJAX
    $auth->post('/ang_strumenti_get_operations')->to( controller => 'anagrafica', action => 'get_operations' );

    # !! DIVULGAZIONE
    $auth->get('/div_telegram'  )->requires(has_priv => '/div_telegram'  )->to( controller => 'telegram'    , action => 'telegram'  );
    $auth->get('/div_email_gest')->requires(has_priv => '/div_email_gest')->to( controller => 'emailgest'   , action => 'emailgest' );
    $auth->get('/div_notifiche' )->requires(has_priv => '/div_notifiche' )->to( controller => 'divulgazione', action => 'notifiche' );

    # DIVULGAZIONE - TELEGRAM - AJAX
    $auth->post('/div_tel_get_messages'        )->to( controller => 'telegram', action => 'get_messages'         );
    $auth->post('/div_tel_get_selected_message')->to( controller => 'telegram', action => 'get_selected_message' );
    $auth->post('/div_tel_put_message'         )->to( controller => 'telegram', action => 'put_message'          );
    $auth->post('/div_tel_del_selected_message')->to( controller => 'telegram', action => 'del_selected_message' );

    # DIVULGAZIONE - GESTIONE EMAIL - AJAX
    $auth->post('/div_gest_get_mailing_lists'        )->to( controller => 'emailgest', action => 'get_mailing_lists'         );
    $auth->post('/div_gest_get_selected_mailing_list')->to( controller => 'emailgest', action => 'get_selected_mailing_list' );
    $auth->post('/div_gest_get_external_mails'       )->to( controller => 'emailgest', action => 'get_external_mails'        );
    $auth->post('/div_gest_put_mailing_list'         )->to( controller => 'emailgest', action => 'put_mailing_list'          );
    $auth->post('/div_gest_put_external_mail'        )->to( controller => 'emailgest', action => 'put_external_mail'         );
    $auth->post('/div_gest_del_mailing_list'         )->to( controller => 'emailgest', action => 'del_mailing_list'          );
    $auth->post('/div_gest_del_external_mail'        )->to( controller => 'emailgest', action => 'del_external_mail'         );

    $auth->post('/div_notifiche_get_stations_grants'    )->to(controller => 'divulgazione',    action => 'get_stations_grants'      );
    $auth->post('/div_notifiche_put_grants'             )->to(controller => 'divulgazione',    action => 'put_grants'               );

    # INFOARIA
    $auth->get('/info_dataset_e2a')->requires(has_priv => '/info_dataset_e2a')->to( controller => 'infoaria', action => 'dataset_e2a' );
    $auth->get('/info_dataset_e1a')->requires(has_priv => '/info_dataset_e1a')->to( controller => 'infoaria', action => 'dataset_e1a' );

    # !! INFOARIA - AJAX
    $auth->post('/info_dataset_e_get_stations'                 )->to( controller => 'common'  , action => 'get_stations_by_net_province'  );
    $auth->post('/info_dataset_e_get_stations_params'          )->to( controller => 'infoaria', action => 'get_stations_params'           );
    $auth->post('/info_dataset_e_get_stations_params_e2a_recap')->to( controller => 'infoaria', action => 'get_stations_params_e2a_recap' );
    $auth->post('/info_dataset_e_get_stations_params_e1a_recap')->to( controller => 'infoaria', action => 'get_stations_params_e1a_recap' );
    $auth->post('/info_dataset_e_get_e1a_files'                )->to( controller => 'infoaria', action => 'get_e1a_files'                 );
    $auth->post('/info_dataset_e_put_status'                   )->to( controller => 'infoaria', action => 'put_status'                    );
    $auth->post('/info_dataset_e_put_e1a_creation'             )->to( controller => 'infoaria', action => 'put_e1a_creation'              );

    $auth->get('/demo')->requires(has_priv => '/demo')->to( controller => 'demo', action => 'demo' );

    # !! PAGINE CUSTOM
    $auth->get('/dat_horiba'       )->requires(has_priv => '/dat_horiba')->to( controller => 'customized'  , action => 'horiba'     );
    $auth->get('/custom_get_report')->requires(has_priv => '/'          )->to( controller => 'customized'  , action => 'get_report' );

    # AJAX HORIBA
    $auth->post('/dat_horiba_get_images')->to(controller => 'customized' , action => 'get_horiba_images'    );

    # !!VARIE
    $auth->get('/faq'            )->requires(has_priv => '/faq'     )->to( controller => 'faq'      , action => 'faq'                 );
    $auth->get('/faq_tech'       )->requires(has_priv => '/faq_tech')->to( controller => 'faq'      , action => 'faq_tech'            );
    $auth->get('/map'            )->requires(has_priv => '/map'     )->to( controller => 'utilities', action => 'map'                 );
    $auth->get('/help/<page:txt>')->requires(has_priv => '/help'    )->to( controller => 'utilities', action => 'help', page => undef );

    # FAQ - AJAX
    $auth->post('/faq_get_argument')->to( controller => 'faq', action => 'get_page_arguments' );
    $auth->post('/faq_get_key'     )->to( controller => 'faq', action => 'search_key'         );
    $auth->post('/faq_put_page'    )->to( controller => 'faq', action => 'put_page'           );
    $auth->post('/faq_put_argument')->to( controller => 'faq', action => 'put_argument'       );
    $auth->post('/faq_del_argument')->to( controller => 'faq', action => 'del_argument'       );
}

1;

=head1 startup

Questa funzione verra' eseguita una volta sola, all'avvio del server.

Argomenti:  URL RICHIESTO

Lista delle routes:

=over

=item /                                       GET

Pagina di login.

=item /login                                  GET

Funzione che renderizza loghi e menu del portale, in base all'utente.

=item /logout                                 GET

Effettua il logout dall'applicativo con redirect alla pagina di login.

=item /str_dataview                           GET

Strumento Dataview: visualizzazione in tempo reale, su mappa georeferenziata, dei dati delle stazioni di monitoraggio.

=item /str_dataview_station/:stid/:tab        GET

Pagina di dettaglio stazione dello strumento Dataview.

=item /str_dataview_download                  GET

Pagina di scarico dati dell'applicativo Dataview.

=item /primo_login                            GET

Pagina per effettuare il cambio password a seguito del primo login.

=item /password                               GET

Pagina di modifica della password.

=item /usr_admin                              GET

Pagina di Amministrazione del portale.

=item /usr_sysadmin                           GET

Pagina di gestione impostazioni del System Admin

=item /usr_profile                            GET

Pagina gestione profilo utente.

=item /usr_options                            GET

Pagina di gestione della homepage e del menu da parte dell'utente.

=item /calendario                             GET

Pagina di visualizzazione su calendario delle attività da svolgere o gia' effettuate sulla propria rete di appartenenza.

=item /str_analyser                           GET

Strumento Analyser: analisi, elaborazione ed utilizzo dei dati chimico-meteorologici provenienti dalle stazioni del sistema.

=item /str_visualizer                         GET

Strumento Visualizer: visualizzazione di dati, filtrati per data, delle stazioni della/e propria/e rete/i di appartenenza organizzati in raggruppamenti, chiamati "Macro", impostabili dall'utente.

=item /str_sinottici                          GET

Pagina di visualizzazione dei sinottici dei vari impianti/vasche appartenenti alla propria rete idrica.

=item /str_openair                            GET

Pagina di visualizzazione e generazione di grafici riguardanti gli inquinanti delle stazioni attraverso l'utilizzo del pacchetto 'OpenAir' di R.

=item /str_mapper                             GET

Pagina di visualizzazione delle stazioni della/e propria/e rete/i di appartenenza all'interno di una mappa attraverso l'utilizzo di marker georeferenziati.

=item /dat_validazione                        GET

Strumento Validazione: strumento utilizzato per la validazione dei dati.

=item /dat_diagnostici                        GET

Pagina di visualizzazione dei dati diagnostici delle stazioni appartenenti alla/e propria/e rete/i.

=item /dat_tarature_aut                       GET

Pagina di visualizzazione dei risultati delle tarature automatiche in formato tabellare o grafico.

=item /dat_allarmi                            GET

Pagina di visualizzazione degli allarmi riferiti alle stazioni appartenenti alla/e propria/e rete/i.

=item /dat_copertura                          GET

Pagina di visualizzazione della percentuale mensile di ricezione dei dati relativi ai parametri di ogni stazione associata al portale.

=item /dat_warning                            GET

Pagina di visualizzazione dei warning degli strumenti suddivisi per categoria e poi per stazione.

=item /str_ava_analyser                       GET

Pagina di creazione e gestione dei gruppi di stazioni da utilizzare nell'albero di destra, presente all'interno dell'applicativo "Analyser", sotto "Lista delle stazioni".

=item /str_ava_visualizer                     GET

Pagina di creazione e gestione dei pannelli e delle finestre, presenti all'interno dell'applicativo "Visualizer".

=item /str_ava_validazione                    GET

Pagina di creazione dei sottogruppi di stazioni presenti all'interno dell'applicativo "Validazione" e delle regole impostabili per la validazione di dati anomali per parametro o per stazione.

=item /stat_indicatori                        GET

Pagina delle statistiche giornaliere relative agli inquinanti.

=item /rep_qa_sopralluoghi                    GET

Pagina di visualizzazione, creazione e modifica dei report sopralluoghi presenti sul portale.

=item /rep_qa_tarature                        GET

Pagina di visualizzazione, creazione e modifica dei report tarature presenti sul portale.

=item /rep_qa_manutenzioni                    GET

Pagina di visualizzazione, creazione e modifica dei report manutenzioni presenti sul portale.

=item /rep_verbali                            GET

Pagina di visualizzazione, creazione e modifica dei report verbali presenti sul portale.

=item /rep_alims                              GET

Pagina di visualizzazione, creazione e modifica dei report dei verbali ALIMS presenti sul portale e di inviarne di nuovi.

=item /rep_automatici                         GET

Pagina di visualizzazione, creazione e modifica dei report di analisi di dati inviati automaticamente.

=item /plan_attivita                          GET

Pagina di pianificazione, attraverso l'uso di diversi tipi di ticket, delle attività necessarie.

=item /cnf_parametri                          GET

Pagina di visualizzazione di tutti i parametri (attivi e non attivi) della propria rete di appartenenza.

=item /cnf_stazioni                           GET

Pagina di visualizzazione delle informazioni di anagrafica delle stazioni e dei parametri associati ad esse.

=item /cnf_strumenti                          GET

Pagina di visualizzazione, aggiunta e posizionamento degli strumenti presenti nelle stazioni appartenenti alla propria rete.

=item /cnf_bombole                            GET

Pagina di visualizzazione, aggiunta e posizionamento delle bombole presenti nelle stazioni appartenenti alla propria rete.

=item /cnf_campagne                           GET

Pagina di visualizzazione, aggiunta e posizionamento delle campagne appartenenti alla propria rete.

=item /cnf_dotazioni                          GET

Pagina di visualizzazione, aggiunta e posizionamento delle dotazioni presenti nelle stazioni appartenenti alla propria rete.

=item /ang_strumenti                          GET

Pagina di visualizzazione dell'anagrafica della strumentazione presente nella propria rete.

=item /div_telegram                           GET

Strumento di gestione dell'invio, e delle eventuali eliminazioni, dei messaggi sui canali presenti sull'app 'Telegram'.

=item /div_email_gest                         GET

Pagina di visualizzazione e gestione delle mailing list della propria rete, aggiungendo e modificando gruppi a seconda delle necessità.



=item /faq                                    GET

Pagina delle Frequently Asked Questions.

=item /faq_tech                               GET

Pagina delle Frequently Asked Questions di matrice tecnica.

=item /map                                    GET

Mappa portale.

=item /help/<page:txt>                        GET

Pagina di help del portale.

=back

=over

=item POST

Le successive route vengono utilizzate dai form per l'invio di dati al backend

=item /get_login                                       POST

=item /get_password                                    POST

=item /rep_alims_ws                                    POST

=item /str_dataview_get_stations_list                  POST

=item /str_dataview_get_map_last_data                  POST

=item /str_dataview_get_map_indicators                 POST

=item /str_dataview_get_map_stations                   POST

=item /str_dataview_get_near_stations                  POST

=item /str_dataview_get_allparams_data                 POST

=item /str_dataview_get_allparams_data_tbl             POST

=item /str_dataview_get_windrose_data                  POST

=item /str_dataview_get_stations                       POST

=item /str_dataview_get_params                         POST

=item /str_dataview_get_station_params                 POST

=item /str_dataview_get_official_data                  POST

=item /str_dataview_get_data                           POST

=item /str_dataview_get_downloads                      POST

=item /str_dataview_get_notifications                  POST

=item /str_dataview_put_notification_ack               POST

=item /get_notifications                               POST

=item /put_notification_ack                            POST

=item /home_get_stations                               POST

=item /home_get_open_doors                             POST

=item /home_get_last_reports                           POST

=item /home_get_delays                                 POST

=item /home_get_instr_delays                           POST

=item /home_get_station_params_delays                  POST

=item /home_get_last_alarms                            POST

=item /home_get_last_warnings                          POST

=item /home_get_user_links                             POST

=item /home_get_links                                  POST

=item /home_put_link                                   POST

=item /home_put_user_links                             POST

=item /put_password                                    POST

=item /usr_admin_get_groups                            POST

=item /usr_admin_get_users                             POST

=item /usr_admin_get_user_byid                         POST

=item /usr_admin_get_comp_detail                       POST

=item /usr_admin_get_groups_detail                     POST

=item /usr_admin_get_group_pages_grants                POST

=item /usr_admin_get_group_stations_grants             POST

=item /usr_admin_get_group_others_grants               POST

=item /usr_admin_get_user_password                     POST

=item /usr_admin_put_group                             POST

=item /usr_admin_put_user                              POST

=item /usr_admin_put_group_pages_grants                POST

=item /usr_admin_put_group_stations_grants             POST

=item /usr_admin_put_group_others_grants               POST

=item /usr_admin_put_group_channels_grants             POST

=item /usr_admin_put_widget_destination                POST

=item /usr_admin_del_group                             POST

=item /usr_admin_get_portal_options                    POST

=item /usr_admin_put_validation_options                POST

=item /usr_sysadmin_get_options                        POST

=item /usr_sysadmin_put_options                        POST

=item /usr_profile_get_user_byid                       POST

=item /usr_profile_put_user                            POST

=item /usr_profile_put_password                        POST

=item /usr_options_get_widget_list                     POST

=item /usr_options_get_options                         POST

=item /usr_options_put_widgets                         POST

=item /usr_options_put_shortcuts                       POST

=item /calendario_get_events                           POST

=item /str_ana_get_analyser_options                    POST

=item /str_ana_get_categories                          POST

=item /str_ana_get_category_byid                       POST

=item /str_ana_get_macro_metadata                      POST

=item /str_ana_get_param_info                          POST

=item /str_ana_get_wind_scale                          POST

=item /str_ana_get_highcharts_data_bydate              POST

=item /str_ana_get_highcharts_data_per_year            POST

=item /str_ana_get_windrose_data                       POST

=item /str_ana_get_tabulator_data                      POST

=item /str_ana_get_csv_data                            POST

=item /str_ana_put_analyser_user_options               POST

=item /str_ana_put_category                            POST

=item /str_ana_put_macro                               POST

=item /str_ana_put_macro_duplication                   POST

=item /str_ana_del_category                            POST

=item /str_ana_del_macro                               POST

=item /str_vis_get_visualizer_user_options             POST

=item /str_vis_get_pages_by_cat                        POST

=item /str_vis_get_macros_by_page                      POST

=item /str_vis_get_highcharts_data_bydate              POST

=item /str_vis_put_visualizer_user_options             POST

=item /str_map_get_stations                            POST

=item /str_map_get_map_stations                        POST

=item /str_map_get_data_station                        POST

=item /str_map_get_inst_data_station                   POST

=item /str_map_get_windrose_data                       POST

=item /str_map_get_info_station                        POST

=item /str_openair_get_stations                        POST

=item /str_openair_get_runs                            POST

=item /str_openair_get_images                          POST

=item /str_openair_put_images_creation                 POST

=item /dat_val_get_codes                               POST

=item /dat_val_get_stations                            POST

=item /dat_val_get_parameters                          POST

=item /dat_val_get_validation_codes                    POST

=item /dat_val_get_validation_user_options             POST

=item /dat_val_get_stations_by_param                   POST

=item /dat_val_get_all_params_data_table               POST

=item /dat_val_get_all_stations_data_table             POST

=item /dat_val_get_validation_codes_bycell             POST

=item /dat_val_get_point_neighborhood                  POST

=item /dat_val_put_validation_user_options             POST

=item /dat_val_put_action_by_calendar                  POST

=item /dat_val_put_cells                               POST

=item /dat_val_put_check_cells                         POST

=item /dat_val_put_reset_cells                         POST

=item /dat_validaz_finale_get_stations_by_network      POST

=item /dat_validaz_finale_get_stations                 POST

=item /dat_validaz_finale_get_validation_per_year      POST

=item /dat_validaz_finale_get_validation_table         POST

=item /dat_validaz_finale_get_station_param_data       POST

=item /dat_validaz_finale_get_activities_log           POST

=item /dat_validaz_finale_put_final_validation         POST

=item /dat_inst_get_stations                           POST

=item /dat_inst_get_data                               POST

=item /dat_diagnostici_get_stations                    POST

=item /dat_diagnostici_get_diags_data                  POST

=item /dat_tarature_aut_get_stations                   POST

=item /dat_tarature_aut_get_data                       POST

=item /dat_tarature_aut_get_events                     POST

=item /dat_tarature_aut_get_events_list                POST

=item /dat_tarature_aut_get_chart                      POST

=item /dat_allarmi_get_stations                        POST

=item /dat_allarmi_get_alarms_bydate                   POST

=item /dat_warning_get_stations                        POST

=item /dat_warning_get_instruments_messages            POST

=item /str_ava_ana_get_stations_bynets                 POST

=item /str_ava_ana_get_subgroup_by_id                  POST

=item /str_ava_ana_put_subgroup                        POST

=item /str_ava_ana_del_subgroup                        POST

=item /str_ava_vis_get_stations                        POST

=item /str_ava_vis_get_categories                      POST

=item /str_ava_vis_get_category_byid                   POST

=item /str_ava_vis_get_params_bystid_types             POST

=item /str_ava_vis_get_parameters                      POST

=item /str_ava_vis_get_form_options                    POST

=item /str_ava_vis_get_params_info                     POST

=item /str_ava_vis_get_macros_by_page                  POST

=item /str_ava_vis_get_automatic_macros                POST

=item /str_ava_vis_put_category                        POST

=item /str_ava_vis_put_page                            POST

=item /str_ava_vis_put_page_duplication                POST

=item /str_ava_vis_del_category                        POST

=item /str_ava_vis_del_page                            POST

=item /str_ava_val_get_stations_bynets                 POST

=item /str_ava_val_get_subgroup_by_id                  POST

=item /str_ava_val_put_subgroup                        POST

=item /str_ava_val_del_subgroup                        POST

=item /str_ava_val_get_abnormals_data                  POST

=item /str_ava_val_get_abnormals_data_by_id            POST

=item /str_ava_val_put_abnormals_limit                 POST

=item /str_ava_val_del_abnormals_limit                 POST

=item /str_ava_val_get_stations                        POST

=item /str_ava_val_get_parameters                      POST

=item /str_ava_val_get_stat_abnormals_data             POST

=item /str_ava_val_get_stat_abnormals_data_by_id       POST

=item /str_ava_val_put_stat_abnormals_limit            POST

=item /str_ava_val_del_stat_abnormals_limit            POST

=item /stat_indicatori_get_stations                    POST

=item /stat_indicatori_get_pdf_files                   POST

=item /stat_indicatori_get_table_by_date               POST

=item /stat_indicatori_get_table_by_station            POST

=item /stat_indicatori_put_stats_calculation           POST

=item /stat_indicatori_put_pdf_by_date_net             POST

=item /stat_reportistica_get_stations_by_zone          POST

=item /stat_reportistica_get_params_by_zone            POST

=item /stat_reportistica_get_reports                   POST

=item /stat_reportistica_get_check_data                POST

=item /stat_reportistica_get_stats_by_station          POST

=item /stat_reportistica_get_stats_by_type             POST

=item /stat_reportistica_put_stats_calculation         POST

=item /stat_reportistica_put_pdf                       POST

=item /stat_reportistica_del_report                    POST

=item /stat_ana_validazione_get_stations               POST

=item /stat_ana_validazione_get_validation_analysis    POST

=item /stat_ana_validazione_get_csv_data               POST

=item /stat_ana_validazione_get_network_csv_data       POST

=item /stat_ana_validazione_get_downloads              POST

=item /stat_ana_copertura_get_stations                 POST

=item /stat_ana_copertura_get_data_coverage            POST

=item /rep_qa_sopralluoghi_get_municipalities          POST

=item /rep_qa_sopralluoghi_get_reports                 POST

=item /rep_qa_sopralluoghi_get_selected_report         POST

=item /rep_qa_sopralluoghi_put_report                  POST

=item /rep_qa_sopralluoghi_del_report                  POST

=item /rep_qa_sopralluoghi_selected_attachment         POST

=item /rep_qa_tarature_get_stations                    POST

=item /rep_qa_tarature_get_instruments                 POST

=item /rep_qa_tarature_get_metadata                    POST

=item /rep_qa_tarature_get_reports                     POST

=item /rep_qa_tarature_get_selected_report             POST

=item /rep_qa_tarature_put_report                      POST

=item /rep_qa_tarature_del_report                      POST

=item /rep_qa_tarature_selected_attachment             POST

=item /rep_qa_manutenzioni_get_stations                POST

=item /rep_qa_manutenzioni_get_instruments             POST

=item /rep_qa_manutenzioni_get_miscellanies            POST

=item /rep_qa_manutenzioni_get_operations              POST

=item /rep_qa_manutenzioni_get_calibrations            POST

=item /rep_qa_manutenzioni_get_reports                 POST

=item /rep_qa_manutenzioni_get_selected_report         POST

=item /rep_qa_manutenzioni_put_report                  POST

=item /rep_qa_manutenzioni_del_report                  POST

=item /rep_verbali_get_reports                         POST

=item /rep_verbali_get_selected_report                 POST

=item /rep_verbali_put_report                          POST

=item /rep_verbali_del_selected_report                 POST

=item /rep_alims_get_stations                          POST

=item /rep_alims_get_instruments                       POST

=item /rep_alims_get_reports                           POST

=item /rep_alims_get_selected_report                   POST

=item /rep_alims_get_volume                            POST

=item /rep_alims_put_report                            POST

=item /rep_alims_put_send                              POST

=item /rep_alims_del_report                            POST

=item /rep_automatici_get_ws_status                    POST

=item /plan_attivita_get_stations                      POST

=item /plan_attivita_get_equipments                    POST

=item /plan_attivita_get_maintenances                  POST

=item /plan_attivita_get_tickets                       POST

=item /plan_attivita_get_selected_ticket               POST

=item /plan_attivita_put_ticket                        POST

=item /plan_attivita_put_ticket_status                 POST

=item /plan_attivita_del_selected_ticket               POST

=item /cnf_stazioni_get_provinces                      POST

=item /cnf_stazioni_get_municipalities                 POST

=item /cnf_stazioni_get_municipality_by_coords         POST

=item /cnf_stazioni_get_stations                       POST

=item /cnf_stazioni_get_station_by_id                  POST

=item /cnf_stazioni_put_station                        POST

=item /cnf_stazioni_put_pdf                            POST

=item /cnf_stazioni_del_station                        POST

=item /cnf_parametri_get_parameters_by_stid            POST

=item /cnf_parametri_get_parameter_by_stprid           POST

=item /cnf_parametri_put_station_param                 POST

=item /cnf_parametri_put_config_file                   POST

=item /cnf_parametri_put_config_params                 POST

=item /cnf_parametri_del_station_param                 POST

=item /cnf_strumenti_get_stations                      POST

=item /cnf_strumenti_get_stations_bynets               POST

=item /cnf_strumenti_get_instruments                   POST

=item /cnf_strumenti_get_instruments_for_location      POST

=item /cnf_strumenti_get_instrument_by_id              POST

=item /cnf_strumenti_get_params_by_instr_type          POST

=item /cnf_strumenti_get_location_by_id                POST

=item /cnf_strumenti_put_instrument                    POST

=item /cnf_strumenti_put_location                      POST

=item /cnf_strumenti_put_location_closure              POST

=item /cnf_strumenti_del_instrument                    POST

=item /cnf_strumenti_del_attachment                    POST

=item /cnf_bombole_get_stations                        POST

=item /cnf_bombole_get_stations_bynets                 POST

=item /cnf_bombole_get_cylinders                       POST

=item /cnf_bombole_get_cylinders_for_location          POST

=item /cnf_bombole_get_cylinder_by_id                  POST

=item /cnf_bombole_get_location_by_id                  POST

=item /cnf_bombole_put_cylinder                        POST

=item /cnf_bombole_put_location                        POST

=item /cnf_bombole_put_location_closure                POST

=item /cnf_bombole_del_cylinder                        POST

=item /cnf_bombole_del_attachment                      POST

=item /cnf_campagne_get_provinces                      POST

=item /cnf_campagne_get_municipalities                 POST

=item /cnf_campagne_get_municipality_by_coords         POST

=item /cnf_campagne_get_roaming_stations_bynets        POST

=item /cnf_campagne_get_campaigns                      POST

=item /cnf_campagne_get_sites                          POST

=item /cnf_campagne_get_site_by_id                     POST

=item /cnf_campagne_get_location_by_id                 POST

=item /cnf_campagne_put_campaign                       POST

=item /cnf_campagne_put_campaign_status                POST

=item /cnf_campagne_put_site                           POST

=item /cnf_campagne_put_location                       POST

=item /cnf_campagne_put_location_closure               POST

=item /cnf_campagne_del_campaign                       POST

=item /cnf_campagne_del_attachment                     POST

=item /cnf_campagne_del_site                           POST

=item /cnf_dotazioni_get_stations                      POST

=item /cnf_dotazioni_get_stations_bynets               POST

=item /cnf_dotazioni_get_miscellanies                  POST

=item /cnf_dotazioni_get_miscellanies_for_location     POST

=item /cnf_dotazioni_get_miscellany_by_id              POST

=item /cnf_dotazioni_get_location_by_id                POST

=item /cnf_dotazioni_put_miscellany                    POST

=item /cnf_dotazioni_put_location                      POST

=item /cnf_dotazioni_put_location_closure              POST

=item /cnf_dotazioni_del_miscellany                    POST

=item /cnf_dotazioni_del_attachment                    POST

=item /ang_parametri_get_parameters                    POST

=item /ang_parametri_get_parameters_by_types           POST

=item /ang_parametri_get_parameter_by_id               POST

=item /ang_parametri_put_parameter                     POST

=item /ang_parametri_del_selected_coefficient          POST

=item /ang_stazioni_get_parameters                     POST

=item /ang_stazioni_get_instruments                    POST

=item /ang_stazioni_get_stations                       POST

=item /ang_stazioni_get_station_equipments             POST

=item /ang_strumenti_get_operations                    POST

=item /div_tel_get_messages                            POST

=item /div_tel_get_selected_message                    POST

=item /div_tel_put_message                             POST

=item /div_tel_del_selected_message                    POST

=item /div_gest_get_mailing_lists                      POST

=item /div_gest_get_selected_mailing_list              POST

=item /div_gest_get_external_mails                     POST

=item /div_gest_put_mailing_list                       POST

=item /div_gest_put_external_mail                      POST

=item /div_gest_del_mailing_list                       POST

=item /div_gest_del_external_mail                      POST

=item /info_dataset_e_get_stations                     POST

=item /info_dataset_e_get_stations_params              POST

=item /info_dataset_e_get_stations_params_e2a_recap    POST

=item /info_dataset_e_get_stations_params_e1a_recap    POST

=item /info_dataset_e_get_e1a_files                    POST

=item /info_dataset_e_put_status                       POST

=item /info_dataset_e_put_e1a_creation                 POST

=item /faq_get_argument                                POST

=item /faq_get_key                                     POST

=item /faq_put_page                                    POST

=item /faq_put_argument                                POST

=item /faq_del_argument                                POST

=back

=cut