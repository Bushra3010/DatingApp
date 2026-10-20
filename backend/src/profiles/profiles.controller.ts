import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Put, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, AuthUser, CurrentUser } from '../common/auth.guard';
import { parse, uuid } from '../common/validation';
import { VITAL_KEYS } from './profile-cards.service';
import { GENDERS, INTENTS, ProfilesService, REQUIRED_PHOTOS, REQUIRED_PROMPTS } from './profiles.service';

const basics = z.object({
  firstName: z.string().trim().min(1).max(40).optional(),
  birthDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  gender: z.enum(GENDERS).optional(),
  showMe: z.array(z.enum(GENDERS)).min(1).optional(),
  intent: z.enum(INTENTS).optional(),
  heightCm: z.number().int().min(120).max(230).optional(),
  location: z.object({
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
    city: z.string().max(80).optional(),
  }).optional(),
});

const vital = z.object({ value: z.string().trim().max(80), visible: z.boolean() });
const vitals = z.object(Object.fromEntries(VITAL_KEYS.map((k) => [k, vital.optional()]))).strict();

function slot(position: number, count: number): number {
  return parse(z.number().int().min(0).max(count - 1), position);
}

@Controller()
@UseGuards(AuthGuard)
export class ProfilesController {
  constructor(private readonly profiles: ProfilesService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.profiles.me(user.id);
  }

  @Patch('me/basics')
  basics(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    return this.profiles.updateBasics(user.id, parse(basics, body));
  }

  @Patch('me/vitals')
  vitals(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    return this.profiles.updateVitals(user.id, parse(vitals, body));
  }

  @Put('me/photos/:position')
  setPhoto(@CurrentUser() user: AuthUser, @Param('position', ParseIntPipe) position: number, @Body() body: unknown) {
    const { mediaId, caption } = parse(z.object({ mediaId: uuid, caption: z.string().max(100).nullish() }), body);
    return this.profiles.setPhoto(user.id, slot(position, REQUIRED_PHOTOS), mediaId, caption ?? null);
  }

  @Delete('me/photos/:position')
  removePhoto(@CurrentUser() user: AuthUser, @Param('position', ParseIntPipe) position: number) {
    return this.profiles.removePhoto(user.id, slot(position, REQUIRED_PHOTOS));
  }

  @Post('me/photos/reorder')
  reorder(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    const { order } = parse(z.object({ order: z.array(uuid).max(REQUIRED_PHOTOS) }), body);
    return this.profiles.reorderPhotos(user.id, order);
  }

  @Get('prompts')
  prompts() {
    return this.profiles.prompts();
  }

  @Put('me/prompts/:position')
  setPrompt(@CurrentUser() user: AuthUser, @Param('position', ParseIntPipe) position: number, @Body() body: unknown) {
    const { promptId, answer } = parse(
      z.object({ promptId: z.string(), answer: z.string().trim().min(1).max(225) }),
      body,
    );
    return this.profiles.setPrompt(user.id, slot(position, REQUIRED_PROMPTS), promptId, answer);
  }

  @Delete('me/prompts/:position')
  removePrompt(@CurrentUser() user: AuthUser, @Param('position', ParseIntPipe) position: number) {
    return this.profiles.removePrompt(user.id, slot(position, REQUIRED_PROMPTS));
  }

  @Get('me/preview')
  preview(@CurrentUser() user: AuthUser) {
    return this.profiles.preview(user.id);
  }

  @Post('me/verification')
  verify(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    const { mediaId } = parse(z.object({ mediaId: uuid }), body);
    return this.profiles.submitVerification(user.id, mediaId);
  }
}
