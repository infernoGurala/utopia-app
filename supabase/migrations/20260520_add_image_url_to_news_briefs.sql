-- Migration: Add image_url to news_briefs
-- Date: 2026-05-20
-- Description: Adds a nullable image_url column to store article images.

ALTER TABLE public.news_briefs 
ADD COLUMN IF NOT EXISTS image_url TEXT;
