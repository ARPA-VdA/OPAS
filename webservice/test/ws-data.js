import { app } from '../index.js';
import t from 'tap';
import process from 'node:process';

app.log.level = 'debug';

t.test('Basics', async t => {
  const ua = await app.newTestUserAgent({ tap: t, maxRedirects: 1 });

  // authenticated routes bearer + token
  const token = process.env.TOKEN;
  // app.log.debug("token: "+token);

  await t.test('Data', async () => {
    // ○ Get series                                                                           ✓
    (
      await ua.getOk('/series', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get series / region istat code                                                       ✓
    (
      await ua.getOk('/series/02', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get series / station id                                                              ✓
    (
      await ua.getOk('/series/1000', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get latest data per series                                                           ✓
    (
      await ua.getOk('/series-data/500/24', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get data frame per series and period time (ISO 8601 format)                          ✓
    (
      await ua.getOk('/series-data/500/2024-01-01T00%3A00%3A00/2024-01-31T00%3A00%3A00', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get data frame per series and period time (Unix epoch time format)                   ✓
    (
      await ua.getOk('/series-data/500/1704067200/1706659200', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get last edited data frame per series and date time (ISO 8601 format)                ✓
    (
      await ua.getOk('/series-data-synchro/500/2024-01-01T00%3A00%3A00', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get last edited data frame per series and date time (Unix epoch time format)         ✓
    (
      await ua.getOk('/series-data-synchro/500/1704067200', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);
  });

  await ua.stop();
});
