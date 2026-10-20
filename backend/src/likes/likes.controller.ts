import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, AuthUser, CurrentUser } from '../common/auth.guard';
import { parse, uuid } from '../common/validation';
import { LikesService } from './likes.service';

const comment = z.string().trim().min(1).max(150).optional();

@Controller()
@UseGuards(AuthGuard)
export class LikesController {
  constructor(private readonly likes: LikesService) {}

  @Post('likes')
  send(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    const input = parse(
      z.object({ toUserId: uuid, targetType: z.enum(['photo', 'prompt']), targetId: uuid, comment }),
      body,
    );
    return this.likes.send(user, input);
  }

  @Get('likes/remaining')
  async remaining(@CurrentUser() user: AuthUser) {
    return { remaining: await this.likes.remainingLikes(user), unlimited: user.plan === 'plus' };
  }

  @Post('skips/:userId')
  @HttpCode(200)
  skip(@CurrentUser() user: AuthUser, @Param('userId', ParseUUIDPipe) userId: string) {
    return this.likes.skip(user, userId);
  }

  @Get('likes/received')
  inbox(@CurrentUser() user: AuthUser, @Query() query: unknown) {
    const { sort } = parse(z.object({ sort: z.enum(['oldest', 'newest']).default('oldest') }), query);
    return this.likes.inbox(user, sort);
  }

  @Post('likes/:id/match')
  @HttpCode(200)
  match(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() body: unknown) {
    const { comment: reply } = parse(z.object({ comment }), body ?? {});
    return this.likes.match(user, id, reply);
  }

  @Post('likes/:id/remove')
  @HttpCode(200)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.likes.remove(user, id);
  }
}
