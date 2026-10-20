import { Module } from '@nestjs/common';
import { MediaController } from './media.controller';
import { LocalStorage, Storage } from './storage.service';

@Module({
  controllers: [MediaController],
  providers: [LocalStorage, { provide: Storage, useExisting: LocalStorage }],
  exports: [Storage, LocalStorage],
})
export class MediaModule {}
