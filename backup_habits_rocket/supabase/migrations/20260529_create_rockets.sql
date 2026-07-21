-- ── MIGRATION: CREATE FOCUS ROCKETS SCHEMA ──
-- Migration Date: 2026-05-29
-- Description: Creates the focus_rockets table and storage configurations for neural speed reader files.

-- Create public.focus_rockets table
CREATE TABLE IF NOT EXISTS public.focus_rockets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  raw_text TEXT NOT NULL,
  voice TEXT NOT NULL,
  speed DOUBLE PRECISION NOT NULL DEFAULT 1.0,
  timings JSONB NOT NULL,
  groq_styles JSONB,
  supabase_audio_urls TEXT[] NOT NULL DEFAULT '{}',
  cloudinary_audio_urls TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Disable Row Level Security (RLS) to match other tables in the project
ALTER TABLE public.focus_rockets DISABLE ROW LEVEL SECURITY;

-- Storage configuration: create a public 'rockets' bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('rockets', 'rockets', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies if they exist to avoid conflict
DROP POLICY IF EXISTS "Public Access on rockets" ON storage.objects;
DROP POLICY IF EXISTS "Insert Access on rockets" ON storage.objects;
DROP POLICY IF EXISTS "Delete Access on rockets" ON storage.objects;

-- Create policies for storage access
CREATE POLICY "Public Access on rockets" ON storage.objects
  FOR SELECT USING (bucket_id = 'rockets');

CREATE POLICY "Insert Access on rockets" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'rockets');

CREATE POLICY "Delete Access on rockets" ON storage.objects
  FOR DELETE USING (bucket_id = 'rockets');
