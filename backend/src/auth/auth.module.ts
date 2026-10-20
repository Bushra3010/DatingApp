import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { ConsoleSmsProvider, SmsProvider } from './sms.provider';

@Module({
  controllers: [AuthController],
  providers: [AuthService, { provide: SmsProvider, useClass: ConsoleSmsProvider }],
  exports: [SmsProvider],
})
export class AuthModule {}
