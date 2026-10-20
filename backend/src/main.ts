import 'reflect-metadata';
import { createApp } from './bootstrap';
import { loadConfig } from './config';

async function main() {
  const config = loadConfig();
  const app = await createApp(config);
  await app.listen(config.port);
  console.log(`Kindred API listening on http://localhost:${config.port}`);
}

main();
