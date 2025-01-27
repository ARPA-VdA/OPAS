# STRUMENTI - GRAFICI OPENAIR

Per poter accedere a questa sezione occorre cliccare sulla voce "Strumenti" posta nel menu principale di sinistra e cliccare sull'elemento "Grafici OpenAir".

<h3>
    > Strumenti<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <i>o</i> <span style="color:red">Grafici OpenAir</span>
</h3>

Attraverso questo strumento è possibile generare e visualizzare i grafici OpenAir riguardanti gli inquinanti delle stazioni della propria rete di appartenenza.

![10](img/[10]_index.png "Grafici OpenAir")

1. Creazione di una nuova configurazione;
2. Pulsanti <u>CSV</u> - <u>PDF</u> - <u>STAMPA</u> : è possibile scaricare l'elenco delle configurazioni sottostanti in due formati, CSV e PDF, oppure stamparlo direttamente;
3. <u>Filtro di ricerca nella tabella</u>: la ricerca viene effettuata su tutte le colonne della tabella;
4. Tabella delle configurazioni: cliccando il pulsante <img src="img/pulsico/visual.png" height="50px"></img> è possibile visualizzare le immagini dei grafici, organizzate per tipologia:

    ![30](img/[30]_grafici.png "Grafici")

5. Esplorazione delle pagine;

## Crea una nuoca configurazione

![20](img/[20]_config.png "Nuova configurazione")

Per generare i grafici compilare i seguenti campi:

1. Intervallo date (<span style="color:red">*</span>obbligatorio);

    Attraverso questo strumento è possibile impostare il periodo temporale per la visualizzazione dei dati.

    L'utente ha due possibilità: selezionare il periodo dall'elenco di default presente sulla sinistra (punto "a."), oppure impostarlo manualmente (nell'elenco di default verrà selezionato automaticamente "Personalizza"). In quest'ultimo caso, è importante ricordare che, per impostare il periodo, è SEMPRE NECESSARIO CLICCARE DUE VOLTE, una per il giorno d'inizio e una per il giorno di fine.

    Una volta selezionato il periodo, premere il pulsante Applica per completare l'operazione.

    ![000](img/[000]_new_calendar_date.png "Calendario")

    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;a. Periodi di default;<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;b. Calendario mese precedente;<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;c. Calendario mese corrente;<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;d. Pulsante <u>Annulla</u>: chiude la finestra del periodo temporale;<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;e. Pulsante <u>Applica</u>;<br>

2. Calma di vento (<span style="color:red">*</span>obbligatorio);
3. Categoria di strumenti: è possibile selezionare una categoria per generare i grafici SOLO per quella tipologia d'inquinante. Qualora non si selezioni niente, verranno generate le immagini per TUTTI gli inquinanti;
4. Provincia della stazione inquinante (filtro per il campo 5.);
5. Stazione inquinante (<span style="color:red">*</span>obbligatorio);
6. Provincia della stazione meteo (filtro per il campo 7.);
7. Stazione meteo (<span style="color:red">*</span>obbligatorio);
8. Limite inferiore dei grafici;
9. Limite superiore dei grafici;
10. Impostazione della scala dei grafici (<span style="color:red">*</span>obbligatorio): è possibile scegliere tra 3 possibilità:

    * <u>Default</u>: la scala viene gestita automaticamente dallo script di generazione delle immagini;
    * <u>N° fasce della scala</u>: inserire il numero di fasce in cui verrà ripartita la scala;
    * <u>Ripartizione step della scala</u>: inserire una serie di numeri, in ordine crescente, per definire ogni step della scala;

11. Pulsanti <img src="img/pulsico/crea_grafici.png" height="50px"></img> per effettuare la richiesta di generazione dei grafici, oppure il pulsante "Annulla" per ripulire il form.

