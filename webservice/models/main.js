export class Main {
  constructor(pg) {
    this.pg = pg;
  }

  /**
   * Get organization information
   * @returns organization infos
   */
  async getOrganization() {
    return (await this.pg.query`
      SELECT row_to_json (t) AS organization FROM (
          SELECT
              *
          FROM
              webservice.v1_organization
      ) t
    `).first;
  }

  /**
   * * Get an user from db
   * ! deprecated
   * ? always
   * todo let user login
   * @param user User data object from client, bearing mail and password
   * @returns User from database
   */
  async getUser(user, groups) {
    return (await this.pg.query`
      SELECT
        us_id, us_name, us_surname
      FROM
        bobo.users u
      WHERE
        us_email = ${user.email}
      AND
        us_pwd = crypt(${user.password}, us_pwd)
      AND EXISTS (
        SELECT 1
        FROM
            bobo.user_groups ug
        WHERE
            ug.gr_id::text = ANY(${groups})
            AND ug.us_id = u.us_id
        LIMIT 1
      )
    `).first;
  }
}
