# OPAS
PROGETTO OPAS: OPen Air System

Il sistema OPAS è composto da un insieme di componenti Hardware e Software che vanno a formare un'infrastruttura atta alla gestione di molteplici reti di monitoraggio dati sia chimici che meteo.

Le attività principali del sistema sono l'acquisizione, la validazione, l'elaborazione e l'export dei dati acquisiti nel tempo.
E' composto da una parte centrale, formata dal Datacenter e dai software Web, e da una costellazione di sistemi di acquisizione periferici che vanno ad alimentare il database principale con i dati raccolti in periferia.

## Architettura del progetto

Gli applicativi web si basano sul framework MVC Mojolicious (https://mojolicious.org/) basato sul linguaggio Perl, installato attraverso l'applicativo Perlbrew (https://perlbrew.pl/).

L'architettura MVC (Model-View-Controller) è un modello software comunemente usato nello sviluppo di interfacce utente che suddivide la logica del programma in tre elementi distinti al fine di separare le rappresentazioni interne delle informazioni dai modi in cui queste vengono presentate e accettate dall'utente finale.
Questi tre elementi sono:

* MODEL: responsabile della gestione dei dati dell'applicazione. Riceve gli input dell'utente tramite il controller;
* VIEW: renderizza la presentazione del model in un determinato formato;
* CONTROLLER: risponde all'input dell'utente ed esegue le interazioni sugli oggetti del modello di dati. Il controller riceve l'input, lo convalida (se necessario) e quindi passa l'input al model.

Per quanto riguarda il database, il sistema utilizzato è PostgreSQL.

PostgreSQL è un sistema *open source* di gestione di database relazionale orientato agli oggetti (ORDBMS) che utilizza ed estende il linguaggio SQL combinato con molte funzionalità che archiviano e ridimensionano in modo sicuro i carichi di lavoro dei dati più complicati.

Un ORDBMS (Object–Relational DataBase Management System) è un modello di database relazionale orientato agli oggetti: oggetti, classi ed ereditarietà di questi sono direttamente supportate negli schemi del database e nell'esecuzione delle query. Inoltre, così come i sistemi puramente relazionali (non orientati agli oggetti), il modello supporta l'estensione dei modelli di dati attraverso la creazione di metodi e tipologie di dati personalizzati.

## Download

Via shell:
```console
$ git clone ...
```

Una volta effettuato il download, copiare la cartella */src* nel path desiderato e seguire le istruzione del file in doc/*INSTALL.md*.
