import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG, AppConfig } from '../config';
import { Db } from '../db/db.service';
import { distanceKmSql } from '../common/geo';
import { ProfileCard, ProfileCards } from '../profiles/profile-cards.service';

const CANDIDATE_POOL = 200;
const EXPLORATION_SHARE = 0.2;

/** True when either of two users has blocked the other. */
export const BLOCKED_SQL = (a: string, b: string) =>
  `EXISTS (SELECT 1 FROM blocks WHERE (blocker = ${a} AND blocked = ${b}) OR (blocker = ${b} AND blocked = ${a}))`;

interface Candidate {
  user_id: string;
  score: number;
}

/**
 * Phase 1 ranking (PRD section 6): hard filters, an explainable score, then an 80/20 mix of
 * best-scored and exploration candidates. No attractiveness, race or skin-tone signals are used.
 */
@Injectable()
export class DiscoveryService {
  constructor(
    private readonly db: Db,
    private readonly cards: ProfileCards,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async candidates(userId: string): Promise<Candidate[]> {
    const dist = distanceKmSql('me.lat', 'me.lng', 'c.lat', 'c.lng');
    return this.db.query<Candidate>(
      `WITH me AS (
         SELECT p.user_id, p.gender, p.show_me, p.lat, p.lng, pr.age_min, pr.age_max, pr.max_distance_km,
                date_part('year', age(p.birth_date)) AS age
         FROM profiles p JOIN preferences pr ON pr.user_id = p.user_id WHERE p.user_id = $1
       ),
       pool AS (
         SELECT c.user_id, c.verification_status, u.created_at, u.last_active_at,
                ${dist} AS distance_km, me.max_distance_km,
                (SELECT count(*) FROM likes l WHERE l.to_user = c.user_id
                   AND l.created_at > now() - interval '7 days') AS recent_likes_received,
                EXISTS (SELECT 1 FROM likes l WHERE l.from_user = c.user_id AND l.to_user = me.user_id
                   AND l.status = 'pending') AS likes_me
         FROM me
         JOIN profiles c ON c.user_id <> me.user_id
         JOIN users u ON u.id = c.user_id AND u.status = 'active'
         JOIN preferences cp ON cp.user_id = c.user_id
         WHERE c.gender = ANY (me.show_me) AND me.gender = ANY (c.show_me)
           AND date_part('year', age(c.birth_date)) BETWEEN me.age_min AND me.age_max
           AND me.age BETWEEN cp.age_min AND cp.age_max
           AND ${dist} <= me.max_distance_km
           AND NOT ${BLOCKED_SQL('me.user_id', 'c.user_id')}
           AND NOT EXISTS (SELECT 1 FROM likes l WHERE l.from_user = me.user_id AND l.to_user = c.user_id)
           AND NOT EXISTS (SELECT 1 FROM likes l WHERE l.from_user = c.user_id AND l.to_user = me.user_id
                             AND l.status = 'removed')
           AND NOT EXISTS (SELECT 1 FROM skips s WHERE s.from_user = me.user_id AND s.to_user = c.user_id
                             AND s.created_at > now() - make_interval(days => $2))
           AND NOT EXISTS (SELECT 1 FROM matches m
                             WHERE m.user_a = LEAST(me.user_id, c.user_id) AND m.user_b = GREATEST(me.user_id, c.user_id))
       )
       SELECT user_id,
              ( CASE WHEN verification_status = 'verified' THEN 0.15 ELSE 0 END
              + CASE WHEN last_active_at > now() - interval '1 day' THEN 0.25
                     WHEN last_active_at > now() - interval '7 days' THEN 0.10 ELSE 0 END
              + CASE WHEN created_at > now() - interval '7 days' THEN 0.20 ELSE 0 END
              + CASE WHEN likes_me THEN 0.30 ELSE 0 END
              + CASE WHEN recent_likes_received < 3 THEN 0.10 ELSE 0 END
              - LEAST(0.30, recent_likes_received * 0.02)
              + 0.20 * (1 - distance_km / GREATEST(max_distance_km, 1))
              )::float8 AS score
       FROM pool
       ORDER BY score DESC, user_id
       LIMIT ${CANDIDATE_POOL}`,
      [userId, this.config.skipCooldownDays],
    );
  }

  async feed(userId: string, limit: number, random: () => number = Math.random): Promise<ProfileCard[]> {
    const ranked = await this.candidates(userId);
    const exploreCount = Math.min(Math.floor(limit * EXPLORATION_SHARE), Math.max(0, ranked.length - limit));
    const best = ranked.slice(0, limit - exploreCount);
    const rest = ranked.slice(best.length);
    const explore: Candidate[] = [];
    while (explore.length < exploreCount && rest.length) {
      explore.push(rest.splice(Math.floor(random() * rest.length), 1)[0]);
    }
    const mixed = [...best];
    for (const c of explore) mixed.splice(Math.floor(random() * (mixed.length + 1)), 0, c);
    return this.cards.build(mixed.map((c) => c.user_id), userId);
  }
}
