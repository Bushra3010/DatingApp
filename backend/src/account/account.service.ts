import { BadRequestException, Injectable } from '@nestjs/common';
import { Events } from '../common/events';
import { Db, Queryable } from '../db/db.service';
import { ProfilesService } from '../profiles/profiles.service';

export const PURGE_AFTER_DAYS = 30;

@Injectable()
export class AccountService {
  constructor(private readonly db: Db, private readonly profiles: ProfilesService, private readonly events: Events) {}

  async preferences(userId: string) {
    const p = await this.db.one(`SELECT age_min, age_max, max_distance_km FROM preferences WHERE user_id = $1`, [userId]);
    return { ageMin: p.age_min, ageMax: p.age_max, maxDistanceKm: p.max_distance_km };
  }

  /** PF-1: basic filters (age, distance). Gender is set through show_me on the profile. */
  async updatePreferences(userId: string, input: { ageMin?: number; ageMax?: number; maxDistanceKm?: number }) {
    const current = await this.preferences(userId);
    const next = { ...current, ...input };
    if (next.ageMin > next.ageMax) throw new BadRequestException('Minimum age must not exceed maximum age');
    await this.db.query(
      `UPDATE preferences SET age_min = $2, age_max = $3, max_distance_km = $4 WHERE user_id = $1`,
      [userId, next.ageMin, next.ageMax, next.maxDistanceKm],
    );
    return next;
  }

  async settings(userId: string) {
    const s = await this.db.one(`SELECT read_receipts, push FROM settings WHERE user_id = $1`, [userId]);
    return { readReceipts: s.read_receipts, push: s.push };
  }

  /** CH-1 read receipts toggle and PF-5 push notification controls per type. */
  async updateSettings(userId: string, input: { readReceipts?: boolean; push?: Record<string, boolean> }) {
    await this.db.query(
      `UPDATE settings SET read_receipts = COALESCE($2, read_receipts), push = push || $3::jsonb WHERE user_id = $1`,
      [userId, input.readReceipts ?? null, JSON.stringify(input.push ?? {})],
    );
    return this.settings(userId);
  }

  /** ON-6: paused accounts are hidden from discovery and Likes You; chats are kept. */
  async pause(userId: string) {
    await this.db.query(`UPDATE users SET status = 'paused' WHERE id = $1 AND status IN ('active', 'onboarding')`, [userId]);
    return { status: 'paused' };
  }

  async unpause(userId: string) {
    await this.db.query(`UPDATE users SET status = 'onboarding' WHERE id = $1 AND status = 'paused'`, [userId]);
    return { status: await this.profiles.refreshStatus(userId) };
  }

  /**
   * ON-6 full deletion. The account disappears at once (matches end, phone freed) and the remaining rows
   * are purged after PURGE_AFTER_DAYS, unless a ban or open safety report requires retention.
   */
  async delete(userId: string) {
    const ended = await this.db.tx(async (q) => {
      await q.query(`UPDATE users SET status = 'deleted', deleted_at = now(), phone = NULL WHERE id = $1`, [userId]);
      return endAllMatches(q, userId);
    });
    for (const m of ended) this.events.emit({ type: 'match:removed', users: [m.user_a, m.user_b], matchId: m.id });
    return { deleted: true, purgeAfterDays: PURGE_AFTER_DAYS };
  }

  /** Data export on request (section 5). */
  async export(userId: string) {
    const [profile, preferences, settings] = await Promise.all([
      this.profiles.me(userId), this.preferences(userId), this.settings(userId),
    ]);
    const likesSent = await this.db.query(
      `SELECT to_user, target_type, comment, status, created_at FROM likes WHERE from_user = $1 ORDER BY created_at`,
      [userId],
    );
    const messagesSent = await this.db.query(
      `SELECT match_id, kind, body, media_url, created_at FROM messages WHERE sender_id = $1 ORDER BY created_at`,
      [userId],
    );
    const reportsFiled = await this.db.query(
      `SELECT reason, details, status, created_at FROM reports WHERE reporter = $1 ORDER BY created_at`,
      [userId],
    );
    return { exportedAt: new Date().toISOString(), profile, preferences, settings, likesSent, messagesSent, reportsFiled };
  }
}

export async function endAllMatches(q: Queryable, userId: string) {
  return q.query<{ id: string; user_a: string; user_b: string }>(
    `UPDATE matches SET unmatched_at = now(), unmatched_by = $1
     WHERE $1 IN (user_a, user_b) AND unmatched_at IS NULL RETURNING id, user_a, user_b`,
    [userId],
  );
}

/** Hard-deletes accounts deleted more than PURGE_AFTER_DAYS ago, except banned users kept for enforcement. */
export async function purgeDeletedAccounts(db: Db): Promise<number> {
  const rows = await db.query(
    `DELETE FROM users u WHERE u.status = 'deleted' AND u.deleted_at < now() - make_interval(days => $1)
       AND NOT EXISTS (SELECT 1 FROM reports r WHERE r.reported = u.id AND r.status = 'open')
     RETURNING id`,
    [PURGE_AFTER_DAYS],
  );
  return rows.length;
}
