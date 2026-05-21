-- Migration: Grant SELECT on news tables to anon role
-- Date: 2026-05-20
-- Description: PostgREST cannot see tables unless the requesting role has base
--              table privileges. The existing RLS policies filter rows, but the
--              anon role still needs GRANT SELECT to even access the tables.

-- news_briefs: grant base SELECT to anon and authenticated
GRANT SELECT ON public.news_briefs TO anon, authenticated;

-- news_categories: grant base SELECT to anon (was only authenticated before)
GRANT SELECT ON public.news_categories TO anon, authenticated;
