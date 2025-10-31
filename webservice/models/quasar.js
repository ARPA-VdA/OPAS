export class Quasar {
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
              webservice.qapp_stations
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
              *
          FROM
              webservice.qapp_stations_detail
          WHERE
            id = ${id}
      ) t
    `).first;
  }

  /**
    * Get online users
    * @returns list of users
    */
  async getUsersOnline() {
    return (await this.pg.query`
      SELECT array_to_json(array_agg(row_to_json(t))) AS users FROM (
        SELECT
            us_id AS us_id,
            us_name||' '||us_surname AS user_name,
            to_char(aur_insert_ts, 'DD/MM/YYYY HH24:MI') AS user_last_time
        FROM
            audit.active_users_rt aur
            left join bobo.users using (us_id)
        ORDER BY
            aur_insert_ts
      ) t
    `).first;
  }

  /**
 *
 * @param id the user id
 * @returns single user
 */
  async getUser(id) {
    // user_id, user_active, user_name, user_second_name, user_surname, user_email,
    // user_phone, user_mobile, user_role, user_password, user_avatar, user_avatar_thumb,
    // user_expiration_time, user_first_log, groups_id, groups_name, company_id,
    // company_name, company_desc, company_title, company_logo, company_thumb_logo,
    // company_address, company_phone, company_web, company_email, portal_id,
    // portal_name, portal_desc, portal_extra_desc
    return (await this.pg.query`
      SELECT row_to_json(t) AS user FROM (
          SELECT
            user_id,
            user_active,
            user_name,
            --user_second_name,
            user_surname,
            user_email,
            user_phone,
            user_mobile,
            user_role,
            --user_password,
            --user_avatar,
            user_avatar_thumb,
            'https://opas.isprambiente.it' || user_avatar_thumb AS user_avatar_url,
            --user_expiration_time,
            --user_first_log,
            --groups_id,
            groups_name,
            --company_id,
            company_name,
            company_desc,
            --company_title,
            --company_logo,
            --company_thumb_logo,
            --company_address,
            --company_phone,
            --company_web,
            --company_email,
            --portal_id,
            portal_name
            --portal_desc,
            --portal_extra_desc
          FROM
              bobo.view_users
          WHERE
            user_id = ${id}
      ) t
    `).first;
  }
}
