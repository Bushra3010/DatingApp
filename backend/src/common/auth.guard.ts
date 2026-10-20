import {
  CanActivate, ExecutionContext, ForbiddenException, Inject, Injectable, UnauthorizedException,
  createParamDecorator,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { APP_CONFIG, AppConfig } from '../config';
import { Db } from '../db/db.service';

export interface AuthUser {
  id: string;
  status: 'onboarding' | 'active' | 'paused' | 'banned' | 'deleted';
  plan: 'free' | 'plus';
}

export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): AuthUser => {
  return ctx.switchToHttp().getRequest().user;
});

/** Resolves a bearer token to a live (not banned or deleted) user. Used by HTTP and WebSocket. */
@Injectable()
export class SessionResolver {
  constructor(private readonly jwt: JwtService, private readonly db: Db) {}

  async resolve(token: string | undefined): Promise<AuthUser> {
    if (!token) throw new UnauthorizedException('Missing token');
    let sub: string;
    try {
      sub = (await this.jwt.verifyAsync<{ sub: string }>(token)).sub;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
    const user = await this.db.one<AuthUser & { plan_expires_at: Date | null }>(
      `UPDATE users SET last_active_at = now() WHERE id = $1
       RETURNING id, status, plan, plan_expires_at`,
      [sub],
    );
    if (!user || user.status === 'deleted') throw new UnauthorizedException('Account not found');
    if (user.status === 'banned') throw new ForbiddenException('Account banned');
    const plan = user.plan === 'plus' && user.plan_expires_at && user.plan_expires_at > new Date() ? 'plus' : 'free';
    return { id: user.id, status: user.status, plan };
  }
}

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly sessions: SessionResolver) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    const header: string | undefined = req.headers.authorization;
    req.user = await this.sessions.resolve(header?.startsWith('Bearer ') ? header.slice(7) : undefined);
    return true;
  }
}

/** Shared-secret guard for the moderation/admin API until the admin console has its own auth. */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {}

  canActivate(ctx: ExecutionContext): boolean {
    const token = ctx.switchToHttp().getRequest().headers['x-admin-token'];
    if (token !== this.config.adminToken) throw new UnauthorizedException();
    return true;
  }
}

export function requireActive(user: AuthUser): void {
  if (user.status !== 'active') {
    throw new ForbiddenException(
      user.status === 'paused' ? 'Account is paused' : 'Finish your profile before using discovery',
    );
  }
}
