import { Inject, Injectable } from '@nestjs/common';
import { mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { APP_CONFIG, AppConfig } from '../config';

export abstract class Storage {
  /** Stores bytes and returns a public URL. */
  abstract put(bytes: Buffer, ext: string): Promise<string>;
}

/** Local-disk storage served at /media; production swaps in S3-compatible storage + CDN. */
@Injectable()
export class LocalStorage extends Storage {
  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {
    super();
  }

  get root(): string {
    return resolve(this.config.mediaDir);
  }

  async put(bytes: Buffer, ext: string): Promise<string> {
    await mkdir(this.root, { recursive: true });
    const name = `${randomUUID()}.${ext}`;
    await writeFile(join(this.root, name), bytes);
    return `${this.config.publicBaseUrl}/media/${name}`;
  }
}
