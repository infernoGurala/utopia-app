-- Step 1: Drop the old incorrectly-configured daily_notes table
DROP TABLE IF EXISTS daily_notes CASCADE;

-- Step 2: Recreate daily_notes table with the correct UNIQUE constraint required for upserts
CREATE TABLE daily_notes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  habits_state JSONB NOT NULL DEFAULT '{}'::jsonb,
  tasks JSONB NOT NULL DEFAULT '[]'::jsonb,
  journal TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, date)
);
CREATE INDEX idx_dn_user_date ON daily_notes(user_id, date);

-- Step 3: Disable Row Level Security (RLS) to ensure offline-first sync works perfectly
ALTER TABLE daily_notes DISABLE ROW LEVEL SECURITY;
