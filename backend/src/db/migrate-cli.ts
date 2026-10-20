import { loadConfig } from '../config';
import { Db } from './db.service';
import { migrate } from './migrate';

(async () => {
  const db = new Db(loadConfig().databaseUrl);
  await migrate(db, console.log);
  await db.onModuleDestroy();
  console.log('migrations up to date');
})();
