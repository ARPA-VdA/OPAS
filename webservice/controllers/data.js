import moment from 'moment';
import pkg from 'node-gzip';
const { gzip, ungzip } = pkg;
import sizeof from 'object-sizeof';
import byteSize from 'byte-size';
// const { gzip, ungzip } = require('node-gzip');

export default class DataController {

  /**
     * Get station log
     * @param id station id
     */
  async stationLog(ctx) {
    ctx.log.info("Function stationLog");

    // get param
    ctx.log.info(`station ${ctx.stash.stid}`);
    ctx.log.info(`ep1 ${ctx.stash.ep1}`);
    ctx.log.info(`ep2 ${ctx.stash.ep2}`);

    // get epoch time
    var epoch1 = ctx.stash.ep1;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep1)) {
      epoch1 = moment(ctx.stash.ep1).unix();
    }
    var epoch2 = ctx.stash.ep2;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep2)) {
      epoch2 = moment(ctx.stash.ep2).unix();
    }
    ctx.log.debug(`epoch ${epoch1}`);
    ctx.log.debug(`epoch ${epoch2}`);

    // get data from db
    var json_data = await ctx.models.data.getStationLog(ctx.stash.stid, epoch1, epoch2);
    await ctx.render({ json: json_data || {} });
  }


  /**
   * Get available data per single series
   */
  async series(ctx) {
    ctx.log.info("Function series");

    // get param
    ctx.log.info(`series ${ctx.stash.id}`);
    ctx.log.info(`time ${ctx.stash.hh}`);

    // get data from db
    var json_data = await ctx.models.data.getDataBySeriesIdHours(
      ctx.stash.id,
      ctx.stash.hh
    );
    await ctx.render({ json: json_data });
  }

  /**
   * Get available data per single series and date start - end
   */
  async seriesFrame(ctx) {
    ctx.log.info("Function seriesFrame");

    // get param
    ctx.log.info(`series ${ctx.stash.id}`);
    ctx.log.info(`ep1 ${ctx.stash.ep1}`);
    ctx.log.info(`ep2 ${ctx.stash.ep2}`);

    // get epoch time
    var epoch1 = ctx.stash.ep1;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep1)) {
      epoch1 = moment(ctx.stash.ep1).unix();
    }
    var epoch2 = ctx.stash.ep2;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep2)) {
      epoch2 = moment(ctx.stash.ep2).unix();
    }
    ctx.log.debug(`epoch ${epoch1}`);
    ctx.log.debug(`epoch ${epoch2}`);

    // get data from db
    var json_data = await ctx.models.data.getDataBySeriesIdEpochTimes(
      ctx.stash.id,
      epoch1,
      epoch2
    );
    await ctx.render({ json: json_data });
  }

  /**
   * Get available daily data per single series
   */
  async dailySeries(ctx) {
    ctx.log.info("Function dailySeries");

    // get param
    ctx.log.info(`series ${ctx.stash.id}`);
    ctx.log.info(`days ${ctx.stash.dd}`);

    // get data from db
    var json_data = await ctx.models.data.getDailyDataBySeriesIdDays(
      ctx.stash.id,
      ctx.stash.dd
    );
    await ctx.render({ json: json_data });
  }

  /**
   * Get available daily data per single series and date start - end
   */
  async dailySeriesFrame(ctx) {
    ctx.log.info("Function dailySeriesFrame");

    // get param
    ctx.log.info(`series ${ctx.stash.id}`);
    ctx.log.info(`ep1 ${ctx.stash.ep1}`);
    ctx.log.info(`ep2 ${ctx.stash.ep2}`);

    // get epoch time
    var epoch1 = ctx.stash.ep1;
    if (/\d{4}-\d{2}-\d{2}/.test(ctx.stash.ep1)) {
      epoch1 = moment(ctx.stash.ep1).unix();
    }
    var epoch2 = ctx.stash.ep2;
    if (/\d{4}-\d{2}-\d{2}/.test(ctx.stash.ep2)) {
      epoch2 = moment(ctx.stash.ep2).unix();
    }
    ctx.log.debug(`epoch ${epoch1}`);
    ctx.log.debug(`epoch ${epoch2}`);

    // get data from db
    var json_data = await ctx.models.data.getDailyDataBySeriesIdEpochTimes(
      ctx.stash.id,
      epoch1,
      epoch2
    );
    await ctx.render({ json: json_data });
  }


  /**
   * Get last available data per single series and date start
   */
  async seriesSynchroFrameSeries(ctx) {
    ctx.log.info("Function seriesSynchroFrameSeries");

    // get param
    ctx.log.info(`series ${ctx.stash.id}`);
    ctx.log.info(`ep ${ctx.stash.ep}`);
    // get epoch time
    var epoch = ctx.stash.ep;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep)) {
      epoch = moment(ctx.stash.ep).unix();
    }
    ctx.log.info(`epoch ${epoch}`);

    try {
      // get data from db
      ctx.log.info("get data from db");
      var json_data = await ctx.models.data.getLastEditedDataBySeriesIdEpochTime(
        ctx.stash.id,
        epoch
      );
      ctx.log.debug("done");

      // get object size
      // var sizeObj = sizeof(json_data)
      // ctx.log.trace(`size of the JSON object: ${byteSize(sizeObj)}`)

      // compress data
      let json_string = JSON.stringify(json_data);
      const compressed = await gzip(json_string);
      ctx.log.trace(`size of the JSON compressed: ${compressed.length}`)

      // return data
      ctx.render({ text: compressed, format: 'json' });

    } catch ({ name, message }) {
      // return error
      ctx.log.error(`An error occured: ${message}`)
      await ctx.render({ text: 'An error occured.', status: 500 });
    }
  }

  /**
    * Get last available data per all series in a station and date start
    */
  async seriesSynchroFrameStation(ctx) {
    ctx.log.info("Function seriesSynchroFrameStation");

    // get param
    ctx.log.info(`station ${ctx.stash.id}`);
    ctx.log.info(`ep ${ctx.stash.ep}`);
    // get epoch time
    var epoch = ctx.stash.ep;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep)) {
      epoch = moment(ctx.stash.ep).unix();
    }
    ctx.log.debug(`epoch ${epoch}`);

    try {
      // get data from db
      ctx.log.info("get data from db");
      var json_data = await ctx.models.data.getLastEditedDataByStationIdEpochTime(
        ctx.stash.id,
        epoch
      );
      ctx.log.debug("done");

      // get object size
      // var sizeObj = sizeof(json_data)
      // ctx.log.trace(`size of the JSON object: ${byteSize(sizeObj)}`)

      // compress data
      let json_string = JSON.stringify(json_data);
      const compressed = await gzip(json_string);
      ctx.log.trace(`size of the JSON compressed: ${compressed.length}`)

      // return data
      await ctx.render({ text: compressed, format: 'json' });

    } catch ({ name, message }) {
      // return error
      ctx.log.error(`An error occured: ${message}`)
      await ctx.render({ text: 'An error occured.', status: 500 });
    }
  }

  /**
   * Get last available data per all series in a region and date start
   */
  async seriesSynchroFrameRegion(ctx) {
    ctx.log.info("Function seriesSynchroFrameRegion");

    // get param
    ctx.log.info(`region ${ctx.stash.id}`);
    ctx.log.info(`ep ${ctx.stash.ep}`);
    // get epoch time
    var epoch = ctx.stash.ep;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep)) {
      epoch = moment(ctx.stash.ep).unix();
    }
    ctx.log.debug(`epoch ${epoch}`);

    try {
      // get data from db
      ctx.log.info("get data from db");
      var json_data = await ctx.models.data.getLastEditedDataByRegionIdEpochTime(
        ctx.stash.id,
        epoch
      );
      ctx.log.debug("done");

      // get object size
      // var sizeObj = sizeof(json_data)
      // ctx.log.trace(`size of the JSON object: ${byteSize(sizeObj)}`)

      // compress data
      let json_string = JSON.stringify(json_data);
      const compressed = await gzip(json_string);
      ctx.log.trace(`size of the JSON compressed: ${compressed.length}`)

      // return data
      await ctx.render({ text: compressed, format: 'json' });

    } catch ({ name, message }) {
      // return error
      ctx.log.error(`An error occured: ${message}`)
      await ctx.render({ text: 'An error occured.', status: 500 });
    }
  }

}
