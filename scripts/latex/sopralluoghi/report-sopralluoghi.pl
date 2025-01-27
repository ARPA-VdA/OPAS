#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : report-sopralluoghi.pl
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#
#   REPORT SOPRALLUOGHI
#       Perl script to generate report PDF
#
#   RUN EXAMPLE:
#       (insp_id)   $ perl /path/to/script/report-sopralluoghi.pl 16
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
use experimental qw(switch);
use JSON;
use LWP::Simple;
use HTML::Restrict; # remove all html
use POSIX qw(strftime);
use Encode qw( encode_utf8 );

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
my $logfile  = 'report-sopralluoghi.log';
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
    $log->warn("No ReportID provided!");
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
my $tex_file_wrapper = $working_path.'/report_sopralluoghi_'.$random_str.'.tex';
my $tex_file_body = $working_path.'/sopralluoghi_'.$random_str.'.tex';
my $tex_file_headfoot = $working_path.'/header_footer_sopralluoghi_'.$random_str.'.tex';

#------------------------------------------------------------------------------
# CONNECT TO DATABASE
#------------------------------------------------------------------------------
dbh_connect($db_settings) or bail_out("Cannot connect to database !");

#------------------------------------------------------------------------------
# QUERY
#------------------------------------------------------------------------------
my $sql = qq{
    SELECT
        i.insp_id,
        i.mu_id,
        mu.mu_name,
        p.province_id,
        p.province_code,
        p.province_name,
        mu.mu_name||' ('||p.province_code||')' AS municipality_format,
        i.insp_locality,
        i.insp_fulldate,
        TO_CHAR(i.insp_fulldate, '<strong>DD/MM/YYYY</strong> alle <strong>HH24:MI</strong>') AS insp_fulldate_format,
        TO_CHAR(i.insp_fulldate, 'DD/MM/YYYY') AS insp_date_format,
        TO_CHAR(i.insp_fulldate, 'HH24:MI') AS insp_hour_format,
        i.insp_operators,
        ARRAY(
            SELECT
                us_name || ' ' || COALESCE(us_2nd_name||' ', '') || us_surname AS us_fullname
            FROM
                bobo.users
            WHERE
                us_id = ANY(i.insp_operators)
        ) AS operators_name,
        i.insp_note,
        i.us_id,
        u.us_name || ' ' || COALESCE(u.us_2nd_name||' ', '') || u.us_surname AS us_fullname,
        u.us_avatar_thumb,
        i.insp_insert_ts,
        -- Allegati
        (
            SELECT to_json(ARRAY_AGG(row_to_json(j)))
            FROM (
                SELECT
                    ia.att_id AS file_id,
                    lpad(ia.insp_id::text , 9, '0')||'/'||ia.file_archive AS file_archive,
                    ia.file_image,
                    ia.file_original
                FROM
                    reports.inspection_attachments ia
                WHERE ia.insp_id = i.insp_id
            ) j
        ) AS attachments,
        um.portal_id,
        po.portal_logo
    FROM
        reports.inspections i
        LEFT JOIN bobo.users_metadata um USING (us_id)
        LEFT JOIN main.municipalities mu USING (mu_id)
        LEFT JOIN main.province_municipalities pm USING (mu_id)
        LEFT JOIN main.provinces p USING (province_id)
        LEFT JOIN bobo.users u USING (us_id)
        LEFT JOIN bobo.portals po ON um.portal_id = po.portal_id
    WHERE
        i.insp_id = $reportid;
};

#------------------------------------------------------------------------------
# GET RECORD
#------------------------------------------------------------------------------
# campi della query sql
my $inspection = dbh_get_row_hashref( $sql );
$log->debug(Dumper($inspection));

# controllo se il report è presente oppure no
if (!$inspection) {
    $log->warn("No report with id $reportid!");
    end();
    exit(1);
}

#------------------------------------------------------------------------------
# RULES OF HTML HANDLER
#------------------------------------------------------------------------------
# use default rules to start with (strip away all HTML) => no arguments to new() function
# OR setup some rules:
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
);
# THEN pass the hash '%rules' as argument
my $hr = HTML::Restrict->new( rules => \%rules );

#------------------------------------------------------------------------------
# HEADER/FOOTER
#------------------------------------------------------------------------------
$log->debug('header-footer sopralluoghi ...');

# variabile contenuto
my $headfoot;

# togliere il commento se si vuole prendere l'immagine del logo dalla directory "/inc" (caricare l'immagine in quella cartella)
# my $logo_name = basename($inspection->{portal_logo});

# costruzione del file .tex
$headfoot .= '%%----------------- DEFINIZIONE HEADER E FOOTER -----------------'."\n";
$headfoot .= '\pagestyle{fancy}'."\n";
$headfoot .= '\setlength{\headheight}{50pt} % distanza dell\'header dalla cima del foglio'."\n";
$headfoot .= '\setlength{\footskip}{80pt} % distanza del footer dall\'ultima linea della pagina'."\n";
$headfoot .= '\fancyhf{} % cancella tutti i campi di intestazione e pie pagina'."\n";
$headfoot .= "\n";
$headfoot .= '%% modifica colore delle linee dell\'header e del footer'."\n";
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
$headfoot .= '    \raisebox{2ex}{\includegraphics[height=1cm, keepaspectratio]{'.$logo_path.''.$inspection->{portal_logo}.'}}'."\n";
$headfoot .= '}'."\n";
$headfoot .= "\n";
$headfoot .= '\fancyhead[R]{'."\n";
$headfoot .= '    \raisebox{1.5ex}{\textcolor{greyHEADFOOT}{\bfseries{\Large Report Sopralluoghi}}} \\\\'."\n";
$headfoot .= '}'."\n";
$headfoot .= '%%----------------- FOOTER -----------------'."\n";
$headfoot .= '\fancyfoot[L]{'."\n";
$headfoot .= '    \textcolor{greyHEADFOOT}{\bfseries{'.$foot_desc.' - Report Sopralluoghi}} \\\\'."\n";
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
$log->debug('corpo centrale sopralluoghi ...');

# variabile contenuto
my $body;

# costruzione del file .tex
# titolo
$body .= '\begin{center}'."\n";
$body .= '    \textcolor{BOBOblue}{\Large{Sopralluogo n. \textbf{'.$inspection->{insp_id}.'} del \textbf{'.$inspection->{insp_date_format}.'} alle \textbf{'.$inspection->{insp_hour_format}.'}}} % TITOLO'."\n";
$body .= '\end{center}'."\n";
$body .= "\n";
$body .= '\vspace*{1mm}'."\n";
$body .= "\n";

# dati sopralluogo
$body .= '\begin{center}'."\n";
$body .= '    \renewcommand{\arraystretch}{1.5}'."\n";
$body .= '    \begin{tabularx}{0.90\textwidth}{'."\n";
$body .= '        r'."\n";
$body .= '        p{0.70\textwidth}'."\n";
$body .= '    }'."\n";
$body .= '        \bfseries{Operatore:} & \mdseries{'.latex_encode($inspection->{us_fullname}).'} \\\\'."\n";
$body .= '        \bfseries{Provincia:} & \mdseries{'.latex_encode($inspection->{province_name}).'} \\\\'."\n";
$body .= '        \bfseries{Comune:} & \mdseries{'.latex_encode($inspection->{municipality_format}).'} \\\\'."\n";
$body .= '        \bfseries{Localita\':} & \mdseries{'.latex_encode($inspection->{insp_locality}).'} \\\\'."\n";

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
$body .= '} \\\\'."\n";

$body .= '        \\\\'."\n";
$body .= '        \bfseries{Note:} & \mdseries{'.escape_html($hr->process($inspection->{insp_note})).'} \\\\'."\n";
$body .= '    \end{tabularx}'."\n";
$body .= '\end{center}'."\n";
$body .= "\n";
$body .= '\vspace*{1mm}'."\n";
$body .= "\n";

# allegati
# $inspection->{attachments} --> array di json
my $arr_allegati = $inspection->{attachments};

# check se ci sono allegati o no
if (!$arr_allegati) {
    $log->info("NO ATTACHMENTS");
    $body .= '    \section*{\textcolor{BOBOblue}{\bfseries{Allegati}}}'."\n";
    $body .= '    \mdseries{Nessun allegato}'."\n";
} else {
    $arr_allegati = decode_json(encode_utf8($inspection->{attachments}));
    $log->info("ATTACHMENTS: IMAGES");
    $body .= '\newpage'."\n";
    $body .= "\n";
    $body .= '%%%%%%%%%%%%%%%%%%%%%%%% - Allegati (immagini) - %%%%%%%%%%%%%%%%%%%%%%%%'."\n";
    $body .= '\subsection*{\textcolor{BOBOblue}{\mdseries{Immagini}}}'."\n";
    $body .= '\begin{figure}[!h]'."\n";
    $body .= '    \begin{minipage}{0.75\linewidth}'."\n";

    # contatore immagini per latex
    my $image_counter = 1;

    # flag presenza immagini
    my $images = 0;

    # gestione array degli allegati PER LE IMMAGINI
    foreach my $allegato ( @{$arr_allegati} ){
        # controllo se l'allegato è un'immagine
        if (!$allegato->{file_image}){
            $log->info("NOT IMAGE: NEXT ATTACHMENT...");
            next;
        }

        $log->info("EXIST IMAGE: ADDING IT...");
        $body .= '        \subfigure[Foto '.$image_counter.']{%'."\n";
        $body .= '            \setlength{\tabcolsep}{10mm}'."\n";
        $body .= '            \begin{tabular}{c}'."\n";
        $body .= '                \includegraphics*[width=0.45\textwidth,height=0.28\textheight,keepaspectratio]{'.check_fix_imgs($allegato->{file_archive}).'}'."\n";
        $body .= '            \end{tabular}'."\n";
        # if ($image_counter % 3 == 0) {
        #     $body .= '        } \\\\'."\n";
        # } else {
        #     $body .= '        }'."\n";
        # }

        $body .= '        }'."\n";

        $image_counter = $image_counter + 1;
        $images = 1;
    }

    if (!$images){
        $body .= '        \mdseries{Nessuna immagine}'."\n";
    }

    $body .= '    \end{minipage}'."\n";
    $body .= '\end{figure}'."\n";
    $body .= ''."\n";

    # flag presenza altri allegati (no immagini)
    my $others = 0;

    $log->info("ATTACHMENTS: OTHERS");
    $body .= '%%%%%%%%%%%%%%%%%%%%%%%% - Allegati (files) - %%%%%%%%%%%%%%%%%%%%%%%%'."\n";
    $body .= '\subsection*{\textcolor{BOBOblue}{\mdseries{Altri allegati}}}'."\n";

    $body .= '\begin{itemize}'."\n";

    # gestione array degli allegati PER GLI ALTRI ALLEGATI
    foreach my $allegato ( @{$arr_allegati} ){
        # controllo se l'allegato è un'immagine
        if ($allegato->{file_image}){
            $log->info("IS IMAGE: NEXT ATTACHMENT...");
            next;
        }

        # se non è un'immagine: inserire il nome originale nell'elenco puntato
        $body .= '    \item '.latex_encode($allegato->{file_original}).''."\n";
        $others = 1;
    }

    $body .= '\end{itemize}'."\n";

    if (!$others){
        $body .= '\mdseries{Nessun altro allegato}'."\n";
    }
}

#------------------------------------------------------------------------------
# WRAPPER
#------------------------------------------------------------------------------
$log->debug('wrapper sopralluoghi ...');

# variabile contenuto
my $wrap;

# costruzione del file .tex
$wrap .= '%% -------------------- PREAMBOLO --------------------'."\n";
$wrap .= '\input{'.$abs_path.'/inc/preamble.tex}'."\n";
$wrap .= ''."\n";
$wrap .= '%% -------------------- DEFINIZIONE HEADER E FOOTER --------------------'."\n";
$wrap .= '\input{'.$tex_file_headfoot.'}'."\n";
$wrap .= ''."\n";
$wrap .= '%% -------------------- DEFINITIONS --------------------'."\n";
$wrap .= '\input{'.$abs_path.'/inc/define.tex}'."\n";
$wrap .= ''."\n";
$wrap .= '%% -------------------- INIZIO DOCUMENTO --------------------'."\n";
$wrap .= '\begin{document}'."\n";
$wrap .= ''."\n";
$wrap .= '    \input{'.$tex_file_body.'}'."\n";
$wrap .= ''."\n";
$wrap .= '\end{document}'."\n";
$wrap .= '%% -------------------- FINE DOCUMENTO --------------------'."\n";

#------------------------------------------------------------------------------
# WRITE TO FILES
#------------------------------------------------------------------------------
# FILE WRAPPER
$log->info("Writing to file $tex_file_wrapper ...");
$log->info("");
open(FILE ,">:encoding(UTF-8)", $tex_file_wrapper) or die $!;
print FILE $wrap;
close FILE;

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
my $job_name = 'report-sopralluoghi'.'-'.sprintf("%06d",$reportid);
my $pdf_filename = $job_name.'.pdf';
my $pdf_fullname = $pdf_export_path.'/'.$pdf_filename;

#------------------------------------------------------------------------------
# CHANGE WORKING PATH
#------------------------------------------------------------------------------
$log->debug("Changing working path ...");
chdir($abs_path) or log_msg("Cannot chdir to $abs_path $!", 1);

#------------------------------------------------------------------------------
# CREATE PDF
#------------------------------------------------------------------------------
my $res = latex2pdf ( $pdf_export_path, $job_name, $tex_file_wrapper, $pdf_fullname, $working_path, $random_str );

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
    my $exppath  = shift;
    my $jobname  = shift;
    my $texfile  = shift;
    my $pdffile  = shift;
    my $workpath = shift;
    my $randstr  = shift;

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

        # remove ".tex" files once finished
        $log->debug("Unlinking tex files ...");
        unlink <$workpath/*$randstr.tex>;
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

# funzione che converte le immagini per visualizzarle correttamente all'interno del PDF
sub check_fix_imgs {
    my $img = shift;

    # regex per estrarre il nome dell'immagine senza estensione
    my $name_to_convert = $1 if $img =~ /(\d+\/file-\d+-\d+)/; # solo per le immagini

    # regex per estrarre il nome della directory in cui sono salvate le immagini
    $imgs_dir = $1 if $img =~ /(\d+\/)/;
    make_path($url_sopralluoghi.$imgs_dir);
    $log->info($imgs_dir);

    my $conv_imgs_path = "$url_sopralluoghi"."$name_to_convert".".png";

    $imgs_path = $url_sopralluoghi.$img;

    $log->info("PATH: $imgs_path");
    $log->info("CONV PATH: $conv_imgs_path");

    # conversione immagini in PNG per visualizzarle sul PDF
    system("convert $imgs_path $conv_imgs_path");

    # verifica esistenza file convertito
    if (-e $conv_imgs_path) {
        # utilizzo di 'pngquant' per il resize dell'immagine convertita
        system("pngquant $conv_imgs_path --output $conv_imgs_path --force");

        return $conv_imgs_path;
    } else {
        return "$abs_path/inc/facsimile.jpg";
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

    $field =~ s|<u>|\\underbar{|g;
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
