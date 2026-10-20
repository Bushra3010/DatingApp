import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, AuthUser, CurrentUser, requireActive } from '../common/auth.guard';
import { parse } from '../common/validation';
import { DiscoveryService } from './discovery.service';

@Controller('discover')
@UseGuards(AuthGuard)
export class DiscoveryController {
  constructor(private readonly discovery: DiscoveryService) {}

  /** DI-1: profiles to show one at a time, best first. */
  @Get()
  feed(@CurrentUser() user: AuthUser, @Query() query: unknown) {
    requireActive(user);
    const { limit } = parse(z.object({ limit: z.coerce.number().int().min(1).max(30).default(10) }), query);
    return this.discovery.feed(user.id, limit);
  }
}
