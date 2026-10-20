import { DynamicModule, Global, Module } from '@nestjs/common';
import { AccountModule } from './account/account.module';
import { AdminModule } from './admin/admin.module';
import { AuthModule } from './auth/auth.module';
import { BillingModule } from './billing/billing.module';
import { ChatModule } from './chat/chat.module';
import { CommonModule } from './common/common.module';
import { APP_CONFIG, AppConfig } from './config';
import { DbModule } from './db/db.module';
import { DiscoveryModule } from './discovery/discovery.module';
import { HealthController } from './health.controller';
import { LikesModule } from './likes/likes.module';
import { MediaModule } from './media/media.module';
import { ProfilesModule } from './profiles/profiles.module';
import { SafetyModule } from './safety/safety.module';

@Global()
@Module({})
class ConfigModule {
  static with(config: AppConfig): DynamicModule {
    return { module: ConfigModule, providers: [{ provide: APP_CONFIG, useValue: config }], exports: [APP_CONFIG] };
  }
}

@Module({})
export class AppModule {
  static with(config: AppConfig): DynamicModule {
    return {
      module: AppModule,
      imports: [
        ConfigModule.with(config), DbModule, CommonModule, AuthModule, MediaModule, ProfilesModule,
        DiscoveryModule, LikesModule, ChatModule, SafetyModule, AccountModule, BillingModule, AdminModule,
      ],
      controllers: [HealthController],
    };
  }
}
