import moment from 'moment';
import pkg from 'node-gzip';
const { gzip, ungzip } = pkg;
import sizeof from 'object-sizeof';
import byteSize from 'byte-size';
// const { gzip, ungzip } = require('node-gzip');

export default class DataController {

  /**
   * Get available data per single series
   */
  async series(ctx) {
    ctx.log.info("series");

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
    ctx.log.info("seriesFrame");

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
    ctx.log.info(`epoch ${epoch1}`);
    ctx.log.info(`epoch ${epoch2}`);

    // get data from db
    var json_data = await ctx.models.data.getDataBySeriesIdEpochTimes(
      ctx.stash.id,
      epoch1,
      epoch2
    );
    await ctx.render({ json: json_data });
  }

  /**
   * Get last available data per single series and date start
   */
  async seriesSynchroFrame(ctx) {
    ctx.log.info("seriesSynchroFrame");

    // get param
    ctx.log.info(`series ${ctx.stash.id}`);
    ctx.log.info(`ep ${ctx.stash.ep}`);
    // get epoch time
    var epoch = ctx.stash.ep;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep)) {
      epoch = moment(ctx.stash.ep).unix();
    }
    ctx.log.info(`epoch ${epoch}`);

    // get data from db
    var json_data = await ctx.models.data.getLastEditedDataBySeriesIdEpochTime(
      ctx.stash.id,
      epoch
    );
    await ctx.render({ json: json_data });
  }

  /**
   * Get last available data per all series in a region and date start
   */
  async seriesSynchroFrameRegion(ctx) {
    ctx.log.info("seriesSynchroFrameRegion");

    // get param
    ctx.log.info(`region ${ctx.stash.id}`);
    ctx.log.info(`ep ${ctx.stash.ep}`);
    // get epoch time
    var epoch = ctx.stash.ep;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep)) {
      epoch = moment(ctx.stash.ep).unix();
    }
    ctx.log.info(`epoch ${epoch}`);

    // get data from db
    ctx.log.info("get data from db");
    var json_data = await ctx.models.data.getLastEditedDataByRegionIdEpochTime(
      ctx.stash.id,
      epoch
    );

    // get object size
    var sizeObj = sizeof(json_data)
    ctx.log.trace(`size of the JSON object: ${byteSize(sizeObj)}`)

    // return data
    await ctx.render({ json: json_data });
  }

  /**
    * Get last available data per all series in a station and date start
    */
  async seriesSynchroFrameStation(ctx) {
    ctx.log.info("seriesSynchroFrameStation");

    // get param
    ctx.log.info(`station ${ctx.stash.id}`);
    ctx.log.info(`ep ${ctx.stash.ep}`);
    // get epoch time
    var epoch = ctx.stash.ep;
    if (/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(ctx.stash.ep)) {
      epoch = moment(ctx.stash.ep).unix();
    }
    ctx.log.info(`epoch ${epoch}`);

    // get data from db
    ctx.log.info("get data from db");
    var json_data = await ctx.models.data.getLastEditedDataByStationIdEpochTime(
      ctx.stash.id,
      epoch
    );

    // get object size
    var sizeObj = sizeof(json_data)
    ctx.log.trace(`size of the JSON object: ${byteSize(sizeObj)}`)

    let json_string = JSON.stringify(json_data);

    const compressed = await gzip(json_string);
    ctx.log.trace(`size of the JSON compressed: ${compressed.length}`)

    // return data
    ctx.render({ text: compressed, format: 'application/json' });

    // return data
    // await ctx.render({ json: json_data });
  }
}
