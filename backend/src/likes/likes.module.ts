import { Module } from '@nestjs/common';
import { ProfilesModule } from '../profiles/profiles.module';
import { LikesController } from './likes.controller';
import { LikesService } from './likes.service';

@Module({
  imports: [ProfilesModule],
  controllers: [LikesController],
  providers: [LikesService],
})
export class LikesModule {}
