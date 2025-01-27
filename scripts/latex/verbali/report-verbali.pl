#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : report-verbali.pl
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#
#   REPORT VERBALI
#       Perl script to generate report PDF
#
#   RUN EXAMPLE:
#       (meet_id)   $ perl /path/to/script/report-verbali.pl 16
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# USE LIBS
#------------------------------------------------------------------------------
# enables the strict and warnings pragmas
# use Modern::Perl '2018';
use File::Spec::Functions qw(rel2abs);
use File::Basename;
use Getopt::Std;
use Fcntl qw(:flock);
use Log::Log4perl::Level;
use LaTeX::Encode 'latex_encode';
use feature qw(switch);
use experimental qw( switch );
use JSON;
use LWP::Simple;
use HTML::Restrict; # remove all html
use POSIX qw(strftime);

#------------------------------------------------------------------------------
# NON-BLOCKING FLOCK
#------------------------------------------------------------------------------
open our $file, '<', $0 or die $!;
flock $file, LOCK_EX|LOCK_NB or die "Unable to lock file $!";

#------------------------------------------------------------------------------
# ARGUMENTS
#------------------------------------------------------------------------------
my $num_args = $#ARGV + 1;

#------------------------------------------------------------------------------
# SCRIPT SETTINGS
#------------------------------------------------------------------------------
my $title    = 'Reports';
my $location = 'Opas';
my $logfile  = 'report-verbali.log';
my $version  = '1.0';
my $script   = basename($0);
# absolute path
my $abs_path = dirname(rel2abs($0));

#------------------------------------------------------------------------------
# LOG HANDLER
#------------------------------------------------------------------------------
our $log;

#------------------------------------------------------------------------------
# DATE TIME VARIABLES
#------------------------------------------------------------------------------
our ($year,$month,$day,$hour,$min,$sec);

#------------------------------------------------------------------------------
# LOAD LIBRARIES
#------------------------------------------------------------------------------
require "$abs_path/inc/library-v2.pl";
require "$abs_path/inc/library-dbh-v3.pl";
require "$abs_path/settings.pl";

#------------------------------------------------------------------------------
# START UP
#------------------------------------------------------------------------------
$log = set_logfile("$abs_path/log", $logfile);
$log->level($DEBUG); # one of TRACE, DEBUG, INFO, WARN, ERROR, FATAL
# $log->trace("...");  # Log a trace message
# $log->debug("...");  # Log a debug message
# $log->info("...");   # Log a info message
# $log->warn("...");   # Log a warn message
# $log->error("...");  # Log a error message
# $log->fatal("...");  # Log a fatal message
startup($title, $location, $version);

#------------------------------------------------------------------------------
# CHECKING ARGUMENTS
#------------------------------------------------------------------------------
my $reportid;
if ($num_args == 1) {
    $reportid = $ARGV[0];
} else {
    $log->warn("No ReportID provided");
    end();
    exit(0);
}

#------------------------------------------------------------------------------
# TEX DIRECTORY
#------------------------------------------------------------------------------
my $working_path = $abs_path.'/tex_tmp';
createpath($working_path);

#------------------------------------------------------------------------------
# RANDOM STRING
#------------------------------------------------------------------------------
my $random_str = sprintf("%05X", rand(0xFFFFFFFF));

#------------------------------------------------------------------------------
# MAIN PATHS
#------------------------------------------------------------------------------
# my $pdf_export_path in settings.pl
my $tex_file_wrapper = $working_path.'/report_verbali_'.$random_str.'.tex';
my $tex_file_body = $working_path.'/verbali_'.$random_str.'.tex';
my $tex_file_headfoot = $working_path.'/header_footer_verbali_'.$random_str.'.tex';

#------------------------------------------------------------------------------
# CONNECT TO DATABASE
#------------------------------------------------------------------------------
dbh_connect($db_settings) or bail_out("Cannot connect to database !");

#------------------------------------------------------------------------------
# QUERY
#------------------------------------------------------------------------------
my $sql = qq{
    SELECT
        vm.meet_id,
        vm.meet_date,
        vm.meet_date_format,
        vm.meet_start_time,
        vm.meet_end_time,
        TO_CHAR(vm.meet_start_time, 'HH24:MI') AS formatted_start,
        TO_CHAR(vm.meet_end_time, 'HH24:MI') AS formatted_end,
        EXTRACT(HOUR FROM vm.meet_end_time::time - vm.meet_start_time::time) AS ore,
	    EXTRACT(MINUTE FROM vm.meet_end_time::time - vm.meet_start_time::time) AS minuti,
        vm.province_id,
        vm.province_name,
        vm.province_code,
        vm.meet_locality,
        vm.meet_participants,
        ARRAY(
            SELECT
                u.us_name||' '
                ||COALESCE(u.us_2nd_name, '')
                ||u.us_surname              AS user_fullname
            FROM
                bobo.users u
            WHERE u.us_id = ANY (vm.meet_participants)
        ) AS participants,
        vm.meet_title,
        vm.meet_desc,
        vm.us_id,
        vm.user_fullname,
        vm.user_avatar,
        vm.user_avatar_thumb,
        um.portal_id,
        p.portal_logo,
        vm.meet_insert_time,
        vm.meet_pdf_time,
        vm.meet_pdf_created
    FROM reports.view_meetings vm
    LEFT JOIN bobo.users_metadata um USING (us_id)
    LEFT JOIN bobo.portals p ON um.portal_id = p.portal_id
    WHERE
        meet_id = $reportid;
};

#------------------------------------------------------------------------------
# GET RECORD
#------------------------------------------------------------------------------
# campi della query sql
my $meeting = dbh_get_row_hashref( $sql );
$log->info(Dumper($meeting));

# controllo se il report è presente oppure no
if (!$meeting) {
    $log->warn("No report with id $reportid!");
    end();
    exit(1);
}

#------------------------------------------------------------------------------
# RULES OF HTML HANDLER
#------------------------------------------------------------------------------
my %rules = (
    b       => [],
    i       => [],
    li      => [],
    ol      => [],
    p       => [],
    u       => [],
    ul      => [],
    h1      => [],
    h2      => [],
    h3      => [],
    h4      => [],
    h5      => [],
    br      => [],
);
my $hr = HTML::Restrict->new( rules => \%rules );
# $log->info(escape_html($hr->process($metting->{meet_desc})));

#------------------------------------------------------------------------------
# HEADER/FOOTER
#------------------------------------------------------------------------------
$log->debug('header-footer verbali ...');

# variabile contenuto
my $headfoot;

# togliere il commento se si vuole prendere l'immagine del logo dalla directory "/inc" (caricare l'immagine in quella cartella)
# my $logo_name = basename($meeting->{portal_logo});

# costruzione del file .tex
$headfoot .= '%%----------------- DEFINIZIONE HEADER E FOOTER -----------------'."\n";
$headfoot .= '\pagestyle{fancy}'."\n";
$headfoot .= '\setlength{\headheight}{50pt} % distanza dell\'header dalla cima del foglio'."\n";
$headfoot .= '\setlength{\footskip}{80pt} % distanza del footer dall\'ultima linea della pagina'."\n";
$headfoot .= '\fancyhf{} % cancella tutti i campi di intestazione e pie pagina'."\n";
$headfoot .= "\n";
$headfoot .= '%% MODIFICA COLORE DELLE LINEE DELL\'HEADER E DEL FOOTER'."\n";
$headfoot .= '\let\oldheadrule\headrule % Copy \headrule into \oldheadrule'."\n";
$headfoot .= '\renewcommand{\headrule}{\color{greyHEADFOOT}\oldheadrule} % Add colour to \headrule'."\n";
$headfoot .= '\let\oldfootrule\footrule % Copy \footrule into \oldfootrule'."\n";
$headfoot .= '\renewcommand{\footrule}{\color{greyHEADFOOT}\oldfootrule} % Add colour to \footrule'."\n";
$headfoot .= "\n";
$headfoot .= '%%----------------- HEADER -----------------'."\n";
$headfoot .= '\fancyhead[L]{'."\n";
$headfoot .= '    \raisebox{2ex}{\includegraphics[height=1cm, keepaspectratio]{'.$main_logo.'}}'."\n";
$headfoot .= '    \quad % aggiunge una tabulazione per distanziare le immagini'."\n";
$headfoot .= '    \quad'."\n";
# $headfoot .= '    \raisebox{2ex}{\includegraphics[height=1cm, keepaspectratio]{'.$logo_path.''.$logo_name.'}}'."\n"; # per immagine da "/inc"
$headfoot .= '    \raisebox{2ex}{\includegraphics[height=1cm, keepaspectratio]{'.$logo_path.''.$meeting->{portal_logo}.'}}'."\n";
$headfoot .= '}'."\n";
$headfoot .= "\n";
$headfoot .= '\fancyhead[R]{'."\n";
$headfoot .= '    \raisebox{1.5ex}{\textcolor{blueCF}{\bfseries{\Large Report Verbali}}} \\\\'."\n";
$headfoot .= '}'."\n";
$headfoot .= '%%----------------- FOOTER -----------------'."\n";
$headfoot .= '\fancyfoot[L]{'."\n";
$headfoot .= '    \textcolor{greyHEADFOOT}{\bfseries{'.$foot_desc.' - Report Verbali}} \\\\'."\n";
$headfoot .= '    \textcolor{greyHEADFOOT}{\mdseries{Report generato il \today}}'."\n";
$headfoot .= '}'."\n";
$headfoot .= "\n";
$headfoot .= '\fancyfoot[R]{'."\n";
$headfoot .= '    \mdseries{Pagina \thepage $ $ di \pageref{LastPage}}'."\n";
$headfoot .= '}'."\n";
$headfoot .= "\n";
$headfoot .= '\renewcommand{\footrulewidth}{0.2mm}'."\n";

#------------------------------------------------------------------------------
# CORPO CENTRALE
#------------------------------------------------------------------------------
$log->debug('corpo centrale verbali ...');

# variabile contenuto
my $body;

# costruzione del file .tex
# titolo
$body .= '\begin{center}'."\n";
$body .= '    \textcolor{azureCF}{\Large{Verbale n. \textbf{'.$meeting->{meet_id}.'} del \textbf{'.$meeting->{meet_date_format}.'} dalle \textbf{'.$meeting->{formatted_start}.'} alle \textbf{'.$meeting->{formatted_end}.'}}} % TITOLO'."\n";
$body .= '\end{center}'."\n";
$body .= "\n";
$body .= '\vspace{0.25cm}'."\n";
$body .= "\n";

# dati riunione
$body .= '\begin{center}'."\n";
$body .= '    \renewcommand{\arraystretch}{2.0}'."\n";
$body .= '    \begin{tabularx}{0.90\textwidth}{'."\n";
$body .= '         r'."\n";
$body .= '         l'."\n";
$body .= '         c'."\n";
$body .= '         r'."\n";
$body .= '         l'."\n";
$body .= '    }'."\n";
$body .= '        \bfseries{Verbalizzante:} & \mdseries{'.latex_encode($meeting->{user_fullname}).'} &  & \bfseries{Data:} & \mdseries{'.latex_encode($meeting->{meet_date_format}).'} \\\\'."\n";
$body .= '        \bfseries{Ora inizio:} & \mdseries{'.latex_encode($meeting->{formatted_start}).'} &  & \bfseries{Ora fine:} & \mdseries{'.latex_encode($meeting->{formatted_end}).'} \\\\'."\n";
$body .= '        \bfseries{Provincia:} & \mdseries{'.latex_encode($meeting->{province_name}).'} &  & \bfseries{Localita\':} & \mdseries{'.latex_encode($meeting->{meet_locality}).'} \\\\'."\n";
$body .= '        \bfseries{Durata riunione:} & \mdseries{'.latex_encode($meeting->{ore}).' ore e '.latex_encode($meeting->{minuti}).' minuti} & & & \\\\'."\n";

# # loop dei partecipanti
# my $first = 1;
# $body .= '\\\\'."\n";
# foreach my $partecipant ( @{$meeting->{participants}} )
# {
#     if ($first){
#         $body .= '\bfseries{Partecipanti:} & \multicolumn{4}{l}{\mdseries{'.latex_encode($partecipant).'}} \\\\'."\n";
#         $first = 0;
#     } else {
#         $body .= ' & \multicolumn{4}{l}{\mdseries{'.latex_encode($partecipant).'}} \\\\'."\n";
#     }
# }

$body .= '        \bfseries{Partecipanti:} & \mdseries{';
# $inspection->{operators_name} --> array dei partecipanti
my $partecipanti = $inspection->{operators_name};
my $last = 1; # flag
foreach my $partecipante ( @{$partecipanti} ){
    if (scalar @{$partecipanti} == $last) {
        $log->info("ultimo");
        $body .= ''.controlnull(latex_encode($partecipante)).'';
    } else {
        $log->info("non ancora");
        $body .= ''.controlnull(latex_encode($partecipante)).', ';

        $last = $last + 1;
    }
}

$body .= "\n";
$body .= '\end{tabularx}'."\n";
$body .= '\end{center}'."\n";
$body .= "\n";
$body .= '\vspace{0.25cm}'."\n";
$body .= "\n";
# dettagli verbale
# $body .= '\textcolor{blueCF}{\bfseries{\large Dettagli verbale}}'."\n";
# $body .= "\n";
$body .= '\section*{\textcolor{blueCF}{\bfseries{\large Dettagli verbale}}}'."\n";
$body .= '\begin{center}'."\n";
$body .= '\renewcommand{\arraystretch}{2.0}'."\n";
$body .= '\begin{tabularx}{0.90\textwidth}{'."\n";
$body .= '   r'."\n";
$body .= '   p{0.70\textwidth}'."\n";
# $body .= '   X'."\n";
# $body .= '   X'."\n";
$body .= '}'."\n";
# $body .= '    \bfseries{Oggetto:} & \multicolumn{3}{l}{\mdseries{'.latex_encode($meeting->{meet_title}).'}} \\\\'."\n";
$body .= '    \bfseries{Oggetto:} & \mdseries{'.latex_encode($meeting->{meet_title}).'} \\\\'."\n";
# $body .= '    \bfseries{Testo verbale:} & \multicolumn{3}{X}{\mdseries{'.escape_html($hr->process($meeting->{meet_desc})).'}} \\\\'."\n";
$body .= '    \bfseries{Testo verbale:} & \mdseries{'.escape_html($hr->process($meeting->{meet_desc})).'} \\\\'."\n";
$body .= '\end{tabularx}'."\n";
$body .= '\end{center}'."\n";
$body .= "\n";
$body .= '\vspace{0.5cm}'."\n";
$body .= "\n";

#------------------------------------------------------------------------------
# WRITE TO FILE
#------------------------------------------------------------------------------
# FILE HEADER-FOOTER
$log->info("Writing to file $tex_file_headfoot ...");
$log->info("");
open(FILE ,">:encoding(UTF-8)", $tex_file_headfoot) or die $!;
print FILE $headfoot;
close FILE;

# FILE BODY
$log->info("Writing to file $tex_file_body ...");
$log->info("");
open(FILE ,">:encoding(UTF-8)", $tex_file_body) or die $!;
print FILE $body;
close FILE;

#------------------------------------------------------------------------------
# PDF FILENAME
#------------------------------------------------------------------------------
my $job_name = 'verbale'.'-'.sprintf("%04d",$reportid);
my $pdf_filename  = $job_name.'-'.sprintf("%04d",$reportid).'.pdf';
my $pdf_fullname  = $pdf_export_path.'/'.$pdf_filename;

#------------------------------------------------------------------------------
# CHANGE WORKING PATH
#------------------------------------------------------------------------------
$log->debug("Changing working path ...");
chdir($abs_path) or log_msg("Cannot chdir to $abs_path $!", 1);

#------------------------------------------------------------------------------
# CREATE PDF
#------------------------------------------------------------------------------
my $res = latex2pdf ( $pdf_export_path, $job_name, $tex_file_wrapper, $pdf_fullname );

#------------------------------------------------------------------------------
# CHECK IF PDF IS GENERATED
#------------------------------------------------------------------------------
# if all went ok
if ( $res ) {

    # update report pdf status if pdf file has been generated
    $log->debug("Updating pdf_ready status for report  $reportid ...");

    my $update_query = qq{UPDATE reports.meetings SET meet_pdf_time = CURRENT_TIMESTAMP WHERE meet_id = $reportid};
    $log->info("QUERY DI UPDATE: $update_query");

    dbh_execute_query($update_query);
}

#------------------------------------------------------------------------------
# DISCONNECT FROM DB
#------------------------------------------------------------------------------
dbh_disconnect();

#------------------------------------------------------------------------------
# THE END
#------------------------------------------------------------------------------
end();
exit(0);





#------------------------------------------------------------------------------
# SUBS
#------------------------------------------------------------------------------
# funzione per gestire i null: se presente un null, oppure una stringa vuota, lo sostituisce con la stringa '--'
sub controlnull {
    my $dato = shift;

    if (!defined $dato) {
        return "--";
    } elsif ($dato eq '') {
        return "--";
    } else {
        return $dato;
    }
}

# funzione di lancio del comando di generazione del PDF partendo dai files .tex generati
sub latex2pdf {
    my $exppath = shift;
    my $jobname  = shift;
    my $texfile  = shift;
    my $pdffile  = shift;

    # log
    $log->info("");
    $log->debug("Generating pdf file $pdffile ...");

    # delete the pdf file if exists
    if (-e $pdffile) { unlink $pdffile; }

    # default to wrong result
    my $res = 0;

    # -------------------------------------------------------
    # generate pdf
    # http://www.perlhowto.com/executing_external_commands
    # cat test.tex | pdflatex &>/dev/null && rm texput.log texput.aux
    # -interaction=STRING  set interaction mode (STRING=batchmode/nonstopmode/scrollmode/errorstopmode)
    # -------------------------------------------------------
    if ( $^O eq 'linux' ) {
        $log->debug("Calling system() ...");
        $log->debug("pdflatex -interaction=nonstopmode --shell-escape -output-directory=$exppath --jobname=$jobname $texfile");
        system("pdflatex -interaction=nonstopmode --shell-escape -output-directory=$exppath --jobname=$jobname $texfile");
        system("pdflatex -interaction=nonstopmode --shell-escape -output-directory=$exppath --jobname=$jobname $texfile");

        if ( $? == -1 ) {
            $log->debug("Command failed: $!");
        } else {
            $log->debug( (printf "Command exited with value %d", $? >> 8));
            $res = 1;
        }

        $log->debug("Calling chmod ...");
        if (-e $pdffile) {
            chmod 0744, $pdffile or $log->debug( "Couldn't chmod $pdffile: $!" );
        }
    }

    # if all went ok delete support files
    if ( $res ) {
        # clear all -- http://www.perlhowto.com/working_with_files
        $log->debug("Unlinking support files ...");
        #if ( ! $DEBUG ) { unlink <$exppath/report*.tex>; }
        unlink <$exppath/report*.tex>;
        unlink <$exppath/*.tex>;
        unlink <$exppath/*.aux>;
        unlink <$exppath/*.log>;
        unlink <$exppath/*.out>;
        # del *.dvi
        # del *.aux
        # del *.bbl
        # del *.blg
        # del *.brf
        # del *.out
    }

    # return
    return $res;
}

# funzione di download delle immagini attraverso https
sub getImage {

    my $img_url = shift;
    my $img_name = shift;
    my $img_save_path = "$abs_path/inc/tmp/$img_name.jpg";
    $log->debug("Downloading ... ");

    # displaying a user friendly message
    $log->debug($img_save_path);

    # first parameter is the URL of the image
    # second parameter is the location of the downloaded image

    getstore($img_url, $img_save_path);

    # checking for successful
    if (-e $img_save_path) {
        $log->debug("Image successfully downloaded.");
        return 1;
    }
    else {
        $log->debug("Image download failed.");
        return 0;
    }
}

# funzione che effettua la trasformazione del codice html in testo latex attraverso delle regular expressions
sub escape_html {
    my $field = shift;

    #
    # convertions
    # http://www.iwriteiam.nl/html2tex.html#com
    # http://www.personal.ceu.hu/tex/breaking.htm
    # http://alvinalexander.com/blog/post/latex/crazy-sed-script-convert-html-code-latex
    #

    #open (FILE, ">>", 'mylog.txt');
    #print FILE $field . "  ->  ";

    $field =~ s|&gt;|>|g;
    $field =~ s|&lt;|<|g;
    $field =~ s|&nbsp;| |g;

    $field =~ s|_|\\_|g;

    $field =~ s|<p>||g;
    $field =~ s|</p>| |g;

    $field =~ s|<br>| \\par|g;
    $field =~ s|<hr>|\\hline\n|g;

    $field =~ s|<ul>|\\begin{itemize}\n|g;
    $field =~ s|<li>|\\item |g;
    $field =~ s|</li>|\n|g;
    $field =~ s|</ul>|\\end{itemize}\n|g;

    $field =~ s|<ol>|\\begin{enumerate}\n|g;
    $field =~ s|<li>|\\item |g;
    $field =~ s|</li>|\n|g;
    $field =~ s|</ol>|\\end{enumerate}\n|g;

    $field =~ s|<strong>|\\textbf{|g;
    $field =~ s|</strong>|}\n|g;

    $field =~ s|<b>|\\textbf{|g;
    $field =~ s|</b>|}\n|g;

    $field =~ s|<u>|\\ul{|g;
    $field =~ s|</u>|}\n|g;

    $field =~ s|<i>|\\textit{|g;
    $field =~ s|</i>|}\n|g;

    $field =~ s|<s>||g;
    $field =~ s|</s>||g;

    $field =~ s|<h1>|\\par {\\Huge |g;
    $field =~ s|</h1>|} \\par \n|g;

    $field =~ s|<h2>|\\par {\\huge |g;
    $field =~ s|</h2>|} \\par \n|g;

    $field =~ s|<h3>|\\par {\\LARGE |g;
    $field =~ s|</h3>|} \\par \n|g;

    $field =~ s|<h4>|\\par \\textcolor{BOBOgreen}{\\Large |g;
    $field =~ s|</h4>|} \\par\n|g;

    $field =~ s|<h5>|\\par \\textcolor{BOBOgreen}{\\large |g;
    $field =~ s|</h5>|} \\par \n|g;

    $field =~ s|<small>|\\textcolor{BOBOorange}{\\small |g;
    $field =~ s|</small>|}|g;

    #print FILE $field . "\n";
    #close (FILE);
    return $field;
}
