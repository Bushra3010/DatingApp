import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AdminGuard } from '../common/auth.guard';
import { Events } from '../common/events';
import { parse } from '../common/validation';
import { Db } from '../db/db.service';
import { endAllMatches, purgeDeletedAccounts } from '../account/account.service';
import { ProfilesService } from '../profiles/profiles.service';

/** Moderation API behind the admin console: report queue, photo review, verification review, bans. */
@Controller('admin')
@UseGuards(AdminGuard)
export class AdminController {
  constructor(private readonly db: Db, private readonly profiles: ProfilesService, private readonly events: Events) {}

  @Get('reports')
  reports(@Query() query: unknown) {
    const { status } = parse(z.object({ status: z.enum(['open', 'actioned', 'dismissed']).default('open') }), query);
    return this.db.query(
      `SELECT r.*, ms.body AS message_body, rp.first_name AS reported_name,
              (SELECT count(*)::int FROM reports x WHERE x.reported = r.reported) AS reports_against_user
       FROM reports r
       JOIN profiles rp ON rp.user_id = r.reported
       LEFT JOIN messages ms ON ms.id = r.message_id
       WHERE r.status = $1
       ORDER BY (r.priority = 'high') DESC, r.created_at`,
      [status],
    );
  }

  @Post('reports/:id/resolve')
  @HttpCode(200)
  async resolve(@Param('id', ParseUUIDPipe) id: string, @Body() body: unknown) {
    const { action, note } = parse(
      z.object({ action: z.enum(['dismiss', 'warn', 'ban']), note: z.string().max(1000).optional() }),
      body,
    );
    const report = await this.db.one(
      `UPDATE reports SET status = $2, resolution = $3, resolved_at = now() WHERE id = $1 RETURNING reported`,
      [id, action === 'dismiss' ? 'dismissed' : 'actioned', note ? `${action}: ${note}` : action],
    );
    if (report && action === 'ban') await this.ban(report.reported, note ?? 'report');
    return { resolved: !!report };
  }

  @Post('users/:id/ban')
  @HttpCode(200)
  async banUser(@Param('id', ParseUUIDPipe) id: string, @Body() body: unknown) {
    const { reason } = parse(z.object({ reason: z.string().max(500) }), body);
    await this.ban(id, reason);
    return { banned: true };
  }

  /** Bans apply to the phone number as well as the account (section 5). Device bans come with fingerprinting. */
  private async ban(userId: string, reason: string) {
    const ended = await this.db.tx(async (q) => {
      const [u] = await q.query(`UPDATE users SET status = 'banned' WHERE id = $1 RETURNING phone`, [userId]);
      if (u?.phone) {
        await q.query(
          `INSERT INTO banned_identifiers (kind, value, reason) VALUES ('phone', $1, $2) ON CONFLICT DO NOTHING`,
          [u.phone, reason],
        );
      }
      return endAllMatches(q, userId);
    });
    for (const m of ended) this.events.emit({ type: 'match:removed', users: [m.user_a, m.user_b], matchId: m.id });
  }

  @Get('photos/pending')
  pendingPhotos() {
    return this.db.query(
      `SELECT ph.id, ph.user_id, ph.position, ph.caption, m.url, ph.created_at FROM photos ph
       JOIN media m ON m.id = ph.media_id WHERE ph.moderation_status = 'pending' ORDER BY ph.created_at`,
    );
  }

  @Post('photos/:id/review')
  @HttpCode(200)
  async reviewPhoto(@Param('id', ParseUUIDPipe) id: string, @Body() body: unknown) {
    const { status, reason } = parse(
      z.object({ status: z.enum(['approved', 'rejected']), reason: z.string().max(200).optional() }),
      body,
    );
    const photo = await this.db.one(
      `UPDATE photos SET moderation_status = $2, moderation_reason = $3 WHERE id = $1 RETURNING user_id`,
      [id, status, reason ?? null],
    );
    if (photo) await this.profiles.refreshStatus(photo.user_id);
    return { reviewed: !!photo };
  }

  @Get('verifications/pending')
  pendingVerifications() {
    return this.db.query(
      `SELECT user_id, first_name, verification_media FROM profiles WHERE verification_status = 'pending'`,
    );
  }

  @Post('verifications/:userId/review')
  @HttpCode(200)
  async reviewVerification(@Param('userId', ParseUUIDPipe) userId: string, @Body() body: unknown) {
    const { status } = parse(z.object({ status: z.enum(['verified', 'rejected']) }), body);
    await this.db.query(`UPDATE profiles SET verification_status = $2 WHERE user_id = $1`, [userId, status]);
    return { reviewed: true };
  }

  @Post('purge-deleted')
  @HttpCode(200)
  async purge() {
    return { purged: await purgeDeletedAccounts(this.db) };
  }
}
