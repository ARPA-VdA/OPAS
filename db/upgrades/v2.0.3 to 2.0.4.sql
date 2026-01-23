-- +----------------------------------------------------------------------------------------------+
-- | - Script Name   : v2.0.3 to 2.0.4.sql                                                        |
-- | - Author        : Ecometer s.n.c.                                                            |
-- | - Creation Date : 2025-12-31                                                                 |
-- | - Description   : Script to update PostgreSQL database.                                      |
-- +----------------------------------------------------------------------------------------------+

-- ---------------------------------------------
-- New page file path
-- ---------------------------------------------
INSERT INTO bobo.pages
    (page_id, page_name, page_href, page_shortcut_icon)
VALUES
    (72, 'File path', '/dat_filepath', 'fa-regular fa-list-tree'          ) -- 72

RETURNING page_id;


INSERT INTO bobo.group_pages
    (gr_id, page_id, gp_iud_grants)
VALUES
    ( 3, 72, '111'); -- File path


INSERT INTO bobo.menu_pages
    (mp_id, menu_id, page_id, mp_name, mp_path, mp_order)
VALUES
    (88, 1, 72,   'File path', 'sidebar1.dat.filepath' ,  158 )  -- 88 

RETURNING mp_id;


INSERT INTO bobo.menu_css
    (mp_id, menu_css_class, menu_css_expanded, menu_css_icon, menu_css_blank)
VALUES
    (88, null, true , null, false ); -- File path


ALTER TABLE metadata.stations_network_type ADD COLUMN st_network_datapath text;
COMMENT ON COLUMN metadata.stations_network_type.st_network_datapath IS 'Station network data path for FTP files';

UPDATE metadata.stations_network_type SET st_network_datapath = 'rete1' WHERE st_network_id = 1 ; -- Rete 1

-- Tabella che contiene la lista dei file trovati sul server script e sftp
-- DROP TABLE IF EXISTS clients.data_file_status;
CREATE TABLE IF NOT EXISTS clients.data_file_status
(
    id              serial     NOT NULL,
    data_path       text       NOT NULL,
    data_type       text       NOT NULL CHECK ( data_type IN ('dat', 'cal', 'inst', 'read') ),
    file_name       text       NOT NULL,
    file_date       timestamp  NOT NULL,
    file_location   text       NOT NULL CHECK ( file_location IN ('sftp', 'import', 'backup') ),
    file_header     text,

    CONSTRAINT clients_data_file_status_pkey PRIMARY KEY (id),
    CONSTRAINT clients_data_file_status_ukey UNIQUE (data_path, file_name)
);

-- grants
GRANT ALL ON TABLE    clients.data_file_status TO group_admin;
GRANT ALL ON TABLE    clients.data_file_status TO group_bobo;
GRANT ALL ON TABLE    clients.data_file_status TO group_tools;
GRANT SELECT ON TABLE clients.data_file_status TO group_readonly;

-- comments
COMMENT ON TABLE  clients.data_file_status               IS '[OPAS] Holds a list of file found in server script and sftp';
COMMENT ON COLUMN clients.data_file_status.id            IS 'Progerssive ID';
COMMENT ON COLUMN clients.data_file_status.data_path     IS 'Data path per netwok (arpa_xxx)';
COMMENT ON COLUMN clients.data_file_status.data_path     IS 'Data type (dat, cal, inst, read)';
COMMENT ON COLUMN clients.data_file_status.file_name     IS 'File name';
COMMENT ON COLUMN clients.data_file_status.file_date     IS 'File date';
COMMENT ON COLUMN clients.data_file_status.file_location IS 'File location (sftp, import, backup)';
COMMENT ON COLUMN clients.data_file_status.file_header   IS 'File header to map station_id';

-- ---------------------------------------------
-- UPDATE PAGE "Indicatori"
-- ---------------------------------------------
CREATE TABLE clients_stats.runs
(
    run_id              bigint GENERATED ALWAYS AS IDENTITY,
    run_date            date NOT NULL,
    province_id         integer NOT NULL,

    run_result          boolean,
    
    run_pdf             boolean DEFAULT FALSE,
    run_pdf_last_mod    timestamp without time zone,
    run_pdf_creator     integer,

    us_id               integer,
    run_insert_ts       timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    run_update_ts       timestamp without time zone,

    CONSTRAINT clients_stats_runs_pkey PRIMARY KEY (run_id),
    CONSTRAINT clients_stats_runs_ukey UNIQUE (run_date, province_id),
    CONSTRAINT clients_stats_runs_fkey FOREIGN KEY (province_id)
        REFERENCES main.provinces (province_id) MATCH SIMPLE
        ON UPDATE CASCADE 
        ON DELETE RESTRICT,
    CONSTRAINT clients_stats_results_fkey2 FOREIGN KEY (run_pdf_creator)
        REFERENCES bobo.users (us_id) MATCH SIMPLE
        ON UPDATE CASCADE 
        ON DELETE RESTRICT,
    CONSTRAINT clients_stats_results_fkey3 FOREIGN KEY (us_id)
        REFERENCES bobo.users (us_id) MATCH SIMPLE
        ON UPDATE CASCADE 
        ON DELETE RESTRICT
);

-- grants
GRANT ALL    ON TABLE clients_stats.runs TO group_admin;
GRANT ALL    ON TABLE clients_stats.runs TO group_bobo;
GRANT ALL    ON TABLE clients_stats.runs TO group_tools;
GRANT SELECT ON TABLE clients_stats.runs TO group_readonly;

-- comments
COMMENT ON TABLE  clients_stats.runs                     IS '[OPAS] Table holding all runs of statistics script';;
COMMENT ON COLUMN clients_stats.runs.run_id              IS 'Run ID (PK)';
COMMENT ON COLUMN clients_stats.runs.run_date            IS 'Run date (UNIQUE)';
COMMENT ON COLUMN clients_stats.runs.province_id         IS 'Province ID (UNIQUE, FK)';
COMMENT ON COLUMN clients_stats.runs.run_result          IS 'Run result (Boolean)';
COMMENT ON COLUMN clients_stats.runs.run_pdf             IS 'Run has PDF (Boolean)';
COMMENT ON COLUMN clients_stats.runs.run_pdf_last_mod    IS 'Run PDF last modified';
COMMENT ON COLUMN clients_stats.runs.run_pdf_creator     IS 'Creator of the PDF (FK)';
COMMENT ON COLUMN clients_stats.runs.us_id               IS 'Creator of the run (FK)';
COMMENT ON COLUMN clients_stats.runs.run_insert_ts       IS 'Run insert timestamp';
COMMENT ON COLUMN clients_stats.runs.run_update_ts       IS 'Run last update timestamp';



-- ---------------------------------------------
-- NEW TRIGGER 
-- ---------------------------------------------

-- DROP FUNCTION IF EXISTS clients.f_sanity_check();
CREATE OR REPLACE FUNCTION clients.f_sanity_check()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
    DECLARE
        q text; -- query
        r boolean; -- result
        
    BEGIN
        RAISE NOTICE 'FUNCTION f_sanity_check';

        /** 
         * ! First check !
         * Measure fulldate must be equal to HH:00:00 ( without minutes or seconds ) 
         */
        IF EXTRACT(minutes FROM NEW.measure_date_time) != 0 OR EXTRACT(seconds FROM NEW.measure_date_time) != 0 THEN
            /* prevent insert */
            RETURN NULL;
        END IF;

        /** 
         * ! Second check !
         * Measure fulldate in the future
         */
        IF NEW.measure_date_time > CURRENT_TIMESTAMP THEN
            /* prevent insert */
            RETURN NULL;
        END IF;

        /** 
         * ! Third check !
         * Prevent conflict
         */
        q := 'SELECT EXISTS ('|| E'\n'
            ||'    SELECT 1'|| E'\n'
            ||'    FROM '||TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME || E'\n'
            ||'    WHERE'|| E'\n'
            ||'        measure_id = '|| NEW.measure_id || E'\n'
            ||'        AND measure_date_time = '|| quote_literal(NEW.measure_date_time) ||'::timestamp '|| E'\n'
            ||');';

        EXECUTE q INTO r;
        
        IF r THEN 
            /* prevent insert */
            RETURN NULL;
        END IF;

        /* return value */
        RETURN NEW;

        /* errors check */
        EXCEPTION
            WHEN insufficient_privilege THEN
                    RETURN NEW;
            WHEN OTHERS THEN

                RAISE NOTICE 'ERROR IN clients.f_sanity_check() : %', SQLERRM;
                /* return value */
                RETURN NEW;
        END;
$BODY$;


GRANT EXECUTE ON FUNCTION clients.f_sanity_check() TO group_admin;
GRANT EXECUTE ON FUNCTION clients.f_sanity_check() TO group_bobo;
GRANT EXECUTE ON FUNCTION clients.f_sanity_check() TO group_tools;

COMMENT ON FUNCTION clients.f_sanity_check() IS '[OPAS] Function that checks the sanity (or validity) of the data to be inserted';



-- ---------------------------------------------
-- UPDATES 
-- ---------------------------------------------
ALTER TABLE client_lig_alims.arguments ADD COLUMN arg_info text;
COMMENT ON COLUMN client_lig_alims.arguments.arg_info   IS 'Argument information';

CREATE OR REPLACE FUNCTION metadata.f_get_icon_by_station_id(
    stid integer)
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100
    STABLE PARALLEL UNSAFE
AS $BODY$
    DECLARE
        i text; -- icon
    BEGIN

        SELECT
            CASE
                WHEN ss_suspended IS TRUE THEN 'f6e2'
                WHEN st_info_typology_fk =  5 THEN 'f3b3' -- Emissioni f240 6 per bobo
                WHEN st_info_typology_fk =  6 THEN 'f495' -- magazzini
                WHEN st_info_typology_fk =  9 THEN 'f276' -- campionatori
                WHEN st_info_typology_fk = 10 THEN 'f472' -- mini cabina
                WHEN st_info_roaming_type_fk IN (2, 4) THEN 'f0d1' -- staz mobili e siti con stanziamento
                ELSE 'f3c5'
            END INTO i
        FROM
            metadata.stations_info si
            LEFT JOIN metadata.stations_status ss USING (station_id)
        WHERE
            station_id = stid;

        RETURN i;

    /* errors check */
    EXCEPTION
       /* in case of any error */
       WHEN OTHERS THEN RAISE NOTICE 'ERROR in f_get_icon_by_station_id: %', SQLERRM;
    END;
$BODY$;

CREATE OR REPLACE FUNCTION template.f_create_cc_view(
    stid integer)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE SECURITY DEFINER PARALLEL UNSAFE
AS $BODY$
    DECLARE
        cc jsonb;  -- const variable

        q text;     -- dynamic query
        p text;     -- partial query
        a text[];   -- array of partial queries

        v text;     -- new view name
        m integer;  -- param id main parameter
        rec record;

    BEGIN

        /* entry */
        RAISE NOTICE 'Function template.f_create_cc_view, stid: %', stid;
        /* Testing
            SELECT template.f_create_cc_view(1000::integer);
        */

        cc = '{
                "496": { "main_id" : "30", "step": "zero", "deriva": "false" },
                "497": { "main_id" : "31", "step": "zero", "deriva": "false" },
                "498": { "main_id" : "32", "step": "zero", "deriva": "false" },
                "499": { "main_id" : "30", "step": "span", "deriva": "false" },
                "500": { "main_id" : "30", "step": "span", "deriva": "false" },
                "501": { "main_id" : "30", "step": "span", "deriva": "true"  },
                "502": { "main_id" : "31", "step": "span", "deriva": "false" },
                "503": { "main_id" : "31", "step": "span", "deriva": "false" },
                "504": { "main_id" : "31", "step": "span", "deriva": "true"  },
                "505": { "main_id" : "32", "step": "span", "deriva": "false" },
                "506": { "main_id" : "32", "step": "span", "deriva": "false" },
                "507": { "main_id" : "32", "step": "span", "deriva": "true"  },
                "509": { "main_id" : "34", "step": "zero", "deriva": "false" },
                "510": { "main_id" : "34", "step": "span", "deriva": "false" },
                "511": { "main_id" : "34", "step": "span", "deriva": "false" },
                "512": { "main_id" : "34", "step": "span", "deriva": "true"  },
                "514": { "main_id" : "33", "step": "zero", "deriva": "false" },
                "515": { "main_id" : "33", "step": "span", "deriva": "false" },
                "516": { "main_id" : "33", "step": "span", "deriva": "false" },
                "517": { "main_id" : "33", "step": "span", "deriva": "true"  },
                "519": { "main_id" : "29", "step": "zero", "deriva": "false" },
                "520": { "main_id" : "29", "step": "span", "deriva": "false" },
                "521": { "main_id" : "29", "step": "span", "deriva": "false" },
                "522": { "main_id" : "29", "step": "span", "deriva": "true"  },
                "524": { "main_id" : "38", "step": "zero", "deriva": "false" },
                "525": { "main_id" : "39", "step": "zero", "deriva": "false" },
                "526": { "main_id" : "40", "step": "zero", "deriva": "false" },
                "527": { "main_id" : "38", "step": "span", "deriva": "false" },
                "528": { "main_id" : "38", "step": "span", "deriva": "false" },
                "529": { "main_id" : "38", "step": "span", "deriva": "true"  },
                "530": { "main_id" : "39", "step": "span", "deriva": "false" },
                "531": { "main_id" : "39", "step": "span", "deriva": "false" },
                "532": { "main_id" : "39", "step": "span", "deriva": "true"  },
                "533": { "main_id" : "40", "step": "span", "deriva": "false" },
                "534": { "main_id" : "40", "step": "span", "deriva": "false" },
                "535": { "main_id" : "40", "step": "span", "deriva": "true"  },
                "548": { "main_id" : "41", "step": "span", "deriva": "false" },
                "549": { "main_id" : "41", "step": "span", "deriva": "true"  },
                "550": { "main_id" : "42", "step": "span", "deriva": "false" },
                "551": { "main_id" : "42", "step": "span", "deriva": "true"  },
                "552": { "main_id" : "45", "step": "span", "deriva": "false" },
                "553": { "main_id" : "45", "step": "span", "deriva": "true"  },

                "842": { "main_id" : "51", "step": "zero", "deriva": "false" },
                "843": { "main_id" : "52", "step": "zero", "deriva": "false" },
                "844": { "main_id" : "53", "step": "zero", "deriva": "false" },
                "845": { "main_id" : "54", "step": "zero", "deriva": "false" },
                "846": { "main_id" : "55", "step": "zero", "deriva": "false" },
                "847": { "main_id" : "56", "step": "zero", "deriva": "false" },
                "848": { "main_id" : "57", "step": "zero", "deriva": "false" },
                "849": { "main_id" : "58", "step": "zero", "deriva": "false" },
                "850": { "main_id" : "59", "step": "zero", "deriva": "false" },
                "851": { "main_id" : "60", "step": "zero", "deriva": "false" },
                "852": { "main_id" : "61", "step": "zero", "deriva": "false" },
                "853": { "main_id" : "62", "step": "zero", "deriva": "false" },
                "854": { "main_id" : "64", "step": "zero", "deriva": "false" },
                "855": { "main_id" : "65", "step": "zero", "deriva": "false" },
                "856": { "main_id" : "66", "step": "zero", "deriva": "false" },
                "857": { "main_id" : "67", "step": "zero", "deriva": "false" },
                "858": { "main_id" : "68", "step": "zero", "deriva": "false" },
                "859": { "main_id" : "69", "step": "zero", "deriva": "false" },
                "860": { "main_id" : "70", "step": "zero", "deriva": "false" },
                "861": { "main_id" : "71", "step": "zero", "deriva": "false" },
                "862": { "main_id" : "72", "step": "zero", "deriva": "false" },
                "863": { "main_id" : "76", "step": "zero", "deriva": "false" },
                "864": { "main_id" : "77", "step": "zero", "deriva": "false" },
                "865": { "main_id" : "78", "step": "zero", "deriva": "false" },
                "866": { "main_id" : "79", "step": "zero", "deriva": "false" },
                "867": { "main_id" : "80", "step": "zero", "deriva": "false" },
                "868": { "main_id" : "81", "step": "zero", "deriva": "false" },
                "869": { "main_id" : "82", "step": "zero", "deriva": "false" },
                "870": { "main_id" : "83", "step": "zero", "deriva": "false" },
                "871": { "main_id" : "657", "step": "zero", "deriva": "false" },
                "872": { "main_id" : "658", "step": "zero", "deriva": "false" },
                "873": { "main_id" : "659", "step": "zero", "deriva": "false" },
                "874": { "main_id" : "809", "step": "zero", "deriva": "false" },
                "875": { "main_id" : "810", "step": "zero", "deriva": "false" },
                "876": { "main_id" : "811", "step": "zero", "deriva": "false" },
                "877": { "main_id" : "812", "step": "zero", "deriva": "false" },
                "878": { "main_id" : "813", "step": "zero", "deriva": "false" },
                "879": { "main_id" : "814", "step": "zero", "deriva": "false" },
                "880": { "main_id" : "815", "step": "zero", "deriva": "false" },
                "881": { "main_id" : "816", "step": "zero", "deriva": "false" },
                "882": { "main_id" : "817", "step": "zero", "deriva": "false" },
                "883": { "main_id" : "818", "step": "zero", "deriva": "false" },
                "884": { "main_id" : "819", "step": "zero", "deriva": "false" },
                "885": { "main_id" : "820", "step": "zero", "deriva": "false" },
                "886": { "main_id" : "821", "step": "zero", "deriva": "false" },
                "887": { "main_id" : "822", "step": "zero", "deriva": "false" },
                "888": { "main_id" : "823", "step": "zero", "deriva": "false" },
                "889": { "main_id" : "824", "step": "zero", "deriva": "false" },
                "890": { "main_id" : "825", "step": "zero", "deriva": "false" },

                "1199": { "main_id" : "37", "step": "zero", "deriva": "false" },
                "1202": { "main_id" : "37", "step": "span", "deriva": "false" },
                "1203": { "main_id" : "37", "step": "span", "deriva": "false" },
                "1204": { "main_id" : "37", "step": "span", "deriva": "true"  },
                
                "1229": { "main_id" : "183", "step": "zero", "deriva": "false" }
            }'::jsonb;

        SELECT
            station_schema || '.' || COALESCE(station_prefix, '')|| station_table||'_cc' INTO v
        FROM
            metadata.stations
        WHERE
            station_id = stid;

        RAISE NOTICE 'Generazione SQL per creazione della vista: %', v;
        RAISE NOTICE '--';

        q = 'DROP VIEW IF EXISTS '||v||';'||E'\n'
        ||'CREATE OR REPLACE VIEW '||v||' AS'||E'\n';

        FOR rec IN

            SELECT
                param_id, parameter_name, stpr_table_id, stpr_group_id
            FROM
                metadata.view_stations_parameters
            WHERE
                station_id = stid
                AND parameter_type_id = 12 -- taratura
            ORDER BY param_id

        LOOP

            RAISE NOTICE 'Param id: %, param name: %, table id: %, Main id: %, step: %', rec.param_id, rec.parameter_name, rec.stpr_table_id, cc->(rec.param_id)::text->>'main_id', cc->(rec.param_id)::text->>'step';

            -- recupero table id del main parameter
            -- query diverse a seconda che il group id è definito o meno
            IF rec.stpr_group_id IS NULL THEN
                SELECT
                    stpr_table_id INTO m
                FROM
                    metadata.stations_parameters
                WHERE
                    station_id = stid
                    AND param_id = ( cc->(rec.param_id)::text->>'main_id' )::integer;
            ELSE
                SELECT
                    stpr_table_id INTO m
                FROM
                    metadata.stations_parameters
                WHERE
                    station_id = stid
                    AND param_id = ( cc->(rec.param_id)::text->>'main_id' )::integer
                    AND stpr_group_id = rec.stpr_group_id;
            END IF;

            RAISE NOTICE 'Table id parametro main: %', m;
            -- skip the current iteration if m IS NULL
            CONTINUE WHEN m IS NULL;

            IF ( cc->(rec.param_id)::text->>'deriva' )::boolean IS TRUE THEN

                p =
                'SELECT '||E'\n'
                ||'    date_trunc(''hour''::text, c.calibration_date_time) AS measure_date_time,'||E'\n'
                ||'    '||rec.stpr_table_id||'::smallint AS measure_id, -- '||rec.parameter_name||' '||E'\n'
                ||'    CASE '||E'\n'
                ||'        WHEN c.reference_value <> 0 THEN ROUND(-(100::real - (( c.result_value / c.reference_value) * 100::real) )::numeric, 2)'||E'\n'
                ||'        ELSE NULL '||E'\n'
                ||'    END AS measure_value,'||E'\n'
                ||'    100::smallint AS measure_perc,'||E'\n'
                ||'    NULL AS measure_min,'||E'\n'
                ||'    NULL AS measure_min_time,'||E'\n'
                ||'    NULL AS measure_max,'||E'\n'
                ||'    NULL AS measure_max_time,'||E'\n'
                ||'    NULL AS measure_std_dev,'||E'\n'
                ||'    0::integer  AS measure_code,'||E'\n'
                ||'    0::smallint AS station_code,'||E'\n'
                ||'    0::integer  AS auto_validity_code,'||E'\n'
                ||'    2::integer  AS post_validity_code,'||E'\n'
                ||'    0::smallint AS final_validity_code,'||E'\n'
                ||'    24::smallint AS extract_code,'||E'\n'
                ||'    NULL::timestamp AS db_insert_time,'||E'\n'
                ||'    NULL::timestamp AS db_update_time'||E'\n'
                ||'FROM '||E'\n'
                ||'    clients.calibrations_result c'||E'\n'
                ||'WHERE c.station_id = '||stid||' '||E'\n'
                ||'AND c.measure_id = '|| m ||' '||E'\n'
                ||'AND c.calibration_step = '||quote_literal(UPPER( cc->(rec.param_id)::text->>'step' ))||'::text '||E'\n';

            ELSE
                p =
                'SELECT '||E'\n'
                ||'    date_trunc(''hour''::text, c.calibration_date_time) AS measure_date_time,'||E'\n'
                ||'    '||rec.stpr_table_id||'::smallint AS measure_id, -- '||rec.parameter_name||' '||E'\n'
                ||'    c.result_value AS measure_value,'||E'\n'
                ||'    100::smallint AS measure_perc,'||E'\n'
                ||'    NULL AS measure_min,'||E'\n'
                ||'    NULL AS measure_min_time,'||E'\n'
                ||'    NULL AS measure_max,'||E'\n'
                ||'    NULL AS measure_max_time,'||E'\n'
                ||'    NULL AS measure_std_dev,'||E'\n'
                ||'    0::integer  AS measure_code,'||E'\n'
                ||'    0::smallint AS station_code,'||E'\n'
                ||'    0::integer  AS auto_validity_code,'||E'\n'
                ||'    2::integer  AS post_validity_code,'||E'\n'
                ||'    0::smallint AS final_validity_code,'||E'\n'
                ||'    24::smallint AS extract_code,'||E'\n'
                ||'    NULL::timestamp AS db_insert_time,'||E'\n'
                ||'    NULL::timestamp AS db_update_time'||E'\n'
                ||'FROM '||E'\n'
                ||'    clients.calibrations_result c'||E'\n'
                ||'WHERE c.station_id = '||stid||' '||E'\n'
                ||'AND c.measure_id = '|| m ||' '||E'\n'
                ||'AND c.calibration_step = '||quote_literal(UPPER( cc->(rec.param_id)::text->>'step' ))||'::text '||E'\n';

            END IF;

            /* notice */
            -- RAISE NOTICE 'Partial query: %', E'\n'||p;

            a = a || p;

        END LOOP;

        IF ARRAY_LENGTH(a, 1) IS NULL THEN

            RAISE NOTICE 'Nessun parametro CC!';
            RETURN TRUE;
        END IF;

        q = q
        || ARRAY_TO_STRING( a , 'UNION ALL'||E'\n', '')
        || 'ORDER BY 1,2;'||E'\n'
        || '  '||E'\n'
        || 'GRANT ALL ON TABLE '||v||' TO group_admin;'||E'\n'
        || 'GRANT ALL ON TABLE '||v||' TO group_bobo;'||E'\n'
        || 'GRANT ALL ON TABLE '||v||' TO group_tools;'||E'\n'
        || 'GRANT SELECT ON TABLE '||v||' TO group_readonly;'||E'\n';

        RAISE NOTICE '--';
        -- RAISE NOTICE 'Query finale: %', q;

        /* return value */
        EXECUTE q;
        RETURN TRUE;

    /* errors check */
    EXCEPTION
        WHEN OTHERS THEN RAISE NOTICE 'ERROR template.f_create_cc_view(): %', SQLERRM;
        RETURN FALSE;
    END;
$BODY$;

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
            WHEN (mo->>'ModuleType')::integer IN ( 200, 420, 850, 861, 866, 1200, 1201, 1532 ) THEN
                /** nox 
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
                    
            /* NOX-NO-NO2 NH3 */
            WHEN (mo->>'ModuleType')::integer IN ( 201, 880, 1241 ) THEN
                /** nox + hn3
                 *  496, 4000 NOx Zero
                 *  497, 4001 NO Zero
                 *  498, 4002 NO2 Zero
                 *  499, 4003 NOx Span trovato
                 *  501, 4005 NOx Span deriva
                 *  502, 4006 NO Span trovato
                 *  504, 4008 NO Span deriva
                 *  505, 4009 NO2 Span trovato
                 * 1229, 4054 NH3 Zero
                 */
                q := 'SELECT
                        param_id,
                        param_name,
                        param_unit,
                        CASE param_id
                            WHEN  496 THEN 4000
                            WHEN  497 THEN 4001
                            WHEN  498 THEN 4002
                            WHEN  499 THEN 4003
                            WHEN  501 THEN 4005
                            WHEN  502 THEN 4006
                            WHEN  504 THEN 4008
                            WHEN  505 THEN 4009
                            WHEN 1229 THEN 4054
                            ELSE NULL
                        END AS table_id
                    FROM
                        metadata.parameters
                    WHERE
                        param_id IN (496,497,498,499,501,502,504,505,1229)
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
                        /** nox + nh3
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
                            
                    ELSIF co->>'Name' ~ 'NH3' THEN
                        /** nox + hn3
                         * 1229, 4054 NH3 Zero
                         */
                        q := 'SELECT
                                param_id,
                                param_name,
                                param_unit,
                                CASE param_id
                                    WHEN 1229 THEN 4054
                                    ELSE NULL
                                END AS table_id
                            FROM
                                metadata.parameters
                            WHERE
                                param_id IN (1229)
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

CREATE OR REPLACE FUNCTION template.f_create_opas_tables(
    stid integer
)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE SECURITY DEFINER PARALLEL UNSAFE
AS $BODY$
DECLARE
    -- variables
    s text; -- schema
    t text; -- table
    f integer; -- filter for roaming type
    q text; -- query

    r boolean; -- result

BEGIN
    /**
     * The function takes care of creating the tables and triggers of a new station. The function is
     * executed by the portal when user is inserting a new station
     *
     * The function is launched from the portal and is executed with the owner role (user_admin).
     */

    /* Select schema, table name and roaming type */
    SELECT station_schema, station_table, st_info_roaming_type_fk INTO s,t,f
    FROM metadata.stations
    LEFT JOIN metadata.stations_info si USING (station_id)
    WHERE station_id = stid;

    /* If station not found then return false */
    IF NOT FOUND THEN
        RAISE NOTICE 'Station % not found!', stid;
        RETURN FALSE;
    END IF;

    RAISE NOTICE '> Create tables...';

    /* Create main table */
    SELECT template.f_create_table_like_template(stid, 'opas'::text, false) INTO r;
    /* Check errors */
    IF NOT r THEN
        RAISE EXCEPTION 'Error during template.f_create_table_like_template function!';
    END IF;

    RAISE NOTICE '> Create triggers...';

    /* Create DEFAULT triggers */

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

    /* If station roaming type equal to "fissa", "mezzo mobile" */
    IF f IN (1, 2) THEN
        RAISE NOTICE 'Creating instant and readings tables for: %', stid;

        /* Create table for instant data */
        SELECT template.f_create_table_like_template(stid, 'realtime'::text, false) INTO r;
        /* Check errors */
        IF NOT r THEN
            RAISE EXCEPTION 'Error during template.f_create_table_like_template function!';
        END IF;

        /* Create table for readings data */
        SELECT template.f_create_table_like_template(stid, 'readings'::text, false) INTO r;
        /* Check errors */
        IF NOT r THEN
            RAISE EXCEPTION 'Error during template.f_create_table_like_template function!';
        END IF;
    END IF;

    RETURN TRUE;
    /* errors check */
    EXCEPTION
    WHEN OTHERS THEN /* in case of any error */
        RAISE NOTICE 'ERROR IN template.f_create_opas_tables() : %', SQLERRM ;
        -- rollback
        RETURN FALSE;
END;
$BODY$;



DROP VIEW webservice.v1_stations;
CREATE OR REPLACE VIEW webservice.v1_stations AS
    SELECT 
        st.station_id AS id,
        st.station_name AS name,
        st.station_active AS active,
        st.station_note AS note,
        st.station_ext_id AS external_id,
        sm.st_info_startup_date AS startup_date,
        sm.st_info_dismiss_date AS dismiss_date,
        (sm.st_info_basepath || '/'::text) || st.station_id AS media_path,
        m.mu_istat_code AS municipality_istat_code,
        m.mu_name AS municipality_name,
        p.province_istat_code,
        p.province_name,
        p.province_code,
        r.region_istat_code,
        r.region_name,
        sm.st_info_locality AS locality,
        sm.st_info_zone AS zone,
        sm.st_info_basin AS basin,
        sm.st_info_community AS community,
        sm.st_info_north_utm AS north_utm,
        sm.st_info_east_utm AS east_utm,
        sm.st_info_altitude AS altitude,
        sm.st_info_lat_wgs84 AS lat_wgs84,
        sm.st_info_lon_wgs84 AS lon_wgs84,
        sm.st_info_national_code AS national_code,
        snt.st_network_desc AS network_type_desc,
        snt.st_network_name AS network_type_name,
        srt.st_roaming_desc AS roaming_type_desc,
        stt.st_typology_desc AS typology_desc,
        mt.measure_type_desc,
        mc.measure_cadence_desc AS cadence_type_desc,
        mc.measure_cadence_min AS cadence_type_min,
        sm.st_info_note AS metadata_note,
        sm.st_info_export_id AS export_id,
        sm.st_info_ws_name AS ws_name
       FROM metadata.stations st
         LEFT JOIN metadata.stations_info sm USING (station_id)
         LEFT JOIN metadata.stations_municipality stm USING (station_id)
         LEFT JOIN main.municipalities m USING (mu_id)
         LEFT JOIN main.province_municipalities pm USING (mu_id)
         LEFT JOIN main.provinces p USING (province_id)
         LEFT JOIN main.region_provinces rp USING (province_id)
         LEFT JOIN main.regions r USING (region_id)
         LEFT JOIN metadata.stations_network_type snt ON snt.st_network_id = sm.st_info_network_type_fk
         LEFT JOIN metadata.stations_roaming_type srt ON srt.st_roaming_id = sm.st_info_roaming_type_fk
         LEFT JOIN metadata.stations_typology stt ON stt.st_typology_id = sm.st_info_typology_fk
         LEFT JOIN metadata.measures_type mt ON mt.measure_type_id = sm.st_info_measure_fk
         LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = sm.st_info_cadence_fk
      WHERE sm.st_info_roaming_type_fk = ANY (ARRAY[1, 2])
      ORDER BY st.station_id;

COMMENT ON VIEW webservice.v1_stations
    IS '[OPAS] The view contains all the principal info, used by the web service, about fixed and mobile stations';

GRANT ALL ON TABLE webservice.v1_stations TO group_admin;
GRANT ALL ON TABLE webservice.v1_stations TO group_tools;