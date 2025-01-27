# INFOARIA - DATASET E1a

Per poter accedere a questa sezione è necessario cliccare sulla voce "Infoaria", posta nel menu principale di sinistra, ed in seguito cliccare sull'elemento "Dataset E1a".

<h3>
    > Infoaria<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <i>o</i> <span style="color:red">Dataset E1a</span>
</h3>

Da questa pagina è possibile creare i dataset E1a che vengono inviati ad ISPRA con cadenza annuale.

![10](img/[10]_index.png "Dataset E1a")

## STEP 1

In questo step è <u>OBBLIGATORIO</u> selezionare l'anno e la regione di riferimento del dataset che si intende generare.

## STEP 2

In questo step è possibile aggiungere le associazioni stazione/parametro al dataset che si sta creando.

![13](img/[13]_tabella.png "Tabella stazione/parametro")

1. Selezionare una <u>rete</u> (filtro tabella);

    ![11](img/[11]_selez_reti.png "Reti")

2. Selezionare una <u>provincia</u> (filtro tabella);
3. Selezionare una <u>stazione</u> (filtro tabella);

    ![12](img/[12]_stazioni.png "Stazioni")

4. Selezionare un <u>parametro</u> (filtro tabella);
5. Pulsante <img src="img/pulsico/si.png" height="50px"></img> / <img src="img/pulsico/no.png" height="50px"></img> per modificare in una volta sola TUTTI gli invii delle associazioni presenti nella tabella sottostante;
6. Numero di elementi della tabella per pagina;
7. <u>Filtro di ricerca nella tabella</u>: la ricerca viene effettuata su tutte le colonne della tabella;
8. Tabella delle associazioni stazione/parametro;

    È possibile selezionare singolarmente quali dati andranno inviati ad ISPRA mediante i pulsanti <img src="img/pulsico/si.png" height="50px"></img> / <img src="img/pulsico/no.png" height="50px"></img>

    Le seguenti configurazioni elencate sono <span style="color:red">OBBLIGATORIE</span>:

    * impostare il **codice europeo** della stazione dalla pagina "Infoaria > Dataset D";
    * i parametri inviati **devono essere associati ad uno strumento** al fine di generare correttamente il codice identificativo dello SPO necessario ad Infoaria;
    * i parametri inviati e le relative stazioni **devono avere impostate le date di attivazione** nella sezione di anagrafica del portale (pagina "Impostazioni rete > Stazioni") al fine di generare correttamente gli identificativi di Infoaria;
    * in futuro, per garantire il corretto funzionamento del sistema, qualora venga dismesso uno strumento presente in una stazione che effettuava l'invio dei dati, **ricordarsi di disattivare anche il relativo invio presente nella tabella**.

9. Esplorazione delle pagine;

## STEP 3

In questo step è possibile creare il CSV del dataset. Ci sono due possibilità:

* Generare un file di anteprima, senza effettuare alcun invio:

    <img src="img/pulsico/anteprima.png" height="50px"></img>

* Generare il file ufficiale ed effettuare il caricamento di quest'ultimo sul server FTP di ISPRA:

    <img src="img/pulsico/csv_ufficiale.png" height="50px"></img>

In entrambi i casi, sarà richiesta la conferma all'utente per generare il file csv:

![21](img/[21]_send_last.png "Messaggio")

