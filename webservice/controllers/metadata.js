import moment from 'moment';
export default class MetadataController {

  /**
   * Get available stations
   */
  async stations(ctx) {
    ctx.log.info("stations");

    // get data from db
    var json_data = await ctx.models.metadata.getStations();
    await ctx.render({ json: json_data || {} });
  }

  /**
   * Get available stations per region
   */
  async stationsRegion(ctx) {
    ctx.log.info("stationsRegion");

    // get param
    ctx.log.info(`region ${ctx.stash.id}`);

    // get data from db
    var json_data = await ctx.models.metadata.getStationsRegion(ctx.stash.id);
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
    var json_data = await ctx.models.metadata.getStation(ctx.stash.id);
    await ctx.render({ json: json_data || {} });
  }

  /**
 * Get available parameters
 */
  async parameters(ctx) {
    ctx.log.info("parameters");

    // get data from db
    var json_data = await ctx.models.metadata.getParameters();
    await ctx.render({ json: json_data || {} });
  }

  /**
   * Get single parameter
   * @param id parameter id
   */
  async parameter(ctx) {
    ctx.log.info("parameter");

    // get param
    ctx.log.info(`parameter ${ctx.stash.id}`);

    // get data from db
    var json_data = await ctx.models.metadata.getParameter(ctx.stash.id);
    await ctx.render({ json: json_data || {} });
  }

  /**
   * Get station parameter series
   * @param id parameter id
   */
  async stationParameters(ctx) {
    ctx.log.info("stationParameters");

    // get param
    ctx.log.info(`parameter ${ctx.stash.stid}`);
    ctx.log.info(`parameter ${ctx.stash.prid}`);

    // get data from db
    var json_data = await ctx.models.metadata.getStationParameters(ctx.stash.stid, ctx.stash.prid);
    await ctx.render({ json: json_data || {} });
  }

  /**
   * Get available sites
   */
  async sites(ctx) {
    ctx.log.info("sites");

    // get data from db
    var json_data = await ctx.models.metadata.getSites();
    await ctx.render({ json: json_data || {} });
  }

  /**
   * Get campaings per station
   * @param id station id
   */
  async campaigns(ctx) {
    ctx.log.info("campaigns");

    // get param
    ctx.log.info(`parameter ${ctx.stash.id}`);

    // get data from db
    var json_data = await ctx.models.metadata.getCampaigns(ctx.stash.id);
    await ctx.render({ json: json_data || {} });
  }

  /**
  * Get campaings per station
  * @param id station id
  */
  async campaignsDates(ctx) {
    ctx.log.info("campaignsDates");

    // get param
    ctx.log.info(`parameter ${ctx.stash.id}`);
    ctx.log.info(`parameter ${ctx.stash.ep}`);

    // get epoch time
    var epoch = ctx.stash.ep;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep)) {
      epoch = moment(ctx.stash.ep).unix();
    }
    ctx.log.info(`epoch ${epoch}`);

    // get data from db
    var json_data = await ctx.models.metadata.getCampaignsDates(
      ctx.stash.id,
      epoch
    );
    await ctx.render({ json: json_data || {} });
  }

  /**
  * Get available series
  */
  async series(ctx) {
    ctx.log.info("series");

    // get data from db
    var json_data = await ctx.models.metadata.getSeries();
    await ctx.render({ json: json_data || {} });
  }

  /**
  * Get available series per region
  */
  async seriesRegion(ctx) {
    ctx.log.info("seriesRegion");

    // get param
    ctx.log.info(`parameter ${ctx.stash.id}`);

    // get data from db
    var json_data = await ctx.models.metadata.getSeriesRegion(ctx.stash.id);
    await ctx.render({ json: json_data || {} });
  }

  /**
* Get available series per station
*/
  async seriesStation(ctx) {
    ctx.log.info("seriesStation");

    // get param
    ctx.log.info(`parameter ${ctx.stash.id}`);

    // get data from db
    var json_data = await ctx.models.metadata.getSeriesStation(ctx.stash.id);
    await ctx.render({ json: json_data || {} });
  }
}
