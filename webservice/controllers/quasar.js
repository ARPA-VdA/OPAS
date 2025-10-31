export default class QuasarController {

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
 * Get available stations
 */
  async stations(ctx) {
    ctx.log.info("stations");

    // get data from db
    var json_data = await ctx.models.quasar.getStations();
    await ctx.render({ json: json_data || {} });
  }

  /**
 * Get single station & owned parameters
 * @param id station id
 */
  async station(ctx) {
    ctx.log.info("station");

    // get param
    ctx.log.info(`station ${ctx.stash.id}`);

    // get data from db
    var json_data = await ctx.models.quasar.getStation(ctx.stash.id);
    await ctx.render({ json: json_data || {} });
  }

  /**
   * Get online users
   */
  async usersOnline(ctx) {
    ctx.log.info("usersOnline");

    // get data from db
    var json_data = await ctx.models.quasar.getUsersOnline();
    await ctx.render({ json: json_data });
  }

  /**
   * Get user info
   */
  async user(ctx) {
    ctx.log.info("user");

    // get param
    ctx.log.info(`user ${ctx.stash.id}`);

    // get data from db
    var json_data = await ctx.models.quasar.getUser(ctx.stash.id);
    // await this.sleep(1000)
    await ctx.render({ json: json_data || {} });
  }
}
