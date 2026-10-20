import { Global, Module } from '@nestjs/common';
import { APP_CONFIG, AppConfig } from '../config';
import { Db } from './db.service';

@Global()
@Module({
  providers: [{ provide: Db, inject: [APP_CONFIG], useFactory: (c: AppConfig) => new Db(c.databaseUrl) }],
  exports: [Db],
})
export class DbModule {}
