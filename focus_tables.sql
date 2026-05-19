-- Focus Daily Notes Table
CREATE TABLE IF NOT EXISTS daily_notes (
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
CREATE INDEX IF NOT EXISTS idx_dn_user_date ON daily_notes(user_id, date);

-- Focus User Habits Configuration Table
CREATE TABLE IF NOT EXISTS focus_user_habits (
  user_id TEXT PRIMARY KEY,
  habits JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Focus Habit completions Table for Heatmaps
CREATE TABLE IF NOT EXISTS habit_completions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  task_name TEXT NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT false,
  completion_count INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, date, task_name)
);
CREATE INDEX IF NOT EXISTS idx_hc_user_task_date ON habit_completions(user_id, task_name, date);
CREATE INDEX IF NOT EXISTS idx_hc_user_date ON habit_completions(user_id, date);

-- Focus Reminders Table
CREATE TABLE IF NOT EXISTS reminders (
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
CREATE INDEX IF NOT EXISTS idx_reminders_user ON reminders(user_id, is_active);

-- Disable Row Level Security (RLS) to allow offline-first sync without complex Auth wrappers for now
ALTER TABLE daily_notes DISABLE ROW LEVEL SECURITY;
ALTER TABLE focus_user_habits DISABLE ROW LEVEL SECURITY;
ALTER TABLE habit_completions DISABLE ROW LEVEL SECURITY;
ALTER TABLE reminders DISABLE ROW LEVEL SECURITY;
