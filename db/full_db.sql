-- +----------------------------------------------------------------------------------------------+
-- | - Script Name   : full_db.sql                                                                |
-- | - Author        : Ecometer s.n.c.                                                            |
-- | - Creation Date : 2025-03-31                                                                 |
-- | - Description   : Script to create PostgreSQL 'opas' database full structure.                |
-- +----------------------------------------------------------------------------------------------+


-- before schemas...

    -- --------------------------------------------------------------------------------------------
    -- EXTENSIONS AND TYPES
    -- --------------------------------------------------------------------------------------------
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS btree_gist;
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    CREATE EXTENSION IF NOT EXISTS ltree;
    CREATE EXTENSION IF NOT EXISTS tablefunc;
    CREATE EXTENSION IF NOT EXISTS intarray;
    CREATE EXTENSION IF NOT EXISTS citext;
    CREATE DOMAIN email AS citext
    CHECK ( value ~ '^[a-zA-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$' );
    CREATE TYPE bobo_nav AS ENUM ('sidebarnav', 'usernav', 'notesnav');
    CREATE TYPE status AS ENUM ('taken charge', 'closed', 'rejected');

    CREATE OR REPLACE FUNCTION public.first_agg (anyelement, anyelement)
    RETURNS anyelement
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS
    'SELECT $1';

    CREATE AGGREGATE public.first(anyelement) (
    SFUNC = public.first_agg
    , STYPE = anyelement
    , PARALLEL = safe
    );

    CREATE OR REPLACE FUNCTION public.last_agg (anyelement, anyelement)
    RETURNS anyelement
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS
    'SELECT $2';

    CREATE AGGREGATE public.last(anyelement) (
    SFUNC = public.last_agg
    , STYPE = anyelement
    , PARALLEL = safe
    );

-- SCHEMA main

    -- DROP SCHEMA IF EXISTS main CASCADE;
    CREATE SCHEMA main
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA main TO group_admin;
    GRANT USAGE ON SCHEMA main TO group_bobo;
    GRANT USAGE ON SCHEMA main TO group_readonly;
    GRANT USAGE ON SCHEMA main TO group_tools;
    COMMENT ON SCHEMA main IS 'Main schema for OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella che contiene le informazioni relative ai comuni d'Italia
    -- DROP TABLE IF EXISTS main.municipalities;
    CREATE TABLE main.municipalities
    (
        mu_id           serial NOT NULL,
        mu_name         text NOT NULL,
        mu_istat_code   text DEFAULT NULL,
        mu_catasto_code text DEFAULT NULL,
        mu_cap          text DEFAULT NULL,
        mu_note         text DEFAULT NULL,

        CONSTRAINT main_municipalities_pkey PRIMARY KEY (mu_id)
    ) WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    main.municipalities TO group_admin;
    GRANT ALL ON TABLE    main.municipalities TO group_bobo;
    GRANT ALL ON TABLE    main.municipalities TO group_tools;
    GRANT SELECT ON TABLE main.municipalities TO group_readonly;

    -- comments
    COMMENT ON TABLE  main.municipalities                 IS 'Table with principal information about stations';
    COMMENT ON COLUMN main.municipalities.mu_id           IS 'Municipality id';
    COMMENT ON COLUMN main.municipalities.mu_name         IS 'Municipality name';
    COMMENT ON COLUMN main.municipalities.mu_istat_code   IS 'Municipality ISTAT code';
    COMMENT ON COLUMN main.municipalities.mu_catasto_code IS 'Municipality catasto code';
    COMMENT ON COLUMN main.municipalities.mu_cap          IS 'Municipality CAP';
    COMMENT ON COLUMN main.municipalities.mu_note         IS 'Municipality note';

    -- Tabella che contiene le informazioni relative alle province d'Italia
    -- DROP TABLE IF EXISTS main.provinces;
    CREATE TABLE main.provinces
    (
        province_id         serial NOT NULL,
        province_name       text NOT NULL,
        province_istat_code text DEFAULT NULL,
        province_code       text DEFAULT NULL,
        province_note       text DEFAULT NULL,

        CONSTRAINT main_provinces_pkey PRIMARY KEY (province_id)
    ) WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    main.provinces TO group_admin;
    GRANT ALL ON TABLE    main.provinces TO group_bobo;
    GRANT ALL ON TABLE    main.provinces TO group_tools;
    GRANT SELECT ON TABLE main.provinces TO group_readonly;

    -- comments
    COMMENT ON TABLE  main.provinces                     IS 'Table with principal information about stations';
    COMMENT ON COLUMN main.provinces.province_id         IS 'Province id';
    COMMENT ON COLUMN main.provinces.province_name       IS 'Province name';
    COMMENT ON COLUMN main.provinces.province_istat_code IS 'Province ISTAT code';
    COMMENT ON COLUMN main.provinces.province_code       IS 'Province cars code';
    COMMENT ON COLUMN main.provinces.province_note       IS 'Province province';

    -- Tabella che contiene le informazioni relative alle regioni d'Italia
    -- DROP TABLE IF EXISTS main.regions;
    CREATE TABLE main.regions
    (
        region_id         integer NOT NULL,
        region_name       text NOT NULL,
        region_istat_code text DEFAULT NULL,
        region_note       text DEFAULT NULL,

        CONSTRAINT main_regions_pkey PRIMARY KEY (region_id)
    ) WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    main.regions TO group_admin;
    GRANT ALL ON TABLE    main.regions TO group_bobo;
    GRANT ALL ON TABLE    main.regions TO group_tools;
    GRANT SELECT ON TABLE main.regions TO group_readonly;

    -- comments
    COMMENT ON TABLE  main.regions                   IS 'Table with principal information about regions';
    COMMENT ON COLUMN main.regions.region_id         IS 'Region id';
    COMMENT ON COLUMN main.regions.region_name       IS 'Region name';
    COMMENT ON COLUMN main.regions.region_istat_code IS 'Region ISTAT code';
    COMMENT ON COLUMN main.regions.region_note       IS 'Region note';

    -- Tabella che contiene le informazioni relative alle associazioni provincia - comuni
    -- DROP TABLE IF EXISTS main.province_municipalities;
    CREATE TABLE main.province_municipalities
    (
        pm_id       serial NOT NULL,
        province_id integer,
        mu_id       integer,

        CONSTRAINT main_province_municipalities_pkey PRIMARY KEY (pm_id)
        -- CONSTRAINT main_province_municipalities_fk1 FOREIGN KEY (province_id)
        --     REFERENCES main.provinces (province_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT main_province_municipalities_fk2 FOREIGN KEY (mu_id)
        --     REFERENCES main.municipalities (mu_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    ) WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    main.province_municipalities TO group_admin;
    GRANT ALL ON TABLE    main.province_municipalities TO group_bobo;
    GRANT ALL ON TABLE    main.province_municipalities TO group_tools;
    GRANT SELECT ON TABLE main.province_municipalities TO group_readonly;

    -- comments
    COMMENT ON TABLE  main.province_municipalities             IS 'Table with relation between provinces and municipalities';
    COMMENT ON COLUMN main.province_municipalities.pm_id       IS 'Province municipalities relation id';
    COMMENT ON COLUMN main.province_municipalities.province_id IS 'Province id';
    COMMENT ON COLUMN main.province_municipalities.mu_id       IS 'Municipality id';

    -- Tabella che contiene le informazioni relative alle associazioni regione - province
    -- DROP TABLE IF EXISTS main.region_provinces;
    CREATE TABLE main.region_provinces
    (
        rp_id       serial NOT NULL,
        region_id   integer,
        province_id integer,

        CONSTRAINT main_region_provinces_pkey PRIMARY KEY (rp_id)
        -- CONSTRAINT main_region_provinces_fk1 FOREIGN KEY (region_id)
        --     REFERENCES main.regions (region_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT main_region_provinces_fk2 FOREIGN KEY (province_id)
        --     REFERENCES main.provinces (province_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    ) WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    main.region_provinces TO group_admin;
    GRANT ALL ON TABLE    main.region_provinces TO group_bobo;
    GRANT ALL ON TABLE    main.region_provinces TO group_tools;
    GRANT SELECT ON TABLE main.region_provinces TO group_readonly;

    -- comments
    COMMENT ON TABLE  main.region_provinces             IS 'Table with relation between regions and provinces';
    COMMENT ON COLUMN main.region_provinces.rp_id       IS 'Region provinces relation id';
    COMMENT ON COLUMN main.region_provinces.region_id   IS 'Region id';
    COMMENT ON COLUMN main.region_provinces.province_id IS 'Province id';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- Vista che raccoglie le informazioni relative ai comuni
    -- DROP VIEW IF EXISTS main.view_municipalities;
    CREATE VIEW main.view_municipalities AS
    SELECT
        m.mu_id               AS mu_id,
        m.mu_name             AS mu_name,
        m.mu_istat_code       AS mu_istat_code,
        m.mu_catasto_code     AS mu_catasto_code,
        m.mu_cap              AS mu_cap,
        m.mu_note             AS mu_note,
        p.province_id         AS province_id,
        p.province_name       AS province_name,
        p.province_istat_code AS province_istat_code,
        p.province_code       AS province_code,
        p.province_note       AS province_note,
        r.region_id           AS region_id,
        r.region_name         AS region_name,
        r.region_istat_code   AS region_istat_code,
        r.region_note         AS region_note
    FROM
        main.municipalities m
        LEFT JOIN main.province_municipalities pm USING (mu_id)
        LEFT JOIN main.provinces p USING (province_id)
        LEFT JOIN main.region_provinces rp USING (province_id)
        LEFT JOIN main.regions r USING (region_id)
    ORDER BY m.mu_name;

    -- grants
    GRANT ALL ON TABLE    main.view_municipalities TO group_admin;
    GRANT ALL ON TABLE    main.view_municipalities TO group_bobo;
    GRANT ALL ON TABLE    main.view_municipalities TO group_tools;
    GRANT SELECT ON TABLE main.view_municipalities TO group_readonly;

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Calculate the greatest power of 2 contained in an integer
    -- DROP FUNCTION test.bitmask_greater(integer, integer);
    CREATE OR REPLACE FUNCTION main.bitmask_greater(
        integer,
        integer)
        RETURNS integer
        LANGUAGE 'plpgsql'

        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        original_num ALIAS FOR $1;
        max_code     ALIAS FOR $2;
        greater_res  INTEGER;
    BEGIN
        -- Test
        -- SELECT test.bitmask_greater(5, 1024);
        greater_res := 0;

        LOOP
            IF max_code = 0 THEN
                EXIT;
            END IF;


            IF (original_num / max_code) = 1 THEN
                greater_res := max_code;
                EXIT;
            END IF;

            max_code := max_code / 2;

        END LOOP;

        RETURN greater_res;

        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN
        RAISE NOTICE 'ERROR IN main.bitmask_greater() : %', SQLERRM ;
        RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION main.bitmask_greater(integer, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION main.bitmask_greater(integer, integer) TO group_tools;
    GRANT EXECUTE ON FUNCTION main.bitmask_greater(integer, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION main.bitmask_greater(integer, integer) TO group_readonly;

    -- comment
    COMMENT ON FUNCTION main.bitmask_greater(integer, integer)
        IS 'Calculate the greatest power of 2 contained in an integer';

    -- Convert an integer to array of powers of 2
    -- DROP FUNCTION main.bitmask_toarray(integer, integer);
    CREATE OR REPLACE FUNCTION main.bitmask_toarray(
        integer,
        integer)
        RETURNS integer[]
        LANGUAGE 'plpgsql'

        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        original_num ALIAS FOR $1;
        counter      ALIAS FOR $2;
        bin_power    INTEGER;
        array_res    INTEGER[];
    BEGIN
        -- Test
        -- SELECT test.bitmask_toarray(735, 10);
        LOOP
            IF counter = -1 THEN
                EXIT;  -- exit loop
            END IF;

            bin_power := POWER(2, counter);
            --RAISE NOTICE 'Potenza di 2: %', bin_power;

            IF (original_num / bin_power) = 1 THEN

                array_res := array_append(array_res, bin_power);
                original_num := original_num % bin_power ;
                --RAISE NOTICE 'Array: %', array_res;
            END IF;

            counter := counter - 1;
        END LOOP;

        RETURN array_res;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN
            RAISE NOTICE 'ERROR IN main.bitmask_toarray() : %', SQLERRM ;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION main.bitmask_toarray(integer, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION main.bitmask_toarray(integer, integer) TO group_tools;
    GRANT EXECUTE ON FUNCTION main.bitmask_toarray(integer, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION main.bitmask_toarray(integer, integer) TO group_readonly;

    -- comment
    COMMENT ON FUNCTION main.bitmask_toarray(integer, integer)
        IS 'Convert an integer to array of powers of 2';

    -- Convert a bigint to array of powers of 2
    -- DROP FUNCTION main.bitmask_toarray(integer, integer);
    CREATE OR REPLACE FUNCTION main.bitmask_toarray(
        bigint,
        integer)
        RETURNS bigint[]
        LANGUAGE 'plpgsql'

        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        original_num ALIAS FOR $1;
        counter      ALIAS FOR $2;
        bin_power    BIGINT;
        array_res    BIGINT[];
    BEGIN
        -- Test
        -- SELECT main.bitmask_toarray(18056398249482123, 60);
        LOOP
            IF counter = -1 THEN
                EXIT;  -- exit loop
            END IF;

            bin_power := POWER(2, counter);
            --RAISE NOTICE 'Potenza di 2: %', bin_power;

            IF (original_num / bin_power) = 1 THEN

                array_res := array_append(array_res, bin_power);
                original_num := original_num % bin_power ;
                --RAISE NOTICE 'Array: %', array_res;
            END IF;

            counter := counter - 1;
        END LOOP;

        RETURN array_res;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN
            RAISE NOTICE 'ERROR IN main.bitmask_toarray() : %', SQLERRM ;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION main.bitmask_toarray(bigint, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION main.bitmask_toarray(bigint, integer) TO group_tools;
    GRANT EXECUTE ON FUNCTION main.bitmask_toarray(bigint, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION main.bitmask_toarray(bigint, integer) TO group_readonly;

    -- comment
    COMMENT ON FUNCTION main.bitmask_toarray(bigint, integer)
        IS 'Convert a bigint to array of powers of 2';

    -- Funzione che recupera il numero di giorni di un determinato mese
    -- DROP FUNCTION IF EXISTS main.f_num_days_inmonth(integer, integer);
    CREATE OR REPLACE FUNCTION main.f_num_days_inmonth(int, int) RETURNS float8 AS -- years, months
        'SELECT date_part(''day'',
            (($1::text || ''-'' || $2::text || ''-01'')::date
                + ''1 month''::interval
                - ''1 day''::interval)) AS days'
    LANGUAGE 'sql';

    -- DROP FUNCTION IF EXISTS main.signed_bitmask_toarray(integer, integer);
    CREATE OR REPLACE FUNCTION main.signed_bitmask_toarray(
        integer,
        integer)
        RETURNS integer[]
        LANGUAGE 'plpgsql'

        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        original_num ALIAS FOR $1;
        counter      ALIAS FOR $2;
        negative     BOOLEAN;
        bin_power    INTEGER;
        array_res    INTEGER[];
    BEGIN
        -- Test
        -- SELECT main.signed_bitmask_toarray(735, 10);

        -- codice validità = 0
        IF original_num = 0 THEN
            array_res := array_append(array_res, 0);
            RETURN array_res;
        END IF;

        -- faccio il modulo
        IF original_num < 0 THEN
            original_num := original_num * -1;
            negative := TRUE;
        END IF;

        LOOP
            IF counter = -1 THEN
                EXIT;  -- exit loop
            END IF;

            bin_power := POWER(2, counter);
            --RAISE NOTICE 'Potenza di 2: %', bin_power;

            IF (original_num / bin_power) = 1 THEN

                original_num := original_num % bin_power ;

                IF negative IS TRUE THEN
                    bin_power := bin_power * -1;
                END IF;

                array_res := array_append(array_res, bin_power);

                --RAISE NOTICE 'Array: %', array_res;
            END IF;

            counter := counter - 1;
        END LOOP;

        RETURN array_res;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN
            RAISE NOTICE 'ERROR IN main.signed_bitmask_toarray() : %', SQLERRM ;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION main.signed_bitmask_toarray(integer, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION main.signed_bitmask_toarray(integer, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION main.signed_bitmask_toarray(integer, integer) TO group_tools;

    -- Function that calculates AND between 2 signed integers
    -- DROP FUNCTION IF EXISTS main.signed_integer_and(integer, integer);
    CREATE OR REPLACE FUNCTION main.signed_integer_and(
        left_arg  integer,
        right_arg integer
    )
    RETURNS integer AS

    $BODY$

    DECLARE
        -- variables
        left_arg_bit  bit(16);
        right_arg_bit bit(16);

        result_bit    bit(16);
        result        integer;
    BEGIN

        -- TEST
        -- SELECT main.signed_integer_or(-4::integer, -8::integer);
        IF left_arg >= 0 AND right_arg < 0 THEN
            RETURN right_arg;
        ELSIF left_arg < 0 AND right_arg >= 0 THEN
            RETURN right_arg;
        END IF;

        SELECT
            CASE
                WHEN left_arg >= 0 THEN left_arg::bit(16)
                ELSE set_bit((ABS(left_arg))::bit(16), 0, 1)
            END,
            CASE
                WHEN right_arg >= 0 THEN right_arg::bit(16)
                ELSE set_bit((ABS(right_arg))::bit(16), 0, 1)
            END
        INTO left_arg_bit, right_arg_bit;

        SELECT left_arg_bit & right_arg_bit INTO result_bit;

        SELECT
            CASE
                WHEN get_bit(result_bit, 0)::boolean THEN (set_bit(result_bit, 0, 0)::integer)*(-1)
                ELSE  (result_bit)::integer
            END
        INTO result;

        RETURN result;
        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN main.signed_integer_and() : %', SQLERRM ;
            RETURN FALSE;
    END;

    $BODY$

    LANGUAGE 'plpgsql'
    VOLATILE
    COST 100;

    -- grants
    GRANT EXECUTE ON FUNCTION main.signed_integer_and(integer, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION main.signed_integer_and(integer, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION main.signed_integer_and(integer, integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION main.signed_integer_and(integer, integer)
        IS 'Function that calculates AND between 2 signed integers';

    -- Function that calculates OR between 2 signed integers
    -- DROP FUNCTION IF EXISTS main.signed_integer_or(integer, integer);
    CREATE OR REPLACE FUNCTION main.signed_integer_or(
        left_arg  integer,
        right_arg integer
    )
    RETURNS integer AS

    $BODY$

    DECLARE
        -- variables
        left_arg_bit  bit(16);
        right_arg_bit bit(16);

        result_bit    bit(16);
        result        integer;
    BEGIN

        -- TEST
        -- SELECT main.signed_integer_or(-4::integer, -8::integer);
        IF left_arg >= 0 AND right_arg < 0 THEN
            RETURN right_arg;
        ELSIF left_arg < 0 AND right_arg >= 0 THEN
            RETURN right_arg;
        END IF;

        SELECT
            CASE
                WHEN left_arg >= 0 THEN left_arg::bit(16)
                ELSE set_bit((ABS(left_arg))::bit(16), 0, 1)
            END,
            CASE
                WHEN right_arg >= 0 THEN right_arg::bit(16)
                ELSE set_bit((ABS(right_arg))::bit(16), 0, 1)
            END
        INTO left_arg_bit, right_arg_bit;

        SELECT left_arg_bit | right_arg_bit INTO result_bit;

        SELECT
            CASE
                WHEN get_bit(result_bit, 0)::boolean THEN (set_bit(result_bit, 0, 0)::integer)*(-1)
                ELSE  (result_bit)::integer
            END
        INTO result;

        RETURN result;
        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN main.signed_integer_or() : %', SQLERRM ;
            RETURN FALSE;
    END;

    $BODY$

    LANGUAGE 'plpgsql'
    VOLATILE
    COST 100;

    -- grants
    GRANT EXECUTE ON FUNCTION main.signed_integer_or(integer, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION main.signed_integer_or(integer, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION main.signed_integer_or(integer, integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION main.signed_integer_or(integer, integer)
        IS 'Function that calculates OR between 2 signed integers';

    -- DROP OPERATOR IF EXISTS ||| (integer, integer);
    CREATE OPERATOR ||| (
        PROCEDURE = main.signed_integer_or,
        LEFTARG = integer,
        RIGHTARG = integer
    );

    -- DROP OPERATOR IF EXISTS &&& (integer, integer);
    CREATE OPERATOR &&& (
        PROCEDURE = main.signed_integer_and,
        LEFTARG = integer,
        RIGHTARG = integer
    );

-- SCHEMA bobo

    -- DROP SCHEMA IF EXISTS bobo CASCADE;
    CREATE SCHEMA bobo
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA bobo TO group_admin;
    GRANT USAGE ON SCHEMA bobo TO group_bobo;
    GRANT USAGE ON SCHEMA bobo TO group_readonly;
    GRANT USAGE ON SCHEMA bobo TO group_tools;
    COMMENT ON SCHEMA bobo IS 'Schema for the authentication in OPAS';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella che raccoglie tutte le informazioni relative agli utenti che hanno accesso al portale
    -- DROP TABLE IF EXISTS bobo.users;
    CREATE TABLE bobo.users
    (
        us_id           serial,
        us_name         text NOT NULL CHECK (us_name <> ''),
        us_2nd_name     text CHECK (us_2nd_name <> ''),
        us_surname      text NOT NULL CHECK (us_surname <> ''),
        us_role         text,
        us_email        email NOT NULL CHECK (us_email <> ''),
        us_phone        text DEFAULT NULL,
        us_mobile       text DEFAULT NULL,
        us_pwd          text NOT NULL,
        us_avatar       text DEFAULT NULL,
        us_avatar_thumb text DEFAULT '/bobo-img/default/avatar/ava01.png',
        us_active       boolean DEFAULT TRUE,
        us_first_log    boolean DEFAULT TRUE,
        us_exp_time     integer DEFAULT (3600*24*1), -- 1 giorno di default
        us_insert_time  timestamp without time zone DEFAULT now(),
        us_pwd_update_ts timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT bobo_users_pkey PRIMARY KEY (us_id),
        CONSTRAINT bobo_users_ukey UNIQUE (us_email)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.users TO group_admin;
    GRANT ALL ON TABLE    bobo.users TO group_bobo;
    GRANT ALL ON TABLE    bobo.users TO group_tools;
    GRANT SELECT ON TABLE bobo.users TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.users_us_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.users_us_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.users_us_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.users                 IS 'Table that holds all info about users';
    COMMENT ON COLUMN bobo.users.us_id           IS 'User id';
    COMMENT ON COLUMN bobo.users.us_name         IS 'User name';
    COMMENT ON COLUMN bobo.users.us_2nd_name     IS 'User second name';
    COMMENT ON COLUMN bobo.users.us_surname      IS 'User surname';
    COMMENT ON COLUMN bobo.users.us_role         IS 'User role';
    COMMENT ON COLUMN bobo.users.us_email        IS 'User email';
    COMMENT ON COLUMN bobo.users.us_phone        IS 'User phone number';
    COMMENT ON COLUMN bobo.users.us_mobile       IS 'User mobile number';
    COMMENT ON COLUMN bobo.users.us_pwd          IS 'User password (encrypted with md5)';
    COMMENT ON COLUMN bobo.users.us_avatar       IS 'User avatar';
    COMMENT ON COLUMN bobo.users.us_avatar_thumb IS 'User thumb avatar';
    COMMENT ON COLUMN bobo.users.us_active       IS 'User active or not';
    COMMENT ON COLUMN bobo.users.us_first_log    IS 'User flag if first time login';
    COMMENT ON COLUMN bobo.users.us_exp_time     IS 'User expiration time (default 1 day)';
    COMMENT ON COLUMN bobo.users.us_insert_time  IS 'User creation date';

    -- Tabella che raccoglie tutte le informazioni relative agli enti a cui appartengono gli utenti
    -- DROP TABLE IF EXISTS bobo.companies;
    CREATE TABLE bobo.companies
    (
        comp_id          serial,
        comp_name        text NOT NULL CHECK (comp_name <> ''),
        comp_desc        text DEFAULT NULL CHECK (comp_desc <> ''),
        comp_title       text DEFAULT NULL,
        comp_logo        text DEFAULT NULL,
        comp_thumb_logo  text DEFAULT NULL,
        comp_address     text DEFAULT NULL,
        comp_phone       text DEFAULT NULL,
        comp_web         text DEFAULT NULL,
        comp_email       email DEFAULT NULL,
        comp_active      boolean DEFAULT TRUE,
        comp_insert_time timestamp without time zone DEFAULT now(),

        CONSTRAINT bobo_companies_pkey PRIMARY KEY (comp_id),
        CONSTRAINT bobo_companies_ukey UNIQUE (comp_name)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.companies TO group_admin;
    GRANT ALL ON TABLE    bobo.companies TO group_bobo;
    GRANT ALL ON TABLE    bobo.companies TO group_tools;
    GRANT SELECT ON TABLE bobo.companies TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo.companies                  IS 'Table that holds all info about users';
    COMMENT ON COLUMN bobo.companies.comp_id          IS 'Company id';
    COMMENT ON COLUMN bobo.companies.comp_name        IS 'Company name';
    COMMENT ON COLUMN bobo.companies.comp_desc        IS 'Company description';
    COMMENT ON COLUMN bobo.companies.comp_title       IS 'Company title';
    COMMENT ON COLUMN bobo.companies.comp_logo        IS 'Company logo';
    COMMENT ON COLUMN bobo.companies.comp_thumb_logo  IS 'Company thumb logo';
    COMMENT ON COLUMN bobo.companies.comp_address     IS 'Company address';
    COMMENT ON COLUMN bobo.companies.comp_phone       IS 'Company phone number';
    COMMENT ON COLUMN bobo.companies.comp_web         IS 'Company website';
    COMMENT ON COLUMN bobo.companies.comp_email       IS 'Company email';
    COMMENT ON COLUMN bobo.companies.comp_active      IS 'Company active or not';
    COMMENT ON COLUMN bobo.companies.comp_insert_time IS 'Company creation date';

    -- Tabella che contiene le informazioni relative agli argomenti delle FAQ presenti sul portale
    -- DROP TABLE IF EXISTS bobo.faq_arguments;
    CREATE TABLE bobo.faq_arguments
    (
        faq_arg_id        serial,
        faq_page_id       integer NOT NULL,
        faq_arg_title     text NOT NULL,
        faq_arg_desc      text NOT NULL,
        faq_arg_desc_fts  tsvector,
        faq_arg_technical boolean DEFAULT FALSE,

        CONSTRAINT bobo_faq_arguments_pkey PRIMARY KEY (faq_arg_id)
        -- CONSTRAINT bobo_faq_arguments_fk1 FOREIGN KEY (faq_page_id)
        --     REFERENCES bobo.faq_pages (faq_page_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.faq_arguments TO group_admin;
    GRANT ALL ON TABLE    bobo.faq_arguments TO group_bobo;
    GRANT ALL ON TABLE    bobo.faq_arguments TO group_tools;
    GRANT SELECT ON TABLE bobo.faq_arguments TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.faq_arguments_faq_arg_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.faq_arguments_faq_arg_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.faq_arguments_faq_arg_id_seq TO group_tools;

    COMMENT ON TABLE  bobo.faq_arguments                   IS 'Table that holds the descriptions about sub-arguments';
    COMMENT ON COLUMN bobo.faq_arguments.faq_arg_id        IS 'Faq argument id';
    COMMENT ON COLUMN bobo.faq_arguments.faq_page_id       IS 'Faq page id';
    COMMENT ON COLUMN bobo.faq_arguments.faq_arg_title     IS 'Faq argument title';
    COMMENT ON COLUMN bobo.faq_arguments.faq_arg_desc      IS 'Faq argument description';
    COMMENT ON COLUMN bobo.faq_arguments.faq_arg_desc_fts  IS 'Field for full-text search';
    COMMENT ON COLUMN bobo.faq_arguments.faq_arg_technical IS 'Faq argument technical true/false';

    -- Tabella che contiene le informazioni relative alle pagine delle FAQ presenti sul portale
    -- DROP TABLE IF EXISTS bobo.faq_pages;
    CREATE TABLE bobo.faq_pages
    (
        faq_page_id   serial,
        faq_page_name text NOT NULL,

        CONSTRAINT bobo_faq_pages_pkey PRIMARY KEY (faq_page_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.faq_pages TO group_admin;
    GRANT ALL ON TABLE    bobo.faq_pages TO group_bobo;
    GRANT ALL ON TABLE    bobo.faq_pages TO group_tools;
    GRANT SELECT ON TABLE bobo.faq_pages TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.faq_pages_faq_page_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.faq_pages_faq_page_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.faq_pages_faq_page_id_seq TO group_tools;

    CREATE UNIQUE INDEX bobo_faq_pages_idx ON bobo.faq_pages (lower(faq_page_name));

    -- comments
    COMMENT ON TABLE  bobo.faq_pages               IS 'Table that holds info about faq macro arguments';
    COMMENT ON COLUMN bobo.faq_pages.faq_page_id   IS 'Faq page id';
    COMMENT ON COLUMN bobo.faq_pages.faq_page_name IS 'Faq page name';

    -- Tabella che contiene le informazioni relative alle associazioni tra i canali Telegram ed i gruppi di utenti del portale
    -- DROP TABLE IF EXISTS bobo.group_channels;
    CREATE TABLE bobo.group_channels
    (
        gc_id serial,
        gr_id integer NOT NULL,
        tc_id integer NOT NULL,
        gc_iud_grants bit(3) NOT NULL DEFAULT '000',

        CONSTRAINT bobo_group_channels_pkey PRIMARY KEY (gc_id),
        CONSTRAINT bobo_group_channels_ukey UNIQUE (gr_id, tc_id)
        -- CONSTRAINT bobo_group_channels_fk1 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_group_widgets_fk2 FOREIGN KEY (tc_id)
        --     REFERENCES gateways.telegram_channels (tc_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.group_channels TO group_admin;
    GRANT ALL ON TABLE    bobo.group_channels TO group_bobo;
    GRANT ALL ON TABLE    bobo.group_channels TO group_tools;
    GRANT SELECT ON TABLE bobo.group_channels TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.group_channels_gc_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.group_channels_gc_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.group_channels_gc_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.group_channels       IS 'Table that holds relations between groups and telegram channels';
    COMMENT ON COLUMN bobo.group_channels.gc_id IS 'Table serial id (PK)';
    COMMENT ON COLUMN bobo.group_channels.gr_id IS 'Group id (FK)';
    COMMENT ON COLUMN bobo.group_channels.tc_id IS 'Telegram channel id (FK)';

    -- Tabella che associa i codici di validazione finale con i gruppi degli utenti
    -- DROP TABLE IF EXISTS bobo.group_final_codes;
    CREATE TABLE bobo.group_final_codes
    (
        gfc_id         serial,
        gr_id          integer NOT NULL,
        fvc_code_id    integer NOT NULL,
        gfc_iud_grants bit(3) NOT NULL DEFAULT '000',

        CONSTRAINT bobo_group_final_codes_pkey PRIMARY KEY (gfc_id),
        CONSTRAINT bobo_group_final_codes_ukey UNIQUE (gr_id, fvc_code_id)
        -- CONSTRAINT bobo_group_final_codes_fk1 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_group_final_codes_fk2 FOREIGN KEY (fvc_code_id)
        --     REFERENCES metadata.final_validation_codes (fvc_code_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.group_final_codes TO group_admin;
    GRANT ALL ON TABLE    bobo.group_final_codes TO group_bobo;
    GRANT ALL ON TABLE    bobo.group_final_codes TO group_tools;
    GRANT SELECT ON TABLE bobo.group_final_codes TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.group_final_codes_gfc_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.group_final_codes_gfc_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.group_final_codes_gfc_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.group_final_codes                IS 'Table that holds info about relation between groups and final validation codes';
    COMMENT ON COLUMN bobo.group_final_codes.gfc_id         IS 'Group codes relation id';
    COMMENT ON COLUMN bobo.group_final_codes.gr_id          IS 'Group id';
    COMMENT ON COLUMN bobo.group_final_codes.fvc_code_id    IS 'Final validity code';
    COMMENT ON COLUMN bobo.group_final_codes.gfc_iud_grants IS 'Bit mask for grants (insert, update and delete)';

    -- Tabella che associa le reti con i gruppi degli utenti
    -- DROP TABLE IF EXISTS bobo.group_networks;
    CREATE TABLE bobo.group_networks
    (
        gn_id         serial,
        gr_id         integer NOT NULL,
        st_network_id integer NOT NULL,
        gn_iud_grants bit(3) NOT NULL DEFAULT '000',

        CONSTRAINT bobo_group_networks_pkey PRIMARY KEY (gn_id),
        CONSTRAINT bobo_group_networks_ukey UNIQUE (gr_id, st_network_id)
        -- CONSTRAINT bobo_group_networks_fk1 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_group_networks_fk2 FOREIGN KEY (st_network_id)
        --     REFERENCES metadata.stations_network_type (st_network_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.group_networks TO group_admin;
    GRANT ALL ON TABLE    bobo.group_networks TO group_bobo;
    GRANT ALL ON TABLE    bobo.group_networks TO group_tools;
    GRANT SELECT ON TABLE bobo.group_networks TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.group_networks_gn_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.group_networks_gn_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.group_networks_gn_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.group_networks               IS 'Table that holds info about relation between groups and networks';
    COMMENT ON COLUMN bobo.group_networks.gn_id         IS 'Group networks relation id';
    COMMENT ON COLUMN bobo.group_networks.gr_id         IS 'Group id';
    COMMENT ON COLUMN bobo.group_networks.st_network_id IS 'Network id';
    COMMENT ON COLUMN bobo.group_networks.gn_iud_grants IS 'Bit mask for grants (insert, update and delete)';

    -- Tabella che associa le pagine con i gruppi degli utenti precisandone i grants
    -- DROP TABLE IF EXISTS bobo.group_pages;
    CREATE TABLE bobo.group_pages
    (
        gp_id         serial,
        gr_id         integer NOT NULL,
        page_id       integer NOT NULL,
        gp_iud_grants bit(3) NOT NULL,

        CONSTRAINT bobo_group_pages_pkey PRIMARY KEY (gp_id),
        CONSTRAINT bobo_group_pages_ukey UNIQUE (gr_id, page_id)
        -- CONSTRAINT bobo_group_pages_fk1 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_group_pages_fk2 FOREIGN KEY (page_id)
        --     REFERENCES bobo.pages (page_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.group_pages TO group_admin;
    GRANT ALL ON TABLE    bobo.group_pages TO group_bobo;
    GRANT ALL ON TABLE    bobo.group_pages TO group_tools;
    GRANT SELECT ON TABLE bobo.group_pages TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.group_pages_gp_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.group_pages_gp_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.group_pages_gp_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.group_pages               IS 'Table that holds info about relation between groups and pages';
    COMMENT ON COLUMN bobo.group_pages.gp_id         IS 'Group pages relation id';
    COMMENT ON COLUMN bobo.group_pages.gr_id         IS 'Group id';
    COMMENT ON COLUMN bobo.group_pages.page_id       IS 'Page id';
    COMMENT ON COLUMN bobo.group_pages.gp_iud_grants IS 'Bit mask for grants (insert, update and delete)';

    -- Tabella che associa le stazioni con i gruppi degli utenti
    -- DROP TABLE IF EXISTS bobo.group_stations;
    CREATE TABLE bobo.group_stations
    (
        gs_id         serial,
        gr_id         integer NOT NULL,
        station_id    integer NOT NULL,
        gs_iud_grants bit(3) NOT NULL DEFAULT '000',

        CONSTRAINT bobo_group_stations_pkey PRIMARY KEY (gs_id),
        CONSTRAINT bobo_group_stations_ukey UNIQUE (gr_id, station_id)
        -- CONSTRAINT bobo_group_stations_fk1 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_group_stations_fk2 FOREIGN KEY (station_id)
        --     REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.group_stations TO group_admin;
    GRANT ALL ON TABLE    bobo.group_stations TO group_bobo;
    GRANT ALL ON TABLE    bobo.group_stations TO group_tools;
    GRANT SELECT ON TABLE bobo.group_stations TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.group_stations_gs_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.group_stations_gs_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.group_stations_gs_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.group_stations               IS 'Table that holds info about relation between groups and stations';
    COMMENT ON COLUMN bobo.group_stations.gs_id         IS 'Group stations relation id';
    COMMENT ON COLUMN bobo.group_stations.gr_id         IS 'Group id';
    COMMENT ON COLUMN bobo.group_stations.station_id    IS 'Station id';
    COMMENT ON COLUMN bobo.group_stations.gs_iud_grants IS 'Bit mask for grants (insert, update and delete)';

    -- Tabella relazionale che associa i widget ai gruppi utenti per gestirne la visibilità
    -- DROP TABLE IF EXISTS bobo.group_widgets;
    CREATE TABLE bobo.group_widgets
    (
        gw_id   serial,
        gr_id   integer NOT NULL,
        wdg_id  integer NOT NULL,
        gw_dest jsonb DEFAULT '{"type": "default"}'::jsonb,

        CONSTRAINT bobo_group_widgets_pkey PRIMARY KEY (gw_id),
        CONSTRAINT bobo_group_widgets_ukey UNIQUE (wdg_id, gr_id)
        -- CONSTRAINT bobo_group_widgets_fk1 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_group_widgets_fk2 FOREIGN KEY (wdg_id)
        --     REFERENCES bobo_tools.homepage_widgets (wdg_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.group_widgets TO group_admin;
    GRANT ALL ON TABLE    bobo.group_widgets TO group_bobo;
    GRANT ALL ON TABLE    bobo.group_widgets TO group_tools;
    GRANT SELECT ON TABLE bobo.group_widgets TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.group_widgets_gw_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.group_widgets_gw_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.group_widgets_gw_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.group_widgets         IS 'Table that holds relations between groups and widgets';
    COMMENT ON COLUMN bobo.group_widgets.gw_id   IS 'Table serial id (PK)';
    COMMENT ON COLUMN bobo.group_widgets.gr_id   IS 'Group id (FK)';
    COMMENT ON COLUMN bobo.group_widgets.wdg_id  IS 'Widget id (FK)';
    COMMENT ON COLUMN bobo.group_widgets.gw_dest IS 'JSONB containing widget destination';

    -- Tabella che raccoglie tutte le informazioni relative ai gruppi di utenti che hanno accesso al portale
    -- DROP TABLE IF EXISTS bobo.groups;
    CREATE TABLE bobo.groups
    (
        gr_id          serial,
        gr_name        text NOT NULL,
        gr_shortname   text CHECK (length(gr_shortname) < 30 ),
        gr_desc        text DEFAULT NULL,
        gr_insert_time timestamp without time zone DEFAULT now(),
        gr_sys_admin   boolean DEFAULT FALSE,

        CONSTRAINT bobo_groups_pkey PRIMARY KEY (gr_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.groups TO group_admin;
    GRANT ALL ON TABLE    bobo.groups TO group_bobo;
    GRANT ALL ON TABLE    bobo.groups TO group_tools;
    GRANT SELECT ON TABLE bobo.groups TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.groups_gr_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.groups_gr_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.groups_gr_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.groups                IS 'Table that holds all info about groups';
    COMMENT ON COLUMN bobo.groups.gr_id          IS 'Group id';
    COMMENT ON COLUMN bobo.groups.gr_name        IS 'Group name';
    COMMENT ON COLUMN bobo.groups.gr_shortname   IS 'Group shortname (30 ch)';
    COMMENT ON COLUMN bobo.groups.gr_desc        IS 'Group description';
    COMMENT ON COLUMN bobo.groups.gr_insert_time IS 'Group creation date';
    COMMENT ON COLUMN bobo.groups.gr_sys_admin   IS 'Group is system admin';

    -- Tabella che contiene tutte le info sullo stile dei menu del portale
    -- DROP TABLE IF EXISTS bobo.menu_css;
    CREATE TABLE bobo.menu_css
    (
        menu_css_id       serial,
        mp_id             integer NOT NULL,
        menu_css_class    text,
        menu_css_expanded boolean,
        menu_css_icon     text,
        menu_css_blank    boolean DEFAULT FALSE,
        menu_css_beta     boolean DEFAULT FALSE,

        CONSTRAINT bobo_menu_css_pkey PRIMARY KEY (menu_css_id)
        -- CONSTRAINT bobo_menu_css_fk1 FOREIGN KEY (mp_id)
        --     REFERENCES bobo.menu_pages (mp_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.menu_css TO group_admin;
    GRANT ALL ON TABLE    bobo.menu_css TO group_bobo;
    GRANT ALL ON TABLE    bobo.menu_css TO group_tools;
    GRANT SELECT ON TABLE bobo.menu_css TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo.menu_css                   IS 'Table that holds info about menu style';
    COMMENT ON COLUMN bobo.menu_css.menu_css_id       IS 'Menu css id';
    COMMENT ON COLUMN bobo.menu_css.mp_id             IS 'Menu page id';
    COMMENT ON COLUMN bobo.menu_css.menu_css_class    IS 'Menu css class to add to default';
    COMMENT ON COLUMN bobo.menu_css.menu_css_expanded IS 'Menu css html attribute aria-expanded';
    COMMENT ON COLUMN bobo.menu_css.menu_css_icon     IS 'Menu css icon';
    COMMENT ON COLUMN bobo.menu_css.menu_css_blank    IS 'Menu css boolean: open page in new tab';
    COMMENT ON COLUMN bobo.menu_css.menu_css_beta     IS 'Menu css boolean: beta version';

    -- Tabella che mette in relazione il menu con le pagine e/o aggiunge delle voci al menu non cliccabili (dropdown)
    -- DROP TABLE IF EXISTS bobo.menu_pages;
    CREATE TABLE bobo.menu_pages
    (
        mp_id    serial,
        menu_id  integer NOT NULL,
        page_id  integer,
        mp_name  text,
        mp_path  ltree NOT NULL,
        mp_order integer,

        CONSTRAINT bobo_menu_pages_pkey PRIMARY KEY (mp_id)
        -- CONSTRAINT bobo_menu_pages_fk1 FOREIGN KEY (menu_id)
        --     REFERENCES bobo.menus (menu_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_menu_pages_fk2 FOREIGN KEY (page_id)
        --     REFERENCES bobo.pages (page_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.menu_pages TO group_admin;
    GRANT ALL ON TABLE    bobo.menu_pages TO group_bobo;
    GRANT ALL ON TABLE    bobo.menu_pages TO group_tools;
    GRANT SELECT ON TABLE bobo.menu_pages TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo.menu_pages          IS 'Table that holds info about relation between menus and pages';
    COMMENT ON COLUMN bobo.menu_pages.mp_id    IS 'Menu pages relation id';
    COMMENT ON COLUMN bobo.menu_pages.menu_id  IS 'Menu id';
    COMMENT ON COLUMN bobo.menu_pages.page_id  IS 'Page id (it can be null if the menu element isn''t related to a page = is dropdown)';
    COMMENT ON COLUMN bobo.menu_pages.mp_name  IS 'Menu element name';
    COMMENT ON COLUMN bobo.menu_pages.mp_path  IS 'Menu element path';
    COMMENT ON COLUMN bobo.menu_pages.mp_order IS 'Menu order to force a particular order representation of elements';

    CREATE INDEX menu_pages_path_idx ON bobo.menu_pages USING GIST (mp_path);

    -- Tabella che raccoglie le informazioni funzionali all'applicativo sui menu che vanno a comporre il portale
    -- DROP TABLE IF EXISTS bobo.menus;
    CREATE TABLE bobo.menus
    (
        menu_id   serial,
        menu_type bobo_nav,
        menu_desc text NOT NULL,

        CONSTRAINT bobo_menus_pkey PRIMARY KEY (menu_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.menus TO group_admin;
    GRANT ALL ON TABLE    bobo.menus TO group_bobo;
    GRANT ALL ON TABLE    bobo.menus TO group_tools;
    GRANT SELECT ON TABLE bobo.menus TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo.menus           IS 'Table that holds all info about menus';
    COMMENT ON COLUMN bobo.menus.menu_type IS 'Menu type (selected from bobo_nav enum)';
    COMMENT ON COLUMN bobo.menus.menu_desc IS 'Short menu description';

    -- Tabella che raccoglie le informazioni funzionali all'applicativo sulle pagine che vanno a comporre il portale
    -- DROP TABLE IF EXISTS bobo.pages;
    CREATE TABLE bobo.pages
    (
        page_id            serial,
        page_name          text NOT NULL,
        page_href          text NOT NULL CHECK (length(page_href) < 30 ),
        page_shortcut_icon text DEFAULT 'fa-solid fa-cat-space',

        CONSTRAINT bobo_pages_pkey PRIMARY KEY (page_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.pages TO group_admin;
    GRANT ALL ON TABLE    bobo.pages TO group_bobo;
    GRANT ALL ON TABLE    bobo.pages TO group_tools;
    GRANT SELECT ON TABLE bobo.pages TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo.pages                    IS 'Table that holds all info about pages';
    COMMENT ON COLUMN bobo.pages.page_id            IS 'Page id';
    COMMENT ON COLUMN bobo.pages.page_name          IS 'Page name';
    COMMENT ON COLUMN bobo.pages.page_href          IS 'Page href (30 ch)';
    COMMENT ON COLUMN bobo.pages.page_shortcut_icon IS 'Page icon for shortcut link';

    -- Tabella che raccoglie le informazioni relative agli amministratori del portale
    -- DROP TABLE IF EXISTS bobo.portal_properties;
    CREATE TABLE bobo.portal_properties
    (
        portal_id       integer DEFAULT NULL,
        admin_gr_id     integer,
        admin_comp_id   integer,
        linked_gr_id    integer[],
        linked_comp_id  integer[],
        pp_pwd_exp_gap  integer DEFAULT 15552000,
        region_id       integer,
        db_schema_names text[],

        CONSTRAINT bobo_admin_groups_pkey PRIMARY KEY (portal_id)
        -- CONSTRAINT bobo_admin_groups_fk1 FOREIGN KEY (portal_id)
        --     REFERENCES bobo.portals (portal_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_admin_groups_fk2 FOREIGN KEY (admin_gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_admin_groups_fk3 FOREIGN KEY (admin_comp_id)
        --     REFERENCES bobo.companies (comp_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_admin_groups_fk4 FOREIGN KEY (region_id)
        --     REFERENCES main.regions (region_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.portal_properties TO group_admin;
    GRANT ALL ON TABLE    bobo.portal_properties TO group_bobo;
    GRANT ALL ON TABLE    bobo.portal_properties TO group_tools;
    GRANT SELECT ON TABLE bobo.portal_properties TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo.portal_properties                 IS 'Table that holds relations between admin groups and simple groups';
    COMMENT ON COLUMN bobo.portal_properties.portal_id       IS 'Portal id';
    COMMENT ON COLUMN bobo.portal_properties.admin_gr_id     IS 'Admin Group id';
    COMMENT ON COLUMN bobo.portal_properties.admin_comp_id   IS 'Admin Company id';
    COMMENT ON COLUMN bobo.portal_properties.linked_gr_id    IS 'Array of groups linked to the admin';
    COMMENT ON COLUMN bobo.portal_properties.linked_comp_id  IS 'Array of companies linked to the admin';
    COMMENT ON COLUMN bobo.portal_properties.pp_pwd_exp_gap  IS 'Portal properties expiration password time';
    COMMENT ON COLUMN bobo.portal_properties.region_id       IS 'Main reference region for the portal (NULL for Italy)';
    COMMENT ON COLUMN bobo.portal_properties.db_schema_names IS 'DB - schema names for stations data tables';

    -- Tabella che raccoglie gli elementi di stile del portale
    -- DROP TABLE IF EXISTS bobo.portals;
    CREATE TABLE bobo.portals
    (
        portal_id           serial,
        portal_name         text NOT NULL,
        portal_desc         text NOT NULL,
        portal_extra_desc   text DEFAULT NULL,
        portal_logo         text NOT NULL,
        portal_thumb_logo   text NOT NULL,
        portal_footer_text  text DEFAULT NULL,
        portal_style        text DEFAULT NULL,
        portal_carousel     text[] DEFAULT NULL,
        portal_basepath     text DEFAULT NULL,
        portal_link         text DEFAULT NULL,
        portal_filesys_path text DEFAULT NULL,

        CONSTRAINT bobo_portals_pkey PRIMARY KEY (portal_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.portals TO group_admin;
    GRANT ALL ON TABLE    bobo.portals TO group_bobo;
    GRANT ALL ON TABLE    bobo.portals TO group_tools;
    GRANT SELECT ON TABLE bobo.portals TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo.portals                      IS 'Table that holds info about portal relations wth other elements';
    COMMENT ON COLUMN bobo.portals.portal_id            IS 'Portal id';
    COMMENT ON COLUMN bobo.portals.portal_name          IS 'Portal name';
    COMMENT ON COLUMN bobo.portals.portal_desc          IS 'Portal description';
    COMMENT ON COLUMN bobo.portals.portal_extra_desc    IS 'Portal extra description';
    COMMENT ON COLUMN bobo.portals.portal_logo          IS 'Portal logo';
    COMMENT ON COLUMN bobo.portals.portal_thumb_logo    IS 'Portal thumb logo';
    COMMENT ON COLUMN bobo.portals.portal_footer_text   IS 'Portal footer text';
    COMMENT ON COLUMN bobo.portals.portal_style         IS 'Portal style';
    COMMENT ON COLUMN bobo.portals.portal_carousel      IS 'Portal carousel';
    COMMENT ON COLUMN bobo.portals.portal_basepath      IS 'Portal basepath for favicon and avatar';
    COMMENT ON COLUMN bobo.portals.portal_link          IS 'Portal link URL';
    COMMENT ON COLUMN bobo.portals.portal_filesys_path  IS 'Portal file system path for scripts usage';

    -- Tabella che associa gli utenti ai gruppi ereditandone i privilegi
    -- DROP TABLE IF EXISTS bobo.user_groups;
    CREATE TABLE bobo.user_groups
    (
        ug_id serial,
        us_id integer,
        gr_id integer,

        CONSTRAINT bobo_user_groups_pkey PRIMARY KEY (ug_id),
        CONSTRAINT bobo_user_groups_ukey UNIQUE (us_id, gr_id)
        -- CONSTRAINT bobo_user_groups_fk1 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_user_groups_fk2 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.user_groups TO group_admin;
    GRANT ALL ON TABLE    bobo.user_groups TO group_bobo;
    GRANT ALL ON TABLE    bobo.user_groups TO group_tools;
    GRANT SELECT ON TABLE bobo.user_groups TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.user_groups_ug_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.user_groups_ug_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.user_groups_ug_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.user_groups       IS 'Table that holds relations between user groups';
    COMMENT ON COLUMN bobo.user_groups.ug_id IS 'User group relation id';
    COMMENT ON COLUMN bobo.user_groups.us_id IS 'User id';
    COMMENT ON COLUMN bobo.user_groups.gr_id IS 'Group id';

    -- Tabella che associa gli utenti alle impostazioni del portale di riferimento
    -- DROP TABLE IF EXISTS bobo.user_options;
    CREATE TABLE bobo.user_options
    (
        option_id          serial,
        option_user        integer NOT NULL,
        option_object      jsonb NOT NULL,
        option_last_update timestamp without time zone DEFAULT NULL,

        CONSTRAINT bobo_tools_user_options_pkey PRIMARY KEY (option_id),
        CONSTRAINT bobo_tools_user_options_ukey UNIQUE (option_user)
        -- CONSTRAINT bobo_tools_user_options_fk1 FOREIGN KEY (option_user)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.user_options TO group_admin;
    GRANT ALL ON TABLE    bobo.user_options TO group_bobo;
    GRANT ALL ON TABLE    bobo.user_options TO group_tools;
    GRANT SELECT ON TABLE bobo.user_options TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.user_options_option_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.user_options_option_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.user_options_option_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.user_options                    IS 'Table with user options of user tool';
    COMMENT ON COLUMN bobo.user_options.option_id          IS 'Option serial id (PK)';
    COMMENT ON COLUMN bobo.user_options.option_user        IS 'Option user id (FK)';
    COMMENT ON COLUMN bobo.user_options.option_object      IS 'Option JSON object';
    COMMENT ON COLUMN bobo.user_options.option_last_update IS 'Option last update date';

    -- Tabella che associa ulteriori informazioni all'utente
    -- DROP TABLE IF EXISTS bobo.users_metadata;
    CREATE TABLE bobo.users_metadata
    (
        um_id     serial,
        us_id     integer NOT NULL,
        comp_id   integer,
        portal_id integer DEFAULT 0,

        CONSTRAINT bobo_users_metadata_pkey PRIMARY KEY (um_id),
        CONSTRAINT bobo_users_metadata_ukey UNIQUE (us_id)
        -- CONSTRAINT bobo_users_metadata_fk1 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_users_metadata_fk2 FOREIGN KEY (comp_id)
        --     REFERENCES bobo.companies (comp_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_users_metadata_fk3 FOREIGN KEY (portal_id)
        --     REFERENCES bobo.portals (portal_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo.users_metadata TO group_admin;
    GRANT ALL ON TABLE    bobo.users_metadata TO group_bobo;
    GRANT ALL ON TABLE    bobo.users_metadata TO group_tools;
    GRANT SELECT ON TABLE bobo.users_metadata TO group_readonly;
    GRANT ALL ON SEQUENCE bobo.users_metadata_um_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo.users_metadata_um_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo.users_metadata_um_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo.users_metadata           IS 'Table that holds all additional users metadata';
    COMMENT ON COLUMN bobo.users_metadata.um_id     IS 'User metadata id';
    COMMENT ON COLUMN bobo.users_metadata.us_id     IS 'User id';
    COMMENT ON COLUMN bobo.users_metadata.comp_id   IS 'Company id';
    COMMENT ON COLUMN bobo.users_metadata.portal_id IS 'Portal id';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- Vista che raccoglie tutte le info riguardanti le faq
    -- DROP VIEW IF EXISTS bobo.view_faq_page_arguments;
    CREATE VIEW bobo.view_faq_page_arguments AS
    SELECT
        fp.faq_page_id       AS faq_page_id,
        fp.faq_page_name     AS faq_page_name,
        fa.faq_arg_id        AS faq_arg_id,
        fa.faq_arg_title     AS faq_arg_title,
        fa.faq_arg_desc      AS faq_arg_desc,
        fa.faq_arg_desc_fts  AS faq_arg_desc_fts,
        fa.faq_arg_technical AS faq_arg_technical
    FROM bobo.faq_pages fp
        LEFT JOIN bobo.faq_arguments fa USING (faq_page_id)
    ORDER BY faq_page_id;

    -- grants
    GRANT ALL ON TABLE    bobo.view_faq_page_arguments TO group_admin;
    GRANT ALL ON TABLE    bobo.view_faq_page_arguments TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_faq_page_arguments TO group_tools;
    GRANT SELECT ON TABLE bobo.view_faq_page_arguments TO group_readonly;

    -- Vista che raccoglie le info dei gruppi in relazione alle pagine a cui sono associati
    -- DROP VIEW IF EXISTS bobo.view_group_pages;
    CREATE VIEW bobo.view_group_pages AS
    SELECT
        gp.gp_id         AS group_pages_id,
        g.gr_id          AS group_id,
        p.page_id        AS page_id,
        g.gr_name        AS group_name,
        g.gr_shortname   AS group_shortname,
        p.page_name      AS page_name,
        p.page_href      AS page_href,
        gp.gp_iud_grants AS group_pages_grants
    FROM
        bobo.group_pages gp
        LEFT JOIN bobo.groups g USING (gr_id)
        LEFT JOIN bobo.pages p USING (page_id)
    ORDER BY g.gr_id;

    -- grants
    GRANT ALL ON TABLE    bobo.view_group_pages TO group_admin;
    GRANT ALL ON TABLE    bobo.view_group_pages TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_group_pages TO group_tools;
    GRANT SELECT ON TABLE bobo.view_group_pages TO group_readonly;

    -- Vista che raccoglie le info del menu, delle pagine che contiene e del css
    -- DROP VIEW IF EXISTS bobo.view_menu_pages;
    CREATE OR REPLACE VIEW bobo.view_menu_pages AS
    SELECT
        mp.mp_id                          AS mp_id,
        mp.menu_id                        AS menu_id,
        m.menu_type                       AS menu_type,
        mp.page_id                        AS page_id,
        COALESCE(p.page_name, mp.mp_name) AS page_name,
        mp.mp_path                        AS page_path,
        p.page_href                       AS page_href,
        p.page_shortcut_icon              AS page_shortcut_icon,
        mp.mp_order                       AS menu_page_order,
        nlevel(mp.mp_path)                AS menu_page_level,
        COALESCE(mcss.menu_css_class, '') AS menu_page_class,
        mcss.menu_css_expanded            AS menu_page_expanded,
        COALESCE(mcss.menu_css_icon, '')  AS menu_page_icon,
        mcss.menu_css_blank               AS menu_page_blank,
        mcss.menu_css_beta                AS menu_page_beta
    FROM bobo.menu_pages mp
        LEFT JOIN bobo.menus m USING (menu_id)
        LEFT JOIN bobo.pages p USING (page_id)
        LEFT JOIN bobo.menu_css mcss USING (mp_id)
    ORDER BY mp_id;

    -- grants
    GRANT ALL ON TABLE    bobo.view_menu_pages TO group_admin;
    GRANT ALL ON TABLE    bobo.view_menu_pages TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_menu_pages TO group_tools;
    GRANT SELECT ON TABLE bobo.view_menu_pages TO group_readonly;

    -- DROP VIEW IF EXISTS bobo.view_user_authentication;
    CREATE VIEW bobo.view_user_authentication AS
    SELECT DISTINCT ON (u.us_id)
        u.us_id                     AS user_id,
        u.us_name                   AS user_name,
        u.us_2nd_name               AS user_second_name,
        u.us_surname                AS user_surname,
        u.us_email                  AS user_email,
        u.us_pwd                    AS user_password,
        u.us_avatar                 AS user_avatar,
        u.us_avatar_thumb           AS user_avatar_thumb,
        u.us_exp_time               AS user_expiration_time,
        u.us_first_log              AS user_first_log,
        u.us_pwd_update_ts          AS user_pwd_update_timestamp,
        CASE
            WHEN EXTRACT(epoch FROM CURRENT_TIMESTAMP - u.us_pwd_update_ts::timestamp with time zone) >= pp.pp_pwd_exp_gap::numeric AND u.us_first_log IS FALSE THEN true
            ELSE false
        END                         AS user_pwd_expired,
        (
            SELECT bool_or(groups.gr_sys_admin) AS bool_or
            FROM bobo.groups
            WHERE (
                groups.gr_id IN (
                    SELECT user_groups.gr_id
                    FROM bobo.user_groups
                    WHERE user_groups.us_id = u.us_id
                )
            )
        ) AS user_sys_admin,
        array(
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = u.us_id
            )                       AS groups_id,
        array(
                SELECT gr_name
                FROM bobo.groups
                WHERE gr_id IN (
                    SELECT gr_id
                    FROM bobo.user_groups
                    WHERE us_id = u.us_id
                )
            )                       AS groups_name,
        c.comp_id                   AS company_id,
        c.comp_name                 AS company_name,
        c.comp_desc                 AS company_desc,
        c.comp_title                AS company_title,
        c.comp_logo                 AS company_logo,
        c.comp_thumb_logo           AS company_thumb_logo,
        c.comp_address              AS company_address,
        c.comp_phone                AS company_phone,
        c.comp_web                  AS company_web,
        c.comp_email                AS company_email,
        p.portal_id                 AS portal_id,
        p.portal_name               AS portal_name,
        p.portal_desc               AS portal_desc,
        p.portal_extra_desc         AS portal_extra_desc,
        p.portal_logo               AS portal_logo,
        p.portal_thumb_logo         AS portal_thumb_logo,
        p.portal_footer_text        AS portal_footer_text,
        p.portal_style              AS portal_style,
        p.portal_carousel           AS portal_carousel,
        p.portal_basepath           AS portal_basepath,
        p.portal_link               AS portal_link,
        pp.region_id                AS portal_region
    FROM
        bobo.users u
        LEFT JOIN bobo.user_groups ug USING (us_id)
        LEFT JOIN bobo.groups g USING (gr_id)
        LEFT JOIN bobo.users_metadata um USING (us_id)
        LEFT JOIN bobo.companies c on c.comp_id = (
            CASE
                WHEN um.comp_id IS NULL THEN 1
                ELSE um.comp_id
            END
        )
        LEFT JOIN bobo.portals p USING (portal_id)
        LEFT JOIN bobo.portal_properties pp USING (portal_id)
    WHERE u.us_active IS TRUE
    ORDER BY u.us_id;

    -- grants
    GRANT ALL ON TABLE    bobo.view_user_authentication TO group_admin;
    GRANT ALL ON TABLE    bobo.view_user_authentication TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_user_authentication TO group_tools;
    GRANT SELECT ON TABLE bobo.view_user_authentication TO group_readonly;

    -- Vista che raccoglie le info dell'utente in relazione alle pagine a cui ha accesso e alla somma dei permessi relativi ai gruppi a cui appartiene
    -- DROP VIEW IF EXISTS bobo.view_user_grants_pages;
    CREATE VIEW bobo.view_user_grants_pages AS
    SELECT DISTINCT ON (u.us_id, p.page_id)
        u.us_id             AS user_id,
        u.us_name           AS user_name,
        u.us_2nd_name       AS user_second_name,
        u.us_surname        AS user_surname,
        u.us_role           AS user_role,
        u.us_email          AS user_email,
        u.us_phone          AS user_phone,
        u.us_mobile         AS user_mobile,
        u.us_pwd            AS user_password,
        u.us_avatar         AS user_avatar,
        u.us_avatar_thumb   AS user_avatar_thumb,
        u.us_exp_time       AS user_expiration_time,
        u.us_first_log      AS user_first_log,
        u.us_pwd_update_ts  AS user_pwd_update_timestamp,
        CASE
            WHEN
                EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - u.us_pwd_update_ts)) >= pp.pp_pwd_exp_gap
                AND u.us_first_log IS FALSE
            THEN TRUE
            ELSE FALSE
        END                 AS user_pwd_expired,
        array(
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = u.us_id
            )               AS user_groups_array,
        p.page_id           AS page_id,
        p.page_name         AS page_name,
        p.page_href         AS page_href,
        (
            SELECT bit_or(tbit.gp_iud_grants) FROM
                (
                    SELECT gp_iud_grants
                    FROM bobo.group_pages
                    WHERE page_id = p.page_id
                    AND gr_id IN (
                        SELECT gr_id
                        FROM bobo.user_groups
                        WHERE us_id = u.us_id
                    )
                ) AS tbit
        ) AS total_user_grants
    FROM
        bobo.users u
        LEFT JOIN bobo.user_groups ug USING (us_id)
        LEFT JOIN bobo.users_metadata um USING (us_id)
        LEFT JOIN bobo.portal_properties pp USING (portal_id)
        LEFT JOIN bobo.groups g USING (gr_id)
        LEFT JOIN bobo.group_pages gp USING (gr_id)
        LEFT JOIN bobo.pages p USING (page_id)
    WHERE u.us_active IS TRUE
    ORDER BY u.us_id;

    -- grants
    GRANT ALL ON TABLE    bobo.view_user_grants_pages TO group_admin;
    GRANT ALL ON TABLE    bobo.view_user_grants_pages TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_user_grants_pages TO group_tools;
    GRANT SELECT ON TABLE bobo.view_user_grants_pages TO group_readonly;

    -- Vista che raccoglie le info dell'user in relazione con i gruppi a cui è associato
    -- DROP VIEW IF EXISTS bobo.view_user_groups;
    CREATE VIEW bobo.view_user_groups AS
    SELECT
        ug.ug_id          AS user_groups_id,
        u.us_id           AS user_id,
        g.gr_id           AS group_id,
        u.us_name         AS user_name,
        u.us_2nd_name     AS user_second_name,
        u.us_surname      AS user_surname,
        u.us_role         AS user_role,
        u.us_email        AS user_email,
        u.us_phone        AS user_phone,
        u.us_mobile       AS user_mobile,
        u.us_pwd          AS user_password,
        u.us_avatar       AS user_avatar,
        u.us_avatar_thumb AS user_avatar_thumb,
        u.us_exp_time     AS user_expiration_time,
        u.us_first_log    AS user_first_log,
        g.gr_name         AS group_name,
        g.gr_shortname    AS group_shortname
    FROM
        bobo.user_groups ug
        LEFT JOIN bobo.users u USING (us_id)
        LEFT JOIN bobo.groups g USING (gr_id)
    WHERE u.us_active IS TRUE
    ORDER BY u.us_id;

    -- grants
    GRANT ALL ON TABLE    bobo.view_user_groups TO group_admin;
    GRANT ALL ON TABLE    bobo.view_user_groups TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_user_groups TO group_tools;
    GRANT SELECT ON TABLE bobo.view_user_groups TO group_readonly;

    -- Vista che raccoglie le informazioni relative agli utenti del portale
    -- DROP VIEW IF EXISTS bobo.view_users;
    CREATE VIEW bobo.view_users AS
    SELECT DISTINCT ON (u.us_id)
        u.us_id                     AS user_id,
        u.us_active                 AS user_active,
        u.us_name                   AS user_name,
        COALESCE(u.us_2nd_name, '') AS user_second_name,
        u.us_surname                AS user_surname,
        COALESCE(u.us_email , '')   AS user_email,
        COALESCE(u.us_phone , '')   AS user_phone,
        COALESCE(u.us_mobile, '')   AS user_mobile,
        COALESCE(u.us_role  , '')   AS user_role,
        u.us_pwd                    AS user_password,
        u.us_avatar                 AS user_avatar,
        u.us_avatar_thumb           AS user_avatar_thumb,
        u.us_exp_time               AS user_expiration_time,
        u.us_first_log              AS user_first_log,
        array(
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = u.us_id
            )                       AS groups_id,
        array(
                SELECT gr_name
                FROM bobo.groups
                WHERE gr_id IN (
                    SELECT gr_id
                    FROM bobo.user_groups
                    WHERE us_id = u.us_id
                )
            )                       AS groups_name,
        c.comp_id                   AS company_id,
        c.comp_name                 AS company_name,
        c.comp_desc                 AS company_desc,
        c.comp_title                AS company_title,
        c.comp_logo                 AS company_logo,
        c.comp_thumb_logo           AS company_thumb_logo,
        c.comp_address              AS company_address,
        c.comp_phone                AS company_phone,
        c.comp_web                  AS company_web,
        c.comp_email                AS company_email,
        p.portal_id                 AS portal_id,
        p.portal_name               AS portal_name,
        p.portal_desc               AS portal_desc,
        p.portal_extra_desc         AS portal_extra_desc
    FROM
        bobo.users u
        LEFT JOIN bobo.user_groups ug USING (us_id)
        LEFT JOIN bobo.groups g USING (gr_id)
        LEFT JOIN bobo.users_metadata um USING (us_id)
        LEFT JOIN bobo.companies c on c.comp_id = (
            CASE
                WHEN um.comp_id IS NULL THEN 1
                ELSE um.comp_id
            END
        )
        LEFT JOIN bobo.portals p USING (portal_id)
    ORDER BY u.us_id;

    -- grants
    GRANT ALL ON TABLE    bobo.view_users TO group_admin;
    GRANT ALL ON TABLE    bobo.view_users TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_users TO group_tools;
    GRANT SELECT ON TABLE bobo.view_users TO group_readonly;

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Funzione per convertire la maschera di grants in stringa
    -- DROP FUNCTION bobo.f_convert_grants_to_string(bit);
    CREATE OR REPLACE FUNCTION bobo.f_convert_grants_to_string(
        bit)
        RETURNS text
        LANGUAGE 'plpgsql'

        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        grants          ALIAS FOR $1;
        insert_permission   integer;
        update_permission   integer;
        delete_permission   integer;
        string_grants       text;
    BEGIN
        -- TEST SELECT bobo.f_convert_grants_to_string(b'101');
        string_grants := '';

        SELECT INTO insert_permission bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (grants), (b'100')) AS t (bit) ) AS temp;
        IF  insert_permission != 0 THEN
            string_grants := 'inserimento, ';
        END IF;

        SELECT INTO update_permission bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (grants), (b'010')) AS t (bit)) AS temp;
        IF  update_permission != 0 THEN
            string_grants := string_grants || 'modifica, ';
        END IF;

        SELECT INTO delete_permission bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (grants), (b'001')) AS t (bit)) AS temp;
        IF delete_permission != 0 THEN
            string_grants := string_grants || 'eliminazione';
        END IF;


        RETURN string_grants;

        /* errors check */
        EXCEPTION WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN bobo.f_convert_grants_to_string(bit) : %', SQLERRM ;
            RETURN 'Error!'; /* return value */
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION bobo.f_convert_grants_to_string(bit) TO group_bobo;
    GRANT EXECUTE ON FUNCTION bobo.f_convert_grants_to_string(bit) TO group_bobo;
    GRANT EXECUTE ON FUNCTION bobo.f_convert_grants_to_string(bit) TO group_tools;
    GRANT EXECUTE ON FUNCTION bobo.f_convert_grants_to_string(bit) TO group_readonly;

    -- Funzione che recupera le impostazioni personalizzate dall'utente delle pagine del portale
    -- DROP FUNCTION bobo.f_get_user_portal_options();
    CREATE OR REPLACE FUNCTION bobo.f_get_user_portal_options(
        usid integer,
        href text
    )
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    STABLE

    AS $BODY$

    DECLARE
        p integer; -- portal id
        o text; -- object
    BEGIN
        --
        -- TEST SELECT * FROM clients.f_data_validity_statistics( 231 , '2023-09-05 00:00'::timestamp, '2023-09-12 23:00'::timestamp );
        --
        SELECT
            portal_id INTO p
        FROM
            bobo.users_metadata
        WHERE
            us_id = usid;

        WITH t AS (
            SELECT
                po_obj
            FROM
                bobo_tools.portal_options
            WHERE
                portal_id = p
                AND page_id = (
                    SELECT page_id
                    FROM bobo.pages
                    WHERE page_href = href
                )
        ),
        t2 AS (
            SELECT t.po_obj AS options
            FROM t
            UNION ALL
            SELECT '{}'::jsonb AS options
            WHERE NOT EXISTS (SELECT 1 FROM t)
        )
        SELECT options INTO o FROM t2;

        /* return value */
        RETURN o;


        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR bobo.f_get_user_portal_options(): %', SQLERRM;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION bobo.f_get_user_portal_options(integer, text) TO group_readonly;
    GRANT EXECUTE ON FUNCTION bobo.f_get_user_portal_options(integer, text) TO group_bobo;
    GRANT EXECUTE ON FUNCTION bobo.f_get_user_portal_options(integer, text) TO group_admin;
    GRANT EXECUTE ON FUNCTION bobo.f_get_user_portal_options(integer, text) TO group_tools;

    -- comment
    COMMENT ON FUNCTION bobo.f_get_user_portal_options(integer, text) IS 'Function that retrieves user''s page options setted for the portal';

    -- Funzione per convertire la maschera di grants in stringa
    -- DROP FUNCTION bobo.f_recover_user_password(text);
    CREATE OR REPLACE FUNCTION bobo.f_recover_user_password(
        text)
        RETURNS text
        LANGUAGE 'plpgsql'

        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        user_email     ALIAS FOR $1;
        user_id       integer;
        new_pwd       text;
    BEGIN
        -- TEST SELECT bobo.f_recover_user_password('utente.opas@opas.it');
        new_pwd := '';

        SELECT INTO user_id us_id FROM bobo.users WHERE us_email = user_email;
        IF  user_id IS NULL THEN
            RETURN NULL;
        END IF;

        SELECT INTO new_pwd
            string_agg(substr(characters, (random() * length(characters) + 1)::integer, 1), '') AS random_word
        FROM (VALUES('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@$!%*?&')) AS symbols(characters)
        -- length of password
        JOIN generate_series(1, 15) ON 1 = 1;

        UPDATE bobo.users SET us_pwd = crypt(new_pwd, gen_salt('bf')), us_first_log = TRUE WHERE us_id = user_id;

        RETURN new_pwd;

        /* errors check */
        EXCEPTION WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN bobo.f_recover_user_password(text) : %', SQLERRM ;
            RETURN NULL; /* return value */
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION bobo.f_recover_user_password(text) TO group_bobo;
    GRANT EXECUTE ON FUNCTION bobo.f_recover_user_password(text) TO group_bobo;
    GRANT EXECUTE ON FUNCTION bobo.f_recover_user_password(text) TO group_tools;
    GRANT EXECUTE ON FUNCTION bobo.f_recover_user_password(text) TO group_readonly;

    -- Funzione che modifica la colonna della data di aggiornamento della password
    -- DROP FUNCTION bobo.f_update_pwd_timestamp();
    CREATE OR REPLACE FUNCTION bobo.f_update_pwd_timestamp()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$

    DECLARE
    BEGIN
        -- RAISE NOTICE 'TRIGGER f_update_pwd_timestamp!';

        -- check for changes
        IF
            NEW.us_pwd != OLD.us_pwd
        THEN
            -- continue
            NEW.us_pwd_update_ts = CURRENT_TIMESTAMP;
        ELSE
            -- skip
            --RAISE NOTICE 'Nothing changed!';
            RETURN NEW;
        END IF;


        RETURN NEW;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR bobo.f_update_pwd_timestamp(): %', SQLERRM;
            RETURN NEW;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION bobo.f_update_pwd_timestamp() TO group_admin;
    GRANT EXECUTE ON FUNCTION bobo.f_update_pwd_timestamp() TO group_bobo;
    GRANT EXECUTE ON FUNCTION bobo.f_update_pwd_timestamp() TO group_tools;

    -- comment
    COMMENT ON FUNCTION bobo.f_update_pwd_timestamp() IS 'Trigger function that updates column password update timestamp for expiration aims';

    -- --------------------------------------------------------------------------------------------
    -- TRIGGERS
    -- --------------------------------------------------------------------------------------------

    CREATE OR REPLACE TRIGGER bobo_update_pwd_ts_bu
        BEFORE UPDATE OF us_pwd
        ON bobo.users
        FOR EACH ROW
        EXECUTE FUNCTION bobo.f_update_pwd_timestamp();

-- SCHEMA bobo_tools

    -- DROP SCHEMA IF EXISTS bobo_tools CASCADE;
    CREATE SCHEMA bobo_tools
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA bobo_tools TO group_admin;
    GRANT USAGE ON SCHEMA bobo_tools TO group_bobo;
    GRANT USAGE ON SCHEMA bobo_tools TO group_readonly;
    GRANT USAGE ON SCHEMA bobo_tools TO group_tools;
    COMMENT ON SCHEMA bobo_tools IS 'Bobo tools schema for OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella che contiene le categorie sotto cui si raggruppano le pagine
    -- DROP TABLE IF EXISTS bobo_tools.homepage_widgets;
    CREATE TABLE bobo_tools.homepage_widgets
    (
        wdg_id          serial,
        wdg_name        text NOT NULL,
        wdg_description text,
        wdg_image_url   text,
        wdg_page_html   text,

        CONSTRAINT bobo_tools_homepage_widgets_pkey PRIMARY KEY (wdg_id),
        CONSTRAINT bobo_tools_homepage_widgets_ukey UNIQUE (wdg_page_html)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.homepage_widgets TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.homepage_widgets TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.homepage_widgets TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.homepage_widgets TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.homepage_widgets_wdg_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.homepage_widgets_wdg_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.homepage_widgets_wdg_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.homepage_widgets                 IS 'Table with widget of user tool';
    COMMENT ON COLUMN bobo_tools.homepage_widgets.wdg_id          IS 'Widget serial id (PK)';
    COMMENT ON COLUMN bobo_tools.homepage_widgets.wdg_name        IS 'Widget name';
    COMMENT ON COLUMN bobo_tools.homepage_widgets.wdg_description IS 'Widget description';
    COMMENT ON COLUMN bobo_tools.homepage_widgets.wdg_image_url   IS 'Widget image url';
    COMMENT ON COLUMN bobo_tools.homepage_widgets.wdg_page_html   IS 'Widget main page html';

    -- Tabella che contiene le categorie sotto cui si raggruppano le macro
    -- DROP TABLE IF EXISTS bobo_tools.analyser_categories;
    CREATE TABLE bobo_tools.analyser_categories
    (
        cat_id     serial,
        cat_name   text NOT NULL,
        cat_public boolean DEFAULT FALSE,
        cat_owner  integer NOT NULL,

        CONSTRAINT bobo_tools_analyser_categories_pkey PRIMARY KEY (cat_id)
        -- CONSTRAINT bobo_tools_analyser_categories_fk1 FOREIGN KEY (cat_owner)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.analyser_categories TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.analyser_categories TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.analyser_categories TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.analyser_categories TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_categories_cat_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_categories_cat_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_categories_cat_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.analyser_categories            IS 'Table with categories of analyser tool';
    COMMENT ON COLUMN bobo_tools.analyser_categories.cat_id     IS 'Analyser category serial id (PK)';
    COMMENT ON COLUMN bobo_tools.analyser_categories.cat_name   IS 'Analyser category name';
    COMMENT ON COLUMN bobo_tools.analyser_categories.cat_public IS 'Analyser category flag if public';
    COMMENT ON COLUMN bobo_tools.analyser_categories.cat_owner  IS 'Analyser category owner';

    -- Tabella relazionale che associa le categorie di analyser ai gruppi utenti per gestirne la visibilità
    -- DROP TABLE IF EXISTS bobo_tools.analyser_category_groups;
    CREATE TABLE bobo_tools.analyser_category_groups
    (
        acg_id serial,
        cat_id integer NOT NULL,
        gr_id  integer NOT NULL,

        CONSTRAINT bobo_tools_analyser_category_groups_pkey PRIMARY KEY (acg_id),
        CONSTRAINT bobo_tools_analyser_category_groups_ukey UNIQUE (cat_id, gr_id)
        -- CONSTRAINT bobo_tools_analyser_category_groups_fk1 FOREIGN KEY (cat_id)
        --     REFERENCES bobo_tools.analyser_categories (cat_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_tools_analyser_category_groups_fk2 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.analyser_category_groups TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.analyser_category_groups TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.analyser_category_groups TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.analyser_category_groups TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_category_groups_acg_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_category_groups_acg_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_category_groups_acg_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.analyser_category_groups        IS 'Table that holds relations between categories and groups';
    COMMENT ON COLUMN bobo_tools.analyser_category_groups.acg_id IS 'Table serial id (PK)';
    COMMENT ON COLUMN bobo_tools.analyser_category_groups.cat_id IS 'Analyser category id (FK)';
    COMMENT ON COLUMN bobo_tools.analyser_category_groups.gr_id  IS 'Bobo group id (FK)';

    -- Tabella che contiene le macro di analyser sottoforma di json
    -- DROP TABLE IF EXISTS bobo_tools.analyser_macros;
    CREATE TABLE bobo_tools.analyser_macros
    (
        macro_id          serial,
        macro_category    integer NOT NULL,
        macro_object      jsonb NOT NULL,
        macro_last_update timestamp without time zone DEFAULT NULL,

        CONSTRAINT bobo_tools_analyser_macros_pkey PRIMARY KEY (macro_id)
        -- CONSTRAINT bobo_tools_analyser_macros_fk1 FOREIGN KEY (macro_category)
        --     REFERENCES bobo_tools.analyser_categories (cat_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.analyser_macros TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.analyser_macros TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.analyser_macros TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.analyser_macros TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_macros_macro_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_macros_macro_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_macros_macro_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.analyser_macros                   IS 'Table with macro data of analyser tool';
    COMMENT ON COLUMN bobo_tools.analyser_macros.macro_id          IS 'Macro serial id (PK)';
    COMMENT ON COLUMN bobo_tools.analyser_macros.macro_category    IS 'Macro category id (FK)';
    COMMENT ON COLUMN bobo_tools.analyser_macros.macro_object      IS 'Macro JSON object';
    COMMENT ON COLUMN bobo_tools.analyser_macros.macro_last_update IS 'Macro last update date';

    -- Tabella che contiene le impostazioni utente dell'applicativo "Analyser"
    -- DROP TABLE IF EXISTS bobo_tools.analyser_options;
    CREATE TABLE bobo_tools.analyser_options
    (
        option_id          serial,
        option_user        integer NOT NULL,
        option_object      jsonb NOT NULL,
        option_last_update timestamp without time zone DEFAULT NULL,

        CONSTRAINT bobo_tools_analyser_options_pkey PRIMARY KEY (option_id)
        -- CONSTRAINT bobo_tools_analyser_options_fk1 FOREIGN KEY (option_user)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.analyser_options TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.analyser_options TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.analyser_options TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.analyser_options TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_options_option_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_options_option_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_options_option_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.analyser_options                    IS 'Table with user options of analyser tool';
    COMMENT ON COLUMN bobo_tools.analyser_options.option_id          IS 'Option serial id (PK)';
    COMMENT ON COLUMN bobo_tools.analyser_options.option_user        IS 'Option user id (FK)';
    COMMENT ON COLUMN bobo_tools.analyser_options.option_object      IS 'Option JSON object';
    COMMENT ON COLUMN bobo_tools.analyser_options.option_last_update IS 'Option last update date';

    -- Tabella che contiene gli alberi di analyser sottoforma di array di oggetti
    -- DROP TABLE IF EXISTS bobo_tools.analyser_trees;
    CREATE TABLE bobo_tools.analyser_trees
    (
        tree_id     serial,
        tree_name   text NOT NULL,
        tree_object jsonb NOT NULL,
        tree_public boolean DEFAULT FALSE,
        tree_order  smallint,
        tree_owner  integer NOT NULL,

        CONSTRAINT bobo_tools_analyser_trees_pkey PRIMARY KEY (tree_id)
        -- CONSTRAINT bobo_tools_analyser_trees_fk1 FOREIGN KEY (tree_owner)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.analyser_trees TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.analyser_trees TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.analyser_trees TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.analyser_trees TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_trees_tree_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_trees_tree_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_trees_tree_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.analyser_trees             IS 'Table with station trees of analyser tool';
    COMMENT ON COLUMN bobo_tools.analyser_trees.tree_id     IS 'Tree serial id (PK)';
    COMMENT ON COLUMN bobo_tools.analyser_trees.tree_name   IS 'Tree name';
    COMMENT ON COLUMN bobo_tools.analyser_trees.tree_object IS 'Tree JSON object';
    COMMENT ON COLUMN bobo_tools.analyser_trees.tree_public IS 'Tree flag if public';
    COMMENT ON COLUMN bobo_tools.analyser_trees.tree_order  IS 'Tree order';

    -- Tabella che contiene le informazioni relative alle associazioni alberi di Analyser - gruppi
    -- DROP TABLE IF EXISTS bobo_tools.analyser_trees_groups;
    CREATE TABLE bobo_tools.analyser_trees_groups
    (
        atg_id  serial,
        tree_id integer NOT NULL,
        gr_id   integer NOT NULL,

        CONSTRAINT bobo_tools_analyser_trees_groups_pkey PRIMARY KEY (atg_id),
        CONSTRAINT bobo_tools_analyser_trees_groups_ukey UNIQUE (tree_id, gr_id)
        -- CONSTRAINT bobo_tools_analyser_trees_groups_fk1 FOREIGN KEY (tree_id)
        --     REFERENCES bobo_tools.analyser_trees (tree_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_tools_analyser_trees_groups_fk2 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.analyser_trees_groups TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.analyser_trees_groups TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.analyser_trees_groups TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.analyser_trees_groups TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_trees_groups_atg_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_trees_groups_atg_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.analyser_trees_groups_atg_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.analyser_trees_groups         IS 'Table that holds relations between trees and groups';
    COMMENT ON COLUMN bobo_tools.analyser_trees_groups.atg_id  IS 'Table serial id (PK)';
    COMMENT ON COLUMN bobo_tools.analyser_trees_groups.tree_id IS 'Analyser tree id (FK)';
    COMMENT ON COLUMN bobo_tools.analyser_trees_groups.gr_id   IS 'Bobo group id (FK)';

    -- Tabella che contiene le informazioni relative alle annotazioni aggiunte ai dati
    -- DROP TABLE IF EXISTS bobo_tools.annotations;
    CREATE TABLE bobo_tools.annotations
    (
        ann_id   serial,
        ann_desc text NOT NULL,
        us_id    integer NOT NULL,

        CONSTRAINT bobo_tools_annotations_pkey PRIMARY KEY (ann_id)
        -- CONSTRAINT bobo_tools_annotations_fk1 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.annotations TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.annotations TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.annotations TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.annotations TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.annotations_ann_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.annotations_ann_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.annotations_ann_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.annotations          IS 'Table containing all data annotations';
    COMMENT ON COLUMN bobo_tools.annotations.ann_id   IS 'Annotation serial id (PK)';
    COMMENT ON COLUMN bobo_tools.annotations.ann_desc IS 'Annotation description';
    COMMENT ON COLUMN bobo_tools.annotations.us_id    IS 'Annotation creator (FK)';

    -- Tabella che contiene i testi delle descrizioni contenuti in dataview
    -- DROP TABLE IF EXISTS bobo_tools.dataview_descriptions;
    CREATE TABLE bobo_tools.dataview_descriptions
    (
        desc_id          serial,
        desc_live        text,
        desc_indicator   text,
        desc_last_values text,
        desc_infos       text,

        CONSTRAINT bobo_tools_dataview_descriptions_pkey PRIMARY KEY (desc_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.dataview_descriptions TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.dataview_descriptions TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.dataview_descriptions TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.dataview_descriptions TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo_tools.dataview_descriptions                  IS 'Table with dataview option';
    COMMENT ON COLUMN bobo_tools.dataview_descriptions.desc_id          IS 'Dataview description id';
    COMMENT ON COLUMN bobo_tools.dataview_descriptions.desc_live        IS 'Dataview description data live';
    COMMENT ON COLUMN bobo_tools.dataview_descriptions.desc_indicator   IS 'Dataview description data indicators';
    COMMENT ON COLUMN bobo_tools.dataview_descriptions.desc_last_values IS 'Dataview description available values';
    COMMENT ON COLUMN bobo_tools.dataview_descriptions.desc_infos       IS 'Dataview description info charts and tables';

    -- Tabella che contiene i testi delle descrizioni contenuti in dataview
    -- DROP TABLE IF EXISTS bobo_tools.dataview_descriptions;
    CREATE TABLE bobo_tools.dataview_files
    (
        file_id   serial,
        file_desc text,
        file_url  text NOT NULL,
        file_icon text,

        CONSTRAINT bobo_tools_dataview_files_pkey PRIMARY KEY (file_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.dataview_files TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.dataview_files TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.dataview_files TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.dataview_files TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo_tools.dataview_files           IS 'Table with dataview option';
    COMMENT ON COLUMN bobo_tools.dataview_files.file_id   IS 'Dataview file id';
    COMMENT ON COLUMN bobo_tools.dataview_files.file_desc IS 'Dataview file description';
    COMMENT ON COLUMN bobo_tools.dataview_files.file_url  IS 'Dataview file url';
    COMMENT ON COLUMN bobo_tools.dataview_files.file_icon IS 'Dataview file icon';

    -- Tabella che contiene la legenda per gli indicators
    -- DROP TABLE IF EXISTS bobo_tools.dataview_indicators_legend;
    CREATE TABLE bobo_tools.dataview_indicators_legend
    (
        legend_id    serial,
        legend_desc  text NOT NULL,
        legend_color text NOT NULL,
        legend_order integer,

        CONSTRAINT bobo_tools_dataview_indicators_legend_pkey PRIMARY KEY (legend_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.dataview_indicators_legend TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.dataview_indicators_legend TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.dataview_indicators_legend TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.dataview_indicators_legend TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo_tools.dataview_indicators_legend              IS 'Table with dataview option';
    COMMENT ON COLUMN bobo_tools.dataview_indicators_legend.legend_id    IS 'Dataview legend id';
    COMMENT ON COLUMN bobo_tools.dataview_indicators_legend.legend_desc  IS 'Dataview legend description';
    COMMENT ON COLUMN bobo_tools.dataview_indicators_legend.legend_color IS 'Dataview legend color (hexadecimal)';
    COMMENT ON COLUMN bobo_tools.dataview_indicators_legend.legend_order IS 'Dataview legend order';

    -- Tabella che contiene i range per gli indicators
    -- DROP TABLE IF EXISTS bobo_tools.dataview_indicators_range;
    CREATE TABLE bobo_tools.dataview_indicators_range
    (
        range_id     serial,
        param_id     integer DEFAULT NULL,
        pollutant_id integer DEFAULT NULL,
        stat_id      integer DEFAULT NULL,
        range_limits jsonb NOT NULL,

        CONSTRAINT bobo_tools_dataview_indicators_range_pkey PRIMARY KEY (range_id),
        CONSTRAINT bobo_tools_dataview_indicators_range_check CHECK ((param_id IS NULL) <> (pollutant_id IS NULL))
        -- CONSTRAINT bobo_tools_dataview_indicators_range_fk1 FOREIGN KEY (param_id)
        --     REFERENCES metadata.parameters (param_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_tools_dataview_indicators_range_fk2 FOREIGN KEY (pollutant_id)
        --     REFERENCES infoaria.pollutants (pollutant_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_tools_dataview_indicators_range_fk3 FOREIGN KEY (stat_id)
        --     REFERENCES clients_stats.statistics (stat_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.dataview_indicators_range TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.dataview_indicators_range TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.dataview_indicators_range TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.dataview_indicators_range TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo_tools.dataview_indicators_range              IS 'Table with dataview option';
    COMMENT ON COLUMN bobo_tools.dataview_indicators_range.range_id     IS 'Dataview indicator range id';
    COMMENT ON COLUMN bobo_tools.dataview_indicators_range.param_id     IS 'Dataview indicator parameter';
    COMMENT ON COLUMN bobo_tools.dataview_indicators_range.pollutant_id IS 'Dataview indicator pollutant';
    COMMENT ON COLUMN bobo_tools.dataview_indicators_range.pollutant_id IS 'Dataview indicator statistics';
    COMMENT ON COLUMN bobo_tools.dataview_indicators_range.range_limits IS 'Dataview indicator limits jsonb object';

    -- Tabella che contiene le informazioni della coda di job relativa all'applicativo "Dataview"
    -- DROP TABLE IF EXISTS bobo_tools.dataview_jobs_queue;
    CREATE TABLE bobo_tools.dataview_jobs_queue
    (
        djq_id         bigserial NOT NULL,
        djq_uuid       uuid NOT NULL,
        djq_args_obj   jsonb,
        djq_start_ts   timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        djq_end_ts     timestamp,
        djq_result_obj jsonb,
        djq_ack        boolean DEFAULT FALSE,

        CONSTRAINT bobo_tools_dataview_jobs_queue_pkey PRIMARY KEY (djq_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.dataview_jobs_queue TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.dataview_jobs_queue TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.dataview_jobs_queue TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.dataview_jobs_queue TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.dataview_jobs_queue_djq_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.dataview_jobs_queue_djq_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.dataview_jobs_queue_djq_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.dataview_jobs_queue                IS 'Table holding the queue of jobs called by the web application';
    COMMENT ON COLUMN bobo_tools.dataview_jobs_queue.djq_id         IS 'Job queue id (PK)';
    COMMENT ON COLUMN bobo_tools.dataview_jobs_queue.djq_uuid       IS 'User UUID to notify';
    COMMENT ON COLUMN bobo_tools.dataview_jobs_queue.djq_args_obj   IS 'Job arguments';
    COMMENT ON COLUMN bobo_tools.dataview_jobs_queue.djq_start_ts   IS 'Job start timestamp';
    COMMENT ON COLUMN bobo_tools.dataview_jobs_queue.djq_end_ts     IS 'Job end timestamp';
    COMMENT ON COLUMN bobo_tools.dataview_jobs_queue.djq_result_obj IS 'Job result with fields for toasts shown in the application';
    COMMENT ON COLUMN bobo_tools.dataview_jobs_queue.djq_ack        IS 'Job notification acknowledge';

    -- Tabella che contiene le informazioni relative alle impostazioni generali degli applicativi del portale
    -- DROP TABLE IF EXISTS bobo_tools.general_options;
    CREATE TABLE bobo_tools.general_options
    (
        go_id   serial,
        go_tool text NOT NULL CHECK ( go_tool IN ('analyser', 'visualizer', 'validation', 'dataview', 'sysadmin') ), -- TIPO DI VOCE
        go_obj  jsonb NOT NULL DEFAULT '{}'::jsonb,
        go_desc text,

        CONSTRAINT bobo_tools_general_options_pkey PRIMARY KEY (go_id),
        CONSTRAINT bobo_tools_general_options_ukey UNIQUE (go_tool)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.general_options TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.general_options TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.general_options TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.general_options TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.general_options_go_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.general_options_go_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.general_options_go_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.general_options         IS 'Table containing all tools general options';
    COMMENT ON COLUMN bobo_tools.general_options.go_id   IS 'Option serial id (PK)';
    COMMENT ON COLUMN bobo_tools.general_options.go_tool IS 'Tool to which the options belong';
    COMMENT ON COLUMN bobo_tools.general_options.go_obj  IS 'Option JSONB';
    COMMENT ON COLUMN bobo_tools.general_options.go_desc IS 'Option description';

    -- Tabella che contiene ile informazioni relative al widget "Link utili" della homepage
    -- DROP TABLE IF EXISTS bobo_tools.homepage_links;
    CREATE TABLE bobo_tools.homepage_links
    (
        link_id        serial,
        link_name      text NOT NULL,
        link_url       text NOT NULL,
        link_image_url text,
        link_default   boolean DEFAULT FALSE,
        us_id          integer DEFAULT NULL,
        portal_id      integer,

        CONSTRAINT bobo_tools_homepage_links_pkey PRIMARY KEY (link_id)
        -- CONSTRAINT bobo_tools_homepage_links_fk1 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_tools_homepage_links_fk2 FOREIGN KEY (portal_id)
        --     REFERENCES bobo.portals (portal_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.homepage_links TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.homepage_links TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.homepage_links TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.homepage_links TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.homepage_links_link_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.homepage_links_link_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.homepage_links_link_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.homepage_links                IS 'Table with widget of user tool';
    COMMENT ON COLUMN bobo_tools.homepage_links.link_id        IS 'Link serial id (PK)';
    COMMENT ON COLUMN bobo_tools.homepage_links.link_name      IS 'Link name';
    COMMENT ON COLUMN bobo_tools.homepage_links.link_url       IS 'Link URL';
    COMMENT ON COLUMN bobo_tools.homepage_links.link_image_url IS 'Link banner URL';
    COMMENT ON COLUMN bobo_tools.homepage_links.link_default   IS 'Link is default (TRUE/FALSE)';
    COMMENT ON COLUMN bobo_tools.homepage_links.us_id          IS 'Link creator';

    -- Tabella che contiene impostazioni aggiuntive dei parametri da visualizzare nei tool
    -- DROP TABLE IF EXISTS bobo_tools.parameters_options;
    CREATE TABLE bobo_tools.parameters_options
    (
        param_id    integer,
        param_order smallint,

        CONSTRAINT bobo_tools_parameters_options_pkey PRIMARY KEY (param_id)
        -- CONSTRAINT bobo_tools_parameters_options_fk1 FOREIGN KEY (param_id)
        --         REFERENCES metadata.parameters (param_id) MATCH SIMPLE
        --         ON UPDATE CASCADE
        --         ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.parameters_options TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.parameters_options TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.parameters_options TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.parameters_options TO group_readonly;

    -- comments
    COMMENT ON TABLE  bobo_tools.parameters_options             IS 'Table with extra options for parameters used in tools';
    COMMENT ON COLUMN bobo_tools.parameters_options.param_id    IS 'Parameter id';
    COMMENT ON COLUMN bobo_tools.parameters_options.param_order IS 'Parameter order';

    -- Tabella che contiene le informazioni relative alle impostazioni di ogni associazione portale-pagina
    -- DROP TABLE IF EXISTS bobo_tools.portal_options;
    CREATE TABLE bobo_tools.portal_options
    (
        po_id     serial,
        portal_id integer NOT NULL,
        page_id   integer NOT NULL,
        po_obj    jsonb NOT NULL DEFAULT '{}'::jsonb,
        po_desc   text,

        CONSTRAINT bobo_tools_portal_options_pkey PRIMARY KEY (po_id),
        CONSTRAINT bobo_tools_portal_options_ukey UNIQUE (portal_id, page_id)
        -- CONSTRAINT bobo_tools_portal_options_fk1 FOREIGN KEY (portal_id)
        --     REFERENCES bobo.portals (portal_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_tools_general_options_fk2 FOREIGN KEY (page_id)
        --     REFERENCES bobo.pages (page_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.portal_options TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.portal_options TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.portal_options TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.portal_options TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.portal_options_po_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.portal_options_po_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.portal_options_po_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.portal_options           IS 'Table containing options foreach relation portal-page';
    COMMENT ON COLUMN bobo_tools.portal_options.po_id     IS 'Option serial id (PK)';
    COMMENT ON COLUMN bobo_tools.portal_options.portal_id IS 'Portal ID (FK)';
    COMMENT ON COLUMN bobo_tools.portal_options.page_id   IS 'Page ID (FK)';
    COMMENT ON COLUMN bobo_tools.portal_options.po_obj    IS 'Option JSONB';
    COMMENT ON COLUMN bobo_tools.portal_options.po_desc   IS 'Option description';

    -- Tabella che contiene le impostazioni utente dell'applicativo "Validazione"
    -- DROP TABLE IF EXISTS bobo_tools.validation_options;
    CREATE TABLE bobo_tools.validation_options
    (
        option_id          serial,
        option_user        integer NOT NULL,
        option_object      jsonb NOT NULL,
        option_last_update timestamp without time zone DEFAULT NULL,

        CONSTRAINT bobo_tools_validation_options_pkey PRIMARY KEY (option_id)
        -- CONSTRAINT bobo_tools_validation_options_fk1 FOREIGN KEY (option_user)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.validation_options TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.validation_options TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.validation_options TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.validation_options TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.validation_options_option_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.validation_options_option_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.validation_options_option_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.validation_options                    IS 'Table with user options of validation tool';
    COMMENT ON COLUMN bobo_tools.validation_options.option_id          IS 'Option serial id (PK)';
    COMMENT ON COLUMN bobo_tools.validation_options.option_user        IS 'Option user id (FK)';
    COMMENT ON COLUMN bobo_tools.validation_options.option_object      IS 'Option JSON object';
    COMMENT ON COLUMN bobo_tools.validation_options.option_last_update IS 'Option last update date';

    -- Tabella che contiene gli alberi di Validazione sottoforma di array di oggetti
    -- DROP TABLE IF EXISTS bobo_tools.validation_trees;
    CREATE TABLE bobo_tools.validation_trees
    (
        tree_id     serial,
        tree_name   text  NOT NULL,
        tree_object jsonb NOT NULL,
        tree_public boolean DEFAULT FALSE,
        tree_order  smallint,
        tree_owner  integer NOT NULL,

        CONSTRAINT bobo_tools_validation_trees_pkey PRIMARY KEY (tree_id)
        -- CONSTRAINT bobo_tools_validation_trees_fk1 FOREIGN KEY (tree_owner)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.validation_trees TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.validation_trees TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.validation_trees TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.validation_trees TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.validation_trees_tree_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.validation_trees_tree_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.validation_trees_tree_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.validation_trees             IS 'Table with station trees of validation tool';
    COMMENT ON COLUMN bobo_tools.validation_trees.tree_id     IS 'Tree serial id (PK)';
    COMMENT ON COLUMN bobo_tools.validation_trees.tree_name   IS 'Tree name';
    COMMENT ON COLUMN bobo_tools.validation_trees.tree_object IS 'Tree JSON object';
    COMMENT ON COLUMN bobo_tools.validation_trees.tree_public IS 'Tree flag if public';
    COMMENT ON COLUMN bobo_tools.validation_trees.tree_order  IS 'Tree order';
    COMMENT ON COLUMN bobo_tools.validation_trees.tree_owner  IS 'Tree owner (FK)';

    -- Tabella che contiene le informazioni relative alle associazioni alberi di Validazione - gruppi
    -- DROP TABLE IF EXISTS bobo_tools.validation_trees_groups;
    CREATE TABLE bobo_tools.validation_trees_groups
    (
        vtg_id  serial,
        tree_id integer NOT NULL,
        gr_id   integer NOT NULL,

        CONSTRAINT bobo_tools_validation_trees_groups_pkey PRIMARY KEY (vtg_id),
        CONSTRAINT bobo_tools_validation_trees_groups_ukey UNIQUE (tree_id, gr_id)
        -- CONSTRAINT bobo_tools_validation_trees_groups_fk1 FOREIGN KEY (tree_id)
        --     REFERENCES bobo_tools.validation_trees (tree_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_tools_validation_trees_groups_fk2 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.validation_trees_groups TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.validation_trees_groups TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.validation_trees_groups TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.validation_trees_groups TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.validation_trees_groups_vtg_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.validation_trees_groups_vtg_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.validation_trees_groups_vtg_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.validation_trees_groups         IS 'Table that holds relations between trees and groups';
    COMMENT ON COLUMN bobo_tools.validation_trees_groups.vtg_id  IS 'Table serial id (PK)';
    COMMENT ON COLUMN bobo_tools.validation_trees_groups.tree_id IS 'Validation tree id (FK)';
    COMMENT ON COLUMN bobo_tools.validation_trees_groups.gr_id   IS 'Bobo group id (FK)';

    -- Tabella che contiene le associazioni albero di Validazione - pagina di Visualizer
    -- DROP TABLE IF EXISTS bobo_tools.validation_trees_pages;
    CREATE TABLE bobo_tools.validation_trees_pages
    (
        vtp_id  serial,
        tree_id integer NOT NULL,
        page_id integer NOT NULL,

        CONSTRAINT bobo_tools_validation_trees_pages_pkey PRIMARY KEY (vtp_id),
        CONSTRAINT bobo_tools_validation_trees_pages_ukey UNIQUE (tree_id, page_id)
        -- CONSTRAINT bobo_tools_validation_trees_pages_fk1 FOREIGN KEY (tree_id)
        --     REFERENCES bobo_tools.validation_trees (tree_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_tools_validation_trees_pages_fk2 FOREIGN KEY (page_id)
        --     REFERENCES bobo_tools.visualizer_pages (page_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.validation_trees_pages TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.validation_trees_pages TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.validation_trees_pages TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.validation_trees_pages TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.validation_trees_pages_vtp_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.validation_trees_pages_vtp_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.validation_trees_pages_vtp_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.validation_trees_pages         IS 'Table with links between validation trees and visualizer pages';
    COMMENT ON COLUMN bobo_tools.validation_trees_pages.vtp_id  IS 'Table serial id (PK)';
    COMMENT ON COLUMN bobo_tools.validation_trees_pages.tree_id IS 'Validation tree id';
    COMMENT ON COLUMN bobo_tools.validation_trees_pages.page_id IS 'Visualizer page id';

    -- Tabella che contiene le pagine di visualizer
    -- DROP TABLE IF EXISTS bobo_tools.visualizer_pages;
    CREATE TABLE bobo_tools.visualizer_pages
    (
        page_id          serial,
        page_category    integer NOT NULL,
        page_name        text NOT NULL,
        page_last_update timestamp without time zone DEFAULT NULL,

        CONSTRAINT bobo_tools_visualizer_pages_pkey PRIMARY KEY (page_id)
        -- CONSTRAINT bobo_tools_visualizer_pages_fk1 FOREIGN KEY (page_category)
        --     REFERENCES bobo_tools.visualizer_categories (cat_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.visualizer_pages TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.visualizer_pages TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.visualizer_pages TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.visualizer_pages TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_pages_page_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_pages_page_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_pages_page_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.visualizer_pages                  IS 'Table with pages of Visualizer tool';
    COMMENT ON COLUMN bobo_tools.visualizer_pages.page_id          IS 'Page serial id (PK)';
    COMMENT ON COLUMN bobo_tools.visualizer_pages.page_category    IS 'Page category id (FK)';
    COMMENT ON COLUMN bobo_tools.visualizer_pages.page_name        IS 'Page name';
    COMMENT ON COLUMN bobo_tools.visualizer_pages.page_last_update IS 'Page last update date';

    -- Tabella che contiene le categorie sotto cui si raggruppano le pagine
    -- DROP TABLE IF EXISTS bobo_tools.visualizer_categories;
    CREATE TABLE bobo_tools.visualizer_categories
    (
        cat_id     serial,
        cat_name   text NOT NULL,
        cat_public boolean DEFAULT FALSE,
        cat_owner  integer NOT NULL,

        CONSTRAINT bobo_tools_visualizer_categories_pkey PRIMARY KEY (cat_id)
        -- CONSTRAINT bobo_tools_visualizer_categories_fk1 FOREIGN KEY (cat_owner)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.visualizer_categories TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.visualizer_categories TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.visualizer_categories TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.visualizer_categories TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_categories_cat_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_categories_cat_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_categories_cat_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.visualizer_categories            IS 'Table with categories of visualizer tool';
    COMMENT ON COLUMN bobo_tools.visualizer_categories.cat_id     IS 'Visualizer category serial id (PK)';
    COMMENT ON COLUMN bobo_tools.visualizer_categories.cat_name   IS 'Visualizer category name';
    COMMENT ON COLUMN bobo_tools.visualizer_categories.cat_public IS 'Visualizer category flag if public';
    COMMENT ON COLUMN bobo_tools.visualizer_categories.cat_owner  IS 'Visualizer category owner';

    -- Tabella relazionale che associa le categorie di visualizer ai gruppi utenti per gestirne la visibilità
    -- DROP TABLE IF EXISTS bobo_tools.visualizer_category_groups;
    CREATE TABLE bobo_tools.visualizer_category_groups
    (
        acg_id serial,
        cat_id integer NOT NULL,
        gr_id  integer NOT NULL,

        CONSTRAINT bobo_tools_visualizer_category_groups_pkey PRIMARY KEY (acg_id),
        CONSTRAINT bobo_tools_visualizer_category_groups_ukey UNIQUE (cat_id, gr_id)
        -- CONSTRAINT bobo_tools_visualizer_category_groups_fk1 FOREIGN KEY (cat_id)
        --     REFERENCES bobo_tools.visualizer_categories (cat_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT bobo_tools_visualizer_category_groups_fk2 FOREIGN KEY (gr_id)
        --     REFERENCES bobo.groups (gr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.visualizer_category_groups TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.visualizer_category_groups TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.visualizer_category_groups TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.visualizer_category_groups TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_category_groups_acg_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_category_groups_acg_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_category_groups_acg_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.visualizer_category_groups        IS 'Table that holds relations between categories and groups';
    COMMENT ON COLUMN bobo_tools.visualizer_category_groups.acg_id IS 'Table serial id (PK)';
    COMMENT ON COLUMN bobo_tools.visualizer_category_groups.cat_id IS 'Visualizer category id (FK)';
    COMMENT ON COLUMN bobo_tools.visualizer_category_groups.gr_id  IS 'Bobo group id (FK)';

    -- Tabella che contiene le macro di visualizer sottoforma di json
    -- DROP TABLE IF EXISTS bobo_tools.visualizer_macros;
    CREATE TABLE bobo_tools.visualizer_macros
    (
        macro_id          serial,
        macro_page        integer NOT NULL,
        macro_object      jsonb NOT NULL,
        macro_last_update timestamp without time zone DEFAULT NULL,

        CONSTRAINT bobo_tools_visualizer_macros_pkey PRIMARY KEY (macro_id)
        -- CONSTRAINT bobo_tools_visualizer_macros_fk1 FOREIGN KEY (macro_page)
        --     REFERENCES bobo_tools.visualizer_pages (page_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.visualizer_macros TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.visualizer_macros TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.visualizer_macros TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.visualizer_macros TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_macros_macro_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_macros_macro_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_macros_macro_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.visualizer_macros                   IS 'Table with macro data of visualizer tool';
    COMMENT ON COLUMN bobo_tools.visualizer_macros.macro_id          IS 'Macro serial id (PK)';
    COMMENT ON COLUMN bobo_tools.visualizer_macros.macro_page        IS 'Macro page id (FK)';
    COMMENT ON COLUMN bobo_tools.visualizer_macros.macro_object      IS 'Macro JSON object';
    COMMENT ON COLUMN bobo_tools.visualizer_macros.macro_last_update IS 'Macro last update date';

    -- Tabella che contiene le impostazioni utente dell'applicativo "Visualizer"
    -- DROP TABLE IF EXISTS bobo_tools.visualizer_options;
    CREATE TABLE bobo_tools.visualizer_options
    (
        option_id          serial,
        option_user        integer NOT NULL,
        option_object      jsonb NOT NULL,
        option_last_update timestamp without time zone DEFAULT NULL,

        CONSTRAINT bobo_tools_visualizer_options_pkey PRIMARY KEY (option_id)
        -- CONSTRAINT bobo_tools_visualizer_options_fk1 FOREIGN KEY (option_user)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.visualizer_options TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.visualizer_options TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.visualizer_options TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.visualizer_options TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_options_option_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_options_option_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.visualizer_options_option_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.visualizer_options                    IS 'Table with user options of visualizer tool';
    COMMENT ON COLUMN bobo_tools.visualizer_options.option_id          IS 'Option serial id (PK)';
    COMMENT ON COLUMN bobo_tools.visualizer_options.option_user        IS 'Option user id (FK)';
    COMMENT ON COLUMN bobo_tools.visualizer_options.option_object      IS 'Option JSON object';
    COMMENT ON COLUMN bobo_tools.visualizer_options.option_last_update IS 'Option last update date';

    -- Tabella che contiene le informazioni relative alle scale del vento
    -- DROP TABLE IF EXISTS bobo_tools.wind_scales;
    CREATE TABLE bobo_tools.wind_scales
    (
        ws_id   serial,
        ws_name text NOT NULL, -- TIPO DI VOCE
        ws_obj  jsonb NOT NULL DEFAULT '{}'::jsonb,

        CONSTRAINT bobo_tools_wind_scales_pkey PRIMARY KEY (ws_id),
        CONSTRAINT bobo_tools_wind_scales_ukey UNIQUE (ws_name)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    bobo_tools.wind_scales TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.wind_scales TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.wind_scales TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.wind_scales TO group_readonly;
    GRANT ALL ON SEQUENCE bobo_tools.wind_scales_ws_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE bobo_tools.wind_scales_ws_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE bobo_tools.wind_scales_ws_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  bobo_tools.wind_scales         IS 'Table containing all wind scales for windrose';
    COMMENT ON COLUMN bobo_tools.wind_scales.ws_id   IS 'Scale id (PK)';
    COMMENT ON COLUMN bobo_tools.wind_scales.ws_name IS 'Scale name';
    COMMENT ON COLUMN bobo_tools.wind_scales.ws_obj  IS 'Scale JSONB';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- Vista che raccoglie le informazioni relative alle categorie presenti nell'applicativo "Analyser"
    -- DROP VIEW IF EXISTS bobo_tools.view_analyser_categories;
    CREATE OR REPLACE VIEW bobo_tools.view_analyser_categories AS
    SELECT
        ac.cat_id     AS category_id,
        ac.cat_name   AS category_name,
        ac.cat_public AS category_public,
        ac.cat_owner  AS category_owner,
        um.comp_id    AS category_owner_company,
        um.portal_id  AS category_owner_portal,
        ARRAY(
            SELECT analyser_category_groups.gr_id
            FROM bobo_tools.analyser_category_groups
            WHERE analyser_category_groups.cat_id = ac.cat_id
        )             AS groups_id
    FROM bobo_tools.analyser_categories ac
    LEFT JOIN bobo.users_metadata um ON um.us_id = ac.cat_owner
    ORDER BY cat_id;

    -- grants
    GRANT ALL ON TABLE    bobo_tools.view_analyser_categories TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.view_analyser_categories TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.view_analyser_categories TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.view_analyser_categories TO group_readonly;

    -- Vista che raccoglie le informazioni relative alle macro presenti nell'applicativo "Analyser"
    -- DROP VIEW IF EXISTS bobo_tools.view_analyser_macros;
    CREATE OR REPLACE VIEW bobo_tools.view_analyser_macros AS
    SELECT
        am.macro_id                                                          AS macro_id,
        ac.cat_id                                                            AS category_id,
        ac.cat_name                                                          AS category_name,

        -- FIELDS OF MACRO --
        ( am.macro_object ->  'macro' )::jsonb ->> 'name'                    AS macro_name,
        ( am.macro_object ->  'macro' )::jsonb ->> 'description'             AS macro_description,
        (( am.macro_object -> 'macro' )::jsonb ->> 'po_id'        )::integer AS macro_position,
        (( am.macro_object -> 'macro' )::jsonb ->> 'chart_y_min'  )::real    AS macro_chart_y_min,
        (( am.macro_object -> 'macro' )::jsonb ->> 'chart_y_max'  )::real    AS macro_chart_y_max,
        (( am.macro_object -> 'macro' )::jsonb ->> 'legendx_angle')::integer AS macro_legendx_angle,
        (( am.macro_object -> 'macro' )::jsonb ->> 'int_time'     )::integer AS macro_int_time,
        ( am.macro_object ->  'macro' )::jsonb ->> 'percent_data'            AS macro_percent_data,
        ( am.macro_object ->  'macro' )::jsonb ->> 'aggregation'             AS macro_aggregation,
        ( am.macro_object ->  'params')::jsonb                               AS macro_parameters,

        am.macro_last_update                                                 AS macro_last_update
    FROM bobo_tools.analyser_macros am
    LEFT JOIN bobo_tools.analyser_categories ac ON am.macro_category = ac.cat_id
    ORDER BY macro_name;

    -- grants
    GRANT ALL ON TABLE    bobo_tools.view_analyser_macros TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.view_analyser_macros TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.view_analyser_macros TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.view_analyser_macros TO group_readonly;

    -- Vista che raccoglie le informazioni relative agli alberi dell'applicativo "Analyser"
    -- DROP VIEW IF EXISTS bobo_tools.view_analyser_trees;
    CREATE OR REPLACE VIEW bobo_tools.view_analyser_trees AS
    SELECT
        at.tree_id       AS tree_id,
        at.tree_name     AS tree_name,
        at.tree_public   AS tree_public,
        at.tree_object   AS tree_object,
        at.tree_order    AS tree_order,
        at.tree_owner    AS tree_owner,
        um.comp_id       AS tree_owner_company,
        um.portal_id     AS tree_owner_portal,
        ARRAY(
            SELECT atg.gr_id
            FROM bobo_tools.analyser_trees_groups atg
            WHERE atg.tree_id = at.tree_id
        )                AS groups_id
    FROM bobo_tools.analyser_trees at
    LEFT JOIN bobo.users_metadata um ON um.us_id = at.tree_owner
    ORDER BY tree_id;

    -- grants
    GRANT ALL ON TABLE    bobo_tools.view_analyser_trees TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.view_analyser_trees TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.view_analyser_trees TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.view_analyser_trees TO group_readonly;

    -- Vista che raccoglie le informazioni relative agli alberi dell'applicativo "Validazione"
    -- DROP VIEW IF EXISTS bobo_tools.view_validation_trees;
    CREATE OR REPLACE VIEW bobo_tools.view_validation_trees AS
    SELECT
        vt.tree_id          AS tree_id,
        vt.tree_name        AS tree_name,
        vt.tree_object      AS tree_object,
        vt.tree_public      AS tree_public,
        vt.tree_order       AS tree_order,
        vt.tree_owner       AS tree_owner,
        um.comp_id          AS tree_owner_company,
        um.portal_id        AS tree_owner_portal,
        ARRAY(
            SELECT vtg.gr_id
            FROM bobo_tools.validation_trees_groups vtg
            WHERE vtg.tree_id = vt.tree_id
        )                   AS groups_id,
        ARRAY(
            SELECT vtp.page_id
            FROM bobo_tools.validation_trees_pages vtp
            WHERE vtp.tree_id = vt.tree_id
        )                   AS panels_id
    FROM bobo_tools.validation_trees vt
    LEFT JOIN bobo.users_metadata um ON um.us_id = vt.tree_owner
    ORDER BY tree_id;

    -- grants
    GRANT ALL ON TABLE    bobo_tools.view_validation_trees TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.view_validation_trees TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.view_validation_trees TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.view_validation_trees TO group_readonly;

    -- Vista che raccoglie le informazioni relative alle associazioni albero di Validazione - pagina di Visualizer
    -- DROP VIEW IF EXISTS bobo_tools.view_validation_trees_pages;
    CREATE OR REPLACE VIEW bobo_tools.view_validation_trees_pages AS
    SELECT
        vt.tree_id       AS tree_id,
        vt.tree_name     AS tree_name,
        vt.tree_public   AS tree_public,
        vt.tree_order    AS tree_order,
        vp.page_id       AS page_id,
        vp.page_category AS page_category,
        vp.page_name     AS page_name
    FROM bobo_tools.validation_trees vt
    LEFT JOIN bobo_tools.validation_trees_pages vtp USING (tree_id)
    LEFT JOIN bobo_tools.visualizer_pages vp USING (page_id)
    ORDER BY tree_id;

    -- grants
    GRANT ALL ON TABLE    bobo_tools.view_validation_trees_pages TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.view_validation_trees_pages TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.view_validation_trees_pages TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.view_validation_trees_pages TO group_readonly;

    -- Vista che raccoglie le informazioni relative alle categorie presenti nell'applicativo "Visualizer"
    -- DROP VIEW IF EXISTS bobo_tools.view_visualizer_categories;
    CREATE OR REPLACE VIEW bobo_tools.view_visualizer_categories AS
    SELECT
        vc.cat_id     AS category_id,
        vc.cat_name   AS category_name,
        vc.cat_public AS category_public,
        vc.cat_owner  AS category_owner,
        um.comp_id    AS category_owner_company,
        um.portal_id  AS category_owner_portal,
        ARRAY(
            SELECT vcg.gr_id
            FROM bobo_tools.visualizer_category_groups vcg
            WHERE vcg.cat_id = vc.cat_id
        )             AS groups_id
    FROM bobo_tools.visualizer_categories vc
    LEFT JOIN bobo.users_metadata um ON um.us_id = vc.cat_owner
    ORDER BY cat_id;

    -- grants
    GRANT ALL ON TABLE    bobo_tools.view_visualizer_categories TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.view_visualizer_categories TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.view_visualizer_categories TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.view_visualizer_categories TO group_readonly;

    -- Vista che raccoglie le informazioni relative alle pagine presenti nell'applicativo "Visualizer"
    -- DROP VIEW IF EXISTS bobo_tools.view_analyser_macros;
    CREATE OR REPLACE VIEW bobo_tools.view_visualizer_pages AS
    SELECT
        vc.cat_id           AS category_id,
        vc.cat_name         AS category_name,
        vp.page_id          AS page_id,
        vp.page_name        AS page_name,
        vp.page_last_update AS page_last_update
    FROM bobo_tools.visualizer_pages vp
    LEFT JOIN bobo_tools.visualizer_categories vc ON vp.page_category = vc.cat_id
    ORDER BY page_name;

    -- grants
    GRANT ALL ON TABLE    bobo_tools.view_visualizer_pages TO group_admin;
    GRANT ALL ON TABLE    bobo_tools.view_visualizer_pages TO group_bobo;
    GRANT ALL ON TABLE    bobo_tools.view_visualizer_pages TO group_tools;
    GRANT SELECT ON TABLE bobo_tools.view_visualizer_pages TO group_readonly;

    -- Vista che raccoglie le info dei widget in relazione ai gruppi a cui l'utente è associato
    -- DROP VIEW IF EXISTS bobo_tools.view_user_widgets;
    CREATE OR REPLACE VIEW bobo.view_user_widgets AS
    SELECT DISTINCT ON (u.us_id, w.wdg_name)
        u.us_id AS user_id,
        u.us_name AS user_name,
        u.us_2nd_name AS user_second_name,
        u.us_surname AS user_surname,
        u.us_role AS user_role,
        u.us_email AS user_email,
        u.us_phone AS user_phone,
        u.us_mobile AS user_mobile,
        u.us_avatar AS user_avatar,
        u.us_avatar_thumb AS user_avatar_thumb,
        ARRAY( SELECT user_groups.gr_id
               FROM bobo.user_groups
              WHERE user_groups.us_id = u.us_id) AS user_groups_array,
        w.wdg_id,
        w.wdg_name,
        w.wdg_description,
        w.wdg_image_url,
        w.wdg_page_html,
        --wg.*,
        g.gr_id,
        g.gr_name,
        g.gr_shortname,
        g.gr_insert_time
    FROM bobo.users u
        LEFT JOIN bobo.user_groups ug USING (us_id)
        LEFT JOIN bobo.groups g USING (gr_id)
        LEFT JOIN bobo.group_widgets wg USING (gr_id)
        LEFT JOIN bobo_tools.homepage_widgets w USING (wdg_id)
    WHERE w.wdg_id IS NOT NULL
    ORDER BY
        u.us_id, w.wdg_name;

    -- grants
    GRANT ALL ON TABLE    bobo.view_user_widgets TO group_admin;
    GRANT ALL ON TABLE    bobo.view_user_widgets TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_user_widgets TO group_tools;
    GRANT SELECT ON TABLE bobo.view_user_widgets TO group_readonly;

    -- comments
    COMMENT ON VIEW bobo.view_user_widgets IS 'Available widgets per user';

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Funzione che genera automaticamente le finestre in fase di creazione di una macro (applicativo "Visualizer")
    -- DROP FUNCTION bobo_tools.f_visualizer_auto_generate_macro(integer[], integer[], integer[], integer, boolean);
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

    -- grants
    GRANT EXECUTE ON FUNCTION bobo_tools.f_visualizer_auto_generate_macro(integer[], integer[], integer[], integer, boolean) TO group_readonly;
    GRANT EXECUTE ON FUNCTION bobo_tools.f_visualizer_auto_generate_macro(integer[], integer[], integer[], integer, boolean) TO group_bobo;
    GRANT EXECUTE ON FUNCTION bobo_tools.f_visualizer_auto_generate_macro(integer[], integer[], integer[], integer, boolean) TO group_admin;
    GRANT EXECUTE ON FUNCTION bobo_tools.f_visualizer_auto_generate_macro(integer[], integer[], integer[], integer, boolean) TO group_tools;

    -- comment
    COMMENT ON FUNCTION bobo_tools.f_visualizer_auto_generate_macro(integer[], integer[], integer[], integer, boolean) IS 'Auto generate structures for visualizer macro';

-- SCHEMA metadata

    -- DROP SCHEMA IF EXISTS metadata CASCADE;
    CREATE SCHEMA metadata
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA metadata TO group_admin;
    GRANT USAGE ON SCHEMA metadata TO group_bobo;
    GRANT USAGE ON SCHEMA metadata TO group_readonly;
    GRANT USAGE ON SCHEMA metadata TO group_tools;
    GRANT USAGE ON SCHEMA metadata TO user_swam;
    COMMENT ON SCHEMA metadata IS 'Metadata schema for OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TYPES
    -- --------------------------------------------------------------------------------------------

    -- Generic data extraction enum type
    -- DROP TYPE IF EXISTS metadata.e_aggregations;
    CREATE TYPE metadata.e_aggregations AS ENUM ('hh', 'dd', 'mm', 'yy');

    -- grants
    GRANT USAGE ON TYPE metadata.e_aggregations TO group_admin;
    GRANT USAGE ON TYPE metadata.e_aggregations TO group_bobo;
    GRANT USAGE ON TYPE metadata.e_aggregations TO group_tools;
    GRANT USAGE ON TYPE metadata.e_aggregations TO group_readonly;

    -- comments
    COMMENT ON TYPE metadata.e_aggregations IS 'Enum used to pass aggregation to generic data extraction functions';

    -- DROP TYPE IF EXISTS metadata.e_treatments;
    CREATE TYPE metadata.e_treatments AS ENUM ('avg', 'sum', 'max', 'min', 'cum', 'sldavg', 'first');

    -- grants
    GRANT USAGE ON TYPE metadata.e_treatments TO group_admin;
    GRANT USAGE ON TYPE metadata.e_treatments TO group_bobo;
    GRANT USAGE ON TYPE metadata.e_treatments TO group_tools;
    GRANT USAGE ON TYPE metadata.e_treatments TO group_readonly;

    -- comments
    COMMENT ON TYPE metadata.e_treatments IS 'Enum used to pass parameter treatment to generic data extraction functions';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    --  Tabella che contiene i codici di validazione finale usati dall'utente
    -- DROP TABLE IF EXISTS metadata.final_validation_codes;
    CREATE TABLE metadata.final_validation_codes
    (
        fvc_id           serial,
        fvc_code_id      integer NOT NULL,
        fvc_code_desc    text     NOT NULL,
        fvc_code_default boolean  DEFAULT FALSE,
        fvc_code_valid   boolean  DEFAULT NULL,

        CONSTRAINT metadata_final_validation_codes_pkey PRIMARY KEY (fvc_id),
        CONSTRAINT metadata_final_validation_codes_ukey UNIQUE (fvc_code_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.final_validation_codes TO group_admin;
    GRANT ALL ON TABLE    metadata.final_validation_codes TO group_bobo;
    GRANT ALL ON TABLE    metadata.final_validation_codes TO group_tools;
    GRANT SELECT ON TABLE metadata.final_validation_codes TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.final_validation_codes                  IS 'The table contains all the codes used for user validation';
    COMMENT ON COLUMN metadata.final_validation_codes.fvc_id           IS 'Validation code serial ID';
    COMMENT ON COLUMN metadata.final_validation_codes.fvc_code_id      IS 'Validation code main ID';
    COMMENT ON COLUMN metadata.final_validation_codes.fvc_code_desc    IS 'Validation code description';
    COMMENT ON COLUMN metadata.final_validation_codes.fvc_code_default IS 'Validation code by default';
    COMMENT ON COLUMN metadata.final_validation_codes.fvc_code_valid   IS 'If validation code is valid or not';

    -- Tabella che contiene le informazioni riguardo alle reti presenti sul portale
    -- DROP TABLE IF EXISTS metadata.stations_network_type;
    CREATE TABLE metadata.stations_network_type
    (
        st_network_id   serial NOT NULL,
        st_network_desc text NOT NULL,
        st_network_logo text DEFAULT NULL,
        st_network_name text DEFAULT NULL,

        CONSTRAINT metadata_stations_network_type_pkey PRIMARY KEY (st_network_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_network_type TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_network_type TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_network_type TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_network_type TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.stations_network_type_st_network_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_network_type_st_network_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_network_type_st_network_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.stations_network_type                 IS 'Support table for station network type';
    COMMENT ON COLUMN metadata.stations_network_type.st_network_id   IS 'Station network type id';
    COMMENT ON COLUMN metadata.stations_network_type.st_network_desc IS 'Station network type desc';
    COMMENT ON COLUMN metadata.stations_network_type.st_network_logo IS 'Station network type logo';
    COMMENT ON COLUMN metadata.stations_network_type.st_network_logo IS 'Station network type name';

    -- custom station id sequence starting from 1000
    CREATE SEQUENCE metadata.stations_station_id_seq
        INCREMENT 1
        START 1000
        MINVALUE 1000
        MAXVALUE 2147483647
        CACHE 1;

    -- grants
    GRANT ALL ON SEQUENCE metadata.stations_station_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_station_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_station_id_seq TO group_tools;

    -- Tabella che contiene le principali informazioni delle stazioni presenti sul portale
    -- DROP TABLE IF EXISTS metadata.stations;
    CREATE TABLE metadata.stations
    (
        station_id           integer DEFAULT nextval('metadata.stations_station_id_seq') NOT NULL,
        station_name         text NOT NULL,
        station_schema       text DEFAULT NULL,
        station_table        text DEFAULT NULL,
        station_prefix       text DEFAULT NULL,
        station_active       boolean DEFAULT TRUE,
        station_note         text DEFAULT NULL,
        station_ext_id       text DEFAULT NULL,
        station_file_header  text DEFAULT NULL,
        station_remote_ctrl  text DEFAULT NULL,
        station_insert_ts    timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        station_insert_us_id integer,
        station_update_ts    timestamp without time zone,
        station_update_us_id integer,

        CONSTRAINT metadata_stations_pkey PRIMARY KEY (station_id),
        CONSTRAINT metadata_stations_ukey UNIQUE NULLS NOT DISTINCT (station_schema, station_table, station_prefix)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations TO group_admin;
    GRANT ALL ON TABLE    metadata.stations TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations TO group_tools;
    GRANT SELECT ON TABLE metadata.stations TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.stations                      IS 'Table with principal information about stations';
    COMMENT ON COLUMN metadata.stations.station_id           IS 'Station ID';
    COMMENT ON COLUMN metadata.stations.station_name         IS 'Station name';
    COMMENT ON COLUMN metadata.stations.station_schema       IS 'Station schema';
    COMMENT ON COLUMN metadata.stations.station_table        IS 'Station table with new data each 30/60 minutes';
    COMMENT ON COLUMN metadata.stations.station_prefix       IS 'Station prefix (può indicare una vista es. mview_)';
    COMMENT ON COLUMN metadata.stations.station_active       IS 'Station status if active or not';
    COMMENT ON COLUMN metadata.stations.station_note         IS 'Station note';
    COMMENT ON COLUMN metadata.stations.station_ext_id       IS 'Station external id';
    COMMENT ON COLUMN metadata.stations.station_file_header  IS 'Station file header (periphery)';
    COMMENT ON COLUMN metadata.stations.station_remote_ctrl  IS 'Station ID for remote control';
    COMMENT ON COLUMN metadata.stations.station_insert_ts    IS 'Station insert timestamp';
    COMMENT ON COLUMN metadata.stations.station_insert_us_id IS 'Station insert user';
    COMMENT ON COLUMN metadata.stations.station_update_ts    IS 'Station last update timestamp';
    COMMENT ON COLUMN metadata.stations.station_update_us_id IS 'Station last update user';

    -- parameter id sequence
    CREATE SEQUENCE metadata.parameters_param_id_seq
        INCREMENT 1
        START 1
        MINVALUE 1
        MAXVALUE 2147483647
        CACHE 1;

    -- grants
    GRANT ALL ON SEQUENCE metadata.parameters_param_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.parameters_param_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.parameters_param_id_seq TO group_tools;

    -- Tabella che contiene le principali informazioni dei parametri presenti sul portale
    -- DROP TABLE IF EXISTS metadata.parameters;
    CREATE TABLE metadata.parameters
    (
        param_id        integer DEFAULT nextval('metadata.parameters_param_id_seq') NOT NULL,
        param_name      text NOT NULL,
        param_unit      text NOT NULL,
        param_conv      real DEFAULT 1,
        param_unit_conv text NOT NULL,
        param_offset    real DEFAULT NULL,
        param_decimals  smallint DEFAULT 2,
        param_active    boolean DEFAULT TRUE,
        param_note      text DEFAULT NULL,
        param_ext_id    text DEFAULT NULL,

        CONSTRAINT metadata_parameters_pkey PRIMARY KEY (param_id),
        CONSTRAINT metadata_parameters_ukey1 UNIQUE (param_name, param_unit)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.parameters TO group_admin;
    GRANT ALL ON TABLE    metadata.parameters TO group_bobo;
    GRANT ALL ON TABLE    metadata.parameters TO group_tools;
    GRANT SELECT ON TABLE metadata.parameters TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.parameters                 IS 'Table with principal information about parameter';
    COMMENT ON COLUMN metadata.parameters.param_id        IS 'Parameter ID';
    COMMENT ON COLUMN metadata.parameters.param_name      IS 'Parameter name';
    COMMENT ON COLUMN metadata.parameters.param_unit      IS 'Parameter unit';
    COMMENT ON COLUMN metadata.parameters.param_conv      IS 'Parameter conversion factor';
    COMMENT ON COLUMN metadata.parameters.param_unit_conv IS 'Parameter converted unit';
    COMMENT ON COLUMN metadata.parameters.param_offset    IS 'Parameter offset';
    COMMENT ON COLUMN metadata.parameters.param_decimals  IS 'Parameter number of decimals';
    COMMENT ON COLUMN metadata.parameters.param_active    IS 'Parameter status if active or not';
    COMMENT ON COLUMN metadata.parameters.param_note      IS 'Parameter note';
    COMMENT ON COLUMN metadata.parameters.param_ext_id    IS 'Parameter external id';

    -- Tabella che contiene ulteriori informazioni riguardo alle stazioni presenti sul portale
    -- DROP TABLE IF EXISTS metadata.stations_info;
    CREATE TABLE metadata.stations_info
    (
        station_id              integer NOT NULL,
        st_info_shortname       text NOT NULL,
        st_info_longname        text,
        st_info_startup_date    timestamp without time zone,
        st_info_dismiss_date    timestamp without time zone,
        st_info_basepath        text,
        st_info_locality        text,
        st_info_zone            text,
        st_info_basin           text,
        st_info_community       text,
        st_info_north_utm       real,
        st_info_east_utm        real,
        st_info_altitude        real,
        st_info_lat_wgs84       real,
        st_info_lon_wgs84       real,
        st_info_network_type_fk integer DEFAULT 1, -- rete di appartenenza
        st_info_roaming_type_fk integer DEFAULT 1, -- tipo di stanziamento (fissa,mobile ecc.ecc.)
        st_info_typology_fk     integer DEFAULT 2, -- tipo stazione (meteo, chimica ecc.ecc.)
        st_info_measure_fk      integer DEFAULT 1, -- tipo di misura (continua, periodica, on demand ecc)
        st_info_cadence_fk      integer DEFAULT 5, -- cadenza misura generale della stazione (oraria, 10 min ecc.ecc.)
        st_info_note            text,
        st_info_export_id       text,
        st_info_national_code   text,
        st_info_accepted_delay  integer DEFAULT 60, -- minuti di ritardo accettato, prima di evidenziare un problema
        st_info_ws_name         text,
        st_info_import_ws_id    text,

        CONSTRAINT metadata_stations_info_pkey PRIMARY KEY (station_id)
        -- CONSTRAINT metadata_stations_info_fk1 FOREIGN KEY (station_id)
        --     REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_info_fk2 FOREIGN KEY (st_info_network_type_fk)
        --     REFERENCES metadata.stations_network_type (st_network_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_info_fk3 FOREIGN KEY (st_info_roaming_type_fk)
        --     REFERENCES metadata.stations_roaming_type (st_roaming_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_info_fk4 FOREIGN KEY (st_info_typology_fk)
        --     REFERENCES metadata.stations_typology (st_typology_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_info_fkey5 FOREIGN KEY (st_info_measure_fk)
        -- REFERENCES metadata.measures_type (measure_type_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_info_fk6 FOREIGN KEY (st_info_cadence_fk)
        --     REFERENCES metadata.measures_cadence (measure_cadence_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_info TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_info TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_info TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_info TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.stations_info                         IS 'Table with principal information about stations';
    COMMENT ON COLUMN metadata.stations_info.station_id              IS 'Reference to station_id in metadata.stations';
    COMMENT ON COLUMN metadata.stations_info.st_info_shortname       IS 'Station shortname';
    COMMENT ON COLUMN metadata.stations_info.st_info_longname        IS 'Station longname';
    COMMENT ON COLUMN metadata.stations_info.st_info_startup_date    IS 'Station startup date';
    COMMENT ON COLUMN metadata.stations_info.st_info_dismiss_date    IS 'Station dismiss date';
    COMMENT ON COLUMN metadata.stations_info.st_info_locality        IS 'Station locality';
    COMMENT ON COLUMN metadata.stations_info.st_info_zone            IS 'Station zone';
    COMMENT ON COLUMN metadata.stations_info.st_info_basin           IS 'Station basin';
    COMMENT ON COLUMN metadata.stations_info.st_info_community       IS 'Station community';
    COMMENT ON COLUMN metadata.stations_info.st_info_north_utm       IS 'Station coordinates in meter';
    COMMENT ON COLUMN metadata.stations_info.st_info_east_utm        IS 'Station coordinates in meter';
    COMMENT ON COLUMN metadata.stations_info.st_info_altitude        IS 'Station coordinates in meter';
    COMMENT ON COLUMN metadata.stations_info.st_info_lat_wgs84       IS 'Station coordinates in degrees';
    COMMENT ON COLUMN metadata.stations_info.st_info_lon_wgs84       IS 'Station coordinates in degrees';
    COMMENT ON COLUMN metadata.stations_info.st_info_network_type_fk IS 'Station network type foreign key';
    COMMENT ON COLUMN metadata.stations_info.st_info_roaming_type_fk IS 'Station type (if mobile or not) foreign key';
    COMMENT ON COLUMN metadata.stations_info.st_info_typology_fk     IS 'Station typology foreign key';
    COMMENT ON COLUMN metadata.stations_info.st_info_measure_fk      IS 'Station measures type foreign key';
    COMMENT ON COLUMN metadata.stations_info.st_info_cadence_fk      IS 'Station measures cadences foreign key';
    COMMENT ON COLUMN metadata.stations_info.st_info_note            IS 'Station metadata notes';
    COMMENT ON COLUMN metadata.stations_info.st_info_export_id       IS 'Station export id, for external link';
    COMMENT ON COLUMN metadata.stations_info.st_info_national_code   IS 'Station national code';
    COMMENT ON COLUMN metadata.stations_info.st_info_accepted_delay  IS 'Max accepted delay before raise a problem';
    COMMENT ON COLUMN metadata.stations_info.st_info_ws_name         IS 'Station name for web service aims';
    COMMENT ON COLUMN metadata.stations_info.st_info_import_ws_id    IS 'Station import ID for ws';

    -- Tabella che associa i parametri alle stazioni
    -- DROP TABLE IF EXISTS metadata.station_parameters;
    CREATE TABLE metadata.stations_parameters
    (
        stpr_id           serial NOT NULL,
        station_id        integer NOT NULL,
        param_id          integer NOT NULL,
        stpr_table_id     integer NOT NULL,
        stpr_active       boolean DEFAULT TRUE,
        stpr_startup_date timestamp without time zone DEFAULT NULL,
        stpr_dismiss_date timestamp without time zone DEFAULT NULL,
        stpr_note         text DEFAULT NULL,
        stpr_ext_id       text DEFAULT NULL,
        stpr_group_id     integer,

        CONSTRAINT metadata_stations_parameters_pkey PRIMARY KEY (stpr_id),
        CONSTRAINT metadata_stations_parameters_ukey UNIQUE (station_id, stpr_table_id)
        -- CONSTRAINT metadata_stations_parameters_fkey1 FOREIGN KEY (param_id)
        -- REFERENCES metadata.parameters (param_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_parameters_fkey2 FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_parameters TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_parameters TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_parameters TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_parameters TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.stations_parameters_stpr_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_parameters_stpr_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_parameters_stpr_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.stations_parameters                   IS 'Relational table with information about station-parameters';
    COMMENT ON COLUMN metadata.stations_parameters.stpr_id           IS 'Station parameters serial id';
    COMMENT ON COLUMN metadata.stations_parameters.station_id        IS 'Station ID';
    COMMENT ON COLUMN metadata.stations_parameters.param_id          IS 'Parameter ID';
    COMMENT ON COLUMN metadata.stations_parameters.stpr_table_id     IS 'Station parameters ID in data tables';
    COMMENT ON COLUMN metadata.stations_parameters.stpr_active       IS 'Station parameters active flag';
    COMMENT ON COLUMN metadata.stations_parameters.stpr_startup_date IS 'Station parameters startup date';
    COMMENT ON COLUMN metadata.stations_parameters.stpr_dismiss_date IS 'Station parameters dismiss date';
    COMMENT ON COLUMN metadata.stations_parameters.stpr_note         IS 'Station parameters note';
    COMMENT ON COLUMN metadata.stations_parameters.stpr_ext_id       IS 'Station parameters external id';
    COMMENT ON COLUMN metadata.stations_parameters.stpr_group_id     IS 'Station parameters group id (unique for station - group of parameters)';

    -- group id sequence
    CREATE SEQUENCE metadata.stations_parameters_stpr_group_id_seq
        INCREMENT 1
        START 1
        MINVALUE 1
        MAXVALUE 2147483647
        CACHE 1;

    -- grants
    GRANT ALL ON SEQUENCE metadata.stations_parameters_stpr_group_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_parameters_stpr_group_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_parameters_stpr_group_id_seq TO group_tools;

    -- Tabella che contiene le informazioni aggiuntive per ciascuna associazione stazione-parametro
    -- DROP TABLE IF EXISTS metadata.stations_params_info;
    CREATE TABLE metadata.stations_params_info
    (
        stpr_id              integer NOT NULL,
        stpr_pluvio_heated   boolean,
        stpr_info_measure_fk integer DEFAULT 1, -- continua
        stpr_info_cadence_fk integer, -- eredita dalla stazione se NULL
        stpr_export_id1      text,
        stpr_export_id2      text,
        stpr_info_ws_id      text,
        stpr_import_ws_id    text,

        CONSTRAINT metadata_stations_params_info_pkey PRIMARY KEY (stpr_id)
        -- CONSTRAINT metadata_stations_params_info_fkey1 FOREIGN KEY (stpr_id)
        -- REFERENCES metadata.stations_parameters (stpr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_params_info_fkey2 FOREIGN KEY (stpr_info_measure_fk)
        -- REFERENCES metadata.measures_type (measure_type_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_params_info_fkey3 FOREIGN KEY (stpr_info_cadence_fk)
        -- REFERENCES metadata.measures_cadence (measure_cadence_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_params_info TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_params_info TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_params_info TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_params_info TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.stations_params_info                      IS 'Relational table with additional information about station-parameters';
    COMMENT ON COLUMN metadata.stations_params_info.stpr_id              IS 'Station parameters id (FK)';
    COMMENT ON COLUMN metadata.stations_params_info.stpr_pluvio_heated   IS 'Station parameter rain gauge heated';
    COMMENT ON COLUMN metadata.stations_params_info.stpr_info_measure_fk IS 'Station parameter measure type (FK)';
    COMMENT ON COLUMN metadata.stations_params_info.stpr_info_cadence_fk IS 'Station parameter measure cadence (FK)';
    COMMENT ON COLUMN metadata.stations_params_info.stpr_export_id1      IS 'Station parameter export code #1';
    COMMENT ON COLUMN metadata.stations_params_info.stpr_export_id2      IS 'Station parameter export code #2';
    COMMENT ON COLUMN metadata.stations_params_info.stpr_info_ws_id      IS 'Station parameter ws id';
    COMMENT ON COLUMN metadata.stations_params_info.stpr_import_ws_id    IS 'Station parameter import ws id';

    -- Tabella che contiene le informazioni riguardo lo stato delle varie stazioni
    -- DROP TABLE IF EXISTS metadata.stations_status;
    CREATE TABLE metadata.stations_status
    (
        station_id               integer NOT NULL,
        ss_suspended             boolean DEFAULT FALSE,
        ss_ws_publish            boolean DEFAULT FALSE,
        ss_dataview_publish      boolean DEFAULT FALSE,
        ss_custom_export_publish boolean DEFAULT FALSE,
        ss_real_time             boolean DEFAULT FALSE,
        ss_email                 boolean DEFAULT FALSE,
        ss_telegram              boolean DEFAULT FALSE,

        CONSTRAINT metadata_stations_status_pkey PRIMARY KEY (station_id)
        -- CONSTRAINT metadata_stations_status_fk1 FOREIGN KEY (station_id)
        --     REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_status TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_status TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_status TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_status TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.stations_status                          IS 'Table with information about stations status';
    COMMENT ON COLUMN metadata.stations_status.station_id               IS 'Reference to station_id in metadata.stations';
    COMMENT ON COLUMN metadata.stations_status.ss_suspended             IS 'Station suspended';
    COMMENT ON COLUMN metadata.stations_status.ss_ws_publish            IS 'Station to publish on webservice';
    COMMENT ON COLUMN metadata.stations_status.ss_dataview_publish      IS 'Station to publish on dataview';
    COMMENT ON COLUMN metadata.stations_status.ss_custom_export_publish IS 'Station to publish on custom export (another db, sira ecc)';
    COMMENT ON COLUMN metadata.stations_status.ss_real_time             IS 'Enabled real time (true/false)';
    COMMENT ON COLUMN metadata.stations_status.ss_email                 IS 'Enabled notification via email (true/false)';
    COMMENT ON COLUMN metadata.stations_status.ss_telegram              IS 'Enabled notification via telegram (true/false)';

    -- Tabella che associa le stazioni ai comuni di appartenenza
    -- DROP TABLE IF EXISTS metadata.stations_municipality;
    CREATE TABLE metadata.stations_municipality
    (
        sm_id      serial NOT NULL,
        mu_id      integer NOT NULL,
        station_id integer NOT NULL,

        CONSTRAINT metadata_stations_municipality_pkey PRIMARY KEY (sm_id),
        CONSTRAINT metadata_stations_municipality_ukey UNIQUE (station_id)
        -- CONSTRAINT metadata_stations_municipality_fkey1 FOREIGN KEY (mu_id)
        -- REFERENCES main.municipalities (mu_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_municipality_fkey2 FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_municipality TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_municipality TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_municipality TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_municipality TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.stations_municipality_sm_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_municipality_sm_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_municipality_sm_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.stations_municipality            IS 'Relational table with information about region-municipality-stations';
    COMMENT ON COLUMN metadata.stations_municipality.sm_id      IS 'Table primary key (serial)';
    COMMENT ON COLUMN metadata.stations_municipality.mu_id      IS 'Municipality id (FK)';
    COMMENT ON COLUMN metadata.stations_municipality.station_id IS 'Station id (FK)';

    -- Tabella che associa gli strumenti alle stazioni
    -- DROP TABLE IF EXISTS metadata.stations_instruments;
    CREATE TABLE metadata.stations_instruments
    (
        stin_id           serial,
        station_id        integer NOT NULL,
        instr_id          integer NOT NULL,
        stpr_group_id     integer NOT NULL,
        stin_startup_date timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
        stin_dismiss_date timestamp without time zone DEFAULT 'infinity'::timestamp,
        stin_note         text,
        stin_master       boolean DEFAULT TRUE,

        CONSTRAINT metadata_stations_instruments_pkey PRIMARY KEY (stin_id)
        -- CONSTRAINT metadata_stations_instruments_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_instruments_fkey2 FOREIGN KEY (instr_id)
        -- REFERENCES equipments.instruments (instr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_instruments_check EXCLUDE USING GIST (
        --     stpr_group_id WITH =,
        --     tsrange(stin_startup_date, stin_dismiss_date, '[]') WITH &&
        -- ) WHERE (stpr_group_id != 0),
        -- CONSTRAINT metadata_stations_instruments_check2 EXCLUDE USING GIST (
        --     instr_id WITH =,
        --     tsrange(stin_startup_date, stin_dismiss_date, '[]') WITH &&
        -- )
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_instruments TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_instruments TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_instruments TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_instruments TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.stations_instruments_stin_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_instruments_stin_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_instruments_stin_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.stations_instruments                   IS 'Relational table with information about stations-instruments';
    COMMENT ON COLUMN metadata.stations_instruments.stin_id           IS 'Station-instrument relation ID primary key';
    COMMENT ON COLUMN metadata.stations_instruments.station_id        IS 'Station ID ';
    COMMENT ON COLUMN metadata.stations_instruments.instr_id          IS 'Instrument ID ';
    COMMENT ON COLUMN metadata.stations_instruments.stpr_group_id     IS 'Station parameter group ID (FK)';
    COMMENT ON COLUMN metadata.stations_instruments.stin_startup_date IS 'Station-instrument relation startup date';
    COMMENT ON COLUMN metadata.stations_instruments.stin_dismiss_date IS 'Station-instrument relation startup date';
    COMMENT ON COLUMN metadata.stations_instruments.stin_note         IS 'Station-instrument relation note';
    COMMENT ON COLUMN metadata.stations_instruments.stin_master       IS 'Station-instrument master relation (TRUE/FALSE)';

    -- Tabella che contiene tutte le possibili aggregazioni usate nelle varie applicazioni
    -- DROP TABLE IF EXISTS metadata.apps_aggregation;
    CREATE TABLE metadata.app_aggregations
    (
        app_agg_id         serial,
        measure_cadence_id integer NOT NULL,
        app_agg_label      metadata.e_aggregations NOT NULL,
        app_agg_default    boolean DEFAULT FALSE,

        CONSTRAINT metadata_app_aggregations_pkey PRIMARY KEY (app_agg_id)
        -- CONSTRAINT metadata_app_aggregations_fk1 FOREIGN KEY (measure_cadence_id)
        -- REFERENCES metadata.measures_cadence (measure_cadence_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.app_aggregations TO group_admin;
    GRANT ALL ON TABLE    metadata.app_aggregations TO group_bobo;
    GRANT ALL ON TABLE    metadata.app_aggregations TO group_tools;
    GRANT SELECT ON TABLE metadata.app_aggregations TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.app_aggregations_app_agg_id_seq TO group_admin;

    -- comments
    COMMENT ON TABLE  metadata.app_aggregations                    IS 'The table contains all the possible aggregations used in bobo applications';
    COMMENT ON COLUMN metadata.app_aggregations.app_agg_id         IS 'App aggregations serial id';
    COMMENT ON COLUMN metadata.app_aggregations.measure_cadence_id IS 'App aggregations measure cadence id FK';
    COMMENT ON COLUMN metadata.app_aggregations.app_agg_label      IS 'App aggregations labels';
    COMMENT ON COLUMN metadata.app_aggregations.app_agg_default    IS 'App aggregations default: TRUE / FALSE';

    -- Tabella che contiene i codici usati per la prima validazione automatica
    -- DROP TABLE IF EXISTS metadata.auto_validation_codes;
    CREATE TABLE metadata.auto_validation_codes
    (
        avc_id           serial,
        avc_code_id      integer NOT NULL,
        avc_code_desc    text NOT NULL,
        avc_code_default boolean DEFAULT FALSE,
        avc_code_valid   boolean DEFAULT NULL,

        CONSTRAINT metadata_auto_validation_codes_pkey PRIMARY KEY (avc_id),
        CONSTRAINT metadata_auto_validation_codes_ukey UNIQUE (avc_code_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.auto_validation_codes TO group_admin;
    GRANT ALL ON TABLE    metadata.auto_validation_codes TO group_bobo;
    GRANT ALL ON TABLE    metadata.auto_validation_codes TO group_tools;
    GRANT SELECT ON TABLE metadata.auto_validation_codes TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.auto_validation_codes                  IS 'The table contains all the codes used for first automatic validation';
    COMMENT ON COLUMN metadata.auto_validation_codes.avc_id           IS 'Validation code serial ID';
    COMMENT ON COLUMN metadata.auto_validation_codes.avc_code_id      IS 'Validation code main ID';
    COMMENT ON COLUMN metadata.auto_validation_codes.avc_code_desc    IS 'Validation code description';
    COMMENT ON COLUMN metadata.auto_validation_codes.avc_code_default IS 'Validation code by default';
    COMMENT ON COLUMN metadata.auto_validation_codes.avc_code_valid   IS 'If validation code is valid or not';

    -- Tabella che contiene le informazioni riguardo le campagne presenti sul portale
    -- DROP TABLE IF EXISTS metadata.campaigns;
    CREATE TABLE metadata.campaigns
    (
        camp_id       serial,
        camp_name     text NOT NULL,
        camp_active   boolean DEFAULT true,
        network_types integer[] NOT NULL,
        insert_time   timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT metadata_campaigns_pkey PRIMARY KEY (camp_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.campaigns TO group_admin;
    GRANT ALL ON TABLE    metadata.campaigns TO group_bobo;
    GRANT ALL ON TABLE    metadata.campaigns TO group_tools;
    GRANT SELECT ON TABLE metadata.campaigns TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.campaigns_camp_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.campaigns_camp_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.campaigns_camp_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.campaigns               IS 'Table holding the list of campaigns';
    COMMENT ON COLUMN metadata.campaigns.camp_id       IS 'Campaign ID (PK)';
    COMMENT ON COLUMN metadata.campaigns.camp_name     IS 'Campaign name';
    COMMENT ON COLUMN metadata.campaigns.camp_name     IS 'Campaign active';
    COMMENT ON COLUMN metadata.campaigns.network_types IS 'Network types (FK)';
    COMMENT ON COLUMN metadata.campaigns.insert_time   IS 'Insert time';

    -- Tabella che contiene le principali informazioni dei diagnostici presenti sul portale
    -- DROP TABLE IF EXISTS metadata.diagnostics;
    CREATE TABLE metadata.diagnostics
    (
        diag_id          integer NOT NULL,
        diag_instr_id    text NOT NULL,
        diag_name        text NOT NULL,
        diag_min         real DEFAULT NULL,
        diag_max         real DEFAULT NULL,
        param_id_fk      integer NOT NULL,
        instr_type_id_fk integer,

        CONSTRAINT metadata_diagnostics_pkey PRIMARY KEY (diag_id)
        -- CONSTRAINT metadata_diagnostics_fkey1 FOREIGN KEY (param_id_fk)
        --     REFERENCES metadata.parameters (param_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_diagnostics_fkey2 FOREIGN KEY (instr_type_id_fk)
        --     REFERENCES equipments.instruments_type (instr_type_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.diagnostics TO group_admin;
    GRANT ALL ON TABLE    metadata.diagnostics TO group_bobo;
    GRANT ALL ON TABLE    metadata.diagnostics TO group_tools;
    GRANT SELECT ON TABLE metadata.diagnostics TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.diagnostics                  IS 'Table with principal information about diagnostics';
    COMMENT ON COLUMN metadata.diagnostics.diag_id          IS 'Diagnostic ID';
    COMMENT ON COLUMN metadata.diagnostics.diag_instr_id    IS 'Diagnostic instrument (FK)';
    COMMENT ON COLUMN metadata.diagnostics.diag_name        IS 'Diagnostic name';
    COMMENT ON COLUMN metadata.diagnostics.diag_min         IS 'Diagnostic Min value';
    COMMENT ON COLUMN metadata.diagnostics.diag_max         IS 'Diagnostic Max value';
    COMMENT ON COLUMN metadata.diagnostics.param_id_fk      IS 'Diagnostic parameter id';
    COMMENT ON COLUMN metadata.diagnostics.instr_type_id_fk IS 'Diagnostic instrument type';

    -- Tabella di supporto per la funzione 'metadata.f_get_parameters_from_station_config()'
    -- DROP TABLE IF EXISTS metadata.dl_vocabulary;
    CREATE TABLE metadata.dl_vocabulary
    (
        dl_id    serial,
        dl_key   text,
        dl_value integer,

        CONSTRAINT metadata_dl_vocabulary_pkey PRIMARY KEY (dl_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.dl_vocabulary TO group_admin;
    GRANT ALL ON TABLE    metadata.dl_vocabulary TO group_bobo;
    GRANT ALL ON TABLE    metadata.dl_vocabulary TO group_tools;
    GRANT SELECT ON TABLE metadata.dl_vocabulary TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.dl_vocabulary_dl_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.dl_vocabulary_dl_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.dl_vocabulary_dl_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.dl_vocabulary          IS 'Support table for function metadata.f_get_parameters_from_station_config()';
    COMMENT ON COLUMN metadata.dl_vocabulary.dl_id    IS 'DataLogger vocabulary serial id';
    COMMENT ON COLUMN metadata.dl_vocabulary.dl_key   IS 'DataLogger vocabulary key';
    COMMENT ON COLUMN metadata.dl_vocabulary.dl_value IS 'DataLogger vocabulary value';

    -- Tabella che contiene le varie cadenze di misurazione
    -- DROP TABLE IF EXISTS metadata.measure_cadences;
    CREATE TABLE metadata.measures_cadence
    (
        measure_cadence_id   serial,
        measure_cadence_desc text,
        measure_cadence_min  integer,
        measure_cadence_db   interval,

        CONSTRAINT metadata_measures_cadence_pkey PRIMARY KEY (measure_cadence_id)
    )
    WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.measures_cadence TO group_admin;
    GRANT ALL ON TABLE    metadata.measures_cadence TO group_bobo;
    GRANT ALL ON TABLE    metadata.measures_cadence TO group_tools;
    GRANT SELECT ON TABLE metadata.measures_cadence TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.measures_cadence                      IS 'Support table for measure cadences';
    COMMENT ON COLUMN metadata.measures_cadence.measure_cadence_id   IS 'Measure cadence id (PK)';
    COMMENT ON COLUMN metadata.measures_cadence.measure_cadence_desc IS 'Measure cadence desc';
    COMMENT ON COLUMN metadata.measures_cadence.measure_cadence_min  IS 'Measure cadence minutes';
    COMMENT ON COLUMN metadata.measures_cadence.measure_cadence_db   IS 'Measure cadence interval db';

    -- Tabella che contiene le varie tipologie di misurazione dei parametri
    -- DROP TABLE IF EXISTS metadata.measures_type;
    CREATE TABLE metadata.measures_type
    (
        measure_type_id   serial,
        measure_type_desc text,

        CONSTRAINT metadata_measure_type_pkey PRIMARY KEY (measure_type_id)
    )
    WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.measures_type TO group_admin;
    GRANT ALL ON TABLE    metadata.measures_type TO group_bobo;
    GRANT ALL ON TABLE    metadata.measures_type TO group_tools;
    GRANT SELECT ON TABLE metadata.measures_type TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.measures_type                   IS 'Support table for measure types';
    COMMENT ON COLUMN metadata.measures_type.measure_type_id   IS 'Measure type id (PK)';
    COMMENT ON COLUMN metadata.measures_type.measure_type_desc IS 'Measure type desc';

    -- Tabella contenente lo storico dei fattori di conversione applicati ai parametri
    -- TRUNCATE TABLE metadata.parameters_conversions RESTART IDENTITY;
    CREATE TABLE metadata.parameters_conversions
    (
        pc_id            serial,
        param_id         integer NOT NULL,
        pc_conv          real NOT NULL DEFAULT 1,
        pc_from_fulldate timestamp without time zone NOT NULL DEFAULT '-infinity',
        pc_to_fulldate   timestamp without time zone DEFAULT 'infinity',
        pc_note          text,
        pc_insert_ts     timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        pc_update_ts     timestamp without time zone,

        CONSTRAINT metadata_parameters_conversions_pkey PRIMARY KEY (pc_id)
        -- CONSTRAINT metadata_parameters_conversions_fkey FOREIGN KEY (param_id)
        --     REFERENCES metadata.parameters (param_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_parameters_conversions_check EXCLUDE USING GIST (
        --     param_id WITH =,
        --     tsrange(pc_from_fulldate, pc_to_fulldate, '[]') WITH &&
        -- )
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.parameters_conversions TO group_admin;
    GRANT ALL ON TABLE    metadata.parameters_conversions TO group_bobo;
    GRANT ALL ON TABLE    metadata.parameters_conversions TO group_tools;
    GRANT SELECT ON TABLE metadata.parameters_conversions TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.parameters_conversions_pc_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.parameters_conversions_pc_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.parameters_conversions_pc_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.parameters_conversions                  IS 'Table with the history of the conversion coefficients applied to the parameters';
    COMMENT ON COLUMN metadata.parameters_conversions.pc_id            IS 'Parameter-conversion ID (PK)';
    COMMENT ON COLUMN metadata.parameters_conversions.param_id         IS 'Parameter ID (FK)';
    COMMENT ON COLUMN metadata.parameters_conversions.pc_conv          IS 'Parameter-conversion coefficient';
    COMMENT ON COLUMN metadata.parameters_conversions.pc_from_fulldate IS 'Parameter-conversion start date of the period of use the coefficient';
    COMMENT ON COLUMN metadata.parameters_conversions.pc_to_fulldate   IS 'Parameter-conversion end date of the period of use the coefficient';
    COMMENT ON COLUMN metadata.parameters_conversions.pc_note          IS 'Parameter-conversion note';
    COMMENT ON COLUMN metadata.parameters_conversions.pc_insert_ts     IS 'Parameter-conversion insert timestamp';
    COMMENT ON COLUMN metadata.parameters_conversions.pc_update_ts     IS 'Parameter-conversion update timestamp';

    -- Tabella che contiene ulteriori informazioni riguardo ai parametri presenti sul portale
    -- DROP TABLE IF EXISTS metadata.parameters_info;
    CREATE TABLE metadata.parameters_info
    (
        param_id                integer NOT NULL,
        pm_info_shortname       text DEFAULT NULL,
        pm_info_extra_shortname text DEFAULT NULL,
        pm_info_type_fk         integer NOT NULL,
        pm_info_obj             jsonb DEFAULT '{}'::jsonb,
        pm_info_note            text DEFAULT NULL,
        instr_type_ids          integer[] DEFAULT '{}'::integer[],

        CONSTRAINT metadata_parameters_info_pkey PRIMARY KEY (param_id)
        -- CONSTRAINT metadata_parameters_info_fk1 FOREIGN KEY (pm_info_type_fk)
        --     REFERENCES metadata.parameters_type (pm_type_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_parameters_info_fk2 FOREIGN KEY (param_id)
        --     REFERENCES metadata.parameters (param_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.parameters_info TO group_admin;
    GRANT ALL ON TABLE    metadata.parameters_info TO group_bobo;
    GRANT ALL ON TABLE    metadata.parameters_info TO group_tools;
    GRANT SELECT ON TABLE metadata.parameters_info TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.parameters_info                         IS 'Table with principal information about parameter';
    COMMENT ON COLUMN metadata.parameters_info.param_id                IS 'Parameter ID';
    COMMENT ON COLUMN metadata.parameters_info.pm_info_shortname       IS 'Parameter short name';
    COMMENT ON COLUMN metadata.parameters_info.pm_info_extra_shortname IS 'Parameter extra short name';
    COMMENT ON COLUMN metadata.parameters_info.pm_info_type_fk         IS 'Parameter type (FK)';
    COMMENT ON COLUMN metadata.parameters_info.pm_info_obj             IS 'Parameter object info';
    COMMENT ON COLUMN metadata.parameters_info.pm_info_note            IS 'Parameter note';
    COMMENT ON COLUMN metadata.parameters_info.instr_type_ids          IS 'Array of instruments types that can acquire the parameter';

    -- Tabella che contiene le informazioni riguardo alle tipologie di parametri presenti sul portale
    -- DROP TABLE IF EXISTS metadata.parameters_type;
    CREATE TABLE metadata.parameters_type
    (
        pm_type_id     integer NOT NULL,
        pm_type_desc   text NOT NULL,
        pm_type_icon   text DEFAULT 'fa-solid fa-sparkles',
        pm_type_colour text DEFAULT 'default',

        CONSTRAINT metadata_parameters_type_pkey PRIMARY KEY (pm_type_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.parameters_type TO group_admin;
    GRANT ALL ON TABLE    metadata.parameters_type TO group_bobo;
    GRANT ALL ON TABLE    metadata.parameters_type TO group_tools;
    GRANT SELECT ON TABLE metadata.parameters_type TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.parameters_type                IS 'Table with principal information about parameter types';
    COMMENT ON COLUMN metadata.parameters_type.pm_type_id     IS 'Parameter type ID';
    COMMENT ON COLUMN metadata.parameters_type.pm_type_desc   IS 'Parameter type description';
    COMMENT ON COLUMN metadata.parameters_type.pm_type_icon   IS 'Parameter type icon';
    COMMENT ON COLUMN metadata.parameters_type.pm_type_colour IS 'Parameter type colour';

    -- Tabella che contiene le informazioni riguardo alle unità di misura dei parametri
    -- DROP TABLE metadata.parameters_unit;
    CREATE TABLE metadata.parameters_unit
    (
        pm_unit_id   serial NOT NULL,
        pm_unit_desc text NOT NULL,

        CONSTRAINT metadata_parameters_unit_pkey PRIMARY KEY (pm_unit_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.parameters_unit TO group_admin;
    GRANT ALL ON TABLE    metadata.parameters_unit TO group_bobo;
    GRANT ALL ON TABLE    metadata.parameters_unit TO group_tools;
    GRANT SELECT ON TABLE metadata.parameters_unit TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.parameters_unit              IS 'Table with principal information about parameter units';
    COMMENT ON COLUMN metadata.parameters_unit.pm_unit_id   IS 'Parameter unit ID';
    COMMENT ON COLUMN metadata.parameters_unit.pm_unit_desc IS 'Parameter unit description';

    -- Tabella che contiene i codici di validazione usati in periferia
    -- DROP TABLE IF EXISTS metadata.periphery_validation_codes;
    CREATE TABLE metadata.periphery_validation_codes
    (
        pvc_id           serial,
        pvc_code_id      integer NOT NULL,
        pvc_code_desc    text NOT NULL,
        pvc_code_default boolean DEFAULT FALSE,
        pvc_code_valid   boolean DEFAULT NULL,

        CONSTRAINT metadata_periphery_validation_codes_pkey PRIMARY KEY (pvc_id),
        CONSTRAINT metadata_periphery_validation_codes_ukey UNIQUE (pvc_code_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.periphery_validation_codes TO group_admin;
    GRANT ALL ON TABLE    metadata.periphery_validation_codes TO group_bobo;
    GRANT ALL ON TABLE    metadata.periphery_validation_codes TO group_tools;
    GRANT SELECT ON TABLE metadata.periphery_validation_codes TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.periphery_validation_codes                  IS 'The table contains all the codes used by the periphery';
    COMMENT ON COLUMN metadata.periphery_validation_codes.pvc_id           IS 'Validation code serial ID';
    COMMENT ON COLUMN metadata.periphery_validation_codes.pvc_code_id      IS 'Validation code main ID';
    COMMENT ON COLUMN metadata.periphery_validation_codes.pvc_code_desc    IS 'Validation code description';
    COMMENT ON COLUMN metadata.periphery_validation_codes.pvc_code_default IS 'Validation code by default';
    COMMENT ON COLUMN metadata.periphery_validation_codes.pvc_code_valid   IS 'If validation code is valid or not';

    -- Tabella che contiene le informazioni riguardo gli allegati dei vari siti disponibili sul portale
    -- DROP TABLE IF EXISTS metadata.site_attachments;
    CREATE TABLE metadata.site_attachments
    (
        att_id        serial,
        site_id       integer NOT NULL,
        file_original text NOT NULL,
        file_archive  text NOT NULL,
        file_image    boolean DEFAULT false,
        att_fulldate  timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT metadata_site_attachments_pkey PRIMARY KEY (att_id),
        CONSTRAINT metadata_site_attachments_ukey UNIQUE (site_id, file_archive)
        -- CONSTRAINT metadata_site_attachments_fk1 FOREIGN KEY (site_id)
        --     REFERENCES metadata.sites (site_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.site_attachments TO group_admin;
    GRANT ALL ON TABLE    metadata.site_attachments TO group_bobo;
    GRANT ALL ON TABLE    metadata.site_attachments TO group_tools;
    GRANT SELECT ON TABLE metadata.site_attachments TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.site_attachments_att_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.site_attachments_att_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.site_attachments_att_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.site_attachments               IS 'Table storing cylinders attachments';
    COMMENT ON COLUMN metadata.site_attachments.att_id        IS 'Attachment ID (PK)';
    COMMENT ON COLUMN metadata.site_attachments.site_id       IS 'Site ID (FK)';
    COMMENT ON COLUMN metadata.site_attachments.file_original IS 'Original file name';
    COMMENT ON COLUMN metadata.site_attachments.file_archive  IS 'Archive file name';
    COMMENT ON COLUMN metadata.site_attachments.file_image    IS 'Flag if file is an image';
    COMMENT ON COLUMN metadata.site_attachments.att_fulldate  IS 'Attachment insert fulldate';

    -- Tabella che contiene le informazioni riguardo i siti disponibili sul portale
    -- DROP TABLE IF EXISTS metadata.sites;
    CREATE TABLE metadata.sites
    (
        site_id        serial,
        site_name      text NOT NULL,
        network_types  integer[] NOT NULL,
        mu_id          integer NOT NULL,
        site_locality  text NOT NULL,
        site_altitude  real DEFAULT NULL,
        site_wgs84_lat real NOT NULL,
        site_wgs84_lon real NOT NULL,
        site_note      text,

        CONSTRAINT metadata_sites_pkey PRIMARY KEY (site_id),
        CONSTRAINT metadata_sites_ukey UNIQUE (site_name)
        -- CONSTRAINT metadata_sites_fk1 FOREIGN KEY (mu_id)
        --     REFERENCES main.municipalities (mu_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.sites TO group_admin;
    GRANT ALL ON TABLE    metadata.sites TO group_bobo;
    GRANT ALL ON TABLE    metadata.sites TO group_tools;
    GRANT SELECT ON TABLE metadata.sites TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.sites_site_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.sites_site_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.sites_site_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.sites                IS 'Table holding the list of sites';
    COMMENT ON COLUMN metadata.sites.site_id        IS 'Site ID (PK)';
    COMMENT ON COLUMN metadata.sites.site_name      IS 'Site name';
    COMMENT ON COLUMN metadata.sites.network_types  IS 'Network types (FK)';
    COMMENT ON COLUMN metadata.sites.mu_id          IS 'Municipality ID (FK)';
    COMMENT ON COLUMN metadata.sites.site_locality  IS 'Site locality';
    COMMENT ON COLUMN metadata.sites.site_altitude  IS 'Site altitude';
    COMMENT ON COLUMN metadata.sites.site_wgs84_lat IS 'Site wgs84 latitude';
    COMMENT ON COLUMN metadata.sites.site_wgs84_lon IS 'Site wgs84 longitude';
    COMMENT ON COLUMN metadata.sites.site_note      IS 'Site note';

    -- Tabella che associa le bombole alle stazioni
    -- DROP TABLE IF EXISTS metadata.stations_cylinders;
    CREATE TABLE metadata.stations_cylinders
    (
        stcy_id           serial,
        station_id        integer NOT NULL,
        cy_id             integer NOT NULL,
        stcy_startup_date timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
        stcy_dismiss_date timestamp without time zone DEFAULT 'infinity'::timestamp,
        stcy_note         text,

        CONSTRAINT metadata_stations_cylinders_pkey PRIMARY KEY (stcy_id)
        -- CONSTRAINT metadata_stations_cylinders_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_cylinders_fkey2 FOREIGN KEY (cy_id)
        -- REFERENCES equipments.cylinders (cy_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_cylinders_check EXCLUDE USING GIST (
        --     cy_id WITH =,
        --     tsrange(stcy_startup_date, stcy_dismiss_date, '[)') WITH &&
        -- )
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_cylinders TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_cylinders TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_cylinders TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_cylinders TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.stations_cylinders_stcy_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_cylinders_stcy_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_cylinders_stcy_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.stations_cylinders                   IS 'Relational table with information about stations-cylinders';
    COMMENT ON COLUMN metadata.stations_cylinders.stcy_id           IS 'Station-cylinder relation ID primary key';
    COMMENT ON COLUMN metadata.stations_cylinders.station_id        IS 'Station ID';
    COMMENT ON COLUMN metadata.stations_cylinders.cy_id             IS 'Cylinder ID';
    COMMENT ON COLUMN metadata.stations_cylinders.stcy_startup_date IS 'Station-cylinder relation startup date';
    COMMENT ON COLUMN metadata.stations_cylinders.stcy_dismiss_date IS 'Station-cylinder relation dismiss date';
    COMMENT ON COLUMN metadata.stations_cylinders.stcy_note         IS 'Station-cylinder relation note';

    -- Tabella che associa le dotazioni alle stazioni
    -- DROP TABLE IF EXISTS metadata.stations_miscellanies;
    CREATE TABLE metadata.stations_miscellanies
    (
        stmi_id           serial,
        station_id        integer NOT NULL,
        mi_id             integer NOT NULL,
        stmi_startup_date timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
        stmi_dismiss_date timestamp without time zone DEFAULT 'infinity'::timestamp,
        stmi_note         text,

        CONSTRAINT metadata_stations_miscellanies_pkey PRIMARY KEY (stmi_id)
        -- CONSTRAINT metadata_stations_miscellanies_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_miscellanies_fkey2 FOREIGN KEY (mi_id)
        -- REFERENCES equipments.miscellanies (mi_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_miscellanies_check EXCLUDE USING GIST (
        --     mi_id WITH =,
        --     tsrange(stmi_startup_date, stmi_dismiss_date, '[]') WITH &&
        -- )
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_miscellanies TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_miscellanies TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_miscellanies TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_miscellanies TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.stations_miscellanies_stmi_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_miscellanies_stmi_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_miscellanies_stmi_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.stations_miscellanies                   IS 'Relational table with information about stations-miscellanies';
    COMMENT ON COLUMN metadata.stations_miscellanies.stmi_id           IS 'Station-miscellanies relation ID primary key';
    COMMENT ON COLUMN metadata.stations_miscellanies.station_id        IS 'Station ID';
    COMMENT ON COLUMN metadata.stations_miscellanies.mi_id             IS 'Miscellanies ID';
    COMMENT ON COLUMN metadata.stations_miscellanies.stmi_startup_date IS 'Station-miscellanies relation startup date';
    COMMENT ON COLUMN metadata.stations_miscellanies.stmi_dismiss_date IS 'Station-miscellanies relation dismiss date';
    COMMENT ON COLUMN metadata.stations_miscellanies.stmi_note         IS 'Station-miscellanies relation note';

    -- Tabella che contiene le informazioni riguardo lo stato dei parametri associati alle stazioni
    -- DROP TABLE IF EXISTS metadata.stations_params_status;
    CREATE TABLE metadata.stations_params_status
    (
        stpr_id                    integer NOT NULL,
        stpr_suspended             boolean DEFAULT FALSE,
        stpr_ws_publish            boolean DEFAULT FALSE,
        stpr_dataview_publish      boolean DEFAULT FALSE,
        stpr_custom_export_publish boolean DEFAULT FALSE,

        CONSTRAINT metadata_stations_params_status_pkey PRIMARY KEY (stpr_id)
        -- CONSTRAINT metadata_stations_params_status_fkey1 FOREIGN KEY (stpr_id)
        -- REFERENCES metadata.stations_parameters (stpr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_params_status TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_params_status TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_params_status TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_params_status TO group_readonly;

    -- comments
    COMMENT ON TABLE  metadata.stations_params_status                            IS 'Table with information about parameters status';
    COMMENT ON COLUMN metadata.stations_params_status.stpr_id                    IS 'Reference to stpr_id in metadata.stations_parameters';
    COMMENT ON COLUMN metadata.stations_params_status.stpr_suspended             IS 'Parameter suspended';
    COMMENT ON COLUMN metadata.stations_params_status.stpr_ws_publish            IS 'Parameter to publish on webservice';
    COMMENT ON COLUMN metadata.stations_params_status.stpr_dataview_publish      IS 'Parameter to publish on dataview';
    COMMENT ON COLUMN metadata.stations_params_status.stpr_custom_export_publish IS 'Parameter to publish on custom export (another db, sira ecc)';

    -- Tabella che contiene le informazioni riguardo alle tipologie di roaming delle stazioni
    -- DROP TABLE IF EXISTS metadata.stations_roaming_type;
    CREATE TABLE metadata.stations_roaming_type
    (
        st_roaming_id   serial NOT NULL,
        st_roaming_desc text NOT NULL,
        st_roaming_info text DEFAULT NULL,

        CONSTRAINT metadata_stations_roaming_type_pkey PRIMARY KEY (st_roaming_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_roaming_type TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_roaming_type TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_roaming_type TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_roaming_type TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.stations_roaming_type_st_roaming_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_roaming_type_st_roaming_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_roaming_type_st_roaming_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.stations_roaming_type                 IS 'Support table for roaming stations';
    COMMENT ON COLUMN metadata.stations_roaming_type.st_roaming_id   IS 'Station roaming type id';
    COMMENT ON COLUMN metadata.stations_roaming_type.st_roaming_desc IS 'Station roaming type desc';
    COMMENT ON COLUMN metadata.stations_roaming_type.st_roaming_info IS 'Station roaming type additional information';

    -- Tabella che associa le stazioni ai siti disponibili sul portale
    -- DROP TABLE IF EXISTS metadata.stations_sites;
    CREATE TABLE metadata.stations_sites
    (
        stsi_id             serial,
        station_id          integer NOT NULL,
        station_override_id integer NOT NULL,
        site_id             integer NOT NULL,
        stsi_startup_date   timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
        stsi_dismiss_date   timestamp without time zone DEFAULT 'infinity'::timestamp,
        stsi_note           text,
        camp_id             integer DEFAULT NULL,

        CONSTRAINT metadata_stations_sites_pkey PRIMARY KEY (stsi_id)
        -- CONSTRAINT metadata_stations_sites_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_sites_fkey2 FOREIGN KEY (station_override_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_sites_fkey3 FOREIGN KEY (site_id)
        -- REFERENCES metadata.sites (site_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_sites_fkey4 FOREIGN KEY (camp_id)
        -- REFERENCES metadata.campaigns (camp_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT metadata_stations_sites_check EXCLUDE USING GIST (
        --     station_id WITH =,
        --     tsrange(stsi_startup_date, stsi_dismiss_date, '[]') WITH &&
        -- )
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_sites TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_sites TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_sites TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_sites TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.stations_sites_stsi_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_sites_stsi_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_sites_stsi_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.stations_sites                     IS 'Relational table with information about stations-sites';
    COMMENT ON COLUMN metadata.stations_sites.stsi_id             IS 'Station-site relation ID primary key';
    COMMENT ON COLUMN metadata.stations_sites.station_id          IS 'Station ID (FK)';
    COMMENT ON COLUMN metadata.stations_sites.station_override_id IS 'Station override ID (FK)';
    COMMENT ON COLUMN metadata.stations_sites.site_id             IS 'Site ID (FK)';
    COMMENT ON COLUMN metadata.stations_sites.stsi_startup_date   IS 'Station-site relation startup date';
    COMMENT ON COLUMN metadata.stations_sites.stsi_dismiss_date   IS 'Station-site relation startup date';
    COMMENT ON COLUMN metadata.stations_sites.stsi_note           IS 'Station-site relation note';
    COMMENT ON COLUMN metadata.stations_sites.camp_id             IS 'Campaign ID (FK)';

    -- Tabella che contiene le informazioni riguardo alle tipologie di stazioni
    -- DROP TABLE IF EXISTS metadata.stations_typology;
    CREATE TABLE metadata.stations_typology
    (
        st_typology_id   serial NOT NULL,
        st_typology_desc text NOT NULL,
        st_typology_info text DEFAULT NULL,

        CONSTRAINT metadata_stations_typology_pkey PRIMARY KEY (st_typology_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.stations_typology TO group_admin;
    GRANT ALL ON TABLE    metadata.stations_typology TO group_bobo;
    GRANT ALL ON TABLE    metadata.stations_typology TO group_tools;
    GRANT SELECT ON TABLE metadata.stations_typology TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.stations_typology_st_typology_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.stations_typology_st_typology_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.stations_typology_st_typology_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.stations_typology                  IS 'Support table for station typology';
    COMMENT ON COLUMN metadata.stations_typology.st_typology_id   IS 'Station typology id';
    COMMENT ON COLUMN metadata.stations_typology.st_typology_desc IS 'Station typology desc';
    COMMENT ON COLUMN metadata.stations_typology.st_typology_info IS 'Station typology additional information';

    -- Tabella che contiene i codici di validazione usati dall'utente
    -- DROP TABLE IF EXISTS metadata.user_validation_codes;
    CREATE TABLE metadata.user_validation_codes
    (
        uvc_id           serial,
        uvc_code_id      integer NOT NULL,
        uvc_code_desc    text NOT NULL,
        uvc_code_default boolean DEFAULT FALSE,
        uvc_code_valid   boolean DEFAULT NULL,

        CONSTRAINT metadata_user_validation_codes_pkey PRIMARY KEY (uvc_id),
        CONSTRAINT metadata_user_validation_codes_ukey UNIQUE (uvc_code_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    metadata.user_validation_codes TO group_admin;
    GRANT ALL ON TABLE    metadata.user_validation_codes TO group_bobo;
    GRANT ALL ON TABLE    metadata.user_validation_codes TO group_tools;
    GRANT SELECT ON TABLE metadata.user_validation_codes TO group_readonly;
    GRANT ALL ON SEQUENCE metadata.user_validation_codes_uvc_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE metadata.user_validation_codes_uvc_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE metadata.user_validation_codes_uvc_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  metadata.user_validation_codes                  IS 'The table contains all the codes used for user validation';
    COMMENT ON COLUMN metadata.user_validation_codes.uvc_id           IS 'Validation code serial ID';
    COMMENT ON COLUMN metadata.user_validation_codes.uvc_code_id      IS 'Validation code main ID';
    COMMENT ON COLUMN metadata.user_validation_codes.uvc_code_desc    IS 'Validation code description';
    COMMENT ON COLUMN metadata.user_validation_codes.uvc_code_default IS 'Validation code by default';
    COMMENT ON COLUMN metadata.user_validation_codes.uvc_code_valid   IS 'If validation code is valid or not';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- Vista che raccoglie le informazioni di tutte le possibili aggregazioni delle varie applicazioni del portale
    -- DROP VIEW metadata.view_app_aggregations;
    CREATE OR REPLACE VIEW metadata.view_app_aggregations AS
    SELECT
        aa.app_agg_id           AS app_aggregation_id,
        aa.app_agg_label        AS app_aggregation_label,
        aa.app_agg_default      AS app_aggregation_default,
        aa.measure_cadence_id   AS app_aggregation_cadence_id,
        mc.measure_cadence_desc AS app_aggregation_desc,
        mc.measure_cadence_min  AS app_aggregation_min,
        mc.measure_cadence_db   AS app_aggregation_db
    FROM
        metadata.app_aggregations aa
        LEFT JOIN metadata.measures_cadence mc USING (measure_cadence_id)
    ORDER BY app_agg_id;

    -- grants
    GRANT ALL ON TABLE    metadata.view_app_aggregations TO group_admin;
    GRANT ALL ON TABLE    metadata.view_app_aggregations TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_app_aggregations TO group_tools;
    GRANT SELECT ON TABLE metadata.view_app_aggregations TO group_readonly;

    -- comment
    COMMENT ON VIEW metadata.view_app_aggregations IS 'The view contains all the info about possible app aggregations';

    -- Vista che raccoglie le informazioni dei parametri
    -- DROP VIEW IF EXISTS metadata.view_parameters_info;
    CREATE OR REPLACE VIEW metadata.view_parameters_info AS
    SELECT
        p.param_id                                                                                 AS parameter_id,
        p.param_name                                                                               AS parameter_name,
        p.param_unit                                                                               AS parameter_unit,
        p.param_conv                                                                               AS parameter_conv,
        p.param_unit_conv                                                                          AS parameter_unit_conv,
        p.param_offset                                                                             AS parameter_offset,
        p.param_decimals                                                                           AS parameter_decimals,
        p.param_active                                                                             AS parameter_active,
        p.param_note                                                                               AS parameter_note,
        p.param_ext_id                                                                             AS parameter_external_id,
        -- pp.pollutant_id                                                                            AS pollutant_id,
        pi.pm_info_shortname                                                                       AS parameter_shortname,
        pi.pm_info_extra_shortname                                                                 AS parameter_extra_shortname,
        pi.pm_info_type_fk                                                                         AS parameter_type_id,
        pt.pm_type_desc                                                                            AS parameter_type_desc,
        COALESCE((pi.pm_info_obj ->'general')::jsonb ->>'treatment', 'avg')::metadata.e_treatments AS parameter_treatment,
        ((pi.pm_info_obj ->'general')::jsonb ->>'dataview_flag')::boolean                          AS parameter_dataview_flag,
        ((pi.pm_info_obj ->'general')::jsonb ->>'dataview_live')::boolean                          AS parameter_dataview_live,
        ((pi.pm_info_obj ->'general')::jsonb ->>'dataview_indicator')::boolean                     AS parameter_dataview_indicator,
        (pi.pm_info_obj ->'general')::jsonb ->'dataview_labels'                                    AS parameter_dataview_labels,
        ((pi.pm_info_obj ->'aggregation')::jsonb ->'hh'->>'enabled')::boolean                      AS parameter_aggr_hh_enabled,
        (pi.pm_info_obj ->'aggregation')::jsonb ->'hh'->>'perc_valid'                              AS parameter_aggr_hh_perc,
        ((pi.pm_info_obj ->'aggregation')::jsonb ->'dd'->>'enabled')::boolean                      AS parameter_aggr_dd_enabled,
        (pi.pm_info_obj ->'aggregation')::jsonb ->'dd'->>'perc_valid'                              AS parameter_aggr_dd_perc,
        ((pi.pm_info_obj ->'aggregation')::jsonb ->'mm'->>'enabled')::boolean                      AS parameter_aggr_mm_enabled,
        (pi.pm_info_obj ->'aggregation')::jsonb ->'mm'->>'perc_valid'                              AS parameter_aggr_mm_perc,
        ((pi.pm_info_obj ->'aggregation')::jsonb ->'yy'->>'enabled')::boolean                      AS parameter_aggr_yy_enabled,
        (pi.pm_info_obj ->'aggregation')::jsonb ->'yy'->>'perc_valid'                              AS parameter_aggr_yy_perc,
        pi.pm_info_note                                                                            AS parameter_info_note
    FROM
        metadata.parameters p
        LEFT JOIN metadata.parameters_info pi  USING (param_id)
        LEFT JOIN metadata.parameters_type pt  ON (pi.pm_info_type_fk = pt.pm_type_id)
        -- LEFT JOIN infoaria.params_pollutant pp USING (param_id)
    ORDER BY p.param_id;

    -- grants
    GRANT ALL ON TABLE    metadata.view_parameters_info TO group_admin;
    GRANT ALL ON TABLE    metadata.view_parameters_info TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_parameters_info TO group_tools;
    GRANT SELECT ON TABLE metadata.view_parameters_info TO group_readonly;

    -- comment
    COMMENT ON VIEW metadata.view_parameters_info IS 'The view contains all the principal info and metadata about parameters';

    -- Vista che raccoglie le informazioni dei parametri in relazione ai trattamenti associati
    -- DROP VIEW IF EXISTS metadata.view_params_treatments;
    CREATE OR REPLACE VIEW metadata.view_params_treatments AS
    SELECT
        e.enumlabel AS treatment_id,
        CASE
            WHEN enumlabel = 'avg'    THEN 'Media'
            WHEN enumlabel = 'sum'    THEN 'Somma'
            WHEN enumlabel = 'max'    THEN 'Massimo'
            WHEN enumlabel = 'min'    THEN 'Minimo'
            WHEN enumlabel = 'cum'    THEN 'Cumulata'
            WHEN enumlabel = 'first'  THEN 'Puntuale'
            WHEN enumlabel = 'sldavg' THEN 'Media mobile'
            ELSE 'Unknown'
        END         AS treatment_name
    FROM pg_type t
    LEFT JOIN pg_enum e ON t.oid = e.enumtypid
    LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE nspname = 'metadata'
    AND typname = 'e_treatments';

    -- grants
    GRANT ALL ON TABLE    metadata.view_params_treatments TO group_admin;
    GRANT ALL ON TABLE    metadata.view_params_treatments TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_params_treatments TO group_tools;
    GRANT SELECT ON TABLE metadata.view_params_treatments TO group_readonly;

    -- comment
    COMMENT ON VIEW metadata.view_params_treatments IS 'The view contains all the info about parameters treatments';

    -- Vista che raccoglie le informazioni dei siti
    -- DROP VIEW IF EXISTS metadata.view_sites;
    CREATE OR REPLACE VIEW metadata.view_sites AS
    SELECT
        s.site_id,
        s.site_name,
        s.network_types,
        ARRAY (
            SELECT stations_network_type.st_network_name
            FROM metadata.stations_network_type
            WHERE stations_network_type.st_network_id = ANY (s.network_types)
        ) AS network_names,
        s.mu_id,
        m.mu_name AS municipality_name,
        p.province_id,
        p.province_name,
        r.region_id,
        r.region_name,
        s.site_locality,
        s.site_altitude,
        s.site_wgs84_lat,
        s.site_wgs84_lon,
        s.site_note
    FROM
        metadata.sites s
        LEFT JOIN main.municipalities m USING (mu_id)
        LEFT JOIN main.province_municipalities pm USING (mu_id)
        LEFT JOIN main.provinces p USING (province_id)
        LEFT JOIN main.region_provinces rp USING (province_id)
        LEFT JOIN main.regions r USING (region_id)
    ORDER BY s.site_id;

    -- grants
    GRANT ALL ON TABLE    metadata.view_sites TO group_admin;
    GRANT ALL ON TABLE    metadata.view_sites TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_sites TO group_tools;
    GRANT SELECT ON TABLE metadata.view_sites TO group_readonly;

    -- comments
    COMMENT ON VIEW metadata.view_sites IS 'The view contains all the principal info about sites';

    -- Vista che raccoglie le informazioni delle stazioni
    -- DROP VIEW IF EXISTS metadata.view_stations_info;
    CREATE OR REPLACE VIEW metadata.view_stations_info AS
        WITH t AS (
            SELECT
                station_id,
                st_info_shortname,
                st_info_longname,
                st_info_startup_date,
                st_info_dismiss_date,
                st_info_basepath,
                st_info_locality,
                st_info_zone,
                st_info_basin,
                st_info_community,
                st_info_north_utm,
                st_info_east_utm,
                st_info_altitude,
                st_info_lat_wgs84,
                st_info_lon_wgs84,
                st_info_network_type_fk,
                st_info_roaming_type_fk,
                st_info_typology_fk,
                st_info_measure_fk,
                st_info_cadence_fk,
                st_info_note,
                st_info_national_code,
                st_info_export_id,
                st_info_ws_name,
                st_info_import_ws_id,
                st_info_accepted_delay
            FROM
                metadata.stations_info
            WHERE
                ( stations_info.st_info_roaming_type_fk != 4 OR stations_info.st_info_roaming_type_fk ISNULL )
            UNION ALL
            SELECT DISTINCT ON (si.station_id)
                si.station_id,
                si.st_info_shortname,
                si.st_info_longname,
                si.st_info_startup_date,
                si.st_info_dismiss_date,
                si2.st_info_basepath,
                s.site_locality AS st_info_locality,
                si.st_info_zone,
                si.st_info_basin,
                si.st_info_community,
                si.st_info_north_utm,
                si.st_info_east_utm,
                s.site_altitude AS st_info_altitude,
                s.site_wgs84_lat AS st_info_lat_wgs84,
                s.site_wgs84_lon AS st_info_lon_wgs84,
                si.st_info_network_type_fk,
                si.st_info_roaming_type_fk,
                si.st_info_typology_fk,
                si.st_info_measure_fk,
                si.st_info_cadence_fk,
                si.st_info_note,
                si.st_info_national_code,
                si.st_info_export_id,
                si.st_info_ws_name,
                si.st_info_import_ws_id,
                si.st_info_accepted_delay
            FROM
                metadata.stations_info si
                LEFT JOIN metadata.stations_sites ss ON si.station_id = ss.station_override_id
                LEFT JOIN metadata.stations_info si2 ON ss.station_id = si2.station_id
                LEFT JOIN metadata.sites s USING (site_id)
            WHERE
                si.st_info_roaming_type_fk = 4
            ORDER BY 1
        )
    SELECT
        st.station_id,
        st.station_name,
        st.station_schema,
        st.station_table,
        st.station_prefix,
        ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable,
        st.station_active,
        st.station_note,
        st.station_ext_id AS station_external_id,
        st.station_file_header AS station_file_header,
        st.station_remote_ctrl AS station_remote_ctrl,
        sm.st_info_shortname AS station_shortname,
        sm.st_info_longname AS station_longname,
        sm.st_info_startup_date AS station_startup_date,
        sm.st_info_dismiss_date AS station_dismiss_date,
        sm.st_info_basepath AS station_base_path,
        (sm.st_info_basepath || '/'::text) || st.station_id AS station_media_path,
        sm.st_info_locality AS station_locality,
        sm.st_info_zone AS station_zone,
        sm.st_info_basin AS station_basin,
        sm.st_info_community AS station_community,
        sm.st_info_north_utm AS station_north_utm,
        sm.st_info_east_utm AS station_east_utm,
        sm.st_info_altitude AS station_altitude,
        sm.st_info_lat_wgs84 AS station_lat_wgs84,
        sm.st_info_lon_wgs84 AS station_lon_wgs84,
        sm.st_info_national_code AS station_national_code,
        sm.st_info_network_type_fk AS station_network_type_id,
        snt.st_network_desc AS station_network_type_desc,
        snt.st_network_name AS station_network_type_name,
        snt.st_network_logo AS station_network_type_logo,
        sm.st_info_roaming_type_fk AS station_roaming_type_id,
        srt.st_roaming_desc AS station_roaming_type_desc,
        sm.st_info_typology_fk AS station_typology_id,
        stt.st_typology_desc AS station_typology_desc,
        sm.st_info_measure_fk AS station_measure_type_id,
        mt.measure_type_desc AS station_measure_type_desc,
        sm.st_info_cadence_fk AS station_cadence_type_id,
        mc.measure_cadence_desc AS station_cadence_type_desc,
        mc.measure_cadence_min AS station_cadence_type_min,
        mc.measure_cadence_db AS station_cadence_type_db,
        sm.st_info_note AS station_metadata_note,
        sm.st_info_export_id AS station_export_id,
        sm.st_info_ws_name AS station_ws_name,
        sm.st_info_import_ws_id AS station_import_ws_id
    FROM
        metadata.stations st
        LEFT JOIN t sm USING (station_id)
        LEFT JOIN metadata.stations_network_type snt ON snt.st_network_id = sm.st_info_network_type_fk
        LEFT JOIN metadata.stations_roaming_type srt ON srt.st_roaming_id = sm.st_info_roaming_type_fk
        LEFT JOIN metadata.stations_typology stt ON stt.st_typology_id = sm.st_info_typology_fk
        LEFT JOIN metadata.measures_type mt ON mt.measure_type_id = sm.st_info_measure_fk
        LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = sm.st_info_cadence_fk
    WHERE
        sm.st_info_roaming_type_fk != 0 -- non quelle accessorie
    ORDER BY
        st.station_id;

    -- grants
    GRANT ALL ON TABLE    metadata.view_stations_info TO group_admin;
    GRANT ALL ON TABLE    metadata.view_stations_info TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_stations_info TO group_tools;
    GRANT SELECT ON TABLE metadata.view_stations_info TO group_readonly;
    GRANT SELECT ON TABLE metadata.view_stations_info TO group_clients_ro;

    -- comment
    COMMENT ON VIEW metadata.view_stations_info IS 'The view contains all the principal info and metadata about stations';

    -- Vista che raccoglie le informazioni delle stazioni in relazione ai comuni associati
    -- DROP VIEW IF EXISTS metadata.view_stations_municipality;
    CREATE OR REPLACE VIEW metadata.view_stations_municipality AS
    WITH t AS (
        SELECT
            station_id,
            mu_id
        FROM
            metadata.stations_info
            LEFT JOIN metadata.stations_municipality USING (station_id)
        WHERE
            st_info_roaming_type_fk != 4 OR st_info_roaming_type_fk IS NULL
        UNION ALL
        SELECT
            DISTINCT ON (si.station_id) si.station_id,
            s.mu_id
        FROM metadata.stations_info si
            LEFT JOIN metadata.stations_sites ss ON si.station_id = ss.station_override_id
            LEFT JOIN metadata.sites s USING (site_id)
        WHERE
            si.st_info_roaming_type_fk = 4
    )
    SELECT
        st.station_id,
        st.station_name,
        st.station_schema,
        st.station_table,
        st.station_prefix,
        ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable,
        st.station_active,
        st.station_note,
        m.mu_id,
        m.mu_name,
        m.mu_istat_code,
        m.mu_catasto_code,
        m.mu_cap,
        m.mu_note,
        p.province_id,
        p.province_name,
        p.province_istat_code,
        p.province_code,
        p.province_note,
        r.region_id,
        r.region_name,
        r.region_istat_code,
        r.region_note
    FROM
        metadata.stations st
        LEFT JOIN t sm USING (station_id)
        LEFT JOIN main.municipalities m USING (mu_id)
        LEFT JOIN main.province_municipalities pm USING (mu_id)
        LEFT JOIN main.provinces p USING (province_id)
        LEFT JOIN main.region_provinces rp USING (province_id)
        LEFT JOIN main.regions r USING (region_id)
    ORDER BY
        st.station_id;

    -- grants
    GRANT ALL ON TABLE    metadata.view_stations_municipality TO group_admin;
    GRANT ALL ON TABLE    metadata.view_stations_municipality TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_stations_municipality TO group_tools;
    GRANT SELECT ON TABLE metadata.view_stations_municipality TO group_readonly;

    -- comment
    COMMENT ON VIEW metadata.view_stations_municipality IS 'The view contains all the info about stations location';

    -- Vista che raccoglie le informazioni delle stazioni in relazione ai parametri associati
    -- DROP VIEW IF EXISTS metadata.view_stations_parameters;
    CREATE OR REPLACE VIEW metadata.view_stations_parameters AS
    SELECT
        sp.stpr_id                                                                AS stpr_id,
        st.station_id                                                             AS station_id,
        p.param_id                                                                AS param_id,
        sp.stpr_group_id                                                          AS stpr_group_id,
        sp.stpr_table_id                                                          AS stpr_table_id,
        st.station_name                                                           AS station_name,
        st.station_schema                                                         AS station_schema,
        st.station_table                                                          AS station_table,
        st.station_prefix                                                         AS station_prefix,
        st.station_schema||'.'||COALESCE(st.station_prefix, '')||st.station_table AS station_fulltable,
        p.param_name || COALESCE(' - '||sp.stpr_note, '')                         AS parameter_name,
        p.param_unit                                                              AS parameter_unit,
        st.station_active                                                         AS station_active,
        sp.stpr_active                                                            AS station_param_active,
        sp.stpr_ext_id                                                            AS station_param_ext_id,
        sp.stpr_startup_date                                                      AS station_param_startup_date,
        sp.stpr_dismiss_date                                                      AS station_param_dismiss_date,
        COALESCE(spi.stpr_info_measure_fk, si.st_info_measure_fk)::integer        AS station_param_measure_type_id,
        COALESCE(spi.stpr_info_cadence_fk, si.st_info_cadence_fk)::integer        AS station_param_cadence_type_id,
        spi.stpr_info_ws_id                                                       AS station_param_info_ws_id,
        spi.stpr_import_ws_id                                                     AS station_param_import_ws_id,
        p.param_conv                                                              AS parameter_conv,
        p.param_unit_conv                                                         AS parameter_unit_conv,
        p.param_offset                                                            AS parameter_offset,
        p.param_decimals                                                          AS parameter_decimals,
        p.param_active                                                            AS parameter_active,
        -- pp.pollutant_id                                                           AS pollutant_id,
        pm.pm_info_shortname                                                      AS parameter_shortname,
        pm.pm_info_extra_shortname                                                AS parameter_extra_shortname,
        pm.pm_info_type_fk                                                        AS parameter_type_id,
        pt.pm_type_desc                                                           AS parameter_type_desc,
        pm.pm_info_obj                                                            AS parameter_object,
        st.station_note                                                           AS station_note,
        sp.stpr_note                                                              AS station_param_note,
        p.param_note                                                              AS parameter_note,
        pm.pm_info_note                                                           AS parameter_meta_note,
        sp.stpr_id                                                                AS station_param_id,
        p.param_id                                                                AS parameter_id,
        sp.stpr_table_id                                                          AS station_param_table_id
    FROM
        metadata.stations st
        LEFT JOIN metadata.stations_info si USING (station_id)
        LEFT JOIN metadata.stations_parameters sp USING (station_id)
        LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
        LEFT JOIN metadata.measures_type mt ON (mt.measure_type_id = spi.stpr_info_measure_fk)
        LEFT JOIN metadata.parameters p USING (param_id)
        LEFT JOIN metadata.parameters_info pm USING (param_id)
        LEFT JOIN metadata.parameters_type pt ON (pm.pm_info_type_fk = pt.pm_type_id)
        -- LEFT JOIN infoaria.params_pollutant pp USING (param_id)
    ORDER BY station_id, stpr_table_id;

    -- grants
    GRANT ALL ON TABLE    metadata.view_stations_parameters TO group_admin;
    GRANT ALL ON TABLE    metadata.view_stations_parameters TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_stations_parameters TO group_tools;
    GRANT SELECT ON TABLE metadata.view_stations_parameters TO group_readonly;

    -- comment
    COMMENT ON VIEW metadata.view_stations_parameters IS 'The view contains all the principal info about the relation station-parameter';

    -- Vista che raccoglie le informazioni delle stagioni in relazione a quale sito sono associate
    -- DROP VIEW IF EXISTS metadata.view_stations_sites;
    CREATE OR REPLACE VIEW metadata.view_stations_sites AS
    SELECT
        ss.stsi_id,
        ss.station_id,
        st.station_name,
        ((st.station_schema || '.'::text)|| COALESCE(st.station_prefix, ''::text))|| st.station_table AS station_fulltable,
        ss.station_override_id,
        ss.site_id,
        s.site_name,
        s.network_types,
        ARRAY (
            SELECT
                st_network_name
            FROM  metadata.stations_network_type
            WHERE st_network_id = ANY(s.network_types)
        ) AS network_names,
        s.mu_id,
        s.site_locality,
        s.site_altitude,
        s.site_wgs84_lat,
        s.site_wgs84_lon,
        s.site_note,
        ss.stsi_startup_date,
        ss.stsi_dismiss_date,
        ss.stsi_note,
        ss.camp_id,
        c.camp_name
    FROM
        metadata.stations_sites ss
        LEFT JOIN metadata.stations st USING (station_id)
        LEFT JOIN metadata.sites s USING (site_id)
        LEFT JOIN metadata.campaigns c USING (camp_id)
    ORDER BY ss.stsi_startup_date;

    -- grants
    GRANT ALL ON TABLE    metadata.view_stations_sites TO group_admin;
    GRANT ALL ON TABLE    metadata.view_stations_sites TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_stations_sites TO group_tools;
    GRANT SELECT ON TABLE metadata.view_stations_sites TO group_readonly;

    -- comment
    COMMENT ON VIEW metadata.view_stations_sites IS 'The view contains all the principal info about the relation station-site';

    -- Vista che raccoglie le informazioni relative alle associazioni dei codici di validazione finale ai vari utenti
    -- DROP VIEW IF EXISTS bobo.view_user_final_codes;
    CREATE OR REPLACE VIEW bobo.view_user_final_codes AS
    SELECT DISTINCT ON (u.us_id, f.fvc_code_id)
        u.us_id AS user_id,
        u.us_name AS user_name,
        u.us_2nd_name AS user_second_name,
        u.us_surname AS user_surname,
        u.us_role AS user_role,
        u.us_email AS user_email,
        u.us_phone AS user_phone,
        u.us_mobile AS user_mobile,
        u.us_avatar AS user_avatar,
        u.us_avatar_thumb AS user_avatar_thumb,
        ARRAY( SELECT user_groups.gr_id
            FROM bobo.user_groups
            WHERE user_groups.us_id = u.us_id) AS user_groups_array,
        f.fvc_id,
        f.fvc_code_id,
        f.fvc_code_desc,
        --wg.*,
        g.gr_id,
        g.gr_name,
        g.gr_shortname,
        g.gr_insert_time
    FROM bobo.users u
        LEFT JOIN bobo.user_groups ug USING (us_id)
        LEFT JOIN bobo.groups g USING (gr_id)
        LEFT JOIN bobo.group_final_codes gfc USING (gr_id)
        LEFT JOIN metadata.final_validation_codes f USING (fvc_code_id)
    WHERE f.fvc_code_id IS NOT NULL
    ORDER BY
        u.us_id, f.fvc_code_id;

    -- grants
    GRANT ALL ON TABLE    bobo.view_user_final_codes TO group_admin;
    GRANT ALL ON TABLE    bobo.view_user_final_codes TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_user_final_codes TO group_tools;
    GRANT SELECT ON TABLE bobo.view_user_final_codes TO group_readonly;

    -- comments
    COMMENT ON VIEW bobo.view_user_final_codes IS 'Available final validation codes per user';

    -- Vista che raccoglie le informazioni relative alle associazioni delle reti ai vari utenti
    -- DROP VIEW IF EXISTS bobo.view_user_networks;
    CREATE OR REPLACE VIEW bobo.view_user_networks AS
    SELECT DISTINCT ON (u.us_id, n.st_network_name)
        u.us_id AS user_id,
        u.us_name AS user_name,
        u.us_2nd_name AS user_second_name,
        u.us_surname AS user_surname,
        u.us_role AS user_role,
        u.us_email AS user_email,
        u.us_phone AS user_phone,
        u.us_mobile AS user_mobile,
        u.us_avatar AS user_avatar,
        u.us_avatar_thumb AS user_avatar_thumb,
        ARRAY( SELECT user_groups.gr_id
            FROM bobo.user_groups
            WHERE user_groups.us_id = u.us_id) AS user_groups_array,
        n.st_network_id  ,
        n.st_network_desc,
        n.st_network_logo,
        n.st_network_name,
        --wg.*,
        g.gr_id,
        g.gr_name,
        g.gr_shortname,
        g.gr_insert_time
    FROM bobo.users u
        LEFT JOIN bobo.user_groups ug USING (us_id)
        LEFT JOIN bobo.groups g USING (gr_id)
        LEFT JOIN bobo.group_networks wg USING (gr_id)
        LEFT JOIN metadata.stations_network_type n USING (st_network_id)
    WHERE n.st_network_id IS NOT NULL
    ORDER BY
        u.us_id, n.st_network_name;

    -- grants
    GRANT ALL ON TABLE    bobo.view_user_networks TO group_admin;
    GRANT ALL ON TABLE    bobo.view_user_networks TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_user_networks TO group_tools;
    GRANT SELECT ON TABLE bobo.view_user_networks TO group_readonly;

    -- comments
    COMMENT ON VIEW bobo.view_user_networks IS 'Available networks per user';

    -- Vista che raccoglie le info dell'utente in relazione alle stazioni a cui ha accesso
    -- DROP VIEW IF EXISTS bobo.view_user_stations;
    CREATE VIEW bobo.view_user_stations AS
    SELECT DISTINCT ON (u.us_id, s.station_id)
        u.us_id                 AS user_id,
        u.us_name               AS user_name,
        u.us_2nd_name           AS user_second_name,
        u.us_surname            AS user_surname,
        u.us_role               AS user_role,
        u.us_email              AS user_email,
        u.us_phone              AS user_phone,
        u.us_mobile             AS user_mobile,
        u.us_avatar             AS user_avatar,
        u.us_avatar_thumb       AS user_avatar_thumb,
        array(
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = u.us_id
            )                   AS user_groups_array,
        s.station_id            AS station_id,
        s.station_name          AS station_name,
        s.station_schema        AS station_schema,
        s.station_table         AS station_table,
        s.station_prefix        AS station_prefix,
        s.station_schema||'.'||
        COALESCE(s.station_prefix, '')||
        s.station_table                AS station_fulltable,
        s.station_active        AS station_active,
        s.station_note          AS station_note,
        (
            SELECT bit_or(tbit.gs_iud_grants) FROM
                (
                    SELECT gs_iud_grants
                    FROM bobo.group_stations
                    WHERE station_id = s.station_id
                    AND gr_id IN (
                        SELECT gr_id
                        FROM bobo.user_groups
                        WHERE us_id = u.us_id
                    )
                ) AS tbit
        ) AS total_user_grants
    FROM
        bobo.users u
        LEFT JOIN bobo.user_groups ug USING (us_id)
        LEFT JOIN bobo.groups g USING (gr_id)
        LEFT JOIN bobo.group_stations gs USING (gr_id)
        LEFT JOIN metadata.stations s USING (station_id)
    WHERE u.us_active IS TRUE
    ORDER BY u.us_id;

    -- grants
    GRANT ALL ON TABLE    bobo.view_user_stations TO group_admin;
    GRANT ALL ON TABLE    bobo.view_user_stations TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_user_stations TO group_tools;
    GRANT SELECT ON TABLE bobo.view_user_stations TO group_readonly;

    -- DROP VIEW metadata.view_horiba_parameters;
    CREATE OR REPLACE VIEW metadata.view_horiba_parameters
    AS
    SELECT t.param_id,
        p.param_name,
        p.param_unit,
        p.param_decimals
    FROM ( VALUES (50,1), (962,2), (963,3), (965,4), (967,5), (968,6), (1143,7), (970,8), (971,9), (972,10), (973,11), (974,12), (975,13), (976,14), (977,15), (978,16), (979,17), (980,18), (1144,19), (982,20), (983,21), (984,22), (985,23), (987,24), (988,25), (989,26), (990,27), (991,28), (992,29), (1145,30), (993,31), (995,32), (1146,33), (997,34), (648,35), (1003,36), (1004,37)) t(param_id, pos)
        LEFT JOIN metadata.parameters p USING (param_id)
    ORDER BY t.pos;

    -- grants
    GRANT ALL ON TABLE metadata.view_horiba_parameters TO postgres;
    GRANT ALL ON TABLE metadata.view_horiba_parameters TO group_admin;
    GRANT ALL ON TABLE metadata.view_horiba_parameters TO group_bobo;
    GRANT ALL ON TABLE metadata.view_horiba_parameters TO group_tools;
    GRANT SELECT ON TABLE metadata.view_horiba_parameters TO group_readonly;

    CREATE OR REPLACE VIEW metadata.view_sites_parameters AS
        SELECT
            -(so.station_override_id::text || lpad(sp.stpr_id::text, 7, '0'))::bigint AS stpr_id,
            station_override_id AS station_id,
            p.param_id,
            sp.stpr_group_id,
            sp.stpr_table_id,
            sp.stpr_note,
            st.station_name,
            ((st2.station_schema || '.'::text) || COALESCE(st2.station_prefix, ''::text)) || st2.station_table AS station_fulltable,
            stsi_period,
            p.param_name || COALESCE(' - '::text || sp.stpr_note, ''::text) AS parameter_name,
            p.param_unit                AS parameter_unit,
            p.param_conv                AS parameter_conv,
            p.param_unit_conv           AS parameter_unit_conv,
            p.param_offset              AS parameter_offset,
            p.param_decimals            AS parameter_decimals,
            p.param_active              AS parameter_active,
            pm.pm_info_type_fk          AS parameter_type_id,
            pt.pm_type_desc             AS parameter_type_desc,
            pm.pm_info_obj              AS parameter_object,
            spi.stpr_info_cadence_fk    AS station_param_cadence,
            sp.stpr_active              AS station_param_active
        FROM (
            SELECT
                station_id,
                station_override_id,
                range_agg (tsrange(stsi_startup_date, stsi_dismiss_date, '[]')) as stsi_period
            FROM metadata.stations_sites ss
            GROUP BY station_id, station_override_id
            ORDER BY station_id, station_override_id
        ) so
        LEFT JOIN metadata.stations st ON (st.station_id = so.station_override_id)
        LEFT JOIN metadata.stations st2 ON (st2.station_id = so.station_id)
        LEFT JOIN metadata.stations_parameters sp ON (sp.station_id = so.station_id)
        LEFT JOIN metadata.stations_params_info spi ON ( spi.stpr_id = sp.stpr_id)
        LEFT JOIN metadata.parameters p USING (param_id)
        LEFT JOIN metadata.parameters_info pm USING (param_id)
        LEFT JOIN metadata.parameters_type pt ON pm.pm_info_type_fk = pt.pm_type_id;

    GRANT ALL ON TABLE      metadata.view_sites_parameters TO group_admin;
    GRANT ALL ON TABLE      metadata.view_sites_parameters TO group_bobo;
    GRANT ALL ON TABLE      metadata.view_sites_parameters TO group_tools;
    GRANT SELECT ON TABLE   metadata.view_sites_parameters TO group_readonly;

    COMMENT ON VIEW metadata.view_sites_parameters IS '[BOBO] The view contains all the principal info about the relation site-parameter';


    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Funzione che elimina una determinata stazione e tutti i relativi metadati
    -- DROP FUNCTION IF EXISTS metadata.f_delete_station(integer);
    CREATE OR REPLACE FUNCTION metadata.f_delete_station(
        stid integer
    )
      RETURNS smallint
      LANGUAGE 'plpgsql'
      SECURITY DEFINER
      VOLATILE
      COST 100
    AS $BODY$

    DECLARE
        q text;
        t text;
        c integer;
    BEGIN
        /**
         * Function that takes care of deleting a station and all associated minimal metadata.
         * The deletion is successful only if the station has no data in the table and there is none
         * elements (parameters, tools, reports...) associated with it.
         *
         * The function is launched from the portal and is executed with the owner role (user_admin).
         *
         * TEST
         * SELECT metadata.f_delete_station(1000::integer); -> -2 Data in station's table
         * SELECT metadata.f_delete_station(1438::integer); -> -1 No table but foreign key violation
         */


        /* Get station fulltable name */
        SELECT
            station_schema ||'.'|| COALESCE(station_prefix, '')|| station_table INTO t
        FROM
            metadata.stations
        WHERE station_id = stid;

        /**
         * Check if table exists
         * If it doesn't exist then continue
         * else check if any data exists
         */
        IF (
            SELECT NOT EXISTS (
                SELECT 1
                FROM pg_tables
                WHERE CONCAT_WS('.', schemaname, tablename) LIKE t
            )
        ) THEN
            RAISE NOTICE 'Station''s table not present in db! Continue in deletion...';
        ELSE

            q := 'SELECT COUNT(*) FROM '||t;
            EXECUTE q INTO c;

            /* If counter greater then 0 then stop deletion and return error */
            IF c > 0 THEN
                RAISE NOTICE 'There are data in station''s table...Cannot delete station!';
                RETURN -2;
            END IF;
        END IF;

        /* Delete metadata */
        DELETE FROM metadata.stations_municipality WHERE station_id = stid;
        DELETE FROM metadata.stations_info WHERE station_id = stid;
        DELETE FROM metadata.stations_status WHERE station_id = stid;
        DELETE FROM bobo.group_stations WHERE station_id = stid;

        /**
         * Try to delete main element in metadata.stations
         * If any "foreign key violation" occurs then stop deletion and return error
         */
        DELETE FROM metadata.stations WHERE station_id = stid;

        /* Delete tables (main and inst) */
        q := 'DROP TABLE IF EXISTS '||t;
        EXECUTE q;

        q := 'DROP TABLE IF EXISTS '||t||'_inst';
        EXECUTE q;

        /* Return success*/
        RETURN 1;

        /* Errors check */
        EXCEPTION
        WHEN foreign_key_violation THEN
            -- in case of foreign key violation
            RAISE NOTICE 'ERROR IN metadata.f_delete_station() : %', SQLERRM ;
            RETURN -1;
        WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN metadata.f_delete_station() : %', SQLERRM ;
            RETURN 0;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION metadata.f_delete_station(integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION metadata.f_delete_station(integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION metadata.f_delete_station(integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION metadata.f_delete_station(integer) IS 'Function that removes station and all linked metadata';

    -- Funzione che restituisce un oggetto contenente i parametri CC e i relativi id recuperati dai moduli della stazione indicati nel file di configurazione
    -- DROP FUNCTION IF EXISTS metadata.f_get_cc_from_station_config(jsonb);
    CREATE OR REPLACE FUNCTION metadata.f_get_cc_from_station_config(
        mo jsonb
    )
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
            WHEN (mo->>'ModuleType')::integer IN (100, 415, 852, 860, 867, 1230, 1231, 1240, 1522 )  THEN
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
            WHEN (mo->>'ModuleType')::integer IN ( 417 )  THEN
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

    -- grants
    GRANT EXECUTE ON FUNCTION metadata.f_get_cc_from_station_config(jsonb) TO group_bobo;
    GRANT EXECUTE ON FUNCTION metadata.f_get_cc_from_station_config(jsonb) TO group_admin;
    GRANT EXECUTE ON FUNCTION metadata.f_get_cc_from_station_config(jsonb) TO group_tools;

    -- comment
    COMMENT ON FUNCTION metadata.f_get_cc_from_station_config(jsonb) IS 'Function that returns an object with all CC parameters and their ids retrieved from module of station configuration file';

    -- Funzione per recuperare il coefficiente di conversione in base ad una data e di un determinato parametro
    -- DROP FUNCTION IF EXISTS metadata.f_get_conversion_by_date_prid(integer, timestamp without time zone);
    CREATE OR REPLACE FUNCTION metadata.f_get_conversion_by_date_prid(
        prid integer,
        ts timestamp without time zone
    )
        RETURNS real
        LANGUAGE 'plpgsql'
        COST 100
        STABLE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        conv real;
    BEGIN
        /* TEST
            SELECT metadata.f_get_conversion_by_date_prid(1007, '2023-07-18 10:00:00'::timestamp without time zone);
            SELECT metadata.f_get_conversion_by_date_prid(1000, '2024-04-15 10:00:00'::timestamp without time zone);
        */

        SELECT
            pc_conv INTO conv
        FROM
            metadata.parameters_conversions
        WHERE
            param_id = prid
            AND tsrange(pc_from_fulldate, pc_to_fulldate, '[]') @> ts;

        RETURN conv;

        /* errors check */
        EXCEPTION
        /* in case of any error */
        WHEN OTHERS THEN RAISE NOTICE 'ERROR in metadata.f_get_conversion_by_date_prid: %', SQLERRM;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION metadata.f_get_conversion_by_date_prid(integer, timestamp without time zone) TO group_admin;
    GRANT EXECUTE ON FUNCTION metadata.f_get_conversion_by_date_prid(integer, timestamp without time zone) TO group_bobo;
    GRANT EXECUTE ON FUNCTION metadata.f_get_conversion_by_date_prid(integer, timestamp without time zone) TO group_tools;
    GRANT EXECUTE ON FUNCTION metadata.f_get_conversion_by_date_prid(integer, timestamp without time zone) TO group_readonly;

    -- comment
    COMMENT ON FUNCTION metadata.f_get_conversion_by_date_prid(integer, timestamp without time zone)
        IS 'Function to retrieve the conversion coefficient based on the past date: it is useful in case a parameter has changed conversion factor over time';

    -- Funzione per recuperare il coefficiente di conversione in base ad una data e di un determinato parametro di una determinata stazione
    -- DROP FUNCTION IF EXISTS metadata.f_get_conversion_by_date_stprid(bigint, timestamp without time zone);
    CREATE OR REPLACE FUNCTION metadata.f_get_conversion_by_date_stprid(
        stprid bigint,
        ts timestamp without time zone)
        RETURNS real
        LANGUAGE 'plpgsql'
        COST 100
        STABLE PARALLEL UNSAFE
    AS $BODY$
            DECLARE
                conv real;
            BEGIN

                /* TEST
                    SELECT metadata.f_get_conversion_by_date_stprid(98, '2023-07-18 10:00:00'::timestamp without time zone);
                    SELECT metadata.f_get_conversion_by_date_stprid(98, '2024-04-15 10:00:00'::timestamp without time zone);
                */
                CASE  
                    WHEN stprid < 0 THEN  

                        SELECT
                            pc.pc_conv INTO conv
                        FROM
                            metadata.f_get_view_sites_parameters(stprid::bigint) sp
                            LEFT JOIN metadata.parameters_conversions pc USING (param_id)
                        WHERE
                            stpr_id = stprid
                            AND tsrange(pc_from_fulldate, pc_to_fulldate, '[]') @> ts;

                    ELSE
                        SELECT
                            pc.pc_conv INTO conv
                        FROM
                            metadata.stations_parameters sp
                            LEFT JOIN metadata.parameters_conversions pc USING (param_id)
                        WHERE
                            stpr_id = stprid
                            AND tsrange(pc_from_fulldate, pc_to_fulldate, '[]') @> ts;
                END CASE;

                RETURN conv;

            /* errors check */
            EXCEPTION
               /* in case of any error */
               WHEN OTHERS THEN RAISE NOTICE 'ERROR in metadata.f_get_conversion_by_date_stprid: %', SQLERRM;
            END;
    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION metadata.f_get_conversion_by_date_stprid(bigint, timestamp without time zone) TO group_admin;
    GRANT EXECUTE ON FUNCTION metadata.f_get_conversion_by_date_stprid(bigint, timestamp without time zone) TO group_bobo;
    GRANT EXECUTE ON FUNCTION metadata.f_get_conversion_by_date_stprid(bigint, timestamp without time zone) TO group_tools;
    GRANT EXECUTE ON FUNCTION metadata.f_get_conversion_by_date_stprid(bigint, timestamp without time zone) TO group_readonly;

    -- comment
    COMMENT ON FUNCTION metadata.f_get_conversion_by_date_stprid(bigint, timestamp without time zone)
        IS 'Function to retrieve the conversion coefficient based on the past date: it is useful in case a parameter has changed conversion factor over time.';

    -- Funzione per recuperare l'icona della mappa di una determinata stazione
    -- DROP FUNCTION IF EXISTS metadata.f_get_icon_by_station_id(integer);
    CREATE OR REPLACE FUNCTION metadata.f_get_icon_by_station_id(
        stid integer
    )
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
                WHEN st_info_typology_fk = 5 THEN 'f3b3' -- Emissioni f240 6 per bobo
                WHEN st_info_roaming_type_fk IN (2, 4) THEN 'f0d1' -- staz mobili e siti con stanziamento
                WHEN st_info_roaming_type_fk = 5 THEN 'f495' -- magazzini
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

    -- grants
    GRANT EXECUTE ON FUNCTION metadata.f_get_icon_by_station_id(integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION metadata.f_get_icon_by_station_id(integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION metadata.f_get_icon_by_station_id(integer) TO group_tools;
    GRANT EXECUTE ON FUNCTION metadata.f_get_icon_by_station_id(integer) TO group_readonly;

    -- comment
    COMMENT ON FUNCTION metadata.f_get_icon_by_station_id(integer) IS 'Get map icon by station id';

    -- Funzione che restituisce un oggetto con tutti i parametri e i loro ID recuperati dal file di configurazione della stazione
    -- DROP FUNCTION IF EXISTS metadata.f_get_parameters_from_station_config_v3(jsonb);
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
                                'need-group', TRUE,
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
                                        'need-group', TRUE,
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

    -- Funzione per recuperare l'stid in base alla data passata
    -- la funzione è utile nel caso di mezzi mobili dislocati in siti diversi nel corso del tempo
    -- per le stazioni fisse l'stid restituito corrisponde all'originale
    -- DROP FUNCTION IF EXISTS metadata.f_get_stationid_by_date(integer, timestamp without time zone);
    CREATE OR REPLACE FUNCTION metadata.f_get_stationid_by_date(
        stid integer,
        ts   timestamp
    )
        RETURNS integer
        LANGUAGE 'plpgsql'
        STABLE
    AS
    $$

    DECLARE
        n_stid integer;
    BEGIN
        /* TEST
            SELECT metadata.f_get_stationid_by_date(1007, '2023-07-18 10:00:00'::timestamp without time zone);
            SELECT metadata.f_get_stationid_by_date(1000, '2023-07-18 10:00:00'::timestamp without time zone);
        */

        SELECT
            COALESCE(  ss.station_override_id, s.station_id ) INTO n_stid
        FROM
            metadata.stations s
            LEFT JOIN metadata.stations_sites ss ON (s.station_id = ss.station_id AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> ( ts AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome'))
        WHERE
            s.station_id = stid;

        RETURN n_stid;

        /* errors check */
        EXCEPTION
        /* in case of any error */
        WHEN OTHERS THEN RAISE NOTICE 'ERROR in f_get_stationid_by_date: %', SQLERRM;
    END;

    $$;

    -- grants
    GRANT EXECUTE ON FUNCTION metadata.f_get_stationid_by_date(integer, timestamp without time zone) TO group_admin;
    GRANT EXECUTE ON FUNCTION metadata.f_get_stationid_by_date(integer, timestamp without time zone) TO group_tools;
    GRANT EXECUTE ON FUNCTION metadata.f_get_stationid_by_date(integer, timestamp without time zone) TO group_bobo;
    GRANT EXECUTE ON FUNCTION metadata.f_get_stationid_by_date(integer, timestamp without time zone) TO group_readonly;

    -- comment
    COMMENT ON FUNCTION metadata.f_get_stationid_by_date(integer, timestamp without time zone)
        IS 'Function to retrieve the stid based on the past date: it is useful in the case of mobile vehicles located in different sites over time. For fixed stations the returned stid corresponds to the original one';

    -- Funzione per recuperare l'id della associazione stazione-parametro di un determinato parametro di una determinata stazione
    -- DROP FUNCTION IF EXISTS metadata.f_get_stprid_by_station_and_table_id(integer, integer);
    CREATE OR REPLACE FUNCTION metadata.f_get_stprid_by_station_and_table_id(
        stid integer,
        tbid integer
    )
        RETURNS integer
        LANGUAGE 'plpgsql'
        STABLE
    AS
    $$

    DECLARE
        stprid integer;
    BEGIN
        SELECT
            stpr_id INTO stprid
        FROM
            metadata.stations_parameters
        WHERE
            stpr_table_id = tbid and station_id = stid;

        RETURN stprid;

        /* errors check */
        EXCEPTION
        /* in case of any error */
        WHEN OTHERS THEN RAISE NOTICE 'ERROR in f_get_stprid_by_station_and_table_id: %', SQLERRM;
    END;

    $$;

    -- grants
    ALTER FUNCTION metadata.f_get_stprid_by_station_and_table_id(integer, integer) OWNER TO postgres;
    GRANT EXECUTE ON FUNCTION metadata.f_get_stprid_by_station_and_table_id(integer, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION metadata.f_get_stprid_by_station_and_table_id(integer, integer) TO group_tools;
    GRANT EXECUTE ON FUNCTION metadata.f_get_stprid_by_station_and_table_id(integer, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION metadata.f_get_stprid_by_station_and_table_id(integer, integer) TO group_readonly;

    -- comment
    COMMENT ON FUNCTION metadata.f_get_stprid_by_station_and_table_id(integer, integer)
        IS 'Get the parameter stprid upon station_id and table_id';

    -- Funzione per recuperare il nome della tabella dei dati di una determinata stazione
    -- DROP FUNCTION IF EXISTS metadata.f_get_tablename_by_stationid(integer);
    CREATE OR REPLACE FUNCTION metadata.f_get_tablename_by_stationid(
        stid integer
    )
        RETURNS text
        LANGUAGE 'plpgsql'
        STABLE
    AS
    $$

    DECLARE
        tablename text;
    BEGIN
        SELECT
            ((station_schema || '.'::text) || COALESCE(station_prefix, ''::text)) || station_table
            INTO tablename
        FROM
            metadata.stations
        WHERE
            station_id = stid;

        RETURN tablename;

        /* errors check */
        EXCEPTION
        /* in case of any error */
        WHEN OTHERS THEN RAISE NOTICE 'ERROR in f_get_tablename_by_stationid: %', SQLERRM;
    END;

    $$;

    -- grants
    ALTER FUNCTION metadata.f_get_tablename_by_stationid(integer) OWNER TO postgres;
    GRANT EXECUTE ON FUNCTION metadata.f_get_tablename_by_stationid(integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION metadata.f_get_tablename_by_stationid(integer) TO group_tools;
    GRANT EXECUTE ON FUNCTION metadata.f_get_tablename_by_stationid(integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION metadata.f_get_tablename_by_stationid(integer) TO group_readonly;

    -- DROP FUNCTION metadata.f_get_view_sites_parameters(bigint);
    CREATE OR REPLACE FUNCTION metadata.f_get_view_sites_parameters(
        stprid bigint
    )
        RETURNS TABLE(
            stpr_id         bigint,    
            station_id      integer,    
            param_id        integer,    
            stpr_group_id   integer,        
            stpr_table_id   integer,
            station_fulltable text,
            stsi_period     tsmultirange,
            stpr_note       text    
        )
        LANGUAGE 'plpgsql'
        COST 100
        STABLE PARALLEL UNSAFE
    AS $BODY$
        DECLARE
            s integer;
        BEGIN

            /**
             * Function for the dynamic recovery of a table containing all the metadata relating to a specific STPRID of an ALLOCATED mobile vehicle 
             * These special STPRIDs are negative and they are built in this way:
             *  - STID || LPAD(STPRID, 7, '0') 
             * 
             * The STID is the one assigned to the allocation of the mobile vehicle.
             * The function is used in Analyser for the recovery of parameter information
             * 
             * Example: SELECT * FROM metadata.f_get_view_sites_parameters( -15320026270::bigint);
             */

            /* Get station override id*/ 
            SELECT 
                LEFT(( stprid )::text, -7)::integer * -1 INTO s;

            /* Return the set of metadata for the specifc stprid */
            RETURN QUERY
                EXECUTE
                    'SELECT
                        -(so.station_override_id::text || lpad(sp.stpr_id::text, 7, ''0''))::bigint AS stpr_id,
                        station_override_id AS station_id,
                        sp.param_id,
                        sp.stpr_group_id,
                        sp.stpr_table_id,
                        ((st2.station_schema || ''.''::text) || COALESCE(st2.station_prefix, ''''::text)) || st2.station_table AS station_fulltable,
                        stsi_period,
                        sp.stpr_note
                    FROM (
                        SELECT
                            station_id,
                            station_override_id,
                            range_agg (tsrange(stsi_startup_date, stsi_dismiss_date, ''[]'')) as stsi_period
                        FROM metadata.stations_sites ss
                        WHERE 
                            station_override_id = '|| s ||' 
                        GROUP BY station_id, station_override_id
                        ORDER BY station_id, station_override_id
                    ) so
                        LEFT JOIN metadata.stations_parameters sp ON (sp.station_id = so.station_id)
                        LEFT JOIN metadata.stations st ON (st.station_id = so.station_override_id)
                        LEFT JOIN metadata.stations st2 ON (st2.station_id = so.station_id)
                    WHERE 
                        -(so.station_override_id::text || lpad(sp.stpr_id::text, 7, ''0''))::bigint = '|| stprid;

        /* errors check */
        EXCEPTION
           /* in case of any error */
           WHEN OTHERS THEN RAISE NOTICE 'ERROR in metadata.f_get_view_sites_parameters: %', SQLERRM;
        END;
    $BODY$;

    GRANT EXECUTE ON FUNCTION      metadata.f_get_view_sites_parameters(bigint) TO group_admin;
    GRANT EXECUTE ON FUNCTION      metadata.f_get_view_sites_parameters(bigint) TO group_bobo;
    GRANT EXECUTE ON FUNCTION      metadata.f_get_view_sites_parameters(bigint) TO group_tools;

    COMMENT ON FUNCTION metadata.f_get_view_sites_parameters(bigint) IS '[OPAS] Function for the recovery of the metadata relating to a specific STPRID of an ALLOCATED mobile vehicle.';


    -- comment
    COMMENT ON FUNCTION metadata.f_get_tablename_by_stationid(integer)
        IS 'Get the parameter table id upon param_id';

    -- Funzione trigger che propaga il nuovo coefficiente nella tabella principale 'metadata.parameters'
    -- DROP FUNCTION IF EXISTS metadata.f_update_param_current_conversion();
    CREATE OR REPLACE FUNCTION metadata.f_update_param_current_conversion()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$

    BEGIN
        RAISE NOTICE 'TRIGGER f_update_param_current_conversion!';

        -- sanity check
        IF NOT tsrange(NEW.pc_from_fulldate, NEW.pc_to_fulldate, '[]') @> CURRENT_DATE::timestamp THEN
            -- Do not update parameter conversion
            RETURN NEW;
        END IF;

        UPDATE metadata.parameters SET param_conv = NEW.pc_conv WHERE param_id = NEW.param_id;

        -- RAISE NOTICE '-- END --';
        RETURN NEW;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR metadata.f_update_param_current_conversion(): %', SQLERRM;
            RETURN NEW;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION metadata.f_update_param_current_conversion() TO group_admin;
    GRANT EXECUTE ON FUNCTION metadata.f_update_param_current_conversion() TO group_bobo;
    GRANT EXECUTE ON FUNCTION metadata.f_update_param_current_conversion() TO group_tools;

    -- comment
    COMMENT ON FUNCTION metadata.f_update_param_current_conversion() IS 'Trigger function that propagates new coefficient in the main table metadata.parameters';

    -- Funzione trigger che propaga le modifiche del nome del sito a tutte le stazioni virtuali
    -- DROP FUNCTION IF EXISTS metadata.f_update_site_allocations();
    CREATE OR REPLACE FUNCTION metadata.f_update_site_allocations()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$

    DECLARE
        r record;
        n text;
    BEGIN
        -- RAISE NOTICE 'TRIGGER f_update_site!';

        -- check for changes
        IF
            NEW.site_name != OLD.site_name
        THEN
            -- continue
        ELSE
            -- skip
            --RAISE NOTICE 'Nothing changed!';
            RETURN NEW;
        END IF;

        RAISE NOTICE '-- START LOOP --';
        FOR r IN
            /* check if exist locations in this site */
            SELECT station_override_id, station_id
            FROM metadata.stations_sites
            WHERE site_id = NEW.site_id
            GROUP BY station_override_id, station_id
        LOOP

            RAISE NOTICE 'Override ID: % - Station ID: %',
            FORMAT('%', r.station_override_id),
            FORMAT('%', r.station_id);

            /* retrieve station short name */
            SELECT st_info_shortname INTO n
            FROM metadata.stations_info
            WHERE station_id = r.station_id;

            /* update station-site name in metadata.stations*/
            UPDATE metadata.stations SET station_name = n||' - '||NEW.site_name WHERE station_id = r.station_override_id;

            /* update station-site short name in metadata.stations_info*/
            UPDATE metadata.stations_info SET st_info_shortname = n||' - '||NEW.site_name WHERE station_id = r.station_override_id;

        END LOOP;

        RAISE NOTICE '-- END --';
        RETURN NEW;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR metadata.f_update_site_allocations(): %', SQLERRM;
            RETURN NEW;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION metadata.f_update_site_allocations() TO group_admin;
    GRANT EXECUTE ON FUNCTION metadata.f_update_site_allocations() TO group_bobo;
    GRANT EXECUTE ON FUNCTION metadata.f_update_site_allocations() TO group_tools;

    -- comment
    COMMENT ON FUNCTION metadata.f_update_site_allocations() IS 'Trigger function that propagates site name changes to all virtual stations';

    -- --------------------------------------------------------------------------------------------
    -- TRIGGERS
    -- --------------------------------------------------------------------------------------------

    CREATE OR REPLACE TRIGGER metadata_parameters_update_current_conversion_ai
        AFTER INSERT
        ON metadata.parameters_conversions
        FOR EACH ROW
        EXECUTE FUNCTION metadata.f_update_param_current_conversion();

    CREATE OR REPLACE TRIGGER metadata_site_update_allocations_au
        AFTER UPDATE OF site_name
        ON metadata.sites
        FOR EACH ROW
        EXECUTE FUNCTION metadata.f_update_site_allocations();

-- SCHEMA clients

    -- DROP SCHEMA IF EXISTS clients CASCADE;
    CREATE SCHEMA clients
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA clients TO group_admin;
    GRANT USAGE ON SCHEMA clients TO group_bobo;
    GRANT USAGE ON SCHEMA clients TO group_readonly;
    GRANT USAGE ON SCHEMA clients TO group_tools;
    COMMENT ON SCHEMA clients IS 'Data schema for clients utilities in OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TYPES
    -- --------------------------------------------------------------------------------------------

    -- Tipo utilizzato per restituire i dati pubblici per le estrazioni in formato csv
    -- DROP TYPE IF EXISTS clients.t_data_csv;
    CREATE TYPE clients.t_data_csv AS
    (
        dataora timestamp without time zone,
        misura numeric,
        codice smallint
    );

    -- grants
    GRANT USAGE ON TYPE clients.t_data_csv TO group_admin;
    GRANT USAGE ON TYPE clients.t_data_csv TO group_bobo;
    GRANT USAGE ON TYPE clients.t_data_csv TO group_tools;
    GRANT USAGE ON TYPE clients.t_data_csv TO group_readonly;

    -- comment
    COMMENT ON TYPE clients.t_data_csv IS 'Type used to return data for public csv extractions';

    -- Tipo utilizzato per restituire dati da funzioni di estrazione dati generiche
    -- DROP TYPE IF EXISTS clients.t_data_function;
    CREATE TYPE clients.t_data_function AS
    (
        measure_date_time   timestamp,
        measure_id          smallint,
        measure_value       numeric,
        measure_min         numeric,
        measure_max         numeric,
        measure_perc        smallint,
        post_validity_code  integer,
        final_validity_code smallint
    );

    -- grants
    GRANT USAGE ON TYPE clients.t_data_function TO group_admin;
    GRANT USAGE ON TYPE clients.t_data_function TO group_bobo;
    GRANT USAGE ON TYPE clients.t_data_function TO group_tools;
    GRANT USAGE ON TYPE clients.t_data_function TO group_readonly;

    -- comment
    COMMENT ON TYPE clients.t_data_function IS 'Type used to return data from generic data extraction functions';

    -- Tipo utilizzato per restituire dati dalle funzioni di estrazione dati in tempo reale
    -- DROP TYPE IF EXISTS clients.t_inst_data_function;
    CREATE TYPE clients.t_inst_data_function AS
    (
        measure_date_time timestamp,
        measure_id        smallint,
        measure_value     numeric,
        measure_min       numeric,
        measure_max       numeric,
        station_code      smallint,
        measure_code      integer
    );

    -- grants
    GRANT USAGE ON TYPE clients.t_inst_data_function TO group_admin;
    GRANT USAGE ON TYPE clients.t_inst_data_function TO group_bobo;
    GRANT USAGE ON TYPE clients.t_inst_data_function TO group_tools;
    GRANT USAGE ON TYPE clients.t_inst_data_function TO group_readonly;

    -- comment
    COMMENT ON TYPE clients.t_inst_data_function IS 'Type used to return data from realtime data extraction functions';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella che contiene i risultati delle tarature effettuate
    -- DROP TABLE IF EXISTS clients.calibrations_result;
    CREATE TABLE clients.calibrations_result
    (
        calibration_id        integer NOT NULL,
        calibration_date_time timestamp NOT NULL,
        station_id            integer NOT NULL,
        measure_id            smallint NOT NULL,
        calibration_type      text NOT NULL,
        calibration_step      text NOT NULL,
        reference_value       real NOT NULL,
        defect_value          real NOT NULL,
        result_code           smallint NOT NULL,
        result_value          real NOT NULL,

        CONSTRAINT calibrations_result_pkey PRIMARY KEY (calibration_id, calibration_date_time, station_id, measure_id, calibration_type, calibration_step)
        -- CONSTRAINT calibrations_result_fkey FOREIGN KEY (station_id)
        --     REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE ON DELETE RESTRICT
    );

    -- grants
    GRANT SELECT ON TABLE clients.calibrations_result TO group_readonly;
    GRANT ALL ON TABLE    clients.calibrations_result TO group_admin;
    GRANT ALL ON TABLE    clients.calibrations_result TO group_bobo;
    GRANT ALL ON TABLE    clients.calibrations_result TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.calibrations_result                       IS 'Remote stations calibrations results';
    COMMENT ON COLUMN clients.calibrations_result.calibration_id        IS 'Calibration measure_id';
    COMMENT ON COLUMN clients.calibrations_result.calibration_date_time IS 'Calibration date time';
    COMMENT ON COLUMN clients.calibrations_result.measure_id            IS 'Calibration measure id';
    COMMENT ON COLUMN clients.calibrations_result.calibration_type      IS 'Calibration type (AUTO,USER)';
    COMMENT ON COLUMN clients.calibrations_result.calibration_step      IS 'Calibration calibration_step (ZERO,SPAN,PURGE,UNKNOWN)';
    COMMENT ON COLUMN clients.calibrations_result.reference_value       IS 'Calibration reference value';
    COMMENT ON COLUMN clients.calibrations_result.defect_value          IS 'Calibration defect value (Percent or absolute(zero ppb)';
    COMMENT ON COLUMN clients.calibrations_result.result_code           IS 'Calibration result code (SPAN_LOW = 1, SPAN_HIGH = 2, ZERO_LOW = 4, ZERO_HIGH = 8, CALIBRATION = 16)';
    COMMENT ON COLUMN clients.calibrations_result.result_value          IS 'Calibration result value';

    -- Tabella che le informazioni relative agli allarmi
    -- DROP TABLE IF EXISTS clients.alarms;
    CREATE TABLE clients.alarms (
        param_id        integer NOT NULL,
        alarm_label     text NOT NULL,
        alarm_icon      text NOT NULL,
        alarm_color     text NOT NULL,

        CONSTRAINT clients_alarms_pk PRIMARY KEY (param_id)
        -- CONSTRAINT clients_alarms_fk2 FOREIGN KEY (param_id)
        -- REFERENCES metadata.parameters (param_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    clients.alarms TO group_admin;
    GRANT ALL ON TABLE    clients.alarms TO group_bobo;
    GRANT ALL ON TABLE    clients.alarms TO group_tools;
    GRANT SELECT ON TABLE clients.alarms TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.alarms             IS 'Table containing information about alarms';
    COMMENT ON COLUMN clients.alarms.param_id    IS 'Parameter id (PK)';
    COMMENT ON COLUMN clients.alarms.alarm_label IS 'Alarm label';
    COMMENT ON COLUMN clients.alarms.alarm_icon  IS 'Alarm icon';
    COMMENT ON COLUMN clients.alarms.alarm_color IS 'Alarm color';

    -- Tabella che contiene i risultati delle validazioni automatiche
    -- DROP TABLE IF EXISTS clients.auto_validation_results;
    CREATE TABLE clients.auto_validation_results (
        avr_id            bigserial NOT NULL,
        stpr_id           integer NOT NULL,
        measure_date_time timestamp NOT NULL,
        avr_date_time     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT auto_validation_results_pkey PRIMARY KEY (avr_id)
        -- CONSTRAINT clients_auto_validation_results_fkey FOREIGN KEY (stpr_id)
        -- REFERENCES metadata.stations_parameters (stpr_id) MATCH SIMPLE
        --     ON UPDATE NO ACTION
        --     ON DELETE RESTRICT
    ) WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    clients.auto_validation_results TO group_bobo;
    GRANT ALL ON TABLE    clients.auto_validation_results TO group_admin;
    GRANT ALL ON TABLE    clients.auto_validation_results TO group_tools;
    GRANT SELECT ON TABLE clients.auto_validation_results TO group_readonly;
    GRANT ALL ON SEQUENCE clients.auto_validation_results_avr_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.auto_validation_results_avr_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.auto_validation_results_avr_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE clients.auto_validation_results                    IS 'Table containing all automatic validation results';
    COMMENT ON COLUMN clients.auto_validation_results.avr_id            IS 'auto validation result id';
    COMMENT ON COLUMN clients.auto_validation_results.stpr_id           IS 'station parameter limit id';
    COMMENT ON COLUMN clients.auto_validation_results.measure_date_time IS 'date time of invalidated/suspect measure';
    COMMENT ON COLUMN clients.auto_validation_results.avr_date_time     IS 'date time of automatic invalidation';

    -- Tabella che contiene i dati delle tarature effettuate
    -- DROP TABLE IF EXISTS clients.calibrations_data;
    CREATE TABLE clients.calibrations_data
    (
        calibration_id        integer NOT NULL,
        calibration_date_time timestamp NOT NULL,
        station_id            integer NOT NULL,
        measure_id            smallint NOT NULL,
        calibration_type      text NOT NULL,
        calibration_step      text NOT NULL,
        measure_value         real NOT NULL,

        CONSTRAINT clients_calibrations_data_pkey PRIMARY KEY (calibration_id, calibration_date_time, station_id, measure_id)
        -- CONSTRAINT clients_calibrations_data_fkey FOREIGN KEY (station_id)
        --     REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE ON DELETE RESTRICT
    );

    -- grants
    GRANT SELECT ON TABLE clients.calibrations_data TO group_readonly;
    GRANT ALL ON TABLE    clients.calibrations_data TO group_admin;
    GRANT ALL ON TABLE    clients.calibrations_data TO group_bobo;
    GRANT ALL ON TABLE    clients.calibrations_data TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.calibrations_data                       IS 'Remote stations calibrations data';
    COMMENT ON COLUMN clients.calibrations_data.calibration_id        IS 'Calibration measure_id';
    COMMENT ON COLUMN clients.calibrations_data.calibration_date_time IS 'Calibration calibration_date_time';
    COMMENT ON COLUMN clients.calibrations_data.measure_id            IS 'Parameter measure_id';
    COMMENT ON COLUMN clients.calibrations_data.calibration_type      IS 'Calibration calibration_type (AUTO,USER)';
    COMMENT ON COLUMN clients.calibrations_data.calibration_step      IS 'Calibration calibration_step (ZERO,SPAN,PURGE,UNKNOWN)';
    COMMENT ON COLUMN clients.calibrations_data.measure_value         IS 'Parameter measure_value';

    -- Tabella che contiene le informazioni relative alla copertura dei dati
    -- DROP TABLE IF EXISTS clients.data_coverage;
    CREATE TABLE clients.data_coverage
    (
        station_id            integer NOT NULL,
        measure_year          smallint NOT NULL,
        measure_month         smallint NOT NULL,
        measure_id            smallint NOT NULL,
        measure_perc          smallint NOT NULL,
        measure_validity_perc smallint NOT NULL,

        CONSTRAINT clients_data_coverage_pkey PRIMARY KEY (station_id, measure_year, measure_month, measure_id)
        -- CONSTRAINT clients_data_coverage_fkey FOREIGN KEY (station_id)
        --     REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE ON DELETE RESTRICT
    );

    -- grants
    GRANT SELECT ON TABLE clients.data_coverage TO group_readonly;
    GRANT ALL ON TABLE    clients.data_coverage TO group_admin;
    GRANT ALL ON TABLE    clients.data_coverage TO group_bobo;
    GRANT ALL ON TABLE    clients.data_coverage TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.data_coverage                       IS 'Coverage table';
    COMMENT ON COLUMN clients.data_coverage.station_id            IS 'Coverage station id';
    COMMENT ON COLUMN clients.data_coverage.measure_year          IS 'Coverage date year';
    COMMENT ON COLUMN clients.data_coverage.measure_month         IS 'Coverage date month';
    COMMENT ON COLUMN clients.data_coverage.measure_id            IS 'Coverage measure id';
    COMMENT ON COLUMN clients.data_coverage.measure_perc          IS 'Coverage measure percentage';
    COMMENT ON COLUMN clients.data_coverage.measure_validity_perc IS 'Coverage valid measure percentage';

    -- Tabella che contiene i dati più recenti da plottare all'interno dell'applicativo "Dataview"
    -- DROP TABLE IF EXISTS clients.dataview_lastdata;
    CREATE TABLE clients.dataview_lastdata
    (
        station_id   integer NOT NULL,
        param_id     integer NOT NULL,
        marker_value real,
        marker_dir   real,
        marker_sum   real, -- for rain

        CONSTRAINT clients_dataview_lastdata_pkey PRIMARY KEY (station_id, param_id)
    );

    -- grants
    GRANT ALL ON TABLE    clients.dataview_lastdata TO group_admin;
    GRANT ALL ON TABLE    clients.dataview_lastdata TO group_bobo;
    GRANT ALL ON TABLE    clients.dataview_lastdata TO group_tools;
    GRANT SELECT ON TABLE clients.dataview_lastdata TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.dataview_lastdata              IS 'Collect latest data to be plotted in the dataview application map';
    COMMENT ON COLUMN clients.dataview_lastdata.station_id   IS 'Station ID';
    COMMENT ON COLUMN clients.dataview_lastdata.param_id     IS 'Parameter ID';
    COMMENT ON COLUMN clients.dataview_lastdata.marker_value IS 'Measure value';
    COMMENT ON COLUMN clients.dataview_lastdata.marker_dir   IS 'Measure dir';
    COMMENT ON COLUMN clients.dataview_lastdata.marker_sum   IS 'Measure rain sum';

    -- Tabella che contiene le informazioni relative ai messaggi dello strumento DERENDA
    -- DROP TABLE IF EXISTS clients.derenda_messages;
    CREATE TABLE clients.derenda_messages
    (
        id      smallint PRIMARY KEY,
        message text
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.derenda_messages TO group_admin;
    GRANT ALL ON TABLE    clients.derenda_messages TO group_bobo;
    GRANT ALL ON TABLE    clients.derenda_messages TO group_tools;
    GRANT SELECT ON TABLE clients.derenda_messages TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.derenda_messages         IS 'Store skypost derenda default messages';
    COMMENT ON COLUMN clients.derenda_messages.id      IS 'Progressive id';
    COMMENT ON COLUMN clients.derenda_messages.message IS 'Error message';

    -- Tabella che contiene le informazioni relative agli allarmi dello strumento DERENDA
    -- DROP TABLE IF EXISTS clients.derenda_warnings;
    CREATE TABLE clients.derenda_warnings
    (
        id         serial NOT NULL PRIMARY KEY,
        fulldate   timestamp NOT NULL,
        station_id integer NOT NULL,
        warning_id smallint,

        CONSTRAINT clients_derenda_warnings_ukey UNIQUE (fulldate, station_id)
        -- CONSTRAINT clients_derenda_warnings_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.derenda_warnings TO group_admin;
    GRANT ALL ON TABLE    clients.derenda_warnings TO group_bobo;
    GRANT ALL ON TABLE    clients.derenda_warnings TO group_tools;
    GRANT SELECT ON TABLE clients.derenda_warnings TO group_readonly;
    GRANT ALL ON SEQUENCE clients.derenda_warnings_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.derenda_warnings_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.derenda_warnings_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.derenda_warnings            IS 'Store skypost derenda alarms';
    COMMENT ON COLUMN clients.derenda_warnings.id         IS 'The unique id';
    COMMENT ON COLUMN clients.derenda_warnings.fulldate   IS 'The record date';
    COMMENT ON COLUMN clients.derenda_warnings.station_id IS 'The station id';
    COMMENT ON COLUMN clients.derenda_warnings.warning_id IS 'The warning id';

    -- Tabella che contiene le informazioni relative ai messaggi dello strumento ENVEA MP101M
    -- DROP TABLE IF EXISTS clients.envea_messages;
    CREATE TABLE clients.envea_messages
    (
        id      smallint PRIMARY KEY,
        message text
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.envea_messages TO group_admin;
    GRANT ALL ON TABLE    clients.envea_messages TO group_bobo;
    GRANT ALL ON TABLE    clients.envea_messages TO group_tools;
    GRANT SELECT ON TABLE clients.envea_messages TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.envea_messages         IS 'Store MPM101 envea default messages';
    COMMENT ON COLUMN clients.envea_messages.id      IS 'Progressive id';
    COMMENT ON COLUMN clients.envea_messages.message IS 'Error message';

    -- Tabella che contiene le informazioni relative agli allarmi dello strumento ENVEA MP101M
    -- DROP TABLE IF EXISTS clients.envea_warnings;
    CREATE TABLE clients.envea_warnings
    (
        id         serial NOT NULL PRIMARY KEY,
        fulldate   timestamp NOT NULL,
        station_id integer NOT NULL,
        warning_id smallint,

        CONSTRAINT clients_envea_warnings_ukey UNIQUE (fulldate, station_id)
        -- CONSTRAINT clients_envea_warnings_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.envea_warnings TO group_admin;
    GRANT ALL ON TABLE    clients.envea_warnings TO group_bobo;
    GRANT ALL ON TABLE    clients.envea_warnings TO group_tools;
    GRANT SELECT ON TABLE clients.envea_warnings TO group_readonly;
    GRANT ALL ON SEQUENCE clients.envea_warnings_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.envea_warnings_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.envea_warnings_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.envea_warnings            IS 'Store MPM101 envea alarms';
    COMMENT ON COLUMN clients.envea_warnings.id         IS 'The unique id';
    COMMENT ON COLUMN clients.envea_warnings.fulldate   IS 'The record date';
    COMMENT ON COLUMN clients.envea_warnings.station_id IS 'The station id';
    COMMENT ON COLUMN clients.envea_warnings.warning_id IS 'The warning id';

    -- Tabella che contiene le informazioni relative ai messaggi dello strumento PALAS FIDAS
    -- DROP TABLE IF EXISTS clients.fidas_messages;
    CREATE TABLE clients.fidas_messages (
        fm_id   integer NOT NULL,
        fm_code text NOT NULL,
        fm_desc text NOT NULL,

        CONSTRAINT clients_fidas_messages_pk PRIMARY KEY (fm_id)
    )
    WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    clients.fidas_messages TO group_admin;
    GRANT ALL ON TABLE    clients.fidas_messages TO group_bobo;
    GRANT ALL ON TABLE    clients.fidas_messages TO group_tools;
    GRANT SELECT ON TABLE clients.fidas_messages TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.fidas_messages         IS 'Table containing fidas possible messages';
    COMMENT ON COLUMN clients.fidas_messages.fm_id   IS 'Serial ID';
    COMMENT ON COLUMN clients.fidas_messages.fm_code IS 'Message CODE';
    COMMENT ON COLUMN clients.fidas_messages.fm_desc IS 'Message description';

    -- Tabella che contiene le informazioni relative agli allarmi dello strumento PALAS FIDAS
    -- DROP TABLE IF EXISTS clients.fidas_warnings;
    CREATE TABLE clients.fidas_warnings (

        id         serial NOT NULL,
        fulldate   timestamp NOT NULL,
        station_id integer NOT NULL,
        bit_mask   bit(8) NOT NULL,

        CONSTRAINT clients_fidas_warnings_pkey PRIMARY KEY (id),
        CONSTRAINT clients_fidas_warnings_ukey UNIQUE (fulldate, station_id)
        -- CONSTRAINT clients_fidas_warnings_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    clients.fidas_warnings TO group_admin;
    GRANT ALL ON TABLE    clients.fidas_warnings TO group_bobo;
    GRANT ALL ON TABLE    clients.fidas_warnings TO group_tools;
    GRANT SELECT ON TABLE clients.fidas_warnings TO group_readonly;
    GRANT ALL ON SEQUENCE clients.fidas_warnings_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.fidas_warnings_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.fidas_warnings_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.fidas_warnings            IS 'Table containing stations instrumental warnings';
    COMMENT ON COLUMN clients.fidas_warnings.id         IS 'Serial ID (PK)';
    COMMENT ON COLUMN clients.fidas_warnings.fulldate   IS 'Warning fulldate';
    COMMENT ON COLUMN clients.fidas_warnings.station_id IS 'Station id (FK)';
    COMMENT ON COLUMN clients.fidas_warnings.bit_mask   IS 'Warning bit mask';

    -- DROP TABLE IF EXISTS clients.final_validation_log;
    CREATE TABLE clients.final_validation_log
    (
        fvl_id         serial,
        us_id          integer NOT NULL,
        stpr_id        integer NOT NULL,
        fvc_code_id    smallint NOT NULL,
        fvl_date_start timestamp WITHOUT TIME ZONE NOT NULL,
        fvl_date_end   timestamp WITHOUT TIME ZONE NOT NULL,
        fvl_rows       integer NOT NULL,
        fvl_insert_ts  timestamp WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT clients_final_validation_log_pkey PRIMARY KEY (fvl_id)
        -- CONSTRAINT clients_final_validation_log_fk1 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_final_validation_log_fk2 FOREIGN KEY (stpr_id)
        --     REFERENCES metadata.stations_parameters (stpr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_final_validation_log_fk3 FOREIGN KEY (fvc_code_id)
        --     REFERENCES metadata.final_validation_codes (fvc_code_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.final_validation_log TO group_admin;
    GRANT ALL ON TABLE    clients.final_validation_log TO group_bobo;
    GRANT ALL ON TABLE    clients.final_validation_log TO group_tools;
    GRANT SELECT ON TABLE clients.final_validation_log TO group_readonly;
    GRANT ALL ON SEQUENCE clients.final_validation_log_fvl_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.final_validation_log_fvl_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.final_validation_log_fvl_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.final_validation_log                IS 'Table that holds the history of validations carried out by the portal';
    COMMENT ON COLUMN clients.final_validation_log.fvl_id         IS 'Validation serial ID (PK)';
    COMMENT ON COLUMN clients.final_validation_log.us_id          IS 'User ID (FK)';
    COMMENT ON COLUMN clients.final_validation_log.stpr_id        IS 'Station parameter ID (FK)';
    COMMENT ON COLUMN clients.final_validation_log.fvc_code_id    IS 'Final validation code (FK)';
    COMMENT ON COLUMN clients.final_validation_log.fvl_date_start IS 'Validation date start';
    COMMENT ON COLUMN clients.final_validation_log.fvl_date_end   IS 'Validation date end';
    COMMENT ON COLUMN clients.final_validation_log.fvl_rows       IS 'Number of rows affected by validation';
    COMMENT ON COLUMN clients.final_validation_log.fvl_insert_ts  IS 'Validation insert timestamp';

    -- Tabella che contiene le informazioni relative agli ultimi aggiornamenti dei dati degli strumenti associati alle stazioni
    -- DROP TABLE clients.instruments_last_update IF EXISTS;
    CREATE TABLE clients.instruments_last_update (
        station_id        integer,
        instr_last_update jsonb NOT NULL DEFAULT '{}'::jsonb,

        CONSTRAINT clients_instruments_last_update_pk PRIMARY KEY (station_id)
        -- CONSTRAINT clients_instruments_last_update_fk FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    clients.instruments_last_update TO group_admin;
    GRANT ALL ON TABLE    clients.instruments_last_update TO group_bobo;
    GRANT ALL ON TABLE    clients.instruments_last_update TO group_tools;
    GRANT SELECT ON TABLE clients.instruments_last_update TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.instruments_last_update                   IS 'Table containing fulldate of the last instruments data update';
    COMMENT ON COLUMN clients.instruments_last_update.station_id        IS 'Station id';
    COMMENT ON COLUMN clients.instruments_last_update.instr_last_update IS 'Instruments last update object';

    -- Tabella che contiene la lista dei job con i relativi comandi
    -- DROP TABLE IF EXISTS clients.jobs;
    CREATE TABLE clients.jobs (
        job_id      integer,
        job_name    text NOT NULL,
        job_desc    text,
        job_command text NOT NULL,

        CONSTRAINT clients_jobs_pkey PRIMARY KEY (job_id),
        CONSTRAINT clients_jobs_ukey UNIQUE (job_name)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.jobs TO group_admin;
    GRANT ALL ON TABLE    clients.jobs TO group_bobo;
    GRANT ALL ON TABLE    clients.jobs TO group_tools;
    GRANT SELECT ON TABLE clients.jobs TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.jobs             IS 'Table holding the list of jobs with commands';
    COMMENT ON COLUMN clients.jobs.job_id      IS 'Job id (PK)';
    COMMENT ON COLUMN clients.jobs.job_name    IS 'Job name';
    COMMENT ON COLUMN clients.jobs.job_desc    IS 'Job description';
    COMMENT ON COLUMN clients.jobs.job_command IS 'Job command';

    -- Tabella che contiene la coda dei jobs chiamati dal portale web
    -- DROP TABLE IF EXISTS clients.jobs_queue;
    CREATE TABLE clients.jobs_queue
    (
        jq_id         bigserial NOT NULL,
        job_id        integer NOT NULL,
        us_id         integer NOT NULL,
        jq_args_obj   jsonb,
        jq_start_ts   timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        jq_end_ts     timestamp,
        jq_result_obj jsonb,
        jq_ack        boolean DEFAULT FALSE,

        CONSTRAINT clients_jobs_queue_pkey PRIMARY KEY (jq_id)
        -- CONSTRAINT clients_jobs_queue_fkey FOREIGN KEY (job_id)
        -- REFERENCES clients.jobs (job_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_jobs_queue_fkey2 FOREIGN KEY (us_id)
        -- REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.jobs_queue TO group_admin;
    GRANT ALL ON TABLE    clients.jobs_queue TO group_bobo;
    GRANT ALL ON TABLE    clients.jobs_queue TO group_tools;
    GRANT SELECT ON TABLE clients.jobs_queue TO group_readonly;
    GRANT ALL ON SEQUENCE clients.jobs_queue_jq_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.jobs_queue_jq_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.jobs_queue_jq_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.jobs_queue               IS 'Table holding the queue of jobs called by the web application';
    COMMENT ON COLUMN clients.jobs_queue.jq_id         IS 'Job queue id (PK)';
    COMMENT ON COLUMN clients.jobs_queue.job_id        IS 'Job id (FK)';
    COMMENT ON COLUMN clients.jobs_queue.us_id         IS 'User ID (FK) to notify';
    COMMENT ON COLUMN clients.jobs_queue.jq_args_obj   IS 'Job arguments';
    COMMENT ON COLUMN clients.jobs_queue.jq_start_ts   IS 'Job start timestamp';
    COMMENT ON COLUMN clients.jobs_queue.jq_end_ts     IS 'Job end timestamp';
    COMMENT ON COLUMN clients.jobs_queue.jq_result_obj IS 'Job result with fields for toasts shown in the application';
    COMMENT ON COLUMN clients.jobs_queue.jq_ack        IS 'Job notification acknowledge';

    -- Tabella che contiene le informazioni relative ai messaggi dello strumento METONE BC 1054
    -- DROP TABLE IF EXISTS clients.metone_messages;
    CREATE TABLE clients.metone_messages
    (
        id      integer PRIMARY KEY,
        message text
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.metone_messages TO group_admin;
    GRANT ALL ON TABLE    clients.metone_messages TO group_bobo;
    GRANT ALL ON TABLE    clients.metone_messages TO group_tools;
    GRANT SELECT ON TABLE clients.metone_messages TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.metone_messages         IS 'Store METONE BC 1054 default messages';
    COMMENT ON COLUMN clients.metone_messages.id      IS 'Progressive id';
    COMMENT ON COLUMN clients.metone_messages.message IS 'Error message';

    -- Tabella che contiene le informazioni relative agli allarmi dello strumento METONE BC 1054
    -- DROP TABLE IF EXISTS clients.metone_warnings;
    CREATE TABLE clients.metone_warnings
    (
        id         serial NOT NULL PRIMARY KEY,
        fulldate   timestamp NOT NULL,
        station_id integer NOT NULL,
        warning_id smallint,

        CONSTRAINT clients_metone_warnings_ukey UNIQUE (fulldate, station_id)
        -- CONSTRAINT clients_metone_warnings_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.metone_warnings TO group_admin;
    GRANT ALL ON TABLE    clients.metone_warnings TO group_bobo;
    GRANT ALL ON TABLE    clients.metone_warnings TO group_tools;
    GRANT SELECT ON TABLE clients.metone_warnings TO group_readonly;
    GRANT ALL ON SEQUENCE clients.metone_warnings_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.metone_warnings_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.metone_warnings_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.metone_warnings            IS 'Store METONE BC 1054 alarms';
    COMMENT ON COLUMN clients.metone_warnings.id         IS 'The unique id';
    COMMENT ON COLUMN clients.metone_warnings.fulldate   IS 'The record date';
    COMMENT ON COLUMN clients.metone_warnings.station_id IS 'The station id';
    COMMENT ON COLUMN clients.metone_warnings.warning_id IS 'The warning id';

    -- Tabella che contiene le informazioni relative ai limiti per parametro impostati per l'auto-validazione
    -- DROP TABLE IF EXISTS clients.param_limits;
    CREATE TABLE clients.param_limits (
        pl_id                  serial NOT NULL,
        param_id               integer NOT NULL,
        pl_jd_from             smallint NOT NULL DEFAULT 1,
        pl_jd_to               smallint NOT NULL DEFAULT 366,
        pl_suspect_min         real,
        pl_suspect_max         real,
        pl_error_min           real,
        pl_error_max           real,
        pl_suspect_gap         real,
        pl_error_gap           real,
        pl_suspect_persistence integer,
        pl_error_persistence   integer,
        network_types          integer[] NOT NULL,

        CONSTRAINT clients_param_limits_pkey PRIMARY KEY (pl_id)
        -- CONSTRAINT clients_param_limits_fkey FOREIGN KEY (param_id)
        --     REFERENCES metadata.parameters(param_id) ON DELETE RESTRICT,
        -- CONSTRAINT clients_param_limits_check EXCLUDE USING GIST (
        --     param_id WITH =,
        --     network_types WITH &&,
        --     int4range(pl_jd_from, pl_jd_to, '[]') WITH &&
        -- )
    )
    WITHOUT OIDS;

    -- grants
    GRANT SELECT ON TABLE clients.param_limits TO group_readonly;
    GRANT ALL ON TABLE clients.param_limits TO group_bobo;
    GRANT ALL ON TABLE clients.param_limits TO group_admin;
    GRANT ALL ON TABLE clients.param_limits TO group_tools;
    GRANT ALL ON SEQUENCE clients.param_limits_pl_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.param_limits_pl_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.param_limits_pl_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.param_limits                        IS 'Table with setting of parameter limits for auto validation ';
    COMMENT ON COLUMN clients.param_limits.pl_id                  IS 'parameter limit id';
    COMMENT ON COLUMN clients.param_limits.param_id               IS 'parameter id';
    COMMENT ON COLUMN clients.param_limits.pl_jd_from             IS 'julian day, beginning of the interval';
    COMMENT ON COLUMN clients.param_limits.pl_jd_to               IS 'julian day, end of the interval';
    COMMENT ON COLUMN clients.param_limits.pl_suspect_min         IS 'min of the range for suspect values';
    COMMENT ON COLUMN clients.param_limits.pl_suspect_max         IS 'max of the range for suspect values';
    COMMENT ON COLUMN clients.param_limits.pl_error_min           IS 'min of the range for for automatic invalidation';
    COMMENT ON COLUMN clients.param_limits.pl_error_max           IS 'max of the range for for automatic invalidation';
    COMMENT ON COLUMN clients.param_limits.pl_suspect_gap         IS 'suspect gap from previous value';
    COMMENT ON COLUMN clients.param_limits.pl_error_gap           IS 'gap from previous value for automatic invalidation';
    COMMENT ON COLUMN clients.param_limits.pl_suspect_persistence IS 'suspect number of constant values';
    COMMENT ON COLUMN clients.param_limits.pl_error_persistence   IS 'number of constant values for automatic invalidation';
    COMMENT ON COLUMN clients.param_limits.network_types          IS 'networks where the rule is applicable';

    -- Tabella che contiene le informazioni relative agli allarmi di stazione
    -- DROP TABLE clients.stations_alarms IF EXISTS;
    CREATE TABLE clients.stations_alarms (
        sa_id       serial,
        station_id  integer NOT NULL,
        param_id    integer NOT NULL,
        stpr_id     integer,
        sa_fulldate timestamp NOT NULL,

        CONSTRAINT clients_stations_alarms_pkey PRIMARY KEY (sa_id),
        CONSTRAINT clients_stations_alarms_ukey UNIQUE NULLS NOT DISTINCT (station_id, param_id, stpr_id, sa_fulldate)
        -- CONSTRAINT clients_stations_alarms_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stations_alarms_fkey2 FOREIGN KEY (param_id)
        -- REFERENCES metadata.parameters (param_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stations_alarms_fkey3 FOREIGN KEY (stpr_id)
        -- REFERENCES metadata.stations_parameters (stpr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    clients.stations_alarms TO group_admin;
    GRANT ALL ON TABLE    clients.stations_alarms TO group_bobo;
    GRANT ALL ON TABLE    clients.stations_alarms TO group_tools;
    GRANT SELECT ON TABLE clients.stations_alarms TO group_readonly;
    GRANT ALL ON SEQUENCE clients.stations_alarms_sa_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.stations_alarms_sa_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.stations_alarms_sa_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.stations_alarms             IS 'Table containing stations alarms';
    COMMENT ON COLUMN clients.stations_alarms.sa_id       IS 'Station alarm ID (PK)';
    COMMENT ON COLUMN clients.stations_alarms.station_id  IS 'Station ID (FK)';
    COMMENT ON COLUMN clients.stations_alarms.param_id    IS 'Parameter ID (FK)';
    COMMENT ON COLUMN clients.stations_alarms.stpr_id     IS 'Station parameter ID Nullable (FK)';
    COMMENT ON COLUMN clients.stations_alarms.sa_fulldate IS 'Station alarm fulldate';

    -- Tabella che contiene le informazioni relative agli ultimi aggiornamenti dei dati delle stazioni
    -- DROP TABLE IF EXISTS clients.stations_last_update;
    CREATE TABLE clients.stations_last_update (
        station_id     integer,
        st_last_update timestamp NOT NULL,

        CONSTRAINT clients_stations_last_update_pk PRIMARY KEY (station_id)
        -- CONSTRAINT clients_stations_last_update_fk FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    clients.stations_last_update TO group_admin;
    GRANT ALL ON TABLE    clients.stations_last_update TO group_bobo;
    GRANT ALL ON TABLE    clients.stations_last_update TO group_tools;
    GRANT SELECT ON TABLE clients.stations_last_update TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.stations_last_update                IS 'Table containing fulldate of the last stations data update';
    COMMENT ON COLUMN clients.stations_last_update.station_id     IS 'Station id';
    COMMENT ON COLUMN clients.stations_last_update.st_last_update IS 'Station last update';

    -- Tabella di override che contiene le impostazioni dei limiti per ogni singola associazione stazione-parametro per l'auto-validazione
    -- DROP TABLE IF EXISTS clients.stations_param_limits;
    CREATE TABLE clients.stations_param_limits (
        spl_id                  serial  NOT NULL,
        stpr_id                 integer NOT NULL,
        spl_jd_from             smallint NOT NULL DEFAULT 1,
        spl_jd_to               smallint NOT NULL DEFAULT 366,
        spl_suspect_min         real,
        spl_suspect_max         real,
        spl_error_min           real,
        spl_error_max           real,
        spl_suspect_gap         real,
        spl_error_gap           real,
        spl_suspect_persistence integer,
        spl_error_persistence   integer,

        CONSTRAINT clients_stations_param_limits_pkey PRIMARY KEY (spl_id)
        -- CONSTRAINT clients_stations_param_limits_fkey FOREIGN KEY (stpr_id)
        --     REFERENCES metadata.stations_parameters(stpr_id)
        --     ON DELETE RESTRICT,
        -- CONSTRAINT clients_stations_param_limits_check EXCLUDE USING GIST (
        --     stpr_id WITH =,
        --     int4range(spl_jd_from, spl_jd_to, '[]') WITH &&
        -- )
    )
    WITHOUT OIDS;

    -- grants
    GRANT SELECT ON TABLE clients.stations_param_limits TO group_readonly;
    GRANT ALL ON TABLE    clients.stations_param_limits TO group_bobo;
    GRANT ALL ON TABLE    clients.stations_param_limits TO group_admin;
    GRANT ALL ON TABLE    clients.stations_param_limits TO group_tools;
    GRANT ALL ON SEQUENCE clients.stations_param_limits_spl_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.stations_param_limits_spl_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.stations_param_limits_spl_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.stations_param_limits                         IS 'Override Table with setting of parameter limits for single station-parameter, for auto validation';
    COMMENT ON COLUMN clients.stations_param_limits.spl_id                  IS 'Station parameter limit id';
    COMMENT ON COLUMN clients.stations_param_limits.stpr_id                 IS 'Station parameter id';
    COMMENT ON COLUMN clients.stations_param_limits.spl_jd_from             IS 'Julian day, beginning of the interval';
    COMMENT ON COLUMN clients.stations_param_limits.spl_jd_to               IS 'Julian day, end of the interval';
    COMMENT ON COLUMN clients.stations_param_limits.spl_suspect_min         IS 'Min of the range for suspect values';
    COMMENT ON COLUMN clients.stations_param_limits.spl_suspect_max         IS 'Max of the range for suspect values';
    COMMENT ON COLUMN clients.stations_param_limits.spl_error_min           IS 'Min of the range for for automatic invalidation';
    COMMENT ON COLUMN clients.stations_param_limits.spl_error_max           IS 'Max of the range for for automatic invalidation';
    COMMENT ON COLUMN clients.stations_param_limits.spl_suspect_gap         IS 'Suspect gap from previous value';
    COMMENT ON COLUMN clients.stations_param_limits.spl_error_gap           IS 'Gap from previous value for automatic invalidation';
    COMMENT ON COLUMN clients.stations_param_limits.spl_suspect_persistence IS 'Suspect number of constant values';
    COMMENT ON COLUMN clients.stations_param_limits.spl_error_persistence   IS 'Number of constant values for automatic invalidation';

    -- Tabella che contiene le informazioni relative ai messaggi dello strumento SWAM
    -- DROP TABLE IF EXISTS clients.swam_messages;
    CREATE TABLE clients.swam_messages (
        sm_id   integer NOT NULL,
        sm_code text NOT NULL,
        sm_desc text NOT NULL,

        CONSTRAINT clients_swam_messages_pk PRIMARY KEY (sm_id)
    ) WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    clients.swam_messages TO group_admin;
    GRANT ALL ON TABLE    clients.swam_messages TO group_bobo;
    GRANT ALL ON TABLE    clients.swam_messages TO group_tools;
    GRANT SELECT ON TABLE clients.swam_messages TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.swam_messages         IS 'Table containing SWAM possible messages';
    COMMENT ON COLUMN clients.swam_messages.sm_id   IS 'Serial ID';
    COMMENT ON COLUMN clients.swam_messages.sm_code IS 'Message CODE';
    COMMENT ON COLUMN clients.swam_messages.sm_desc IS 'Message description';

    -- Tabella che contiene le informazioni relative agli allarmi dello strumento SWAM
    -- DROP TABLE IF EXISTS clients.swam_warnings;
    CREATE TABLE clients.swam_warnings (
        sw_fulldate timestamp NOT NULL,
        station_id  integer NOT NULL,
        sw_id       integer NOT NULL,
        sw_bit_mask bit(32) NOT NULL,

        CONSTRAINT clients_swam_warnings_pk PRIMARY KEY (sw_fulldate, station_id, sw_id)
        -- CONSTRAINT clients_swam_warnings_fk1 FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    ) WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    clients.swam_warnings TO group_admin;
    GRANT ALL ON TABLE    clients.swam_warnings TO group_bobo;
    GRANT ALL ON TABLE    clients.swam_warnings TO group_tools;
    GRANT SELECT ON TABLE clients.swam_warnings TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.swam_warnings             IS 'Table containing stations instrumental warnings';
    COMMENT ON COLUMN clients.swam_warnings.sw_fulldate IS 'Warning fulldate';
    COMMENT ON COLUMN clients.swam_warnings.station_id  IS 'Station id';
    COMMENT ON COLUMN clients.swam_warnings.sw_id       IS 'Warning id';
    COMMENT ON COLUMN clients.swam_warnings.sw_bit_mask IS 'Warning bit mask';

    -- Tabella che contiene le informazioni relative alla diagnostica dello strumento TECORA
    -- DROP TABLE IF EXISTS clients.tecora_data;
    CREATE TABLE clients.tecora_data
    (
        id                    serial NOT NULL PRIMARY KEY,
        fulldate              timestamp NOT NULL,
        station_id            integer NOT NULL,
        code                  text,
        sample                text,
        sample_start          text,
        sample_stop           text,
        sample_str            text,
        sample_stp            text,
        prog_flow_qx          text,
        elapsed_time          text,
        flow_rate5            text,
        e_timeout_spec        text,
        average_flow_rate_qs  text,
        average_flow_rate_qa  text,
        deviation_flowrate_cv text,
        gas_meter_volume      text,
        standard_volume       text,
        actual_volume         text,
        aver_temp_gas_met     text,
        max_ambient_temp      text,
        min_ambient_temp      text,
        aver_ambient_temp     text,
        max_ambient_press     text,
        min_ambient_press     text,
        aver_ambient_press    text,
        max_diff_pressure     text,
        concentraion_coeff    text,
        estimed_mass_conc     text,
        temp_filter           text,
        max_diff              text,
        filter_temp_out_spec  text,
        supply_ir             text,

        CONSTRAINT clients_tecora_data_ukey UNIQUE (fulldate, station_id)
        -- CONSTRAINT clients_tecora_data_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.tecora_data TO group_admin;
    GRANT ALL ON TABLE    clients.tecora_data TO group_bobo;
    GRANT ALL ON TABLE    clients.tecora_data TO group_tools;
    GRANT SELECT ON TABLE clients.tecora_data TO group_readonly;
    GRANT ALL ON SEQUENCE clients.tecora_data_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.tecora_data_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.tecora_data_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.tecora_data                       IS 'Store skypost tecora raw data';
    COMMENT ON COLUMN clients.tecora_data.id                    IS 'The unique id';
    COMMENT ON COLUMN clients.tecora_data.fulldate              IS 'The record date';
    COMMENT ON COLUMN clients.tecora_data.station_id            IS 'The station st_id';
    COMMENT ON COLUMN clients.tecora_data.sample                IS 'n° Number of sample report';
    COMMENT ON COLUMN clients.tecora_data.sample_start          IS 'Sampling programmed Start';
    COMMENT ON COLUMN clients.tecora_data.sample_stop           IS 'Sampling programmed Stop';
    COMMENT ON COLUMN clients.tecora_data.sample_str            IS 'Effective sampling Start';
    COMMENT ON COLUMN clients.tecora_data.sample_stp            IS 'Effective sampling Stop';
    COMMENT ON COLUMN clients.tecora_data.prog_flow_qx          IS 'Setted sampling flow rate l/min';
    COMMENT ON COLUMN clients.tecora_data.elapsed_time          IS 'Effective sampling time hh/mm/ss';
    COMMENT ON COLUMN clients.tecora_data.flow_rate5            IS 'OET Flow rate deviation alarm ON o –';
    COMMENT ON COLUMN clients.tecora_data.e_timeout_spec        IS 'Sampling duration alarm PM10 >23 <25h ON o –';
    COMMENT ON COLUMN clients.tecora_data.average_flow_rate_qs  IS 'Average flow rate at standard condition';
    COMMENT ON COLUMN clients.tecora_data.average_flow_rate_qa  IS 'Average flow rate at actual condition';
    COMMENT ON COLUMN clients.tecora_data.deviation_flowrate_cv IS 'Flow deviation';
    COMMENT ON COLUMN clients.tecora_data.gas_meter_volume      IS 'Total Volume on dry gas meter';
    COMMENT ON COLUMN clients.tecora_data.standard_volume       IS 'Volume at standard condition';
    COMMENT ON COLUMN clients.tecora_data.actual_volume         IS 'Volume at actual condition';
    COMMENT ON COLUMN clients.tecora_data.aver_temp_gas_met     IS 'Average temperature at dry gas meter';
    COMMENT ON COLUMN clients.tecora_data.max_ambient_temp      IS 'Max. Ambient Temperature';
    COMMENT ON COLUMN clients.tecora_data.min_ambient_temp      IS 'Min. Ambient Temperature';
    COMMENT ON COLUMN clients.tecora_data.aver_ambient_temp     IS 'Average ambient temperature';
    COMMENT ON COLUMN clients.tecora_data.max_ambient_press     IS 'Max. atmospheric Pressure';
    COMMENT ON COLUMN clients.tecora_data.min_ambient_press     IS 'Min. atmospheric Pressure';
    COMMENT ON COLUMN clients.tecora_data.aver_ambient_press    IS 'Average. atmospheric Pressure';
    COMMENT ON COLUMN clients.tecora_data.max_diff_pressure     IS 'Pressure drop on filter between Pa and Pf';
    COMMENT ON COLUMN clients.tecora_data.concentraion_coeff    IS 'Concentration coefficient';
    COMMENT ON COLUMN clients.tecora_data.estimed_mass_conc     IS 'Theoretical mass concentration on filter';
    COMMENT ON COLUMN clients.tecora_data.temp_filter           IS 'Advise the max. temperature difference between ambient temperature and filter temperature during all pre-programmed sampling';
    COMMENT ON COLUMN clients.tecora_data.max_diff              IS 'Advise the max. temperature difference between ambient temperature and filter temperature during all pre-programmed sampling';
    COMMENT ON COLUMN clients.tecora_data.filter_temp_out_spec  IS 'Alarm filter temperature “Out of specification”, it is activated in case for more 30 min the differential temperature between filter and ambient is over 5°C';
    COMMENT ON COLUMN clients.tecora_data.supply_ir             IS 'Main supply interruption';

    -- Tabella che contiene le informazioni relative ai messaggi dello strumento TECORA
    -- DROP TABLE IF EXISTS clients.tecora_messages;
    CREATE TABLE clients.tecora_messages
    (
        id      smallint PRIMARY KEY,
        message text
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.tecora_messages TO group_admin;
    GRANT ALL ON TABLE    clients.tecora_messages TO group_bobo;
    GRANT ALL ON TABLE    clients.tecora_messages TO group_tools;
    GRANT SELECT ON TABLE clients.tecora_messages TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.tecora_messages         IS 'Store skypost tecora default messages';
    COMMENT ON COLUMN clients.tecora_messages.id      IS 'Progressive id';
    COMMENT ON COLUMN clients.tecora_messages.message IS 'Error message';

    -- Tabella che contiene le informazioni relative agli allarmi dello strumento TECORA
    -- DROP TABLE IF EXISTS clients.tecora_warnings;
    CREATE TABLE clients.tecora_warnings
    (
        id         serial NOT NULL PRIMARY KEY,
        fulldate   timestamp NOT NULL,
        station_id integer NOT NULL,
        warning_id smallint,

        CONSTRAINT clients_tecora_warnings_ukey UNIQUE (fulldate, station_id)
        -- CONSTRAINT clients_tecora_warnings_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.tecora_warnings TO group_admin;
    GRANT ALL ON TABLE    clients.tecora_warnings TO group_bobo;
    GRANT ALL ON TABLE    clients.tecora_warnings TO group_tools;
    GRANT SELECT ON TABLE clients.tecora_warnings TO group_readonly;
    GRANT ALL ON SEQUENCE clients.tecora_warnings_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.tecora_warnings_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.tecora_warnings_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.tecora_warnings            IS 'Store skypost tecora alarms';
    COMMENT ON COLUMN clients.tecora_warnings.id         IS 'The unique id';
    COMMENT ON COLUMN clients.tecora_warnings.fulldate   IS 'The record date';
    COMMENT ON COLUMN clients.tecora_warnings.station_id IS 'The station id';
    COMMENT ON COLUMN clients.tecora_warnings.warning_id IS 'The warning id';

    -- Tabella che contiene le informazioni relative ai messaggi degli strumenti TELEDYNE API
    -- DROP TABLE IF EXISTS clients.teledyne_messages;
    CREATE TABLE clients.teledyne_messages
    (
        id      bigint PRIMARY KEY,
        message text
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.teledyne_messages TO group_admin;
    GRANT ALL ON TABLE    clients.teledyne_messages TO group_bobo;
    GRANT ALL ON TABLE    clients.teledyne_messages TO group_tools;
    GRANT SELECT ON TABLE clients.teledyne_messages TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.teledyne_messages         IS 'Store Teledyne API default messages';
    COMMENT ON COLUMN clients.teledyne_messages.id      IS 'Progressive id';
    COMMENT ON COLUMN clients.teledyne_messages.message IS 'Error message';

    -- Tabella che contiene le informazioni relative agli allarmi degli strumenti TELEDYNE API
    -- DROP TABLE IF EXISTS clients.teledyne_warnings;
    CREATE TABLE clients.teledyne_warnings
    (
        id            serial NOT NULL PRIMARY KEY,
        fulldate      timestamp NOT NULL,
        station_id    integer NOT NULL,
        stpr_group_id integer NOT NULL,
        warning_id    bigint,

        CONSTRAINT clients_teledyne_warnings_ukey UNIQUE (fulldate, station_id, stpr_group_id)
        -- CONSTRAINT clients_teledyne_warnings_fkey FOREIGN KEY (station_id)
        -- REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.teledyne_warnings TO group_admin;
    GRANT ALL ON TABLE    clients.teledyne_warnings TO group_bobo;
    GRANT ALL ON TABLE    clients.teledyne_warnings TO group_tools;
    GRANT SELECT ON TABLE clients.teledyne_warnings TO group_readonly;
    GRANT ALL ON SEQUENCE clients.teledyne_warnings_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients.teledyne_warnings_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients.teledyne_warnings_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients.teledyne_warnings               IS 'Store Teledyne API alarms';
    COMMENT ON COLUMN clients.teledyne_warnings.id            IS 'The unique id';
    COMMENT ON COLUMN clients.teledyne_warnings.fulldate      IS 'The record date';
    COMMENT ON COLUMN clients.teledyne_warnings.station_id    IS 'The station id';
    COMMENT ON COLUMN clients.teledyne_warnings.stpr_group_id IS 'STPR group id';
    COMMENT ON COLUMN clients.teledyne_warnings.warning_id    IS 'The warning id';


    -- Tabella che contiene i dati necessari alla funzione "clients.f_save_changes"
    -- DROP TABLE IF EXISTS clients.trigger_history;
    CREATE UNLOGGED TABLE clients.trigger_history
    (
        us_id   integer NOT NULL,
        ann_id  integer DEFAULT NULL,
        options jsonb DEFAULT '{}'::jsonb

        -- CONSTRAINT clients_trigger_history_fk1 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_trigger_history_fk2 FOREIGN KEY (ann_id)
        --     REFERENCES bobo_tools.annotations (ann_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients.trigger_history TO group_admin;
    GRANT ALL ON TABLE    clients.trigger_history TO group_bobo;
    GRANT ALL ON TABLE    clients.trigger_history TO group_tools;
    GRANT SELECT ON TABLE clients.trigger_history TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients.trigger_history           IS 'Table containing all data for trigger function f_save_changes';
    COMMENT ON COLUMN clients.trigger_history.us_id     IS 'User ID (FK)';
    COMMENT ON COLUMN clients.trigger_history.ann_id    IS 'Annotation ID (FK)';
    COMMENT ON COLUMN clients.trigger_history.options   IS 'Portal options';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- Vista di utility
    -- DROP VIEW IF EXISTS clients.limits_dlgs155_2010;
    CREATE OR REPLACE VIEW clients.limits_dlgs155_2010 AS
    SELECT
        NULL::timestamp AS measure_date_time,
        0::integer      AS measure_id,
        0::numeric      AS measure_value,
        100::smallint   AS measure_validity_perc,
        NULL::numeric   AS measure_min,
        NULL::numeric   AS measure_max,
        NULL::numeric   AS measure_standard_dev,
        0::smallint     AS measure_code,
        0::integer      AS auto_validity_code,
        0::integer      AS post_validity_code,
        0::smallint     AS final_validity_code,
        NULL::timestamp AS db_insert_time,
        NULL::timestamp AS db_update_time;

    -- grants
    GRANT ALL ON TABLE    clients.limits_dlgs155_2010 TO group_admin;
    GRANT ALL ON TABLE    clients.limits_dlgs155_2010 TO group_bobo;
    GRANT ALL ON TABLE    clients.limits_dlgs155_2010 TO group_tools;
    GRANT SELECT ON TABLE clients.limits_dlgs155_2010 TO group_readonly;

    -- comment
    COMMENT ON VIEW clients.limits_dlgs155_2010 IS 'Utility view';

    -- Vista relativa ai risultati delle auto-validazioni
    -- DROP VIEW IF EXISTS clients.view_auto_validation_results;
    CREATE OR REPLACE VIEW clients.view_auto_validation_results AS
    SELECT
        s.station_name                                                                                                                                                          AS station_name,
        p.param_name                                                                                                                                                            AS parameter_name,
        vr.measure_date_time                                                                                                                                                    AS measure_date_time,
        CASE WHEN spl.spl_suspect_min         IS NOT NULL THEN 'STS' ELSE 'DEF' END ||' '||lpad(coalesce(spl.spl_suspect_min        , pl.pl_suspect_min        )::text, 8, ' ') AS suspect_min,
        CASE WHEN spl.spl_suspect_max         IS NOT NULL THEN 'STS' ELSE 'DEF' END ||' '||lpad(coalesce(spl.spl_suspect_max        , pl.pl_suspect_max        )::text, 8, ' ') AS suspect_max,
        CASE WHEN spl.spl_error_min           IS NOT NULL THEN 'STS' ELSE 'DEF' END ||' '||lpad(coalesce(spl.spl_error_min          , pl.pl_error_min          )::text, 8, ' ') AS error_min,
        CASE WHEN spl.spl_error_max           IS NOT NULL THEN 'STS' ELSE 'DEF' END ||' '||lpad(coalesce(spl.spl_error_max          , pl.pl_error_max          )::text, 8, ' ') AS error_max,
        CASE WHEN spl.spl_suspect_gap         IS NOT NULL THEN 'STS' ELSE 'DEF' END ||' '||lpad(coalesce(spl.spl_suspect_gap        , pl.pl_suspect_gap        )::text, 8, ' ') AS suspect_gap,
        CASE WHEN spl.spl_error_gap           IS NOT NULL THEN 'STS' ELSE 'DEF' END ||' '||lpad(coalesce(spl.spl_error_gap          , pl.pl_error_gap          )::text, 8, ' ') AS error_gap,
        CASE WHEN spl.spl_suspect_persistence IS NOT NULL THEN 'STS' ELSE 'DEF' END ||' '||lpad(coalesce(spl.spl_suspect_persistence, pl.pl_suspect_persistence)::text, 8, ' ') AS suspect_persistence,
        CASE WHEN spl.spl_error_persistence   IS NOT NULL THEN 'STS' ELSE 'DEF' END ||' '||lpad(coalesce(spl.spl_error_persistence  , pl.pl_error_persistence  )::text, 8, ' ') AS error_persistence,
        'station_id: '||s.station_id||', param_id: '||p.param_id||', table_id: '||sp.stpr_table_id                                                                              AS info,
        'SELECT'||E'\n\t'
        ||'measure_date_time, measure_id, measure_value, measure_code, auto_validity_code, post_validity_code'||E'\n'
        ||'FROM'||E'\n\t'
        ||s.station_schema||'.data10_'||s.station_table||E'\n'
        ||'WHERE'||E'\n\t'
        ||'measure_date_time BETWEEN '||quote_literal(vr.measure_date_time)||'::timestamp - INTERVAL ''1 hours'' AND '
        ||quote_literal(vr.measure_date_time)||'::timestamp + INTERVAL ''1 hours'' AND measure_id = '||sp.stpr_table_id||E'\n'
        ||'ORDER BY 1;'                                                                                                                                                         AS query_sql
    FROM
        clients.auto_validation_results vr
        LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
        LEFT JOIN metadata.stations s USING (station_id)
        LEFT JOIN metadata.parameters p USING (param_id)
        LEFT JOIN clients.param_limits pl ON pl.param_id = sp.param_id AND to_char(current_timestamp, 'DDD')::smallint BETWEEN pl.pl_jd_from AND pl.pl_jd_to
        LEFT JOIN clients.stations_param_limits spl ON spl.stpr_id = vr.stpr_id AND to_char(current_timestamp, 'DDD')::smallint BETWEEN spl.spl_jd_from AND spl.spl_jd_to
    ORDER BY
        avr_id;

    -- grants
    GRANT ALL ON TABLE    clients.view_auto_validation_results TO group_admin;
    GRANT ALL ON TABLE    clients.view_auto_validation_results TO group_bobo;
    GRANT ALL ON TABLE    clients.view_auto_validation_results TO group_tools;
    GRANT SELECT ON TABLE clients.view_auto_validation_results TO group_readonly;

    -- comments
    COMMENT ON VIEW clients.view_auto_validation_results IS 'Validation results view';

    -- Vista che raccoglie le informazioni relative ai parametri di cui si effettua la taratura
    -- DROP VIEW IF EXISTS clients.view_calibration_parameters;
    CREATE OR REPLACE VIEW clients.view_calibration_parameters AS
    SELECT
        param_id,
        param_name
    FROM
        ( VALUES
            (29, 'Parametro 1'),
            (30, 'Parametro 2'),
            (31, 'Parametro 3'),
            (32, 'Parametro 4'),
            (33, 'Parametro 5'),
            (34, 'Parametro 6'),
            (38, 'Parametro 7')
        ) AS t (param_id, param_name)
    ORDER BY param_name;

    -- grants
    GRANT ALL ON TABLE    clients.view_calibration_parameters TO group_admin;
    GRANT ALL ON TABLE    clients.view_calibration_parameters TO group_bobo;
    GRANT ALL ON TABLE    clients.view_calibration_parameters TO group_tools;
    GRANT SELECT ON TABLE clients.view_calibration_parameters TO group_readonly;

    -- comments
    COMMENT ON VIEW clients.view_calibration_parameters IS 'Calibrations parameters';

    -- Vista che raccoglie le informazioni relative ai dati di taratura
    -- DROP VIEW IF EXISTS clients.view_calibrations_data;
    CREATE OR REPLACE VIEW clients.view_calibrations_data AS
    SELECT
        cd.calibration_id,
        cd.calibration_date_time,
        cd.station_id,
        st.station_name,
        st.station_schema,
        st.station_table,
        st.station_prefix,
        st.station_schema ||'.'::text||COALESCE(st.station_prefix, ''::text)||st.station_table AS station_fulltable,
        cd.measure_id,
        pa.param_id,
        pa.param_name,
        pa.param_unit,
        pa.param_conv,
        pa.param_unit_conv,
        pa.param_decimals,
        cd.calibration_type,
        cd.calibration_step,
        cd.measure_value
    FROM
        clients.calibrations_data cd
        LEFT JOIN metadata.stations st USING (station_id)
        LEFT JOIN metadata.stations_parameters sp ON (cd.station_id = sp.station_id AND cd.measure_id = sp.stpr_table_id)
        LEFT JOIN metadata.parameters pa USING (param_id)
    ORDER BY cd.calibration_id, cd.calibration_date_time;

    -- grants
    GRANT ALL ON TABLE    clients.view_calibrations_data TO group_admin;
    GRANT ALL ON TABLE    clients.view_calibrations_data TO group_bobo;
    GRANT ALL ON TABLE    clients.view_calibrations_data TO group_tools;
    GRANT SELECT ON TABLE clients.view_calibrations_data TO group_readonly;

    -- comments
    COMMENT ON VIEW clients.view_calibrations_data IS 'Calibrations data view';

    -- Vista che raccoglie le informazioni relative agli allarmi delle varie stazioni
    -- DROP VIEW IF EXISTS clients.view_stations_last_update;
    CREATE OR REPLACE VIEW clients.view_stations_alarms AS
    SELECT
        sa.sa_id                                      AS sa_id,
        sa.stpr_id                                    AS stpr_id,
        sa.station_id                                 AS station_id,
        st.station_name                               AS station_name,
        sa.param_id                                   AS param_id,
        a.alarm_label                                 AS alarm_label,
        CONCAT_WS(' - ', a.alarm_label, sp.stpr_note) AS alarm_label_formatted,
        a.alarm_color                                 AS alarm_color,
        a.alarm_icon                                  AS alarm_icon,
        sa.sa_fulldate                                AS station_alarm_fulldate,
        to_char(sa.sa_fulldate, 'DD.MM h HH24')       AS station_alarm_fulldate_formatted,
        CASE
            WHEN sa.sa_fulldate = DATE_TRUNC('hour', CURRENT_TIMESTAMP) THEN FALSE
            ELSE (
                SELECT COUNT(*)
                FROM clients.stations_alarms t
                WHERE t.station_id = sa.station_id
                AND t.param_id = sa.param_id
                AND DATE_TRUNC('hour', t.sa_fulldate) = DATE_TRUNC('hour', sa.sa_fulldate) + interval '1 hour'
            ) = 0
        END                                           AS station_alarm_off
    FROM
        clients.stations_alarms sa
        LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
        LEFT JOIN clients.alarms a ON sa.param_id = a.param_id
        LEFT JOIN metadata.stations st ON sa.station_id = st.station_id;

    -- grants
    GRANT ALL ON TABLE    clients.view_stations_alarms TO group_admin;
    GRANT ALL ON TABLE    clients.view_stations_alarms TO group_bobo;
    GRANT ALL ON TABLE    clients.view_stations_alarms TO group_tools;
    GRANT SELECT ON TABLE clients.view_stations_alarms TO group_readonly;

    -- comments
    COMMENT ON VIEW clients.view_stations_alarms IS 'The view contains all the station alarms';

    -- Vista che raccoglie le informazioni relative all'ultimo stato delle stazioni (eventuale ritardo)
    -- DROP VIEW IF EXISTS clients.view_stations_last_update;
    CREATE OR REPLACE VIEW clients.view_stations_last_update AS
    SELECT
        slu.station_id                                       AS station_id,
        st.station_name                                      AS station_name,
        snt.st_network_name                                  AS network_name,
        COALESCE(p.province_code, '--')                      AS province_code,
        slu.st_last_update                                   AS station_last_update,
        to_char(slu.st_last_update, 'DD.MM.YYYY h HH24')     AS station_last_update_formatted,
        ((EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) -
        EXTRACT(EPOCH FROM slu.st_last_update))/60)::integer AS station_minutes_gap,
        CASE
            WHEN (EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) - EXTRACT(EPOCH FROM slu.st_last_update))/60 > si.st_info_accepted_delay * 2 THEN 'late'
            WHEN (EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) - EXTRACT(EPOCH FROM slu.st_last_update))/60 > si.st_info_accepted_delay     THEN 'almost-late'
            ELSE ''
        END                                                  AS station_last_update_class,
        st_info_accepted_delay                               AS station_accepted_delay
    FROM
        clients.stations_last_update slu
        LEFT JOIN metadata.stations st USING (station_id)
        LEFT JOIN metadata.stations_info si USING (station_id)
        LEFT JOIN metadata.stations_network_type snt ON snt.st_network_id = si.st_info_network_type_fk
        LEFT JOIN metadata.stations_municipality sm USING (station_id)
        LEFT JOIN main.municipalities m USING (mu_id)
        LEFT JOIN main.province_municipalities pm USING (mu_id)
        LEFT JOIN main.provinces p USING (province_id);

    -- grants
    GRANT ALL ON TABLE    clients.view_stations_last_update TO group_admin;
    GRANT ALL ON TABLE    clients.view_stations_last_update TO group_bobo;
    GRANT ALL ON TABLE    clients.view_stations_last_update TO group_tools;
    GRANT SELECT ON TABLE clients.view_stations_last_update TO group_readonly;

    -- comments
    COMMENT ON VIEW clients.view_stations_alarms IS 'The view contains all station last state';

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Funzione di audit per inviare le stazioni in ritardo attraverso il canale "Telegram"
    -- DROP FUNCTION IF EXISTS clients.f_audit_stations_late();
    CREATE OR REPLACE FUNCTION clients.f_audit_stations_late()
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        r record; -- record
        m text; -- message
        q text; -- query
        i integer;
        c text; -- chat id
    BEGIN
        /* Run
         *  SELECT clients.f_audit_stations_late();
         */

        /* initialize variables */
        c = '-155562418';
        m = '';

        /* loop through all late stations */
        FOR r IN (
            WITH t AS(
                SELECT
                    slu.station_id,
                    slu.station_name,
                    slu.network_name,
                    slu.province_code,
                    slu.station_last_update,
                    slu.station_last_update_formatted,
                    slu.station_minutes_gap,
                    slu.station_last_update_class,
                    CASE
                        WHEN station_last_update_class LIKE 'late' THEN 'Ritardo'
                        WHEN station_last_update_class LIKE 'almost-late' THEN 'Lieve ritardo' -- station_minutes_gap||' min rit.'
                        ELSE 'Ok'
                    END AS station_last_update_text
                FROM
                    clients.view_stations_last_update slu
                WHERE
                    station_minutes_gap < (60*24*7 * 100000)
                ORDER BY
                    (station_minutes_gap/station_accepted_delay) DESC,
                    station_minutes_gap DESC
            )
            SELECT
                *,
                CASE
                    WHEN ( SELECT COUNT(*) FROM (SELECT DISTINCT(network_name) FROM t ) AS t2) > 1 THEN TRUE
                    ELSE FALSE
                END AS network_visible
            FROM
                t
            WHERE
                station_last_update_text = 'Ritardo'
        ) LOOP

            /* notice */
            --RAISE NOTICE 'station: %', r.station_name;

            /* message */
            m = m || r.network_name ||E', '
            || r.station_name ||E'\n';

        END LOOP;

        /* last check */
        IF m <> '' THEN
            --RAISE NOTICE 'Stazioni in ritardo: %', m;

            /* check if last message sent was equal (message) to avoid sending twice */
            q= 'SELECT count(*) FROM gateways.telegrams WHERE app = %L AND chat = %L AND message = %L';
            EXECUTE format(q, 'audit.stations.late', c, m) INTO i;
            --RAISE NOTICE 'i %', i;
            IF i > 0 THEN
                RAISE NOTICE 'Message already sent';
                RETURN true;
            END IF;

            /* query */
            q= 'INSERT INTO gateways.telegrams (app, chat, telegram_type, parse_mode, message) VALUES ('||E'\n'
                ||'%L,'||E'\n' -- app
                ||'%L,'||E'\n' -- chat
                ||'%L,'||E'\n' -- telegram_type
                ||'%L,'||E'\n' -- parse_mode
                ||'%L '||E'\n' -- message
                ||')';

            --RAISE NOTICE 'Query: %', q;
            EXECUTE format(q, 'audit.stations.late', c, 'Message', 'Markdown', m);

            /* check for arpae, in case send mail as well */
            IF m ~* 'emilia' THEN
                /* query */
                q= 'INSERT INTO gateways.mails (app, recipients, subject, body) VALUES ('||E'\n'
                    ||'%L,'||E'\n' -- app
                    ||'%L,'||E'\n' -- recipients
                    ||'%L,'||E'\n' -- subject
                    ||'%L '||E'\n' -- message
                    ||')';

                --RAISE NOTICE 'Query: %', q;
                EXECUTE format(q, 'audit.opas.stations.late', 'utente.opas@opas.it', 'Opas Ispra', m);
            END IF;

        ELSE
            RAISE NOTICE 'Tutto ok!';
        END IF;

        /* return */
        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_audit_stations_late(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    ALTER FUNCTION            clients.f_audit_stations_late() OWNER TO postgres;
    GRANT EXECUTE ON FUNCTION clients.f_audit_stations_late() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_audit_stations_late() TO group_tools;
    GRANT EXECUTE ON FUNCTION clients.f_audit_stations_late() TO postgres;

    -- comments
    COMMENT ON FUNCTION clients.f_audit_stations_late()
        IS 'Audit function to send telegram with late stations';

    -- Funzione di autovalidazione e aggiornamento del "post_validity_code"
    -- DROP FUNCTION clients.f_auto_to_post_validity_code();
    CREATE OR REPLACE FUNCTION clients.f_auto_to_post_validity_code ()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$

    DECLARE
        -- variabili sql
        table_name  text;
        stid        integer;
        stprid      integer;
        prname      text;
        stname      text;
        dyn_sql     text;
        dyn_sql_rec record;
        inner_rec   record;

        -- variabili interne
        prev_value          real;
        perst_value         integer;
        jd_from             integer;
        jd_to               integer;
        suspect_min         real;
        suspect_max         real;
        error_min           real;
        error_max           real;
        suspect_gap         real;
        error_gap           real;
        suspect_persistence integer;
        error_persistence   integer;
        limit_persistence   integer;

        -- codici di autovalidazione:
        auto_val_code           integer := 0;
        post_val_code           integer := 0;
        -- NOTA: se la funzione gira anche before update: post_val_code integer := NEW.post_validity_code;
        -- (altrimenti non funziona la validazione manuale)

        cod_suspect_range       integer := 16;
        cod_error_range         integer := 65536;
        cod_suspect_gap         integer := 2;
        cod_error_gap           integer := 8192;
        cod_suspect_persistence integer := 8;
        cod_error_persistence   integer := 32768;

        -- massimo ritardo, in minuti, del dato precedente, x il calcolo della variazione
        variation_gap           integer := 120;
    BEGIN
        -- return value when reprocessing
        -- RETURN NEW;

        -- station measure_id passed by caller
        stid := TG_ARGV[0];

        -- get the table name */
        table_name := TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME;

        -- get current code value
        post_val_code := NEW.post_validity_code;

        -- log
        RAISE NOTICE 'stid : % table_name: %', stid, table_name;

        -- query to search for parameters withs limits sets */ -- in clients.stations_param_limits o clients.param_limits
        dyn_sql := 'WITH t1 AS (
          SELECT
              coalesce(
                  (select spl_suspect_min
                       from clients.stations_param_limits
                       where
                            stpr_id = (select stpr_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN spl_jd_from AND spl_jd_to
                      ),
                  (select pl_suspect_min
                        from clients.param_limits
                        WHERE
                            exists ( select 1 from metadata.stations_info where station_id = '|| stid || ' and st_info_network_type_fk = ANY (network_types) )
                            and param_id = (select param_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN pl_jd_from AND pl_jd_to
                      )
                  )
              AS suspect_min
        ),
        t2 AS (
          SELECT
              coalesce(
                  (select spl_suspect_max
                       from clients.stations_param_limits
                       where
                            stpr_id = (select stpr_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN spl_jd_from AND spl_jd_to
                      ),
                  (select pl_suspect_max
                        from clients.param_limits
                        WHERE
                            exists ( select 1 from metadata.stations_info where station_id = '|| stid || ' and st_info_network_type_fk = ANY (network_types) )
                            and param_id = (select param_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN pl_jd_from AND pl_jd_to
                      )
                  )
              AS suspect_max
        ),
        t3 AS (
          SELECT
              coalesce(
                  (select spl_error_min
                       from clients.stations_param_limits
                       where
                            stpr_id = (select stpr_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN spl_jd_from AND spl_jd_to
                      ),
                   (select pl_error_min
                        from clients.param_limits
                        WHERE
                            exists ( select 1 from metadata.stations_info where station_id = '|| stid || ' and st_info_network_type_fk = ANY (network_types) )
                            and param_id = (select param_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN pl_jd_from AND pl_jd_to
                      )
                  )
              AS error_min
        ),

        t4 AS (
          SELECT
              coalesce(
                  (select spl_error_max
                       from clients.stations_param_limits
                       where
                            stpr_id = (select stpr_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN spl_jd_from AND spl_jd_to
                      ),
                  (select pl_error_max
                        from clients.param_limits
                        WHERE
                            exists ( select 1 from metadata.stations_info where station_id = '|| stid || ' and st_info_network_type_fk = ANY (network_types) )
                            and param_id = (select param_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN pl_jd_from AND pl_jd_to
                      )
                  )
              AS error_max
        ),
        t5 AS (
          SELECT
              coalesce(
                  (select spl_suspect_gap
                       from clients.stations_param_limits
                       where
                            stpr_id = (select stpr_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN spl_jd_from AND spl_jd_to
                      ),
                   (select pl_suspect_gap
                        from clients.param_limits
                        WHERE
                            exists ( select 1 from metadata.stations_info where station_id = '|| stid || ' and st_info_network_type_fk = ANY (network_types) )
                            and param_id = (select param_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN pl_jd_from AND pl_jd_to
                      )
                  )
              AS suspect_gap
        ),
        t6 AS (
          SELECT
              coalesce(
                  (select spl_error_gap
                       from clients.stations_param_limits
                       where
                            stpr_id = (select stpr_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN spl_jd_from AND spl_jd_to
                      ),
                   (select pl_error_gap
                        from clients.param_limits
                        WHERE
                            exists ( select 1 from metadata.stations_info where station_id = '|| stid || ' and st_info_network_type_fk = ANY (network_types) )
                            and param_id = (select param_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN pl_jd_from AND pl_jd_to
                      )
                  )
              AS error_gap
        ),
        t7 AS (
          SELECT
              coalesce(
                  (select spl_suspect_persistence
                       from clients.stations_param_limits
                       where
                            stpr_id = (select stpr_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN spl_jd_from AND spl_jd_to
                      ),
                   (select pl_suspect_persistence
                        from clients.param_limits
                         WHERE
                            exists ( select 1 from metadata.stations_info where station_id = '|| stid || ' and st_info_network_type_fk = ANY (network_types) )
                            and param_id = (select param_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN pl_jd_from AND pl_jd_to
                      )
                  )
              AS suspect_persistence
        ),
        t8 AS (
          SELECT
              coalesce(
                  (select spl_error_persistence
                       from clients.stations_param_limits
                       where
                            stpr_id = (select stpr_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN spl_jd_from AND spl_jd_to
                      ),
                   (select pl_error_persistence
                        from clients.param_limits
                         WHERE
                            exists ( select 1 from metadata.stations_info where station_id = '|| stid || ' and st_info_network_type_fk = ANY (network_types) )
                            and param_id = (select param_id from metadata.stations_parameters where station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||')
                            and (to_char(current_timestamp, ''DDD''))::smallint BETWEEN pl_jd_from AND pl_jd_to
                      )
                  )
              AS error_persistence
        )
        SELECT
            stpr_id,
            suspect_min, suspect_max, error_min, error_max, suspect_gap, error_gap, suspect_persistence,error_persistence
        FROM metadata.stations_parameters,
            t1, t2, t3, t4, t5, t6, t7, t8
        WHERE station_id = '|| stid || ' and stpr_table_id = '|| NEW.measure_id ||';';

        --
        --select * from clients.stations_param_limits;
        --select * from clients.param_limits;

        -- RAISE NOTICE 'dyn_sql : % ', dyn_sql;

        -- parameter properties
        FOR dyn_sql_rec IN EXECUTE dyn_sql LOOP

            /* get the limits values */
            stprid              := dyn_sql_rec.stpr_id;
            suspect_min         := dyn_sql_rec.suspect_min;
            suspect_max         := dyn_sql_rec.suspect_max;
            error_min           := dyn_sql_rec.error_min;
            error_max           := dyn_sql_rec.error_max;
            suspect_gap         := dyn_sql_rec.suspect_gap;
            error_gap           := dyn_sql_rec.error_gap;
            suspect_persistence := dyn_sql_rec.suspect_persistence;
            error_persistence   := dyn_sql_rec.error_persistence  ;
            -- RAISE NOTICE 'stprid : % suspect_min : % suspect_max : % error_min: % error_max: % suspect_gap: % error_gap: % suspect_persistence: % error_persistence: %', stprid, suspect_min, suspect_max, error_min, error_max, suspect_gap, error_gap, suspect_persistence, error_persistence;

            -- ~~~~ range ~~~~
            -- checks min & max range
            IF NEW.measure_value < error_min THEN
                RAISE NOTICE 'error_min';
                auto_val_code := auto_val_code | cod_error_range; -- errato per range
                post_val_code := post_val_code ||| -2;
            ELSEIF NEW.measure_value < suspect_min THEN
                RAISE NOTICE 'suspect_min';
                auto_val_code := auto_val_code | cod_suspect_range; -- sospetto per range
                post_val_code := post_val_code ||| -1;
            END IF;
            IF NEW.measure_value > error_max THEN
                RAISE NOTICE 'error_max';
                auto_val_code := auto_val_code | cod_error_range; -- errato per range
                post_val_code := post_val_code ||| -2;
            ELSEIF NEW.measure_value > suspect_max THEN
                RAISE NOTICE 'suspect_max';
                auto_val_code := auto_val_code | cod_suspect_range; -- sospetto per range
                post_val_code := post_val_code ||| -1;
            END IF;

            -- ~~~~ consecutive ~~~~
            -- checks consucutive values
            perst_value := 1;
            limit_persistence  := COALESCE(error_persistence, suspect_persistence);

            IF limit_persistence > 0 THEN
                dyn_sql := 'SELECT measure_value '|| E'\n'
                     ||'FROM ' || table_name || E'\n'
                     ||'WHERE measure_date_time < ''' || NEW.measure_date_time || ''' AND measure_id = '
                     || NEW.measure_id || E'\n'
                     ||'ORDER BY measure_date_time DESC LIMIT '|| limit_persistence ||';';

                RAISE NOTICE 'query : %', dyn_sql;

                FOR inner_rec IN EXECUTE dyn_sql LOOP
                    IF inner_rec.measure_value = NEW.measure_value THEN
                        perst_value := perst_value + 1;
                        -- RAISE NOTICE 'perst_value : %', perst_value;
                    ELSE
                        exit;
                    END IF;
                END LOOP; /* limits loaded */
                IF perst_value >= error_persistence THEN /* count check */
                    -- RAISE NOTICE 'errato per persistenza';
                    auto_val_code := auto_val_code | cod_error_persistence; -- errato per persistenza
                    post_val_code := post_val_code ||| -2;
                ELSEIF  perst_value >= suspect_persistence THEN /* count check */
                    auto_val_code := auto_val_code | cod_suspect_persistence; -- sospetto per persistenza
                    post_val_code := post_val_code ||| -1;
                END IF;
            END IF;

            -- ~~~~ variation ~~~~
            -- checks variation: per la variazione non considera il dato precedente se sospetto o errato (da capire quanto ha senso andare indietro per valutare la variazione)
            IF COALESCE(error_gap, suspect_gap) <> 0 THEN
                dyn_sql := 'SELECT measure_value '|| E'\n'
                     ||'FROM ' || table_name || E'\n'
                     ||'WHERE measure_date_time < ''' || NEW.measure_date_time || E'\n'
                     || ''' AND measure_date_time >= ''' || NEW.measure_date_time || '''::timestamp - interval '''||variation_gap||' minutes'' AND measure_id = '|| NEW.measure_id || E'\n'
                     || ' AND post_validity_code >= 0'|| E'\n'
                     ||'ORDER BY measure_date_time DESC LIMIT 1';
                RAISE NOTICE 'query : %', dyn_sql;
                EXECUTE dyn_sql;
                FOR inner_rec IN EXECUTE dyn_sql LOOP
                    prev_value := inner_rec.measure_value;
                    -- check
                    IF abs(NEW.measure_value - prev_value) >= error_gap THEN
                        auto_val_code := auto_val_code | cod_error_gap; -- errato per variazione
                        post_val_code := post_val_code ||| -2;
                    ELSEIF abs(NEW.measure_value - prev_value) >= suspect_gap THEN
                        auto_val_code := auto_val_code | cod_suspect_gap; -- sospetto per variazione
                        post_val_code := post_val_code ||| -1;
                    END IF;
                 END LOOP; -- limits loaded
            END IF;

            -- INSERT:
            -- inserisce una riga in auto_validation_results se il codice di validazione è diverso da zero
            -- aggiorna i codici  auto_validity_code e post_validity_code
            RAISE NOTICE 'auto_val_code : % post_val_code: %', auto_val_code, post_val_code;

            IF auto_val_code <> 0 THEN
                RAISE NOTICE 'insert auto_val_code e post_val_code';
                NEW.auto_validity_code := auto_val_code;
                NEW.post_validity_code := post_val_code;
                INSERT INTO clients.auto_validation_results VALUES(default,stprid,NEW.measure_date_time,default);
            END IF;

        END LOOP; -- there are limits

        -- Final value
        RETURN NEW;

        -- errors check
        EXCEPTION
            -- still errors */
            WHEN OTHERS THEN RAISE NOTICE 'ERROR in clients.f_auto_to_post_validity_code() ';
            /* Final value */
            RETURN NEW;
    END;

    $BODY$;

    -- grants
    ALTER FUNCTION            clients.f_auto_to_post_validity_code() OWNER TO postgres;
    GRANT EXECUTE ON FUNCTION clients.f_auto_to_post_validity_code() TO postgres;
    GRANT EXECUTE ON FUNCTION clients.f_auto_to_post_validity_code() TO PUBLIC;
    GRANT EXECUTE ON FUNCTION clients.f_auto_to_post_validity_code() TO group_tools;

    -- comments
    COMMENT ON FUNCTION clients.f_auto_to_post_validity_code() IS 'Auto validation function and update of post validity code';

    -- Funzione di calcolo della media mobile dinamica
    -- DROP FUNCTION IF EXISTS clients.f_calc_dynamic_moving_mean(bigint, timestamp without time zone, timestamp without time zone, text, integer);
    CREATE OR REPLACE FUNCTION clients.f_calc_dynamic_moving_mean(
        stprid bigint,
        date_from timestamp without time zone,
        date_to timestamp without time zone,
        validity text DEFAULT '>= 0'::text,
        dwindow integer DEFAULT 8)
        RETURNS SETOF clients.t_data_function 
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
        ROWS 1000

    AS $BODY$
            DECLARE
                c integer; -- counter
                n integer; -- minimum number of data in window
                q text;    -- dynamic query
            BEGIN

                /* entry */
                RAISE NOTICE 'Function clients.f_calc_dynamic_moving_mean, stpr_id: %', stprid;

                /* Testing

                    SELECT * FROM  clients.f_calc_dynamic_moving_mean (
                        45,
                        '2021-01-13 00:00'::timestamp,
                        '2021-01-20 23:00'::timestamp,
                        '>= 0'::text,
                        6::integer
                    );
                */

                SELECT ((dwindow/100.0)*75)::integer INTO n;

                q =
                'WITH t AS ('||E'\n'
                ||'    SELECT'||E'\n'
                ||'        measure_date_time,'||E'\n'
                ||'        measure_id,'||E'\n'
                ||'        ROUND(avg(measure_value) OVER mywindow, 10)::numeric AS measure_value,'||E'\n'
                ||'        ROUND(avg(measure_min) OVER mywindow, 10)::numeric AS measure_min,'||E'\n'
                ||'        ROUND(avg(measure_max) OVER mywindow, 10)::numeric AS measure_max,'||E'\n';

                FOR c in 1..(dwindow-1) LOOP
                    RAISE NOTICE 'counter: %', c;
                    q = q ||'        CASE WHEN LAG(measure_value, '||c||') OVER mywindow IS NULL THEN 0 ELSE 1 END +'||E'\n';

                    -- IF c != (dwindow-1) THEN
                    --     q = q ||'+'||E'\n';
                    -- END IF;
                END LOOP;
                
                q = q
                ||'        CASE WHEN measure_value IS NULL THEN 0 ELSE 1 END'||E'\n'
                ||'    AS measure_counter'||E'\n'
                ||'    FROM clients.f_data_extraction('||stprid||'::bigint, ('||quote_literal(date_from)||'::timestamp - INTERVAL '''||dwindow||' hours''), '||quote_literal(date_to)||'::timestamp, ''hh''::metadata.e_aggregations, ''avg''::metadata.e_treatments, '||quote_literal(validity)||'::text) tbl'||E'\n'
                ||'    WINDOW mywindow AS (ORDER BY measure_date_time ROWS BETWEEN '||(dwindow-1)||' PRECEDING AND CURRENT ROW)'||E'\n'
                ||'    ORDER BY measure_date_time'||E'\n'
                ||')'||E'\n'
                ||'SELECT '||E'\n'
                ||'    t.measure_date_time,'||E'\n'
                ||'    t.measure_id,'||E'\n'
                ||'    CASE '||E'\n'
                ||'        WHEN t.measure_counter >= '||n||' THEN t.measure_value '||E'\n'
                ||'        ELSE NULL '||E'\n'
                ||'    END AS measure_value,'||E'\n'
                ||'    CASE '||E'\n'
                ||'        WHEN t.measure_counter >= '||n||' THEN t.measure_min '||E'\n'
                ||'        ELSE NULL '||E'\n'
                ||'    END AS measure_min,'||E'\n'
                ||'    CASE '||E'\n'
                ||'        WHEN t.measure_counter >= '||n||' THEN t.measure_max '||E'\n'
                ||'        ELSE NULL '||E'\n'
                ||'    END AS measure_max,'||E'\n'
                ||'    CASE WHEN t.measure_value NOTNULL THEN (t.measure_counter::real / '||(dwindow)||'*100)::smallint END AS measure_perc,'||E'\n'
                ||'    0::integer  AS post_validity_code,'||E'\n'
                ||'    0::smallint AS final_validity_code'||E'\n'
                ||'FROM t'||E'\n'
                ||'ORDER BY t.measure_date_time;'||E'\n';

                /* notice */
                RAISE NOTICE 'Query: %', E'\n'||q;

                /* return value */
                RETURN QUERY EXECUTE q;

            /* errors check */
            EXCEPTION
                WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_calc_dynamic_moving_mean(): %', SQLERRM;
            END;
        
    $BODY$;

    GRANT EXECUTE ON FUNCTION clients.f_calc_dynamic_moving_mean(bigint, timestamp without time zone, timestamp without time zone, text, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_calc_dynamic_moving_mean(bigint, timestamp without time zone, timestamp without time zone, text, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_calc_dynamic_moving_mean(bigint, timestamp without time zone, timestamp without time zone, text, integer) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_calc_dynamic_moving_mean(bigint, timestamp without time zone, timestamp without time zone, text, integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_calc_dynamic_moving_mean(bigint, timestamp without time zone, timestamp without time zone, text, integer)
        IS 'Moving Average data extraction function';

    -- Funzione che restituisce la descrizione testuale del risultato di una taratura
    -- DROP FUNCTION IF EXISTS clients.f_calibration_result_tostring(integer, text);
    CREATE OR REPLACE FUNCTION clients.f_calibration_result_tostring (
        result_code      integer,
        calibration_step text
    )
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE
    AS $BODY$

    DECLARE
        result text;
    BEGIN
        /* TEST
        SELECT * FROM clients.calibration_result_tostring(5);
        */
        IF (result_code = 0) THEN
            result := 'Ok';
            RETURN result;
        END IF;

        /* build the dynamic query_sql */
        IF (calibration_step = 'SPAN') THEN

            CASE
                WHEN (result_code | 1) = result_code THEN result := 'Span Low';
                WHEN (result_code | 2) = result_code THEN result := 'Span High';
                ELSE result := 'Ok';
            END CASE;

        ELSE -- calibration_step = 'ZERO'

            CASE
                WHEN (result_code | 4) = result_code THEN result := 'Zero Low';
                WHEN (result_code | 8) = result_code THEN result := 'Zero High';
                ELSE result := 'Ok';
            END CASE;

        END IF;

        /* return value */
        RETURN result ;

        /* errors check */
        EXCEPTION WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN clients.f_calibration_result_tostring(integer, text) : %', SQLERRM ;
            RETURN NULL; /* return value */
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_calibration_result_tostring(integer, text) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_calibration_result_tostring(integer, text) TO group_tools;
    GRANT EXECUTE ON FUNCTION clients.f_calibration_result_tostring(integer, text) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_calibration_result_tostring(integer, text) TO group_readonly;

    -- comment
    COMMENT ON FUNCTION clients.f_calibration_result_tostring(integer, text)
        IS 'Convert calibration into description';

    -- Vista che raccoglie le informazioni relative ai risultati delle tarature effettuate
    -- DROP VIEW IF EXISTS clients.view_calibrations_result;
    CREATE OR REPLACE VIEW clients.view_calibrations_result AS
    SELECT
        cr.calibration_id,
        cr.calibration_date_time,
        cr.station_id,
        st.station_name,
        st.station_schema,
        st.station_table,
        st.station_prefix,
        st.station_schema ||'.'::text||COALESCE(st.station_prefix, ''::text)||st.station_table AS station_fulltable,
        cr.measure_id,
        pa.param_id,
        pa.param_name,
        pa.param_unit,
        pa.param_conv,
        pa.param_unit_conv,
        pa.param_decimals,
        cr.calibration_type,
        cr.calibration_step,
        cr.reference_value,
        cr.defect_value,
        CASE
            WHEN cr.calibration_step = 'ZERO'::text THEN (cr.defect_value)::text ||' ppb'::text
            ELSE (cr.defect_value)::text ||' %'::text
        END AS calibration_defect,
        cr.result_code,
        CASE
            WHEN pa.param_name IN ('NO', 'NO2') THEN ''::text
            ELSE clients.f_calibration_result_tostring((cr.result_code)::integer, cr.calibration_step)
        END AS result_code_string,
        cr.result_value
    FROM
        clients.calibrations_result cr
        LEFT JOIN metadata.stations st USING (station_id)
        LEFT JOIN metadata.stations_parameters sp ON (cr.station_id = sp.station_id AND cr.measure_id = sp.stpr_table_id)
        LEFT JOIN metadata.parameters pa USING (param_id)
    ORDER BY cr.calibration_id, cr.calibration_date_time;

    -- grants
    GRANT ALL ON TABLE    clients.view_calibrations_result TO group_admin;
    GRANT ALL ON TABLE    clients.view_calibrations_result TO group_bobo;
    GRANT ALL ON TABLE    clients.view_calibrations_result TO group_tools;
    GRANT SELECT ON TABLE clients.view_calibrations_result TO group_readonly;

    -- comments
    COMMENT ON VIEW clients.view_calibrations_result IS 'Calibrations result view';

    -- Funzione che copia i dati delle tarature all'interno delle tabelle di export
    -- DROP FUNCTION IF EXISTS clients.f_calibrations_export();
    CREATE OR REPLACE FUNCTION clients.f_calibrations_export()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$

    DECLARE
        s text;  -- schema
        q text;  -- query
        e boolean;
    BEGIN
        /* check station is export enabled */
        SELECT INTO e ss_custom_export_publish FROM metadata.stations_status WHERE station_id = NEW.station_id;
        IF e IS FALSE THEN
            -- RAISE NOTICE 'Station export active false';
            /* return */
            RETURN NEW;
        END IF;

        /* get table name */
        SELECT
            station_schema INTO s
        FROM
            metadata.stations
        WHERE
            station_id = NEW.station_id;

        -- check if table exists
        SELECT INTO e EXISTS (
            SELECT FROM
                pg_tables
            WHERE
                schemaname = s AND
                tablename  = 'calibrations_export'
        );

        IF e IS FALSE THEN
            -- RAISE NOTICE 'Export table does not exist';
            /* return */
            RETURN NEW;
        END IF;

        /* build query */
        q = 'INSERT INTO '||s||'.calibrations_export ( '||E'\n'
        ||'    calibration_id, '||E'\n'
        ||'    calibration_date_time, '||E'\n'
        ||'    station_id, '||E'\n'
        ||'    measure_id, '||E'\n'
        ||'    calibration_type, '||E'\n'
        ||'    calibration_step, '||E'\n'
        ||'    reference_value, '||E'\n'
        ||'    defect_value, '||E'\n'
        ||'    result_code, '||E'\n'
        ||'    result_value '||E'\n'
        ||') VALUES ( '||E'\n'
        ||'    '||NEW.calibration_id||', '||E'\n'
        ||'    '||quote_literal(NEW.calibration_date_time)||', '||E'\n'
        ||'    '||NEW.station_id||', '||E'\n'
        ||'    '||NEW.measure_id||', '||E'\n'
        ||'    '||quote_literal(NEW.calibration_type)||', '||E'\n'
        ||'    '||quote_literal(NEW.calibration_step)||', '||E'\n'
        ||'    '||NEW.reference_value||', '||E'\n'
        ||'    '||NEW.defect_value||', '||E'\n'
        ||'    '||NEW.result_code||', '||E'\n'
        ||'    '||NEW.result_value||' '||E'\n'
        ||');'||E'\n\n';

        /* execute */
        EXECUTE q;

        /* return value */
        RETURN NEW;

        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR IN clients.f_calibrations_export() : %', SQLERRM;
            /* return value */
            RETURN NEW;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_calibrations_export() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_calibrations_export() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_calibrations_export() TO group_tools;

    -- comments
    COMMENT ON FUNCTION clients.f_calibrations_export()
        IS 'Clone data from calibrations to export table';

    -- Funzione che controlla i valori minimi e massimi e li inserisce nel parametro appropriato
    -- DROP FUNCTION IF EXISTS clients.f_campbell_min_max();
    CREATE OR REPLACE FUNCTION clients.f_campbell_min_max()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$

    DECLARE
        stid           integer;
        tableid        integer;
        prid           integer;
        prid_min       integer;
        prid_max       integer;
    BEGIN
        --RAISE NOTICE 'FUNCTION f_campbell_min_max';

        /*station id passed by caller*/
        stid  := TG_ARGV[0];
        --RAISE NOTICE 'stid: %', stid;

        /*get the parameter id*/
        SELECT INTO prid param_id FROM metadata.stations_parameters
            WHERE station_id = stid AND stpr_table_id = NEW.measure_id;
        --RAISE NOTICE 'prid: %', prid;

        /*check exists or swam one*/
        IF NOT FOUND THEN
            --RAISE NOTICE 'prid not found';
            RETURN NEW;
        END IF;

        /*select the right parameters min&max ids*/
        --RAISE NOTICE 'select prids';
        /*
            -- 19  Velocità Vento Vett.
            -- 21  Velocità Vento Raff.

            -- 22  Direzione Vento Vett.
            -- 24  Direzione Vento Raff.

            -- 1   Temperatura
            -- 2   Temperatura min
            -- 3   Temperatura max

            -- 4   Umidità
            -- 5   Umidità min
            -- 6   Umidità max
        */
        IF prid = 19 THEN prid_max := 21; END IF; -- Velocità Vento Vett.
        IF prid = 22 THEN prid_max := 24; END IF; -- Direzione Vento Raff.

        /*
        IF prid = 1 THEN -- Temperatura
            prid_min := 2;
            prid_max := 3;
        END IF;
        IF prid = 4 THEN -- Umidità
            prid_min := 5;
            prid_max := 6;
        END IF;
        */

        /* insert min */
        IF prid_min IS NOT NULL AND NEW.measure_min IS NOT NULL THEN

            --RAISE NOTICE 'prid_min: %', prid_min;
            /*get parameter table id per min&max ids*/
            SELECT INTO tableid stpr_table_id FROM metadata.stations_parameters
                WHERE station_id = stid AND param_id = prid_min;

            /*check*/
            IF FOUND THEN
                --RAISE NOTICE 'tableid: %', tableid;

                /*insert new record*/
                EXECUTE format(
                    'INSERT INTO %I.%I ('
                    ||'    measure_date_time,'
                    ||'    measure_id,'
                    ||'    measure_value,'
                    ||'    measure_code,'
                    ||'    measure_perc'
                    ||') VALUES ('
                    ||'    $1.measure_date_time,'
                    ||'    '||tableid||','
                    ||'    $1.measure_min,'
                    ||'    $1.measure_code,'
                    ||'    $1.measure_perc'
                    ||')' , TG_TABLE_SCHEMA, TG_TABLE_NAME)
                USING NEW;

            END IF;

        END IF;

        /* insert min */
        IF prid_max IS NOT NULL AND NEW.measure_max IS NOT NULL THEN
            --RAISE NOTICE 'prid_max: %', prid_max;

            /*get parameter table id per min&max ids*/
            SELECT INTO tableid stpr_table_id FROM metadata.stations_parameters
                WHERE station_id = stid AND param_id = prid_max;

            /*check*/
            IF FOUND THEN
                --RAISE NOTICE 'tableid: %', tableid;

                /*insert new record*/
                EXECUTE format(
                    'INSERT INTO %I.%I ('
                    ||'    measure_date_time,'
                    ||'    measure_id,'
                    ||'    measure_value,'
                    ||'    measure_code,'
                    ||'    measure_perc'
                    ||') VALUES ('
                    ||'    $1.measure_date_time,'
                    ||'    '||tableid||','
                    ||'    $1.measure_max,'
                    ||'    $1.measure_code,'
                    ||'    $1.measure_perc'
                    ||')' , TG_TABLE_SCHEMA, TG_TABLE_NAME)
                USING NEW;

            END IF;

        END IF;

        /* return value */
        RETURN NEW;

        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR IN clients.f_campbell_min_max() : %', SQLERRM;
            /* return value */
            RETURN NEW;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_campbell_min_max() TO PUBLIC;
    GRANT EXECUTE ON FUNCTION clients.f_campbell_min_max() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_campbell_min_max() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_campbell_min_max() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_campbell_min_max()
        IS 'Check min & max values and insert them into appropriate param_id';

    -- Funzione di aggiornamento della tabella relativa agli allarmi di stazione
    -- DROP FUNCTION clients.f_check_station_alarms;
    CREATE OR REPLACE FUNCTION clients.f_check_station_alarms(
        )
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        r record;
        q text;
        ir record; -- inner record
        iq text; -- inner query
        sq text; -- subquery
    BEGIN
        -- TEST SELECT clients.f_check_station_alarms();

       -- loop through all active stations and get last available alarms
        FOR r IN (
            SELECT
                st.station_id,
                ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable
            FROM
                metadata.stations st
                LEFT JOIN metadata.stations_status ss USING(station_id)
                LEFT JOIN metadata.stations_info si USING (station_id)
            WHERE
                st.station_id >= 1000
                AND st.station_active IS TRUE
                AND ss.ss_suspended IS FALSE
                AND si.st_info_typology_fk != 6 -- Magazzino
        ) LOOP

            --RAISE NOTICE 'Station: %', r.station_id;

            -- measure code alarms
            q= 'WITh t AS ( '||E'\n'
                ||'    SELECT  '||E'\n'
                ||'        stpr_table_id, '||E'\n'
                ||'        stpr_id, '||E'\n'
                ||'        station_id, '||E'\n'
                ||'        param_id '||E'\n'
                ||'    FROM  '||E'\n'
                ||'        metadata.stations_parameters sp '||E'\n'
                ||'        LEFT JOIN metadata.parameters_info pi USING (param_id) '||E'\n'
                ||'        LEFT JOIN metadata.parameters_type pt ON pt.pm_type_id = pi.pm_info_type_fk '||E'\n'
                ||'    WHERE  '||E'\n'
                ||'        station_id = '||r.station_id||'  '||E'\n'
                ||'        AND pt.pm_type_desc LIKE ''Allarmi'' '||E'\n'
                ||'), '||E'\n'
                ||'t2 as ( '||E'\n'
                ||'    SELECT  '||E'\n'
                ||'        measure_id, '||E'\n'
                ||'        measure_date_time '||E'\n'
                ||'    FROM '||r.station_fulltable||' '||E'\n'
                ||'    WHERE measure_id IN ( '||E'\n'
                ||'        SELECT stpr_table_id FROM t '||E'\n'
                ||'    ) '||E'\n'
                ||'    AND measure_value = 1 '||E'\n'
                ||'    AND measure_date_time > CURRENT_TIMESTAMP - interval ''3 days''  '||E'\n'
                ||') '||E'\n'
                ||'INSERT INTO clients.stations_alarms (station_id, param_id, stpr_id, sa_fulldate) '||E'\n'
                ||'( '||E'\n'
                ||'    SELECT '||E'\n'
                ||'        t.station_id, '||E'\n'
                ||'        t.param_id, '||E'\n'
                ||'        t.stpr_id, '||E'\n'
                ||'        t2.measure_date_time '||E'\n'
                ||'    FROM  '||E'\n'
                ||'        t2 '||E'\n'
                ||'        LEFT JOIN t ON t2.measure_id = t.stpr_table_id '||E'\n'
                ||'    ORDER BY measure_date_time  '||E'\n'
                ||') '||E'\n'
                ||'ON CONFLICT ON CONSTRAINT clients_stations_alarms_ukey DO NOTHING; '||E'\n\n';

            --RAISE NOTICE 'Query: %', q;
            EXECUTE q;

            -- station code alarms
            iq= 'SELECT measure_date_time, MAX(station_code) AS station_code'||E'\n'
            ||'FROM '||r.station_fulltable||' '||E'\n'
            ||'WHERE station_code != 0'||E'\n'
            ||'AND measure_date_time > CURRENT_TIMESTAMP - interval ''3 day'''||E'\n'
            ||'GROUP BY measure_date_time'||E'\n'
            ||'ORDER BY measure_date_time'||E'\n\n';

            --RAISE NOTICE 'Query : %', iq;
            FOR ir IN EXECUTE iq
            LOOP
                /* Station Alarm      BOBO - OPAS
                SOFTWARE_ERROR = 1 -> 846  - 149    Allarme software
                SYSTEM_RESTART = 2 -> 894  - 537    Allarme riavvio sistema
                LOW_DISK_SPACE = 4 -> 847  - 150    Allarme disco <1GB
                */

                IF ir.station_code & 1 = 1 THEN
                    sq = 'INSERT INTO clients.stations_alarms (station_id, param_id, sa_fulldate) VALUES ('||r.station_id||', 149::integer, '||quote_literal(ir.measure_date_time)||') ON CONFLICT ON CONSTRAINT clients_stations_alarms_ukey DO NOTHING;';
                    --EXECUTE sq;
                END IF;

                IF ir.station_code & 2 = 2 THEN
                    sq = 'INSERT INTO clients.stations_alarms (station_id, param_id, sa_fulldate) VALUES ('||r.station_id||', 537::integer, '||quote_literal(ir.measure_date_time)||') ON CONFLICT ON CONSTRAINT clients_stations_alarms_ukey DO NOTHING;';
                    EXECUTE sq;
                END IF;

                IF ir.station_code & 4 = 4 THEN
                    sq = 'INSERT INTO clients.stations_alarms (station_id, param_id, sa_fulldate) VALUES ('||r.station_id||', 150::integer, '||quote_literal(ir.measure_date_time)||') ON CONFLICT ON CONSTRAINT clients_stations_alarms_ukey DO NOTHING;';
                    EXECUTE sq;
                END IF;
            END LOOP;
        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_check_station_alarms(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_check_station_alarms() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_check_station_alarms() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_check_station_alarms() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_check_station_alarms() TO group_tools;

    -- comments
    COMMENT ON FUNCTION clients.f_check_station_alarms()
        IS 'Refresh table with latest alarms';

    -- Funzione di estrazione dei dati per i vari applicativi del portale
    -- DROP FUNCTION IF EXISTS clients.f_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, metadata.e_treatments, text);
    CREATE OR REPLACE FUNCTION clients.f_data_extraction(
        stprid bigint,
        date_from timestamp without time zone,
        date_to timestamp without time zone,
        aggregation metadata.e_aggregations DEFAULT 'hh'::metadata.e_aggregations,
        treatment metadata.e_treatments DEFAULT 'avg'::metadata.e_treatments,
        validity text DEFAULT '>= 0'::text)
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
                --RAISE NOTICE 'Function clients.f_data_extraction, stpr_id: %', stprid;

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
                            ||'    CASE WHEN t.measure_value NOTNULL AND '||v||' THEN 100::smallint END AS measure_perc,'||E'\n'
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


    GRANT EXECUTE ON FUNCTION clients.f_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, metadata.e_treatments, text) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, metadata.e_treatments, text) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, metadata.e_treatments, text) TO group_tools;
    GRANT EXECUTE ON FUNCTION clients.f_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, metadata.e_treatments, text) TO group_readonly;

    COMMENT ON FUNCTION clients.f_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, metadata.e_treatments, text) IS '[OPAS] Generic data extraction function';


    -- Funzione che calcola le statistiche di validità dei parametri di una determinata stazione
    -- DROP FUNCTION IF EXISTS clients.f_data_validity_statistics(integer, timestamp, timestamp, boolean);
    CREATE OR REPLACE FUNCTION clients.f_data_validity_statistics(
        stprid integer,
        d1 timestamp,
        d2 timestamp,
        c  boolean
    )
    RETURNS TABLE (
        min_value           numeric,
        max_value           numeric,
        avg_value           numeric,
        perc_value          numeric,
        perc_valid_values   numeric,
        perc_validity_lvl1  numeric,
        perc_validity_lvl2  numeric,
        perc_validity_lvl4  numeric,
        perc_validity_lvl8  numeric
    )
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE
    ROWS 1000
    AS $BODY$

    DECLARE
        t text;         -- tablename
        p integer;      -- parameter table id
        d integer;      -- parameter decimals
        o text;         -- operation
        q text;         -- dynamic query
    BEGIN
        --
        -- TEST SELECT * FROM clients.f_data_validity_statistics( 231 , '2023-09-05 00:00'::timestamp, '2023-09-12 23:00'::timestamp, TRUE );
        --
        SELECT
            s.station_schema ||'.'||COALESCE(s.station_prefix, '')||s.station_table, sp.stpr_table_id, p.param_decimals,
            CASE
                -- WHEN c IS TRUE THEN '*'||p.param_conv
                WHEN c IS TRUE THEN '* metadata.f_get_conversion_by_date( '||p.param_id||', tbl.measure_date_time ) '
                ELSE ''
            END INTO t, p, d, o
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.parameters p USING (param_id)
        WHERE
            stpr_id = stprid;

        IF NOT FOUND THEN
            RAISE NOTICE 'Parameter % not found', stprid;
            RETURN;
        END IF;

        q =
            '-- calculate difference in hours between 2 dates'||E'\n'
            ||'WITH h AS('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        ( EXTRACT(''epoch'' FROM '||quote_literal(d2)||'::timestamp - '||quote_literal(d1)||'::timestamp) / 3600 )::integer + 1 AS diff'||E'\n'
            ||'),'||E'\n'
            ||'-- extract values and count based on filter between 2 dates'||E'\n'
            ||'v AS ('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        ROUND( MIN(measure_value'||o||') FILTER (WHERE post_validity_code >= 0 ), '||d||' )    AS min_value,'||E'\n'
            ||'        ROUND( MAX(measure_value'||o||') FILTER (WHERE post_validity_code >= 0 ), '||d||' )    AS max_value,'||E'\n'
            ||'        ROUND( AVG(measure_value'||o||') FILTER (WHERE post_validity_code >= 0 ), '||d||' )    AS avg_value,'||E'\n'
            ||'        COALESCE( SUM(extract_code) , 0 )       AS cnt_rows,'||E'\n'
            ||'        COALESCE( SUM(extract_code) FILTER (WHERE post_validity_code >= 0 ) , 0 ) AS cnt_rows_valid,'||E'\n'
            ||'        COALESCE( SUM(extract_code) FILTER (WHERE 1 = ANY(main.bitmask_toarray(final_validity_code::integer, 10))) , 0 ) AS cnt_rows_lvl1,'||E'\n'
            ||'        COALESCE( SUM(extract_code) FILTER (WHERE 2 = ANY(main.bitmask_toarray(final_validity_code::integer, 10))) , 0 ) AS cnt_rows_lvl2,'||E'\n'
            ||'        COALESCE( SUM(extract_code) FILTER (WHERE 4 = ANY(main.bitmask_toarray(final_validity_code::integer, 10))) , 0 ) AS cnt_rows_lvl4,'||E'\n'
            ||'        COALESCE( SUM(extract_code) FILTER (WHERE 8 = ANY(main.bitmask_toarray(final_validity_code::integer, 10))) , 0 ) AS cnt_rows_lvl8'||E'\n'
            ||'    FROM '||E'\n'
            ||'        '||t||' '||E'\n'
            ||'    WHERE'||E'\n'
            ||'        measure_id = '||p||' '||E'\n'
            ||'        AND measure_date_time BETWEEN '||quote_literal(d1)||'::timestamp AND '||quote_literal(d2)||'::timestamp'||E'\n'
            ||')'||E'\n'
            ||'-- calculate statistics'||E'\n'
            ||'SELECT'||E'\n'
            ||'    v.min_value,'||E'\n'
            ||'    v.max_value,'||E'\n'
            ||'    v.avg_value,'||E'\n'
            ||'    LEAST( ROUND((v.cnt_rows / h.diff::numeric)* 100, 1 ) , 100 )  AS perc_value,'||E'\n'
            ||'    CASE WHEN v.cnt_rows = 0 THEN 0 ELSE LEAST( TRUNC(( v.cnt_rows_valid / h.diff::numeric * 100 ), 1) , 100 ) END AS perc_valid_values,'||E'\n'
            ||'    CASE WHEN v.cnt_rows = 0 THEN 0 ELSE LEAST( TRUNC(( v.cnt_rows_lvl1 / v.cnt_rows::numeric * 100 ), 1) , 100 ) END AS perc_validity_lvl1,'||E'\n'
            ||'    CASE WHEN v.cnt_rows = 0 THEN 0 ELSE LEAST( TRUNC(( v.cnt_rows_lvl2 / v.cnt_rows::numeric * 100 ), 1) , 100 ) END AS perc_validity_lvl2,'||E'\n'
            ||'    CASE WHEN v.cnt_rows = 0 THEN 0 ELSE LEAST( TRUNC(( v.cnt_rows_lvl4 / v.cnt_rows::numeric * 100 ), 1) , 100 ) END AS perc_validity_lvl4,'||E'\n'
            ||'    CASE WHEN v.cnt_rows = 0 THEN 0 ELSE LEAST( TRUNC(( v.cnt_rows_lvl8 / v.cnt_rows::numeric * 100 ), 1) , 100 ) END AS perc_validity_lvl8'||E'\n'
            ||'FROM '||E'\n'
            ||'    v, h;'||E'\n';

        RAISE NOTICE '%', q;

        /* return value */
        RETURN QUERY EXECUTE q;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_data_validity_statistics(): %', SQLERRM;
            RETURN;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_data_validity_statistics(integer, timestamp, timestamp, boolean) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_data_validity_statistics(integer, timestamp, timestamp, boolean) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_data_validity_statistics(integer, timestamp, timestamp, boolean) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_data_validity_statistics(integer, timestamp, timestamp, boolean) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_data_validity_statistics(integer, timestamp, timestamp, boolean)
        IS 'Function that calculates station-parameter validity''s statistics';

    -- Funzione che restituisce l'ultimo valore di un determinato parametro in una determinata stazione
    -- DROP FUNCTION IF EXISTS clients.f_get_last_param_data(integer, metadata.e_aggregations);
    CREATE OR REPLACE FUNCTION clients.f_get_last_param_data(
        stprid integer,
        param_aggr metadata.e_aggregations)
        RETURNS numeric
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        c real; -- conv
        d integer; -- decimals
        a text; -- aggregation
        v numeric; --last value
        q text; -- query
    BEGIN
        -- TEST
        -- SELECT clients.f_get_last_param_data(1023::integer, 32::integer, 'hh'::metadata.e_aggregations);

        SELECT param_conv, param_decimals INTO c, d
        FROM metadata.stations_parameters
        LEFT JOIN metadata.parameters p USING (param_id)
        WHERE stpr_id = stprid;

        IF NOT FOUND THEN
            RAISE NOTICE 'Parameter % not found for station: %', pr_id, st_id;
            RETURN NULL;
        END IF;

        a = 'hour';

        IF param_aggr = 'dd'::metadata.e_aggregations  THEN
            a = 'day';
        END IF;


        q = 'SELECT ROUND((tbl.measure_value*'||c||')::numeric, '||d||') '
            || 'FROM clients.f_data_extraction( '||stprid||', date_trunc('''||a||''', (CURRENT_TIMESTAMP - interval ''2 '||a||'''))::timestamp, date_trunc('''||a||''', CURRENT_TIMESTAMP)::timestamp, '||quote_literal(param_aggr)||'::metadata.e_aggregations) tbl '
            || 'WHERE measure_value NOTNULL '
            || 'AND measure_perc >= 75 '
            || 'ORDER BY measure_date_time DESC '
            || 'LIMIT 1;';


        -- RAISE NOTICE 'Query : %', q;

        EXECUTE q INTO v;

        RETURN v;
        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN clients.f_get_last_param_data() : %', SQLERRM ;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_get_last_param_data(integer, metadata.e_aggregations) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_get_last_param_data(integer, metadata.e_aggregations) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_get_last_param_data(integer, metadata.e_aggregations) TO group_tools;
    GRANT EXECUTE ON FUNCTION clients.f_get_last_param_data(integer, metadata.e_aggregations) TO group_readonly;

    -- comment
    COMMENT ON FUNCTION clients.f_get_last_param_data(integer, metadata.e_aggregations)
        IS 'Function that returns the last value of a certain parameter for a certain station';

    -- Funzione che esplode una bitmask in un array di messaggi (strumento ENVEA MP101M)
    -- DROP FUNCTION clients.f_get_messages_envea(bit)
    CREATE OR REPLACE FUNCTION clients.f_get_messages_envea( m bit(11) )
        RETURNS jsonb
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        idx integer;
        t jsonb;
        o jsonb;
    BEGIN
        -- TEST SELECT clients.f_get_messages_envea('11111111111'::bit(11));
        RAISE NOTICE 'Maschera: %', m;

        o := '[]'::jsonb;

        FOR idx IN (
            WITH x AS (SELECT m AS b)
            SELECT i
            FROM  (SELECT b, generate_series(1, length(b)) AS i FROM x) y
            WHERE  substring(b, i, 1) = '1'
        ) LOOP

            RAISE NOTICE 'Indice: %', idx;

            SELECT jsonb_build_object('code', id, 'desc', message) INTO t
            FROM clients.envea_messages
            WHERE id = idx;

            SELECT o || t INTO o;

        END LOOP;

        RETURN o;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_get_messages_envea(): %', SQLERRM;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_envea(bit) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_envea(bit) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_envea(bit) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_envea(bit) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_get_messages_envea(bit)
        IS 'Explode bitmask into array of messages';

   -- Funzione che esplode una bitmask in un array di messaggi (strumento PALAS FIDAS)
    -- DROP FUNCTION clients.f_get_messages_fidas(bit)
    CREATE OR REPLACE FUNCTION clients.f_get_messages_fidas(
        m bit(8)
    )
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE
    AS $BODY$

    DECLARE
        idx integer;
        t jsonb;
        o jsonb;
    BEGIN
        -- TEST SELECT clients.f_get_messages_fidas('00001001'::bit(8));
        RAISE NOTICE 'Maschera: %', m;

        o := '[]'::jsonb;

        FOR idx IN (
            WITH x AS (SELECT m AS b)
            SELECT (length(b)+1)-i -- converto ordine indice little-endian
            FROM  (SELECT b, generate_series(1, length(b)) AS i FROM x) y
            WHERE  substring(b, i, 1) = '1'
        ) LOOP

            RAISE NOTICE 'Indice: %', idx;

            SELECT jsonb_build_object('code', fm_code, 'desc', fm_desc) INTO t
            FROM clients.fidas_messages
            WHERE fm_id = idx;

            SELECT o || t INTO o;

        END LOOP;

        RETURN o;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_get_messages_fidas(): %', SQLERRM;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_fidas(bit) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_fidas(bit) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_fidas(bit) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_fidas(bit) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_get_messages_fidas(bit)
        IS 'Explode bitmask into array of messages';

    -- Funzione che esplode una bitmask in un array di messaggi (strumento METONE BC 1054)
    -- DROP FUNCTION clients.f_get_messages_metone(bit)
    CREATE OR REPLACE FUNCTION clients.f_get_messages_metone(
        s integer)
        RETURNS jsonb
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        idx integer;
        t jsonb;
        o jsonb;
    BEGIN
        -- TEST SELECT clients.f_get_messages_metone(69696);
        RAISE NOTICE 'Status: %', s;

        o := '[]'::jsonb;

        FOREACH idx IN ARRAY (
            SELECT main.bitmask_toarray(s, 20)
        ) LOOP

            RAISE NOTICE 'Indice: %', idx;

            SELECT jsonb_build_object('code', id, 'desc', message) INTO t
            FROM clients.metone_messages
            WHERE id = idx;

            SELECT o || t INTO o;

        END LOOP;

        RETURN o;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_get_messages_metone(): %', SQLERRM;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_metone(integer) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_metone(integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_metone(integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_metone(integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_get_messages_metone(integer)
        IS 'Expand status code into array of messages';

    -- Funzione che esplode una bitmask in un array di messaggi (strumento SWAM)
    -- DROP FUNCTION clients.f_get_messages_swam(bit)
    CREATE OR REPLACE FUNCTION clients.f_get_messages_swam(
        m bit(32)
    )
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE
    AS $BODY$

    DECLARE
        idx integer;
        t jsonb;
        o jsonb;
    BEGIN
        -- TEST SELECT clients.f_get_messages_swam('10000000000000000010000000000001'::bit(32));
        RAISE NOTICE 'Maschera: %', m;

        o := '[]'::jsonb;

        FOR idx IN (
            WITH x AS (SELECT m AS b)
            SELECT i
            FROM  (SELECT b, generate_series(1, length(b)) AS i FROM x) y
            WHERE  substring(b, i, 1) = '1'
        ) LOOP

            RAISE NOTICE 'Indice: %', idx;

            SELECT jsonb_build_object('code', sm_code, 'desc', sm_desc) INTO t
            FROM clients.swam_messages
            WHERE sm_id = idx;

            SELECT o || t INTO o;

        END LOOP;

        RETURN o;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_get_messages_swam(): %', SQLERRM;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_swam(bit) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_swam(bit) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_swam(bit) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_swam(bit) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_get_messages_swam(bit)
        IS 'Explode bitmask into array of messages';

    -- Funzione che esplode una bitmask in un array di messaggi (strumento Teledyne API)
    -- DROP FUNCTION clients.f_get_messages_teledyne(bigint)
    CREATE OR REPLACE FUNCTION clients.f_get_messages_teledyne(
        s bigint)
        RETURNS jsonb
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        idx integer;
        t jsonb;
        o jsonb;
    BEGIN
        -- TEST SELECT clients.f_get_messages_metone(69696);
        RAISE NOTICE 'Status: %', s;

        o := '[]'::jsonb;

        FOREACH idx IN ARRAY (
            SELECT main.bitmask_toarray(s, 60)
        ) LOOP

            RAISE NOTICE 'Indice: %', idx;

            SELECT jsonb_build_object('code', id, 'desc', message) INTO t
            FROM clients.teledyne_messages
            WHERE id = idx;

            SELECT o || t INTO o;

        END LOOP;

        RETURN o;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_get_messages_teledyne(): %', SQLERRM;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_teledyne(bigint) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_teledyne(bigint) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_teledyne(bigint) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_get_messages_teledyne(bigint) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_get_messages_teledyne(bigint)
        IS 'Expand status code into array of messages';

    -- DROP FUNCTION IF EXISTS clients.f_get_station_gaps(integer, timestamp without time zone);
    CREATE OR REPLACE FUNCTION clients.f_get_station_gaps(
        stid integer,
        fulldate timestamp without time zone
    )
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        r   record;
        ri  record;
        q   text;
        o   jsonb;
    BEGIN
        /**
            * Function that recovers the delays of a station over the two weeks before the date passed as argument.
            * Delays are calculated for all main parameters and are based on the acquisition
            * frequencies declared (hourly, daily, etc., etc.)
            *
            * A different color is assigned based on the severity of the delay
            *
            * TEST SELECT clients.f_get_station_gaps(1000, CURRENT_TIMESTAMP::timestamp without time zone);
            */

        o := array_to_json(ARRAY[]::jsonb[]);

        RAISE NOTICE 'Looping through parameters of station % ...', stid;
        FOR r IN (
            SELECT
                s.station_id,
                s.station_schema ||'.'|| COALESCE(s.station_prefix, '') || s.station_table AS station_fulltable,
                sp.stpr_table_id,
                CONCAT_WS( ' - ', p.param_name, sp.stpr_note ) AS parameter_name,
                mc.measure_cadence_db AS max_gap,
                mc.measure_cadence_id
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.stations s USING (station_id)
                LEFT JOIN metadata.stations_info si USING (station_id)
                LEFT JOIN metadata.measures_cadence mc ON COALESCE(spi.stpr_info_cadence_fk, si.st_info_cadence_fk) = mc.measure_cadence_id
            WHERE
                s.station_id = stid
                AND sp.stpr_active IS TRUE
                AND sp.param_id IN (
                    SELECT param_id
                    FROM metadata.parameters_info
                    WHERE pm_info_type_fk IN (1,2,3,20)
                )
            ORDER BY sp.stpr_table_id
        ) LOOP

            RAISE NOTICE 'Parameter % - %', r.stpr_table_id, r.parameter_name;

            /* Calculate the delay based on the acquisition frequency declared for each parameter linked to the station  */
            CASE r.measure_cadence_id
                -- daily
                WHEN 8 THEN

                    q = 'WITH t AS('||E'\n'
                        ||'    SELECT'||E'\n'
                        ||'        measure_date_time,'||E'\n'
                        ||'        measure_insert_ts,'||E'\n'
                        ||'        DATE_TRUNC(''day'', measure_insert_ts) - DATE_TRUNC(''day'', measure_date_time) AS interval_gap,'||E'\n'
                        ||'        ('||E'\n'
                        ||'            EXTRACT(EPOCH FROM DATE_TRUNC(''day'', measure_insert_ts) - DATE_TRUNC(''day'', measure_date_time)) /'||E'\n'
                        ||'            EXTRACT(EPOCH FROM '||quote_literal(r.max_gap)||'::interval)'||E'\n'
                        ||'        )::integer AS num_delays'||E'\n'
                        ||'    FROM '||E'\n'
                        ||'        '||r.station_fulltable||' '||E'\n'
                        ||'    WHERE '||E'\n'
                        ||'        measure_date_time BETWEEN '||quote_literal(fulldate)||'::timestamp - interval ''1 weeks'' AND '||quote_literal(fulldate)||'::timestamp '||E'\n'
                        ||'        AND measure_id = '||r.stpr_table_id||' '||E'\n'
                        ||'    ORDER BY 1 ASC'||E'\n'
                        ||')'||E'\n'
                        ||'SELECT '||E'\n'
                        ||'    measure_date_time,'||E'\n'
                        ||'    measure_insert_ts,'||E'\n'
                        ||'    TRUNC((EXTRACT(EPOCH FROM interval_gap)/(3600*24))::numeric, 0)||'' giorno/i'' AS text_gap, '||E'\n'
                        ||'    CASE'||E'\n'
                        ||'        WHEN num_delays <= 2 THEN ''warning'' '||E'\n'
                        ||'        WHEN num_delays BETWEEN 3 AND 4 THEN ''primary'' '||E'\n'
                        ||'        WHEN num_delays > 4 THEN ''danger'' '||E'\n'
                        ||'    END AS colour_gap '||E'\n'
                        ||'FROM t '||E'\n'
                        ||'WHERE interval_gap > '||quote_literal(r.max_gap)||' '||E'\n'
                        ||'ORDER BY measure_date_time;'||E'\n\n';

                -- all other cases
                ELSE
                    q = 'WITH t AS('||E'\n'
                        ||'    SELECT'||E'\n'
                        ||'        measure_date_time,'||E'\n'
                        ||'        measure_insert_ts,'||E'\n'
                        ||'        DATE_TRUNC(''hour'', measure_insert_ts) - measure_date_time AS interval_gap,'||E'\n'
                        ||'        ('||E'\n'
                        ||'            EXTRACT(EPOCH FROM DATE_TRUNC(''hour'', measure_insert_ts) - measure_date_time) /'||E'\n'
                        ||'            EXTRACT(EPOCH FROM '||quote_literal(r.max_gap)||'::interval)'||E'\n'
                        ||'        )::integer AS num_delays'||E'\n'
                        ||'    FROM '||E'\n'
                        ||'        '||r.station_fulltable||' '||E'\n'
                        ||'    WHERE '||E'\n'
                        ||'        measure_date_time BETWEEN '||quote_literal(fulldate)||'::timestamp - interval ''1 weeks'' AND '||quote_literal(fulldate)||'::timestamp '||E'\n'
                        ||'        AND measure_id = '||r.stpr_table_id||' '||E'\n'
                        ||'    ORDER BY 1 ASC'||E'\n'
                        ||')'||E'\n'
                        ||'SELECT '||E'\n'
                        ||'    measure_date_time,'||E'\n'
                        ||'    measure_insert_ts,'||E'\n'
                        ||'    CASE '||E'\n'
                        ||'        WHEN interval_gap < ''1 day'' THEN (EXTRACT(EPOCH FROM interval_gap)/3600)::integer||'' ora/e'' '||E'\n'
                        ||'        ELSE TRUNC((EXTRACT(EPOCH FROM interval_gap)/(3600*24))::numeric, 0)||'' giorno/i e ''||((EXTRACT(EPOCH FROM interval_gap)%(3600*24))/3600)::integer||'' ore'' '||E'\n'
                        ||'    END AS text_gap, '||E'\n'
                        ||'    CASE'||E'\n'
                        ||'        WHEN num_delays <= 2 THEN ''warning'' '||E'\n'
                        ||'        WHEN num_delays BETWEEN 3 AND 4 THEN ''primary'' '||E'\n'
                        ||'        WHEN num_delays > 4 THEN ''danger'' '||E'\n'
                        ||'    END AS colour_gap '||E'\n'
                        ||'FROM t '||E'\n'
                        ||'WHERE interval_gap >= '||quote_literal(r.max_gap)||' '||E'\n'
                        ||'ORDER BY measure_date_time;'||E'\n\n';

            END CASE;

            RAISE NOTICE 'Query %', q;

            /* For each delay build an object with all main information and append it to an array */
            FOR ri IN
                EXECUTE q
            LOOP

                SELECT o ||
                    jsonb_build_object(
                        'table_id'      , r.stpr_table_id,
                        'param_name'    , r.parameter_name,
                        'measure_date'  , ri.measure_date_time,
                        'measure_insert', ri.measure_insert_ts,
                        'gap'           , ri.text_gap,
                        'colour_gap'    , ri.colour_gap
                    ) INTO o;
            END LOOP;

        END LOOP;

        /* Sort the final array by date and parameter */
        SELECT
            array_to_json(array_agg(row_to_json(t))) INTO o
        FROM (
            SELECT
                table_id,
                param_name,
                TO_CHAR(measure_date,   'YYYY-MM-DD HH24:MI') AS measure_date,
                TO_CHAR(measure_insert, 'YYYY-MM-DD HH24:MI') AS measure_insert,
                gap,
                colour_gap
            FROM
                jsonb_to_recordset(o) AS x(table_id integer, param_name text, measure_date timestamp without time zone, measure_insert timestamp without time zone, gap text, colour_gap text)
            ORDER BY
                x.measure_date, x.table_id
        ) t;

        RETURN o;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_get_station_gaps(): %', SQLERRM;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_get_station_gaps(integer, timestamp without time zone) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_get_station_gaps(integer, timestamp without time zone) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_get_station_gaps(integer, timestamp without time zone) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_get_station_gaps(integer, timestamp without time zone) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_get_station_gaps(integer, timestamp without time zone)
        IS 'Retrieve station gaps';

    -- Funzione che ripulisce le tabelle dei dati istantanei delle stazioni
    -- DROP FUNCTION IF EXISTS clients.f_inst_clean_tables(boolean);
    CREATE OR REPLACE FUNCTION clients.f_inst_clean_tables(
        dryrun boolean
    )
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 1000
    AS $BODY$

    DECLARE
        r record; -- record
        t text; -- tablename
        q text; -- query
    BEGIN
        /* entry */
        RAISE NOTICE 'Function clients.f_inst_clean_tables';

        /* Testing
            SELECT * FROM clients.f_inst_clean_tables( dryrun => true );
        */

        -- loop through all active stations and get last avaible alarms
        FOR r IN (
            SELECT
                temp.schemaname||'.'||temp.tablename AS fulltable,
                schemaname,
                tablename

            FROM
                (
                    SELECT schemaname, tablename FROM pg_tables WHERE schemaname ~ 'client_' AND tablename ~ '_inst$' ORDER BY 1,2
                ) temp
        ) LOOP

                IF NOT (
                    SELECT EXISTS(
                    SELECT 1
                    FROM information_schema.columns
                    WHERE table_schema= r.schemaname AND table_name= r.tablename AND column_name= 'post_validity_code'
                )
            ) THEN

                RAISE NOTICE 'Clean up tablename: %', r.fulltable;
                q= 'DELETE FROM '||r.fulltable||' '||E'\n'
                ||'WHERE measure_date_time < CURRENT_TIMESTAMP - interval ''3 days'''||E'\n\n';

                IF dryrun IS TRUE THEN
                    RAISE NOTICE 'Query: %', q;
                ELSE
                    EXECUTE q;
                END IF;

            ELSE
                RAISE NOTICE 'Critical table %! Not cleaned', r.fulltable;
            END IF;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_inst_clean_tables(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_inst_clean_tables(boolean) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_inst_clean_tables(boolean) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_inst_clean_tables(boolean) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_inst_clean_tables(boolean) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_inst_clean_tables(boolean)
        IS 'Clean instantaneous data tables';

    -- Funzione di estrazione dei dati istantanei per i vari applicativi del portale
    -- DROP FUNCTION IF EXISTS clients.f_inst_data_extraction(integer, timestamp, timestamp);
    CREATE OR REPLACE FUNCTION clients.f_inst_data_extraction(
        stprid    integer,
        date_from timestamp without time zone,
        date_to   timestamp without time zone
    )
        RETURNS SETOF clients.t_inst_data_function
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE
        ROWS 1000

    AS $BODY$

    DECLARE
        t text;         -- tablename
        p integer;      -- parameter table id
        i integer;      -- parameter id
        d integer;      -- parameter decimals
        q text;         -- dynamic query
    BEGIN
        /* entry */
        RAISE NOTICE 'Function clients.f_inst_data_extraction, stpr_id: %', stprid;

        /* Testing
            SELECT * FROM  clients.f_inst_data_extraction (
                17::integer,
                '2022-01-17 00:00'::timestamp,
                '2022-01-20 00:00'::timestamp
            );
        */

        /* get station properties */
        /* suffix in order to get data from a view es cc, labs */
        SELECT
            station_fulltable||'_inst' AS  station_fulltable, station_param_table_id, parameter_decimals INTO t, p, d
        FROM
            metadata.view_stations_parameters
        WHERE
            station_param_id = stprid;

        RAISE NOTICE 'Function clients.f_inst_data_extraction, tablename: %, parame id: %', t, p;

        /* build main dynamic query */
        q =
        'WITH m AS ('||E'\n'
        ||'    SELECT'||E'\n'
        ||'        * '||E'\n'
        ||'    FROM'||E'\n'
        ||'        generate_series('||quote_literal(date_from)||'::timestamp, '||quote_literal(date_to)||'::timestamp, INTERVAL ''1 minute'') AS measure_date_time'||E'\n'
        ||')'||E'\n\n';

        /* date time */
        q = q
        ||'SELECT'||E'\n'
        ||'    m.measure_date_time AS measure_date_time,'||E'\n';

        /* measures */
        q = q
        ||'    '||p||'::smallint AS measure_id,'||E'\n'
        ||'    t.measure_value::numeric,'||E'\n'
        ||'    NULL::numeric AS measure_min,'||E'\n'
        ||'    NULL::numeric AS measure_max,'||E'\n'
        ||'    t.station_code::smallint AS station_code,'||E'\n'
        ||'    t.measure_code::integer  AS measure_code'||E'\n'
        ||'FROM'||E'\n'
        ||'    m LEFT JOIN '||t||' t ON (m.measure_date_time = t.measure_date_time AND t.measure_id = '||p||')'||E'\n'
        ||'WHERE'||E'\n'
        ||'    m.measure_date_time BETWEEN '||quote_literal(date_from)||' AND '||quote_literal(date_to)||''||E'\n'
        ||'ORDER BY'||E'\n'
        ||'    measure_date_time'||E'\n';

        /* notice */
        RAISE NOTICE 'Query: %', E'\n'||q;

        /* return value */
        RETURN QUERY EXECUTE q;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_inst_data_extraction(): %', SQLERRM;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_inst_data_extraction(integer, timestamp, timestamp) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_inst_data_extraction(integer, timestamp, timestamp) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_inst_data_extraction(integer, timestamp, timestamp) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_inst_data_extraction(integer, timestamp, timestamp) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_inst_data_extraction(integer, timestamp, timestamp)
        IS 'Generic real-time data extraction function';

    -- Funzione di gestione del "post_validity_code"
    -- DROP FUNCTION IF EXISTS clients.f_measure_to_post_validity_code();
    CREATE OR REPLACE FUNCTION clients.f_measure_to_post_validity_code()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$

    DECLARE
        pv_code integer;
    BEGIN
        --RAISE NOTICE 'TRIGGER FUNCTION f_measure_to_post_validity_code';

        /* Default value */
        pv_code := NEW.post_validity_code;

        --RAISE NOTICE 'pv_code: %', pv_code;

        /* OPAS-DL CODES
        -- EnumChannelCode --

        ' imported file by operator
        IMPORTED_FILE = -1

        ' default to valid
        VALID = 0

        ' calibrations result
        SPAN_LOW = 1
        SPAN_HIGH = 2
        ZERO_LOW = 4
        ZERO_HIGH = 8
        CALIBRATION = 16

        ' not valid by user
        NOT_VALID_USER1 = 32 ' manutenzione ordinaria
        NOT_VALID_USER2 = 64 ' manutenzione straordinaria

        ' readings
        MIN_READING_PERC = 128

        ' error from instruments
        INTRUMENT_ERROR = 256

        ' dl
        DETECTION_LIMIT = 512
        MIN_DETECTION_LIMIT = 1024

        ' validations
        MIN_THERSHOLD = 2048
        MAX_THERSHOLD = 4096
        MIN_MEAN = 8192
        'MAX_VARIANCE = 16384

        -- EnumStationAlarm --
        ' codici non implementati, trattati come allarmi
        NORMAL = 0
        SOFTWARE_ERROR = 1
        SYSTEM_RESTART = 2
        LOW_DISK_SPACE = 4
        */

        /* Value measure_code positive
            Positive first because a negative post validity code must win.
            And the ||| operator give back the last value in signh change (
                -1 ||| -2 -> -3   good
                -1 |||  2 ->  2   bad, should wind negative code, invalid data
            )
        */

        /* MANUAL IMPORT FROM (SELF MADE / BY SCRIPTS) FILES */
        IF NEW.measure_code = -1 THEN
            pv_code := 32;
        END IF;

        /* CALIBRATION VALID */
        IF NEW.measure_code & 16 = 16 THEN
            pv_code := pv_code ||| 2;
        END IF;

        /* DETECTION_LIMIT VALID */
        IF NEW.measure_code & 512 = 512 THEN
            pv_code := pv_code ||| 4;
        END IF;

        -- /* MIN_THERSHOLD */
        -- IF NEW.measure_code & 2048 = 2048 THEN
        --     pv_code := pv_code ||| 512;
        -- END IF;

        -- /* MAX_THERSHOLD */
        -- IF NEW.measure_code & 4096 = 4096 THEN
        --     pv_code := pv_code ||| 512;
        -- END IF;

        /* MIN_MEAN */
        IF NEW.measure_code & 8192 = 8192 THEN
            pv_code := pv_code ||| -512;
        END IF;

        /* SOFTWARE_ERROR - NOT IMPLEMENTED
        IF NEW.station_code & 1 = 1 THEN
            pv_code := pv_code ||| 512;
        END IF;
            */

        /* Value measure_code negative
        */

        /* SPAN_LOW */
        IF NEW.measure_code & 1 = 1 THEN
            pv_code := pv_code ||| -16;
        END IF;

        /* SPAN_HIGH */
        IF NEW.measure_code & 2 = 2 THEN
            pv_code := pv_code ||| -16;
        END IF;

        /* ZERO_LOW */
        IF NEW.measure_code & 4 = 4 THEN
            pv_code := pv_code ||| -16;
        END IF;

        /* ZERO_HIGH */
        IF NEW.measure_code & 8 = 8 THEN
            pv_code := pv_code ||| -16;
        END IF;

        /* 32 Invalido da operatore */
        IF NEW.measure_code & 32 = 32 THEN
            pv_code := pv_code ||| -64;
        END IF;

        /* 64 Invalido da operatore */
        IF NEW.measure_code & 64 = 64 THEN
            pv_code := pv_code ||| -64;
        END IF;

        /* MIN_READING_PERC */
        IF NEW.measure_code & 128 = 128 THEN
            pv_code := pv_code ||| -4;
        END IF;

        /* INTRUMENT_ERROR */
        IF NEW.measure_code & 256 = 256 THEN
            pv_code := pv_code ||| -32;
        END IF;

        /* MIN_DETECTION_LIMIT */
        IF NEW.measure_code & 1024 = 1024 THEN
            pv_code := pv_code ||| -8;
        END IF;

        /* Final value */
        NEW.post_validity_code := pv_code;

        /* return value */
        RETURN NEW;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'ERROR IN clients.f_measure_to_post_validity_code() : %', SQLERRM;
                /* return value */
                RETURN NEW;
    END;

    $BODY$;

    -- grants
    ALTER FUNCTION clients.f_measure_to_post_validity_code() OWNER TO postgres;
    GRANT EXECUTE ON FUNCTION clients.f_measure_to_post_validity_code() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_measure_to_post_validity_code() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_measure_to_post_validity_code() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_measure_to_post_validity_code()
        IS 'Generate post validity code base on station code values';

    -- Funzione che salva i valori giornalieri di PM10, PM2.5 e PM1 dello strumento ENVEA MP101M nella prima ora del giorno precedente
    -- DROP FUNCTION IF EXISTS clients.f_mp101m_to_1h();
    CREATE OR REPLACE FUNCTION clients.f_mp101m_to_1h()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$
    DECLARE
        stid           integer;
        prid           integer;
        table_name     varchar;
        query_sql      varchar;
        get_diag       integer;
        frame_wnd      integer;
        frame_wnd_from integer;
        dt             timestamp;
    BEGIN
        --RAISE NOTICE 'FUNCTION f_mp101m_to_1h';

        /*station id passed by caller*/
        stid  := TG_ARGV[0];
        --RAISE NOTICE 'stid: %', stid;

        /*get the parameter id*/
        SELECT INTO prid param_id
        FROM
            metadata.stations_parameters
            LEFT JOIN metadata.stations_params_info USING (stpr_id)
        WHERE
            station_id = stid AND stpr_table_id = NEW.measure_id;
            --AND stpr_info_cadence_fk = 8;
        --RAISE NOTICE 'prid: %', prid;

        /*check exists parameter*/
        -- 47::integer,  PM1
        -- 48::integer,  PM2.5
        -- 50::integer,  PM10
        IF NOT FOUND THEN
            --RAISE NOTICE 'prid not found, eventually diagnostics';
            RETURN NEW;
        ELSIF prid NOT IN (50, 47, 48) THEN
            RETURN NEW;
        END IF;
        --RAISE NOTICE 'Id PM10/2.5/1 Found';

        /*get hour to check against a frame*/
        SELECT INTO frame_wnd date_part('hour', NEW.measure_date_time);
        --RAISE NOTICE 'frame window: %', frame_wnd;

        /* data frame and code check */
        frame_wnd_from = 2;
        --RAISE NOTICE 'frame window from hour: %', frame_wnd_from;

        /* frame check */
        IF frame_wnd BETWEEN frame_wnd_from AND 22 THEN
            --RAISE NOTICE 'data in frame, insert data';

            /* get previous day date time */
            dt := NEW.measure_date_time - interval '24 hour';
            dt := date_trunc('day', dt);

            /* check if a data as already been inserted */
            EXECUTE format('SELECT * FROM %I.%I WHERE measure_date_time = %L AND measure_id = %L',
               TG_TABLE_SCHEMA, TG_TABLE_NAME, dt, NEW.measure_id);
            GET DIAGNOSTICS get_diag = ROW_COUNT;

            /* count check */
            IF get_diag = 0 THEN
                --RAISE NOTICE 'dt %', dt;
                NEW.measure_date_time := dt;

            ELSE
                --RAISE NOTICE 'Data already inserted';
                RETURN NULL;

            END IF; /*IF get_diag = 0 THEN*/

        ELSE
            /* not in frame, skip insert */
            --RAISE NOTICE 'Out of hour frame, nothing to do, return NULL';
            RETURN NULL;

        END IF; /*IF frame_wnd BETWEEN 6 AND 22 THEN*/

        /* return value */
        RETURN NEW;

        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR IN clients.f_mp101m_to_1h() : %', SQLERRM;
            /* return value */
            RETURN NEW;
    END;
    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_mp101m_to_1h() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_mp101m_to_1h() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_mp101m_to_1h() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_mp101m_to_1h()
        IS 'Store PM10/2.5/1 daily value into first hour of previous day';

    -- Function which, starting from the data entered by the operator in the manual calibration reports,
    -- calculates the data to insert into the tables common to automatic calibrations
    -- DROP FUNCTION IF EXISTS clients.f_refresh_calibrations_by_user();
    CREATE OR REPLACE FUNCTION clients.f_refresh_calibrations_by_user(
        )
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        r record;

        q text;     -- fixed sql for insert
        zr numeric = 0;  -- zero reference
        zt numeric = 1;  -- zero tolerance ppb
        st numeric = 5; -- span tolerance %
        t  numeric; -- tolerance      ppb
        rc integer; -- result code

        i integer; -- measure id
        c integer; -- calibration id (nextval)
    BEGIN
        /**
        * Function which, starting from the data entered by the operator in the manual calibration reports,
        * calculates the data to insert into the tables common to automatic calibrations.
        * In this way, data are visualized inside the CC panels in Visualizer or Analyser
        * ! USED BY VDA ONLY !
        *
        * TEST SELECT clients.f_refresh_calibrations_by_user();
        */

        -- loop through all active stations and get last available alarms
        FOR r IN (
            SELECT
                calib_id,
                us_id,
                c.station_id,
                c.instr_id,
                si.stpr_group_id,
                calib_fulldate,
                calib_re_id,
                calib_multipoint,
                calib_values,
                calib_note,

                -- so2
                case when (calib_values->'find-zero-so2'  )::text <> '""' then regexp_replace((calib_values->'find-zero-so2'  )::text, '"', '', 'g')::real else null end as so2_zero,
                case when (calib_values->'read-span-so2'  )::text <> '""' then regexp_replace((calib_values->'read-span-so2'  )::text, '"', '', 'g')::real else null end as so2_span_read,
                case when (calib_values->'theory-span-so2')::text <> '""' then regexp_replace((calib_values->'theory-span-so2')::text, '"', '', 'g')::real else null end as so2_span_val,

                -- co
                case when (calib_values->'find-zero-co'  )::text <> '""' then regexp_replace((calib_values->'find-zero-co'  )::text, '"', '', 'g')::real else null end as co_zero,
                case when (calib_values->'read-span-co'  )::text <> '""' then regexp_replace((calib_values->'read-span-co'  )::text, '"', '', 'g')::real else null end as co_span_read,
                case when (calib_values->'theory-span-co')::text <> '""' then regexp_replace((calib_values->'theory-span-co')::text, '"', '', 'g')::real else null end as co_span_val,

                -- o3
                case when (calib_values->'find-zero-o3'  )::text <> '""' then regexp_replace((calib_values->'find-zero-o3'  )::text, '"', '', 'g')::real else null end as o3_zero,
                case when (calib_values->'read-span-o3'  )::text <> '""' then regexp_replace((calib_values->'read-span-o3'  )::text, '"', '', 'g')::real else null end as o3_span_read,
                case when (calib_values->'theory-span-o3')::text <> '""' then regexp_replace((calib_values->'theory-span-o3')::text, '"', '', 'g')::real else null end as o3_span_val,

                -- nox
                case when (calib_values->'nox-zero-noxnono2')::text <> '""' then regexp_replace((calib_values->'nox-zero-noxnono2')::text, '"', '', 'g')::real else null end as nox_zero,
                case when (calib_values->'no-zero-noxnono2' )::text <> '""' then regexp_replace((calib_values->'no-zero-noxnono2' )::text, '"', '', 'g')::real else null end as no_zero,
                case when (calib_values->'no2-zero-noxnono2')::text <> '""' then regexp_replace((calib_values->'no2-zero-noxnono2')::text, '"', '', 'g')::real else null end as no2_zero,

                case when (calib_values->'read-nox-span-noxnono2')::text <> '""' then regexp_replace((calib_values->'read-nox-span-noxnono2')::text, '"', '', 'g')::real else null end as nox_span_read,
                case when (calib_values->'read-no-span-noxnono2' )::text <> '""' then regexp_replace((calib_values->'read-no-span-noxnono2' )::text, '"', '', 'g')::real else null end as no_span_read,
                case when (calib_values->'read-no2-span-noxnono2')::text <> '""' then regexp_replace((calib_values->'read-no2-span-noxnono2')::text, '"', '', 'g')::real else null end as no2_span_read,

                case when (calib_values->'theory-nox-span-noxnono2')::text <> '""' then regexp_replace((calib_values->'theory-nox-span-noxnono2')::text, '"', '', 'g')::real else null end as nox_span_val,
                case when (calib_values->'theory-no-span-noxnono2' )::text <> '""' then regexp_replace((calib_values->'theory-no-span-noxnono2' )::text, '"', '', 'g')::real else null end as no_span_val,
                case when (calib_values->'theory-no2-span-noxnono2')::text <> '""' then regexp_replace((calib_values->'theory-no2-span-noxnono2')::text, '"', '', 'g')::real else null end as no2_span_val

            FROM
                reports.calibrations c
                LEFT JOIN metadata.stations_instruments si ON (si.instr_id = c.instr_id AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> c.calib_fulldate)
            WHERE
                calib_insert_time > current_timestamp - interval '25 hours'
                AND c.station_id IN(
                    select station_id from metadata.stations_info where st_info_network_type_fk = 1
                )
                AND calib_multipoint IS FALSE
                --AND st.station_active IS TRUE
                --AND ss.ss_suspended IS FALSE
            ) LOOP

            /*
            calibration_id integer NOT NULL,
            calibration_date_time timestamp without time zone NOT NULL,
            station_id integer NOT NULL,
            measure_id smallint NOT NULL,
            calibration_type text COLLATE pg_catalog."default" NOT NULL,
            calibration_step text COLLATE pg_catalog."default" NOT NULL,
            reference_value real NOT NULL,
            defect_value real NOT NULL,
            result_code smallint NOT NULL,
            result_value real NOT NULL,
            */

            -- calibration_id        -> get next val - SELECT nextval('clients.calibrations_id_seq'::regclass);
            -- calibration_date_time -> calib_fulldate
            -- station_id            -> station_id
            -- measure_id            -> par_zero | par_span
            -- calibration_type      -> USER (USER | AUTO)
            -- calibration_step      -> ZERO,SPAN (par_zero | par_span) (ZERO | SPAN | PURGE | UNKNOWN)
            -- reference_value       -> theory_xxx
            -- defect_value          -> 10%
            -- result_code           -> calculated (16  CALIBRATION || {1 SPAN_LOW - 2 SPAN_HIGH - 4 ZERO_LOW - 8 ZERO_HIGH})
            -- result_value          -> read_xxx

            /*

            template = 'INSERT INTO %s (bla bla)
                station_id = %L
            '

            -- span & zero --
                c
                fulldate
                station_id
                stpr_table_id
                USER
                SPAN|ZERO
                VALORE TEORICO
                10 %
                16 | code
                VALORE LETTO
            */
            q= 'INSERT INTO clients.calibrations_result VALUES ('||E'\n'
                ||'    %L,'||E'\n'         -- CALIB ID
                ||'    '||quote_literal(r.calib_fulldate)||','||E'\n'
                ||'    '||r.station_id||','||E'\n'
                ||'     %L,'||E'\n'        -- MEASURE ID
                ||'    ''USER'','||E'\n'
                ||'     %L,'||E'\n'        -- SPAN / ZERO
                ||'     %L,'||E'\n'        -- VALORE TEORICO
                ||'     %L,'||E'\n'        -- TOLLERANZA
                ||'     %L,'||E'\n'        -- CODICE
                ||'     %L '||E'\n'        -- VALORE LETTO
                ||') ON CONFLICT DO NOTHING;'||E'\n\n';

            -- !! parameter SO2 (29) SPAN
            IF (r.so2_span_val IS NOT NULL AND r.so2_span_read IS NOT NULL) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 29 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;

                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'so2_span_val: %', r.so2_span_val;
                RAISE NOTICE 'so2_span_read: %', r.so2_span_read;

                rc := 16;
                t := (r.so2_span_val * st) / 100;

                IF r.so2_span_read < (r.so2_span_val - t) THEN
                    rc := rc | 1; -- LOW
                ELSIF r.so2_span_read > (r.so2_span_val + t) THEN
                    rc := rc | 2; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'SPAN', r.so2_span_val, st, rc, r.so2_span_read);

            END IF;

            -- !! parameter SO2 (29) ZERO
            IF (r.so2_zero IS NOT NULL ) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 29 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'so2_zero: %', r.so2_zero;

                rc := 16;

                IF r.so2_zero < zr THEN
                    rc := rc | 4; -- LOW
                ELSIF r.so2_zero > zt THEN
                    rc := rc | 8; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'ZERO', zr, zt, rc, r.so2_zero);

            END IF;

            -----------------------------------------------------------------------------------------------

            -- !! parameter CO (33) SPAN
            IF (r.co_span_val IS NOT NULL AND r.co_span_read IS NOT NULL) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 33 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'co_span_val: %', r.co_span_val;
                RAISE NOTICE 'co_span_read: %', r.co_span_read;

                rc := 16;
                t := (r.co_span_val * st) / 100;

                IF r.co_span_read < (r.co_span_val - t) THEN
                    rc := rc | 1; -- LOW
                ELSIF r.co_span_read > (r.co_span_val + t) THEN
                    rc := rc | 2; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'SPAN', r.co_span_val, st, rc, r.co_span_read);

            END IF;

            -- !! parameter CO (33) ZERO
            IF (r.co_zero IS NOT NULL ) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 33 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'co_zero: %', r.co_zero;

                rc := 16;

                IF r.co_zero < zr THEN
                    rc := rc | 4; -- LOW
                ELSIF r.co_zero > zt THEN
                    rc := rc | 8; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'ZERO', zr, zt, rc, r.co_zero);

            END IF;

            -----------------------------------------------------------------------------------------------

            -- !! parameter O3 (34) SPAN
            IF (r.o3_span_val IS NOT NULL AND r.o3_span_read IS NOT NULL) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 34 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'o3_span_val: %', r.o3_span_val;
                RAISE NOTICE 'o3_span_read: %', r.o3_span_read;

                rc := 16;
                t := (r.o3_span_val * st) / 100;

                IF r.o3_span_read < (r.o3_span_val - t) THEN
                    rc := rc | 1; -- LOW
                ELSIF r.o3_span_read > (r.o3_span_val + t) THEN
                    rc := rc | 2; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'SPAN', r.o3_span_val, st, rc, r.o3_span_read);

            END IF;

            -- !! parameter O3 (34) ZERO
            IF (r.o3_zero IS NOT NULL ) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 34 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'o3_zero: %', r.o3_zero;

                rc := 16;

                IF r.o3_zero < zr THEN
                    rc := rc | 4; -- LOW
                ELSIF r.o3_zero > zt THEN
                    rc := rc | 8; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'ZERO', zr, zt, rc, r.o3_zero);

            END IF;

            -----------------------------------------------------------------------------------------------

            -- !! parameter NOx (30) SPAN
            IF (r.nox_span_val IS NOT NULL AND r.nox_span_read IS NOT NULL) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 30 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'nox_span_val: %', r.nox_span_val;
                RAISE NOTICE 'nox_span_read: %', r.nox_span_read;

                rc := 16;
                t := (r.nox_span_val * st) / 100;

                IF r.nox_span_read < (r.nox_span_val - t) THEN
                    rc := rc | 1; -- LOW
                ELSIF r.nox_span_read > (r.nox_span_val + t) THEN
                    rc := rc | 2; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'SPAN', r.nox_span_val, st, rc, r.nox_span_read);

            END IF;

            -- !! parameter NOx (30) ZERO
            IF (r.nox_zero IS NOT NULL ) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 30 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'nox_zero: %', r.nox_zero;

                rc := 16;

                IF r.nox_zero < zr THEN
                    rc := rc | 4; -- LOW
                ELSIF r.nox_zero > zt THEN
                    rc := rc | 8; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'ZERO', zr, zt, rc, r.nox_zero);

            END IF;

            -- !! parameter NO (31) SPAN
            IF (r.no_span_val IS NOT NULL AND r.no_span_read IS NOT NULL) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 31 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'no_span_val: %', r.no_span_val;
                RAISE NOTICE 'no_span_read: %', r.no_span_read;

                rc := 16;
                t := (r.no_span_val * st) / 100;

                IF r.no_span_read < (r.no_span_val - t) THEN
                    rc := rc | 1; -- LOW
                ELSIF r.no_span_read > (r.no_span_val + t) THEN
                    rc := rc | 2; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'SPAN', r.no_span_val, st, rc, r.no_span_read);

            END IF;

            -- !! parameter NO (31) ZERO
            IF (r.no_zero IS NOT NULL ) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 31 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'no_zero: %', r.no_zero;

                rc := 16;

                IF r.no_zero < zr THEN
                    rc := rc | 4; -- LOW
                ELSIF r.no_zero > zt THEN
                    rc := rc | 8; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'ZERO', zr, zt, rc, r.no_zero);

            END IF;

            -- !! parameter NO2 (32) SPAN
            IF (r.no2_span_val IS NOT NULL AND r.no2_span_read IS NOT NULL) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 32 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'no2_span_val: %', r.no2_span_val;
                RAISE NOTICE 'no2_span_read: %', r.no2_span_read;

                rc := 16;
                t := (r.no2_span_val * st) / 100;

                IF r.no2_span_read < (r.no2_span_val - t) THEN
                    rc := rc | 1; -- LOW
                ELSIF r.no2_span_read > (r.no2_span_val + t) THEN
                    rc := rc | 2; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'SPAN', r.no2_span_val, st, rc, r.no2_span_read);

            END IF;

            -- !! parameter NO2 (32) ZERO
            IF (r.no2_zero IS NOT NULL ) THEN
                -- get next calibration id
                SELECT nextval('clients.calibrations_id_seq'::regclass) INTO c;
                RAISE NOTICE 'Calib Id: %', c;

                -- get measure id
                SELECT stpr_table_id FROM metadata.stations_parameters sp WHERE sp.station_id = r.station_id AND sp.stpr_group_id = r.stpr_group_id AND param_id = 32 INTO i;
                IF NOT FOUND THEN
                    RAISE NOTICE 'Measure Id not found';
                    CONTINUE;
                END IF;
                RAISE NOTICE 'Measure Id: %', i;

                RAISE NOTICE 'no2_zero: %', r.no2_zero;

                rc := 16;

                IF r.no2_zero < zr THEN
                    rc := rc | 4; -- LOW
                ELSIF r.no2_zero > zt THEN
                    rc := rc | 8; -- HIGH
                ELSE
                    -- do nothing
                END IF;

                EXECUTE format(q, c, i, 'ZERO', zr, zt, rc, r.no2_zero);

            END IF;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_calibrations_by_user(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_calibrations_by_user() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_calibrations_by_user() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_calibrations_by_user() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_calibrations_by_user() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_calibrations_by_user()
        IS 'Refresh table with latest strumental warnings';

    -- Funzione che aggiorna la tabella di copertura dei dati con le ultime statistiche disponibili
    -- DROP FUNCTION IF EXISTS clients.f_refresh_data_coverage();
    CREATE OR REPLACE FUNCTION clients.f_refresh_data_coverage(
    )
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        y   smallint;
        q   text;
        rec record;
    BEGIN
        /* get two years ago */
        SELECT INTO y EXTRACT('year' FROM current_date - interval '2 year');

        /* dete old records before inserting data */
        DELETE FROM clients.data_coverage WHERE measure_year >= y;

        /* loop through all stations and parameters */
        FOR rec IN
            SELECT
                st.station_name,
                st.station_id,
                st.station_schema || '.'::text || COALESCE(st.station_prefix, ''::text) || st.station_table AS station_fulltable,
                sp.stpr_table_id
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.stations st USING(station_id)
                LEFT JOIN metadata.stations_info si USING(station_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
            WHERE
                station_active IS true
                AND si.st_info_roaming_type_fk IN (1,2)
                AND si.st_info_typology_fk != 6 -- Magazzino
                AND pi.pm_info_type_fk IN (1,2,3)
            ORDER BY
                station_id, stpr_table_id
        LOOP
            RAISE NOTICE 'Station: %, parame id: %', rec.station_name, rec.stpr_table_id;
            /* create dynamic query */
            q := 'INSERT INTO'||E'\n'
            || 'clients.data_coverage ('||E'\n'
            || '    measure_year, measure_month, station_id, measure_id, measure_perc, measure_validity_perc'||E'\n'
            || ')'||E'\n'
            || 'SELECT'||E'\n'
            || '    extract(year from measure_date_time) as yyyy,'||E'\n'
            || '    extract(month from measure_date_time) as mm,'||E'\n'
            || '    max('||rec.station_id||'),'||E'\n'
            || '    max('||rec.stpr_table_id||'),'||E'\n'
            || '    LEAST(COALESCE((SUM(extract_code) /'||E'\n'
            || '    (MAX(main.f_num_days_inmonth(extract(year from measure_date_time)::integer, extract(month from measure_date_time)::integer)*24)) *100)::integer, 0), 100),'||E'\n'
            || '    LEAST(COALESCE((SUM(extract_code) FILTER ( WHERE post_validity_code > -1 )/'||E'\n'
            || '    (max(main.f_num_days_inmonth(extract(year from measure_date_time)::integer, extract(month from measure_date_time)::integer)*24)) *100)::integer, 0), 100)'||E'\n'
            || 'FROM'||E'\n'
            || '   '||rec.station_fulltable||E'\n'
            || 'WHERE'||E'\n'
            || '    measure_id = '||rec.stpr_table_id||E'\n'
            || '    and measure_date_time >= '''||y||'-01-01'''||E'\n'
            || 'GROUP BY 1,2'||E'\n'
            || 'ORDER BY 1,2 ';

            /* execute the insert query */
            --RAISE NOTICE 'Query : %', q;
            EXECUTE q;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_data_coverage(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_data_coverage() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_data_coverage() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_data_coverage() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_data_coverage() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_data_coverage()
        IS 'Refresh data coverage table with latest stats';

    -- Funzione che aggiorna i dati visualizzati dall'applicativo "Dataview" agli ultimi disponibili
    -- DROP FUNCTION IF EXISTS clients.f_refresh_dataview_lastdata();
    CREATE OR REPLACE FUNCTION clients.f_refresh_dataview_lastdata(
        )
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        ids int[] := '{29, 30, 31, 32, 33, 34, 38, 46, 47, 48, 49, 50}';
        i integer;
            -- 30 -> NOx
            -- 31 -> NO
            -- 32 -> NO2
            -- 33 -> CO
            -- 34 -> O3
            -- 29 -> SO2
            -- 47 -> PM1 (Fidas)
            -- 48 -> PM2.5 (Fidas)
            -- 49 -> PM4 (Fidas)
            -- 50 -> PM10 (Fidas)
            -- 46 -> PMtotal (Fidas)
    BEGIN
        /* TEST */
        /* SELECT clients.f_refresh_dataview_lastdata(); */

        /*loop through all parameters*/
        FOREACH i IN ARRAY ids LOOP

            RAISE NOTICE 'Parameter param_id: %', i;

            DELETE FROM clients.dataview_lastdata WHERE param_id = i;

            -- integer, integer, real, real
            WITH t AS (
                SELECT DISTINCT station_id,
                    param_id,
                    stpr_id
                FROM
                    metadata.stations_parameters sp
                WHERE param_id = i
                AND EXISTS (
                    SELECT 1
                    FROM
                        metadata.stations_instruments si
                    WHERE
                        si.stpr_group_id = sp.stpr_group_id
                        AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                        AND si.stin_master IS TRUE
                )
            )
            INSERT INTO clients.dataview_lastdata
                SELECT
                    t.station_id,
                    t.param_id,
                    CASE
                        WHEN t.param_id IN (48, 50) THEN clients.f_get_last_param_data(t.stpr_id, 'dd'::metadata.e_aggregations)   -- PM10 e PM2.5
                        ELSE clients.f_get_last_param_data(t.stpr_id, 'hh'::metadata.e_aggregations)
                    END AS marker_value
                FROM
                    t
                ORDER BY
                    t.station_id
            ON CONFLICT ON CONSTRAINT clients_dataview_lastdata_pkey DO NOTHING;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_dataview_lastdata(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_dataview_lastdata() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_dataview_lastdata() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_dataview_lastdata() TO group_tools;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_dataview_lastdata() TO group_readonly;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_dataview_lastdata()
        IS 'Refresh table with latest data used by dataview';

    -- Funzione che aggiorna i dati degli strumenti agli ultimi disponibili
    -- DROP FUNCTION IF EXISTS clients.f_refresh_last_instruments_update();
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

            WITH p AS (
                SELECT
                    COALESCE(stpr_group_id, 99999) AS stpr_group_id,
                    station_id,
                    ARRAY_AGG(stpr_table_id) AS table_ids
                FROM
                    metadata.stations_parameters sp
                    LEFT JOIN metadata.parameters_info pi USING (param_id)
                WHERE
                    -- meteo, chimici, polveri, allarmi
                    pm_info_type_fk IN (1,2,3,13,14)
                    -- group id null oppure parametri Porta aperta, Temp. Cabina
                    AND ( stpr_group_id NOTNULL OR param_id IN (138, 163))
                    AND stpr_active IS TRUE
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
                    AND (vi.category_id BETWEEN 1 AND 18 OR vi.category_id IN (20, 21, 22, 24))
            UNION ALL
                SELECT
                    p.station_id,
                    s.station_name,
                    p.stpr_group_id,
                    s.station_schema||'.'||COALESCE(s.station_prefix, '')||s.station_table AS station_fulltable,
                    table_ids,
                    'Kit Stazione' AS instrument_fullname,
                    'Staz.'        AS category_short_name
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

        /* return value */
        RETURN TRUE;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_last_instruments_update(): %', SQLERRM;
            RETURN FALSE;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_last_instruments_update() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_last_instruments_update() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_last_instruments_update() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_last_instruments_update() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_last_instruments_update()
        IS 'Refresh table with latest instruments updates';

    -- Funzione di aggiornamento della tabella degli relativa ad eventuali ritadi delle stazioni
    -- DROP FUNCTION IF EXISTS clients.f_refresh_station_last_update();
    CREATE OR REPLACE FUNCTION clients.f_refresh_station_last_update()
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        r record;
        q text;
    BEGIN
        -- TEST SELECT clients.f_refresh_station_last_update();

        -- loop through all active stations and get last available measure_date_time
        DELETE FROM clients.stations_last_update;

        FOR r IN (
            SELECT
                st.station_id,
                ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable
            FROM
                metadata.stations st
                LEFT JOIN metadata.stations_status ss USING (station_id)
                LEFT JOIN metadata.stations_info si USING (station_id)
            WHERE
                st.station_id >= 1000
                AND st.station_active IS TRUE
                AND ss.ss_suspended IS FALSE
                AND st_info_roaming_type_fk IN (1,2) -- stazioni fisse e mobili
                AND si.st_info_typology_fk != 6 -- Magazzino
            ORDER BY station_id
        ) LOOP

            -- RAISE NOTICE 'Looping station % ...', r.station_id;

            q = 'INSERT INTO clients.stations_last_update'||E'\n'
                ||'SELECT '||E'\n'
                ||'   '||r.station_id||','||E'\n'
                ||'   COALESCE( MAX(measure_date_time)::text, TO_CHAR(CURRENT_TIMESTAMP, ''YYYY-01-01''))::timestamp'||E'\n'
                ||'FROM '||r.station_fulltable||' '||E'\n'
                ||'WHERE measure_id IN ('||E'\n'
                ||'    SELECT stpr_table_id'||E'\n'
                ||'    FROM metadata.stations_parameters sp'||E'\n'
                ||'    LEFT JOIN metadata.parameters_info pi USING (param_id)'||E'\n'
                ||'    WHERE station_id = '||r.station_id||' '||E'\n'
                ||'    AND pi.pm_info_type_fk NOT IN (13,14,18)'||E'\n' -- all except alarms, diagnostics and limits
                ||'    OR stpr_table_id IN(5027,5077,5127)'||E'\n' -- Volume Ingresso     5027 5077 5127
                -- ||'    OR stpr_table_id IN(5040,5090,5140)'||E'\n' -- Stato campionamento 5040 5090 5140
                ||')'||E'\n\n';

            --RAISE NOTICE 'Query: %', q;
            BEGIN
                EXECUTE q;
            EXCEPTION
                WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_station_last_update(): %', SQLERRM;
            END;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_station_last_update(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_station_last_update() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_station_last_update() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_station_last_update() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_station_last_update() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_station_last_update()
        IS 'Refresh table with latest measure_date_time used by alarms';

    -- Funzione di aggiornamento dei dati dello strumento TECORA di una determinata stazione
    -- DROP FUNCTION IF EXISTS clients.f_refresh_tecora_data(integer);
    CREATE OR REPLACE FUNCTION clients.f_refresh_tecora_data(st_id integer)
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 1000
    AS $BODY$

    DECLARE
        tablename text;
    BEGIN
        /*get tablename*/
        SELECT metadata.f_get_tablename_by_stationid(st_id) INTO tablename;
        RAISE NOTICE 'Insert data into table: %', tablename;

        /*insert data query*/
        EXECUTE format('
        INSERT INTO %s (measure_date_time, measure_id, measure_value, extract_code)
        (
            WITH t AS (
                SELECT
                    fulldate AS measure_date_time,
                    average_flow_rate_qa ::numeric AS measure_value_3151,
                    actual_volume        ::numeric AS measure_value_3155,
                    aver_ambient_temp    ::numeric AS measure_value_3159,
                    etimed_mass_conc     ::numeric AS measure_value_3165,

                    average_flow_rate_qs ::numeric AS measure_value_3150,
                    deviation_flowrate_cv::numeric AS measure_value_3152,
                    gas_meter_volume     ::numeric AS measure_value_3153,
                    standard_volume      ::numeric AS measure_value_3154,
                    aver_temp_gas_met    ::numeric AS measure_value_3156,
                    max_ambient_temp     ::numeric AS measure_value_3157,
                    min_ambient_temp     ::numeric AS measure_value_3158,
                    max_ambient_press    ::numeric AS measure_value_3160,
                    min_ambient_press    ::numeric AS measure_value_3161,
                    aver_ambient_press   ::numeric AS measure_value_3162,
                    max_diff_pressure    ::numeric AS measure_value_3163,
                    concentraion_coeff   ::numeric AS measure_value_3164

                FROM
                    clients.tecora_data
                WHERE
                    station_id = %L
                AND
                    fulldate > CURRENT_DATE - INTERVAL ''7 days''
            )
            SELECT measure_date_time, 3151::smallint, measure_value_3151, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3155::smallint, measure_value_3155, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3159::smallint, measure_value_3159, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3165::smallint, measure_value_3165, 24::smallint FROM t

            UNION ALL
            SELECT measure_date_time, 3150::smallint, measure_value_3150, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3152::smallint, measure_value_3152, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3153::smallint, measure_value_3153, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3154::smallint, measure_value_3154, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3156::smallint, measure_value_3156, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3157::smallint, measure_value_3157, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3158::smallint, measure_value_3158, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3160::smallint, measure_value_3160, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3161::smallint, measure_value_3161, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3162::smallint, measure_value_3162, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3163::smallint, measure_value_3163, 24::smallint FROM t
            UNION ALL
            SELECT measure_date_time, 3164::smallint, measure_value_3164, 24::smallint FROM t
        )
        ON CONFLICT DO NOTHING', tablename, st_id);

        /*return value*/
        RETURN true;

        /*errors*/
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_tecora_data(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    ALTER FUNCTION clients.f_refresh_tecora_data(integer) OWNER TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_tecora_data(integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_tecora_data(integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_tecora_data(integer)
        IS 'Refresh tecora data from tecora table to destination one';

    -- Funzione di aggiornamento degli ultimi allarmi strumentali (strumento DERENDA)
    -- DROP FUNCTION IF EXISTS clients.f_refresh_warnings_derenda();
    CREATE OR REPLACE FUNCTION clients.f_refresh_warnings_derenda()
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        r record;
        q text;
        i text;
    BEGIN
        /*
         * TEST SELECT clients.f_refresh_warnings_derenda();
         */

        -- midnight run 1 week in the past to catch up late data
        IF EXTRACT(HOUR FROM CURRENT_TIMESTAMP) = 0 THEN
            i = '7 days';
        ELSE
            i = '2 days'; -- 2 days to catch diagnostics data wich is stored @ 00:00:00
        END IF;

        -- loop through all active stations and get last avaible alarms
        FOR r IN (
            SELECT
                st.station_id,
                ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable
            FROM
                metadata.stations st
                LEFT JOIN metadata.stations_status ss USING (station_id)
                LEFT JOIN metadata.stations_info si USING (station_id)
            WHERE
                st.station_schema = 'client_ero_samplers'
                AND st.station_id >= 1000 -- below system station, reserved
                AND st.station_active IS TRUE
                AND ss.ss_suspended IS NOT TRUE -- (no NULL or FALSE)
                AND si.st_info_typology_fk != 6 -- Magazzino
        ) LOOP

            -- RAISE NOTICE 'Looping station % ...', r.station_id;

            q = 'WITH temp as ('||E'\n'
            ||'    SELECT *'||E'\n'
            ||'    FROM '||r.station_fulltable||' '||E'\n'
            ||'    WHERE measure_id = 12'||E'\n'
            ||'    AND measure_value > 0 '||E'\n' -- Status Alarm
            ||'    AND measure_date_time > CURRENT_TIMESTAMP - interval '||quote_literal(i)||' '||E'\n'
            ||')'||E'\n'
            ||'INSERT INTO clients.derenda_warnings'||E'\n'
            ||'    (fulldate, station_id, warning_id)'||E'\n'
            ||'('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        measure_date_time,'||E'\n'
            ||'        '||r.station_id||','||E'\n'
            ||'        measure_value'||E'\n'
            ||'    FROM temp'||E'\n'
            ||'    ORDER BY measure_date_time'||E'\n'
            ||')'||E'\n'
            ||'ON CONFLICT DO NOTHING;'||E'\n\n';

            --RAISE NOTICE 'Query: %', q;
            EXECUTE q;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_warnings_derenda(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_derenda() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_derenda() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_derenda() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_derenda() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_warnings_derenda()
        IS 'Refresh table with latest strumental warnings';

    -- Funzione di aggiornamento degli ultimi allarmi strumentali (strumento ENVEA MP101M)
    -- DROP FUNCTION IF EXISTS clients.f_refresh_warnings_envea();
    CREATE OR REPLACE FUNCTION clients.f_refresh_warnings_envea()
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        r record;
        q text;
        i text;
    BEGIN
        /*
         * TEST SELECT clients.f_refresh_warnings_envea();
         */

        -- midnight run 1 week in the past to catch up late data
        IF EXTRACT(HOUR FROM CURRENT_TIMESTAMP) = 0 THEN
            i = '7 days';
        ELSE
            i = '2 days'; -- 2 days to catch diagnostics data wich is stored @ 00:00:00
        END IF;

        -- loop through all active stations and get last avaible alarms
        FOR r IN (
            SELECT
                st.station_id,
                ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable,
                sp.stpr_table_id
            FROM
                metadata.stations st
                LEFT JOIN metadata.stations_status ss USING (station_id)
                LEFT JOIN metadata.stations_parameters sp USING (station_id)
                LEFT JOIN metadata.stations_info si USING (station_id)
            WHERE
                st.station_id >= 1000 -- below system station, reserved
                AND st.station_active IS TRUE
                AND ss.ss_suspended IS NOT TRUE -- (no NULL or FALSE)
                AND si.st_info_typology_fk != 6 -- Magazzino
                AND sp.param_id = 929           -- 929 [MP101] Status Code
        ) LOOP

            -- RAISE NOTICE 'Looping station % ...', r.station_id;

            q = 'WITH temp as ('||E'\n'
            ||'    SELECT *'||E'\n'
            ||'    FROM '||r.station_fulltable||' '||E'\n'
            ||'    WHERE measure_id = '||r.stpr_table_id||E'\n'
            ||'    AND measure_value <> 512 '||E'\n' -- Status Alarm 512 OK -> MEASURE
            ||'    AND measure_date_time > CURRENT_TIMESTAMP - interval '||quote_literal(i)||' '||E'\n'
            ||')'||E'\n'
            ||'INSERT INTO clients.envea_warnings'||E'\n'
            ||'    (fulldate, station_id, warning_id)'||E'\n'
            ||'('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        measure_date_time,'||E'\n'
            ||'        '||r.station_id||','||E'\n'
            ||'        measure_value'||E'\n'
            ||'    FROM temp'||E'\n'
            ||'    ORDER BY measure_date_time'||E'\n'
            ||')'||E'\n'
            ||'ON CONFLICT DO NOTHING;'||E'\n\n';

            --RAISE NOTICE 'Query: %', q;
            EXECUTE q;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_warnings_envea(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_envea() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_envea() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_envea() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_envea() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_warnings_envea()
        IS 'Refresh table with latest strumental warnings';

    -- Funzione di aggiornamento degli ultimi allarmi strumentali (strumento PALAS FIDAS)
    -- DROP FUNCTION IF EXISTS clients.f_refresh_warnings_fidas();
    CREATE OR REPLACE FUNCTION clients.f_refresh_warnings_fidas(
    )
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        r record;
        q text;
        p text;
    BEGIN
        -- TEST SELECT clients.f_refresh_warnings_fidas();

        IF EXTRACT(HOUR FROM CURRENT_TIMESTAMP) = 0 THEN
            p = '7 days';
        ELSE
            p = '2 days'; -- 2 days to catch diagnostics data wich is stored @ 00:00:00
        END IF;

        p = '2 months';

        -- loop through all active stations and get last avaible alarms
        FOR r IN (
            SELECT
                st.station_id,
                ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable
            FROM
                metadata.stations st
                LEFT JOIN metadata.stations_status ss USING (station_id)
                LEFT JOIN metadata.stations_info si USING (station_id)
            WHERE
                st.station_id >= 1000 -- below system station, reserved
                AND st.station_active IS TRUE
                AND ss.ss_suspended IS FALSE
                AND si.st_info_typology_fk != 6 -- Magazzino
        ) LOOP

            -- RAISE NOTICE 'Looping station % ...', r.station_id;

            q= 'WITH temp as ('||E'\n'
            ||'    SELECT *'||E'\n'
            ||'    FROM '||r.station_fulltable||' '||E'\n'
            ||'    WHERE measure_id IN ('||E'\n'
            ||'        2556'||E'\n'
            ||'    )'||E'\n'
            ||'    AND measure_value != 0 '||E'\n'
            ||'    AND measure_date_time > CURRENT_TIMESTAMP - interval '||quote_literal(p)||' '||E'\n'
            ||')'||E'\n'
            ||'INSERT INTO clients.fidas_warnings (fulldate, station_id, bit_mask) ('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        measure_date_time AS fulldate,'||E'\n'
            ||'        '||r.station_id||' AS station_id,'||E'\n'
            ||'        (measure_max::integer)::bit(8) AS bit_mask'||E'\n'
            ||'    FROM temp'||E'\n'
            ||'    ORDER BY measure_date_time )'||E'\n'
            ||'ON CONFLICT ON CONSTRAINT clients_fidas_warnings_ukey DO NOTHING;'||E'\n\n';

            --RAISE NOTICE 'Query: %', q;
            EXECUTE q;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_warnings_fidas(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_fidas() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_fidas() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_fidas() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_fidas() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_warnings_fidas()
        IS 'Refresh table with latest strumental warnings';

    -- Funzione di aggiornamento degli ultimi allarmi strumentali (strumento METONE BC 1054)
    -- DROP FUNCTION IF EXISTS clients.f_refresh_warnings_metone();
    CREATE OR REPLACE FUNCTION clients.f_refresh_warnings_metone()
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        r record;
        q text;
        i text;
    BEGIN
        /*
         * TEST SELECT clients.f_refresh_warnings_metone();
         */

        -- midnight run 1 week in the past to catch up late data
        IF EXTRACT(HOUR FROM CURRENT_TIMESTAMP) = 0 THEN
            i = '14 days';
        ELSE
            i = '7 days';
        END IF;

        -- loop through all active stations and get last avaible alarms
        FOR r IN (
            SELECT
                st.station_id,
                ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable,
                sp.stpr_table_id
            FROM
                metadata.stations st
                LEFT JOIN metadata.stations_status ss USING (station_id)
                LEFT JOIN metadata.stations_parameters sp USING (station_id)
                LEFT JOIN metadata.stations_info si USING (station_id)
            WHERE
                st.station_id >= 1000 -- below system station, reserved
                AND st.station_active IS TRUE
                AND ss.ss_suspended IS NOT TRUE -- (no NULL or FALSE)
                AND si.st_info_typology_fk != 6 -- Magazzino
                AND sp.param_id = 567           --  [BC] Status [ing_unit] -> param_id: 567
        ) LOOP

            -- RAISE NOTICE 'Looping station % ...', r.station_id;

            q = 'WITH temp as ('||E'\n'
            ||'    SELECT *'||E'\n'
            ||'    FROM '||r.station_fulltable||' '||E'\n'
            ||'    WHERE measure_id = '||r.stpr_table_id||E'\n'
            ||'    AND measure_value > 0 '||E'\n' -- Status Alarm 512 OK -> MEASURE
            ||'    AND measure_date_time > CURRENT_TIMESTAMP - interval '||quote_literal(i)||' '||E'\n'
            ||')'||E'\n'
            ||'INSERT INTO clients.metone_warnings'||E'\n'
            ||'    (fulldate, station_id, warning_id)'||E'\n'
            ||'('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        measure_date_time,'||E'\n'
            ||'        '||r.station_id||','||E'\n'
            ||'        measure_value'||E'\n'
            ||'    FROM temp'||E'\n'
            ||'    ORDER BY measure_date_time'||E'\n'
            ||')'||E'\n'
            ||'ON CONFLICT DO NOTHING;'||E'\n\n';

            --RAISE NOTICE 'Query: %', q;
            EXECUTE q;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_warnings_metone(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_metone() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_metone() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_metone() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_metone() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_warnings_metone()
        IS 'Refresh table with latest strumental warnings';

    -- Funzione di aggiornamento degli ultimi allarmi strumentali (strumento SWAM)
    -- DROP FUNCTION IF EXISTS clients.f_refresh_warnings_swam();
    CREATE OR REPLACE FUNCTION clients.f_refresh_warnings_swam(
    )
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        r record;
        q text;
        p text;
    BEGIN
        -- TEST SELECT clients.f_refresh_warnings_swam();

        IF EXTRACT(HOUR FROM CURRENT_TIMESTAMP) = 0 THEN
            p = '7 days';
        ELSE
            p = '2 days'; -- 2 days to catch diagnostics data wich is stored @ 00:00:00
        END IF;

        -- loop through all active stations and get last avaible alarms
        FOR r IN (
            SELECT
                st.station_id,
                ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable
            FROM
                metadata.stations st
                LEFT JOIN metadata.stations_status ss USING (station_id)
                LEFT JOIN metadata.stations_info si USING (station_id)
            WHERE
                st.station_id >= 1000 -- below system station, reserved
                AND st.station_active IS TRUE
                AND ss.ss_suspended IS FALSE
                AND si.st_info_typology_fk != 6 -- Magazzino
        ) LOOP

            -- RAISE NOTICE 'Looping station % ...', r.station_id;

            q= 'WITH temp as ('||E'\n'
            ||'    SELECT *'||E'\n'
            ||'    FROM '||r.station_fulltable||' '||E'\n'
            ||'    WHERE measure_id IN ('||E'\n'
            ||'        5026, 5076, 5126'||E'\n'
            ||'    )'||E'\n'
            ||'    AND measure_value != 0 '||E'\n'
            ||'    AND measure_date_time > CURRENT_TIMESTAMP - interval '||quote_literal(p)||' '||E'\n'
            ||')'||E'\n'
            ||'INSERT INTO clients.swam_warnings ('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        measure_date_time AS sw_fulldate,'||E'\n'
            ||'        '||r.station_id||' AS station_id,'||E'\n'
            ||'        measure_id AS sw_id,'||E'\n'
            ||'        (measure_value::integer)::bit(32) AS sw_bit_mask'||E'\n'
            ||'    FROM temp'||E'\n'
            ||'    ORDER BY measure_date_time )'||E'\n'
            ||'ON CONFLICT ON CONSTRAINT clients_swam_warnings_pk DO NOTHING;'||E'\n\n';

            --RAISE NOTICE 'Query: %', q;
            EXECUTE q;

            q= 'WITH temp as ('||E'\n'
            ||'    SELECT *'||E'\n'
            ||'    FROM '||r.station_fulltable||' '||E'\n'
            ||'    WHERE measure_id = 5040'||E'\n'
            ||'    AND measure_value = 6 '||E'\n' -- Status Alarm
            ||'    AND measure_date_time > CURRENT_TIMESTAMP - interval '||quote_literal(p)||' '||E'\n'
            ||')'||E'\n'
            ||'INSERT INTO clients.swam_warnings ('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        measure_date_time AS sw_fulldate,'||E'\n'
            ||'        '||r.station_id||' AS station_id,'||E'\n'
            ||'        measure_id AS sw_id,'||E'\n'
            ||'        (measure_value::integer)::bit(32) AS sw_bit_mask'||E'\n'
            ||'    FROM temp'||E'\n'
            ||'    ORDER BY measure_date_time )'||E'\n'
            ||'ON CONFLICT ON CONSTRAINT clients_swam_warnings_pk DO NOTHING;'||E'\n\n';

            -- RAISE NOTICE 'Query: %', q;
            EXECUTE q;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_warnings_swam(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_swam() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_swam() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_swam() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_swam() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_warnings_swam()
        IS 'Refresh table with latest strumental warnings';

    -- Funzione di aggiornamento degli ultimi allarmi strumentali (strumento Teledyne API)
    -- DROP FUNCTION IF EXISTS clients.f_refresh_warnings_teledyne();
    CREATE OR REPLACE FUNCTION clients.f_refresh_warnings_teledyne()
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        r record;
        q text;
        i text;
    BEGIN
        /*
         * TEST SELECT clients.f_refresh_warnings_teledyne();
         */

        -- midnight run 1 week in the past to catch up late data
        IF EXTRACT(HOUR FROM CURRENT_TIMESTAMP) = 0 THEN
            i = '14 days';
        ELSE
            i = '7 days';
        END IF;

        -- loop through all active stations and get last avaible alarms
        FOR r IN (
            SELECT
                st.station_id,
                ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable,
                sp.stpr_table_id,
                stpr_group_id
            FROM
                metadata.stations st
                LEFT JOIN metadata.stations_status ss USING (station_id)
                LEFT JOIN metadata.stations_parameters sp USING (station_id)
                LEFT JOIN metadata.stations_info si USING (station_id)
            WHERE
                st.station_id >= 1000 -- below system station, reserved
                AND st.station_active IS TRUE
                AND ss.ss_suspended IS NOT TRUE -- (no NULL or FALSE)
                AND si.st_info_typology_fk != 6 -- Magazzino
                AND sp.param_id = 1126          -- Status (OR) [ing_unit]
        ) LOOP

            -- RAISE NOTICE 'Looping station % ...', r.station_id;

            q = 'WITH temp as ('||E'\n'
            ||'    SELECT *'||E'\n'
            ||'    FROM '||r.station_fulltable||' '||E'\n'
            ||'    WHERE measure_id = '||r.stpr_table_id||E'\n'
            ||'    AND measure_value > 0 '||E'\n' -- Status Alarm 512 OK -> MEASURE
            ||'    AND measure_date_time > CURRENT_TIMESTAMP - interval '||quote_literal(i)||' '||E'\n'
            ||')'||E'\n'
            ||'INSERT INTO clients.teledyne_warnings'||E'\n'
            ||'    (fulldate, station_id, stpr_group_id, warning_id)'||E'\n'
            ||'('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        measure_date_time,'||E'\n'
            ||'        '||r.station_id||','||E'\n'
            ||'        '||r.stpr_group_id||','||E'\n'
            ||'        measure_value'||E'\n'
            ||'    FROM temp'||E'\n'
            ||'    ORDER BY measure_date_time'||E'\n'
            ||')'||E'\n'
            ||'ON CONFLICT DO NOTHING;'||E'\n\n';

            --RAISE NOTICE 'Query: %', q;
            EXECUTE q;

        END LOOP;

        RETURN true;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_refresh_warnings_teledyne(): %', SQLERRM;
            RETURN false;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_teledyne() TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_teledyne() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_teledyne() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_refresh_warnings_teledyne() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_refresh_warnings_teledyne()
        IS 'Refresh table with latest strumental warnings';

    -- Funzione che effettua il salvataggio delle azioni intraprese dall'utente del portale all'interno dell'applicativo "Validazione"
    -- DROP FUNCTION IF EXISTS clients.f_save_history();
    CREATE OR REPLACE FUNCTION clients.f_save_history()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$

    DECLARE
        obj  text;
        u    integer; -- user id
        a    integer; -- annotation
    BEGIN
        -- RAISE NOTICE 'TRIGGER f_save_history!';

        -- check if operation arrives from portal
        SELECT us_id, ann_id INTO u, a FROM clients.trigger_history;

        IF NOT FOUND THEN
            -- RAISE NOTICE 'User not found';
            RETURN NEW;
        END IF;

        -- check if it's an INSERT operation or UPDATE
        IF  (TG_OP = 'INSERT') THEN

            obj = '{'
                ||'    "d": "'||CURRENT_TIMESTAMP||'",'
                ||'    "u": '||u||','
                ||'    "a": '||COALESCE(a::text, 'null')||','
                ||'    "new":{'
                ||'        "v": '|| NEW.measure_value ||','
                ||'        "p": '|| NEW.post_validity_code ||','
                ||'        "f": '|| NEW.final_validity_code ||' '
                ||'    },'
                ||'    "old":{'
                ||'        "v": "--",'
                ||'        "p": "--",'
                ||'        "f": "--" '
                ||'    }'
                ||'}';

                obj = '['||obj||']';
                NEW.measure_update_obj := obj::jsonb;
        ELSE
            -- check for changes
            -- NOT USED
            -- IF
            --     NEW.measure_value != OLD.measure_value OR
            --     NEW.post_validity_code  != OLD.post_validity_code OR
            --     NEW.final_validity_code != OLD.final_validity_code
            -- THEN
            --     -- continue
            -- ELSE
            --     -- skip
            --     --RAISE NOTICE 'Nothing changed!';
            --     RETURN NEW;
            -- END IF;

            /* meanvalue changed */
            IF  NEW.measure_value != OLD.measure_value
            THEN
                -- add "ricostruito" code to data
                NEW.post_validity_code := NEW.post_validity_code ||| 1; -- ricostruito
            END IF;

            /* any changes */
            IF  NEW.measure_value != OLD.measure_value OR
                NEW.post_validity_code != OLD.post_validity_code
            THEN
                -- reset flag, dirty
                NEW.final_validity_code := 0;
            END IF;

            obj = '{'
                ||'    "d": "'||CURRENT_TIMESTAMP||'",'
                ||'    "u": '||u||','
                ||'    "a": '||COALESCE(a::text, 'null')||','
                ||'    "new":{'
                ||'        "v": '|| NEW.measure_value ||','
                ||'        "p": '|| NEW.post_validity_code ||','
                ||'        "f": '|| NEW.final_validity_code ||' '
                ||'    },'
                ||'    "old":{'
                ||'        "v": '|| OLD.measure_value ||','
                ||'        "p": '|| OLD.post_validity_code ||','
                ||'        "f": '|| OLD.final_validity_code ||' '
                ||'    }'
                ||'}';

            -- RAISE NOTICE 'Status OBJ: %', obj;

            IF OLD.measure_update_obj IS NULL THEN

                -- RAISE NOTICE 'First update made by user: new JSONB';
                obj = '['||obj||']';
                NEW.measure_update_obj := obj::jsonb;

            ELSE
                -- RAISE NOTICE 'Append update to JSONB';
                NEW.measure_update_obj := OLD.measure_update_obj || obj::jsonb;

            END IF;
        END IF;

        RETURN NEW;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_save_history(): %', SQLERRM;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_save_history() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_save_history() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_save_history() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_save_history()
        IS 'Trigger function that stores all changes made by user from OPAS tool validation';

    -- Funzione che imposta l'extract_code dei dati sulla base della cadenza di acquisizione
    -- DROP FUNCTION clients.f_set_extract_code();
    CREATE OR REPLACE FUNCTION clients.f_set_extract_code()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$

    DECLARE
        stid    integer;
        prid    integer;
        c       integer; -- cadence
    BEGIN
        -- RAISE NOTICE 'FUNCTION f_set_extract_code';

        /*station id passed by caller*/
        stid  := TG_ARGV[0];
        -- RAISE NOTICE 'stid: %', stid;

        /*get the parameter id*/
        SELECT
            param_id, COALESCE(stpr_info_cadence_fk, st_info_cadence_fk) INTO prid, c
        FROM
            metadata.stations_parameters
            LEFT JOIN metadata.stations_info USING (station_id)
            LEFT JOIN metadata.stations_params_info USING (stpr_id)
        WHERE
            station_id = stid
            AND stpr_table_id = NEW.measure_id;

        /*check exists*/
        IF NOT FOUND THEN
            -- RAISE NOTICE 'prid not found';
            RETURN NEW;
        END IF;

        -- RAISE NOTICE 'prid: %', prid;

        -- /!\ prendo tutti i parametri /!\
        -- 50::integer,  PM10
        -- 47::integer,  PM1
        -- 48::integer,  PM2.5
        -- ELSIF prid NOT IN (47, 48, 50) THEN
        --      RETURN NEW;
        -- RAISE NOTICE 'Id PM10/2.5 Found';

        --  5   'oraria' DO NOTHING
        --  6   'bi-oraria'
        --  7   'tri-oraria'
        --  12  '6 ore'
        --  8   'giornaliera'
        -- Set
        IF c = 6 THEN -- bi-oraria
            NEW.extract_code = 2;

        ELSIF c = 7 THEN -- tri-oraria
            NEW.extract_code = 3;

        ELSIF c = 12 THEN -- 6 ore
            NEW.extract_code = 6;

        ELSIF c = 8 THEN -- giornaliero
            NEW.extract_code = 24;
        END IF;

        RETURN NEW;

        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR IN clients.f_set_extract_code() : %', SQLERRM;
            /* return value */
            RETURN NEW;
    END;

    $BODY$;

    -- grants
    ALTER FUNCTION clients.f_set_extract_code() OWNER TO postgres;
    GRANT EXECUTE ON FUNCTION clients.f_set_extract_code() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_set_extract_code() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_set_extract_code() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_set_extract_code()
        IS 'Set extract code based on measure cadence';

    -- Funzione per l'estrazione dei dati di media mobile
    -- DROP FUNCTION IF EXISTS clients.f_sldavg_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, text, integer);
    CREATE OR REPLACE FUNCTION clients.f_sldavg_data_extraction(
        stprid bigint,
        date_from timestamp without time zone,
        date_to timestamp without time zone,
        aggregation metadata.e_aggregations DEFAULT 'hh'::metadata.e_aggregations,
        validity text DEFAULT '>= 0'::text,
        dwindow integer DEFAULT 8)
        RETURNS SETOF clients.t_data_function 
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
        ROWS 1000

    AS $BODY$
            DECLARE
                treatment metadata.e_treatments := 'avg';
                d integer := 10; -- parameter decimals
                q text;         -- dynamic query
            BEGIN

                /* entry */
                RAISE NOTICE 'Function clients.f_sldavg_data_extraction, stpr_id: %', stprid;

                /* Testing
                    SELECT * FROM  clients.f_sldavg_data_extraction (
                        45,
                        '2021-01-13 00:00'::timestamp,
                        '2021-01-20 23:00'::timestamp,
                        'dd'::metadata.e_aggregations,
                        '>= 0'::text,
                        8::integer
                    );
                */

                /* build main dynamic query */
                q =
                'WITH m AS ('||E'\n'
                ||'    SELECT a AS measure_date_time FROM generate_series'||E'\n'
                ||'    ( '||quote_literal(date_from)||'::timestamp'||E'\n'
                ||'    , '||quote_literal(date_to)||'::timestamp'||E'\n'
                ||'    , ''1 hour''::interval) s(a)'||E'\n'
                ||')'||E'\n\n';

                /* take care of aggregation time */
                CASE
                    WHEN aggregation = 'hh'::metadata.e_aggregations THEN

                        /* date time */
                        q =
                        'SELECT * '||E'\n'
                        ||'FROM clients.f_calc_dynamic_moving_mean ('||stprid||'::bigint, '||quote_literal(date_from)||'::timestamp, '||quote_literal(date_to)||'::timestamp,'||quote_literal(validity)||'::text, '||dwindow||'::integer) tbl'||E'\n'
                        ||'WHERE'||E'\n'
                        ||'    tbl.measure_date_time BETWEEN '||quote_literal(date_from)||' AND '||quote_literal(date_to)||''||E'\n';

                    WHEN aggregation = 'dd'::metadata.e_aggregations THEN

                        /* date time */
                        q = q
                        ||'SELECT'||E'\n'
                        ||'    date_trunc(''day'', m.measure_date_time) AS measure_date_time,'||E'\n';

                        /* measures */
                        q = q
                        ||'    MAX(measure_id) AS measure_id,'||E'\n'
                        ||'    ROUND('||treatment||'(t.measure_value::numeric), '||d||') AS measure_value,'||E'\n'
                        ||'    ROUND( MIN(t.measure_min::numeric), '||d||') AS measure_min,'||E'\n'
                        ||'    ROUND( MAX(t.measure_max::numeric), '||d||') AS measure_max,'||E'\n'
                        ||'    (SUM(CASE WHEN t.measure_value NOTNULL THEN 1::smallint ELSE 0::smallint END)/24::real*100)::smallint AS measure_perc,'||E'\n'
                        ||'    MAX( t.post_validity_code::integer ) AS post_validity_code,'||E'\n'
                        ||'    MAX( t.final_validity_code::smallint ) AS final_validity_code'||E'\n';

                        /* from clause */
                        q = q
                        ||'FROM'||E'\n'
                        ||'    m LEFT JOIN clients.f_calc_dynamic_moving_mean ('||stprid||'::bigint, '||quote_literal(date_from)||'::timestamp, '||quote_literal(date_to)||'::timestamp,'||quote_literal(validity)||'::text, '||dwindow||'::integer) t ON (m.measure_date_time = t.measure_date_time)'||E'\n'
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
                        ||'    MAX(measure_id) AS measure_id,'||E'\n'
                        ||'    ROUND('||treatment||'(t.measure_value::numeric), '||d||') AS measure_value,'||E'\n'
                        ||'    ROUND( MIN(t.measure_min::numeric), '||d||') AS measure_min,'||E'\n'
                        ||'    ROUND( MAX(t.measure_max::numeric), '||d||') AS measure_max,'||E'\n'
                        ||'    (SUM(CASE WHEN t.measure_value NOTNULL THEN 1::smallint ELSE 0::smallint END)/('||E'\n'
                        ||'    24 * MAX(extract(days FROM date_trunc(''month'', m.measure_date_time) + interval ''1 month - 1 day''))'||E'\n'
                        ||'    )::real*100)::smallint AS measure_perc,'||E'\n'
                        ||'    MAX( t.post_validity_code::integer ) AS post_validity_code,'||E'\n'
                        ||'    MAX( t.final_validity_code::smallint ) AS final_validity_code'||E'\n';

                        /* from clause */
                        q = q
                        ||'FROM'||E'\n'
                        ||'    m LEFT JOIN clients.f_calc_dynamic_moving_mean ('||stprid||'::bigint, '||quote_literal(date_from)||'::timestamp, '||quote_literal(date_to)||'::timestamp,'||quote_literal(validity)||'::text, '||dwindow||'::integer) t ON (m.measure_date_time = t.measure_date_time)'||E'\n'
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
                        ||'    MAX(measure_id) AS measure_id,'||E'\n'
                        ||'    ROUND('||treatment||'(t.measure_value::numeric), '||d||') AS measure_value,'||E'\n'
                        ||'    ROUND(MIN (t.measure_min::numeric), '||d||') AS measure_min,'||E'\n'
                        ||'    ROUND(MAX (t.measure_max::numeric), '||d||') AS measure_max,'||E'\n'
                        ||'    (SUM(CASE WHEN t.measure_value NOTNULL THEN 1::smallint ELSE 0::smallint END)/('||E'\n'
                        ||'    24 * DATE_PART(''day'', date_trunc(''year'', now()) + interval ''1 year - 1 day'' - date_trunc(''year'', now()))'||E'\n'
                        ||'    )::real*100)::smallint AS measure_perc'||E'\n'
                        ||'    MAX( t.post_validity_code::integer ) AS post_validity_code,'||E'\n'
                        ||'    MAX( t.final_validity_code::smallint ) AS final_validity_code'||E'\n';

                        /* from clause */
                        q = q
                        ||'FROM'||E'\n'
                        ||'    m LEFT JOIN clients.f_calc_dynamic_moving_mean ('||stprid||'::bigint, '||quote_literal(date_from)||'::timestamp, '||quote_literal(date_to)||'::timestamp,'||quote_literal(validity)||'::text, '||dwindow||'::integer) t ON (m.measure_date_time = t.measure_date_time)'||E'\n'
                        ||'WHERE'||E'\n'
                        ||'    m.measure_date_time BETWEEN '||quote_literal(date_from)||' AND '||quote_literal(date_to)||''||E'\n';

                        /* order by */
                        q = q
                        ||'GROUP BY 1'||E'\n'
                        ||'ORDER BY 1'||E'\n';

                    ELSE

                END CASE;

                /* notice */
                RAISE NOTICE 'Query: %', E'\n'||q;

                /* return value */
                RETURN QUERY EXECUTE q;

            /* errors check */
            EXCEPTION
                WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_sldavg_data_extraction(): %', SQLERRM;
            END;
        
    $BODY$;

    GRANT EXECUTE ON FUNCTION clients.f_sldavg_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, text, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_sldavg_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, text, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_sldavg_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, text, integer) TO group_tools;
    GRANT EXECUTE ON FUNCTION clients.f_sldavg_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, text, integer) TO group_readonly;

    COMMENT ON FUNCTION clients.f_sldavg_data_extraction(bigint, timestamp without time zone, timestamp without time zone, metadata.e_aggregations, text, integer) IS '[OPAS] Generic data extraction function for moving mean';


    -- Versione 2 della funzione che "spalma" i valori giornalieri di PM10, PM2.5 e PM1 dello strumento SWAM sulle 24 ore
    -- DROP FUNCTION IF EXISTS clients.f_swam_to_24h_v2();
    CREATE FUNCTION clients.f_swam_to_24h_v2() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$

        DECLARE
            stid           integer;
            prid           integer;
            table_name     varchar;
            query_sql      varchar;
            get_diag       integer;
            dt             timestamp;
        BEGIN
            --RAISE NOTICE 'FUNCTION check_measure_value_swam';

            /*station id passed by caller*/
            stid  := TG_ARGV[0];
            --RAISE NOTICE 'stid: %', stid;

            /* sanity check */
            IF EXTRACT('hour' FROM NEW.measure_date_time) > 0 THEN
                RETURN NEW;
            END IF;

            /*
            * get the parameter id for the given station and measure id
            * with DAILY cadence
            */
            SELECT INTO prid param_id
            FROM
                metadata.stations_parameters
                LEFT JOIN metadata.stations_params_info USING (stpr_id)
            WHERE
                station_id = stid
                AND stpr_table_id = NEW.measure_id
                AND stpr_info_cadence_fk = 8;

            --RAISE NOTICE 'prid: %', prid;

            /*
            * check result:
            *   - if not found then do nothing and return NEW;
            *   - else if it is a swam diagnostic then set extract_code to 24 and return NEW;
            *   - else if the parameter isn't a swam diagnostic nor a swam concentration then return NEW
            *   - else parameter is a PM10, PM2.5 or PM1
            *        -- 47::integer,  PM1
            *        -- 48::integer,  PM2.5
            *        -- 50::integer,  PM10
            */
            IF NOT FOUND THEN
                RETURN NEW;

            ELSIF ( (prid BETWEEN 364 AND 392) OR ( prid IN (539, 651, 652, 653, 654, 806, 807) ) ) THEN
                NEW.extract_code := 24;
                RETURN NEW;

            ELSIF prid NOT IN (50, 47, 48) THEN
                RETURN NEW;
            END IF;

            /* set extract code equal to 1 */
            NEW.extract_code := 1;

            --RAISE NOTICE 'Id PM10/2.5/1 Found';

            /* get previous day date time */
            dt := NEW.measure_date_time + interval '1 hour';
            --dt := date_trunc('day', dt);

            /* check if a data as already been inserted */
            EXECUTE format('SELECT * FROM %I.%I WHERE measure_date_time = %L AND measure_id = %L',
            TG_TABLE_SCHEMA, TG_TABLE_NAME, dt, NEW.measure_id);
            GET DIAGNOSTICS get_diag = ROW_COUNT;

            /* count check */
            IF get_diag = 0 THEN

                /* ATTENZIONE! set user_swam role in order to not trigger anything */
                SET ROLE user_swam;

                /* insert 24 hours equal to the first one find */
                FOR i IN 1..23 LOOP
                    --RAISE NOTICE 'Insert row: %, data: % -> id: %', i, dt, pm10_25_id;

                    /* force no station alarm for swam records
                    put station_code equal to zero
                    */

                    EXECUTE format(
                    'INSERT INTO %I.%I ('
                    ||'    measure_date_time,'
                    ||'    measure_id,'
                    ||'    measure_value,'
                    ||'    measure_code,'
                    ||'    station_code,'
                    ||'    measure_perc,'
                    ||'    measure_min,'
                    ||'    measure_min_time,'
                    ||'    measure_max,'
                    ||'    measure_max_time,'
                    ||'    measure_std_dev,'
                    ||'    post_validity_code,'
                    ||'    extract_code'
                    ||') VALUES ('
                    ||'    '||quote_literal(dt)||','
                    ||'    $1.measure_id,'
                    ||'    $1.measure_value,'
                    ||'    $1.measure_code,'
                    ||'    0,'
                    ||'    $1.measure_perc,'
                    ||'    $1.measure_min,'
                    ||'    $1.measure_min_time,'
                    ||'    $1.measure_max,'
                    ||'    $1.measure_max_time,'
                    ||'    $1.measure_std_dev,'
                    ||'    $1.post_validity_code,'
                    ||'    $1.extract_code'
                    ||')' , TG_TABLE_SCHEMA, TG_TABLE_NAME)
                    USING NEW;

                    -- increment 1 hour
                    dt := dt + interval '1 hour';

                END LOOP;

                /* ATTENZIONE! reset role */
                RESET ROLE;
            -- all inserted, no more to do
            --RAISE NOTICE 'Inserted 24 new records for PM10/2.5';

            END IF; /*IF get_diag = 0 THEN*/

            /* return value */
            RETURN NEW;

            /* errors check */
            EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'ERROR IN clients.f_test_swam_to_24h() : %', SQLERRM;
                /* return value */
                RETURN NEW;
        END;

    $_$;

    -- grants
    ALTER FUNCTION clients.f_swam_to_24h_v2() OWNER TO postgres;
    GRANT EXECUTE ON FUNCTION clients.f_swam_to_24h_v2() TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_swam_to_24h_v2() TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_swam_to_24h_v2() TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_swam_to_24h_v2()
        IS 'Spread PM10/2.5/1 daily value into 24 hours - version 2';

    -- Funzione che applica un codice di validità finale a un sottoinsieme di dati di una specifica relazione stazione-parametro
    -- DROP FUNCTION clients.f_update_final_validity_code(integer, timestamp, timestamp, smallint);
    CREATE OR REPLACE FUNCTION clients.f_update_final_validity_code(
        stprid integer,
        d_from timestamp,
        d_to   timestamp,
        code   smallint
    )
    RETURNS integer
    LANGUAGE 'plpgsql'
    VOLATILE
    AS $BODY$

    DECLARE
        t text;         -- tablename
        f text;         -- prefix of triggers functions name
        p integer;      -- parameter table id
        r integer;      -- result: number of rows affected by the update
        q text;         -- dynamic query
    BEGIN
        --
        -- TEST SELECT clients.f_update_final_validity_code( 43::integer , '2023-01-02 00:00'::timestamp, '2023-01-02 23:00'::timestamp, 8::smallint ) AS num_rows
        --

        /* get fulltable and measure_id linked to st_pr_id */
        SELECT
            s.station_schema ||'.'||COALESCE(s.station_prefix, '')||s.station_table,
            s.station_schema ||'_'||COALESCE(s.station_prefix, '')||s.station_table,
            sp.stpr_table_id

            INTO t, f, p
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.parameters p USING (param_id)
        WHERE
            stpr_id = stprid;

        /* check existence of stprid */
        IF NOT FOUND THEN
            RAISE NOTICE 'Parameter % not found', stprid;
            RETURN NULL;
        END IF;

        -- Eventualmente prevedere di disabilitare tutti i trigger
        -- abilitare solo quelli necessari (save_history e, SE ESISTE, trigger di export)
        -- 'ALTER TABLE '||t||' DISABLE TRIGGER ALL;'

        /* build dynamic query with data returned by previous query */
        q =
            'WITH rows AS ('||E'\n'
            ||'    UPDATE '||t||' '||E'\n'
            ||'    SET final_validity_code = final_validity_code | '||code||'::smallint '||E'\n'
            ||'    WHERE '||E'\n'
            ||'        measure_date_time BETWEEN '||quote_literal(d_from)||'::timestamp AND '||quote_literal(d_to)||'::timestamp '||E'\n'
            ||'        AND measure_id = '||p||'::integer  '||E'\n'
            ||'        AND final_validity_code < '||code||'::smallint '||E'\n'
            ||'    RETURNING 1'||E'\n'
            ||')'||E'\n'
            ||'SELECT COUNT(*) FROM rows;'||E'\n';

        -- 'ALTER TABLE '||t||' ENABLE TRIGGER ALL;'

        /* notice */
        -- RAISE NOTICE 'Query: %', E'\n'||q;

        /* execute query and store result */
        EXECUTE q INTO r;

        /* return value */
        RETURN r;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_update_final_validity_code(): %', SQLERRM;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients.f_update_final_validity_code(integer, timestamp, timestamp, smallint) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_update_final_validity_code(integer, timestamp, timestamp, smallint) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_update_final_validity_code(integer, timestamp, timestamp, smallint) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_update_final_validity_code(integer, timestamp, timestamp, smallint) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients.f_update_final_validity_code(integer, timestamp, timestamp, smallint)
        IS 'Function that applies a final validity code to a subset of data of a specific station-parameter relation';

    -- Funzione che recupera i dati in formato .csv
    -- DROP FUNCTION IF EXISTS clients.f_get_csv_data(timestamp without time zone, timestamp without time zone, metadata.e_aggregations, integer, integer);
    CREATE OR REPLACE FUNCTION clients.f_get_csv_data(
        d_start timestamp without time zone,
        d_end timestamp without time zone,
        aggr metadata.e_aggregations,
        stid integer,
        prid integer)
    RETURNS SETOF clients.t_data_csv
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    ROWS 1000
    AS $BODY$

    DECLARE
        -- variables
        startupdd   timestamp;
        dismissdd   timestamp;
        stprid      integer;
        treatment   metadata.e_treatments;
        parconv     numeric;
        pardecimals smallint;
        perc_valid  integer;
        rec         record;
        query       text;
        r           clients.t_data_csv%rowtype;
    BEGIN
        /* TEST
            SELECT * FROM clients.f_get_csv_data('2023-04-01'::timestamp, '2023-04-02'::timestamp, 'hh'::metadata.e_aggregations, 1000::integer, 32::integer);
        */

        RAISE NOTICE 'Date start from INPUT: %', d_start;
        RAISE NOTICE 'Date end from INPUT: %', d_end;

        SELECT
            COALESCE(st_info_startup_date::text, '1995-01-01')::timestamp AS station_startupdate,
            COALESCE(st_info_dismiss_date::text, CURRENT_TIMESTAMP::text)::timestamp AS station_dismissdate INTO rec
        FROM metadata.stations_info
        WHERE station_id = stid;

        IF NOT FOUND THEN
            RAISE NOTICE 'Station % not found ', stid;
            RETURN;
        END IF;

        SELECT
            stpr_startup_date, stpr_dismiss_date, stpr_id, COALESCE(pm_info_obj->'general'->>'treatment', 'avg'), param_conv, param_decimals
            INTO startupdd, dismissdd, stprid, treatment, parconv, pardecimals
        FROM metadata.stations_parameters sp-- tabella nuova di BOBO
        LEFT JOIN metadata.parameters_info pi USING (param_id)
        LEFT JOIN metadata.parameters pp USING (param_id)
        WHERE station_id = stid
        AND param_id = prid
        AND EXISTS (
            SELECT 1
            FROM
                metadata.stations_instruments si
            WHERE
                si.stpr_group_id = sp.stpr_group_id
                AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                AND si.stin_master IS TRUE
        );

        IF NOT FOUND THEN
            RAISE NOTICE 'Parameter % not found for station: %', prid, stid;
            RETURN;
        END IF;

        IF startupdd IS NULL THEN
            RAISE NOTICE 'Date start parameter IS NULL: get station date start';
            startupdd := rec.station_startupdate;
        END IF;
        RAISE NOTICE 'Date start from DB: %', startupdd;

        IF dismissdd IS NULL THEN
            RAISE NOTICE 'Date end parameter IS NULL: get station date end';
            dismissdd := rec.station_dismissdate;
        END IF;
        RAISE NOTICE 'Date end from DB: %', dismissdd;

        -- adjust start and end time
        IF d_start < startupdd THEN
            d_start := startupdd;
        END IF;

        IF d_end > dismissdd THEN
            d_end := dismissdd;
        END IF;

        -- log
        RAISE NOTICE 'Final used dates start: %, end: %', d_start, d_end;
        RAISE NOTICE 'Params aggr: %, stid: %, prid: %', aggr, stid, prid;

        IF (aggr = 'hh') THEN
            SELECT parameter_aggr_hh_perc INTO perc_valid FROM metadata.view_parameters_info WHERE parameter_id = prid;
        ELSEIF (aggr = 'dd') THEN
            SELECT parameter_aggr_dd_perc INTO perc_valid FROM metadata.view_parameters_info WHERE parameter_id = prid;
        ELSEIF (aggr = 'mm') THEN
            SELECT parameter_aggr_mm_perc INTO perc_valid FROM metadata.view_parameters_info WHERE parameter_id = prid;
        ELSE
            SELECT parameter_aggr_yy_perc INTO perc_valid FROM metadata.view_parameters_info WHERE parameter_id = prid;
        END IF ;

        --perc_valid = 10;
        RAISE NOTICE 'Final perc_valid: %', perc_valid;

        query = 'SELECT '
            || '    tbl.measure_date_time AS dataora, '
            || '    CASE '
            -- || '        WHEN tbl.measure_perc >= '||perc_valid||'::integer THEN ROUND((tbl.measure_value * ' || parconv || ')::numeric, ' || pardecimals || ')'
            || '        WHEN tbl.measure_perc >= '||perc_valid||'::integer THEN ROUND((tbl.measure_value * metadata.f_get_conversion_by_date('||prid||', tbl.measure_date_time) )::numeric, ' || pardecimals || ')'
            || '        ELSE NULL '
            || '    END AS misura '
            || 'FROM clients.f_data_extraction('||stprid||'::integer, '||quote_literal(d_start)||'::timestamp, '||quote_literal(d_end)||'::timestamp, '||quote_literal(aggr)||'::metadata.e_aggregations, '||quote_literal(treatment)||'::metadata.e_treatments, ''>= -1''::text) tbl '
            || 'ORDER BY tbl.measure_date_time; ';

        RAISE NOTICE 'Query : %', query;

        FOR r IN EXECUTE query

        LOOP
            RETURN NEXT r; -- return current row of SELECT
        END LOOP;
        RETURN;
    END;

    $BODY$;

    -- grants
    ALTER FUNCTION clients.f_get_csv_data(timestamp without time zone, timestamp without time zone, metadata.e_aggregations, integer, integer) OWNER TO postgres;
    GRANT EXECUTE ON FUNCTION clients.f_get_csv_data(timestamp without time zone, timestamp without time zone, metadata.e_aggregations, integer, integer) TO PUBLIC;
    GRANT EXECUTE ON FUNCTION clients.f_get_csv_data(timestamp without time zone, timestamp without time zone, metadata.e_aggregations, integer, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_get_csv_data(timestamp without time zone, timestamp without time zone, metadata.e_aggregations, integer, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_get_csv_data(timestamp without time zone, timestamp without time zone, metadata.e_aggregations, integer, integer) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients.f_get_csv_data(timestamp without time zone, timestamp without time zone, metadata.e_aggregations, integer, integer) TO group_tools;
    GRANT EXECUTE ON FUNCTION clients.f_get_csv_data(timestamp without time zone, timestamp without time zone, metadata.e_aggregations, integer, integer) TO postgres;

    -- comment
    COMMENT ON FUNCTION clients.f_get_csv_data(timestamp without time zone, timestamp without time zone, metadata.e_aggregations, integer, integer)
        IS 'Get data for csv export';

    -- --------------------------------------------------------------------------------------------
    -- TRIGGERS
    -- --------------------------------------------------------------------------------------------

    CREATE OR REPLACE TRIGGER clients_calibrations_result_to_export_ai
        AFTER INSERT
        ON clients.calibrations_result
        FOR EACH ROW
        EXECUTE FUNCTION clients.f_calibrations_export();

    -- comment
    COMMENT ON TRIGGER clients_calibrations_result_to_export_ai ON clients.calibrations_result
        IS 'Trigger to clone data from calibrations to export table';

-- SCHEMA clients_stats

    -- DROP SCHEMA IF EXISTS clients_stats CASCADE;
    CREATE SCHEMA clients_stats
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA clients_stats TO group_admin;
    GRANT USAGE ON SCHEMA clients_stats TO group_bobo;
    GRANT USAGE ON SCHEMA clients_stats TO group_readonly;
    GRANT USAGE ON SCHEMA clients_stats TO group_tools;
    COMMENT ON SCHEMA clients_stats IS 'Data schema for statistics utilities in OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella che associa a ciascun inquinante la statistica e il tipo di valore soglia
    -- DROP TABLE IF EXISTS clients_stats.limits;
    CREATE TABLE clients_stats.limits
    (
        limit_id             serial,
        pollutant_id         integer NOT NULL,
        stat_id              integer NOT NULL,
        lt_id                integer NOT NULL,
        protection_target_id text DEFAULT NULL,
        objective_type_id    text DEFAULT NULL,
        reporting_metric_id  text DEFAULT NULL,
        limit_aggr           metadata.e_aggregations,
        limit_value          numeric NOT NULL, -- valore di soglia (valore limite, livello critico, valore obiettivo...)
        limit_sup            integer, -- limite di superamenti (in un anno)
        limit_upper_eval     numeric, -- soglia di valutazione superiore
        limit_lower_eval     numeric, -- soglia di valutazione inferiore
        limit_unit           text, -- unità di misura
        limit_note           text,

        CONSTRAINT clients_stats_limits_pkey PRIMARY KEY (limit_id),
        CONSTRAINT clients_stats_limits_ukey UNIQUE (pollutant_id, stat_id, lt_id)
        -- CONSTRAINT clients_stats_limits_fkey1 FOREIGN KEY (pollutant_id)
        --     REFERENCES infoaria.pollutants (pollutant_id) MATCH FULL
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
        --     NOT VALID,
        -- CONSTRAINT clients_stats_limits_fkey2 FOREIGN KEY (stat_id)
        --     REFERENCES clients_stats.statistics (stat_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
        --     NOT VALID,
        -- CONSTRAINT clients_stats_limits_fkey3 FOREIGN KEY (lt_id)
        --     REFERENCES clients_stats.limits_type (lt_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
        --     NOT VALID,
        -- CONSTRAINT clients_stats_limits_fkey4 FOREIGN KEY (protection_target_id)
        --     REFERENCES infoaria.protection_targets (protection_target_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
        --     NOT VALID,
        -- CONSTRAINT clients_stats_limits_fkey5 FOREIGN KEY (objective_type_id)
        --     REFERENCES infoaria.objective_types (objective_type_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
        --     NOT VALID,
        -- CONSTRAINT clients_stats_limits_fkey6 FOREIGN KEY (reporting_metric_id)
        --     REFERENCES infoaria.reporting_metrics (reporting_metric_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
        --     NOT VALID
    );

    -- grants
    GRANT ALL ON TABLE    clients_stats.limits TO group_admin;
    GRANT ALL ON TABLE    clients_stats.limits TO group_bobo;
    GRANT ALL ON TABLE    clients_stats.limits TO group_tools;
    GRANT SELECT ON TABLE clients_stats.limits TO group_readonly;

    --- comments
    COMMENT ON TABLE  clients_stats.limits                      IS 'Table that associates to each pollutant the statistics and the type of threshold value';
    COMMENT ON COLUMN clients_stats.limits.limit_id             IS 'Limit serial ID (PK)';
    COMMENT ON COLUMN clients_stats.limits.pollutant_id         IS 'Pollutant ID (FK)';
    COMMENT ON COLUMN clients_stats.limits.stat_id              IS 'Statistics type ID (FK)';
    COMMENT ON COLUMN clients_stats.limits.lt_id                IS 'Limit type ID (FK)';
    COMMENT ON COLUMN clients_stats.limits.protection_target_id IS 'Protection target (FK)';
    COMMENT ON COLUMN clients_stats.limits.objective_type_id    IS 'Objective type (FK)';
    COMMENT ON COLUMN clients_stats.limits.reporting_metric_id  IS 'Reporting metric (FK)';
    COMMENT ON COLUMN clients_stats.limits.limit_aggr           IS 'Limit aggregation (hh, mm, dd...)';
    COMMENT ON COLUMN clients_stats.limits.limit_value          IS 'Numerical value of the limit associated with the statistics and the parameter';
    COMMENT ON COLUMN clients_stats.limits.limit_sup            IS 'Limit on the number of exceedances of the threshold value since the beginning of the year';
    COMMENT ON COLUMN clients_stats.limits.limit_upper_eval     IS 'Upper evaluation threshold';
    COMMENT ON COLUMN clients_stats.limits.limit_lower_eval     IS 'Lower evaluation threshold';
    COMMENT ON COLUMN clients_stats.limits.limit_unit           IS 'Limit unit';
    COMMENT ON COLUMN clients_stats.limits.limit_note           IS 'Limit note';

    -- Tabella che desctive le tipologie di limite
    -- DROP TABLE IF EXISTS clients_stats.limits_type;
    CREATE TABLE clients_stats.limits_type
    (
        lt_id   integer NOT NULL,
        lt_desc text,

        CONSTRAINT clients_stats_limits_type_pkey PRIMARY KEY (lt_id)
    );

    -- grants
    GRANT ALL ON TABLE    clients_stats.limits_type TO group_admin;
    GRANT ALL ON TABLE    clients_stats.limits_type TO group_bobo;
    GRANT ALL ON TABLE    clients_stats.limits_type TO group_tools;
    GRANT SELECT ON TABLE clients_stats.limits_type TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients_stats.limits_type         IS 'Table describing the type of limits';
    COMMENT ON COLUMN clients_stats.limits_type.lt_id   IS 'Limit type id';
    COMMENT ON COLUMN clients_stats.limits_type.lt_desc IS 'Limit type description';

    -- Tabella che contiene i risultati tutte le statistiche
    -- DROP TABLE IF EXISTS clients_stats.report_results;
    CREATE TABLE clients_stats.report_results
    (
        rr_id         bigserial,
        rr_date       date NOT NULL,
        stpr_id       integer NOT NULL,
        rt_id         integer NOT NULL,
        rs_id         integer NOT NULL,
        rr_result     numeric,
        rr_overcoming boolean DEFAULT FALSE,
        rr_insert_ts  timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT clients_stats_report_results_pkey PRIMARY KEY (rr_id),
        CONSTRAINT clients_stats_report_results_ukey UNIQUE (rr_date, stpr_id, rt_id, rs_id)
        -- CONSTRAINT clients_stats_report_results_fk1 FOREIGN KEY (stpr_id)
        --     REFERENCES metadata.stations_parameters (stpr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stats_report_results_fk2 FOREIGN KEY (rt_id)
        --     REFERENCES clients_stats.report_types (rt_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stats_report_results_fk3 FOREIGN KEY (rs_id)
        --     REFERENCES clients_stats.report_stats (rs_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    );

    -- grants
    GRANT ALL ON TABLE    clients_stats.report_results TO group_admin;
    GRANT ALL ON TABLE    clients_stats.report_results TO group_bobo;
    GRANT ALL ON TABLE    clients_stats.report_results TO group_tools;
    GRANT SELECT ON TABLE clients_stats.report_results TO group_readonly;
    GRANT ALL ON SEQUENCE clients_stats.report_results_rr_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients_stats.report_results_rr_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients_stats.report_results_rr_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients_stats.report_results               IS 'Table that holds all possibile statistics results';
    COMMENT ON COLUMN clients_stats.report_results.rr_id         IS 'Result serial ID (PK)';
    COMMENT ON COLUMN clients_stats.report_results.rr_date       IS 'Result date';
    COMMENT ON COLUMN clients_stats.report_results.stpr_id       IS 'Station-parameter ID (FK)';
    COMMENT ON COLUMN clients_stats.report_results.rt_id         IS 'Report type (FK)';
    COMMENT ON COLUMN clients_stats.report_results.rs_id         IS 'Statistic ID (FK)';
    COMMENT ON COLUMN clients_stats.report_results.rr_result     IS 'Result calculated by R script';
    COMMENT ON COLUMN clients_stats.report_results.rr_overcoming IS 'Result overcoming calculated by R script';
    COMMENT ON COLUMN clients_stats.report_results.rr_insert_ts  IS 'Result insert timestamp';

    -- Tabella che contiene tutte le statistiche
    -- DROP TABLE IF EXISTS clients_stats.report_stats;
    CREATE TABLE clients_stats.report_stats
    (
        rs_id           serial,
        rs_name         text NOT NULL,
        rs_label        text,
        rs_desc         text,
        rs_note         text,
        rs_rscript_obj  jsonb,
        rs_insert_ts    timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        rs_order        integer,
        rs_active       boolean DEFAULT TRUE,

        CONSTRAINT clients_stats_report_stats_pkey PRIMARY KEY (rs_id),
        CONSTRAINT clients_stats_report_stats_ukey UNIQUE (rs_name)
    );

    -- grants
    GRANT ALL ON TABLE      clients_stats.report_stats TO group_admin;
    GRANT ALL ON TABLE      clients_stats.report_stats TO group_bobo;
    GRANT ALL ON TABLE      clients_stats.report_stats TO group_tools;
    GRANT SELECT ON TABLE   clients_stats.report_stats TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients_stats.report_stats                IS 'Table that holds all possibile statistics';
    COMMENT ON COLUMN clients_stats.report_stats.rs_id          IS 'Statistic ID (PK)';
    COMMENT ON COLUMN clients_stats.report_stats.rs_name        IS 'Statistic name (UNIQUE)';
    COMMENT ON COLUMN clients_stats.report_stats.rs_label       IS 'Statistic label';
    COMMENT ON COLUMN clients_stats.report_stats.rs_desc        IS 'Statistic description (FK)';
    COMMENT ON COLUMN clients_stats.report_stats.rs_note        IS 'Statistic note';
    COMMENT ON COLUMN clients_stats.report_stats.rs_rscript_obj IS 'Statistic object for R script aims (FK)';
    COMMENT ON COLUMN clients_stats.report_stats.rs_insert_ts   IS 'Statistic insert timestamp';
    COMMENT ON COLUMN clients_stats.report_stats.rs_order       IS 'Statistic order to force a particular order representation of elements';
    COMMENT ON COLUMN clients_stats.report_stats.rs_active      IS 'Statistic active or not';

    -- Tabella che contiene tutte le tipologie di statistiche
    -- DROP TABLE IF EXISTS clients_stats.report_type_stats;
    CREATE TABLE clients_stats.report_type_stats
    (
        rts_id        serial,
        portal_id     integer NOT NULL,
        rt_id         integer NOT NULL,
        rs_id         integer NOT NULL,
        rts_order     integer,
        rts_threshold numeric,
        rts_insert_ts timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        rts_active    boolean DEFAULT TRUE,

        CONSTRAINT clients_stats_report_type_stats_pkey PRIMARY KEY (rts_id),
        CONSTRAINT clients_stats_report_type_stats_ukey UNIQUE (portal_id, rt_id, rs_id)
        -- CONSTRAINT clients_stats_report_type_stats_fk1 FOREIGN KEY (portal_id)
        --     REFERENCES bobo.portals (portal_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stats_report_type_stats_fk2 FOREIGN KEY (rt_id)
        --     REFERENCES clients_stats.report_types (rt_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stats_report_type_stats_fk3 FOREIGN KEY (rs_id)
        --     REFERENCES clients_stats.report_stats (rs_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    );

    -- grants
    GRANT ALL ON TABLE    clients_stats.report_type_stats TO group_admin;
    GRANT ALL ON TABLE    clients_stats.report_type_stats TO group_bobo;
    GRANT ALL ON TABLE    clients_stats.report_type_stats TO group_tools;
    GRANT SELECT ON TABLE clients_stats.report_type_stats TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients_stats.report_type_stats               IS 'Table that holds all possibile statistics typologies';
    COMMENT ON COLUMN clients_stats.report_type_stats.rts_id        IS 'Type - Statistic ID (PK)';
    COMMENT ON COLUMN clients_stats.report_type_stats.rt_id         IS 'Report type ID (FK)';
    COMMENT ON COLUMN clients_stats.report_type_stats.rs_id         IS 'Report statistic ID (FK)';
    COMMENT ON COLUMN clients_stats.report_type_stats.rts_order     IS 'Type - Statistic order';
    COMMENT ON COLUMN clients_stats.report_type_stats.rts_threshold IS 'Type - Statistic threshold';
    COMMENT ON COLUMN clients_stats.report_type_stats.rts_insert_ts IS 'Type - Statistic insert timestamp';
    COMMENT ON COLUMN clients_stats.report_type_stats.rts_active    IS 'Type - Statistic active state';

    -- Tabella di lookup che continene le tipologie di report
    -- DROP TABLE IF EXISTS clients_stats.report_types;
    CREATE TABLE clients_stats.report_types
    (
        rt_id        smallint,
        rt_name      text,
        rt_desc      text,
        rt_icon      text,
        rt_color     text,
        rt_insert_ts timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT clients_stats_report_types_pkey PRIMARY KEY (rt_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    clients_stats.report_types TO group_admin;
    GRANT ALL ON TABLE    clients_stats.report_types TO group_bobo;
    GRANT ALL ON TABLE    clients_stats.report_types TO group_tools;
    GRANT SELECT ON TABLE clients_stats.report_types TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients_stats.report_types              IS 'Lookup table holding report types';
    COMMENT ON COLUMN clients_stats.report_types.rt_id        IS 'Report type ID (PK)';
    COMMENT ON COLUMN clients_stats.report_types.rt_name      IS 'Report type name';
    COMMENT ON COLUMN clients_stats.report_types.rt_desc      IS 'Report type description';
    COMMENT ON COLUMN clients_stats.report_types.rt_icon      IS 'Report type icon';
    COMMENT ON COLUMN clients_stats.report_types.rt_color     IS 'Report type color';
    COMMENT ON COLUMN clients_stats.report_types.rt_insert_ts IS 'Report type insert timestamp';

    -- Tabella dei report statictiche
    -- DROP TABLE IF EXISTS clients_stats.reports;
    CREATE TABLE clients_stats.reports
    (
        rep_id        serial,
        rt_id         integer NOT NULL,
        sz_id         integer NOT NULL,
        param_id      integer,
        rep_date      date NOT NULL,
        rep_signer    integer,
        rep_note      text,
        rep_file_name text,
        rep_insert_ts timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        us_id         integer,

        CONSTRAINT clients_stats_reports_pkey PRIMARY KEY (rep_id),
        CONSTRAINT clients_stats_reports_ukey UNIQUE (rt_id, sz_id, param_id, rep_date)
        -- CONSTRAINT clients_stats_reports_fk1 FOREIGN KEY (rt_id)
        --     REFERENCES clients_stats.report_types (rt_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stats_reports_fk2 FOREIGN KEY (sz_id)
        --     REFERENCES clients_stats.stations_zones (sz_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stats_reports_fk3 FOREIGN KEY (param_id)
        --     REFERENCES metadata.parameters (param_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stats_reports_fk4 FOREIGN KEY (rep_signer)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stats_reports_fk5 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    );

    -- grants
    GRANT ALL ON TABLE    clients_stats.reports TO group_admin;
    GRANT ALL ON TABLE    clients_stats.reports TO group_bobo;
    GRANT ALL ON TABLE    clients_stats.reports TO group_tools;
    GRANT SELECT ON TABLE clients_stats.reports TO group_readonly;
    GRANT ALL ON SEQUENCE clients_stats.reports_rep_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients_stats.reports_rep_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients_stats.reports_rep_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients_stats.reports               IS 'Table that contains statistic reports';
    COMMENT ON COLUMN clients_stats.reports.rep_id        IS 'Report ID (PK)';
    COMMENT ON COLUMN clients_stats.reports.rt_id         IS 'Report type (FK)';
    COMMENT ON COLUMN clients_stats.reports.sz_id         IS 'Stations zone (FK)';
    COMMENT ON COLUMN clients_stats.reports.param_id      IS 'Parameter id (FK) [Month/Year]';
    COMMENT ON COLUMN clients_stats.reports.rep_date      IS 'Report date';
    COMMENT ON COLUMN clients_stats.reports.rep_signer    IS 'Report signer (FK)';
    COMMENT ON COLUMN clients_stats.reports.rep_note      IS 'Report note';
    COMMENT ON COLUMN clients_stats.reports.rep_insert_ts IS 'Report request insert timestamp';
    COMMENT ON COLUMN clients_stats.reports.us_id         IS 'Report creator (FK)';

    -- Tabella contenente i dati delle statistiche calcolate dallo script R
    -- DROP TABLE IF EXISTS clients_stats.results;
    CREATE TABLE clients_stats.results
    (
        res_date           date NOT NULL,
        stpr_id            integer NOT NULL,
        limit_id           integer NOT NULL,
        res_value          numeric, -- valore statistica
        res_exceed_value   boolean, -- soglia superata
        res_num_sup        integer, -- numero superamenti
        res_exceed_num_sup boolean, -- soglia massimi superamenti superato
        res_perc_valid     numeric,
        res_aggrules       boolean,

        CONSTRAINT clients_stats_results_pkey PRIMARY KEY (res_date, stpr_id, limit_id)
        -- CONSTRAINT clients_stats_results_fkey1 FOREIGN KEY (stpr_id)
        --     REFERENCES metadata.stations_parameters (stpr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT clients_stats_results_fkey2 FOREIGN KEY (limit_id)
        --     REFERENCES clients_stats.limits (limit_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT
    );

    -- grants
    GRANT SELECT ON TABLE clients_stats.results TO group_readonly;
    GRANT ALL    ON TABLE clients_stats.results TO group_admin;
    GRANT ALL    ON TABLE clients_stats.results TO group_bobo;
    GRANT ALL    ON TABLE clients_stats.results TO group_tools;

    -- comments
    COMMENT ON TABLE  clients_stats.results                    IS 'R Statistic script data output table';
    COMMENT ON COLUMN clients_stats.results.res_date           IS 'Result date';
    COMMENT ON COLUMN clients_stats.results.stpr_id            IS 'Station-parameter ID (FK)';
    COMMENT ON COLUMN clients_stats.results.limit_id           IS 'Limit type ID (FK)';
    COMMENT ON COLUMN clients_stats.results.res_value          IS 'Result value';
    COMMENT ON COLUMN clients_stats.results.res_exceed_value   IS 'Result greater than limit value';
    COMMENT ON COLUMN clients_stats.results.res_num_sup        IS 'Result number sup';
    COMMENT ON COLUMN clients_stats.results.res_exceed_num_sup IS 'Result greater than limit number of exceedances';
    COMMENT ON COLUMN clients_stats.results.res_perc_valid     IS 'Result percentage of valid data';
    COMMENT ON COLUMN clients_stats.results.res_aggrules       IS 'Result comply with aggregation rules (min perc valid data)';

    --Tabella che raggruppa le stazioni in zone
    -- DROP TABLE IF EXISTS clients_stats.stations_zones;
    CREATE TABLE clients_stats.stations_zones
    (
        sz_id        serial,
        sz_name      text NOT NULL,
        sz_code      text,
        station_ids  integer[],
        sz_order     smallint DEFAULT 1,
        sz_note      text,
        sz_active    boolean DEFAULT TRUE,
        portal_id    integer NOT NULL,
        sz_insert_ts timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        us_id        integer,

        CONSTRAINT clients_stats_stations_zones_pkey PRIMARY KEY (sz_id),
        CONSTRAINT clients_stats_stations_zones_ukey UNIQUE (sz_name, portal_id)
        -- CONSTRAINT clients_stats_stations_zones_fk1 FOREIGN KEY (portal_id)
        --     REFERENCES bobo.portals (portal_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT clients_stats_stations_zones_fk2 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    );

    -- grants
    GRANT ALL ON TABLE    clients_stats.stations_zones TO group_admin;
    GRANT ALL ON TABLE    clients_stats.stations_zones TO group_bobo;
    GRANT ALL ON TABLE    clients_stats.stations_zones TO group_tools;
    GRANT SELECT ON TABLE clients_stats.stations_zones TO group_readonly;
    GRANT ALL ON SEQUENCE clients_stats.stations_zones_sz_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE clients_stats.stations_zones_sz_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE clients_stats.stations_zones_sz_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  clients_stats.stations_zones              IS 'Table that groups stations under zones';
    COMMENT ON COLUMN clients_stats.stations_zones.sz_id        IS 'Stations-zone id (PK)';
    COMMENT ON COLUMN clients_stats.stations_zones.sz_name      IS 'Stations-zone name';
    COMMENT ON COLUMN clients_stats.stations_zones.sz_code      IS 'Stations-zone code';
    COMMENT ON COLUMN clients_stats.stations_zones.station_ids  IS 'Stations id';
    COMMENT ON COLUMN clients_stats.stations_zones.sz_order     IS 'Stations-zone order';
    COMMENT ON COLUMN clients_stats.stations_zones.sz_note      IS 'Stations-zone note';
    COMMENT ON COLUMN clients_stats.stations_zones.sz_active    IS 'Stations-zone active';
    COMMENT ON COLUMN clients_stats.stations_zones.portal_id    IS 'Portal id (FK)';
    COMMENT ON COLUMN clients_stats.stations_zones.sz_insert_ts IS 'Stations-zone insert timestamp';
    COMMENT ON COLUMN clients_stats.stations_zones.us_id        IS 'Stations-zone creator (FK)';

    -- Tabella che definisce le tipologie di statistica
    -- DROP TABLE IF EXISTS clients_stats.statistics;
    CREATE TABLE clients_stats.statistics
    (
        stat_id   integer NOT NULL,
        stat_desc text NOT NULL,
        stat_note text,

        CONSTRAINT clients_stats_stats_pkey PRIMARY KEY (stat_id)
    );

    -- grants
    GRANT ALL ON TABLE    clients_stats.statistics TO group_admin;
    GRANT ALL ON TABLE    clients_stats.statistics TO group_bobo;
    GRANT ALL ON TABLE    clients_stats.statistics TO group_tools;
    GRANT SELECT ON TABLE clients_stats.statistics TO group_readonly;

    -- comments
    COMMENT ON TABLE  clients_stats.statistics           IS 'Table defining the type of statistics';
    COMMENT ON COLUMN clients_stats.statistics.stat_id   IS 'Statistics id';
    COMMENT ON COLUMN clients_stats.statistics.stat_desc IS 'Statistics description';
    COMMENT ON COLUMN clients_stats.statistics.stat_note IS 'Statistics note';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- DROP VIEW clients_stats.view_limits;
    CREATE OR REPLACE VIEW clients_stats.view_limits AS
    SELECT
        l.limit_id,
        -- p.pollutant_notation,
        l.pollutant_id,
        l.protection_target_id,
        l.objective_type_id,
        l.reporting_metric_id,
        l.limit_aggr,
        l.stat_id,
        s.stat_desc,
        l.lt_id,
        lt.lt_desc,
        l.limit_value,
        l.limit_sup,
        l.limit_upper_eval,
        l.limit_lower_eval,
        l.limit_unit,
        l.limit_note
    FROM
        clients_stats.limits l
        -- LEFT JOIN infoaria.pollutants p USING (pollutant_id)
        LEFT JOIN clients_stats.statistics s USING (stat_id)
        LEFT JOIN clients_stats.limits_type lt USING (lt_id)
    ORDER BY
        l.pollutant_id, l.stat_id;

    -- grants
    GRANT ALL ON TABLE    clients_stats.view_limits TO group_admin;
    GRANT ALL ON TABLE    clients_stats.view_limits TO group_bobo;
    GRANT ALL ON TABLE    clients_stats.view_limits TO group_tools;
    GRANT SELECT ON TABLE clients_stats.view_limits TO group_readonly;

    -- DROP VIEW clients_stats.view_results;
    CREATE OR REPLACE VIEW clients_stats.view_results AS
    SELECT
        r.res_date,
        r.stpr_id,
        sp.station_id,
        s.station_name,
        sp.param_id,
        l.pollutant_id,
        -- p.pollutant_notation,
        r.limit_id,
        l.stat_id,
        l.lt_id,
        l.limit_unit,
        r.res_value,
        l.limit_value,
        r.res_exceed_value,
        r.res_num_sup,
        l.limit_sup,
        r.res_exceed_num_sup,
        r.res_perc_valid,
        r.res_aggrules,
        l.limit_upper_eval,
        l.limit_lower_eval,
        l.limit_note
    FROM
        clients_stats.results r
        LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
        LEFT JOIN metadata.stations s USING (station_id)
        LEFT JOIN clients_stats.limits l USING (limit_id)
        -- LEFT JOIN infoaria.pollutants p USING (pollutant_id)
        LEFT JOIN ( VALUES (1, 1), (10, 2), (7, 3), (8, 4), (20, 5), (5, 6), (6001, 7)) t(pollutant_id, pos) USING (pollutant_id)
    ORDER BY
        r.res_date, sp.station_id, pos, l.stat_id;

    -- grants
    GRANT ALL ON TABLE    clients_stats.view_results TO group_admin;
    GRANT ALL ON TABLE    clients_stats.view_results TO group_bobo;
    GRANT ALL ON TABLE    clients_stats.view_results TO group_tools;
    GRANT SELECT ON TABLE clients_stats.view_results TO group_readonly;

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Funzione che controlla la validità dei dati prima di altre elaborazioni
    -- DROP FUNCTION clients_stats.f_check_data(integer, integer, timestamp, timestamp);
    CREATE OR REPLACE FUNCTION clients_stats.f_check_data(
        usid integer,
        zone integer,
        d_from timestamp without time zone,
        d_to timestamp without time zone)
        RETURNS jsonb
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$

    DECLARE
        rec record;  -- result record
        irec record; -- inner result record
        q text;      -- dynamic query
        f boolean;   -- error flag
        r jsonb;     -- result
    BEGIN
        --
        -- TEST SELECT clients_stats.f_check_data( 4::integer , 8::integer , '2023-01-01 00:00'::timestamp, '2024-01-31 23:00'::timestamp)
        --

        RAISE NOTICE 'SELECT clients_stats.f_check_data';

        /* build jsonb container */
        SELECT jsonb_build_object(
            'res'        , 'true',
            'negatives'  , '{}'::jsonb,
            'suspects'   , '{}'::jsonb,
            'not_checked', '{}'::jsonb,
            'code_diff'  , '{}'::jsonb,
            'pm10_prob'  , '{}'::jsonb
        ) INTO r;

        f = FALSE;

        /*
        * get fulltable and measure_id linked to st_pr_id
        * loop through:
        *   - all stations that belong to the selected zone
        *   - all active parameters for the final validation, based on the portal to which the user is linked
        */
        FOR rec IN

            WITH t AS (
                SELECT
                    value AS param_id
                FROM
                    jsonb_to_recordset(
                        bobo.f_get_user_portal_options( usid, '/dat_validaz_finale' )-> 'params'
                    ) AS x(value integer, label text)
                ORDER BY
                    value
            )
            SELECT
                sp.stpr_id,
                s.station_id,
                s.station_name,
                s.station_schema ||'.'||COALESCE(s.station_prefix, '')||s.station_table AS fulltable,
                sp.stpr_table_id,
                CONCAT_WS('-', p.param_name, sp.stpr_note) AS param_name
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.stations s USING (station_id)
                LEFT JOIN metadata.parameters p USING (param_id)
            WHERE
                station_id IN ( SELECT UNNEST(station_ids) FROM clients_stats.stations_zones WHERE sz_id = zone)
                AND param_id IN ( SELECT param_id FROM t )
            ORDER BY
                station_id, stpr_id

        LOOP

            -- RAISE NOTICE '';
            -- RAISE NOTICE 'Station: %, parameter: % % ', rec.station_name, rec.param_name, rec.stpr_table_id;
            -- RAISE NOTICE '-- PRIMO CONTROLLO: presenza negativi e dati non visti';

            /* build dynamic query with data returned by previous query */
            q =
                'SELECT'||E'\n'
                ||'    COUNT(*) FILTER (WHERE measure_value < 0 AND post_validity_code >= -1) AS cnt_negative,'||E'\n'
                ||'    COUNT(*) FILTER (WHERE post_validity_code = -1) AS cnt_suspect,'||E'\n'
                ||'    COUNT(*) FILTER (WHERE final_validity_code = 0) AS cnt_not_checked'||E'\n'
                ||'FROM  '||E'\n'
                ||'    '||rec.fulltable||' '||E'\n'
                ||'WHERE '||E'\n'
                ||'    measure_id = '||rec.stpr_table_id||' '||E'\n'
                ||'    AND measure_date_time BETWEEN '||quote_literal(d_from)||'::timestamp AND '||quote_literal(d_to)||'::timestamp ;'||E'\n';

            -- RAISE NOTICE 'Query : %', q;
            EXECUTE q INTO irec;

            /* checks if negative and valid values exist */
            IF irec.cnt_negative > 0 THEN
                /* set error flag */
                f = TRUE;

                -- RAISE NOTICE '-- SECONDO CONTROLLO: Presenza valori negativi';

                /*
                * check if for the looped station the jsonb container is null
                *  - if TRUE then create it and append current parameter
                *  - else append current parameter
                */
                IF  r->'negatives'->(rec.station_id::text)  IS NULL  THEN
                    -- RAISE NOTICE '-- Creazione oggetto per la stazione % ', rec.station_id;
                    -- update the result jsonb variable
                    SELECT jsonb_insert(
                        r,
                        ARRAY['negatives', rec.station_id::text]::text[],
                        jsonb_build_object('name', rec.station_name, 'params', array_to_json(ARRAY[rec.param_name]::text[]) ),
                        false
                    ) INTO r;

                    -- RAISE NOTICE 'Jsonb parziale: %', jsonb_pretty(r);

                ELSE
                    -- RAISE NOTICE '-- Aggiunta parametro % per la stazione % ', rec.param_name, rec.station_id;
                    SELECT jsonb_set(
                            r,
                            ARRAY['negatives', rec.station_id::text, 'params']::text[],
                            r->'negatives'->(rec.station_id::text)->'params' || to_jsonb(rec.param_name),
                            true
                        ) INTO r;

                        -- RAISE NOTICE 'Jsonb parziale: %', jsonb_pretty(r);
                END IF;
            END IF;

            /* checks if suspect values exist */
            IF irec.cnt_suspect > 0 THEN
                /* set error flag */
                f = TRUE;

                -- RAISE NOTICE '-- Presenza valori sospetti';

                /*
                * check if for the looped station the jsonb container is null
                *  - if TRUE then create it and append current parameter
                *  - else append current parameter
                */
                IF  r->'suspects'->(rec.station_id::text)  IS NULL  THEN
                    -- RAISE NOTICE '-- Creazione oggetto per la stazione % ', rec.station_id;
                    -- update the result jsonb variable
                    SELECT jsonb_insert(
                        r,
                        ARRAY['suspects', rec.station_id::text]::text[],
                        jsonb_build_object('name', rec.station_name, 'params', array_to_json(ARRAY[rec.param_name]::text[]) ),
                        false
                    ) INTO r;

                    -- RAISE NOTICE 'Jsonb parziale: %', jsonb_pretty(r);

                ELSE
                    -- RAISE NOTICE '-- Aggiunta parametro % per la stazione % ', rec.param_name, rec.station_id;
                    SELECT jsonb_set(
                            r,
                            ARRAY['suspects', rec.station_id::text, 'params']::text[],
                            r->'suspects'->(rec.station_id::text)->'params' || to_jsonb(rec.param_name),
                            true
                        ) INTO r;

                        -- RAISE NOTICE 'Jsonb parziale: %', jsonb_pretty(r);
                END IF;
            END IF;

            /* checks if not checked values exist */
            IF irec.cnt_not_checked > 0 THEN
                -- set error flag
                f = TRUE;
                -- RAISE NOTICE '-- Presenza dati non validati!';

                /*
                * check if for the looped station the jsonb container is null
                *  - if TRUE then create it and append current parameter
                *  - else append current parameter
                */
                IF  r->'not_checked'->(rec.station_id::text)  IS NULL  THEN
                    -- RAISE NOTICE '-- Creazione oggetto per la stazione % ', rec.station_id;
                    -- update the result jsonb variable
                    SELECT jsonb_insert(
                        r,
                        ARRAY['not_checked', rec.station_id::text]::text[],
                        jsonb_build_object('name', rec.station_name, 'params', array_to_json(ARRAY[rec.param_name]::text[]) ),
                        false
                    ) INTO r;

                    -- RAISE NOTICE 'Jsonb parziale: %', jsonb_pretty(r);

                ELSE
                    -- RAISE NOTICE '-- Aggiunta parametro % per la stazione % ', rec.param_name, rec.station_id;
                    SELECT jsonb_set(
                            r,
                            ARRAY['not_checked', rec.station_id::text, 'params']::text[],
                            r->'not_checked'->(rec.station_id::text)->'params' || to_jsonb(rec.param_name),
                            true
                        ) INTO r;

                        -- RAISE NOTICE 'Jsonb parziale: %', jsonb_pretty(r);
                END IF;
            END IF;

        END LOOP;

        -- RAISE NOTICE '';
        -- RAISE NOTICE '-- TERZO CONTROLLO: coerenza validazione tra parametri dello stesso strumento';
        FOR rec IN
            SELECT
                sp.stpr_group_id,
                MAX(s.station_id) AS station_id,
                MAX(s.station_name) AS station_name,
                MAX(s.station_schema) ||'.'||COALESCE(MAX(s.station_prefix), '')||MAX(s.station_table) AS fulltable,
                ARRAY_AGG(sp.stpr_table_id) AS table_ids,
                ARRAY_AGG(CONCAT_WS('-', p.param_name, sp.stpr_note)) AS params
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.stations s USING (station_id)
                LEFT JOIN metadata.parameters p USING (param_id)
            WHERE
                station_id IN ( SELECT UNNEST(station_ids) FROM clients_stats.stations_zones WHERE sz_id = zone)
                AND param_id IN ( 30,31,32 )

            GROUP BY
                stpr_group_id
            ORDER BY
                stpr_group_id

        LOOP

            /* Controllo coerenza validazione tra parametri dello stesso strumento */
            -- RAISE NOTICE '';
            -- RAISE NOTICE 'Station: %, parameters IDs: % ', rec.station_name, rec.table_ids;

            /* build dynamic query with data returned by previous query */
            q =
                'WITH t AS ('||E'\n'
                ||'    SELECT'||E'\n'
                ||'        measure_date_time,'||E'\n'
                -- ||'        COUNT(DISTINCT post_validity_code) AS counter'||E'\n'
                ||'         COUNT('||E'\n'
                ||'             DISTINCT('||E'\n'
                ||'                 CASE '||E'\n'
                ||'                     WHEN post_validity_code >= 0 THEN 1'||E'\n'
                ||'                     ELSE -1'||E'\n'
                ||'                 END'||E'\n'
                ||'             )'||E'\n'
                ||'         ) AS counter'||E'\n'
                ||'    FROM  '||E'\n'
                ||'        '||rec.fulltable||' '||E'\n'
                ||'    WHERE '||E'\n'
                ||'        measure_id IN ('|| array_to_string(rec.table_ids, ',') ||')'||E'\n'
                ||'        AND measure_date_time BETWEEN '||quote_literal(d_from)||'::timestamp AND '||quote_literal(d_to)||'::timestamp'||E'\n'
                ||'    GROUP BY '||E'\n'
                ||'        measure_date_time'||E'\n'
                ||'    ORDER BY '||E'\n'
                ||'        measure_date_time'||E'\n'
                ||')'||E'\n'
                ||'SELECT '||E'\n'
                ||'    COUNT(*) AS cnt_diff, '||E'\n'
                ||'    ARRAY_AGG(DISTINCT(measure_date_time::date) ) AS dates'||E'\n'
                ||'FROM t'||E'\n'
                ||'WHERE counter > 1'||E'\n'
                ||'ORDER BY 1;'||E'\n';

            --RAISE NOTICE 'Query : %', q;
            EXECUTE q INTO irec;

            /* checks if post_validity_code differences exist */
            IF irec.cnt_diff > 0 THEN
                /* set error flag */
                f = TRUE;

                -- RAISE NOTICE '-- Presenza differenze tra post_validity_code';

                /*
                * check if for the looped station the jsonb container is null
                *  - if TRUE then create it and append current parameter
                */
                IF  r->'code_diff'->(rec.station_id::text)  IS NULL  THEN
                    -- RAISE NOTICE '-- Creazione oggetto per la stazione % ', rec.station_id;
                    -- update the result jsonb variable
                    SELECT jsonb_insert(
                        r,
                        ARRAY['code_diff', rec.station_id::text]::text[],
                        jsonb_build_object('name', rec.station_name, 'params', rec.params, 'dates', array_to_json(irec.dates::text[])),
                        false
                    ) INTO r;

                    --RAISE NOTICE 'Jsonb parziale: %', jsonb_pretty(r);

                END IF;
            END IF;

        END LOOP;

        /* Controllo problemi PM10: PM10 < PM2.5 e PM compreso tra 0 e 1 */
        -- RAISE NOTICE '-- QUARTO CONTROLLO: coerenza validazione tra parametri dello stesso strumento';
        FOR rec IN
            SELECT
                sp.station_id,
                MAX(s.station_name) AS station_name,
                MAX(s.station_schema) ||'.'||COALESCE(MAX(s.station_prefix), '')||MAX(s.station_table) AS fulltable,
                MAX(sp.stpr_table_id) FILTER (WHERE sp.param_id = 50) AS table_id_pm10,
                MAX(sp.stpr_table_id) FILTER (WHERE sp.param_id = 48) AS table_id_pm25
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.stations s USING (station_id)
                LEFT JOIN metadata.parameters p USING (param_id)
            WHERE
                station_id IN ( SELECT UNNEST(station_ids) FROM clients_stats.stations_zones WHERE sz_id = zone)
                AND param_id IN (48, 50)
                -- PM10 must exists
                AND EXISTS (
                    SELECT 1 FROM metadata.stations_parameters sp2  WHERE sp2.station_id = sp.station_id AND sp2.param_id = 50
                )
                AND EXISTS (
                    SELECT 1
                    FROM
                        metadata.stations_instruments si
                    WHERE
                        si.stpr_group_id = sp.stpr_group_id
                        AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[]') && tsrange(d_from, d_to, '[]')
                        AND si.stin_master IS TRUE
                )
            GROUP BY sp.station_id
            ORDER BY sp.station_id

        LOOP

            /* Controllo coerenza validazione tra parametri dello stesso strumento */
            -- RAISE NOTICE '';
            -- RAISE NOTICE 'Station: %', rec.station_name;

            /* build dynamic query with data returned by previous query */
            q =
                'WITH t AS ('||E'\n'
                ||'    SELECT'||E'\n'
                ||'        measure_date_time,'||E'\n'
                ||'        measure_id,'||E'\n'
                ||'        measure_value'||E'\n'
                ||'    FROM  '||E'\n'
                ||'        '||rec.fulltable||'  '||E'\n'
                ||'    WHERE '||E'\n'
                ||'        measure_id IN ('||CONCAT_WS(',', rec.table_id_pm10, rec.table_id_pm25)||') '||E'\n'
                ||'        AND measure_date_time BETWEEN '||quote_literal(d_from)||'::timestamp AND '||quote_literal(d_to)||'::timestamp '||E'\n'
                ||'        AND post_validity_code >= 0 '||E'\n'
                ||'    ORDER BY'||E'\n'
                ||'        measure_value'||E'\n'
                ||'),'||E'\n';

                /* da riattivare per controllo PM10 between 0 e 1
                    ||'t1 AS ('||E'\n'
                    ||'    SELECT'||E'\n'
                    ||'        COUNT(*) AS cnt_pm10_anomalous'||E'\n'
                    ||'    FROM  '||E'\n'
                    ||'        t'||E'\n'
                    ||'    WHERE '||E'\n'
                    ||'        measure_id = '||rec.table_id_pm10||' '||E'\n'
                    ||'        AND measure_value BETWEEN 0 AND 1'||E'\n'
                    ||'),'||E'\n';
                */
            IF rec.table_id_pm25 IS NOT NULL THEN
                q = q
                    ||'t2 AS ('||E'\n'
                    ||'    SELECT'||E'\n'
                    ||'        COUNT(*) FILTER (WHERE pm10.measure_value < pm25.measure_value) AS cnt_pm10_pm25'||E'\n'
                    ||'    FROM  '||E'\n'
                    ||'        t pm10'||E'\n'
                    ||'        LEFT JOIN t pm25 ON (pm10.measure_date_time = pm25.measure_date_time AND pm25.measure_id = '||rec.table_id_pm25||')'||E'\n'
                    ||'    WHERE'||E'\n'
                    ||'        pm10.measure_id = '||rec.table_id_pm10||' '||E'\n'
                    ||')'||E'\n';
            ELSE
                q = q
                    ||'t2 AS ('||E'\n'
                    ||'    SELECT'||E'\n'
                    ||'        0 AS cnt_pm10_pm25'||E'\n'
                    ||')'||E'\n';
            END IF;

            /* # da riattivare per controllo PM10 between 0 e 1
                q = q
                    ||'SELECT'||E'\n'
                    ||'    cnt_pm10_anomalous + cnt_pm10_pm25 AS cnt_problems'||E'\n'
                    ||'FROM '||E'\n'
                    ||'    t1, t2'||E'\n';
                */
            q = q
                ||'SELECT'||E'\n'
                ||'    cnt_pm10_pm25::integer AS cnt_problems'||E'\n'
                ||'FROM '||E'\n'
                ||'    t2'||E'\n';

            -- RAISE NOTICE 'Query : %', q;
            EXECUTE q INTO irec;

            /* checks if pm10 problems exist */
            IF irec.cnt_problems > 0 THEN
                /* set error flag */
                f = TRUE;

                -- RAISE NOTICE '-- Presenza problemi per il PM10';

                /*
                * check if for the looped station the jsonb container is null
                *  - if TRUE then create it and append current parameter
                */
                IF  r->'pm10_prob'->(rec.station_id::text)  IS NULL  THEN
                    -- RAISE NOTICE '-- Creazione oggetto per la stazione % ', rec.station_id;
                    -- update the result jsonb variable
                    SELECT jsonb_insert(
                        r,
                        ARRAY['pm10_prob', rec.station_id::text]::text[],
                        jsonb_build_object('name', rec.station_name),
                        false
                    ) INTO r;

                    --RAISE NOTICE 'Jsonb parziale: %', jsonb_pretty(r);

                END IF;
            END IF;

        END LOOP;

        /*
        * Update result flag
        *   - TRUE if it's all ok
        *   - FALSE if there are problems
        */
        SELECT jsonb_set(
            r,
            '{res}'::text[],
            to_jsonb(NOT f)
        ) INTO r;

        /* return value */
        RETURN r;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients_stats.f_check_data(): %', SQLERRM;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients_stats.f_check_data(integer, integer, timestamp, timestamp) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients_stats.f_check_data(integer, integer, timestamp, timestamp) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients_stats.f_check_data(integer, integer, timestamp, timestamp) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients_stats.f_check_data(integer, integer, timestamp, timestamp) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients_stats.f_check_data(integer, integer, timestamp, timestamp)
        IS 'Function that controls validity of the data before other elaborations';

    -- Funzione che calcola le statistiche di validità dei parametri di una determinata stazione a livello utente
    -- DROP FUNCTION clients_stats.f_user_validity_analysis(integer, timestamp, timestamp);
    CREATE OR REPLACE FUNCTION clients_stats.f_user_validity_analysis(
        stprid integer,
        d1 timestamp,
        d2 timestamp
    )
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    VOLATILE
    AS $BODY$

    DECLARE
        t text;    -- tablename
        p integer; -- parameter table id
        q text;    -- dynamic query
        r jsonb;   -- result
    BEGIN
        --
        -- TEST SELECT * FROM clients_stats.f_user_validity_analysis( 231 , '2023-09-05 00:00'::timestamp, '2023-09-12 23:00'::timestamp );
        --
        SELECT
            s.station_schema ||'.'||COALESCE(s.station_prefix, '')||s.station_table, sp.stpr_table_id INTO t, p
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations s USING (station_id)
        WHERE
            stpr_id = stprid;

        IF NOT FOUND THEN
            RAISE NOTICE 'Parameter % not found', stprid;
            RETURN NULL;
        END IF;

        q =
            '-- calculate difference in hours between 2 dates'||E'\n'
            ||'WITH h AS('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        ( EXTRACT(''epoch'' FROM '||quote_literal(d2)||'::timestamp - '||quote_literal(d1)||'::timestamp) / 3600 )::integer + 1 AS diff'||E'\n'
            ||'),'||E'\n'
            ||'d AS ('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        measure_id,'||E'\n'
            ||'        extract_code,'||E'\n'
            ||'        post_validity_code,'||E'\n'
            ||'        main.signed_bitmask_toarray(post_validity_code, 10) AS user_codes'||E'\n'
            ||'    FROM '||E'\n'
            ||'         '||t||' '||E'\n'
            ||'    WHERE'||E'\n'
            ||'        measure_id = '||p||' '||E'\n'
            ||'        AND measure_date_time BETWEEN '||quote_literal(d1)||'::timestamp AND '||quote_literal(d2)||'::timestamp'||E'\n'
            ||'),'||E'\n'
            ||'c AS ('||E'\n'
            ||'    SELECT'||E'\n'
            ||'        measure_id,'||E'\n'
            ||'        COALESCE(SUM(extract_code) FILTER (WHERE post_validity_code < 0) , 0 ) AS count_not_valid,'||E'\n'
            ||'        COALESCE(SUM(extract_code) FILTER (WHERE post_validity_code >= 0) , 0 ) AS count_valid,'||E'\n'
            ||'        COALESCE(SUM(extract_code) , 0 ) AS count_total,'||E'\n'
            ||'        ARRAY['||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE -1024 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE  -512 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE  -256 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE  -128 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE   -64 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE   -32 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE   -16 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE    -8 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE    -4 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE    -2 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE    -1 = ANY(user_codes)) , 0 )'||E'\n'
            ||'        ] AS count_notvalid_codes,'||E'\n'
            ||'        ARRAY['||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE post_validity_code = 0) , 0 ), '||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE    1 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE    2 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE    4 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE    8 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE   16 = ANY(user_codes)) , 0 ),'||E'\n'
            ||'            COALESCE( SUM(extract_code) FILTER (WHERE   32 = ANY(user_codes)) , 0 )'||E'\n'
            ||'        ] AS count_valid_codes'||E'\n'
            ||'    FROM d'||E'\n'
            ||'    GROUP BY measure_id'||E'\n'
            ||')'||E'\n'
            ||'SELECT'||E'\n'
            ||'    jsonb_build_object( '||E'\n'
            ||'        ''expected_data''        , h.diff,'||E'\n'
            ||'        ''count_not_valid''      , c.count_not_valid,'||E'\n'
            ||'        ''count_valid''          , c.count_valid,'||E'\n'
            ||'        ''count_total''          , c.count_total,'||E'\n'
            ||'        ''count_missing''        , ( h.diff - c.count_total ),'||E'\n'
            ||'        ''count_notvalid_codes'' , c.count_notvalid_codes, '||E'\n'
            ||'        ''count_valid_codes''    , c.count_valid_codes '||E'\n'
            --||'        ''perc_codes'' , ( SELECT ARRAY_AGG(TRUNC(( n / h.diff::numeric * 100 ), 1)) FROM UNNEST(c.count_codes) AS n ) '||E'\n'
            ||'    )'||E'\n'
            ||'FROM'||E'\n'
            ||'    c, h'||E'\n';

        /* execute query and store result */
        EXECUTE q INTO r;

        /* return value */
        RETURN r;


        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients_stats.f_user_validity_analysis(): %', SQLERRM;
            RETURN NULL;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION clients_stats.f_user_validity_analysis(integer, timestamp, timestamp) TO group_readonly;
    GRANT EXECUTE ON FUNCTION clients_stats.f_user_validity_analysis(integer, timestamp, timestamp) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients_stats.f_user_validity_analysis(integer, timestamp, timestamp) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients_stats.f_user_validity_analysis(integer, timestamp, timestamp) TO group_tools;

    -- comment
    COMMENT ON FUNCTION clients_stats.f_user_validity_analysis(integer, timestamp, timestamp)
        IS 'Function that calculates station-parameter validity''s statistics at user level';

-- SCHEMA equipments

    -- DROP SCHEMA IF EXISTS equipments CASCADE;
    CREATE SCHEMA equipments
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA equipments TO group_admin;
    GRANT USAGE ON SCHEMA equipments TO group_bobo;
    GRANT USAGE ON SCHEMA equipments TO group_readonly;
    GRANT USAGE ON SCHEMA equipments TO group_tools;
    COMMENT ON SCHEMA equipments IS 'Equipments schema for OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella che contiene i vari brands degli strumenti
    -- DROP TABLE IF EXISTS equipments.brands;
    CREATE TABLE equipments.brands(
        brand_id   serial,
        brand_name text NOT NULL,

        CONSTRAINT equipments_brands_pkey PRIMARY KEY (brand_id),
        CONSTRAINT equipments_brands_ukey1 UNIQUE (brand_name)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.brands TO group_admin;
    GRANT ALL ON TABLE    equipments.brands TO group_bobo;
    GRANT ALL ON TABLE    equipments.brands TO group_tools;
    GRANT SELECT ON TABLE equipments.brands TO group_readonly;

    -- comments
    COMMENT ON TABLE  equipments.brands            IS 'Table with principal information about brands';
    COMMENT ON COLUMN equipments.brands.brand_id   IS 'Brand ID';
    COMMENT ON COLUMN equipments.brands.brand_name IS 'Brand name';

    -- Tabella che contiene i vari costruttori degli strumenti
    -- DROP TABLE IF EXISTS equipments.constructors;
    CREATE TABLE equipments.constructors(
        constr_id   serial,
        constr_name text NOT NULL,

        CONSTRAINT equipments_constructors_pkey PRIMARY KEY (constr_id),
        CONSTRAINT equipments_constructors_ukey1 UNIQUE (constr_name)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.constructors TO group_admin;
    GRANT ALL ON TABLE    equipments.constructors TO group_bobo;
    GRANT ALL ON TABLE    equipments.constructors TO group_tools;
    GRANT SELECT ON TABLE equipments.constructors TO group_readonly;

    -- comments
    COMMENT ON TABLE  equipments.constructors             IS 'Table with principal information about constructors';
    COMMENT ON COLUMN equipments.constructors.constr_id   IS 'Constructor ID';
    COMMENT ON COLUMN equipments.constructors.constr_name IS 'Constructor name';

    -- Tabella che contiene gli strumenti
    -- DROP TABLE IF EXISTS equipments.instruments CASCADE;
    CREATE TABLE equipments.instruments(
        instr_id            serial,
        instr_type_id       integer NOT NULL,
        instr_arpa_id       text DEFAULT NULL,
        instr_owner         text DEFAULT NULL,
        instr_serial_num    text DEFAULT NULL,
        instr_name          text DEFAULT NULL,
        instr_active        boolean DEFAULT TRUE,
        instr_note          text DEFAULT NULL,
        network_types       integer[] NOT NULL,
        instr_delivery_date date NOT NULL,
        instr_dismiss_date  date,
        insert_time         timestamp without time zone  DEFAULT CURRENT_TIMESTAMP,
        insert_user         integer,

        CONSTRAINT equipments_instruments_pkey PRIMARY KEY (instr_id),
        CONSTRAINT equipments_instruments_ukey UNIQUE (instr_serial_num)
        -- CONSTRAINT equipments_instruments_fkey1 FOREIGN KEY (instr_type_id)
        -- REFERENCES equipments.instruments_type (instr_type_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT equipments_instruments_fkey2 FOREIGN KEY (insert_user)
        -- REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.instruments TO group_admin;
    GRANT ALL ON TABLE    equipments.instruments TO group_bobo;
    GRANT ALL ON TABLE    equipments.instruments TO group_tools;
    GRANT SELECT ON TABLE equipments.instruments TO group_readonly;
    GRANT ALL ON SEQUENCE equipments.instruments_instr_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE equipments.instruments_instr_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE equipments.instruments_instr_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  equipments.instruments                     IS 'Table holding the list of real instruments';
    COMMENT ON COLUMN equipments.instruments.instr_id            IS 'Instrument ID primary key';
    COMMENT ON COLUMN equipments.instruments.instr_type_id       IS 'Instrument type id (FK)';
    COMMENT ON COLUMN equipments.instruments.instr_arpa_id       IS 'Instrument ARPA id';
    COMMENT ON COLUMN equipments.instruments.instr_owner         IS 'Instrument owner';
    COMMENT ON COLUMN equipments.instruments.instr_serial_num    IS 'Instrument serial number';
    COMMENT ON COLUMN equipments.instruments.instr_name          IS 'Instrument name';
    COMMENT ON COLUMN equipments.instruments.instr_active        IS 'Instrument active';
    COMMENT ON COLUMN equipments.instruments.instr_note          IS 'Instrument note';
    COMMENT ON COLUMN equipments.instruments.network_types       IS 'Array of networks to which the instrument refers';
    COMMENT ON COLUMN equipments.instruments.instr_delivery_date IS 'Instrument delivery date';
    COMMENT ON COLUMN equipments.instruments.instr_dismiss_date  IS 'Instrument dismiss date';
    COMMENT ON COLUMN equipments.instruments.insert_time         IS 'Instrument insert time';
    COMMENT ON COLUMN equipments.instruments.insert_user         IS 'Instrument insert user';

    -- Tabella che contiene le varie tipologie di strumento
    -- DROP TABLE IF EXISTS equipments.instruments_type CASCADE;
    CREATE TABLE equipments.instruments_type(
        instr_type_id        serial,
        constr_id            integer NOT NULL DEFAULT 0,
        brand_id             integer NOT NULL DEFAULT 0,
        model_id             integer NOT NULL DEFAULT 0,
        category_id          integer NOT NULL DEFAULT 0,
        instr_type_range_min real DEFAULT NULL,
        instr_type_range_max real DEFAULT NULL,
        instr_type_precision real DEFAULT NULL,
        instr_type_unit      text DEFAULT NULL,
        instr_type_note      text DEFAULT NULL,

        CONSTRAINT equipments_instruments_type_pkey PRIMARY KEY (instr_type_id),
        CONSTRAINT equipments_instruments_type_ukey UNIQUE (constr_id, brand_id, model_id, category_id)
        -- CONSTRAINT equipments_instruments_type_fkey1 FOREIGN KEY (constr_id)
        -- REFERENCES equipments.constructors (constr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT equipments_instruments_type_fkey2 FOREIGN KEY (brand_id)
        -- REFERENCES equipments.brands (brand_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT equipments_instruments_type_fkey3 FOREIGN KEY (model_id)
        -- REFERENCES equipments.models (model_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT equipments_instruments_type_fkey4 FOREIGN KEY (category_id)
        -- REFERENCES equipments.categories (category_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.instruments_type TO group_admin;
    GRANT ALL ON TABLE    equipments.instruments_type TO group_bobo;
    GRANT ALL ON TABLE    equipments.instruments_type TO group_tools;
    GRANT SELECT ON TABLE equipments.instruments_type TO group_readonly;

    -- comments
    COMMENT ON TABLE  equipments.instruments_type                      IS 'Table holding the list of principal instruments types';
    COMMENT ON COLUMN equipments.instruments_type.instr_type_id        IS 'Instrument type ID primary key';
    COMMENT ON COLUMN equipments.instruments_type.constr_id            IS 'Constructor id (FK)';
    COMMENT ON COLUMN equipments.instruments_type.brand_id             IS 'Brand id (FK)';
    COMMENT ON COLUMN equipments.instruments_type.model_id             IS 'Model id (FK)';
    COMMENT ON COLUMN equipments.instruments_type.category_id          IS 'Category id (FK)';
    COMMENT ON COLUMN equipments.instruments_type.instr_type_range_min IS 'Instrument type measurement  range min';
    COMMENT ON COLUMN equipments.instruments_type.instr_type_range_max IS 'Instrument type measurement range max';
    COMMENT ON COLUMN equipments.instruments_type.instr_type_precision IS 'Instrument measurement precision';
    COMMENT ON COLUMN equipments.instruments_type.instr_type_unit      IS 'Instrument measurement precision unit';
    COMMENT ON COLUMN equipments.instruments_type.instr_type_unit      IS 'Instrument measurement note';

    -- Tabella che contiene i vari modelli degli strumenti
    -- DROP TABLE IF EXISTS equipments.models;
    CREATE TABLE equipments.models(
        model_id   serial,
        model_name text NOT NULL,

        CONSTRAINT equipments_models_pkey PRIMARY KEY (model_id),
        CONSTRAINT equipments_models_ukey1 UNIQUE (model_name)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.models TO group_admin;
    GRANT ALL ON TABLE    equipments.models TO group_bobo;
    GRANT ALL ON TABLE    equipments.models TO group_tools;
    GRANT SELECT ON TABLE equipments.models TO group_readonly;

    -- comments
    COMMENT ON TABLE  equipments.models            IS 'Table with principal information about models';
    COMMENT ON COLUMN equipments.models.model_id   IS 'Model ID';
    COMMENT ON COLUMN equipments.models.model_name IS 'Model name';

    -- Tabella che contiene le varie categorie di strumenti
    -- DROP TABLE IF EXISTS equipments.categories;
    CREATE TABLE equipments.categories(
        category_id         serial,
        category_name       text NOT NULL,
        category_visible    boolean DEFAULT TRUE,
        category_short_name text DEFAULT NULL,

        CONSTRAINT equipments_categories_pkey PRIMARY KEY (category_id),
        CONSTRAINT equipments_categories_ukey1 UNIQUE (category_name)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.categories TO group_admin;
    GRANT ALL ON TABLE    equipments.categories TO group_bobo;
    GRANT ALL ON TABLE    equipments.categories TO group_tools;
    GRANT SELECT ON TABLE equipments.categories TO group_readonly;

    -- comments
    COMMENT ON TABLE  equipments.categories                     IS 'Table with principal information about categories';
    COMMENT ON COLUMN equipments.categories.category_id         IS 'Category ID';
    COMMENT ON COLUMN equipments.categories.category_name       IS 'Category name';
    COMMENT ON COLUMN equipments.categories.category_visible    IS 'Category visible on portal (TRUE/FALSE)';
    COMMENT ON COLUMN equipments.categories.category_short_name IS 'Category short name';

    -- Tabella che contiene i vari alleati delle bombole
    -- DROP TABLE IF EXISTS equipments.cylinder_attachments;
    CREATE TABLE equipments.cylinder_attachments
    (
        att_id        serial,
        cy_id         integer NOT NULL,
        file_original text NOT NULL,
        file_archive  text NOT NULL,
        file_image    boolean DEFAULT false,
        att_fulldate  timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT equipments_cylinder_attachments_pkey PRIMARY KEY (att_id),
        CONSTRAINT equipments_cylinder_attachments_ukey UNIQUE (cy_id, file_archive)
        -- CONSTRAINT equipments_cylinder_attachments_fk1 FOREIGN KEY (cy_id)
        --     REFERENCES equipments.cylinders  (cy_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.cylinder_attachments TO group_admin;
    GRANT ALL ON TABLE    equipments.cylinder_attachments TO group_bobo;
    GRANT ALL ON TABLE    equipments.cylinder_attachments TO group_tools;
    GRANT SELECT ON TABLE equipments.cylinder_attachments TO group_readonly;
    GRANT ALL ON SEQUENCE equipments.cylinder_attachments_att_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE equipments.cylinder_attachments_att_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE equipments.cylinder_attachments_att_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  equipments.cylinder_attachments               IS 'Table storing cylinders attachments';
    COMMENT ON COLUMN equipments.cylinder_attachments.att_id        IS 'Attachment ID (PK)';
    COMMENT ON COLUMN equipments.cylinder_attachments.cy_id         IS 'Cylinder ID (FK)';
    COMMENT ON COLUMN equipments.cylinder_attachments.file_original IS 'Original file name';
    COMMENT ON COLUMN equipments.cylinder_attachments.file_archive  IS 'Archive file name';
    COMMENT ON COLUMN equipments.cylinder_attachments.file_image    IS 'Flag if file is an image';
    COMMENT ON COLUMN equipments.cylinder_attachments.att_fulldate  IS 'Attachment insert fulldate';

    -- Tabella che contiene le bombole
    -- DROP TABLE IF EXISTS equipments.cylinders;
    CREATE TABLE equipments.cylinders(
        cy_id            serial,
        cy_arpa_id       text DEFAULT NULL,
        cy_name          text,
        cy_mixture       text,
        category_id      integer NOT NULL,
        cy_built_date    date NOT NULL,
        cy_expiry_date   date NOT NULL,
        cy_ch_values     real[] NOT NULL,
        cy_all_stations  boolean DEFAULT FALSE,
        cy_is_zero       boolean DEFAULT FALSE,
        cy_is_exhausted  boolean DEFAULT FALSE,
        cy_is_returned   boolean DEFAULT FALSE,
        cy_not_compliant boolean DEFAULT FALSE,
        cy_active        boolean DEFAULT TRUE,
        cy_note          text,
        network_types    integer[] NOT NULL,
        insert_time      timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        insert_user      integer,

        CONSTRAINT equipments_cylinders_pkey PRIMARY KEY (cy_id)
        -- CONSTRAINT equipments_cylinders_fkey1 FOREIGN KEY (category_id)
        -- REFERENCES equipments.categories (category_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT equipments_cylinders_fkey2 FOREIGN KEY (insert_user)
        -- REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.cylinders TO group_admin;
    GRANT ALL ON TABLE    equipments.cylinders TO group_bobo;
    GRANT ALL ON TABLE    equipments.cylinders TO group_tools;
    GRANT SELECT ON TABLE equipments.cylinders TO group_readonly;
    GRANT ALL ON SEQUENCE equipments.cylinders_cy_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE equipments.cylinders_cy_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE equipments.cylinders_cy_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  equipments.cylinders                  IS 'Table holding the list of cylinders';
    COMMENT ON COLUMN equipments.cylinders.cy_id            IS 'Cylinder ID (PK)';
    COMMENT ON COLUMN equipments.cylinders.cy_arpa_id       IS 'Cylinder arpa id';
    COMMENT ON COLUMN equipments.cylinders.cy_name          IS 'Cylinder name';
    COMMENT ON COLUMN equipments.cylinders.cy_mixture       IS 'Cylinder mixture';
    COMMENT ON COLUMN equipments.cylinders.category_id      IS 'Cylinder category id (FK)';
    COMMENT ON COLUMN equipments.cylinders.cy_built_date    IS 'Cylinder built date';
    COMMENT ON COLUMN equipments.cylinders.cy_expiry_date   IS 'Cylinder expiry date';
    COMMENT ON COLUMN equipments.cylinders.cy_ch_values     IS 'Cylinder channel values';
    COMMENT ON COLUMN equipments.cylinders.cy_all_stations  IS 'Cylinder refers to all stations';
    COMMENT ON COLUMN equipments.cylinders.cy_is_zero       IS 'Cylinder is zero';
    COMMENT ON COLUMN equipments.cylinders.cy_is_exhausted  IS 'Cylinder is exhausted';
    COMMENT ON COLUMN equipments.cylinders.cy_is_returned   IS 'Cylinder is returned';
    COMMENT ON COLUMN equipments.cylinders.cy_not_compliant IS 'Cylinder is not compliant';
    COMMENT ON COLUMN equipments.cylinders.cy_active        IS 'Cylinder active';
    COMMENT ON COLUMN equipments.cylinders.cy_note          IS 'Cylinder note';
    COMMENT ON COLUMN equipments.cylinders.network_types    IS 'Array of networks to which the cylinder refers';
    COMMENT ON COLUMN equipments.cylinders.insert_time      IS 'Cylinder insert time';
    COMMENT ON COLUMN equipments.cylinders.insert_user      IS 'Cylinder insert user';

    -- Tabella che contiene le varie frequenze delle operazioni
    -- DROP TABLE IF EXISTS equipments.frequencies;
    CREATE TABLE equipments.frequencies
    (
        freq_id    serial,
        freq_desc  text NOT NULL,
        freq_label text NOT NULL,
        freq_db    interval,

        CONSTRAINT equipments_frequencies_pkey PRIMARY KEY (freq_id)
    )
    WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.frequencies TO group_admin;
    GRANT ALL ON TABLE    equipments.frequencies TO group_bobo;
    GRANT ALL ON TABLE    equipments.frequencies TO group_tools;
    GRANT SELECT ON TABLE equipments.frequencies TO group_readonly;

    -- comments
    COMMENT ON TABLE  equipments.frequencies           IS 'Support table for frequencies';
    COMMENT ON COLUMN equipments.frequencies.freq_id   IS 'Frequency ID (PK)';
    COMMENT ON COLUMN equipments.frequencies.freq_desc IS 'Frequency description';
    COMMENT ON COLUMN equipments.frequencies.freq_db   IS 'Frequency interval db';

    -- Tabella che contiene i vari alleati degli strumenti
    -- DROP TABLE equipments.instrument_attachments CASCADE;
    CREATE TABLE equipments.instrument_attachments
    (
        att_id        serial,
        instr_id      integer NOT NULL,
        file_original text NOT NULL,
        file_archive  text NOT NULL,
        file_image    boolean DEFAULT false,
        att_fulldate  timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT equipments_instrument_attachments_pkey PRIMARY KEY (att_id),
        CONSTRAINT equipments_instrument_attachments_ukey UNIQUE (instr_id, file_archive)
        -- CONSTRAINT equipments_instrument_attachments_fk1 FOREIGN KEY (instr_id)
        --     REFERENCES equipments.instruments  (instr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.instrument_attachments TO group_admin;
    GRANT ALL ON TABLE    equipments.instrument_attachments TO group_bobo;
    GRANT ALL ON TABLE    equipments.instrument_attachments TO group_tools;
    GRANT SELECT ON TABLE equipments.instrument_attachments TO group_readonly;
    GRANT ALL ON SEQUENCE equipments.instrument_attachments_att_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE equipments.instrument_attachments_att_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE equipments.instrument_attachments_att_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  equipments.instrument_attachments               IS 'Table storing cylinders attachments';
    COMMENT ON COLUMN equipments.instrument_attachments.att_id        IS 'Attachment ID (PK)';
    COMMENT ON COLUMN equipments.instrument_attachments.instr_id      IS 'Instrument ID (FK)';
    COMMENT ON COLUMN equipments.instrument_attachments.file_original IS 'Original file name';
    COMMENT ON COLUMN equipments.instrument_attachments.file_archive  IS 'Archive file name';
    COMMENT ON COLUMN equipments.instrument_attachments.file_image    IS 'Flag if file is an image';
    COMMENT ON COLUMN equipments.instrument_attachments.att_fulldate  IS 'Attachment insert fulldate';

    -- Tabella che contiene le associazioni strumento-operazioni
    -- DROP TABLE IF EXISTS equipments.instruments_operations;
    CREATE TABLE equipments.instruments_operations
    (
        in_op_id      serial,
        category_id   integer NOT NULL,
        instr_type_id integer,
        op_id         integer NOT NULL,
        op_ca_id      integer NOT NULL,
        freq_id       integer NOT NULL,

        CONSTRAINT equipments_instruments_operations_pkey PRIMARY KEY (in_op_id)
        -- CONSTRAINT equipments_instruments_operations_fk1 FOREIGN KEY (category_id)
        --     REFERENCES equipments.categories (category_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT equipments_instruments_operations_fk2 FOREIGN KEY (instr_type_id)
        --     REFERENCES equipments.instruments_type (instr_type_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT equipments_instruments_operations_fk3 FOREIGN KEY (op_id)
        --     REFERENCES equipments.operations (op_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT equipments_instruments_operations_fk4 FOREIGN KEY (op_ca_id)
        --     REFERENCES equipments.operations_category (op_ca_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT equipments_instruments_operations_fk5 FOREIGN KEY (freq_id)
        --     REFERENCES equipments.frequencies (freq_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.instruments_operations TO group_admin;
    GRANT ALL ON TABLE    equipments.instruments_operations TO group_bobo;
    GRANT ALL ON TABLE    equipments.instruments_operations TO group_tools;
    GRANT SELECT ON TABLE equipments.instruments_operations TO group_readonly;

    -- comments
    COMMENT ON TABLE  equipments.instruments_operations               IS 'Table that holds info about relation between intruments type - operations and frequencies';
    COMMENT ON COLUMN equipments.instruments_operations.in_op_id      IS 'Instrument operation id PK';
    COMMENT ON COLUMN equipments.instruments_operations.category_id   IS 'Instrument category id FK';
    COMMENT ON COLUMN equipments.instruments_operations.instr_type_id IS 'Instrument type id FK';
    COMMENT ON COLUMN equipments.instruments_operations.op_id         IS 'Operation id FK';
    COMMENT ON COLUMN equipments.instruments_operations.op_ca_id      IS 'Operation category FK';
    COMMENT ON COLUMN equipments.instruments_operations.freq_id       IS 'Frequency id FK';

    -- Tabella che contiene le dotazioni
    -- DROP TABLE IF EXISTS equipments.miscellanies;
    CREATE TABLE equipments.miscellanies(
        mi_id               serial,
        mi_arpa_id          text DEFAULT NULL,
        mi_owner            text DEFAULT NULL,
        mi_name             text NOT NULL,
        mi_brand_model      text DEFAULT NULL,
        mi_serial_num       text DEFAULT NULL,
        mi_delivery_date    date DEFAULT NULL,
        mi_dismiss_date     date,
        mi_active           boolean DEFAULT TRUE,
        mi_note             text,
        network_types       integer[] NOT NULL,
        insert_time         timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        insert_user         integer,

        CONSTRAINT equipments_miscellanies_pkey PRIMARY KEY (mi_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.miscellanies TO group_admin;
    GRANT ALL ON TABLE    equipments.miscellanies TO group_bobo;
    GRANT ALL ON TABLE    equipments.miscellanies TO group_tools;
    GRANT SELECT ON TABLE equipments.miscellanies TO group_readonly;
    GRANT ALL ON SEQUENCE equipments.miscellanies_mi_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE equipments.miscellanies_mi_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE equipments.miscellanies_mi_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  equipments.miscellanies                       IS 'Table holding the list of miscellanies';
    COMMENT ON COLUMN equipments.miscellanies.mi_id                 IS 'Miscellany ID (PK)';
    COMMENT ON COLUMN equipments.miscellanies.mi_arpa_id            IS 'Miscellany arpa id';
    COMMENT ON COLUMN equipments.miscellanies.mi_owner              IS 'Miscellany owner';
    COMMENT ON COLUMN equipments.miscellanies.mi_name               IS 'Miscellany name';
    COMMENT ON COLUMN equipments.miscellanies.mi_brand_model        IS 'Miscellany brand/model';
    COMMENT ON COLUMN equipments.miscellanies.mi_serial_num         IS 'Miscellany serial number';
    COMMENT ON COLUMN equipments.miscellanies.mi_delivery_date      IS 'Miscellany delivery date';
    COMMENT ON COLUMN equipments.miscellanies.mi_dismiss_date       IS 'Miscellany dismiss date';
    COMMENT ON COLUMN equipments.miscellanies.mi_active             IS 'Miscellany is active';
    COMMENT ON COLUMN equipments.miscellanies.mi_note               IS 'Miscellany note';
    COMMENT ON COLUMN equipments.miscellanies.network_types         IS 'Array of networks to which the miscellanies refers';
    COMMENT ON COLUMN equipments.miscellanies.insert_time           IS 'Miscellanies insert time';
    COMMENT ON COLUMN equipments.miscellanies.insert_user           IS 'Miscellanies insert user';

    -- Tabella che contiene la varie operazioni
    -- DROP TABLE IF EXISTS equipments.miscellanies_operations;
    CREATE TABLE equipments.miscellanies_operations(
        mi_op_id      serial,
        mi_op_desc    text NOT NULL,
        mi_op_counter integer DEFAULT 0,

        CONSTRAINT equipments_miscellanies_operations_pkey PRIMARY KEY (mi_op_id),
        CONSTRAINT equipments_miscellanies_operations_ukey UNIQUE (mi_op_desc)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.miscellanies_operations TO group_admin;
    GRANT ALL ON TABLE    equipments.miscellanies_operations TO group_bobo;
    GRANT ALL ON TABLE    equipments.miscellanies_operations TO group_tools;
    GRANT SELECT ON TABLE equipments.miscellanies_operations TO group_readonly;

    -- comments
    COMMENT ON TABLE  equipments.miscellanies_operations               IS 'Table with principal information about miscellanies operations';
    COMMENT ON COLUMN equipments.miscellanies_operations.mi_op_id      IS 'Operation ID PK';
    COMMENT ON COLUMN equipments.miscellanies_operations.mi_op_desc    IS 'Operation description';
    COMMENT ON COLUMN equipments.miscellanies_operations.mi_op_counter IS 'Operation usage frequency counter';

    -- Tabella che contiene i vari alleati delle dotazioni
    -- DROP TABLE IF EXISTS equipments.miscellany_attachments;
    CREATE TABLE equipments.miscellany_attachments
    (
        att_id        serial,
        mi_id         integer NOT NULL,
        file_original text NOT NULL,
        file_archive  text NOT NULL,
        file_image    boolean DEFAULT false,
        att_fulldate  timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT equipments_miscellany_attachments_pkey PRIMARY KEY (att_id),
        CONSTRAINT equipments_miscellany_attachments_ukey UNIQUE (mi_id, file_archive)
        -- CONSTRAINT equipments_miscellany_attachments_fk1 FOREIGN KEY (mi_id)
        --     REFERENCES equipments.miscellanies  (mi_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.miscellany_attachments TO group_admin;
    GRANT ALL ON TABLE    equipments.miscellany_attachments TO group_bobo;
    GRANT ALL ON TABLE    equipments.miscellany_attachments TO group_tools;
    GRANT SELECT ON TABLE equipments.miscellany_attachments TO group_readonly;
    GRANT ALL ON SEQUENCE equipments.miscellany_attachments_att_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE equipments.miscellany_attachments_att_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE equipments.miscellany_attachments_att_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  equipments.miscellany_attachments               IS 'Table storing miscellanies attachments';
    COMMENT ON COLUMN equipments.miscellany_attachments.att_id        IS 'Attachment ID (PK)';
    COMMENT ON COLUMN equipments.miscellany_attachments.mi_id         IS 'Miscellany ID (FK)';
    COMMENT ON COLUMN equipments.miscellany_attachments.file_original IS 'Original file name';
    COMMENT ON COLUMN equipments.miscellany_attachments.file_archive  IS 'Archive file name';
    COMMENT ON COLUMN equipments.miscellany_attachments.file_image    IS 'Flag if file is an image';
    COMMENT ON COLUMN equipments.miscellany_attachments.att_fulldate  IS 'Attachment insert fulldate';

    -- Tabella che contiene la varie operazioni
    -- DROP TABLE IF EXISTS equipments.operations;
    CREATE TABLE equipments.operations(
        op_id      serial,
        op_desc    text NOT NULL,
        op_counter integer DEFAULT 0,

        CONSTRAINT equipments_operations_pkey PRIMARY KEY (op_id),
        CONSTRAINT equipments_operations_ukey1 UNIQUE (op_desc)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.operations TO group_admin;
    GRANT ALL ON TABLE    equipments.operations TO group_bobo;
    GRANT ALL ON TABLE    equipments.operations TO group_tools;
    GRANT SELECT ON TABLE equipments.operations TO group_readonly;

    -- comments
    COMMENT ON TABLE  equipments.operations            IS 'Table with principal information about operations';
    COMMENT ON COLUMN equipments.operations.op_id      IS 'Operation ID PK';
    COMMENT ON COLUMN equipments.operations.op_desc    IS 'Operation description';
    COMMENT ON COLUMN equipments.operations.op_counter IS 'Operation usage frequency counter';

    -- Tabella che contiene le varie categorie di operazioni
    -- DROP TABLE IF EXISTS equipments.operations_category;
    CREATE TABLE equipments.operations_category(
        op_ca_id   serial,
        op_ca_desc text NOT NULL,

        CONSTRAINT equipments_operations_category_pkey PRIMARY KEY (op_ca_id),
        CONSTRAINT equipments_operations_category_ukey1 UNIQUE (op_ca_desc)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    equipments.operations_category TO group_admin;
    GRANT ALL ON TABLE    equipments.operations_category TO group_bobo;
    GRANT ALL ON TABLE    equipments.operations_category TO group_tools;
    GRANT SELECT ON TABLE equipments.operations_category TO group_readonly;

    -- comments
    COMMENT ON TABLE  equipments.operations_category            IS 'Table with principal information about operations category';
    COMMENT ON COLUMN equipments.operations_category.op_ca_id   IS 'Operation category ID PK';
    COMMENT ON COLUMN equipments.operations_category.op_ca_desc IS 'Operation category description';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- Vista che raccoglie le informazioni delle bombole
    -- DROP VIEW IF EXISTS equipments.view_cylinders;
    CREATE OR REPLACE VIEW equipments.view_cylinders AS
    SELECT
        c.cy_id                                                        AS cy_id,
        c.cy_arpa_id                                                   AS cylinder_arpa_id,
        c.cy_name                                                      AS cylinder_name,
        c.cy_mixture                                                   AS cylinder_mixture,
        c.category_id                                                  AS category_id,
        ca.category_name                                               AS category_name,
        c.cy_built_date                                                AS cylinder_built_date,
        c.cy_expiry_date                                               AS cylinder_expiry_date,
        c.cy_ch_values                                                 AS cylinder_ch_values,
        c.cy_all_stations                                              AS cylinder_all_stations,
        c.cy_is_zero                                                   AS cylinder_is_zero,
        c.cy_is_exhausted                                              AS cylinder_is_exhausted,
        c.cy_is_returned                                               AS cylinder_is_returned,
        c.cy_not_compliant                                             AS cylinder_not_compliant,
        c.cy_active                                                    AS cylinder_active,
        c.cy_note                                                      AS cylinder_note,

        c.network_types                                                AS network_types,
        ARRAY(
            SELECT
                st_network_name
            FROM  metadata.stations_network_type
            WHERE st_network_id = ANY(c.network_types)
        )                                                              AS network_names,
        c.insert_time,
        c.insert_user,
        u.us_name||COALESCE(' '||u.us_2nd_name, '')||' '||u.us_surname AS user_fullname,
        u.us_avatar_thumb                                              AS user_avatar_thumb
    FROM
        equipments.cylinders c
        LEFT JOIN equipments.categories ca USING (category_id)
        LEFT JOIN bobo.users u ON (c.insert_user = u.us_id)
    ORDER BY cy_id;

    -- grants
    GRANT ALL ON TABLE    equipments.view_cylinders TO group_admin;
    GRANT ALL ON TABLE    equipments.view_cylinders TO group_bobo;
    GRANT ALL ON TABLE    equipments.view_cylinders TO group_tools;
    GRANT SELECT ON TABLE equipments.view_cylinders TO group_readonly;

    -- comments
    COMMENT ON VIEW equipments.view_cylinders IS 'The view contains all the info about cylinders';

    -- Vista che raccoglie le informazioni degli strumenti
    -- DROP VIEW IF EXISTS equipments.view_instruments;
    CREATE VIEW equipments.view_instruments AS
    SELECT
        i.instr_id                                                     AS instr_id,
        i.instr_type_id                                                AS instr_type_id,
        CASE
            WHEN it.instr_type_id = 0 THEN 'Stazione'
            ELSE c.constr_name||' '
                ||b.brand_name||' '
                ||m.model_name
        END                                                            AS instr_type_fullname,
        i.instr_arpa_id                                                AS instrument_arpa_id,
        i.instr_owner                                                  AS instrument_owner,
        i.instr_serial_num                                             AS instrument_serial_num,
        i.instr_name                                                   AS instrument_name,
        i.instr_active                                                 AS instrument_active,
        i.instr_note                                                   AS instrument_note,
        i.instr_delivery_date                                          AS instrument_delivery_date,
        i.instr_dismiss_date                                           AS instrument_dismiss_date,
        ca.category_id                                                 AS category_id,
        ca.category_name                                               AS category_name,
        ca.category_short_name                                         AS category_short_name,

        i.network_types                                                AS network_types,
        ARRAY(
            SELECT
                st_network_name
            FROM  metadata.stations_network_type
            WHERE st_network_id = ANY(i.network_types)
        )                                                              AS network_names,
        i.insert_time,
        i.insert_user,
        u.us_name||COALESCE(' '||u.us_2nd_name, '')||' '||u.us_surname AS user_fullname,
        u.us_avatar_thumb                                              AS user_avatar_thumb
    FROM
        equipments.instruments i
        LEFT JOIN bobo.users u                   ON (i.insert_user = u.us_id)
        LEFT JOIN equipments.instruments_type it USING (instr_type_id)
        LEFT JOIN equipments.constructors c      USING (constr_id)
        LEFT JOIN equipments.brands b            USING (brand_id)
        LEFT JOIN equipments.models m            USING (model_id)
        LEFT JOIN equipments.categories ca       USING (category_id)
    ORDER BY instr_id;

    -- grants
    GRANT ALL ON TABLE    equipments.view_instruments TO group_admin;
    GRANT ALL ON TABLE    equipments.view_instruments TO group_bobo;
    GRANT ALL ON TABLE    equipments.view_instruments TO group_tools;
    GRANT SELECT ON TABLE equipments.view_instruments TO group_readonly;

    -- comments
    COMMENT ON VIEW equipments.view_instruments IS 'The view contains all the info about instruments';

    -- Vista che raccoglie le informazioni degli strumenti in relazione alle operazioni associate
    -- DROP VIEW IF EXISTS equipments.view_instruments_operations;
    CREATE OR REPLACE VIEW equipments.view_instruments_operations AS
    SELECT
        io.in_op_id      AS in_op_id,
        io.category_id   AS category_id,
        ca.category_name AS category_name,
        io.instr_type_id AS instr_type_id,
        io.op_id         AS op_id,
        o.op_desc        AS operation_description,
        io.op_ca_id      AS op_ca_id,
        oc.op_ca_desc    AS operation_category_desc,
        io.freq_id       AS freq_id,
        f.freq_desc      AS frequency_desc,
        f.freq_label     AS frequency_label,
        f.freq_db        AS frequency_db
    FROM
        equipments.instruments_operations io
        LEFT JOIN equipments.categories ca          USING (category_id)
        LEFT JOIN equipments.operations o           USING (op_id)
        LEFT JOIN equipments.operations_category oc USING (op_ca_id)
        LEFT JOIN equipments.frequencies f          USING (freq_id)
    ORDER BY in_op_id;

    -- grants
    GRANT ALL ON TABLE    equipments.view_instruments_operations TO group_admin;
    GRANT ALL ON TABLE    equipments.view_instruments_operations TO group_bobo;
    GRANT ALL ON TABLE    equipments.view_instruments_operations TO group_tools;
    GRANT SELECT ON TABLE equipments.view_instruments_operations TO group_readonly;

    -- comments
    COMMENT ON VIEW equipments.view_instruments_operations IS 'The view contains all the info about instruments operations';

    -- Vista che raccoglie le informazioni delle tipologie di strumento
    -- DROP VIEW IF EXISTS equipments.view_instruments_type;
    CREATE OR REPLACE VIEW equipments.view_instruments_type AS
    SELECT
        it.instr_type_id        AS instr_type_id,
        CASE
            WHEN it.instr_type_id = 0 THEN 'Stazione'
            ELSE TRIM(c.constr_name||' '
                ||b.brand_name||' '
                ||m.model_name)
        END                     AS instr_type_fullname,
        it.constr_id            AS constructor_id,
        c.constr_name           AS constructor_name,
        it.brand_id             AS brand_id,
        b.brand_name            AS brand_name,
        it.model_id             AS model_id,
        m.model_name            AS model_name,
        it.category_id          AS category_id,
        ca.category_name        AS category_name,
        ca.category_short_name  AS category_short_name,
        it.instr_type_range_min AS instr_type_range_min,
        it.instr_type_range_max AS instr_type_range_max,
        it.instr_type_precision AS instr_type_precision,
        it.instr_type_unit      AS instr_type_unit,
        it.instr_type_note      AS instr_type_note
    FROM
        equipments.instruments_type it
        LEFT JOIN equipments.constructors c USING (constr_id)
        LEFT JOIN equipments.brands b       USING (brand_id)
        LEFT JOIN equipments.models m       USING (model_id)
        LEFT JOIN equipments.categories ca  USING (category_id)
    ORDER BY instr_type_id;

    -- grants
    GRANT ALL ON TABLE    equipments.view_instruments_type TO group_admin;
    GRANT ALL ON TABLE    equipments.view_instruments_type TO group_bobo;
    GRANT ALL ON TABLE    equipments.view_instruments_type TO group_tools;
    GRANT SELECT ON TABLE equipments.view_instruments_type TO group_readonly;

    -- comments
    COMMENT ON VIEW equipments.view_instruments_type IS 'The view contains all the info about instruments types';

    -- Vista che raccoglie le informazioni delle dotazioni
    -- DROP VIEW IF EXISTS equipments.view_miscellanies;
    CREATE OR REPLACE VIEW equipments.view_miscellanies AS
    SELECT
        m.mi_id                                                        AS mi_id,
        m.mi_arpa_id                                                   AS miscellany_arpa_id,
        m.mi_owner                                                     AS miscellany_owner,
        m.mi_name                                                      AS miscellany_name,
        m.mi_brand_model                                               AS miscellany_brand_model,
        m.mi_serial_num                                                AS miscellany_serial_num,
        m.mi_delivery_date                                             AS miscellany_delivery_date,
        m.mi_dismiss_date                                              AS miscellany_dismiss_date,
        m.mi_active                                                    AS miscellany_active,
        m.mi_note                                                      AS miscellany_note,
        m.network_types                                                AS network_types,
        ARRAY(
            SELECT
                st_network_name
            FROM  metadata.stations_network_type
            WHERE st_network_id = ANY(m.network_types)
        )                                                              AS network_names,
        m.insert_time,
        m.insert_user,
        u.us_name||COALESCE(' '||u.us_2nd_name, '')||' '||u.us_surname AS user_fullname,
        u.us_avatar_thumb                                              AS user_avatar_thumb
    FROM
        equipments.miscellanies m
        LEFT JOIN bobo.users u ON (m.insert_user = u.us_id)
    ORDER BY mi_id;

    -- grants
    GRANT ALL ON TABLE    equipments.view_miscellanies TO group_admin;
    GRANT ALL ON TABLE    equipments.view_miscellanies TO group_bobo;
    GRANT ALL ON TABLE    equipments.view_miscellanies TO group_tools;
    GRANT SELECT ON TABLE equipments.view_miscellanies TO group_readonly;

    -- comments
    COMMENT ON VIEW equipments.view_miscellanies IS 'The view contains all the info about miscellanies';

    -- Vista che raccoglie le informazioni delle stazioni in base alle bombole associate
    -- DROP VIEW IF EXISTS metadata.view_stations_cylinders;
    CREATE OR REPLACE VIEW metadata.view_stations_cylinders AS
    SELECT
        sc.stcy_id,
        sc.cy_id,
        sc.station_id,
        s.station_name,
        sc.stcy_startup_date AS station_cy_startup_date,
        sc.stcy_dismiss_date AS station_cy_dismiss_date,
        sc.stcy_note         AS station_cy_note,
        c.cy_arpa_id         AS cylinder_arpa_id,
        c.cy_name            AS cylinder_name,
        c.cy_mixture         AS cylinder_mixture,
        c.category_id        AS category_id,
        ca.category_name     AS category_name,
        c.cy_built_date      AS cylinder_built_date,
        c.cy_expiry_date     AS cylinder_expiry_date,
        c.cy_ch_values       AS cylinder_ch_values,
        c.cy_all_stations    AS cylinder_all_stations,
        c.cy_is_zero         AS cylinder_is_zero,
        c.cy_is_exhausted    AS cylinder_is_exhausted,
        c.cy_is_returned     AS cylinder_is_returned,
        c.cy_not_compliant   AS cylinder_not_compliant,
        c.cy_active          AS cylinder_active,
        c.cy_note            AS cylinder_note,
        c.network_types      AS network_types,
        ARRAY(
            SELECT
                st_network_name
            FROM  metadata.stations_network_type
            WHERE st_network_id = ANY(c.network_types)
        )                    AS network_names
    FROM
        metadata.stations_cylinders sc
        LEFT JOIN metadata.stations s USING (station_id)
        LEFT JOIN equipments.cylinders c USING (cy_id)
        LEFT JOIN equipments.categories ca USING (category_id)
    ORDER BY stcy_id;

    -- grants
    GRANT ALL ON TABLE    metadata.view_stations_cylinders TO group_admin;
    GRANT ALL ON TABLE    metadata.view_stations_cylinders TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_stations_cylinders TO group_tools;
    GRANT SELECT ON TABLE metadata.view_stations_cylinders TO group_readonly;

    -- comment
    COMMENT ON VIEW metadata.view_stations_cylinders IS 'The view contains all the info about the relation stations-cylinders';

    -- Vista che raccoglie le informazioni delle stazioni in relazioni agli strumenti associati
    -- DROP VIEW IF EXISTS metadata.view_stations_instruments;
    CREATE OR REPLACE VIEW metadata.view_stations_instruments AS
    SELECT
        si.stin_id,
        si.stpr_group_id,
        si.instr_id,
        si.station_id,
        s.station_name,
        c.constr_name||' '||b.brand_name||' '||m.model_name AS instrument_type_fullname,
        si.stin_startup_date                                AS station_instr_startup_date,
        si.stin_dismiss_date                                AS station_instr_dismiss_date,
        si.stin_master                                      AS station_instr_master,
        i.instr_arpa_id                                     AS instrument_arpa_id,
        i.instr_owner                                       AS instrument_owner,
        i.instr_serial_num                                  AS instrument_serial_num,
        i.instr_name                                        AS instrument_name,
        i.instr_delivery_date                               AS instrument_delivery_date,
        i.instr_dismiss_date                                AS instrument_dismiss_date,
        i.instr_active                                      AS instrument_active,
        i.instr_note                                        AS instrument_note,
        i.network_types                                     AS network_types,
        ARRAY(
            SELECT
                st_network_name
            FROM  metadata.stations_network_type
            WHERE st_network_id = ANY(i.network_types)
        )                                                   AS network_names,
        it.instr_type_id                                    AS instr_type_id,
        it.constr_id                                        AS constructor_id,
        it.brand_id                                         AS brand_id,
        it.model_id                                         AS model_id,
        it.category_id                                      AS category_id,
        ca.category_name                                    AS category_name,
        it.instr_type_range_min                             AS instrument_type_range_min,
        it.instr_type_range_max                             AS instrument_type_range_max,
        it.instr_type_precision                             AS instrument_type_precision,
        it.instr_type_unit                                  AS instrument_type_unit,
        it.instr_type_note                                  AS instrument_type_note
    FROM
        metadata.stations_instruments si
        LEFT JOIN metadata.stations s            USING (station_id)
        LEFT JOIN equipments.instruments i       USING (instr_id)
        LEFT JOIN equipments.instruments_type it USING (instr_type_id)
        LEFT JOIN equipments.constructors c      USING (constr_id)
        LEFT JOIN equipments.brands b            USING (brand_id)
        LEFT JOIN equipments.models m            USING (model_id)
        LEFT JOIN equipments.categories ca       USING (category_id)
    ORDER BY stin_id;

    -- grants
    GRANT ALL ON TABLE    metadata.view_stations_instruments TO group_admin;
    GRANT ALL ON TABLE    metadata.view_stations_instruments TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_stations_instruments TO group_tools;
    GRANT SELECT ON TABLE metadata.view_stations_instruments TO group_readonly;

    -- comment
    COMMENT ON VIEW metadata.view_stations_instruments IS 'The view contains all the info about the relation stations-instruments';

    -- Vista che raccoglie le informazioni delle stazioni in relazione alle dotazioni associate
    -- DROP VIEW IF EXISTS metadata.view_stations_miscellanies;
    CREATE OR REPLACE VIEW metadata.view_stations_miscellanies AS
    SELECT 
        sm.stmi_id,
        sm.mi_id,
        sm.station_id,
        s.station_name,
        sm.stmi_startup_date    AS station_mi_startup_date,
        sm.stmi_dismiss_date    AS station_mi_dismiss_date,
        sm.stmi_note            AS station_mi_note,
        m.mi_arpa_id            AS miscellany_arpa_id,
        m.mi_owner              AS miscellany_owner,
        m.mi_name               AS miscellany_name,
        m.mi_brand_model        AS miscellany_brand_model,
        m.mi_serial_num         AS miscellany_serial_num,
        m.mi_delivery_date      AS miscellany_delivery_date,
        m.mi_dismiss_date       AS miscellany_dismiss_date,
        m.mi_active             AS miscellany_active,
        m.mi_note               AS miscellany_note,
        m.network_types,
        ARRAY( 
            SELECT stations_network_type.st_network_name
            FROM metadata.stations_network_type
            WHERE stations_network_type.st_network_id = ANY (m.network_types)
        )                       AS network_names
    FROM 
        metadata.stations_miscellanies sm
        LEFT JOIN metadata.stations s USING (station_id)
        LEFT JOIN equipments.miscellanies m USING (mi_id)
    ORDER BY 
        sm.stmi_id;

    -- grants
    GRANT ALL ON TABLE    metadata.view_stations_miscellanies TO group_admin;
    GRANT ALL ON TABLE    metadata.view_stations_miscellanies TO group_bobo;
    GRANT ALL ON TABLE    metadata.view_stations_miscellanies TO group_tools;
    GRANT SELECT ON TABLE metadata.view_stations_miscellanies TO group_readonly;

    -- comment
    COMMENT ON VIEW metadata.view_stations_miscellanies IS 'The view contains all the info about the relation stations-miscellanies';

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Funzione per verificare se uno strumento è utilizzato in qualche applicativo del portale
    -- DROP FUNCTION IF EXISTS equipments.f_check_instrument(integer);
    CREATE OR REPLACE FUNCTION equipments.f_check_instrument(
        IN  inid integer,
        OUT check_flag boolean
    )
    -- no returns clause necessary, output structure controlled by OUT parameters
    -- returns XXX
    LANGUAGE 'plpgsql'
    AS $BODY$

    BEGIN
        WITH t1 AS (
            SELECT COUNT(*) AS s
            FROM reports.calibrations c,
                jsonb_each_text(c.calib_values)
            WHERE key ~ 'calib'
            AND value::integer = inid
        ),
        t2 AS (
            SELECT COUNT(*) AS s
            FROM reports.calibrations c
            WHERE instr_id = inid
        ),
        t3 AS (
            SELECT COUNT(*) AS s
            FROM reports.maintenances_operations
            WHERE instr_id = inid
        ),
        t4 AS (
            SELECT COUNT(*) AS s
            FROM reports.tickets
            WHERE instr_id::integer = inid
            AND tk_opening_date <= CURRENT_TIMESTAMP

        ),
        t5 AS (
            SELECT
                COUNT(*) AS s
            FROM client_lig_alims.reports
            WHERE instr_id = inid
        )
        SELECT
            CASE WHEN t1.s + t2.s + t3.s + t4.s + t5.s > 0 THEN TRUE
            ELSE FALSE
            END AS result INTO check_flag
        FROM t1, t2, t3, t4, t5;

        -- no return statement necessary, output values already stored in OUT parameters
        -- return XXX;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION equipments.f_check_instrument(integer) TO group_readonly;
    GRANT EXECUTE ON FUNCTION equipments.f_check_instrument(integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION equipments.f_check_instrument(integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION equipments.f_check_instrument(integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION equipments.f_check_instrument(integer)
        IS 'Function for checking if the instrument is used in any reports';

    -- Funzione per verificare se uno strumento stanziato in una certa data è utilizzato in qualche applicativo del portale
    -- DROP FUNCTION IF EXISTS equipments.f_check_instrument_location(integer);
    CREATE OR REPLACE FUNCTION equipments.f_check_instrument_location(
        IN  stinid integer,
        OUT check_flag boolean,
        OUT check_date timestamp
    )
    -- no returns clause necessary, output structure controlled by OUT parameters
    -- returns XXX
    LANGUAGE 'plpgsql'
    AS $BODY$

    BEGIN
        WITH t1 AS (
            SELECT *
            FROM metadata.stations_instruments
            WHERE stin_id = stinid
        ),
        t2 AS (
            SELECT
                COUNT(*) AS s,
                MAX(calib_fulldate) AS max_date
            FROM t1
            LEFT JOIN reports.calibrations c ON (t1.station_id = c.station_id AND tsrange(t1.stin_startup_date, t1.stin_dismiss_date, '[)') @> c.calib_fulldate ),
                jsonb_each_text(c.calib_values)
            WHERE key ~ 'calib'
            AND value::integer = t1.instr_id
        ),
        t3 AS (
            SELECT
                COUNT(*) AS s,
                MAX(calib_fulldate) AS max_date
            FROM t1
            LEFT JOIN reports.calibrations c ON (t1.station_id = c.station_id AND tsrange(t1.stin_startup_date, t1.stin_dismiss_date, '[)') @> c.calib_fulldate )
            WHERE c.instr_id = t1.instr_id
        ),
        t4 AS (
            SELECT
                COUNT(*) AS s,
                MAX(ma_fulldate) AS max_date
            FROM t1
            LEFT JOIN reports.maintenances m ON (t1.station_id = m.station_id AND tsrange(t1.stin_startup_date, t1.stin_dismiss_date, '[)') @> m.ma_fulldate )
            LEFT JOIN reports.maintenances_operations mo USING (ma_id)
            WHERE mo.instr_id = t1.instr_id
        ),
        t5 AS (
            SELECT
                COUNT(*) AS s,
                MAX(rep_fulldate) AS max_date
            FROM t1
            LEFT JOIN client_lig_alims.reports r ON (t1.station_id = r.station_id AND tsrange(t1.stin_startup_date, t1.stin_dismiss_date, '[)') @> r.rep_fulldate )
            WHERE r.instr_id = t1.instr_id
        ),
        t6 AS (
            SELECT
                COUNT(*) AS s,
                MAX(tk_opening_date) AS max_date
            FROM t1
            LEFT JOIN reports.tickets t ON (t1.station_id = t.station_id AND tsrange(t1.stin_startup_date, t1.stin_dismiss_date, '[)') @> t.tk_opening_date )
            WHERE t.instr_id::integer = t1.instr_id
            AND t.tk_opening_date <= CURRENT_TIMESTAMP
        )
        SELECT
            CASE
                WHEN t2.s + t3.s + t4.s + t5.s + t6.s > 0 THEN TRUE
                ELSE FALSE
            END AS flag,
            GREATEST(t2.max_date, t3.max_date, t4.max_date, t5.max_date, t6.max_date) AS fulldate INTO check_flag, check_date
        FROM t2, t3, t4, t5, t6;

        -- no return statement necessary, output values already stored in OUT parameters
        -- return XXX;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION equipments.f_check_instrument_location(integer) TO group_readonly;
    GRANT EXECUTE ON FUNCTION equipments.f_check_instrument_location(integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION equipments.f_check_instrument_location(integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION equipments.f_check_instrument_location(integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION equipments.f_check_instrument_location(integer)
        IS 'Function for checking if the instrument is used in any reports during its location';

-- SCHEMA reports

    -- DROP SCHEMA IF EXISTS reports CASCADE;
    CREATE SCHEMA reports
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA reports TO group_admin;
    GRANT USAGE ON SCHEMA reports TO group_bobo;
    GRANT USAGE ON SCHEMA reports TO group_readonly;
    GRANT USAGE ON SCHEMA reports TO group_tools;
    COMMENT ON SCHEMA reports IS 'Reports schema for OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella che contiene le informazioni relative agli allegati delle tarature
    -- DROP TABLE IF EXISTS reports.calibration_attachments;
    CREATE TABLE reports.calibration_attachments
    (
        att_id        serial,
        calib_id      integer NOT NULL,
        file_original text NOT NULL,
        file_archive  text NOT NULL,
        file_image    boolean DEFAULT false,
        att_fulldate  timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT reports_calibration_attachments_pkey PRIMARY KEY (att_id),
        CONSTRAINT reports_calibration_attachments_ukey UNIQUE (calib_id, file_archive)
        -- CONSTRAINT reports_calibration_attachments_fk1 FOREIGN KEY (calib_id)
        --     REFERENCES reports.calibrations (calib_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.calibration_attachments TO group_admin;
    GRANT ALL ON TABLE    reports.calibration_attachments TO group_bobo;
    GRANT ALL ON TABLE    reports.calibration_attachments TO group_tools;
    GRANT SELECT ON TABLE reports.calibration_attachments TO group_readonly;
    GRANT ALL ON SEQUENCE reports.calibration_attachments_att_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.calibration_attachments_att_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.calibration_attachments_att_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.calibration_attachments               IS 'Table storing calibrations attachments';
    COMMENT ON COLUMN reports.calibration_attachments.att_id        IS 'Attachment ID (PK)';
    COMMENT ON COLUMN reports.calibration_attachments.calib_id      IS 'Calibration report ID (FK)';
    COMMENT ON COLUMN reports.calibration_attachments.file_original IS 'Original file name';
    COMMENT ON COLUMN reports.calibration_attachments.file_archive  IS 'Archive file name';
    COMMENT ON COLUMN reports.calibration_attachments.file_image    IS 'Flag if file is an image';
    COMMENT ON COLUMN reports.calibration_attachments.att_fulldate  IS 'Attachment insert fulldate';

    -- Tabella che contiene le informazioni relative ai possibili metodi di taratura
    -- DROP TABLE reports.calibration_methods IF EXISTS;
    CREATE TABLE reports.calibration_methods
    (
        calib_me_id   serial,
        calib_me_name text NOT NULL,

        CONSTRAINT reports_calibration_methods_pkey PRIMARY KEY (calib_me_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.calibration_methods TO group_admin;
    GRANT ALL ON TABLE    reports.calibration_methods TO group_bobo;
    GRANT ALL ON TABLE    reports.calibration_methods TO group_tools;
    GRANT SELECT ON TABLE reports.calibration_methods TO group_readonly;

    -- comments
    COMMENT ON TABLE  reports.calibration_methods               IS 'Lookup table holding calibration methods';
    COMMENT ON COLUMN reports.calibration_methods.calib_me_id   IS 'Method ID (PK)';
    COMMENT ON COLUMN reports.calibration_methods.calib_me_name IS 'Method name';

    -- Tabella che contiene le informazioni relative alle possibili motivazioni di taratura
    -- DROP TABLE reports.calibration_reasons IF EXISTS;
    CREATE TABLE reports.calibration_reasons
    (
        calib_re_id   serial,
        calib_re_name text NOT NULL,

        CONSTRAINT reports_calibration_reasons_pkey PRIMARY KEY (calib_re_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.calibration_reasons TO group_admin;
    GRANT ALL ON TABLE    reports.calibration_reasons TO group_bobo;
    GRANT ALL ON TABLE    reports.calibration_reasons TO group_tools;
    GRANT SELECT ON TABLE reports.calibration_reasons TO group_readonly;

    -- comments
    COMMENT ON TABLE  reports.calibration_reasons               IS 'Lookup table holding calibration reasons';
    COMMENT ON COLUMN reports.calibration_reasons.calib_re_id   IS 'Reason ID (PK)';
    COMMENT ON COLUMN reports.calibration_reasons.calib_re_name IS 'Reason name';

    -- Tabella che contiene le informazioni relative alle tarature
    -- DROP TABLE IF EXISTS reports.calibrations;
    CREATE TABLE reports.calibrations
    (
        calib_id          serial,
        us_id             integer NOT NULL,
        station_id        integer NOT NULL,
        instr_id          integer NOT NULL,
        calib_fulldate    timestamp without time zone NOT NULL,
        calib_re_id       integer NOT NULL,
        calib_multipoint  boolean DEFAULT FALSE,
        calib_values      jsonb DEFAULT '{}'::jsonb,
        calib_note        text DEFAULT NULL,
        calib_insert_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT reports_calibrations_pkey PRIMARY KEY (calib_id)
        -- CONSTRAINT reports_calibrations_fk1 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_calibrations_fk2 FOREIGN KEY (station_id)
        --     REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_calibrations_fk3 FOREIGN KEY (instr_id)
        --     REFERENCES equipments.instruments (instr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_calibrations_fk4 FOREIGN KEY (calib_re_id)
        --     REFERENCES reports.calibration_reasons (calib_re_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.calibrations TO group_admin;
    GRANT ALL ON TABLE    reports.calibrations TO group_bobo;
    GRANT ALL ON TABLE    reports.calibrations TO group_tools;
    GRANT SELECT ON TABLE reports.calibrations TO group_readonly;
    GRANT ALL ON SEQUENCE reports.calibrations_calib_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.calibrations_calib_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.calibrations_calib_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.calibrations                   IS 'Table storing calibration reports';
    COMMENT ON COLUMN reports.calibrations.calib_id          IS 'Calibration id (PK)';
    COMMENT ON COLUMN reports.calibrations.us_id             IS 'User ID (FK)';
    COMMENT ON COLUMN reports.calibrations.station_id        IS 'Station ID (FK)';
    COMMENT ON COLUMN reports.calibrations.instr_id          IS 'Calibrated instrument id (FK)';
    COMMENT ON COLUMN reports.calibrations.calib_re_id       IS 'Reason ID (FK)';
    COMMENT ON COLUMN reports.calibrations.calib_fulldate    IS 'Calibration fulldate';
    COMMENT ON COLUMN reports.calibrations.calib_multipoint  IS 'Calibration multipoint';
    COMMENT ON COLUMN reports.calibrations.calib_values      IS 'Calibration values JSON object';
    COMMENT ON COLUMN reports.calibrations.calib_note        IS 'Calibration note';
    COMMENT ON COLUMN reports.calibrations.calib_insert_time IS 'Calibration insert time';

    -- Tabella che contiene le informazioni relative ai destinatari dei messaggi
    -- DROP TABLE reports.destinations IF EXISTS;
    CREATE TABLE reports.destinations
    (
        dest_id   serial,
        dest_name text NOT NULL,
        dest_app  text,
        dest_css  text,

        CONSTRAINT reports_destinations_pkey PRIMARY KEY (dest_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.destinations TO group_admin;
    GRANT ALL ON TABLE    reports.destinations TO group_bobo;
    GRANT ALL ON TABLE    reports.destinations TO group_tools;
    GRANT SELECT ON TABLE reports.destinations TO group_readonly;

    -- comments
    COMMENT ON TABLE  reports.destinations           IS 'Lookup table holding messages possible destinations';
    COMMENT ON COLUMN reports.destinations.dest_id   IS 'Destination ID (PK)';
    COMMENT ON COLUMN reports.destinations.dest_name IS 'Destination name';
    COMMENT ON COLUMN reports.destinations.dest_app  IS 'Destination application';
    COMMENT ON COLUMN reports.destinations.dest_css  IS 'Destination CSS';

    -- Tabella che contiene le informazioni relative che agli allegati dei sopralluoghi
    -- DROP TABLE IF EXISTS reports.inspection_attachments;
    CREATE TABLE reports.inspection_attachments
    (
        att_id        serial,
        insp_id       integer NOT NULL,
        file_original text NOT NULL,
        file_archive  text NOT NULL,
        file_image    boolean DEFAULT false,
        att_fulldate  timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT reports_inspection_attachments_pkey PRIMARY KEY (att_id),
        CONSTRAINT reports_inspection_attachments_ukey UNIQUE (insp_id, file_archive)
        -- CONSTRAINT reports_inspection_attachments_fk1 FOREIGN KEY (insp_id)
        --     REFERENCES reports.inspections (insp_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS = FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.inspection_attachments TO group_admin;
    GRANT ALL ON TABLE    reports.inspection_attachments TO group_bobo;
    GRANT ALL ON TABLE    reports.inspection_attachments TO group_tools;
    GRANT SELECT ON TABLE reports.inspection_attachments TO group_readonly;
    GRANT ALL ON SEQUENCE reports.inspection_attachments_att_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.inspection_attachments_att_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.inspection_attachments_att_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.inspection_attachments               IS 'Table storing inspections attachments';
    COMMENT ON COLUMN reports.inspection_attachments.att_id        IS 'Attachment ID (PK)';
    COMMENT ON COLUMN reports.inspection_attachments.insp_id       IS 'Inspection id (FK)';
    COMMENT ON COLUMN reports.inspection_attachments.file_original IS 'Original file name';
    COMMENT ON COLUMN reports.inspection_attachments.file_archive  IS 'Archive file name';
    COMMENT ON COLUMN reports.inspection_attachments.file_image    IS 'Flag if file is an image';
    COMMENT ON COLUMN reports.inspection_attachments.att_fulldate  IS 'Attachment insert fulldate';

    -- Tabella che contiene le informazioni relative ai sopralluoghi
    -- DROP TABLE IF EXISTS reports.inspections CASCADE;
    CREATE TABLE reports.inspections
    (
        insp_id        serial,
        mu_id          integer NOT NULL,
        insp_locality  text NOT NULL,
        insp_fulldate  timestamp without time zone NOT NULL,
        insp_operators integer[],
        insp_note      text NOT NULL,
        us_id          integer NOT NULL,
        insp_insert_ts timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT reports_inspections_pkey PRIMARY KEY (insp_id)
        -- CONSTRAINT reports_inspections_fk1 FOREIGN KEY (mu_id)
        --     REFERENCES main.municipalities (mu_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_inspections_fk2 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.inspections TO group_admin;
    GRANT ALL ON TABLE    reports.inspections TO group_bobo;
    GRANT ALL ON TABLE    reports.inspections TO group_tools;
    GRANT SELECT ON TABLE reports.inspections TO group_readonly;
    GRANT ALL ON SEQUENCE reports.inspections_insp_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.inspections_insp_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.inspections_insp_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.inspections                IS 'Table storing inspection reports';
    COMMENT ON COLUMN reports.inspections.insp_id        IS 'Inspection ID (PK)';
    COMMENT ON COLUMN reports.inspections.mu_id          IS 'Municipality id (FK)';
    COMMENT ON COLUMN reports.inspections.insp_locality  IS 'Inspection locality';
    COMMENT ON COLUMN reports.inspections.insp_fulldate  IS 'Inspection fulldate';
    COMMENT ON COLUMN reports.inspections.insp_operators IS 'Inspection operators';
    COMMENT ON COLUMN reports.inspections.insp_note      IS 'Inspection note';
    COMMENT ON COLUMN reports.inspections.us_id          IS 'User id (FK)';
    COMMENT ON COLUMN reports.inspections.insp_insert_ts IS 'Inspection insert timestamp';

    -- Tabella che contiene le informazioni relative alle manutenzioni effettuate
    -- DROP TABLE reports.maintenances IF EXISTS;
    CREATE TABLE reports.maintenances
    (
        ma_id          serial,
        station_id     integer NOT NULL,
        us_id          integer NOT NULL,
        ma_fulldate    timestamp without time zone NOT NULL,
        ma_note        text DEFAULT NULL,
        ma_insert_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT reports_maintenances_pkey PRIMARY KEY (ma_id)
        -- CONSTRAINT reports_maintenances_fk1 FOREIGN KEY (station_id)
        --     REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_maintenances_fk2 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.maintenances TO group_admin;
    GRANT ALL ON TABLE    reports.maintenances TO group_bobo;
    GRANT ALL ON TABLE    reports.maintenances TO group_tools;
    GRANT SELECT ON TABLE reports.maintenances TO group_readonly;
    GRANT ALL ON SEQUENCE reports.maintenances_ma_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.maintenances_ma_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.maintenances_ma_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.maintenances                IS 'Table storing maintenance reports';
    COMMENT ON COLUMN reports.maintenances.ma_id          IS 'Report maintenance ID (PK)';
    COMMENT ON COLUMN reports.maintenances.station_id     IS 'Station id (FK)';
    COMMENT ON COLUMN reports.maintenances.us_id          IS 'User id (FK)';
    COMMENT ON COLUMN reports.maintenances.ma_fulldate    IS 'Report maintenance fulldate';
    COMMENT ON COLUMN reports.maintenances.ma_note        IS 'Report maintenance note';
    COMMENT ON COLUMN reports.maintenances.ma_insert_time IS 'Report maintenance insert time';

    -- @TODO da terminare
    -- Tabella che contiene le associazioni manutenzioni-operazioni
    -- DROP TABLE IF EXISTS reports.maintenances_miscellanies_operations CASCADE;
    CREATE TABLE reports.maintenances_miscellanies_operations
    (
        mami_op_id   serial,
        ma_id        integer NOT NULL,
        mi_id        integer NOT NULL,
        mi_op_id     integer NOT NULL,
        mami_op_note text,

        CONSTRAINT reports_maintenances_miscellanies_operations_pkey PRIMARY KEY (mami_op_id)
        -- CONSTRAINT reports_maintenances_miscellanies_operations_fk1 FOREIGN KEY (ma_id)
        --     REFERENCES reports.maintenances (ma_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_maintenances_miscellanies_operations_fk2 FOREIGN KEY (mi_id)
        --     REFERENCES equipments.miscellanies (mi_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_maintenances_miscellanies_operations_fk3 FOREIGN KEY (mi_op_id)
        --     REFERENCES equipments.miscellanies_operations (mi_op_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.maintenances_miscellanies_operations TO group_admin;
    GRANT ALL ON TABLE    reports.maintenances_miscellanies_operations TO group_bobo;
    GRANT ALL ON TABLE    reports.maintenances_miscellanies_operations TO group_tools;
    GRANT SELECT ON TABLE reports.maintenances_miscellanies_operations TO group_readonly;
    GRANT ALL ON SEQUENCE reports.maintenances_miscellanies_operations_mami_op_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.maintenances_miscellanies_operations_mami_op_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.maintenances_miscellanies_operations_mami_op_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.maintenances_miscellanies_operations              IS 'Table storing maintenance reports';
    COMMENT ON COLUMN reports.maintenances_miscellanies_operations.mami_op_id   IS 'Maintenance operation id PK';
    COMMENT ON COLUMN reports.maintenances_miscellanies_operations.ma_id        IS 'Maintenance id FK';
    COMMENT ON COLUMN reports.maintenances_miscellanies_operations.mi_id        IS 'Miscellany id FK';
    COMMENT ON COLUMN reports.maintenances_miscellanies_operations.mi_op_id     IS 'Miscellany type operation FK';
    COMMENT ON COLUMN reports.maintenances_miscellanies_operations.mami_op_note IS 'Maintenance operation note';

    -- @TODO da terminare
    -- Tabella che contiene le associazioni manutenzioni-operazioni
    -- DROP TABLE IF EXISTS reports.maintenances_operations CASCADE;
    CREATE TABLE reports.maintenances_operations
    (
        ma_op_id          serial,
        ma_id             integer NOT NULL,
        instr_id          integer NOT NULL,
        in_op_id          integer NOT NULL,
        calib_id          integer,
        ma_op_filters_exp timestamp without time zone,
        ma_op_note        text,

        CONSTRAINT reports_maintenance_operations_pkey PRIMARY KEY (ma_op_id)
        -- CONSTRAINT reports_maintenance_operations_fk1 FOREIGN KEY (ma_id)
        --     REFERENCES reports.maintenances (ma_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_maintenance_operations_fk2 FOREIGN KEY (instr_id)
        --     REFERENCES equipments.instruments (instr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_maintenance_operations_fk3 FOREIGN KEY (in_op_id)
        --     REFERENCES equipments.instruments_operations (in_op_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_maintenance_operations_fk4 FOREIGN KEY (calib_id)
        --     REFERENCES reports.calibrations (calib_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.maintenances_operations TO group_admin;
    GRANT ALL ON TABLE    reports.maintenances_operations TO group_bobo;
    GRANT ALL ON TABLE    reports.maintenances_operations TO group_tools;
    GRANT SELECT ON TABLE reports.maintenances_operations TO group_readonly;
    GRANT ALL ON SEQUENCE reports.maintenances_operations_ma_op_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.maintenances_operations_ma_op_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.maintenances_operations_ma_op_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.maintenances_operations                   IS 'Table storing maintenance reports';
    COMMENT ON COLUMN reports.maintenances_operations.ma_op_id          IS 'Maintenance operation id PK';
    COMMENT ON COLUMN reports.maintenances_operations.ma_id             IS 'Maintenance id FK';
    COMMENT ON COLUMN reports.maintenances_operations.instr_id          IS 'Instrument id FK';
    COMMENT ON COLUMN reports.maintenances_operations.in_op_id          IS 'Instrument type operation FK';
    COMMENT ON COLUMN reports.maintenances_operations.calib_id          IS 'Report calibration id FK';
    COMMENT ON COLUMN reports.maintenances_operations.ma_op_filters_exp IS 'Maintenance operation filters expiration date';
    COMMENT ON COLUMN reports.maintenances_operations.ma_op_note        IS 'Maintenance operation note';

    -- Tabella che contiene le principali informazioni dei verbali presenti sul portale
    -- DROP TABLE IF EXISTS reports.meetings;
    CREATE TABLE reports.meetings
    (
        meet_id           serial,
        meet_date         date NOT NULL,
        meet_start_time   time NOT NULL,
        meet_end_time     time NOT NULL,
        province_id       integer NOT NULL,
        meet_locality     text NOT NULL,
        meet_participants integer[],
        meet_title        text NOT NULL,
        meet_desc         text NOT NULL,
        us_id             integer NOT NULL,
        meet_insert_time  timestamp DEFAULT CURRENT_TIMESTAMP,
        meet_pdf_time     timestamp,
        meet_mail_time    timestamp,

        CONSTRAINT reports_meetings_pkey PRIMARY KEY (meet_id)
        -- CONSTRAINT reports_meetings_fk1 FOREIGN KEY (province_id)
        --     REFERENCES main.provinces (province_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_meetings_fk2 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.meetings TO group_admin;
    GRANT ALL ON TABLE    reports.meetings TO group_bobo;
    GRANT ALL ON TABLE    reports.meetings TO group_tools;
    GRANT SELECT ON TABLE reports.meetings TO group_readonly;
    GRANT ALL ON SEQUENCE reports.meetings_meet_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.meetings_meet_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.meetings_meet_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.meetings                   IS 'Table storing meeting reports';
    COMMENT ON COLUMN reports.meetings.meet_id           IS 'Meeting id (PK)';
    COMMENT ON COLUMN reports.meetings.meet_date         IS 'Meeting date';
    COMMENT ON COLUMN reports.meetings.meet_start_time   IS 'Meeting start time';
    COMMENT ON COLUMN reports.meetings.meet_end_time     IS 'Meeting end time';
    COMMENT ON COLUMN reports.meetings.province_id       IS 'Province id (FK)';
    COMMENT ON COLUMN reports.meetings.meet_locality     IS 'Meeting locality';
    COMMENT ON COLUMN reports.meetings.meet_participants IS 'Meeting participants (FK users)';
    COMMENT ON COLUMN reports.meetings.meet_title        IS 'Meeting title';
    COMMENT ON COLUMN reports.meetings.meet_desc         IS 'Meeting description';
    COMMENT ON COLUMN reports.meetings.us_id             IS 'Meeting opening user id';
    COMMENT ON COLUMN reports.meetings.meet_insert_time  IS 'Meeting insert time';
    COMMENT ON COLUMN reports.meetings.meet_pdf_time     IS 'Meeting pdf creation time';
    COMMENT ON COLUMN reports.meetings.meet_mail_time    IS 'Meeting mail sending time';

    -- Tabella relativa alle associazioni messaggio-destinazioni
    -- DROP TABLE reports.message_destinations IF EXISTS;
    CREATE TABLE reports.message_destinations
    (
        md_id   serial,
        msg_id  integer NOT NULL,
        dest_id integer NOT NULL,

        CONSTRAINT reports_message_destinations_pkey PRIMARY KEY (md_id),
        CONSTRAINT reports_message_destinations_ukey UNIQUE (msg_id, dest_id)
        -- CONSTRAINT reports_message_destinations_fk1 FOREIGN KEY (msg_id)
        --     REFERENCES reports.messages (msg_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT reports_message_destinations_fk2 FOREIGN KEY (dest_id)
        --     REFERENCES reports.destinations (dest_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.message_destinations TO group_admin;
    GRANT ALL ON TABLE    reports.message_destinations TO group_bobo;
    GRANT ALL ON TABLE    reports.message_destinations TO group_tools;
    GRANT SELECT ON TABLE reports.message_destinations TO group_readonly;
    GRANT ALL ON SEQUENCE reports.message_destinations_md_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.message_destinations_md_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.message_destinations_md_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.message_destinations         IS 'Relational table with information about message-destinations';
    COMMENT ON COLUMN reports.message_destinations.md_id   IS 'Relation ID (PK)';
    COMMENT ON COLUMN reports.message_destinations.msg_id  IS 'Message ID (FK)';
    COMMENT ON COLUMN reports.message_destinations.dest_id IS 'Destination ID (FK)';

    -- Tabella che contiene le informazioni relative ai messaggi inviati
    -- DROP TABLE reports.messages IF EXISTS;
    CREATE TABLE reports.messages
    (
        msg_id       serial,
        us_id        integer NOT NULL,
        msg_note     text NOT NULL,
        msg_ins_date timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
        msg_exp_date timestamp without time zone DEFAULT 'infinity'::timestamp,

        CONSTRAINT reports_messages_pkey PRIMARY KEY (msg_id)
        -- CONSTRAINT reports_messages_fk1 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    reports.messages TO group_admin;
    GRANT ALL ON TABLE    reports.messages TO group_bobo;
    GRANT ALL ON TABLE    reports.messages TO group_tools;
    GRANT SELECT ON TABLE reports.messages TO group_readonly;
    GRANT ALL ON SEQUENCE reports.messages_msg_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.messages_msg_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.messages_msg_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.messages              IS 'Lookup table holding messages';
    COMMENT ON COLUMN reports.messages.msg_id       IS 'Message ID (PK)';
    COMMENT ON COLUMN reports.messages.us_id        IS 'User ID (FK)';
    COMMENT ON COLUMN reports.messages.msg_note     IS 'Message note';
    COMMENT ON COLUMN reports.messages.msg_ins_date IS 'Message insert fulldate';
    COMMENT ON COLUMN reports.messages.msg_exp_date IS 'Message expiration date';

    -- Tabella che contiene le varie categorie di ticket
    -- DROP TABLE IF EXISTS reports.ticket_categories;
    CREATE TABLE reports.ticket_categories (
        tc_id   smallint NOT NULL,
        tc_desc text NOT NULL,

        CONSTRAINT reports_ticket_categories_pkey PRIMARY KEY (tc_id)
    );

    -- grants
    GRANT ALL ON TABLE    reports.ticket_categories TO group_admin;
    GRANT ALL ON TABLE    reports.ticket_categories TO group_bobo;
    GRANT ALL ON TABLE    reports.ticket_categories TO group_tools;
    GRANT SELECT ON TABLE reports.ticket_categories TO group_readonly;

    -- comments
    COMMENT ON TABLE  reports.ticket_categories         IS 'Ticket category table';
    COMMENT ON COLUMN reports.ticket_categories.tc_id   IS 'Ticket category id (PK)';
    COMMENT ON COLUMN reports.ticket_categories.tc_desc IS 'Ticket category description';

    -- Tabella che contiene le varie frequenze di ticket
    -- DROP TABLE IF EXISTS reports.ticket_frequencies;
    CREATE TABLE reports.ticket_frequencies (
        tf_id    serial NOT NULL,
        tf_desc  text NOT NULL,
        tf_label text NOT NULL,
        tf_db    interval,
        tf_order smallint,

        CONSTRAINT reports_ticket_frequencies_pkey PRIMARY KEY (tf_id)
    );

    -- grants
    GRANT ALL ON TABLE    reports.ticket_frequencies TO group_admin;
    GRANT ALL ON TABLE    reports.ticket_frequencies TO group_bobo;
    GRANT ALL ON TABLE    reports.ticket_frequencies TO group_tools;
    GRANT SELECT ON TABLE reports.ticket_frequencies TO group_readonly;

    -- comments
    COMMENT ON TABLE  reports.ticket_frequencies          IS 'Ticket type table';
    COMMENT ON COLUMN reports.ticket_frequencies.tf_id    IS 'Ticket frequency id';
    COMMENT ON COLUMN reports.ticket_frequencies.tf_desc  IS 'Ticket frequency description';
    COMMENT ON COLUMN reports.ticket_frequencies.tf_label IS 'Ticket frequency label';
    COMMENT ON COLUMN reports.ticket_frequencies.tf_db    IS 'Ticket frequency interval db';
    COMMENT ON COLUMN reports.ticket_frequencies.tf_db    IS 'Ticket frequency order';

    -- Tabella che contiene le varie tipologie di ticket
    -- DROP TABLE IF EXISTS reports.ticket_types;
    CREATE TABLE reports.ticket_types (
        tt_id   smallint NOT NULL,
        tt_desc text NOT NULL,

        CONSTRAINT reports_ticket_types_pkey PRIMARY KEY (tt_id)
    );

    -- grants
    GRANT ALL ON TABLE    reports.ticket_types TO group_admin;
    GRANT ALL ON TABLE    reports.ticket_types TO group_bobo;
    GRANT ALL ON TABLE    reports.ticket_types TO group_tools;
    GRANT SELECT ON TABLE reports.ticket_types TO group_readonly;

    -- comments
    COMMENT ON TABLE  reports.ticket_types         IS 'Ticket type table';
    COMMENT ON COLUMN reports.ticket_types.tt_id   IS 'Ticket type id';
    COMMENT ON COLUMN reports.ticket_types.tt_desc IS 'Ticket type description';

    -- Tabella che contiene le varie tipologie di urgenza dei tickets
    -- DROP TABLE IF EXISTS reports.ticket_types;
    CREATE TABLE reports.ticket_urgencies (
        tu_id   smallint NOT NULL,
        tu_desc text NOT NULL,

        CONSTRAINT reports_ticket_urgencies_pkey PRIMARY KEY (tu_id)
    );

    -- grants
    GRANT ALL ON TABLE    reports.ticket_urgencies TO group_admin;
    GRANT ALL ON TABLE    reports.ticket_urgencies TO group_bobo;
    GRANT ALL ON TABLE    reports.ticket_urgencies TO group_tools;
    GRANT SELECT ON TABLE reports.ticket_urgencies TO group_readonly;

    -- comments
    COMMENT ON TABLE  reports.ticket_urgencies         IS 'Ticket urgencies table';
    COMMENT ON COLUMN reports.ticket_urgencies.tu_id   IS 'Ticket urgency id';
    COMMENT ON COLUMN reports.ticket_urgencies.tu_desc IS 'Ticket urgency description';

    -- Tabella che contiene le informazioni dei tickets
    -- DROP TABLE IF EXISTS reports.tickets CASCADE;
    CREATE TABLE reports.tickets (
        tk_id                serial,
        tk_parent_id_fk      integer DEFAULT NULL,
        tk_opening_date      timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        tk_expiry_date       timestamp without time zone NOT NULL,
        tk_opening_user_fk   integer NOT NULL,
        tk_recipient_comp_fk integer NOT NULL,
        station_id           integer NOT NULL,
        instr_id             integer, -- instrument id
        cy_id                integer, -- cylinder id
        mi_id                integer, -- miscellaneous
        tt_id                smallint NOT NULL,
        tc_id                smallint NOT NULL,
        tu_id                smallint NOT NULL,
        tf_id                integer NOT NULL,
        tk_title             text NOT NULL,
        tk_opening_note      text NOT NULL,
        tk_mail_date         timestamp without time zone,

        CONSTRAINT reports_tickets_pkey PRIMARY KEY (tk_id),
        CONSTRAINT reports_tickets_check CHECK (
            (CASE WHEN instr_id IS NULL THEN 0 ELSE 1 END ) +
            (CASE WHEN cy_id IS NULL THEN 0 ELSE 1 END ) +
            (CASE WHEN mi_id IS NULL THEN 0 ELSE 1 END ) <= 1
        )
        -- CONSTRAINT reports_tickets_fkey FOREIGN KEY (tk_parent_id_fk)
        --     REFERENCES reports.tickets (tk_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_fkey2 FOREIGN KEY (tk_opening_user_fk)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_fkey3 FOREIGN KEY (tk_recipient_comp_fk)
        --     REFERENCES bobo.companies (comp_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_fkey4 FOREIGN KEY (station_id)
        --     REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_fkey5 FOREIGN KEY (instr_id)
        --     REFERENCES equipments.instruments (instr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_fkey6 FOREIGN KEY (cy_id)
        --     REFERENCES equipments.cylinders (cy_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_fkey7 FOREIGN KEY (mi_id)
        --     REFERENCES equipments.miscellanies (mi_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_fkey8 FOREIGN KEY (tt_id)
        --     REFERENCES reports.ticket_types (tt_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_fkey9 FOREIGN KEY (tc_id)
        --     REFERENCES reports.ticket_categories (tc_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_fkey10 FOREIGN KEY (tu_id)
        --     REFERENCES reports.ticket_urgencies (tu_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_fkey11 FOREIGN KEY (tf_id)
        --     REFERENCES reports.ticket_frequencies (tf_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT
    );

    -- grants
    GRANT ALL ON TABLE    reports.tickets TO group_admin;
    GRANT ALL ON TABLE    reports.tickets TO group_bobo;
    GRANT ALL ON TABLE    reports.tickets TO group_tools;
    GRANT SELECT ON TABLE reports.tickets TO group_readonly;
    GRANT ALL ON SEQUENCE reports.tickets_tk_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.tickets_tk_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.tickets_tk_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.tickets                      IS 'Main table for tickets';
    COMMENT ON COLUMN reports.tickets.tk_id                IS 'Ticket id';
    COMMENT ON COLUMN reports.tickets.tk_parent_id_fk      IS 'Ticket parent id FK';
    COMMENT ON COLUMN reports.tickets.tk_opening_date      IS 'Ticket opening date';
    COMMENT ON COLUMN reports.tickets.tk_expiry_date       IS 'Ticket expiration date';
    COMMENT ON COLUMN reports.tickets.tk_opening_user_fk   IS 'Ticket opening user FK';
    COMMENT ON COLUMN reports.tickets.tk_recipient_comp_fk IS 'Ticket recipient company FK';
    COMMENT ON COLUMN reports.tickets.station_id           IS 'Station id FK';
    COMMENT ON COLUMN reports.tickets.instr_id             IS 'Instrument id FK';
    COMMENT ON COLUMN reports.tickets.cy_id                IS 'Cylinder id FK';
    COMMENT ON COLUMN reports.tickets.mi_id                IS 'Miscellaneous id FK';
    COMMENT ON COLUMN reports.tickets.tt_id                IS 'Ticket type id FK';
    COMMENT ON COLUMN reports.tickets.tc_id                IS 'Ticket category id FK';
    COMMENT ON COLUMN reports.tickets.tu_id                IS 'Ticket urgency id FK';
    COMMENT ON COLUMN reports.tickets.tf_id                IS 'Ticket frequency id FK';
    COMMENT ON COLUMN reports.tickets.tk_title             IS 'Ticket title';
    COMMENT ON COLUMN reports.tickets.tk_opening_note      IS 'Ticket opening note';
    COMMENT ON COLUMN reports.tickets.tk_mail_date         IS 'Ticket date when email is sent';

    -- Tabella che contiene le associazioni ticket-mailing list
    -- DROP TABLE IF EXISTS reports.tickets_mlists CASCADE;
    CREATE TABLE reports.tickets_mlists (
        tm_id bigserial,
        tk_id integer NOT NULL,
        ml_id integer NOT NULL,

        CONSTRAINT reports_tickets_mlists_pkey PRIMARY KEY (tm_id)
        -- CONSTRAINT reports_tickets_mlists_fkey FOREIGN KEY (tk_id)
        --     REFERENCES reports.tickets (tk_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE CASCADE,
        -- CONSTRAINT reports_tickets_mlists_fkey2 FOREIGN KEY (ml_id)
        --     REFERENCES gateways.mailing_list (ml_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE CASCADE
    );

    -- grants
    GRANT ALL ON TABLE    reports.tickets_mlists TO group_admin;
    GRANT ALL ON TABLE    reports.tickets_mlists TO group_bobo;
    GRANT ALL ON TABLE    reports.tickets_mlists TO group_tools;
    GRANT SELECT ON TABLE reports.tickets_mlists TO group_readonly;
    GRANT ALL ON SEQUENCE reports.tickets_mlists_tm_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.tickets_mlists_tm_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.tickets_mlists_tm_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.tickets_mlists       IS 'Relational table that links ticket with mailing lists';
    COMMENT ON COLUMN reports.tickets_mlists.tm_id IS 'Ticket mailing list serial id';
    COMMENT ON COLUMN reports.tickets_mlists.tk_id IS 'Ticket id FK';
    COMMENT ON COLUMN reports.tickets_mlists.ml_id IS 'Mailing list FK';

    -- Tabella che contiene i vari status dei ticket presenti nel sistema
    -- DROP TABLE IF EXISTS reports.tickets_status CASCADE;
    CREATE TABLE reports.tickets_status (
        ts_id       serial,
        tk_id       integer NOT NULL,
        us_id       integer NOT NULL,
        ts_fulldate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        ts_note     text,
        ts_status   status NOT NULL,
        ma_id       integer DEFAULT NULL,

        CONSTRAINT reports_tickets_status_pkey PRIMARY KEY (ts_id)
        -- CONSTRAINT reports_tickets_status_fkey FOREIGN KEY (tk_id)
        --     REFERENCES reports.tickets (tk_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_status_fkey2 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT,
        -- CONSTRAINT reports_tickets_status_fkey3 FOREIGN KEY (ma_id)
        --     REFERENCES reports.maintenances (ma_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT
    );

    -- grants
    GRANT ALL ON TABLE    reports.tickets_status TO group_admin;
    GRANT ALL ON TABLE    reports.tickets_status TO group_bobo;
    GRANT ALL ON TABLE    reports.tickets_status TO group_tools;
    GRANT SELECT ON TABLE reports.tickets_status TO group_readonly;
    GRANT ALL ON SEQUENCE reports.tickets_status_ts_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE reports.tickets_status_ts_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE reports.tickets_status_ts_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  reports.tickets_status             IS 'Main table for ticket status';
    COMMENT ON COLUMN reports.tickets_status.ts_id       IS 'Ticket status serial id';
    COMMENT ON COLUMN reports.tickets_status.tk_id       IS 'Ticket id FK';
    COMMENT ON COLUMN reports.tickets_status.us_id       IS 'User id FK';
    COMMENT ON COLUMN reports.tickets_status.ts_fulldate IS 'Ticket status fulldate';
    COMMENT ON COLUMN reports.tickets_status.ts_note     IS 'Ticket status note';
    COMMENT ON COLUMN reports.tickets_status.ts_status   IS 'Ticket status';
    COMMENT ON COLUMN reports.tickets_status.ts_status   IS 'Link to report maintenance id FK';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- Vista che raccoglie le informazioni relative alle tarature
    -- DROP VIEW IF EXISTS reports.view_calibrations;
    CREATE OR REPLACE VIEW reports.view_calibrations AS
    SELECT
        c.calib_id                                                AS calib_id,
        c.us_id                                                   AS us_id,
        u.us_name||' '||COALESCE(u.us_2nd_name, '')||u.us_surname AS user_fullname,
        u.us_avatar                                               AS user_avatar,
        u.us_avatar_thumb                                         AS user_avatar_thumb,
        c.station_id                                              AS station_id,
        s.station_name                                            AS station_name,
        c.instr_id                                                AS instr_id,
        i.instr_type_id                                           AS instr_type_id,
        i.instr_arpa_id                                           AS instr_arpa_id,
        i.instr_serial_num                                        AS instr_serial_num,
        i.instr_name                                              AS instr_name,
        c.calib_fulldate                                          AS calib_fulldate,
        TO_CHAR(c.calib_fulldate, 'DD/MM/YYYY alle HH24:MI')      AS calib_fulldate_formatted,
        c.calib_re_id                                             AS calib_re_id,
        cr.calib_re_name                                          AS calib_reason,
        c.calib_multipoint                                        AS calib_multipoint,
        c.calib_values                                            AS calib_values,
        COALESCE(c.calib_note, '')                                AS calib_note
    FROM
        reports.calibrations c
        LEFT JOIN bobo.users u                   USING (us_id)
        LEFT JOIN metadata.stations s            USING (station_id)
        LEFT JOIN reports.calibration_reasons cr USING (calib_re_id)
        LEFT JOIN equipments.instruments i       USING (instr_id)
    ORDER BY calib_id;

    -- grants
    GRANT ALL ON TABLE    reports.view_calibrations TO group_admin;
    GRANT ALL ON TABLE    reports.view_calibrations TO group_bobo;
    GRANT ALL ON TABLE    reports.view_calibrations TO group_tools;
    GRANT SELECT ON TABLE reports.view_calibrations TO group_readonly;

    -- comment
    COMMENT ON VIEW reports.view_calibrations IS 'The view contains all the info about reports calibrations';

    -- Vista che raccoglie le informazioni relative alle manutenzioni
    -- DROP VIEW IF EXISTS reports.view_maintenances;
    CREATE OR REPLACE VIEW reports.view_maintenances AS
    SELECT
        m.ma_id                                                    AS ma_id,
        m.station_id                                               AS station_id,
        s.station_name                                             AS station_name,
        m.us_id                                                    AS us_id,
        u.us_name||COALESCE(' '||u.us_2nd_name, ' ')||u.us_surname AS user_fullname,
        u.us_avatar                                                AS user_avatar,
        u.us_avatar_thumb                                          AS user_avatar_thumb,
        m.ma_fulldate                                              AS maintenance_fulldate,
        m.ma_note                                                  AS maintenance_note,
        mo.ma_op_id                                                AS ma_op_id,
        mo.instr_id                                                AS instr_id,
        i.instr_type_id                                            AS instr_type_id,
        COALESCE( i.instr_arpa_id, '' )                            AS instr_arpa_id,
        COALESCE( i.instr_serial_num, '')                          AS instr_serial_num,
        i.instr_name                                               AS instr_name,
        mo.in_op_id                                                AS in_op_id,
        io.op_id                                                   AS op_id,
        io.op_ca_id                                                AS op_ca_id,
        io.freq_id                                                 AS freq_id ,
        mo.calib_id                                                AS calib_id,
        mo.ma_op_filters_exp                                       AS main_operation_filters_exp,
        mo.ma_op_note                                              AS main_operation_note
    FROM
        reports.maintenances m
        LEFT JOIN reports.maintenances_operations mo   USING (ma_id)
        LEFT JOIN metadata.stations s                  USING (station_id)
        LEFT JOIN bobo.users u                         USING (us_id)
        LEFT JOIN equipments.instruments i             USING (instr_id)
        LEFT JOIN equipments.instruments_operations io USING (in_op_id)
    ORDER BY ma_id;

    -- grants
    GRANT ALL ON TABLE    reports.view_maintenances TO group_admin;
    GRANT ALL ON TABLE    reports.view_maintenances TO group_bobo;
    GRANT ALL ON TABLE    reports.view_maintenances TO group_tools;
    GRANT SELECT ON TABLE reports.view_maintenances TO group_readonly;

    -- comment
    COMMENT ON VIEW reports.view_maintenances IS 'The view contains all the info about reports maintenances';

    -- Vista che contiene le informazioni dei verbali
    -- DROP VIEW IF EXISTS reports.view_meetings;
    CREATE OR REPLACE VIEW reports.view_meetings AS
    SELECT
        m.meet_id                                                 AS meet_id,
        m.meet_date                                               AS meet_date,
        TO_CHAR(m.meet_date, 'DD/MM/YYYY')                        AS meet_date_format,
        m.meet_start_time                                         AS meet_start_time,
        m.meet_end_time                                           AS meet_end_time,
        m.province_id                                             AS province_id,
        p.province_name                                           AS province_name,
        p.province_code                                           AS province_code,
        m.meet_locality                                           AS meet_locality,
        m.meet_participants                                       AS meet_participants,
        m.meet_title                                              AS meet_title,
        m.meet_desc                                               AS meet_desc,
        m.us_id                                                   AS us_id,
        u.us_name||' '||COALESCE(u.us_2nd_name, '')||u.us_surname AS user_fullname,
        u.us_avatar                                               AS user_avatar,
        u.us_avatar_thumb                                         AS user_avatar_thumb,
        um.portal_id                                              AS portal_id,
        m.meet_insert_time                                        AS meet_insert_time,
        m.meet_pdf_time                                           AS meet_pdf_time,
        CASE
            WHEN m.meet_pdf_time IS NOT NULL THEN TRUE
            ELSE FALSE
        END                                                       AS meet_pdf_created,
        m.meet_mail_time                                          AS meet_mail_time,
        CASE
            WHEN m.meet_mail_time IS NOT NULL THEN TRUE
            ELSE FALSE
        END                                                       AS meet_mail_sent
    FROM reports.meetings m
        LEFT JOIN main.provinces p       USING (province_id)
        LEFT JOIN bobo.users u           USING (us_id)
        LEFT JOIN bobo.users_metadata um USING (us_id)
    ORDER BY meet_id;

    -- comment
    COMMENT ON VIEW reports.view_meetings IS 'The view contains all the info about reports meetings';

    -- grants
    GRANT ALL ON TABLE reports.view_meetings TO group_admin;
    GRANT ALL ON TABLE reports.view_meetings TO group_bobo;
    GRANT ALL ON TABLE reports.view_meetings TO group_tools;
    GRANT SELECT ON TABLE reports.view_meetings TO group_readonly;

    -- Vista che raccoglie le informazioni dei messaggi
    -- DROP VIEW IF EXISTS reports.view_messages;
    CREATE OR REPLACE VIEW reports.view_messages AS
    SELECT
        msg_id                                                                AS msg_id,
        us_id                                                                 AS us_id,
        u.us_name || ' ' || COALESCE(u.us_2nd_name, ''::text) || u.us_surname AS user_fullname,
        u.us_avatar                                                           AS user_avatar,
        u.us_avatar_thumb                                                     AS user_avatar_thumb,
        msg_note                                                              AS message_note,
        msg_ins_date                                                          AS message_ins_date,
        TO_CHAR(msg_ins_date, 'DD/MM/YYYY HH24:MI')                           AS message_ins_date_formatted,
        msg_exp_date                                                          AS message_exp_date,
        CASE
            WHEN msg_exp_date = 'infinity'::timestamp THEN 'non presente'
            ELSE TO_CHAR(msg_exp_date, 'DD/MM/YYYY HH24:MI')
        END                                                                   AS message_exp_date_formatted,
        ARRAY(
            SELECT
                dest_id
            FROM reports.message_destinations md
            LEFT JOIN reports.destinations d USING (dest_id)
            WHERE md.msg_id = m.msg_id
        )                                                                     AS message_destinations
    FROM reports.messages m
    LEFT JOIN bobo.users u USING (us_id)
    ORDER BY msg_id;

    -- grants
    GRANT ALL ON TABLE reports.view_messages TO group_admin;
    GRANT ALL ON TABLE reports.view_messages TO group_bobo;
    GRANT ALL ON TABLE reports.view_messages TO group_tools;
    GRANT SELECT ON TABLE reports.view_messages TO group_readonly;

    -- comment
    COMMENT ON VIEW reports.view_messages IS 'The view contains all the info about messages';

    -- Vista che raccoglie le informazioni relative ai tickets
    -- DROP VIEW IF EXISTS reports.view_tickets;
    CREATE OR REPLACE VIEW reports.view_tickets AS
    SELECT
        tk_id,
        tk_parent_id_fk,
        tk_opening_date,
        tk_expiry_date,
        tk_opening_user_fk,
        tk_recipient_comp_fk,
        c.comp_name,
        station_id,
        s.station_name,
        instr_id,
        cy_id,
        mi_id,
        tt_id,
        tt.tt_desc,
        tc_id,
        tc.tc_desc,
        tu_id,
        tu.tu_desc,
        tf_id,
        tf.tf_desc,
        tk_title,
        tk_opening_note,
        tk_mail_date
    FROM
        reports.tickets t
        LEFT JOIN bobo.companies c              ON (c.comp_id = t.tk_recipient_comp_fk)
        LEFT JOIN metadata.stations s           USING (station_id)
        LEFT JOIN reports.ticket_types tt       USING (tt_id)
        LEFT JOIN reports.ticket_categories tc  USING (tc_id)
        LEFT JOIN reports.ticket_urgencies tu   USING (tu_id)
        LEFT JOIN reports.ticket_frequencies tf USING (tf_id)
    ORDER BY tk_id;

    -- grants
    GRANT ALL ON TABLE    reports.view_tickets TO group_admin;
    GRANT ALL ON TABLE    reports.view_tickets TO group_bobo;
    GRANT ALL ON TABLE    reports.view_tickets TO group_tools;
    GRANT SELECT ON TABLE reports.view_tickets TO group_readonly;

    -- comment
    COMMENT ON VIEW reports.view_tickets IS 'The view contains all the principal info about tickets';

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Funzione per eliminare, dato l'id, un determinato ticket
    -- DROP FUNCTION reports.f_delete_tickets(integer, boolean);
    CREATE OR REPLACE FUNCTION reports.f_delete_tickets(
        ticket_id  integer,
        delete_all boolean
    )
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        p integer; -- parent
        n integer; -- number
        e timestamp; -- expiry date
    BEGIN
        -- TEST SELECT reports.f_delete_tickets(1, true);
        -- TEST SELECT reports.f_delete_tickets(1, false);

        SELECT INTO p, e
            tk_parent_id_fk,
            tk_expiry_date
        FROM reports.tickets WHERE tk_id = ticket_id;

        SELECT INTO n COUNT(*) FROM reports.tickets_status WHERE tk_id = ticket_id;

        IF n > 0 THEN
            RAISE NOTICE 'Ticket cannot be deleted: status != open';
            RETURN false;
        END IF;

        IF delete_all IS TRUE THEN
            -- original ticket, not a copy
            IF p IS NULL THEN
                DELETE FROM reports.tickets WHERE tk_parent_id_fk = ticket_id; --First I remove children
                DELETE FROM reports.tickets WHERE tk_id = ticket_id;

            -- possible copy of another ticket
            ELSE
                --remove all other copies after the one selected
                DELETE FROM reports.tickets WHERE tk_parent_id_fk = p AND tk_expiry_date > e;
                DELETE FROM reports.tickets WHERE tk_id = ticket_id;
            END IF;
        ELSE
            -- Original ticket -> must check if it has children
            IF p IS NULL THEN
                SELECT INTO n COUNT(*) FROM reports.tickets WHERE tk_parent_id_fk = ticket_id;
                IF n > 0 THEN
                    RAISE NOTICE 'Ticket has children! cannot be deleted';
                    RETURN FALSE;
                END IF;
            END IF;

            DELETE FROM reports.tickets WHERE tk_id = ticket_id;
        END IF;

        RETURN true;

        /* errors check */
        EXCEPTION WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN reports.f_delete_tickets(integer; boolean) : %', SQLERRM ;
            RETURN false; /* return value */
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION reports.f_delete_tickets(integer, boolean) TO group_admin;
    GRANT EXECUTE ON FUNCTION reports.f_delete_tickets(integer, boolean) TO group_bobo;
    GRANT EXECUTE ON FUNCTION reports.f_delete_tickets(integer, boolean) TO group_tools;

    -- comment
    COMMENT ON FUNCTION reports.f_delete_tickets(integer, boolean)
        IS 'Function in order to delete tickets';

    -- Funzione per generare automaticamente i ticket periodici
    -- DROP FUNCTION reports.f_insert_periodic_tickets(integer, timestamp, timestamp, integer);
    CREATE OR REPLACE FUNCTION reports.f_insert_periodic_tickets(
        tk_parent_id integer,
        date_from    timestamp,
        date_to      timestamp,
        frequency    integer
    )
        RETURNS boolean
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE
    AS $BODY$

    DECLARE
        d interval;
    BEGIN
        -- TEST SELECT reports.f_insert_periodic_tickets(1, '2019-04-29 09:00'::timestamp, '2020-04-29 09:00'::timestamp, 6);

        -- Check if parent ticket exists
        IF NOT EXISTS ( SELECT 1 FROM reports.tickets WHERE tk_id = tk_parent_id ) THEN
            RAISE NOTICE 'ERROR IN reports.f_insert_periodic_tickets(integer; boolean) : parent ticket doesn''t exist' ;
            RETURN false;
        END IF;

        SELECT INTO d tf_db FROM reports.ticket_frequencies WHERE tf_id = frequency;

        -- RAISE NOTICE 'Frequenza: %', d;

        -- Check if delta date is greater equal then 5 years _> not allowed
        IF (SELECT (date_to - date_from)  < interval '5 years') IS FALSE THEN
            RAISE NOTICE 'ERROR IN reports.f_insert_periodic_tickets(integer; boolean) : max 5 years' ;
            RETURN false;
        END IF;

        -- Loop while date_from is lower than date_to
        WHILE date_from < date_to
        LOOP
            -- EXTRACT 'dow' -> [0-6] where 0 is Sunday
            -- If Saturday + 2 days, else if Sunday + 1 day, else OK
            SELECT INTO date_from
                CASE
                    WHEN EXTRACT('dow' FROM (date_from + d )) = 6 THEN date_from + d + interval '2 days'
                    WHEN EXTRACT('dow' FROM (date_from + d )) = 0 THEN date_from + d + interval '1 day'
                    ELSE date_from + d
                END AS next_day;

            RAISE NOTICE 'Nuova data: %', date_from;

            -- Check if new date is lower then date_to
            IF date_from < date_to THEN
                INSERT INTO reports.tickets
                    (tk_opening_date, tk_expiry_date, tk_opening_user_fk, tk_recipient_comp_fk, station_id, instr_id, cy_id, mi_id, tt_id, tc_id, tu_id, tf_id, tk_title, tk_opening_note, tk_parent_id_fk)
                (
                    SELECT
                        tk_opening_date,
                        date_from                                       AS tk_expiry_date,
                        tk_opening_user_fk,
                        tk_recipient_comp_fk,
                        station_id, instr_id, cy_id, mi_id, tt_id,
                        tc_id, tu_id, tf_id, tk_title,
                        tk_opening_note,
                        tk_parent_id                                    AS tk_parent_id_fk
                    FROM reports.tickets
                    WHERE tk_id = tk_parent_id
                );
            END IF;
        END LOOP;

        RETURN TRUE;

        /* errors check */
        EXCEPTION WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN reports.f_insert_periodic_tickets(integer, timestamp, timestamp, integer) : %', SQLERRM ;
            RETURN FALSE; /* return value */
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION reports.f_insert_periodic_tickets(integer, timestamp, timestamp, integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION reports.f_insert_periodic_tickets(integer, timestamp, timestamp, integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION reports.f_insert_periodic_tickets(integer, timestamp, timestamp, integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION reports.f_insert_periodic_tickets(integer, timestamp, timestamp, integer)
        IS 'Function in order to dynamically create periodic tickets';

-- SCHEMA gateways

    -- DROP SCHEMA IF EXISTS gateways CASCADE;
    CREATE SCHEMA gateways
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA gateways TO group_admin;
    GRANT USAGE ON SCHEMA gateways TO group_bobo;
    GRANT USAGE ON SCHEMA gateways TO group_tools;
    COMMENT ON SCHEMA gateways IS 'Schema used for mails, telegram, ecc gateways';

    -- --------------------------------------------------------------------------------------------
    -- TYPES
    -- --------------------------------------------------------------------------------------------

    -- DROP TYPE IF EXISTS gateways.enum_parse_mode;
    CREATE TYPE gateways.enum_parse_mode AS ENUM ('Markdown','HTML');
    ALTER TYPE gateways.enum_parse_mode OWNER TO user_admin;

    -- DROP TYPE IF EXISTS gateways.enum_telegram_type;
    CREATE TYPE gateways.enum_telegram_type AS ENUM ('Message','Photo','Document');
    ALTER TYPE gateways.enum_telegram_type OWNER TO user_admin;

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella che contiene le informazioni relative ai canali presenti sull'applicativo Telegram
    -- DROP TABLE IF EXISTS gateways.telegram_channels;
    CREATE TABLE gateways.telegram_channels (
        tc_id    serial,
        chat     text,
        tc_name  text,
        tc_desc  text,
        tc_color text DEFAULT 'primary',

        CONSTRAINT gateways_telegram_channels_pkey PRIMARY KEY (tc_id),
        CONSTRAINT gateways_telegram_channels_ukey UNIQUE (chat)
    )
    WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE gateways.telegram_channels TO GROUP group_admin;
    GRANT ALL ON TABLE gateways.telegram_channels TO GROUP group_bobo;
    GRANT ALL ON TABLE gateways.telegram_channels TO GROUP group_tools;

    -- comments
    COMMENT ON TABLE  gateways.telegram_channels          IS 'Store telegram channels info';
    COMMENT ON COLUMN gateways.telegram_channels.tc_id    IS 'Telegram channel id (PK)';
    COMMENT ON COLUMN gateways.telegram_channels.chat     IS 'Telegram channel';
    COMMENT ON COLUMN gateways.telegram_channels.tc_name  IS 'Telegram channel name';
    COMMENT ON COLUMN gateways.telegram_channels.tc_desc  IS 'Telegram channel description';
    COMMENT ON COLUMN gateways.telegram_channels.tc_color IS 'Telegram channel color';

    -- Tabella che contiene le mail esterne, cioè diverse da quelle degli utenti presenti sul portale
    -- DROP TABLE IF EXISTS gateways.external_emails CASCADE;
    CREATE TABLE gateways.external_emails (
        ee_id      serial,
        ee_name    text,
        ee_surname text,
        ee_mail    email NOT NULL CHECK (ee_mail <> ''),
        comp_id    integer,
        portal_ids integer[],

        CONSTRAINT gateways_external_emails_pkey PRIMARY KEY (ee_id),
        CONSTRAINT gateways_external_emails_ukey UNIQUE (ee_mail)
        -- CONSTRAINT gateways_external_emails_fkey FOREIGN KEY (comp_id)
        -- REFERENCES bobo.companies (comp_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    gateways.external_emails TO group_admin;
    GRANT ALL ON TABLE    gateways.external_emails TO group_bobo;
    GRANT ALL ON TABLE    gateways.external_emails TO group_tools;
    GRANT SELECT ON TABLE gateways.external_emails TO group_readonly;
    GRANT ALL ON SEQUENCE gateways.external_emails_ee_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE gateways.external_emails_ee_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE gateways.external_emails_ee_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  gateways.external_emails            IS 'Table that contains all external emails not present in the list of users';
    COMMENT ON COLUMN gateways.external_emails.ee_id      IS 'External email id (PK)';
    COMMENT ON COLUMN gateways.external_emails.ee_name    IS 'External email name';
    COMMENT ON COLUMN gateways.external_emails.ee_surname IS 'External email surname';
    COMMENT ON COLUMN gateways.external_emails.ee_mail    IS 'External email address';
    COMMENT ON COLUMN gateways.external_emails.comp_id    IS 'Company id (FK) to which the external mail is associated';
    COMMENT ON COLUMN gateways.external_emails.portal_ids IS 'Portals where the external mail is visible';

    -- Tabella che contiene le informazioni relative allo scheletro html delle mail inviate dal sistema
    -- DROP TABLE IF EXISTS gateways.html_mails CASCADE;
    CREATE TABLE gateways.html_mails (
        id          serial,
        app         text default null,
        recipients  text not null,
        subject     text not NULL,
        body        text not NULL,
        logo        text not NULL,
        status      boolean default null, -- null = new, false = error, true = sent
        insert_time timestamp not null default current_timestamp,
        sent_time   timestamp default null,
        sent_tries  smallint default 0,

        CONSTRAINT gateways_html_mails_pkey PRIMARY KEY (id)
    )
    WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    gateways.html_mails TO GROUP group_bobo;
    GRANT ALL ON TABLE    gateways.html_mails TO GROUP group_tools;
    GRANT ALL ON SEQUENCE gateways.html_mails_id_seq TO GROUP group_bobo;
    GRANT ALL ON SEQUENCE gateways.html_mails_id_seq TO GROUP group_tools;

    -- comments
    COMMENT ON TABLE  gateways.html_mails             IS 'Store sent mails';
    COMMENT ON COLUMN gateways.html_mails.id          IS 'Progressive id';
    COMMENT ON COLUMN gateways.html_mails.app         IS 'Coming application';
    COMMENT ON COLUMN gateways.html_mails.recipients  IS 'Mail recipients, separetd by [;]';
    COMMENT ON COLUMN gateways.html_mails.subject     IS 'Mail subject';
    COMMENT ON COLUMN gateways.html_mails.body        IS 'Mail body';
    COMMENT ON COLUMN gateways.html_mails.logo        IS 'Mail logo';
    COMMENT ON COLUMN gateways.html_mails.status      IS 'Status : null => new, false => error, true => sent';
    COMMENT ON COLUMN gateways.html_mails.insert_time IS 'The time mail has been inserted into the table';
    COMMENT ON COLUMN gateways.html_mails.sent_time   IS 'The time mail has been sent';
    COMMENT ON COLUMN gateways.html_mails.sent_tries  IS 'The tries before mail has been sent';

    -- Tabella che contiene le informazioni relative alle mailing lists presenti sul portale
    -- DROP TABLE IF EXISTS gateways.mailing_list CASCADE;
    CREATE TABLE gateways.mailing_list (
        ml_id           serial,
        ml_name         text NOT NULL,
        ml_description  text,
        comp_id         integer,
        portal_id       integer NOT NULL,
        insert_ts       timestamp NOT NULL DEFAULT current_timestamp,

        CONSTRAINT gateways_mailing_list_pkey PRIMARY KEY (ml_id)
        -- CONSTRAINT gateways_mailing_list_fkey1 FOREIGN KEY (comp_id)
        -- REFERENCES bobo.companies (comp_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT gateways_mailing_list_fkey2 FOREIGN KEY (portal_id)
        -- REFERENCES bobo.portals (portal_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    gateways.mailing_list TO group_admin;
    GRANT ALL ON TABLE    gateways.mailing_list TO group_bobo;
    GRANT ALL ON TABLE    gateways.mailing_list TO group_tools;
    GRANT SELECT ON TABLE gateways.mailing_list TO group_readonly;
    GRANT ALL ON SEQUENCE gateways.mailing_list_ml_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE gateways.mailing_list_ml_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE gateways.mailing_list_ml_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  gateways.mailing_list                IS 'Table that contains all mailing list';
    COMMENT ON COLUMN gateways.mailing_list.ml_id          IS 'Mailing list id (PK)';
    COMMENT ON COLUMN gateways.mailing_list.ml_name        IS 'Mailing list name';
    COMMENT ON COLUMN gateways.mailing_list.ml_description IS 'Mailing list description';
    COMMENT ON COLUMN gateways.mailing_list.comp_id        IS 'Company id (FK) to which the mailing list is associated';
    COMMENT ON COLUMN gateways.mailing_list.portal_id      IS 'Portal where the mailing list is visible';
    COMMENT ON COLUMN gateways.mailing_list.insert_ts      IS 'Mailing list creation time';

    -- Tabella che contiene le associazioni tra le mail esterne e le varie mailing lists
    -- DROP TABLE IF EXISTS gateways.mlist_users CASCADE;
    CREATE TABLE gateways.mlist_external_mails (
        mem_id  serial,
        ml_id   integer NOT NULL,
        ee_id   integer NOT NULL,

        CONSTRAINT gateways_mlist_external_mails_pkey PRIMARY KEY (mem_id)
        -- CONSTRAINT gateways_mlist_external_mails_fkey1 FOREIGN KEY (ml_id)
        -- REFERENCES gateways.mailing_list (ml_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT gateways_mlist_external_mails_fkey2 FOREIGN KEY (ee_id)
        -- REFERENCES gateways.external_emails (ee_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    gateways.mlist_external_mails TO group_admin;
    GRANT ALL ON TABLE    gateways.mlist_external_mails TO group_bobo;
    GRANT ALL ON TABLE    gateways.mlist_external_mails TO group_tools;
    GRANT SELECT ON TABLE gateways.mlist_external_mails TO group_readonly;
    GRANT ALL ON SEQUENCE gateways.mlist_external_mails_mem_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE gateways.mlist_external_mails_mem_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE gateways.mlist_external_mails_mem_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  gateways.mlist_external_mails        IS 'Table that holds relations between mailing list and external emails';
    COMMENT ON COLUMN gateways.mlist_external_mails.mem_id IS 'Relation id (PK)';
    COMMENT ON COLUMN gateways.mlist_external_mails.ml_id  IS 'Mailing list ID (FK)';
    COMMENT ON COLUMN gateways.mlist_external_mails.ee_id  IS 'External email ID (FK)';

    -- Tabella che contiene le associazioni tra utenti e mailing lists
    -- DROP TABLE IF EXISTS gateways.mlist_users CASCADE;
    CREATE TABLE gateways.mlist_users (
        mu_id serial,
        ml_id integer NOT NULL,
        us_id integer NOT NULL,

        CONSTRAINT gateways_mlist_users_pkey PRIMARY KEY (mu_id)
        -- CONSTRAINT gateways_mlist_users_fkey1 FOREIGN KEY (ml_id)
        -- REFERENCES gateways.mailing_list (ml_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT gateways_mlist_users_fkey2 FOREIGN KEY (us_id)
        -- REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    gateways.mlist_users TO group_admin;
    GRANT ALL ON TABLE    gateways.mlist_users TO group_bobo;
    GRANT ALL ON TABLE    gateways.mlist_users TO group_tools;
    GRANT SELECT ON TABLE gateways.mlist_users TO group_readonly;
    GRANT ALL ON SEQUENCE gateways.mlist_users_mu_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE gateways.mlist_users_mu_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE gateways.mlist_users_mu_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  gateways.mlist_users       IS 'Table that holds relations between mailing list and users';
    COMMENT ON COLUMN gateways.mlist_users.mu_id IS 'Relation id (PK)';
    COMMENT ON COLUMN gateways.mlist_users.ml_id IS 'Mailing list ID (FK)';
    COMMENT ON COLUMN gateways.mlist_users.us_id IS 'User ID (FK)';

    -- Tabella che contiene le informazioni relative ai messaggi inviati dal sistema attraverso l'applicativo 'Telegram'
    -- DROP TABLE IF EXISTS gateways.telegrams CASCADE;
    CREATE TABLE gateways.telegrams (
        id               serial,
        app              text default null,
        tag              text default null,
        chat             text not null,
        telegram_type    gateways.enum_telegram_type NOT NULL DEFAULT 'Message',
        parse_mode       gateways.enum_parse_mode DEFAULT 'Markdown',
        message          text,
        photo            text,
        photo_caption    text,
        document         text,
        document_caption text,
        status           boolean default null, -- null = new, false = error, true = sent
        response         jsonb default null,
        insert_time      timestamp not null default current_timestamp,
        sent_time        timestamp default null,
        sent_tries       smallint default 0,
        tobe_deleted     boolean default false, -- false = nothing, true = to be deleted
        deleted          boolean default null, -- null = , false = , true = deleted
        deleted_time     timestamp default null,
        deleted_tries    smallint default 0,
        deleted_response jsonb default null,
        us_id integer,

        CONSTRAINT gateways_telegrams_pkey PRIMARY KEY (id)
        -- CONSTRAINT gateways_telegrams_fkey FOREIGN KEY (us_id)
        -- REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITHOUT OIDS;

    -- grants
    GRANT ALL ON TABLE    gateways.telegrams TO GROUP group_admin;
    GRANT ALL ON TABLE    gateways.telegrams TO GROUP group_bobo;
    GRANT ALL ON TABLE    gateways.telegrams TO GROUP group_tools;
    GRANT ALL ON SEQUENCE gateways.telegrams_id_seq TO GROUP group_admin;
    GRANT ALL ON SEQUENCE gateways.telegrams_id_seq TO GROUP group_bobo;
    GRANT ALL ON SEQUENCE gateways.telegrams_id_seq TO GROUP group_tools;

    -- comments
    COMMENT ON TABLE  gateways.telegrams                  IS 'Store telegram messages';
    COMMENT ON COLUMN gateways.telegrams.id               IS 'Progressive id';
    COMMENT ON COLUMN gateways.telegrams.app              IS 'Coming application';
    COMMENT ON COLUMN gateways.telegrams.tag              IS 'Telegram custom tag';
    COMMENT ON COLUMN gateways.telegrams.chat             IS 'Chat id';
    COMMENT ON COLUMN gateways.telegrams.telegram_type    IS 'The telegram type (Message, Photo, Document)';
    COMMENT ON COLUMN gateways.telegrams.parse_mode       IS 'The telegram parse mode (Markdown, HTML)';
    COMMENT ON COLUMN gateways.telegrams.message          IS 'Message to be sent';
    COMMENT ON COLUMN gateways.telegrams.photo            IS 'Photo filename, if any to be sent';
    COMMENT ON COLUMN gateways.telegrams.photo_caption    IS 'Photo caption';
    COMMENT ON COLUMN gateways.telegrams.document         IS 'Document filename, if any to be sent';
    COMMENT ON COLUMN gateways.telegrams.document_caption IS 'Document caption';
    COMMENT ON COLUMN gateways.telegrams.status           IS 'Status : null => new, false => error, true => sent';
    COMMENT ON COLUMN gateways.telegrams.response         IS 'The response from telegram API';
    COMMENT ON COLUMN gateways.telegrams.insert_time      IS 'The time telegram has been inserted into the table';
    COMMENT ON COLUMN gateways.telegrams.sent_time        IS 'The time telegram has been sent';
    COMMENT ON COLUMN gateways.telegrams.sent_tries       IS 'The tries before telegram has been sent';
    COMMENT ON COLUMN gateways.telegrams.tobe_deleted     IS 'The message must be deleted';
    COMMENT ON COLUMN gateways.telegrams.deleted          IS 'The message has been deleted';
    COMMENT ON COLUMN gateways.telegrams.deleted_time     IS 'The message deletion time';
    COMMENT ON COLUMN gateways.telegrams.deleted_tries    IS 'The tries before telegram has been deleted';
    COMMENT ON COLUMN gateways.telegrams.deleted_response IS 'The response from telegram API';
    COMMENT ON COLUMN gateways.telegrams.us_id            IS 'Telegram message creator';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- Vista che raccoglie le informazioni relative ai messaggi dell'applicativo Telegram
    -- DROP VIEW IF EXISTS gateways.view_telegrams;
    CREATE OR REPLACE VIEW gateways.view_telegrams AS
    SELECT
        id                               AS id,
        app                              AS app,
        tag                              AS tag,
        chat                             AS chat,
        telegram_type                    AS telegram_type,
        parse_mode                       AS parse_mode,
        message                          AS message,
        photo                            AS photo,
        photo_caption                    AS photo_caption,
        document                         AS document,
        document_caption                 AS document_caption,
        status                           AS status,
        response                         AS response,
        response->'result'->'message_id' AS message_id,
        insert_time                      AS insert_time,
        sent_time                        AS sent_time,
        tobe_deleted                     AS tobe_deleted,
        deleted                          AS deleted,
        deleted_time                     AS deleted_time
    FROM
        gateways.telegrams
    ORDER BY
        telegrams.id DESC;

    -- grants
    GRANT ALL ON TABLE gateways.view_telegrams    TO group_admin;
    GRANT SELECT ON TABLE gateways.view_telegrams TO group_tools;
    GRANT SELECT ON TABLE gateways.view_telegrams TO group_bobo;
    GRANT SELECT ON TABLE gateways.view_telegrams TO group_readonly;

    -- comment
    COMMENT ON VIEW gateways.view_telegrams IS 'View telegram messages';

    -- Vista che raccoglie le info dei widget in relazione ai gruppi a cui l'utente è associato
    -- DROP VIEW IF EXISTS bobo.view_user_channels;
    CREATE OR REPLACE VIEW bobo.view_user_channels AS
    SELECT DISTINCT ON (u.us_id, tc.chat)
        u.us_id AS user_id,
        u.us_name AS user_name,
        u.us_2nd_name AS user_second_name,
        u.us_surname AS user_surname,
        u.us_role AS user_role,
        u.us_email AS user_email,
        u.us_phone AS user_phone,
        u.us_mobile AS user_mobile,
        u.us_avatar AS user_avatar,
        u.us_avatar_thumb AS user_avatar_thumb,
        ARRAY( SELECT user_groups.gr_id
            FROM bobo.user_groups
            WHERE user_groups.us_id = u.us_id) AS user_groups_array,
        tc.tc_id   AS channel_id,
        tc.chat    AS chat,
        tc.tc_name AS channel_name,
        tc.tc_desc AS channel_desc,
        (
            SELECT bit_or(tbit.gc_iud_grants) AS bit_or
            FROM (
                SELECT group_channels.gc_iud_grants
                FROM bobo.group_channels
                WHERE group_channels.tc_id = tc.tc_id
                AND ( group_channels.gr_id IN (
                    SELECT user_groups.gr_id
                    FROM bobo.user_groups
                    WHERE user_groups.us_id = u.us_id )
                )
            ) tbit
        ) AS total_user_grants
    FROM bobo.users u
        LEFT JOIN bobo.user_groups ug USING (us_id)
        LEFT JOIN bobo.groups g USING (gr_id)
        LEFT JOIN bobo.group_channels gc USING (gr_id)
        LEFT JOIN gateways.telegram_channels tc USING (tc_id)
    WHERE tc.tc_id IS NOT NULL
    ORDER BY
        u.us_id, tc.chat;

    -- grants
    GRANT ALL ON TABLE    bobo.view_user_channels TO group_admin;
    GRANT ALL ON TABLE    bobo.view_user_channels TO group_bobo;
    GRANT ALL ON TABLE    bobo.view_user_channels TO group_tools;
    GRANT SELECT ON TABLE bobo.view_user_channels TO group_readonly;

    -- comment
    COMMENT ON VIEW bobo.view_user_channels IS 'Available channels per user';

    -- Vista che raccoglie le informazioni relative alle associazioni ticket-mailing lists
    -- DROP VIEW IF EXISTS reports.view_tickets_mlists;
    CREATE OR REPLACE VIEW reports.view_tickets_mlists AS
    SELECT
        tk_id                                                                                  AS tk_id,
        ml_id                                                                                  AS ml_id,
        ARRAY_REMOVE(ARRAY_AGG(u.us_id)   , NULL)                                              AS user_ids,
        ARRAY_REMOVE(ARRAY_AGG(u.us_email), NULL)                                              AS user_mails,
        ARRAY_REMOVE(ARRAY_AGG(ee.ee_id)  , NULL)                                              AS external_ids,
        ARRAY_REMOVE(ARRAY_AGG(ee.ee_mail), NULL)                                              AS external_mails,
        ARRAY_REMOVE(ARRAY_AGG(u.us_email), NULL) || ARRAY_REMOVE(ARRAY_AGG(ee.ee_mail), NULL) AS total_mails
    FROM
        reports.tickets_mlists
        LEFT JOIN gateways.mlist_users mu          USING (ml_id)
        LEFT JOIN bobo.users u                     USING (us_id)
        LEFT JOIN gateways.mlist_external_mails me USING (ml_id)
        LEFT JOIN gateways.external_emails ee      USING (ee_id)
    GROUP BY tk_id, ml_id
    ORDER BY tk_id, ml_id;

    -- grants
    GRANT ALL ON TABLE    reports.view_tickets_mlists TO group_admin;
    GRANT ALL ON TABLE    reports.view_tickets_mlists TO group_bobo;
    GRANT ALL ON TABLE    reports.view_tickets_mlists TO group_tools;
    GRANT SELECT ON TABLE reports.view_tickets_mlists TO group_readonly;

    -- comment
    COMMENT ON VIEW reports.view_tickets_mlists IS 'The view contains all the principal info about relations tickets-mlist';

-- SCHEMA audit

    -- DROP SCHEMA IF EXISTS audit CASCADE;
    CREATE SCHEMA audit
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA audit TO group_admin;
    GRANT USAGE ON SCHEMA audit TO group_bobo;
    GRANT USAGE ON SCHEMA audit TO group_readonly;
    GRANT USAGE ON SCHEMA audit TO group_tools;
    COMMENT ON SCHEMA audit IS 'Audit schema for OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella che contiene le informazioni relative agli accessi effettuati sul portale
    -- DROP TABLE IF EXISTS audit.access_log;
    CREATE TABLE audit.access_log
    (
        log_id          bigserial,
        log_headers     jsonb NOT NULL,
        log_email       email NOT NULL,
        log_result      text,
        log_insert_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT audit_access_log_pkey PRIMARY KEY (log_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    audit.access_log TO group_admin;
    GRANT ALL ON TABLE    audit.access_log TO group_bobo;
    GRANT ALL ON TABLE    audit.access_log TO group_tools;
    GRANT SELECT ON TABLE audit.access_log TO group_readonly;
    GRANT ALL ON SEQUENCE audit.access_log_log_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE audit.access_log_log_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE audit.access_log_log_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  audit.access_log                 IS 'Table with audit about access log';
    COMMENT ON COLUMN audit.access_log.log_id          IS 'Log serial id';
    COMMENT ON COLUMN audit.access_log.log_headers     IS 'Log header (JSON)';
    COMMENT ON COLUMN audit.access_log.log_email       IS 'Log email';
    COMMENT ON COLUMN audit.access_log.log_result      IS 'Log result';
    COMMENT ON COLUMN audit.access_log.log_insert_time IS 'Log insert time';

    -- Tabella che contiene le informazioni relative agli audit delle operazioni effettuate nell'applicativo "Analyser"
    -- DROP TABLE IF EXISTS audit.analyser;
    CREATE TABLE audit.analyser
    (
        log_id          serial,
        log_user        integer,
        log_action      text,
        log_data        jsonb NOT NULL,
        log_insert_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT audit_analyser_pkey PRIMARY KEY (log_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    audit.analyser TO group_admin;
    GRANT ALL ON TABLE    audit.analyser TO group_bobo;
    GRANT ALL ON TABLE    audit.analyser TO group_tools;
    GRANT SELECT ON TABLE audit.analyser TO group_readonly;
    GRANT ALL ON SEQUENCE audit.analyser_log_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE audit.analyser_log_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE audit.analyser_log_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  audit.analyser                 IS 'Table with audit data of analyser tool';
    COMMENT ON COLUMN audit.analyser.log_id          IS 'Log serial id';
    COMMENT ON COLUMN audit.analyser.log_action      IS 'Log action';
    COMMENT ON COLUMN audit.analyser.log_data        IS 'Log data (JSON)';
    COMMENT ON COLUMN audit.analyser.log_insert_time IS 'Log insert time';

    -- Tabella che contiene le informazioni relative agli audit dell'applicativo "Dataview"
    -- DROP TABLE IF EXISTS audit.dataview;
    CREATE TABLE audit.dataview
    (
        log_id          serial,
        log_data        jsonb NOT NULL,
        log_insert_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT audit_dataview_pkey PRIMARY KEY (log_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    audit.dataview TO group_admin;
    GRANT ALL ON TABLE    audit.dataview TO group_bobo;
    GRANT ALL ON TABLE    audit.dataview TO group_tools;
    GRANT SELECT ON TABLE audit.dataview TO group_readonly;
    GRANT ALL ON SEQUENCE audit.dataview_log_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE audit.dataview_log_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE audit.dataview_log_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  audit.dataview                 IS 'Table with audit data of dataview tool';
    COMMENT ON COLUMN audit.dataview.log_id          IS 'Log serial id';
    COMMENT ON COLUMN audit.dataview.log_data        IS 'Log data (JSON)';
    COMMENT ON COLUMN audit.dataview.log_insert_time IS 'Log insert time';

    -- Tabella che contiene le informazioni relative agli audit dei report taratura effettuati sul portale
    -- DROP TABLE IF EXISTS audit.rep_qacalibrations;
    CREATE TABLE audit.rep_qacalibrations
    (
        log_id          serial,
        log_user        integer,
        log_action      text,
        log_data        jsonb NOT NULL,
        log_insert_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT audit_rep_qacalibrations_pkey PRIMARY KEY (log_id)
        -- CONSTRAINT audit_rep_qacalibrations_fkey FOREIGN KEY (log_user)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    audit.rep_qacalibrations TO group_admin;
    GRANT ALL ON TABLE    audit.rep_qacalibrations TO group_bobo;
    GRANT ALL ON TABLE    audit.rep_qacalibrations TO group_tools;
    GRANT SELECT ON TABLE audit.rep_qacalibrations TO group_readonly;
    GRANT ALL ON SEQUENCE audit.rep_qacalibrations_log_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE audit.rep_qacalibrations_log_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE audit.rep_qacalibrations_log_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  audit.rep_qacalibrations                 IS 'Table with audit data of calibrations reports';
    COMMENT ON COLUMN audit.rep_qacalibrations.log_id          IS 'Log serial id';
    COMMENT ON COLUMN audit.rep_qacalibrations.log_user        IS 'Log user id (FK)';
    COMMENT ON COLUMN audit.rep_qacalibrations.log_action      IS 'Log action';
    COMMENT ON COLUMN audit.rep_qacalibrations.log_data        IS 'Log data (JSON)';
    COMMENT ON COLUMN audit.rep_qacalibrations.log_insert_time IS 'Log insert time';

    -- Tabella che contiene le informazioni relative agli audit dei report manutenzione effettuati sul portale
    -- DROP TABLE IF EXISTS audit.rep_qamanutenzioni;
    CREATE TABLE audit.rep_qamaintenances
    (
        log_id          serial,
        log_user        integer,
        log_action      text,
        log_data        jsonb NOT NULL,
        log_insert_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT audit_rep_qamaintenances_pkey PRIMARY KEY (log_id)
        -- CONSTRAINT audit_rep_qamaintenances_fkey FOREIGN KEY (log_user)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    audit.rep_qamaintenances TO group_admin;
    GRANT ALL ON TABLE    audit.rep_qamaintenances TO group_bobo;
    GRANT ALL ON TABLE    audit.rep_qamaintenances TO group_tools;
    GRANT SELECT ON TABLE audit.rep_qamaintenances TO group_readonly;
    GRANT ALL ON SEQUENCE audit.rep_qamaintenances_log_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE audit.rep_qamaintenances_log_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE audit.rep_qamaintenances_log_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  audit.rep_qamaintenances                 IS 'Table with audit data of maintenances reports';
    COMMENT ON COLUMN audit.rep_qamaintenances.log_id          IS 'Log serial id';
    COMMENT ON COLUMN audit.rep_qamaintenances.log_user        IS 'Log user id (FK)';
    COMMENT ON COLUMN audit.rep_qamaintenances.log_action      IS 'Log action';
    COMMENT ON COLUMN audit.rep_qamaintenances.log_data        IS 'Log data (JSON)';
    COMMENT ON COLUMN audit.rep_qamaintenances.log_insert_time IS 'Log insert time';

    -- Tabella che contiene le informazioni relative agli audit delle operazioni effettuate nell'applicativo "Impostazioni - Stazioni"
    -- DROP TABLE IF EXISTS audit.stations;
    CREATE TABLE audit.stations
    (
        log_id              serial,
        log_user            integer,
        log_action          text,
        log_data            jsonb NOT NULL,
        log_insert_time     timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT audit_stations_pkey PRIMARY KEY (log_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    audit.stations TO group_admin;
    GRANT ALL ON TABLE    audit.stations TO group_bobo;
    GRANT ALL ON TABLE    audit.stations TO group_tools;
    GRANT SELECT ON TABLE audit.stations TO group_readonly;
    GRANT ALL ON SEQUENCE audit.stations_log_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE audit.stations_log_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE audit.stations_log_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  audit.stations                 IS 'Table with audit data of validation tool';
    COMMENT ON COLUMN audit.stations.log_id          IS 'Log serial id';
    COMMENT ON COLUMN audit.stations.log_action      IS 'Log action';
    COMMENT ON COLUMN audit.stations.log_data        IS 'Log data (JSON)';
    COMMENT ON COLUMN audit.stations.log_insert_time IS 'Log insert time';

    -- Tabella che contiene le informazioni relative agli audit delle operazioni effettuate nell'applicativo "Validazione"
    -- DROP TABLE IF EXISTS audit.validation;
    CREATE TABLE audit.validation
    (
        log_id          serial,
        log_user        integer,
        log_action      text,
        log_data        jsonb NOT NULL,
        log_insert_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT audit_validation_pkey PRIMARY KEY (log_id)
    )
    WITH (OIDS=FALSE);

    -- grants
    GRANT ALL ON TABLE    audit.validation TO group_admin;
    GRANT ALL ON TABLE    audit.validation TO group_bobo;
    GRANT ALL ON TABLE    audit.validation TO group_tools;
    GRANT SELECT ON TABLE audit.validation TO group_readonly;
    GRANT ALL ON SEQUENCE audit.validation_log_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE audit.validation_log_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE audit.validation_log_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  audit.validation                 IS 'Table with audit data of validation tool';
    COMMENT ON COLUMN audit.validation.log_id          IS 'Log serial id';
    COMMENT ON COLUMN audit.validation.log_action      IS 'Log action';
    COMMENT ON COLUMN audit.validation.log_data        IS 'Log data (JSON)';
    COMMENT ON COLUMN audit.validation.log_insert_time IS 'Log insert time';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- Vista che raccoglie le informazioni relative agli audit dell'applicativo "Validazione"
    -- DROP VIEW audit.view_validation;
    CREATE OR REPLACE VIEW audit.view_validation AS
    WITH temp AS (
            SELECT validation.log_id,
                validation.log_user,
                validation.log_action,
                validation.log_insert_time,
                validation.log_data,
                jsonb_array_elements(((validation.log_data ->> 'cells'::text))::jsonb) AS element
            FROM audit.validation
            )
    SELECT t.log_insert_time,
        t.log_action,
        t.log_user,
        (((u.us_name || ' '::text) || COALESCE((u.us_2nd_name || ' '::text), ''::text)) || u.us_surname) AS log_user_fullname,
        (t.element ->> 'table'::text) AS log_fulltable,
        ((t.element ->> 'tableid'::text))::integer AS log_table_id,
        ((t.element ->> 'date'::text))::timestamp without time zone AS log_fulldate,
        ((t.log_data ->> 'from'::text))::timestamp without time zone AS log_from,
        ((t.log_data ->> 'to'::text))::timestamp without time zone AS log_to,
        ((t.element ->> 'grant'::text))::boolean AS log_grant,
        ((t.element ->> 'code'::text))::integer AS log_code,
        ((t.element ->> 'value'::text))::numeric AS log_value,
        ((t.element ->> 'oldvalue'::text))::numeric AS log_value_old
    FROM (temp t
        LEFT JOIN bobo.users u ON ((t.log_user = u.us_id)))
    ORDER BY ((t.element ->> 'date'::text))::timestamp without time zone;

    -- comments
    COMMENT ON VIEW audit.view_validation IS 'View with audit data of validation tool';

-- SCHEMA template

    -- DROP SCHEMA IF EXISTS template CASCADE;
    CREATE SCHEMA template
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA template TO group_admin;
    GRANT USAGE ON SCHEMA template TO group_bobo;
    GRANT USAGE ON SCHEMA template TO group_readonly;
    GRANT USAGE ON SCHEMA template TO group_tools;
    COMMENT ON SCHEMA template IS 'Template schema for OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella di template per la creazione delle tabelle dati di OPAS
    -- DROP TABLE IF EXISTS template.opas;
    CREATE TABLE template.opas
    (
        measure_date_time   timestamp without time zone NOT NULL,
        measure_id          integer NOT NULL,
        measure_value       numeric NOT NULL,
        measure_perc        smallint DEFAULT 100,
        measure_min         numeric DEFAULT NULL,
        measure_min_time    time DEFAULT NULL,
        measure_max         numeric DEFAULT NULL,
        measure_max_time    time DEFAULT NULL,
        measure_std_dev     numeric DEFAULT NULL,
        measure_code        integer DEFAULT 0,
        station_code        smallint DEFAULT 0,
        auto_validity_code  integer DEFAULT 0,
        post_validity_code  integer DEFAULT 0,
        final_validity_code smallint DEFAULT 0,
        extract_code        smallint DEFAULT 1,
        measure_insert_ts   timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        measure_update_obj  jsonb,

        CONSTRAINT template_opas_pkey PRIMARY KEY (measure_date_time, measure_id)
    );

    -- grants
    GRANT ALL ON TABLE    template.opas TO group_admin;
    GRANT ALL ON TABLE    template.opas TO group_bobo;
    GRANT ALL ON TABLE    template.opas TO group_tools;
    GRANT SELECT ON TABLE template.opas TO group_readonly;
    GRANT INSERT ON TABLE template.opas TO user_swam;

    -- comments
    COMMENT ON TABLE  template.opas                     IS 'Template for data tables';
    COMMENT ON COLUMN template.opas.measure_date_time   IS 'Measure date and time';
    COMMENT ON COLUMN template.opas.measure_id          IS 'Measure id';
    COMMENT ON COLUMN template.opas.measure_value       IS 'Measure value';
    COMMENT ON COLUMN template.opas.measure_perc        IS 'Measure data validity percentage';
    COMMENT ON COLUMN template.opas.measure_min         IS 'Measure minimum data';
    COMMENT ON COLUMN template.opas.measure_min_time    IS 'Measure minimum time';
    COMMENT ON COLUMN template.opas.measure_max         IS 'Measure maximum data';
    COMMENT ON COLUMN template.opas.measure_max_time    IS 'Measure maximum time';
    COMMENT ON COLUMN template.opas.measure_std_dev     IS 'Measure standard deviation';
    COMMENT ON COLUMN template.opas.measure_code        IS 'Measure general code';
    COMMENT ON COLUMN template.opas.station_code        IS 'Station general code';
    COMMENT ON COLUMN template.opas.auto_validity_code  IS 'Validity code assigned by automatic systems';
    COMMENT ON COLUMN template.opas.post_validity_code  IS 'Validity code assigned by an operator';
    COMMENT ON COLUMN template.opas.final_validity_code IS 'Final code assigned by an operator for daily, monthly, yearly validation';
    COMMENT ON COLUMN template.opas.extract_code        IS 'Support column used for the correct extraction of the percentage of daily data';
    COMMENT ON COLUMN template.opas.measure_insert_ts   IS 'Measure insert time into the database';
    COMMENT ON COLUMN template.opas.measure_update_obj  IS 'Measure last update time';

    -- Tabella di template per la creazione delle tabelle contenenti i dati istantanei delle stazioni
    -- DROP TABLE IF EXISTS template.realtime;
    CREATE TABLE template.realtime
    (
        -- from periphery
        measure_date_time timestamp without time zone NOT NULL,
        measure_id        integer NOT NULL,
        measure_value     numeric NOT NULL,
        measure_code      integer  DEFAULT 0,
        station_code      smallint DEFAULT 0,

        CONSTRAINT template_realtime_pkey PRIMARY KEY (measure_date_time, measure_id)
    );

    -- grants
    GRANT ALL ON TABLE    template.realtime TO group_admin;
    GRANT ALL ON TABLE    template.realtime TO group_bobo;
    GRANT ALL ON TABLE    template.realtime TO group_tools;
    GRANT SELECT ON TABLE template.realtime TO group_readonly;

    -- comments
    COMMENT ON TABLE  template.realtime                   IS 'Tabella dati real time (cadenza 1 minuto)';
    COMMENT ON COLUMN template.realtime.measure_date_time IS 'Measure date and time';
    COMMENT ON COLUMN template.realtime.measure_id        IS 'Measure id';
    COMMENT ON COLUMN template.realtime.measure_value     IS 'Measure value';
    COMMENT ON COLUMN template.realtime.measure_code      IS 'Measure general code';
    COMMENT ON COLUMN template.realtime.station_code      IS 'Station general code';

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Funzione per creare dinamicamente viste carte di controllo per ID stazione
    -- DROP FUNCTION IF EXISTS template.f_create_cc_view(integer);
    CREATE OR REPLACE FUNCTION template.f_create_cc_view(
        stid      integer
    )
        RETURNS boolean
        LANGUAGE 'plpgsql'
        SECURITY DEFINER
        COST 100
        VOLATILE
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

        -- "496" [CC] NOx Zero
        -- "497" [CC] NO Zero
        -- "498" [CC] NO2 Zero
        -- "499" [CC] NOx Span trovato
        -- "500" [CC] NOx Span verifica
        -- "501" [CC] NOx Span deriva
        -- "502" [CC] NO Span trovato
        -- "503" [CC] NO Span verifica
        -- "504" [CC] NO Span deriva
        -- "505" [CC] NO2 in NO ref
        -- "506" [CC] NO2 Span verifica
        -- "507" [CC] NO2 Span deriva
        -- "509" [CC] O3 Zero
        -- "510" [CC] O3 Span trovato
        -- "511" [CC] O3 Span verifica
        -- "512" [CC] O3 Span deriva
        -- "514" [CC] CO Zero
        -- "515" [CC] CO Span trovato
        -- "516" [CC] CO Span verifica
        -- "517" [CC] CO Span deriva
        -- "519" [CC] SO2 Zero
        -- "520" [CC] SO2 Span trovato
        -- "521" [CC] SO2 Span verifica
        -- "522" [CC] SO2 Span deriva
        -- "524" [CC] Ben Zero
        -- "525" [CC] Tol Zero
        -- "526" [CC] Xil Zero
        -- "527" [CC] Ben Span trovato
        -- "528" [CC] Ben Span verifica
        -- "529" [CC] Ben Span deriva
        -- "530" [CC] Tol Span trovato
        -- "531" [CC] Tol Span verifica
        -- "532" [CC] Tol Span deriva
        -- "533" [CC] Xil Span trovato
        -- "534" [CC] Xil Span verifica
        -- "535" [CC] Xil Span deriva
        -- "548" [CC] Ethylbenzene Span trovato
        -- "549" [CC] Ethylbenzene Span deriva
        -- "550" [CC] O-xylene Span trovato
        -- "551" [CC] O-xylene Span deriva
        -- "552" [CC] M&P-xylene Span trovato
        -- "553" [CC] M&P-xylene Span deriva

        -- "842" [CC] Cadmio su PM10 Zero
        -- "843" [CC] Cromo su PM10 Zero
        -- "844" [CC] Ferro su PM10 Zero
        -- "845" [CC] Manganese su PM10 Zero
        -- "846" [CC] Nichel su PM10 Zero
        -- "847" [CC] Piombo su PM10 Zero
        -- "848" [CC] Rame su PM10 Zero
        -- "849" [CC] Zinco su PM10 Zero
        -- "850" [CC] Arsenico su PM10 Zero
        -- "851" [CC] Vanadio su PM10 Zero
        -- "852" [CC] Cobalto su PM10 Zero
        -- "853" [CC] Mercurio su PM10 Zero
        -- "854" [CC] Fluorantene su PM10 Zero
        -- "855" [CC] Pirene su PM10 Zero
        -- "856" [CC] Benzo(a)Antracene su PM10 Zero
        -- "857" [CC] Crisene su PM10 Zero
        -- "858" [CC] Benzo(b)Fluorantene su PM10 Zero
        -- "859" [CC] Benzo(k)Fluorantene su PM10 Zero
        -- "860" [CC] Benzo(a)Pirene su PM10 Zero
        -- "861" [CC] DiBenzo(a,h)Antracene su PM10 Zero
        -- "862" [CC] Benzo(g,h,i)Perilene su PM10 Zero
        -- "863" [CC] Sodio in PM10 Zero
        -- "864" [CC] Ammonio in PM10 Zero
        -- "865" [CC] Magnesio in PM10 Zero
        -- "866" [CC] Potassio in PM10 Zero
        -- "867" [CC] Calcio in PM10 Zero
        -- "868" [CC] Cloruri in PM10 Zero
        -- "869" [CC] Nitrati in PM10 Zero
        -- "870" [CC] Solfati in PM10 Zero
        -- "871" [CC] Alluminio su PM10 Zero
        -- "872" [CC] PM10 Gravimetrica Zero
        -- "873" [CC] PM2.5 Gravimetrica Zero
        -- "874" [CC] Antimonio Zero
        -- "875" [CC] Antracene Zero
        -- "876" [CC] Bario Zero
        -- "877" [CC] Benzo(b+j)fluorantene Zero
        -- "878" [CC] Benzo(e)pirene Zero
        -- "879" [CC] Berillio Zero
        -- "880" [CC] Coronene Zero
        -- "881" [CC] Fenantrene Zero
        -- "882" [CC] Acenaftene Zero
        -- "883" [CC] Acenaftilene Zero
        -- "884" [CC] Selenio Zero
        -- "885" [CC] Titanio Zero
        -- "886" [CC] Fluorene Zero
        -- "887" [CC] Fluoruri Zero
        -- "888" [CC] Indeno(1,2,3-c,d)pirene Zero
        -- "889" [CC] Naftalene Zero
        -- "890" [CC] Sommatoria IPA Zero

        -- "1199" [CC] H2S Zero
        -- "1202" [CC] H2S Span trovato
        -- "1203" [CC] H2S Span verifica
        -- "1204" [CC] H2S Span deriva


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
                "1204": { "main_id" : "37", "step": "span", "deriva": "true"  }
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

            -- RAISE NOTICE 'Param id: %, param name: %, table id: %, Main id: %, step: %', rec.param_id, rec.parameter_name, rec.stpr_table_id, cc->(rec.param_id)::text->>'main_id', cc->(rec.param_id)::text->>'step';

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
        RAISE NOTICE 'Query finale: %', q;

        /* return value */
        EXECUTE q;
        RETURN TRUE;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR template.f_create_cc_view(): %', SQLERRM;
            RETURN FALSE;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION template.f_create_cc_view(integer) TO group_readonly;
    GRANT EXECUTE ON FUNCTION template.f_create_cc_view(integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION template.f_create_cc_view(integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION template.f_create_cc_view(integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION template.f_create_cc_view(integer) IS
        'Function to dynamically create CC views by station id';

    -- Funzione che crea la tabella dei dati istantanei
    -- DROP FUNCTION IF EXISTS template.f_create_inst_table_like_template(integer, boolean);
    CREATE OR REPLACE FUNCTION template.f_create_inst_table_like_template(
        st_id integer,
        drop  boolean
    )
    RETURNS boolean AS

    $BODY$

    DECLARE
        -- variables
        table_name text;
        sql_query  text;
    BEGIN
        -- TEST
        -- SELECT template.f_create_inst_table_like_template(1000::integer, false);

        SELECT station_fulltable||'_inst' INTO table_name
        FROM metadata.view_stations_info
        WHERE station_id = st_id;

        IF NOT FOUND THEN
            RAISE NOTICE 'Station % not found!', st_id;
            RETURN NULL;
        END IF;

        RAISE NOTICE 'Table name : %', table_name;

        IF drop IS TRUE THEN
            RAISE NOTICE 'Drop station % if exists!', table_name;
            sql_query = 'DROP TABLE IF EXISTS '|| table_name ||';';
            EXECUTE sql_query;
        END IF;

        sql_query = 'CREATE TABLE IF NOT EXISTS '|| table_name ||' (LIKE template.realtime INCLUDING ALL);';
        RAISE NOTICE 'Query : %', sql_query;

        EXECUTE sql_query;

        sql_query = 'GRANT ALL ON TABLE     '|| table_name ||' TO group_admin;   '
                ||'GRANT ALL ON TABLE     '|| table_name ||' TO group_bobo;    '
                ||'GRANT ALL ON TABLE     '|| table_name ||' TO group_tools;   '
                ||'GRANT SELECT ON TABLE  '|| table_name ||' TO group_readonly;';

        RAISE NOTICE 'Add grants';
        EXECUTE sql_query;

        RETURN TRUE;
        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN template.f_create_inst_table_like_template() : %', SQLERRM ;
            RETURN FALSE;
    END;

    $BODY$
    LANGUAGE 'plpgsql'
    VOLATILE
    COST 100;

    -- grants
    GRANT EXECUTE ON FUNCTION template.f_create_inst_table_like_template(integer, boolean) TO group_bobo;
    GRANT EXECUTE ON FUNCTION template.f_create_inst_table_like_template(integer, boolean) TO group_admin;
    GRANT EXECUTE ON FUNCTION template.f_create_inst_table_like_template(integer, boolean) TO group_tools;

    -- comment
    COMMENT ON FUNCTION template.f_create_inst_table_like_template(integer, boolean)
        IS 'Function that creates dynamically station table like a predefined template';

    -- Funzione che crea le tabelle e i trigger per la nuova stazione
    -- DROP FUNCTION template.f_create_opas_tables(integer);
    CREATE OR REPLACE FUNCTION template.f_create_opas_tables(
        stid integer
    )
      RETURNS boolean
      LANGUAGE 'plpgsql'
      SECURITY DEFINER
      VOLATILE
      COST 100
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
        IF s IN ('client_abr', 'client_ero', 'client_fvg', 'client_tos', 'client_umb') THEN

            q = 'CREATE OR REPLACE TRIGGER '||s||'_'||t||'_99_chk_measure_swam_bi '
                ||'BEFORE INSERT '
                ||'ON '||s||'.'||t||' '
                ||'FOR EACH ROW '
                ||'WHEN (pg_trigger_depth() = 0) '
                ||'EXECUTE FUNCTION clients.f_swam_to_24h_v2('||quote_literal(stid)||'); ';

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

    END IF;


    RETURN TRUE;
    /* errors check */
    EXCEPTION
    WHEN OTHERS THEN /* in case of any error */
        RAISE NOTICE 'ERROR IN template.f_create_opas_tables() : %', SQLERRM ;
        RETURN FALSE;
    END;
    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION template.f_create_opas_tables(integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION template.f_create_opas_tables(integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION template.f_create_opas_tables(integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION template.f_create_opas_tables(integer)
        IS 'Function that dynamically creates station tables and linked triggers';

    -- Funzione che crea la tabella dei dati partendo da un determinato template
    -- DROP FUNCTION template.f_create_table_like_template(integer, text, boolean);
    CREATE OR REPLACE FUNCTION template.f_create_table_like_template(
        st_id         integer,
        template_name text,
        drop          boolean
    )
    RETURNS boolean AS

    $BODY$

    DECLARE
        -- variables
        table_name  text;
        sql_query   text;
    BEGIN
        -- TEST
        -- SELECT template.f_create_table_like_template(1000::integer, 'discarica'::text, true);

        SELECT station_fulltable INTO table_name
        FROM metadata.view_stations_info
        WHERE station_id = st_id;

        IF NOT FOUND THEN
            RAISE NOTICE 'Station % not found!', st_id;
            RETURN NULL;
        END IF;

        RAISE NOTICE 'Table name : %', table_name;

        IF drop IS TRUE THEN
            RAISE NOTICE 'Drop station % if exists!', table_name;
            sql_query = 'DROP TABLE IF EXISTS '|| table_name ||';';
            EXECUTE sql_query;
        END IF;

        sql_query = 'CREATE TABLE '|| table_name ||' (LIKE template.'||quote_ident(template_name)||' INCLUDING ALL);';
        RAISE NOTICE 'Query : %', sql_query;

        EXECUTE sql_query;

        sql_query = 'GRANT ALL ON TABLE     '|| table_name ||' TO group_admin;   '
                ||'GRANT ALL ON TABLE     '|| table_name ||' TO group_bobo;    '
                ||'GRANT ALL ON TABLE     '|| table_name ||' TO group_tools;   '
                ||'GRANT SELECT ON TABLE  '|| table_name ||' TO group_readonly;'
                ||'GRANT INSERT ON TABLE  '|| table_name ||' TO user_swam;';

        RAISE NOTICE 'Add grants';
        EXECUTE sql_query;

        RETURN TRUE;
        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN template.f_create_table_like_template() : %', SQLERRM ;
            RETURN FALSE;
    END;

    $BODY$
    LANGUAGE 'plpgsql'
    VOLATILE
    COST 100;

    -- grants
    GRANT EXECUTE ON FUNCTION template.f_create_table_like_template(integer, text, boolean) TO group_bobo;
    GRANT EXECUTE ON FUNCTION template.f_create_table_like_template(integer, text, boolean) TO group_admin;
    GRANT EXECUTE ON FUNCTION template.f_create_table_like_template(integer, text, boolean) TO group_tools;

    -- comment
    COMMENT ON FUNCTION template.f_create_table_like_template(integer, text, boolean)
        IS 'Function that creates dynamically station table like a predefined template';

-- SCHEMA webservice

    -- DROP SCHEMA IF EXISTS webservice CASCADE;
    CREATE SCHEMA webservice
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA webservice TO group_admin;
    GRANT USAGE ON SCHEMA webservice TO group_tools;
    COMMENT ON SCHEMA webservice IS 'Data schema for webservice utilities in OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Funzione di estrazione dei dati per i vari applicativi del portale
    -- DROP FUNCTION IF EXISTS clients.f_data_extraction(integer, timestamp, timestamp, metadata.e_aggregations, metadata.e_treatments, text);
    CREATE OR REPLACE FUNCTION webservice.f_data_extraction(
        stprid      integer,
        date_from   timestamp without time zone,
        date_to     timestamp without time zone
    )
        RETURNS TABLE (
            measure_date_time   timestamp without time zone,
            measure_id          integer,
            measure_value       numeric,
            measure_perc        smallint,
            measure_min         numeric,
            measure_min_time    time without time zone,
            measure_max         numeric,
            measure_max_time    time without time zone,
            measure_std_dev     numeric,
            measure_code        integer,
            station_code        smallint,
            auto_validity_code  integer,
            post_validity_code  integer,
            final_validity_code smallint,
            extract_code        smallint,
            measure_insert_ts   timestamp without time zone,
            measure_update_obj  jsonb
        )
        LANGUAGE 'plpgsql'

        COST 100
        VOLATILE
        ROWS 1000
    AS $BODY$

    DECLARE
        t text;    -- tablename
        p integer; -- parameter table id
        i integer; -- parameter id
        y integer; -- parameter type (10 = limite)
        q text;    -- dynamic query
    BEGIN
        /* entry */
        RAISE NOTICE 'Function webservice.f_data_extraction, stpr_id: %', stprid;

        /* Testing
            SELECT * FROM  webservice.f_data_extraction (
                38::integer,
                '2024-01-01 00:00'::timestamp,
                '2024-01-31 23:59'::timestamp
            );
        */

        /* get station properties */
        SELECT
            s.station_schema ||'.'|| COALESCE(s.station_prefix, ''::text)||s.station_table,
            sp.stpr_table_id   ,
            pi.pm_info_type_fk  INTO t, p, y
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.parameters_info pi USING (param_id)
        WHERE
            stpr_id = stprid;

        RAISE NOTICE 'Function webservice.f_data_extraction, tablename: %, parame id: %', t, p;

        -- q =
        -- 'WITH m AS ('||E'\n'
        -- ||'    SELECT'||E'\n'
        -- ||'        ('||quote_literal(date_from)||'::timestamp + interval ''60 minute'' * s.a)::timestamp AS measure_date_time'||E'\n'
        -- ||'    FROM'||E'\n'
        -- ||'        generate_series(0,(EXTRACT(EPOCH FROM '||quote_literal(date_to)||'::timestamp'||E'\n'
        -- ||'        - '||quote_literal(date_from)||'::timestamp)/3600)::integer) AS s(a)'||E'\n'
        -- ||')'||E'\n\n';

        /* build main dynamic query */
        /* date time */
        q =
        'SELECT'||E'\n'
        ||'    t.measure_date_time AS measure_date_time,'||E'\n';

        /* measures */
        q = q
            ||'    t.measure_id::integer                                AS measure_id,           '||E'\n'
            ||'    t.measure_value::numeric                             AS measure_value,        '||E'\n'
            ||'    t.measure_perc::smallint                             AS measure_perc,         '||E'\n'
            ||'    t.measure_min::numeric                               AS measure_min,          '||E'\n'
            ||'    t.measure_min_time::time without time zone           AS measure_min_time,     '||E'\n'
            ||'    t.measure_max::numeric                               AS measure_max,          '||E'\n'
            ||'    t.measure_max_time::time without time zone           AS measure_max_time,     '||E'\n'
            ||'    t.measure_std_dev::numeric                           AS measure_std_dev,      '||E'\n'
            ||'    t.measure_code::integer                              AS measure_code,         '||E'\n'
            ||'    t.station_code::smallint                             AS station_code,         '||E'\n'
            ||'    t.auto_validity_code::integer                        AS auto_validity_code,   '||E'\n'
            ||'    t.post_validity_code::integer                        AS post_validity_code,   '||E'\n'
            ||'    t.final_validity_code::smallint                      AS final_validity_code,  '||E'\n'
            ||'    t.extract_code::smallint                             AS extract_code ,        '||E'\n'
            ||'    t.measure_insert_ts::timestamp without time zone     AS measure_insert_ts ,   '||E'\n'
            ||'    t.measure_update_obj::jsonb                          AS measure_update_obj    '||E'\n';

        /* from clause */
        q = q
        ||'FROM'||E'\n'
        ||'    '||t||' t '||E'\n'
        ||'WHERE'||E'\n'
        ||'    t.measure_id = '||p||''||E'\n'
        ||'    AND t.measure_date_time BETWEEN '||quote_literal(date_from)||' AND '||quote_literal(date_to)||''||E'\n';

        /* order by */
        q = q
        ||'ORDER BY'||E'\n'
        ||'    measure_date_time'||E'\n';


        /* notice */
        RAISE NOTICE 'Query: %', E'\n'||q;

        /* return value */
        RETURN QUERY EXECUTE q;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR webservice.f_data_extraction(): %', SQLERRM;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION webservice.f_data_extraction(integer, timestamp, timestamp) TO group_admin;
    GRANT EXECUTE ON FUNCTION webservice.f_data_extraction(integer, timestamp, timestamp) TO group_tools;

    -- comment
    COMMENT ON FUNCTION webservice.f_data_extraction(integer, timestamp, timestamp)
        IS 'Generic data extraction function for WEBSERVICE';

        CREATE OR REPLACE FUNCTION webservice.f_data_extraction_v2(
        stprid integer,
        date_from timestamp without time zone,
        date_to timestamp without time zone,
        aggregation metadata.e_aggregations DEFAULT 'hh'::metadata.e_aggregations
    )
        RETURNS TABLE (
            measure_date_time   timestamp without time zone,
            measure_id          integer,
            measure_value       numeric,
            measure_perc        smallint,
            measure_min         numeric,
            measure_min_time    time without time zone,
            measure_max         numeric,
            measure_max_time    time without time zone,
            measure_std_dev     numeric,
            measure_code        integer,
            station_code        smallint,
            auto_validity_code  integer,
            post_validity_code  integer,
            final_validity_code smallint,
            extract_code        smallint,
            measure_insert_ts   timestamp without time zone,
            measure_update_obj  jsonb
        )
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
        ROWS 1000

    AS $BODY$
        DECLARE
            t text;                     -- tablename
            p integer;                  -- parameter table id
            d integer;                  -- parameter decimals
            o metadata.e_treatments;    -- parameter treatment
            q text;                     -- dynamic query
        BEGIN

            /* entry */
            -- RAISE NOTICE 'Function webservice.f_data_extraction_v2, stpr_id: %', stprid;

            /* Testing
                SELECT * FROM  webservice.f_data_extraction_v2 (
                    38::integer,
                    '2024-01-01 00:00'::timestamp,
                    '2024-01-31 23:59'::timestamp,
                    'dd'
                );
            */

            /* get station properties */
            SELECT
                s.station_schema ||'.'|| COALESCE(s.station_prefix, ''::text)||s.station_table,
                sp.stpr_table_id   ,
                COALESCE(pi.pm_info_obj ->'general'->>'treatment', 'avg'),
                5  INTO t, p, o, d
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.stations s USING (station_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
            WHERE
                stpr_id = stprid;

            -- RAISE NOTICE 'Function webservice.f_data_extraction, tablename: %, parame id: %', t, p;

            /* build main dynamic query */
            CASE
                WHEN aggregation = 'hh'::metadata.e_aggregations THEN
                    q =
                    'SELECT'||E'\n'
                    ||'    t.measure_date_time AS measure_date_time,'||E'\n';

                    /* measures */
                    q = q
                        ||'    t.measure_id::integer                                AS measure_id,           '||E'\n'
                        ||'    t.measure_value::numeric                             AS measure_value,        '||E'\n'
                        ||'    t.measure_perc::smallint                             AS measure_perc,         '||E'\n'
                        ||'    t.measure_min::numeric                               AS measure_min,          '||E'\n'
                        ||'    t.measure_min_time::time without time zone           AS measure_min_time,     '||E'\n'
                        ||'    t.measure_max::numeric                               AS measure_max,          '||E'\n'
                        ||'    t.measure_max_time::time without time zone           AS measure_max_time,     '||E'\n'
                        ||'    t.measure_std_dev::numeric                           AS measure_std_dev,      '||E'\n'
                        ||'    t.measure_code::integer                              AS measure_code,         '||E'\n'
                        ||'    t.station_code::smallint                             AS station_code,         '||E'\n'
                        ||'    t.auto_validity_code::integer                        AS auto_validity_code,   '||E'\n'
                        ||'    t.post_validity_code::integer                        AS post_validity_code,   '||E'\n'
                        ||'    t.final_validity_code::smallint                      AS final_validity_code,  '||E'\n'
                        ||'    t.extract_code::smallint                             AS extract_code ,        '||E'\n'
                        ||'    t.measure_insert_ts::timestamp without time zone     AS measure_insert_ts ,   '||E'\n'
                        ||'    t.measure_update_obj::jsonb                          AS measure_update_obj    '||E'\n';

                    /* from clause */
                    q = q
                    ||'FROM'||E'\n'
                    ||'    '||t||' t '||E'\n'
                    ||'WHERE'||E'\n'
                    ||'    t.measure_id = '||p||''||E'\n'
                    ||'    AND t.measure_date_time BETWEEN '||quote_literal(date_from)||' AND '||quote_literal(date_to)||''||E'\n';

                    /* order by */
                    q = q
                    ||'ORDER BY'||E'\n'
                    ||'    measure_date_time'||E'\n';

                WHEN aggregation = 'dd'::metadata.e_aggregations THEN

                    /** 
                     * build temporary tables 
                     *  - main table with series of hours
                     *  - data table with aggregated values
                     */
                    q =
                    'WITH m AS ('||E'\n'
                    ||'    SELECT'||E'\n'
                    ||'        ('||quote_literal(date_from)||'::timestamp + interval ''60 minute'' * s.a)::timestamp AS measure_date_time'||E'\n'
                    ||'    FROM'||E'\n'
                    ||'        generate_series(0,(EXTRACT(EPOCH FROM '||quote_literal(date_to)||'::timestamp'||E'\n'
                    ||'        - '||quote_literal(date_from)||'::timestamp)/3600)::integer) AS s(a)'||E'\n'
                    ||'),'||E'\n'
                    ||'d AS ('||E'\n'
                    ||'    SELECT'||E'\n'
                    ||'        DATE_TRUNC( ''day'', m.measure_date_time )   AS measure_date_time,'||E'\n'
                    ||'        MAX( t.measure_id::integer )                 AS measure_id,'||E'\n'
                    ||'        ROUND( '||o||'( CASE WHEN t.post_validity_code >= 0 THEN t.measure_value::numeric END ), '||d||' ) AS measure_value,'||E'\n'
                    ||'        ( SUM( CASE WHEN t.measure_value NOTNULL AND t.post_validity_code >= 0 THEN t.extract_code ELSE 0::smallint END )/24::real*100 )::smallint AS measure_perc,'||E'\n'
                    ||'        ROUND( MIN( CASE WHEN t.post_validity_code >= 0 THEN t.measure_min::numeric END), '||d||')   AS measure_min,'||E'\n'
                    ||'        DATE_TRUNC(''day'', m.measure_date_time)::time without time zone                             AS measure_min_time,'||E'\n'
                    ||'        ROUND( MAX(CASE WHEN t.post_validity_code >= 0 THEN t.measure_max::numeric END), '||d||')    AS measure_max,'||E'\n'
                    ||'        DATE_TRUNC(''day'', m.measure_date_time)::time without time zone                               AS measure_max_time'||E'\n'
                    ||'    FROM'||E'\n'
                    ||'        m LEFT JOIN '||t||' t ON (m.measure_date_time = t.measure_date_time AND t.measure_id = '||p||')'||E'\n'
                    ||'    WHERE'||E'\n'
                    ||'        m.measure_date_time BETWEEN '||quote_literal(date_from)||' AND '||quote_literal(date_to)||''||E'\n'
                    ||'    GROUP BY 1'||E'\n'
                    ||'    ORDER BY 1'||E'\n'
                    ||')'||E'\n';

                    /* last extraction with data manipulation */
                    q = q
                    ||'SELECT'||E'\n'
                    ||'    d.measure_date_time,'||E'\n'
                    ||'    d.measure_id,'||E'\n'
                    ||'    d.measure_value,'||E'\n'
                    ||'    d.measure_perc,'||E'\n'
                    ||'    d.measure_min,'||E'\n'
                    ||'    d.measure_min_time,'||E'\n'
                    ||'    d.measure_max,'||E'\n'
                    ||'    d.measure_max_time,'||E'\n'
                    ||'    NULL::numeric        AS measure_std_dev,'||E'\n'
                    ||'    NULL::integer        AS measure_code,'||E'\n'
                    ||'    NULL::smallint       AS station_code,'||E'\n'
                    ||'    NULL::integer        AS auto_validity_code,'||E'\n'
                    ||'    CASE '||E'\n'
                    ||'        WHEN d.measure_perc >= 75 THEN 0::integer'||E'\n' -- valido di default
                    ||'        ELSE -16::integer'||E'\n' -- numero letture insufficiente
                    ||'    END                  AS post_validity_code,'||E'\n'
                    ||'    NULL::smallint       AS final_validity_code,'||E'\n'
                    ||'    NULL::smallint       AS extract_code,'||E'\n'
                    ||'    NULL::timestamp without time zone        AS measure_insert_ts,'||E'\n'
                    ||'    NULL::jsonb          AS measure_update_obj'||E'\n'
                    ||'FROM'||E'\n'
                    ||'    d'||E'\n'
                    ||'WHERE'||E'\n'
                    ||'    d.measure_value NOTNULL'||E'\n'
                    ||'ORDER BY 1;'||E'\n';

                ELSE
                    /* Do nothing */
            END CASE; 

            /* notice */
            RAISE NOTICE 'Query: %', E'\n'||q;

            /* return value */
            RETURN QUERY EXECUTE q;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR webservice.f_data_extraction_v2(): %', SQLERRM;
        END;
        
    $BODY$;


    GRANT EXECUTE ON FUNCTION webservice.f_data_extraction_v2(integer, timestamp without time zone, timestamp without time zone, metadata.e_aggregations) TO group_admin;
    GRANT EXECUTE ON FUNCTION webservice.f_data_extraction_v2(integer, timestamp without time zone, timestamp without time zone, metadata.e_aggregations) TO group_tools;

    COMMENT ON FUNCTION webservice.f_data_extraction_v2(integer, timestamp without time zone, timestamp without time zone, metadata.e_aggregations) 
        IS 'Generic data extraction function for WEBSERVICE v2.0';


    -- Funzione di estrazione degli ultimi dati modificati per il webservice del portale
    -- DROP FUNCTION IF EXISTS webservice.f_last_edited_data_extraction(integer, timestamp);
    CREATE OR REPLACE FUNCTION webservice.f_last_edited_data_extraction(
        stprid      integer,
        date_from   timestamp without time zone
    )
        RETURNS TABLE (
            measure_date_time   timestamp without time zone,
            measure_id          integer,
            measure_value       numeric,
            measure_perc        smallint,
            measure_min         numeric,
            measure_min_time    time without time zone,
            measure_max         numeric,
            measure_max_time    time without time zone,
            measure_std_dev     numeric,
            measure_code        integer,
            station_code        smallint,
            auto_validity_code  integer,
            post_validity_code  integer,
            final_validity_code smallint,
            extract_code        smallint,
            measure_insert_ts   timestamp without time zone,
            measure_update_ts   timestamp without time zone,
            measure_update_obj  jsonb
        )
        LANGUAGE 'plpgsql'

        COST 100
        VOLATILE
        ROWS 1000
    AS $BODY$

    DECLARE
        t text;    -- tablename
        p integer; -- parameter table id
        i integer; -- parameter id
        y integer; -- parameter type (10 = limite)
        q text;    -- dynamic query
    BEGIN
        /* entry */
        --RAISE NOTICE 'Function webservice.f_last_edited_data_extraction, stpr_id: %', stprid;

        /* Testing
            SELECT * FROM  webservice.f_last_edited_data_extraction (
                38::integer,
                '2024-04-20 00:00'::timestamp
            );
        */

        /* get station properties */
        SELECT
            s.station_schema ||'.'|| COALESCE(s.station_prefix, ''::text)||s.station_table,
            sp.stpr_table_id   ,
            pi.pm_info_type_fk  INTO t, p, y
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.parameters_info pi USING (param_id)
        WHERE
            stpr_id = stprid;

        --RAISE NOTICE 'Function webservice.f_last_edited_data_extraction, tablename: %, param id: %', t, p;

        /* build main dynamic query */
        /* get */
        q =
        'WITH t AS('||E'\n'
        ||'    SELECT'||E'\n'
        ||'         t.measure_date_time                             ,       '||E'\n'
        ||'         t.measure_id::integer                           ,       '||E'\n'
        ||'         t.measure_value::numeric                        ,       '||E'\n'
        ||'         t.measure_perc::smallint                        ,       '||E'\n'
        ||'         t.measure_min::numeric                          ,       '||E'\n'
        ||'         t.measure_min_time::time without time zone      ,       '||E'\n'
        ||'         t.measure_max::numeric                          ,       '||E'\n'
        ||'         t.measure_max_time::time without time zone      ,       '||E'\n'
        ||'         t.measure_std_dev::numeric                      ,       '||E'\n'
        ||'         t.measure_code::integer                         ,       '||E'\n'
        ||'         t.station_code::smallint                        ,       '||E'\n'
        ||'         t.auto_validity_code::integer                   ,       '||E'\n'
        ||'         t.post_validity_code::integer                   ,       '||E'\n'
        ||'         t.final_validity_code::smallint                 ,       '||E'\n'
        ||'         t.extract_code::smallint                        ,       '||E'\n'
        ||'         t.measure_insert_ts::timestamp without time zone,       '||E'\n'
        ||'         ('||E'\n'
        ||'                SELECT'||E'\n'
        ||'                    user_action->>''d'' '||E'\n'
        ||'                FROM '||E'\n'
        ||'                    ( SELECT jsonb_array_elements(t.measure_update_obj) AS user_action )'||E'\n'
        ||'                ORDER BY user_action->''d'' DESC'||E'\n'
        ||'                LIMIT 1'||E'\n'
        ||'         )::timestamp without time zone AS measure_update_ts,    '||E'\n'
        ||'         t.measure_update_obj::jsonb                             '||E'\n'
        ||'    FROM'||E'\n'
        ||'        '||t||' t'||E'\n'
        ||'    WHERE'||E'\n'
        ||'        t.measure_id = '||p||''||E'\n'
        ||'        AND COALESCE('||E'\n'
        ||'            ('||E'\n'
        ||'                SELECT'||E'\n'
        ||'                    user_action->>''d'' '||E'\n'
        ||'                FROM '||E'\n'
        ||'                    ( SELECT jsonb_array_elements(t.measure_update_obj) AS user_action )'||E'\n'
        ||'                ORDER BY user_action->''d'' DESC'||E'\n'
        ||'                LIMIT 1'||E'\n'
        ||'            )::timestamp, measure_insert_ts'||E'\n'
        ||'         )   >= '||quote_literal(date_from)||' '||E'\n'
        ||')'||E'\n'
        ||'SELECT'||E'\n'
        ||'    t.measure_date_time          AS measure_date_time,    '||E'\n'
        ||'    t.measure_id                 AS measure_id,           '||E'\n'
        ||'    t.measure_value              AS measure_value,        '||E'\n'
        ||'    t.measure_perc               AS measure_perc,         '||E'\n'
        ||'    t.measure_min                AS measure_min,          '||E'\n'
        ||'    t.measure_min_time           AS measure_min_time,     '||E'\n'
        ||'    t.measure_max                AS measure_max,          '||E'\n'
        ||'    t.measure_max_time           AS measure_max_time,     '||E'\n'
        ||'    t.measure_std_dev            AS measure_std_dev,      '||E'\n'
        ||'    t.measure_code               AS measure_code,         '||E'\n'
        ||'    t.station_code               AS station_code,         '||E'\n'
        ||'    t.auto_validity_code         AS auto_validity_code,   '||E'\n'
        ||'    t.post_validity_code         AS post_validity_code,   '||E'\n'
        ||'    t.final_validity_code        AS final_validity_code,  '||E'\n'
        ||'    t.extract_code               AS extract_code ,        '||E'\n'
        ||'    t.measure_insert_ts          AS measure_insert_ts ,   '||E'\n'
        ||'    t.measure_update_ts          AS measure_update_ts ,   '||E'\n'
        ||'    t.measure_update_obj         AS measure_update_obj    '||E'\n';

        /* from and order by clause */
        q = q
        ||'FROM'||E'\n'
        ||'    t '||E'\n'
        ||'ORDER BY'||E'\n'
        ||'    measure_date_time;'||E'\n';

        /* notice */
        -- RAISE NOTICE 'Query: %', E'\n'||q;

        /* return value */
        RETURN QUERY EXECUTE q;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR webservice.f_last_edited_data_extraction(): %', SQLERRM;
    END;

    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION webservice.f_last_edited_data_extraction(integer, timestamp) TO group_admin;
    GRANT EXECUTE ON FUNCTION webservice.f_last_edited_data_extraction(integer, timestamp) TO group_tools;

    -- comment
    COMMENT ON FUNCTION webservice.f_last_edited_data_extraction(integer, timestamp)
        IS 'Generic function for the extraction of last edited data for WEBSERVICE';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- organization
    -- DROP VIEW IF EXISTS webservice.v1_organization;
    CREATE OR REPLACE VIEW webservice.v1_organization AS
    SELECT
        'OPen Air System (OPAS)'::text                                               AS creator_organization,
        'Ispra'::text                                                                AS point_of_contact_organization,
        (
            'You agree that you will: • Take all reasonable steps to protect against unauthorized access to, use of, and disclosure of the Data and the Password. • Write the content yourself, or copy it from a public domain or similar free resource • NOT SUBMIT COPYRIGHTED WORK WITHOUT PERMISSION'
        )::text                                                                      AS conditions_for_access_and_use,
        'There are no limitations on public access to data sets and services.'::text AS limitations_on_public_access;

    -- grants
    GRANT ALL ON TABLE webservice.v1_organization TO group_admin;
    GRANT ALL ON TABLE webservice.v1_organization TO group_tools;

    -- comment
    COMMENT ON VIEW webservice.v1_organization IS 'The view contains all the principal info, used by the web service, about the organization';

    -- parameters
    -- DROP VIEW IF EXISTS webservice.v1_parameters;
    CREATE OR REPLACE VIEW webservice.v1_parameters AS
    SELECT
        p.param_id                                                                                              AS id,
        p.param_name                                                                                            AS name,
        p.param_unit                                                                                            AS unit,
        metadata.f_get_conversion_by_date_prid(p.param_id, CURRENT_TIMESTAMP::timestamp without time zone)      AS conversion_factor_curr,
        (
            SELECT to_json(ARRAY_AGG(row_to_json(j)))
            FROM (
                SELECT
                    ROW_NUMBER() OVER(ORDER BY pc.pc_from_fulldate) AS index,
                    pc.pc_conv                                      AS value,
                    pc.pc_from_fulldate                             AS date_from,
                    pc.pc_to_fulldate                               AS date_to
                FROM
                    metadata.parameters_conversions pc
                WHERE
                    p.param_id = pc.param_id
                ORDER BY
                    pc.pc_from_fulldate
            ) j
        )                                                                                                       AS conversion_history,
        p.param_unit_conv                                                                                       AS conversion_unit,
        p.param_offset                                                                                          AS offset,
        p.param_decimals                                                                                        AS decimals,
        p.param_active                                                                                          AS active,
        p.param_note                                                                                            AS note,
        -- p.param_ext_id                                                                                          AS external_id,
        -- pp.pollutant_id                                                                                         AS pollutant_id,
        -- pi.pm_info_shortname                                                                                    AS shortname,
        -- pi.pm_info_extra_shortname                                                                              AS extra_shortname,
        pi.pm_info_type_fk                                                                                      AS type_id,
        pt.pm_type_desc                                                                                         AS type_desc,
        COALESCE((pi.pm_info_obj -> 'general'::text) ->> 'treatment'::text, 'avg'::text)::metadata.e_treatments AS treatment,
        (((pi.pm_info_obj -> 'aggregation'::text) -> 'hh'::text) ->> 'enabled'::text)::boolean                  AS aggr_hh_enabled,
        ((pi.pm_info_obj -> 'aggregation'::text) -> 'hh'::text) ->> 'perc_valid'::text                          AS aggr_hh_perc,
        (((pi.pm_info_obj -> 'aggregation'::text) -> 'dd'::text) ->> 'enabled'::text)::boolean                  AS aggr_dd_enabled,
        ((pi.pm_info_obj -> 'aggregation'::text) -> 'dd'::text) ->> 'perc_valid'::text                          AS aggr_dd_perc,
        (((pi.pm_info_obj -> 'aggregation'::text) -> 'mm'::text) ->> 'enabled'::text)::boolean                  AS aggr_mm_enabled,
        ((pi.pm_info_obj -> 'aggregation'::text) -> 'mm'::text) ->> 'perc_valid'::text                          AS aggr_mm_perc,
        (((pi.pm_info_obj -> 'aggregation'::text) -> 'yy'::text) ->> 'enabled'::text)::boolean                  AS aggr_yy_enabled,
        ((pi.pm_info_obj -> 'aggregation'::text) -> 'yy'::text) ->> 'perc_valid'::text                          AS aggr_yy_perc,
        pi.pm_info_note                                                                                         AS info_note
    FROM
        metadata.parameters p
        LEFT JOIN metadata.parameters_info pi USING (param_id)
        LEFT JOIN metadata.parameters_type pt ON pi.pm_info_type_fk = pt.pm_type_id
        -- LEFT JOIN infoaria.params_pollutant pp USING (param_id)
    ORDER BY
        p.param_id;

    -- grants
    GRANT ALL ON TABLE webservice.v1_parameters TO group_admin;
    GRANT ALL ON TABLE webservice.v1_parameters TO group_tools;

    -- comment
    COMMENT ON VIEW webservice.v1_parameters IS 'The view contains all the principal info, used by the web service, about parameters';

    -- data series
    -- DROP VIEW IF EXISTS webservice.v1_series;
    CREATE OR REPLACE VIEW webservice.v1_series AS
    SELECT
        sp.stpr_id                                    AS series_id,
        CONCAT_WS(' - ', pp.param_name, sp.stpr_note) AS series_name,
        sp.stpr_table_id                              AS database_id,
        st.station_id                                 AS station_id,
        st.station_ext_id                             AS station_external_id,
        st.station_name                               AS station_name,
        st.station_active                             AS station_active,
        pp.param_id                                   AS parameter_id,
        sp.stpr_ext_id                                AS parameter_external_id,
        pp.param_name                                 AS parameter_name,
        pp.param_active                               AS parameter_active,
        pp.param_unit                                 AS parameter_unit,
        metadata.f_get_conversion_by_date_prid(pp.param_id, CURRENT_TIMESTAMP::timestamp without time zone)           AS parameter_conv_curr,
        (
            SELECT to_json(ARRAY_AGG(row_to_json(j)))
            FROM (
                SELECT
                    ROW_NUMBER() OVER(ORDER BY pc.pc_from_fulldate) AS index,
                    pc.pc_conv                                      AS value,
                    pc.pc_from_fulldate                             AS date_from,
                    pc.pc_to_fulldate                               AS date_to
                FROM
                    metadata.parameters_conversions pc
                WHERE
                    pp.param_id = pc.param_id
                ORDER BY
                    pc.pc_from_fulldate
            ) j
        )                                             AS parameter_conv_history,
        pp.param_unit_conv                            AS parameter_conv_unit,
        pp.param_decimals                             AS parameter_decimals,
        -- pm.pm_info_type_fk                            AS parameter_type_id,
        pt.pm_type_desc                               AS parameter_type_desc,
        pp.param_note                                 AS parameter_note,
        sp.stpr_active                                AS station_param_active,
        sp.stpr_note                                  AS station_param_note,
        r.region_istat_code                           AS region_istat_code,
        r.region_name                                 AS region_name
    FROM
        metadata.stations st
        LEFT JOIN metadata.stations_municipality stm USING (station_id)
        LEFT JOIN main.province_municipalities prm USING (mu_id)
        LEFT JOIN main.region_provinces rp USING (province_id)
        LEFT JOIN main.regions r USING (region_id)
        LEFT JOIN metadata.stations_parameters sp USING (station_id)
        LEFT JOIN metadata.parameters pp USING (param_id)
        LEFT JOIN metadata.parameters_info pm USING (param_id)
        LEFT JOIN metadata.parameters_type pt ON pm.pm_info_type_fk = pt.pm_type_id
    ORDER BY
        st.station_id, sp.stpr_table_id;

    -- grants
    GRANT ALL ON TABLE webservice.v1_series TO group_admin;
    GRANT ALL ON TABLE webservice.v1_series TO group_tools;

    -- comment
    COMMENT ON VIEW webservice.v1_series IS 'The view contains all the principal info, used by the web service, about data series';

    -- sites
    -- DROP VIEW IF EXISTS webservice.v1_sites;
    CREATE OR REPLACE VIEW webservice.v1_sites AS
    SELECT
        s.site_id                   AS id,
        s.site_name                 AS name,
        -- s.network_types             AS network_types,
        ARRAY(
            SELECT stations_network_type.st_network_name
            FROM metadata.stations_network_type
            WHERE stations_network_type.st_network_id = ANY (s.network_types)
        )                           AS network_names,
        -- s.mu_id                     AS municipality_id,
        m.mu_name                   AS municipality_name,
        -- p.province_id               AS province_id,
        p.province_name             AS province_name,
        -- r.region_id                 AS region_id,
        r.region_name               AS region_name,
        s.site_locality             AS locality,
        s.site_altitude             AS altitude,
        s.site_wgs84_lat            AS wgs84_lat,
        s.site_wgs84_lon            AS wgs84_lon,
        s.site_note                 AS note
    FROM
        metadata.sites s
        LEFT JOIN main.municipalities m USING (mu_id)
        LEFT JOIN main.province_municipalities pm USING (mu_id)
        LEFT JOIN main.provinces p USING (province_id)
        LEFT JOIN main.region_provinces rp USING (province_id)
        LEFT JOIN main.regions r USING (region_id)
    ORDER BY
        s.site_id;

    -- grants
    GRANT ALL ON TABLE webservice.v1_sites TO group_admin;
    GRANT ALL ON TABLE webservice.v1_sites TO group_tools;

    -- comment
    COMMENT ON VIEW webservice.v1_sites IS 'The view contains all the principal info, used by the web service, about sites';

    -- campaigns
    -- DROP VIEW IF EXISTS webservice.v1_sites_allocations;
    CREATE OR REPLACE VIEW webservice.v1_sites_allocations AS
    SELECT
        -- ss.stsi_id                                                                                      AS stsi_id,
        ss.station_id                                                                                   AS station_id,
        st.station_name                                                                                 AS station_name,
        -- ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS station_fulltable,
        ss.station_override_id                                                                          AS station_override_id,
        st2.station_ext_id                                                                              AS station_external_id,
        ss.site_id                                                                                      AS site_id,
        s.site_name                                                                                     AS site_name,
        -- s.network_types                                                                                 AS network_types,
        ARRAY(
            SELECT stations_network_type.st_network_name
            FROM metadata.stations_network_type
            WHERE stations_network_type.st_network_id = ANY (s.network_types)
        )                                                                                               AS network_names,
        -- s.mu_id                                                                                         AS municipality_id,
        s.site_locality                                                                                 AS site_locality,
        s.site_altitude                                                                                 AS site_altitude,
        s.site_wgs84_lat                                                                                AS site_wgs84_lat,
        s.site_wgs84_lon                                                                                AS site_wgs84_lon,
        s.site_note                                                                                     AS site_note,
        ss.stsi_startup_date                                                                            AS allocation_startup_date,
        ss.stsi_dismiss_date                                                                            AS allocation_dismiss_date,
        ss.stsi_note                                                                                    AS allocation_note,
        ss.camp_id                                                                                      AS campaign_id,
        c.camp_name                                                                                     AS campaign_name
    FROM
        metadata.stations_sites ss
        LEFT JOIN metadata.stations st USING (station_id)
        LEFT JOIN metadata.sites s USING (site_id)
        LEFT JOIN metadata.campaigns c USING (camp_id)
        LEFT JOIN metadata.stations st2 ON (ss.station_override_id = st2.station_id)
    ORDER BY
        ss.site_id, ss.stsi_startup_date;

    -- grants
    GRANT ALL ON TABLE webservice.v1_sites_allocations TO group_admin;
    GRANT ALL ON TABLE webservice.v1_sites_allocations TO group_tools;

    -- comment
    COMMENT ON VIEW webservice.v1_sites_allocations IS 'The view contains all the principal info, used by the web service, about sites allocations';

    -- stations
    -- DROP VIEW IF EXISTS webservice.v1_stations;
    CREATE OR REPLACE VIEW webservice.v1_stations AS
        SELECT
             st.station_id                                                                                   AS id,
            st.station_name                                                                                 AS name,
            -- st.station_schema                                                                               AS schema,
            -- st.station_table                                                                                AS table,
            -- st.station_prefix                                                                               AS prefix,
            -- ((st.station_schema || '.'::text) || COALESCE(st.station_prefix, ''::text)) || st.station_table AS fulltable,
            st.station_active                                                                               AS active,
            st.station_note                                                                                 AS note,
            st.station_ext_id                                                                               AS external_id,
            -- st.station_file_header                                                                          AS file_header,
            -- st.station_remote_ctrl                                                                          AS remote_ctrl,
            -- sm.st_info_shortname                                                                            AS shortname,
            -- sm.st_info_longname                                                                             AS longname,
            sm.st_info_startup_date                                                                         AS startup_date,
            sm.st_info_dismiss_date                                                                         AS dismiss_date,
            -- sm.st_info_basepath                                                                             AS base_path,
            -- (sm.st_info_basepath || '/'::text) || st.station_id                                             AS media_path,
            r.region_istat_code                                                                             AS region_istat_code,
            r.region_name                                                                                   AS region_name,
            sm.st_info_locality                                                                             AS locality,
            sm.st_info_zone                                                                                 AS zone,
            sm.st_info_basin                                                                                AS basin,
            sm.st_info_community                                                                            AS community,
            sm.st_info_north_utm                                                                            AS north_utm,
            sm.st_info_east_utm                                                                             AS east_utm,
            sm.st_info_altitude                                                                             AS altitude,
            sm.st_info_lat_wgs84                                                                            AS lat_wgs84,
            sm.st_info_lon_wgs84                                                                            AS lon_wgs84,
            sm.st_info_national_code                                                                        AS national_code,
            -- sm.st_info_network_type_fk                                                                      AS network_type_id,
            snt.st_network_desc                                                                             AS network_type_desc,
            snt.st_network_name                                                                             AS network_type_name,
            -- snt.st_network_logo                                                                             AS network_type_logo,
            -- sm.st_info_roaming_type_fk                                                                      AS roaming_type_id,
            srt.st_roaming_desc                                                                             AS roaming_type_desc,
            -- sm.st_info_typology_fk                                                                          AS typology_id,
            stt.st_typology_desc                                                                            AS typology_desc,
            -- sm.st_info_measure_fk                                                                           AS measure_type_id,
            mt.measure_type_desc                                                                            AS measure_type_desc,
            -- sm.st_info_cadence_fk                                                                           AS cadence_type_id,
            mc.measure_cadence_desc                                                                         AS cadence_type_desc,
            mc.measure_cadence_min                                                                          AS cadence_type_min,
            -- mc.measure_cadence_db                                                                           AS cadence_type_db,
            sm.st_info_note                                                                                 AS metadata_note,
            sm.st_info_export_id                                                                            AS export_id,
            sm.st_info_ws_name                                                                              AS ws_name
            -- sm.st_info_import_ws_id                                                                         AS import_ws_id
        FROM
            metadata.stations st
            LEFT JOIN metadata.stations_info sm USING (station_id)
            LEFT JOIN metadata.stations_municipality stm USING (station_id)
            LEFT JOIN main.province_municipalities pm USING (mu_id)
            LEFT JOIN main.region_provinces rp USING (province_id)
            LEFT JOIN main.regions r USING (region_id)
            LEFT JOIN metadata.stations_network_type snt ON snt.st_network_id = sm.st_info_network_type_fk
            LEFT JOIN metadata.stations_roaming_type srt ON srt.st_roaming_id = sm.st_info_roaming_type_fk
            LEFT JOIN metadata.stations_typology stt ON stt.st_typology_id = sm.st_info_typology_fk
            LEFT JOIN metadata.measures_type mt ON mt.measure_type_id = sm.st_info_measure_fk
            LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = sm.st_info_cadence_fk
        WHERE
            sm.st_info_roaming_type_fk IN (1,2) -- stazioni fisse e mobili
        ORDER BY
            st.station_id;

    -- grants
    GRANT ALL ON TABLE webservice.v1_stations TO group_admin;
    GRANT ALL ON TABLE webservice.v1_stations TO group_tools;

    -- comment
    COMMENT ON VIEW webservice.v1_stations IS 'The view contains all the principal info, used by the web service, about fixed and mobile stations';

-- SCHEMA geodata

    -- DROP SCHEMA IF EXISTS geodata CASCADE;
    CREATE SCHEMA geodata
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA geodata TO group_admin;
    GRANT USAGE ON SCHEMA geodata TO group_bobo;
    GRANT USAGE ON SCHEMA geodata TO group_readonly;
    GRANT USAGE ON SCHEMA geodata TO group_tools;
    COMMENT ON SCHEMA geodata IS 'Geografic data schema for OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- Tabella di supporto
    -- DROP TABLE IF EXISTS geodata.comuni;
    CREATE TABLE IF NOT EXISTS geodata.comuni
    (
        gid        serial,
        cod_rip    double precision,
        cod_reg    double precision,
        cod_prov   double precision,
        cod_cm     double precision,
        cod_uts    double precision,
        pro_com    double precision,
        pro_com_t  character varying(6) COLLATE pg_catalog."default",
        comune     character varying(100) COLLATE pg_catalog."default",
        comune_a   character varying(100) COLLATE pg_catalog."default",
        cc_uts     double precision,
        shape_leng numeric,
        shape_area numeric,
        geom       geometry(MultiPolygon,4326),

        CONSTRAINT comuni_pkey PRIMARY KEY (gid)
    )
    TABLESPACE pg_default;

    -- grants
    ALTER TABLE IF EXISTS geodata.comuni OWNER to user_admin;
    GRANT ALL ON TABLE    geodata.comuni TO group_admin;
    GRANT ALL ON TABLE    geodata.comuni TO group_bobo;
    GRANT SELECT ON TABLE geodata.comuni TO group_readonly;
    GRANT ALL ON TABLE    geodata.comuni TO group_tools;
    GRANT ALL ON TABLE    geodata.comuni TO user_admin;

        -- DROP INDEX IF EXISTS geodata.geodata_comuni_geom_idx;
    CREATE INDEX IF NOT EXISTS geodata_comuni_geom_idx
        ON geodata.comuni USING gist
        (geom)
        TABLESPACE pg_default;

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- Funzione che recupera, date le coordinate geografiche, il nome del relativo comune
    -- DROP FUNCTION IF EXISTS clients.f_get_comune_lonlat(float, float);
    CREATE OR REPLACE FUNCTION clients.f_get_comune_lonlat(lon float, lat float)
        RETURNS character varying
        LANGUAGE 'sql'
        COST 100
        VOLATILE PARALLEL UNSAFE
    AS $BODY$
        /*
            SELECT clients.f_get_comune_lonlat(7.32372, 45.7369);
            SELECT * from clients.f_get_comune_lonlat(10.966358, 44.68779);
        */

        /* reference
            https://postgis.net/docs/ST_Point.html
            https://postgis.net/docs/ST_SetSRID.html
            https://postgis.net/docs/ST_Transform.html

            ST_Point(float x, float y, integer srid=unknown);
            or geodetic coordinates, X is longitude and Y is latitude
        */

        SELECT
            pro_com_t
        FROM
            geodata.comuni
        WHERE
            st_contains(
                geom,
                ST_SetSRID(ST_Point(lon, lat), 4326)
            ) IS true
    $BODY$;

    -- grants
    ALTER FUNCTION clients.f_get_comune_lonlat(lon float, lat float) OWNER TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_get_comune_lonlat(lon float, lat float) TO group_admin;
    GRANT EXECUTE ON FUNCTION clients.f_get_comune_lonlat(lon float, lat float) TO group_bobo;
    GRANT EXECUTE ON FUNCTION clients.f_get_comune_lonlat(lon float, lat float) TO group_tools;
    GRANT EXECUTE ON FUNCTION clients.f_get_comune_lonlat(lon float, lat float) TO group_readonly;

    -- comments
    COMMENT ON FUNCTION clients.f_get_comune_lonlat(double precision, double precision)
        IS 'Get commune code pro+com from X,Y coordinates, X is longitude and Y is latitude';

-- SCHEMA client_lig_alims

    -- DROP SCHEMA IF EXISTS client_lig_alims CASCADE;
    CREATE SCHEMA client_lig_alims
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA client_lig_alims TO group_admin;
    GRANT USAGE ON SCHEMA client_lig_alims TO group_bobo;
    GRANT USAGE ON SCHEMA client_lig_alims TO group_readonly;
    GRANT USAGE ON SCHEMA client_lig_alims TO group_tools;
    COMMENT ON SCHEMA client_lig_alims IS 'Alims schema for ARPA Liguria in OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- DROP TABLE IF EXISTS client_lig_alims.analytics;
    CREATE TABLE client_lig_alims.analytics (
        ana_id     integer NOT NULL,
        ana_desc   text NOT NULL,
        ana_active boolean DEFAULT TRUE,

        CONSTRAINT client_lig_alims_analytics_pkey PRIMARY KEY (ana_id)
    );

    -- grants
    GRANT ALL ON TABLE    client_lig_alims.analytics TO group_admin;
    GRANT ALL ON TABLE    client_lig_alims.analytics TO group_bobo;
    GRANT ALL ON TABLE    client_lig_alims.analytics TO group_tools;
    GRANT SELECT ON TABLE client_lig_alims.analytics TO group_readonly;

    -- comments
    COMMENT ON TABLE  client_lig_alims.analytics            IS 'Analytic sets table';
    COMMENT ON COLUMN client_lig_alims.analytics.ana_id     IS 'Analytic set ID (PK)';
    COMMENT ON COLUMN client_lig_alims.analytics.ana_desc   IS 'Analytic set description';
    COMMENT ON COLUMN client_lig_alims.analytics.ana_active IS 'Analytic set active status';

    -- DROP TABLE IF EXISTS client_lig_alims.arguments;
    CREATE TABLE client_lig_alims.arguments (
        arg_id   integer NOT NULL,
        arg_desc text NOT NULL,

        CONSTRAINT client_lig_alims_arguments_pkey PRIMARY KEY (arg_id)
    );

    -- grants
    GRANT ALL ON TABLE    client_lig_alims.arguments TO group_admin;
    GRANT ALL ON TABLE    client_lig_alims.arguments TO group_bobo;
    GRANT ALL ON TABLE    client_lig_alims.arguments TO group_tools;
    GRANT SELECT ON TABLE client_lig_alims.arguments TO group_readonly;

    -- comments
    COMMENT ON TABLE  client_lig_alims.arguments          IS 'Arguments table';
    COMMENT ON COLUMN client_lig_alims.arguments.arg_id   IS 'Argument ID (PK)';
    COMMENT ON COLUMN client_lig_alims.arguments.arg_desc IS 'Argument description';

    -- DROP TABLE IF EXISTS client_lig_alims.filters;
    CREATE TABLE client_lig_alims.filters (
        filter_id             serial NOT NULL,
        rep_id                integer NOT NULL,
        filter_name           text NOT NULL,
        filter_start_fulldate timestamp without time zone NOT NULL,
        filter_end_fulldate   timestamp without time zone NOT NULL,
        filter_volume         numeric NOT NULL,
        filter_cancelled      boolean DEFAULT FALSE,
        filter_white          boolean DEFAULT FALSE,
        filter_results_obj    jsonb,

        CONSTRAINT client_lig_alims_filters_pkey PRIMARY KEY (filter_id)
        -- CONSTRAINT client_lig_alims_filters_fkey1 FOREIGN KEY (rep_id)
        --     REFERENCES client_lig_alims.reports (rep_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE RESTRICT
    );

    -- grants
    GRANT ALL ON TABLE    client_lig_alims.filters TO group_admin;
    GRANT ALL ON TABLE    client_lig_alims.filters TO group_bobo;
    GRANT ALL ON TABLE    client_lig_alims.filters TO group_tools;
    GRANT SELECT ON TABLE client_lig_alims.filters TO group_readonly;
    GRANT ALL ON SEQUENCE client_lig_alims.filters_filter_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE client_lig_alims.filters_filter_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE client_lig_alims.filters_filter_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  client_lig_alims.filters                       IS 'Table storing all data about ALIMS filters';
    COMMENT ON COLUMN client_lig_alims.filters.filter_id             IS 'Filter ID (PK)';
    COMMENT ON COLUMN client_lig_alims.filters.rep_id                IS 'Report ALIMS ID (FK)';
    COMMENT ON COLUMN client_lig_alims.filters.filter_name           IS 'Filter Name';
    COMMENT ON COLUMN client_lig_alims.filters.filter_start_fulldate IS 'Filter Start Fulldate';
    COMMENT ON COLUMN client_lig_alims.filters.filter_end_fulldate   IS 'Filter End Fulldate';
    COMMENT ON COLUMN client_lig_alims.filters.filter_volume         IS 'Filter Volume';
    COMMENT ON COLUMN client_lig_alims.filters.filter_cancelled      IS 'Filter Cancelled';
    COMMENT ON COLUMN client_lig_alims.filters.filter_white          IS 'Filter White';
    COMMENT ON COLUMN client_lig_alims.filters.filter_results_obj    IS 'Filter results obj from laboratory';

    -- DROP TABLE IF EXISTS client_lig_alims.reports;
    CREATE TABLE client_lig_alims.reports (
        rep_id              serial NOT NULL,
        rep_seq             integer,
        us_id               integer NOT NULL,
        rep_fulldate        timestamp without time zone NOT NULL,
        rep_number          text NOT NULL,
        arg_id              integer NOT NULL,
        station_id          integer NOT NULL,
        instr_id            integer NOT NULL,
        rep_multi_filters   boolean DEFAULT FALSE,
        ana_ids             integer[] NOT NULL,
        rep_insert_ts       timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
        rep_pdf             boolean DEFAULT FALSE,
        rep_sent            boolean DEFAULT FALSE,
        rep_sent_ts         timestamp without time zone DEFAULT NULL,
        analisys_obj        jsonb DEFAULT NULL,
        analisys_receive_ts timestamp without time zone DEFAULT NULL,

        CONSTRAINT client_lig_alims_reports_pkey PRIMARY KEY (rep_id),
        CONSTRAINT client_lig_alims_reports_ukey UNIQUE (rep_number)
        -- CONSTRAINT client_lig_alims_reports_fkey1 FOREIGN KEY (us_id)
        --     REFERENCES bobo.users (us_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT client_lig_alims_reports_fkey2 FOREIGN KEY (arg_id)
        --     REFERENCES client_lig_alims.arguments (arg_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT client_lig_alims_reports_fkey3 FOREIGN KEY (station_id)
        --     REFERENCES metadata.stations (station_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT client_lig_alims_reports_fkey4 FOREIGN KEY (instr_id)
        --     REFERENCES equipments.instruments (instr_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    );

    -- grants
    GRANT ALL ON TABLE    client_lig_alims.reports TO group_admin;
    GRANT ALL ON TABLE    client_lig_alims.reports TO group_bobo;
    GRANT ALL ON TABLE    client_lig_alims.reports TO group_tools;
    GRANT SELECT ON TABLE client_lig_alims.reports TO group_readonly;
    GRANT ALL ON SEQUENCE client_lig_alims.reports_rep_id_seq TO group_admin;
    GRANT ALL ON SEQUENCE client_lig_alims.reports_rep_id_seq TO group_bobo;
    GRANT ALL ON SEQUENCE client_lig_alims.reports_rep_id_seq TO group_tools;

    -- comments
    COMMENT ON TABLE  client_lig_alims.reports                     IS 'Table that holds all info about ALIMS reports';
    COMMENT ON COLUMN client_lig_alims.reports.rep_id              IS 'Report ID (PK)';
    COMMENT ON COLUMN client_lig_alims.reports.rep_seq             IS 'Report sequence id';
    COMMENT ON COLUMN client_lig_alims.reports.us_id               IS 'Report User (FK)';
    COMMENT ON COLUMN client_lig_alims.reports.rep_fulldate        IS 'Report Fulldate';
    COMMENT ON COLUMN client_lig_alims.reports.rep_number          IS 'Report Number';
    COMMENT ON COLUMN client_lig_alims.reports.station_id          IS 'Station ID (FK)';
    COMMENT ON COLUMN client_lig_alims.reports.instr_id            IS 'Instrument ID (FK)';
    COMMENT ON COLUMN client_lig_alims.reports.arg_id              IS 'Argument ID (FK)';
    COMMENT ON COLUMN client_lig_alims.reports.ana_ids             IS 'Array of Analytics ID (FK)';
    COMMENT ON COLUMN client_lig_alims.reports.rep_multi_filters   IS 'Flag multiple filters';
    COMMENT ON COLUMN client_lig_alims.reports.rep_insert_ts       IS 'Report insert fulldate';
    COMMENT ON COLUMN client_lig_alims.reports.rep_pdf             IS 'Report flag: true if the pdf has been created';
    COMMENT ON COLUMN client_lig_alims.reports.rep_sent            IS 'Report flag: true if the report has been sent to webservice';
    COMMENT ON COLUMN client_lig_alims.reports.rep_sent_ts         IS 'Report sending fulldate';
    COMMENT ON COLUMN client_lig_alims.reports.analisys_obj        IS 'Analisys data in json format';
    COMMENT ON COLUMN client_lig_alims.reports.analisys_receive_ts IS 'Analisys recieving fulldate';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- DROP VIEW IF EXISTS client_lig_alims.view_reports;
    CREATE OR REPLACE VIEW client_lig_alims.view_reports AS
    SELECT
        r.rep_id                               AS report_id  ,
        r.rep_seq                              AS report_seq,
        r.rep_fulldate                         AS report_fulldate,
        TO_CHAR(r.rep_fulldate, 'DD/MM/YYYY HH24:MI') AS report_fulldate_formated,
        r.rep_number                           AS report_number     ,
        r.rep_insert_ts                        AS report_insert_ts,
        r.rep_pdf                              AS report_pdf,
        r.rep_sent                             AS report_sent,
        r.rep_sent_ts                          AS report_sent_ts,
        r.rep_multi_filters                    AS report_multi_filters,
        -- argument
        r.arg_id                                AS argument_id,
        a.arg_desc                              AS argument_desc,
        -- analytic
        r.ana_ids                               AS analytics_id,
        ARRAY(
            SELECT ana_desc
            FROM client_lig_alims.analytics
            WHERE ana_id = ANY(r.ana_ids)
        )                                       AS analytics_desc,
        array_to_string(ARRAY
            (
                SELECT ana_desc
                FROM client_lig_alims.analytics
                WHERE ana_id = ANY(r.ana_ids)
            ), ','::text
        )                                       AS analytics_desc_str,
        (
            SELECT COUNT(*)
            FROM client_lig_alims.filters f
            WHERE f.rep_id = r.rep_id
        )                                       AS report_filter_number,
        -- station
        r.station_id                            AS station_id,
        s.station_name                          AS station_name,
        -- user
        r.us_id                                 AS user_id,
        u.us_name || ' '
        || COALESCE(u.us_2nd_name, ''::text)
        || u.us_surname                         AS user_fullname,
        u.us_avatar                             AS user_avatar,
        u.us_avatar_thumb                       AS user_avatar_thumb,
        -- instrument
        r.instr_id                              AS instr_id        ,
        i.instr_type_id                         AS instr_type_id   ,
        CASE
            WHEN it.instr_type_id = 0 THEN 'Stazione'
            ELSE c.constr_name||' '
                ||b.brand_name||' '
                ||m.model_name
        END                                     AS instr_type_fullname  ,
        i.instr_arpa_id                         AS instrument_arpa_id   ,
        i.instr_serial_num                      AS instrument_serial_num,
        i.instr_name                            AS instrument_name
    FROM
        client_lig_alims.reports r
        LEFT JOIN client_lig_alims.arguments a   USING (arg_id)
        LEFT JOIN metadata.stations s            USING (station_id)
        LEFT JOIN bobo.users u                   USING (us_id)
        LEFT JOIN equipments.instruments i       USING (instr_id)
        LEFT JOIN equipments.instruments_type it USING (instr_type_id)
        LEFT JOIN equipments.constructors c      USING (constr_id)
        LEFT JOIN equipments.brands b            USING (brand_id)
        LEFT JOIN equipments.models m            USING (model_id)

    ORDER BY
        r.rep_id;

    -- grants
    GRANT ALL ON TABLE    client_lig_alims.view_reports TO group_admin;
    GRANT ALL ON TABLE    client_lig_alims.view_reports TO group_bobo;
    GRANT ALL ON TABLE    client_lig_alims.view_reports TO group_tools;
    GRANT SELECT ON TABLE client_lig_alims.view_reports TO group_readonly;

    -- comments
    COMMENT ON VIEW client_lig_alims.view_reports IS 'View with all data about reports ALIMS';

    -- DROP VIEW IF EXISTS client_lig_alims.view_reports_filters;
    CREATE OR REPLACE VIEW client_lig_alims.view_reports_filters AS
    SELECT
        r.rep_id                  AS report_id,
        r.rep_fulldate            AS report_fulldate,
        TO_CHAR(r.rep_fulldate,
            'DD/MM/YYYY HH24:MI') AS report_fulldate_formated,
        r.rep_number              AS report_number,
        r.rep_insert_ts           AS report_insert_ts,
        r.rep_pdf                 AS report_pdf,
        r.rep_sent                AS report_sent,
        r.rep_sent_ts             AS report_sent_ts,
        r.rep_multi_filters       AS report_multi_filters,
        -- argument
        r.arg_id                  AS argument_id,
        a.arg_desc                AS argument_desc,
        -- analytic
        r.ana_ids                 AS analytics_id,
        ARRAY(
            SELECT ana_desc
            FROM client_lig_alims.analytics
            WHERE ana_id = ANY(r.ana_ids)
        )                         AS analytics_desc,
        array_to_string(ARRAY
            (
                SELECT ana_desc
                FROM client_lig_alims.analytics
                WHERE ana_id = ANY(r.ana_ids)
            ), '|'::text
        )                         AS analytics_desc_str,
        (
            SELECT COUNT(*)
            FROM client_lig_alims.filters f
            WHERE f.rep_id = r.rep_id
        )                                           AS report_filter_number,
        -- station
        r.station_id                                AS station_id,
        s.station_name                              AS station_name,
        si.st_info_export_id                        AS siral_id,
        -- user
        r.us_id                                     AS user_id,
        u.us_name || ' '
        || COALESCE(u.us_2nd_name, ''::text)
        || u.us_surname                             AS user_fullname,
        u.us_avatar                                 AS user_avatar,
        u.us_avatar_thumb                           AS user_avatar_thumb,
        -- instrument
        r.instr_id                                  AS instrument_id,
        i.instr_type_id                             AS instr_type_id   ,
        CASE
            WHEN it.instr_type_id = 0 THEN 'Stazione'
            ELSE c.constr_name||' '
                ||b.brand_name||' '
                ||m.model_name
        END                                         AS instr_type_fullname  ,
        i.instr_arpa_id                             AS instrument_arpa_id   ,
        i.instr_serial_num                          AS instrument_serial_num,
        i.instr_name                                AS instrument_name,
        -- filters
        f.filter_id                                 AS filter_id,
        f.filter_name                               AS filter_name,
        f.filter_start_fulldate                     AS filter_start_fulldate,
        TO_CHAR(f.filter_start_fulldate,
            'DD/MM/YYYY HH24:MI')                   AS filter_start_fulldate_formated,
        f.filter_end_fulldate                       AS filter_end_fulldate,
        TO_CHAR(f.filter_end_fulldate,
            'DD/MM/YYYY HH24:MI')                   AS filter_end_fulldate_formated,
        f.filter_volume                             AS filter_volume,
        f.filter_cancelled                          AS filter_cancelled,
        CASE WHEN f.filter_cancelled
            THEN 'X'::text ELSE '' END              AS filter_cancelled_formated,
        f.filter_white                              AS filter_white,
        CASE WHEN f.filter_white
            THEN 'X'::text ELSE '' END              AS filter_white_formated,
        lpad(r.rep_id::text, 5 ,'0')                AS attachment_file_id
    FROM
        client_lig_alims.reports r
        LEFT JOIN client_lig_alims.arguments a   USING (arg_id)
        LEFT JOIN client_lig_alims.filters f     USING (rep_id)
        LEFT JOIN metadata.stations s            USING (station_id)
        LEFT JOIN metadata.stations_info si      USING (station_id)
        LEFT JOIN bobo.users u                   USING (us_id)
        LEFT JOIN equipments.instruments i       USING (instr_id)
        LEFT JOIN equipments.instruments_type it USING (instr_type_id)
        LEFT JOIN equipments.constructors c      USING (constr_id)
        LEFT JOIN equipments.brands b            USING (brand_id)
        LEFT JOIN equipments.models m            USING (model_id)
    ORDER BY
        r.rep_id, f.filter_id;

    -- grants
    GRANT ALL ON TABLE    client_lig_alims.view_reports_filters TO group_admin;
    GRANT ALL ON TABLE    client_lig_alims.view_reports_filters TO group_bobo;
    GRANT ALL ON TABLE    client_lig_alims.view_reports_filters TO group_tools;
    GRANT SELECT ON TABLE client_lig_alims.view_reports_filters TO group_readonly;

    -- comments
    COMMENT ON VIEW client_lig_alims.view_reports_filters IS 'View with all data about reports - filter ALIMS';

    -- --------------------------------------------------------------------------------------------
    -- FUNCTIONS
    -- --------------------------------------------------------------------------------------------

    -- DROP FUNCTION IF EXISTS client_lig_alims.f_insert_alims_cc_params(integer, boolean);
    CREATE OR REPLACE FUNCTION client_lig_alims.f_insert_alims_cc_params(
        stid integer,
        drop boolean
    )
    RETURNS boolean AS

    $BODY$

    DECLARE
        -- variables
        sql_query text;
    BEGIN
        -- TEST
        -- SELECT metadata.f_insert_alims_cc_params(1000::integer, true);
        -- SELECT * FROM metadata.stations_parameters WHERE station_id = 1000 AND stpr_table_id >= 500 ORDER BY stpr_table_id;

        RAISE NOTICE 'Station ID : %', stid;

        IF drop IS TRUE THEN
            RAISE NOTICE 'DELETE alims CC params for station % !', stid;
            sql_query = 'DELETE FROM metadata.stations_parameters WHERE stpr_table_id BETWEEN 555 AND 603 AND station_id = '|| stid ||';';
            EXECUTE sql_query;
        END IF;

        sql_query = 'INSERT INTO metadata.stations_parameters '
                    ||'    (station_id, param_id, stpr_table_id, stpr_active, stpr_note) '
                    ||'VALUES '
                    ||'    ( '||stid||', 842, 555, TRUE, NULL ),'
                    ||'    ( '||stid||', 843, 556, TRUE, NULL ),'
                    ||'    ( '||stid||', 844, 557, TRUE, NULL ),'
                    ||'    ( '||stid||', 845, 558, TRUE, NULL ),'
                    ||'    ( '||stid||', 846, 559, TRUE, NULL ),'
                    ||'    ( '||stid||', 847, 560, TRUE, NULL ),'
                    ||'    ( '||stid||', 848, 561, TRUE, NULL ),'
                    ||'    ( '||stid||', 849, 562, TRUE, NULL ),'
                    ||'    ( '||stid||', 850, 563, TRUE, NULL ),'
                    ||'    ( '||stid||', 851, 564, TRUE, NULL ),'
                    ||'    ( '||stid||', 852, 565, TRUE, NULL ),'
                    ||'    ( '||stid||', 853, 566, TRUE, NULL ),'
                    ||'    ( '||stid||', 854, 567, TRUE, NULL ),'
                    ||'    ( '||stid||', 855, 568, TRUE, NULL ),'
                    ||'    ( '||stid||', 856, 569, TRUE, NULL ),'
                    ||'    ( '||stid||', 857, 570, TRUE, NULL ),'
                    ||'    ( '||stid||', 858, 571, TRUE, NULL ),'
                    ||'    ( '||stid||', 859, 572, TRUE, NULL ),'
                    ||'    ( '||stid||', 860, 573, TRUE, NULL ),'
                    ||'    ( '||stid||', 861, 574, TRUE, NULL ),'
                    ||'    ( '||stid||', 862, 575, TRUE, NULL ),'
                    ||'    ( '||stid||', 863, 576, TRUE, NULL ),'
                    ||'    ( '||stid||', 864, 577, TRUE, NULL ),'
                    ||'    ( '||stid||', 865, 578, TRUE, NULL ),'
                    ||'    ( '||stid||', 866, 579, TRUE, NULL ),'
                    ||'    ( '||stid||', 867, 580, TRUE, NULL ),'
                    ||'    ( '||stid||', 868, 581, TRUE, NULL ),'
                    ||'    ( '||stid||', 869, 582, TRUE, NULL ),'
                    ||'    ( '||stid||', 870, 583, TRUE, NULL ),'
                    ||'    ( '||stid||', 871, 584, TRUE, NULL ),'
                    ||'    ( '||stid||', 872, 585, TRUE, NULL ),'
                    ||'    ( '||stid||', 873, 586, TRUE, NULL ),'
                    ||'    ( '||stid||', 874, 587, TRUE, NULL ),'
                    ||'    ( '||stid||', 875, 588, TRUE, NULL ),'
                    ||'    ( '||stid||', 876, 589, TRUE, NULL ),'
                    ||'    ( '||stid||', 877, 590, TRUE, NULL ),'
                    ||'    ( '||stid||', 878, 591, TRUE, NULL ),'
                    ||'    ( '||stid||', 879, 592, TRUE, NULL ),'
                    ||'    ( '||stid||', 880, 593, TRUE, NULL ),'
                    ||'    ( '||stid||', 881, 594, TRUE, NULL ),'
                    ||'    ( '||stid||', 882, 595, TRUE, NULL ),'
                    ||'    ( '||stid||', 883, 596, TRUE, NULL ),'
                    ||'    ( '||stid||', 884, 597, TRUE, NULL ),'
                    ||'    ( '||stid||', 885, 598, TRUE, NULL ),'
                    ||'    ( '||stid||', 886, 599, TRUE, NULL ),'
                    ||'    ( '||stid||', 887, 600, TRUE, NULL ),'
                    ||'    ( '||stid||', 888, 601, TRUE, NULL ),'
                    ||'    ( '||stid||', 889, 602, TRUE, NULL ),'
                    ||'    ( '||stid||', 890, 603, TRUE, NULL );';

        RAISE NOTICE 'Insert parameters';
        EXECUTE sql_query;

        RETURN TRUE;
        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN metadata.f_insert_alims_cc_params() : %', SQLERRM ;
            RETURN FALSE;
    END;

    $BODY$

    LANGUAGE 'plpgsql'
    VOLATILE
    COST 100;

    -- grants
    GRANT EXECUTE ON FUNCTION client_lig_alims.f_insert_alims_cc_params(integer, boolean) TO group_bobo;
    GRANT EXECUTE ON FUNCTION client_lig_alims.f_insert_alims_cc_params(integer, boolean) TO group_admin;
    GRANT EXECUTE ON FUNCTION client_lig_alims.f_insert_alims_cc_params(integer, boolean) TO group_tools;

    -- comment
    COMMENT ON FUNCTION client_lig_alims.f_insert_alims_cc_params(integer, boolean) IS 'Function that adds ALIMS CC parameters to station';

    -- DROP FUNCTION IF EXISTS client_lig_alims.f_insert_alims_params(integer, boolean);
    CREATE OR REPLACE FUNCTION client_lig_alims.f_insert_alims_params(
        stid integer,
        drop boolean
    )

    RETURNS boolean AS

    $BODY$

    DECLARE
        -- variables
        sql_query text;
    BEGIN
        -- TEST
        -- SELECT metadata.f_insert_alims_params(1000::integer, true);
        -- SELECT * FROM metadata.stations_parameters WHERE station_id = 1000 AND stpr_table_id >= 500 ORDER BY stpr_table_id;

        RAISE NOTICE 'Station ID : %', stid;

        IF drop IS TRUE THEN
            RAISE NOTICE 'DELETE alims params for station % !', stid;
            sql_query = 'DELETE FROM metadata.stations_parameters WHERE stpr_table_id BETWEEN 500 AND 546 AND station_id = '|| stid ||';';
            EXECUTE sql_query;
        END IF;

        sql_query = 'INSERT INTO metadata.stations_parameters '
                    ||'    (station_id, param_id, stpr_table_id, stpr_active, stpr_note) '
                    ||'VALUES '
                    ||'    ( '||stid||', 657, 500, TRUE, '||quote_literal('ALIMS')||' ),' -- Alluminio su PM10
                    ||'    ( '||stid||',  77, 501, TRUE, '||quote_literal('ALIMS')||' ),' -- Ammonio in PM10
                    ||'    ( '||stid||', 809, 502, TRUE, '||quote_literal('ALIMS')||' ),' -- Antimonio
                    ||'    ( '||stid||', 810, 503, TRUE, '||quote_literal('ALIMS')||' ),' -- Antracene
                    ||'    ( '||stid||',  59, 504, TRUE, '||quote_literal('ALIMS')||' ),' -- Arsenico su PM10
                    ||'    ( '||stid||', 811, 505, TRUE, '||quote_literal('ALIMS')||' ),' -- Bario
                    ||'    ( '||stid||',  66, 506, TRUE, '||quote_literal('ALIMS')||' ),' -- Benzo(a)Antracene su PM10
                    ||'    ( '||stid||',  70, 507, TRUE, '||quote_literal('ALIMS')||' ),' -- Benzo(a)Pirene su PM10
                    ||'    ( '||stid||',  68, 508, TRUE, '||quote_literal('ALIMS')||' ),' -- Benzo(b)Fluorantene su PM10
                    ||'    ( '||stid||', 812, 509, TRUE, '||quote_literal('ALIMS')||' ),' -- Benzo(b+j)fluorantene
                    ||'    ( '||stid||', 813, 510, TRUE, '||quote_literal('ALIMS')||' ),' -- Benzo(e)pirene
                    ||'    ( '||stid||',  72, 511, TRUE, '||quote_literal('ALIMS')||' ),' -- Benzo(g,h,i)Perilene su PM10
                    ||'    ( '||stid||',  69, 512, TRUE, '||quote_literal('ALIMS')||' ),' -- Benzo(k)Fluorantene su PM10
                    ||'    ( '||stid||', 814, 513, TRUE, '||quote_literal('ALIMS')||' ),' -- Berillio
                    ||'    ( '||stid||', 815, 514, TRUE, '||quote_literal('ALIMS')||' ),' -- Coronene
                    ||'    ( '||stid||',  67, 515, TRUE, '||quote_literal('ALIMS')||' ),' -- Crisene su PM10
                    ||'    ( '||stid||',  52, 516, TRUE, '||quote_literal('ALIMS')||' ),' -- Cromo su PM10
                    ||'    ( '||stid||',  71, 517, TRUE, '||quote_literal('ALIMS')||' ),' -- DiBenzo(a,h)Antracene su PM10
                    ||'    ( '||stid||', 816, 518, TRUE, '||quote_literal('ALIMS')||' ),' -- Fenantrene
                    ||'    ( '||stid||',  51, 519, TRUE, '||quote_literal('ALIMS')||' ),' -- Cadmio su PM10
                    ||'    ( '||stid||',  80, 520, TRUE, '||quote_literal('ALIMS')||' ),' -- Calcio in PM10
                    ||'    ( '||stid||',  81, 521, TRUE, '||quote_literal('ALIMS')||' ),' -- Cloruri in PM10
                    ||'    ( '||stid||',  61, 522, TRUE, '||quote_literal('ALIMS')||' ),' -- Cobalto su PM10
                    ||'    ( '||stid||', 817, 523, TRUE, '||quote_literal('ALIMS')||' ),' -- Acenaftene
                    ||'    ( '||stid||', 818, 524, TRUE, '||quote_literal('ALIMS')||' ),' -- Acenaftilene
                    ||'    ( '||stid||', 819, 525, TRUE, '||quote_literal('ALIMS')||' ),' -- Selenio
                    ||'    ( '||stid||',  76, 526, TRUE, '||quote_literal('ALIMS')||' ),' -- Sodio in PM10
                    ||'    ( '||stid||',  83, 527, TRUE, '||quote_literal('ALIMS')||' ),' -- Solfati in PM10
                    ||'    ( '||stid||',  60, 528, TRUE, '||quote_literal('ALIMS')||' ),' -- Vanadio su PM10
                    ||'    ( '||stid||',  58, 529, TRUE, '||quote_literal('ALIMS')||' ),' -- Zinco su PM10
                    ||'    ( '||stid||', 820, 530, TRUE, '||quote_literal('ALIMS')||' ),' -- Titanio
                    ||'    ( '||stid||',  53, 531, TRUE, '||quote_literal('ALIMS')||' ),' -- Ferro su PM10
                    ||'    ( '||stid||',  64, 532, TRUE, '||quote_literal('ALIMS')||' ),' -- Fluorantene su PM10
                    ||'    ( '||stid||', 821, 533, TRUE, '||quote_literal('ALIMS')||' ),' -- Fluorene
                    ||'    ( '||stid||', 822, 534, TRUE, '||quote_literal('ALIMS')||' ),' -- Fluoruri
                    ||'    ( '||stid||', 823, 535, TRUE, '||quote_literal('ALIMS')||' ),' -- Indeno(1,2,3-c,d)pirene
                    ||'    ( '||stid||',  78, 536, TRUE, '||quote_literal('ALIMS')||' ),' -- Magnesio in PM10
                    ||'    ( '||stid||',  54, 537, TRUE, '||quote_literal('ALIMS')||' ),' -- Manganese su PM10
                    ||'    ( '||stid||',  62, 538, TRUE, '||quote_literal('ALIMS')||' ),' -- Mercurio su PM10
                    ||'    ( '||stid||', 824, 539, TRUE, '||quote_literal('ALIMS')||' ),' -- Naftalene
                    ||'    ( '||stid||',  55, 540, TRUE, '||quote_literal('ALIMS')||' ),' -- Nichel su PM10
                    ||'    ( '||stid||',  82, 541, TRUE, '||quote_literal('ALIMS')||' ),' -- Nitrati in PM10
                    -- ||'    ( '||stid||', 822, 542, TRUE, '||quote_literal('ALIMS')||' ),' -- Particolato atmosferico
                    ||'    ( '||stid||',  56, 543, TRUE, '||quote_literal('ALIMS')||' ),' -- Piombo su PM10
                    ||'    ( '||stid||',  65, 544, TRUE, '||quote_literal('ALIMS')||' ),' -- Pirene su PM10
                    -- ||'    ( '||stid||', 658, 545, TRUE, '||quote_literal('ALIMS')||' ),' -- PM10
                    -- ||'    ( '||stid||', 659, 546, TRUE, '||quote_literal('ALIMS')||' ),' -- PM2.5
                    ||'    ( '||stid||',  79, 547, TRUE, '||quote_literal('ALIMS')||' ),' -- Potassio in PM10
                    ||'    ( '||stid||',  57, 548, TRUE, '||quote_literal('ALIMS')||' ),' -- Rame su PM10
                    ||'    ( '||stid||', 658, 549, TRUE, '||quote_literal('ALIMS')||' ),' -- PM10 Gravimetrica
                    ||'    ( '||stid||', 659, 550, TRUE, '||quote_literal('ALIMS')||' ),' -- PM2.5 Gravimetrica
                    -- ||'    ( '||stid||', 98,  551, TRUE, '||quote_literal('Alims')||' ), ' -- 'Tara(filtro bianco)'
                    -- ||'    ( '||stid||', 99,  552, TRUE, '||quote_literal('Alims')||' ), ' -- 'Peso_lordo(filtro dopo il campionamento)'
                    -- ||'    ( '||stid||', 100, 553, TRUE, '||quote_literal('Alims')||' ), ' -- 'PM10(calcolo)'
                    ||'    ( '||stid||', 825, 554, TRUE, '||quote_literal('ALIMS')||' );' ;-- Sommatoria IPA

        RAISE NOTICE 'Insert parameters';
        EXECUTE sql_query;

        RETURN TRUE;
        /* errors check */
        EXCEPTION
        WHEN OTHERS THEN /* in case of any error */
            RAISE NOTICE 'ERROR IN metadata.f_insert_alims_params() : %', SQLERRM ;
            RETURN FALSE;
    END;

    $BODY$

    LANGUAGE 'plpgsql'
    VOLATILE
    COST 100;

    -- grants
    GRANT EXECUTE ON FUNCTION client_lig_alims.f_insert_alims_params(integer, boolean) TO group_bobo;
    GRANT EXECUTE ON FUNCTION client_lig_alims.f_insert_alims_params(integer, boolean) TO group_admin;
    GRANT EXECUTE ON FUNCTION client_lig_alims.f_insert_alims_params(integer, boolean) TO group_tools;

    -- comment
    COMMENT ON FUNCTION client_lig_alims.f_insert_alims_params(integer, boolean) IS 'Function that adds ALIMS parameters to station';

-- SCHEMA client_lig

    -- DROP SCHEMA IF EXISTS client_lig CASCADE;
    CREATE SCHEMA client_lig
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA client_lig TO group_admin;
    GRANT USAGE ON SCHEMA client_lig TO group_bobo;
    GRANT USAGE ON SCHEMA client_lig TO group_readonly;
    GRANT USAGE ON SCHEMA client_lig TO group_tools;
    COMMENT ON SCHEMA client_lig IS 'Client schema for ARPA Liguria in OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------
    CREATE TYPE client_lig.ws_commands AS ENUM ('misure', 'misure-log', 'stazioni', 'stazioni-edit');

    -- DROP TABLE IF EXISTS client_lig.ws_opas2siral;
    CREATE TABLE IF NOT EXISTS client_lig.ws_opas2siral
    (
        counter      bigserial,
        execution_ts timestamp DEFAULT current_timestamp    NOT NULL,
        command      client_lig.ws_commands                 DEFAULT NULL,
        result       smallint                               DEFAULT NULL,
        mode         varchar(1)                             DEFAULT NULL CHECK (mode IN ('N','V')),
        file         text                                   DEFAULT NULL,

        sending_res  jsonb                                  DEFAULT NULL,
        process_res  jsonb                                  DEFAULT NULL,

        CONSTRAINT client_lig_ws_opas2siral_pkey PRIMARY KEY (counter)
    );
    -- grants
    GRANT ALL ON TABLE    client_lig.ws_opas2siral TO group_admin;
    GRANT ALL ON TABLE    client_lig.ws_opas2siral TO group_bobo;
    GRANT ALL ON TABLE    client_lig.ws_opas2siral TO group_tools;
    GRANT SELECT ON TABLE client_lig.ws_opas2siral TO group_readonly;

    GRANT ALL ON SEQUENCE client_lig.ws_opas2siral_counter_seq TO group_admin;
    GRANT ALL ON SEQUENCE client_lig.ws_opas2siral_counter_seq TO group_bobo;
    GRANT ALL ON SEQUENCE client_lig.ws_opas2siral_counter_seq TO group_tools;

    -- comments
    COMMENT ON TABLE client_lig.ws_opas2siral               IS '[BOBO] Web service Siral, export result';
    COMMENT ON COLUMN client_lig.ws_opas2siral.counter      IS 'Progressive counter, used to recreate data update sequence';
    COMMENT ON COLUMN client_lig.ws_opas2siral.execution_ts IS 'Execution time';
    COMMENT ON COLUMN client_lig.ws_opas2siral.command      IS 'Command executed';
    COMMENT ON COLUMN client_lig.ws_opas2siral.result       IS 'Http result [200, 400, 404, 405]';
    COMMENT ON COLUMN client_lig.ws_opas2siral.mode         IS 'Execution mode (N raw data, V valid data)';
    COMMENT ON COLUMN client_lig.ws_opas2siral.file         IS 'Siral full file name (cor)';
    COMMENT ON COLUMN client_lig.ws_opas2siral.sending_res  IS 'Sending data result json object';
    COMMENT ON COLUMN client_lig.ws_opas2siral.process_res  IS 'Procedd data result json object';

    CREATE TABLE IF NOT EXISTS client_lig.ws_opas2aernostrum
    (
        counter      bigserial,
        execution_ts timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
        result       boolean,

        CONSTRAINT client_lig_ws_opas2aernosturm_pkey PRIMARY KEY (counter)
    );
    -- grants
    GRANT ALL ON TABLE    client_lig.ws_opas2aernostrum TO group_admin;
    GRANT ALL ON TABLE    client_lig.ws_opas2aernostrum TO group_bobo;
    GRANT ALL ON TABLE    client_lig.ws_opas2aernostrum TO group_tools;
    GRANT SELECT ON TABLE client_lig.ws_opas2aernostrum TO group_readonly;

    GRANT ALL ON SEQUENCE client_lig.ws_opas2aernostrum_counter_seq TO group_admin;
    GRANT ALL ON SEQUENCE client_lig.ws_opas2aernostrum_counter_seq TO group_bobo;
    GRANT ALL ON SEQUENCE client_lig.ws_opas2aernostrum_counter_seq TO group_tools;

    -- comments
    COMMENT ON TABLE client_lig.ws_opas2aernostrum               IS '[BOBO] Web service AER Nostrum, export result';
    COMMENT ON COLUMN client_lig.ws_opas2aernostrum.counter      IS 'Progressive counter, used to recreate data update sequence';
    COMMENT ON COLUMN client_lig.ws_opas2aernostrum.execution_ts IS 'Execution time';
    COMMENT ON COLUMN client_lig.ws_opas2aernostrum.result       IS 'Script result True / False';

-- SCHEMA infoaria

    -- DROP SCHEMA IF EXISTS infoaria CASCADE;
    CREATE SCHEMA infoaria
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA infoaria TO group_admin;
    GRANT USAGE ON SCHEMA infoaria TO group_bobo;
    GRANT USAGE ON SCHEMA infoaria TO group_readonly;
    GRANT USAGE ON SCHEMA infoaria TO group_tools;
    COMMENT ON SCHEMA infoaria IS 'Infoaria schema for OPAS project';

    -- --------------------------------------------------------------------------------------------
    -- TABLES
    -- --------------------------------------------------------------------------------------------

    -- DROP TABLE IF EXISTS infoaria.pollutants;
    CREATE TABLE IF NOT EXISTS infoaria.pollutants
    (
        pollutant_id integer NOT NULL,
        pollutant_uri text COLLATE pg_catalog."default",
        pollutant_notation text COLLATE pg_catalog."default",
        pollutant_label text COLLATE pg_catalog."default",
        pollutant_definition text COLLATE pg_catalog."default",

        CONSTRAINT infoaria_pollutants_pkey PRIMARY KEY (pollutant_id)
    );

    -- grants
    GRANT ALL ON TABLE infoaria.pollutants TO group_admin;
    GRANT ALL ON TABLE infoaria.pollutants TO group_bobo;
    GRANT SELECT ON TABLE infoaria.pollutants TO group_readonly;
    GRANT ALL ON TABLE infoaria.pollutants TO group_tools;
    GRANT ALL ON TABLE infoaria.pollutants TO user_admin;

    -- DROP TABLE IF EXISTS infoaria.observation_units;
    CREATE TABLE IF NOT EXISTS infoaria.observation_units
    (
        observation_unit_id text COLLATE pg_catalog."default" NOT NULL,
        observation_unit_uri text COLLATE pg_catalog."default",
        observation_unit_notation text COLLATE pg_catalog."default",
        observation_unit_label text COLLATE pg_catalog."default",
        observation_unit_definition text COLLATE pg_catalog."default",

        CONSTRAINT infoaria_observation_units_pkey PRIMARY KEY (observation_unit_id)
    );

    -- grants
    GRANT ALL ON TABLE infoaria.observation_units TO group_admin;
    GRANT ALL ON TABLE infoaria.observation_units TO group_bobo;
    GRANT SELECT ON TABLE infoaria.observation_units TO group_readonly;
    GRANT ALL ON TABLE infoaria.observation_units TO group_tools;

    -- DROP TABLE IF EXISTS infoaria.assessment_types;
    CREATE TABLE IF NOT EXISTS infoaria.assessment_types
    (
        assessment_type_id text COLLATE pg_catalog."default" NOT NULL,
        assessment_type_uri text COLLATE pg_catalog."default",
        assessment_type_notation text COLLATE pg_catalog."default",
        assessment_type_label text COLLATE pg_catalog."default",
        assessment_type_definition text COLLATE pg_catalog."default",

        CONSTRAINT infoaria_assessment_types_pkey PRIMARY KEY (assessment_type_id)
    );

    GRANT ALL ON TABLE infoaria.assessment_types TO group_admin;

    GRANT ALL ON TABLE infoaria.assessment_types TO group_bobo;

    GRANT SELECT ON TABLE infoaria.assessment_types TO group_readonly;

    GRANT ALL ON TABLE infoaria.assessment_types TO group_tools;

    -- DROP TABLE IF EXISTS infoaria.params_pollutant;
    CREATE TABLE IF NOT EXISTS infoaria.params_pollutant
    (
        pp_id serial,
        param_id integer NOT NULL,
        pollutant_id integer NOT NULL,
        observation_unit_id text COLLATE pg_catalog."default" NOT NULL,
        pp_decimals smallint,
        pp_uncertainty_estimation smallint,
        pp_time_coverage_perc smallint,

        CONSTRAINT infoaria_params_pollutant_pkey PRIMARY KEY (pp_id)
        -- CONSTRAINT infoaria_params_pollutant_fk1 FOREIGN KEY (param_id)
        --     REFERENCES metadata.parameters (param_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT infoaria_params_pollutant_fk2 FOREIGN KEY (pollutant_id)
        --     REFERENCES infoaria.pollutants (pollutant_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION,
        -- CONSTRAINT infoaria_params_pollutant_fk3 FOREIGN KEY (observation_unit_id)
        --     REFERENCES infoaria.observation_units (observation_unit_id) MATCH SIMPLE
        --     ON UPDATE CASCADE
        --     ON DELETE NO ACTION
    );

    -- grants
    GRANT ALL ON TABLE infoaria.params_pollutant TO group_admin;
    GRANT ALL ON TABLE infoaria.params_pollutant TO group_bobo;
    GRANT SELECT ON TABLE infoaria.params_pollutant TO group_readonly;
    GRANT ALL ON TABLE infoaria.params_pollutant TO group_tools;
    GRANT ALL ON TABLE infoaria.params_pollutant TO postgres;

    -- comments
    COMMENT ON TABLE infoaria.params_pollutant IS 'Table that contains relations between parameters and pollutants';
    COMMENT ON COLUMN infoaria.params_pollutant.pp_id IS 'Parameters pollutant serial id';
    COMMENT ON COLUMN infoaria.params_pollutant.param_id IS 'Parameter ID (FK)';
    COMMENT ON COLUMN infoaria.params_pollutant.pollutant_id IS 'Pollutanti ID (FK)';
    COMMENT ON COLUMN infoaria.params_pollutant.pp_decimals IS 'Parameters pollutant decimals';
    COMMENT ON COLUMN infoaria.params_pollutant.pp_uncertainty_estimation IS 'Parameters pollutant uncertainty estimation (%)';
    COMMENT ON COLUMN infoaria.params_pollutant.pp_time_coverage_perc IS 'Parameters pollutant time coverage percentage (%)';

    -- DROP TABLE IF EXISTS infoaria.stations_params_e2a;
    CREATE TABLE IF NOT EXISTS infoaria.stations_params_e2a
    (
        stpr_id integer NOT NULL,
        spe_active boolean DEFAULT true,

        CONSTRAINT infoaria_stations_params_e2a_pkey PRIMARY KEY (stpr_id)
        -- CONSTRAINT infoaria_stations_params_e2a_fk1 FOREIGN KEY (stpr_id)
        --     REFERENCES metadata.stations_parameters (stpr_id) MATCH SIMPLE
        --     ON UPDATE NO ACTION
        --     ON DELETE NO ACTION
    );

    GRANT ALL ON TABLE infoaria.stations_params_e2a TO group_admin;
    GRANT ALL ON TABLE infoaria.stations_params_e2a TO group_bobo;
    GRANT SELECT ON TABLE infoaria.stations_params_e2a TO group_readonly;
    GRANT ALL ON TABLE infoaria.stations_params_e2a TO group_tools;

    COMMENT ON TABLE infoaria.stations_params_e2a
        IS 'Table that contains station-parameters status for e2a data export';
    COMMENT ON COLUMN infoaria.stations_params_e2a.stpr_id
        IS 'Station parameters id (PK-FK)';
    COMMENT ON COLUMN infoaria.stations_params_e2a.spe_active
        IS 'Export status';

    -- DROP TABLE IF EXISTS infoaria.stations_params_status;
    CREATE TABLE IF NOT EXISTS infoaria.stations_params_status
    (
        stpr_id integer NOT NULL,
        sps_year integer NOT NULL,
        sps_used_aqd boolean DEFAULT false,
        sps_dataset_d boolean DEFAULT true,
        sps_dataset_e1a boolean DEFAULT true,

        CONSTRAINT infoaria_stations_params_status_pkey PRIMARY KEY (stpr_id, sps_year)
        -- CONSTRAINT infoaria_stations_params_status_fk1 FOREIGN KEY (stpr_id)
        --     REFERENCES metadata.stations_parameters (stpr_id) MATCH SIMPLE
        --     ON UPDATE NO ACTION
        --     ON DELETE NO ACTION
    );

    GRANT ALL ON TABLE infoaria.stations_params_status TO group_admin;

    GRANT ALL ON TABLE infoaria.stations_params_status TO group_bobo;

    GRANT SELECT ON TABLE infoaria.stations_params_status TO group_readonly;

    GRANT ALL ON TABLE infoaria.stations_params_status TO group_tools;

    COMMENT ON TABLE infoaria.stations_params_status
        IS 'Table that contains station-parameters status for IPR data export';

    COMMENT ON COLUMN infoaria.stations_params_status.stpr_id
        IS 'Station parameters id (PK-FK)';

    COMMENT ON COLUMN infoaria.stations_params_status.sps_year
        IS 'Export year';

    COMMENT ON COLUMN infoaria.stations_params_status.sps_used_aqd
        IS 'Flag used for air quality directive';

    COMMENT ON COLUMN infoaria.stations_params_status.sps_dataset_d
        IS 'Dataset D export status';

    COMMENT ON COLUMN infoaria.stations_params_status.sps_dataset_e1a
        IS 'Dataset E1a export status';

    -- --------------------------------------------------------------------------------------------
    -- VIEWS
    -- --------------------------------------------------------------------------------------------

    -- DROP VIEW infoaria.view_e2a_metadata;
    CREATE OR REPLACE VIEW infoaria.view_e2a_metadata
    AS
    SELECT
        999 AS stpr_id,
        true AS e2a_active,
        999 AS station_id,
        999 AS stpr_table_id,
        '--' AS station_name,
        999 AS param_id,
        '--' AS param_name,
        '--' AS param_conv,
        '--' AS param_unit_conv,
        0 AS param_decimals,
        '2024-12-31'::timestamp AS stpr_startup_date,
        '--' AS stpr_cadence,
        '--' AS spo_name,
        '--' AS st_info_name,
        '--' AS st_info_eu_code,
        999 AS pollutant_id,
        '--' AS pollutant_notation,
        999 AS observation_unit_id,
        999 AS assessment_type_id,
        '--' AS analytical_technique_notation,
        999 AS instr_type_id,
        '--' AS instr_type_fullname,
        '--' AS measurement_type_notation,
        '--' AS equipment,
        '--' AS method,
        '--' AS detection_limit,
        999 AS detection_limit_unit_id;

    -- comment
    COMMENT ON VIEW infoaria.view_e2a_metadata
        IS 'The view contains all the info about spo to send for e2a dataset';

    -- grants
    GRANT ALL ON TABLE infoaria.view_e2a_metadata TO group_admin;
    GRANT ALL ON TABLE infoaria.view_e2a_metadata TO group_bobo;
    GRANT SELECT ON TABLE infoaria.view_e2a_metadata TO group_readonly;
    GRANT ALL ON TABLE infoaria.view_e2a_metadata TO group_tools;

    -- --------------------------------------------------------------------------------------------
    -- FUNCTION
    -- --------------------------------------------------------------------------------------------

    -- FUNCTION: infoaria.f_get_e1a_metadata(integer)
    -- DROP FUNCTION IF EXISTS infoaria.f_get_e1a_metadata(integer);
    CREATE OR REPLACE FUNCTION infoaria.f_get_e1a_metadata(
        year integer)
        RETURNS TABLE(stpr_id integer, sps_year integer, spo_name text, e1a_active boolean, station_id integer, stpr_table_id integer, station_name text, param_id integer, param_name text, param_conv real, param_unit_conv text, stpr_startup_date timestamp without time zone, stpr_dismiss_date timestamp without time zone, stpr_cadence integer, stpr_note text, st_info_name text, st_info_eu_code text, pollutant_id integer, pollutant_notation text, observation_unit_id text, pp_uncertainty_estimation smallint, pp_time_coverage_perc smallint, pp_decimals smallint, assessment_type_id text, analytical_technique_notation text, instr_type_id integer, instr_type_fullname text, measurement_type_notation text, equipment text, method text, detection_limit numeric, detection_limit_unit_id text)
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
        ROWS 1000

    AS $BODY$

        BEGIN
        --
        -- TEST SELECT * FROM infoaria.f_get_e1a_metadata(2022::integer);
        --
        RETURN QUERY
            SELECT
                999 AS stpr_id,
                2024 AS sps_year,
                true AS e1a_active,
                999 AS station_id,
                999 AS stpr_table_id,
                '--' AS station_name,
                999 AS param_id,
                '--' AS param_name,
                '--' AS param_conv,
                '--' AS param_unit_conv,
                '2024-12-31'::timestamp AS stpr_startup_date,
                NULL AS stpr_dismiss_date,
                '--' AS stpr_cadence,
                '--' AS stpr_note,
                '--' AS spo_name,
                '--' AS st_info_name,
                '--' AS st_info_eu_code,
                999 AS pollutant_id,
                '--' AS pollutant_notation,
                999 AS observation_unit_id,
                '--' AS pp_uncertainty_estimation,
                '--' AS pp_time_coverage_perc,
                '--' AS pp_decimals,
                999 AS assessment_type_id,
                '--' AS analytical_technique_notation,
                999 AS instr_type_id,
                '--' AS instr_type_fullname,
                '--' AS measurement_type_notation,
                '--' AS equipment,
                '--' AS method,
                '--' AS detection_limit,
                999 AS detection_limit_unit_id;

        /* errors check */
        EXCEPTION
            WHEN OTHERS THEN RAISE NOTICE 'ERROR clients.f_get_e1a_metadata(): %', SQLERRM;
        END;
    $BODY$;

    -- grants
    GRANT EXECUTE ON FUNCTION infoaria.f_get_e1a_metadata(integer) TO group_admin;
    GRANT EXECUTE ON FUNCTION infoaria.f_get_e1a_metadata(integer) TO group_bobo;
    GRANT EXECUTE ON FUNCTION infoaria.f_get_e1a_metadata(integer) TO group_readonly;
    GRANT EXECUTE ON FUNCTION infoaria.f_get_e1a_metadata(integer) TO group_tools;

    -- comment
    COMMENT ON FUNCTION infoaria.f_get_e1a_metadata(integer) IS 'E1A metadata extraction function per year';

-- SCHEMA client_test
    CREATE SCHEMA client_test
        AUTHORIZATION group_admin;
    GRANT ALL ON SCHEMA client_test TO group_admin;
    GRANT USAGE ON SCHEMA client_test TO group_bobo;
    GRANT USAGE ON SCHEMA client_test TO group_readonly;
    GRANT USAGE ON SCHEMA client_test TO group_tools;
    COMMENT ON SCHEMA clients IS 'Data schema in OPAS project';