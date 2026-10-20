import { Injectable, Logger } from '@nestjs/common';
import { Db } from '../db/db.service';

export type PushType = 'likes' | 'matches' | 'messages' | 'reminders';

/** Sends push notifications, respecting each user's per-type settings (PF-5). FCM/APNs delivery is a TODO. */
@Injectable()
export class Notifier {
  private readonly log = new Logger('Push');
  readonly sent: { userId: string; type: PushType; title: string }[] = [];

  constructor(private readonly db: Db) {}

  async push(userId: string, type: PushType, title: string): Promise<void> {
    const row = await this.db.one<{ enabled: boolean | null }>(
      `SELECT (push ->> $2)::boolean AS enabled FROM settings WHERE user_id = $1`,
      [userId, type],
    );
    if (row?.enabled === false) return;
    this.sent.push({ userId, type, title });
    this.log.debug(`[${type}] -> ${userId}: ${title}`);
  }
}
