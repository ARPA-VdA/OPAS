package Bobo::Controller::Alims;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::File 'path';
use Time::Moment;

use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;
use Sys::Hostname;
use Encode qw(encode_utf8);

use Scalar::Util qw(looks_like_number);

sub alims {
    my $self = shift;
    $self->app->log->debug("Bobo::Controller::Alims");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces( $user_id );
    $self->stash(provinces => $provinces);

    # get arguments
    my $arguments = $self->dbalims->get_arguments();
    $self->stash(arguments => $arguments);

    # get analytics
    my $analytics = $self->dbalims->get_analytics();
    $self->stash(analytics => $analytics);

    # Render template "report/alims.html.ep" with message
    $self->render('report/alims');
}

sub get_stations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Alims sub get_stations");

    my $user_id = $self->session('it.ecometer.bobo');

    my $prid = $self->param('prid'); # post
    $self->app->log->debug("ID provincia: $prid");

    # get stations from province
    my $stations = $self->dbalims->get_stations_by_province($user_id, $prid);

    my $json = {
        res => "OK",
        stations => $stations
    };

    # render
    $self->render(json => $json);
}

sub get_reports {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Alims sub get_reports");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $prid = $self->param('prid'); # post
    my $stid = $self->param('stid'); # post
    my $pack = $self->param('pack'); # post

    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("ID province: $prid");
    $self->app->log->debug("ID station: $stid");

    my $user_id = $self->session('it.ecometer.bobo');
    my $reports;

    if ($stid == -1) {
        # get report
        $reports = $self->dbalims->get_reports_by_date_province($user_id, $from, $to, $prid, $pack);
    }
    else {
        $reports = $self->dbalims->get_reports_by_date_station($from, $to, $stid, $pack);
    }

    my $json;
    if (defined $reports) {
        $json = {
            res => "OK",
            reports => $reports
        };
    }
    else {
        $json = {
            res => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

sub get_csv_reports {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Alims sub get_csv_reports");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $prid = $self->param('prid'); # post
    my $stid = $self->param('stid'); # post
    my $pack = $self->param('pack'); # post

    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("ID province: $prid");
    $self->app->log->debug("ID station: $stid");

    my $user_id = $self->session('it.ecometer.bobo');

    # get application path .../public/ path
    my $app_path = $self->app->home->rel_file('public/downloads/report/alims');
    $self->app->log->debug("Application path: $app_path");

    # get times
    $self->app->log->debug("Formattazione date");
    my $tm = Time::Moment->now;
    my $head_time = $tm->strftime("{%Y%m%d_%H%M%S}");

    my $dateFromISO = $from;
    $dateFromISO .= 'T00:00:00Z';
    $self->app->log->debug("From: $dateFromISO");
    $tm = Time::Moment->from_string($dateFromISO);
    $head_time .= '-' . $tm->strftime("[%Y%m%d");

    my $dateToISO = $to;
    $dateToISO =~ s/ /T/;
    $dateToISO .= 'Z';
    $tm = Time::Moment->from_string($dateToISO);
    $head_time .= '-' . $tm->strftime("%Y%m%d]");

    # build filename
    # my $csv_filename = '/Dati_'.$stid.'-'.$prid.'.csv';
    my $csv_filename = '/Lista_reports_'.$head_time.'.csv';
    $csv_filename = encode_utf8( $csv_filename );
    my $full_csv_filename = $app_path.'/'.$csv_filename;
    $self->app->log->debug("File csv : $full_csv_filename");

    # write header
    my $eco_file_header;
    $eco_file_header .= "Data;";
    $eco_file_header .= "Operatore;";
    $eco_file_header .= "Codice;";
    $eco_file_header .= "Provincia;";
    $eco_file_header .= "Stazione;";
    $eco_file_header .= "Strumento;";
    $eco_file_header .= "S.N.;";
    $eco_file_header .= "ArpaID;";
    $eco_file_header .= "Pacchetti analitici;";
    $eco_file_header .= "Filtri validi;";
    $eco_file_header .= "Filtri annullati;";
    $eco_file_header .= "Multiplo;";
    $eco_file_header .= "Inviato;";
    $eco_file_header .= "Ricevuto;";
    # $eco_file_header .= ";";
    # $eco_file_header .= ";";

    my $data_rows;

    if ($stid == -1) {
        # get report
        $data_rows = $self->dbalims->get_reports_by_date_province($user_id, $from, $to, $prid, $pack);
    }
    else {
        $data_rows = $self->dbalims->get_reports_by_date_station($from, $to, $stid, $pack);
    }

    my $csv_rows = '';
    foreach my $row (@{$data_rows}) {
            my $csv_row = '';
            $csv_row .= $row->{'report_fulldate_formatted'} .';';
            $csv_row .= $row->{'user_fullname'} .';';
            $csv_row .= $row->{'report_number'} .';';
            $csv_row .= $row->{'province_name'} .';';
            $csv_row .= $row->{'station_name'} .';';
            $csv_row .= $row->{'instr_type_fullname'} .';';
            $csv_row .= $row->{'instr_serial_num'} .';';
            $csv_row .= $row->{'instr_arpa_id'} .';';
            $csv_row .= $row->{'analytics_desc'} .';';
            $csv_row .= $row->{'report_num_valid'} .';';
            $csv_row .= $row->{'report_num_cancelled'} .';';
            $csv_row .= ( $row->{'report_multi_filters'} == 1 ? 'Si' : 'No' ).';';
            $csv_row .= ( $row->{'report_sent'} == 1 ? 'Si' : 'No' ) .';';
            $csv_row .= ( $row->{'report_received'} == 1 ? 'Si' : 'No' );
            $csv_rows .= $csv_row ."\n";

    } # foreach my $row (@{$data_rows})

    # open single data file
    $self->app->log->debug("Open CSV data file");
    open(FH, '>', $full_csv_filename) or die $!;
    # print header & pubs
    print FH $eco_file_header ."\n";

    # print rows with values
    $self->app->log->debug("Print rows with values...");
    print FH $csv_rows ."\n";

    # close data file
    $self->app->log->debug("Close CSV data file");
    close(FH);

    # last check
    $self->app->log->debug("Check zip file exists");
    if (-e $full_csv_filename) {
        # Open file in browser(do not show save dialog)
        $self->app->log->debug("Render file back to browser");

        $self->render_file(
            'filepath' => $full_csv_filename,
            'format' => 'csv', # will change Content-Type "application/x-download" to "application/pdf"
            'content_disposition' => 'attachment', # will change Content-Disposition from "attachment" to "inline"
            'cleanup' => 0, # delete file after completed
        );

    }
    else {
        $self->app->log->error("Error. Zip file DOES NOT exists!");

        my $json = {
            res => 'ERROR',
            desc => "Errore durante lo scarico dei dati."
        };

        # final render
        $self->render(json => $json);
    }
};

sub get_selected_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Alims sub get_selected_report");

    my $rpid = $self->param('id'); # post

    $self->app->log->debug("ID report: $rpid");

    # get report
    my $report = $self->dbalims->get_report_by_id($rpid);
    my $filters = $self->dbalims->get_filters_by_report($rpid);

    my $json;
    if (defined $report) {
        $json = {
            res => "OK",
            report => $report,
            filters => $filters
        };
    }
    else {
        $json = {
            res => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

sub get_volume {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Alims sub get_volume");

    # -------------------------------------------------------
    # get post data
    # -------------------------------------------------------
    my $params = $self->req->body_params->to_hash; # post
    $self->helperDumper($params);
    my $stid = $params->{'stid'};
    my $inid = $params->{'inid'};
    my $dt = $params->{'dt'};

    $self->app->log->debug("Stazione: $stid");
    $self->app->log->debug("Strumento: $inid");
    $self->app->log->debug("Date: $dt");

    my $volume = $self->dbalims->get_volume($stid, $inid, $dt);

    # final render
    my $json;
    if (defined $volume) {
        $json = {
            res => "OK",
            volume => $volume
        };
    }
    else {
        $json = {
            res => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

sub get_pdf {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Alims sub get_pdf");

    my $params  = $self->req->query_params->to_hash;
    $self->helperDumper( $params );

    # get dates
    my $rpid = $params->{'rpid'}; # post

    $self->app->log->debug("PDF del report: $rpid");
    my $report = $self->dbalims->get_report_by_id($rpid);

    if ( $^O eq 'linux' ) {
        # choose by host
        my $host = hostname;
        $self->app->log->debug("Host: $host");
        if ( $host eq 'opas-http' ) {
            # system
            eval{
                # create remote report
                $self->app->log->debug("[SSH] Lancio script creazione pdf via ssh");
                my $cmd = 'ls';
                $self->app->log->debug($cmd);
                system($cmd) or $self->app->log->warn("Ssh failed: $!");
                $self->app->log->debug("Fine script creazione pdf");

                # get remote report
                $self->app->log->debug("[SCP] Copia file remoto in locale");
                my $filename = 'verbale_alims-'.$report->{'rep_number'}.'.pdf';
                my $remotefile = 'PATH/'.$filename;
                my $dest_path = 'PATH/';
                system("ls") or $self->app->log->warn("Scp failed: $!");
                $self->app->log->debug("Fine copia");
            };
        }
        else {
            $self->app->log->debug("Lancio script creazione pdf");
            system('ls');
            $self->app->log->debug("Fine script creazione pdf");
        }
    }

    my $json;

    $self->app->log->debug("check system result");
    $self->app->log->debug($?);
    if ( $? == -1 ) { # errore if ( $? == -1 ) {
        $self->app->log->debug("command failed: $!");
        # update report PDF flag
        $self->dbalims->update_pdf_flag( $rpid, 0 );

        $json = {
            res  => 'ERROR',
            desc => 'Errore durante la creazione del pdf',
            id   => 0
        };

        # final render
        $self->render(json => $json);

    }
    else { # comando andato a buon fine
        $self->app->log->debug('Pdf creato correttamente');
        $self->app->log->debug("Inizio recupero dati");

        # get application download path .../public/ path
        my $download_path = $self->app->static->paths->[0].'/downloads/report/alims';
        $self->app->log->debug("Download path: $download_path");

        # get PDF filename
        $self->app->log->debug("File PDF");
        my $pdf_filename = 'verbale_alims-'.$report->{'rep_number'}.'.pdf';

        # get full zip filename
        my $full_pdf_filename = $download_path.'/'.$pdf_filename;
        # log
        $self->app->log->debug("PDF filename: $full_pdf_filename");

        # last check
        if (-e $full_pdf_filename) {
            # update report PDF flag
            $self->dbalims->update_pdf_flag( $rpid, 1 );

            # downloadPdfFile | render_file
            $self->render_file(
                'filepath' => $full_pdf_filename,
                'filename' => $pdf_filename,
                'format'   => 'pdf',                   # will change Content-Type "application/x-download" to "application/pdf"
                'content_disposition' => 'attachment', # will change Content-Disposition from "attachment" to "inline"
                'cleanup' => 0                         # delete file after completed

                # inline               - is for showing file inline
                # attachment (default) - is for downloading
            );

        }
        else {
            $self->app->log->error("Error. PDF file DOES NOT exists!");

            # update report PDF flag
            $self->dbalims->update_pdf_flag( $rpid, 0 );

            $json = {
                res  => 'ERROR',
                desc => "Errore durante lo scarico del bollettino."
            };

            # final render
            $self->render(json => $json);
        }
    }
}

sub put_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Alims sub put_report");

    # dump post data (with user infos)
    $self->helperDumperPostData('Alims', 'put_report', $self->req->body_params);

    my $params  = $self->req->body_params->to_hash;
    $self->helperDumper( $params );

    my $user_id = $self->session('it.ecometer.bobo');

    # store request to audit table
    # my $table = 'rep_qamaintenances';

    # get params from ajax
    my $res = 1;
    my $rpid = $params->{'id-alims'};

    # if rpid defined -> edit report
    if (defined $rpid && $rpid ne "") {
        $self->app->log->debug("Bobo::Controller::Alims edit of report");
        # $self->helperInsertUserLog( 'UPDATE', $table, encode_json($params));

        $res = $self->dbalims->update_report($params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Alims insert of new report");
        # $self->helperInsertUserLog( 'INSERT', $table, encode_json($params));

        $rpid = $self->dbalims->insert_report($user_id, $params);
    }

    if (defined $rpid && $res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1)
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0)
    }
}

sub put_send {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Alims sub put_send");

    # -------------------------------------------------------
    # get post data
    # -------------------------------------------------------
    my $rpid = $self->param('id'); # post

    # log
    $self->app->log->debug("Sending report id: $rpid");

    my $script = 'ls';
    $self->app->log->debug("Running system: $script");

    # result
    my $exit_code = system( $script );
    # my $exit_code = 0;

    my $msg;
    my $res = 1;
    $self->app->log->debug("Analysing result: $exit_code");
    if ($exit_code != 0) {
        $self->app->log->error("Command $script failed");
        $res = undef;

        $self->app->log->debug("Updating status report 0");
        $self->dbalims->update_sent_flag($rpid, 0);
    }
    else {
        $self->app->log->error("Command successful");

        $self->app->log->debug("Updating status report 1");
        $self->dbalims->update_sent_flag($rpid, 1);
    }

    # render back
    if (defined $res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1)
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0)
    }
}

sub del_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Alims sub del_report");
    $self->helperDumperPostData('Alims', 'del_report', $self->req->body_params);

    my $params  = $self->req->body_params->to_hash; # for audit
    my $rpid = $self->param('id'); # post

    $self->app->log->debug("Report id: $rpid");

    # store action to audit table
    # my $table = 'rep_qamaintenances';
    # $self->helperInsertUserLog( 'DELETE', $table, encode_json($params));

    my $res = $self->dbalims->delete_report_by_id($rpid);

    # render
    $self->render(json => $res);
}

# WEBSERVICE
# alims action
sub alims_ws {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Alims sub alims_ws");

    # -------------------------------------------------------
    # get post data
    # -------------------------------------------------------
    $self->app->log->debug('<'."~" x 100);
    my $obj = decode_json($self->req->body);
    $self->app->log->debug("Store post data");
    my $file = $self->helperDumperPostDataAlims('alims_ws', $obj);

    $self->app->log->debug("[WSALIMS] Dump post data: " . $self->helperDumper($obj) );
    $self->app->log->debug("[WSALIMS] Num verbale: ".$obj->{'NumeroVerbale'});
    $self->app->log->debug("[WSALIMS] FilterId: ".$obj->{'FilterId'});

    # format file name
    $file = path($file)->to_rel($self->app->home->rel_file('/public/uploads/'))->to_string;
    $self->app->log->debug("[WSALIMS] File: ".$file);

    # error flag, ok if 1, default to it
    my $err = 1;

    my @email_recipients = (
        'email.da_aggiungere@email.it'
    );
    my $email_title   = 'ArpaL';
    my $email_subject = '[NO REPLY] Nuova segnalazione ALIMS';
    my $email_logo = $self->config->{logo_mail};

    # -------------------------------------------------------
    # get report by number
    # -------------------------------------------------------
    my $report = $self->dbalims->get_report_by_number( $obj->{'NumeroVerbale'});
    if (!defined $report) {
        $self->app->log->debug("[WSALIMS] Verbale non trovato!");

        my $email_body ='<p>Gentile Utente,<br>';
        $email_body .= 'Sono stati ricevuti i risultati di un verbale non presente nel database</p>';
        $email_body .= '<p>Numero verbale: <strong>'.$obj->{'NumeroVerbale'}.'</strong><br>';
        $email_body .= 'Filtro: <strong>'.$obj->{'FilterId'}.'</strong><br>';
        $email_body .= 'Nome file: <strong>'.$file.'</strong></p>';
        $email_body .= '<p>Cordiali saluti</p>';

        $self->helperSendEmailHTML( $email_title, $email_subject , $email_body, $email_logo, @email_recipients );
        $err = 0;
    }
    else {
        # -------------------------------------------------------
        # store analysis result
        # -------------------------------------------------------
        $self->app->log->debug("[WSALIMS] Insert received data");
        my $res = $self->dbalims->update_received_obj( $report->{'rep_id'}, $obj );

        # -------------------------------------------------------
        # get filter
        # -------------------------------------------------------
        # multiple filter
        if (defined $report->{'rep_multi_filters'} && $report->{'rep_multi_filters'} == 1) {
            my $filter_tot;

            # recupero nome primo filtro
            # my @filters_name = split "_", $obj->{'FilterId'};
            # $filter_name = $filters_name[0];
            $self->app->log->debug("[WSALIMS] Filtro multiplo!");


            # recupero info totali del filtro multiplo
            $filter_tot = $self->dbalims->get_multiple_filter_by_report_id( $report->{'rep_id'} );
            my $stid = $filter_tot->{'station_id'};

            if(defined $stid){
                $self->app->log->debug("[WSALIMS] Stazione: ".$filter_tot->{'station_name'}. " Stid: ".$filter_tot->{'station_id'});

                # -------------------------------------------------------
                # store new data
                # -------------------------------------------------------
                $res = $self->dbalims->update_received_filter_obj($filter_tot->{'filter_id'}, $obj->{'Results'});

                # insert values -> ogni filtro può avere più di un risultato associato ad un parametro diverso
                foreach my $result (@{$obj->{'Results'}}) {
                $self->app->log->debug("[WSALIMS] Parametro: " .$result->{'ResultId'}. " ". $result->{'ResultName'});
                # recupero informazioni relative al parametro associato alla stazione
                my $stpr = $self->dbalims->get_stpr_by_alims_code($stid, $result->{'ResultId'});

                if (defined $stpr) {
                    $self->app->log->debug("[WSALIMS] Param name: ".$stpr->{'param_name'}." PRID: ". $stpr->{'param_id'} ." ID: ".$stpr->{'stpr_table_id'});
                    $self->app->log->debug("[WSALIMS] Valore: ".($result->{'ResultValue'} || ''));

                    # Ho scoperto che, quando il file json arriva con dei campi vuoti è perché il laboratorio
                    # mette nel campo del risultato una stringa di testo tipo "Basso recupero" o "Non determinabile.
                    # Presenza di interferenza introdotta in fase di preparazione del campione" che quindi OPAS pone = 0.
                    # E' possibile in questi casi fare in modo che il dato risulti automaticamente non valido con il codice -128?
                    # sanity check
                    my $value = $result->{'ResultValue'};
                    if (!looks_like_number($value)) {
                        $self->app->log->debug("[WSALIMS] Valore NON numerico!");

                        my $email_body ='<p>Gentile Utente,<br>';
                        $email_body .= 'Sono stati ricevuti dei risultati non numerici per il seguente verbale:</p>';
                        $email_body .= '<p>Numero verbale: <strong>'.$obj->{'NumeroVerbale'}.'</strong><br>';
                        $email_body .= 'Filtro: <strong>'.$obj->{'FilterId'}.'</strong><br>';
                        $email_body .= 'Stazione: <strong>'.$filter_tot->{'station_name'}.'</strong><br>';
                        $email_body .= 'Parametro: <strong>'.$result->{'ResultId'}.' '.$result->{'ResultName'}.'</strong><br>';
                        $email_body .= 'Valore: <strong>'.($result->{'ResultValue'} || '').'</strong><br>';
                        $email_body .= 'Nome file: <strong>'.$file.'</strong></p>';
                        $email_body .= '<p>Non verranno inseriti dati nel database.</p>';
                        $email_body .= '<p>Cordiali saluti</p>';

                        $self->helperSendEmailHTML($email_title, $email_subject , $email_body, $email_logo, @email_recipients);

                        # next Results
                        next;
                    }

                    # recupero tutti i filtri associati al report
                    my $filters = $self->dbalims->get_filters_by_report($report->{'rep_id'});
                    foreach my $filter (@{$filters}) {
                        # si presume che
                        # - ciascun filtro che compone il filtro multiplo abbia durata 1 giorno -> ndays = 1
                        # - non ci siano filtri bianchi
                        # - è possibile che ci siano filtri relativi a giorni non contigui
                        my $ndays   = $filter->{'filter_ndays'};
                        my $iswhite = $filter->{'filter_white'};
                        my $start   = $filter->{'filter_start_fulldate'};

                        # volume totale del filtro multiplo
                        my $volume = $filter_tot->{'filter_volume'};

                        $err = $self->dbalims->insert_filter_value($iswhite, $volume, $start, $ndays, $stpr, $result->{'ResultValue'}, $result->{'ResultLDQ'});
                    }

                    # $err is zero in case of error, and exit routine
                    last if ($err == 0)
                }
                else {
                    $self->app->log->debug("[WSALIMS] Parametro non associato alla stazione!");

                    my $email_body ='<p>Gentile Utente,<br>';
                    $email_body .= 'Sono stati ricevuti i risultati per un parametro non associato alla stazione del verbale.</p>';
                    $email_body .= '<p>Numero verbale: <strong>'.$obj->{'NumeroVerbale'}.'</strong><br>';
                    $email_body .= 'Filtro: <strong>'.$obj->{'FilterId'}.'</strong><br>';
                    $email_body .= 'Stazione: <strong>'.$filter_tot->{'station_name'}.'</strong><br>';
                    $email_body .= 'Parametro: <strong>'.$result->{'ResultId'}.' '.$result->{'ResultName'}.'</strong><br>';
                    $email_body .= 'Nome file: <strong>'.$file.'</strong></p>';
                    $email_body .= '<p>Cordiali saluti</p>';

                    $self->helperSendEmailHTML( $email_title, $email_subject , $email_body, $email_logo, @email_recipients );
                }
                }
            } # end defined stid
            else{
                $self->app->log->debug("[WSALIMS] Filtro o Stazione non trovati!");

                my $email_body ='<p>Gentile Utente,<br>';
                $email_body .= 'Sono stati ricevuti i risultati di un verbale per cui non è stato possibile trovare il filtro o la stazione di riferimento.</p>';
                $email_body .= '<p>Numero verbale: <strong>'.$obj->{'NumeroVerbale'}.'</strong><br>';
                $email_body .= 'Filtro: <strong>'.$obj->{'FilterId'}.'</strong><br>';
                $email_body .= 'Nome file: <strong>'.$file.'</strong></p>';
                $email_body .= '<p>Cordiali saluti</p>';

                $self->helperSendEmailHTML($email_title, $email_subject , $email_body, $email_logo, @email_recipients);
                $err = 0;
            }
        }
        else {
            $self->app->log->debug("[WSALIMS] Filtro singolo!");

            my $filter;
            my $filter_name = $obj->{'FilterId'};
            # recupero info del filtro
            $filter = $self->dbalims->get_filter_by_report_id( $report->{'rep_id'}, $filter_name );
            my $stid = $filter->{'station_id'};

            if(defined $stid){
                $self->app->log->debug("[WSALIMS] Stazione: ".$filter->{'station_name'}. " Stid: ".$filter->{'station_id'});

                # -------------------------------------------------------
                # store new data
                # -------------------------------------------------------
                $res = $self->dbalims->update_received_filter_obj($filter->{'filter_id'}, $obj->{'Results'});

                # insert values -> ogni filtro può avere più di un risultato associato ad un parametro diverso
                foreach my $result (@{$obj->{'Results'}}) {
                    $self->app->log->debug("[WSALIMS] Parametro: " .$result->{'ResultId'}. " ". $result->{'ResultName'});
                    # recupero informazioni relative al parametro associato alla stazione
                    my $stpr = $self->dbalims->get_stpr_by_alims_code($stid, $result->{'ResultId'});

                    if (defined $stpr) {
                        $self->app->log->debug("[WSALIMS] Param name: ".$stpr->{'param_name'}." PRID: ". $stpr->{'param_id'} ." ID: ".$stpr->{'stpr_table_id'});
                        $self->app->log->debug("[WSALIMS] Valore: ".($result->{'ResultValue'} || ''));

                        # Ho scoperto che, quando il file json arriva con dei campi vuoti è perché il laboratorio
                        # mette nel campo del risultato una stringa di testo tipo "Basso recupero" o "Non determinabile.
                        # Presenza di interferenza introdotta in fase di preparazione del campione" che quindi OPAS pone = 0.
                        # E' possibile in questi casi fare in modo che il dato risulti automaticamente non valido con il codice -128?
                        # sanity check
                        my $value = $result->{'ResultValue'};
                        if (!looks_like_number($value)) {
                            $self->app->log->debug("[WSALIMS] Valore NON numerico!");

                            my $email_body ='<p>Gentile Utente,<br>';
                            $email_body .= 'Sono stati ricevuti dei risultati non numerici per il seguente verbale:</p>';
                            $email_body .= '<p>Numero verbale: <strong>'.$obj->{'NumeroVerbale'}.'</strong><br>';
                            $email_body .= 'Filtro: <strong>'.$obj->{'FilterId'}.'</strong><br>';
                            $email_body .= 'Stazione: <strong>'.$filter->{'station_name'}.'</strong><br>';
                            $email_body .= 'Parametro: <strong>'.$result->{'ResultId'}.' '.$result->{'ResultName'}.'</strong><br>';
                            $email_body .= 'Valore: <strong>'.($result->{'ResultValue'} || '').'</strong><br>';
                            $email_body .= 'Nome file: <strong>'.$file.'</strong></p>';
                            $email_body .= '<p>Non verranno inseriti dati nel database.</p>';
                            $email_body .= '<p>Cordiali saluti</p>';

                            $self->helperSendEmailHTML($email_title, $email_subject , $email_body, $email_logo, @email_recipients);

                            # next Results
                            next;
                        }

                        # si presume che
                        # - ciascun filtro potrebbe avere durata superiore a 1 giorno -> ndays >= 1
                        # - ci siano filtri bianchi
                        my $ndays   = $filter->{'filter_ndays'};
                        my $iswhite = $filter->{'filter_white'};
                        my $volume  = $filter->{'filter_volume'};
                        my $start   = $filter->{'filter_start_fulldate'};

                        $err = $self->dbalims->insert_filter_value($iswhite, $volume, $start, $ndays, $stpr, $result->{'ResultValue'});

                        # $err is zero in case of error, and exit routine
                        last if ($err == 0)
                    }
                    else {
                        $self->app->log->debug("[WSALIMS] Parametro non associato alla stazione!");

                        my $email_body ='<p>Gentile Utente,<br>';
                        $email_body .= 'Sono stati ricevuti i risultati per un parametro non associato alla stazione del verbale.</p>';
                        $email_body .= '<p>Numero verbale: <strong>'.$obj->{'NumeroVerbale'}.'</strong><br>';
                        $email_body .= 'Filtro: <strong>'.$obj->{'FilterId'}.'</strong><br>';
                        $email_body .= 'Stazione: <strong>'.$filter->{'station_name'}.'</strong><br>';
                        $email_body .= 'Parametro: <strong>'.$result->{'ResultId'}.' '.$result->{'ResultName'}.'</strong><br>';
                        $email_body .= 'Nome file: <strong>'.$file.'</strong></p>';
                        $email_body .= '<p>Cordiali saluti</p>';

                        $self->helperSendEmailHTML($email_title, $email_subject , $email_body, $email_logo, @email_recipients);
                    }
                }
            }
            else{
                $self->app->log->debug("[WSALIMS] Filtro o Stazione non trovati!");

                my $email_body ='<p>Gentile Utente,<br>';
                $email_body .= 'Sono stati ricevuti i risultati di un verbale per cui non è stato possibile trovare il filtro o la stazione di riferimento.</p>';
                $email_body .= '<p>Numero verbale: <strong>'.$obj->{'NumeroVerbale'}.'</strong><br>';
                $email_body .= 'Filtro: <strong>'.$obj->{'FilterId'}.'</strong><br>';
                $email_body .= 'Nome file: <strong>'.$file.'</strong></p>';
                $email_body .= '<p>Cordiali saluti</p>';

                $self->helperSendEmailHTML($email_title, $email_subject , $email_body, $email_logo, @email_recipients);
                $err = 0;
            }
        }
    }

    #--------------------------------------------------------
    # render back to ws alims
    #--------------------------------------------------------
    my $json;
    if ( $err == 1 ) {
        $json = {
            result => "1",
            message => "alims web service - dati ricevuti"
        };
    }
    else {
        $json = {
            result => "0",
            message => "alims web service - errore dati"
        };
    }

    # render json
    $self->render(json => $json);
}

1;

=head1 alims

Render della pagina relativa ai report Alims.

Argomenti:  /

Return:     /

=cut

=head1 get_stations

Funzione per recuperare tutte le stazioni disponibili sul portale.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia, se presente ('prid');

Return:     json contenente la risposta "OK" e le stazioni.

=cut

=head1 get_reports

Funzione per recuperare tutti i report Alims disponibili in un determinato periodo temporale.

Argomenti:  * id dell'utente ('userid');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della provincia, se presente ('prid');

           * id della stazione, se presente ('stid');

           * id della tipologia di pacchetti analitici, se presente ('pack');

Return:     json contenente la risposta "OK" e i report, oppure la risposta "ERR".

=cut

=head1 get_selected_report

Funzione per recuperare, dato l'id, le informazioni di un determinato report Alims.

Argomenti:  * id del report ('id');

Return:     json contenente, se presenti, la risposta "OK" e i vari campi del report selezionato,
oppure solamente la risposta "ERR".

=cut

=head1 get_volume

Funzione per recuperare il valore di volume dei filtri inseriti per un determinato strumento
in una determinata stazione ed in una determinata data.

Argomenti:  * id della stazione ('stid');

           * is dello strumento ('inid');

           * data/ora ('dt');

Return:     json contenente la risposta "OK" e i report, oppure la risposta "ERR".

=cut

=head1 get_pdf

Funzione che effettua, dato l'id, il download del pdf di un determinato report.

Argomenti:  * id del report ('rpid');

Return:     download del pdf, oppure json contenente la risposta "ERR" e un messaggio di errore.

=cut

=head1 put_report

Funzione per inserire/modificare un determinato report.

Argomenti:  * oggetto contenente le informazioni del verbale da inserire/modificare ('params');

           * id dell'utente ('user_id');

           * id del report; se presente: UPDATE ('id-alims');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_send

Funzione per inserire nel database l'informazione di invio di un determinato report.

Argomenti:  * id del report ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_report

Funzione per eliminare, dato l'id, un determinato verbale Alims.

Argomenti:  * oggetto contenente le informazioni del verbale da eliminare ('params');

           * id del report ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut