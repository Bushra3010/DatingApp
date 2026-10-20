import { INestApplication } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { AppConfig } from './config';
import { Db } from './db/db.service';
import { migrate } from './db/migrate';
import { LocalStorage } from './media/storage.service';

/** Builds the app (migrations applied, local media served). Shared by main.ts and the e2e tests. */
export async function createApp(config: AppConfig, opts: { logger?: false } = {}): Promise<INestApplication> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule.with(config), {
    logger: opts.logger,
  });
  await migrate(app.get(Db), (m) => console.log(`[migrate] ${m}`));
  app.useStaticAssets(app.get(LocalStorage).root, { prefix: '/media/', maxAge: '7d' });
  app.enableShutdownHooks();
  return app;
}
