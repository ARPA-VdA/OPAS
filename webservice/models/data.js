export class Data {
  constructor(pg) {
    this.pg = pg;
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
          sp.stpr_ext_id                                  AS parameter_external_id,
          p.param_name                                    AS parameter_name,
          p.param_unit                                    AS parameter_unit,
          sp.stpr_table_id                                AS series_id,
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
          sp.stpr_ext_id                                  AS parameter_external_id,
          p.param_name                                    AS parameter_name,
          p.param_unit                                    AS parameter_unit,
          sp.stpr_table_id                                AS series_id,
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
          sp.stpr_ext_id                                  AS parameter_external_id,
          p.param_name                                    AS parameter_name,
          p.param_unit                                    AS parameter_unit,
          sp.stpr_table_id                                AS series_id,
          CONCAT_WS(' - ', p.param_name, sp.stpr_note)    AS series_name,
          (
            SELECT array_to_json(array_agg(row_to_json(d)))
            FROM webservice.f_last_edited_data_extraction (
              sp.stpr_id::integer,
              date_trunc('hour', to_timestamp(${ep}))::timestamp
            ) d
          )                                               AS series_data
        FROM
          metadata.stations_parameters sp
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
                sp.stpr_ext_id                                  AS parameter_external_id,
                p.param_name                                    AS parameter_name,
                p.param_unit                                    AS parameter_unit,
                sp.stpr_table_id                                AS series_id,
                CONCAT_WS(' - ', p.param_name, sp.stpr_note)    AS series_name,
                (
                  SELECT array_to_json(array_agg(row_to_json(d)))
                  FROM webservice.f_last_edited_data_extraction (
                    sp.stpr_id::integer,
                    date_trunc('hour', to_timestamp(${ep}))::timestamp
                  ) d
                )                                      AS series_data
              FROM
                s s2
                LEFT JOIN metadata.stations_parameters sp USING (station_id)
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
              WHERE
                pi.pm_info_type_fk IN (2,3)
                AND sp.param_id != 648 -- remove Hg
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
                sp.stpr_ext_id                                  AS parameter_external_id,
                p.param_name                                    AS parameter_name,
                p.param_unit                                    AS parameter_unit,
                sp.stpr_table_id                                AS series_id,
                CONCAT_WS(' - ', p.param_name, sp.stpr_note)    AS series_name,
                (
                  SELECT array_to_json(array_agg(row_to_json(d)))
                  FROM webservice.f_last_edited_data_extraction (
                    sp.stpr_id::integer,
                    date_trunc('hour', to_timestamp(${ep}))::timestamp
                  ) d
                )                                               AS series_data
              FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.stations s USING (station_id)
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
              WHERE
                station_id = ${station_id}
                AND pi.pm_info_type_fk IN (2,3)
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
