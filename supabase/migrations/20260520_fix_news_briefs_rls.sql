-- Migration: Fix news_briefs RLS select policy to allow anon reads
-- Date: 2026-05-20
-- Description: Allows anonymous (unauthenticated) app instances to fetch news briefs.

-- Drop the restrictive authenticated-only select policy
DROP POLICY IF EXISTS "Allow read access for authenticated users" ON public.news_briefs;

-- Create a new select policy allowing both anon and authenticated users
CREATE POLICY "Allow read access for all users" 
ON public.news_briefs
FOR SELECT 
TO anon, authenticated 
USING (is_active = true);
