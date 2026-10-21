import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Db, Queryable } from '../db/db.service';
import { ageFrom } from '../common/geo';
import { screenText } from '../common/text-screen';
import { PhotoModerator, SelfieVerifier } from '../moderation/moderation.providers';
import { ProfileCards, Vitals } from './profile-cards.service';

export const REQUIRED_PHOTOS = 6;
export const REQUIRED_PROMPTS = 3;
export const GENDERS = ['woman', 'man', 'nonbinary'] as const;
export const INTENTS = ['long_term', 'long_term_open_short', 'figuring_out'] as const;

export interface BasicsInput {
  firstName?: string;
  birthDate?: string;
  gender?: (typeof GENDERS)[number];
  showMe?: (typeof GENDERS)[number][];
  intent?: (typeof INTENTS)[number];
  heightCm?: number;
  location?: { lat: number; lng: number; city?: string };
}

@Injectable()
export class ProfilesService {
  constructor(
    private readonly db: Db,
    private readonly cards: ProfileCards,
    private readonly photoModerator: PhotoModerator,
    private readonly verifier: SelfieVerifier,
  ) {}

  /** The owner's view: everything, including hidden vitals, photo review state and what is missing. */
  async me(userId: string) {
    const user = await this.db.one(
      `SELECT u.id, u.phone, u.status, u.plan, u.plan_expires_at, p.*
       FROM users u JOIN profiles p ON p.user_id = u.id WHERE u.id = $1`,
      [userId],
    );
    if (!user) throw new NotFoundException();
    const photos = await this.db.query(
      `SELECT ph.id, ph.position, ph.caption, ph.moderation_status, m.url
       FROM photos ph JOIN media m ON m.id = ph.media_id WHERE ph.user_id = $1 ORDER BY ph.position`,
      [userId],
    );
    const prompts = await this.db.query(
      `SELECT pp.id, pp.position, pp.prompt_id, pl.text AS question, pp.answer
       FROM profile_prompts pp JOIN prompt_library pl ON pl.id = pp.prompt_id
       WHERE pp.user_id = $1 ORDER BY pp.position`,
      [userId],
    );
    return {
      id: user.id,
      phone: user.phone,
      status: user.status,
      plan: user.plan,
      planExpiresAt: user.plan_expires_at,
      firstName: user.first_name,
      birthDate: user.birth_date,
      age: user.birth_date ? ageFrom(user.birth_date) : null,
      gender: user.gender,
      showMe: user.show_me,
      intent: user.intent,
      heightCm: user.height_cm,
      location: user.lat === null ? null : { lat: user.lat, lng: user.lng, city: user.city },
      vitals: user.vitals,
      verificationStatus: user.verification_status,
      photos: photos.map((p) => ({
        id: p.id, position: p.position, url: p.url, caption: p.caption, moderationStatus: p.moderation_status,
      })),
      prompts: prompts.map((p) => ({
        id: p.id, position: p.position, promptId: p.prompt_id, question: p.question, answer: p.answer,
      })),
      missing: await this.missing(this.db, userId),
    };
  }

  /** What still blocks the profile from going live (ON-3, ON-4). Empty means ready. */
  async missing(q: Queryable, userId: string): Promise<string[]> {
    const [row] = await q.query(
      `SELECT p.first_name, p.birth_date, p.gender, cardinality(p.show_me) AS show_me_count, p.intent,
              p.height_cm, p.lat,
              (SELECT count(*)::int FROM photos WHERE user_id = p.user_id AND moderation_status = 'approved') AS approved,
              (SELECT count(*)::int FROM photos WHERE user_id = p.user_id AND moderation_status = 'pending') AS pending,
              (SELECT count(*)::int FROM profile_prompts WHERE user_id = p.user_id) AS prompts
       FROM profiles p WHERE p.user_id = $1`,
      [userId],
    );
    const missing: string[] = [];
    if (!row.first_name) missing.push('first_name');
    if (!row.birth_date) missing.push('birth_date');
    if (!row.gender) missing.push('gender');
    if (!row.show_me_count) missing.push('show_me');
    if (!row.intent) missing.push('intent');
    if (!row.height_cm) missing.push('height');
    if (row.lat === null) missing.push('location');
    if (row.approved < REQUIRED_PHOTOS) {
      missing.push(row.approved + row.pending >= REQUIRED_PHOTOS ? 'photos_in_review' : 'photos');
    }
    if (row.prompts < REQUIRED_PROMPTS) missing.push('prompts');
    return missing;
  }

  /** Moves a profile between onboarding and active as it becomes complete or incomplete. Paused/banned stay put. */
  async refreshStatus(userId: string): Promise<string> {
    return this.db.tx(async (q) => {
      const [{ status }] = await q.query(`SELECT status FROM users WHERE id = $1 FOR UPDATE`, [userId]);
      if (status !== 'onboarding' && status !== 'active') return status;
      const next = (await this.missing(q, userId)).length === 0 ? 'active' : 'onboarding';
      if (next !== status) await q.query(`UPDATE users SET status = $2 WHERE id = $1`, [userId, next]);
      return next;
    });
  }

  async updateBasics(userId: string, input: BasicsInput) {
    const current = await this.db.one(`SELECT birth_date FROM profiles WHERE user_id = $1`, [userId]);
    if (input.birthDate !== undefined) {
      // ON-2: date of birth is locked after setup and must be 18+.
      if (current.birth_date) throw new ForbiddenException('Date of birth cannot be changed');
      if (ageFrom(input.birthDate) < 18) throw new ForbiddenException('You must be 18 or older to use Everlane');
    }
    if (input.firstName !== undefined && screenText(input.firstName).length) {
      throw new BadRequestException('Name contains contact or payment details');
    }
    await this.db.query(
      `UPDATE profiles SET
         first_name = COALESCE($2, first_name),
         birth_date = COALESCE($3::date, birth_date),
         gender     = COALESCE($4, gender),
         show_me    = COALESCE($5::text[], show_me),
         intent     = COALESCE($6, intent),
         height_cm  = COALESCE($7, height_cm),
         lat        = COALESCE($8, lat),
         lng        = COALESCE($9, lng),
         city       = COALESCE($10, city),
         updated_at = now()
       WHERE user_id = $1`,
      [
        userId, input.firstName ?? null, input.birthDate ?? null, input.gender ?? null, input.showMe ?? null,
        input.intent ?? null, input.heightCm ?? null, input.location?.lat ?? null, input.location?.lng ?? null,
        input.location?.city ?? null,
      ],
    );
    await this.refreshStatus(userId);
    return this.me(userId);
  }

  async updateVitals(userId: string, vitals: Vitals) {
    for (const v of Object.values(vitals)) {
      if (v && screenText(v.value).length) throw new BadRequestException('Vitals cannot contain contact or payment details');
    }
    await this.db.query(
      `UPDATE profiles SET vitals = vitals || $2::jsonb, updated_at = now() WHERE user_id = $1`,
      [userId, JSON.stringify(vitals)],
    );
    return this.me(userId);
  }

  /** Puts a photo or video into one of the 6 slots (PR-1), replacing whatever was there, and sends it to moderation. */
  async setPhoto(userId: string, position: number, mediaId: string, caption: string | null) {
    const media = await this.db.one(
      `SELECT id, url, kind FROM media WHERE id = $1 AND owner_id = $2`,
      [mediaId, userId],
    );
    if (!media || (media.kind !== 'photo' && media.kind !== 'video')) throw new BadRequestException('Unknown photo');
    if (caption && screenText(caption).length) throw new BadRequestException('Caption contains contact or payment details');
    const review = await this.photoModerator.review(media.url);
    await this.db.tx(async (q) => {
      await q.query(`DELETE FROM photos WHERE user_id = $1 AND position = $2`, [userId, position]);
      await q.query(
        `INSERT INTO photos (user_id, media_id, position, caption, moderation_status, moderation_reason)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [userId, mediaId, position, caption, review.status, review.reason ?? null],
      );
    });
    await this.refreshStatus(userId);
    return this.me(userId);
  }

  async removePhoto(userId: string, position: number) {
    await this.db.query(`DELETE FROM photos WHERE user_id = $1 AND position = $2`, [userId, position]);
    await this.refreshStatus(userId);
    return this.me(userId);
  }

  /** Reorders photos: `order` lists the user's photo ids in their new slot order. */
  async reorderPhotos(userId: string, order: string[]) {
    const owned = await this.db.query(`SELECT id FROM photos WHERE user_id = $1`, [userId]);
    const ownedIds = new Set(owned.map((r) => r.id));
    if (order.length !== ownedIds.size || !order.every((id) => ownedIds.has(id)) || new Set(order).size !== order.length) {
      throw new BadRequestException('Order must list each of your photos exactly once');
    }
    await this.db.tx(async (q) => {
      for (const [i, id] of order.entries()) {
        await q.query(`UPDATE photos SET position = $2 WHERE id = $1`, [id, i]);
      }
    });
    return this.me(userId);
  }

  prompts() {
    return this.db.query(`SELECT id, category, text FROM prompt_library WHERE is_active ORDER BY id`);
  }

  async setPrompt(userId: string, position: number, promptId: string, answer: string) {
    if (screenText(answer).length) throw new BadRequestException('Answers cannot contain contact or payment details');
    const prompt = await this.db.one(`SELECT id FROM prompt_library WHERE id = $1 AND is_active`, [promptId]);
    if (!prompt) throw new BadRequestException('Unknown prompt');
    await this.db.tx(async (q) => {
      await q.query(`DELETE FROM profile_prompts WHERE user_id = $1 AND (position = $2 OR prompt_id = $3)`, [
        userId, position, promptId,
      ]);
      await q.query(
        `INSERT INTO profile_prompts (user_id, prompt_id, answer, position) VALUES ($1, $2, $3, $4)`,
        [userId, promptId, answer.trim(), position],
      );
    });
    await this.refreshStatus(userId);
    return this.me(userId);
  }

  async removePrompt(userId: string, position: number) {
    await this.db.query(`DELETE FROM profile_prompts WHERE user_id = $1 AND position = $2`, [userId, position]);
    await this.refreshStatus(userId);
    return this.me(userId);
  }

  /** PR-6: the profile exactly as other people see it. */
  preview(userId: string) {
    return this.cards.one(userId, userId);
  }

  async submitVerification(userId: string, mediaId: string) {
    const media = await this.db.one(
      `SELECT url FROM media WHERE id = $1 AND owner_id = $2 AND kind = 'verification'`,
      [mediaId, userId],
    );
    if (!media) throw new BadRequestException('Upload a verification video first');
    const photoUrls = (
      await this.db.query(
        `SELECT m.url FROM photos ph JOIN media m ON m.id = ph.media_id WHERE ph.user_id = $1`,
        [userId],
      )
    ).map((r) => r.url);
    const status = await this.verifier.verify(media.url, photoUrls);
    await this.db.query(
      `UPDATE profiles SET verification_status = $2, verification_media = $3 WHERE user_id = $1`,
      [userId, status, media.url],
    );
    return { verificationStatus: status };
  }
}
