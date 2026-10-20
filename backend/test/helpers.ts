import 'reflect-metadata';
import { INestApplication } from '@nestjs/common';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';
import { createApp } from '../src/bootstrap';
import { AppConfig, loadConfig } from '../src/config';

// 1x1 transparent PNG.
export const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  'base64',
);

export async function testApp(overrides: Partial<AppConfig> = {}): Promise<INestApplication> {
  const config = loadConfig({
    databaseUrl: 'memory://',
    mediaDir: mkdtempSync(join(tmpdir(), 'kindred-media-')),
    otpDevBypass: true,
    moderationProvider: 'auto',
    verificationProvider: 'auto',
    adminToken: 'test-admin',
    ...overrides,
  });
  const app = await createApp(config, { logger: false });
  await app.init();
  return app;
}

let phoneSeq = 0;
let placeSeq = 0;

/** A location far from every other place() so tests that read the discovery feed do not see each other's users. */
export function place(): { lat: number; lng: number } {
  placeSeq++;
  return { lat: -60 + (placeSeq % 40) * 3, lng: -170 + Math.floor(placeSeq / 40) * 20 };
}

export interface TestUser {
  id: string;
  token: string;
  phone: string;
  photoIds: string[];
  promptIds: string[];
}

export function api(app: INestApplication, token?: string) {
  const server = app.getHttpServer();
  const auth = (r: request.Test) => (token ? r.set('Authorization', `Bearer ${token}`) : r);
  return {
    get: (url: string) => auth(request(server).get(url)),
    post: (url: string, body?: object) => auth(request(server).post(url)).send(body ?? {}),
    put: (url: string, body?: object) => auth(request(server).put(url)).send(body ?? {}),
    patch: (url: string, body?: object) => auth(request(server).patch(url)).send(body ?? {}),
    delete: (url: string) => auth(request(server).delete(url)),
    upload: (url: string, buf: Buffer, contentType: string) =>
      auth(request(server).post(url)).attach('file', buf, { filename: 'f', contentType }),
  };
}

export async function signUp(app: INestApplication): Promise<{ id: string; token: string; phone: string }> {
  const phone = `+9190000${String(++phoneSeq).padStart(5, '0')}`;
  const res = await api(app).post('/auth/otp/verify', { phone, code: '000000' }).expect(200);
  return { id: res.body.userId, token: res.body.token, phone };
}

export interface ProfileOpts {
  firstName?: string;
  gender?: 'woman' | 'man' | 'nonbinary';
  showMe?: ('woman' | 'man' | 'nonbinary')[];
  birthDate?: string;
  lat?: number;
  lng?: number;
}

/** Signs up and completes a full profile (basics, 6 photos, 3 prompts) so it goes live. */
export async function liveUser(app: INestApplication, opts: ProfileOpts = {}): Promise<TestUser> {
  const u = await signUp(app);
  const a = api(app, u.token);
  await a
    .patch('/me/basics', {
      firstName: opts.firstName ?? 'Test',
      birthDate: opts.birthDate ?? '1997-05-10',
      gender: opts.gender ?? 'woman',
      showMe: opts.showMe ?? ['man'],
      intent: 'long_term',
      heightCm: 165,
      location: { lat: opts.lat ?? 12.9716, lng: opts.lng ?? 77.5946, city: 'Bengaluru' },
    })
    .expect(200);
  for (let i = 0; i < 6; i++) {
    const media = await a.upload('/media/photo', PNG, 'image/png').expect(201);
    await a.put(`/me/photos/${i}`, { mediaId: media.body.id, caption: i === 0 ? 'Sunday hike' : undefined }).expect(200);
  }
  let me: any;
  for (let i = 0; i < 3; i++) {
    me = (await a.put(`/me/prompts/${i}`, { promptId: `p00${i + 1}`, answer: `Answer number ${i + 1}` }).expect(200)).body;
  }
  return {
    ...u,
    photoIds: me.photos.map((p: any) => p.id),
    promptIds: me.prompts.map((p: any) => p.id),
  };
}
