# STRUMENTI - MAPPER

Per poter accedere a questa sezione è necessario cliccare sulla voce "Strumenti" posta nel menu principale di sinistra ed in seguito cliccare sull'elemento "Mapper".

<h3>
    > Strumenti<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <i>o</i> <span style="color:red">Mapper</span>
</h3>

Verrà visualizzata la schermata principale dello strumento Mapper.

![20](img/[20]_map.png "Mapper")

1. Elenco province disponibili sul portale;

    ![30](img/[30]_selez_prov.png "Selezione province")

2. Elenco/ricerca stazioni disponibili sul portale;

    ![40](img/[40]_cerca_staz.png "Cerca stazioni")

3. Pulsante <u>Aggiorna</u>: una volta selezionato la provincia e/o la stazione, premere il pulsante per aggiornare la mappa;
4. Pulsante <u>Reset</u>: resetta la mappa ricaricando quella iniziale (visualizzazione di tutte le stazioni disponibili sul portale);
5. Filtro di selezione delle reti disponibili sul portale: cliccare su una delle reti per nasconderne i marcatori sulla mappa. Cliccando nuovamente si riattiverà la visualizzazione dei marcatori;

    * Tutte le reti selezionate (Default):

        ![21](img/[21]_filtro_all_selez.png "Filtro di selezione delle reti")

    * Nessuna rete selezionata (dopo aver cliccato "Deseleziona tutti"):

        ![22](img/[22]_filtro_not_selez.png "Filtro di selezione delle reti")

        Cliccando su "Seleziona tutti" si tornerà allo stato precedente.

6. Mappa;
7. Zoom +/- della mappa (è possibile zoomare in avanti e indietro anche utilizzando la rotella del mouse);
8. Mappa a schermo intero;
9. Filtro della mappa

    Attraverso questo filtro è possibile modificare la visualizzazione della mappa:

    ![50](img/[50]_filtro.png "Filtro della mappa")

    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;a. Tipologia della mappa

    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;b. Reti disponibili sul portale

    Gli elementi <u>SELEZIONATI</u> e <u>ATTIVI</u> sono quelli in <u>BLU</u>, mentre quelli in <u>BIANCO</u> sono <u>DISATTIVATI</u>.

    Seguono alcuni esempi di filtro:

    Formato mappa: STANDARD

    ![51](img/[51]_map_standard.png "Esempio mappa 1")

    Formato mappa: SATELLITE

    ![52](img/[52]_map_satellite.png "Esempio mappa 2")

    Formato mappa: TOPOGRAFIA

    ![53](img/[53]_map_topografica.png "Esempio mappa 3")

10. Marcatori stazioni disponibili sul portale;

    L'indicatore <img src="img/pulsico/staz_sospesa.png" height="40px"></img> identifica le stazione attive, ma SOSPESE sul portale.

11. Informazioni sul proprietario del portale;

## Marcatori stazioni disponibili sul portale

Una volta individuata la stazione interessata, cliccando sul marcatore corrispondente, verrà visualizzata la finestra relativa contenente le informazioni e i links alle pagine di anagrafica, sinottico e dati in real time.

![60](img/[60]_map_popup.png "Mappa con marcatori")

1. Schede della pagina:

    * Mappa: schermata visualizzata in questo momento;
    * Eventuali schede <u>Anagrafica</u> <img src="img/pulsico/anagrafica.png" height="40px"></img>, <u>Sinottico</u> <img src="img/pulsico/sinottico.png" height="40px"></img> e <u>Real Time</u> <img src="img/pulsico/realtime.png" height="40px"></img> delle stazioni selezionate;

2. Finestra informativa della stazione selezionata;
3. Links:

    ### Scheda "Anagrafica"

    In questa sezione è possibile visualizzare i dati anagrafici della stazione selezionata in precedenza:

    ![70](img/[70]_anagr_staz.png "Anagrafica stazione")

    1. Immagine della stazione;
    2. Dati anagrafici della stazione.

    ### Scheda "Sinottico"

    In questa sezione è possibile visualizzare i grafici degli strumenti presenti sulla stazione di un certo periodo temporale impostato dall'utente.

    ![80](img/[80]_sinott_staz.png "Sinottico stazione")

    1. Pulsante <u>Aggiorna con i dati attuali</u>: aggiorna i grafici sottostanti con gli ultimi dati aggiornati;
    2. Periodo temporale;

        Attraverso questo strumento è possibile impostare il periodo temporale.

        È importante ricordare che, per impostare il periodo, è SEMPRE NECESSARIO CLICCARE DUE VOLTE, una per il giorno d'inizio e una per il giorno di fine.

        Una volta selezionato il periodo, premere il pulsante Applica per completare l'operazione.

        ![31](img/[31]_calendar_date.png "Calendario")

        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;a. Data d'inizio;<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;b. Data di fine;<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;c. Pulsante <u>Applica</u>;<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;d. Pulsante <u>Annulla</u>: chiude la finestra del periodo temporale;<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;e. Calendario mese precedente;<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;f. Calendario mese corrente.<br>

    3. Pulsante <u>Conversione dati</u>: attivando la conversione dei dati, il sistema applicherà il fattore di conversione impostato per i parametri presenti sulla stazione selezionata:

        * <img src="img/pulsico/no.png" height="50px" width="80px"></img> --> Parametri non convertiti

        * <img src="img/pulsico/si.png" height="50px" width="80px"></img> --> Parametri convertiti

    4. Grafici dei parametri presenti sulla stazione;

        Cliccando sul pulsante <img src="img/pulsico/menu_grafico.png" height="40px" width="40px"></img> dei grafici è possibile visualizzare a schermo intero il grafico, stamparlo, estrarne i dati e salvarli in formato CSV, oppure salvarlo in formato JPEG o PDF.

        ![81](img/[81]_sinott_grafico_1.png "Grafici sinottico")

        1. <u>Menu del grafico</u>;
        2. <u>Filtro dei valori del grafico</u>;

            Inoltre, è possibile modificare il grafico impostando quali valori visualizzare e quali no cliccando sulle scritte presenti:

            ![82](img/[82]_sinott_grafico_2.png "Grafici sinottico")


    ### Scheda "Realtime"

    In questa sezione è possibile osservare, in tempo reale, i dati che arrivano dagli strumenti presenti nella stazione selezionata:

    ![90](img/[90]_rt_staz.png "Grafici sinottico")

    1. Pulsante <img src="img/pulsico/ulteriori_dettagli.png" height="40px"></img>: cliccando qui si verrà reindirizzati alla pagina "Dati" > "Dati istantanei" dove saranno visualizzati i dati istantanei dei parametri, con i relativi strumenti a cui sono associati,0 in formato tabellare e suddivisi per tipologia di parametro (Chimici, Polveri, Diagnostici, ...);
    2. Barra di progressione dei dati istantanei e data/ora dell'ultimo dato ricevuto;
    3. Grafici dei dati;

        ![91](img/[91]_rt_grafico.png "Grafici sinottico")

