import { Injectable } from '@nestjs/common';
import { EventEmitter } from 'node:events';

export type AppEvent =
  | { type: 'like:new'; to: string; likeId: string }
  | { type: 'match:new'; users: [string, string]; matchId: string }
  | { type: 'match:removed'; users: [string, string]; matchId: string }
  | { type: 'message:new'; users: [string, string]; matchId: string; message: unknown }
  | { type: 'message:read'; to: string; matchId: string; readAt: string };

/** In-process event bus between services and the realtime gateway; swap for Redis pub/sub when scaling out. */
@Injectable()
export class Events {
  private readonly bus = new EventEmitter();

  emit(event: AppEvent): void {
    this.bus.emit('event', event);
  }

  on(listener: (event: AppEvent) => void): () => void {
    this.bus.on('event', listener);
    return () => this.bus.off('event', listener);
  }
}
