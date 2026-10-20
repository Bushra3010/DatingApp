import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG, AppConfig } from '../config';

export type ModerationResult = { status: 'approved' | 'rejected' | 'pending'; reason?: string };

/**
 * Photo screening for nudity, minors, weapons, celebrity and stolen images (section 5).
 * "auto" approves everything for local development; "manual" leaves photos in the human review queue.
 * A hosted image-moderation API plugs in here, routing uncertain results to "pending".
 */
@Injectable()
export class PhotoModerator {
  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {}

  async review(_url: string): Promise<ModerationResult> {
    return this.config.moderationProvider === 'auto' ? { status: 'approved' } : { status: 'pending' };
  }
}

/** Selfie video verification against profile photos (ON-5). A face-match provider plugs in here. */
@Injectable()
export class SelfieVerifier {
  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {}

  async verify(_videoUrl: string, _photoUrls: string[]): Promise<'verified' | 'rejected' | 'pending'> {
    return this.config.verificationProvider === 'auto' ? 'verified' : 'pending';
  }
}
