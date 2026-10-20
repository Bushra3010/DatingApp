import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Db } from './db.service';

const MIGRATIONS_DIR = join(__dirname, '..', '..', 'migrations');

/** Applies migrations/*.sql in name order, once each. */
export async function migrate(db: Db, log: (msg: string) => void = () => {}): Promise<void> {
  await db.exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
    name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())`);
  const applied = new Set((await db.query<{ name: string }>('SELECT name FROM schema_migrations')).map((r) => r.name));
  const files = readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith('.sql')).sort();
  for (const file of files) {
    if (applied.has(file)) continue;
    const sql = readFileSync(join(MIGRATIONS_DIR, file), 'utf8');
    await db.exec(`BEGIN;\n${sql}\nINSERT INTO schema_migrations (name) VALUES ('${file}');\nCOMMIT;`);
    log(`applied ${file}`);
  }
}
