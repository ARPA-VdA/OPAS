import { app } from '../index.js';
import t from 'tap';
import process from 'node:process';

app.log.level = 'debug';

t.test('Basics', async t => {
  const ua = await app.newTestUserAgent({ tap: t, maxRedirects: 1 });

  // authenticated routes bearer + token
  const token = process.env.TOKEN;
  // app.log.debug("token: "+token);

  await t.test('Metadata', async () => {
    // ○ Dashboard                                                                            ✓
    (
      await ua.getOk('/dashboard', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200); //.jsonIs({ 'message': 'Dashboard info' });

    // ○ Get stations                                                                         ✓
    (
      await ua.getOk('/stations', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get stations / region istat code                                                     ✓
    (
      await ua.getOk('/stations/02', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get stations / id                                                                    ✓
    (
      await ua.getOk('/stations/1000', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get parameters                                                                       ✓
    (
      await ua.getOk('/parameters', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get parameters / id                                                                  ✓
    (
      await ua.getOk('/parameters/1000', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get stations_parameters / id                                                         ✓
    (
      await ua.getOk('/stations-parameters/1000/1', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get sites                                                                            ✓
    (
      await ua.getOk('/sites', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get campaigns per station                                                            ✓
    (
      await ua.getOk('/campaigns/1374', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get campaigns per station and date (ISO 8601 format)                                 ✓
    (
      await ua.getOk('/campaigns/1374/2024-01-01T00%3A00%3A00', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);

    // ○ Get campaigns per station and date (Unix epoch time format)                          ✓
    (
      await ua.getOk('/campaigns/1374/1704067200', { headers: { Accept: '*/*', Authorization: 'bearer ' + token } })
    ).statusIs(200);
  });

  await ua.stop();
});
