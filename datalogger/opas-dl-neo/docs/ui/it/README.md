# Documentazione UI

Panoramica delle sezioni principali dell'app OPAS DL Neo.

## Dashboard

Vista d'insieme della stazione: allarmi di sistema (disco quasi pieno, strumenti che non
rispondono, servizio Python non raggiungibile) se presenti, scorciatoia alla vista preferita
se ne hai impostata una, stato dei driver e log recenti.

## Strumenti

Elenco degli strumenti configurati. Aprendo il dettaglio di uno strumento si vedono le card
"Parametri" e "Diagnostici" con i valori correnti, incluso il valore raw pre-formula quando
disponibile (dipende dalla build del servizio Python in uso).

## Driver

Stato dei driver che comunicano con gli strumenti fisici, con accesso ai relativi log.

## Configurazioni

Gestione dei file di configurazione del servizio (strumenti, moduli, canali, formule).

## Grafici

Visualizzazione storica delle letture, per canale e intervallo di tempo.

## Viste

Dashboard personalizzate: seleziona i canali che ti interessano tra più strumenti e salvali
come vista, in formato card o tabella. Una vista può essere impostata come preferita (icona a
stella) per comparire come scorciatoia in Dashboard.

## Impostazioni

Percorso del servizio Opas DL, livello di log di stazione, numero massimo di decimali
mostrato per i valori raw. Le impostazioni dell'app (percorso del servizio e decimali) si
possono esportare su file e reimportare, ad esempio per un backup o per riportarle su
un'altra installazione.

## Documentazione

Questa sezione: raccoglie la documentazione del servizio Python ("Servizio Python") e quella
della UI (questa pagina).

## Sistema

Informazioni sulla versione dell'app, stato del servizio Python e utilizzo di CPU/RAM/disco.
