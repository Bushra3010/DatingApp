import { BadRequestException, Injectable } from '@nestjs/common';
import { Events } from '../common/events';
import { Db } from '../db/db.service';
import { endMatchesBetween } from '../chat/chat.service';

export const REPORT_REASONS = [
  'fake_profile', 'scam', 'harassment', 'inappropriate_photos', 'hate_speech', 'underage', 'threats',
  'sexual_violence', 'met_in_person_unsafe', 'other',
] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];

/** Threats, minors and sexual violence go to the priority queue (section 5). */
const HIGH_PRIORITY: ReportReason[] = ['underage', 'threats', 'sexual_violence', 'met_in_person_unsafe'];

@Injectable()
export class SafetyService {
  constructor(private readonly db: Db, private readonly events: Events) {}

  /** Blocks are mutual-invisibility: neither person sees the other anywhere again; any match ends. */
  async block(blocker: string, blocked: string): Promise<void> {
    if (blocker === blocked) throw new BadRequestException('You cannot block yourself');
    const ended = await this.db.tx(async (q) => {
      await q.query(
        `INSERT INTO blocks (blocker, blocked) SELECT $1, $2 WHERE EXISTS (SELECT 1 FROM users WHERE id = $2)
         ON CONFLICT DO NOTHING`,
        [blocker, blocked],
      );
      return endMatchesBetween(q, blocker, blocked, blocker);
    });
    for (const matchId of ended) this.events.emit({ type: 'match:removed', users: [blocker, blocked], matchId });
  }

  async unblock(blocker: string, blocked: string): Promise<void> {
    await this.db.query(`DELETE FROM blocks WHERE blocker = $1 AND blocked = $2`, [blocker, blocked]);
  }

  /** Reporting works whether or not the two are still matched. The reported user is hidden from the reporter at once. */
  async report(reporter: string, reported: string, reason: ReportReason, details?: string, messageId?: string) {
    if (reporter === reported) throw new BadRequestException('You cannot report yourself');
    if (messageId) {
      const msg = await this.db.one(
        `SELECT 1 FROM messages ms JOIN matches m ON m.id = ms.match_id
         WHERE ms.id = $1 AND ms.sender_id = $2 AND $3 IN (m.user_a, m.user_b)`,
        [messageId, reported, reporter],
      );
      if (!msg) throw new BadRequestException('Message not found');
    }
    const priority = HIGH_PRIORITY.includes(reason) ? 'high' : 'normal';
    const row = await this.db.one(
      `INSERT INTO reports (reporter, reported, reason, details, message_id, priority)
       SELECT $1, $2, $3, $4, $5, $6 WHERE EXISTS (SELECT 1 FROM users WHERE id = $2)
       RETURNING id, priority`,
      [reporter, reported, reason, details ?? null, messageId ?? null, priority],
    );
    if (!row) throw new BadRequestException('User not found');
    await this.block(reporter, reported);
    return { reportId: row.id, priority: row.priority };
  }
}
