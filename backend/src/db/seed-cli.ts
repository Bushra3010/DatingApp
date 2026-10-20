import { loadConfig } from '../config';
import { Db } from './db.service';
import { migrate } from './migrate';

/** Seeds live demo profiles around Bengaluru for local development. Log in as any of them with code 000000. */
const NAMES: [string, 'woman' | 'man' | 'nonbinary', ('woman' | 'man' | 'nonbinary')[]][] = [
  ['Aisha', 'woman', ['man']], ['Kavya', 'woman', ['man']], ['Priya', 'woman', ['man', 'woman']],
  ['Neha', 'woman', ['man']], ['Zara', 'woman', ['woman']], ['Arjun', 'man', ['woman']],
  ['Vikram', 'man', ['woman']], ['Kabir', 'man', ['woman']], ['Dev', 'man', ['man']], ['Rio', 'nonbinary', ['woman', 'man', 'nonbinary']],
];

(async () => {
  const db = new Db(loadConfig().databaseUrl);
  await migrate(db, console.log);
  for (const [i, [name, gender, showMe]] of NAMES.entries()) {
    const phone = `+91999000${String(i).padStart(4, '0')}`;
    if (await db.one(`SELECT 1 FROM users WHERE phone = $1`, [phone])) continue;
    await db.tx(async (q) => {
      const [u] = await q.query(`INSERT INTO users (phone, status) VALUES ($1, 'active') RETURNING id`, [phone]);
      await q.query(
        `INSERT INTO profiles (user_id, first_name, birth_date, gender, show_me, intent, height_cm, lat, lng, city, vitals, verification_status)
         VALUES ($1, $2, $3, $4, $5, 'long_term', $6, $7, $8, 'Bengaluru', $9, $10)`,
        [
          u.id, name, `${1990 + i}-0${(i % 9) + 1}-15`, gender, showMe, 155 + i * 3,
          12.9716 + (i - 5) * 0.01, 77.5946 + (i - 5) * 0.01,
          JSON.stringify({ work: { value: 'Product designer', visible: true }, languages: { value: 'English, Hindi', visible: true } }),
          i % 2 ? 'verified' : 'none',
        ],
      );
      await q.query(`INSERT INTO preferences (user_id) VALUES ($1)`, [u.id]);
      await q.query(`INSERT INTO settings (user_id) VALUES ($1)`, [u.id]);
      for (let p = 0; p < 6; p++) {
        const [m] = await q.query(
          `INSERT INTO media (owner_id, kind, url, mime_type, size_bytes) VALUES ($1, 'photo', $2, 'image/jpeg', 0) RETURNING id`,
          [u.id, `https://picsum.photos/seed/kindred-${i}-${p}/600/800`],
        );
        await q.query(
          `INSERT INTO photos (user_id, media_id, position, moderation_status) VALUES ($1, $2, $3, 'approved')`,
          [u.id, m.id, p],
        );
      }
      for (let p = 0; p < 3; p++) {
        await q.query(
          `INSERT INTO profile_prompts (user_id, prompt_id, answer, position) VALUES ($1, $2, $3, $4)`,
          [u.id, `p0${String(10 + i * 3 + p).padStart(2, '0')}`, `${name}'s answer ${p + 1}`, p],
        );
      }
    });
    console.log(`seeded ${name} (${phone})`);
  }
  await db.onModuleDestroy();
})();
