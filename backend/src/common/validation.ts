import { BadRequestException } from '@nestjs/common';
import { z } from 'zod';

/** Parses a request body or query against a zod schema, returning 400 with field errors on failure. */
export function parse<S extends z.ZodTypeAny>(schema: S, input: unknown): z.infer<S> {
  const result = schema.safeParse(input);
  if (!result.success) {
    throw new BadRequestException({
      message: 'Validation failed',
      errors: result.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
    });
  }
  return result.data;
}

export const uuid = z.string().uuid();
