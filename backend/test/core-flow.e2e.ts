import { INestApplication } from '@nestjs/common';
import { io, Socket } from 'socket.io-client';
import { AddressInfo } from 'node:net';
import { SmsProvider, ConsoleSmsProvider } from '../src/auth/sms.provider';
import { api, liveUser, place, PNG, signUp, testApp } from './helpers';

describe('Everlane MVP core flow', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await testApp();
  });
  afterAll(async () => {
    await app.close();
  });

  describe('auth and onboarding', () => {
    it('signs up with a real OTP code from the SMS provider', async () => {
      const phone = '+919812345678';
      await api(app).post('/auth/otp/request', { phone }).expect(200);
      const sms = app.get(SmsProvider) as ConsoleSmsProvider;
      const code = sms.outbox.at(-1)!.text.slice(0, 6);
      await api(app).post('/auth/otp/verify', { phone, code: code === '999999' ? '999998' : '999999' }).expect(401);
      const res = await api(app).post('/auth/otp/verify', { phone, code }).expect(200);
      expect(res.body).toMatchObject({ isNew: true, status: 'onboarding' });
      // Same phone logs back into the same account.
      const again = await api(app).post('/auth/otp/verify', { phone, code: '000000' }).expect(200);
      expect(again.body.userId).toBe(res.body.userId);
      expect(again.body.isNew).toBe(false);
    });

    it('rejects malformed phone numbers', async () => {
      await api(app).post('/auth/otp/request', { phone: '98123' }).expect(400);
    });

    it('enforces the 18+ gate and locks date of birth', async () => {
      const u = await signUp(app);
      const a = api(app, u.token);
      const minor = new Date();
      minor.setFullYear(minor.getFullYear() - 17);
      await a.patch('/me/basics', { birthDate: minor.toISOString().slice(0, 10) }).expect(403);
      await a.patch('/me/basics', { birthDate: '1995-01-01' }).expect(200);
      await a.patch('/me/basics', { birthDate: '1990-01-01' }).expect(403);
    });

    it('stays in onboarding until 6 photos and 3 prompts, then goes live', async () => {
      const u = await signUp(app);
      const a = api(app, u.token);
      let me = (await a.get('/me').expect(200)).body;
      expect(me.status).toBe('onboarding');
      expect(me.missing).toEqual(expect.arrayContaining(['first_name', 'photos', 'prompts', 'location']));
      await a.get('/discover').expect(403);

      const live = await liveUser(app);
      me = (await api(app, live.token).get('/me').expect(200)).body;
      expect(me.status).toBe('active');
      expect(me.missing).toEqual([]);
      expect(me.photos).toHaveLength(6);
      expect(me.prompts).toHaveLength(3);
    });

    it('rejects contact details in prompt answers', async () => {
      const u = await signUp(app);
      await api(app, u.token)
        .put('/me/prompts/0', { promptId: 'p001', answer: 'Call me on +91 98765 43210' })
        .expect(400);
    });

    it('serves the prompt library with 80+ prompts', async () => {
      const u = await signUp(app);
      const res = await api(app, u.token).get('/prompts').expect(200);
      expect(res.body.length).toBeGreaterThanOrEqual(80);
    });

    it('rejects unsupported media types', async () => {
      const u = await signUp(app);
      await api(app, u.token).upload('/media/photo', Buffer.from('hi'), 'text/plain').expect(400);
    });

    it('previews only visible vitals and verifies via selfie video', async () => {
      const u = await liveUser(app);
      const a = api(app, u.token);
      await a
        .patch('/me/vitals', { work: { value: 'Designer', visible: true }, religion: { value: 'Hindu', visible: false } })
        .expect(200);
      const preview = (await a.get('/me/preview').expect(200)).body;
      expect(preview.vitals).toEqual({ work: 'Designer' });
      expect(preview.verified).toBe(false);
      expect(preview.photos[0].caption).toBe('Sunday hike');

      const video = await a.upload('/media/verification', PNG, 'video/mp4').expect(201);
      const v = await a.post('/me/verification', { mediaId: video.body.id }).expect(201);
      expect(v.body.verificationStatus).toBe('verified');
      expect((await a.get('/me/preview').expect(200)).body.verified).toBe(true);
    });
  });

  describe('discovery, likes and matching', () => {
    it('shows mutually compatible people only, with rounded distance', async () => {
      const here = { lat: 12.9716, lng: 77.5946 };
      const woman = await liveUser(app, { firstName: 'Ananya', gender: 'woman', showMe: ['man'], ...here });
      const man = await liveUser(app, { firstName: 'Rohit', gender: 'man', showMe: ['woman'], lat: 12.99, lng: 77.6 });
      const manSeekingMen = await liveUser(app, { gender: 'man', showMe: ['man'], ...here });
      const farMan = await liveUser(app, { gender: 'man', showMe: ['woman'], lat: 18.52, lng: 73.85 });

      const feed = (await api(app, woman.token).get('/discover').expect(200)).body;
      const ids = feed.map((c: any) => c.userId);
      expect(ids).toContain(man.id);
      expect(ids).not.toContain(manSeekingMen.id);
      expect(ids).not.toContain(farMan.id);
      const card = feed.find((c: any) => c.userId === man.id);
      expect(card.distance).toBe('2 km away');
      expect(card).not.toHaveProperty('phone');
      expect(card.photos).toHaveLength(6);
    });

    it('likes a prompt with a comment, shows it in Likes You and matches on like back', async () => {
      const her = await liveUser(app, { firstName: 'Meera', gender: 'woman', showMe: ['man'] });
      const him = await liveUser(app, { firstName: 'Sam', gender: 'man', showMe: ['woman'] });

      const like = await api(app, him.token)
        .post('/likes', { toUserId: her.id, targetType: 'prompt', targetId: her.promptIds[1], comment: 'Tell me more!' })
        .expect(201);
      expect(like.body).toMatchObject({ matched: false, remainingLikes: 7 });
      await api(app, him.token)
        .post('/likes', { toUserId: her.id, targetType: 'photo', targetId: her.photoIds[0] })
        .expect(409);

      // He is no longer in his own feed's target list; she sees his like with context.
      const himFeed = (await api(app, him.token).get('/discover').expect(200)).body;
      expect(himFeed.map((c: any) => c.userId)).not.toContain(her.id);

      const inbox = (await api(app, her.token).get('/likes/received').expect(200)).body;
      expect(inbox.total).toBe(1);
      expect(inbox.likes[0]).toMatchObject({
        comment: 'Tell me more!',
        liked: { type: 'prompt', question: 'A small thing that makes my whole day', answer: 'Answer number 2' },
        profile: { userId: him.id, firstName: 'Sam' },
      });

      const match = await api(app, her.token).post(`/likes/${inbox.likes[0].likeId}/match`, { comment: 'Hi Sam!' }).expect(200);
      const matches = (await api(app, him.token).get('/matches').expect(200)).body;
      expect(matches).toHaveLength(1);
      expect(matches[0]).toMatchObject({ matchId: match.body.matchId, other: { firstName: 'Meera' }, yourTurn: true });

      const msgs = (await api(app, him.token).get(`/matches/${match.body.matchId}/messages`).expect(200)).body;
      expect(msgs.map((m: any) => m.kind)).toEqual(['text', 'like_context']);
      expect(msgs[1]).toMatchObject({ comment: 'Tell me more!', liked: { type: 'prompt', id: her.promptIds[1] }, fromMe: true });
      expect((await api(app, her.token).get('/likes/received').expect(200)).body.total).toBe(0);
    });

    it('matches straight away when both like each other from discovery', async () => {
      const a = await liveUser(app, { gender: 'woman', showMe: ['man'] });
      const b = await liveUser(app, { gender: 'man', showMe: ['woman'] });
      await api(app, a.token).post('/likes', { toUserId: b.id, targetType: 'photo', targetId: b.photoIds[2] }).expect(201);
      const back = await api(app, b.token)
        .post('/likes', { toUserId: a.id, targetType: 'prompt', targetId: a.promptIds[0], comment: 'Same!' })
        .expect(201);
      expect(back.body.matched).toBe(true);
      const msgs = (await api(app, a.token).get(`/matches/${back.body.matchId}/messages`).expect(200)).body;
      expect(msgs[0]).toMatchObject({ kind: 'text', body: 'Same!', fromMe: false });
    });

    it('enforces the free daily like limit and lifts it for Plus', async () => {
      const liker = await liveUser(app, { gender: 'man', showMe: ['woman'] });
      const targets = [];
      for (let i = 0; i < 9; i++) targets.push(await liveUser(app, { gender: 'woman', showMe: ['man'] }));
      const a = api(app, liker.token);
      for (let i = 0; i < 8; i++) {
        await a.post('/likes', { toUserId: targets[i].id, targetType: 'photo', targetId: targets[i].photoIds[0] }).expect(201);
      }
      const blocked = await a.post('/likes', { toUserId: targets[8].id, targetType: 'photo', targetId: targets[8].photoIds[0] });
      expect(blocked.status).toBe(429);
      expect(blocked.body.code).toBe('LIKE_LIMIT');

      await a.post('/billing/verify', { store: 'dev', productId: 'everlane_plus_1m', purchaseToken: `t-${liker.id}` }).expect(200);
      await a.post('/likes', { toUserId: targets[8].id, targetType: 'photo', targetId: targets[8].photoIds[0] }).expect(201);
      expect((await a.get('/likes/remaining').expect(200)).body).toEqual({ remaining: null, unlimited: true });
    });

    it('free users see one like at a time in order; Plus sees all', async () => {
      const her = await liveUser(app, { gender: 'woman', showMe: ['man'] });
      const likers = [];
      for (let i = 0; i < 3; i++) {
        const m = await liveUser(app, { gender: 'man', showMe: ['woman'] });
        await api(app, m.token).post('/likes', { toUserId: her.id, targetType: 'photo', targetId: her.photoIds[0] }).expect(201);
        likers.push(m);
      }
      const a = api(app, her.token);
      const free = (await a.get('/likes/received').expect(200)).body;
      expect(free).toMatchObject({ total: 3, canSeeAll: false });
      expect(free.likes).toHaveLength(1);
      expect(free.likes[0].profile.userId).toBe(likers[0].id);

      await a.post('/billing/verify', { store: 'dev', productId: 'everlane_plus_3m', purchaseToken: `t-${her.id}` }).expect(200);
      const plus = (await a.get('/likes/received?sort=newest').expect(200)).body;
      expect(plus.likes.map((l: any) => l.profile.userId)).toEqual([likers[2].id, likers[1].id, likers[0].id]);
    });

    it('skipped profiles leave the feed', async () => {
      const here = place();
      const a = await liveUser(app, { gender: 'nonbinary', showMe: ['nonbinary'], ...here });
      const b = await liveUser(app, { gender: 'nonbinary', showMe: ['nonbinary'], ...here });
      const before = (await api(app, a.token).get('/discover').expect(200)).body.map((c: any) => c.userId);
      expect(before).toContain(b.id);
      await api(app, a.token).post(`/skips/${b.id}`).expect(200);
      const after = (await api(app, a.token).get('/discover').expect(200)).body.map((c: any) => c.userId);
      expect(after).not.toContain(b.id);
    });
  });

  describe('chat and safety', () => {
    async function matchedPair() {
      const a = await liveUser(app, { firstName: 'A', gender: 'woman', showMe: ['man'] });
      const b = await liveUser(app, { firstName: 'B', gender: 'man', showMe: ['woman'] });
      await api(app, a.token).post('/likes', { toUserId: b.id, targetType: 'photo', targetId: b.photoIds[0] }).expect(201);
      const back = await api(app, b.token).post('/likes', { toUserId: a.id, targetType: 'photo', targetId: a.photoIds[0] }).expect(201);
      return { a, b, matchId: back.body.matchId as string };
    }

    it('delivers messages in real time with read receipts and typing', async () => {
      const { a, b, matchId } = await matchedPair();
      await app.listen(0);
      const port = (app.getHttpServer().address() as AddressInfo).port;
      const sock: Socket = io(`http://localhost:${port}/realtime`, { auth: { token: b.token }, transports: ['websocket'] });
      const sockA: Socket = io(`http://localhost:${port}/realtime`, { auth: { token: a.token }, transports: ['websocket'] });
      await Promise.all([sock, sockA].map((s) => new Promise<void>((r) => s.on('connect', () => r()))));
      try {
        const typing = new Promise((r) => sock.once('typing', r));
        sockA.emit('typing', { matchId });
        expect(await typing).toEqual({ matchId });

        const received = new Promise<any>((r) => sock.once('message:new', r));
        await api(app, a.token).post(`/matches/${matchId}/messages`, { kind: 'text', body: 'Coffee on Saturday?' }).expect(201);
        const evt = await received;
        expect(evt.message).toMatchObject({ body: 'Coffee on Saturday?', fromMe: false });

        const read = new Promise<any>((r) => sockA.once('message:read', r));
        await api(app, b.token).post(`/matches/${matchId}/read`).expect(200);
        expect((await read).matchId).toBe(matchId);
        const mine = (await api(app, a.token).get(`/matches/${matchId}/messages`).expect(200)).body;
        expect(mine[0].readAt).toBeTruthy();

        // B turns read receipts off: A no longer sees read times.
        await api(app, b.token).patch('/me/settings', { readReceipts: false }).expect(200);
        const hidden = (await api(app, a.token).get(`/matches/${matchId}/messages`).expect(200)).body;
        expect(hidden[0].readAt).toBeUndefined();
      } finally {
        sock.disconnect();
        sockA.disconnect();
      }
    });

    it('sends voice notes and GIFs, rejects GIFs from other hosts', async () => {
      const { a, matchId } = await matchedPair();
      const c = api(app, a.token);
      const voice = await c.upload('/media/voice', PNG, 'audio/aac').expect(201);
      await c.post(`/matches/${matchId}/messages`, { kind: 'voice', mediaId: voice.body.id, durationS: 61 }).expect(400);
      await c.post(`/matches/${matchId}/messages`, { kind: 'voice', mediaId: voice.body.id, durationS: 12 }).expect(201);
      await c.post(`/matches/${matchId}/messages`, { kind: 'gif', url: 'https://media.giphy.com/media/x/giphy.gif' }).expect(201);
      await c.post(`/matches/${matchId}/messages`, { kind: 'gif', url: 'https://evil.example/x.gif' }).expect(400);
    });

    it('unmatch removes the chat for both people but reporting stays available', async () => {
      const { a, b, matchId } = await matchedPair();
      await api(app, a.token).post(`/matches/${matchId}/unmatch`).expect(200);
      await api(app, b.token).get(`/matches/${matchId}/messages`).expect(404);
      expect((await api(app, b.token).get('/matches').expect(200)).body).toHaveLength(0);
      const r = await api(app, b.token).post('/reports', { userId: a.id, reason: 'harassment' }).expect(201);
      expect(r.body.priority).toBe('normal');
    });

    it('report hides the person at once, routes high severity first, and a ban locks the phone', async () => {
      const { a, b, matchId } = await matchedPair();
      const r = await api(app, a.token).post('/reports', { userId: b.id, reason: 'threats', details: 'Threatening messages' }).expect(201);
      expect(r.body.priority).toBe('high');
      await api(app, a.token).get(`/matches/${matchId}/messages`).expect(404);

      const admin = api(app);
      const queue = (await admin.get('/admin/reports').set('x-admin-token', 'test-admin').expect(200)).body;
      expect(queue[0].priority).toBe('high');
      await admin.get('/admin/reports').expect(401);

      await admin.post(`/admin/reports/${r.body.reportId}/resolve`, { action: 'ban' }).set('x-admin-token', 'test-admin').expect(200);
      await api(app, b.token).get('/me').expect(403);
      await api(app).post('/auth/otp/verify', { phone: b.phone, code: '000000' }).expect(403);
    });

    it('blocking hides both people from each other in discovery', async () => {
      const here = place();
      const a = await liveUser(app, { gender: 'woman', showMe: ['woman'], ...here });
      const b = await liveUser(app, { gender: 'woman', showMe: ['woman'], ...here });
      expect((await api(app, a.token).get('/discover').expect(200)).body.map((c: any) => c.userId)).toContain(b.id);
      await api(app, b.token).post(`/blocks/${a.id}`).expect(200);
      expect((await api(app, a.token).get('/discover').expect(200)).body.map((c: any) => c.userId)).not.toContain(b.id);
      expect((await api(app, b.token).get('/discover').expect(200)).body.map((c: any) => c.userId)).not.toContain(a.id);
    });
  });

  describe('account', () => {
    it('pause hides from discovery but keeps chats; unpause restores', async () => {
      const here = place();
      const a = await liveUser(app, { gender: 'man', showMe: ['nonbinary'], ...here });
      const b = await liveUser(app, { gender: 'nonbinary', showMe: ['man'], ...here });
      await api(app, a.token).post('/likes', { toUserId: b.id, targetType: 'photo', targetId: b.photoIds[0] }).expect(201);
      const m = await api(app, b.token).post('/likes', { toUserId: a.id, targetType: 'photo', targetId: a.photoIds[0] }).expect(201);

      const c = await liveUser(app, { gender: 'nonbinary', showMe: ['man'], ...here });
      await api(app, a.token).post('/me/pause').expect(200);
      expect((await api(app, c.token).get('/discover').expect(200)).body.map((x: any) => x.userId)).not.toContain(a.id);
      await api(app, a.token).get('/discover').expect(403);
      await api(app, b.token).get(`/matches/${m.body.matchId}/messages`).expect(200);

      expect((await api(app, a.token).post('/me/unpause').expect(200)).body.status).toBe('active');
      expect((await api(app, c.token).get('/discover').expect(200)).body.map((x: any) => x.userId)).toContain(a.id);
    });

    it('updates basic filters and rejects inverted age ranges', async () => {
      const a = await liveUser(app);
      await api(app, a.token).patch('/me/preferences', { ageMin: 30, ageMax: 25 }).expect(400);
      const res = await api(app, a.token).patch('/me/preferences', { ageMin: 25, ageMax: 35, maxDistanceKm: 20 }).expect(200);
      expect(res.body).toEqual({ ageMin: 25, ageMax: 35, maxDistanceKm: 20 });
    });

    it('exports data and deletes the account, freeing the phone number', async () => {
      const a = await liveUser(app);
      const exp = (await api(app, a.token).get('/me/export').expect(200)).body;
      expect(exp.profile.id).toBe(a.id);
      await api(app, a.token).delete('/me').expect(200);
      await api(app, a.token).get('/me').expect(401);
      const again = await api(app).post('/auth/otp/verify', { phone: a.phone, code: '000000' }).expect(200);
      expect(again.body.isNew).toBe(true);
    });

    it('respects push notification settings per type', async () => {
      const { Notifier } = await import('../src/common/notifier');
      const notifier = app.get(Notifier);
      const her = await liveUser(app, { gender: 'woman', showMe: ['woman'], lat: 22.72, lng: 75.86 });
      const other = await liveUser(app, { gender: 'woman', showMe: ['woman'], lat: 22.72, lng: 75.86 });
      await api(app, her.token).patch('/me/settings', { push: { likes: false } }).expect(200);
      await api(app, other.token).post('/likes', { toUserId: her.id, targetType: 'photo', targetId: her.photoIds[0] }).expect(201);
      expect(notifier.sent.filter((p) => p.userId === her.id && p.type === 'likes')).toHaveLength(0);
    });
  });
});
