import { Module } from '@nestjs/common';
import { PhotoModerator, SelfieVerifier } from '../moderation/moderation.providers';
import { ProfileCards } from './profile-cards.service';
import { ProfilesController } from './profiles.controller';
import { ProfilesService } from './profiles.service';

@Module({
  controllers: [ProfilesController],
  providers: [ProfilesService, ProfileCards, PhotoModerator, SelfieVerifier],
  exports: [ProfilesService, ProfileCards],
})
export class ProfilesModule {}
