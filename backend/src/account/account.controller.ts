import { Body, Controller, Delete, Get, HttpCode, Patch, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, AuthUser, CurrentUser } from '../common/auth.guard';
import { parse } from '../common/validation';
import { AccountService } from './account.service';

@Controller('me')
@UseGuards(AuthGuard)
export class AccountController {
  constructor(private readonly account: AccountService) {}

  @Get('preferences')
  preferences(@CurrentUser() user: AuthUser) {
    return this.account.preferences(user.id);
  }

  @Patch('preferences')
  updatePreferences(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    const input = parse(
      z.object({
        ageMin: z.number().int().min(18).max(99).optional(),
        ageMax: z.number().int().min(18).max(99).optional(),
        maxDistanceKm: z.number().int().min(1).max(500).optional(),
      }),
      body,
    );
    return this.account.updatePreferences(user.id, input);
  }

  @Get('settings')
  settings(@CurrentUser() user: AuthUser) {
    return this.account.settings(user.id);
  }

  @Patch('settings')
  updateSettings(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    const push = z.object({
      likes: z.boolean(), matches: z.boolean(), messages: z.boolean(), reminders: z.boolean(),
    }).partial().strict();
    return this.account.updateSettings(user.id, parse(z.object({ readReceipts: z.boolean().optional(), push: push.optional() }), body));
  }

  @Post('pause')
  @HttpCode(200)
  pause(@CurrentUser() user: AuthUser) {
    return this.account.pause(user.id);
  }

  @Post('unpause')
  @HttpCode(200)
  unpause(@CurrentUser() user: AuthUser) {
    return this.account.unpause(user.id);
  }

  @Get('export')
  export(@CurrentUser() user: AuthUser) {
    return this.account.export(user.id);
  }

  @Delete()
  delete(@CurrentUser() user: AuthUser) {
    return this.account.delete(user.id);
  }
}
