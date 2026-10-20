import { Module } from '@nestjs/common';
import { ProfilesModule } from '../profiles/profiles.module';
import { AccountController } from './account.controller';
import { AccountService } from './account.service';

@Module({
  imports: [ProfilesModule],
  controllers: [AccountController],
  providers: [AccountService],
})
export class AccountModule {}
