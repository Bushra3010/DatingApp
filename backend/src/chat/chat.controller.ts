import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, AuthUser, CurrentUser } from '../common/auth.guard';
import { parse, uuid } from '../common/validation';
import { ChatService } from './chat.service';

const message = z.discriminatedUnion('kind', [
  z.object({ kind: z.literal('text'), body: z.string().trim().min(1).max(2000) }),
  z.object({ kind: z.literal('gif'), url: z.string().url() }),
  z.object({ kind: z.literal('voice'), mediaId: uuid, durationS: z.number().int().min(1).max(60) }),
]);

@Controller('matches')
@UseGuards(AuthGuard)
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.chat.list(user.id);
  }

  @Get(':id/messages')
  messages(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Query() query: unknown) {
    const { before, limit } = parse(
      z.object({ before: z.string().datetime().optional(), limit: z.coerce.number().int().min(1).max(100).default(50) }),
      query,
    );
    return this.chat.messages(user.id, id, before, limit);
  }

  @Post(':id/messages')
  send(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() body: unknown) {
    return this.chat.send(user, id, parse(message, body));
  }

  @Post(':id/read')
  @HttpCode(200)
  read(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.chat.markRead(user.id, id);
  }

  @Post(':id/unmatch')
  @HttpCode(200)
  unmatch(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.chat.unmatch(user.id, id);
  }
}
