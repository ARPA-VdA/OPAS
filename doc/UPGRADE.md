# AGGIORNAMENTO PORTALE OPAS

## UPGRADE DALLA VERSIONE 2.0.1 ALLA VERSIONE 2.0.3

### Aggiornamento DB (cartella */db/upgrades*)

* Spostarsi nella cartella principale del portale

    ```console
    $ cd ~/OPAS
    ```

* Creazione e aggiornamento delle tabelle, delle viste e delle funzioni utili per la nuova versione del portale :

    ```console
    $ psql -h localhost -U postgres -d opas -f ./db/upgrades/v2.0.1\ to\ 2.0.3.sql

### Aggiornamento portale (nella cartella */src*)

* In */src* sovrascrivere le cartelle */lib* e */templates* avendo cura di modificare nuovamente eventuali path / riferimenti interni al progetto con i propri dati

    ```console
    $ cd src/
    ```

* Spostarsi in public e sovrascrivere le cartelle */bobo-js*, */bobo-css* e */node_modules*
    
    ```console
    $ cd public/
    ```

### Deploy delle modifiche

* Lanciare il comando per rendere effettive le modifiche del portale
    ```console
    $ hypnotoad src/script/bobo


## UPGRADE DALLA VERSIONE 2.0.0 ALLA VERSIONE 2.0.1

### Aggiornamento DB (cartella */db/upgrades*)

* Spostarsi nella cartella principale del portale

    ```console
    $ cd ~/OPAS
    ```

* Creazione e aggiornamento delle tabelle, delle viste e delle funzioni utili per la nuova versione del portale :

    ```console
    $ psql -h localhost -U postgres -d opas -f ./db/upgrades/v2.0.0\ to\ 2.0.1.sql

### Aggiornamento portale (cartella */src*)

* Sovrascrivere tutte le cartelle contenute in */src* avendo cura di modificare nuovamente i dati di connessione ed eventuali path / riferimenti interni al progetto con i propri dati

### Deploy delle modifiche

Lanciare il comando per rendere effettive le modifiche del portale
```console
$ hypnotoad src/script/bobo