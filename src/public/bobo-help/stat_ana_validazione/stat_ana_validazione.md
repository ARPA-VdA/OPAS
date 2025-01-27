# STATISTICHE - ANALISI VALIDAZIONE

Per poter accedere a questa sezione occorre cliccare sulla voce "Statistiche" posta nel menu principale di sinistra ed in seguito cliccare sull'elemento "Analisi validazione".

<h3>
    > Statistiche<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <i>o</i> <span style="color:red">Analisi validazione</span>
</h3>

In questa sezione è possibile visualizzare le statistiche relative ai codici di validazione/invalidazione, suddivise per stazione, in un determinato periodo temporale impostabile dall'utente.

La pagina è suddivisa in due macro sezioni:

![10](img/[10]_schede.png "Schede")

## Analisi singola stazione

![20](img/[20]_analisi_singola_staz.png "Schede")

1. Periodo temporale:

    Attraverso questo strumento è possibile impostare il periodo temporale per la visualizzazione dei dati.

    È importante ricordare che, per impostare il periodo, è SEMPRE NECESSARIO CLICCARE DUE VOLTE, una per il giorno d'inizio e una per il giorno di fine.

    Una volta selezionato il periodo, premere il pulsante Applica per completare l'operazione.

    ![31](img/[41]_calendar_date.png "Calendario - Periodo temporale")

    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;a. Valori preimpostati OPPURE personalizzati dall'utente;<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;b. Pulsante per visualizzare il mese precedente;<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;c. Pulsante per visualizzare il mese successivo.<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;d. Calendario mese precedente;<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;e. Calendario mese successivo.<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;f. Pulsante <u>Annulla</u>: chiude la finestra del periodo temporale;<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;g. Pulsante <u>Applica</u>;<br>

2. Filtro per rete;
3. Filtro per provincia;
4. Selezione della stazione di cui si intende visualizzare le statistiche;
5. Pulsante <img src="img/pulsico/csv-stazione.png" height="40px"></img> : tramite questo pulsante è possibile effettuare il download delle statistiche estratte in formato *.csv*.

Una volta selezionata la stazione, verranno estratte le relative statistiche:

![21](img/[21]_tabella_stats.png "Statistiche - singola stazione")

E' importante ricordare che talvolta il totale dei dati invalidi/validi può non combaciare con l'effettivo numero dei dati invalidi/validi presi per singolo codice: ad esempio, nell'immagine, per il parametro "Parametro TRE" il "TOT" è 1, ma la somma dei dati presi singolarmente è 2 (1+1). Questo avviene perché è possibile che un singolo dato possa contenere molteplici codici di invalidità/validità e, di conseguenza, viene conteggiato più di una volta. Il totale dei dati invalidi/validi, invece, non tiene conto del numero di codici assegnati, ma solo dello stato di validità del dato stesso che, quindi, viene conteggiato un'unica volta.

## Analisi globale

![30](img/[30]_analisi_globale.png "Statistiche - analisi globale")

1. Periodo temporale (come sopra);
2. Selezione della rete di cui si intende visualizzare le statistiche per stazione;
3. Pulsante <img src="img/pulsico/genera.png" height="40px"></img>

Una volta selezionati il periodo temporale e la rete, cliccando il pulsante "Genera", verrà effettuata la richiesta al sistema di generazione di un file, formato *.csv* contenente le statistiche, relative al periodo temporale scelto, delle stazioni appartenenti alla rete scelta:

![31](img/[31]_msg_genera.png "Richiesta inoltrata")

Quando il file è stato generato, il sistema avvisa l'utente tramite una notifica posta in alto a destra sul portale:

![32](img/[32]_file_creato.png "File dati creato")

Inoltre, posta al di sotto dei campi d'inserimento, verranno visualizzate le informazioni relative all'ultimo file *.csv* generato:

![33](img/[33]_tabella_files.png "Files")

Infine, per effettuare il download del file *.csv* richiesto, cliccare il pulsante <img src="img/pulsico/csv-tutte-stazioni.png" height="40px"></img> .

