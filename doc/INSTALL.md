# INSTALLAZIONE PORTALE OPAS

## PREPARAZIONE AMBIENTE

* ### Creare una macchina virtuale (VM) con i seguenti requisiti minimi:

    * CPU: 4 core
    * RAM: 32 GB
    * HDD: 50 GB

* ### Installare il sistema operativo (OS) "Ubuntu 24.04.1 LTS" tramite l'immagine (ISO) da scaricare al seguente link:

    https://releases.ubuntu.com/noble/ubuntu-24.04.1-live-server-amd64.iso
## AGGIUNGERE DETTAGLI SU PARAMETRI DI INSTALLAZIONE DI Ubuntu (Ex. pacchetti, layout tastiera e lingua)
## POST INSTALLAZIONE

* ### Accesso alla macchina virtuale appena creata tramite *SSH*

    ```console
    ssh [USERNAME]@[HOSTANAME_O_IP]
    ```

* ### Primo aggiornamento del sistema

    ```console
    [USERNAME]@[HOSTANAME_O_IP]:~$ sudo apt update
    [USERNAME]@[HOSTANAME_O_IP]:~$ sudo apt autoremove -y
    [USERNAME]@[HOSTANAME_O_IP]:~$ sudo apt remove needrestart -y
    [USERNAME]@[HOSTANAME_O_IP]:~$ sudo apt upgrade -y
    ```

* ### Aggiungere il pacchetto per la lingua italiana

    ```console
    $ sudo apt install language-pack-it -y
    $ sudo locale-gen it_IT.utf8
    $ sudo update-locale
    $ locale -a
        (verificare che sia presente il pacchetto "it_IT.utf8")
    C
    C.utf8
    en_US.utf8
    it_CH.utf8    <--
    it_IT.utf8    <--
    POSIX
    ```

* ### Installare il pacchetto *net-tools*

    ```console
    $ sudo apt install net-tools
    ```

* ### Impostare la Timezone a *UTC*

    ```console
    $ sudo dpkg-reconfigure tzdata
        - selezionare "None of the above" o "Etc";
        - selezionare "UTC";
        (verificare che il "Local time" e lo "Universal Time" siano entrambi ad "UTC")
    Current default time zone: 'Etc/UTC'
    ...
    ...
    ```

* ### SSH

    ```console
    $ ssh-keygen
                          - cliccare "Invio" ad ogni richiesta
    Your identification has been saved in /home/USERNAME/.ssh/id_rsa
    Your public key has been saved in /home/USERNAME/.ssh/id_rsa.pub
    The key fingerprint is:
    SHA256:N3tfwOnLvJY2rR0+PQlCEBhDLHZ6Irh59MUgyCZi+Cs USERNAME@HOSTANAME
    The key's randomart image is:
    ...
    ...
    ```

## POSTGRESQL + POSTGIS

* ### Installazione

    ```console
    $ sudo apt install postgresql-common -y
    $ sudo sh /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
        (cliccare "Invio" per continuare)
    $ sudo apt update && sudo apt upgrade -y
    $ sudo apt install postgresql-17 -y
    $ sudo apt install postgresql-plperl-17
    $ sudo apt install postgresql-plpython3-17 -y
    $ sudo apt install postgresql-17-postgis-3
    ```

* ### Per verificare i pacchetti installati, lanciare il seguente comando:

    ```console
    $ dpkg --get-selections | grep postgres
    postgresql-17                                   install
    postgresql-17-postgis-3                         install
    postgresql-17-postgis-3-scripts                 install
    postgresql-client-17                            install
    postgresql-client-common                        install
    postgresql-common                               install
    postgresql-plperl-17                            install
    postgresql-plpython3-17                         install
    ```

* ### Configurazione

    Creare il file *opas.conf* sotto la directory */etc/postgresql/17/main/conf.d*, così da impostare le seguenti configurazioni:
    - permettere ad un qualunque IP della rete di collegarsi al db;
    - impostare il corretto stile per i valori relativi alle date;
    ```console
    $ sudo vi /etc/postgresql/17/main/conf.d/opas.conf
    (inserire le seguenti linee)
    listen_addresses = '*'
    datestyle = 'iso, dmy'
    ```
    Approntare le seguenti modifiche al file */etc/postgresql/17/main/pg_hba.conf*:

    Copiare il file di configurazione originale, così da poter ripristinare, all'occorrenza, le impostazioni default
    ```console
    $ sudo cp /etc/postgresql/17/main/pg_hba.conf /etc/postgresql/17/main/pg_hba.conf.original
    ```

    Modificare il file per inserire i permessi di accesso agli utenti utilizzati per le connessioni al database (*user_bobo* e *user_tools*):
    Gli indirizzi Ip e la maschera (xxx.xxx.xxx.xxx/24) da inserire nel file di configurazione dovranno rispecchiare la tipologia di rete utilizzata.
	```console
    $ sudo vi /etc/postgresql/17/main/pg_hba.conf
    (da inserire SOTTO alla sezione indicata con "# IPv6 local connections:")
    ...
    ...
    # intranet
    # TYPE  DATABASE        USER            ADDRESS                 METHOD
    #host    all             all             192.168.1.0/24        scram-sha-256
    host    all             postgres        192.168.1.0/24        scram-sha-256
    host    all             user_bobo       192.168.1.0/24        scram-sha-256
    host    all             user_tools      192.168.1.0/24        scram-sha-256
    ...
    ...
    ```

    Impostare la password per l'utente "postgres"
    ```console
    $ sudo -i -u postgres psql
    (digitare il seguente comando psql)
    \password
    (digitare la nuova password)
    xxxx
    (confermare la nuova password)
    xxxx
    (comando per uscire)
    \q
    ```

    Una volta completate tutte le configurazioni, riavviare il servizio
    ```console
    $ sudo service postgresql restart
    ```

## PERL

* ### Installazione di Perlbrew

    Per installare perlbrew viritare la pagina http://perlbrew.pl, di seguito riassunti i comandi necessari.

    ```console
    $ \curl -L http://install.perlbrew.pl | bash
    $ echo 'source ~/perl5/perlbrew/etc/bashrc' >> ~/.bashrc
    $ exec $SHELL
    $ sudo apt install build-essential -y
    $ perlbrew available # mostra le versioni disponibili
    $ perlbrew install perl-5.40.0 # installa la versione mettendoci 10 minuti buoni
    $ perlbrew switch perl-5.40.0 # rede la versione installata quella di default
    $ perl --version # mostra la versione corrente
    $ perlbrew install-cpanm  # installa l'estensione cpanm, per semplificare la gestione dei pachetti Perl
    ```

## MOJOLICIOUS

* ### Prerequisiti

    ```console
    $ sudo apt install libssl-dev
    $ sudo apt install libpq-dev
    $ sudo apt install libgd-dev -y
    $ sudo apt install pkg-config
    $ sudo apt install libnet-ssleay-perl libcrypt-ssleay-perl libio-socket-ssl-perl -y
    ```

* ### Installazione

    Per effettuare l'installazione visitare il sito https://www.mojolicious.org, di seguito riassunti i comandi necessari.

    ```console
    $ curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n Mojolicious
    ```

* ### Installazione dei moduli CPAN necessari al portale:

    ```console
    $ cpanm Mojolicious::Plugin::Authentication --notest
    $ cpanm Mojolicious::Plugin::Authorization --notest
    $ cpanm Mojo::Pg --notest
    $ cpanm Unicode::UTF8 --notest
    $ cpanm Date::Calc --notest
    $ cpanm DateTime --notest
    $ cpanm DateTime::Format::Strptime --notest
    $ cpanm Email::Send::SMTP::Gmail --notest
    $ cpanm GD::Thumbnail --notest
    $ cpanm WWW::Mechanize --notest
    $ cpanm Archive::Zip --notest
    $ cpanm Time::Moment --notest
    $ cpanm File::Find::Rule --notest
    $ cpanm Text::CSV::Encoded --notest
    $ cpanm Mojo::AsyncAwait --notest
    $ cpanm Log::Log4perl::Level --notest
    $ cpanm Net::Address::IP::Local --notest
    $ cpanm JSON --notest
    ```

## NGINX

* ### Installazione

    ```console
    $ sudo apt install nginx -y
    ```

* ### Configurazione

    ```console
    $ sudo vi /etc/nginx/conf.d/opas.conf
    ```
    Copiare ed incollare il seguente contenuto:

    ```console
    upstream opastest {
      server 127.0.0.1:8080;
    }
    server {
      listen 80;
      server_name localhost;
      location / {
        proxy_pass http://opastest;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }
    }
    ```

    Aprire il seguente file:
    ```console
    $ sudo vi /etc/nginx/nginx.conf
    ```

    Commentare la seguente linea dal file */etc/nginx/nginx.conf* per disabilitare la route di default del server nginx:

    ```console
    include /etc/nginx/sites-enabled/*;
    ```

    Infine, ricaricare il server:

    ```console
    $ sudo service nginx restart
    ```

* ### Clonare il repository da Github in una directory locale

    ```console
    git clone https://github.com/ARPA-VdA/OPAS.git
    ```
    Una volta lanciato il comando, nella cartella *OPAS* si ritroveranno le directories *src*, *doc*, *scripts*, *webservice* e *db* contenenti i file dell'applicativo e gli sql.
    Spostarsi nella cartella appena creata

    ```console
    $ cd ./OPAS
    ```

## POPOLAMENTO DB (cartella */db*)

La seguente tabella elenca i file .sql necessari a popolare il database:

| Ordine | Nome del file    |
| - | - |
|      1 | db_creation.sql  |
|      2 | full_db.sql      |
|      3 | foreign_keys.sql |
|      4 | minimum_data.sql |

* Creazione del database *opas* e tutti di ruoli/users necessari al corretto funzionamento del portale:

    Il file Sql db_creation contiene le insert degli utenti e le password di default. questo possono essere modificare prima di lanciare il comando, oppure dal portale nella propia sezione di impostazioni
    ```console
    $ psql -h localhost -U postgres -f ./db/db_creation.sql
    ```

* Creazione dello 'scheletro' (tabelle + viste + funzioni) del database:

    ```console
    $ psql -h localhost -U postgres -d opas -f ./db/full_db.sql
    ```

* Creazione delle chiavi esterne del database:

    ```console
    $ psql -h localhost -U postgres -d opas -f ./db/foreign_keys.sql
    ```

* Inserimento dei dati minimi necessario all'avvio del portale:

    ```console
    $ psql -h localhost -U postgres -d opas -f ./db/minimum_data.sql
    ```

## PRIMA DI AVVIARE IL SERVER...

Modificare il file *bobo.production.conf* inserendo i propri dati nella stringa *database* (sostituire *user*, *pass*, *host*, *port*, *dbname*, *application_name*, e *app.name*)

Stringa di connessione da modificare in base alla configurazione del proprio server postgres, se diversa da quella di default: 'postgresql://user:pass@host:port/dbname?pg_enable_utf8=1&application_name="app.name"'

```console
$ vi ~/OPAS/src/bobo.production.conf
...
...
database => 'postgresql://user_bobo:xxxxxxxxxx@localhost:5432/opas?pg_enable_utf8=1&application_name="webapp.opas"',
```

## AVVIARE IL SERVER PER ACCEDERE AL PORTALE

Lanciare il comando:
```console
$ hypnotoad -f src/script/bobo
```

## ACCEDERE AL PORTALE

Aprire il browser internet e puntare a:

```url
http://[INDIRIZZO_IP_SERVER]:8080
```

Effettuare il login al portale con le seguenti credenziali:

```
USERNAME: utente.opas@opas.it
PASSWORD: Opas
```

## DEPLOY DELL'APPLICATIVO

L'applicativo web può essere utilizzato per test e sviluppo sfruttando l'http server built-in tramite il comando:
```console
$ hypnotoad src/script/bobo # omettere il flag "-f"
```

Per l'utilizzo in un ambiente di produzione si potrà utilizzare uno dei servizi http descritti nella pagina https://docs.mojolicious.org/Mojolicious/Guides/Cookbook#DEPLOYMENT, attivando anche l'HTTPS tramite certificati SSL
