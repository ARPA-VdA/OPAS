# DATI - VALIDAZIONE

Per accedere alla sezione dedicata alla validazione dei dati delle stazioni, cliccare nel menu laterale sulla voce "Dati" e selezionare "Validazione".

<h3>
    > Dati<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <i>o</i> <span style="color:red">Validazione</span>
</h3>

Verrà visualizzata la schermata principale dello strumento Validazione.

![10](img/[10]_home.png "Home")

1. <u>Menu di Validazione</u>: vedi "Menu di Validazione";
2. <u>Lista stazioni & dati sospetti</u>: in questa sezione vengono elencate, organizzate ad albero, le stazioni, raggruppate per rete di appartenenza, e i dati identificati automaticamente come sospetti.

    ![30](img/[30]_staz_e_sosp.png "Lista stazioni e dati sospetti")

    È possibile modificare questa sezione rendendo possibile la selezione per parametro:

    - Dal menu a tendina "Strumenti", cliccare 'Opzioni'.

        ![40](img/[40]_strumenti_si_invalid.png "Strumenti")

    - Attivare l'opzione 'Visualizza per parametro' e cliccare su 'Applica in locale'.

        ![41](img/[41]_opz_generali.png "Generali")

    - E così verranno visualizzati i parametri

        ![41-1](img/[41-1]_visu_param.png "Visualizza per parametro")

3. <u>Dettaglio codici & storico modifiche</u>: in questa sezione è possibile visualizzare, una volta selezionato il dato dalla tabella posta al centro (punto 4.), il dettaglio dei codici attualmente applicati al valore (tab "Codici validità") e il dettaglio delle modifiche effettuate sul dato scelto, sia come valore sia come codice applicato, sotto forma di "storico" (tab. "Storico modifiche"):

    * Dettaglio dei codici

        ![50](img/[50]_his_+_valid.png "Dettaglio codici - Valido")
        ![51](img/[51]_his_+_valid_2.png "Dettaglio codici - Non Valido")

    * Dettaglio delle modifiche

        ![52](img/[52]_his_+_valid_3.png "Storico modifiche")

4. <u>Schermata di visualizzazione tabellare dei dati</u>: in questa sezione vengono visualizzati i dati, in formato tabellare, della stazione selezionata;

    ![60](img/[60]_tabella_principale.png "Tabella dei dati")

    La schermata di default visualizzerà i dati del giorno precedente a quello odierno dalle ore 00 (mezzanotte) alle ore 23.

    Qualora si selezioni un periodo più esteso di un giorno, sarà possibile selezionare il numero di righe per pagina tra dei multipli di 24, così da poter selezionare 2, 3 o 4 giorni.

    ![61](img/[61]_numero_righe.png "Numero di righe per pagina")

    Per validare un dato, selezionare la cella corrispondente, oppure cliccare e trascinare per selezionare più celle in una volta sola

    ![62](img/[62]_celle_multiple.png "Celle multiple")

    e successivamente selezionare il codice desiderato dall'elenco di quelli disponibili posto alla destra della tabella (punto 5.).

    Per modificare un dato, effettuare doppio click sulla cella selezionata (il dato sarà disponibile per la modifica)

    ![63](img/[63]_modifica_dato.png "Modificare un dato")

    e successivamente modificare il dato inserendo un nuovo valore, oppure utilizzando gli appositi pulsanti "Su" e "Giù".

    Per effettuare modifiche su più dati contemporaneamente, selezionare le celle desiderate e utilizzare la schemata delle "Operazioni" (punto 6.).

    Infine, per effettuare validazioni o modifiche su grandi moli di dati, è possibile utilizzare lo strumento <img src="img/pulsico/calendario.png" height="40px" /> (vedi "Calendario") oppure lo strumento <img src="img/pulsico/mod_avanzata.png" height="40px" /> (vedi "Modalità Avanzata").

    Quando uno o più dati della tabella appaiano in grassetto:

    ![100](img/[100]_dati_modificati.png "Dati modificati")

    Significa che sono state apportate modifiche (validazione/operazione) e, una volta aggiornata la tabella tramite il tasto 'Aggiorna' in alto, torneranno normali.

    Inoltre, possono avere colori diversi in base ai codici di validazione apportati ai dati (punto 5.). Se il dato è valido, di default la cella è di colore bianco.

    Facendo click con il tasto destro del mouse sulla cella di un dato è possibile visualizzare il grafico del dettaglio nella fascia temporale da 24 ore prima a 24 ore dopo.

    ![110](img/[110]_grafico.png "Grafico")

    Infine, mediante il bottone posto in alto a destra del grafico è possibile visualizzare a schermo intero e stampare il grafico.

    ![111](img/[111]_pulsante_grafico.png "Menu del grafico")

5. <u>Codici validità</u>: elenco dei codici di validità disponibili;

    ![60](img/[60]_codici.png "Codici di validità")

    Dopo aver selezionato dalla tabella il/i dato/dati, cliccare il codice di validazione che si vuole applicare.

    Quando si vogliono assegnare più codici ad un/dei dato/dati, bisognerà selezionare nuovamente il/i dato/dati nella tabella applicando una validazione alla volta.

    Infine, cliccando il pulsante <img src="img/pulsico/help.png" height="40px"></img> verrà visualizzato l'elenco dei codici di validazione impostati per il portale.

6. <u>Operazioni</u>: da questa sezione è possibile applicare ed effettuare delle operazioni ad uno o più dati selezionati nella tabella principale.

    ![70](img/[70]_operazioni.png "Operazioni")

    Dopo aver selezionato dalla tabella il/i dato/dati che serve/servono, scegliere una delle quattro operazioni, inserire il valore e, infine, cliccare il tasto 'Esegui'.

    Esattamente come accade per i codici di validità, anche le operazioni possono essere fatte una alla volta selezionando nuovamente dalla tabella il dato che si intende modificare.

## Menu di Validazione

![190](img/[190]_menu_principale.png "Menu principale")

1. Torna al portale;
2. Torna alla pagina iniziale di Validazione;
3. Accedi alla documentazione (questa pagina);

### Menu principale - *Strumenti*

![40](img/[40]_strumenti_si_invalid.png "Menu Strumenti")

* <u>Opzioni</u>:

    Tutte le impostazioni che si andranno a modificare in questa voce possono essere applicate in maniera temporanea (pulsante "Applica in locale") o salvate nel database (pulsante "Salva nel DB") in modo tale da ritrovarle ad un successivo accesso alla sezione. Le impostazioni sono per utente e quindi le modifiche di uno non andranno ad influenzare gli altri utenti.

    * <u>Generali</u>: in questo menu è possibile visualizzare i dati grezzi, andando a disattivare l'interruttore 'Visualizza dati convertiti', attivare/disattivare la visualizzazione dell'STID (ID della stazione), della QUOTA cliccando sul relativo bottone;

        ![41](img/[41]_opz_generali.png "Generali")

    * <u>Grafici</u>: in questa sezione è possibile personalizzare il layout dei grafici visualizzati;

        ![120](img/[120]_opz_grafici.png "Grafici")

    * <u>Tabelle</u>: in questa sezione è possibile attivare/disattivare i filtri di visualizzazione;

        ![130](img/[130]_opz_tabelle.png "Tabelle")

        Attraverso i filtri è possibile effettuare delle ricerche di determinati valori all'interno della tabella visualizzata:

        ![131](img/[131]_filtri.png "Filtri di visualizzazione")

        1. Selezionare la colonna che si intende filtrare;
        2. Selezionare l'operazione di ricerca tra quelle disponibili:

            ![132](img/[132]_operazioni_filtri.png "Operazioni")

        3. Inserire il valore per cui filtrare;

        Di seguito un esempio:

        ![133](img/[133]_valori_filtrati.png "Valori filtrati")

        Cliccando il pulsante "Annulla" verranno resettati tutti i filtri e si visualizzerà nuovamente l'intera tabella.

    * <u>Filtri</u>: ###

* <u>Carica albero completo</u>: cliccando su questa voce è possibile caricare velocemente tutto l'albero delle stazioni/parametri. Per confermare l'azione, cliccare su "Si, carica!".

    ![150](img/[150]_strum_carica_alb.png "Carica albero completo")

### Menu secondario - Filtri e operazioni

![300](img/[300]_menu_secondario.png "Filtri e operazioni")

1. <u>Data inizio/fine</u>: selezionare il periodo temporale in cui verranno visualizzati i dati;

    ![301](img/[301]_data_inizio_fine.png "Inserimento data")

2. Pulsante <img src="img/pulsico/aggiorna.png" height="40px" />: aggiorna i tab sulla base delle date e della fascia temporale richiesta;
3. Pulsante <img src="img/pulsico/validaz.png" height="40px" />: contrassegna come validati tutti i parametri visualizzati;
4. Pulsante <img src="img/pulsico/calendario.png" height="40px" />: cliccando questo pulsante è possibile effettuare la validazione dei parametri, oppure delle operazioni, tramite calendario:

    ![200](img/[200]_validazione_calendario.png "Validazione tramite calendario")

    1. Periodo temporale:

        Attraverso questo strumento è possibile impostare il periodo temporale.

        È importante ricordare che, per impostare il periodo, è SEMPRE NECESSARIO CLICCARE DUE VOLTE, una per il giorno d'inizio e una per il giorno di fine (il calendario di sinistra si riferisce alla data d'inizio, mentre quello di destra alla data di fine).

        Per impostare l'orario, selezionare i minuti e le ore dai menu a tendina (quelli di sinistra si riferiscono all'ora d'inizio, mentre quelli di destra all'ora di fine).

        Per confermare il periodo cliccare il pulsante "Applica".

        ![31](img/[31]_calendar_datehour.png "Calendario data/ora")

    2. Seleziona la provincia;
    3. Seleziona la stazione;
    4. Seleziona il parametro;
    5. Attività da svolgere: selezionare l'attività da svolgere nel periodo temporale impostato al punto 1:

        * Modifica dei dati

            ![201](img/[201]_attività_modifica.png "Attività da svolgere > Modifica")

        * Validazione dei dati

            ![202](img/[202]_attività_validaz.png "Attività da svolgere > Validazione")

        Attivando "Filtrare per valore" è possibile selezionare i dati da modificare/validare in maniera ancora più precisa:

        ![203](img/[203]_filtrare_per_valore.png "Filtrare per valore")

5. Pulsante <img src="img/pulsico/mod_avanzata.png" height="40px" />: attiva la modalità avanzata per inserimento/modifica dei dati (vedi "Modalità avanzata");
6. Pulsante <img src="img/pulsico/copia_tabella.png" height="40px" />: cliccando questo pulsante è possibile copiare la tabella visualizzata negli appunti (clipboard) del PC, rendendo possibile incollarla su un foglio di calcolo, come ad esempio Excel;
7. Pulsante <img src="img/pulsico/reset.png" height="40px" />: resetta i tab (svuota), o quello attivo, o tutti quelli presenti attualmente;

    ![36](img/[36]_menu_2_reset.png "Reset")

## Modalità avanzata

Cliccando il pulsante <img src="img/pulsico/mod_avanzata.png" height="40px" /> verrà abilitata la modalità avanzata la tabella visualizzata si colorerà di rosso, li linee diventeranno tratteggiate e verranno aggiunti dei pulsanti al menù:

![402](img/[402]_tabella_mod.png "Tabella rossa")

![400](img/[400]_modalita_avanzata.png "Menu principale")

1. Il pulsante principale passerà allo stato "ON" una volta attivata la modalità avanzata;
2. Pulsante <img src="img/pulsico/copia_tabella.png" height="40px" />: cliccando questo pulsante è possibile copiare la tabella visualizzata negli appunti (clipboard) del PC, rendendo possibile incollarla su un foglio di calcolo, come ad esempio Excel;
3. Pulsante <img src="img/pulsico/salva.png" height="40px" />: salva le modifiche effettuate;
4. Pulsante <img src="img/pulsico/annulla.png" height="40px" />: scarta le modifiche effettuate;
5. Pulsante <img src="img/pulsico/info.png" height="40px" />: cliccando questo pulsante verranno visualizzate le informazioni relative all'utilizzo della modalità avanzata:

    ![401](img/[401]_info_mod_ava.png "Menu principale")

Successivamente:

* Cliccare sul bottone blu <img src="img/pulsico/copia_tabella.png" height="40px" />: un messaggio di avvenuta copia verrà visualizzato in alto a destra:

    ![403](img/[403]_msg_copia.png "Copia avvenuta")

* Sul proprio dispositivo, aprire un nuovo foglio di calcolo, ad esempio "Excel", e incollare la tabella copiata:

    ![404](img/[404]_excel.png "Incollo su Excel")

* Inserire e/o modificare i dati come si desidera;
* Copiare la tabella modificata selezionando TUTTE le colonne precedentemente incollate, non solo quelle modificate;
* Tornare su "Validazione" e mettere a fuoco la tabella cliccando (click singolo o doppio) sulla colonna "Data";
* Incollare la tabella tramite la combinazione di tasti CTRL + V: un messaggio di avvenuta copia verrà visualizzato in alto a destra:

    ![405](img/[405]_msg_incolla.png "Incolla avvenuta")

    le celle modificate saranno evidenziate tramite uno sfondo rosso:

    ![406](img/[406]_fine_copia_incolla.png "Modifiche copiate e incollate")

* Salvare le modifiche nel database tramite il bottone blu <img src="img/pulsico/salva.png" height="40px" />, oppure cliccare su <img src="img/pulsico/annulla.png" height="40px" /> per cancellare le modifiche e disabilitare la modalità avanzata.

