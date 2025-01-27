import { app } from '../index.js';
import t from 'tap';
import process from 'node:process';

app.log.level = 'debug';

t.test('Basics', async t => {
  const ua = await app.newTestUserAgent({ tap: t, maxRedirects: 1 });

  await t.test('Index', async () => {
    // ○ Welcome                                                                              ✓
    (
      await ua.getOk('/')
    ).statusIs(200);

    // ○ Get organization info                                                                ✓
    (
      await ua.getOk('/organization')
    ).statusIs(200).bodyLike(/OPAS/);
  });

  await ua.stop();
});
