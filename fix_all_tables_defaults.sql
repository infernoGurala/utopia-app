-- Step 1: Drop the old incorrectly-configured habit_completions and reminders tables
DROP TABLE IF EXISTS habit_completions CASCADE;
DROP TABLE IF EXISTS reminders CASCADE;

-- Step 2: Recreate habit_completions table with correct DEFAULT UUID generator
CREATE TABLE habit_completions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  task_name TEXT NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT false,
  completion_count INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, date, task_name)
);
CREATE INDEX idx_hc_user_task_date ON habit_completions(user_id, task_name, date);
CREATE INDEX idx_hc_user_date ON habit_completions(user_id, date);

-- Step 3: Recreate reminders table with correct DEFAULT UUID generator
CREATE TABLE reminders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT NOT NULL,
  label TEXT NOT NULL,
  type TEXT NOT NULL,
  reminder_time TEXT NOT NULL,
  remind_date TEXT,
  weekdays INTEGER[] DEFAULT '{}',
  month_day INTEGER,
  active_months INTEGER[] DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_reminders_user ON reminders(user_id, is_active);

-- Step 4: Disable Row Level Security (RLS) on both tables
ALTER TABLE habit_completions DISABLE ROW LEVEL SECURITY;
ALTER TABLE reminders DISABLE ROW LEVEL SECURITY;
