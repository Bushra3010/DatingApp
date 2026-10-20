import { Body, Controller, Delete, HttpCode, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, AuthUser, CurrentUser } from '../common/auth.guard';
import { parse, uuid } from '../common/validation';
import { REPORT_REASONS, SafetyService } from './safety.service';

/** Safety tools are available to every user, free or paid, in any account state. */
@Controller()
@UseGuards(AuthGuard)
export class SafetyController {
  constructor(private readonly safety: SafetyService) {}

  @Post('blocks/:userId')
  @HttpCode(200)
  async block(@CurrentUser() user: AuthUser, @Param('userId', ParseUUIDPipe) userId: string) {
    await this.safety.block(user.id, userId);
    return { blocked: true };
  }

  @Delete('blocks/:userId')
  async unblock(@CurrentUser() user: AuthUser, @Param('userId', ParseUUIDPipe) userId: string) {
    await this.safety.unblock(user.id, userId);
    return { blocked: false };
  }

  @Post('reports')
  report(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    const input = parse(
      z.object({
        userId: uuid,
        reason: z.enum(REPORT_REASONS),
        details: z.string().trim().max(1000).optional(),
        messageId: uuid.optional(),
      }),
      body,
    );
    return this.safety.report(user.id, input.userId, input.reason, input.details, input.messageId);
  }
}
