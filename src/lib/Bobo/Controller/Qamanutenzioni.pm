package Bobo::Controller::Qamanutenzioni;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::File 'path';
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];
use Sys::Hostname;

sub qa_manutenzioni {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    my $operations = $self->dbqamanutenzioni->get_miscellanies_operations();
    $self->stash(operations => $operations);

    # Render template "report/qa_manutenzioni.html.ep" with message
    $self->render('report/qa_manutenzioni');
}

sub get_instruments {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni sub get_instruments");

    my $stid = $self->param('stid'); # post
    $self->app->log->debug("ID stazione: $stid");

    my $dt = $self->param('dt'); # post
    $self->app->log->debug("data e ora: $dt");

    # get instruments from station
    my $instruments = $self->dbqamanutenzioni->get_instruments_by_station($stid, $dt);

    my $json = {
        res => "OK",
        instruments => $instruments
    };

    # render
    $self->render(json => $json);
}

sub get_miscellanies {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni sub get_miscellanies");

    my $stid = $self->param('stid'); # post
    $self->app->log->debug("ID stazione: $stid");

    my $dt = $self->param('dt'); # post
    $self->app->log->debug("data e ora: $dt");

    # get instruments from station
    my $miscellanies = $self->dbcommon->get_miscellanies_by_station_date($stid, $dt);

    my $json = {
        res => "OK",
        miscellanies => $miscellanies
    };

    # render
    $self->render(json => $json);
}

sub get_operations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni sub get_operations");

    my $instrid = $self->param('instr'); # post
    $self->app->log->debug("ID strumento: $instrid");

    my $catid = $self->param('cat'); # post
    $self->app->log->debug("ID categoria: $catid");

    # get operations from instrument
    my $operations = $self->dbqamanutenzioni->get_operations_by_instrument($instrid, $catid);

    my $json = {
        res => "OK",
        operations => $operations
    };

    # render
    $self->render(json => $json);
}

sub get_calibrations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni sub get_calibrations");

    my $stid = $self->param('stid'); # post
    $self->app->log->debug("ID stazione: $stid");

    my $instr = $self->param('instr'); # post
    $self->app->log->debug("ID strumento: $instr");

    my $dt = $self->param('dt'); # post
    $self->app->log->debug("data e ora: $dt");

    # get calibrations from station instruments
    my $calibrations = $self->dbqamanutenzioni->get_calibrations_by_station_instr($stid, $instr, $dt);

    my $json = {
        res => "OK",
        calibrations => $calibrations
    };

    # render
    $self->render(json => $json);
}

sub get_reports {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni sub get_reports");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $net = $self->param('net'); # post
    my $prid = $self->param('prid'); # post
    my $stid = $self->param('stid'); # post

    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("ID province: $prid");
    $self->app->log->debug("ID station: $stid");

    my $user_id = $self->session('it.ecometer.bobo');
    my $reports;

    if ($stid == -1) {
        # get report
        $reports = $self->dbqamanutenzioni->get_reports_by_date_net_province($user_id, $from, $to, $net, $prid);
    }
    else {
        $reports = $self->dbqamanutenzioni->get_reports_by_date_station($user_id, $from, $to, $stid);
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

sub get_selected_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni sub get_selected_report");

    my $rpid = $self->param('id'); # post

    $self->app->log->debug("ID report: $rpid");

    # get report
    my $report = $self->dbqamanutenzioni->get_report_by_id($rpid);
    my $operations = $self->dbqamanutenzioni->get_operations_by_report($rpid);
    my $mi_operations = $self->dbqamanutenzioni->get_miscellanies_operations_by_report($rpid);

    my $json;
    if (defined $report) {
        $json = {
            res => "OK",
            report => $report,
            operations => $operations,
            mi_operations => $mi_operations
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
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni sub get_pdf");

    my $params = $self->req->query_params->to_hash;
    $self->helperDumper($params);

    # get dates
    my $rpid = $params->{'rpid'}; # post

    $self->app->log->debug("PDF del report: $rpid");

    if ($^O eq 'linux') {
        # choose by host
        my $host = hostname;
        if ($host eq 'opas-http') {
            # system
            eval {
                # create remote report
                $self->app->log->debug("[SSH] Lancio script creazione pdf via ssh");
                my $cmd = 'ls';
                $self->app->log->debug($cmd);
                system($cmd) or $self->app->log->warn("Ssh failed: $!");
                $self->app->log->debug("Fine script creazione pdf");

                # get remote report
                $self->app->log->debug("[SCP] Copia file remoto in locale");
                my $rpid_file = sprintf("%06d", $rpid);
                my $filename = "report-manutenzione-".$rpid_file.".pdf";
                my $remotefile = 'PATH/'.$filename;
                my $dest_path = 'PATH';
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

    if ($? == -1) { # errore if ($? == -1) {
        $self->app->log->debug("command failed: $!");

        $json = {
            res => 'ERROR',
            desc => 'Errore durante la creazione del pdf',
            id => 0
        };

        # final render
        $self->render(json => $json);
    }
    else { # comando andato a buon fine
        $self->app->log->debug('Pdf creato correttamente');
        $self->app->log->debug("Inizio recupero dati");

        # get application download path .../public/ path
        my $download_path = $self->app->static->paths->[0].'/downloads/report/qa_manutenzioni';
        $self->app->log->debug("Download path: $download_path");

        my $rpid_file = sprintf("%06d", $rpid);

        # get PDF filename
        $self->app->log->debug("File PDF");
        my $pdf_filename = "report-manutenzione-".$rpid_file.".pdf";

        # get full zip filename
        my $full_pdf_filename = $download_path.'/'.$pdf_filename;

        # log
        $self->app->log->debug("PDF filename: $full_pdf_filename");

        # last check
        if (-e $full_pdf_filename) {
            # encode filename to support "à"
            $pdf_filename = encode_utf8($pdf_filename);

            # downloadPdfFile | render_file
            $self->render_file(
                'filepath' => $full_pdf_filename,
                'filename' => $pdf_filename,
                'format' => 'pdf', # will change Content-Type "application/x-download" to "application/pdf"
                'content_disposition' => 'attachment', # will change Content-Disposition from "attachment" to "inline"
                'cleanup' => 0 # delete file after completed

                # inline               - is for showing file inline
                # attachment (default) - is for downloading
            );
        }
        else {
            $self->app->log->error("Error. PDF file DOES NOT exists!");

            $json = {
                res => 'ERROR',
                desc => "Errore durante lo scarico del bollettino."
            };

            # final render
            $self->render(json => $json);
        }
    }
}

sub get_total_pdf {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni sub get_total_pdf");

    my $params  = $self->req->query_params->to_hash;
    $self->helperDumper($params);

    my $user_id = $self->session('it.ecometer.bobo');

    # get dates
    my $from = $params->{'from'}; # post
    my $to = $params->{'to'}; # post
    my $net = $params->{'net'}; # post
    my $stid = $params->{'stid'}; # post

    if ($^O eq 'linux') {

        # choose by host
        my $host = hostname;
        if ($host eq 'opas-http') {

            # system
            eval{
                # create remote report
                $self->app->log->debug("[SSH] Lancio script creazione pdf via ssh");
                my $tof = $to;
                $tof =~ tr/ /T/;
                my $cmd = 'ls';
                $self->app->log->debug($cmd);
                system($cmd) or $self->app->log->warn("Ssh failed: $!");
                $self->app->log->debug("Fine script creazione pdf");

                # get remote report
                $self->app->log->debug("[SCP] Copia file remoto in locale");

                $from =~ m/^(\d\d\d\d)-(\d\d)-(\d\d)$/;
                my $from_format = "$1$2$3";
                $to =~ m/^(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d):(\d\d)$/;
                my $to_format = "$1$2$3";
                my $filename = "report-manutenzione-{".$user_id.$net."}-".$from_format."-".$to_format.".pdf";
                my $remotefile = 'PATH/'.$filename;
                my $dest_path = 'PATH';
                $cmd = "ls";
                $self->app->log->debug($cmd);
                system($cmd) or $self->app->log->warn("Scp failed: $!");
                $self->app->log->debug("Fine copia");
            };

        }
        else {

            $self->app->log->debug("Lancio script creazione pdf");
            # $self->app->log->debug('perl /var/www/bobo_latex/manutenzione-cumulativo/report-manutenzione-date.pl \''.$from.'\' \''.$to.'\' '.$net.' '.$stid.' '.$user_id);
            system('ls');
            $self->app->log->debug("Fine script creazione pdf");

        }
    }

    my $json;

    $self->app->log->debug("check system result");
    $self->app->log->debug($?);

    if ($? == -1) { # errore if ($? == -1) {
        $self->app->log->debug("command failed: $!");

        $json = {
            res => 'ERROR',
            desc => 'Errore durante la creazione del pdf',
            id => 0
        };

        # final render
        $self->render(json => $json);
    }
    else { # comando andato a buon fine
        $self->app->log->debug('Pdf creato correttamente');
        $self->app->log->debug("Inizio recupero dati");

        # get application download path .../public/ path
        my $download_path = $self->app->static->paths->[0].'/downloads/report/qa_manutenzioni';
        $self->app->log->debug("Download path: $download_path");

        $from =~ m/^(\d\d\d\d)-(\d\d)-(\d\d)$/;
        my $from_format = "$1$2$3";

        $to =~ m/^(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d):(\d\d)$/;
        my $to_format = "$1$2$3";

        # get PDF filename
        $self->app->log->debug("File PDF");
        # report-manutenzione-YYYYMMDD-YYYYMMDD.pdf;
        my $pdf_filename = "report-manutenzione-{".$user_id.$net."}-".$from_format."-".$to_format.".pdf";

        # get full zip filename
        my $full_pdf_filename = $download_path.'/'.$pdf_filename;
        # log
        $self->app->log->debug("PDF filename: $full_pdf_filename");

        # last check
        if (-e $full_pdf_filename) {
            # encode filename to support "à"
            $pdf_filename = encode_utf8($pdf_filename);

            # downloadPdfFile | render_file
            $self->render_file(
                'filepath' => $full_pdf_filename,
                'filename' => $pdf_filename,
                'format' => 'pdf', # will change Content-Type "application/x-download" to "application/pdf"
                'content_disposition' => 'attachment', # will change Content-Disposition from "attachment" to "inline"
                'cleanup' => 0 # delete file after completed

                # inline               - is for showing file inline
                # attachment (default) - is for downloading
            );
        }
        else {
            $self->app->log->error("Error. PDF file DOES NOT exists!");

            $json = {
                res => 'ERROR',
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
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni sub put_report");

    # dump post data (with user infos)
    $self->helperDumperPostData('Manutenzioni', 'put_report', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper($params);

    my $user_id = $self->session('it.ecometer.bobo');

    # store request to audit table
    my $table = 'rep_qamaintenances';

    # get params from ajax
    my $res = 1;
    my $rpid = $params->{'maintenance-id'};

    # if rpid defined -> edit report
    if (defined $rpid && $rpid ne "") {
        $self->app->log->debug("Bobo::Controller::Qamanutenzioni edit of report");
        $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbqamanutenzioni->update_report($params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Qamanutenzioni insert of new report");
        $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $rpid = $self->dbqamanutenzioni->insert_report($user_id, $params);
    }

    if (defined $rpid && defined $res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qamanutenzioni sub del_report");
    $self->helperDumperPostData('Manutenzioni', 'del_report', $self->req->body_params);

    my $params = $self->req->body_params->to_hash; # for audit
    my $report_id = $self->param('id'); # post

    $self->app->log->debug("Report id: $report_id");

    # store action to audit table
    my $table = 'rep_qamaintenances';
    $self->helperInsertUserLog('DELETE', $table, encode_json($params));

    my $res = $self->dbqamanutenzioni->delete_report_by_id($report_id);

    $self->render(json => $res);
}

1;

=head1 qa_manutenzioni

Render della pagina di visualizzazione dei report manutenzione.

Argomenti:  /

Return:     /

=cut

=head1 get_instruments

Funzione per recuperare gli strumenti associati ad una determinata stazione.

Argomenti:  * id della stazione ('stid');

           * data e ora della manutenzione ('dt');

Return:     json contenente la risposta "OK" e gli strumenti.

=cut

=head1 get_miscellanies

Funzione per recuperare le dotazioni associate ad una determinata stazione.

Argomenti:  * id della stazione ('stid');

           * data e ora della manutenzione ('dt');

Return:     json contenente la risposta "OK" e le dotazioni.

=cut

=head1 get_operations

Funzione per recuperare le operazioni associate ad un determinato strumento.

Argomenti:  * id dello strumento ('instr');

           * id della categoria di strumento ('cat');

Return:     json contenente la risposta "OK" e le operazioni.
=cut

=head1 get_calibrations

Funzione per recuperare le tarature associate ad un determinato strumento di una determinata stazione.

Argomenti:  * id della stazione ('stid');

           * id dello strumento ('instr');

           * data e ora della manutenzione ('dt');

Return:     json contenente la risposta "OK" e le tarature.

=cut

=head1 get_reports

Funzione per recuperare tutti i report manutenzione disponibili in un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prid');

           * id della stazione, se presente ('stid');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e i report, oppure solamente la risposta "ERR".

=cut

=head1 get_selected_report

Funzione per recuperare, dato l'id, le informazioni di una determinata manutenzione.

Argomenti:  * id del report ('id');

Return:     json contenente, se presenti, la risposta "OK", il report e le operazioni,
oppure solamente la risposta "ERR".

=cut

=head1 get_pdf

Funzione che effettua, dato l'id, il download del pdf di una determinata manutenzione.

Argomenti:  * id del report ('rpid');

Return:     download del pdf, oppure json contenente la risposta "ERR" e un messaggio di errore.

=cut

=head1 get_total_pdf

Funzione che effettua il download del pdf totale di tutte le manutenzioni di una determinata rete
in un determinato periodo temporale ed, eventualmente, di una determinata stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete ('net');

           * id della stazione, se presente ('stid');

Return:     download del pdf, oppure json contenente la risposta "ERR" e un messaggio di errore.

=cut


=head1 put_report

Funzione per inserire/modificare un determinato report.

Argomenti:  * oggetto contenente le informazioni della manutenzione da inserire/modificare ('params');

           * id dell'utente ('user_id');

           * id del report; se presente: UPDATE ('maintenance-id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_report

Funzione per eliminare, dato l'id, una determinata manutenzione.

Argomenti:  * id del report ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut