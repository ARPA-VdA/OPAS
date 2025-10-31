-- +----------------------------------------------------------------------------------------------+
-- | - Script Name   : v2.0.0 to 2.0.1.sql                                                        |
-- | - Author        : Ecometer s.n.c.                                                            |
-- | - Creation Date : 2025-06-30                                                                 |
-- | - Description   : Script to update PostgreSQL database.                    				  |
-- +----------------------------------------------------------------------------------------------+
	
-- -----------------------------------------------------------------
-- Add new pages to menu
-- -----------------------------------------------------------------
	INSERT INTO bobo.pages
        (page_id, page_name, page_href, page_shortcut_icon)
    VALUES	
    	(38, 'Media'   , '/media'      , 'fa-regular fa-photo-film'        ),
    	(68, 'Centro'  , '/plan_centro', 'fa-solid fa-list-tree'           );

    INSERT INTO bobo.group_pages
        (gr_id, page_id, gp_iud_grants)
    VALUES
        (3, 38, '111'),
        (3, 68, '111')
    ON CONFLICT ON CONSTRAINT bobo_group_pages_ukey DO NOTHING;

    INSERT INTO bobo.menu_pages
        (mp_id, menu_id, page_id, mp_name, mp_path, mp_order)
    VALUES
    	(49, 1, 38,   'Media' , 'sidebar1.media'			, 800), 
		(83, 1, 68,   'Centro', 'sidebar1.planning.centro'	, 352); 

	INSERT INTO bobo.menu_css
        (menu_css_id, mp_id, menu_css_class, menu_css_expanded, menu_css_icon, menu_css_blank, menu_css_beta)
    VALUES
		(35, 49, 'waves-effect waves-dark'	, true  , 'icon-layers', false, false ),
    	(79, 83, null						, true  , null		   , false, false );


    INSERT INTO bobo.groups (gr_id, gr_name, gr_shortname, gr_sys_admin) VALUES (125, 'Ticket Centro'   , 'Ticket Centro'   ,  FALSE);  
    INSERT INTO bobo.groups (gr_id, gr_name, gr_shortname, gr_sys_admin) VALUES (126, 'Manutentori CED' , 'Manutentori CED' ,  FALSE);  

    UPDATE bobo.portal_properties SET linked_gr_id = array_append(linked_gr_id, 125) WHERE admin_gr_id  = 3;
	UPDATE bobo.portal_properties SET linked_gr_id = array_append(linked_gr_id, 126) WHERE admin_gr_id  = 3;

-- -----------------------------------------------------------------
-- Create tables for ticket "Centro"
-- -----------------------------------------------------------------

    -- Tabella che contiene le varie tipologie di ticket
    -- DROP TABLE IF EXISTS reports.ced_ticket_types;
    CREATE TABLE reports.ced_ticket_types (
        ctt_id      smallint NOT NULL,
        ctt_name    text NOT NULL,
        ctt_desc    text NOT NULL,
        ctt_icon    text DEFAULT 'fa-regular fa-laptop-code',
        ctt_colour  text DEFAULT 'gray-dark',

        CONSTRAINT reports_ced_ticket_types_pkey PRIMARY KEY (ctt_id)
    );

    -- grants
    GRANT ALL ON TABLE    reports.ced_ticket_types TO group_admin;
    GRANT ALL ON TABLE    reports.ced_ticket_types TO group_bobo;
    GRANT ALL ON TABLE    reports.ced_ticket_types TO group_tools;
    GRANT SELECT ON TABLE reports.ced_ticket_types TO group_readonly;

    -- comments
    COMMENT ON TABLE  reports.ced_ticket_types              IS 'CED ticket types table';
    COMMENT ON COLUMN reports.ced_ticket_types.ctt_id       IS 'CED ticket type id';
    COMMENT ON COLUMN reports.ced_ticket_types.ctt_desc     IS 'CED ticket type name';
    COMMENT ON COLUMN reports.ced_ticket_types.ctt_desc     IS 'CED ticket type description';
    COMMENT ON COLUMN reports.ced_ticket_types.ctt_icon     IS 'CED ticket type icon';
    COMMENT ON COLUMN reports.ced_ticket_types.ctt_colour   IS 'CED ticket type text';

    INSERT INTO reports.ced_ticket_types
        (ctt_id, ctt_name, ctt_desc, ctt_icon, ctt_colour)
    VALUES 
        ( 1, 'Flusso dati (import)'     , 'I dati non vengono acquisiti correttamente dalla periferia'         , 'fa-solid fa-arrow-progress'       , 'purple'  ),
        ( 2, 'Web service (export)'     , 'I dati non vengono trasmessi correttamente verso sistemi esterni'   , 'fa-solid fa-arrow-right-from-line', 'primary' ),
        ( 3, 'Bug software'             , 'Il software presenta un comportamento anomalo o inatteso'           , 'fa-solid fa-bug'                  , 'violet'  ),
        ( 4, 'Malfunzionamento software', 'Una funzionalità che è sempre stata operativa, ora non funziona più', 'fa-solid fa-circle-exclamation'   , 'danger'  ),
        ( 5, 'Richiesta di assistenza'  , 'Hai bisogno di supporto su una pagina o funzione del sistema'       , 'fa-solid fa-messages'             , 'info'    ),
        (99, 'Altro'                    , 'La segnalazione non rientra nelle tipologie precedenti'             , 'fa-solid fa-waves-sine'           , 'esmerald');

    -- Tabella che contiene le varie tipologie di urgenza dei tickets
    -- DROP TABLE IF EXISTS reports.ced_ticket_urgencies;
    CREATE TABLE reports.ced_ticket_urgencies (
        ctu_id      smallint NOT NULL,
        ctu_name    text NOT NULL,
        ctu_desc    text NOT NULL,
        ctu_colour  text DEFAULT 'type',

        CONSTRAINT reports_ced_ticket_urgencies_pkey PRIMARY KEY (ctu_id)
    );

    -- grants
    GRANT ALL ON TABLE    reports.ced_ticket_urgencies TO group_admin;
    GRANT ALL ON TABLE    reports.ced_ticket_urgencies TO group_bobo;
    GRANT ALL ON TABLE    reports.ced_ticket_urgencies TO group_tools;
    GRANT SELECT ON TABLE reports.ced_ticket_urgencies TO group_readonly;

    -- comments
    COMMENT ON TABLE  reports.ced_ticket_urgencies              IS 'CED ticket urgencies table';
    COMMENT ON COLUMN reports.ced_ticket_urgencies.ctu_id       IS 'CED ticket urgency id';
    COMMENT ON COLUMN reports.ced_ticket_urgencies.ctu_name     IS 'CED ticket urgency name';
    COMMENT ON COLUMN reports.ced_ticket_urgencies.ctu_desc     IS 'CED ticket urgency description';
    COMMENT ON COLUMN reports.ced_ticket_urgencies.ctu_colour   IS 'CED ticket urgency colour';

    -- inserts
    INSERT INTO reports.ced_ticket_urgencies VALUES ( 1, 'Bassa'    , 'malfunzionamenti del sistema che non impediscono il regolare svolgimento di un processo applicativo, ma che siano causa di disagi nell’uso per l’utente.<br>(Esempio Dataview, Grafici OpenAir, Reportistica)', 'warning' );
    INSERT INTO reports.ced_ticket_urgencies VALUES (10, 'Media'    , 'malfunzionamenti tali da non impedire il regolare svolgimento di un processo applicativo, ma che siano causa di inefficienza o di problemi operativi per l’utente.<br>(Esempio Ticketing, Anagrafica, Mapper, Validazione Multilivello)', 'primary' );
    INSERT INTO reports.ced_ticket_urgencies VALUES (20, 'Alta'     , 'malfunzionamenti che impediscono l’utilizzo corretto di una singola funzionalità, pur non impedendo totalmente lo svolgimento del processo applicativo al quale la funzionalità appartiene;<br>(Esempio Visualizer, Analyser , Export Dati, Web Service)', 'danger'  );
    INSERT INTO reports.ced_ticket_urgencies VALUES (30, 'Bloccante', 'malfunzionamenti che impediscono il regolare svolgimento di un intero processo applicativo;<br>(Esempio i moduli Portale/Autenticazione, Validazione, Statistiche, Import Dati)', 'purple'  );


    -- Tabella che contiene le informazioni dei tickets
    -- DROP TABLE IF EXISTS reports.ced_tickets CASCADE;
    CREATE TABLE reports.ced_tickets (
        ct_id                   serial,
        ct_fulldate             timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        -- metadata --
        ct_title                text NOT NULL,
        ct_description          text NOT NULL,

        us_id                   integer NOT NULL,

        ct_useful               boolean DEFAULT TRUE,
        ct_email_ts             timestamp without time zone,
        ct_update_ts            timestamp without time zone,

        CONSTRAINT reports_ced_tickets_pkey PRIMARY KEY (ct_id),
        CONSTRAINT reports_ced_tickets_fkey2 FOREIGN KEY (us_id)
            REFERENCES bobo.users (us_id) MATCH SIMPLE
            ON UPDATE CASCADE
            ON DELETE RESTRICT
    );

    -- grants
    GRANT ALL ON TABLE    reports.ced_tickets TO group_admin;
    GRANT ALL ON TABLE    reports.ced_tickets TO group_bobo;
    GRANT ALL ON TABLE    reports.ced_tickets TO group_tools;
    GRANT SELECT ON TABLE reports.ced_tickets TO group_readonly;

    GRANT ALL ON SEQUENCE reports.ced_tickets_ct_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.ced_tickets_ct_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.ced_tickets_ct_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.ced_tickets                       IS 'Main table for CED tickets';
    COMMENT ON COLUMN reports.ced_tickets.ct_id                 IS 'CED ticket id';
    COMMENT ON COLUMN reports.ced_tickets.ct_fulldate           IS 'CED ticket opening date';
    COMMENT ON COLUMN reports.ced_tickets.ct_title              IS 'CED ticket title';
    COMMENT ON COLUMN reports.ced_tickets.ct_description        IS 'CED ticket description';

    COMMENT ON COLUMN reports.ced_tickets.us_id                 IS 'CED ticket creator';
    COMMENT ON COLUMN reports.ced_tickets.ct_useful             IS 'CED ticket utility';
    COMMENT ON COLUMN reports.ced_tickets.ct_email_ts           IS 'CED ticket date when email is sent';
    COMMENT ON COLUMN reports.ced_tickets.ct_update_ts          IS 'CED ticket update timestamp';

    -- Creazione di una nuova tipologia di dato: status
    CREATE TYPE reports.ced_status AS ENUM ('open', 'reassign', 'taken charge', 'closed');

    -- DROP VIEW IF EXISTS reports.view_ced_ticket_status;
    CREATE OR REPLACE VIEW reports.view_ced_ticket_status AS
    SELECT
        e.enumlabel         AS status_label,
        CASE e.enumlabel
            WHEN 'open' THEN 'Aperto'
            WHEN 'reassign' THEN 'Riassegnato'
            WHEN 'taken charge' THEN 'Preso in carico'
            WHEN 'closed' THEN 'Chiuso'
            ELSE '--'
        END                 AS status_desc,
        CASE e.enumlabel
            WHEN 'open' THEN 'Apri'
            WHEN 'reassign' THEN 'Riassegna'
            WHEN 'taken charge' THEN 'Prendi in carico'
            WHEN 'closed' THEN 'Chiudi'
            ELSE '--'
        END                 AS status_action,
        e.enumsortorder     AS status_order
    FROM
        pg_enum e
        LEFT JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'ced_status'
    ORDER BY e.enumsortorder;

        -- grants
    GRANT ALL ON TABLE    reports.view_ced_ticket_status TO group_admin;
    GRANT ALL ON TABLE    reports.view_ced_ticket_status TO group_bobo;
    GRANT ALL ON TABLE    reports.view_ced_ticket_status TO group_tools;
    GRANT SELECT ON TABLE reports.view_ced_ticket_status TO group_readonly;

    COMMENT ON VIEW  reports.view_ced_ticket_status        IS 'Main view for all possible status of CED tickets';

    -- Tabella che contiene i vari status dei ticket presenti nel sistema
    -- DROP TABLE IF EXISTS reports.ced_tickets_status CASCADE;
    CREATE TABLE reports.ced_tickets_status (
        cts_id                  serial,
        ct_id                   integer NOT NULL,

        -- metadata --
        us_id                   integer NOT NULL,
        cts_fulldate            timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        -- data --
        cts_status              reports.ced_status NOT NULL,
        gr_id                   integer NOT NULL,
        ctt_id                  smallint NOT NULL,
        ctu_id                  smallint,
        cts_description         text,

        CONSTRAINT reports_ced_tickets_status_pkey PRIMARY KEY (cts_id),
        CONSTRAINT reports_ced_tickets_status_fkey FOREIGN KEY (ct_id)
            REFERENCES reports.ced_tickets (ct_id) MATCH SIMPLE
            ON UPDATE CASCADE
            ON DELETE RESTRICT,
        CONSTRAINT reports_ced_tickets_status_fkey2 FOREIGN KEY (us_id)
            REFERENCES bobo.users (us_id) MATCH SIMPLE
            ON UPDATE CASCADE
            ON DELETE RESTRICT,
        CONSTRAINT reports_ced_tickets_status_fkey3 FOREIGN KEY (gr_id)
            REFERENCES bobo.groups (gr_id) MATCH SIMPLE
            ON UPDATE CASCADE
            ON DELETE RESTRICT,
        CONSTRAINT reports_ced_tickets_status_fkey4 FOREIGN KEY (ctt_id)
            REFERENCES reports.ced_ticket_types (ctt_id) MATCH SIMPLE
            ON UPDATE CASCADE
            ON DELETE RESTRICT,
        CONSTRAINT reports_ced_tickets_status_fkey5 FOREIGN KEY (ctu_id)
            REFERENCES reports.ced_ticket_urgencies (ctu_id) MATCH SIMPLE
            ON UPDATE CASCADE
            ON DELETE RESTRICT
    );

    -- grants
    GRANT ALL ON TABLE    reports.ced_tickets_status TO group_admin;
    GRANT ALL ON TABLE    reports.ced_tickets_status TO group_bobo;
    GRANT ALL ON TABLE    reports.ced_tickets_status TO group_tools;
    GRANT SELECT ON TABLE reports.ced_tickets_status TO group_readonly;

    GRANT ALL ON SEQUENCE reports.ced_tickets_status_cts_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.ced_tickets_status_cts_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.ced_tickets_status_cts_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.ced_tickets_status                    IS 'Main table for ticket status';
    COMMENT ON COLUMN reports.ced_tickets_status.cts_id             IS 'CED ticket status serial id';
    COMMENT ON COLUMN reports.ced_tickets_status.ct_id              IS 'CED Ticket id FK';
    COMMENT ON COLUMN reports.ced_tickets_status.us_id              IS 'User id FK';
    COMMENT ON COLUMN reports.ced_tickets_status.cts_fulldate       IS 'CED ticket status fulldate';
    COMMENT ON COLUMN reports.ced_tickets_status.cts_status         IS 'CED Ticket status';
    COMMENT ON COLUMN reports.ced_tickets_status.gr_id              IS 'Group to which the ticket was assigned (FK)';
    COMMENT ON COLUMN reports.ced_tickets_status.ctt_id             IS 'CED ticket status type id FK';
    COMMENT ON COLUMN reports.ced_tickets_status.ctu_id             IS 'CED ticket status urgency id FK';
    COMMENT ON COLUMN reports.ced_tickets_status.cts_description    IS 'CED ticket status description';


    -- Tabella che contiene le informazioni relative agli allegati delle tarature
    -- DROP TABLE IF EXISTS reports.ced_tickets_status_attachments;
    CREATE TABLE reports.ced_tickets_status_attachments
    (
        att_id              serial,
        cts_id              integer NOT NULL,
        file_original       text NOT NULL,
        file_archive        text NOT NULL,
        file_image          boolean DEFAULT false,
        att_fulldate        timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT reports_ced_tickets_status_attachments_pkey PRIMARY KEY (att_id),
        CONSTRAINT reports_ced_tickets_status_attachments_ukey UNIQUE (cts_id, file_archive),
        CONSTRAINT reports_ced_tickets_status_attachments_fk1 FOREIGN KEY (cts_id)
            REFERENCES reports.ced_tickets_status (cts_id) MATCH SIMPLE
            ON UPDATE CASCADE
            ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.ced_tickets_status_attachments TO group_admin;
    GRANT ALL ON TABLE    reports.ced_tickets_status_attachments TO group_bobo;
    GRANT ALL ON TABLE    reports.ced_tickets_status_attachments TO group_tools;
    GRANT SELECT ON TABLE reports.ced_tickets_status_attachments TO group_readonly;

    GRANT ALL ON SEQUENCE reports.ced_tickets_status_attachments_att_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.ced_tickets_status_attachments_att_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.ced_tickets_status_attachments_att_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.ced_tickets_status_attachments               IS 'Table storing calibrations attachments';
    COMMENT ON COLUMN reports.ced_tickets_status_attachments.att_id        IS 'Attacchment ID (PK)';
    COMMENT ON COLUMN reports.ced_tickets_status_attachments.cts_id        IS 'CED ticket status ID (FK)';
    COMMENT ON COLUMN reports.ced_tickets_status_attachments.file_original IS 'Original file name';
    COMMENT ON COLUMN reports.ced_tickets_status_attachments.file_archive  IS 'Archive file name';
    COMMENT ON COLUMN reports.ced_tickets_status_attachments.file_image    IS 'Flag if file is an image';
    COMMENT ON COLUMN reports.ced_tickets_status_attachments.att_fulldate  IS 'Attachment insert fulldate';


    CREATE OR REPLACE FUNCTION reports.f_ced_tickets_notifications()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$
        DECLARE
            -- static
            ctp_grid integer := 125;
            ced_grid integer := 126;
            bot      text := '-123456789'; -- Resp. Ticket

            /* email addresses */
            c   text; -- creator email
            ctp text; -- ctp emails
            ced text; -- ced maintainer emails

            /* ticket metadata */
            n text; -- user name
            p text; -- ticket priority
            t text; -- ticket type
            d text; -- description

            /* email variables */
            r text; -- total recipients
            s text; -- subject
            b text; -- body

        BEGIN
        /**
         * Trigger that creates html content to be sent via email or telegram
         * to interested recipients. The trigger fires when a new status of the ticket is inserted
         * and the recipients change depending on the new status itself:
         *
         * > 'open': send email and telegram message to the ticket recipient
         * > 'reassign': send email to the ticket creator and new recipients
         * > 'taken charge': send email to the ticket creator and the CTP
         * > 'closed': send email to ticket creator and CTP
         */

        RAISE NOTICE 'SELECT reports.f_ced_tickets_notifications';

        -- RAISE NOTICE '> Get creator email';
        SELECT us_email INTO c
        FROM bobo.users
        WHERE
            us_id IN ( SELECT us_id FROM reports.ced_tickets WHERE ct_id = NEW.ct_id );

        -- RAISE NOTICE '> Get CTP emails';
        SELECT
            STRING_AGG(us_email, ';' ) INTO ctp
        FROM
            bobo.users
            LEFT JOIN bobo.user_groups USING (us_id)
        WHERE
            gr_id = ctp_grid;

        -- RAISE NOTICE '> Get CED maintainers emails';
        SELECT
            STRING_AGG(us_email, ';' ) INTO ced
        FROM
            bobo.users
            LEFT JOIN bobo.user_groups USING (us_id)
        WHERE
            gr_id = ced_grid;

        /* Get metadata for email's body */
        SELECT
            CONCAT_WS(' ',
                us_name,
                us_2nd_name,
                us_surname,
                ( CASE WHEN comp_id NOTNULL AND comp_id > 1 THEN '('||comp_name||')' ELSE NULL END )
            ) INTO n
        FROM
            bobo.users
            LEFT JOIN bobo.users_metadata USING (us_id)
            LEFT JOIN bobo.companies USING (comp_id)
        WHERE
            us_id = NEW.us_id;

        SELECT ctu_name INTO p FROM reports.ced_ticket_urgencies WHERE ctu_id = NEW.ctu_id;
        SELECT ctt_name INTO t FROM reports.ced_ticket_types     WHERE ctt_id = NEW.ctt_id;

        /* Get ticket's title and description */
        SELECT
            'Ticket #'||NEW.ct_id||': '||ct_title, ct_description INTO s,d
        FROM
            reports.ced_tickets
        WHERE
            ct_id = NEW.ct_id;

        CASE
            WHEN NEW.cts_status = 'open' THEN

                b = '<p>Gentile Utente,<br>'||E'\n'
                    ||'Una nuova richiesta di assistenza &eacute; pervenuta al sistema di ticketing del centro. Di seguito vengono riportate le informazioni principali:</p>'||E'\n'
                    ||'<p>Ticket: <strong><a href="https://opas.isprambiente.it/plan_centro/'||NEW.ct_id||'" target ="_blank">vedi dettagli &raquo;</a></strong><br>'||E'\n'
                    ||'Priorit&agrave;: <strong>'||p||'</strong><br>'||E'\n'
                    ||'Tipologia: <strong>'||t||'</strong><br>'||E'\n'
                    ||'Operatore: <strong>'||n||'</strong><br>'||E'\n'
                    ||'Contatto: <strong>'||c||'</strong></p>'||E'\n'
                    ||'<p><strong>Descrizione:</strong>'||E'\n'
                    ||'<em>'||d||'</em></p>'||E'\n'
                    ||'<p>Cordiali saluti</p>';

                /* Depending on the recipient of the ticket, use different email addresses */
                IF NEW.gr_id = ctp_grid THEN

                    /* send email message to Resp. Tickets*/
                    INSERT INTO gateways.html_mails
                        (app, recipients, subject, body, logo)
                    VALUES
                        ('OPAS Ticketing',ctp,s,b,'opas');

                    /* send telegram message to Resp. Tickets*/

                    b = 'Gentile Utente,'||E'\n'
                    ||'Una nuova richiesta di assistenza è pervenuta al sistema di ticketing del centro. Di seguito vengono riportate le informazioni principali:'||E'\n'
                    ||''||E'\n'
                    ||'Priorità: <strong>'||p||'</strong>'||E'\n'
                    ||'Tipologia: <strong>'||t||'</strong>'||E'\n'
                    ||'Operatore: <strong>'||n||'</strong>'||E'\n'
                    ||'Contatto: <strong>'||c||'</strong>'||E'\n'
                    ||''||E'\n'
                    ||'<strong>Descrizione:</strong>'||E'\n'
                    ||'<blockquote expandable><em>'||regexp_replace(d, E'<[^>]+>', '', 'gi')||'</em></blockquote>'||E'\n'
                    ||''||E'\n'
                    ||'<a href="https://opas.isprambiente.it/plan_centro/'||NEW.ct_id||'" target ="_blank">Apri il ticket per i dettagli »</a>';


                    INSERT INTO gateways.telegrams
                        (app, chat, telegram_type, parse_mode, message)
                    VALUES
                        ('opas.ticketing', bot, 'Message', 'HTML', b );

                ELSE
                    r = ced;

                    /* send email message to IT maintenance personnel */
                    INSERT INTO gateways.html_mails
                        (app, recipients, subject, body, logo)
                    VALUES
                        ('OPAS Ticketing',r,s,b,'opas');
                END IF;

            WHEN NEW.cts_status = 'reassign' THEN

                IF NEW.gr_id = ctp_grid THEN
                    r = ctp;
                ELSE
                    r = ced;
                END IF;

                /* Email to ticket creator */
                b = ' <p>Gentile Utente,<br>'||E'\n'
                ||'La sua richiesta &eacute; stata riassegnata a un nuovo destinatario. Di seguito vengono riportate le informazioni principali:</p>'||E'\n'
                ||'<p>Ticket: <strong><a href="https://opas.isprambiente.it/plan_centro/'||NEW.ct_id||'" target ="_blank">vedi dettagli &raquo;</a></strong><br>'||E'\n'
                ||'Priorit&agrave;: <strong>'||p||'</strong><br>'||E'\n'
                ||'Tipologia: <strong>'||t||'</strong><br>'||E'\n'
                ||'Operatore: <strong>'||n||'</strong></p>'||E'\n'
                ||'<p><strong>Descrizione:</strong>'||E'\n'
                ||'<em>'||COALESCE(NEW.cts_description, '--')||'</em></p>'||E'\n'
                ||'<p>Cordiali saluti</p>';

                INSERT INTO gateways.html_mails
                    (app, recipients, subject, body, logo)
                VALUES
                    ('OPAS Ticketing',c,s,b,'opas');

                /* Email to new recipient */
                b = ' <p>Gentile Utente,<br>'||E'\n'
                ||'La richiesta &eacute; stata riassegnata al suo gruppo. Di seguito vengono riportate le informazioni principali:</p>'||E'\n'
                ||'<p>Ticket: <strong><a href="https://opas.isprambiente.it/plan_centro/'||NEW.ct_id||'" target ="_blank">vedi dettagli &raquo;</a></strong><br>'||E'\n'
                ||'Priorit&agrave;: <strong>'||p||'</strong><br>'||E'\n'
                ||'Tipologia: <strong>'||t||'</strong><br>'||E'\n'
                ||'Operatore: <strong>'||n||'</strong></p>'||E'\n'
                ||'<p><strong>Descrizione:</strong>'||E'\n'
                ||'<em>'||COALESCE(NEW.cts_description, '--')||'</em></p>'||E'\n'
                ||'<p>Cordiali saluti</p>';

                INSERT INTO gateways.html_mails
                    (app, recipients, subject, body, logo)
                VALUES
                    ('OPAS Ticketing',r,s,b,'opas');

            WHEN NEW.cts_status = 'taken charge' THEN

                b = '<p>Gentile Utente,<br>'||E'\n'
                ||'La richiesta in oggetto &eacute; stata presa in carico</p>'||E'\n'
                ||'<p>Ticket: <strong><a href="https://opas.isprambiente.it/plan_centro/'||NEW.ct_id||'" target ="_blank">vedi dettagli &raquo;</a></strong><br>'||E'\n'
                ||'Priorit&agrave;: <strong>'||p||'</strong><br>'||E'\n'
                ||'Tipologia: <strong>'||t||'</strong><br>'||E'\n'
                ||'Operatore: <strong>'||n||'</strong></p>'||E'\n'
                ||'<p><strong>Descrizione:</strong>'||E'\n'
                ||'<em>'||COALESCE(NEW.cts_description, '--')||'</em></p>'||E'\n'
                ||'<p>Cordiali saluti</p>';

                /* Email to ticket creator */
                INSERT INTO gateways.html_mails
                    (app, recipients, subject, body, logo)
                VALUES
                    ('OPAS Ticketing',c,s,b,'opas');

                IF NEW.gr_id = ced_grid THEN

                    /* Email to CTP users, sent only if the status change is made by the IT maintenance personnel. */
                    INSERT INTO gateways.html_mails
                        (app, recipients, subject, body, logo)
                    VALUES
                        ('OPAS Ticketing',ctp,s,b,'opas');

                END IF;

            WHEN NEW.cts_status = 'closed' THEN

                b = '<p>Gentile Utente,<br>'||E'\n'
                ||'La richiesta in oggetto &eacute; stata chiusa. Di seguito vengono riportate le informazioni principali:</p>'||E'\n'
                ||'<p>Ticket: <strong><a href="https://opas.isprambiente.it/plan_centro/'||NEW.ct_id||'" target ="_blank">vedi dettagli &raquo;</a></strong><br>'||E'\n'
                ||'Operatore: <strong>'||n||'</strong></p>'||E'\n'
                ||'<p><strong>Descrizione:</strong>'||E'\n'
                ||'<em>'||COALESCE(NEW.cts_description, '--')||'</em></p>'||E'\n'
                ||'<p>Cordiali saluti</p>';

                /* Email to ticket creator */
                INSERT INTO gateways.html_mails
                    (app, recipients, subject, body, logo)
                VALUES
                    ('OPAS Ticketing',c,s,b,'opas');

                IF NEW.gr_id = ced_grid THEN

                    /* Email to CTP users, sent only if the status change is made by the IT maintenance personnel. */
                    INSERT INTO gateways.html_mails
                        (app, recipients, subject, body, logo)
                    VALUES
                        ('OPAS Ticketing',ctp,s,b,'opas');

                END IF;

            ELSE
                /*Do nothing*/

        END CASE;

        RETURN NEW;

        /* errors check */
        EXCEPTION WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN reports.f_ced_tickets_notifications(date) : %', SQLERRM ;
            RETURN NEW; /* return value */
    END;


    $BODY$;


    GRANT EXECUTE ON FUNCTION reports.f_ced_tickets_notifications() TO group_admin;
    GRANT EXECUTE ON FUNCTION reports.f_ced_tickets_notifications() TO group_bobo;
    GRANT EXECUTE ON FUNCTION reports.f_ced_tickets_notifications() TO group_tools;

    COMMENT ON FUNCTION reports.f_ced_tickets_notifications() IS 'Trigger that takes care of sending emails or telegram messages when any change occurs on ced tickets status';

    CREATE TRIGGER reports_ced_tickets_send_notifications_ai
        AFTER INSERT
        ON reports.ced_tickets_status FOR EACH ROW EXECUTE PROCEDURE reports.f_ced_tickets_notifications();

-- -----------------------------------------------------------------
-- Add column for taking care of updates of stations metadata
-- -----------------------------------------------------------------
	ALTER TABLE metadata.stations_info 
		ADD COLUMN st_info_obj jsonb DEFAULT '{}'::jsonb;
    COMMENT ON COLUMN metadata.stations_info.st_info_obj IS 'Station object: refresh_dependents (TRUE to refresh all products after an update of metadata).';

-- -----------------------------------------------------------------
-- Add column for new section Media 
-- -----------------------------------------------------------------
	ALTER TABLE metadata.stations_network_type
		ADD COLUMN st_network_basepath text;

	COMMENT ON COLUMN metadata.stations_network_type.st_network_basepath IS 'Network basepath for media';

	-- UPDATE EXISTING NETWORKS
	UPDATE metadata.stations_network_type SET st_network_basepath = 'media/rete1' 		WHERE st_network_id =  1;

	-- UPDATE EXISTING STATION
	UPDATE metadata.stations_info si
	SET st_info_basepath = (
		SELECT st_network_basepath
		FROM metadata.stations_network_type
		WHERE st_network_id = si.st_info_network_type_fk
	)
	WHERE
		st_info_roaming_type_fk NOT IN (0, 4);

-- -----------------------------------------------------------------
-- Bug fixing 
-- -----------------------------------------------------------------
	
-- Views
	DROP VIEW IF EXISTS webservice.v1_series;
    CREATE OR REPLACE VIEW webservice.v1_series AS
    SELECT 
        sp.stpr_id          AS series_id,
        concat_ws(' - '::text, pp.param_name, sp.stpr_note) AS series_name,
        sp.stpr_table_id    AS database_id,
        st.station_id,
        st.station_ext_id   AS station_external_id,
        st.station_name,
        st.station_active,
        pp.param_id         AS parameter_id,
        pp.param_name       AS parameter_name,
        pp.param_active     AS parameter_active,
        pp.param_unit       AS parameter_unit,
        metadata.f_get_conversion_by_date_prid(pp.param_id, CURRENT_TIMESTAMP::timestamp without time zone) AS parameter_conv_curr,
        (   SELECT 
                to_json(array_agg(row_to_json(j.*))) AS to_json
            FROM ( 
                SELECT  
                    row_number() OVER (ORDER BY pc.pc_from_fulldate) AS index,
                    pc.pc_conv          AS value,
                    pc.pc_from_fulldate AS date_from,
                    pc.pc_to_fulldate   AS date_to
                FROM metadata.parameters_conversions pc
                WHERE pp.param_id = pc.param_id
                ORDER BY pc.pc_from_fulldate
            ) j
        )                       AS parameter_conv_history,
        pp.param_unit_conv      AS parameter_conv_unit,
        pp.param_decimals       AS parameter_decimals,
        pt.pm_type_desc         AS parameter_type_desc,
        pp.param_note           AS parameter_note,
        mc.measure_cadence_desc AS parameter_cadence_type_desc,
        mc.measure_cadence_min  AS parameter_cadence_type_min,
        sp.stpr_ext_id          AS series_external_id,
        spi.stpr_export_id1     AS series_export_id1,
        spi.stpr_export_id2     AS series_export_id2,
        spi.stpr_info_ws_id     AS series_ws_id,
        sp.stpr_active          AS series_active,
        sp.stpr_note            AS series_note,
        r.region_istat_code,
        r.region_name,
        sp.stpr_active          AS station_param_active,
        sp.stpr_note            AS station_param_note
    FROM 
        metadata.stations st
        LEFT JOIN metadata.stations_municipality stm USING (station_id)
        LEFT JOIN metadata.stations_info sm USING (station_id)
        LEFT JOIN main.province_municipalities prm USING (mu_id)
        LEFT JOIN main.region_provinces rp USING (province_id)
        LEFT JOIN main.regions r USING (region_id)
        LEFT JOIN metadata.stations_parameters sp USING (station_id)
        LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
        LEFT JOIN metadata.parameters pp USING (param_id)
        LEFT JOIN metadata.parameters_info pm USING (param_id)
        LEFT JOIN metadata.parameters_type pt ON pm.pm_info_type_fk = pt.pm_type_id
        LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = COALESCE(spi.stpr_info_cadence_fk, sm.st_info_cadence_fk)
    ORDER BY st.station_id, sp.stpr_table_id;

    COMMENT ON VIEW webservice.v1_series IS '[BOBO] The view contains all the principal info, used by the web service, about data series';

    GRANT ALL ON TABLE webservice.v1_series TO group_admin;
    GRANT ALL ON TABLE webservice.v1_series TO group_tools;

-- Functions

	DROP FUNCTION IF EXISTS metadata.f_get_parameters_from_station_config_v3(jsonb);
	CREATE OR REPLACE FUNCTION metadata.f_get_parameters_from_station_config_v3(
		config jsonb)
	    RETURNS jsonb
	    LANGUAGE 'plpgsql'
	    COST 100
	    VOLATILE PARALLEL UNSAFE
	AS $BODY$
	    DECLARE
	        mo jsonb; -- config module object
	        co jsonb; -- config channel object

	        d boolean; -- daily module
	        i integer; -- parameter id
	        n text; -- parameter name
	        u text; -- parameter unit
	        s text; -- station - parameter note / name suffix

	        po jsonb; -- partial parameter object
	        cc jsonb; -- cc result object
	        ro jsonb; -- result object

	    BEGIN

	        /**
	         * Given the station configuration as argument, the function parses the json
	         * Specifically, for each ACTIVE module, all linked channels are analysed
	         * > If active then an object containing the parameter data (DatabaseID, Name, Unit ...) is created
	         * > otherwise they are ignored
	         *
	         * To retrieve pollutant information, firstly the function checks whether the ParameterId is supplied. Otherwise the function relies on a support table (vocabulary)
	         * with which a mapping is performed between the name of the parameter set in the periphery and the relative ID in the center (param_id)
	         *
	         * The function takes into account the various types of channels (standard, diagnostic or alarms) and
	         * takes care of adding any CC parameters
	         *
	         * Returns an array of objects or NULL.
	         *
	         * TEST SELECT * FROM metadata.f_get_parameters_from_station_config_v3('...'::jsonb);
	         */

	        -- RAISE NOTICE 'Jsonb totale: %', jsonb_pretty(config);

	        /* build jsonb container */
	        SELECT jsonb_build_object(
	            'found'     , array_to_json(ARRAY[]::jsonb[]),
	            'not_found' , array_to_json(ARRAY[]::jsonb[]),
	            'not_active', array_to_json(ARRAY[]::jsonb[])
	        ) INTO ro;

	        /* Loop through all modules */
	        FOR mo IN SELECT * FROM jsonb_array_elements((config->>'Modules')::jsonb) LOOP

	            -- RAISE NOTICE 'Module: %', jsonb_pretty(m);
	            RAISE NOTICE 'Module name %', mo->>'Name';

	            /* Check if module is active otherwise continue to next loop */
	            IF NOT (mo->>'Active')::boolean THEN
	                RAISE NOTICE '-- Module not active!';
	                CONTINUE;
	            END IF;

	            /**
	             * Check if it's a daily module
	             * SWAM_5A_DD, SWAM_5A_DD_MONO, SM200, CHEMISTRY_LAB 
	             */
	            IF (mo->>'ModuleType')::integer IN (1401, 1405, 600, 50) THEN
	                RAISE NOTICE 'Daily module!';
	                d := TRUE;
	            ELSE
	                d := FALSE;
	            END IF;

	            /* Loop through all module's channels */
	            FOR co IN SELECT * FROM jsonb_array_elements((mo->>'Channels')::jsonb) LOOP

	                -- RAISE NOTICE '    Channel: %', jsonb_pretty(c);
	                RAISE NOTICE '    > Channel dbId, name: % %', co->>'DatabaseId', co->>'Name';

	                /* Check if channel is active otherwise add it in "not-active" property and continue to next loop */
	                IF NOT (co->>'Active')::boolean THEN
	                    RAISE NOTICE '    > Channel not active!';
	                    /* Initialize a new object for the new parameter */
	                    SELECT
	                        jsonb_build_object(
	                            'module', (mo->>'ID')::integer,
	                            'module_name', mo->>'Name',
	                            'name', co->>'Name',
	                            'id', (co->>'DatabaseId')::integer
	                        ) INTO po;

	                    /* Append new parameter to final result */
	                    SELECT jsonb_set(
	                            ro,
	                            ARRAY['not_active']::text[],
	                            ro->'not_active' || po,
	                            true
	                        ) INTO ro;

	                    CONTINUE;
	                END IF;

	                /* Check if the channel contains ParameterId: new field inserted for the evolution of the dataogge*/
	                IF (co->>'ParameterId')::integer IS NOT NULL AND (co->>'ParameterId')::integer > 0 THEN
	                    RAISE NOTICE '    > ID parameter already present, it is not necessary to execute further searches!';

	                    /* Search for channel name inside the vocabulary table */
	                    SELECT param_id, param_name, param_unit INTO i, n, u
	                    FROM metadata.parameters p
	                    WHERE param_id = (co->>'ParameterId')::integer;

	                    /* Initialize a new object for the new parameter */
	                    SELECT
	                        jsonb_build_object(
	                            'module', (mo->>'ID')::integer,
	                            'module_name', mo->>'Name',
	                            'prid', i,
	                            'name', n,
	                            'note', (co->>'ParameterNote'),
	                            'unit', u,
	                            'id', (co->>'DatabaseId')::integer,
	                            'need-group', (NOT (co->>'Type')::smallint = 2 ),
	                            'daily', d
	                        ) INTO po;

	                    /* Append new parameter to final result */
	                    SELECT jsonb_set(
	                                ro,
	                                ARRAY['found']::text[],
	                                ro->'found' || po,
	                                true
	                            ) INTO ro;

	                    CONTINUE;
	                END IF;

	                /**
	                 * Based on the type of the channel, retrieve the parameter and build the jsonb in a different way
	                 * Standard = 0
	                 * Diagnostic = 1
	                 * Alarm = 2
	                 */

	                /* Stardard type case */
	                CASE (co->>'Type')::smallint
	                    WHEN 0 THEN
	                        -- RAISE NOTICE '        Channel type: Standard';

	                        /* Search for channel name inside the vocabulary table */
	                        SELECT dl_value, param_name, param_unit INTO i, n, u
	                        FROM metadata.dl_vocabulary d
	                        LEFT JOIN metadata.parameters p ON (p.param_id = d.dl_value)
	                        WHERE LOWER(dl_key) LIKE LOWER( co->>'Name' );

	                        /* If parameter does not exist then do nothing, add it in "not-found" property and continue to next loop */
	                        IF NOT FOUND THEN
	                            RAISE NOTICE '    > Parameter not found!';
	                            /* Initialize a new object for the new parameter */
	                            SELECT
	                                jsonb_build_object(
	                                    'module', (mo->>'ID')::integer,
	                                    'module_name', mo->>'Name',
	                                    'name', co->>'Name',
	                                    'id', (co->>'DatabaseId')::integer
	                                ) INTO po;

	                            /* Append new parameter to final result */
	                            SELECT jsonb_set(
	                                    ro,
	                                    ARRAY['not_found']::text[],
	                                    ro->'not_found' || po,
	                                    true
	                                ) INTO ro;
	                            
	                            /* Initialize a new object for the new parameter */
	                            SELECT
	                                jsonb_build_object(
	                                    'module', (mo->>'ID')::integer,
	                                    'module_name', mo->>'Name',
	                                    'prid', 0,
	                                    'name', 'Param. generico',
	                                    'note', co->>'Name',
	                                    'unit', '--',
	                                    'id', (co->>'DatabaseId')::integer,
	                                    'need-group', TRUE,
	                                    'daily', d
	                                ) INTO po;

	                        ELSE
	                            /* Take care of different types of insruments, set info note */
	                            -- s := NULL;
	                            CASE
	                                /**
	                                * PALAS_FIDAS200_PIPE = 1150 ' PALAS Fidas® 200 via pipe file
	                                * PALAS_FIDAS200_MODBUS = 1151 ' PALAS Fidas® 200 via modbus
	                                * PALAS_FIDAS200_ETH = 1152 ' PALAS Fidas® 200 via ethernet
	                                */
	                                WHEN (mo->>'ModuleType')::integer BETWEEN 1150 AND 1152 THEN
	                                    s := 'FIDAS';
	                                -- WHEN (mo->>'ModuleType')::integer BETWEEN XXX AND XXX THEN
	                                --  s := 'XXX';
	                                ELSE
	                                    /* DO nothing */
	                            END CASE;

	                            -- RAISE NOTICE '        ID parametro: %', i;
	                            /* Initialize a new object for the new parameter */
	                            SELECT
	                                jsonb_build_object(
	                                    'module', (mo->>'ID')::integer,
	                                    'module_name', mo->>'Name',
	                                    'prid', i,
	                                    'name', n,
	                                    'note', s,
	                                    'unit', u,
	                                    'id', (co->>'DatabaseId')::integer,
	                                    'need-group', TRUE,
	                                    'daily', d
	                                ) INTO po;

	                        END IF;

	                        /* Append new parameter to final result */
	                        -- SELECT ro->'found' || po INTO ro;
	                        SELECT jsonb_set(
	                                ro,
	                                ARRAY['found']::text[],
	                                ro->'found' || po,
	                                true
	                            ) INTO ro;

	                    WHEN 1 THEN
	                        -- RAISE NOTICE '        Channel type: Diagnostic';

	                        /* Search for channel databaseID inside the vocabulary table */
	                        SELECT dl_value, param_name, param_unit INTO i, n, u
	                        FROM metadata.dl_vocabulary d
	                        LEFT JOIN metadata.parameters p ON (p.param_id = d.dl_value)
	                        WHERE (co->>'DatabaseId')::text ~ dl_key::text ;

	                        /* If parameter does not exist then do nothing and continue to next loop */
	                        IF NOT FOUND THEN
	                            /* Search for channel name inside the vocabulary table */
	                            SELECT dl_value, param_name, param_unit INTO i, n, u
	                            FROM metadata.dl_vocabulary d
	                            LEFT JOIN metadata.parameters p ON (p.param_id = d.dl_value)
	                            WHERE LOWER(dl_key) LIKE LOWER( co->>'Name' );

	                            /* If parameter does not exist then do nothing, add it in "not-found" property and continue to next loop */
	                            IF NOT FOUND THEN
	                                RAISE NOTICE '    > Parameter not found!';
	                                /* Initialize a new object for the new parameter */
	                                SELECT
	                                    jsonb_build_object(
	                                        'module', (mo->>'ID')::integer,
	                                        'module_name', mo->>'Name',
	                                        'name', co->>'Name',
	                                        'id', (co->>'DatabaseId')::integer
	                                    ) INTO po;

	                                /* Append new parameter to final result */
	                                SELECT jsonb_set(
	                                        ro,
	                                        ARRAY['not_found']::text[],
	                                        ro->'not_found' || po,
	                                        true
	                                    ) INTO ro;
	                                
	                                SELECT
	                                    jsonb_build_object(
	                                        'module', (mo->>'ID')::integer,
	                                        'module_name', mo->>'Name',
	                                        'prid', 0,
	                                        'name', 'Param. generico',
	                                        'note', co->>'Name',
	                                        'unit', '--',
	                                        'id', (co->>'DatabaseId')::integer,
	                                        'need-group', TRUE,
	                                        'daily', d
	                                    ) INTO po;
										
	                            ELSE 

	                                /* Take care of swam, set correct line type in info note */
	                                s := NULL;
	                                CASE
	                                    WHEN (co->>'DatabaseId')::integer BETWEEN 5000 AND 5031 THEN
	                                        s := 'Linea A';
	                                    WHEN (co->>'DatabaseId')::integer BETWEEN 5050 AND 5081 THEN
	                                        s := 'Linea B';
	                                    WHEN (co->>'DatabaseId')::integer BETWEEN 5100 AND 5131 THEN
	                                        s := 'Linea C';
	                                    ELSE
	                                        /* DO nothing */
	                                END CASE;

	                                -- RAISE NOTICE '        ID parametro: %', i;
	                                /* Initialize a new object for the new parameter */
	                                SELECT
	                                    jsonb_build_object(
	                                        'module', (mo->>'ID')::integer,
	                                        'module_name', mo->>'Name',
	                                        'prid', i,
	                                        'name', n,
	                                        'note', s,
	                                        'unit', u,
	                                        'id', (co->>'DatabaseId')::integer,
	                                        'need-group', TRUE,
	                                        'daily', d
	                                    ) INTO po;
								END IF;
	                        
	                        ELSE
	                            /* Take care of swam, set correct line type in info note */
	                            s := NULL;
	                            CASE
	                                WHEN (co->>'DatabaseId')::integer BETWEEN 5000 AND 5031 THEN
	                                    s := 'Linea A';
	                                WHEN (co->>'DatabaseId')::integer BETWEEN 5050 AND 5081 THEN
	                                    s := 'Linea B';
	                                WHEN (co->>'DatabaseId')::integer BETWEEN 5100 AND 5131 THEN
	                                    s := 'Linea C';
	                                ELSE
	                                    /* DO nothing */
	                            END CASE;

	                            -- RAISE NOTICE '        ID parametro: %', i;
	                            /* Initialize a new object for the new parameter */
	                            SELECT
	                                jsonb_build_object(
	                                    'module', (mo->>'ID')::integer,
	                                    'module_name', mo->>'Name',
	                                    'prid', i,
	                                    'name', n,
	                                    'note', s,
	                                    'unit', u,
	                                    'id', (co->>'DatabaseId')::integer,
	                                    'need-group', TRUE,
	                                    'daily', d
	                                ) INTO po;

	                        END IF;

	                        -- RAISE NOTICE 'Jsonb parametro: %', jsonb_pretty(po);

	                        /* Append new parameter to final result */
	                        -- SELECT ro || po INTO ro;
	                        SELECT jsonb_set(
	                                ro,
	                                ARRAY['found']::text[],
	                                ro->'found' || po,
	                                true
	                            ) INTO ro;

	                    /* Alarm parameter */
	                    WHEN 2 THEN
	                        -- RAISE NOTICE '        Channel type: Alarm';

	                        /* Search for channel name inside the vocabulary table */
	                        SELECT dl_value, param_name, param_unit INTO i, n, u
	                        FROM metadata.dl_vocabulary d
	                        LEFT JOIN metadata.parameters p ON (p.param_id = d.dl_value)
	                        WHERE LOWER(dl_key) LIKE LOWER( co->>'Name' );

	                        /* If parameter does not exist then do nothing, add it in "not-found" property and continue to next loop */
	                        IF NOT FOUND THEN
	                            RAISE NOTICE '    > Parameter not found!';
	                            /* Initialize a new object for the new parameter */
	                            SELECT
	                                jsonb_build_object(
	                                    'module', (mo->>'ID')::integer,
	                                    'module_name', mo->>'Name',
	                                    'name', co->>'Name',
	                                    'id', (co->>'DatabaseId')::integer
	                                ) INTO po;

	                            /* Append new parameter to final result */
	                            SELECT jsonb_set(
	                                    ro,
	                                    ARRAY['not_found']::text[],
	                                    ro->'not_found' || po,
	                                    true
	                                ) INTO ro;
	                            
	                            SELECT
	                                jsonb_build_object(
	                                    'module', (mo->>'ID')::integer,
	                                    'module_name', mo->>'Name',
	                                    'prid', 0,
	                                    'name', 'Param. generico',
	                                    'note', co->>'Name',
	                                    'unit', '--',
	                                    'id', (co->>'DatabaseId')::integer,
	                                    'need-group', FALSE,
	                                    'daily', d
	                                ) INTO po;
	                        
	                        ELSE
	                            -- RAISE NOTICE '        ID parametro: %', i;
	                            /* Initialize a new object for the new parameter */
	                            SELECT
	                                jsonb_build_object(
	                                    'module', (mo->>'ID')::integer,
	                                    'module_name', mo->>'Name',
	                                    'prid', i,
	                                    'name', n,
	                                    'unit', u,
	                                    'id', (co->>'DatabaseId')::integer,
	                                    'need-group', FALSE,
	                                    'daily', FALSE
	                                ) INTO po;
	                        
	                        END IF;

	                        /* Append new parameter to final result */
	                        -- SELECT ro || po INTO ro;
	                        SELECT jsonb_set(
	                                ro,
	                                ARRAY['found']::text[],
	                                ro->'found' || po,
	                                true
	                            ) INTO ro;

	                     ELSE
	                        /* Do nothing */
	                        RAISE NOTICE '        Channel type % does not exist', co->>'Type';
	                        CONTINUE;

	                END CASE;

	            /* END channels loop */
	            END LOOP;

	            /* Take care of CC parameters based on module type*/
	            RAISE NOTICE 'Looking for CC...';
	            -- SELECT ro || metadata.f_get_cc_from_station_config( mo ) INTO ro;
	            SELECT metadata.f_get_cc_from_station_config( mo ) INTO cc;
	            IF( jsonb_array_length(cc) > 0 ) THEN
	                SELECT jsonb_set(
	                            ro,
	                            ARRAY['found']::text[],
	                            ro->'found' || metadata.f_get_cc_from_station_config( mo ),
	                            true
	                        ) INTO ro;
	            END IF;

	        /* END modules loop */
	        END LOOP;

	        -- RAISE NOTICE 'Jsonb totale: %', jsonb_pretty(ro);

	        RETURN ro;

	        /* errors check */
	        EXCEPTION
	        WHEN OTHERS THEN /* in case of any error */
	            RAISE NOTICE 'ERROR IN metadata.f_get_parameters_from_station_config_v3(jsonb) : %', SQLERRM ;
	            RETURN NULL;
	    END;

	    
	$BODY$;

	GRANT EXECUTE ON FUNCTION metadata.f_get_parameters_from_station_config_v3(jsonb) TO group_admin;
	GRANT EXECUTE ON FUNCTION metadata.f_get_parameters_from_station_config_v3(jsonb) TO group_bobo;
	GRANT EXECUTE ON FUNCTION metadata.f_get_parameters_from_station_config_v3(jsonb) TO group_tools;

	COMMENT ON FUNCTION metadata.f_get_parameters_from_station_config_v3(jsonb)
	    IS '[BOBO] Function that returns an object with all parameters and their ids retrieved from station configuration file';

	DROP FUNCTION IF EXISTS metadata.f_get_cc_from_station_config(jsonb);
	CREATE OR REPLACE FUNCTION metadata.f_get_cc_from_station_config(
		mo jsonb)
	    RETURNS jsonb
	    LANGUAGE 'plpgsql'
	    COST 100
	    VOLATILE PARALLEL UNSAFE
	AS $BODY$
	    DECLARE
	        co jsonb;   -- channel object
	        q   text;   -- dynamic query
	        rec record; -- query results

	        cc jsonb;

	    BEGIN

	        /**
	         * Support function for the metadata.f_get_parameters_from_station_config
	         * Given the object of a module as input, the function returns an array of objects containing the list of CC parameters
	         *
	         * TEST SELECT metadata.f_get_cc_from_station_config('...'::jsonb);
	         */
	        cc := array_to_json(ARRAY[]::jsonb[]);

	        CASE
	            /* SO2  */
	            WHEN (mo->>'ModuleType')::integer IN (100, 415, 852, 860, 867, 1230, 1231, 1522 )  THEN
	                /** so2
	                 * param_id, stpr_table_id 519, 4023  'SO2 Zero'
	                 * param_id, stpr_table_id 520, 4024  'SO2 Span trovato'
	                 * param_id, stpr_table_id 522, 4026  'SO2 Span deriva'
	                 */
	                q := 'SELECT
	                        param_id,
	                        param_name,
	                        param_unit,
	                        CASE param_id
	                            WHEN 519 THEN 4023
	                            WHEN 520 THEN 4024
	                            WHEN 522 THEN 4026
	                            ELSE NULL
	                        END AS table_id
	                    FROM
	                        metadata.parameters
	                    WHERE
	                        param_id IN (519, 520, 522)
	                    ORDER BY param_id;';

	            /* H2S  */
	            WHEN (mo->>'ModuleType')::integer IN ( 416 )  THEN
	                /** h2s
	                 * param_id, stpr_table_id 1199,      'H2S Zero'
	                 * param_id, stpr_table_id 1202,      'H2S Span trovato'
	                 * param_id, stpr_table_id 1204,      'H2S Span deriva'
	                 */
	                q := 'SELECT
	                        param_id,
	                        param_name,
	                        param_unit,
	                        CASE param_id
	                            WHEN 1199 THEN 4050
	                            WHEN 1202 THEN 4051
	                            WHEN 1204 THEN 4053
	                            ELSE NULL
	                        END AS table_id
	                    FROM
	                        metadata.parameters
	                    WHERE
	                        param_id IN (1199, 1202, 1204)
	                    ORDER BY param_id;';

	            /* SO2 + H2S  */
	            WHEN (mo->>'ModuleType')::integer IN ( 101, 417, 1240, 1243 )  THEN
	                /** so2 + h2s
	                 * param_id, stpr_table_id  519, 4023 'SO2 Zero'
	                 * param_id, stpr_table_id  520, 4024 'SO2 Span trovato'
	                 * param_id, stpr_table_id  522, 4026 'SO2 Span deriva'
	                 * param_id, stpr_table_id 1199, 4050 'H2S Zero'
	                 * param_id, stpr_table_id 1202, 4051 'H2S Span trovato'
	                 * param_id, stpr_table_id 1204, 4053 'H2S Span deriva'
	                 */
	                q := 'SELECT
	                        param_id,
	                        param_name,
	                        param_unit,
	                        CASE param_id
	                            WHEN  519 THEN 4023
	                            WHEN  520 THEN 4024
	                            WHEN  522 THEN 4026
	                            WHEN 1199 THEN 4050
	                            WHEN 1202 THEN 4051
	                            WHEN 1204 THEN 4053
	                            ELSE NULL
	                        END AS table_id
	                    FROM
	                        metadata.parameters
	                    WHERE
	                        param_id IN (519, 520, 522, 1199, 1202, 1204)
	                    ORDER BY param_id;';

	            /* NOX-NO-NO2 */
	            WHEN (mo->>'ModuleType')::integer IN ( 200, 201, 420, 850, 861, 866, 1200, 1201, 1241, 1532 ) THEN
	                /** nox + hn3
	                 * 496, 4000 NOx Zero
	                 * 497, 4001 NO Zero
	                 * 498, 4002 NO2 Zero
	                 * 499, 4003 NOx Span trovato
	                 * 501, 4005 NOx Span deriva
	                 * 502, 4006 NO Span trovato
	                 * 504, 4008 NO Span deriva
	                 * 505, 4009 NO2 Span trovato
	                 */
	                q := 'SELECT
	                        param_id,
	                        param_name,
	                        param_unit,
	                        CASE param_id
	                            WHEN 496 THEN 4000
	                            WHEN 497 THEN 4001
	                            WHEN 498 THEN 4002
	                            WHEN 499 THEN 4003
	                            WHEN 501 THEN 4005
	                            WHEN 502 THEN 4006
	                            WHEN 504 THEN 4008
	                            WHEN 505 THEN 4009
	                            ELSE NULL
	                        END AS table_id
	                    FROM
	                        metadata.parameters
	                    WHERE
	                        param_id IN (496,497,498,499,501,502,504,505)
	                    ORDER BY param_id;';

	            /* O3 */
	            WHEN (mo->>'ModuleType')::integer IN (400, 410, 851, 862, 864, 1210, 1211, 1542 ) THEN
	                /**  o3
	                 * 509, 4013 O3 Zero
	                 * 510, 4014 O3 Span trovato
	                 * 512, 4016 O3 Span deriva
	                 */
	                q := 'SELECT
	                        param_id,
	                        param_name,
	                        param_unit,
	                        CASE param_id
	                            WHEN 509 THEN 4013
	                            WHEN 510 THEN 4014
	                            WHEN 512 THEN 4016
	                            ELSE NULL
	                        END AS table_id
	                    FROM
	                        metadata.parameters
	                    WHERE
	                        param_id IN (509,510,512)
	                    ORDER BY param_id;';

	            /* CO */
	            WHEN (mo->>'ModuleType')::integer IN (300, 425, 853, 863, 865, 1220, 1221, 1512 ) THEN
	                /** co
	                 * 514, 4018 CO Zero
	                 * 515, 4019 CO Span trovato
	                 * 517, 4021 CO Span deriva
	                 */
	                q := 'SELECT
	                        param_id,
	                        param_name,
	                        param_unit,
	                        CASE param_id
	                            WHEN 514 THEN 4018
	                            WHEN 515 THEN 4019
	                            WHEN 517 THEN 4021
	                            ELSE NULL
	                        END AS table_id
	                    FROM
	                        metadata.parameters
	                    WHERE
	                        param_id IN (514,515,517)
	                    ORDER BY param_id;';

	            /* BTX */
	            WHEN (mo->>'ModuleType')::integer IN (800, 804, 805, 806, 807, 808, 809 ) THEN

	                /* Loop through all module's channels */
	                FOR co IN SELECT * FROM jsonb_array_elements((mo->>'Channels')::jsonb) LOOP

	                    IF co->>'Name' ~ 'Benzene' THEN
	                        /**
	                         * 524, 4028 Ben Zero
	                         * 527, 4031 Ben Span trovato
	                         * 529, 4033 Ben Span deriva
	                         */
	                        q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 524 THEN 4028
	                                    WHEN 527 THEN 4031
	                                    WHEN 529 THEN 4033
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (524,527,529)
	                            ORDER BY param_id;';

	                    ELSIF co->>'Name' ~ 'Toluene' THEN
	                        /**
	                         * 525, 4029 Tol Zero
	                         * 530, 4034 Tol Span trovato
	                         * 532, 4036 Tol Span deriva
	                         */
	                         q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 525 THEN 4029
	                                    WHEN 530 THEN 4034
	                                    WHEN 532 THEN 4036
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (525,530,532)
	                            ORDER BY param_id;';

	                    ELSIF co->>'Name' IN ('Ethilbenzene', 'Ethylbenzene') THEN
	                        /**
	                         * 548, 4041 Ethylbenzene Span trovato
	                         * 549, 4042 Ethylbenzene Span deriva
	                         */
	                         q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 548 THEN 4041
	                                    WHEN 549 THEN 4042
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (548,549)
	                            ORDER BY param_id;';

	                    ELSIF co->>'Name' IN ('M+P-Xilene', 'M&p-hxylene') THEN
	                        /**
	                         * 552, 4045 M&P-xylene Span trovato
	                         * 553, 4046 M&P-xylene Span deriva
	                         */
	                         q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 552 THEN 4045
	                                    WHEN 553 THEN 4046
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (552,553)
	                            ORDER BY param_id;';

	                    ELSIF co->>'Name' IN ('O-Xilene', 'O-xylene') THEN
	                        /**
	                         * 550, 4043 O-xylene Span trovato
	                         * 551, 4044 O-xylene Span deriva
	                         */
	                         q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 550 THEN 4043
	                                    WHEN 551 THEN 4044
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (550,551)
	                            ORDER BY param_id;';
	                    ELSE
	                        /* Do nothing*/
	                    END IF;

	                    FOR rec IN
	                        EXECUTE q
	                    LOOP

	                        SELECT cc ||
	                            jsonb_build_object(
	                                'module', (mo->>'ID')::integer,
	                                'module_name', mo->>'Name',
	                                'prid', rec.param_id,
	                                'name', rec.param_name,
	                                'unit', rec.param_unit,
	                                'id', rec.table_id,
	                                'need-group', TRUE,
	                                'daily', FALSE
	                            ) INTO cc;
	                    END LOOP;

	                /* END channels loop */
	                END LOOP;

	                /* Reset variable in order to skip last part of instructions */
	                q := NULL;

	            /* !! ANALOGICI !! */
	            /* ADAM_4017, ADAM_5017, ADAM_TCP_5017 */
	            WHEN (mo->>'ModuleType')::integer IN (3150, 4017, 5017, 5117) THEN
	                /* Loop through all module's channels */
	                FOR co IN SELECT * FROM jsonb_array_elements((mo->>'Channels')::jsonb) LOOP

	                    IF co->>'Name' ~ 'SO2' THEN
	                        /** so2
	                         * param_id, stpr_table_id 519, 4023  'SO2 Zero'
	                         * param_id, stpr_table_id 520, 4024  'SO2 Span trovato'
	                         * param_id, stpr_table_id 522, 4026  'SO2 Span deriva'
	                         */
	                        q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 519 THEN 4023
	                                    WHEN 520 THEN 4024
	                                    WHEN 522 THEN 4026
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (519, 520, 522)
	                            ORDER BY param_id;';

	                    ELSIF co->>'Name' ~ 'NOx' THEN
	                        /** nox + hn3
	                         * 496, 4000 NOx Zero
	                         * 499, 4003 NOx Span trovato
	                         * 501, 4005 NOx Span deriva
	                         */
	                        q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 496 THEN 4000
	                                    WHEN 499 THEN 4003
	                                    WHEN 501 THEN 4005
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (496,499,501)
	                            ORDER BY param_id;';

	                    ELSIF co->>'Name' ~ 'NO2' THEN
	                        /** nox + hn3
	                         * 498, 4002 NO2 Zero
	                         * 505, 4009 NO2 Span trovato
	                         */
	                        q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 498 THEN 4002
	                                    WHEN 505 THEN 4009
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (498,505)
	                            ORDER BY param_id;';

	                    ELSIF co->>'Name' ~ 'NO' THEN
	                        /** nox + hn3
	                         * 497, 4001 NO Zero
	                         * 502, 4006 NO Span trovato
	                         * 504, 4008 NO Span deriva
	                         */
	                        q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 497 THEN 4001
	                                    WHEN 502 THEN 4006
	                                    WHEN 504 THEN 4008
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (497,502,504)
	                            ORDER BY param_id;';

	                    ELSIF co->>'Name' ~ 'O3' THEN
	                        /**  o3
	                         * 509, 4013 O3 Zero
	                         * 510, 4014 O3 Span trovato
	                         * 512, 4016 O3 Span deriva
	                         */
	                        q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 509 THEN 4013
	                                    WHEN 510 THEN 4014
	                                    WHEN 512 THEN 4016
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (509,510,512)
	                            ORDER BY param_id;';

	                    ELSIF co->>'Name' ~ 'CO' THEN
	                        /** co
	                         * 514, 4018 CO Zero
	                         * 515, 4019 CO Span trovato
	                         * 517, 4021 CO Span deriva
	                         */
	                        q := 'SELECT
	                                param_id,
	                                param_name,
	                                param_unit,
	                                CASE param_id
	                                    WHEN 514 THEN 4018
	                                    WHEN 515 THEN 4019
	                                    WHEN 517 THEN 4021
	                                    ELSE NULL
	                                END AS table_id
	                            FROM
	                                metadata.parameters
	                            WHERE
	                                param_id IN (514,515,517)
	                            ORDER BY param_id;';

	                    ELSE
	                        /* Do nothing*/
	                    END IF;

	                    IF q IS NOT NULL THEN
	                        FOR rec IN
	                            EXECUTE q
	                        LOOP

	                            SELECT cc ||
	                                jsonb_build_object(
	                                    'module', (mo->>'ID')::integer,
	                                    'module_name', mo->>'Name',
	                                    'prid', rec.param_id,
	                                    'name', rec.param_name,
	                                    'unit', rec.param_unit,
	                                    'id', rec.table_id,
	                                    'need-group', TRUE,
	                                    'daily', FALSE
	                                ) INTO cc;
	                        END LOOP;
	                        
	                    END IF;

	                /* END channels loop */
	                END LOOP;

	                /* Reset variable in order to skip last part of instructions */
	                q := NULL;

	            ELSE
	                /* Do nothing */
	        END CASE;

	        IF q IS NOT NULL THEN
	            RAISE NOTICE 'CC found!';
	            FOR rec IN
	                EXECUTE q
	            LOOP

	                SELECT cc ||
	                    jsonb_build_object(
	                        'module', (mo->>'ID')::integer,
	                        'module_name', mo->>'Name',
	                        'prid', rec.param_id,
	                        'name', rec.param_name,
	                        'unit', rec.param_unit,
	                        'id', rec.table_id,
	                        'need-group', TRUE,
	                        'daily', FALSE
	                    ) INTO cc;
	            END LOOP;
	        ELSE
	            /* Do nothing */
	        END IF;

	        RETURN cc;

	        /* errors check */
	        EXCEPTION
	        WHEN OTHERS THEN /* in case of any error */
	            RAISE NOTICE 'ERROR IN metadata.f_get_cc_from_station_config(jsonb) : %', SQLERRM ;
	            RETURN NULL;
	    END;

	    
	$BODY$;

	GRANT EXECUTE ON FUNCTION metadata.f_get_cc_from_station_config(jsonb) TO group_admin;
	GRANT EXECUTE ON FUNCTION metadata.f_get_cc_from_station_config(jsonb) TO group_bobo;
	GRANT EXECUTE ON FUNCTION metadata.f_get_cc_from_station_config(jsonb) TO group_tools;

	COMMENT ON FUNCTION metadata.f_get_cc_from_station_config(jsonb)
	    IS '[BOBO] Function that returns an object with all CC parameters and their ids retrieved from module of station configuration file';


	DROP FUNCTION IF EXISTS template.f_create_opas_tables(integer);
	CREATE OR REPLACE FUNCTION template.f_create_opas_tables(
		stid integer)
	    RETURNS boolean
	    LANGUAGE 'plpgsql'
	    COST 100
	    VOLATILE SECURITY DEFINER PARALLEL UNSAFE
	AS $BODY$
	DECLARE
	    -- variables
	    s text; -- schema
	    t text; -- table
	    q text; -- query

	    r boolean; -- result

	BEGIN
	    /**
	     * The function takes care of creating the tables and triggers of a new station. The function is
	     * executed by the portal when user is inserting a new station
	     *
	     * The function is launched from the portal and is executed with the owner role (user_admin).
	     */

	    /* Select schema and table name */
	    SELECT station_schema, station_table INTO s,t
	    FROM metadata.stations
	    WHERE station_id = stid;

	    /* If station not found then return false */
	    IF NOT FOUND THEN
	        RAISE NOTICE 'Station % not found!', stid;
	        RETURN FALSE;
	    END IF;

	    RAISE NOTICE '> Create tables...';

	    /* Create table for instant data */
	    SELECT template.f_create_inst_table_like_template(stid, false) INTO r;
	    /* Check errors */
	    IF NOT r THEN
	        RAISE EXCEPTION 'Error during template.f_create_inst_table_like_template function!';
	    END IF;
	    /* Create main table */
	    SELECT template.f_create_table_like_template(stid, 'opas'::text, false) INTO r;
	    /* Check errors */
	    IF NOT r THEN
	        RAISE EXCEPTION 'Error during template.f_create_table_like_template function!';
	    END IF;

	    RAISE NOTICE '> Create triggers...';
	    /* Create default triggers */
	    q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_1_mc_to_pvc_bi '
	        ||'BEFORE INSERT '
	        ||'ON '||s||'.'||t||' '
	        ||'FOR EACH ROW '
	        ||'EXECUTE FUNCTION clients.f_measure_to_post_validity_code();';

	    EXECUTE q;

	    q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_2_avc_to_pvc_bi '
	        ||'BEFORE INSERT '
	        ||'ON '||s||'.'||t||' '
	        ||'FOR EACH ROW '
	        ||'EXECUTE FUNCTION clients.f_auto_to_post_validity_code('||quote_literal(stid)||'); ';

	    EXECUTE q;

	    q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_4_set_extract_code_bi '
	        ||'BEFORE INSERT '
	        ||'ON '||s||'.'||t||' '
	        ||'FOR EACH ROW '
	        ||'EXECUTE FUNCTION clients.f_set_extract_code('||quote_literal(stid)||'); ';

	    EXECUTE q;

	    q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_10_sh_bibu '
	        ||'BEFORE INSERT OR UPDATE OF measure_value, post_validity_code, final_validity_code '
	        ||'ON '||s||'.'||t||' '
	        ||'FOR EACH ROW '
	        ||'EXECUTE FUNCTION clients.f_save_history(); ';

	    EXECUTE q;

	    /*Create CUSTOM triggers */

	    -- DATA EXPORT
	    IF s IN ('client_abr', 'client_ero', 'client_mar', 'client_tn', 'client_tos', 'client_umb', 'client_ven' ) THEN

	        q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_data_export_aiau '
	            ||'AFTER INSERT OR UPDATE '
	            ||'ON '||s||'.'||t||' '
	            ||'FOR EACH ROW '
	            ||'EXECUTE FUNCTION '||s||'.f_data_export('||quote_literal(stid)||'); ';

	        EXECUTE q;

	    END IF;

	    -- SWAM TO 24H
	    IF s IN ('client_abr', 'client_ero', 'client_fvg', 'client_umb') THEN

	        q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_99_chk_measure_swam_bi '
	            ||'BEFORE INSERT '
	            ||'ON '||s||'.'||t||' '
	            ||'FOR EACH ROW '
	            ||'WHEN (pg_trigger_depth() = 0) '
	            ||'EXECUTE FUNCTION clients.f_swam_to_24h_v2('||quote_literal(stid)||'); ';

	        EXECUTE q;

	    END IF;

		-- TOSCANA - SWAM TO 24H
		IF s IN ('client_tos') THEN

	        q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_99_chk_measure_swam_bi '
	            ||'BEFORE INSERT '
	            ||'ON '||s||'.'||t||' '
	            ||'FOR EACH ROW '
	            ||'WHEN (pg_trigger_depth() = 0) '
	            ||'EXECUTE FUNCTION client_tos.f_swam_to_24h_v2('||quote_literal(stid)||'); ';

	        EXECUTE q;

	    END IF;

	    -- INFOARIA E2a
	    IF s IN ('client_fvg', 'client_vda') THEN

	        q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_data_export_e2a_ai '
	            ||'AFTER INSERT '
	            ||'ON '||s||'.'||t||' '
	            ||'FOR EACH ROW '
	            ||'EXECUTE FUNCTION infoaria.f_data_export_e2a('||quote_literal(stid)||'); ';

	        EXECUTE q;

	    END IF;

	    -- SIRAL
	    IF s IN ('client_lig' ) THEN

	        q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_export_siral_ai '
	            ||'AFTER INSERT '
	            ||'ON '||s||'.'||t||' '
	            ||'FOR EACH ROW '
	            ||'EXECUTE FUNCTION client_lig.f_export_siral('||quote_literal(stid)||'); ';

	        EXECUTE q;

	        q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_export_checked_siral_au '
	            ||'AFTER UPDATE OF measure_value, post_validity_code, final_validity_code '
	            ||'ON '||s||'.'||t||' '
	            ||'FOR EACH ROW '
	            ||'EXECUTE FUNCTION client_lig.f_export_checked_siral('||quote_literal(stid)||'); ';

	        EXECUTE q;

	    END IF;

	    -- ARPAE: BCBB BCFF E FIDAS (?)
	    IF s IN ('client_ero' ) THEN

	        q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_bcbb_bcff_aiau '
	            ||'AFTER INSERT OR UPDATE OF measure_value '
	            ||'ON '||s||'.'||t||' '
	            ||'FOR EACH ROW '
	            ||'WHEN (pg_trigger_depth() = 0) '
	            ||'EXECUTE FUNCTION client_ero.f_calculate_bcbb_bcff('||quote_literal(stid)||'); ';

	        EXECUTE q;

	        -- -- f_fidas_gg_to_fidas
	        -- q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_fidas_au '
	        --     ||'AFTER INSERT OR UPDATE OF post_validity_code, final_validity_code '
	        --     ||'ON '||s||'.'||t||' '
	        --     ||'FOR EACH ROW '
	        --     ||'EXECUTE FUNCTION client_ero.f_fidas_gg_to_fidas('||quote_literal(stid)||');';

	        -- EXECUTE q;

	    END IF;

	    RETURN TRUE;
	    /* errors check */
	    EXCEPTION
	    WHEN OTHERS THEN /* in case of any error */
	        RAISE NOTICE 'ERROR IN template.f_create_opas_tables() : %', SQLERRM ;
	        RETURN FALSE;
	END;
	$BODY$;

	ALTER FUNCTION template.f_create_opas_tables(integer)
	    OWNER TO user_admin;

	GRANT EXECUTE ON FUNCTION template.f_create_opas_tables(integer) TO group_admin;
	GRANT EXECUTE ON FUNCTION template.f_create_opas_tables(integer) TO group_bobo;
	GRANT EXECUTE ON FUNCTION template.f_create_opas_tables(integer) TO group_tools;
	GRANT EXECUTE ON FUNCTION template.f_create_opas_tables(integer) TO user_admin;

	COMMENT ON FUNCTION template.f_create_opas_tables(integer)
	    IS '[BOBO] Function that dynamically creates station tables and linked triggers';


	DROP FUNCTION IF EXISTS clients.f_refresh_last_instruments_update();
	CREATE OR REPLACE FUNCTION clients.f_refresh_last_instruments_update(
		)
	    RETURNS boolean
	    LANGUAGE 'plpgsql'
	    COST 100
	    VOLATILE PARALLEL UNSAFE
	AS $BODY$
		DECLARE

			f boolean;      -- first loop flag
			s integer;      -- previous station_id
			q text;         -- dynamic query

			rec  record;    -- result record
			irec record;    -- inner result record
			r  jsonb;       -- station total object
			ir jsonb;       -- station partial object

		BEGIN
			--
			-- TEST SELECT clients.f_refresh_last_instruments_update();
			--

			-- RAISE NOTICE 'SELECT clients.f_refresh_last_instruments_update';

			/* Initialize variables */
			s := 0;
			r := '[]'::jsonb;
			f := TRUE;

			/* Reset support table */
			TRUNCATE TABLE clients.instruments_last_update RESTART IDENTITY;

			/*
			* get fulltable and measure_id linked to grouped stpr_group_id
			* loop through:
			*   - all stations and for each element insert a new row in a support table
			*   - all grouped parameters and for each group get the minimum of the maximum update dates
			*/
			FOR rec IN
				
				WITH t AS (
					SELECT
						CASE 
							WHEN sp.param_id IN (138, 163) THEN 99999
							ELSE COALESCE(stpr_group_id, 99999) 
						END AS stpr_group_id,
						station_id,
						stpr_table_id
					FROM
						metadata.stations_parameters sp
						LEFT JOIN metadata.parameters_info pi USING (param_id)
					WHERE
						-- meteo, chimici, polveri, allarmi
						( 
							( 
								pm_info_type_fk IN (1,2,3,14) 
								-- group id null oppure parametri Porta aperta, Temp. Cabina
								AND ( stpr_group_id NOTNULL OR param_id IN (138, 163) )
							)
							OR
							( 
								pm_info_type_fk = 13 
								-- 
								-- [SWAM] VolumeIngresso  391
								-- [HYDRA] VolumeIngresso 692
								-- [SM200] Record ID      1190	
								-- [MCZ] Flow             483	
								-- ICMP Ping              1191
								-- 
								AND param_id IN ( 391,483,692,1190,1191 )
							)
						)
						AND stpr_active IS TRUE 
				), 
				p AS (
					SELECT
						stpr_group_id,
						station_id,
						ARRAY_AGG(stpr_table_id) AS table_ids
					FROM
						t
					GROUP BY
						station_id, stpr_group_id
					ORDER BY
						station_id
				)
					SELECT
						p.station_id,
						s.station_name,
						p.stpr_group_id,
						s.station_schema||'.'||COALESCE(s.station_prefix, '')||s.station_table AS station_fulltable,
						table_ids,
						vi.instr_type_fullname || COALESCE(' - '|| vi.instrument_name, '') || COALESCE(' ['|| vi.instrument_serial_num||']', '') AS instrument_fullname,
						vi.category_short_name
					FROM
						p
						LEFT JOIN metadata.stations s USING (station_id)
						LEFT JOIN metadata.stations_status ss USING (station_id)
						LEFT JOIN metadata.view_stations_instruments vsi ON ( p.stpr_group_id = vsi.stpr_group_id AND tsrange(vsi.station_instr_startup_date, vsi.station_instr_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
						LEFT JOIN equipments.view_instruments vi USING (instr_id)
					WHERE
						-- only recovers parameters with associated instrument
						vsi.instr_id NOTNULL
						-- only active stations
						AND s.station_active IS TRUE
						AND ss.ss_suspended IS FALSE
						AND (vi.category_id BETWEEN 1 AND 18 OR vi.category_id IN (20, 21, 22, 24, 31))
				UNION ALL
					SELECT
						p.station_id,
						s.station_name,
						p.stpr_group_id,
						s.station_schema||'.'||COALESCE(s.station_prefix, '')||s.station_table AS station_fulltable,
						table_ids,
						'Kit Stazione' AS instrument_fullname,
						'Staz.' 	   AS category_short_name
					FROM
						p
						LEFT JOIN metadata.stations s USING (station_id)
						LEFT JOIN metadata.stations_status ss USING (station_id)
					WHERE
						p.stpr_group_id = 99999
						-- only active stations
						AND s.station_active IS TRUE
						AND ss.ss_suspended IS FALSE
					ORDER BY
						station_id, stpr_group_id

			LOOP

				-- RAISE NOTICE '-- CONTROLLO: stazione diversa da quella precedente';
				IF rec.station_id != s AND f IS FALSE THEN
					-- RAISE NOTICE '';
					-- RAISE NOTICE '! Stazione diversa: eseguo insert e resetto oggetto';
					/* Insert in table */
					-- RAISE NOTICE '! Jsonb finale: %', jsonb_pretty(r);

					INSERT INTO clients.instruments_last_update
						(station_id, instr_last_update)
					VALUES
						(s, r);

					/* reset jsonb container */
					r := '[]'::jsonb;

				END IF;

				-- RAISE NOTICE '> Station: %, parameters: %, instrument: % ', rec.station_name, rec.table_ids, rec.instrument_fullname;

				f := FALSE;
				/* update station variable */
				s := rec.station_id;
				/* reset internal object */
				ir := '{}'::jsonb;

				/* build dynamic query with data returned by previous query */
				q =
					'WITH d AS ('||E'\n'
					||'    SELECT'||E'\n'
					||'        measure_id,'||E'\n'
					||'        MAX(measure_date_time) AS max_time'||E'\n'
					||'    FROM'||E'\n'
					||'        '||rec.station_fulltable||' '||E'\n'
					||'    WHERE'||E'\n'
					||'        measure_id = ANY('||quote_literal(rec.table_ids)||'::integer[])'||E'\n'
					||'         AND measure_date_time > CURRENT_DATE - interval ''1 week'''||E'\n'
					||'    GROUP BY'||E'\n'
					||'        measure_id'||E'\n'
					||'),'||E'\n'
					||'t AS ('||E'\n'
					||'    SELECT'||E'\n'
					||'        measure_id,'||E'\n'
					||'        max_time,'||E'\n'
					||'        row_number() OVER (ORDER BY max_time ASC) AS rownum_asc,'||E'\n'
					||'        row_number() OVER (ORDER BY max_time DESC) AS rownum_desc'||E'\n'
					||'    FROM'||E'\n'
					||'        d'||E'\n'
					||')'||E'\n'
					||'SELECT'||E'\n'
					||'    measure_id,'||E'\n'
					||'    max_time,'||E'\n'
					||'    AGE(DATE_TRUNC( ''hour'', CURRENT_TIMESTAMP ), max_time) AS interval_gap,'||E'\n'
					||'    CASE '||E'\n'
					||'        WHEN AGE(DATE_TRUNC( ''hour'', CURRENT_TIMESTAMP ), max_time) > ''23 hours''::interval THEN TO_CHAR(AGE(DATE_TRUNC( ''hour'', CURRENT_TIMESTAMP ), max_time), ''DD "giorni" HH24 ore'')'||E'\n'
					||'        ELSE TO_CHAR(AGE(DATE_TRUNC( ''hour'', CURRENT_TIMESTAMP ), max_time), ''HH24 ore'')'||E'\n'
					||'    END AS text_gap'||E'\n'
					||'FROM'||E'\n'
					||'    t'||E'\n'
					||'WHERE'||E'\n'
					||'    rownum_desc = 1;'||E'\n';

				-- RAISE NOTICE 'Query : %', q;
				EXECUTE q INTO irec;

				/* build jsonb container */
				SELECT jsonb_build_object(
					'instr'      , TRIM(rec.instrument_fullname),
					'cat'        , rec.category_short_name,
					'time'       , COALESCE(TO_CHAR(irec.max_time, 'DD.MM.YYYY h HH24'), 'oltre 1 sett.'),
					'gap'        , COALESCE(irec.text_gap, 'oltre 1 sett.'),
					'class'      , CASE
										WHEN rec.category_short_name ~* 'BTX' THEN
											CASE    
												WHEN irec.interval_gap IS NULL OR irec.interval_gap > '3 hours'::interval THEN 'bg-danger'
												WHEN irec.interval_gap BETWEEN '2 hours'::interval AND '3 hours'::interval THEN 'bg-warning'
												WHEN irec.interval_gap < '0 hours'::interval THEN 'bg-purple'
												ELSE 'bg-success'
											END
										ELSE
											CASE    
												WHEN irec.interval_gap IS NULL OR irec.interval_gap > '2 hours'::interval THEN 'bg-danger'
												WHEN irec.interval_gap BETWEEN '1 hours'::interval AND '2 hours'::interval THEN 'bg-warning'
												WHEN irec.interval_gap < '0 hours'::interval THEN 'bg-purple'
												ELSE 'bg-success'
											END
									END,
					'weight'     ,  CASE
										WHEN rec.category_short_name ~* 'BTX' THEN
											CASE
												WHEN irec.interval_gap IS NULL OR irec.interval_gap > '3 hours'::interval THEN 200
												WHEN irec.interval_gap BETWEEN '2 hours'::interval AND '3 hours'::interval THEN 10
												WHEN irec.interval_gap < '0 hours'::interval THEN 1000
												ELSE 0
											END
										ELSE
											CASE
												WHEN irec.interval_gap IS NULL OR irec.interval_gap > '2 hours'::interval THEN 200
												WHEN irec.interval_gap BETWEEN '1 hours'::interval AND '2 hours'::interval THEN 10
												WHEN irec.interval_gap < '0 hours'::interval THEN 1000
												ELSE 0
											END
									END
				) INTO ir;

				-- RAISE NOTICE '-- Jsonb parziale: %', jsonb_pretty(ir);
				-- RAISE NOTICE '-- Accodo json parziale nel json totale della stazione';
				SELECT r || ir INTO r;

			END LOOP;

			-- RAISE NOTICE '';
			-- RAISE NOTICE 'Ultima stazione: eseguo insert';

			/* Insert in table */
			-- RAISE NOTICE '! Jsonb finale: %', jsonb_pretty(r);
			INSERT INTO clients.instruments_last_update
				(station_id, instr_last_update)
			VALUES
				(s, r);
						
			RETURN TRUE;

			/* errors check */
			EXCEPTION
				WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_last_instruments_update(): %', SQLERRM;
				RETURN FALSE;
			END;

	    
	$BODY$;

	GRANT EXECUTE ON FUNCTION clients.f_refresh_last_instruments_update() TO group_admin;
	GRANT EXECUTE ON FUNCTION clients.f_refresh_last_instruments_update() TO group_bobo;
	GRANT EXECUTE ON FUNCTION clients.f_refresh_last_instruments_update() TO group_tools;
	GRANT EXECUTE ON FUNCTION clients.f_refresh_last_instruments_update() TO group_readonly;

	COMMENT ON FUNCTION clients.f_refresh_last_instruments_update() IS 'Refresh table with latest instruments updates';