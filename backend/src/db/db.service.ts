import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { mkdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { Pool } from 'pg';

export interface Queryable {
  query<T = any>(sql: string, params?: unknown[]): Promise<T[]>;
}

/**
 * Thin SQL layer over either a real Postgres pool or embedded PGlite.
 * `memory://` and `file://<dir>` URLs use PGlite; anything else is passed to node-postgres.
 */
@Injectable()
export class Db implements Queryable, OnModuleDestroy {
  private pglite?: PGlite;
  private pool?: Pool;

  constructor(url: string) {
    if (url === 'memory://') {
      this.pglite = new PGlite();
    } else if (url.startsWith('file://')) {
      const dir = url.slice('file://'.length);
      mkdirSync(dir, { recursive: true });
      this.pglite = new PGlite(dir);
    } else {
      this.pool = new Pool({ connectionString: url, max: 20 });
    }
  }

  async query<T = any>(sql: string, params: unknown[] = []): Promise<T[]> {
    if (this.pglite) return (await this.pglite.query<T>(sql, params)).rows;
    return (await this.pool!.query(sql, params)).rows as T[];
  }

  async one<T = any>(sql: string, params: unknown[] = []): Promise<T | undefined> {
    return (await this.query<T>(sql, params))[0];
  }

  async exec(sql: string): Promise<void> {
    if (this.pglite) await this.pglite.exec(sql);
    else await this.pool!.query(sql);
  }

  async tx<T>(fn: (q: Queryable) => Promise<T>): Promise<T> {
    if (this.pglite) {
      return this.pglite.transaction((t) =>
        fn({ query: async (sql, params = []) => (await t.query<any>(sql, params)).rows }),
      );
    }
    const client = await this.pool!.connect();
    try {
      await client.query('BEGIN');
      const result = await fn({ query: async (sql, params = []) => (await client.query(sql, params)).rows });
      await client.query('COMMIT');
      return result;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async onModuleDestroy() {
    await this.pglite?.close();
    await this.pool?.end();
  }
}
