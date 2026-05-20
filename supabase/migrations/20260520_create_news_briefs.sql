-- Migration: Create news_briefs table
-- Date: 2026-05-20
-- Description: Table for daily AI-curated student briefings.

CREATE TABLE IF NOT EXISTS public.news_briefs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category TEXT NOT NULL,
  source_name TEXT NOT NULL,
  original_title TEXT NOT NULL,
  headline TEXT NOT NULL,
  key_fact TEXT NOT NULL,
  summary TEXT NOT NULL,
  published_at TIMESTAMPTZ,
  fetched_date DATE NOT NULL DEFAULT CURRENT_DATE,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true NOT NULL,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Optimize queries by fetched_date, category, and is_active
CREATE INDEX IF NOT EXISTS idx_news_briefs_query 
ON public.news_briefs (fetched_date, category, is_active);

-- Enable Row Level Security
ALTER TABLE public.news_briefs ENABLE ROW LEVEL SECURITY;

-- Read-only policy for all users (anon and authenticated)
CREATE POLICY "Allow read access for all users" 
ON public.news_briefs
FOR SELECT 
TO anon, authenticated 
USING (is_active = true);

-- Full access policy for service role / admin
CREATE POLICY "Allow full access for service_role" 
ON public.news_briefs
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);
