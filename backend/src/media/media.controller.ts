import {
  BadRequestException, Controller, Param, ParseEnumPipe, Post, UploadedFile, UseGuards, UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthGuard, AuthUser, CurrentUser } from '../common/auth.guard';
import { Db } from '../db/db.service';
import { Storage } from './storage.service';

type MediaKind = 'photo' | 'video' | 'voice' | 'verification';

const RULES: Record<MediaKind, { types: Record<string, string>; maxBytes: number }> = {
  photo: { types: { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic' }, maxBytes: 10_000_000 },
  video: { types: { 'video/mp4': 'mp4', 'video/quicktime': 'mov' }, maxBytes: 50_000_000 },
  voice: { types: { 'audio/aac': 'aac', 'audio/mp4': 'm4a', 'audio/mpeg': 'mp3', 'audio/ogg': 'ogg', 'audio/webm': 'webm' }, maxBytes: 5_000_000 },
  verification: { types: { 'video/mp4': 'mp4', 'video/quicktime': 'mov' }, maxBytes: 30_000_000 },
};

@Controller('media')
@UseGuards(AuthGuard)
export class MediaController {
  constructor(private readonly db: Db, private readonly storage: Storage) {}

  /** Multipart upload, field name "file". Returns a media id to attach to a photo slot, message or verification. */
  @Post(':kind')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 50_000_000 } }))
  async upload(
    @CurrentUser() user: AuthUser,
    @Param('kind', new ParseEnumPipe(['photo', 'video', 'voice', 'verification'])) kind: MediaKind,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('Missing file');
    const rule = RULES[kind];
    const ext = rule.types[file.mimetype];
    if (!ext) throw new BadRequestException(`Unsupported type ${file.mimetype} for ${kind}`);
    if (file.size > rule.maxBytes) throw new BadRequestException('File too large');
    const url = await this.storage.put(file.buffer, ext);
    return this.db.one(
      `INSERT INTO media (owner_id, kind, url, mime_type, size_bytes) VALUES ($1, $2, $3, $4, $5)
       RETURNING id, kind, url`,
      [user.id, kind, url, file.mimetype, file.size],
    );
  }
}
