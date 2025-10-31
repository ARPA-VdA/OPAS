-- +----------------------------------------------------------------------------------------------+
-- | - Script Name   : v2.0.1 to 2.0.3.sql                                                        |
-- | - Author        : Ecometer s.n.c.                                                            |
-- | - Creation Date : 2025-09-30                                                                 |
-- | - Description   : Script to update PostgreSQL database.                                      |
-- +----------------------------------------------------------------------------------------------+


-- -----------------------------------------------------------------
-- Bug fixing 
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION bobo_tools.f_visualizer_auto_generate_macro(
	stid integer[],
	types integer[],
	prid integer[] DEFAULT NULL::integer[],
	cat integer DEFAULT '-1'::integer,
	conv boolean DEFAULT false)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
    DECLARE
            tj jsonb; -- total jsonb
            j   text; -- temporary jsonb
            u   text; -- unit
            f   text; -- formule
            c   text; -- chart style
            n   text; -- window's name

            ymin numeric;
            ymax numeric;
            rec record;
    BEGIN

        /* TEST */
        /* SELECT bobo_tools.f_visualizer_auto_generate_macro('{1072}'::integer[], '{13}'::integer[], NULL, 2, true) AS macros; */
        tj := '[]'::jsonb;

        -- se è definita una categoria e non sono stati selezionati dei parametri
        IF cat != -1 AND prid IS NULL THEN

            SELECT
                ARRAY_AGG(param_id) INTO prid
            FROM
                metadata.parameters_info
            WHERE instr_type_ids && ARRAY (
                                        SELECT instr_type_id
                                        FROM equipments.instruments_type
                                        WHERE category_id = cat
                                    );
        END IF;

        /* loop through all stations and parameters */
        FOR rec IN
            WITH t AS(
                SELECT
                    CASE
                        WHEN prid NOTNULL THEN ARRAY_AGG(param_id) & prid
                        ELSE ARRAY_AGG(param_id)
                    END AS ids
                FROM metadata.parameters
            )
            SELECT
                st.station_name,
                sp.stpr_id,
				p.param_id,
                p.param_name,
                sp.stpr_note,
                COALESCE(pi.pm_info_obj->'general'->>'treatment', 'avg') AS param_treatment,
                (pi.pm_info_obj->'general'->>'min')::numeric AS param_min,
                (pi.pm_info_obj->'general'->>'max')::numeric AS param_max,
                CASE
                    WHEN param_conv = 0 THEN 'y='||COALESCE(param_offset::text, '0')
                    ELSE 'y=x'||COALESCE('+'||param_offset::text, '')
                END AS param_formule,
                p.param_unit,
                p.param_unit_conv,
                -- 24/07/2024 11:55
                -- CASE
                --     WHEN param_conv = 0 THEN 'y='||COALESCE(param_offset::text, '0')
                --     WHEN param_conv = 1 THEN 'y=x'||COALESCE('+'||param_offset::text, '')
                --     ELSE 'y='||param_conv||'*x'||COALESCE('+'||param_offset::text, '')
                -- END AS param_formule_conv,
                p.param_decimals,
                pi.pm_info_type_fk AS param_type
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.stations st USING(station_id)
                LEFT JOIN metadata.stations_info si USING(station_id)
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
            WHERE
                station_id = ANY(stid)
                AND pi.pm_info_type_fk = ANY(types)
                AND sp.param_id IN (SELECT UNNEST(ids) FROM t)
            ORDER BY
                st.station_id, sp.stpr_id
        LOOP
            RAISE NOTICE 'Station: %, stpr id: %', rec.station_name, rec.stpr_id;

            f := rec.param_formule;

            IF conv IS TRUE THEN
                u := rec.param_unit_conv;
                -- f := rec.param_formule_conv;
            ELSE
                u := rec.param_unit;
                -- f := rec.param_formule;
            END IF;

            n := rec.station_name||' - '||rec.param_name || COALESCE(' - ' || rec.stpr_note, '');

            c := 'line';
            IF rec.param_type = 12 THEN
                c := 'point';
            END IF;

            CASE
                WHEN rec.param_min < 0 AND rec.param_max IS NULL THEN
                    ymin := rec.param_min + ROUND(( rec.param_min / 2 ));
                    ymax := NULL;

                WHEN rec.param_min IS NULL AND rec.param_max > 0 THEN
                    ymin := NULL;
                    ymax := rec.param_max + ROUND(( rec.param_max / 2 ), 1);

                WHEN rec.param_min > 0 AND rec.param_max > 0 THEN
                    ymin := rec.param_min - ROUND(((rec.param_max - rec.param_min) / 2), 1);
                    ymax := rec.param_max + ROUND(((rec.param_max - rec.param_min) / 2), 1);

                WHEN rec.param_min < 0 AND rec.param_max > 0 THEN
                    ymin := rec.param_min - ROUND(((rec.param_max - rec.param_min) / 2), 1);
                    ymax := rec.param_max + ROUND(((rec.param_max - rec.param_min) / 2), 1);

                ELSE
                    ymin := NULL;
                    ymax := NULL;
            END CASE;

            RAISE NOTICE 'Unit: %, formula: %', u, f;
            /* create dynamic query */
            j = '{'||E'\n'
                ||'   "macro": {'||E'\n'
                ||'       "name": "'||n||'", '||E'\n'
                ||'       "type": "chart", '||E'\n'
                ||'       "aggregation": "hh", '||E'\n'
                ||'       "percent_data": "75", '||E'\n'
                ||'       "min": '||COALESCE(quote_ident(rec.param_min::text), 'null')||', '||E'\n'
                ||'       "max": '||COALESCE(quote_ident(rec.param_max::text), 'null')||', '||E'\n'
                ||'       "Yaxys_min": '||COALESCE(quote_ident(ymin::text), 'null')||', '||E'\n'
                ||'       "Yaxys_max": '||COALESCE(quote_ident(ymax::text), 'null')||', '||E'\n'
                ||'       "validity_code": ">= 0"'||E'\n'
                ||'   },'||E'\n'
                ||'   "params": ['||E'\n'
                ||'       {'||E'\n'
                ||'           "st_pr_id": '||rec.stpr_id||', '||E'\n'
                ||'           "name": "'||rec.param_name||'", '||E'\n'
				-- added 23/07/2025 11:23
				||'           "param_id": '||rec.param_id||', '||E'\n'
                -- added 24/07/2024 11:56
                ||'           "converted": '||conv||', '||E'\n'
                ||'           "station": "'||rec.station_name||'", '||E'\n'
                ||'           "legend": "'||n||' ['|| u ||']", '||E'\n'
                ||'           "column_name": "'||rec.param_name||' ['|| u ||'] <br>'||rec.station_name||'", '||E'\n'
                ||'           "unit": "'||u||'", '||E'\n'
                ||'           "treatment": "'||rec.param_treatment||'", '||E'\n'
                ||'           "chartstyle": "'||c||'", '||E'\n'
                ||'           "color": "FFFFFF", '||E'\n'
                ||'           "line_width": 2, '||E'\n'
                ||'           "minval": false, '||E'\n'
                ||'           "maxval": false, '||E'\n'
                ||'           "formule": "'||f||'", '||E'\n'
                ||'           "decimals": '||rec.param_decimals||', '||E'\n'
                ||'           "is_limit": false' ||E'\n'
                ||'       }'||E'\n'
                ||'   ] '||E'\n'
                ||'} ';

            RAISE NOTICE 'JSON parziale: %', j;

            SELECT tj || j::jsonb INTO tj;

        END LOOP;

        RAISE NOTICE 'JSON finale: %', tj::text;
        RETURN tj;

    /* errors check */
    EXCEPTION
        WHEN OTHERS THEN RAISE NOTICE 'ERROR bobo_tools.f_visualizer_auto_generate_macro(): %', SQLERRM;
        RETURN false;
    END;

$BODY$;


-- -----------------------------------------------------------------
-- Update Analyser and Visualizer macros: add param_id
-- -----------------------------------------------------------------

-- ANALYSER
WITH t AS(
    SELECT
        am.macro_id,
        am.macro_object,
        jsonb_set(
            am.macro_object,
            '{params}',
            array_to_json(
                ARRAY(
                    SELECT
                        x.parameter || jsonb_build_object('param_id', sp.param_id)
                    FROM
                        ( SELECT jsonb_array_elements((am.macro_object->'params')::jsonb) AS parameter ) x
                        LEFT JOIN metadata.stations_parameters sp ON sp.stpr_id = (x.parameter ->> 'st_pr_id')::integer
                )
            )::jsonb,
            false
        ) AS new_macro_object
    FROM
        bobo_tools.analyser_macros am
    GROUP BY macro_id
    ORDER BY macro_id
)
UPDATE bobo_tools.analyser_macros
SET macro_object = t1.new_macro_object
FROM (SELECT * FROM t) AS t1
WHERE analyser_macros.macro_id = t1.macro_id;


-- VISUALIZER
WITH t AS (
    -- SELECT macro_page, jsonb_array_elements(vm.macro_object) AS single_macro
    -- FROM bobo_tools.visualizer_macros vm

    SELECT vm.macro_page, a.nr, a.single_macro
    FROM bobo_tools.visualizer_macros vm
    LEFT JOIN LATERAL jsonb_array_elements(vm.macro_object) WITH ORDINALITY AS a(single_macro, nr) ON true
    ORDER BY macro_page, nr
),
t2 AS (
    SELECT
        macro_page,
        nr,
        jsonb_set(
            t.single_macro,
            '{params}',
            array_to_json(
                ARRAY(
                    SELECT
                        x.parameter || jsonb_build_object('param_id', sp.param_id)
                    FROM
                        ( SELECT jsonb_array_elements((t.single_macro->'params')::jsonb) AS parameter ) x
                        LEFT JOIN metadata.stations_parameters sp ON sp.stpr_id = (x.parameter ->> 'st_pr_id')::integer
                )
            )::jsonb,
            false
        ) AS new_macro_object
    FROM
        t
    GROUP BY macro_page, nr, single_macro
    ORDER BY macro_page, nr
),
t3 AS (
    SELECT
        macro_page,
        jsonb_agg(new_macro_object) AS new_macros
    FROM
        t2
    GROUP BY macro_page
    ORDER BY macro_page
)
UPDATE bobo_tools.visualizer_macros vm SET macro_object = t3.new_macros FROM t3 WHERE vm.macro_page = t3.macro_page;



-- -----------------------------------------------------------------
-- Update tables of ticket "Periferia"
-- -----------------------------------------------------------------
ALTER TABLE reports.ticket_categories ADD COLUMN tc_class text;
COMMENT ON COLUMN reports.ticket_categories.tc_class IS 'Ticket category icon with class';

UPDATE reports.ticket_categories SET tc_class = 'mdi-tag text-success'                  WHERE tc_id = 1;


-- @ADDED 29/07/2025 08:45
ALTER TABLE reports.ticket_urgencies ADD COLUMN tu_colour text;
COMMENT ON COLUMN reports.ticket_urgencies.tu_colour IS 'Ticket urgency colour';

UPDATE reports.ticket_urgencies SET tu_colour = 'info' 		WHERE tu_id = 1;

DROP VIEW IF EXISTS reports.view_tickets;
CREATE OR REPLACE VIEW reports.view_tickets AS
    SELECT t.tk_id,
        t.tk_parent_id_fk,
        t.tk_opening_date,
        t.tk_expiry_date,
        t.tk_opening_user_fk,
        t.tk_recipient_comp_fk,
        c.comp_name,
        t.station_id,
        s.station_name,
        t.instr_id,
        t.cy_id,
        t.mi_id,
        t.tt_id,
        tt.tt_desc,
        t.tc_id,
        tc.tc_desc,
        tc.tc_class,
        t.tu_id,
        tu.tu_desc,
        tu.tu_colour,
        t.tf_id,
        tf.tf_desc,
        t.tk_title,
        t.tk_opening_note,
        t.tk_mail_date
    FROM 
        reports.tickets t
        LEFT JOIN bobo.companies c ON c.comp_id = t.tk_recipient_comp_fk
        LEFT JOIN metadata.stations s USING (station_id)
        LEFT JOIN reports.ticket_types tt USING (tt_id)
        LEFT JOIN reports.ticket_categories tc USING (tc_id)
        LEFT JOIN reports.ticket_urgencies tu USING (tu_id)
        LEFT JOIN reports.ticket_frequencies tf USING (tf_id)
    ORDER BY t.tk_id;


GRANT ALL ON TABLE reports.view_tickets TO group_admin;
GRANT ALL ON TABLE reports.view_tickets TO group_bobo;
GRANT ALL ON TABLE reports.view_tickets TO group_tools;
GRANT SELECT ON TABLE reports.view_tickets TO group_readonly;

COMMENT ON VIEW reports.view_tickets IS 'The view contains all the principal info about tickets';
-- -----------------------------------------------------------------
-- Add new column  
-- -----------------------------------------------------------------
-- @ADDED 21/08/2025 14:18
ALTER TABLE metadata.stations_network_type ADD COLUMN st_network_obj jsonb DEFAULT '{}';
COMMENT ON COLUMN metadata.stations_network_type.st_network_obj IS 'Station network object';


-- -----------------------------------------------------------------
-- Add new pages to menu
-- -----------------------------------------------------------------
INSERT INTO bobo.pages
    (page_id, page_name, page_href, page_shortcut_icon)
VALUES
    (71,  'Strumenti'               , '/stnz_strumenti'         , 'fa-regular fa-shelves'    );  -- 71

UPDATE bobo.pages SET page_shortcut_icon = 'fa-regular fa-box-isometric' WHERE page_id = 27;


INSERT INTO bobo.group_pages
    (gr_id, page_id, gp_iud_grants)
VALUES
    ( 3, 71, '111'); -- Stanziamenti Strumenti


-- table bobo.menu_pages order by mp_id;

INSERT INTO bobo.menu_pages
    (mp_id, menu_id, page_id, mp_name, mp_path, mp_order)
VALUES
    (86, 1, null, 'Stanziamenti'                , 'sidebar1.stanziamenti'           ,  425 ),
    (87, 1, 71,   'Strumenti'                   , 'sidebar1.stanziamenti.strumenti' ,  426 );


INSERT INTO bobo.menu_css
    (mp_id, menu_css_class, menu_css_expanded, menu_css_icon, menu_css_blank)
VALUES
    (86, 'has-arrow waves-effect waves-dark', false , 'fa-light fa-cart-flatbed-boxes'                           , false ), -- Stanziamenti
    (87, null                               , false , null                                                       , false ); -- Strumenti


UPDATE bobo.menu_css SET menu_css_icon = 'fa-light fa-box-archive' WHERE mp_id = 33;


-- -----------------------------------------------------------------
-- New functionality: delete station's parameter
-- -----------------------------------------------------------------
SET ROLE user_admin;

CREATE OR REPLACE FUNCTION metadata.f_delete_station_parameter(
    stprid integer
)
  RETURNS smallint
  LANGUAGE 'plpgsql'
  SECURITY DEFINER
  VOLATILE
  COST 100
AS $BODY$
DECLARE
    q text; -- query
    t text; -- table
    i integer; -- measure id
BEGIN

    /**
     * Function that takes care of deleting a parameter linked to a station, all associated metadata and data in station's table.
     * The deletion is successful only if the parameter has no data in statistics tables and there is none
     * elements (instruments, dataset e1a / e2a) associated with it.
     *
     * The function is launched from the portal and is executed with the owner role (user_admin).
     *
     * TEST
     * SELECT metadata.f_delete_station_parameter(93::integer); -> -1 Foreign key violation
     */


    /* Get station fulltable name */
    SELECT
        station_schema ||'.'|| COALESCE(station_prefix, '')|| station_table, stpr_table_id INTO t,i
    FROM
        metadata.stations_parameters
        LEFT JOIN metadata.stations USING (station_id)
    WHERE stpr_id = stprid;

    /* Check if parameter exists else return generic error */
    IF NOT FOUND THEN
        RAISE NOTICE 'Parameter % not found!', stprid ;
        RETURN 0;
    END IF;

    /**
     * Delete metadata
     * -- OK
     * metadata.stations_params_status.metadata_stations_params_status_fkey1
     * metadata.stations_params_info.metadata_stations_params_info_fkey1
     * clients.stations_alarms.clients_stations_alarms_fkey3
     * clients.stations_param_limits.clients_stations_param_limits_fkey
     * clients.auto_validation_results.clients_auto_validation_results_fkey
     * -- NOT OK
     * metadata.stations_params_instruments.metadata_stations_params_instruments_fkey1
     * clients.final_validation_log.clients_final_validation_log_fk2
     * clients_stats.results.clients_stats_results_fkey1
     * clients_stats.report_results.clients_stats_report_results_fk1
     * infoaria.stations_params_e2a.infoaria_stations_params_e2a_fk1
     * infoaria.stations_params_info.infoaria_stations_params_info_fk1
     * infoaria.stations_params_status.infoaria_stations_params_status_fk1
     *
     */
    DELETE FROM clients.auto_validation_results WHERE stpr_id = stprid;
    DELETE FROM clients.stations_alarms WHERE stpr_id = stprid;
    DELETE FROM clients.stations_param_limits WHERE stpr_id = stprid;
    DELETE FROM metadata.stations_params_status WHERE stpr_id = stprid;
    DELETE FROM metadata.stations_params_info WHERE stpr_id = stprid;

    /**
     * Try to delete main element in metadata.stations_parameters
     * If any "foreign key violation" occurs then stop deletion and return error
     */
    DELETE FROM metadata.stations_parameters WHERE stpr_id = stprid;


    /* Delete data from table */
    q := 'DELETE FROM '||t||' WHERE measure_id = '||i;
    EXECUTE q;

    /* Return success*/
    RETURN 1;

    /* Errors check */
    EXCEPTION
    WHEN foreign_key_violation THEN
        -- in case of foreign key violation
        RAISE NOTICE 'ERROR IN metadata.f_delete_station_parameter() : %', SQLERRM ;
        RETURN -1;
    WHEN OTHERS THEN /* in case of any error */
        RAISE NOTICE 'ERROR IN metadata.f_delete_station_parameter() : %', SQLERRM ;
        RETURN 0;
END;

$BODY$;

GRANT EXECUTE ON FUNCTION  metadata.f_delete_station_parameter(integer) TO group_bobo;
GRANT EXECUTE ON FUNCTION  metadata.f_delete_station_parameter(integer) TO group_admin;
GRANT EXECUTE ON FUNCTION  metadata.f_delete_station_parameter(integer) TO group_tools;

COMMENT ON FUNCTION  metadata.f_delete_station_parameter(integer) IS '[BOBO] Function that removes a parameter associated to a station and all linked metadata';

RESET ROLE;

-- -----------------------------------------------------------------
-- Update "data extraction" function
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION clients.f_data_extraction(
    stprid bigint,
    date_from timestamp without time zone,
    date_to timestamp without time zone,
    aggregation metadata.e_aggregations DEFAULT 'hh'::metadata.e_aggregations,
    treatment metadata.e_treatments DEFAULT 'avg'::metadata.e_treatments,
    validity text DEFAULT '>= 0'::text
)
RETURNS SETOF clients.t_data_function 
LANGUAGE 'plpgsql'
COST 100
VOLATILE PARALLEL UNSAFE
ROWS 1000

AS $BODY$
    DECLARE
        t text;         -- tablename
        v text;         -- formatted validity
        p integer;      -- parameter table id
        i integer;      -- parameter id
        d integer;      -- parameter decimals
        y integer;      -- parameter type (10 = limite)
        f text;         -- when stprid < 0, mm locations interval
        q text;         -- dynamic query
    BEGIN

        /* entry */
        -- RAISE NOTICE 'Function clients.f_data_extraction, stpr_id: %', stprid;

        /* Testing
            SELECT * FROM  clients.f_data_extraction (
                571::integer,
                '2020-01-01 00:00'::timestamp,
                '2020-01-31 23:59'::timestamp,
                'hh'::metadata.e_aggregations,
                'avg'::metadata.e_treatments,
                '<= 4'::text
            );
        */
        f := '';
        
        /* get station properties */
        /* suffix in order to get data from a view es cc, labs */
        CASE
        WHEN stprid > 0 THEN
            SELECT
                station_fulltable||COALESCE( parameter_object->'general'->>'suffix', '' ) AS  station_fulltable, station_param_table_id, 10 AS parameter_decimals, parameter_type_id INTO t, p, d, y
            FROM
                metadata.view_stations_parameters
            WHERE
                station_param_id = stprid;
        ELSE
            SELECT
                station_fulltable||COALESCE( pm.pm_info_obj->'general'->>'suffix', '' ) AS  station_fulltable, stpr_table_id, 10 AS parameter_decimals, pm.pm_info_type_fk, 'AND t.measure_date_time <@ '''||stsi_period||'''::tsmultirange' INTO t, p, d, y, f
            FROM
               metadata.f_get_view_sites_parameters(stprid) tmp
               LEFT JOIN metadata.parameters_info pm USING (param_id)
            WHERE
                stpr_id = stprid;
        END CASE;

        -- RAISE NOTICE 'Function clients.f_data_extraction, tablename: %, parame id: %', t, p;

        SELECT
            CASE
                WHEN array_length(regexp_split_to_array(validity, ', '), 1) > 1 THEN '( main.signed_bitmask_toarray(t.post_validity_code::integer, 10 ) && ''{'||regexp_replace(validity, '= ', '', 'g')||'}''::integer[] )'
                ELSE 't.post_validity_code '|| validity
            END INTO v;

        -- RAISE NOTICE 'CHeck for validity code: %', v;

        /* build main dynamic query */
        q =
        'WITH m AS ('||E'\n'
        ||'    SELECT'||E'\n'
        ||'        ('||quote_literal(date_from)||'::timestamp + interval ''60 minute'' * s.a)::timestamp AS measure_date_time'||E'\n'
        ||'    FROM'||E'\n'
        ||'        generate_series(0,(EXTRACT(EPOCH FROM '||quote_literal(date_to)||'::timestamp'||E'\n'
        ||'        - '||quote_literal(date_from)||'::timestamp)/3600)::integer) AS s(a)'||E'\n'
        ||')'||E'\n\n';

        /* take care of aggregation time */
        CASE
            WHEN aggregation = 'hh'::metadata.e_aggregations THEN

                /* date time */
                q = q
                ||'SELECT'||E'\n'
                ||'    m.measure_date_time AS measure_date_time,'||E'\n';

                /* measures */
                q = q
                ||'    '||p||'::smallint AS measure_id,'||E'\n';

                /* take care of limits, alway 100% */
                IF y = 18 THEN
                    /*limit*/
                    q = q
                    ||'    0::numeric AS measure_value,'||E'\n'
                    ||'    0::numeric AS measure_min,'||E'\n'
                    ||'    0::numeric AS measure_max,'||E'\n'
                    ||'    100::smallint AS measure_perc,'||E'\n'
                    ||'    0::integer AS post_validity_code,'||E'\n'
                    ||'    0::smallint AS final_validity_code'||E'\n';
                ELSE
                    /*standard parameter*/
                    q = q
                    ||'    CASE WHEN '||v||' THEN t.measure_value::numeric END AS measure_value,'||E'\n'
                    ||'    CASE WHEN '||v||' THEN t.measure_min::numeric END AS measure_min,'||E'\n'
                    ||'    CASE WHEN '||v||' THEN t.measure_max::numeric END AS measure_max,'||E'\n'
                    -- modified 2025/08/04 16:11
                    ||'    CASE WHEN t.measure_value NOTNULL AND '||v||' THEN measure_perc::smallint END AS measure_perc,'||E'\n'
                    ||'    t.post_validity_code::integer   AS post_validity_code,'||E'\n'
                    ||'    t.final_validity_code::smallint AS final_validity_code'||E'\n';
                END IF;

                /* from clause */
                q = q
                ||'FROM'||E'\n'
                ||'    m LEFT JOIN '||t||' t ON (m.measure_date_time = t.measure_date_time AND t.measure_id = '||p||' '||f||')'||E'\n'
                ||'WHERE'||E'\n'
                ||'    m.measure_date_time BETWEEN '||quote_literal(date_from)||' AND '||quote_literal(date_to)||''||E'\n';

                /* order by */
                q = q
                ||'ORDER BY'||E'\n'
                ||'    measure_date_time'||E'\n';

            WHEN aggregation = 'dd'::metadata.e_aggregations THEN

                /* date time */
                q = q
                ||'SELECT'||E'\n'
                ||'    date_trunc(''day'', m.measure_date_time) AS measure_date_time,'||E'\n';

                /* measures */
                q = q
                ||'    max('||p||'::smallint) AS measure_id,'||E'\n';

                /* take care of limits, alway 100% */
                IF y = 18 THEN
                    /*limit*/
                    q = q
                    ||'    avg(0)::numeric AS measure_value,'||E'\n'
                    ||'    avg(0)::numeric AS measure_min,'||E'\n'
                    ||'    avg(0)::numeric AS measure_max,'||E'\n'
                    ||'    max(100)::smallint AS measure_perc,'||E'\n'
                    ||'    max(0)::integer AS post_validity_code,'||E'\n'
                    ||'    max(0)::smallint AS final_validity_code'||E'\n';
                ELSE
                    /*standard parameter*/
                    q = q
                    ||'    round('||treatment||'(CASE WHEN '||v||' THEN t.measure_value::numeric END), '||d||') AS measure_value,'||E'\n'
                    ||'    round( min(CASE WHEN '||v||' THEN t.measure_min::numeric END), '||d||') AS measure_min,'||E'\n'
                    ||'    round( max(CASE WHEN '||v||' THEN t.measure_max::numeric END), '||d||') AS measure_max,'||E'\n'
                    ||'    (sum(CASE WHEN t.measure_value NOTNULL AND '||v||' THEN t.extract_code ELSE 0::smallint END)/24::real*100)::smallint AS measure_perc,'||E'\n'
                    ||'    max( t.post_validity_code::integer ) AS post_validity_code,'||E'\n'
                    ||'    max( t.final_validity_code::smallint ) AS final_validity_code'||E'\n';
                END IF;

                /* from clause */
                q = q
                ||'FROM'||E'\n'
                ||'    m LEFT JOIN '||t||' t ON (m.measure_date_time = t.measure_date_time AND t.measure_id = '||p||' '||f||')'||E'\n'
                ||'WHERE'||E'\n'
                ||'    m.measure_date_time BETWEEN '||quote_literal(date_from)||' AND '||quote_literal(date_to)||''||E'\n';

                /* order by */
                q = q
                ||'GROUP BY 1'||E'\n'
                ||'ORDER BY 1'||E'\n';

            WHEN aggregation = 'mm'::metadata.e_aggregations THEN

                /* date time */
                q = q
                ||'SELECT'||E'\n'
                ||'    date_trunc(''month'', m.measure_date_time) AS measure_date_time,'||E'\n';

                /* measures */
                q = q
                ||'    max('||p||'::smallint) AS measure_id,'||E'\n';

                /* take care of limits, alway 100% */
                IF y = 18 THEN
                    /*limit*/
                    q = q
                    ||'    avg(0)::numeric AS measure_value,'||E'\n'
                    ||'    avg(0)::numeric AS measure_min,'||E'\n'
                    ||'    avg(0)::numeric AS measure_max,'||E'\n'
                    ||'    max(100)::smallint AS measure_perc,'||E'\n'
                    ||'    max(0)::integer AS post_validity_code,'||E'\n'
                    ||'    max(0)::smallint AS final_validity_code'||E'\n';
                ELSE
                    /*standard parameter*/
                    q = q
                    ||'    round('||treatment||'(CASE WHEN '||v||' THEN t.measure_value::numeric END), '||d||') AS measure_value,'||E'\n'
                    ||'    round( min(CASE WHEN '||v||' THEN t.measure_min::numeric END), '||d||') AS measure_min,'||E'\n'
                    ||'    round( max(CASE WHEN '||v||' THEN t.measure_max::numeric END), '||d||') AS measure_max,'||E'\n'
                    ||'    (sum(CASE WHEN t.measure_value NOTNULL AND '||v||' THEN t.extract_code ELSE 0::smallint END)/('||E'\n'
                    ||'    24 * max(extract(days FROM date_trunc(''month'', m.measure_date_time) + interval ''1 month - 1 day''))'||E'\n'
                    ||'    )::real*100)::smallint AS measure_perc,'||E'\n'
                    ||'    max( t.post_validity_code::integer ) AS post_validity_code,'||E'\n'
                    ||'    max( t.final_validity_code::smallint ) AS final_validity_code'||E'\n';

                END IF;

                /* from clause */
                q = q
                ||'FROM'||E'\n'
                ||'    m LEFT JOIN '||t||' t ON (m.measure_date_time = t.measure_date_time AND t.measure_id = '||p||' '||f||')'||E'\n'
                ||'WHERE'||E'\n'
                ||'    m.measure_date_time BETWEEN '||quote_literal(date_from)||' AND '||quote_literal(date_to)||''||E'\n';

                /* order by */
                q = q
                ||'GROUP BY 1'||E'\n'
                ||'ORDER BY 1'||E'\n';

            WHEN aggregation = 'yy'::metadata.e_aggregations THEN

                /* date time */
                q = q
                ||'SELECT'||E'\n'
                ||'    date_trunc(''year'', m.measure_date_time) AS measure_date_time,'||E'\n';

                /* measures */
                q = q
                ||'    max('||p||'::smallint) AS measure_id,'||E'\n';

                /* take care of limits, alway 100% */
                IF y = 18 THEN
                    q = q
                    ||'    avg(0)::numeric AS measure_value,'||E'\n'
                    ||'    avg(0)::numeric AS measure_min,'||E'\n'
                    ||'    avg(0)::numeric AS measure_max,'||E'\n'
                    ||'    max(100)::smallint AS measure_perc,'||E'\n'
                    ||'    max(0)::integer AS post_validity_code,'||E'\n'
                    ||'    max(0)::smallint AS final_validity_code'||E'\n';
                ELSE
                    /*standard parameter*/
                    q = q
                    ||'    round('||treatment||'(CASE WHEN '||v||' THEN t.measure_value::numeric END), '||d||') AS measure_value,'||E'\n'
                    ||'    round(min (CASE WHEN '||v||' THEN t.measure_min::numeric END), '||d||') AS measure_min,'||E'\n'
                    ||'    round(max (CASE WHEN '||v||' THEN t.measure_max::numeric END), '||d||') AS measure_max,'||E'\n'
                    ||'    (sum(CASE WHEN t.measure_value NOTNULL AND '||v||' THEN t.extract_code ELSE 0::smallint END)/('||E'\n'
                    ||'    24 * DATE_PART(''day'', date_trunc(''year'', now()) + interval ''1 year - 1 day'' - date_trunc(''year'', now()))'||E'\n'
                    ||'    )::real*100)::smallint AS measure_perc,'||E'\n'
                    ||'    max( t.post_validity_code::integer ) AS post_validity_code,'||E'\n'
                    ||'    max( t.final_validity_code::smallint ) AS final_validity_code'||E'\n';
                END IF;

                /* from clause */
                q = q
                ||'FROM'||E'\n'
                ||'    m LEFT JOIN '||t||' t ON (m.measure_date_time = t.measure_date_time AND t.measure_id = '||p||' '||f||')'||E'\n'
                ||'WHERE'||E'\n'
                ||'    m.measure_date_time BETWEEN '||quote_literal(date_from)||' AND '||quote_literal(date_to)||''||E'\n';

                /* order by */
                q = q
                ||'GROUP BY 1'||E'\n'
                ||'ORDER BY 1'||E'\n';

            ELSE

        END CASE;

        /* notice */
        -- RAISE NOTICE 'Query: %', E'\n'||q;

        /* return value */
        RETURN QUERY EXECUTE q;

    /* errors check */
    EXCEPTION
        WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_data_extraction(): %', SQLERRM;
    END;
        
    
$BODY$;



-- -----------------------------------------------------------------
-- New functionality: table holding realtime readings
-- -----------------------------------------------------------------
-- DROP TABLE IF EXISTS template.readings;
CREATE TABLE IF NOT EXISTS template.readings
(
    measure_date_time   timestamp without time zone NOT NULL,
    measure_id          integer NOT NULL,
    measure_value       numeric NOT NULL,
    measure_code        integer DEFAULT 0,
    CONSTRAINT template_readings_pkey PRIMARY KEY (measure_date_time, measure_id)
);

GRANT ALL ON TABLE template.readings TO group_admin;
GRANT ALL ON TABLE template.readings TO group_bobo;
GRANT ALL ON TABLE template.readings TO group_tools;
GRANT SELECT ON TABLE template.readings TO group_readonly;

COMMENT ON TABLE  template.readings                     IS '[OPAS] Table holding pollutants readings with "1 minute" cadence';
COMMENT ON COLUMN template.readings.measure_date_time   IS 'Measure date and time';
COMMENT ON COLUMN template.readings.measure_id          IS 'Measure id';
COMMENT ON COLUMN template.readings.measure_value       IS 'Measure value';
COMMENT ON COLUMN template.readings.measure_code        IS 'Measure general code';


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


DROP FUNCTION template.f_create_table_like_template(integer,text,boolean);
CREATE OR REPLACE FUNCTION template.f_create_table_like_template(
    stid    integer,
    temp    text,
    drop    boolean
)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    -- variables
    t   text; -- fulltable
    q   text; -- query

BEGIN

    -- TEST
    -- SELECT template.f_create_table_like_template(1000::integer, 'opas'::text, false);

    SELECT station_fulltable INTO t
    FROM metadata.view_stations_info
    WHERE station_id = stid;

    IF NOT FOUND THEN
        RAISE NOTICE 'Station % not found!', stid;
        RETURN NULL;
    END IF;

    RAISE NOTICE 'Table name : %', t;


    IF temp = 'opas' THEN
        IF drop IS TRUE THEN
            RAISE NOTICE 'Drop station % if exists!', t;
            q = 'DROP TABLE IF EXISTS '|| t ||';';

            EXECUTE q;
        END IF;

        q = 'CREATE TABLE '|| t ||' (LIKE template.'||quote_ident(temp)||' INCLUDING ALL);';
        RAISE NOTICE 'Query : %', q;

        EXECUTE q;

        q = 'GRANT ALL ON TABLE    '|| t ||' TO group_admin;   '
          ||'GRANT ALL ON TABLE    '|| t ||' TO group_bobo;    '
          ||'GRANT ALL ON TABLE    '|| t ||' TO group_tools;   '
          ||'GRANT SELECT ON TABLE '|| t ||' TO group_readonly;'
          ||'GRANT INSERT ON TABLE '|| t ||' TO user_swam;';

        RAISE NOTICE 'Add grants';
        EXECUTE q;

    ELSIF temp = 'realtime' THEN

        IF drop IS TRUE THEN
        
            RAISE NOTICE 'Drop station %_inst if exists!', t;
            q = 'DROP TABLE IF EXISTS '|| t ||'_inst;';

            EXECUTE q;
        END IF;

        q = 'CREATE TABLE '|| t ||'_inst (LIKE template.'||quote_ident(temp)||' INCLUDING ALL);';
        RAISE NOTICE 'Query : %', q;

        EXECUTE q;

        q = 'GRANT SELECT ON TABLE '|| t || '_inst TO group_admin;   '
          ||'GRANT SELECT ON TABLE '|| t || '_inst TO group_bobo;    '
          ||'GRANT ALL    ON TABLE '|| t || '_inst TO group_tools;   '
          ||'GRANT SELECT ON TABLE '|| t || '_inst TO group_readonly;';

        RAISE NOTICE 'Add grants';
        EXECUTE q;

    ELSIF temp = 'readings' THEN

        IF drop IS TRUE THEN
            RAISE NOTICE 'Drop station %_rdns if exists!', t;
            q = 'DROP TABLE IF EXISTS '|| t ||'_rdns;';

            EXECUTE q;
        END IF;

        q = 'CREATE TABLE '|| t || '_rdns (LIKE template.'||quote_ident(temp)||' INCLUDING ALL);';
        RAISE NOTICE 'Query : %', q;

        EXECUTE q;

        q = 'GRANT SELECT ON TABLE '|| t ||'_rdns TO group_admin;   '
          ||'GRANT SELECT ON TABLE '|| t ||'_rdns TO group_bobo;    '
          ||'GRANT ALL    ON TABLE '|| t ||'_rdns TO group_tools;   '
          ||'GRANT SELECT ON TABLE '|| t ||'_rdns TO group_readonly;';

        RAISE NOTICE 'Add grants';
        EXECUTE q;

    END IF;

    RETURN TRUE;

    /* errors check */
    EXCEPTION
    WHEN OTHERS THEN /* in case of any error */
        RAISE NOTICE 'ERROR IN template.f_create_table_like_template() : %', SQLERRM ;
        RETURN FALSE;
END;
$BODY$;


CREATE OR REPLACE FUNCTION clients.f_create_bcbb_bcff_trigger(
    stid integer
)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
DECLARE
    -- variables
    s text; -- schema
    t text; -- table
    q text; -- query

BEGIN
    /**
    * The function is called manually by operator in order to taking care of BC instrument.
    * It creates the trigger that calculates BCBB and BCFF values based on the BC value and inserts them into the station's table.
    */

    RAISE NOTICE 'Creating trigger for station ID: %', stid;

    /* Select schema, table name and roaming type */
    SELECT station_schema, station_table INTO s,t
    FROM metadata.stations
    WHERE station_id = stid;

    IF NOT FOUND THEN
        RAISE NOTICE 'Station % not found!', stid;
        RETURN NULL;
    END IF;

    -- BCBB BCFF
    q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_bcbb_bcff_aiau '
        ||'AFTER INSERT OR UPDATE OF measure_value '
        ||'ON '||s||'.'||t||' '
        ||'FOR EACH ROW '
        ||'WHEN (pg_trigger_depth() = 0) '
        ||'EXECUTE FUNCTION clients.f_calculate_bcbb_bcff('||quote_literal(stid)||'); ';

    EXECUTE q;

    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR IN clients.f_create_bcbb_bcff_trigger(integer) : %', SQLERRM;
        RETURN FALSE;
END;
$BODY$;


GRANT EXECUTE ON FUNCTION clients.f_create_bcbb_bcff_trigger(integer) TO group_admin;
GRANT EXECUTE ON FUNCTION clients.f_create_bcbb_bcff_trigger(integer) TO group_bobo;
GRANT EXECUTE ON FUNCTION clients.f_create_bcbb_bcff_trigger(integer) TO group_tools;
GRANT EXECUTE ON FUNCTION clients.f_create_bcbb_bcff_trigger(integer) TO group_readonly;

-- Funzione che calcola Biomass Burning e Fossil Fuel partendo dai valori di BC03 e BC10
-- DROP FUNCTION IF EXISTS clients.f_calculate_bcbb_bcff();
CREATE OR REPLACE FUNCTION clients.f_calculate_bcbb_bcff()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
    DECLARE

        stid integer;

        /* static values */
        bc03_prid integer = 559;
        bc10_prid integer = 566;
        bcbb_prid integer = 1127;
        bcff_prid integer = 1128;

        d smallint = 4; -- decimals

        /*dynamic value*/
        bc03_id integer;
        bc10_id integer;
        bcbb_id integer;
        bcff_id integer;

        bc03 numeric;
        bc10 numeric;
        bcbb numeric;
        bcff numeric;

        q text; -- dynamic query

    BEGIN

        -- station id passed by caller
        stid := TG_ARGV[0];

        RAISE NOTICE 'Trigger clients.f_calculate_bcbb_bcff( )';

        /* retrieve table id for all involved parameters */
        SELECT stpr_table_id INTO bc03_id FROM metadata.stations_parameters WHERE station_id = stid AND param_id = bc03_prid;
        SELECT stpr_table_id INTO bc10_id FROM metadata.stations_parameters WHERE station_id = stid AND param_id = bc10_prid;
        SELECT stpr_table_id INTO bcbb_id FROM metadata.stations_parameters WHERE station_id = stid AND param_id = bcbb_prid;
        SELECT stpr_table_id INTO bcff_id FROM metadata.stations_parameters WHERE station_id = stid AND param_id = bcff_prid;

        /* Check if B03 AND BC10 exist */
        IF bc03_id IS NULL OR bc10_id IS NULL THEN
            RAISE NOTICE 'BC3 OR BC10 are not present in this station';
            RETURN NEW;
        END IF;

        -- RAISE NOTICE 'BC3 and BC10 FOUND!';

        /* Check if BC_BB AND BC_FF exist */
        IF bcbb_id IS NULL OR bcff_id IS NULL THEN
            RAISE NOTICE 'BC_BB OR BC_FF are not present in this station';
            RETURN NEW;
        END IF;

        -- RAISE NOTICE 'BC_BB and BC_FF FOUND!';

        /* Continue only if BC3 or BC10 have been updated */
        IF NEW.measure_id NOT IN (bc03_id, bc10_id) THEN
            RAISE NOTICE 'Nothing to do';
            RETURN NEW;
        END IF;

        /* retrieve BC03 measure value */
        EXECUTE 'SELECT measure_value FROM '|| CONCAT_WS('.', TG_TABLE_SCHEMA, TG_TABLE_NAME ) ||' WHERE measure_date_time = '|| quote_literal(NEW.measure_date_time) ||' AND measure_id = '|| bc03_id ||';' INTO bc03;

        /* retrieve BC10 measure value */
        EXECUTE 'SELECT measure_value FROM '|| CONCAT_WS('.', TG_TABLE_SCHEMA, TG_TABLE_NAME ) ||' WHERE measure_date_time = '|| quote_literal(NEW.measure_date_time) ||' AND measure_id = '|| bc10_id ||';' INTO bc10;

        -- RAISE NOTICE 'BC3 value: %', bc03;
        -- RAISE NOTICE 'BC10 value: %', bc10;

        IF ROW(bc03, bc10) IS NOT NULL THEN

            /**
             * Calculate new measure_value for BC_BB
             * BC_BB = ((BC3*14,55)-(BC10*13,5642))/9,9204
             */
            bcbb := ROUND( ( ((bc03 * 14.55)-(bc10 * 13.5642))/9.9204 )::numeric, d);

            /**
             * Calculate new measure_value for BC_BB
             * BC_FF = ((BC3*14,55)-(BC10*23,4846))/-9,9204
             */
            bcff = ROUND( ( ((bc03 * 14.55)-(bc10 * 23.4846))/(-9.9204) )::numeric, d);

            -- RAISE NOTICE 'BCBB value: %', bcbb;
            -- RAISE NOTICE 'BCFF value: %', bcff;

            IF bcbb NOTNULL THEN
                /* execute the update query */
                q = 'INSERT INTO '|| CONCAT_WS('.', TG_TABLE_SCHEMA, TG_TABLE_NAME ) ||' '||E'\n'
                ||'    (measure_date_time, measure_id, measure_value)'||E'\n'
                ||'VALUES  '||E'\n'
                ||'    ('||quote_literal(NEW.measure_date_time)||', '||bcbb_id||', '||bcbb||') '||E'\n'
                ||'ON CONFLICT (measure_date_time, measure_id) '||E'\n'
                ||'    DO UPDATE SET '||E'\n'
                ||'        measure_value = EXCLUDED.measure_value; '||E'\n';

                -- RAISE NOTICE 'First query: %', q;
                EXECUTE q;

            END IF;

            IF bcff NOTNULL THEN
                /* execute the update query */
                q = 'INSERT INTO '|| CONCAT_WS('.', TG_TABLE_SCHEMA, TG_TABLE_NAME ) ||' '||E'\n'
                ||'    (measure_date_time, measure_id, measure_value)'||E'\n'
                ||'VALUES  '||E'\n'
                ||'    ('||quote_literal(NEW.measure_date_time)||', '||bcff_id||', '||bcff||') '||E'\n'
                ||'ON CONFLICT (measure_date_time, measure_id) '||E'\n'
                ||'    DO UPDATE SET '||E'\n'
                ||'        measure_value = EXCLUDED.measure_value; '||E'\n';

                -- RAISE NOTICE 'Second query: %', q;
                EXECUTE q;

            END IF;

        -- ELSE
            -- RAISE NOTICE 'Something NULL';

        END IF;

        /* return from function */
        RETURN NEW;

        EXCEPTION
        WHEN insufficient_privilege THEN
            RETURN NEW;
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR IN clients.f_calculate_bcbb_bcff() : %', SQLERRM ;
            /* return from function */
            RETURN NEW;
    END;
$BODY$;


GRANT EXECUTE ON FUNCTION clients.f_calculate_bcbb_bcff() TO group_admin;
GRANT EXECUTE ON FUNCTION clients.f_calculate_bcbb_bcff() TO group_bobo;
GRANT EXECUTE ON FUNCTION clients.f_calculate_bcbb_bcff() TO group_tools;

COMMENT ON FUNCTION clients.f_calculate_bcbb_bcff()
    IS 'Function for calculating Biomass Burning and Fossil Fuel values starting from BC03 and BC10 values';

