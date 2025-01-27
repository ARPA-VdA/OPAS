export class Metadata {
  constructor(pg) {
    this.pg = pg;
  }

  /**
   * Get all available stations
   * @returns list of stations
   */
  async getStations() {
    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS stations FROM (
          SELECT
              *
          FROM
              webservice.v1_stations
      ) t
    `).first;
  }

  /**
   * Get all available stations per region
   * @param id the region id
   * @returns list of stations
   */
  async getStationsRegion(id) {
    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS stations FROM (
          SELECT
              *
          FROM
              webservice.v1_stations
          WHERE
            region_istat_code = ${id}
      ) t
    `).first;
  }

  /**
    * Get all available parameters
    * @returns list of parameters
    */
  async getParameters() {
    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS parameters FROM (
          SELECT
              *
          FROM
              webservice.v1_parameters
      ) t
    `).first;
  }

  /**
   *
   * @param id the parameter id
   * @returns single parameter
   */
  async getParameter(id) {
    return (await this.pg.query`
      SELECT row_to_json(t) AS parameter FROM (
        SELECT
            *
        FROM
            webservice.v1_parameters
        WHERE
          id = ${id}
      ) t
    `).first;
  }

  /**
 *
 * @param id the station id
 * @returns single station
 */
  async getStation(id) {
    return (await this.pg.query`
      SELECT row_to_json(t) AS station FROM (
          SELECT
              wss.id          AS id,
              wss.name        AS name,
              wss.external_id AS external_id,
              wss.export_id   AS export_id,
              (
                  SELECT array_to_json(array_agg(row_to_json(p))) AS parameters FROM (
                      SELECT
                          sp.stpr_id                                                  AS series_id,
                          wsp.name || COALESCE(' - '::text || sp.stpr_note, ''::text) AS series_name,
                          sp.stpr_table_id                                            AS database_id,
                          wsp.id                                                      AS id,
                          sp.stpr_ext_id                                              AS external_id,
                          spi.stpr_export_id1                                         AS export_id1,
                          spi.stpr_export_id2                                         AS export_id2,
                          wsp.name                                                    AS name,
                          wsp.unit                                                    AS unit,
                          wsp.conversion_factor_curr                                  AS conversion_factor_curr,
                          wsp.conversion_history                                      AS conversion_history,
                          wsp.conversion_unit                                         AS conversion_unit,
                          wsp.decimals                                                AS decimals,
                          wsp.active                                                  AS active,
                          wsp.note                                                    AS note
                      FROM
                          metadata.stations_parameters sp
                          LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
                          LEFT JOIN webservice.v1_parameters wsp ON sp.param_id = wsp.id
                      WHERE
                          sp.station_id = wss.id
                  ) p
              )
          FROM
              webservice.v1_stations wss
          WHERE
              wss.id = ${id}
      ) t
    `).first;
  }

  /**
   *
   * @param stid the station id
   * @param prid the parameter id
   * @returns single station
   */
  async getStationParameters(stid, prid) {
    return (await this.pg.query`
      SELECT row_to_json(t) AS station FROM (
          SELECT
              wss.id          AS id,
              wss.name        AS name,
              wss.external_id AS external_id,
              wss.export_id   AS export_id,
              (
                  SELECT array_to_json(array_agg(row_to_json(p))) AS parameters FROM (
                      SELECT
                          sp.stpr_id                                                  AS series_id,
                          wsp.name || COALESCE(' - '::text || sp.stpr_note, ''::text) AS series_name,
                          sp.stpr_table_id                                            AS database_id,
                          wsp.id                                                      AS id,
                          sp.stpr_ext_id                                              AS external_id,
                          spi.stpr_export_id1                                         AS export_id1,
                          spi.stpr_export_id2                                         AS export_id2,
                          wsp.name                                                    AS name,
                          wsp.unit                                                    AS unit,
                          wsp.conversion_factor_curr                                  AS conversion_factor_curr,
                          wsp.conversion_history                                      AS conversion_history,
                          wsp.conversion_unit                                         AS conversion_unit,
                          wsp.decimals                                                AS decimals,
                          wsp.active                                                  AS active,
                          wsp.note                                                    AS note
                      FROM
                          metadata.stations_parameters sp
                          LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
                          LEFT JOIN webservice.v1_parameters wsp ON sp.param_id = wsp.id
                      WHERE
                          sp.station_id = wss.id
                      AND
                          sp.param_id = ${prid}
                  ) p
              )
          FROM
              webservice.v1_stations wss
          WHERE
              wss.id = ${stid}
      ) t
    `).first;
  }

  /**
   * Get all available sites
   * @returns list of sites
   */
  async getSites() {
    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS sites FROM (
          SELECT
              *
          FROM
              webservice.v1_sites
      ) t
    `).first;
  }

  /**
   *
   * @param id the station id
   * @returns available campaigns
   */
  async getCampaigns(id) {

    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS allocations FROM (
          SELECT
              *
          FROM
              webservice.v1_sites_allocations
          WHERE
              station_id = ${id}
      ) t
    `).first;
  }

  /**
   *
   * @param id the station id
   * @param ep the date in epoch time
   * @returns available allocations
   */
  async getCampaignsDates(id, ep) {

    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS allocations FROM (
          SELECT
              *
          FROM
              webservice.v1_sites_allocations
          WHERE
              station_id = ${id}
          AND
              tsrange(allocation_startup_date, allocation_dismiss_date, '[]') @> (to_timestamp(${ep})::timestamp)
      ) t
    `).first;
  }

  /**
    * Get all available series
    * @returns list of series
    */
  async getSeries() {
    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS series FROM (
          SELECT
                *
            FROM
                webservice.v1_series
      ) t
    `).first;
  }

  /**
    * Get all available series per region
   * @param id the region id
    * @returns list of series
    */
  async getSeriesRegion(id) {
    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS series FROM (
          SELECT
                *
            FROM
                webservice.v1_series
          WHERE
            region_istat_code = ${id}
      ) t
    `).first;
  }

  /**
    * Get all available series per station
   * @param id the station id
    * @returns list of series
    */
  async getSeriesStation(id) {
    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS series FROM (
          SELECT
                *
            FROM
                webservice.v1_series
          WHERE
            station_id = ${id}
      ) t
    `).first;
  }
}
