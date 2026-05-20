-- Migration: Add fetched_at to news_briefs
-- Date: 2026-05-20
-- Description: Adds a fetched_at timestamptz column to store accurate scrape times and allow concurrent historical batches.

ALTER TABLE public.news_briefs ADD COLUMN IF NOT EXISTS fetched_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL;

-- Optimize queries by fetched_at, category, and is_active
CREATE INDEX IF NOT EXISTS idx_news_briefs_fetched_at 
ON public.news_briefs (fetched_at, category, is_active);
