-- +----------------------------------------------------------------------------------------------+
-- | - Script Name : exporter.sql                                                                 |
-- | - Author      : Ecometer s.n.c.                                                              |
-- | - Create Date : 2025-03-28                                                                   |
-- | - Description : Script to manage data export                                                 |
-- +----------------------------------------------------------------------------------------------+


-- ------------------------------------------------------------------------------------------------
-- CREATE NEW TABLE
-- ------------------------------------------------------------------------------------------------
-- Table: client_xxx.data_export
-- DROP TABLE IF EXISTS client_xxx.data_export;
CREATE TABLE IF NOT EXISTS client_xxx.data_export
(
    counter             bigserial,
    station_id          integer NOT NULL,
    measure_date_time   timestamp NOT NULL,
    measure_id          integer NOT NULL,
    measure_value       double precision NOT NULL,
    measure_perc        smallint,
    measure_min         double precision,
    measure_min_time    time without time zone,
    measure_max         double precision,
    measure_max_time    time without time zone,
    measure_std_dev     double precision,
    measure_code        smallint DEFAULT 0,
    station_code        smallint DEFAULT 0,
    auto_validity_code  integer DEFAULT 0,
    post_validity_code  integer DEFAULT 0,
    final_validity_code smallint DEFAULT 0,

    CONSTRAINT client_xxx_data_export_pkey PRIMARY KEY (counter)
)
TABLESPACE pg_default;
-- Grants
REVOKE ALL ON TABLE client_xxx.data_export FROM group_readonly;
GRANT ALL ON TABLE client_xxx.data_export TO group_bobo;
GRANT SELECT ON TABLE client_xxx.data_export TO group_readonly;
GRANT ALL ON TABLE client_xxx.data_export TO group_tools;

-- Comments
COMMENT ON TABLE client_xxx.data_export
    IS '[OPAS] Remote stations data to be exported and deleted';

COMMENT ON COLUMN client_xxx.data_export.counter
    IS 'Progressive counter, used to recreate data update sequence';

COMMENT ON COLUMN client_xxx.data_export.station_id
    IS 'Station id';

COMMENT ON COLUMN client_xxx.data_export.measure_date_time
    IS 'Measure date and time';

COMMENT ON COLUMN client_xxx.data_export.measure_id
    IS 'Measure id';

COMMENT ON COLUMN client_xxx.data_export.measure_value
    IS 'Measure value';

COMMENT ON COLUMN client_xxx.data_export.measure_perc
    IS 'Measure data validity percentage';

COMMENT ON COLUMN client_xxx.data_export.measure_min
    IS 'Measure minimum data';

COMMENT ON COLUMN client_xxx.data_export.measure_min_time
    IS 'Measure minimum time';

COMMENT ON COLUMN client_xxx.data_export.measure_max
    IS 'Measure maximum data';

COMMENT ON COLUMN client_xxx.data_export.measure_max_time
    IS 'Measure maximum time';

COMMENT ON COLUMN client_xxx.data_export.measure_std_dev
    IS 'Measure standard deviation';

COMMENT ON COLUMN client_xxx.data_export.measure_code
    IS 'Measure general code';

COMMENT ON COLUMN client_xxx.data_export.station_code
    IS 'Station general code';

COMMENT ON COLUMN client_xxx.data_export.auto_validity_code
    IS 'Validity code assigned by automatic systems';

COMMENT ON COLUMN client_xxx.data_export.post_validity_code
    IS 'Final code assigned by remote code, autovalidation code and operator code';

COMMENT ON COLUMN client_xxx.data_export.final_validity_code
    IS 'Final code assigned by an operator for daily, monthly, yearly validation';


-- ------------------------------------------------------------------------------------------------
-- CREATE NEW FUNCTION
-- ------------------------------------------------------------------------------------------------
-- FUNCTION: client_xxx.f_data_export()
-- DROP FUNCTION IF EXISTS client_xxx.f_data_export();
CREATE OR REPLACE FUNCTION client_xxx.f_data_export()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
DECLARE
    /* main variables */
    stid   smallint; /*station id*/
    export boolean; /*local variable*/
    data_minutes integer; /*measure_date_time minutes*/
BEGIN

    /* station st_id passed by caller */
    stid := TG_ARGV[0];
    --RAISE NOTICE 'st_id => %', stid;

    /* check minutes to be zero */
    SELECT INTO data_minutes EXTRACT('minute' FROM NEW.measure_date_time);
    IF data_minutes <> 0 THEN
        -- RAISE NOTICE 'Minuti non validi';
        /* return */
        RETURN NEW;
    END IF;

    /*check station is export enabled*/
    SELECT
        COALESCE(max(ss_custom_export_publish::integer), 0)::boolean INTO export
    FROM
        metadata.stations_status WHERE station_id = stid;
    IF export IS FALSE THEN
        -- RAISE NOTICE 'Station export active false';
        /* return */
        RETURN NEW;
    END IF;

    /*check parameter is export enabled*/
    SELECT
        COALESCE(max(stpr_custom_export_publish::integer), 0)::boolean INTO export
    FROM
        metadata.stations_parameters sp
        LEFT JOIN metadata.stations_params_status sps USING(stpr_id)
    WHERE
        sp.station_id = stid AND sp.stpr_table_id = NEW.measure_id;
    IF export IS FALSE THEN
        -- RAISE NOTICE 'Parameter export active false';
        /* return */
        RETURN NEW;
    END IF;

    /* insert new value */
    INSERT INTO
        client_xxx.data_export
    VALUES (
        default,
        stid,
        NEW.measure_date_time,
        NEW.measure_id,
        NEW.measure_value,
        NEW.measure_perc,
        NEW.measure_min,
        NEW.measure_min_time,
        NEW.measure_max,
        NEW.measure_max_time,
        NEW.measure_std_dev,
        NEW.measure_code,
        NEW.station_code,
        NEW.auto_validity_code,
        NEW.post_validity_code,
        NEW.final_validity_code
    );

    /* return value */
    RETURN NEW;

/* errors check */
EXCEPTION
    /* in case of any error */
    WHEN OTHERS THEN RAISE NOTICE 'ERROR client_xxx.f_data_export(): %', SQLERRM;

    /* return value */
    RETURN NEW;
END;
$BODY$;
-- Grants
GRANT EXECUTE ON FUNCTION client_xxx.f_data_export() TO group_bobo;
GRANT EXECUTE ON FUNCTION client_xxx.f_data_export() TO group_tools;
-- Comments
COMMENT ON FUNCTION client_xxx.f_data_export()
    IS '[OPAS] Insert data to be exported in the export data table';



-- ------------------------------------------------------------------------------------------------
-- CREATE NEW TRIGGER
-- ------------------------------------------------------------------------------------------------
-- Trigger: client_xxx_table_name_10_export_aiau
DROP TRIGGER IF EXISTS client_xxx_table_name_10_export_aiau ON client_xxx.table_name;
CREATE OR REPLACE TRIGGER client_xxx_table_name_10_export_aiau
    AFTER INSERT OR UPDATE
    ON client_xxx.table_name
    FOR EACH ROW
    EXECUTE FUNCTION client_xxx.f_data_export(0000);