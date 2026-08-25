import * as z from 'zod/v4'

export const unsafeInputSchema = z.object({
  limit: z.number().default(20),
})
