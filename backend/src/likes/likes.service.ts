import {
  BadRequestException, ConflictException, ForbiddenException, HttpException, HttpStatus, Inject, Injectable,
  NotFoundException,
} from '@nestjs/common';
import { APP_CONFIG, AppConfig } from '../config';
import { AuthUser, requireActive } from '../common/auth.guard';
import { Events } from '../common/events';
import { Notifier } from '../common/notifier';
import { screenText } from '../common/text-screen';
import { Db, Queryable } from '../db/db.service';
import { BLOCKED_SQL } from '../discovery/discovery.service';
import { ProfileCards } from '../profiles/profile-cards.service';

export interface LikeInput {
  toUserId: string;
  targetType: 'photo' | 'prompt';
  targetId: string;
  comment?: string;
}

interface LikeRow {
  id: string;
  from_user: string;
  to_user: string;
  target_type: 'photo' | 'prompt';
  target_id: string;
  comment: string | null;
  status: string;
  created_at: Date;
}

@Injectable()
export class LikesService {
  constructor(
    private readonly db: Db,
    private readonly cards: ProfileCards,
    private readonly events: Events,
    private readonly notifier: Notifier,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** Likes sent today, counted in the launch market's timezone. */
  async likesSentToday(userId: string): Promise<number> {
    const row = await this.db.one<{ n: number }>(
      `SELECT count(*)::int AS n FROM likes
       WHERE from_user = $1 AND created_at >= (date_trunc('day', now() AT TIME ZONE $2) AT TIME ZONE $2)`,
      [userId, this.config.likeResetTimezone],
    );
    return row!.n;
  }

  async remainingLikes(user: AuthUser): Promise<number | null> {
    if (user.plan === 'plus') return null;
    return Math.max(0, this.config.freeDailyLikes - (await this.likesSentToday(user.id)));
  }

  private assertCleanComment(comment?: string): void {
    const flags = comment ? screenText(comment) : [];
    if (flags.length) throw new BadRequestException({ message: 'Comment not allowed', flags });
  }

  /** DI-2: like one specific photo or prompt, with an optional comment. A like back on a pending like matches. */
  async send(user: AuthUser, input: LikeInput) {
    requireActive(user);
    if (input.toUserId === user.id) throw new BadRequestException('You cannot like yourself');
    this.assertCleanComment(input.comment);

    const target = await this.db.one(
      `SELECT u.status, ${BLOCKED_SQL('$1::uuid', '$2::uuid')} AS blocked,
              CASE WHEN $3 = 'photo'
                   THEN EXISTS (SELECT 1 FROM photos WHERE id = $4::uuid AND user_id = $2 AND moderation_status = 'approved')
                   ELSE EXISTS (SELECT 1 FROM profile_prompts WHERE id = $4::uuid AND user_id = $2) END AS item_ok
       FROM users u WHERE u.id = $2`,
      [user.id, input.toUserId, input.targetType, input.targetId],
    );
    if (!target || target.status !== 'active' || target.blocked) throw new NotFoundException('Profile not available');
    if (!target.item_ok) throw new BadRequestException('That photo or prompt is not on this profile');

    const theirs = await this.db.one<LikeRow>(
      `SELECT * FROM likes WHERE from_user = $1 AND to_user = $2 AND status = 'pending'`,
      [input.toUserId, user.id],
    );
    if (theirs) {
      // They already liked us, so this like is a like back.
      return { matched: true, ...(await this.matchOn(user, theirs, input)) };
    }

    const remaining = await this.remainingLikes(user);
    if (remaining === 0) {
      throw new HttpException(
        { message: 'Out of likes for today', code: 'LIKE_LIMIT', limit: this.config.freeDailyLikes },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    const like = await this.db
      .one<LikeRow>(
        `INSERT INTO likes (from_user, to_user, target_type, target_id, comment)
         VALUES ($1, $2, $3, $4, $5) ON CONFLICT (from_user, to_user) DO NOTHING RETURNING *`,
        [user.id, input.toUserId, input.targetType, input.targetId, input.comment ?? null],
      );
    if (!like) throw new ConflictException('You already liked this person');
    await this.db.query(`DELETE FROM skips WHERE from_user = $1 AND to_user = $2`, [user.id, input.toUserId]);
    this.events.emit({ type: 'like:new', to: input.toUserId, likeId: like.id });
    await this.notifier.push(input.toUserId, 'likes', 'Someone liked your profile');
    return { matched: false, likeId: like.id, remainingLikes: remaining === null ? null : remaining - 1 };
  }

  /** DI-3: skip a profile; it can come back after the cool-down. */
  async skip(user: AuthUser, otherId: string) {
    requireActive(user);
    await this.db.query(
      `INSERT INTO skips (from_user, to_user) SELECT $1, $2 WHERE EXISTS (SELECT 1 FROM users WHERE id = $2)
       ON CONFLICT (from_user, to_user) DO UPDATE SET created_at = now()`,
      [user.id, otherId],
    );
    return { skipped: true };
  }

  private async pendingInbox(userId: string, order: 'ASC' | 'DESC'): Promise<LikeRow[]> {
    return this.db.query<LikeRow>(
      `SELECT l.* FROM likes l JOIN users u ON u.id = l.from_user AND u.status = 'active'
       WHERE l.to_user = $1 AND l.status = 'pending' AND NOT ${BLOCKED_SQL('l.from_user', 'l.to_user')}
       ORDER BY l.created_at ${order}, l.id`,
      [userId],
    );
  }

  /**
   * LM-1/LM-2: Likes You. Free users see one like at a time, oldest first; Plus users see all
   * and can sort.
   */
  async inbox(user: AuthUser, sort: 'oldest' | 'newest') {
    const all = await this.pendingInbox(user.id, user.plan === 'plus' && sort === 'newest' ? 'DESC' : 'ASC');
    const visible = user.plan === 'plus' ? all : all.slice(0, 1);
    const cards = await this.cards.build(visible.map((l) => l.from_user), user.id);
    const cardById = new Map(cards.map((c) => [c.userId, c]));
    const likes = [];
    for (const l of visible) {
      likes.push({
        likeId: l.id,
        comment: l.comment,
        createdAt: l.created_at,
        liked: await this.likedItem(l),
        profile: cardById.get(l.from_user)!,
      });
    }
    return { total: all.length, canSeeAll: user.plan === 'plus', likes };
  }

  /** The item of the receiver's own profile that the like was on, so they can see what caught attention. */
  async likedItem(l: Pick<LikeRow, 'target_type' | 'target_id'>) {
    if (l.target_type === 'photo') {
      const photo = await this.db.one(
        `SELECT m.url, ph.caption FROM photos ph JOIN media m ON m.id = ph.media_id WHERE ph.id = $1`,
        [l.target_id],
      );
      return { type: 'photo' as const, id: l.target_id, url: photo?.url ?? null, caption: photo?.caption ?? null };
    }
    const prompt = await this.db.one(
      `SELECT pl.text AS question, pp.answer FROM profile_prompts pp
       JOIN prompt_library pl ON pl.id = pp.prompt_id WHERE pp.id = $1`,
      [l.target_id],
    );
    return { type: 'prompt' as const, id: l.target_id, question: prompt?.question ?? null, answer: prompt?.answer ?? null };
  }

  private async inboxLike(user: AuthUser, likeId: string): Promise<LikeRow> {
    const inbox = await this.pendingInbox(user.id, 'ASC');
    const idx = inbox.findIndex((l) => l.id === likeId);
    if (idx === -1) throw new NotFoundException('Like not found');
    if (user.plan !== 'plus' && idx !== 0) throw new ForbiddenException('Upgrade to Plus to see every like');
    return inbox[idx];
  }

  /** LM-3: match by liking back. The liker's comment opens the chat. */
  async match(user: AuthUser, likeId: string, reply?: string) {
    requireActive(user);
    this.assertCleanComment(reply);
    const like = await this.inboxLike(user, likeId);
    return this.matchOn(user, like, reply ? { comment: reply } : undefined);
  }

  async remove(user: AuthUser, likeId: string) {
    const like = await this.inboxLike(user, likeId);
    await this.db.query(`UPDATE likes SET status = 'removed' WHERE id = $1`, [like.id]);
    return { removed: true };
  }

  private async matchOn(user: AuthUser, theirLike: LikeRow, back?: Partial<LikeInput>) {
    const [a, b] = [user.id, theirLike.from_user].sort();
    const match = await this.db.tx(async (q: Queryable) => {
      const [updated] = await q.query(
        `UPDATE likes SET status = 'matched' WHERE id = $1 AND status = 'pending' RETURNING id`,
        [theirLike.id],
      );
      if (!updated) throw new ConflictException('This like was already handled');
      if (back?.targetType && back.targetId) {
        await q.query(
          `INSERT INTO likes (from_user, to_user, target_type, target_id, comment, status)
           VALUES ($1, $2, $3, $4, $5, 'matched') ON CONFLICT (from_user, to_user) DO NOTHING`,
          [user.id, theirLike.from_user, back.targetType, back.targetId, back.comment ?? null],
        );
      }
      const [m] = await q.query(
        `INSERT INTO matches (user_a, user_b, like_id) VALUES ($1, $2, $3) RETURNING id, created_at`,
        [a, b, theirLike.id],
      );
      await q.query(
        `INSERT INTO messages (match_id, sender_id, kind, body, media_url, created_at)
         VALUES ($1, $2, 'like_context', $3, $4, $5)`,
        [m.id, theirLike.from_user, theirLike.comment, `${theirLike.target_type}:${theirLike.target_id}`, theirLike.created_at],
      );
      if (back?.comment) {
        await q.query(`INSERT INTO messages (match_id, sender_id, kind, body) VALUES ($1, $2, 'text', $3)`, [
          m.id, user.id, back.comment,
        ]);
      }
      return m;
    });
    this.events.emit({ type: 'match:new', users: [a, b], matchId: match.id });
    await this.notifier.push(theirLike.from_user, 'matches', "It's a match");
    return { matchId: match.id };
  }
}
