import { Module } from '@nestjs/common';
import { ProfilesModule } from '../profiles/profiles.module';
import { AdminController } from './admin.controller';

@Module({ imports: [ProfilesModule], controllers: [AdminController] })
export class AdminModule {}
