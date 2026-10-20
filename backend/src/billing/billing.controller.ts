import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, AuthUser, CurrentUser } from '../common/auth.guard';
import { parse } from '../common/validation';
import { BillingService } from './billing.service';

@Controller('billing')
export class BillingController {
  constructor(private readonly billing: BillingService) {}

  @Get('plans')
  plans() {
    return this.billing.plans();
  }

  @Post('verify')
  @HttpCode(200)
  @UseGuards(AuthGuard)
  verify(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    const input = parse(
      z.object({ store: z.enum(['play', 'app_store', 'dev']), productId: z.string(), purchaseToken: z.string().min(1).max(4096) }),
      body,
    );
    return this.billing.verify(user.id, input.store, input.productId, input.purchaseToken);
  }
}
