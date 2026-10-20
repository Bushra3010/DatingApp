import { Injectable } from '@nestjs/common';
import { Db } from '../db/db.service';
import { ageFrom, displayDistance, distanceKmSql } from '../common/geo';

export const VITAL_KEYS = [
  'work', 'education', 'hometown', 'religion', 'languages', 'drinking', 'smoking', 'family_plans',
] as const;
export type VitalKey = (typeof VITAL_KEYS)[number];
export type Vitals = Partial<Record<VitalKey, { value: string; visible: boolean }>>;

export interface ProfileCard {
  userId: string;
  firstName: string;
  age: number;
  gender: string;
  verified: boolean;
  distance: string | null;
  intent: string;
  heightCm: number | null;
  vitals: Partial<Record<VitalKey, string>>;
  photos: { id: string; url: string; caption: string | null }[];
  prompts: { id: string; promptId: string; question: string; answer: string }[];
}

/** Builds profiles as other people see them: approved photos only, visible vitals only, rounded distance. */
@Injectable()
export class ProfileCards {
  constructor(private readonly db: Db) {}

  async build(userIds: string[], viewerId: string): Promise<ProfileCard[]> {
    if (userIds.length === 0) return [];
    const profiles = await this.db.query(
      `SELECT p.user_id, p.first_name, p.birth_date, p.gender, p.intent, p.height_cm, p.vitals,
              p.verification_status,
              CASE WHEN p.lat IS NULL OR v.lat IS NULL THEN NULL
                   ELSE ${distanceKmSql('v.lat', 'v.lng', 'p.lat', 'p.lng')} END AS distance_km
       FROM profiles p
       LEFT JOIN profiles v ON v.user_id = $2
       WHERE p.user_id = ANY($1::uuid[])`,
      [userIds, viewerId],
    );
    const photos = await this.db.query(
      `SELECT ph.id, ph.user_id, ph.caption, m.url FROM photos ph JOIN media m ON m.id = ph.media_id
       WHERE ph.user_id = ANY($1::uuid[]) AND ph.moderation_status = 'approved' ORDER BY ph.position`,
      [userIds],
    );
    const prompts = await this.db.query(
      `SELECT pp.id, pp.user_id, pp.prompt_id, pl.text AS question, pp.answer
       FROM profile_prompts pp JOIN prompt_library pl ON pl.id = pp.prompt_id
       WHERE pp.user_id = ANY($1::uuid[]) ORDER BY pp.position`,
      [userIds],
    );
    const byId = new Map<string, ProfileCard>();
    for (const p of profiles) {
      const vitals: ProfileCard['vitals'] = {};
      for (const key of VITAL_KEYS) {
        const v = (p.vitals as Vitals)[key];
        if (v?.visible && v.value) vitals[key] = v.value;
      }
      byId.set(p.user_id, {
        userId: p.user_id,
        firstName: p.first_name,
        age: ageFrom(p.birth_date),
        gender: p.gender,
        verified: p.verification_status === 'verified',
        distance: p.user_id === viewerId ? null : displayDistance(p.distance_km === null ? null : Number(p.distance_km)),
        intent: p.intent,
        heightCm: p.height_cm,
        vitals,
        photos: [],
        prompts: [],
      });
    }
    for (const ph of photos) byId.get(ph.user_id)?.photos.push({ id: ph.id, url: ph.url, caption: ph.caption });
    for (const pr of prompts) {
      byId.get(pr.user_id)?.prompts.push({ id: pr.id, promptId: pr.prompt_id, question: pr.question, answer: pr.answer });
    }
    return userIds.map((id) => byId.get(id)).filter((c): c is ProfileCard => !!c);
  }

  async one(userId: string, viewerId: string): Promise<ProfileCard | undefined> {
    return (await this.build([userId], viewerId))[0];
  }
}
