import { Global, Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { APP_CONFIG, AppConfig } from '../config';
import { AdminGuard, AuthGuard, SessionResolver } from './auth.guard';
import { Events } from './events';
import { Notifier } from './notifier';

@Global()
@Module({
  imports: [
    JwtModule.registerAsync({
      inject: [APP_CONFIG],
      useFactory: (c: AppConfig) => ({ secret: c.jwtSecret, signOptions: { expiresIn: '30d' } }),
    }),
  ],
  providers: [SessionResolver, AuthGuard, AdminGuard, Events, Notifier],
  exports: [JwtModule, SessionResolver, AuthGuard, AdminGuard, Events, Notifier],
})
export class CommonModule {}
