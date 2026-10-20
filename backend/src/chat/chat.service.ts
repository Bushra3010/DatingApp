import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AuthUser } from '../common/auth.guard';
import { Events } from '../common/events';
import { Notifier } from '../common/notifier';
import { screenText } from '../common/text-screen';
import { Db, Queryable } from '../db/db.service';

const GIF_HOSTS = ['media.giphy.com', 'i.giphy.com', 'media.tenor.com', 'c.tenor.com'];

export type SendInput =
  | { kind: 'text'; body: string }
  | { kind: 'gif'; url: string }
  | { kind: 'voice'; mediaId: string; durationS: number };

interface MatchRow {
  id: string;
  user_a: string;
  user_b: string;
  other_id: string;
}

@Injectable()
export class ChatService {
  constructor(private readonly db: Db, private readonly events: Events, private readonly notifier: Notifier) {}

  /** An active match the user is part of, with the other person's id. Unmatched chats are gone for both (CH-5). */
  async matchFor(userId: string, matchId: string): Promise<MatchRow> {
    const m = await this.db.one<MatchRow>(
      `SELECT m.id, m.user_a, m.user_b, CASE WHEN m.user_a = $1 THEN m.user_b ELSE m.user_a END AS other_id
       FROM matches m JOIN users o ON o.id = CASE WHEN m.user_a = $1 THEN m.user_b ELSE m.user_a END
       WHERE m.id = $2 AND $1 IN (m.user_a, m.user_b) AND m.unmatched_at IS NULL
         AND o.status IN ('active', 'paused', 'onboarding')`,
      [userId, matchId],
    );
    if (!m) throw new NotFoundException('Chat not found');
    return m;
  }

  async list(userId: string) {
    const rows = await this.db.query(
      `SELECT m.id, m.created_at, o.id AS other_id, p.first_name, p.verification_status,
              (SELECT mu.url FROM photos ph JOIN media mu ON mu.id = ph.media_id
                 WHERE ph.user_id = o.id AND ph.moderation_status = 'approved' ORDER BY ph.position LIMIT 1) AS photo_url,
              last.kind AS last_kind, last.body AS last_body, last.sender_id AS last_sender, last.created_at AS last_at,
              (SELECT count(*)::int FROM messages x
                 WHERE x.match_id = m.id AND x.sender_id <> $1 AND x.read_at IS NULL AND x.kind <> 'like_context') AS unread
       FROM matches m
       JOIN users o ON o.id = CASE WHEN m.user_a = $1 THEN m.user_b ELSE m.user_a END
       JOIN profiles p ON p.user_id = o.id
       LEFT JOIN LATERAL (
         SELECT kind, body, sender_id, created_at FROM messages WHERE match_id = m.id ORDER BY created_at DESC LIMIT 1
       ) last ON true
       WHERE $1 IN (m.user_a, m.user_b) AND m.unmatched_at IS NULL AND o.status IN ('active', 'paused', 'onboarding')
       ORDER BY COALESCE(last.created_at, m.created_at) DESC`,
      [userId],
    );
    return rows.map((r) => ({
      matchId: r.id,
      matchedAt: r.created_at,
      other: { userId: r.other_id, firstName: r.first_name, verified: r.verification_status === 'verified', photoUrl: r.photo_url },
      lastMessage: r.last_kind
        ? { kind: r.last_kind, body: r.last_kind === 'voice' ? null : r.last_body, fromMe: r.last_sender === userId, at: r.last_at }
        : null,
      unread: r.unread,
      yourTurn: !!r.last_kind && r.last_sender !== userId,
    }));
  }

  async messages(userId: string, matchId: string, before: string | undefined, limit: number) {
    const m = await this.matchFor(userId, matchId);
    const otherSettings = await this.db.one<{ read_receipts: boolean }>(
      `SELECT read_receipts FROM settings WHERE user_id = $1`,
      [m.other_id],
    );
    const rows = await this.db.query(
      `SELECT id, sender_id, kind, body, media_url, duration_s, created_at, read_at FROM messages
       WHERE match_id = $1 AND ($2::timestamptz IS NULL OR created_at < $2)
       ORDER BY created_at DESC, id DESC LIMIT $3`,
      [matchId, before ?? null, limit],
    );
    // Read receipts are only shown when the reader has them turned on (CH-1).
    const showReads = otherSettings?.read_receipts !== false;
    return rows.map((r) => this.serialize(r, userId, showReads));
  }

  serialize(r: any, viewerId: string, showReads = true) {
    const base = { id: r.id, senderId: r.sender_id, fromMe: r.sender_id === viewerId, kind: r.kind, createdAt: r.created_at };
    const readAt = r.sender_id === viewerId && showReads ? r.read_at : undefined;
    switch (r.kind) {
      case 'text':
        return { ...base, body: r.body, readAt };
      case 'gif':
        return { ...base, url: r.media_url, readAt };
      case 'voice':
        return { ...base, url: r.media_url, durationS: r.duration_s, readAt };
      default: {
        // like_context: the like that started the chat, e.g. "photo:<id>" plus its comment.
        const [targetType, targetId] = String(r.media_url).split(':');
        return { ...base, comment: r.body, liked: { type: targetType, id: targetId } };
      }
    }
  }

  async send(user: AuthUser, matchId: string, input: SendInput) {
    const m = await this.matchFor(user.id, matchId);
    let body: string | null = null;
    let mediaUrl: string | null = null;
    let duration: number | null = null;
    let flagged = false;
    if (input.kind === 'text') {
      body = input.body;
      // Sharing a phone number in chat is allowed (it is a date-intent moment); payment and abuse are flagged for review.
      flagged = screenText(body).some((f) => f !== 'phone_number');
    } else if (input.kind === 'gif') {
      const host = new URL(input.url).hostname;
      if (!GIF_HOSTS.includes(host)) throw new BadRequestException('GIFs must come from the GIF picker');
      mediaUrl = input.url;
    } else {
      const media = await this.db.one(
        `SELECT url FROM media WHERE id = $1 AND owner_id = $2 AND kind = 'voice'`,
        [input.mediaId, user.id],
      );
      if (!media) throw new BadRequestException('Upload the voice note first');
      mediaUrl = media.url;
      duration = input.durationS;
    }
    const row = await this.db.one(
      `INSERT INTO messages (match_id, sender_id, kind, body, media_url, duration_s, flagged)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [m.id, user.id, input.kind, body, mediaUrl, duration, flagged],
    );
    this.events.emit({ type: 'message:new', users: [m.user_a, m.user_b], matchId: m.id, message: row });
    await this.notifier.push(m.other_id, 'messages', 'New message');
    return this.serialize(row, user.id);
  }

  async markRead(userId: string, matchId: string) {
    const m = await this.matchFor(userId, matchId);
    const [row] = await this.db.query(
      `WITH updated AS (
         UPDATE messages SET read_at = now()
         WHERE match_id = $1 AND sender_id <> $2 AND read_at IS NULL RETURNING read_at
       ) SELECT count(*)::int AS n, max(read_at) AS read_at FROM updated`,
      [m.id, userId],
    );
    const settings = await this.db.one(`SELECT read_receipts FROM settings WHERE user_id = $1`, [userId]);
    if (row.n > 0 && settings?.read_receipts !== false) {
      this.events.emit({ type: 'message:read', to: m.other_id, matchId: m.id, readAt: new Date(row.read_at).toISOString() });
    }
    return { marked: row.n };
  }

  async unmatch(userId: string, matchId: string) {
    const m = await this.matchFor(userId, matchId);
    await endMatch(this.db, m.id, userId);
    this.events.emit({ type: 'match:removed', users: [m.user_a, m.user_b], matchId: m.id });
    return { unmatched: true };
  }
}

/** Ends a match for both people. Messages stay stored for safety review and are purged with the accounts. */
export async function endMatch(q: Queryable, matchId: string, byUserId: string): Promise<void> {
  await q.query(
    `UPDATE matches SET unmatched_at = now(), unmatched_by = $2 WHERE id = $1 AND unmatched_at IS NULL`,
    [matchId, byUserId],
  );
}

/** Ends every match between two people, used by block and report. */
export async function endMatchesBetween(q: Queryable, a: string, b: string, byUserId: string): Promise<string[]> {
  const rows = await q.query<{ id: string }>(
    `UPDATE matches SET unmatched_at = now(), unmatched_by = $3
     WHERE user_a = LEAST($1::uuid, $2::uuid) AND user_b = GREATEST($1::uuid, $2::uuid) AND unmatched_at IS NULL
     RETURNING id`,
    [a, b, byUserId],
  );
  return rows.map((r) => r.id);
}
