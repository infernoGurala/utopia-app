-- ============================================================================
-- Delve — Supabase Schema
-- Run this in your Supabase SQL Editor on focus-1 project.
-- ============================================================================

-- User profiles (synced from Firebase Auth)
CREATE TABLE IF NOT EXISTS delve_profiles (
  uid TEXT PRIMARY KEY,
  display_name TEXT,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  total_decks_completed INT DEFAULT 0,
  total_words_learned INT DEFAULT 0
);

-- Word inventory (waiting pool)
CREATE TABLE IF NOT EXISTS delve_inventory (
  id TEXT PRIMARY KEY,
  uid TEXT NOT NULL REFERENCES delve_profiles(uid) ON DELETE CASCADE,
  word TEXT NOT NULL,
  meaning TEXT NOT NULL,
  ai_meaning TEXT,
  note TEXT,
  part_of_speech TEXT,
  added_at TIMESTAMPTZ NOT NULL,
  archived_at TIMESTAMPTZ,
  fail_count INT DEFAULT 0
);

-- Word archive (learned words)
CREATE TABLE IF NOT EXISTS delve_archive (
  id TEXT PRIMARY KEY,
  uid TEXT NOT NULL REFERENCES delve_profiles(uid) ON DELETE CASCADE,
  word TEXT NOT NULL,
  meaning TEXT NOT NULL,
  ai_meaning TEXT,
  note TEXT,
  part_of_speech TEXT,
  added_at TIMESTAMPTZ NOT NULL,
  archived_at TIMESTAMPTZ NOT NULL,
  fail_count INT DEFAULT 0
);

-- Active deck
CREATE TABLE IF NOT EXISTS delve_active_deck (
  id TEXT PRIMARY KEY,
  uid TEXT NOT NULL UNIQUE REFERENCES delve_profiles(uid) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL,
  current_day INT DEFAULT 1,
  status INT DEFAULT 0,
  set1_word_ids JSONB NOT NULL,
  set2_word_ids JSONB NOT NULL,
  set3_word_ids JSONB NOT NULL,
  last_session_date TIMESTAMPTZ
);

-- ============================================================================
-- Indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_delve_inventory_uid ON delve_inventory(uid);
CREATE INDEX IF NOT EXISTS idx_delve_archive_uid ON delve_archive(uid);
CREATE INDEX IF NOT EXISTS idx_delve_active_deck_uid ON delve_active_deck(uid);

-- ============================================================================
-- Row Level Security (RLS)
-- Disable RLS to allow offline-first cache reads/writes without complex auth policies
-- ============================================================================

ALTER TABLE delve_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE delve_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE delve_archive DISABLE ROW LEVEL SECURITY;
ALTER TABLE delve_active_deck DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RPC: Atomic increment for deck stats
-- ============================================================================

CREATE OR REPLACE FUNCTION increment_deck_stats(p_uid TEXT, p_words INT)
RETURNS VOID AS $$
BEGIN
  UPDATE delve_profiles
  SET total_decks_completed = total_decks_completed + 1,
      total_words_learned = total_words_learned + p_words
  WHERE uid = p_uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
