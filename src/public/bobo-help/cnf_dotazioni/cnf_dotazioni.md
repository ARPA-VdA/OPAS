# IMPOSTAZIONI RETE - DOTAZIONI

Per poter accedere a questa sezione è necessario cliccare sulla voce "Impostazioni rete", posta nel menu principale di sinistra, ed in seguito cliccare sull'elemento "Dotazioni".

<h3>
    > Impostazioni rete<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <i>o</i> <span style="color:red">Dotazioni</span>
</h3>

Da questa pagina è possibile visualizzare tutte le dotazioni, aggiungerne di nuove oppure posizionarle nelle stazioni appartenenti alla propria rete.

![10](img/[10]_index.png "Dotazioni")

1. Schede della pagina:

    * <u>Dotazioni</u>: elenco delle/degli dotazioni/stanziamenti già presenti;
    * <u>Dotazione</u>: scheda d'inserimento di una nuova dotazione;
    * <u>Stanziamento</u>: scheda d'inserimento di un nuovo stanziamento;

2. Interruttore per passare dalla visualizzazione delle dotazioni a quella degli stanziamenti:

    * <img src="img/pulsico/dotazione.png" height="45px"></img>

        ![100](img/[100]_dotazioni.png "Ricerca: Dotazione")

    * <img src="img/pulsico/stanziamento.png" height="45px"></img>

        ![101](img/[101]_stanziamenti.png "Ricerca: Stanziamento")

3. Pulsanti <u>CSV</u> - <u>PDF</u> - <u>STAMPA</u> : è possibile scaricare l'elenco delle/degli dotazioni/stanziamenti sottostanti in due formati, CSV e PDF, oppure stamparlo direttamente;
4. <u>Filtro di ricerca nella tabella</u>: la ricerca viene effettuata su tutte le colonne della tabella;
5. Tabella delle dotazioni:

    * <img src="img/pulsico/att.png" height="50px"></img> => dotazione dismessa/attiva
    * <img src="img/pulsico/disatt.png" height="50px"></img> => dotazione NON dismessa/attiva

6. Pulsanti:

    * <u>Visualizza dotazione</u> <img src="img/pulsico/visualizza.png" height="50px"></img>:

        ![40](img/[40]_visualizza_dettaglio.png "Visualizza dettaglio")

    * <u>Modifica dotazione</u> <img src="img/pulsico/modifica.png" height="50px"></img>: verrà aperta la scheda per modificare i dati della dotazione selezionata (stessi campi presenti in "Inserisci nuova dotazione");
    * <u>Scarica PDF</u> <img src="img/pulsico/scarica-pdf.png" height="50px"></img>: verrà effettuato il download del pdf relativo alla dotazione selezionata;
    * <u>Modifica location</u> <img src="img/pulsico/modif_location.png" height="50px"></img>: verrà aperta la scheda per modificare i dati della location selezionata (stessi campi presenti in "Inserisci nuova location");
    * <u>Chiudi location corrente</u> <img src="img/pulsico/chiudi_location.png" height="50px"></img>: cliccare questo pulsante per chiudere la location della dotazione selezionata; verrà visualizzato il seguente messaggio di conferma:

        ![50](img/[50]_chiudi_location.png "Chiudi location corrente")

    * <u>Elimina tutto</u> <img src="img/pulsico/elimina.png" height="50px"></img>: cliccare questo pulsante per eliminare la dotazione; verrà visualizzato il seguente messaggio di conferma:

        ![70](img/[70]_del_dotazione.png "Elimina dotazione")

        Cliccare "Si, elimina" per effettuare l'eliminazione.

7. Esplorazione delle pagine;

## Inserisci nuova dotazione

![80](img/[80]_new_dotazione.png "Inserisci nuova dotazione")

1. Arpa ID;
2. Data di <u>Dimissione</u>: verrà visualizzato il seguente form per la selezione della data:

    ![60](img/[60]_data.png "Selezione data")

    1. Mese precedente;
    2. Mese successivo;
    3. Anno precedente;
    4. Anno successivo;
    5. Scelta del giorno;

3. <u>Dotazione</u> (<span style="color:red">*</span>obbligatorio): inserire il nome identificativo della dotazione;
4. Interruttore <u>Dotazione attiva/non attiva</u>;

    * <img src="img/pulsico/si.png" height="50px" width="80px"></img> --> Dotazione attiva;
    * <img src="img/pulsico/no.png" height="50px" width="80px"></img> --> Dotazione NON attiva;

5. Selezionare una o più <u>Reti di appartenenza</u> (<span style="color:red">*</span>obbligatorio);
6. Inserire allegati alla dotazione: al click verrà visualizzata la finestra di sistema per scegliere i file;
7. Eventuali note;
8. Interruttore <u>Aggiungi location per la dotazione</u>:

    * <img src="img/pulsico/off.png" height="50px" width="80px"></img> --> No Location;
    * <img src="img/pulsico/on.png" height="50px" width="80px"></img> --> Aggiungi location;

        Se selezionato "Aggiungi location per la dotazione", si dovranno inserire i seguenti campi aggiuntivi (per il dettaglio dei campi, vedere "Inserisci nuovo stanziamento"):

        ![81](img/[81]_add_location_x_dotazione.png "Inserisci location per la dotazione")

9. Pulsanti <u>Inserisci</u> e <u>Annulla</u> : cliccare il pulsante "Inserisci" per effettuare l'inserimento della nuova dotazione, oppure il pulsante Annulla per ritornare alla scheda "Dotazioni";

## Inserisci nuovo stanziamento di una dotazione

![90](img/[90]_new_stanziamento.png "Inserisci nuovo stanziamento")

1. Selezionare la dotazione di cui si vuole effettuare lo stanziamento: nell'elenco saranno presenti le dotazioni create che non sono state ancora stanziate e quelle che non sono più stanziate (di cui si è effettuata la chiusura della location);
2. Selezionare la provincia (serve solo da filtro per il campo "Stazione");
3. Selezionare la stazione in base alla provincia scelta in precedenza (se non si è selezionata la provincia verranno elencate tutte le stazione presenti sul portale) (<span style="color:red">*</span>obbligatorio);
4. Inserire la data/ora di inizio dello stanziamento (<span style="color:red">*</span>obbligatorio): verrà visualizzato lo stesso form visto in fase di inserimento della dotazione;
5. Inserire la data/ora di fine dello stanziamento: questa data/ora NON è obbligatoria e, se il campo viene lasciato vuoto, verrà inserito il valore "infinito" e, di conseguenza, lo stanziamento sarà attivo a tempo indeterminato fino alla chiusura dello stesso da parte dell'utente;
6. Eventuali note;
7. Pulsanti <u>Inserisci</u> e <u>Annulla</u> : cliccare il pulsante "Inserisci" per effettuare l'inserimento del nuovo stanziamento, oppure il pulsante Annulla per ritornare alla scheda "Elenco";

