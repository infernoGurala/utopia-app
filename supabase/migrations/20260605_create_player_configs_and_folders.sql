-- ── MIGRATION: CREATE PLAYER CONFIGS AND FOLDERS SCHEMA ──
-- Migration Date: 2026-06-05
-- Description: Creates rocket_player_configs and focus_folders tables, and adds folder_id column to focus_rockets.

-- Create public.focus_folders table
CREATE TABLE IF NOT EXISTS public.focus_folders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Disable Row Level Security (RLS) to match other tables in the project
ALTER TABLE public.focus_folders DISABLE ROW LEVEL SECURITY;

-- Add folder_id column to focus_rockets table
ALTER TABLE public.focus_rockets ADD COLUMN IF NOT EXISTS folder_id TEXT;

-- Create public.rocket_player_configs table
CREATE TABLE IF NOT EXISTS public.rocket_player_configs (
  user_id TEXT PRIMARY KEY,
  playback_speed DOUBLE PRECISION DEFAULT 1.0,
  highlight_mode BOOLEAN DEFAULT TRUE,
  is_dark_stage BOOLEAN DEFAULT FALSE,
  word_by_word_mode BOOLEAN DEFAULT FALSE,
  show_history BOOLEAN DEFAULT TRUE,
  show_samples BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Disable Row Level Security (RLS) to match other tables in the project
ALTER TABLE public.rocket_player_configs DISABLE ROW LEVEL SECURITY;
