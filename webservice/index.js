import mojo, { yamlConfigPlugin, Logger } from '@mojojs/core';
import Pg from '@mojojs/pg';
import Path from '@mojojs/path';
import { Main } from './models/main.js';
import { Metadata } from './models/metadata.js';
import { Data } from './models/data.js';
import { Quasar } from './models/quasar.js';
import helperPlugin from './plugin/helper.js';
import * as rfs from 'rotating-file-stream'
// const rfs = require("rotating-file-stream");
// import * as fs from 'fs'; // see https://github.com/mojolicious/mojo.js/blob/main/src/logger.ts
// import 'dotenv/config'; // see https://github.com/motdotla/dotenv#how-do-i-use-dotenv-with-import
//ctx.log.debug(process.env); // remove this after you've confirmed it is working

// Main app
export const app = mojo({
  // Format for HTTP exceptions ("html", "json", or "txt")
  exceptionFormat: 'json',
  // Operating mode for application development | productionW
  // From env variable - NODE_ENV=production
  //mode: 'development'
});
const router = app.router;

// Enable cors
app.addContextHook('router:before', async ctx => {
  ctx.res.set('Access-Control-Allow-Origin', '*');
  ctx.res.set('Access-Control-Allow-Methods', 'GET, POST');
  ctx.res.set('Access-Control-Allow-Headers', 'origin, content-type, accept');
  ctx.res.set('Access-Control-Allow-Credentials', true);
});

// Check all requests for a "/v1" path
app.addContextHook('dispatch:before', async ctx => {
  if (ctx.req.path !== '/v1') return;
  await ctx.render({ text: 'This request did not reach the router.' });
  return true;
});

// Add config plugin reading custom file
const file = Path.currentFile()
  .dirname()
  .child(`config.${app.mode}.yml`)
  .toString();
// app.plugin(yamlConfigPlugin);
app.plugin(yamlConfigPlugin, { file });
// app.plugin(yamlConfigPlugin, { ext: 'yaml' });
// app.plugin(yamlConfigPlugin, { file: 'does_not_exist.yml' });

// Get secrets
app.secrets = app.config.secrets;

// Logging
if (app.config.log.filename !== null) {
  // Create a new stream
  const stream = rfs.createStream(app.config.log.filename, {
    size: "10M", // rotate every 10 MegaBytes written
    interval: "1d", // rotate daily
    compress: "gzip" // compress rotated files
  });

  // // Create a new stream
  // let writer = fs.createWriteStream(
  //   app.config.log.filename, {
  //   flags: 'w', encoding: 'utf8'
  // });

  // Assign to logger
  app.log.destination = stream;
}
// Apply log level
app.log.level = app.config.log.level;
// app.log.formatter = Logger.systemdFormatter;
// app.log.formatter = Logger.colorFormatter;

// To use .env variables
// app.log.debug(`Env pass ${process.env.SECRET_PASS}, key: ${process.env.SECRET_KEY}`);

// Prepare mode specific message during startup
const msg = app.mode === 'development' ? 'Development' : 'Production';
app.log.debug(`App mode ${msg}`);

// Enable compression
app.renderer.autoCompress = true;

// Add helper plugin
app.plugin(helperPlugin);

// Model database
app.onStart(async app => {
  if (app.models.pg === undefined) app.models.pg = new Pg(app.config.pg);
  app.models.main = new Main(app.models.pg);
  app.models.metadata = new Metadata(app.models.pg);
  app.models.data = new Data(app.models.pg);
  app.models.quasar = new Quasar(app.models.pg);
});


// Routing
// https://mojojs.org/docs/Routing.md

// Public routes

// # Index                                   ✓
// # User login                              ✓
// # User logout                             ✓
// # Get organization info                   ✓

// Index
app.get('/').to('main#index');

// Organization
app.get('/organization').to('main#organization');

// Login route
app.post('/login').to('main#login');

// Refresh token
app.post('/refresh-token').to('main#refreshToken');

// Authentication via jwt token
const auth = router.under('/', async ctx => {
  ctx.log.debug("Router under route");

  // Get token
  const token = ctx.authExtractToken();
  ctx.log.trace(`Token: ${token}`);

  // get user
  const user = await ctx.jwtDecodeUser(token);
  ctx.log.info(`User: ${user.us_name} ${user.us_surname}`);

  // Authenticated
  // ctx.logObj('jwt', ctx.config.jwt.access);
  ctx.log.trace(`under secret: ${ctx.config.jwt.access.secret}`);
  const res = await ctx.jwtValidate(token, ctx.config.jwt.access);
  if (res.isValid) return;

  // Not authenticated
  ctx.log.debug("token not valid or expired");
  await ctx.render({
    json: {
      message: 'Token not valid or expired',
      error: res.err
    }, status: 401 // Unauthorized
  });
  return false;
});

// Reserved token based routes

// # Dashboard                               ✓
// # Get stations                            ✓
// # Get stations/id                         ✓
// # Get parameters                          ✓
// # Get parameters/id                       ✓
// # Get series...                           ✓
// # Get latest data per series              ✓
// # Get latest data per station
// # Get data frame per series               ✓
// # Get data frame per station

// Logout route
auth.get('/logout').to('main#logout');

// Dashboard & infos
auth.get('/dashboard').to('main#dashboard');

//  https://mojojs.org/docs/Routing.md#toc

// Metadata
auth.get('/stations').to('metadata#stations').name('stations_list');
auth.get('/stations/:id', { id: /\d{2}/ }).to('metadata#stationsRegion').name('stations_list_region');
auth.get('/stations/:id', { id: /\d{4,6}/ }).to('metadata#station').name('station');

auth.get('/parameters').to('metadata#parameters').name('parameters_list');
auth.get('/parameters-type').to('metadata#parametersType').name('parameters_type_list');
auth.get('/parameters/:id', { id: /\d+/ }).to('metadata#parameter').name('parameter');

auth.get('/stations-parameters/:stid/:prid', { stid: /\d{4,6}/, prid: /\d+/ })
  .to('metadata#stationParameters').name('stations_parameters');

auth.get('/sites').to('metadata#sites').name('sites');

auth.get('/campaigns/:id', { id: /\d{4,6}/ })
  .to('metadata#campaigns').name('campaigns');
auth.get('/campaigns/:id/:ep', { id: /\d{4,6}/, ep: /\d+/ })
  .to('metadata#campaignsDates').name('campaigns_date');
auth.get('/campaigns/:id/:ep', { id: /\d{4,6}/, ep: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/ })
  .to('metadata#campaignsDates').name('campaigns_date');

// Hourly data
auth.get('/series').to('metadata#series').name('series_list');
auth.get('/series/:id', { id: /\d{2}/ }).to('metadata#seriesRegion').name('series_list_region');
auth.get('/series/:id', { id: /\d{4,6}/ }).to('metadata#seriesStation').name('series_list_station');

auth.get('/series-data/:id/:hh', { id: /\d+/, hh: /\d+/ })
  .to('data#series').name('series_data');
auth.get('/series-data/:id/:ep1/:ep2', { id: /\d+/, ep1: /\d+/, ep2: /\d+/ })
  .to('data#seriesFrame').name('series_data_frame');
auth.get('/series-data/:id/:ep1/:ep2', {
  id: /\d+/,
  ep1: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/,
  ep2: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
}
).to('data#seriesFrame').name('series_data_frame');

// Daily data
// series-data-dd/{series-id}/{num-days}
auth.get('/series-data-dd/:id/:dd', { id: /\d+/, dd: /\d+/ })
  .to('data#dailySeries').name('series_data');

// series-data-dd/{series-id}/{date-from}/{date-to}
// 'epx' multiple accepted value (example:  1711584000 | 2024-03-28)
auth.get('/series-data-dd/:id/:ep1/:ep2', { id: /\d+/, ep1: /\d+/, ep2: /\d+/ })
  .to('data#dailySeriesFrame').name('series_data_frame');
auth.get('/series-data-dd/:id/:ep1/:ep2', {
  id: /\d+/,
  ep1: /\d{4}-\d{2}-\d{2}/,
  ep2: /\d{4}-\d{2}-\d{2}/
}
).to('data#dailySeriesFrame').name('series_data_frame');

// series-data-synchro-all/{region_istat_code}/{last-ie-date_time}
// 'ep' multiple accepted value (example:  1711584000 | 2024-03-28T00:00:00)
auth.get('/series-data-synchro/:id/:ep', { id: /\d+/, ep: /\d{8,10}|\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/ })
  .to('data#seriesSynchroFrameSeries').name('series_synchro_data_frame_series');

// series-data-synchro-all/{region_istat_code}/{last-ie-date_time}
// 'ep' multiple accepted value (example:  1711584000 | 2024-03-28T00:00:00)
auth.get('/series-data-synchro-all/:id/:ep', { id: /\d{2}/, ep: /\d{8,10}|\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/ })
  .to('data#seriesSynchroFrameRegion').name('series_synchro_data_frame_region');

// series-data-synchro-all/{station-id}/{last-ie-date_time}
// 'ep' multiple accepted value (example:  1711584000 | 2024-03-28T00:00:00)
auth.get('/series-data-synchro-all/:id/:ep', { id: /\d{4,6}/, ep: /\d{8,10}|\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/ })
  .to('data#seriesSynchroFrameStation').name('series_synchro_data_frame_station');


// get log data per station
auth.get('/stations-log/:stid/:ep1/:ep2', {
  stid: /\d+/,
  ep1: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/,
  ep2: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
}
).to('data#stationLog').name('stations_log');



// Quasar app routes
auth.get('/qapp-stations').to('quasar#stations');
auth.get('/qapp-stations/:id', { id: /\d{4,6}/ }).to('quasar#station');
auth.get('/qapp-users-online').to('quasar#usersOnline');
auth.get('/qapp-users/:id', { id: /\d{1,4}/ }).to('quasar#user');

// Catch all route
app.any('/*whatever').to({
  whatever: '', fn: async ctx => {
    const params = await ctx.params();
    const whatever = params.whatever;
    //await ctx.render({ text: `/${whatever} did not match.`, status: 404 });
    await ctx.render({
      json: {
        message: `/${whatever} did not match.`,
        error: 'Route unknown'
      }, status: 404 // Not Found
    });
  }

});

// Run app
app.start();
