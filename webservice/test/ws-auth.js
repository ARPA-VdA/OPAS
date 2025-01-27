import { app } from '../index.js';
import t from 'tap';
import process from 'node:process';

app.log.level = 'debug';

// https://mojojs.org/docs/Growing.md#testing
// https://mojojs.org/docs/User-Agent.md
// baseURL: 'https://opas.isprambiente.it/api/v1'
// running test: node test/wsAuthTest.js

t.test('Basics', async t => {
  const ua = await app.newTestUserAgent({ tap: t, maxRedirects: 1 });

  // var isProduction = process.env.NODE_ENV === 'production';
  // app.log.debug("isProduction: "+isProduction);

  // authenticated routes bearer + refresh token
  const refreshToken = process.env.REFRESH_TOKEN;
  const user = process.env.USER;
  const pass = process.env.PASS;

  app.log.debug("refreshToken: "+refreshToken);
  app.log.debug("user: "+user);
  app.log.debug("pass: "+pass);

  await t.test('Auth', async () => {
    // ○ Login                                                                                ✓
    (
      await ua.postOk('/login', { headers: { Accept: '*/*' }, json: { email: '' + user + '', password: '' + pass + '' } })
    ).statusIs(200);

    // ○ Refresh token                                                                        ✓
    (
      await ua.postOk('/refresh-token', { headers: { Accept: '*/*' }, json: { refreshToken: '' + refreshToken + '' } })
    ).statusIs(200);
  });

  await ua.stop();
});
