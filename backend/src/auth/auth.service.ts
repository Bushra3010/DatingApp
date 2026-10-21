import { ForbiddenException, HttpException, HttpStatus, Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { APP_CONFIG, AppConfig } from '../config';
import { Db } from '../db/db.service';
import { SmsProvider } from './sms.provider';

const OTP_TTL_MINUTES = 10;
const MAX_REQUESTS_PER_HOUR = 5;
const MAX_ATTEMPTS = 5;
const DEV_CODE = '000000';

@Injectable()
export class AuthService {
  constructor(
    private readonly db: Db,
    private readonly jwt: JwtService,
    private readonly sms: SmsProvider,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private hash(phone: string, code: string): string {
    return createHmac('sha256', this.config.jwtSecret).update(`${phone}:${code}`).digest('hex');
  }

  private async assertNotBanned(phone: string): Promise<void> {
    const ban = await this.db.one(`SELECT 1 FROM banned_identifiers WHERE kind = 'phone' AND value = $1`, [phone]);
    if (ban) throw new ForbiddenException('This phone number cannot be used');
  }

  async requestOtp(phone: string): Promise<{ expiresInSeconds: number }> {
    await this.assertNotBanned(phone);
    const recent = await this.db.one<{ n: number }>(
      `SELECT count(*)::int AS n FROM otp_codes WHERE phone = $1 AND created_at > now() - interval '1 hour'`,
      [phone],
    );
    if (recent!.n >= MAX_REQUESTS_PER_HOUR) {
      throw new HttpException('Too many codes requested, try again later', HttpStatus.TOO_MANY_REQUESTS);
    }
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    await this.db.query(
      `INSERT INTO otp_codes (phone, code_hash, expires_at) VALUES ($1, $2, now() + make_interval(mins => $3))`,
      [phone, this.hash(phone, code), OTP_TTL_MINUTES],
    );
    await this.sms.send(phone, `${code} is your Everlane code. It expires in ${OTP_TTL_MINUTES} minutes.`);
    return { expiresInSeconds: OTP_TTL_MINUTES * 60 };
  }

  async verifyOtp(phone: string, code: string): Promise<{ token: string; userId: string; isNew: boolean; status: string }> {
    await this.assertNotBanned(phone);
    const bypass = this.config.otpDevBypass && code === DEV_CODE;
    if (!bypass) {
      const otp = await this.db.one<{ id: string; code_hash: string; attempts: number }>(
        `SELECT id, code_hash, attempts FROM otp_codes
         WHERE phone = $1 AND used_at IS NULL AND expires_at > now()
         ORDER BY created_at DESC LIMIT 1`,
        [phone],
      );
      if (!otp || otp.attempts >= MAX_ATTEMPTS) throw new UnauthorizedException('Code expired, request a new one');
      const expected = Buffer.from(otp.code_hash, 'hex');
      const given = Buffer.from(this.hash(phone, code), 'hex');
      if (!timingSafeEqual(expected, given)) {
        await this.db.query(`UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1`, [otp.id]);
        throw new UnauthorizedException('Incorrect code');
      }
      await this.db.query(`UPDATE otp_codes SET used_at = now() WHERE id = $1`, [otp.id]);
    }

    const existing = await this.db.one<{ id: string; status: string }>(
      `SELECT id, status FROM users WHERE phone = $1 AND status <> 'deleted'`,
      [phone],
    );
    if (existing?.status === 'banned') throw new ForbiddenException('Account banned');
    let user = existing;
    let isNew = false;
    if (!user) {
      isNew = true;
      user = await this.db.tx(async (q) => {
        const [u] = await q.query<{ id: string; status: string }>(
          `INSERT INTO users (phone) VALUES ($1) RETURNING id, status`,
          [phone],
        );
        await q.query(`INSERT INTO profiles (user_id) VALUES ($1)`, [u.id]);
        await q.query(`INSERT INTO preferences (user_id) VALUES ($1)`, [u.id]);
        await q.query(`INSERT INTO settings (user_id) VALUES ($1)`, [u.id]);
        return u;
      });
    }
    const token = await this.jwt.signAsync({ sub: user.id });
    return { token, userId: user.id, isNew, status: user.status };
  }
}
