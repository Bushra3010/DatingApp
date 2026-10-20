import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { z } from 'zod';
import { parse } from '../common/validation';
import { AuthService } from './auth.service';

const phone = z.string().regex(/^\+[1-9]\d{7,14}$/, 'Use international format, e.g. +919876543210');

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('otp/request')
  @HttpCode(200)
  request(@Body() body: unknown) {
    const { phone: p } = parse(z.object({ phone }), body);
    return this.auth.requestOtp(p);
  }

  @Post('otp/verify')
  @HttpCode(200)
  verify(@Body() body: unknown) {
    const { phone: p, code } = parse(z.object({ phone, code: z.string().regex(/^\d{6}$/) }), body);
    return this.auth.verifyOtp(p, code);
  }
}
