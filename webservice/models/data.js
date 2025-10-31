export class Data {
  constructor(pg) {
    this.pg = pg;
  }

  /**
     * Get data log from station id, from epoch time 1 and 2
     * @returns list of log series objects
     */
  async getStationLog(stid, ep1, ep2) {
    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS stations FROM (
        SELECT
            l.log_id             ,
            l.log_date           ,
            l.log_daily          ,
            -- CASE
            --     WHEN l.log_daily IS TRUE THEN TO_CHAR(log_date, 'DD/MM/YYYY')
            --     ELSE TO_CHAR(log_date, 'DD/MM/YYYY HH24:MI')
            -- END AS log_date_formatted,
            l.station_id         ,
            s.station_name       ,
            l.lt_id              ,
            lt.lt_name,
            -- lt.lt_colour         ,
            -- lt.lt_icon           ,
            --l.us_id              ,
            CONCAT_WS(' ', u1.us_name, u1.us_2nd_name, u1.us_surname) AS log_creator_fullname,
            --u1.us_avatar_thumb AS log_creator_avatar,
            --l.log_foreign_id     ,
            --l.log_foreign_table  ,
            l.log_title          ,
            l.log_link           ,
            l.log_obj            ,
            COALESCE(l.log_note, '') AS log_note,
            --l.log_note_creator_fk,
            CONCAT_WS(' ', u2.us_name, u2.us_2nd_name, u2.us_surname) AS log_note_creator_fullname,
            l.log_note_insert_ts ,
            l.log_note_update_ts ,
            l.log_insert_ts      ,
            l.log_update_ts
        FROM
            reports.logs l
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN reports.log_types lt USING (lt_id)
            LEFT JOIN bobo.users u1 ON (u1.us_id = l.us_id)
            LEFT JOIN bobo.users u2 ON (u2.us_id = l.log_note_creator_fk)
        WHERE
            l.log_date BETWEEN to_timestamp(${ep1})::timestamp AND to_timestamp(${ep2})::timestamp
            AND l.station_id = ${stid}
        ORDER BY
            l.log_date
      ) t
    `).first;
  }

  /**
   * Get data from series id, latest hours
   * @returns list of data series objects
   */
  async getDataBySeriesIdHours(series_id, hours) {
    return (await this.pg.query`
      SELECT row_to_json(t) AS data FROM (
        SELECT
          sp.station_id                                   AS station_id,
          s.station_name                                  AS station_name,
          s.station_ext_id                                AS station_external_id,
          sp.param_id                                     AS parameter_id,
          p.param_name                                    AS parameter_name,
          p.param_unit                                    AS parameter_unit,
          sp.stpr_table_id                                AS series_id,
          sp.stpr_ext_id                                  AS series_external_id,
          spi.stpr_export_id1                             AS series_export_id1,
          spi.stpr_export_id2                             AS series_export_id2,
          spi.stpr_info_ws_id                             AS series_ws_id,
          CONCAT_WS(' - ', p.param_name, sp.stpr_note)    AS series_name,
          (
            SELECT array_to_json(array_agg(row_to_json(d)))
            FROM webservice.f_data_extraction (
              sp.stpr_id::integer,
              (CURRENT_TIMESTAMP - ${hours}
                * interval '1 hour'):: timestamp,
              CURRENT_TIMESTAMP::timestamp
            ) d
          )                                               AS series_data
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.parameters p USING (param_id)
        WHERE
            sp.stpr_id = ${series_id}
      ) t
    `).first;
  }

  /**
   * Get data from series id, from epoch time 1 and 2
   * @returns list of data series objects
   */
  async getDataBySeriesIdEpochTimes(series_id, ep1, ep2) {
    return (await this.pg.query`
      SELECT row_to_json(t) AS data FROM (
        SELECT
          sp.station_id                                   AS station_id,
          s.station_name                                  AS station_name,
          s.station_ext_id                                AS station_external_id,
          sp.param_id                                     AS parameter_id,
          p.param_name                                    AS parameter_name,
          p.param_unit                                    AS parameter_unit,
          sp.stpr_table_id                                AS series_id,
          sp.stpr_ext_id                                  AS series_external_id,
          spi.stpr_export_id1                             AS series_export_id1,
          spi.stpr_export_id2                             AS series_export_id2,
          spi.stpr_info_ws_id                             AS series_ws_id,
          CONCAT_WS(' - ', p.param_name, sp.stpr_note)    AS series_name,
          (
            SELECT array_to_json(array_agg(row_to_json(d)))
            FROM webservice.f_data_extraction (
              sp.stpr_id::integer,
              date_trunc('hour', to_timestamp(${ep1}))::timestamp,
              date_trunc('hour', to_timestamp(${ep2}))::timestamp
            ) d
          )                                               AS series_data
        FROM
          metadata.stations_parameters sp
          LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
          LEFT JOIN metadata.stations s USING (station_id)
          LEFT JOIN metadata.parameters p USING (param_id)
        WHERE
          sp.stpr_id = ${series_id}
      ) t
    `).first;
  }

  /**
   * Get data from series id, latest days
   * @returns list of data series objects
   */
  async getDailyDataBySeriesIdDays(series_id, days) {
    return (await this.pg.query`
      SELECT row_to_json(t) AS data FROM (
        SELECT
          sp.station_id                                   AS station_id,
          s.station_name                                  AS station_name,
          s.station_ext_id                                AS station_external_id,
          sp.param_id                                     AS parameter_id,
          p.param_name                                    AS parameter_name,
          p.param_unit                                    AS parameter_unit,
          sp.stpr_table_id                                AS series_id,
          sp.stpr_ext_id                                  AS series_external_id,
          spi.stpr_export_id1                             AS series_export_id1,
          spi.stpr_export_id2                             AS series_export_id2,
          spi.stpr_info_ws_id                             AS series_ws_id,
          CONCAT_WS(' - ', p.param_name, sp.stpr_note)    AS series_name,
          (
            SELECT array_to_json(array_agg(row_to_json(d)))
            FROM webservice.f_data_extraction_v2 (
              sp.stpr_id::integer,
              ( CURRENT_DATE - ${days} * interval '1 day' ):: timestamp without time zone,
              ( CURRENT_DATE + time '23:59:59' ):: timestamp without time zone,
              'dd'::metadata.e_aggregations
            ) d
          )                                               AS series_data
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.parameters p USING (param_id)
        WHERE
            sp.stpr_id = ${series_id}
      ) t
    `).first;
  }

  /**
   * Get data from series id, from epoch time 1 and 2
   * @returns list of data series objects
   */
  async getDailyDataBySeriesIdEpochTimes(series_id, ep1, ep2) {
    return (await this.pg.query`
      SELECT row_to_json(t) AS data FROM (
        SELECT
          sp.station_id                                   AS station_id,
          s.station_name                                  AS station_name,
          s.station_ext_id                                AS station_external_id,
          sp.param_id                                     AS parameter_id,
          p.param_name                                    AS parameter_name,
          p.param_unit                                    AS parameter_unit,
          sp.stpr_table_id                                AS series_id,
          sp.stpr_ext_id                                  AS series_external_id,
          spi.stpr_export_id1                             AS series_export_id1,
          spi.stpr_export_id2                             AS series_export_id2,
          spi.stpr_info_ws_id                             AS series_ws_id,
          CONCAT_WS(' - ', p.param_name, sp.stpr_note)    AS series_name,
          (
            SELECT array_to_json(array_agg(row_to_json(d)))
            FROM webservice.f_data_extraction_v2 (
              sp.stpr_id::integer,
              ( DATE_TRUNC('day', to_timestamp(${ep1})) )::timestamp without time zone,
              ( DATE_TRUNC('day', to_timestamp(${ep2})) + time '23:59:59')::timestamp without time zone,
              'dd'::metadata.e_aggregations
            ) d
          )                                               AS series_data
        FROM
          metadata.stations_parameters sp
          LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
          LEFT JOIN metadata.stations s USING (station_id)
          LEFT JOIN metadata.parameters p USING (param_id)
        WHERE
          sp.stpr_id = ${series_id}
      ) t
    `).first;
  }

  /**
 * Get last edited data from series id and epoch time
 * @returns list of data series objects
 */
  async getLastEditedDataBySeriesIdEpochTime(series_id, ep) {
    return (await this.pg.query`
      SELECT row_to_json(t) AS data FROM (
        SELECT
          sp.station_id                                   AS station_id,
          s.station_name                                  AS station_name,
          s.station_ext_id                                AS station_external_id,
          sp.param_id                                     AS parameter_id,
          p.param_name                                    AS parameter_name,
          p.param_unit                                    AS parameter_unit,
          sp.stpr_table_id                                AS series_id,
          sp.stpr_ext_id                                  AS series_external_id,
          spi.stpr_export_id1                             AS series_export_id1,
          spi.stpr_export_id2                             AS series_export_id2,
          spi.stpr_info_ws_id                             AS series_ws_id,
          CONCAT_WS(' - ', p.param_name, sp.stpr_note)    AS series_name,
          (
            SELECT array_to_json(array_agg(row_to_json(d)))
            FROM webservice.f_last_edited_data_extraction (
              sp.stpr_id::integer,
              to_timestamp(${ep})::timestamp
            ) d
          )                                               AS series_data
        FROM
          metadata.stations_parameters sp
          LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
          LEFT JOIN metadata.stations s USING (station_id)
          LEFT JOIN metadata.parameters p USING (param_id)
        WHERE
          sp.stpr_id = ${series_id}
      ) t
    `).first;
  }

  /**
  * Get last edited data from series id and epoch time
  * @returns list of data series objects
  */
  async getLastEditedDataByRegionIdEpochTime(region_id, ep) {
    return (await this.pg.query`
      WITH s AS(
        SELECT
          s.station_id     AS station_id,
          s.station_name   AS station_name,
          s.station_ext_id AS station_external_id
        FROM
          metadata.stations s
          LEFT JOIN metadata.stations_municipality stm USING (station_id)
          LEFT JOIN main.province_municipalities prm USING (mu_id)
          LEFT JOIN main.region_provinces rp USING (province_id)
          LEFT JOIN main.regions r USING (region_id)
        WHERE
          r.region_id = ${region_id}
      )
      SELECT array_to_json(array_agg(row_to_json(ss))) AS stations FROM (
        SELECT
          station_id,
          station_name,
          station_external_id,
          (
            SELECT array_to_json(array_agg(row_to_json(t))) AS data FROM (
              SELECT
                sp.param_id                                     AS parameter_id,
                p.param_name                                    AS parameter_name,
                p.param_unit                                    AS parameter_unit,
                sp.stpr_table_id                                AS series_id,
                sp.stpr_ext_id                                  AS series_external_id,
                spi.stpr_export_id1                             AS series_export_id1,
                spi.stpr_export_id2                             AS series_export_id2,
                spi.stpr_info_ws_id                             AS series_ws_id,
                CONCAT_WS(' - ', p.param_name, sp.stpr_note)    AS series_name,
                (
                  SELECT array_to_json(array_agg(row_to_json(d)))
                  FROM webservice.f_last_edited_data_extraction (
                    sp.stpr_id::integer,
                    to_timestamp(${ep})::timestamp
                  ) d
                )                                               AS series_data
              FROM
                s s2
                LEFT JOIN metadata.stations_parameters sp USING (station_id)
                LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
              WHERE
                pi.pm_info_type_fk IN (2,3)
                -- update 20/08/2024 14:53
                -- AND sp.param_id != 648 -- remove Hg
                AND s2.station_id = s.station_id
              ORDER BY
                series_id
            ) t
          ) AS parameters
        FROM s
        ORDER BY station_id
      ) ss
    `).first;
  }

  /**
  * Get last edited data from series id and epoch time
  * @returns list of data series objects
  */
  async getLastEditedDataByStationIdEpochTime(station_id, ep) {
    return (await this.pg.query`
      SELECT row_to_json(s) AS station FROM (
        SELECT
          s.station_id     AS station_id,
          s.station_name   AS station_name,
          s.station_ext_id AS station_external_id,
          (
            SELECT array_to_json(array_agg(row_to_json(t))) AS data FROM (
              SELECT
                sp.param_id                                     AS parameter_id,
                p.param_name                                    AS parameter_name,
                p.param_unit                                    AS parameter_unit,
                sp.stpr_table_id                                AS series_id,
                sp.stpr_ext_id                                  AS series_external_id,
                spi.stpr_export_id1                             AS series_export_id1,
                spi.stpr_export_id2                             AS series_export_id2,
                spi.stpr_info_ws_id                             AS series_ws_id,
                CONCAT_WS(' - ', p.param_name, sp.stpr_note)    AS series_name,
                (
                  SELECT array_to_json(array_agg(row_to_json(d)))
                  FROM webservice.f_last_edited_data_extraction (
                    sp.stpr_id::integer,
                    to_timestamp(${ep})::timestamp
                  ) d
                )                                               AS series_data
              FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
                LEFT JOIN metadata.stations s USING (station_id)
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
              WHERE
                station_id = ${station_id}
                AND pi.pm_info_type_fk IN (2,3)
                -- update 20/08/2024 14:53
                -- AND sp.param_id != 648 -- remove Hg
              ORDER BY
                series_id
            ) t
          ) AS parameters
        FROM
          metadata.stations s
        WHERE
          station_id = ${station_id}
      ) s
    `).first;
  }
}

/*
--table metadata.parameters_type;
1	Meteo
2	Chimici
3	Polveri
4	Metalli
5	IPA
6	Ioni
7	ECOC
8	BC
9	Levoglucosano
10	Deposizioni metalli
11	OPC
12	Taratura
13	Diagnostici
14	Allarmi
15	Stato
16	Falda
17	Aria
18	Limiti
19	Gravimetrici
20	Metalli in continuo
21	Diossine su PM10
22	Deposizioni diossine
23	Deposizioni IPA
24	Campionatori passivi
*/
