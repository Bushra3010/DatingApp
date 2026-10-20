import { Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import {
  ConnectedSocket, MessageBody, OnGatewayConnection, SubscribeMessage, WebSocketGateway, WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { SessionResolver } from '../common/auth.guard';
import { Events } from '../common/events';
import { ChatService } from './chat.service';

const room = (userId: string) => `user:${userId}`;

/**
 * Realtime channel (socket.io, namespace /realtime). Clients connect with { auth: { token } } and receive
 * like:new, match:new, match:removed, message:new, message:read and typing events.
 */
@WebSocketGateway({ namespace: '/realtime', cors: { origin: true } })
export class ChatGateway implements OnGatewayConnection, OnModuleInit, OnModuleDestroy {
  private readonly log = new Logger('Realtime');
  private unsubscribe?: () => void;
  @WebSocketServer() server!: Server;

  constructor(private readonly sessions: SessionResolver, private readonly events: Events, private readonly chat: ChatService) {}

  onModuleInit() {
    this.unsubscribe = this.events.on((e) => {
      switch (e.type) {
        case 'like:new':
          this.server.to(room(e.to)).emit('like:new', { likeId: e.likeId });
          break;
        case 'match:new':
        case 'match:removed':
          for (const u of e.users) this.server.to(room(u)).emit(e.type, { matchId: e.matchId });
          break;
        case 'message:new':
          for (const u of e.users) {
            this.server.to(room(u)).emit('message:new', { matchId: e.matchId, message: this.chat.serialize(e.message, u) });
          }
          break;
        case 'message:read':
          this.server.to(room(e.to)).emit('message:read', { matchId: e.matchId, readAt: e.readAt });
          break;
      }
    });
  }

  onModuleDestroy() {
    this.unsubscribe?.();
  }

  async handleConnection(socket: Socket) {
    try {
      const user = await this.sessions.resolve(socket.handshake.auth?.token);
      socket.data.userId = user.id;
      await socket.join(room(user.id));
    } catch {
      socket.emit('error', { message: 'unauthorized' });
      socket.disconnect(true);
    }
  }

  /** CH-1 typing indicator: forwarded to the other person only, never stored. */
  @SubscribeMessage('typing')
  async typing(@ConnectedSocket() socket: Socket, @MessageBody() body: { matchId?: string }) {
    const userId: string | undefined = socket.data.userId;
    if (!userId || typeof body?.matchId !== 'string') return;
    try {
      const m = await this.chat.matchFor(userId, body.matchId);
      this.server.to(room(m.other_id)).emit('typing', { matchId: m.id });
    } catch {
      this.log.debug(`typing for unknown match from ${userId}`);
    }
  }
}
